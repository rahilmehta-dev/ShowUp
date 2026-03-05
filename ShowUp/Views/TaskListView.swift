import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(TaskViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showAddTask = false
    @State private var selectedDate = Date()

    private let calendar = Calendar.current

    private var todaysTasks: [ShowUpTask] {
        viewModel.tasks.filter { $0.isScheduledToday }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Tasks")
                            .font(.system(size: 34, weight: .bold, design: .default))
                            .foregroundColor(.white)
                        Spacer()
                        Button {
                            showAddTask = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    // Week strip
                    WeekStripView(selectedDate: $selectedDate)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    // Task list
                    if todaysTasks.isEmpty {
                        EmptyTasksView()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(todaysTasks, id: \.id) { task in
                                    NavigationLink(destination: TaskDetailView(task: task)) {
                                        TaskCardView(task: task)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddTask) {
                AddTaskView(onSave: { task in
                    viewModel.addTask(task)
                })
            }
        }
    }
}

// MARK: - Week Strip
struct WeekStripView: View {
    @Binding var selectedDate: Date
    private let calendar = Calendar.current
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    private var weekDates: [Date] {
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        // Monday-based: weekday 1=Sun, 2=Mon...7=Sat
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                let isToday = calendar.isDateInToday(date)
                let dayNumber = calendar.component(.day, from: date)
                let dayLetter = weekdays[index]

                VStack(spacing: 4) {
                    Text(dayLetter)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isToday ? .white : Color.white.opacity(0.4))

                    ZStack {
                        if isToday {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 32, height: 32)
                        }
                        Text("\(dayNumber)")
                            .font(.system(size: 15, weight: isToday ? .bold : .regular))
                            .foregroundColor(isToday ? .black : Color.white.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Task Card
struct TaskCardView: View {
    let task: ShowUpTask
    @Environment(TaskViewModel.self) private var viewModel
    @State private var pulseOpacity: Double = 0.0
    @State private var pulseScale: CGFloat = 1.0

    private var isTracking: Bool {
        viewModel.activeTaskIDs.contains(task.id)
    }

    var body: some View {
        ZStack {
            // Pulse glow when tracking
            if isTracking {
                RoundedRectangle(cornerRadius: 20)
                    .fill(task.cardColor.opacity(0.5))
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseOpacity)
            }

            RoundedRectangle(cornerRadius: 20)
                .fill(task.cardColor)
                .frame(height: 120)

            TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Streak
                        Text("⚡ \(task.streakCount)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black.opacity(0.7))

                        Spacer()

                        // Task name
                        Text(task.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .lineLimit(1)

                        // Location
                        Text(task.locationName)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.black.opacity(0.55))
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        // Progress ring — live because TimelineView re-evaluates task.progress every second
                        ProgressRingView(progress: task.progress, isCompleted: task.isCompletedToday)
                            .frame(width: 44, height: 44)

                        Spacer()

                        // Duration badge
                        Text(task.durationText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(height: 120)
            }
        }
        .frame(height: 120)
        .onAppear {
            if isTracking {
                startPulse()
            }
        }
        .onChange(of: isTracking) { _, tracking in
            if tracking {
                startPulse()
            } else {
                stopPulse()
            }
        }
    }

    private func startPulse() {
        pulseOpacity = 0.6
        pulseScale = 1.05
    }

    private func stopPulse() {
        pulseOpacity = 0.0
        pulseScale = 1.0
    }
}

// MARK: - Progress Ring
struct ProgressRingView: View {
    let progress: Double
    let isCompleted: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.15), lineWidth: 4)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isCompleted ? Color.green : Color.black.opacity(0.7),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            if isCompleted {
                Text("✅")
                    .font(.system(size: 16))
            } else {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.black.opacity(0.8))
            }
        }
    }
}

// MARK: - Empty State
struct EmptyTasksView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "mappin.circle")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            Text("No tasks yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            Text("Tap + to create your first location task")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}
