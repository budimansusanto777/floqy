import AppKit
import Combine
import Darwin
import Foundation

/// Monitors kernel memory pressure, top RAM processes, and active local dev ports.
@MainActor
final class SystemMonitorService: ObservableObject {
    @Published private(set) var snapshot: MemorySnapshot = .empty
    @Published private(set) var topConsumers: [MemoryConsumer] = []
    @Published private(set) var localPorts: [LocalDevPort] = []
    @Published private(set) var isPurging: Bool = false
    @Published private(set) var statusMessage: String?

    var onStateChanged: (() -> Void)?

    private var memoryTimer: Timer?
    private var processTimer: Timer?
    private var isRefreshingProcesses = false
    private var isSystemTabVisible = false
    private var lastAlertThresholdActive = false

    func start() {
        stop()
        refreshMemory()
        refreshProcessesAndPorts()

        memoryTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshMemory()
            }
        }
    }

    func stop() {
        memoryTimer?.invalidate()
        memoryTimer = nil
        processTimer?.invalidate()
        processTimer = nil
    }

    func setSystemTabVisible(_ visible: Bool) {
        guard isSystemTabVisible != visible else { return }
        isSystemTabVisible = visible
        processTimer?.invalidate()
        processTimer = nil

        guard visible else { return }
        refreshMemory()
        refreshProcessesAndPorts()
        processTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshProcessesAndPorts()
            }
        }
    }

    func refreshMemory() {
        let updated = Self.readKernelMemorySnapshot()
        snapshot = updated
        let alertActive = updated.usedPercent >= SystemLogic.ramAlertThresholdPercent
        if alertActive != lastAlertThresholdActive {
            lastAlertThresholdActive = alertActive
            onStateChanged?()
        }
    }

    func refreshProcessesAndPorts() {
        guard !isRefreshingProcesses else { return }
        isRefreshingProcesses = true
        let selfPID = ProcessInfo.processInfo.processIdentifier

        Task { [weak self] in
            let results = await Task.detached(priority: .utility) { () -> ([MemoryConsumer], [LocalDevPort]) in
                let psOutput = Self.runCommand("/bin/ps", arguments: ["-Arcwwwxo", "pid=,rss=,comm="]).stdout
                let lsofOutput = Self.runCommand("/usr/sbin/lsof", arguments: ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcn"]).stdout
                let consumers = SystemLogic.parseTopMemoryProcesses(psOutput: psOutput, limit: 6, selfPID: selfPID)
                let ports = SystemLogic.parseListeningPorts(lsofOutput: lsofOutput, limit: 10)
                return (consumers, ports)
            }.value

            guard let self else { return }
            self.topConsumers = results.0
            self.localPorts = results.1
            self.isRefreshingProcesses = false
        }
    }

    @discardableResult
    func terminateProcess(pid: Int32, name: String) -> Bool {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        guard pid > 1, pid != selfPID, !SystemLogic.isProtectedProcess(name) else {
            statusMessage = "Cannot quit protected process \(name)"
            return false
        }

        if let runningApp = NSRunningApplication(processIdentifier: pid), runningApp.terminate() {
            schedulePostTerminateRefresh()
            return true
        }

        if Darwin.kill(pid, SIGTERM) == 0 {
            schedulePostTerminateRefresh()
            return true
        }

        statusMessage = "Unable to stop \(name)"
        return false
    }

    private func schedulePostTerminateRefresh() {
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.refreshMemory()
            self?.refreshProcessesAndPorts()
        }
    }

    func openLocalPort(_ port: LocalDevPort) {
        guard port.isHTTP, let url = URL(string: "http://localhost:\(port.port)") else { return }
        NSWorkspace.shared.open(url)
    }

    func purgeMemoryCache() async -> String {
        guard !isPurging else { return "Purge already in progress" }
        isPurging = true
        statusMessage = nil

        let result = await Task.detached(priority: .userInitiated) {
            Self.runCommand("/usr/bin/osascript", arguments: [
                "-e",
                "do shell script \"/usr/sbin/purge\" with administrator privileges"
            ])
        }.value

        isPurging = false
        refreshMemory()

        let message: String
        if result.status == 0 {
            message = "Memory cache purged"
        } else if result.stderr.localizedCaseInsensitiveContains("cancel") {
            message = "Purge cancelled"
        } else {
            message = "Purge failed"
        }
        statusMessage = message
        return message
    }

    // MARK: - Kernel & Process Helpers

    private nonisolated static func readKernelMemorySnapshot() -> MemorySnapshot {
        let total = ProcessInfo.processInfo.physicalMemory
        let rawPageSize = sysconf(_SC_PAGESIZE)
        let pageSize = UInt64(max(4096, rawPageSize))

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let status: kern_return_t = withUnsafeMutablePointer(to: &stats) { statsPtr in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard status == KERN_SUCCESS else { return .empty }

        let active = UInt64(stats.active_count) * pageSize
        let speculative = UInt64(stats.speculative_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let free = UInt64(stats.free_count) * pageSize

        let purgeable = UInt64(stats.purgeable_count) * pageSize
        let external = UInt64(stats.external_page_count) * pageSize
        let appRaw = active &+ speculative
        let reclaimable = purgeable &+ external
        let app = appRaw > reclaimable ? (appRaw - reclaimable) : active

        var swapUsage = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.stride
        sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0)

        return MemorySnapshot(
            totalBytes: total,
            appBytes: app,
            wiredBytes: wired,
            compressedBytes: compressed,
            swapUsedBytes: swapUsage.xsu_used,
            freeBytes: free
        )
    }

    private nonisolated static func runCommand(_ executablePath: String, arguments: [String]) -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
            var errData = Data()
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global(qos: .utility).async {
                errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.wait()
            process.waitUntilExit()
            return (
                process.terminationStatus,
                String(data: outData, encoding: .utf8) ?? "",
                String(data: errData, encoding: .utf8) ?? ""
            )
        } catch {
            return (-1, "", error.localizedDescription)
        }
    }
}
