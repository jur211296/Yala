//
//  iCloudSyncSettingsView.swift
//  Yala
//
//  Settings view for iCloud sync configuration.
//

import SwiftUI

struct iCloudSyncSettingsView: View {
    @State private var syncService = iCloudSyncService.shared
    @State private var showRestartAlert = false
    @State private var pendingToggleValue = false

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    // Status Card
                    statusCard

                    // Sync Toggle Section
                    SectionBox(title: L10n.iCloud.syncSection) {
                        VStack(spacing: 0) {
                            Toggle(isOn: syncToggleBinding) {
                                HStack(spacing: DS.Spacing.md) {
                                    Image(systemName: "icloud.fill")
                                        .font(.body)
                                        .foregroundStyle(Color.electricIndigo)
                                        .frame(width: DS.Spacing.xl)

                                    Text(L10n.iCloud.enableSync)
                                        .font(.body)
                                }
                            }
                            .tint(Color.electricIndigo)
                            .padding(DS.Spacing.lg)
                            .disabled(!syncService.isAccountAvailable)
                        }
                    }

                    // Warning if no iCloud account
                    if !syncService.isAccountAvailable {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(L10n.iCloud.noAccountWarning)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text(L10n.iCloud.description)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text(L10n.iCloud.privacyNote)
                            .font(.footnote)
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
        .alert(L10n.iCloud.restartRequired, isPresented: $showRestartAlert) {
            Button(L10n.iCloud.restartNow, role: .destructive) {
                syncService.isEnabled = pendingToggleValue
                // Force app restart - required because ModelContainer is immutable
                // and CloudKit configuration can only be set at launch time
                exit(0)
            }
            Button(L10n.Action.cancel, role: .cancel) {}
        } message: {
            Text(L10n.iCloud.restartMessage)
        }
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
                    .font(.title2)
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(statusText)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let lastSync = syncService.lastSyncDate {
                    Text(L10n.iCloud.lastSync(formatLastSync(lastSync)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(DS.Spacing.lg)
        .background(Color.yalaCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Status Helpers

    private var statusColor: Color {
        switch syncService.syncStatus {
        case .idle: return .green
        case .syncing: return .blue
        case .error: return .red
        case .disabled: return .secondary
        case .noAccount: return .orange
        }
    }

    private var statusIcon: String {
        switch syncService.syncStatus {
        case .idle: return "checkmark.icloud.fill"
        case .syncing: return "arrow.triangle.2.circlepath.icloud.fill"
        case .error: return "exclamationmark.icloud.fill"
        case .disabled: return "icloud.slash.fill"
        case .noAccount: return "person.icloud.fill"
        }
    }

    private var statusText: String {
        switch syncService.syncStatus {
        case .idle: return L10n.iCloud.statusSynced
        case .syncing: return L10n.iCloud.statusSyncing
        case .error(let message): return message.isEmpty ? L10n.iCloud.statusError : message
        case .disabled: return L10n.iCloud.statusDisabled
        case .noAccount: return L10n.iCloud.statusNoAccount
        }
    }

    private func formatLastSync(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Toggle Binding

    private var syncToggleBinding: Binding<Bool> {
        Binding(
            get: { syncService.isEnabled },
            set: { newValue in
                // Show restart alert instead of changing immediately
                pendingToggleValue = newValue
                showRestartAlert = true
            }
        )
    }
}

#Preview {
    NavigationStack {
        iCloudSyncSettingsView()
    }
}
