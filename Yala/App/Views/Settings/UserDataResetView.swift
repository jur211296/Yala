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
    // v2 (§3.3.1): salidas SEGURAS de la hoja, ejecutadas en su `onDismiss` (hoja YA fuera, anti-carrera).
    @State private var pendingExport = false          // "Exportar antes" → wizard de export
    @State private var pendingViewGroups = false      // "Ver mis grupos" (con deuda) → tab Grupos + cierra Ajustes
    @State private var isShowingExportWizard = false
    // Fase 1 (C3): segunda confirmación (alert corto). Contenedor DISTINTO del paso 1 ⇒ sin carrera same-anchor.
    @State private var isShowingSecondConfirmationAlert = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    /// v2 (§3.3.1): resumen READ-ONLY de grupos (deuda del usuario), recomputado al TAP de "Vaciar datos"
    /// (molde D5 `ProfileView:1021-1025`: fresco y barato — cero saves, invariante de quiescencia (b) intacto).
    @State private var groupsSummary: AccountDeletionGroupsSummary = .empty

    /// Callback opcional para cerrar la hoja de Ajustes ENTERA desde esta vista PUSHED (su
    /// `@Environment(\.dismiss)` solo haría *pop* a Profile — B1). Lo usa la finalización del wipe y el
    /// desvío "Ver mis grupos". ProfileView lo cablea a su propio `dismiss()`.
    let onRequestCloseSettings: (() -> Void)?

    init(onRequestCloseSettings: (() -> Void)? = nil) {
        self.onRequestCloseSettings = onRequestCloseSettings
    }

    /// D4 (§3.3.1) + C4: operación de la hoja. `wipeDataGroupsOnly` en group-invite legado 5a (sin vida
    /// personal); `wipeDataFull` en el resto — incl. 5b (onboarding completed + sesión backend solo-grupos),
    /// que ve el corpus personal completo con la fila 👥 reflejando sus grupos backend. La sesión NO baja el
    /// scope (ver `wipeOperation`). La etiqueta ☁️ la resuelve `cloudLabel(storageMode)` (mata C2).
    private var scopeOperation: DestructiveScopeLogic.Operation {
        DestructiveScopeLogic.wipeOperation(isGroupInviteMode: sessionState.isGroupInviteMode)
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
                                // v2: detección READ-ONLY al TAP (molde D5) — alimenta la fila 👥 y el desvío
                                // "Ver mis grupos". Cero saves (invariante de quiescencia (b) intacto).
                                groupsSummary = SplitSyncManager.shared.accountDeletionGroupsSummary()
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
            // Molde capture-all → reset-all → act (ProfileView:400-411): 3 salidas mutuamente excluyentes;
            // se resetean TODOS los flags ANTES de actuar (evita un flag stale en un dismiss posterior).
            let goSecondConfirm = pendingSecondConfirm
            let goExport = pendingExport
            let goViewGroups = pendingViewGroups
            pendingSecondConfirm = false
            pendingExport = false
            pendingViewGroups = false
            if goSecondConfirm {
                isShowingSecondConfirmationAlert = true
            } else if goExport {
                isShowingExportWizard = true
            } else if goViewGroups {
                // Selecciona el tab ANTES de cerrar (el estado vive en el singleton SessionState y sobrevive
                // al cierre). `onRequestCloseSettings` cierra la hoja de Ajustes ENTERA (NO `dismiss()`, que
                // solo haría *pop* a Profile dejando Ajustes tapando el tab — B1).
                SessionState.shared.selectMainTab(.groups)
                onRequestCloseSettings?()
            }
        }) {
            DestructiveScopeSheet(config: .make(
                operation: scopeOperation,
                cloudLabel: DestructiveScopeLogic.cloudLabel(storageMode: CloudSyncFlags.storageMode),
                hasOutstandingDebt: groupsSummary.hasOutstandingDebt,
                onConfirm: { pendingSecondConfirm = true },
                // "Ver mis grupos" solo aparece con deuda (lo decide `DestructiveScopeLogic.secondaryActions`).
                onSecondary: { pendingViewGroups = true },
                onExport: { pendingExport = true }))
        }
        // v2 (§3.3.1): "Exportar antes" → wizard de export existente (autocontenido: NavigationStack/dismiss
        // propios; hereda `\.modelContext`/`\.yalaTheme`). Al cerrarlo, regresa a esta vista. Solo aplica a
        // `wipeDataFull` (el wizard personal exige transacciones; el 5a exporta grupos desde la fila de Ajustes).
        // SEAM D10: aquí encajará el batch "También salir de mis grupos" (caso sin deuda) — OTRO chip.
        .sheet(isPresented: $isShowingExportWizard) {
            ExportFiltersStepView()
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
        onRequestCloseSettings?()
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
