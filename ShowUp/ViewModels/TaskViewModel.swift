import Foundation
import SwiftData
import SwiftUI
import Combine

@Observable
final class TaskViewModel {
    private var locationManager: LocationManager
    private var notificationManager: NotificationManager
    private var modelContext: ModelContext
    private let liveActivity = LiveActivityManager()

    var tasks: [ShowUpTask] = []
    var activeTaskIDs: Set<UUID> = []
    private var refreshTimer: Timer?
    private var midnightTimer: Timer?

    // Settings
    var geofenceRadius: Double = 150
    var gracePeriodEnabled: Bool = true
    var liveActivitiesEnabled: Bool = (UserDefaults.standard.object(forKey: "liveActivitiesEnabled") as? Bool) ?? true
    func setLiveActivitiesEnabled(_ enabled: Bool) {
        liveActivitiesEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "liveActivitiesEnabled")
        if !enabled {
            liveActivity.endAll()
        } else {
            for task in tasks where task.isInsideZone && !task.isCompletedToday {
                liveActivity.startActivity(for: task)
            }
        }
    }

    init(locationManager: LocationManager, notificationManager: NotificationManager, modelContext: ModelContext) {
        self.locationManager = locationManager
        self.notificationManager = notificationManager
        self.modelContext = modelContext
        setupGeofenceCallbacks()
    }

    // MARK: - Setup

    private func setupGeofenceCallbacks() {
        locationManager.onEnterRegion = { [weak self] regionID in
            self?.handleEnterRegion(regionID)
        }
        locationManager.onExitRegion = { [weak self] regionID in
            self?.handleExitRegion(regionID)
        }
    }

    private func startRefreshTimer() {
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Task CRUD

    func loadTasks() {
        let descriptor = FetchDescriptor<ShowUpTask>(sortBy: [SortDescriptor(\.createdAt)])
        tasks = (try? modelContext.fetch(descriptor)) ?? []
        resetDailyIfNeeded()
        scheduleMidnightTimer()
        restartMonitoring()
        liveActivity.restoreActivities(matching: tasks)
        locationManager.requestOneTimeFix()
        print("[TaskVM] Loaded \(tasks.count) tasks | liveActivitiesEnabled=\(liveActivitiesEnabled)")
    }

    func addTask(_ task: ShowUpTask) {
        modelContext.insert(task)
        try? modelContext.save()
        tasks.append(task)
        locationManager.startMonitoringTask(task)
    }

    func deleteTask(_ task: ShowUpTask) {
        locationManager.stopMonitoringTask(task)
        modelContext.delete(task)
        try? modelContext.save()
        tasks.removeAll { $0.id == task.id }
    }

    func updateTask(_ task: ShowUpTask) {
        locationManager.stopMonitoringTask(task)
        try? modelContext.save()
        locationManager.startMonitoringTask(task)
    }

    // MARK: - Daily Reset

    private func scheduleMidnightTimer() {
        midnightTimer?.invalidate()
        let calendar = Calendar.current
        guard let nextMidnight = calendar.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else { return }
        let interval = nextMidnight.timeIntervalSince(Date())
        midnightTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.resetDailyIfNeeded()
            self?.scheduleMidnightTimer()
        }
    }

    func resetDailyIfNeeded() {
        for task in tasks where task.needsDailyReset {
            task.resetForNewDay()
        }
        try? modelContext.save()
    }

    // MARK: - Monitoring

    private func restartMonitoring() {
        locationManager.stopMonitoringAll()
        for task in tasks {
            // Clear zone state for tasks that shouldn't be active today
            if task.isInsideZone && (!task.isEnabled || !task.isScheduledToday || task.isCompletedToday) {
                if let entered = task.lastEnteredAt {
                    task.accumulatedSeconds += Date().timeIntervalSince(entered)
                }
                task.isInsideZone = false
                task.lastEnteredAt = nil
            }
            if task.isEnabled && !task.isCompletedToday && task.isScheduledToday {
                locationManager.startMonitoringTask(task)
            }
        }
        try? modelContext.save()
        locationManager.requestStateForAllRegions()
    }

    // MARK: - Geofence Handlers

    private func handleEnterRegion(_ regionID: String) {
        guard let task = tasks.first(where: { $0.regionIdentifier == regionID }) else { return }
        guard !task.isCompletedToday else { return }
        guard task.isScheduledToday else { return }

        let now = Date()
        if !task.isInsideZone {
            // Fresh entry: start new session
            task.sessionStarts.append(now)
            task.lastEnteredAt = now
        }
        // If already isInsideZone (geofence re-fire on relaunch), keep the original
        // lastEnteredAt so accumulated time isn't lost
        task.isInsideZone = true
        activeTaskIDs.insert(task.id)
        try? modelContext.save()

        startRefreshTimer() // wake the timer only when someone enters a zone
        if liveActivitiesEnabled { liveActivity.startActivity(for: task) }

        if task.notificationsEnabled {
            notificationManager.sendEnterZoneNotification(taskName: task.name, locationName: task.locationName)
        }
    }

    private func handleExitRegion(_ regionID: String) {
        guard let task = tasks.first(where: { $0.regionIdentifier == regionID }) else { return }
        guard task.isInsideZone else { return }

        // Accumulate time
        if let entered = task.lastEnteredAt {
            let duration = Date().timeIntervalSince(entered)
            task.accumulatedSeconds += duration
            task.sessionDurations.append(duration)
        }
        task.isInsideZone = false
        task.lastEnteredAt = nil
        activeTaskIDs.remove(task.id)
        try? modelContext.save()

        if activeTaskIDs.isEmpty { stopRefreshTimer() } // no active zones → kill the timer
        liveActivity.updateActivity(for: task)

        if task.notificationsEnabled {
            notificationManager.sendExitZoneNotification(taskName: task.name)
        }
    }

    // MARK: - Milestone persistence (survives app kill)

    private func milestoneKey(_ task: ShowUpTask, percent: String) -> String {
        let day = Int(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970)
        return "milestone_\(task.id.uuidString)_\(percent)_\(day)"
    }

    private func hasFiredMilestone(_ task: ShowUpTask, percent: String) -> Bool {
        UserDefaults.standard.bool(forKey: milestoneKey(task, percent: percent))
    }

    private func markMilestoneFired(_ task: ShowUpTask, percent: String) {
        UserDefaults.standard.set(true, forKey: milestoneKey(task, percent: percent))
    }

    // MARK: - Tick (1 second timer)

    private func tick() {
        var needsSave = false

        for task in tasks {
            guard !task.isCompletedToday else { continue }

            let progress = task.progress

            // Update Live Activity for any in-zone task (drives the elapsed text)
            if task.isInsideZone {
                liveActivity.updateActivity(for: task)
            }

            // Check milestone notifications (UserDefaults-keyed so they survive app kills)
            if progress >= 0.5 && !hasFiredMilestone(task, percent: "50") {
                markMilestoneFired(task, percent: "50")
                if task.notificationsEnabled {
                    notificationManager.sendHalfwayNotification(taskName: task.name)
                }
            }

            if progress >= 0.8 && !hasFiredMilestone(task, percent: "80") {
                markMilestoneFired(task, percent: "80")
                let remainingMins = Int(task.remainingSeconds / 60) + 1
                if task.notificationsEnabled {
                    notificationManager.scheduleProgressNotification(
                        taskName: task.name,
                        remainingMinutes: remainingMins,
                        percentKey: "80"
                    )
                }
            }

            // Check completion
            if progress >= 1.0 {
                completeTask(task)
                needsSave = true
            }
        }

        if needsSave {
            try? modelContext.save()
        }
    }

    // MARK: - Task Completion

    private func completeTask(_ task: ShowUpTask) {
        guard !task.isCompletedToday else { return }

        // Finalize accumulated time, capped at requiredDuration
        if let entered = task.lastEnteredAt {
            let duration = Date().timeIntervalSince(entered)
            task.sessionDurations.append(duration)
            task.accumulatedSeconds = min(task.accumulatedSeconds + duration, task.requiredDuration)
        }
        task.lastEnteredAt = nil
        task.isInsideZone = false
        task.isCompletedToday = true
        task.completedAt = Date()
        activeTaskIDs.remove(task.id)
        if activeTaskIDs.isEmpty { stopRefreshTimer() }

        // Update streak
        updateStreak(for: task)

        // Stop monitoring today
        locationManager.stopMonitoringTask(task)

        // End Live Activity with a brief "Done" celebration
        liveActivity.endActivity(for: task, completed: true)

        // Record history
        let record = StreakRecord(
            taskId: task.id,
            taskName: task.name,
            completedDate: Date(),
            streakCount: task.streakCount,
            durationSeconds: task.accumulatedSeconds
        )
        modelContext.insert(record)

        // Send notification
        if task.notificationsEnabled {
            notificationManager.sendCompletionNotification(taskName: task.name, streak: task.streakCount)
        }

        try? modelContext.save()
    }

    // MARK: - Streak Logic

    private func updateStreak(for task: ShowUpTask) {
        task.streakCount = computeNewStreak(
            lastCompleted: task.lastCompletedDate,
            currentStreak: task.streakCount
        )
        task.lastCompletedDate = Date()
    }

    // MARK: - Settings

    func updateGeofenceRadius(_ radius: Double) {
        geofenceRadius = radius
        locationManager.stopMonitoringAll()
        for task in tasks where task.isEnabled && !task.isCompletedToday {
            task.radius = radius
            locationManager.startMonitoringTask(task)
        }
        try? modelContext.save()
    }

    func updateGracePeriod(enabled: Bool) {
        gracePeriodEnabled = enabled
        locationManager.gracePeriodEnabled = enabled
        if !enabled {
            locationManager.cancelAllGracePeriodTimers()
        }
    }

    func resetAllStreaks() {
        for task in tasks {
            task.streakCount = 0
            task.lastCompletedDate = nil
        }
        try? modelContext.save()
    }

    // MARK: - Helpers

    func recentStreakDays(for task: ShowUpTask, modelContext: ModelContext) -> [Bool] {
        let taskId = task.id
        let descriptor = FetchDescriptor<StreakRecord>(
            predicate: #Predicate { $0.taskId == taskId },
            sortBy: [SortDescriptor(\.completedDate, order: .reverse)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = (0..<7).map { offset -> Bool in
            let targetDay = calendar.date(byAdding: .day, value: -(6 - offset), to: today)!
            return records.contains { calendar.isDate($0.completedDate, inSameDayAs: targetDay) }
        }
        return days
    }

    // Pastel colors palette
    static let pastelColors = [
        "#AED6F1", "#FFDAB9", "#B2F0C5", "#D7BDE2", "#FFF3A3",
        "#FFFFFF", "#C8C8C8", "#FFB3B3", "#FFB6C1", "#FFAB76", "#A8E6E6"
    ]

    static func nextPastelColor(for index: Int) -> String {
        pastelColors[index % pastelColors.count]
    }
}
