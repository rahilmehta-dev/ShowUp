import SwiftUI

struct WatchTaskRowView: View {
    let task: WatchTask

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 6) {
                Circle()
                    .fill(Color(hex: task.colorHex))
                    .frame(width: 8, height: 8)
                Text(task.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                statusView
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 4)
                    Capsule()
                        .fill(task.isCompletedToday ? Color.green : Color(hex: task.colorHex))
                        .frame(width: max(geo.size.width * task.progress, task.progress > 0 ? 4 : 0), height: 4)
                }
            }
            .frame(height: 4)

            Text(task.progressText)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var statusView: some View {
        if task.isCompletedToday {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        } else if task.isInsideZone {
            Image(systemName: "location.fill").foregroundColor(.orange)
        } else {
            Image(systemName: "location.slash").foregroundColor(.secondary)
        }
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.hasPrefix("#") ? String(s.dropFirst()) : s
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}
