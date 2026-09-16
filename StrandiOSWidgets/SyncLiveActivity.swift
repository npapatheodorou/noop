import WidgetKit
import SwiftUI
import ActivityKit
import StrandDesign

/// Live Activity for a strap history sync — the Lock Screen banner and the Dynamic Island.
///
/// Shows what the app's own Today sync control shows: that a sync is running, how many chunks it has
/// pulled, how long it has been going, and the strap's connect-time backlog when it reported one. No
/// progress bar, because there is no total to draw one against (see `SyncActivityAttributes`).
struct SyncLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SyncActivityAttributes.self) { context in
            // Lock Screen / banner presentation.
            HStack(spacing: 14) {
                syncGlyph(context.state.phase)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title)
                        .font(.caption).foregroundStyle(StrandPalette.textSecondary)
                    Text(context.state.status)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(StrandPalette.textPrimary)
                    if let detail = context.state.detail {
                        Text(detail).font(.caption2).foregroundStyle(StrandPalette.textSecondary)
                    }
                }
                Spacer()
                if isActive(context.state.phase) {
                    elapsed(since: context.state.startedAt)
                        .font(.system(.headline, design: .rounded).monospacedDigit())
                        .foregroundStyle(StrandPalette.textPrimary)
                }
            }
            .padding()
            .activityBackgroundTint(StrandPalette.surfaceBase)
            .activitySystemActionForegroundColor(StrandPalette.textPrimary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label { Text(context.state.status) } icon: { syncGlyph(context.state.phase) }
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if isActive(context.state.phase) {
                        elapsed(since: context.state.startedAt)
                            .font(.system(.headline, design: .rounded).monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.detail ?? context.attributes.title)
                        .font(.caption).foregroundStyle(.secondary)
                }
            } compactLeading: {
                syncGlyph(context.state.phase)
            } compactTrailing: {
                // The chunk count is the only live number a sync has. Nothing yet reads as a dash, not
                // as "0", so the island never claims progress the strap has not made.
                Text(context.state.chunks > 0 ? "\(context.state.chunks)" : "–")
                    .monospacedDigit()
            } minimal: {
                syncGlyph(context.state.phase)
            }
        }
    }
}

private func isActive(_ phase: SyncActivityAttributes.Phase) -> Bool {
    phase == .connecting || phase == .syncing
}

/// Counts up on its own from the run's start; no pushes needed to keep it moving.
private func elapsed(since start: Date) -> some View {
    Text(timerInterval: start...Date.distantFuture, countsDown: false)
}

/// One glyph per phase, in the same colour language as the app: accent while working, the positive
/// status colour once done, the critical one when the strap went quiet.
@ViewBuilder
private func syncGlyph(_ phase: SyncActivityAttributes.Phase) -> some View {
    switch phase {
    case .connecting:
        Image(systemName: "antenna.radiowaves.left.and.right").foregroundStyle(StrandPalette.accent)
    case .syncing:
        Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(StrandPalette.accent)
    case .done:
        Image(systemName: "checkmark.circle.fill").foregroundStyle(StrandPalette.statusPositive)
    case .interrupted:
        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(StrandPalette.statusCritical)
    }
}
