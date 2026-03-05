import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StreakRecord.completedDate, order: .reverse)
    private var records: [StreakRecord]

    @Environment(TaskViewModel.self) private var viewModel

    private var groupedRecords: [(String, [StreakRecord])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        var groups: [(String, [StreakRecord])] = []
        var current: (String, [StreakRecord])? = nil

        for record in records {
            let key: String
            if Calendar.current.isDateInToday(record.completedDate) {
                key = "Today"
            } else if Calendar.current.isDateInYesterday(record.completedDate) {
                key = "Yesterday"
            } else {
                key = formatter.string(from: record.completedDate)
            }

            if current?.0 == key {
                current?.1.append(record)
            } else {
                if let prev = current { groups.append(prev) }
                current = (key, [record])
            }
        }
        if let last = current { groups.append(last) }
        return groups
    }

    private var totalCompletions: Int { records.count }

    private var currentStreakMax: Int {
        viewModel.tasks.map { $0.streakCount }.max() ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if records.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No completions yet")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                        Text("Complete a task to see your history")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.3))
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Stats row
                            HStack(spacing: 16) {
                                StatCard(value: "\(totalCompletions)", label: "Total Completions", color: .blue)
                                StatCard(value: "\(currentStreakMax)", label: "Best Streak", color: .orange)
                                StatCard(value: "\(viewModel.tasks.count)", label: "Active Tasks", color: .green)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                            // Grouped history
                            ForEach(groupedRecords, id: \.0) { date, recs in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(date)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.4))
                                        .textCase(.uppercase)
                                        .padding(.horizontal, 20)

                                    ForEach(recs, id: \.id) { record in
                                        HistoryRecordRow(record: record)
                                            .padding(.horizontal, 20)
                                    }
                                }
                            }
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

struct HistoryRecordRow: View {
    let record: StreakRecord

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: record.completedDate)
    }

    private var durationText: String {
        let mins = Int(record.durationSeconds / 60)
        return "\(mins) min"
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(record.taskName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                HStack(spacing: 8) {
                    Text(timeText)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                    Text("•")
                        .foregroundColor(.white.opacity(0.3))
                    Text(durationText)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("🔥 \(record.streakCountAtCompletion)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.orange)
                Text("streak")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct StatCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
