//
//  CloudSessionSignOut.swift
//  Yala
//
//  Coordinador del "Cerrar sesión" universal (H4, decisión owner 2026-07-12).
//  Vive FUERA de CloudMigrationController a propósito: el camino privado debe funcionar
//  con el backend NO configurado (prod DARK), donde `CloudMigrationController.shared` es nil.
//
//  Caminos (CloudSignOutFlowLogic.path):
//  - `.privateReset` (.icloud): NO toca datos — teardown si hay runtime, signOut local
//    (idempotente, no-op sin backend), reset de onboarding → ContentView re-presenta el
//    Welcome vía su onChange. Re-entrada: "Ya tengo cuenta → Restaurar iCloud".
//  - `.cloudSecureSignOut` (.cloud): push-all VERIFICADO (jamás descartar) → teardown +
//    signOut → armar el wipe de boot → pantalla de relaunch asistido (NUNCA auto-kill).
//    El cleanup destructivo corre en el BOOT (SwiftDataConfiguration.performSignOutWipeIfArmed).
//

import Foundation

@MainActor
@Observable
final class CloudSessionSignOut {

    static let shared = CloudSessionSignOut()
    private init() {}

    enum Phase: Equatable {
        case idle
        /// Push-all + teardown en curso (spinner en el dialog/fila).
        case working
        /// El push-all no logró vaciar el outbox → cierre ABORTADO. El usuario reintenta con red.
        case blocked(pendingCount: Int)
        /// Camino `.cloud` completo — cover de relaunch bloqueante hasta que el usuario reabra.
        case awaitingRelaunch
    }

    private(set) var phase: Phase = .idle

    /// Vuelve a `.idle` tras un `.blocked` (el usuario cerró el error).
    func acknowledgeBlocked() {
        if case .blocked = phase { phase = .idle }
    }

    #if DEBUG
    /// Seam de verificación EN SIM (fix carrera 2026-07-14): fuerza la fase terminal SIN armar
    /// el wipe real ni tocar credenciales — única forma de probar en sim la presentación del
    /// cover terminal (dueño único + verify loop) y el exit-on-background (SIWA no corre ahí).
    func _debugForceAwaitingRelaunch() {
        phase = .awaitingRelaunch
    }
    #endif

    func signOut() async {
        guard phase == .idle else { return }
        switch CloudSignOutFlowLogic.path(
            for: CloudSyncFlags.storageMode,
            secondarySessionActive: SecondarySessionStore.isActive()
        ) {
        case .privateReset:
            await performPrivateReset()
        case .cloudSecureSignOut:
            await performCloudSecureSignOut()
        case .secondaryCloudSignOut:
            await performSecondaryCloudSignOut()
        }
    }

    // MARK: - Camino privado (.icloud) — datos intactos

    private func performPrivateReset() async {
        phase = .working
        CloudSyncBreadcrumb.signOutStarted(path: "private-reset")

        // Teardown del runtime si existe (post-reversa / spikes): idempotente, purga espejo+prefs.
        CloudSyncRuntime.shared?.teardownGuestSession()
        await CloudAuthService.shared.signOut()

        resetOnboardingFlagsPreservingData()
        SessionState.shared.resetToDefaults()
        AppRouter.shared.resetAll()

        CloudSyncBreadcrumb.signOutPrivateReset()
        phase = .idle
        // ContentView.onChange(hasCompletedOnboarding=false) desmonta MainTabView y
        // re-presenta el Welcome. Los datos siguen en el device: "Soy nuevo" muestra el
        // alert de fresh-start existente; "Restaurar iCloud" regresa a donde estaba.
    }

    /// Solo los 3 flags de onboarding — las prefs del usuario (tema, moneda, etc.) SOBREVIVEN
    /// (a diferencia del camino `.cloud`, donde el boot-cleanup resetea todo a recién instalada).
    private func resetOnboardingFlagsPreservingData() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        defaults.set(false, forKey: "hasShownWelcomeChooser")
        defaults.set(false, forKey: AppPreferences.Keys.hasShownYalaAIOnboarding)
    }

    // MARK: - Camino nube (.cloud) — push-all verificado + wipe armado

    private func performCloudSecureSignOut() async {
        phase = .working
        CloudSyncBreadcrumb.signOutStarted(path: "cloud-secure")

        // En `.cloud` el backend está configurado por definición (solo el cutover/adopt
        // escriben ese modo); si el controller faltara, solo es seguro cerrar sin pendientes.
        guard let controller = CloudMigrationController.shared else {
            phase = .blocked(pendingCount: 0)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: 0)
            return
        }

        switch await controller.pushAllPendingForSignOut() {
        case .blocked(let pending):
            phase = .blocked(pendingCount: pending)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: pending)
        case .drained:
            // Orden: primero el motor (epoch++ aborta ciclos en vuelo, nada nuevo cicla).
            CloudSyncRuntime.shared?.teardownGuestSession()
            // S2 del review: re-verificar el outbox tras cortar el motor y ANTES de soltar
            // credenciales — si un save concurrente encoló filas durante el push-all, se
            // bloquea con la sesión AÚN viva (reintentar funciona). Residual documentado:
            // writes que queden solo en History (sin drain post-teardown) mueren con el
            // wipe; el guard de handleBecameActive congela los drains de intents App Group
            // durante la ventana armada.
            let residual = controller.livePendingUploadCount()
            guard residual == 0 else {
                phase = .blocked(pendingCount: residual)
                CloudSyncBreadcrumb.signOutPushBlocked(pending: residual)
                return
            }
            await CloudAuthService.shared.signOut()
            StorageModePersistence.armSignOutWipe()
            CloudSyncBreadcrumb.signOutWipeArmed()
            phase = .awaitingRelaunch
        }
    }

    // MARK: - Camino secundario (M1) — push-all verificado + wipe SECUNDARIO armado

    /// Clon del camino `.cloud` con dos diferencias EXACTAS: arma `SecondarySessionStore.armWipe`
    /// (el boot borra SOLO los archivos `-Secondary`; los del dueño y sus keys `storageMode`/
    /// `mirrorOffArmed` jamás se tocan) y NO resetea los flags de onboarding IN-SESSION — lo hace
    /// el boot wipe (resetearlos con el proceso vivo montaría la cadena Welcome DEBAJO del cover
    /// de relaunch: doble presentación en el mismo anchor, clase toolbar-muerta). Reusa la fase
    /// `.awaitingRelaunch` ⇒ el cover durable C1 y el blocker de la matriz funcionan sin cambios.
    private func performSecondaryCloudSignOut() async {
        phase = .working
        CloudSyncBreadcrumb.signOutStarted(path: "secondary")

        guard let controller = CloudMigrationController.shared else {
            phase = .blocked(pendingCount: 0)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: 0)
            return
        }

        switch await controller.pushAllPendingForSignOut() {
        case .blocked(let pending):
            phase = .blocked(pendingCount: pending)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: pending)
        case .drained:
            CloudSyncRuntime.shared?.teardownGuestSession()
            // S2: re-verificar el outbox con la sesión AÚN viva (mismo racional que el camino .cloud).
            let residual = controller.livePendingUploadCount()
            guard residual == 0 else {
                phase = .blocked(pendingCount: residual)
                CloudSyncBreadcrumb.signOutPushBlocked(pending: residual)
                return
            }
            await CloudAuthService.shared.signOut()
            SecondarySessionStore.armWipe()
            CloudSyncBreadcrumb.signOutWipeArmed()
            phase = .awaitingRelaunch
        }
    }
}
