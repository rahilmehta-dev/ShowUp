import WatchConnectivity
import Foundation

final class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Call this whenever task state changes (enter/exit zone, tick, completion, reset).
    func sendTaskUpdate(_ tasks: [ShowUpTask]) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isPaired,
              WCSession.default.isWatchAppInstalled
        else { return }

        let payloads: [[String: Any]] = tasks.filter { $0.isScheduledToday }.map { task in
            [
                "id":               task.id.uuidString,
                "name":             task.name,
                "locationName":     task.locationName,
                "colorHex":         task.colorHex,
                "progress":         task.progress,
                "isInsideZone":     task.isInsideZone,
                "isCompletedToday": task.isCompletedToday,
                "streakCount":      task.streakCount,
                "requiredDuration": task.requiredDuration,
                "totalSeconds":     min(task.totalAccumulatedSeconds, task.requiredDuration)
            ] as [String: Any]
        }
        let context: [String: Any] = ["tasks": payloads, "ts": Date().timeIntervalSince1970]
        try? WCSession.default.updateApplicationContext(context)
    }

    // MARK: - WCSessionDelegate (required stubs)
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
}
