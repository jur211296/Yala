//
//  SyncStatusBanner.swift
//  Yala
//
//  Global sync status banner — small pill floating near the top when the
//  observer reports .failed / .stalled. Silent in every other case.
//
//  Mounted as a ZStack overlay in ContentView (matching the positiveToast
//  idiom) so it doesn't interfere with iOS 26 Liquid Glass nav bars per-tab.
//  Parent injects the tap action so the Profile sheet is presented globally.
//

import CloudKit
import SwiftUI

struct SyncStatusBanner: View {
    let status: iCloudSyncService.SyncStatus
    let onTap: () -> Void

    /// Visual style for a single `needsAttention` state. Factory returns `nil`
    /// for non-attention states — that IS the visibility gate.
    struct Style: Equatable {
        let label: String
        let foreground: Color
        let background: Color

        static func make(for status: iCloudSyncService.SyncStatus) -> Style? {
            switch status {
            case .failed:
                return Style(
                    label: L10n.iCloud.SyncIndicator.failed,
                    foreground: DS.Semantic.errorForeground,
                    background: DS.Semantic.errorBackground
                )
            case .stalled(let days, _):
                return Style(
                    label: L10n.iCloud.SyncIndicator.stalled(days),
                    foreground: DS.Semantic.warningForeground,
                    background: DS.Semantic.warningBackground
                )
            default:
                return nil
            }
        }
    }

    var body: some View {
        if let style = Style.make(for: status) {
            Button(action: onTap) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "exclamationmark.icloud.fill")
                        .font(.system(size: 13, weight: .semibold))

                    Text(style.label)
                        .font(DS.Typography.labelSmall)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .opacity(0.7)
                }
                .foregroundStyle(style.foreground)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .glassEffect(.regular.tint(style.background).interactive())
                .clipShape(Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(style.label)
            .accessibilityHint(L10n.iCloud.SyncIndicator.hint)
            .accessibilityIdentifier("sync_status_banner")
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Host (observation + wipe suppression + tap wiring)

/// Observes `iCloudSyncService.shared` and `SessionState.isWipingData`.
/// Renders `SyncStatusBanner` only when the service reports `.needsAttention`
/// AND a data wipe is not in progress. Wipe suppression lives here (single
/// source of truth) — the service always records real events; the view decides
/// visibility. The parent (`ContentView`) injects the tap action so the Profile
/// sheet is presented at the global level — works from any tab.
struct SyncStatusBannerHost: View {
    let onTap: () -> Void

    @State private var service = iCloudSyncService.shared
    @State private var sessionState = SessionState.shared

    var body: some View {
        Group {
            if !sessionState.isWipingData {
                SyncStatusBanner(status: service.status) {
                    TelemetryService.track(.cloudkitIndicatorTapped)
                    onTap()
                }
            }
        }
        .animation(.snappy, value: service.status)
    }
}

#Preview("Failed") {
    SyncStatusBanner(
        status: .failed(code: .networkUnavailable, endDate: .now, retriable: true),
        onTap: {}
    )
}

#Preview("Stalled") {
    SyncStatusBanner(
        status: .stalled(daysSinceLastSuccess: 9, lastError: .quotaExceeded),
        onTap: {}
    )
}

#Preview("Idle (hidden)") {
    SyncStatusBanner(status: .idle, onTap: {})
        .border(.red)  // Border shows the empty frame — should be 0x0 when hidden.
}
