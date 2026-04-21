//
//  iCloudSyncSettingsView.swift
//  Yala
//
//  Shows iCloud sync status. Sync is automatic when iCloud account is available.
//

import SwiftData
import SwiftUI

struct iCloudSyncSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var syncService = iCloudSyncService.shared
    @State private var isForceSyncDisabled = false

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    // Status Card
                    statusCard

                    // Force sync button (only when iCloud is available)
                    if syncService.isAccountAvailable {
                        forceSyncSection
                    }

                    // Warning if no iCloud account
                    if !syncService.isAccountAvailable {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(DS.Semantic.warningForeground)
                            Text(L10n.iCloud.noAccountWarning)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text(L10n.iCloud.description)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)

                        Text(L10n.iCloud.privacyNote)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DS.Spacing.lg)
                }
                .padding(.vertical, DS.Spacing.xxl)
            }
        }
        .navigationTitle(L10n.iCloud.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Status Card

    private var statusCard: some View {
        HStack(spacing: DS.Spacing.lg) {
            // Status icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: DS.Spacing.xxxxl, height: DS.Spacing.xxxxl)

                Image(systemName: statusIcon)
                    .font(DS.Typography.title)
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(statusText)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)

                if let lastSync = syncService.lastSyncDate {
                    Text(L10n.iCloud.lastSync(formatLastSync(lastSync)))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(DS.Spacing.lg)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Force Sync

    private var forceSyncSection: some View {
        VStack(spacing: DS.Spacing.md) {
            YalaPrimaryButton(
                L10n.iCloud.forceSyncButton,
                icon: "arrow.triangle.2.circlepath",
                isDisabled: isForceSyncDisabled || syncService.syncStatus == .syncing,
                isLoading: syncService.syncStatus == .syncing
            ) {
                Task {
                    await syncService.forceSync(modelContext: modelContext)
                    isForceSyncDisabled = true
                    do {
                        try await Task.sleep(for: .seconds(30))
                    } catch {
                        // Task cancelled (user left view)
                    }
                    isForceSyncDisabled = false
                }
            }

            Text(L10n.iCloud.forceSyncDescription)
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Status Helpers

    private var statusColor: Color {
        switch syncService.syncStatus {
        case .idle: return .green
        case .syncing: return .blue
        case .error: return .red
        case .noAccount: return .orange
        }
    }

    private var statusIcon: String {
        switch syncService.syncStatus {
        case .idle: return "checkmark.icloud.fill"
        case .syncing: return "arrow.triangle.2.circlepath.icloud.fill"
        case .error: return "exclamationmark.icloud.fill"
        case .noAccount: return "person.icloud.fill"
        }
    }

    private var statusText: String {
        switch syncService.syncStatus {
        case .idle: return L10n.iCloud.statusSynced
        case .syncing: return L10n.iCloud.statusSyncing
        case .error(let message): return message.isEmpty ? L10n.iCloud.statusError : message
        case .noAccount: return L10n.iCloud.statusNoAccount
        }
    }

    private func formatLastSync(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date.now)
    }
}

#Preview {
    NavigationStack {
        iCloudSyncSettingsView()
    }
}
