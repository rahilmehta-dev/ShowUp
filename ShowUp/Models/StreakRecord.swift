import SwiftData
import Foundation

@Model
final class StreakRecord {
    var id: UUID
    var taskId: UUID
    var taskName: String
    var completedDate: Date
    var streakCountAtCompletion: Int
    var durationSeconds: Double

    init(taskId: UUID, taskName: String, completedDate: Date, streakCount: Int, durationSeconds: Double) {
        self.id = UUID()
        self.taskId = taskId
        self.taskName = taskName
        self.completedDate = completedDate
        self.streakCountAtCompletion = streakCount
        self.durationSeconds = durationSeconds
    }
}
