//
//  iCloudSyncSettingsView.swift
//  Yala
//
//  Shows real iCloud sync status. Sync is automatic when iCloud is available.
//  Copy is deliberately non-alarming (Brand Voice §8) — errors are framed as
//  "something's a bit off" and always reassure that local data is safe.
//  Desde UX 2.2 · L20-14 es una `YalaSettingsList` (lista agrupada, como el resto de Ajustes).
//

import CloudKit
import SwiftData
import SwiftUI

struct iCloudSyncSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @State private var syncService = iCloudSyncService.shared
    @State private var isForceSyncDisabled = false
    /// Set when an explicit "Sync now" tap couldn't reach iCloud (transient).
    /// Drives a contextual, non-alarming note — never the global banner.
    @State private var manualSyncUnreachable = false
    #if DEBUG
    @State private var dedupHookDisabled = UserDefaults.standard.bool(forKey: AppPreferences.Keys.subcatDedupRemoteHookDisabled)
    @State private var lastRepairMessage: String?
    #endif

    /// UX 2.2 · L20-14 (opción B), decidida por Jürgen el 2026-10-18: **una lista agrupada que no se contradice**. Sin
    /// cuenta ya no dice debajo que «tus datos se sincronizan automáticamente con iCloud», y ofrece abrir los Ajustes del
    /// iPhone; atascada ya no promete «Revisemos qué podemos hacer» sin ningún botón (los de recuperación siguen
    /// apagados: `cloudkit-auto-recovery-stuck-queue`); y el código técnico (`CKError.N`) no se enseña: viaja dentro del
    /// correo de «Contacta con nosotros», que es donde le sirve a alguien.
    var body: some View {
        YalaSettingsList {
            YalaSettingsSection {
                statusRow
            } footer: {
                if let message = statusMessage {
                    Text(message)
                        .accessibilityIdentifier("icloud_status_message")
                }
            }

            if showsNoAccount {
                noAccountSection
            } else {
                forceSyncSection
            }

            if let code = technicalCode {
                contactSection(code: code)
            }

            if !showsNoAccount {
                // Lo que promete iCloud, solo cuando hay iCloud: sin cuenta, los datos se quedan en este iPhone.
                YalaSettingsSection {
                    EmptyView()
                } footer: {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(L10n.iCloud.description)
                        Text(L10n.iCloud.privacyNote)
                    }
                    .accessibilityIdentifier("icloud_description")
                }
            }

            #if DEV_BUILD
            YalaSettingsSection { qaPanel }
            YalaSettingsSection { cloudAuthPanel }
            #endif
            #if DEBUG
            YalaSettingsSection { dedupHookPanel }
            #endif
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.iCloud.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Estado

    /// «Sin cuenta», con UNA sola respuesta para toda la pantalla: la cuenta de iCloud o un `notAuthenticated` de CloudKit
    /// (`status == .noAccount`). Con dos —la fila por el estado y las secciones por el testigo— la pantalla decía
    /// «iCloud no está activo» encima de «Tus datos se sincronizan automáticamente con iCloud» (review del 2026-10-19).
    /// La cuenta es `hasICloudAccount`, no el token de iCloud Drive (card 90yc): con Drive apagado y la sesión abierta el
    /// espejo sincroniza, y la pantalla decía que los datos se quedaban solo aquí.
    private var showsNoAccount: Bool {
        !syncService.hasICloudAccount || syncService.status.isNoAccount
    }

    private var statusRow: some View {
        HStack(spacing: DS.Spacing.lg) {
            iconBadge(statusIcon.name, color: statusIcon.color)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(statusTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = statusDetail {
                    Text(detail)
                        .font(DS.Typography.caption)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, DS.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("icloud_status_row")
    }

    private var statusIcon: (name: String, color: Color) {
        switch syncService.status {
        case .idle, .success, .syncing: ("checkmark.icloud.fill", DS.Semantic.successForeground)
        case .failed: ("icloud.slash", DS.Semantic.errorForeground)
        case .stalled: ("clock.arrow.circlepath", DS.Semantic.warningForeground)
        case .noAccount: ("person.icloud.fill", DS.Semantic.warningForeground)
        }
    }

    private var statusTitle: String {
        switch syncService.status {
        case .idle, .success, .syncing: L10n.iCloud.statusSynced
        case .failed: L10n.iCloud.Detail.errorTitle
        case .stalled(let days, _): L10n.iCloud.Detail.stalledTitle(days)
        case .noAccount: L10n.iCloud.statusNoAccount
        }
    }

    /// La línea bajo el título: la última sincronización, o —sin cuenta— que los datos se quedan aquí.
    private var statusDetail: String? {
        switch syncService.status {
        case .idle, .success, .syncing:
            return (syncService.lastSuccessfulExportDate ?? syncService.lastSuccessfulImportDate)
                .map { L10n.iCloud.Detail.upToDate(formatRelative($0)) }
        case .noAccount:
            return L10n.UXL20N.icloudNoAccountDetail
        case .failed, .stalled:
            return nil
        }
    }

    /// Qué pasa, en el pie del bloque del estado. Sin «Revisemos qué podemos hacer»: no hay botón que lo haga.
    private var statusMessage: String? {
        switch syncService.status {
        case .failed: L10n.iCloud.Detail.errorMessage
        case .stalled: L10n.iCloud.Detail.stalledMessage
        case .idle, .success, .syncing, .noAccount: nil
        }
    }

    /// El código que soporte necesita, cuando hay uno: solo en fallo o atasco.
    private var technicalCode: String? {
        switch syncService.status {
        case .failed(let code, _, _): "CKError.\(code.rawValue)"
        case .stalled(_, let code): code.map { "CKError.\($0.rawValue)" }
        case .idle, .success, .syncing, .noAccount: nil
        }
    }

    private func iconBadge(_ systemName: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: DS.Spacing.xxxxl, height: DS.Spacing.xxxxl)

            Image(systemName: systemName)
                .font(DS.Typography.title)
                .foregroundStyle(color)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Sin cuenta

    /// «Abrir Ajustes del iPhone»: iOS solo deja abrir los Ajustes en la página de Yala (`openSettingsURLString`); desde
    /// ahí, el nombre de la persona está arriba del todo. El pie dice dónde iniciar sesión.
    private var noAccountSection: some View {
        YalaSettingsSection {
            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            } label: {
                YalaSettingsRowLabel(title: L10n.UXL20N.icloudOpenSettings, accessory: "arrow.up.forward")
            }
            .accessibilityIdentifier("icloud_open_settings")
        } footer: {
            Text(L10n.iCloud.noAccountWarning)
        }
    }

    // MARK: - Contacta con nosotros

    /// El detalle técnico, dentro del correo y no en pantalla (L20-14).
    @ViewBuilder
    private func contactSection(code: String) -> some View {
        if let url = SupportMailLinkLogic.url(
            to: AppConstants.supportEmail, subject: L10n.UXL20N.icloudMailSubject,
            body: L10n.iCloud.Detail.technicalCode(code)) {
            YalaSettingsSection {
                Button {
                    openURL(url)
                } label: {
                    YalaSettingsRowLabel(title: L10n.Settings.contact, accessory: "envelope")
                }
                .accessibilityIdentifier("icloud_contact_support")
            } footer: {
                Text(L10n.UXL20N.icloudContactFooter)
            }
        }
    }

    // MARK: - Force Sync

    private var forceSyncSection: some View {
        YalaSettingsSection {
            Button {
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
            } label: {
                HStack {
                    Label(L10n.iCloud.forceSyncButton, systemImage: "arrow.triangle.2.circlepath")
                        .font(DS.Typography.body)
                    Spacer()
                    if syncService.status.isSyncing {
                        ProgressView()
                    }
                }
                .contentShape(Rectangle())
            }
            .disabled(isForceSyncDisabled || syncService.status.isSyncing)
            .accessibilityIdentifier("icloud_force_sync")
        } footer: {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(L10n.iCloud.forceSyncDescription)
                if manualSyncUnreachable {
                    offlineNote
                }
            }
            .animation(.easeInOut(duration: 0.2), value: manualSyncUnreachable)
        }
    }

    /// Contextual, non-alarming note when an explicit "Sync now" tap couldn't
    /// reach iCloud. Neutral info icon (not the red/amber alert styling) —
    /// reassures the user their data is safe (Brand Voice §4.4).
    private var offlineNote: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "info.circle")
            Text(L10n.iCloud.forceSyncOfflineNote)
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
    }

    /// Acceso al panel de auth del Modo Nube (I7c) — DEV_BUILD only.
    private var cloudAuthPanel: some View {
        NavigationLink {
            CloudSyncDebugView()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "key.icloud")
                    .foregroundStyle(DS.Semantic.infoForeground)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text("Modo Nube · Auth")
                        .font(DS.Typography.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("Sign in with Apple + claim contra staging")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
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
    }
    #endif
}

#Preview {
    NavigationStack {
        iCloudSyncSettingsView()
    }
}
