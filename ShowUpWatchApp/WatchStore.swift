import Foundation
import WatchConnectivity

final class WatchStore: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchStore()
    @Published var tasks: [WatchTask] = []

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // Called when iPhone sends updateApplicationContext
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { self.updateTasks(from: applicationContext) }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Load any previously received context immediately on launch
        let ctx = WCSession.default.receivedApplicationContext
        if !ctx.isEmpty {
            DispatchQueue.main.async { self.updateTasks(from: ctx) }
        }
    }

    private func updateTasks(from context: [String: Any]) {
        guard let payloads = context["tasks"] as? [[String: Any]] else { return }
        tasks = payloads.compactMap { WatchTask(dict: $0) }
    }
}

struct WatchTask: Identifiable {
    let id: UUID
    let name: String
    let locationName: String
    let colorHex: String
    let progress: Double          // 0.0–1.0
    let isInsideZone: Bool
    let isCompletedToday: Bool
    let streakCount: Int
    let requiredDuration: Double  // seconds
    let totalSeconds: Double      // capped at requiredDuration

    init?(dict: [String: Any]) {
        guard let idStr = dict["id"] as? String,
              let id = UUID(uuidString: idStr),
              let name = dict["name"] as? String,
              let locationName = dict["locationName"] as? String
        else { return nil }
        self.id = id
        self.name = name
        self.locationName = locationName
        colorHex        = dict["colorHex"]         as? String ?? "#AED6F1"
        progress        = dict["progress"]          as? Double ?? 0
        isInsideZone    = dict["isInsideZone"]      as? Bool   ?? false
        isCompletedToday = dict["isCompletedToday"] as? Bool   ?? false
        streakCount     = dict["streakCount"]       as? Int    ?? 0
        requiredDuration = dict["requiredDuration"] as? Double ?? 3600
        totalSeconds    = dict["totalSeconds"]      as? Double ?? 0
    }

    var progressText: String {
        let m = Int(totalSeconds) / 60
        let s = Int(totalSeconds) % 60
        let goal = Int(requiredDuration) / 60
        return String(format: "%d:%02d / %d min", m, s, goal)
    }
}
