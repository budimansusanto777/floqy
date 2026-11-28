import Foundation

/// Battery charge state parsed from macOS IOKit power sources.
struct BatteryStatus: Equatable {
    let percentage: Int
    let isCharging: Bool
    let isPluggedIn: Bool
    let timeToFullMinutes: Int?

    var formattedETA: String? {
        guard let mins = timeToFullMinutes, mins > 0, mins <= 1440 else { return nil }
        if mins < 60 {
            return "\(mins)m to full"
        }
        let hours = mins / 60
        let remainder = mins % 60
        return remainder > 0 ? "\(hours)h \(remainder)m to full" : "\(hours)h to full"
    }
}

/// Connected audio output headphone metadata.
struct HeadphoneStatus: Equatable {
    let name: String
    let batteryPercent: Int?
    let isAirPods: Bool
}

/// Low battery severity threshold crossed while discharging.
enum LowBatteryLevel: Int, Equatable, Hashable {
    case warning = 20
    case critical = 10

    var isCritical: Bool { self == .critical }
}

/// Pure edge-detection and classification rules for macOS battery and headphone hardware alerts.
enum HardwareStatusLogic {
    static let lowBatteryWarningThreshold = 20
    static let lowBatteryCriticalThreshold = 10

    private static let headphoneKeywords = [
        "airpods", "headphone", "headset", "beats", "earbuds",
        "buds", "bose", "qc", "wh-", "wf-", "momentum", "sony"
    ]

    private static let builtInKeywords = [
        "macbook", "built-in", "imac", "studio display", "hdmi", "displayport"
    ]

    static func shouldTriggerChargingCard(previous: BatteryStatus?, current: BatteryStatus) -> Bool {
        guard let previous else { return false }
        return (!previous.isPluggedIn && current.isPluggedIn) || (!previous.isCharging && current.isCharging)
    }

    static func lowBatteryAlertToTrigger(
        previous: BatteryStatus?,
        current: BatteryStatus,
        lastAlertedThreshold: Int?
    ) -> (level: LowBatteryLevel?, nextAlertedThreshold: Int?) {
        if current.isCharging || current.isPluggedIn || current.percentage > lowBatteryWarningThreshold {
            return (nil, nil)
        }
        let target: LowBatteryLevel = current.percentage <= lowBatteryCriticalThreshold ? .critical : .warning
        guard previous != nil else {
            // Seed baseline silently on launch so we do not flash immediately, while still alerting on a drop to critical.
            return (nil, target.rawValue)
        }
        if lastAlertedThreshold == nil || target.rawValue < lastAlertedThreshold! {
            return (target, target.rawValue)
        }
        return (nil, lastAlertedThreshold)
    }

    static func headphoneLowBatteryAlertToTrigger(
        deviceName: String?,
        batteryPercent: Int?,
        lastDeviceName: String?,
        lastAlertedThreshold: Int?
    ) -> (level: LowBatteryLevel?, nextDeviceName: String?, nextAlertedThreshold: Int?) {
        guard let deviceName else {
            return (nil, nil, nil)
        }
        let effectiveLast = (deviceName == lastDeviceName) ? lastAlertedThreshold : nil
        guard let pct = batteryPercent else {
            return (nil, deviceName, effectiveLast)
        }
        if pct > lowBatteryWarningThreshold {
            return (nil, deviceName, nil)
        }
        let target: LowBatteryLevel = pct <= lowBatteryCriticalThreshold ? .critical : .warning
        if effectiveLast == nil || target.rawValue < effectiveLast! {
            return (target, deviceName, target.rawValue)
        }
        return (nil, deviceName, effectiveLast)
    }

    static func isAirPodsName(_ name: String) -> Bool {
        name.lowercased().contains("airpods")
    }

    static func isLikelyHeadphoneDevice(
        name: String,
        isBluetooth: Bool,
        isWiredHeadphonePort: Bool
    ) -> Bool {
        let lower = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return false }
        if isBluetooth || isWiredHeadphonePort {
            return true
        }
        if builtInKeywords.contains(where: { lower.contains($0) }) {
            return false
        }
        return headphoneKeywords.contains(where: { lower.contains($0) })
    }

    static func shouldTriggerHeadphoneCard(previousDeviceName: String?, current: HeadphoneStatus?) -> Bool {
        guard let previousDeviceName, let current else { return false }
        return current.name != previousDeviceName
    }
}
