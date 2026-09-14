//
//  CloudSessionSignOut.swift
//  Yala
//
//  Coordinador del "Cerrar sesión" (H4, decisión owner 2026-07-12; un verbo por sesión desde el paso 9 del
//  rediseño, ADR 2026-09-09 «Sesiones — dos ejes» §5). Vive FUERA de CloudMigrationController a propósito:
//  el camino privado debe funcionar con el backend NO configurado, donde `CloudMigrationController.shared`
//  es nil.
//
//  Todas las salidas dejan el dispositivo como recién instalado por el MISMO boot-wipe de archivos
//  (`armSignOutWipe` → `SwiftDataConfiguration.performSignOutWipeIfArmed`, que arma el neutro duradero);
//  lo que cambia por celda es qué se sube antes (CloudSignOutFlowLogic.path):
//  - `.privateSignOut` (C): espera a que el último cambio llegue a iCloud → borra personal + sync-meta.
//    iCloud intacto; «entrar» es «Restaurar desde iCloud».
//  - `.privateWithGroupsSignOut` (D, «equipo»): push-all de grupos → espera del export → cierra la sesión
//    de grupos → borra personal + sync-meta + grupos.
//  - `.cloudSecureSignOut` (E): push-all VERIFICADO personal + grupos (jamás descartar) → teardown +
//    signOut → borra personal + sync-meta (+ grupos).
//  - `.groupsOnlySignOut` (F): push-all de grupos → cierra la sesión → borra personal + sync-meta + grupos.
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

    /// Cómo terminó un `detachGroupsAccount`. **Un valor de retorno y no un case de `Phase`**: ver el
    /// docblock de ese método.
    enum DetachOutcome: Equatable {
        /// La cuenta se soltó y el dominio Grupos ya no está en este teléfono.
        case detached
        /// No se soltó nada, y no se escribió nada irreversible. La fase queda en `.blocked` con su
        /// motivo y la pantalla lo lee de ahí, como antes. **No se llama `blockedByPush` a propósito**:
        /// cubre también el abort por un puente que no se pudo ni mirar, que no tiene nada que ver con
        /// subir cambios — y con ese nombre el mensaje que salía («quedan cambios sin subir, inténtalo en
        /// un momento») describía un problema que no era y daba un consejo que no arreglaba nada.
        case blockedBeforeWriting
        /// **La cuenta se cerró en la nube pero el borrado local NO entró.** Los grupos siguen en el
        /// teléfono y la asociación sigue en pie a propósito. Se le ofrece reintentar el borrado.
        case purgeFailed
        /// El coordinador estaba ocupado (un cierre de sesión en curso). No se tocó nada.
        case busy
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
        blockedExit = nil
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
    /// Con el compuesto, un kill remoto sobre un device `.icloud` con sesión de grupos VIVA lo mandaría al
    /// cierre privado sin grupos (`.privateSignOut`), que no sube el outbox de grupos, no olvida el consent
    /// en sesión ni incluye el store de grupos en el borrado. Eso dejaría filas `Split*` del que se fue
    /// visibles para el siguiente y cambios de grupos sin subir muriendo con sync-meta. Los caminos con
    /// grupos (`.privateWithGroupsSignOut`, `.groupsOnlySignOut`) son los que suben y limpian las tres cosas.
    ///
    /// **Con el kill remoto de Grupos, el cierre de una sesión con grupos puede quedar bloqueado, y es
    /// deliberado.** El kill se aplica en el SERVIDOR (`gateway/src/groups/killSwitch.ts`, 403
    /// `yala_groups_disabled` a `/groups/push`) ⇒ con filas de grupos pendientes el push-all no drena y el
    /// cierre queda `.blocked` (reintentable, outbox intacto); con el outbox vacío drena sin una sola
    /// petición. Hasta el paso 9 lo «salvaba» la fila «Salir de Yala en este dispositivo», que purgaba el
    /// outbox —descartaba esas filas en silencio—. El ADR 2026-09-09 dejó un solo verbo y el criterio del
    /// ticket es «nunca descarta»: se espera a que el kill se levante.
    ///
    /// `confirmedPath` (paso 9): el camino cuya hoja leyó y confirmó la persona. Si al ejecutar la celda ya
    /// es otra —una sesión que caducó con la hoja abierta—, no se ejecuta un borrado que nadie leyó: la vista
    /// vuelve a comprobarlo antes de llamar y enseña la hoja nueva; esto es el cinturón.
    ///
    /// `confirmedWithoutICloudCopy`: la persona confirmó, con el segundo gesto, cerrar una sesión PRIVADA sin
    /// copia en iCloud. Solo entonces se salta la espera del export — no hay a dónde subir, y ya se le dijo
    /// que se pierde (decisión de Jürgen del 2026-09-09). En los demás caminos se ignora.
    func signOut(context: ModelContext, confirmedPath: CloudSignOutFlowLogic.Path? = nil,
                 confirmedWithoutICloudCopy: Bool = false) async {
        guard phase == .idle else { return }
        let path = CloudSignOutFlowLogic.path(
            for: CloudSyncFlags.storageMode,
            hasLiveSession: CloudAuthService.shared.hasSession,
            groupsBackendEnabled: CloudSyncFlags.groupsBackendCompiledCapability,
            hasPrivateSession: PrivateSessionMark.hasPrivateSession())
        if let confirmedPath, confirmedPath != path {
            CloudSyncBreadcrumb.signOutCellChangedBeforeRunning()
            return
        }
        switch path {
        case .cloudSecureSignOut:
            await performCloudSecureSignOut(context: context)
        case .privateSignOut, .privateWithGroupsSignOut, .groupsOnlySignOut:
            // Quién sube grupos y quién espera al export lo decide una tabla pura
            // (`CloudSignOutFlowLogic.exitPlan`), no este `switch`.
            guard let plan = CloudSignOutFlowLogic.exitPlan(
                path: path, confirmedWithoutICloudCopy: confirmedWithoutICloudCopy,
                mountAttachesMirror: Self.personalMountAttachesMirror) else { return }
            await performSessionExit(context: context, plan: plan)
        }
    }

    // MARK: - Desasociar la cuenta de grupos (paso 10)

    /// Suelta la cuenta de grupos de una sesión privada **sin tocar nada personal**.
    ///
    /// No es un cierre de sesión y no entra por `signOut`: el ADR §5 dice que la sesión privada y su cuenta
    /// de grupos se mueven juntas, y esto es la excepción que el §4 nombra —«la asociación se ve, se deshace
    /// y se rehace»—. Vive aquí, y no en un coordinador nuevo, porque las cuatro piezas que necesita ya
    /// están escritas y probadas en este tipo: la quiescencia del store personal, el push-all verificado con
    /// su presupuesto de reintentos, el teardown del canal y la purga del estado de sync. Reescribirlas
    /// aparte sería una quinta polaridad de un subsistema que ya tiene cinco.
    ///
    /// **El orden carga peso, y tres de sus pasos son la diferencia entre soltar y destruir:**
    ///
    ///  1. El `sub` asociado se lee **antes** de cerrar la sesión: después ya no hay de dónde.
    ///  2. El puente se suelta **antes** de borrar las filas `Split*`. Al revés, el `save()` del
    ///     des-puenteo comitearía esos deletes todavía dirty bajo el autor POR DEFECTO, que es justo lo
    ///     que el drain captura (`author != outboxSaveAuthor`) y **re-empuja al servidor**: los grupos se
    ///     borrarían de verdad, para todos los miembros. Es la trampa que documenta la regla «Un borrado
    ///     tiene DOS mitades», y aquí sería peor que allí.
    ///  3. Las filas se borran **después** del teardown y del `signOut`, con el canal ya cortado y sin
    ///     credenciales: nada de lo que este borrado local genere puede salir del teléfono **en este
    ///     proceso**. Esa acotación es literal y hay que leerla entera: el SwiftData History sobrevive al
    ///     relanzamiento, así que lo que protege el arranque SIGUIENTE no es el teardown sino cómo se
    ///     escribe el borrado — ver `purgeGroupsDomainForDetach`.
    ///
    /// El bloqueo por cambios sin subir se comporta como el del cierre —«nunca descarta»—: si el push-all
    /// no vacía, la fase queda en `.blocked` y **no se suelta nada**. Reintentar es seguro porque hasta el
    /// paso 2 no se ha escrito nada.
    ///
    /// **Qué pasa si el borrado local falla, y qué se le ofrece entonces** (ticket
    /// `detach-failure-looks-like-success`). Hasta el 2026-09-11 el fallo se tragaba y el gesto seguía
    /// a `clear()`: asociación borrada + grupos enteros en el teléfono, sin un solo mensaje. Ahora el
    /// borrado es la ÚLTIMA condición del gesto, y si no entra **no se limpia nada**: la asociación sigue
    /// en pie porque los datos siguen en pie, y las dos cuentan la misma historia.
    ///
    /// Lo que se le ofrece es **reintentar el borrado**, no rehacer la asociación, y las dos mitades están
    /// medidas:
    ///
    ///  · **Rehacer la asociación no se puede** sin un sign-in nuevo: para cuando el borrado corre, el
    ///    `signOut()` de arriba ya soltó las credenciales. Ofrecerlo sería pedirle a la persona que
    ///    vuelva a entrar en la cuenta para poder salir de ella.
    ///  · **Reintentar no necesita sesión.** El reintento vuelve a entrar por aquí, y su push-all sale
    ///    `.drained` **sin una sola petición**: `pushAllPendingGroupsForSignOut` corta en seco con el
    ///    outbox vacío, y en el reintento lo está porque el primer intento ya lo drenó antes de llegar al
    ///    borrado. El resto del camino es idempotente —el teardown lo es por contrato, `signOut()` sale
    ///    por su primer `guard` sin cliente, y `detachBridge` no reencuentra puente que soltar—. Lo único
    ///    que NO lo era es el libro de conservados, que la segunda pasada borraba: se cerró en
    ///    `GroupsAssociationDetach.detachBridge`, y sin eso reintentar le duplicaría en el Panel cada
    ///    gasto que eligió conservar.
    ///
    /// El estado intermedio, si decide no reintentar ahora, **no vuelve a ofrecer el gesto entero**: la
    /// marca durable hace que la sección ofrezca TERMINAR, sin volver a preguntar por el puente. Volver a
    /// preguntarlo sería ofrecer una elección que ya no puede aplicarse — el puente está soltado, así que
    /// un `.remove` no encontraría nada que quitar y el gesto acabaría diciendo que sí.
    ///
    /// - Parameter choice: qué pasa con los movimientos que el puente metió en el Panel. Lo elige el
    ///   usuario en la confirmación (decisión de Jürgen, 2026-09-09).
    /// - Returns: el veredicto. **Viaja por el retorno y no por una fase nueva**: `Phase` la leen seis
    ///   sitios que no tienen nada que ver con este gesto —el gate del relanzamiento, la fila de cierre
    ///   de sesión del perfil, la puerta de grupos del Welcome— y un case más les cambiaría el
    ///   comportamiento por defecto a cambio de nada. `.idle` sigue siendo verdad aquí: el coordinador no
    ///   está haciendo nada. La que mentía era la PANTALLA, y es la pantalla la que ahora recibe el
    ///   veredicto.
    @discardableResult
    func detachGroupsAccount(
        context: ModelContext, choice: GroupsAssociationDetach.BridgedRowsChoice
    ) async -> DetachOutcome {
        guard phase == .idle else { return .busy }
        phase = .working
        defer { waitingForPending = false }

        // (1) Antes de tocar credenciales.
        let associatedSub = GroupsAccountAssociation.shared.associatedSub ?? CloudAuthService.shared.currentUserID

        // Lo pendiente sube ANTES de cortar nada, con la generación intacta. Mismo presupuesto de
        // reintentos que el cierre: el bloqueo típico es transitorio.
        guard await pushGroupsForSignOut(context: context) else { return .blockedBeforeWriting }

        // Canal fuera + espejo del outbox del App Group purgado. Idempotente.
        GroupsSyncClient.shared.teardownForSignOut()

        // Molde S2 del cierre: una fila encolada entre el push-all y el teardown ya no puede subir, así
        // que es `.permanent`. Es el ÚLTIMO punto en el que abortar no deja nada a medias.
        let residual = Self.liveGroupsPendingCount(context: context)
        guard residual == 0 else {
            phase = .blocked(pendingCount: residual, reason: .permanent)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: residual)
            return .blockedBeforeWriting
        }

        // ── Punto de no retorno ──

        // (2) El puente, con las filas `Split*` todavía limpias. **Si no se pudo ni mirarlo, se ABORTA**:
        // seguir adelante borraría las filas de los grupos dejando las transacciones puenteadas
        // apuntando a una zona que ya no existe, y a ésas no las recoge ningún barrido — el veredicto de
        // zona que `OrphanedBridgedTxSweeper` exige se construye de filas vivas. Sería dinero atrapado
        // para siempre, y hasta aquí no se ha escrito nada irreversible.
        //
        // **Y «no se pudo mirar» incluye que su propio `save()` fallara**: `detachBridge` devuelve `nil`
        // en los dos casos desde el 2026-09-11. Antes, un save fallido devolvía un `Outcome` vacío que
        // este `guard` leía como éxito.
        guard GroupsAssociationDetach.detachBridge(
            context: context, choice: choice, associatedSub: associatedSub) != nil else {
            phase = .blocked(pendingCount: 0, reason: .bridgeUnreadable)
            return .blockedBeforeWriting
        }

        // El consent de Grupos NO se limpia aquí, a diferencia del cierre de sesión. Es un snapshot
        // SELLADO con el `userID` (`GroupsConsentState`), así que no puede colarse en la cuenta
        // siguiente: si vuelve la misma, casa y no se le vuelve a preguntar algo que ya aceptó; si entra
        // otra, el sello no casa y se le pregunta igual. Borrarlo solo costaría una pantalla de más a
        // quien re-asocia.
        await CloudAuthService.shared.signOut()

        // (3) Con el canal cortado y sin credenciales: las filas, el outbox y el cursor, de una vez.
        //
        // **Es la última CONDICIÓN del gesto, no su último paso.** Todo lo de abajo afirma que la cuenta
        // ya no está aquí, y eso solo es cierto si esto entró. Un `catch` que siguiera adelante —lo que
        // había hasta el 2026-09-11— dejaba la asociación borrada sobre unos grupos enteros: la pantalla
        // decía una cosa y el teléfono otra, y la que se equivocaba era la pantalla.
        do {
            try Self.purgeGroupsDomainForDetach(context: context)
        } catch {
            #if DEBUG
            print("CloudSessionSignOut: borrado local del dominio de grupos falló: \(error)")
            #endif
            // **La marca es DURABLE porque la fase no lo es.** Sin ella, al reabrir la app la sección
            // volvería a ofrecer el gesto entero con sus dos salidas, y la segunda ya no puede aplicarse:
            // el puente está soltado. Ver `GroupsDetachPendingPurge`.
            GroupsDetachPendingPurge.arm(sub: associatedSub)
            // Canario FUERA de `#if DEBUG`, molde `freshStartWipeFailed`: este fallo era invisible en
            // producción y es su hermano exacto —un borrado que no ocurrió y una UI que decía que sí—.
            // Sin PII: solo qué eligió la persona para el puente, que es lo que cambia el volumen de
            // filas que la transacción tocaba.
            MetricsService.canary(
                .groupsDetachPurgeFailed,
                detail: "choice=\(choice == .keep ? "keep" : "remove")")
            // NADA de lo de abajo corre. La asociación se queda, y con la sesión ya cerrada la sección
            // pasa a `.associatedNeedsSignIn` —la celda del segundo móvil—, que vuelve a ofrecer el gesto.
            phase = .idle
            return .purgeFailed
        }

        finishDetach(context: context)
        return .detached
    }

    /// **Terminar un desasociar cuyo borrado local no entró.** Es lo que ofrece el aviso «No pudimos
    /// soltar la cuenta», y lo que la sección ofrece mientras `GroupsDetachPendingPurge` esté armada.
    ///
    /// **Hace el borrado y su remate, y NADA más — no re-ejecuta el gesto.** Repetir `detachGroupsAccount`
    /// entero parecía lo barato y lo midió la review del 2026-09-11: volvería a entrar por
    /// `pushGroupsForSignOut` **después** del teardown, que es exactamente lo que prohíben los docblocks
    /// de `pushAllPendingGroupsForSignOut` («DEBE correr ANTES») y de `attemptGroupsOnlyClose`
    /// («reintentar tras el teardown repoblaría el outbox/cursor»). Y no es teórico: las filas `Split*`
    /// siguen vivas y la pestaña Grupos sigue funcionando sin sesión, así que un gasto añadido entre el
    /// fallo y el reintento deja History que el `drainOnce` de ese push traduce a outbox → el pre-check
    /// deja de cortar → 20 ciclos contra un backend sin credenciales → `.blocked`, y el desasociar se
    /// vuelve imposible de terminar. De paso, `writeMirror` repondría en el espejo del App Group los
    /// montos que el teardown acababa de purgar.
    ///
    /// Lo que queda pendiente en ese estado es **solo** el borrado: el push ya drenó, el canal ya está
    /// cortado, el puente ya se soltó con la salida elegida y la sesión ya está cerrada.
    func retryDetachPurge(context: ModelContext) async -> DetachOutcome {
        guard phase == .idle else { return .busy }
        // **El sello se comprueba AQUÍ, no solo en la vista.** Es el guard dentro del escritor: si la
        // pantalla se equivocara —o si alguien añade un segundo call-site— esto no puede borrarle el
        // dominio Grupos a una cuenta que no es la que quedó a medias.
        //
        // La segunda condición es «la sesión viva NO es la de la cuenta pendiente», y es más fina que
        // «no hay sesión»: este método no hace teardown ni suelta credenciales, así que con la sesión de
        // ESA cuenta repuesta dejaría a la persona dentro de una cuenta cuyos datos locales acaba de
        // borrar y cuya asociación acaba de limpiar. Quien vuelve a entrar usa el gesto entero, que sí
        // cierra la sesión. Una sesión de OTRA cuenta no estorba: lo pendiente sigue siendo local.
        guard GroupsDetachPendingPurge.isArmed(for: GroupsAccountAssociation.shared.associatedSub),
              CloudAuthService.shared.currentUserID != GroupsDetachPendingPurge.armedSub()
        else { return .busy }
        phase = .working
        // Un turno del main actor antes de trabajar. Sin él este método no suspende NUNCA —no tiene un
        // solo `await`— así que SwiftUI no re-renderiza entre `.working` y `.idle`: el spinner no llega a
        // salir, y un segundo fallo encendería el aviso en el MISMO turno en que el anterior se está
        // desmontando, que es la carrera de dos presentaciones en un anchor que este repo ya pagó.
        await Task.yield()
        do {
            try Self.purgeGroupsDomainForDetach(context: context)
        } catch {
            #if DEBUG
            print("CloudSessionSignOut: reintento del borrado del dominio de grupos falló: \(error)")
            #endif
            MetricsService.canary(.groupsDetachPurgeFailed, detail: "retry")
            phase = .idle
            return .purgeFailed
        }
        finishDetach(context: context)
        return .detached
    }

    /// El tramo que afirma que la cuenta ya no está aquí. **Solo se llama con el borrado hecho**, y por
    /// eso vive en un método propio: sus dos call-sites —el gesto y su reintento— tienen que decir lo
    /// mismo, y duplicarlo es como dejarían de decirlo.
    private func finishDetach(context: ModelContext) {
        GroupsAccountAssociation.shared.clear()
        GroupsSessionHistoryMarker.markSessionSeen()  // siguió siendo cierto: este device tuvo sesión.
        GroupsDetachPendingPurge.clear()
        SessionState.shared.incrementDataVersion()
        WidgetDataCache.updateCache(context: context)
        phase = .idle
    }

    /// El borrado local del dominio Grupos del desasociar: las filas `Split*`, el outbox y la mitad del
    /// cursor que es del PULL. **En UNA sola transacción** — morir entre dos `save()` dejaba el par
    /// incoherente «cursor reseteado + filas vivas».
    ///
    /// `static` y separada del coordinador para ser directamente testeable, como `purgeGroupsSyncState`:
    /// lo que la envuelve (credenciales, asociación, widgets) no lo es en unit test, y este borrado es
    /// justo la parte cuyo efecto sobre el SwiftData History hay que poder medir.
    ///
    /// **Tres cosas que parecen detalles y son el arreglo entero** (ticket
    /// `detach-history-replay-can-tombstone-groups-on-next-launch`):
    ///
    ///  1. **El `save()` lo hace `deleteLocalGroupsRows`, firmado con el autor del canal.** Cortar el
    ///     canal antes (lo que hace el paso 3 del desasociar) protege ESTE proceso, no el siguiente: el
    ///     History sobrevive al relanzamiento, y un drain posterior que re-barra esa ventana traduciría
    ///     estos deletes a tombstones y borraría los gastos **para todos los miembros del grupo**.
    ///     Firmados, el drain los descarta antes de traducir, mire desde donde mire.
    ///
    ///  2. **El cursor se borra ENTERO —filas y cursor en el mismo `save()`— y la firma es la ÚNICA defensa
    ///     de estos deletes. Conservar el ancla del drain se probó y se retiró, medido** (review adversarial
    ///     del 2026-09-11, tres lentes):
    ///      - **No los protege.** El ancla que sobreviviría es la del último drain ANTERIOR al desasociar, y
    ///        estos deletes son posteriores: `fetchHistory($0.token > token)` los devuelve igual. Lo único
    ///        que los descarta es el autor.
    ///      - **Lo que evitaría —re-barrer el History viejo— no produce nada aquí.** Con las filas ya
    ///        borradas, el `case` de insert/update no resuelve ninguna fila viva por `PersistentIdentifier`
    ///        y no emite. Medido: 0 filas. (Con las filas VIVAS sí re-emite, 1 upsert con HLC nuevo por
    ///        fila — ése es el par «cursor borrado + filas vivas» que esta transacción única impide, y lo
    ///        fija `GroupsDetachHistoryReplayTests`.)
    ///      - **Y cuesta.** `lastDrainedTxAt` es uno de los cuatro suelos del corte de purga del History
    ///        (`CloudSyncEngine.groupDrainedBoundary`). Conservarlo sin canal que lo avance —tras soltar la
    ///        cuenta no hay sesión, así que el loop no arranca— lo deja congelado en el instante del
    ///        desasociar: hoy es inocuo porque la purga solo corre con el runtime personal, que es de
    ///        `.cloud`, pero clavaría el corte para siempre en cuanto esa persona migrara a la nube.
    ///     ⇒ el par coherente en esta frontera de CUENTA sigue siendo **«filas borradas + cursor borrado»,
    ///     atómico** — lo mismo que antes del arreglo, con el borrado ahora firmado.
    ///
    ///  3. **Nada de esto se apoya en que el drain corra ANTES del pull dentro de `syncCycleOnce`.** Eso
    ///     era lo único que cerraba el agujero hasta el 2026-09-11 —con las zonas sin repoblar,
    ///     `backendGroupZoneIDs` sale vacío y el drain no emite— y era un efecto colateral del orden, no
    ///     una defensa: bastaba con que ese primer drain lanzara (su `catch` traga) para que el ciclo
    ///     siguiera al pull, repoblara las zonas y el drain de después sí emitiera.
    ///
    /// **Sin `GroupBridgePreference`**: esa tabla vive en el schema PERSONAL, que sí espeja a iCloud, así
    /// que borrarla exportaría el delete al Apple ID y se la quitaría también al iPad del mismo dueño,
    /// donde puede haber una sesión de grupos viva. Y además es suya: cómo quiere que se puenteen sus
    /// gastos no deja de ser cierto porque suelte esta cuenta.
    ///
    /// **PROPAGA, y hasta el 2026-09-11 no lo hacía** (ticket `detach-failure-looks-like-success`). El
    /// `catch` de aquí imprimía bajo `#if DEBUG` y devolvía como si nada, así que `detachGroupsAccount`
    /// seguía a `clear()` y la pantalla decía que la cuenta estaba suelta **con los grupos enteros en el
    /// teléfono**. `deleteLocalGroupsRows` hace `rollback()` antes de propagar —sin él los deletes
    /// quedarían sucios y el siguiente `save()` de cualquier camino los comitearía bajo el autor por
    /// defecto, traducibles a tombstones—, así que quien reciba este `throw` recibe además un contexto
    /// limpio: el reintento parte del mismo sitio que el primer intento.
    static func purgeGroupsDomainForDetach(context: ModelContext) throws {
        SaveBreadcrumb.willSave("CloudSessionSignOut.detachGroupsAccount")
        try DataWipeService.deleteLocalGroupsRows(in: context, includingBridgePreferences: false) {
            for row in try context.fetch(FetchDescriptor<GroupSyncOutbox>()) { context.delete(row) }
            for cursor in try context.fetch(FetchDescriptor<GroupSyncCursor>()) { context.delete(cursor) }
        }
        SaveBreadcrumb.didSave("CloudSessionSignOut.detachGroupsAccount")
    }

    // MARK: - Los tres cierres que borran por ARCHIVOS: privada (C), «equipo» (D) y solo grupos (F)

    /// El cierre parado en la espera del export, a la espera de lo que decida la persona: «Cerrar sesión
    /// igualmente» (`exitDiscardingUnconfirmed`) o «Esperar» (`resumeWaitingForExport`). `nil` fuera de ese
    /// bloqueo.
    ///
    /// `credentialsReleased` dice dónde se paró: ANTES de soltar la sesión (la primera espera) o DESPUÉS (el
    /// último recuento, pegado al arm). En el segundo caso la sesión en la nube, el push token y el consent
    /// ya se soltaron, así que retomar no puede volver a empezar el cierre: solo le queda esperar o armar.
    /// Volver a `.idle` desde ahí dejaba el dispositivo a medio cerrar, sin sesión y sin borrado (review
    /// adversarial del paso 9).
    private struct BlockedExit {
        let kind: CloudSignOutFlowLogic.ExitKind
        let credentialsReleased: Bool
    }
    private var blockedExit: BlockedExit?

    /// Qué hace el tramo final con lo que no se pudo confirmar en iCloud.
    private enum ExportPolicy {
        /// Solo se arma con cero pendientes demostrado.
        case confirm
        /// La persona aceptó perder lo que no llegó. `upTo` es la cifra que se le enseñó (`nil` = «no pudimos
        /// confirmar», sin número): si al armar hay MÁS, se le vuelve a avisar en vez de llevárselo callado.
        case acceptLoss(upTo: Int?)
        /// No hay a dónde subir: la persona confirmó que no hay copia, o el store no espeja (F).
        case notAwaited
    }

    /// ¿El store personal de ESTE proceso espeja a iCloud? El testigo exacto del mount (eje A), el mismo que
    /// usa el aviso del espejo tardío: no una segunda verdad.
    static var personalMountAttachesMirror: Bool {
        SwiftDataConfiguration.personalStoreMountedDecision.attachesCloudKitMirror
    }

    /// ¿Hay copia en iCloud a la que esperar? La pregunta la hace la VISTA al tocar «Cerrar sesión», para
    /// elegir la hoja (con copia o sin ella), y la respuesta viaja con la confirmación. Lee los testigos
    /// que ya gobiernan: el del mount y lo que dijo el espejo.
    static func privateCopyChannel() -> PrivateSignOutExportGateLogic.CopyChannel {
        PrivateSignOutExportGateLogic.copyChannel(
            mountAttachesMirror: personalMountAttachesMirror,
            mirrorReportedNotAuthenticated: iCloudSyncService.shared.mirrorReportedNotAuthenticated)
    }

    /// Cambios locales del store personal que el espejo aún podría no haber subido (`nil` = no hay número
    /// honesto que dar; ver `PersonalExportPendingCounter`).
    static func pendingPersonalExportCount(context: ModelContext) -> Int? {
        PersonalExportPendingCounter.pendingChangeCount(
            context: context, confirmedExportStart: iCloudSyncService.shared.confirmedExportStart)
    }

    /// ¿El store de grupos guarda filas del canal BACKEND? Son re-descargables (las devuelve el pull), así
    /// que el cierre privado sin sesión las OLVIDA con el resto: una sesión de grupos que caducó deja a este
    /// dispositivo con cara de privada sin grupos (C), y conservar esas filas enseñaría a la persona
    /// siguiente grupos y montos ajenos junto a un cursor que el boot-wipe ya borró (el par incoherente del
    /// camino `.cloud`). Las filas de la era CloudKit que nunca migraron no tienen de dónde volver y se quedan.
    /// Solo lee.
    static func hasBackendGroupRows(context: ModelContext) -> Bool {
        do {
            return try context.fetchCount(FetchDescriptor<SplitGroup>(
                predicate: #Predicate { $0.isBackendGroup || $0.movedToBackendAt != nil })) > 0
        } catch {
            #if DEBUG
            print("CloudSessionSignOut: Error contando grupos del canal backend: \(error)")
            #endif
            return true  // ante la duda, olvidar: grupos ajenos a la vista de otra persona es peor
        }
    }

    /// **Cerrar sesión en una sesión PRIVADA (C), en el «equipo» (D) o en solo grupos (F)** — ADR
    /// 2026-09-09 §5: sube lo pendiente, borra lo local, deja iCloud y la cuenta intactos, y vuelve al
    /// Welcome.
    ///
    /// Orden, y por qué:
    ///  0. **La privada (C) no descarta grupos**: si le quedan cambios de grupos sin subir —una sesión de
    ///     grupos que caducó con el outbox lleno—, se bloquea pidiendo volver a entrar (`blockIfGroupsCannotUpload`).
    ///  1. **Los grupos suben primero** (D, y F si va a esperar al export) — push-all verificado con el
    ///     reintento de H-2026-07-18-6. Si no drena, el cierre se bloquea con el «un momento más» de siempre
    ///     y SIN salida de emergencia: lo de grupos es de más gente, y el criterio del ticket es «nunca
    ///     descarta».
    ///  2. **La espera del export de iCloud** (`PrivateSignOutExportGateLogic`): solo se borra con cero
    ///     cambios locales sin subir. Agotada la espera normal, se bloquea contando lo pendiente y el aviso
    ///     ofrece cerrar igualmente o seguir esperando (decisión de Jürgen del 2026-09-09). Si la persona ya
    ///     confirmó que no hay copia en iCloud, no hay a dónde subir.
    ///  3. **El borrado por ARCHIVOS** (`finalizeSessionExit`), que vuelve a subir los grupos, suelta la sesión
    ///     y cuenta lo personal justo antes de armar (`armAfterCredentials`).
    private func performSessionExit(context: ModelContext, plan: CloudSignOutFlowLogic.ExitPlan) async {
        phase = .working
        waitingForPending = false
        CloudSyncBreadcrumb.signOutStarted(path: Self.breadcrumbPath(plan.kind))
        // Salir por CUALQUIER camino apaga el caption de espera (regla del @Observable).
        defer { waitingForPending = false }

        if blockIfGroupsCannotUpload(context: context, kind: plan.kind) { return }
        if plan.waitsForExport {
            if plan.kind.pushesGroups {
                guard await pushGroupsForSignOut(context: context) else { return }
            }
            guard await confirmExportOrBlock(context: context, kind: plan.kind, credentialsReleased: false) else { return }
        } else if plan.kind != .groupsOnly {
            CloudSyncBreadcrumb.signOutWithoutICloudCopy()
        }
        await finalizeSessionExit(context: context, kind: plan.kind, export: plan.waitsForExport ? .confirm : .notAwaited)
    }

    /// **Salida de EMERGENCIA** («Cerrar sesión igualmente»), aceptando que lo que no llegó a iCloud se
    /// pierde. Decisión de Jürgen del 2026-09-09: tras la espera normal no se deja a nadie atrapado ni se le
    /// borra en silencio — el aviso cuenta lo pendiente, y esto solo corre si la persona lo elige.
    ///
    /// Solo es alcanzable desde ese aviso: sin el bloqueo del export vivo no hay nada que forzar, y sin el
    /// cierre que lo originó no se sabe qué borrar. La cifra aceptada viaja hasta el arm: el cierre todavía
    /// sube grupos y suelta la sesión, y si al armar hay MÁS cambios que los avisados se vuelve a avisar con
    /// el número nuevo en vez de llevárselos sin decirlo (review adversarial del paso 9: antes solo se
    /// comparaba al tocar). Los grupos NO se descartan nunca: el cierre los vuelve a subir.
    func exitDiscardingUnconfirmed(context: ModelContext) async {
        guard case .blocked(let shown, .exportUnconfirmed) = phase else { return }
        guard let blocked = blockedExit else { return }
        // Un 0 en el aviso es «no pudimos confirmar», sin cifra: lo aceptado no tiene número con que comparar.
        let accepted: Int? = shown > 0 ? shown : nil
        if let accepted, let now = Self.pendingPersonalExportCount(context: context), now > accepted {
            phase = .blocked(pendingCount: now, reason: .exportUnconfirmed)
            return
        }
        blockedExit = nil
        CloudSyncBreadcrumb.signOutExportDiscarded()
        MetricsService.canary(.privateSignOutExportDiscarded, detail: accepted.map { "pending=\($0)" } ?? "pending=unknown")
        if blocked.credentialsReleased {
            phase = .working
            await armAfterCredentials(context: context, kind: blocked.kind, export: .acceptLoss(upTo: accepted))
        } else {
            await finalizeSessionExit(context: context, kind: blocked.kind, export: .acceptLoss(upTo: accepted))
        }
    }

    /// **«Esperar»**: el cierre sigue esperando al export y termina solo en cuanto llega lo último, que es
    /// lo que dice el botón. Volver a `.idle` cancelaba el cierre sin decirlo y, si se había parado después de
    /// soltar credenciales, dejaba el dispositivo sin sesión y sin borrado (review adversarial del paso 9). Si
    /// la espera vuelve a agotarse, vuelve el aviso.
    func resumeWaitingForExport(context: ModelContext) async {
        guard case .blocked(_, .exportUnconfirmed) = phase else { return }
        guard let blocked = blockedExit else { return }
        blockedExit = nil
        phase = .working
        defer { waitingForPending = false }
        if blocked.credentialsReleased {
            await armAfterCredentials(context: context, kind: blocked.kind, export: .confirm)
        } else {
            guard await confirmExportOrBlock(context: context, kind: blocked.kind, credentialsReleased: false) else { return }
            await finalizeSessionExit(context: context, kind: blocked.kind, export: .confirm)
        }
    }

    /// La privada (C) no sube grupos. Si aun así le quedan cambios de grupos sin subir —el outbox de una sesión
    /// de grupos que caducó—, se bloquea pidiendo volver a entrar: el boot-wipe borra sync-meta, que es donde
    /// viven, y descartarlos rompe el «nunca descarta» (review adversarial del paso 9: se perdían en silencio
    /// mientras la hoja decía que los grupos no se tocaban). `true` = bloqueado, con la fase puesta.
    /// Síncrono a propósito: también corre pegado al arm.
    private func blockIfGroupsCannotUpload(context: ModelContext, kind: CloudSignOutFlowLogic.ExitKind) -> Bool {
        guard !kind.pushesGroups else { return false }
        let unuploaded = Self.liveGroupsPendingCount(context: context)
        guard unuploaded > 0 else { return false }
        phase = .blocked(pendingCount: unuploaded, reason: .sessionExpired)
        CloudSyncBreadcrumb.signOutPushBlocked(pending: unuploaded)
        return true
    }

    /// Una vuelta de la espera del export. `true` = confirmado (cero pendientes); `false` = bloqueado con el
    /// aviso de la salida de emergencia, fase ya puesta y `blockedExit` recordando dónde retomar.
    ///
    /// Sin ancla, el contador recorre el historial ENTERO para saber si hay algo local: se hace UNA vez por
    /// espera y se reutiliza hasta que aparece un ancla (un export que termina bien), que es lo único que
    /// puede cambiar esa respuesta.
    private func confirmExportOrBlock(context: ModelContext, kind: CloudSignOutFlowLogic.ExitKind, credentialsReleased: Bool) async -> Bool {
        var withoutAnchor: Int?? = .none
        let verdict = await PrivateSignOutExportGateLogic.awaitConfirmedExport(
            pendingCount: {
                if iCloudSyncService.shared.confirmedExportStart == nil {
                    if case .some(let cached) = withoutAnchor { return cached }
                    let fresh = Self.pendingPersonalExportCount(context: context)
                    withoutAnchor = .some(fresh)
                    return fresh
                }
                return Self.pendingPersonalExportCount(context: context)
            },
            onWaiting: { self.waitingForPending = true },
            sleep: { seconds in
                do {
                    try await Task.sleep(for: .seconds(seconds))
                    return true
                } catch {
                    return false  // cancelación del caller → «no se pudo demostrar», jamás borrar
                }
            })
        guard case .stalled(let pending) = verdict else { return true }
        blockedExit = BlockedExit(kind: kind, credentialsReleased: credentialsReleased)
        phase = .blocked(pendingCount: pending ?? 0, reason: .exportUnconfirmed)
        CloudSyncBreadcrumb.signOutExportUnconfirmed(pending: pending)
        MetricsService.canary(.privateSignOutExportUnconfirmed,
                              detail: pending.map { "pending=\($0)" } ?? "pending=unknown")
        return false
    }

    /// El tramo común de los tres cierres hasta soltar la sesión (tras la espera confirmada, sin espera, o tras
    /// la salida de emergencia). Lo último —el recuento y el arm— es `armAfterCredentials`.
    ///
    /// **Borra por ARCHIVOS y en el arranque, nunca filas en sesión**: con el espejo de CloudKit montado,
    /// borrar filas exportaría los deletes a iCloud (`DataWipeService`) y destruiría la copia que esta
    /// salida promete conservar. El boot-wipe es el MISMO de la nube (`performSignOutWipeIfArmed`): borra
    /// los archivos personal + sync-meta (+ grupos) pre-mount, devuelve el dispositivo a recién instalado y
    /// arma el neutro duradero ⇒ el arranque siguiente monta sin espejo, aterriza en el Welcome y
    /// «Restaurar desde iCloud» encuentra todo. Kill-safe por construcción: el arm es la última escritura.
    ///
    /// **No intenta el swap sin relanzar**, ni siquiera donde el mount no espeja (F): el instrumento del
    /// release verificado solo mide el archivo personal, y aquí se borran también grupos y sync-meta. Se
    /// queda en la pantalla de reabrir, que es lo que el cierre solo-grupos ya hacía (`PersonalSwapReleaseTests`
    /// fija que el swap vive solo en `.cloud`).
    private func finalizeSessionExit(context: ModelContext, kind: CloudSignOutFlowLogic.ExitKind, export: ExportPolicy) async {
        phase = .working
        if kind.pushesGroups {
            // Otra vuelta de grupos: lo escrito en grupos durante la espera puede estar SOLO en el historial —
            // el recuento del outbox no lo ve— y solo el push-all lo drena (con su puerta de quiescencia).
            guard await pushGroupsForSignOut(context: context) else { return }
        }
        // Un marker `includesGroups` huérfano de una corrida anterior no puede colarse en este wipe.
        StorageModePersistence.clearSignOutWipeIncludesGroups()

        CloudSyncRuntime.shared?.teardownGuestSession()
        // Canal de Grupos→backend: loop fuera + espejo del outbox en el App Group purgado. Idempotente.
        GroupsSyncClient.shared.teardownForSignOut()
        await PushTokenSignOutSeam.clearForSignOut()  // G8-2: desregistro best-effort del push token
        if kind.pushesGroups {
            // S2 (molde del camino `.cloud`): una fila encolada entre el push-all y el teardown moriría con el
            // wipe. Tras el teardown ya no se puede subir, así que es `.permanent`, como allí.
            let residual = Self.liveGroupsPendingCount(context: context)
            guard residual == 0 else {
                phase = .blocked(pendingCount: residual, reason: .permanent)
                CloudSyncBreadcrumb.signOutPushBlocked(pending: residual)
                return
            }
            // CR-2: sin esto, un kill entre `signOut()` y el arm dejaría el consent de una sesión que ya no
            // existe, y la cuenta siguiente se saltaría su pantalla. Desde C1 es local puro.
            GroupsConsentState.clear()
        }
        await CloudAuthService.shared.signOut()
        await armAfterCredentials(context: context, kind: kind, export: export)
    }

    /// Lo que queda con las credenciales ya sueltas: el último recuento y el arm.
    ///
    /// **El último recuento va PEGADO al arm, sin un solo `await` entre medias**: lo escrito mientras se
    /// soltaba la sesión cuenta, y cualquier suspensión dejaría entrar un save que el borrado se llevaría sin
    /// haberlo contado. Si hay que esperar se espera aquí —el espejo no depende de la sesión en la nube—, y si
    /// la persona aceptó una pérdida y ahora hay MÁS, se le vuelve a avisar. Un bloqueo desde aquí se retoma
    /// con `blockedExit.credentialsReleased`: ni «Esperar» ni «Cerrar sesión igualmente» vuelven a empezar un
    /// cierre que ya soltó la sesión.
    private func armAfterCredentials(context: ModelContext, kind: CloudSignOutFlowLogic.ExitKind, export: ExportPolicy) async {
        switch export {
        case .confirm:
            while true {
                guard await confirmExportOrBlock(context: context, kind: kind, credentialsReleased: true) else { return }
                if Self.pendingPersonalExportCount(context: context) == 0 { break }
            }
        case .acceptLoss(let accepted):
            // `nil` = se aceptó sin cifra («no pudimos confirmar»): no hay número con que comparar.
            if let accepted {
                let now = Self.pendingPersonalExportCount(context: context)
                if now.map({ $0 > accepted }) ?? true {
                    blockedExit = BlockedExit(kind: kind, credentialsReleased: true)
                    phase = .blocked(pendingCount: now ?? 0, reason: .exportUnconfirmed)
                    return
                }
            }
        case .notAwaited:
            break
        }
        // ── Desde aquí no hay ni un `await` hasta el arm. ──
        if blockIfGroupsCannotUpload(context: context, kind: kind) { return }
        let forgetsGroups = kind.pushesGroups || Self.hasBackendGroupRows(context: context)
        if forgetsGroups && CloudSyncFlags.groupsBackendCompiledCapability {
            StorageModePersistence.markSignOutWipeIncludesGroups()  // marker ANTES del arm (CR-4)
        }
        StorageModePersistence.armSignOutWipe()
        CloudSyncBreadcrumb.signOutWipeArmed()
        clearLocalSurfacesForArmedWipe()
        phase = .awaitingRelaunch
    }

    private static func breadcrumbPath(_ kind: CloudSignOutFlowLogic.ExitKind) -> String {
        switch kind {
        case .privateOnly: return "private"
        case .privateWithGroups: return "private-with-groups"
        case .groupsOnly: return "icloud-groups-session"
        }
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
    /// Exclusivo de los caminos que arman un wipe del store PERSONAL: los cuatro cierres de sesión (C, D, E,
    /// F), el secundario M1 y el cierre local tras borrar una cuenta en la nube. El cierre local tras borrar
    /// la cuenta de grupos de una sesión PRIVADA no lo llama: ahí el store personal sobrevive, y tanto sus
    /// recordatorios como lo que pinta el widget siguen siendo legítimos.
    private func clearLocalSurfacesForArmedWipe() {
        NotificationService.shared.cancelAllNotifications()
        NotificationService.shared.clearDeliveredNotifications()
        // `clearCache()` ya dispara `WidgetCenter.reloadAllTimelines()` ⇒ el widget se redibuja vacío
        // sin esperar al relanzamiento. El boot-cleanup lo repite (vía `DataWipeService.resetForSignOutWipe`).
        WidgetDataCache.clearCache()
        CloudSyncBreadcrumb.signOutNotificationsCleared()
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
        // abortaría el ciclo). Blocked ⇒ abort idéntico al personal, **con UNA excepción medida**.
        //
        // El canal de Grupos en pausa viaja tal cual (2026-09-13); el resto se sigue colapsando en
        // `.permanent`, byte-idéntico a lo de siempre. La asimetría es deliberada y cabe en una frase: una
        // cuenta `.cloud` con grupos sufre el kill-switch de Grupos **exactamente igual** que la sesión
        // privada del ticket —mismo 403, misma función, misma mentira— y dejarlo aquí sería arreglar el
        // agujero en tres celdas de cuatro. Los otros motivos se quedan porque su alert en este camino es
        // una decisión propia (ver el comentario del paso 1) y nadie ha pedido cambiarla.
        switch await pushAllPendingGroupsForSignOut(context: context) {
        case .blocked(let pending, let reason):
            phase = .blocked(pendingCount: pending,
                             reason: reason == .channelPaused ? .channelPaused : .permanent)
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

        // **R4 · el swap de persona SIN relanzar.** Va aquí, en la ÚLTIMA línea y no una antes, y el orden
        // es lo que convierte esto en una mejora sin riesgo nuevo:
        //  · el wipe de boot ya está ARMADO ⇒ si el swap no puede ejecutarse (mount con mirror, release no
        //    verificado, kill del proceso a mitad), el boot siguiente hace exactamente lo de siempre. La
        //    red se CONSERVA y este camino jamás la desarma por su cuenta — la desarma el propio wipe al
        //    ejecutarse, aquí o en el boot;
        //  · `phase` ya es `.awaitingRelaunch` ⇒ el cover terminal está en pantalla y el blocker de la
        //    matriz contiene el router antes de que la jerarquía se desmonte, así que el usuario no ve un
        //    hueco entre el árbol viejo y el nuevo;
        //  · y el swap **no toca credenciales ni outbox**: todo eso ya se resolvió arriba, con la sesión
        //    viva y el push-all verificado dos veces.
        //
        // Si sale `.swapped`, el store quedó vacío, el container remontado NEUTRO y la app está en el
        // Welcome — la persona siguiente entra sin haber cerrado la app ni una vez. La fase se devuelve a
        // `.idle` SOLO en ese caso: mientras el cierre siga dependiendo de un relanzamiento, la fase es lo
        // que sostiene el cover y el exit-on-background.
        if await PersonalContainerSwap.attemptSignOutSwap() == .swapped {
            phase = .idle
        }
    }

    // MARK: - La subida del outbox de grupos (D y F)

    /// Push-all del outbox de GRUPOS con el RETRY INTERNO de presupuesto global (H-2026-07-18-6), común al
    /// solo-grupos (F) y al «equipo» (D). `true` = drenado; `false` = bloqueado, con la fase ya puesta.
    ///
    /// El device-QA mostró que el bloqueo típico es TRANSITORIO (writes INTERNOS del boot aún asentándose —
    /// no hay nada que el usuario pueda hacer salvo esperar) y el usuario terminaba tocando "Cerrar sesión"
    /// 2-3 veces hasta que "pegaba". Se reintentan internamente los transitorios dentro de un presupuesto
    /// (segundos ADICIONALES tras el PRIMER bloqueo); los permanentes (sesión/cuenta) se muestran de
    /// inmediato. `retryClockStart` arranca en el primer bloqueo transitorio; en los reintentos el gate de
    /// quiescencia recibe un hardCap = lo que queda del presupuesto (jamás vuelve a bloquear 60 s completos).
    /// La DECISIÓN es pura (`GroupsSignOutRetryDecision`); aquí solo se mide el tiempo real con `Date()`.
    private func pushGroupsForSignOut(context: ModelContext) async -> Bool {
        let budget = GroupsSignOutRetryDecision.budgetSeconds
        var retryClockStart: Date?

        while true {
            let hardCap: TimeInterval = retryClockStart
                .map { max(0, budget - Date().timeIntervalSince($0)) } ?? 60

            switch await attemptGroupsOnlyClose(context: context, quiescenceHardCap: hardCap) {
            case .drained:
                return true
            case .blocked(let pending, let reason):
                let elapsed = retryClockStart.map { Date().timeIntervalSince($0) } ?? 0
                switch GroupsSignOutRetryDecision.decide(
                    elapsedSeconds: elapsed, budgetSeconds: budget, reason: reason
                ) {
                case .surfacePermanent:
                    // **El motivo viaja TAL CUAL, y esa es la corrección del 2026-09-13.** Aquí había un
                    // ternario que colapsaba todo lo que no fuera `.sessionExpired` en `.permanent`: con él,
                    // el canal en pausa llegaba a la pantalla convertido en «el problema es tu cuenta» y el
                    // arreglo heredaba la forma del bug. `decide` solo devuelve `.surfacePermanent` para los
                    // tres motivos que se muestran al momento, así que propagarlo es además byte-equivalente
                    // a lo que hacía el ternario para los dos que ya existían.
                    phase = .blocked(pendingCount: pending, reason: reason)
                    CloudSyncBreadcrumb.signOutPushBlocked(pending: pending)
                    return false
                case .surfaceTransient:
                    phase = .blocked(pendingCount: pending, reason: .transient)
                    CloudSyncBreadcrumb.signOutPushBlocked(pending: pending)
                    return false
                case .retryAfter(let seconds):
                    if retryClockStart == nil { retryClockStart = Date() }
                    waitingForPending = true
                    do {
                        try await Task.sleep(for: .seconds(seconds))
                    } catch {
                        // Cancelación del caller → fail-closed transitorio (reintentable).
                        phase = .blocked(pendingCount: pending, reason: .transient)
                        return false
                    }
                    continue
                }
            }
        }
    }

    /// UN intento del cierre solo-grupos: gate de QUIESCENCIA (hardCap acotado en reintentos) +
    /// push-all VERIFICADO del outbox de grupos. NO hace teardown ni toca credenciales — eso es
    /// `finalizeSessionExit`, que corre UNA sola vez tras `.drained` (reintentar tras el teardown
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
    /// `finalizeSessionExit` SIN el push-all (datos muertos server-side). El GATE DE QUIESCENCIA es
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
            // SEGUNDO call-site del barrido de tombstones de `split_groups` encolados, y NO es redundante
            // con el de `GroupsSyncClient.startIfEligible`: aquel vive detrás del flag COMPUESTO y éste
            // detrás del COMPILADO, que es justo la asimetría que el comentario de arriba describe. Con el
            // kill remoto puesto —o con el snapshot de remote-config ausente/fuera de bucket, que es
            // fail-closed— `startIfEligible` retorna en su primer guard ⇒ el barrido nunca corre, mientras
            // este push-all SÍ empuja porque el transporte no consulta el flag. Y bajar
            // `GROUPS_BACKEND_ROLLOUT_PERCENT` es exactamente la respuesta operativa a ESE incidente, así
            // que sin esta línea el barrido estaría apagado precisamente en la cohorte donde el veneno
            // sobrevive. Va DESPUÉS del drain (que con el guard `!updateOnly` ya no puede producir uno,
            // pero si algún día lo produjera esto lo recogería) y ANTES del pre-check: si la única fila
            // viva era la venenosa, el conteo cae a 0 y el cierre sale `.drained` sin un solo request.
            GroupsSyncClient.shared.purgeQueuedSplitGroupTombstones(context: context)
        }
        if Self.liveGroupsPendingCount(context: context) == 0 { return .drained }
        for iteration in 1...maxIterations {
            let outcome = await GroupsSyncClient.shared.syncCycleOnceCoalesced(context: context)
            if let verdict = CloudSignOutFlowLogic.pushAllVerdict(
                livePendingCount: Self.liveGroupsPendingCount(context: context),
                cycleOutcome: outcome,
                // ¿Paró este ciclo por el kill-switch? Se pregunta CON el outcome en la mano, que es lo que
                // impide leer el testigo de un ciclo que no es éste. Con el kill puesto, el bloqueo se
                // anuncia como «los grupos están en pausa» y no como «tu cuenta ya no vale» — ticket
                // `groups-killswitch-403-blocks-detach-forever`.
                channelKilled: GroupsSyncClient.shared.stoppedByChannelKill(for: outcome),
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
            CloudSignOutFlowLogic.isPersonalSaveSafe(
                mountAttachesMirror: personalMountAttachesMirror,
                accountAvailable: iCloudSyncService.shared.isAccountAvailable,
                firstImportCompleted: iCloudSyncService.shared.hasCompletedFirstImport,
                importQuiescent: iCloudSyncService.shared.isImportQuiescent)
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
