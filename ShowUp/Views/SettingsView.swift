import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(TaskViewModel.self) private var viewModel
    @Environment(LocationManager.self) private var locationManager
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(\.modelContext) private var modelContext

    @State private var showResetAlert = false
    @State private var selectedRadius: Double = 150

    @Query private var tasks: [ShowUpTask]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Permissions status
                        SettingsSection(title: "Permissions") {
                            PermissionRow(
                                icon: "location.fill",
                                iconColor: .blue,
                                title: "Location",
                                status: locationPermissionStatus
                            )
                            PermissionRow(
                                icon: "bell.fill",
                                iconColor: .orange,
                                title: "Notifications",
                                status: notificationManager.isAuthorized ? "Allowed" : "Not Allowed"
                            )
                        }

                        // Geofence settings
                        SettingsSection(title: "Geofence Radius") {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Detection radius for all tasks")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))

                                HStack(spacing: 12) {
                                    ForEach([100.0, 150.0, 200.0], id: \.self) { radius in
                                        Button {
                                            selectedRadius = radius
                                            viewModel.updateGeofenceRadius(radius)
                                        } label: {
                                            Text("\(Int(radius))m")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(selectedRadius == radius ? .black : .white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(selectedRadius == radius ? Color.white : Color.white.opacity(0.1))
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                }
                            }
                            .padding(16)
                        }

                        // Timer Behavior
                        SettingsSection(title: "Timer Behavior") {
                            SettingsToggleRow(
                                icon: "clock.badge.checkmark",
                                iconColor: .green,
                                title: "Grace Period",
                                subtitle: "Allow 5 min exit without pausing timer",
                                isOn: Binding(
                                    get: { viewModel.gracePeriodEnabled },
                                    set: { viewModel.updateGracePeriod(enabled: $0) }
                                )
                            )
                            Divider().background(Color.white.opacity(0.08))
                            SettingsToggleRow(
                                icon: "lock.rectangle.on.rectangle",
                                iconColor: .purple,
                                title: "Live Activity",
                                subtitle: "Show timer on Lock Screen",
                                isOn: Binding(
                                    get: { viewModel.liveActivitiesEnabled },
                                    set: { viewModel.setLiveActivitiesEnabled($0) }
                                )
                            )
                        }

                        // Per-task notifications
                        if !tasks.isEmpty {
                            SettingsSection(title: "Task Notifications") {
                                ForEach(tasks) { task in
                                    TaskNotificationRow(task: task, modelContext: modelContext)
                                }
                            }
                        }

                        // Danger zone
                        SettingsSection(title: "Data") {
                            Button {
                                showResetAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                        .foregroundColor(.red)
                                    Text("Reset All Streaks")
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                                .padding(16)
                            }
                        }

                        // App info
                        VStack(spacing: 6) {
                            Text("ShowUp")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white.opacity(0.3))
                            Text("Version 1.5")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.2))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 40)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Reset All Streaks", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) {
                    viewModel.resetAllStreaks()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset the streak count for all tasks to 0. This cannot be undone.")
            }
            .onAppear {
                selectedRadius = tasks.first?.radius ?? 150
            }
        }
    }

    private var locationPermissionStatus: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways: return "Always On"
        case .authorizedWhenInUse: return "When In Use"
        case .denied, .restricted: return "Denied"
        case .notDetermined: return "Not Set"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Settings Components

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .textCase(.uppercase)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let status: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.white)
            Spacer()
            Text(status)
                .font(.system(size: 14))
                .foregroundColor(status.contains("Allowed") || status.contains("Always") ? .green : .orange)
        }
        .padding(16)
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.green)
        }
        .padding(16)
    }
}

struct TaskNotificationRow: View {
    let task: ShowUpTask
    let modelContext: ModelContext

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(task.cardColor.opacity(0.25))
                    .frame(width: 36, height: 36)
                Image(systemName: task.notificationsEnabled ? "bell.fill" : "bell.slash.fill")
                    .font(.system(size: 15))
                    .foregroundColor(task.cardColor)
            }
            Text(task.name)
                .font(.system(size: 15))
                .foregroundColor(.white)
            Spacer()
            Toggle("", isOn: Binding(
                get: { task.notificationsEnabled },
                set: { newValue in
                    task.notificationsEnabled = newValue
                    try? modelContext.save()
                }
            ))
            .labelsHidden()
            .tint(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
