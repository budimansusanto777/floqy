import CoreAudio
import Foundation
import IOKit
import IOKit.ps

private let floqyPowerSourceCallback: IOPowerSourceCallbackType = { context in
    guard let context else { return }
    let service = Unmanaged<HardwareStatusService>.fromOpaque(context).takeUnretainedValue()
    Task { @MainActor in
        service.handlePowerSourceChange()
    }
}

/// Observes macOS battery power-source callbacks and CoreAudio default headphone route changes with zero idle polling.
@MainActor
final class HardwareStatusService: ObservableObject {
    @Published private(set) var battery: BatteryStatus?
    @Published private(set) var headphones: HeadphoneStatus?

    var onChargingConnected: ((BatteryStatus) -> Void)?
    var onHeadphonesConnected: ((HeadphoneStatus) -> Void)?

    private var powerRunLoopSource: CFRunLoopSource?
    private var audioListenerBlock: AudioObjectPropertyListenerBlock?
    private var lastObservedOutputName: String?
    private var isStarted = false

    deinit {
        if let source = powerRunLoopSource {
            CFRunLoopSourceInvalidate(source)
        }
        if let block = audioListenerBlock {
            var address = Self.defaultOutputPropertyAddress
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                DispatchQueue.main,
                block
            )
        }
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true

        // Capture initial baseline silently so app launch never flashes false connection cards.
        battery = Self.readBatteryStatus()
        let initialAudio = Self.readAudioRoute()
        lastObservedOutputName = initialAudio.deviceName
        headphones = initialAudio.headphones

        registerPowerSourceObserver()
        registerAudioOutputObserver()
    }

    func stop() {
        isStarted = false
        if let source = powerRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            CFRunLoopSourceInvalidate(source)
            powerRunLoopSource = nil
        }
        if let block = audioListenerBlock {
            var address = Self.defaultOutputPropertyAddress
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                DispatchQueue.main,
                block
            )
            audioListenerBlock = nil
        }
    }

    // MARK: - Observers

    nonisolated private static var defaultOutputPropertyAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func registerPowerSourceObserver() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let unmanagedSource = IOPSNotificationCreateRunLoopSource(floqyPowerSourceCallback, context) else {
            return
        }
        let source = unmanagedSource.takeRetainedValue()
        powerRunLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    private func registerAudioOutputObserver() {
        var address = Self.defaultOutputPropertyAddress
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.handleAudioOutputChange()
            }
        }
        audioListenerBlock = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            block
        )
    }

    // MARK: - Event Handling

    fileprivate func handlePowerSourceChange() {
        guard let current = Self.readBatteryStatus() else { return }
        let previous = battery
        battery = current
        if HardwareStatusLogic.shouldTriggerChargingCard(previous: previous, current: current) {
            onChargingConnected?(current)
        }
    }

    private func handleAudioOutputChange() {
        let route = Self.readAudioRoute()
        let previousName = lastObservedOutputName
        lastObservedOutputName = route.deviceName
        headphones = route.headphones

        if HardwareStatusLogic.shouldTriggerHeadphoneCard(previousDeviceName: previousName, current: route.headphones) {
            // Re-read Bluetooth HID battery shortly after route switch so AirPods report fresh percentage.
            if let initial = route.headphones {
                onHeadphonesConnected?(initial)
            }
        }
    }

    // MARK: - IOKit & CoreAudio Readers

    private static func readBatteryStatus() -> BatteryStatus? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any],
                  let type = desc[kIOPSTypeKey as String] as? String,
                  type == (kIOPSInternalBatteryType as String) else {
                continue
            }

            let current = desc[kIOPSCurrentCapacityKey as String] as? Int ?? 0
            let maxCapacity = max(1, desc[kIOPSMaxCapacityKey as String] as? Int ?? 100)
            let pct = min(100, max(0, Int((Double(current) / Double(maxCapacity) * 100).rounded())))
            let isCharging = desc[kIOPSIsChargingKey as String] as? Bool ?? false
            let sourceState = desc[kIOPSPowerSourceStateKey as String] as? String
            let isPluggedIn = sourceState == (kIOPSACPowerValue as String)
            let timeToFull = desc[kIOPSTimeToFullChargeKey as String] as? Int

            return BatteryStatus(
                percentage: pct,
                isCharging: isCharging,
                isPluggedIn: isPluggedIn,
                timeToFullMinutes: timeToFull
            )
        }
        return nil
    }

    private static func readAudioRoute() -> (deviceName: String?, headphones: HeadphoneStatus?) {
        var address = defaultOutputPropertyAddress
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != AudioDeviceID(kAudioObjectUnknown) else {
            return (nil, nil)
        }

        let name = readDeviceName(deviceID: deviceID) ?? "Audio Device"
        let transport = readDeviceTransportType(deviceID: deviceID)
        let isBluetooth = transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
        let isWiredHeadphone = readIsWiredHeadphonePort(deviceID: deviceID)

        guard HardwareStatusLogic.isLikelyHeadphoneDevice(
            name: name,
            isBluetooth: isBluetooth,
            isWiredHeadphonePort: isWiredHeadphone
        ) else {
            return (name, nil)
        }

        let isAirPods = HardwareStatusLogic.isAirPodsName(name)
        let battery = isBluetooth ? readBluetoothBatteryPercent(matchingName: name) : nil
        return (name, HeadphoneStatus(name: name, batteryPercent: battery, isAirPods: isAirPods))
    }

    private static func readDeviceName(deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfName: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &cfName)
        guard status == noErr, let cfName else { return nil }
        return cfName.takeRetainedValue() as String
    }

    private static func readDeviceTransportType(deviceID: AudioDeviceID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transport)
        return status == noErr ? transport : 0
    }

    private static func readIsWiredHeadphonePort(deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDataSource,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return false }
        var sourceCode: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &sourceCode)
        // 'hdpn' = 0x6864_706E (built-in 3.5mm headphone jack)
        return status == noErr && sourceCode == 0x6864_706E
    }

    private static func readBluetoothBatteryPercent(matchingName deviceName: String) -> Int? {
        guard let matching = IOServiceMatching("AppleDeviceManagementHIDEventService") else {
            return nil
        }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        let targetLower = deviceName.lowercased()
        var fallbackPercent: Int?

        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            var propsRef: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(entry, &propsRef, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let props = propsRef?.takeRetainedValue() as? [String: Any],
                  let percent = props["BatteryPercent"] as? Int else {
                continue
            }

            let product = (props["Product"] as? String ?? "").lowercased()
            if !product.isEmpty && (targetLower.contains(product) || product.contains(targetLower)) {
                return min(100, max(0, percent))
            }
            if HardwareStatusLogic.isAirPodsName(targetLower) && HardwareStatusLogic.isAirPodsName(product) {
                return min(100, max(0, percent))
            }
            if fallbackPercent == nil && (product.contains("pod") || product.contains("beats") || product.contains("head")) {
                fallbackPercent = min(100, max(0, percent))
            }
        }
        return fallbackPercent
    }
}
