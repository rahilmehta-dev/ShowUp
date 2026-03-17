import Foundation
import BackgroundTasks

final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    static let refreshTaskID = "com.showup.app.refresh"
    static let processingTaskID = "com.showup.app.processing"

    var onRefresh: (() -> Void)?

    private init() {}

    func registerTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: BackgroundTaskManager.refreshTaskID, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: refreshTask)
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: BackgroundTaskManager.processingTaskID, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else { return }
            self.handleProcessing(task: processingTask)
        }
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: BackgroundTaskManager.refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        try? BGTaskScheduler.shared.submit(request)
    }

    func scheduleProcessingTask() {
        let request = BGProcessingTaskRequest(identifier: BackgroundTaskManager.processingTaskID)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleAppRefresh()
        DispatchQueue.main.async { self.onRefresh?() }
        task.setTaskCompleted(success: true)
    }

    private func handleProcessing(task: BGProcessingTask) {
        scheduleProcessingTask()
        // Perform streak calculations
        task.setTaskCompleted(success: true)
    }
}
