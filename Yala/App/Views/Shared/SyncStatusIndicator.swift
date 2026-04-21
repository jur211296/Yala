//
//  SyncStatusIndicator.swift
//  Yala
//
//  Passive top-bar indicator. Only renders when the sync service reports
//  a state that needs attention (.failed / .stalled). Silent in every other
//  case — sync is silent by default; the icon appears only when something's off.
//

import CloudKit
import SwiftUI

struct SyncStatusIndicator: View {
    let status: iCloudSyncService.SyncStatus
    let onTap: () -> Void

    var body: some View {
        if status.needsAttention {
            Button(action: onTap) {
                Image(systemName: "exclamationmark.icloud.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(L10n.iCloud.SyncIndicator.hint)
            .accessibilityIdentifier("sync_status_indicator")
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
        }
    }

    private var color: Color {
        switch status {
        case .failed: return DS.Semantic.errorForeground
        case .stalled: return DS.Semantic.warningForeground
        default: return .clear
        }
    }

    private var accessibilityLabel: String {
        switch status {
        case .failed:
            return L10n.iCloud.SyncIndicator.failed
        case .stalled(let days, _):
            return L10n.iCloud.SyncIndicator.stalled(days)
        default:
            return ""
        }
    }
}

#Preview("Failed") {
    SyncStatusIndicator(
        status: .failed(code: .networkUnavailable, endDate: .now, retriable: true),
        onTap: {}
    )
}

#Preview("Stalled") {
    SyncStatusIndicator(
        status: .stalled(daysSinceLastSuccess: 9, lastError: .quotaExceeded),
        onTap: {}
    )
}

#Preview("Idle (hidden)") {
    SyncStatusIndicator(status: .idle, onTap: {})
        .border(.red)  // Border shows the empty frame — should be 0x0 when hidden.
}
