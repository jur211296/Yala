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
    ///
    /// El resumen viaja COMO ITEM de la presentación, no por `@State` leído dentro del closure: medido
    /// 2026-08-03 en el gemelo D5 de `ProfileView`, calcular el resumen y encender `isPresented` en el
    /// MISMO tap hace que SwiftUI arme el contenido con el valor ANTERIOR (`.empty`) y no lo re-evalúe
    /// ⇒ ni «Ver mis grupos» (con deuda) ni el batch D10 (sin deuda) llegaban a ofrecerse nunca.
    private struct WipeScope: Identifiable {
        let id = UUID()
        let summary: AccountDeletionGroupsSummary
    }
    @State private var wipeScope: WipeScope?
    @State private var pendingSecondConfirm = false
    // v2 (§3.3.1): salidas SEGURAS de la hoja, ejecutadas en su `onDismiss` (hoja YA fuera, anti-carrera).
    @State private var pendingExport = false          // "Exportar antes" → wizard de export
    @State private var pendingViewGroups = false      // "Ver mis grupos" (con deuda) → tab Grupos + cierra Ajustes
    @State private var pendingLeaveGroups = false     // D10: "También salir de mis grupos" (sin deuda) → flujo batch
    @State private var isShowingExportWizard = false
    @State private var isShowingBatchLeave = false     // D10: flujo dedicado del batch (headless; sobrevive al cierre)
    // Fase 1 (C3): segunda confirmación (alert corto). Contenedor DISTINTO del paso 1 ⇒ sin carrera same-anchor.
    @State private var isShowingSecondConfirmationAlert = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    /// Callback opcional para cerrar la hoja de Ajustes ENTERA desde esta vista PUSHED (su
    /// `@Environment(\.dismiss)` solo haría *pop* a Profile — B1). Lo usa la finalización del wipe y el
    /// desvío "Ver mis grupos". ProfileView lo cablea a su propio `dismiss()`.
    let onRequestCloseSettings: (() -> Void)?

    init(onRequestCloseSettings: (() -> Void)? = nil) {
        self.onRequestCloseSettings = onRequestCloseSettings
    }

    /// D4 (§3.3.1) + C4: operación de la hoja. `wipeDataGroupsOnly` en solo grupos sin espejo (sin vida
    /// personal que viaje a ningún sitio); `wipeDataFull` en el resto — incluido el solo-grupos cuyo store
    /// espeja, porque ahí los borrados salen a iCloud y a todos los dispositivos (ver `wipeOperation`). La
    /// sesión NO baja el scope. La etiqueta ☁️ la resuelve `cloudLabel(storageMode)` (mata C2).
    private var scopeOperation: DestructiveScopeLogic.Operation {
        DestructiveScopeLogic.wipeOperation(
            isGroupInviteMode: sessionState.isGroupInviteMode,
            personalMountAttachesMirror: CloudSessionSignOut.personalMountAttachesMirror)
    }

    /// D10: ofrecer el batch "También salir de mis grupos" solo con el canal backend ON (DARK), grupos vivos y
    /// CERO deudas globales (el batch no se ofrece con deuda — la fila 👥 muestra "Ver mis grupos"). Solo en
    /// `wipeDataFull` (el modelo lo restringe a esa operación).
    private func canLeaveAllGroups(_ summary: AccountDeletionGroupsSummary) -> Bool {
        // QA/XCUITest: fuerza la oferta (ambos seams inertes en release).
        if UITestHooks.groupsBatchDemo || UITestHooks.groupsBatchRunning { return true }
        return CloudSyncFlags.groupsBackendEnabled && summary.hasGroups && !summary.hasOutstandingDebt
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
                                let summary = GroupService.shared.accountDeletionGroupsSummary()
                                wipeScope = WipeScope(summary: summary)
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
                            .accessibilityIdentifier("wipe_data_start")
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
        .sheet(item: $wipeScope, onDismiss: {
            // Molde capture-all → reset-all → act (ProfileView:400-411): 3 salidas mutuamente excluyentes;
            // se resetean TODOS los flags ANTES de actuar (evita un flag stale en un dismiss posterior).
            let goSecondConfirm = pendingSecondConfirm
            let goExport = pendingExport
            let goViewGroups = pendingViewGroups
            let goLeaveGroups = pendingLeaveGroups
            pendingSecondConfirm = false
            pendingExport = false
            pendingViewGroups = false
            pendingLeaveGroups = false
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
            } else if goLeaveGroups {
                // D10: flujo dedicado del batch (paso separado, NO dispara el vaciado — decisión B1).
                isShowingBatchLeave = true
            }
        }) { scope in
            DestructiveScopeSheet(config: .make(
                operation: scopeOperation,
                cloudLabel: DestructiveScopeLogic.cloudLabel(storageMode: CloudSyncFlags.storageMode),
                hasOutstandingDebt: scope.summary.hasOutstandingDebt,
                canLeaveAllGroups: canLeaveAllGroups(scope.summary),
                onConfirm: { pendingSecondConfirm = true },
                // "Ver mis grupos" solo aparece con deuda (lo decide `DestructiveScopeLogic.secondaryActions`).
                onSecondary: { pendingViewGroups = true },
                onExport: { pendingExport = true },
                onLeaveGroups: { pendingLeaveGroups = true }))
        }
        // D10: flujo dedicado del batch "salir de todos mis grupos". Headless — si se descarta o se cierra
        // Ajustes a mitad, el orquestador sigue y el resultado se refleja en el tab Grupos (residual declarado).
        .sheet(isPresented: $isShowingBatchLeave) {
            GroupBatchLeaveView(onRequestCloseSettings: onRequestCloseSettings)
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

    /// Paso 9 del rediseño de sesiones (ticket §7 y fila H de la matriz de escenarios): tras «Vaciar datos»
    /// la app NO vuelve al Welcome — la sesión en la nube y los grupos, si los hay, siguen puestos, y el
    /// Welcome le ofrecería «Ya tengo cuenta» a quien sigue dentro. Con esto se retiró la pantalla de
    /// retención «Seguir con mis grupos»: con «Vaciar datos» sin tocar grupos, no queda nada que retener.
    ///
    /// Deroga SOLO para este camino el «tras wipe vuelve a mostrarse el chooser» (A4) de
    /// `DataWipeService.removeUserPreferenceKeys`; el vaciado remoto (otro dispositivo) no pasa por aquí.
    private func applyWipeLanding(_ landing: DestructiveScopeLogic.WipeLanding) {
        // El mismo dominio que acaba de barrer el wipe (el de quien pulsa, M1 incluida).
        let defaults = UserDefaults.standard
        switch landing {
        case .personalOnboarding:
            // `presentNextOnboardingScreen` salta al onboarding personal cuando el chooser ya se vio.
            defaults.set(true, forKey: "hasShownWelcomeChooser")
        case .groupsShell:
            // Solo grupos: la app sigue enseñando los grupos. Se reponen el modo y el onboarding que el
            // barrido quitó; el perfil y las preferencias, que es lo que se vaciaba, quedan restablecidos.
            sessionState.onboardingMode = .groupInvite
            defaults.set(true, forKey: "hasShownWelcomeChooser")
            defaults.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
            sessionState.selectMainTab(.groups)
        }
    }

    @MainActor
    private func handleWipeAllData() async {
        isProcessing = true

        // Paso 9 · a dónde aterriza la app se decide ANTES del wipe: el barrido de preferencias borra
        // `onboardingMode`, y después ya no se sabría si esto era un solo-grupos.
        let landing = DestructiveScopeLogic.wipeLanding(isGroupInviteMode: sessionState.isGroupInviteMode)
        // Y si avisa a los demás dispositivos del Apple ID: solo una sesión privada (ver la decisión pura).
        let signalsOtherDevices = DestructiveScopeLogic.wipeSignalsAppleIDDevices(
            isGroupInviteMode: sessionState.isGroupInviteMode, storageMode: CloudSyncFlags.storageMode)

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
                reseedInitialData: false,
                broadcastSignal: signalsOtherDevices
            )

            // 5b. Paso 9 · el aterrizaje, en la MISMA vuelta del main actor que el wipe y antes de cualquier
            // `await`: el `onChange(hasCompletedOnboarding)` de ContentView lee estos flags en el render
            // siguiente, así que ve el estado final y no el intermedio que deja el barrido.
            applyWipeLanding(landing)

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
