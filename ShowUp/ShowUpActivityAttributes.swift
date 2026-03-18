import ActivityKit
import Foundation

struct ShowUpActivityAttributes: ActivityAttributes {
    // MARK: - Dynamic state (updates every second while in zone)
    public struct ContentState: Codable, Hashable {
        var isInsideZone: Bool
        var isCompleted: Bool
        var progressFraction: Double    // 0.0 – 1.0, for static fallback bar
        var elapsedSeconds: Double      // display text: "8:30"
        var requiredSeconds: Double     // display text: "/ 30m"
        var streakCount: Int
        // Live animation anchors — nil when paused/completed
        // ProgressView(timerInterval: liveStart...liveEnd) animates automatically
        var liveProgressStart: Date?    // = Date() - elapsedSeconds
        var liveProgressEnd: Date?      // = Date() + remainingSeconds
    }

    // MARK: - Static per-task info
    var taskName: String
    var locationName: String
    var cardColorHex: String
}
