//
//  iCloudSyncSettingsView.swift
//  Yala
//
//  Shows real iCloud sync status. Sync is automatic when iCloud is available.
//  Copy is deliberately non-alarming (Brand Voice §8) — errors are framed as
//  "something's a bit off" and always reassure that local data is safe.
//

import CloudKit
import SwiftData
import SwiftUI

struct iCloudSyncSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var syncService = iCloudSyncService.shared
    @State private var isForceSyncDisabled = false
    @State private var showTechnical = false
    /// Set when an explicit "Sync now" tap couldn't reach iCloud (transient).
    /// Drives a contextual, non-alarming note — never the global banner.
    @State private var manualSyncUnreachable = false
    #if DEBUG
    @State private var dedupHookDisabled = UserDefaults.standard.bool(forKey: AppPreferences.Keys.subcatDedupRemoteHookDisabled)
    @State private var lastRepairMessage: String?
    #endif

    /// Auto-recovery CTAs (Retry / Diagnose) are gated on a future feature.
    /// Flip to true when `cloudkit-auto-recovery-stuck-queue` ships.
    private let isAutoRecoveryAvailable = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                    statusCard

                    if syncService.isAccountAvailable {
                        forceSyncSection
                    }

                    if !syncService.isAccountAvailable {
                        noAccountWarning
                    }

                    descriptionFooter

                    #if DEV_BUILD
                    qaPanel
                    #endif
                    #if DEBUG
                    dedupHookPanel
                    #endif
                }
                .padding(.vertical, DS.Spacing.xxl)
            }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.iCloud.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Status Card

    @ViewBuilder
    private var statusCard: some View {
        switch syncService.status {
        case .idle, .success, .syncing:
            upToDateCard
        case .failed(let code, _, _):
            failedCard(code: code)
        case .stalled(let days, let code):
            stalledCard(days: days, code: code)
        case .noAccount:
            noAccountCard
        }
    }

    // MARK: - Up to Date (idle / success / syncing)

    private var upToDateCard: some View {
        HStack(spacing: DS.Spacing.lg) {
            iconBadge("checkmark.icloud.fill", color: DS.Semantic.successForeground)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.iCloud.statusSynced)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)

                if let lastSync = syncService.lastSuccessfulExportDate
                    ?? syncService.lastSuccessfulImportDate {
                    Text(L10n.iCloud.Detail.upToDate(formatRelative(lastSync)))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .statusCardStyle()
    }

    // MARK: - Failed

    private func failedCard(code: CKError.Code) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.lg) {
                iconBadge("icloud.slash", color: DS.Semantic.errorForeground)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.iCloud.Detail.errorTitle)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                }
                Spacer()
            }

            Text(L10n.iCloud.Detail.errorMessage)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)

            technicalDisclosure(code: code)

            if isAutoRecoveryAvailable {
                recoveryCTAs
            }
        }
        .statusCardStyle()
    }

    // MARK: - Stalled

    private func stalledCard(days: Int, code: CKError.Code?) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.lg) {
                iconBadge("clock.arrow.circlepath", color: DS.Semantic.warningForeground)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.iCloud.Detail.stalledTitle(days))
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                }
                Spacer()
            }

            Text(L10n.iCloud.Detail.stalledMessage)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)

            if let code {
                technicalDisclosure(code: code)
            }

            if isAutoRecoveryAvailable {
                recoveryCTAs
            }
        }
        .statusCardStyle()
    }

    // MARK: - No account

    private var noAccountCard: some View {
        HStack(spacing: DS.Spacing.lg) {
            iconBadge("person.icloud.fill", color: DS.Semantic.warningForeground)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.iCloud.statusNoAccount)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .statusCardStyle()
    }

    // MARK: - Shared pieces

    private func iconBadge(_ systemName: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: DS.Spacing.xxxxl, height: DS.Spacing.xxxxl)

            Image(systemName: systemName)
                .font(DS.Typography.title)
                .foregroundStyle(color)
        }
    }

    private func technicalDisclosure(code: CKError.Code) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTechnical.toggle()
                }
            } label: {
                Text(L10n.iCloud.Detail.CTA.viewTechnical)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)

            if showTechnical {
                Text(L10n.iCloud.Detail.technicalCode("CKError.\(code.rawValue)"))
                    .font(DS.Typography.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var recoveryCTAs: some View {
        HStack(spacing: DS.Spacing.md) {
            Button(L10n.iCloud.Detail.CTA.retry) {
                Task { await syncService.forceSync(modelContext: modelContext) }
            }
            .buttonStyle(.borderedProminent)

            Button(L10n.iCloud.Detail.CTA.diagnose) {
                // Will dispatch to cloudkit-auto-recovery-stuck-queue when available.
            }
            .buttonStyle(.bordered)
        }
    }

    private var noAccountWarning: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DS.Semantic.warningForeground)
            Text(L10n.iCloud.noAccountWarning)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var descriptionFooter: some View {
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

    // MARK: - Force Sync

    private var forceSyncSection: some View {
        VStack(spacing: DS.Spacing.md) {
            YalaPrimaryButton(
                L10n.iCloud.forceSyncButton,
                icon: "arrow.triangle.2.circlepath",
                isDisabled: isForceSyncDisabled || syncService.status.isSyncing,
                isLoading: syncService.status.isSyncing
            ) {
                Task {
                    manualSyncUnreachable = false
                    let result = await syncService.forceSync(modelContext: modelContext)
                    manualSyncUnreachable = (result == .unreachable)
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

            if manualSyncUnreachable {
                offlineNote
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .animation(.easeInOut(duration: 0.2), value: manualSyncUnreachable)
    }

    /// Contextual, non-alarming note when an explicit "Sync now" tap couldn't
    /// reach iCloud. Neutral info icon (not the red/amber alert styling) —
    /// reassures the user their data is safe (Brand Voice §4.4).
    private var offlineNote: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text(L10n.iCloud.forceSyncOfflineNote)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity)
    }

    // MARK: - Helpers

    private func formatRelative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date.now)
    }

    // MARK: - QA Panel (DEV_BUILD only)

    #if DEV_BUILD
    private var qaPanel: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("🧪 QA — Simular estados")
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: DS.Spacing.sm) {
                Button("Simular fallo (red) — 10s") {
                    syncService._qaSimulateFailed(code: .networkUnavailable, visibleFor: 10)
                }
                .buttonStyle(.bordered)
                .tint(DS.Semantic.errorForeground)

                Button("Simular stalled (9 días) — 10s") {
                    syncService._qaSimulateStalled(days: 9, visibleFor: 10)
                }
                .buttonStyle(.bordered)
                .tint(DS.Semantic.warningForeground)

                Button("Reset a idle") {
                    syncService._testReset()
                }
                .buttonStyle(.bordered)
            }

            Text("Solo visible en Yala Dev. Tras el tap: nube aparece inmediata, persiste 10s, vuelve a idle.")
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .padding(.horizontal, DS.Spacing.lg)
    }
    #endif

    #if DEBUG
    /// Toggle del feature flag del dedup-en-oleadas. Visible al correr el scheme Yala
    /// en config Debug (contenedor de producción), que es como se valida el fix.
    private var dedupHookPanel: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Toggle("Apagar dedup en oleadas de sync", isOn: $dedupHookDisabled)
                .font(DS.Typography.caption.weight(.semibold))
                .onChange(of: dedupHookDisabled) { _, newValue in
                    UserDefaults.standard.set(newValue, forKey: AppPreferences.Keys.subcatDedupRemoteHookDisabled)
                }

            Text("Debug: desactiva SOLO el hook que deduplica en cada oleada de CloudKit. El pase de arranque y “Forzar sincronización” siguen activos.")
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)

            Divider()

            Button("Reparar IDs colapsados ahora") {
                let count = CategoryDeduplicationService.repairCollapsedIdentityUUIDs(in: modelContext)
                lastRepairMessage = count > 0
                    ? "Reparados \(count) UUIDs de identidad colapsados."
                    : "Nada que reparar (0 colisiones)."
            }
            .font(DS.Typography.caption.weight(.semibold))

            Text("Debug: regenera Tag.id / shortcutID colapsados (mismo valor entre records distintos) y reconstruye los CSV mirrors. Idempotente.")
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)

            if let lastRepairMessage {
                Text(lastRepairMessage)
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .padding(.horizontal, DS.Spacing.lg)
    }
    #endif
}

private extension View {
    /// Shared card styling used by every status card variant in this view.
    func statusCardStyle() -> some View {
        self
            .padding(DS.Spacing.lg)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
            .padding(.horizontal, DS.Spacing.lg)
    }
}

#Preview {
    NavigationStack {
        iCloudSyncSettingsView()
    }
}
