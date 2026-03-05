import SwiftData
import Foundation

@Model
final class LocationRecord {
    var id: UUID
    var taskId: UUID
    var taskName: String
    var locationName: String
    var enteredAt: Date
    var exitedAt: Date?
    var durationSeconds: Double
    var wasCompleted: Bool

    init(taskId: UUID, taskName: String, locationName: String, enteredAt: Date) {
        self.id = UUID()
        self.taskId = taskId
        self.taskName = taskName
        self.locationName = locationName
        self.enteredAt = enteredAt
        self.durationSeconds = 0
        self.wasCompleted = false
    }

    var formattedDuration: String {
        let minutes = Int(durationSeconds / 60)
        let seconds = Int(durationSeconds) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}
