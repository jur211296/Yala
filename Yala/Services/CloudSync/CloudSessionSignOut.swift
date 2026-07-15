//
//  CloudSessionSignOut.swift
//  Yala
//
//  Coordinador del "Cerrar sesión" universal (H4, decisión owner 2026-07-12; G5-B añade la fila
//  solo-grupos). Vive FUERA de CloudMigrationController a propósito: el camino privado debe funcionar
//  con el backend NO configurado (prod DARK), donde `CloudMigrationController.shared` es nil.
//
//  Caminos (CloudSignOutFlowLogic.path):
//  - `.privateReset` (.icloud, sin sesión backend): NO toca datos — teardown si hay runtime, signOut
//    local (idempotente, no-op sin backend), reset de onboarding → ContentView re-presenta el Welcome
//    vía su onChange. Re-entrada: "Ya tengo cuenta → Restaurar iCloud".
//  - `.cloudSecureSignOut` (.cloud): push-all VERIFICADO personal + GRUPOS (jamás descartar) →
//    teardown + signOut → armar el wipe de boot (personal+sync-meta, y grupos si el flag ON) →
//    pantalla de relaunch asistido (NUNCA auto-kill). El cleanup destructivo corre en el BOOT.
//  - `.groupsOnlySignOut` (.icloud + sesión backend viva, flag ON): cierra SOLO la sesión de grupos —
//    push-all de grupos → teardown del canal → purga in-session del outbox/cursor de grupos → limpieza
//    del consent → signOut → wipe ARMADO del store de grupos al boot. Los datos personales no se tocan.
//

import Foundation
import SwiftData

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
        /// Camino `.cloud`/solo-grupos completo — cover de relaunch bloqueante hasta que el usuario reabra.
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

    /// `context` (CR-1 del review): el coordinador NO tiene ModelContext propio; `ProfileView` (que ya
    /// tiene `@Environment(\.modelContext)`) lo pasa. Se usa para el push-all/purga del canal de Grupos
    /// (su outbox/cursor viven en el store sync-meta, alcanzable por el mainContext compartido).
    func signOut(context: ModelContext) async {
        guard phase == .idle else { return }
        switch CloudSignOutFlowLogic.path(
            for: CloudSyncFlags.storageMode,
            secondarySessionActive: SecondarySessionStore.isActive(),
            hasLiveSession: CloudAuthService.shared.hasSession,
            groupsBackendEnabled: CloudSyncFlags.groupsBackendEnabled
        ) {
        case .privateReset:
            await performPrivateReset()
        case .cloudSecureSignOut:
            await performCloudSecureSignOut(context: context)
        case .secondaryCloudSignOut:
            await performSecondaryCloudSignOut()
        case .groupsOnlySignOut:
            await performGroupsOnlySignOut(context: context)
        }
    }

    // MARK: - Camino privado (.icloud) — datos intactos

    private func performPrivateReset() async {
        phase = .working
        CloudSyncBreadcrumb.signOutStarted(path: "private-reset")

        // Teardown del runtime si existe (post-reversa / spikes): idempotente, purga espejo+prefs.
        CloudSyncRuntime.shared?.teardownGuestSession()
        // B2: canal de Grupos→backend — loop fuera + espejo App Group purgado (montos). Explícito AQUÍ
        // (no dentro de teardownGuestSession: el runtime personal no debe conocer grupos). Idempotente
        // y seguro con el flag OFF (no-ops).
        GroupsSyncClient.shared.teardownForSignOut()
        PushTokenSignOutSeam.clearForSignOut()  // G8 (no-op hoy)
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

    private func performCloudSecureSignOut(context: ModelContext) async {
        phase = .working
        CloudSyncBreadcrumb.signOutStarted(path: "cloud-secure")

        // LOW-1 del review: un marker `includesGroups` HUÉRFANO (marker-set → kill sin arm en una
        // corrida previa, con el flag ya apagado) sobreviviría y haría que ESTE sign-out borre el
        // store de grupos sin pedirlo. Limpiarlo incondicional al entrar; se re-escribe abajo si
        // este sign-out sí lo pide (flag ON).
        StorageModePersistence.clearSignOutWipeIncludesGroups()

        // En `.cloud` el backend está configurado por definición (solo el cutover/adopt
        // escriben ese modo); si el controller faltara, solo es seguro cerrar sin pendientes.
        guard let controller = CloudMigrationController.shared else {
            phase = .blocked(pendingCount: 0)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: 0)
            return
        }

        // 1) Push-all PERSONAL — bloquear si no drena (jamás descartar).
        switch await controller.pushAllPendingForSignOut() {
        case .blocked(let pending):
            phase = .blocked(pendingCount: pending)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: pending)
            return
        case .drained:
            break
        }

        // 2) Push-all GRUPOS (cierra LOW-3 de B2) — ANTES del teardown (la guardia de generación
        // abortaría el ciclo). Blocked ⇒ abort idéntico al personal.
        switch await pushAllPendingGroupsForSignOut(context: context) {
        case .blocked(let pending):
            phase = .blocked(pendingCount: pending)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: pending)
            return
        case .drained:
            break
        }

        // 3) Teardown: primero el motor personal (epoch++ aborta ciclos en vuelo), luego el canal de grupos.
        CloudSyncRuntime.shared?.teardownGuestSession()
        GroupsSyncClient.shared.teardownForSignOut()
        PushTokenSignOutSeam.clearForSignOut()  // G8 (no-op hoy)

        // 4) S2 del review: re-verificar AMBOS outboxes tras cortar los motores y ANTES de soltar
        // credenciales — si un save concurrente encoló filas durante el push-all, se bloquea con la
        // sesión AÚN viva (reintentar funciona). Residual documentado: writes que queden solo en
        // History (sin drain post-teardown) mueren con el wipe.
        let residualPersonal = controller.livePendingUploadCount()
        let residualGroups = Self.liveGroupsPendingCount(context: context)
        let residual = residualPersonal + residualGroups
        guard residual == 0 else {
            phase = .blocked(pendingCount: residual)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: residual)
            return
        }

        await CloudAuthService.shared.signOut()

        // 5) CR-4: marker ANTES del arm (el arm es el DISPARADOR, va ÚLTIMO). Kill entre marker y arm =
        // no-op re-armable; kill entre arm y marker habría dejado un wipe personal SIN grupos. El marker
        // SOLO con el flag ON ⇒ con flag OFF el boot hook es byte-idéntico (jamás borra el store de grupos).
        if CloudSyncFlags.groupsBackendEnabled {
            StorageModePersistence.markSignOutWipeIncludesGroups()
        }
        StorageModePersistence.armSignOutWipe()
        CloudSyncBreadcrumb.signOutWipeArmed()
        phase = .awaitingRelaunch
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
            // B2: canal de Grupos→backend — loop fuera + espejo purgado (en secundaria el canal ni corre,
            // pero el teardown es idempotente y la purga del espejo es red M1 obligatoria).
            GroupsSyncClient.shared.teardownForSignOut()
            PushTokenSignOutSeam.clearForSignOut()  // G8 (no-op hoy)
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

    // MARK: - Camino solo-grupos (G5-B) — cierra la sesión de grupos, datos personales intactos

    /// Sesión backend viva + personal `.icloud` (flag ON). Orden CONGELADO (CR-3: teardown ANTES de
    /// purgar filas — un ciclo en vuelo repoblaría el outbox/cursor tras la purga). El store de grupos
    /// se borra por ARCHIVOS al boot (nunca un store montado; nunca filas in-session como sustituto:
    /// History + semántica re-descargable limpia).
    private func performGroupsOnlySignOut(context: ModelContext) async {
        phase = .working
        CloudSyncBreadcrumb.signOutStarted(path: "groups-only")

        // 1) GATE DE QUIESCENCIA (HIGH del review lente-personal): este path corre con el device en
        // `.icloud` — el mirror personal de CloudKit está VIVO y el mainContext es COMPARTIDO por los
        // 3 stores. TODO save de este flujo (drain del push-all, purga de outbox/cursores) flushearía
        // también el grafo personal: con un import a medio asentar eso dispara el `_assertionFailure`
        // de SwiftData (trap no atrapable — la regla del crash-loop de restore). Mismo invariante que
        // `awaitPersonalImportForBootSave`; en operación normal retorna de inmediato. Timeout ⇒
        // fail-closed como `.blocked` (reintentar luego), jamás proceder sobre un store no quieto.
        guard await Self.awaitPersonalQuiescenceForGroupsSignOut() else {
            let pending = Self.liveGroupsPendingCount(context: context)
            phase = .blocked(pendingCount: pending)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: pending)
            return
        }

        // 2) Push-all de grupos con la generación INTACTA (antes del teardown). Blocked ⇒ abort.
        switch await pushAllPendingGroupsForSignOut(context: context) {
        case .blocked(let pending):
            phase = .blocked(pendingCount: pending)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: pending)
            return
        case .drained:
            break
        }

        // 3) Teardown del canal: stop loop + generation++ (aborta cualquier ciclo en vuelo) + purga espejo.
        GroupsSyncClient.shared.teardownForSignOut()
        PushTokenSignOutSeam.clearForSignOut()  // G8 (no-op hoy)

        // 4) Purga IN-SESSION del outbox + cursor de grupos (TODAS las filas, incl. dead-letters). Razón
        // congelada: el archivo YalaSyncMeta NO se borra en esta fila (es personal); filas huérfanas de la
        // sesión muerta podrían drenarse bajo la SIGUIENTE cuenta (leak cross-cuenta). Dos riesgos DISTINTOS
        // cubiertos: (a) sync-meta es `.none` ⇒ sin replay de History hacia iCloud; (b) el `save()` va al
        // mainContext COMPARTIDO con el store personal ⇒ lo cubre el gate de quiescencia del paso 1 (sin
        // él, un import personal en vuelo + este save = trap de SwiftData).
        Self.purgeGroupsSyncState(context: context)

        // 6) Limpiar el consent de grupos (CR-2: sin limpiar el iKV, `applyRemoteValues()` del próximo boot
        // resucitaría el consent).
        GroupsConsentState.clear()

        // 7) Cerrar la sesión backend.
        await CloudAuthService.shared.signOut()

        // 8) Marker ÚLTIMO write (kill-safe). El boot borra SOLO el store de grupos; NO toca personal/
        // sync-meta, onboarding, prefs personales ni storageMode (el device sigue en `.icloud`).
        // Residual documentado: kill entre signOut() y el arm deja las filas Split* de la sesión muerta
        // visibles transitoriamente hasta el próximo sign-in/sign-out (outbox ya purgado — sin leak de sync).
        StorageModePersistence.armGroupsOnlyWipe()
        CloudSyncBreadcrumb.signOutGroupsOnlyWipeArmed()

        // 9) Reusa la red terminal existente (cover + RelaunchNetLogic + exit(0) en background): la matriz
        // de blockers opera por la FASE VIVA (no por storageMode); el copy del cover es genérico ("reinicia
        // Yala"), aplicable sin cambios.
        phase = .awaitingRelaunch
    }

    // MARK: - Helpers del canal de Grupos (G5-B)

    /// Push-all VERIFICADO del outbox de GRUPOS (molde `CloudMigrationController.pushAllPendingForSignOut`):
    /// cicla `GroupsSyncClient.syncCycleOnceCoalesced` hasta que el outbox VIVO (no dead-letter) quede en 0
    /// verificado por fetch, o bloquea. Dead-letters (`rejectedReason != nil`) NO bloquean (son permanentes
    /// — igual que el personal excluye rejected). Pre-check `== 0`: con outbox vacío (flag OFF / sin grupos)
    /// devuelve `.drained` SIN ciclar (no-op real — cero red). DEBE correr ANTES de `teardownForSignOut`
    /// (la guardia de generación abortaría el ciclo).
    private func pushAllPendingGroupsForSignOut(
        context: ModelContext,
        maxIterations: Int = 20
    ) async -> CloudSignOutFlowLogic.PushAllVerdict {
        // SEV-2 del review lente-grupos: outbox vacío ≠ History drenada. En el path solo-grupos este
        // helper es lo PRIMERO que corre (sin ciclo previo que drene) — una mutación hecha segundos
        // antes del sign-out aún vive SOLO en History; el pre-check sin drenar la perdería para siempre
        // (teardown + wipe del store). Drenar primero hace honesto el conteo. Gateado por flag: con
        // flag OFF (path `.cloud` sin backend de grupos) queda solo el fetchCount read-only de siempre
        // (performDrain crearía cursor/save — no-op estricto preservado).
        if CloudSyncFlags.groupsBackendEnabled {
            GroupsSyncClient.shared.drainOnce(context: context)
        }
        if Self.liveGroupsPendingCount(context: context) == 0 { return .drained }
        for iteration in 1...maxIterations {
            let outcome = await GroupsSyncClient.shared.syncCycleOnceCoalesced(context: context)
            let succeeded = outcome == .completed || outcome == .coalesced
            if let verdict = CloudSignOutFlowLogic.pushAllVerdict(
                livePendingCount: Self.liveGroupsPendingCount(context: context),
                cycleSucceeded: succeeded,
                iteration: iteration,
                maxIterations: maxIterations
            ) {
                return verdict
            }
            // S1: un ciclo de la cadencia EN VUELO devuelve `.coalesced` SINCRÓNICO — la pausa deja
            // terminar el ciclo en vuelo; sin ella el loop quemaría las 20 iteraciones en microsegundos.
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                break  // cancelación del caller
            }
        }
        return .blocked(pendingCount: Self.liveGroupsPendingCount(context: context))
    }

    /// Gate de quiescencia del import PERSONAL para el sign-out solo-grupos (HIGH del review): el path
    /// corre en `.icloud` con el mirror CloudKit VIVO y todo save va al mainContext compartido. Mismo
    /// invariante que `awaitPersonalImportForBootSave` (AppBootstrapper): seguro = sin cuenta iCloud, O
    /// primer import completado Y quiescente (`isImportQuiescent` a secas es true ANTES de que el import
    /// arranque — señal prematura en un restore). Poll 2s, tope 60s (en operación normal retorna al
    /// instante). `false` ⇒ el caller falla CERRADO (.blocked, reintentable) — jamás salvar sobre un
    /// store a medio importar.
    static func awaitPersonalQuiescenceForGroupsSignOut(
        pollInterval: TimeInterval = 2,
        hardCap: TimeInterval = 60
    ) async -> Bool {
        func safe() -> Bool {
            !iCloudSyncService.shared.isAccountAvailable
                || (iCloudSyncService.shared.hasCompletedFirstImport
                    && iCloudSyncService.shared.isImportQuiescent)
        }
        var waited: TimeInterval = 0
        while !safe() && waited < hardCap {
            do {
                try await Task.sleep(for: .seconds(pollInterval))
            } catch {
                return false  // cancelación del caller — fail-closed
            }
            waited += pollInterval
        }
        return safe()
    }

    /// Filas VIVAS (no dead-letter) del outbox de GRUPOS agregadas sobre TODOS los grupos. Cero → seguro
    /// proceder al cierre. `Int.max` conservador si el fetch falla (jamás habilitar un cierre con pendientes).
    static func liveGroupsPendingCount(context: ModelContext) -> Int {
        do {
            return try context.fetchCount(FetchDescriptor<GroupSyncOutbox>(
                predicate: #Predicate { $0.rejectedReason == nil }))
        } catch {
            #if DEBUG
            print("CloudSessionSignOut: Error contando outbox de grupos vivo: \(error)")
            #endif
            return Int.max
        }
    }

    /// Purga IN-SESSION del estado de sync de GRUPOS (outbox COMPLETO incl. dead-letters + cursor). Solo se
    /// invoca en el camino solo-grupos, tras el teardown (generación cortada). Sync-meta es `.none` — sin
    /// mirror ⇒ los deletes de filas no se replayan a iCloud. Cero-silencios: do/catch con log. `static`
    /// (no usa estado de instancia) para ser directamente testeable.
    static func purgeGroupsSyncState(context: ModelContext) {
        do {
            let outbox = try context.fetch(FetchDescriptor<GroupSyncOutbox>())
            for row in outbox { context.delete(row) }
            let cursors = try context.fetch(FetchDescriptor<GroupSyncCursor>())
            for cursor in cursors { context.delete(cursor) }
            try context.save()
        } catch {
            #if DEBUG
            print("CloudSessionSignOut: Error purgando estado de sync de grupos: \(error)")
            #endif
        }
    }
}
