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
        /// El push-all no logró vaciar el outbox → cierre ABORTADO. `reason` distingue el
        /// error transitorio (reintentable, "un momento más") del permanente (sesión/conexión,
        /// H-2026-07-18-6). El usuario reintenta.
        case blocked(pendingCount: Int, reason: CloudSignOutFlowLogic.BlockReason)
        /// Camino `.cloud`/solo-grupos completo — cover de relaunch bloqueante hasta que el usuario reabra.
        case awaitingRelaunch
    }

    private(set) var phase: Phase = .idle

    /// `true` mientras el sign-out solo-grupos ESPERA a que se asienten writes pendientes
    /// (quiescencia del import + retry interno con presupuesto, H-2026-07-18-6). La fila de
    /// Ajustes muestra un caption honesto ("Guardando tus cambios pendientes…") — el bloqueo
    /// típico es transitorio y antes obligaba al usuario a tocar "Cerrar sesión" 2-3 veces.
    private(set) var waitingForPending: Bool = false

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
    /// **D-R1 paso 2: la precedencia se resuelve con la capacidad COMPILADA, no con el getter compuesto**
    /// (y `ProfileView.signOutRowPath` lee lo mismo — si divergieran, la UI ofrecería filas que este
    /// dispatch no honra y la hoja de alcance prometería lo contrario de lo que va a pasar).
    ///
    /// Con el compuesto, un kill remoto sobre un device `.icloud` con sesión de grupos VIVA lo manda a
    /// `.privateReset`, que cierra la sesión y no toca nada más. Eso deja tres cosas cruzando la frontera
    /// de humano: las filas de `GroupSyncOutbox` (que no tienen dueño — `pushPending` las sube con el
    /// bearer de la sesión que esté viva en ese momento), el consent de grupos (sin él, la cuenta
    /// siguiente no ve la pantalla y el canal subiría bajo un `user_id` que jamás consintió) y las filas
    /// `Split*` visibles del que se fue. El camino `.groupsOnlySignOut` es el único que limpia las tres.
    ///
    /// No hay riesgo de dejar al usuario encerrado: el transporte NO consulta el flag
    /// (`syncCycleOnce`/`pushPending` solo miran outbox y token), así que el push-all drena con el kill
    /// activo; y si aun así bloqueara, este mismo path es el que hace pintar la fila de escape
    /// «Salir de Yala en este dispositivo» (`rowLayout` → `.groupsSignOutPlusExitYala`), que no hace
    /// push-all y siempre completa. Con el compuesto bajo kill esa fila ni siquiera existe.
    func signOut(context: ModelContext) async {
        guard phase == .idle else { return }
        switch CloudSignOutFlowLogic.path(
            for: CloudSyncFlags.storageMode,
            secondarySessionActive: SecondarySessionStore.isActive(),
            hasLiveSession: CloudAuthService.shared.hasSession,
            groupsBackendEnabled: CloudSyncFlags.groupsBackendCompiledCapability
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

    /// D2 (§3.3.3): "Salir de Yala en este dispositivo" en el escenario privado+grupos con sesión
    /// backend ([FLAG], path resuelto = `.groupsOnlySignOut`). FUERZA el `.privateReset` directo — la
    /// precedencia NO se toca (daría `.groupsOnlySignOut`): vuelve al Welcome EN SESIÓN sin cover ni
    /// relaunch, cerrando la sesión backend y el canal de grupos (vía `performPrivateReset`).
    ///
    /// Decisión owner (2026-07-19, "encadenar cierre de grupos"): `.privateReset` deja las filas locales
    /// `Split*` del canal backend presentes (cierra la sesión pero no las purga). Para no dejarlas visibles
    /// e inertes tras re-entrar, encadenamos el cierre de grupos: purga IN-SESSION del cursor/outbox de
    /// grupos + `armGroupsOnlyWipe` (boot-wipe de los archivos `YalaGroups`), como UNIDAD.
    ///
    /// Por qué la purga del cursor/outbox es OBLIGATORIA junto al file-wipe (review adversarial D2): el
    /// boot-wipe borra SOLO los archivos de `YalaGroups` (los `Split*`), NUNCA `YalaSyncMeta` — donde viven
    /// `GroupSyncCursor`/`GroupSyncOutbox`. Un cursor por-grupo superviviente suprimiría el re-pull
    /// INCREMENTAL tras el wipe (el server solo devuelve `seq > cursor` ⇒ nada) → grupos invisibles al
    /// re-firmar + canario `groupMerkleDivergence` espurio (la señal que la puerta D9 lee como incidente);
    /// un dead-letter superviviente dejaría ese grupo invisible PERMANENTE (los guards del Merkle lo saltan).
    /// Espeja lo que `finalizeGroupsOnlyClose`/`closeLocalAfterAccountDeletionGroupsOnly` ya hacen — `exitYala`
    /// era el único armador que no purgaba, rompiendo la garantía "re-descargable del backend".
    ///
    /// GATE DE QUIESCENCIA (invariante b): la purga es un `save()` sobre el mainContext COMPARTIDO. Timeout ⇒
    /// NO purgamos NI armamos → las filas `Split*` quedan intactas (residual inerte CONSISTENTE: cursor válido
    /// + filas presentes ⇒ re-sincroniza normal al re-firmar; jamás salvar sobre un import a medio asentar).
    /// Purga+arm atómicos evitan la asimetría cursor-vs-wipe. Residual ratificado: re-entrada in-session
    /// ("Restaurar iCloud" sin cold boot) muestra las filas hasta el próximo boot; un re-sign-in de grupos
    /// DESARMA un wipe aún colgado (`GroupsBackendInviteModifier` → `clearGroupsOnlyWipeArm`).
    ///
    /// **D-R1 paso 2: capacidad COMPILADA.** El docblock anterior decía «gateado por el flag (no-op con
    /// flag OFF; jamás alcanzable ahí)», y con el compilado en `true` eso deja de ser un gate: el bloque
    /// corre siempre que alguien invoque la función. Es lo correcto, porque es el ÚNICO limpiador de tres
    /// superficies que nadie más toca en este camino — el consent (aquí no se arma el wipe personal, así
    /// que el hook de boot que lo limpia no corre, y el hook solo-grupos no lo limpia a propósito), el
    /// outbox sin dueño y el arm del olvido del store. Bajo un kill remoto, además, es MÁS seguro que
    /// antes: ningún ciclo puede repoblar cursor+filas entre la purga y el `signOut`, porque
    /// `startIfEligible`/`syncNowFromPush` sí leen el compuesto y retornan.
    func exitYalaOnThisDevice(context: ModelContext) async {
        guard phase == .idle else { return }
        if CloudSyncFlags.groupsBackendCompiledCapability {
            phase = .working
            if await Self.awaitPersonalQuiescenceForGroupsSignOut() {
                GroupsSyncClient.shared.teardownForSignOut()  // corta la generación antes de purgar (CR-3)
                Self.purgeGroupsSyncState(context: context)
                GroupsConsentState.clear()
                StorageModePersistence.armGroupsOnlyWipe()
                CloudSyncBreadcrumb.signOutGroupsOnlyWipeArmed()
            }
        }
        await performPrivateReset(breadcrumbPath: "exit-yala-groups-session")
    }

    private func performPrivateReset(breadcrumbPath: String = "private-reset") async {
        phase = .working
        CloudSyncBreadcrumb.signOutStarted(path: breadcrumbPath)

        // Teardown del runtime si existe (post-reversa / spikes): idempotente, purga espejo+prefs.
        CloudSyncRuntime.shared?.teardownGuestSession()
        // B2: canal de Grupos→backend — loop fuera + espejo App Group purgado (montos). Explícito AQUÍ
        // (no dentro de teardownGuestSession: el runtime personal no debe conocer grupos). Idempotente
        // y seguro con el flag OFF (no-ops).
        GroupsSyncClient.shared.teardownForSignOut()
        await PushTokenSignOutSeam.clearForSignOut()  // G8-2: desregistro best-effort del push token
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

    /// §5.2.1 — capa IN-SESSION de la limpieza de las superficies del SISTEMA que muestran datos de la
    /// cuenta saliente fuera de la app: notificaciones locales y widgets (defensa en profundidad; la red
    /// kill-safe sigue siendo el boot-cleanup `SwiftDataConfiguration.performSignOutWipeIfArmed`).
    ///
    /// El boot-hook no cubre la ventana entre el arm y el relanzamiento — que puede ser LARGA: el usuario
    /// se queda minutos en el cover terminal, o no vuelve a abrir la app nunca. Durante esa ventana un
    /// recordatorio de la cuenta cerrada puede sonar, y el widget de pantalla de inicio/bloqueo sigue
    /// pintando sus saldos y nombres de cuenta. Se invoca SIEMPRE DESPUÉS del arm, con el wipe ya
    /// comprometido y todos los guards pasados.
    ///
    /// Es BEST-EFFORT, no la garantía: el único camino en que estos datos vuelven a ser válidos es el
    /// abort S3 del boot-cleanup (si el archivo BASE no se pudo borrar, el store sobrevive; el reconciler
    /// reprograma las notificaciones —de hecho con `pending == 0` su heurística de conteo se cumple
    /// seguro— y el widget se repuebla en el próximo `WidgetDataCache` refresh). El reintento del wipe en
    /// el boot siguiente las vuelve a limpiar: la red kill-safe es el boot-hook.
    ///
    /// Por sí sola tampoco bastaría para las notificaciones: un `Task` no estructurado ya suspendido
    /// (p. ej. el de `AppBootstrapper.handleBecameActive`) puede reprogramar o entregar DESPUÉS de este
    /// punto. Lo cierra el guard del choke point en `NotificationService.isPersonalWipeArmed`, que se
    /// evalúa en el `add`.
    ///
    /// Exclusivo de los caminos que arman un wipe del store PERSONAL (`.cloud`, secundario M1 y el
    /// cierre local post-borrado de cuenta). Los caminos SOLO-GRUPOS y `.privateReset` NO lo llaman:
    /// ahí el store personal sobrevive, y tanto sus recordatorios como lo que pinta el widget siguen
    /// siendo legítimos.
    private func clearLocalSurfacesForArmedWipe() {
        NotificationService.shared.cancelAllNotifications()
        NotificationService.shared.clearDeliveredNotifications()
        // `clearCache()` ya dispara `WidgetCenter.reloadAllTimelines()` ⇒ el widget se redibuja vacío
        // sin esperar al relanzamiento. El boot-cleanup lo repite (vía `DataWipeService.resetForSignOutWipe`).
        WidgetDataCache.clearCache()
        CloudSyncBreadcrumb.signOutNotificationsCleared()
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
            phase = .blocked(pendingCount: 0, reason: .permanent)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: 0)
            return
        }

        // 1) Push-all PERSONAL — bloquear si no drena (jamás descartar). El camino `.cloud`
        // conserva su alert de siempre ("conexión"): `reason: .permanent` (byte-idéntico —
        // H-2026-07-18-6 ajusta SOLO el path solo-grupos, no éste).
        switch await controller.pushAllPendingForSignOut() {
        case .blocked(let pending, _):
            phase = .blocked(pendingCount: pending, reason: .permanent)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: pending)
            return
        case .drained:
            break
        }

        // 2) Push-all GRUPOS (cierra LOW-3 de B2) — ANTES del teardown (la guardia de generación
        // abortaría el ciclo). Blocked ⇒ abort idéntico al personal.
        switch await pushAllPendingGroupsForSignOut(context: context) {
        case .blocked(let pending, _):
            phase = .blocked(pendingCount: pending, reason: .permanent)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: pending)
            return
        case .drained:
            break
        }

        // 3) Teardown: primero el motor personal (epoch++ aborta ciclos en vuelo), luego el canal de grupos.
        CloudSyncRuntime.shared?.teardownGuestSession()
        GroupsSyncClient.shared.teardownForSignOut()
        await PushTokenSignOutSeam.clearForSignOut()  // G8-2: desregistro best-effort del push token

        // 4) S2 del review: re-verificar AMBOS outboxes tras cortar los motores y ANTES de soltar
        // credenciales — si un save concurrente encoló filas durante el push-all, se bloquea con la
        // sesión AÚN viva (reintentar funciona). Residual documentado: writes que queden solo en
        // History (sin drain post-teardown) mueren con el wipe.
        let residualPersonal = controller.livePendingUploadCount()
        let residualGroups = Self.liveGroupsPendingCount(context: context)
        let residual = residualPersonal + residualGroups
        guard residual == 0 else {
            phase = .blocked(pendingCount: residual, reason: .permanent)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: residual)
            return
        }

        await CloudAuthService.shared.signOut()

        // 5) CR-4: marker ANTES del arm (el arm es el DISPARADOR, va ÚLTIMO). Kill entre marker y arm =
        // no-op re-armable; kill entre arm y marker habría dejado un wipe personal SIN grupos.
        //
        // D-R1 paso 2: capacidad COMPILADA. El boot-hook ya borra INCONDICIONALMENTE la otra mitad del
        // canal backend — `YalaSyncMeta` muere en el guard S3, y ahí viven `GroupSyncOutbox` y
        // `GroupSyncCursor` —, así que con el compuesto y un kill activo el estado resultante sería el par
        // incoherente «filas de grupos RETENIDAS + cursor DESTRUIDO». Y `SplitGroup` no tiene ningún campo
        // de scoping por usuario: en un device que este mismo hook devuelve a "recién instalado", la cuenta
        // SIGUIENTE vería los grupos, miembros y montos de la anterior, sin nada que los retire después (el
        // pull del backend solo trae SU corpus y no emite tombstones de filas ajenas). El hermano de este
        // marker —el clear del consent en el boot-hook— ya eligió esta misma inmunidad al kill, y su
        // comentario nombra literalmente el hueco que quedaba aquí.
        if CloudSyncFlags.groupsBackendCompiledCapability {
            StorageModePersistence.markSignOutWipeIncludesGroups()
        }
        StorageModePersistence.armSignOutWipe()
        CloudSyncBreadcrumb.signOutWipeArmed()
        clearLocalSurfacesForArmedWipe()
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
            phase = .blocked(pendingCount: 0, reason: .permanent)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: 0)
            return
        }

        // Secundaria (M1) conserva su alert de siempre: `reason: .permanent` (byte-idéntico).
        switch await controller.pushAllPendingForSignOut() {
        case .blocked(let pending, _):
            phase = .blocked(pendingCount: pending, reason: .permanent)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: pending)
        case .drained:
            CloudSyncRuntime.shared?.teardownGuestSession()
            // B2: canal de Grupos→backend — loop fuera + espejo purgado (en secundaria el canal ni corre,
            // pero el teardown es idempotente y la purga del espejo es red M1 obligatoria).
            GroupsSyncClient.shared.teardownForSignOut()
            await PushTokenSignOutSeam.clearForSignOut()  // G8-2: desregistro best-effort del push token
            // S2: re-verificar el outbox con la sesión AÚN viva (mismo racional que el camino .cloud).
            let residual = controller.livePendingUploadCount()
            guard residual == 0 else {
                phase = .blocked(pendingCount: residual, reason: .permanent)
                CloudSyncBreadcrumb.signOutPushBlocked(pending: residual)
                return
            }
            await CloudAuthService.shared.signOut()
            SecondarySessionStore.armWipe()
            CloudSyncBreadcrumb.signOutWipeArmed()
            clearLocalSurfacesForArmedWipe()
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
        waitingForPending = false
        CloudSyncBreadcrumb.signOutStarted(path: "icloud-groups-session")
        // Salir por CUALQUIER camino apaga el caption de espera (regla del @Observable).
        defer { waitingForPending = false }

        // RETRY INTERNO CON PRESUPUESTO GLOBAL (H-2026-07-18-6): el device-QA mostró que el bloqueo
        // típico de este path es TRANSITORIO (writes INTERNOS del boot aún asentándose — no hay nada
        // que el usuario pueda hacer salvo esperar) y el usuario terminaba tocando "Cerrar sesión"
        // 2-3 veces hasta que "pegaba". Ahora reintentamos internamente los transitorios dentro de un
        // presupuesto (segundos ADICIONALES tras el PRIMER bloqueo); los permanentes (sesión/cuenta)
        // se muestran de inmediato. `retryClockStart` arranca en el primer bloqueo transitorio; en los
        // reintentos el gate de quiescencia recibe un hardCap = lo que queda del presupuesto (jamás
        // vuelve a bloquear 60s completos). La DECISIÓN es pura (`GroupsSignOutRetryDecision`); aquí
        // solo se mide el tiempo real con `Date()` (orquestador de servicio, fuera del test target).
        let budget = GroupsSignOutRetryDecision.budgetSeconds
        var retryClockStart: Date?

        while true {
            let hardCap: TimeInterval = retryClockStart
                .map { max(0, budget - Date().timeIntervalSince($0)) } ?? 60

            switch await attemptGroupsOnlyClose(context: context, quiescenceHardCap: hardCap) {
            case .drained:
                // Reusa la red terminal existente (cover + RelaunchNetLogic + exit(0) en background):
                // la matriz de blockers opera por la FASE VIVA (no por storageMode).
                await finalizeGroupsOnlyClose(context: context)
                return
            case .blocked(let pending, let reason):
                let elapsed = retryClockStart.map { Date().timeIntervalSince($0) } ?? 0
                switch GroupsSignOutRetryDecision.decide(
                    elapsedSeconds: elapsed, budgetSeconds: budget, reason: reason
                ) {
                case .surfacePermanent:
                    phase = .blocked(pendingCount: pending, reason: .permanent)
                    CloudSyncBreadcrumb.signOutPushBlocked(pending: pending)
                    return
                case .surfaceTransient:
                    phase = .blocked(pendingCount: pending, reason: .transient)
                    CloudSyncBreadcrumb.signOutPushBlocked(pending: pending)
                    return
                case .retryAfter(let seconds):
                    if retryClockStart == nil { retryClockStart = Date() }
                    waitingForPending = true
                    do {
                        try await Task.sleep(for: .seconds(seconds))
                    } catch {
                        // Cancelación del caller → fail-closed transitorio (reintentable).
                        phase = .blocked(pendingCount: pending, reason: .transient)
                        return
                    }
                    continue
                }
            }
        }
    }

    /// UN intento del cierre solo-grupos: gate de QUIESCENCIA (hardCap acotado en reintentos) +
    /// push-all VERIFICADO del outbox de grupos. NO hace teardown ni toca credenciales — eso es
    /// `finalizeGroupsOnlyClose`, que corre UNA sola vez tras `.drained` (reintentar tras el teardown
    /// repoblaría el outbox/cursor). Gate de quiescencia (HIGH del review lente-personal): el path
    /// corre en `.icloud` con el mirror personal VIVO y el mainContext COMPARTIDO por los 3 stores;
    /// TODO save de este flujo (drain del push-all, purga) flushearía también el grafo personal → con
    /// un import a medio asentar dispara el `_assertionFailure` de SwiftData (trap no atrapable, clase
    /// del crash-loop de restore). Timeout ⇒ `.blocked(reason: .transient)` (store no quieto AÚN —
    /// reintentable; jamás salvar sobre un import a medio asentar).
    private func attemptGroupsOnlyClose(
        context: ModelContext,
        quiescenceHardCap: TimeInterval
    ) async -> CloudSignOutFlowLogic.PushAllVerdict {
        // El caption de espera cubre TAMBIÉN la quiescencia del PRIMER intento (en un restore puede
        // bloquear hasta 60s — exactamente la ventana del hallazgo H-6; sin esto el spinner corre mudo).
        waitingForPending = true
        guard await Self.awaitPersonalQuiescenceForGroupsSignOut(hardCap: quiescenceHardCap) else {
            return .blocked(
                pendingCount: Self.liveGroupsPendingCount(context: context), reason: .transient)
        }
        // Push-all de grupos con la generación INTACTA (antes del teardown).
        return await pushAllPendingGroupsForSignOut(context: context)
    }

    /// Cierre EFECTIVO del canal solo-grupos tras `.drained` (orden CONGELADO, CR-3): teardown del
    /// canal (stop loop + generation++ aborta ciclos en vuelo + purga espejo) → purga IN-SESSION del
    /// outbox/cursor de grupos (TODAS las filas, incl. dead-letters; sync-meta es `.none` ⇒ sin replay
    /// de History hacia iCloud, y el `save()` va al mainContext compartido ⇒ cubierto por el gate de
    /// quiescencia ya pasado) → limpieza del consent (CR-2: sin ello `applyRemoteValues()` del próximo
    /// boot lo resucitaría) → signOut backend → marker ÚLTIMO write (kill-safe: el boot borra SOLO el
    /// store de grupos; NO toca personal/sync-meta, onboarding, prefs personales ni storageMode — el
    /// device sigue en `.icloud`). Residual documentado: kill entre signOut() y el arm deja las filas
    /// Split* de la sesión muerta visibles transitoriamente hasta el próximo sign-in/out (outbox ya
    /// purgado — sin leak de sync).
    private func finalizeGroupsOnlyClose(context: ModelContext) async {
        GroupsSyncClient.shared.teardownForSignOut()
        await PushTokenSignOutSeam.clearForSignOut()  // G8-2: desregistro best-effort del push token
        Self.purgeGroupsSyncState(context: context)
        GroupsConsentState.clear()
        await CloudAuthService.shared.signOut()
        // D2 (§3.3.3): arma el banner one-shot de re-entrada — al reabrir, el empty state H-7 del tab
        // Grupos lo muestra ("Cerraste tu sesión de grupos…"). In-session ⇒ sobrevive el relaunch (vive
        // en UserDefaults). SOLO en el sign-out de grupos, NO tras borrar cuenta (ahí no hay "vuelve a
        // iniciar sesión"). Se quema en el `onAppear` del banner real.
        GroupsSignOutBannerMarker.markPending()
        // §5.2.1 — los banners de grupo YA ENTREGADOS apuntarán a un store que el boot borra. Se retiran
        // AQUÍ (in-session, con `await` disponible) y no solo en el boot-hook: allí la lectura de entregadas
        // es async y solo puede encolarse en un `Task` que el arm —ya limpiado— deja de respaldar. NUNCA las
        // personales: en este camino los datos personales sobreviven intactos.
        await NotificationService.shared.clearDeliveredGroupNotifications()
        StorageModePersistence.armGroupsOnlyWipe()
        CloudSyncBreadcrumb.signOutGroupsOnlyWipeArmed()
        phase = .awaitingRelaunch
    }

    // MARK: - Cierre LOCAL tras un borrado de cuenta (G5-D1b) — SIN push-all

    /// Cierre LOCAL del camino `.cloud` tras un `delete_personal_account` EXITOSO server-side. A diferencia
    /// de `performCloudSecureSignOut` NO hay push-all NI re-verify de outbox: los datos YA murieron en el
    /// backend, no hay nada que preservar (subirlos sería un corpus-zombie). Métodos DEDICADOS (no un
    /// `skipPushAll` sobre el sign-out) para NO tocar el código de sign-out — su garantía flag-OFF
    /// byte-idéntica queda intacta. Mismo tail-end kill-safe: marker `includesGroups` PRIMERO (solo con el
    /// flag ON), `armSignOutWipe` ÚLTIMO (disparador). Reusa el cover terminal por FASE VIVA
    /// (`.awaitingRelaunch`) — cero red duplicada. El `AccountDeletionService` ya corrió los teardowns
    /// antes del borrado; aquí se re-ejecutan por idempotencia (self-contained, correcto si se invoca solo).
    func closeLocalAfterAccountDeletionCloud() async {
        phase = .working
        CloudSyncBreadcrumb.signOutStarted(path: "account-delete-cloud")

        // Higiene molde `performCloudSecureSignOut`: limpiar un marker `includesGroups` huérfano.
        StorageModePersistence.clearSignOutWipeIncludesGroups()

        // Teardowns idempotentes (paran los loops; ya corridos por el service, re-ejecutar es no-op seguro).
        CloudSyncRuntime.shared?.teardownGuestSession()
        GroupsSyncClient.shared.teardownForSignOut()
        await PushTokenSignOutSeam.clearForSignOut()  // G8-2: desregistro best-effort del push token

        await CloudAuthService.shared.signOut()

        // Marker ANTES del arm (kill-safe), con la capacidad COMPILADA — mismo getter y mismo racional
        // que su gemelo de `performCloudSecureSignOut`, y aquí con un agravante: la sesión ya está muerta
        // y las filas del servidor ya no existen, así que un residuo local no lo refresca ni lo retira
        // NADA nunca. Condicionarlo al término remoto sería condicionar una limpieza irreversible a una
        // señal que no es testigo del corpus (fail-closed sin snapshot, snapshot corrupto, bucket de
        // rollout). Ojo con el alcance: lo que cumple la obligación GDPR es `groups_forget_user` +
        // `POST /account/delete`, ya ejecutados al llegar aquí; este marker decide sobre la copia LOCAL.
        if CloudSyncFlags.groupsBackendCompiledCapability {
            StorageModePersistence.markSignOutWipeIncludesGroups()
        }
        StorageModePersistence.armSignOutWipe()
        CloudSyncBreadcrumb.signOutWipeArmed()
        clearLocalSurfacesForArmedWipe()
        phase = .awaitingRelaunch
    }

    /// Cierre LOCAL del camino solo-grupos tras un `delete_personal_account` EXITOSO. Espeja el tail-end de
    /// `performGroupsOnlySignOut` SIN el push-all (datos muertos server-side). El GATE DE QUIESCENCIA es
    /// OBLIGATORIO: la purga in-session salva al mainContext COMPARTIDO por los 3 stores (mismo trap de
    /// SwiftData que en el sign-out solo-grupos). Timeout ⇒ devuelve `false` SIN cerrar la sesión ni armar
    /// nada — el caller marca fallo y el usuario reintenta (`groups_forget_user`/`/account/delete` son
    /// idempotentes; los teardowns también). Éxito ⇒ arma `groupsOnlyWipeArmed`, entra en
    /// `.awaitingRelaunch` (reusa el cover terminal) y devuelve `true`.
    func closeLocalAfterAccountDeletionGroupsOnly(context: ModelContext) async -> Bool {
        phase = .working
        CloudSyncBreadcrumb.signOutStarted(path: "account-delete-groups-only")

        guard await Self.awaitPersonalQuiescenceForGroupsSignOut() else {
            let pending = Self.liveGroupsPendingCount(context: context)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: pending)
            phase = .idle  // jamás dejar el coordinador pegado en `.working`; el service marca el fallo.
            return false
        }

        // Teardown del canal (idempotente) → purga in-session (bajo el gate de quiescencia) → consent.
        GroupsSyncClient.shared.teardownForSignOut()
        await PushTokenSignOutSeam.clearForSignOut()  // G8-2: desregistro best-effort del push token
        Self.purgeGroupsSyncState(context: context)
        GroupsConsentState.clear()

        await CloudAuthService.shared.signOut()

        StorageModePersistence.armGroupsOnlyWipe()
        CloudSyncBreadcrumb.signOutGroupsOnlyWipeArmed()
        phase = .awaitingRelaunch
        return true
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
        // (teardown + wipe del store). Drenar primero hace honesto el conteo.
        //
        // D-R1 paso 2: capacidad COMPILADA, y aquí el motivo NO es "limpiar aunque el canal esté
        // apagado" sino que el término remoto nunca protegió nada. El gate compuesto solo compraba un
        // no-op cuando el outbox YA estaba vacío: con una sola fila viva el pre-check de abajo no corta,
        // el loop entra y `syncCycleOnce` drena + empuja igual, porque el transporte no consulta el flag.
        // Honraba el kill exactamente cuando no había nada en juego. Lo que este gate sí protege —"un
        // build sin canal compilado no toca nada"— lo da EXACTAMENTE el término compilado; su propio
        // comentario anterior lo delataba al describir el caso como «flag OFF (path .cloud sin backend
        // de grupos)», que es la definición del compilado, no la del kill. Y no drenar aquí no difiere
        // nada: los dos boot-wipes borran los archivos donde vive la History del canal, así que lo no
        // drenado se destruye. La partición del drain sigue siendo por `isBackendGroup`, así que en un
        // device sin grupos backend esto produce cero filas.
        if CloudSyncFlags.groupsBackendCompiledCapability {
            GroupsSyncClient.shared.drainOnce(context: context)
        }
        if Self.liveGroupsPendingCount(context: context) == 0 { return .drained }
        for iteration in 1...maxIterations {
            let outcome = await GroupsSyncClient.shared.syncCycleOnceCoalesced(context: context)
            if let verdict = CloudSignOutFlowLogic.pushAllVerdict(
                livePendingCount: Self.liveGroupsPendingCount(context: context),
                cycleOutcome: outcome,
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
        // Fuera del loop solo por cancelación (break): transitorio (reintentable).
        return .blocked(pendingCount: Self.liveGroupsPendingCount(context: context), reason: .transient)
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
