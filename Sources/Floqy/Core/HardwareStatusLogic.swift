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

/// Pure edge-detection and classification rules for macOS battery and headphone hardware alerts.
enum HardwareStatusLogic {
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
