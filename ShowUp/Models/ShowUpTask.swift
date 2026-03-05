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

    // Daily tracking
    var accumulatedSeconds: Double
    var lastEnteredAt: Date?
    var isInsideZone: Bool
    var isCompletedToday: Bool
    var lastResetDate: Date?

    init(
        name: String,
        locationName: String,
        latitude: Double,
        longitude: Double,
        radius: Double = 150,
        requiredDuration: TimeInterval,
        colorHex: String
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

    func resetForNewDay() {
        accumulatedSeconds = 0
        lastEnteredAt = nil
        isInsideZone = false
        isCompletedToday = false
        lastResetDate = Calendar.current.startOfDay(for: Date())
    }

    var needsDailyReset: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        if let last = lastResetDate {
            return last < today
        }
        // If lastCompletedDate exists and is not today, we need a reset
        if let completed = lastCompletedDate {
            return !Calendar.current.isDateInToday(completed) && isCompletedToday
        }
        return false
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
