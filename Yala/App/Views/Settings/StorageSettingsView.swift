//
//  StorageSettingsView.swift
//  Yala
//
//  UI real de migración/reversa del Modo Nube (I14 P3). Pantalla de Ajustes (stack de Profile →
//  `.subtle`) que expone, según el estado derivado del journal (`CloudMigrationController.uiState`):
//   - `.icloud` estable → "Migrar a la nube" (consent → SIWA → doble confirmación → progreso → relaunch)
//     o, si el mirror trae el marcador de un líder (`secondaryDeviceCloudLogin`), el copy de ADOPT.
//   - `.cloud` estable → "Volver a iCloud" (gate `ReverseEligibility` + doble confirmación) + estado de sync.
//   - Fase transicional → progreso (molde `OnboardingRestoreProgress`) + "Retomar"/"Reintentar".
//   - `needsRelaunch` → card BLOQUEANTE "cierra Yala y vuelve a abrirla" (relaunch asistido — NUNCA `exit()`).
//
//  Solo alcanzable si `CloudBackendConfig.isConfigured` (la fila de Profile la oculta si no).
//

import SwiftUI

struct StorageSettingsView: View {
    /// El controller de producción (SSOT del runner). `nil` solo si el backend no está configurado — en
    /// ese caso la fila de Profile ni aparece, pero se degrada elegante por si se navega directo.
    private var controller: CloudMigrationController? { CloudMigrationController.shared }

    @State private var showConsent = false
    @State private var consentPath: CloudMigrationController.ConsentPath = .migration
    @State private var confirmMigrate1 = false
    @State private var confirmMigrate2 = false
    @State private var confirmRevert1 = false
    @State private var confirmRevert2 = false
    @State private var showError = false
    @State private var dryRun: (transactions: Int, categories: Int, accounts: Int, budgets: Int)?
    /// Tick de refresco del journal vivo (el runner no es `@Observable`).
    @State private var refreshTick = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                // M1 belt: en sesión secundaria esta pantalla no aplica (describe/opera la migración
                // del DUEÑO) — la fila de ProfileView ya la oculta; esto degrada un acceso directo.
                if SecondarySessionStore.isActive() {
                    Text(L10n.Storage.Errors.generic)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DS.Spacing.lg)
                } else if let controller {
                    content(controller)
                } else {
                    Text(L10n.Storage.Errors.generic)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DS.Spacing.lg)
                }

                #if DEV_BUILD
                cloudDebugPanel
                #endif
            }
            .padding(.vertical, DS.Spacing.xxl)
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.Storage.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Refresca el journal vivo cada 1s mientras la pantalla está abierta (molde del panel DEBUG).
            while !Task.isCancelled {
                controller?.refresh()
                refreshTick.toggle()
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
            }
        }
        .sheet(isPresented: $showConsent) {
            CloudConsentView(path: consentPath) {
                showConsent = false
                onConsentAccepted()
            }
        }
        .modifier(StorageConfirmations(
            confirmMigrate1: $confirmMigrate1, confirmMigrate2: $confirmMigrate2,
            confirmRevert1: $confirmRevert1, confirmRevert2: $confirmRevert2,
            onMigrate: { Task { await controller?.startMigration(consentPath: .migration) } },
            onRevert: { Task { await controller?.startReverse() } }))
        .alert(L10n.Storage.Errors.title, isPresented: $showError, presenting: controller?.lastError) { _ in
            Button(L10n.Common.ok, role: .cancel) { controller?.lastError = nil }
        } message: { message in
            Text(message)
        }
        .onChange(of: controller?.lastError) { _, newValue in
            showError = (newValue != nil)
        }
    }

    // MARK: - Contenido por estado

    @ViewBuilder
    private func content(_ controller: CloudMigrationController) -> some View {
        switch controller.uiState {
        case .idle:
            statusCard(controller)
            migrateCard(controller)
        case .cloudActive:
            statusCard(controller)
            syncStatusSection(controller)
            revertCard(controller)
        case .migrating(let step):
            progressCard(controller, step: step, reverse: false)
        case .reverting(let step):
            progressCard(controller, step: step, reverse: true)
        case .needsRelaunch(let direction):
            relaunchCard(direction)
        case .waitingForLeader:
            waitingCard()
        case .failed(let kind):
            failedCard(controller, kind: kind)
        }
    }

    // MARK: - Status card

    private func statusCard(_ controller: CloudMigrationController) -> some View {
        let isCloud = (CloudSyncFlags.storageMode == .cloud)
        return HStack(spacing: DS.Spacing.lg) {
            Image(systemName: isCloud ? "cloud.fill" : "lock.icloud.fill")
                .font(DS.Typography.title)
                .foregroundStyle(isCloud ? DS.Semantic.infoForeground : DS.Semantic.successForeground)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(isCloud ? L10n.Storage.Status.cloudTitle : L10n.Storage.Status.icloudTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                Text(isCloud ? L10n.Storage.Status.cloudBody : L10n.Storage.Status.icloudBody)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .storageCardStyle()
        .accessibilityIdentifier("storage_status_card")
    }

    // MARK: - Migrate / Adopt card

    private func migrateCard(_ controller: CloudMigrationController) -> some View {
        // El marcador de un líder en el mirror → copy de ADOPT (evita el falso "migrar" sobre cuenta poblada).
        let isAdopt = (controller.markerDecision() == .secondaryDeviceCloudLogin)
        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(isAdopt ? L10n.Storage.Adopt.title : L10n.Storage.Migrate.title)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
            Text(isAdopt ? L10n.Storage.Adopt.body : L10n.Storage.Migrate.body)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)

            if !isAdopt {
                Button {
                    dryRun = controller.dryRunCounts()
                } label: {
                    Text(L10n.Storage.Migrate.previewButton)
                        .font(DS.Typography.caption.weight(.medium))
                        .foregroundStyle(DS.Semantic.infoForeground)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("storage_preview_button")

                if let dryRun {
                    Text(L10n.Storage.Migrate.previewResult(
                        dryRun.transactions, dryRun.categories, dryRun.accounts, dryRun.budgets))
                        .font(DS.Typography.caption.monospaced())
                        .foregroundStyle(.tertiary)
                }
            }

            YalaPrimaryButton(
                isAdopt ? L10n.Storage.Adopt.button : L10n.Storage.Migrate.button,
                icon: "arrow.up.to.line",
                isDisabled: controller.isWorking
            ) {
                consentPath = isAdopt ? .adopt : .migration
                showConsent = true
            }
            .accessibilityIdentifier("storage_migrate_button")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .storageCardStyle()
    }

    // MARK: - Revert card

    @ViewBuilder
    private func revertCard(_ controller: CloudMigrationController) -> some View {
        let eligibility = controller.reverseEligibility()
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.Storage.Revert.title)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
            Text(L10n.Storage.Revert.body)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)

            if eligibility == .eligible {
                Button {
                    confirmRevert1 = true
                } label: {
                    Text(L10n.Storage.Revert.button)
                        .font(DS.Typography.body.weight(.medium))
                        .foregroundStyle(DS.Semantic.warningForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .tint(DS.Semantic.warningForeground)
                .disabled(controller.isWorking)
                .accessibilityIdentifier("storage_revert_button")
            } else {
                Text(L10n.Storage.Revert.ineligible)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .storageCardStyle()
    }

    // MARK: - Sync status (banner S11)

    @ViewBuilder
    private func syncStatusSection(_ controller: CloudMigrationController) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.Storage.Sync.title)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
            if controller.syncNeedsSignIn {
                Text(L10n.Storage.Sync.needsSignIn(controller.pendingUploadCount))
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Semantic.warningForeground)
                YalaPrimaryButton(L10n.Storage.Sync.signInButton, icon: "person.crop.circle.badge.checkmark",
                                  isDisabled: controller.isWorking) {
                    Task { await controller.signInToResumeSync() }
                }
                .accessibilityIdentifier("storage_sync_signin_button")
            } else {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.Semantic.successForeground)
                    Text(L10n.Storage.Sync.upToDate)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .storageCardStyle()
    }

    // MARK: - Progress card (transitional)

    private func progressCard(_ controller: CloudMigrationController, step: MigrationUIStep, reverse: Bool) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            ProgressView(value: step.fraction)
                .tint(DS.Semantic.infoForeground)
            Text(reverse ? L10n.Storage.Progress.reverting : L10n.Storage.Progress.migrating)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            Button {
                Task { await controller.resume() }
            } label: {
                Text(L10n.Storage.Progress.resume)
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(DS.Semantic.infoForeground)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(controller.isWorking)
            .accessibilityIdentifier("storage_resume_button")
        }
        .frame(maxWidth: .infinity)
        .storageCardStyle()
        .accessibilityIdentifier("storage_progress_card")
    }

    // MARK: - Needs relaunch (assisted relaunch — NEVER exit())

    private func relaunchCard(_ direction: CloudMigrationUIState.RelaunchDirection) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.system(size: 44))  // A11Y-DT: ícono hero decorativo de la card de relaunch (molde GroupInviteOnboardingView); el texto acompañante SÍ escala
                .foregroundStyle(DS.Semantic.infoForeground)
            Text(L10n.Storage.Relaunch.title)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            Text(L10n.Storage.Relaunch.body)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .storageCardStyle()
        .accessibilityIdentifier("storage_relaunch_card")
    }

    // MARK: - Waiting for leader

    private func waitingCard() -> some View {
        HStack(spacing: DS.Spacing.lg) {
            ProgressView()
            Text(L10n.Storage.waitingForLeader)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .storageCardStyle()
    }

    // MARK: - Failed (rollback)

    private func failedCard(_ controller: CloudMigrationController, kind: CloudMigrationUIState.FailureKind) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DS.Semantic.warningForeground)
                Text(kind == .migration ? L10n.Storage.Failed.migration : L10n.Storage.Failed.reverse)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)
            }
            YalaPrimaryButton(L10n.Storage.Progress.retry, icon: "arrow.clockwise",
                              isDisabled: controller.isWorking) {
                Task { await controller.resetAfterRollback() }
            }
            .accessibilityIdentifier("storage_retry_button")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .storageCardStyle()
    }

    // MARK: - Panel DEBUG (DEV_BUILD only)

    #if DEV_BUILD
    /// Acceso al panel DEBUG del Modo Nube desde la fila Almacenamiento — en `.cloud` la fila iCloud
    /// de Profile está oculta (R12 mínimo de I14) y sin esto el panel queda inalcanzable en device Dev.
    /// Mismo patrón que `cloudAuthPanel` de iCloudSyncSettingsView.
    private var cloudDebugPanel: some View {
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
                    Text("Panel DEBUG (solo Yala Dev)")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .storageCardStyle()
        }
        .buttonStyle(.plain)
    }
    #endif

    // MARK: - Consent aceptado

    private func onConsentAccepted() {
        switch consentPath {
        case .adopt:
            // Adopt: NO doble confirmación destructiva (no mueve datos; ya pasó consent+sign-in).
            Task { await controller?.startMigration(consentPath: .adopt) }
        case .migration:
            // Migración: doble confirmación sobre la ACCIÓN antes de mover datos.
            confirmMigrate1 = true
        }
    }
}

// MARK: - Confirmaciones (2 confirmationDialog destructive por acción, patrón panel)

private struct StorageConfirmations: ViewModifier {
    @Binding var confirmMigrate1: Bool
    @Binding var confirmMigrate2: Bool
    @Binding var confirmRevert1: Bool
    @Binding var confirmRevert2: Bool
    let onMigrate: () -> Void
    let onRevert: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(L10n.Storage.Confirm.migrateTitle,
                                isPresented: $confirmMigrate1, titleVisibility: .visible) {
                Button(L10n.Storage.Confirm.migrateContinue, role: .destructive) { confirmMigrate2 = true }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Storage.Confirm.migrateBody)
            }
            .confirmationDialog(L10n.Storage.Confirm.migrate2Title,
                                isPresented: $confirmMigrate2, titleVisibility: .visible) {
                Button(L10n.Storage.Confirm.migrate2Confirm, role: .destructive) { onMigrate() }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Storage.Confirm.migrate2Body)
            }
            .confirmationDialog(L10n.Storage.Confirm.revertTitle,
                                isPresented: $confirmRevert1, titleVisibility: .visible) {
                Button(L10n.Storage.Confirm.revertContinue, role: .destructive) { confirmRevert2 = true }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Storage.Confirm.revertBody)
            }
            .confirmationDialog(L10n.Storage.Confirm.revert2Title,
                                isPresented: $confirmRevert2, titleVisibility: .visible) {
                Button(L10n.Storage.Confirm.revert2Confirm, role: .destructive) { onRevert() }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Storage.Confirm.revert2Body)
            }
    }
}

private extension View {
    func storageCardStyle() -> some View {
        self
            .padding(DS.Spacing.lg)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
            .padding(.horizontal, DS.Spacing.lg)
    }
}
