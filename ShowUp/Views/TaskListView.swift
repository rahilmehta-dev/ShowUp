import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(TaskViewModel.self) private var viewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showAddTask = false
    @State private var selectedDate = Date()
    @Query private var allStreakRecords: [StreakRecord]

    private let calendar = Calendar.current

    private var isSelectedToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    private var tasksScheduledForSelectedDate: [ShowUpTask] {
        let weekday = calendar.component(.weekday, from: selectedDate)
        return viewModel.tasks.filter { $0.isEnabled && ($0.scheduledDays.isEmpty || $0.scheduledDays.contains(weekday)) }
    }

    private var streakRecordsForSelectedDate: [StreakRecord] {
        allStreakRecords.filter { calendar.isDate($0.completedDate, inSameDayAs: selectedDate) }
    }

    private var isPastDay: Bool {
        let startOfSelected = calendar.startOfDay(for: selectedDate)
        let startOfToday = calendar.startOfDay(for: Date())
        return startOfSelected < startOfToday
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tasks")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)
                            if !isSelectedToday {
                                Text(selectedDate, style: .date)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.4))
                                    .transition(.opacity)
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isSelectedToday)
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

                    if isSelectedToday {
                        // Today: live task cards
                        let todaysTasks = viewModel.tasks.filter { $0.isScheduledToday }
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
                    } else {
                        // Past / future day: history rows
                        let scheduled = tasksScheduledForSelectedDate
                        let records = streakRecordsForSelectedDate
                        if scheduled.isEmpty {
                            EmptyTasksView()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(scheduled, id: \.id) { task in
                                        let record = records.first { $0.taskId == task.id }
                                        HistoryTaskRow(task: task, record: record, isPast: isPastDay)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 100)
                            }
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
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    private var weekDates: [Date] {
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                let isToday = calendar.isDateInToday(date)
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                let isFuture = calendar.startOfDay(for: date) > calendar.startOfDay(for: Date())
                let dayNumber = calendar.component(.day, from: date)
                let dayLetter = weekdays[index]

                VStack(spacing: 4) {
                    Text(dayLetter)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isToday || isSelected ? .white : Color.white.opacity(0.4))

                    ZStack {
                        if isToday {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 32, height: 32)
                        } else if isSelected {
                            Circle()
                                .stroke(Color.white.opacity(0.55), lineWidth: 1.5)
                                .frame(width: 32, height: 32)
                        }
                        Text("\(dayNumber)")
                            .font(.system(size: 15, weight: isToday ? .bold : isSelected ? .semibold : .regular))
                            .foregroundColor(isToday ? .black : Color.white.opacity(isFuture ? 0.3 : isSelected ? 1.0 : 0.6))
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    haptic.impactOccurred()
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedDate = date
                    }
                }
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

            TimelineView(.periodic(from: .now, by: 1.0)) { _ in
                VStack(spacing: 0) {
                    // Main content row
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
                    .frame(height: 96)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)

                    // Divider
                    Rectangle()
                        .fill(Color.black.opacity(0.12))
                        .frame(height: 0.5)
                        .padding(.horizontal, 14)

                    // Time info row
                    HStack(spacing: 6) {
                        // Goal (set time)
                        Label(task.durationText, systemImage: "flag.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.black.opacity(0.5))

                        // Start time (first zone entry today)
                        if let start = task.firstSessionStart {
                            Text("·")
                                .font(.system(size: 11))
                                .foregroundColor(.black.opacity(0.3))
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text(start, style: .time)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.black.opacity(0.5))
                        }

                        // Elapsed / session breakdown
                        if !task.sessionBreakdownText.isEmpty {
                            Text("·")
                                .font(.system(size: 11))
                                .foregroundColor(.black.opacity(0.3))
                            HStack(spacing: 3) {
                                Image(systemName: "timer")
                                    .font(.system(size: 10))
                                Text(task.sessionBreakdownText)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundColor(.black.opacity(0.5))
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
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

// MARK: - History Task Row (past / future days)
struct HistoryTaskRow: View {
    let task: ShowUpTask
    let record: StreakRecord?
    let isPast: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: statusIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(task.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            Circle()
                .fill(task.cardColor)
                .frame(width: 10, height: 10)
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var statusColor: Color {
        if let _ = record { return .green }
        return isPast ? .red.opacity(0.8) : .white.opacity(0.4)
    }

    private var statusIcon: String {
        if let _ = record { return "checkmark" }
        return isPast ? "xmark" : "clock"
    }

    private var subtitle: String {
        if let record = record {
            return formatDuration(record.durationSeconds)
        }
        return isPast ? "Not completed" : "Scheduled"
    }

    private func formatDuration(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return s > 0 ? "\(m)m \(s)s" : "\(m)m"
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
