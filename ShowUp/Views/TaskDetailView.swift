import SwiftUI
import MapKit
import SwiftData

struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TaskViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext

    let task: ShowUpTask

    @State private var showDeleteAlert = false
    @State private var showEditSheet = false
    @State private var mapPosition: MapCameraPosition

    init(task: ShowUpTask) {
        self.task = task
        _mapPosition = State(initialValue: .region(
            MKCoordinateRegion(
                center: task.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            )
        ))
    }

    private var streakDays: [Bool] {
        viewModel.recentStreakDays(for: task, modelContext: modelContext)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Map
                    ZStack {
                        Map(position: $mapPosition) {
                            Annotation(task.locationName, coordinate: task.coordinate) {
                                ZStack {
                                    Circle()
                                        .fill(task.cardColor.opacity(0.25))
                                        .frame(width: geofenceCircleSize, height: geofenceCircleSize)
                                    Circle()
                                        .stroke(task.cardColor.opacity(0.6), lineWidth: 2)
                                        .frame(width: geofenceCircleSize, height: geofenceCircleSize)
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(task.cardColor)
                                        .shadow(radius: 4)
                                }
                            }
                        }
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 0))

                        // Gradient overlay at bottom
                        VStack {
                            Spacer()
                            LinearGradient(
                                colors: [.black.opacity(0), .black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 60)
                        }
                    }

                    VStack(alignment: .leading, spacing: 24) {
                        // Title and location
                        VStack(alignment: .leading, spacing: 6) {
                            Text(task.name)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.white.opacity(0.5))
                                    .font(.system(size: 14))
                                Text(task.locationName)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("• \(Int(task.radius))m radius")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }

                        // Status badge — TimelineView keeps status current
                        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                            let currentStatus: TaskStatus = {
                                if task.isCompletedToday { return .done }
                                if task.isInsideZone { return .inProgress }
                                return .waiting
                            }()
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(currentStatus.color)
                                    .frame(width: 10, height: 10)
                                    .overlay(
                                        currentStatus == .inProgress ?
                                        Circle().stroke(currentStatus.color, lineWidth: 2)
                                            .scaleEffect(1.6)
                                            .opacity(0.5) : nil
                                    )
                                Text(currentStatus.label)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(currentStatus.color)

                                Spacer()

                                Text("⚡ \(task.streakCount) day streak")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .padding(14)
                            .background(currentStatus.color.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Progress — TimelineView drives live 1-second updates
                        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Today's Progress")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                    Text("\(formatTime(min(task.totalAccumulatedSeconds, task.requiredDuration))) / \(task.durationText)")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                }

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.white.opacity(0.1))
                                            .frame(height: 12)
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(task.isCompletedToday ? Color.green : task.cardColor)
                                            .frame(width: geo.size.width * task.progress, height: 12)
                                            .animation(.easeInOut(duration: 0.5), value: task.progress)
                                    }
                                }
                                .frame(height: 12)
                            }
                        }

                        // Last 7 days
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Last 7 Days")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))

                            HStack(spacing: 8) {
                                ForEach(Array(streakDays.enumerated()), id: \.offset) { index, completed in
                                    VStack(spacing: 4) {
                                        Circle()
                                            .fill(completed ? Color.green : Color.white.opacity(0.15))
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                completed ?
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.white) : nil
                                            )
                                        Text(dayLabel(daysAgo: 6 - index))
                                            .font(.system(size: 10))
                                            .foregroundColor(.white.opacity(0.4))
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Task details
                        HStack(spacing: 16) {
                            DetailChip(icon: "timer", label: "Duration", value: task.durationText)
                            DetailChip(icon: "circle.dashed", label: "Radius", value: "\(Int(task.radius))m")
                            DetailChip(icon: "calendar", label: "Created", value: formatDate(task.createdAt))
                        }

                        // Schedule display
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Schedule")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)

                            let dayOrder = [2, 3, 4, 5, 6, 7, 1]
                            let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
                            HStack(spacing: 0) {
                                ForEach(Array(dayOrder.enumerated()), id: \.offset) { index, weekday in
                                    let isActive = task.scheduledDays.contains(weekday)
                                    VStack(spacing: 4) {
                                        Text(dayLabels[index])
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(isActive ? .white : .white.opacity(0.25))
                                        Circle()
                                            .fill(isActive ? task.cardColor : Color.clear)
                                            .overlay(
                                                Circle().stroke(Color.white.opacity(isActive ? 0 : 0.2), lineWidth: 1.5)
                                            )
                                            .frame(width: 26, height: 26)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        // Action buttons
                        HStack(spacing: 12) {
                            Button {
                                showEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.white.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            Button {
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.red.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .sheet(isPresented: $showEditSheet) {
            AddTaskView(taskToEdit: task)
        }
        .alert("Delete Task", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                viewModel.deleteTask(task)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(task.name)\"? This cannot be undone.")
        }
    }

    // Approximate visual size for the geofence circle on the map
    private var geofenceCircleSize: CGFloat {
        CGFloat(task.radius / 5)
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    private func dayLabel(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(2))
    }
}

// MARK: - Supporting Types
enum TaskStatus {
    case waiting, inProgress, done

    var label: String {
        switch self {
        case .waiting: return "Waiting"
        case .inProgress: return "In Progress"
        case .done: return "Done ✅"
        }
    }

    var color: Color {
        switch self {
        case .waiting: return .white.opacity(0.5)
        case .inProgress: return .orange
        case .done: return .green
        }
    }
}

struct DetailChip: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
