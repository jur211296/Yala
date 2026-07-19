//
//  UserDataResetView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI

// MARK: - Vaciar datos del usuario

struct UserDataResetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ExchangeRateService.self) private var exchangeRateService
    @Environment(SessionState.self) private var sessionState
    @Environment(ThemeManager.self) private var themeManager

    @State private var isShowingConfirmationAlert = false
    // Fase 1 (C3): segunda confirmación. El paso 1 (confirmationDialog) y el paso 2 (alert) usan
    // contenedores de presentación DISTINTOS ⇒ el segundo presenta tras cerrarse el primero sin
    // carrera same-anchor (mismo patrón que "Eliminar mi cuenta", ProfileView).
    @State private var isShowingSecondConfirmationAlert = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    /// Callback opcional para notificar que el borrado completo de datos
    /// se ha realizado y permitir cerrar también la hoja de Ajustes.
    let onUserDataWiped: (() -> Void)?

    init(onUserDataWiped: (() -> Void)? = nil) {
        self.onUserDataWiped = onUserDataWiped
    }

    /// Fase 1 (C2/C3): cuerpo del diálogo de alcance de Vaciar. La advertencia de sincronización
    /// mira `storageMode` — en Modo Nube (`.cloud`) los datos viven en la cuenta de Yala, no en
    /// iCloud. Extraído del ViewBuilder (el type-checker no resolvía la concatenación inline).
    private var wipeScopeMessage: String {
        let intro = sessionState.isGroupInviteMode
            ? L10n.Settings.deleteDataWarningGroupsOnly
            : L10n.Settings.deleteDataWarning
        let syncWarning = CloudSyncFlags.storageMode == .cloud
            ? L10n.Settings.wipeICloudWarningCloud
            : L10n.Settings.wipeICloudWarning
        return intro + "\n\n" + syncWarning + "\n\n" + L10n.Settings.wipeGroupsExclusionNote
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xxl) {
                    SectionBox(title: L10n.Settings.resetData) {
                        VStack(alignment: .leading, spacing: DS.Spacing.md) {
                            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                                Text(L10n.Settings.resetAllData)
                                    .font(DS.Typography.title)

                                Text(
                                    sessionState.isGroupInviteMode
                                        ? L10n.Settings.resetDataDescriptionGroupsOnly
                                        : L10n.Settings.resetDataDescription
                                )
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.top, DS.Spacing.lg)

                            SubsectionDivider()

                            Button(role: .destructive) {
                                isShowingConfirmationAlert = true
                            } label: {
                                HStack {
                                    if isProcessing {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                    }

                                    Text(L10n.Settings.deleteAllData)
                                        .font(DS.Typography.body)

                                    Spacer()
                                }
                                .padding(DS.Spacing.lg)
                            }
                            .disabled(isProcessing)
                            .accessibilityHint(isProcessing ? L10n.Accessibility.processing : "")
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.Settings.resetData)
        .navigationBarTitleDisplayMode(.inline)

        // Paso 1 — diálogo de alcance (qué se borra / qué se conserva). "Continuar" abre el paso 2.
        .confirmationDialog(
            L10n.Settings.deleteDataConfirmation,
            isPresented: $isShowingConfirmationAlert,
            titleVisibility: .visible
        ) {
            Button(L10n.Action.continueAction, role: .destructive) {
                isShowingSecondConfirmationAlert = true
            }

            Button(L10n.Settings.cancel, role: .cancel) {
                // El usuario se arrepiente, no hacemos nada.
            }
        } message: {
            Text(wipeScopeMessage)
        }

        // Paso 2 — confirmación final corta (C3). Contenedor DISTINTO al paso 1 (alert vs dialog).
        .alert(
            L10n.Settings.wipeDataSecondConfirmTitle,
            isPresented: $isShowingSecondConfirmationAlert
        ) {
            Button(L10n.Settings.cancel, role: .cancel) {}

            Button(L10n.Settings.deleteAllDataAction, role: .destructive) {
                Task {
                    await handleWipeAllData()
                }
            }
        }

        // Alerta secundaria para errores
        .alert(
            L10n.Settings.deleteDataError,
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button(L10n.Common.accept, role: .cancel) {}
        } message: {
            Text(errorMessage ?? L10n.Settings.deleteDataUnknownError)
        }
    }

    // MARK: - Lógica de borrado

    @MainActor
    private func handleWipeAllData() async {
        isProcessing = true

        // 1. Activate wipe overlay BEFORE starting deletion
        //    This prevents @Query observers from crashing by showing a blocking overlay
        sessionState.resetToDefaults()
        sessionState.isWipingData = true

        // 2. Dismiss all sheets first to reduce active observers
        onUserDataWiped?()
        dismiss()

        // 3. Dev-only: reset subscription state BEFORE wipe so UI never sees stale Pro status
        #if DEBUG
        StoreKitManager.shared.resetForDevelopment()
        #endif

        // 4. Wait for SwiftUI to fully unmount the TabView and deactivate @Query observers
        //    This is critical - without this delay, @Query observers may still be active during deletion
        try? await Task.sleep(for: .milliseconds(500))

        // 5. Perform the actual wipe (without auto-seeding categories)
        do {
            try DataWipeService.wipeAllUserData(
                in: modelContext,
                reseedInitialData: false
            )

            // 6. Ensure @Observable tracks the theme reset
            themeManager.resetToDefaults()

            // 7. Small delay to let SwiftData settle before removing overlay
            try? await Task.sleep(for: .milliseconds(200))

            isProcessing = false
            sessionState.isWipingData = false

            // 7. Load exchange rates directly after wipe (more reliable than flag mechanism)
            //    We call the service directly using the same context
            try? await Task.sleep(for: .milliseconds(100))
            await exchangeRateService.updateTodayIfNeeded(context: modelContext)
            await exchangeRateService.preloadHistoricalIfNeeded(context: modelContext)
            await TransactionUpdateService.updateProvisionalTransactions(context: modelContext)
        } catch {
            isProcessing = false
            sessionState.isWipingData = false
            errorMessage = error.localizedDescription
        }
    }
}
