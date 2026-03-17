import SwiftData
import Foundation
import SwiftUI

@Model
final class ShowUpTask {
    var id: UUID
    var name: String
    var locationName: String
    var latitude: Double
    var longitude: Double
    var radius: Double
    var requiredDuration: TimeInterval
    var colorHex: String
    var createdAt: Date
    var isEnabled: Bool
    var notificationsEnabled: Bool
    var streakCount: Int
    var lastCompletedDate: Date?

    // Schedule (Calendar weekday: 1=Sun, 2=Mon, ..., 7=Sat)
    var scheduledDays: [Int] = [1, 2, 3, 4, 5, 6, 7]

    // Daily tracking
    var accumulatedSeconds: Double
    var lastEnteredAt: Date?
    var isInsideZone: Bool
    var isCompletedToday: Bool
    var lastResetDate: Date?

    // Session history (reset each day)
    var sessionStarts: [Date] = []
    var sessionDurations: [Double] = []

    init(
        name: String,
        locationName: String,
        latitude: Double,
        longitude: Double,
        radius: Double = 150,
        requiredDuration: TimeInterval,
        colorHex: String,
        scheduledDays: [Int] = [1, 2, 3, 4, 5, 6, 7]
    ) {
        self.id = UUID()
        self.name = name
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.requiredDuration = requiredDuration
        self.colorHex = colorHex
        self.createdAt = Date()
        self.isEnabled = true
        self.notificationsEnabled = true
        self.streakCount = 0
        self.accumulatedSeconds = 0
        self.isInsideZone = false
        self.isCompletedToday = false
        self.scheduledDays = scheduledDays
        self.lastResetDate = Calendar.current.startOfDay(for: Date())
    }

    var isScheduledToday: Bool {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return scheduledDays.isEmpty || scheduledDays.contains(weekday)
    }

    var progress: Double {
        guard requiredDuration > 0 else { return 0 }
        let total = accumulatedSeconds + currentSessionSeconds
        return min(total / requiredDuration, 1.0)
    }

    var currentSessionSeconds: Double {
        guard isInsideZone, let entered = lastEnteredAt else { return 0 }
        return Date().timeIntervalSince(entered)
    }

    var totalAccumulatedSeconds: Double {
        accumulatedSeconds + currentSessionSeconds
    }

    var durationText: String {
        let minutes = Int(requiredDuration / 60)
        return "\(minutes) min"
    }

    var remainingSeconds: Double {
        max(0, requiredDuration - totalAccumulatedSeconds)
    }

    var cardColor: Color {
        Color(hex: colorHex) ?? Color(hex: "#AED6F1")!
    }

    var regionIdentifier: String {
        "showup_\(id.uuidString)"
    }

    var firstSessionStart: Date? { sessionStarts.first }

    var sessionBreakdownText: String {
        let rawPastTotal = sessionDurations.reduce(0, +)
        let rawCurrent = currentSessionSeconds
        let cappedCurrent = min(rawCurrent, max(0, requiredDuration - rawPastTotal))
        let hasOngoing = isInsideZone && cappedCurrent >= 1
        if sessionDurations.isEmpty && !hasOngoing { return "" }

        // Cap each stored session so the displayed total never exceeds requiredDuration
        var remaining = requiredDuration
        var cappedDurations: [Double] = []
        for d in sessionDurations {
            let capped = min(d, remaining)
            cappedDurations.append(capped)
            remaining = max(0, remaining - capped)
        }

        var parts = cappedDurations.map { formatDuration($0) }
        if hasOngoing { parts.append(formatDuration(cappedCurrent)) }

        if parts.count == 1 {
            return parts[0]
        } else {
            let sum = min(rawPastTotal, requiredDuration) + (hasOngoing ? cappedCurrent : 0)
            return parts.joined(separator: " + ") + " = " + formatDuration(sum)
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let s = Int(seconds)
        if s < 60 { return "\(s)s" }
        let m = s / 60
        let rem = s % 60
        return rem > 0 ? "\(m)m \(rem)s" : "\(m)m"
    }

    func resetForNewDay() {
        accumulatedSeconds = 0
        lastEnteredAt = nil
        isInsideZone = false
        isCompletedToday = false
        lastResetDate = Calendar.current.startOfDay(for: Date())
        sessionStarts = []
        sessionDurations = []
    }

    var needsDailyReset: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        if let last = lastResetDate {
            return last < today
        }
        // Existing tasks without lastResetDate — reset if any progress was made
        return accumulatedSeconds > 0 || isCompletedToday || !sessionStarts.isEmpty
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
