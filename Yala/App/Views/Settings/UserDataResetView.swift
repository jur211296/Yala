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

    // D4 (§3.3.1): paso 1 = hoja de alcance (`.sheet`, `DestructiveScopeSheet`). El botón destructivo fija
    // `pendingSecondConfirm` y cierra la hoja; su `onDismiss` presenta el paso 2 (alert corto) YA con la hoja
    // fuera (anti-carrera). La mecánica de `wipeAllUserData` NO cambia.
    @State private var isShowingScopeSheet = false
    @State private var pendingSecondConfirm = false
    // Fase 1 (C3): segunda confirmación (alert corto). Contenedor DISTINTO del paso 1 ⇒ sin carrera same-anchor.
    @State private var isShowingSecondConfirmationAlert = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    /// Callback opcional para notificar que el borrado completo de datos
    /// se ha realizado y permitir cerrar también la hoja de Ajustes.
    let onUserDataWiped: (() -> Void)?

    init(onUserDataWiped: (() -> Void)? = nil) {
        self.onUserDataWiped = onUserDataWiped
    }

    /// D4 (§3.3.1): operación de la hoja según el escenario. `wipeDataGroupsOnly` en group-invite (5a),
    /// `wipeDataFull` en el resto. La etiqueta ☁️ la resuelve `cloudLabel(storageMode)` (mata C2).
    private var scopeOperation: DestructiveScopeLogic.Operation {
        sessionState.isGroupInviteMode ? .wipeDataGroupsOnly : .wipeDataFull
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
                                isShowingScopeSheet = true
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

        // Paso 1 — hoja de alcance (D4): 3 filas (📱/☁️/👥) + nota de conservación. "Vaciar definitivamente"
        // fija `pendingSecondConfirm` y cierra la hoja; el `onDismiss` presenta el paso 2 sin carrera.
        .sheet(isPresented: $isShowingScopeSheet, onDismiss: {
            if pendingSecondConfirm {
                pendingSecondConfirm = false
                isShowingSecondConfirmationAlert = true
            }
        }) {
            DestructiveScopeSheet(config: .make(
                operation: scopeOperation,
                cloudLabel: DestructiveScopeLogic.cloudLabel(storageMode: CloudSyncFlags.storageMode),
                onConfirm: { pendingSecondConfirm = true }))
        }

        // Paso 2 — confirmación final corta (C3). Contenedor DISTINTO al paso 1 (alert vs sheet).
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
