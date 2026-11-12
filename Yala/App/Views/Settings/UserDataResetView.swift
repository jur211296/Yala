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
    @Environment(SceneNavigation.self) private var navigation
    @Environment(ThemeManager.self) private var themeManager

    // D4 (§3.3.1): paso 1 = hoja de alcance (`.sheet`, `DestructiveScopeSheet`). El botón destructivo fija
    // `pendingSecondConfirm` y cierra la hoja; su `onDismiss` presenta el paso 2 (alert corto) YA con la hoja
    // fuera (anti-carrera). El borrado es `DataWipeService.wipePersonalDataKeepingGroups`.
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
    @State private var pendingExport = false          // "Exportar antes" → pantalla de exportar
    @State private var pendingViewGroups = false      // "Ver mis grupos" (con deuda) → tab Grupos + cierra Ajustes
    @State private var isShowingExportWizard = false
    /// L20-3: «Seguir con el vaciado» desde el aviso tras compartir. Se arma antes de cerrar la hoja de exportar y su
    /// `onDismiss` reabre la de alcance, ya con la de exportar fuera (anti-carrera, como las demás salidas).
    @State private var pendingContinueWipe = false
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
            hasPrivateSession: PrivateSessionMark.hasPrivateSession(),
            personalMountAttachesMirror: CloudSessionSignOut.personalMountAttachesMirror)
    }

    /// L20-5 (decisión de Jürgen, 2026-10-18): una frase que dice qué se borra y dónde, sin jerga. Sale de la misma
    /// operación que la hoja y el borrado (`ExportRecordsLogic.wipeSentence` → `DestructiveScopeLogic.wipeDescription`).
    static func sentence(for operation: DestructiveScopeLogic.Operation,
                         cloudLabel: DestructiveScopeLogic.CloudLabel) -> String {
        switch ExportRecordsLogic.wipeSentence(for: operation, cloudLabel: cloudLabel) {
        case .deviceAndICloud: return L10n.UXL20D.wipeSentenceICloud
        case .deviceAndCloudAccount: return L10n.UXL20D.wipeSentenceCloud
        case .profileOnly: return L10n.UXL20D.wipeSentenceGroupsOnly
        }
    }

    /// La hoja de alcance, con el resumen de grupos leído al tocar (molde D5: READ-ONLY, cero saves).
    private func openWipeScope() {
        wipeScope = WipeScope(summary: GroupService.shared.accountDeletionGroupsSummary())
    }

    /// L20-5: antes eran cuatro veces el título («Vaciar datos» ×2, «Vaciar todos tus datos», «Vaciar mis datos») y un
    /// párrafo con «tipos de cambio» y «perfil de Yala». Ahora, una frase y dos botones: «Exportar una copia antes»
    /// relleno (solo donde hay registros que copiar) y «Vaciar mis datos» en rojo.
    var body: some View {
        YalaSettingsList {
            YalaSettingsSection {
                Text(Self.sentence(for: scopeOperation,
                                   cloudLabel: DestructiveScopeLogic.cloudLabel(storageMode: CloudSyncFlags.storageMode)))
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, DS.Spacing.sm)
                    .accessibilityIdentifier("wipe_data_sentence")
            }

            Section {
                VStack(spacing: DS.Spacing.md) {
                    if ExportRecordsLogic.offersExportCopy(for: scopeOperation) {
                        YalaPrimaryButton(L10n.UXL20D.wipeExportCopy, icon: "square.and.arrow.up",
                                          isDisabled: isProcessing) {
                            isShowingExportWizard = true
                        }
                        .accessibilityIdentifier("wipe_export_copy")
                    }

                    YalaSecondaryButton(L10n.Settings.deleteAllData, isDisabled: isProcessing, destructive: true) {
                        openWipeScope()
                    }
                    .accessibilityIdentifier("wipe_data_start")
                    .accessibilityHint(isProcessing ? L10n.Accessibility.processing : "")
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
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
                navigation.selectMainTab(.groups)
                onRequestCloseSettings?()
            }
        }) { scope in
            DestructiveScopeSheet(config: .make(
                operation: scopeOperation,
                cloudLabel: DestructiveScopeLogic.cloudLabel(storageMode: CloudSyncFlags.storageMode),
                hasOutstandingDebt: scope.summary.hasOutstandingDebt,
                onConfirm: { pendingSecondConfirm = true },
                // "Ver mis grupos" solo aparece con deuda (lo decide `DestructiveScopeLogic.secondaryActions`).
                onSecondary: { pendingViewGroups = true },
                onExport: { pendingExport = true }))
        }
        // «Exportar una copia antes» (la pantalla) y «Exportar antes» (la hoja) abren la misma exportación, con
        // «Todo» elegido. Tras compartir, «Seguir con el vaciado» la cierra y reabre la hoja de alcance (L20-3).
        // «Salir de todos mis grupos» ya no vive aquí: L19-12 lo llevó a Ajustes de Grupos.
        .sheet(isPresented: $isShowingExportWizard, onDismiss: {
            guard pendingContinueWipe else { return }
            pendingContinueWipe = false
            openWipeScope()
        }) {
            ExportRecordsView(origin: .wipe, onContinueWipe: {
                pendingContinueWipe = true
                isShowingExportWizard = false
            })
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

    /// A dónde aterriza la app tras «Vaciar datos». Desde el encargo S27i (decisión de Jürgen, 2026-10-29) la persona se
    /// queda dentro: «Vaciar» borra el contenido y conserva la sesión, la cuenta, los grupos y sus ajustes, así que no hay
    /// bienvenida que repetir —tampoco el onboarding del Paso 9, que esto supera—. Salir es otra fila: «Cerrar sesión».
    ///
    /// Deroga SOLO para este camino el «tras wipe vuelve a mostrarse el chooser» (A4) de
    /// `DataWipeService.removeUserPreferenceKeys`; el vaciado remoto (otro dispositivo) no pasa por aquí.
    private func applyWipeLanding(_ landing: DestructiveScopeLogic.WipeLanding) {
        // El mismo dominio que acaba de barrer el wipe (el de quien pulsa, M1 incluida).
        let defaults = UserDefaults.standard
        switch landing {
        case .panel:
            // Los ajustes se conservaron (`keepsPersonSettings`), `hasCompletedOnboarding` incluido: la app sigue montada.
            // Todas las ventanas al Panel —la capa de borrado las desmontó—. El aviso de crear la primera cuenta se arma al
            // bajar la capa (`handleWipeAllData`). Con «Solo grupos» elegido la shell sigue reducida: la marca de esa
            // vista es un ajuste y se conserva, y ahí no hay Panel (el cambio de pestaña lo descarta la propia shell).
            for window in SceneRegistry.shared.allNavigations {
                window.selectMainTab(.panel)
            }
        case .groupsShell:
            // Solo grupos: la app sigue enseñando los grupos. Se repone el onboarding que el barrido
            // quitó; el perfil y las preferencias, que es lo que se vaciaba, quedan restablecidos.
            //
            // El eje 1 se repone aunque sea idempotente por diseño: la marca SOBREVIVE al vaciado
            // —vaciar no cambia quién eres— y reafirmarla aquí deja el estado en memoria y el
            // persistido contando lo mismo si algún camino futuro llegara a barrerla.
            sessionState.hasPrivateSession = false
            defaults.set(true, forKey: "hasShownWelcomeChooser")
            defaults.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
            navigation.selectMainTab(.groups)
        }
    }

    @MainActor
    private func handleWipeAllData() async {
        isProcessing = true

        // A dónde aterriza la app se decide ANTES del wipe, con el eje 1 leído sobre el teléfono todavía intacto. Y con el
        // aterrizaje, qué se conserva: quien se queda en el Panel conserva sus ajustes y recordatorios (S27i).
        let landing = DestructiveScopeLogic.wipeLanding(
            hasPrivateSession: PrivateSessionMark.hasPrivateSession())
        let keepsPersonSettings = DestructiveScopeLogic.wipeKeepsPersonSettings(landing)
        // Y si avisa a los demás dispositivos del Apple ID: solo una sesión privada (ver la decisión pura).
        // `confirmedPrivateSession` y NO `hasPrivateSession`: esta es la única de las tres cuyo `true`
        // sale de este teléfono (ver el docblock de `wipeSignalsAppleIDDevices`).
        let signalsOtherDevices = DestructiveScopeLogic.wipeSignalsAppleIDDevices(
            confirmedPrivateSession: PrivateSessionMark.confirmedPrivateSession(),
            storageMode: CloudSyncFlags.storageMode)

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

        // 5. Perform the actual wipe (without auto-seeding categories). Conserva los grupos y pide que sus gastos y
        //    liquidaciones vuelvan a lo personal (ver `wipePersonalDataKeepingGroups`).
        do {
            try DataWipeService.wipePersonalDataKeepingGroups(
                in: modelContext,
                broadcastSignal: signalsOtherDevices,
                keepsPersonSettings: keepsPersonSettings
            )

            // 5b. Paso 9 · el aterrizaje, en la MISMA vuelta del main actor que el wipe y antes de cualquier
            // `await`: el `onChange(hasCompletedOnboarding)` de ContentView lee estos flags en el render
            // siguiente, así que ve el estado final y no el intermedio que deja el barrido.
            applyWipeLanding(landing)
            // 5c. Y en esa misma vuelta, la caída de `hasPersonalData` se anuncia como DELIBERADA. En solo-grupos el
            // aterrizaje repone `hasCompletedOnboarding`, y con el guard abierto esa caída arrancaba la gracia de 5 s
            // del aviso «tus datos fueron eliminados de iCloud», como si el borrado viniera de otro dispositivo
            // (ticket `wipe-data-does-not-cancel-the-remote-wipe-grace`).
            sessionState.requestDeliberateWipeSettle()

            // 6. El tema se restablece solo si se restablecieron las preferencias (shell de grupos); en el Panel se queda.
            //    Y los recordatorios conservados se vuelven a programar: el borrado canceló todo lo del sistema, también
            //    los avisos de pagos y presupuestos que se fueron.
            if keepsPersonSettings {
                DataWipeService.rescheduleSurvivingReminders(in: modelContext)
            } else {
                themeManager.resetToDefaults()
            }

            // 7. Small delay to let SwiftData settle before removing overlay
            try? await Task.sleep(for: .milliseconds(200))

            isProcessing = false
            // El aviso de empezar de cero, solo en el Panel (no en la shell de «Solo grupos», donde no hay cuentas que
            // crear) y armado pegado a la bajada que lo enseña: si otro flujo hubiera bajado ya la capa, un `false → false`
            // no dispara el `onChange` y el aviso quedaría colgado para una bajada que no tiene nada que ver.
            sessionState.wipeLandingToastPending = keepsPersonSettings && !sessionState.isGroupsFocusedShell
                && sessionState.isWipingData
            sessionState.isWipingData = false

            // 7. Load exchange rates directly after wipe (more reliable than flag mechanism)
            //    We call the service directly using the same context
            try? await Task.sleep(for: .milliseconds(100))
            await exchangeRateService.updateTodayIfNeeded(context: modelContext)
            await exchangeRateService.preloadHistoricalIfNeeded(context: modelContext)
            await TransactionUpdateService.updateProvisionalTransactions(context: modelContext)
        } catch {
            // También tras un fallo: el borrado guarda por lotes, y uno que lanza a media lista baja la señal igual.
            sessionState.requestDeliberateWipeSettle()
            isProcessing = false
            // El aviso de empezar de cero, solo en el Panel (no en la shell de «Solo grupos», donde no hay cuentas que
            // crear) y armado pegado a la bajada que lo enseña: si otro flujo hubiera bajado ya la capa, un `false → false`
            // no dispara el `onChange` y el aviso quedaría colgado para una bajada que no tiene nada que ver.
            sessionState.wipeLandingToastPending = keepsPersonSettings && !sessionState.isGroupsFocusedShell
                && sessionState.isWipingData
            sessionState.isWipingData = false
            errorMessage = error.localizedDescription
        }
    }
}
