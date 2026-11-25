import Foundation

enum MemoryPressureLevel: String, Equatable {
    case nominal = "Nominal"
    case warning = "Elevated"
    case critical = "Critical"
}

struct MemorySnapshot: Equatable {
    let totalBytes: UInt64
    let appBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let swapUsedBytes: UInt64
    let freeBytes: UInt64

    static let empty = MemorySnapshot(
        totalBytes: 0,
        appBytes: 0,
        wiredBytes: 0,
        compressedBytes: 0,
        swapUsedBytes: 0,
        freeBytes: 0
    )

    var usedBytes: UInt64 {
        min(totalBytes, appBytes &+ wiredBytes &+ compressedBytes)
    }

    var usedPercent: Int {
        guard totalBytes > 0 else { return 0 }
        return min(100, Int((Double(usedBytes) / Double(totalBytes) * 100.0).rounded()))
    }

    var pressureLevel: MemoryPressureLevel {
        if usedPercent >= SystemLogic.ramAlertThresholdPercent {
            return .critical
        }
        if usedPercent >= 75 {
            return .warning
        }
        return .nominal
    }

    static func formatBytes(_ bytes: UInt64) -> String {
        if bytes >= 1_073_741_824 {
            return String(format: "%.1f GB", Double(bytes) / 1_073_741_824.0)
        }
        return "\(bytes / 1_048_576) MB"
    }
}

struct MemoryConsumer: Identifiable, Equatable {
    var id: Int32 { pid }
    let pid: Int32
    let name: String
    let residentBytes: UInt64
    let isProtected: Bool
}

struct LocalDevPort: Identifiable, Equatable {
    var id: String { "\(pid)-\(port)" }
    let pid: Int32
    let port: Int
    let processName: String
    let isHTTP: Bool
}

/// Pure parsing and calculation helpers for kernel memory stats, processes, and local dev ports.
enum SystemLogic {
    static let ramAlertThresholdPercent = 85

    static let protectedProcessNames: Set<String> = [
        "kernel_task",
        "launchd",
        "windowserver",
        "loginwindow",
        "finder",
        "dock",
        "systemuiserver",
        "mds",
        "mds_stores",
        "coreaudiod",
        "bluetoothd",
        "cfprefsd",
        "distnoted",
        "notifyd",
        "floqy"
    ]

    private static let preferredDevPorts: Set<Int> = [
        3000, 3001, 4000, 4200, 4321, 5000, 5173, 5174, 5432, 6379, 8000, 8080, 8081, 8888, 9000, 11434
    ]

    private static let nonHTTPPorts: Set<Int> = [
        5432, 3306, 6379, 27017, 5672, 9092, 11211
    ]

    static func isProtectedProcess(_ name: String) -> Bool {
        let base = (name as NSString).lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return protectedProcessNames.contains(base)
    }

    static func parseTopMemoryProcesses(
        psOutput: String,
        limit: Int = 5,
        selfPID: Int32 = 0
    ) -> [MemoryConsumer] {
        var consumers: [MemoryConsumer] = []

        for rawLine in psOutput.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Format from `ps -Arcwwwxo pid=,rss=,comm=`: "<pid> <rss_kb> <command path...>"
            let parts = trimmed.split(maxSplits: 2, omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
            guard parts.count == 3,
                  let pid = Int32(parts[0]),
                  let rssKB = UInt64(parts[1]) else {
                continue
            }

            let commandPath = String(parts[2]).trimmingCharacters(in: .whitespaces)
            let name = (commandPath as NSString).lastPathComponent
            guard pid > 1, pid != selfPID, !name.isEmpty else { continue }

            let isProtected = isProtectedProcess(name)
            guard !isProtected else { continue }

            consumers.append(
                MemoryConsumer(
                    pid: pid,
                    name: name,
                    residentBytes: rssKB * 1024,
                    isProtected: false
                )
            )
        }

        let sorted = consumers.sorted { lhs, rhs in
            if lhs.residentBytes != rhs.residentBytes {
                return lhs.residentBytes > rhs.residentBytes
            }
            return lhs.pid < rhs.pid
        }
        return Array(sorted.prefix(max(0, limit)))
    }

    static func parseListeningPorts(lsofOutput: String, limit: Int = 10) -> [LocalDevPort] {
        var currentPID: Int32?
        var currentCommand = "process"
        var seenPorts: Set<Int> = []
        var ports: [LocalDevPort] = []

        for rawLine in lsofOutput.components(separatedBy: .newlines) {
            guard let tag = rawLine.first else { continue }
            let value = String(rawLine.dropFirst())

            switch tag {
            case "p":
                currentPID = Int32(value)
                currentCommand = "process"
            case "c":
                if !value.isEmpty {
                    currentCommand = value
                }
            case "n":
                guard let pid = currentPID,
                      let colonIndex = value.lastIndex(of: ":") else {
                    continue
                }
                let portSlice = value[value.index(after: colonIndex)...]
                guard let port = Int(portSlice),
                      (1024...49151).contains(port),
                      !seenPorts.contains(port) else {
                    continue
                }
                seenPorts.insert(port)
                ports.append(
                    LocalDevPort(
                        pid: pid,
                        port: port,
                        processName: currentCommand,
                        isHTTP: !nonHTTPPorts.contains(port)
                    )
                )
            default:
                continue
            }
        }

        let sorted = ports.sorted { lhs, rhs in
            let lhsPreferred = preferredDevPorts.contains(lhs.port)
            let rhsPreferred = preferredDevPorts.contains(rhs.port)
            if lhsPreferred != rhsPreferred {
                return lhsPreferred && !rhsPreferred
            }
            return lhs.port < rhs.port
        }
        return Array(sorted.prefix(max(0, limit)))
    }
}
