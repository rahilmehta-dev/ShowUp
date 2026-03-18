import Foundation

/// Pure function — computes the new streak count after a task completion.
/// - dayDiff == 1  → consecutive day  → increment
/// - dayDiff  > 1  → gap              → reset to 1
/// - dayDiff == 0  → same day         → unchanged (shouldn't happen in normal flow)
/// - lastCompleted == nil             → first ever completion → 1
func computeNewStreak(
    lastCompleted: Date?,
    currentStreak: Int,
    today: Date = Date(),
    calendar: Calendar = .current
) -> Int {
    guard let lastCompleted else { return 1 }
    let lastDay   = calendar.startOfDay(for: lastCompleted)
    let todayStart = calendar.startOfDay(for: today)
    let dayDiff = calendar.dateComponents([.day], from: lastDay, to: todayStart).day ?? 0
    switch dayDiff {
    case 1:      return currentStreak + 1
    case 2...:   return 1
    default:     return currentStreak
    }
}
