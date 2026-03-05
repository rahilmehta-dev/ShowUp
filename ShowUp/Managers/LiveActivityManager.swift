import ActivityKit
import Foundation

final class LiveActivityManager {
    private var activities: [String: Activity<ShowUpActivityAttributes>] = [:]
    // Throttle to every 5s — ProgressView(timerInterval:) handles visual animation between updates
    private var lastUpdateTime: [String: Date] = [:]
    private let updateInterval: TimeInterval = 5

    // MARK: - Start

    func startActivity(for task: ShowUpTask) {
        let authInfo = ActivityAuthorizationInfo()
        guard authInfo.areActivitiesEnabled else {
            print("[LiveActivity] ❌ Activities not enabled. Check NSSupportsLiveActivities in Info.plist and device Settings → ShowUp → Live Activities.")
            return
        }
        // End any existing activity for this task first
        endActivity(for: task, completed: false)

        let attributes = ShowUpActivityAttributes(
            taskName: task.name,
            locationName: task.locationName,
            cardColorHex: task.colorHex
        )
        let state = makeState(for: task)
        do {
            let activity = try Activity<ShowUpActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: state, staleDate: Date().addingTimeInterval(60)),
                pushType: nil
            )
            activities[task.id.uuidString] = activity
            print("[LiveActivity] ✅ Started '\(task.name)' id=\(activity.id)")
        } catch {
            print("[LiveActivity] ❌ Failed to start '\(task.name)': \(error)")
        }
    }

    // MARK: - Update (called every second from TaskViewModel.tick)

    func updateActivity(for task: ShowUpTask) {
        guard let activity = activities[task.id.uuidString] else { return }
        let key = task.id.uuidString
        let now = Date()
        if let last = lastUpdateTime[key], now.timeIntervalSince(last) < updateInterval { return }
        lastUpdateTime[key] = now
        let state = makeState(for: task)
        Task {
            await activity.update(
                .init(state: state, staleDate: Date().addingTimeInterval(60))
            )
        }
    }

    // MARK: - End

    func endActivity(for task: ShowUpTask, completed: Bool) {
        guard let activity = activities[task.id.uuidString] else { return }
        var state = makeState(for: task)
        state.isCompleted = completed
        state.isInsideZone = false
        state.liveProgressStart = nil
        state.liveProgressEnd = nil
        Task {
            // Keep on screen for 8 seconds after completion, then dismiss
            let policy: ActivityUIDismissalPolicy = completed
                ? .after(Date().addingTimeInterval(8))
                : .immediate
            await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: policy)
            activities.removeValue(forKey: task.id.uuidString)
        }
    }

    func endAll() {
        for (_, activity) in activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        activities.removeAll()
    }

    // MARK: - State builder

    private func makeState(for task: ShowUpTask) -> ShowUpActivityAttributes.ContentState {
        let elapsed = task.totalAccumulatedSeconds
        let required = task.requiredDuration
        let remaining = max(0, required - elapsed)
        let fraction = min(elapsed / required, 1.0)

        var liveStart: Date?
        var liveEnd: Date?
        if task.isInsideZone && !task.isCompletedToday && remaining > 0 {
            liveStart = Date().addingTimeInterval(-elapsed)
            liveEnd = Date().addingTimeInterval(remaining)
        }

        return ShowUpActivityAttributes.ContentState(
            isInsideZone: task.isInsideZone,
            isCompleted: task.isCompletedToday,
            progressFraction: fraction,
            elapsedSeconds: elapsed,
            requiredSeconds: required,
            streakCount: task.streakCount,
            liveProgressStart: liveStart,
            liveProgressEnd: liveEnd
        )
    }
}
