import XCTest
@testable import ShowUp

final class ShowUpTests: XCTestCase {

    // MARK: - Helpers

    private func calendar(timeZone: TimeZone = .current) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }

    /// Returns a Date set to midnight of a given day-offset from a reference point.
    private func date(daysAgo: Int, from reference: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Calendar.current.startOfDay(for: reference))!
    }

    private func makeTask(
        requiredDuration: TimeInterval = 1800,
        scheduledDays: [Int] = [1, 2, 3, 4, 5, 6, 7]
    ) -> ShowUpTask {
        ShowUpTask(
            name: "Test",
            locationName: "Nowhere",
            latitude: 0, longitude: 0,
            requiredDuration: requiredDuration,
            colorHex: "#AED6F1",
            scheduledDays: scheduledDays
        )
    }

    // MARK: - Streak Calculation

    func test_streak_firstCompletion_givesOne() {
        let result = computeNewStreak(lastCompleted: nil, currentStreak: 0, today: Date())
        XCTAssertEqual(result, 1)
    }

    func test_streak_consecutiveDay_increments() {
        let yesterday = date(daysAgo: 1)
        let result = computeNewStreak(lastCompleted: yesterday, currentStreak: 5, today: Date())
        XCTAssertEqual(result, 6)
    }

    func test_streak_missedOneDay_resetsToOne() {
        let twoDaysAgo = date(daysAgo: 2)
        let result = computeNewStreak(lastCompleted: twoDaysAgo, currentStreak: 10, today: Date())
        XCTAssertEqual(result, 1)
    }

    func test_streak_missedManyDays_resetsToOne() {
        let longAgo = date(daysAgo: 30)
        let result = computeNewStreak(lastCompleted: longAgo, currentStreak: 20, today: Date())
        XCTAssertEqual(result, 1)
    }

    func test_streak_sameDay_unchanged() {
        let today = Calendar.current.startOfDay(for: Date())
        let result = computeNewStreak(lastCompleted: today, currentStreak: 7, today: Date())
        XCTAssertEqual(result, 7)
    }

    // MARK: - Scheduled Days Filtering

    func test_scheduledDays_emptyMeansEveryDay() {
        let task = makeTask(scheduledDays: [])
        // isScheduled on any day should return true
        let monday = nextWeekday(2) // Calendar weekday 2 = Monday
        XCTAssertTrue(task.isScheduled(on: monday))
    }

    func test_scheduledDays_containsWeekday_isScheduled() {
        // Only Monday (weekday 2)
        let task = makeTask(scheduledDays: [2])
        let monday = nextWeekday(2)
        XCTAssertTrue(task.isScheduled(on: monday))
    }

    func test_scheduledDays_excludesWeekday_notScheduled() {
        // Only Mon/Wed/Fri (2, 4, 6)
        let task = makeTask(scheduledDays: [2, 4, 6])
        let tuesday = nextWeekday(3) // weekday 3 = Tuesday
        XCTAssertFalse(task.isScheduled(on: tuesday))
    }

    func test_scheduledDays_allDays_alwaysScheduled() {
        let task = makeTask(scheduledDays: [1, 2, 3, 4, 5, 6, 7])
        for weekday in 1...7 {
            XCTAssertTrue(task.isScheduled(on: nextWeekday(weekday)), "Should be scheduled on weekday \(weekday)")
        }
    }

    // MARK: - Duration Thresholds

    func test_progress_zeroDuration_isZero() {
        let task = makeTask(requiredDuration: 1800)
        // no time accumulated, no active session
        XCTAssertEqual(task.progress, 0.0)
    }

    func test_progress_exactlyComplete_isCappedAtOne() {
        let task = makeTask(requiredDuration: 1800)
        task.accumulatedSeconds = 1800 // exactly 30 min
        XCTAssertEqual(task.progress, 1.0)
    }

    func test_progress_justBelowThreshold_notComplete() {
        let task = makeTask(requiredDuration: 1800)
        task.accumulatedSeconds = 1799 // 29:59
        XCTAssertLessThan(task.progress, 1.0)
        XCTAssertFalse(task.isCompletedToday)
    }

    func test_progress_overAccumulated_cappedAtOne() {
        let task = makeTask(requiredDuration: 1800)
        task.accumulatedSeconds = 9999 // way over
        XCTAssertEqual(task.progress, 1.0)
    }

    func test_remainingSeconds_decreasesWithAccumulation() {
        let task = makeTask(requiredDuration: 1800)
        task.accumulatedSeconds = 900 // halfway
        XCTAssertEqual(task.remainingSeconds, 900)
    }

    func test_remainingSeconds_neverNegative() {
        let task = makeTask(requiredDuration: 1800)
        task.accumulatedSeconds = 9999
        XCTAssertGreaterThanOrEqual(task.remainingSeconds, 0)
    }

    // MARK: - Grace Period / Daily Reset

    func test_needsDailyReset_freshTask_isFalse() {
        let task = makeTask()
        // lastResetDate is set to today in init
        XCTAssertFalse(task.needsDailyReset)
    }

    func test_needsDailyReset_staleResetDate_isTrue() {
        let task = makeTask()
        task.lastResetDate = date(daysAgo: 1)
        XCTAssertTrue(task.needsDailyReset)
    }

    func test_resetForNewDay_clearsProgress() {
        let task = makeTask()
        task.accumulatedSeconds = 1200
        task.isCompletedToday = true
        task.isInsideZone = true
        task.sessionStarts = [Date()]
        task.sessionDurations = [600]

        task.resetForNewDay()

        XCTAssertEqual(task.accumulatedSeconds, 0)
        XCTAssertFalse(task.isCompletedToday)
        XCTAssertFalse(task.isInsideZone)
        XCTAssertTrue(task.sessionStarts.isEmpty)
        XCTAssertTrue(task.sessionDurations.isEmpty)
        XCTAssertNil(task.lastEnteredAt)
        XCTAssertNil(task.completedAt)
    }

    func test_resetForNewDay_preservesStreak() {
        let task = makeTask()
        task.streakCount = 7
        task.resetForNewDay()
        XCTAssertEqual(task.streakCount, 7)
    }

    func test_resetForNewDay_setsResetDateToToday() {
        let task = makeTask()
        task.lastResetDate = date(daysAgo: 2)
        task.resetForNewDay()
        let today = Calendar.current.startOfDay(for: Date())
        XCTAssertEqual(task.lastResetDate, today)
    }

    // MARK: - Session Accumulation

    func test_totalAccumulatedSeconds_includesActiveSession() {
        let task = makeTask()
        task.accumulatedSeconds = 300
        task.isInsideZone = true
        task.lastEnteredAt = Date().addingTimeInterval(-60) // 1 min ago
        // totalAccumulatedSeconds should be ≥ 360
        XCTAssertGreaterThanOrEqual(task.totalAccumulatedSeconds, 360)
    }

    func test_totalAccumulatedSeconds_whenNotInZone_equalsAccumulated() {
        let task = makeTask()
        task.accumulatedSeconds = 500
        task.isInsideZone = false
        XCTAssertEqual(task.totalAccumulatedSeconds, 500)
    }

    // MARK: - Helpers

    /// Returns the next (or current) date that falls on a given Calendar weekday (1=Sun…7=Sat).
    private func nextWeekday(_ weekday: Int) -> Date {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.weekday = weekday
        return cal.nextDate(after: Date().addingTimeInterval(-86400), matching: comps, matchingPolicy: .nextTime)!
    }
}
