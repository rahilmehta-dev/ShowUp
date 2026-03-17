import SwiftUI
import SwiftData

@main
struct ShowUpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([ShowUpTask.self, LocationRecord.self, StreakRecord.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

// MARK: - AppDelegate
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BackgroundTaskManager.shared.registerTasks()
        BackgroundTaskManager.shared.scheduleAppRefresh()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        BackgroundTaskManager.shared.scheduleAppRefresh()
    }
}

// MARK: - RootView (injects environment objects)
struct RootView: View {
    @State private var locationManager = LocationManager()
    @State private var notificationManager = NotificationManager()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel: TaskViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                ContentView()
                    .environment(locationManager)
                    .environment(notificationManager)
                    .environment(vm)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = TaskViewModel(
                    locationManager: locationManager,
                    notificationManager: notificationManager,
                    modelContext: modelContext
                )
                viewModel = vm
                vm.loadTasks()
                BackgroundTaskManager.shared.onRefresh = { [weak vm] in vm?.resetDailyIfNeeded() }
                locationManager.requestAlwaysAuthorization()
                notificationManager.requestAuthorization()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel?.resetDailyIfNeeded()
            }
        }
    }
}
