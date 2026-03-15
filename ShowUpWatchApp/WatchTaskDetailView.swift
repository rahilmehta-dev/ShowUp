import SwiftUI

struct WatchTaskDetailView: View {
    let task: WatchTask

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: task.progress)
                        .stroke(
                            task.isCompletedToday ? Color.green : Color(hex: task.colorHex),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.4), value: task.progress)

                    if task.isCompletedToday {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Text("\(Int(task.progress * 100))%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 80, height: 80)

                Text(task.progressText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)

                Divider()

                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    Text(task.locationName)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                    Text("\(task.streakCount) day streak")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Status pill
                Text(statusLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
        }
        .navigationTitle(task.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusLabel: String {
        if task.isCompletedToday { return "Done" }
        if task.isInsideZone { return "In Zone" }
        return "Waiting"
    }

    private var statusColor: Color {
        if task.isCompletedToday { return .green }
        if task.isInsideZone { return .orange }
        return .secondary
    }
}
