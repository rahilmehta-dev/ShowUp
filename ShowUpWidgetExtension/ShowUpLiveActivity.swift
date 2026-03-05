import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Widget declaration
struct ShowUpLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ShowUpActivityAttributes.self) { context in
            // Lock Screen / Notification banner
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.9))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded (long-press on pill)
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                CompactRingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Lock Screen view
private struct LockScreenView: View {
    let context: ActivityViewContext<ShowUpActivityAttributes>

    private var accent: Color { cardColor(context.attributes.cardColorHex) }

    var body: some View {
        HStack(spacing: 14) {
            // Circular progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: context.state.progressFraction)
                    .stroke(
                        context.state.isCompleted ? Color.green : accent,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                if context.state.isCompleted {
                    Text("✅").font(.system(size: 20))
                } else {
                    Text("\(Int(context.state.progressFraction * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 52, height: 52)

            // Centre column
            VStack(alignment: .leading, spacing: 5) {
                Text(context.attributes.taskName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                // Status chip
                HStack(spacing: 5) {
                    Image(systemName: statusIcon(context.state))
                        .font(.system(size: 11))
                        .foregroundStyle(statusColor(context.state, accent: accent))
                    Text(statusLabel(context.state))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(statusColor(context.state, accent: accent))
                }

                // Live progress bar
                liveBar(context: context, accent: accent)
                    .frame(height: 6)
            }

            Spacer(minLength: 0)

            // Elapsed / total
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatElapsed(context.state.elapsedSeconds))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text("/ \(Int(context.state.requiredSeconds / 60))m")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
                if context.state.streakCount > 0 {
                    Text("🔥 \(context.state.streakCount)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - Dynamic Island: Expanded regions
private struct ExpandedLeadingView: View {
    let context: ActivityViewContext<ShowUpActivityAttributes>
    private var accent: Color { cardColor(context.attributes.cardColorHex) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: context.state.progressFraction)
                .stroke(
                    context.state.isCompleted ? Color.green : accent,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            if context.state.isCompleted {
                Text("✅").font(.system(size: 14))
            } else {
                Text("\(Int(context.state.progressFraction * 100))%")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 38, height: 38)
        .padding(.leading, 4)
    }
}

private struct ExpandedTrailingView: View {
    let context: ActivityViewContext<ShowUpActivityAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(formatElapsed(context.state.elapsedSeconds))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Text("/ \(Int(context.state.requiredSeconds / 60))m")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.trailing, 4)
    }
}

private struct ExpandedBottomView: View {
    let context: ActivityViewContext<ShowUpActivityAttributes>
    private var accent: Color { cardColor(context.attributes.cardColorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(context.attributes.taskName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: statusIcon(context.state))
                        .font(.system(size: 10))
                    Text(statusLabel(context.state))
                        .font(.system(size: 11))
                }
                .foregroundStyle(statusColor(context.state, accent: accent))
            }
            liveBar(context: context, accent: accent)
                .frame(height: 5)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}

// MARK: - Dynamic Island: Compact + Minimal
private struct CompactRingView: View {
    let context: ActivityViewContext<ShowUpActivityAttributes>
    private var accent: Color { cardColor(context.attributes.cardColorHex) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: context.state.progressFraction)
                .stroke(
                    context.state.isCompleted ? Color.green : accent,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 20, height: 20)
        .padding(.leading, 4)
    }
}

private struct CompactTrailingView: View {
    let context: ActivityViewContext<ShowUpActivityAttributes>
    private var accent: Color { cardColor(context.attributes.cardColorHex) }

    var body: some View {
        if context.state.isCompleted {
            Text("Done! ✅")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.green)
        } else {
            Text(compactTimeLabel(context.state))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(context.state.isInsideZone ? accent : .white.opacity(0.6))
        }
    }
}

private struct MinimalView: View {
    let context: ActivityViewContext<ShowUpActivityAttributes>
    private var accent: Color { cardColor(context.attributes.cardColorHex) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2)
            Circle()
                .trim(from: 0, to: context.state.progressFraction)
                .stroke(
                    context.state.isCompleted ? Color.green : accent,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 16, height: 16)
    }
}

// MARK: - Shared helpers

/// Live progress bar: uses timerInterval for smooth animation when in zone
@ViewBuilder
private func liveBar(
    context: ActivityViewContext<ShowUpActivityAttributes>,
    accent: Color
) -> some View {
    let state = context.state
    if !state.isCompleted,
       state.isInsideZone,
       let start = state.liveProgressStart,
       let end = state.liveProgressEnd {
        // Animates automatically — no app update needed
        ProgressView(timerInterval: start...end, countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.linear)
        .tint(accent)
    } else {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.15))
                RoundedRectangle(cornerRadius: 3)
                    .fill(state.isCompleted ? Color.green : accent)
                    .frame(width: geo.size.width * state.progressFraction)
            }
        }
    }
}

private func cardColor(_ hex: String) -> Color {
    var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    h = h.hasPrefix("#") ? String(h.dropFirst()) : h
    var rgb: UInt64 = 0
    guard Scanner(string: h).scanHexInt64(&rgb) else { return .blue }
    return Color(
        red: Double((rgb >> 16) & 0xFF) / 255,
        green: Double((rgb >> 8) & 0xFF) / 255,
        blue: Double(rgb & 0xFF) / 255
    )
}

private func statusIcon(_ state: ShowUpActivityAttributes.ContentState) -> String {
    if state.isCompleted { return "checkmark.circle.fill" }
    if state.isInsideZone { return "location.fill" }
    return "pause.circle.fill"
}

private func statusLabel(_ state: ShowUpActivityAttributes.ContentState) -> String {
    if state.isCompleted { return "Done! 🔥" }
    if state.isInsideZone { return "Timer running" }
    return "Paused"
}

private func statusColor(
    _ state: ShowUpActivityAttributes.ContentState,
    accent: Color
) -> Color {
    if state.isCompleted { return .green }
    if state.isInsideZone { return accent }
    return .orange
}

private func formatElapsed(_ seconds: Double) -> String {
    let m = Int(seconds) / 60
    let s = Int(seconds) % 60
    return String(format: "%d:%02d", m, s)
}

private func compactTimeLabel(_ state: ShowUpActivityAttributes.ContentState) -> String {
    let remaining = max(0, state.requiredSeconds - state.elapsedSeconds)
    let m = Int(remaining) / 60
    return m > 0 ? "\(m)m left" : "< 1m"
}
