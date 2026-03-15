import ActivityKit
import Foundation

final class LiveActivityManager {
    private var activities: [String: Activity<ShowUpActivityAttributes>] = [:]
    // Throttle updates — ProgressView(timerInterval:) animates between them
    private var lastUpdateTime: [String: Date] = [:]
    private let updateInterval: TimeInterval = 5

    // MARK: - Restore on launch

    /// Call on app launch to re-adopt any Live Activities the system kept alive
    /// after the app was killed. Without this, the activities dict is empty and
    /// we can't update or end them.
    func restoreActivities(matching tasks: [ShowUpTask]) {
        for activity in Activity<ShowUpActivityAttributes>.activities {
            guard activity.activityState == .active else { continue }
            if let task = tasks.first(where: { $0.name == activity.attributes.taskName }),
               !task.isCompletedToday {
                activities[task.id.uuidString] = activity
                print("[LiveActivity] ♻️ Restored '\(task.name)' id=\(activity.id)")
            } else {
                // Orphaned or completed — kill it immediately
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
                print("[LiveActivity] 🧹 Ended orphaned activity id=\(activity.id)")
            }
        }
    }

    // MARK: - Start

    func startActivity(for task: ShowUpTask) {
        let authInfo = ActivityAuthorizationInfo()
        guard authInfo.areActivitiesEnabled else {
            print("[LiveActivity] ❌ Not enabled — go to Settings → ShowUp → Live Activities and enable them.")
            return
        }

        // End any stale activity for this task
        endActivity(for: task, completed: false)

        let attributes = ShowUpActivityAttributes(
            taskName: task.name,
            locationName: task.locationName,
            cardColorHex: task.colorHex
        )
        do {
            let activity = try Activity<ShowUpActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: makeState(for: task), staleDate: Date().addingTimeInterval(60)),
                pushType: nil
            )
            activities[task.id.uuidString] = activity
            lastUpdateTime.removeValue(forKey: task.id.uuidString)
            print("[LiveActivity] ✅ Started '\(task.name)' id=\(activity.id)")
        } catch {
            print("[LiveActivity] ❌ Failed to start '\(task.name)': \(error)")
        }
    }

    // MARK: - Update

    func updateActivity(for task: ShowUpTask) {
        guard let activity = activities[task.id.uuidString] else { return }
        guard activity.activityState == .active else {
            activities.removeValue(forKey: task.id.uuidString)
            return
        }
        let key = task.id.uuidString
        let now = Date()
        if let last = lastUpdateTime[key], now.timeIntervalSince(last) < updateInterval { return }
        lastUpdateTime[key] = now
        let state = makeState(for: task)
        Task {
            await activity.update(.init(state: state, staleDate: Date().addingTimeInterval(60)))
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
        let key = task.id.uuidString
        Task {
            let policy: ActivityUIDismissalPolicy = completed
                ? .after(Date().addingTimeInterval(8))
                : .immediate
            await activity.end(.init(state: state, staleDate: nil), dismissalPolicy: policy)
            activities.removeValue(forKey: key)
            lastUpdateTime.removeValue(forKey: key)
        }
    }

    func endAll() {
        activities.removeAll()
        lastUpdateTime.removeAll()
        // Use the system list — covers activities started in previous sessions
        // that aren't in the local dict (the common cause of "stuck" activities)
        for activity in Activity<ShowUpActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        print("[LiveActivity] 🛑 Ended all activities")
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
