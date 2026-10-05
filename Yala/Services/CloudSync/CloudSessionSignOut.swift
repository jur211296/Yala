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
        /// No se soltó nada, y no se escribió nada irreversible. **El motivo viaja AQUÍ y la fase vuelve a
        /// `.idle` antes de devolver** (ticket `detach-blocked-phase-is-stranded-when-the-storage-sheet-closes-mid-wait`):
        /// hasta el 2026-10-02 la fase se quedaba en `.blocked` y la pantalla la leía de ahí, así que con la hoja de
        /// Almacenamiento cerrada a mitad de la espera nadie la reconocía —su aviso se escribía en una vista ya
        /// desmontada— y «Cerrar sesión» y el desasociar siguiente chocaban con un bloqueo que nadie iba a quitar.
        /// Ver `releaseDetachBlock`. **No se llama `blockedByPush` a propósito**: cubre también el abort por un puente
        /// que no se pudo ni mirar, que no tiene nada que ver con subir cambios — y con ese nombre el mensaje que salía
        /// («quedan cambios sin subir, inténtalo en un momento») describía un problema que no era y daba un consejo
        /// que no arreglaba nada.
        ///
        /// **Lleva el aviso ya decidido, no el motivo a secas** (2026-10-05, ticket
        /// `detach-with-a-stuck-groups-drain-names-only-the-first-of-two-causes`): con la captura de grupos atascada y un
        /// motivo que en un cierre abriría la salida (sin sesión, sin App Attest, otra cuenta), el aviso nombra las dos causas
        /// (`CloudSignOutFlowLogic.detachBlockedNotice`). El testigo de la captura vive en el coordinador, así que lo decide él.
        case blockedBeforeWriting(notice: CloudSignOutFlowLogic.DetachBlockedNotice)
        /// **La cuenta se cerró en la nube pero el borrado local NO entró.** Los grupos siguen en el
        /// teléfono y la asociación sigue en pie a propósito. Se le ofrece reintentar el borrado.
        case purgeFailed
        /// El coordinador estaba ocupado (un cierre de sesión en curso). No se tocó nada.
        case busy
    }

    private(set) var phase: Phase = .idle {
        // Con varias ventanas, quién lanzó el cierre se fija al entrar en `.working` (fase 4 del carril adaptativo).
        didSet { SceneRegistry.shared.signOutPhaseDidChange(from: oldValue, to: phase) }
    }

    /// `true` mientras corre un desasociar o su reintento del borrado. **Es del coordinador y no de la vista**: la hoja de
    /// Almacenamiento puede cerrarse y volver a abrirse a mitad de la espera (hasta un minuto), y una sección nueva no
    /// hereda el `@State` de la que lanzó el gesto. Sin esto, la reabierta no pintaba el spinner y un toque en
    /// «Desasociar» chocaba con el gesto en vuelo y decía «Estás cerrando sesión», que es falso. No sirve `phase` a
    /// secas: `.working` es también la de un cierre de sesión.
    private(set) var isDetaching = false

    /// `true` mientras el sign-out solo-grupos ESPERA a que se asienten writes pendientes
    /// (quiescencia del import + retry interno con presupuesto, H-2026-07-18-6). La fila de
    /// Ajustes muestra un caption honesto ("Guardando tus cambios pendientes…") — el bloqueo
    /// típico es transitorio y antes obligaba al usuario a tocar "Cerrar sesión" 2-3 veces.
    private(set) var waitingForPending: Bool = false

    /// Vuelve a `.idle` tras un `.blocked` (el usuario cerró el error).
    func acknowledgeBlocked() {
        if case .blocked = phase {
            phase = .idle
            // La salida que pierde los cambios de grupos es de ESTE bloqueo: reconocerlo la retira, y lo aceptado no
            // sobrevive a un gesto nuevo. **Solo con la fase bloqueada** (review adversarial, 2026-09-15): un
            // reconocimiento que llega con el cierre trabajando —el doble cierre de un alert ajeno— borraba la aceptación
            // en vuelo, y el cierre volvía a preguntar o bloqueaba tras soltar el canal.
            groupsLossExit = nil
            acceptedGroupsLoss = nil
            // Y la de los cambios PERSONALES en la nube, por lo mismo (2026-09-15): «Ahora no» en cualquiera de los dos avisos
            // retira las dos aceptaciones, porque el cierre que las tenía ya no sigue.
            personalLossExit = nil
            acceptedPersonalLoss = nil
        }
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
        // Con la subida de «Empezar de cero» en vuelo tampoco: sube el mismo outbox (`freshStartDrainInFlight`).
        guard phase == .idle, !freshStartDrainInFlight else { return }
        // Un gesto nuevo no hereda lo que otro aceptó perder (las salidas del teléfono sin App Attest, la de grupos y la
        // personal).
        groupsLossExit = nil
        acceptedGroupsLoss = nil
        personalLossExit = nil
        acceptedPersonalLoss = nil
        // Ni lo que vio la captura de otro gesto: una celda que no captura no puede contar el History por un atasco viejo.
        groupsCaptureStuck = false
        provenStuckGroupsChanges = []
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
    /// no vacía, el gesto devuelve `.blockedBeforeWriting` con el motivo y **no se suelta nada** (la fase vuelve a `.idle`:
    /// `releaseDetachBlock`). Reintentar es seguro porque hasta el
    /// paso 2 no se ha escrito nada. Lo mismo si la sesión en la nube **sobrevive** a su cierre (`.sessionNotClosed`):
    /// el cierre va delante del paso 2 y se comprueba, porque con la sesión viva el borrado del paso 3 se deshace solo
    /// en el siguiente primer plano, y peor.
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
        // Con la subida de «Empezar de cero» en vuelo tampoco: sube el mismo outbox (`freshStartDrainInFlight`).
        guard phase == .idle, !freshStartDrainInFlight else { return .busy }
        phase = .working
        isDetaching = true
        defer {
            waitingForPending = false
            isDetaching = false
        }
        // El desasociar no hereda lo que un cierre aceptó perder, ni ofrece esa salida: ver `lossExit: nil` abajo.
        groupsLossExit = nil
        acceptedGroupsLoss = nil
        personalLossExit = nil
        acceptedPersonalLoss = nil
        // Ni lo que vio la captura de otro gesto: una celda que no captura no puede contar el History por un atasco viejo.
        groupsCaptureStuck = false
        provenStuckGroupsChanges = []

        // (1) Antes de tocar credenciales.
        let associatedSub = GroupsAccountAssociation.shared.associatedSub ?? CloudAuthService.shared.currentUserID

        // Lo pendiente sube ANTES de cortar nada, con la generación intacta. Mismo presupuesto de
        // reintentos que el cierre: el bloqueo típico es transitorio.
        //
        // **`lossExit: nil` es la decisión de Jürgen** (2026-09-15): con el teléfono sin App Attest el desasociar enseña el
        // aviso terminal y NO ofrece soltar la cuenta perdiendo los cambios. Solo los cierres de sesión lo ofrecen.
        //
        // **El único bloqueo que puede llevar dos causas** (2026-10-05): el push-all deja puesto si su última captura se quedó
        // atascada, sin `await` entre esa captura y aquí.
        guard await pushGroupsForSignOut(context: context, lossExit: nil) else {
            return .blockedBeforeWriting(notice: releaseDetachBlock(captureStuck: groupsCaptureStuck))
        }

        // Canal fuera + espejo del outbox del App Group purgado. Idempotente.
        GroupsSyncClient.shared.teardownForSignOut()

        // Molde S2 del cierre: una fila encolada entre el push-all y el teardown ya no puede subir, así
        // que es `.permanent`. Va ANTES de cerrar la sesión: con ella viva, el loop del siguiente primer
        // plano sube esa fila, y cerrada haría falta volver a entrar para subirla.
        let residual = Self.liveGroupsPendingCount(context: context)
        guard residual == 0 else {
            phase = .blocked(pendingCount: residual, reason: .permanent)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: residual)
            return .blockedBeforeWriting(notice: releaseDetachBlock(captureStuck: false))
        }

        // El consent de Grupos NO se limpia aquí, a diferencia del cierre de sesión. Es un snapshot
        // SELLADO con el `userID` (`GroupsConsentState`), así que no puede colarse en la cuenta
        // siguiente: si vuelve la misma, casa y no se le vuelve a preguntar algo que ya aceptó; si entra
        // otra, el sello no casa y se le pregunta igual. Borrarlo solo costaría una pantalla de más a
        // quien re-asocia.
        //
        // **La sesión se cierra ANTES del puente, y se COMPRUEBA** (ticket
        // `detach-does-not-verify-the-cloud-session-actually-closed`). Si sobrevive —el llavero no la borró, o
        // un refresco del token en vuelo la repuso—, todo lo de abajo deja el teléfono peor que antes: en el
        // siguiente primer plano el loop arranca con esa sesión, el cursor ya está borrado y el corpus
        // entero vuelve a bajar; con la asociación limpia el libro de conservados no casa y se re-puentea
        // todo, en silencio, al lado de lo que la persona eligió conservar. Parado aquí, el teléfono queda
        // como con el bloqueo de arriba: canal cortado y nada del dominio Grupos escrito, y reintentar es el
        // gesto entero. (Lo que `signOut()` borra antes de tocar la sesión —perfil capturado, proveedor, la
        // caché del entitlement— sí se va, igual que con cualquier cierre que falle: el reintento lo repite.)
        //
        // Detrás del puente no valdría: el puente ya estaría soltado con la asociación en pie, y el reintento
        // volvería a ofrecer las dos salidas cuando la segunda ya no puede aplicarse.
        guard await CloudAuthService.shared.signOut() else {
            phase = .blocked(pendingCount: 0, reason: .sessionNotClosed)
            // Fuera de `#if DEBUG`: el ticket dejó sin medir si esto pasa en la flota, y este es el sitio donde
            // se ve.
            MetricsService.canary(.groupsDetachSessionSurvived, detail: "choice=\(choice == .keep ? "keep" : "remove")")
            return .blockedBeforeWriting(notice: releaseDetachBlock(captureStuck: false))
        }

        // ── Punto de no retorno ──
        //
        // (2) y (3), el puente y el borrado, van JUNTOS por `writeDetachUnderQuiescence`, que vuelve a pedir la
        // quiescencia del store personal pegada a sus dos `save()` (ticket
        // `detach-saves-the-personal-graph-outside-the-quiescence-window`). La que se comprobó dentro del push-all ya
        // no vale aquí: entre ella y estos `save()` hay hasta 20 ciclos con red, sus pausas y el `signOut()` de
        // arriba, y en `.icloud` el espejo sigue vivo sobre el `mainContext` compartido. Un import que arranque en
        // esa ventana y un `save()` del puente —que escribe el grafo PERSONAL, `TransactionItem` e `InboxDraft`—
        // son el `_assertionFailure` que ningún `do/catch` atrapa, y este camino no termina en un boot-wipe que lo
        // tape.
        //
        // **La sesión se vuelve a mirar DESPUÉS de la espera** (`stillMayWrite`): hasta 60 s con la app usable dejan
        // volver a entrar, y escribir con la sesión de vuelta es el daño que la comprobación de arriba impide.
        switch await Self.writeDetachUnderQuiescence(
            context: context, bridge: .init(choice: choice, associatedSub: associatedSub),
            stillMayWrite: { CloudAuthService.shared.storedSessionIsGone }) {
        case .preconditionLost:
            // La sesión volvió mientras se esperaba la quietud: lo mismo que si hubiera sobrevivido a su cierre.
            phase = .blocked(pendingCount: 0, reason: .sessionNotClosed)
            MetricsService.canary(
                .groupsDetachSessionSurvived,
                detail: "choice=\(choice == .keep ? "keep" : "remove") after=quiescence")
            return .blockedBeforeWriting(notice: releaseDetachBlock(captureStuck: false))
        case .notQuiescent, .bridgeUnreadable:
            // **Si el store no se quedó quieto, o el puente no se pudo ni mirar, se ABORTA sin escribir nada**:
            // seguir adelante borraría las filas de los grupos dejando las transacciones puenteadas apuntando a
            // una zona que ya no existe, y a ésas no las recoge ningún barrido — el veredicto de zona que
            // `OrphanedBridgedTxSweeper` exige se construye de filas vivas. Sería dinero atrapado para siempre, y
            // hasta aquí no se ha escrito nada irreversible. La sesión ya está cerrada, y eso no suelta nada: la
            // asociación sigue en pie, la sección pasa a la celda del segundo móvil y el reintento no necesita
            // sesión con el outbox vacío.
            //
            // **«No se pudo mirar» incluye que el `save()` del puente fallara** (`detachBridge` devuelve `nil` en
            // los dos casos desde el 2026-09-11) **y que el store no se quedara quieto a tiempo**: los dos dejan los
            // movimientos del Panel sin revisar y nada soltado, y el aviso de `.bridgeUnreadable` dice exactamente
            // eso. `.transient` diría «quedan cambios de tus grupos sin subir», y aquí el push-all ya drenó.
            phase = .blocked(pendingCount: 0, reason: .bridgeUnreadable)
            return .blockedBeforeWriting(notice: releaseDetachBlock(captureStuck: false))
        case .purgeFailed:
            // **El borrado es la última CONDICIÓN del gesto, no su último paso.** Todo lo de abajo afirma que la
            // cuenta ya no está aquí, y eso solo es cierto si esto entró. Un `catch` que siguiera adelante —lo que
            // había hasta el 2026-09-11— dejaba la asociación borrada sobre unos grupos enteros: la pantalla decía
            // una cosa y el teléfono otra, y la que se equivocaba era la pantalla.
            //
            // **La marca es DURABLE porque la fase no lo es.** Sin ella, al reabrir la app la sección volvería a
            // ofrecer el gesto entero con sus dos salidas, y la segunda ya no puede aplicarse: el puente está
            // soltado. Ver `GroupsDetachPendingPurge`.
            GroupsDetachPendingPurge.arm(sub: associatedSub)
            // Canario FUERA de `#if DEBUG`, molde `freshStartWipeFailed`: este fallo era invisible en producción y
            // es su hermano exacto —un borrado que no ocurrió y una UI que decía que sí—. Sin PII: solo qué eligió
            // la persona para el puente, que es lo que cambia el volumen de filas que la transacción tocaba.
            MetricsService.canary(
                .groupsDetachPurgeFailed,
                detail: "choice=\(choice == .keep ? "keep" : "remove")")
            // NADA de lo de abajo corre. La asociación se queda, y con la sesión ya cerrada la sección pasa a
            // `.associatedNeedsSignIn` —la celda del segundo móvil—, que vuelve a ofrecer el gesto.
            phase = .idle
            return .purgeFailed
        case .written:
            break
        }

        finishDetach(context: context)
        return .detached
    }

    /// **El bloqueo del desasociar no se queda en la fase compartida**: devuelve su motivo y deja la fase en `.idle`, en el
    /// mismo turno del main actor en que se puso (ticket
    /// `detach-blocked-phase-is-stranded-when-the-storage-sheet-closes-mid-wait`). Todo `return .blockedBeforeWriting` de
    /// `detachGroupsAccount` pasa por aquí, y es el ÚNICO sitio que suelta ese bloqueo.
    ///
    /// Por qué no se espera a que lo reconozca la pantalla, que era el contrato hasta el 2026-10-02: la fase es de seis
    /// lectores y el desasociar no tiene dueño que la suelte. Con la hoja de Almacenamiento cerrada a mitad de la espera,
    /// el `Task` de la sección escribía su aviso en una vista ya desmontada y nadie llamaba a `acknowledgeBlocked()`; Perfil
    /// ignora a propósito los motivos del desasociar, así que «Cerrar sesión» no hacía nada y un desasociar nuevo devolvía
    /// `.busy` («Estás cerrando sesión», falso). Solo salía matando la app.
    ///
    /// La fase pasa por `.blocked` y no se escribe el motivo directo porque `pushGroupsForSignOut` —compartido con los
    /// cierres— lo deja ahí; las ramas propias del desasociar lo escriben igual para que el motivo tenga un solo camino. No
    /// hay `await` entre esa escritura y esta lectura, así que ningún lector de la fase llega a ver el `.blocked`. El
    /// `.transient` de reserva no es alcanzable: toda rama que llama aquí acaba de poner la fase en `.blocked`.
    ///
    /// `captureStuck` lo pasa cada llamada, sin valor por defecto: solo el bloqueo del push-all puede venir con la captura
    /// de grupos atascada (`groupsCaptureStuck`); los demás bloquean después de que el push-all drenara y pasan `false`. El
    /// aviso lo decide `CloudSignOutFlowLogic.detachBlockedNotice`.
    private func releaseDetachBlock(captureStuck: Bool) -> CloudSignOutFlowLogic.DetachBlockedNotice {
        defer { phase = .idle }
        guard case .blocked(_, let reason) = phase else { return .reason(.transient) }
        return CloudSignOutFlowLogic.detachBlockedNotice(reason: reason, captureStuck: captureStuck)
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
        isDetaching = true
        defer { isDetaching = false }
        // Un turno del main actor antes de trabajar. Sin él este método no suspende NUNCA —no tiene un
        // solo `await`— así que SwiftUI no re-renderiza entre `.working` y `.idle`: el spinner no llega a
        // salir, y un segundo fallo encendería el aviso en el MISMO turno en que el anterior se está
        // desmontando, que es la carrera de dos presentaciones en un anchor que este repo ya pagó.
        await Task.yield()
        // El borrado pasa por la MISMA puerta que el del gesto: es un `save()` sobre el `mainContext` compartido, y
        // en `.icloud` el espejo sigue vivo. Era la única purga de grupos de este coordinador sin quiescencia.
        switch await Self.writeDetachUnderQuiescence(
            context: context, bridge: nil,
            // La condición del `guard` de arriba, otra vez tras la espera: la sesión de ESA cuenta pudo volver.
            stillMayWrite: { CloudAuthService.shared.currentUserID != GroupsDetachPendingPurge.armedSub() }) {
        case .written:
            break
        case .preconditionLost:
            phase = .idle
            return .busy
        case .purgeFailed:
            MetricsService.canary(.groupsDetachPurgeFailed, detail: "retry")
            phase = .idle
            return .purgeFailed
        case .notQuiescent, .bridgeUnreadable:
            // No se borró nada y la marca sigue armada: el aviso «No pudimos soltar la cuenta… Vuelve a intentarlo
            // para terminar» es exacto. Sin canario: el borrado no falló, no llegó a intentarse. (`.bridgeUnreadable`
            // no puede salir sin puente; va aquí para que el `switch` siga siendo exhaustivo.)
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
    /// cursor que es del PULL. **Outbox, filas y cursor, en ese orden y cada uno en su `save()`** — no en uno,
    /// porque uno que cruza stores no es una transacción: medido el 2026-10-01 con el store de Grupos en solo
    /// lectura, el sync-meta quedaba comiteado igual y salía el par incoherente «cursor borrado + filas vivas»
    /// (ticket `groups-purge-save-crosses-two-stores-without-atomicity`). Con el orden, el único corte dañino
    /// posible es «filas borradas + cursor vivo» y sin outbox, que es local y tiene salida: el reintento que el
    /// `catch` del desasociar arma, y el Merkle de Grupos si la persona vuelve a entrar (que salta los grupos
    /// con dead-letters: por eso el outbox va primero). El orden lo pone `deleteLocalGroupsRows`.
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
    ///  2. **El cursor se borra ENTERO —detrás de las filas, en su propio `save()`— y la firma es la ÚNICA defensa
    ///     de estos deletes. Conservar el ancla del drain se probó y se retiró, medido** (review adversarial
    ///     del 2026-09-11, tres lentes):
    ///      - **No los protege.** El ancla que sobreviviría es la del último drain ANTERIOR al desasociar, y
    ///        estos deletes son posteriores: `fetchHistory($0.token > token)` los devuelve igual. Lo único
    ///        que los descarta es el autor.
    ///      - **Lo que evitaría —re-barrer el History viejo— no produce nada aquí.** Con las filas ya
    ///        borradas, el `case` de insert/update no resuelve ninguna fila viva por `PersistentIdentifier`
    ///        y no emite. Medido: 0 filas. (Con las filas VIVAS sí re-emite, 1 upsert con HLC nuevo por
    ///        fila — ése es el par «cursor borrado + filas vivas» que el ORDEN de los `save()` impide, y
    ///        lo fijan `GroupsDetachHistoryReplayTests` y `GroupsPurgeCrossStoreOrderTests`.)
    ///      - **Y cuesta.** `lastDrainedTxAt` es uno de los cuatro suelos del corte de purga del History
    ///        (`CloudSyncEngine.groupDrainedBoundary`). Conservarlo sin canal que lo avance —tras soltar la
    ///        cuenta no hay sesión, así que el loop no arranca— lo deja congelado en el instante del
    ///        desasociar: hoy es inocuo porque la purga solo corre con el runtime personal, que es de
    ///        `.cloud`, pero clavaría el corte para siempre en cuanto esa persona migrara a la nube.
    ///     ⇒ el par coherente en esta frontera de CUENTA sigue siendo **«filas borradas + cursor borrado»**,
    ///     con el borrado firmado. Hasta el 2026-10-01 aquí decía «atómico», y no lo era: lo que hay es un
    ///     ORDEN cuyo único corte posible es el par reparable (ver arriba).
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
            var rows: [any PersistentModel] = try context.fetch(FetchDescriptor<GroupSyncOutbox>())
            rows += try context.fetch(FetchDescriptor<GroupSyncCursor>()) as [any PersistentModel]
            return rows
        }
        SaveBreadcrumb.didSave("CloudSessionSignOut.detachGroupsAccount")
    }

    /// Lo que el desasociar ESCRIBE —el puente personal y el borrado del dominio Grupos— detrás de la quiescencia
    /// del store personal, comprobada OTRA VEZ y pegada a esos `save()`.
    enum DetachWrite: Equatable {
        /// El store personal no se quedó quieto dentro del tope de la puerta. No se escribió nada.
        case notQuiescent
        /// La condición de quien llama dejó de cumplirse durante la espera (`stillMayWrite`). No se escribió nada.
        case preconditionLost
        /// `detachBridge` no pudo mirar el puente (su fetch lanzó o su `save()` no entró). No se escribió nada.
        case bridgeUnreadable
        /// El puente se soltó, pero el borrado del dominio Grupos lanzó. El contexto queda limpio
        /// (`deleteLocalGroupsRows` hace `rollback()`).
        case purgeFailed
        /// Las dos cosas entraron.
        case written
    }

    /// La salida del puente que eligió la persona y la cuenta que sella el libro de conservados. `nil` en el
    /// reintento del borrado (`retryDetachPurge`), que ya no toca el puente.
    struct DetachBridgeRelease: Equatable {
        let choice: GroupsAssociationDetach.BridgedRowsChoice
        let associatedSub: String?
    }

    /// La puerta de quiescencia, y después los `save()` del desasociar **sin un solo `await` entre medias**
    /// (ticket `detach-saves-the-personal-graph-outside-the-quiescence-window`).
    ///
    /// **Por qué se vuelve a pedir la puerta, si el push-all ya la pidió.** Esa comprobación vive dentro de
    /// `attemptGroupsOnlyClose`, antes del push-all, y entre ella y el `save()` del puente pueden pasar hasta 20
    /// ciclos con red, sus pausas de 250 ms y el `signOut()` del desasociar. En `.icloud` el espejo de CloudKit
    /// sigue vivo y el `mainContext` lo comparten los tres stores: un import que arranque en esa ventana deja el
    /// store a medio asentar, y un `save()` encima es el `_assertionFailure` de SwiftData que no atrapa ningún
    /// `do/catch`. Este camino es además el único de la familia que escribe el grafo PERSONAL (`TransactionItem`,
    /// `InboxDraft`) y el único que no termina en un boot-wipe que tape el destrozo.
    ///
    /// **Lo que hace honesta la puerta es lo que va DESPUÉS de ella**: el `safe()` que devuelve se lee en el mismo
    /// turno del main actor en que corren los dos `save()`. Un `await` entre la puerta y el puente —un
    /// `Task.yield()`, un log asíncrono— reabre la ventana entera, porque el estado del import lo actualizan
    /// notificaciones que se entregan en el main actor. El puente y el borrado van juntos aquí, y no el puente solo,
    /// por eso mismo: con una vuelta al llamador entre los dos, el borrado volvería a quedar fuera.
    ///
    /// **No se mueve el puente delante del push-all**, que era la otra salida del ticket: con el push bloqueado el
    /// puente quedaría soltado sin nada más hecho, y el reintento ofrecería las dos salidas cuando la segunda ya no
    /// puede aplicarse. Esto conserva el orden.
    ///
    /// La puerta ESPERA (sondeo cada 2 s, tope 60 s; en uso normal contesta al instante) y, si no llega, no se
    /// escribe nada. `awaitPersonalSaveSafe` es el seam de los tests; producción usa la de siempre.
    ///
    /// **`stillMayWrite` se evalúa tras la puerta, síncrono, y es obligatorio.** Antes de este escritor, entre la
    /// comprobación de quien llama (la sesión cerrada, en el gesto; la sesión que no es la de la cuenta pendiente, en
    /// el reintento) y los `save()` no había un solo `await`. La espera de la puerta abre esa ventana —hasta 60 s con
    /// la app usable—, así que la condición se vuelve a mirar aquí, donde ya nada puede suspender. Sin valor por
    /// defecto a propósito: un `{ true }` heredado sería una puerta que falla abierta.
    static func writeDetachUnderQuiescence(
        context: ModelContext,
        bridge: DetachBridgeRelease?,
        defaults: UserDefaults = .standard,
        stillMayWrite: () -> Bool,
        awaitPersonalSaveSafe: () async -> Bool = { await CloudSessionSignOut.awaitPersonalQuiescenceForGroupsSignOut() }
    ) async -> DetachWrite {
        guard await awaitPersonalSaveSafe() else { return .notQuiescent }

        // ── Desde aquí, sin `await`. ──

        guard stillMayWrite() else { return .preconditionLost }

        // (2) El puente, con las filas `Split*` todavía limpias: ver el docblock de `detachGroupsAccount`.
        if let bridge {
            guard GroupsAssociationDetach.detachBridge(
                context: context, choice: bridge.choice, associatedSub: bridge.associatedSub,
                defaults: defaults) != nil else {
                return .bridgeUnreadable
            }
        }

        // (3) Las filas, el outbox y el cursor, de una vez. Lo que propague sale como `.purgeFailed`, y quien llama
        // decide la marca y el canario.
        do {
            try purgeGroupsDomainForDetach(context: context)
        } catch {
            #if DEBUG
            print("CloudSessionSignOut: borrado local del dominio de grupos falló: \(error)")
            #endif
            return .purgeFailed
        }
        return .written
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

    /// Desde dónde retoma un cierre parado en `.attestUnavailable` si la persona acepta perder los cambios de grupos que
    /// no subieron (`exitDiscardingUnsyncedGroups`, ticket `groups-phone-that-never-attests-is-told-to-retry-forever`).
    /// Son los tres sitios donde un cierre sube grupos, y solo ésos: el desasociar comparte `pushGroupsForSignOut` y le
    /// pasa `nil`, así que su bloqueo no ofrece ninguna salida.
    ///
    /// **Los tres están ANTES de soltar credenciales**: el tramo final de D y F sube grupos antes del teardown, y la nube
    /// en su paso 2. Por eso retomar vuelve a entrar por la función entera y no necesita el `credentialsReleased` de
    /// `BlockedExit`.
    private enum GroupsLossResume {
        /// El inicio de D y F, antes de la espera del export.
        case sessionExit(CloudSignOutFlowLogic.ExitPlan)
        /// El tramo final de D y F, con la política del export que ya se decidió.
        case finalize(kind: CloudSignOutFlowLogic.ExitKind, export: ExportPolicy)
        /// El paso 2 del cierre en la nube.
        case cloud
    }

    /// La salida ofrecida: desde dónde retomar, QUÉ filas contó el aviso, por su `clientMutationID` (`nil` si el recuento
    /// falló y el aviso salió sin cifra), y por qué no suben (`cause`, desde el 2026-09-28: el attest, la sesión que no hay
    /// o la otra cuenta). Se anotan juntas, en el mismo tramo síncrono que la cifra de la fase.
    ///
    /// **Desde el 2026-10-05 lo contado son dos mitades** (`CloudSignOutFlowLogic.GroupsLoss`, ticket
    /// `groups-drain-that-always-aborts-takes-the-loss-exit-away`): las filas y, con la captura atascada, los cambios del
    /// History que el drain no capturó.
    private struct GroupsLossOffer {
        let resume: GroupsLossResume
        let loss: CloudSignOutFlowLogic.GroupsLoss
        let cause: CloudSignOutFlowLogic.LossCause
    }
    private var groupsLossExit: GroupsLossOffer?

    /// **¿La última captura de grupos de este gesto se quedó atascada?** (`captureGroupsForExit`, 2026-10-05). Decide si la
    /// oferta de perder los cambios lee el History (`groupsLoss`): con la captura completa no hay nada fuera del outbox y el
    /// History no se lee. La pone cada captura con reintentos y la baja cada gesto nuevo.
    private var groupsCaptureStuck = false

    /// **Los cambios del History que este gesto ya probó atascados** (`captureGroupsForExit`): con ellos, la captura siguiente
    /// del mismo gesto no repite los segundos de reintentos si alguno sigue fuera. La baja cada gesto nuevo.
    private var provenStuckGroupsChanges: Set<String> = []

    /// Sustituye cada espera entre reintentos de la captura previa a una salida, sin cambiar cuántos intentos hay. Solo los
    /// tests, que no esperan; `nil` = las de producción (`CloudSignOutFlowLogic.groupsExitCaptureRetryDelays`).
    var exitCaptureDelayOverride: Duration?

    /// Lo que la persona aceptó perder en ESTE cierre: las filas del aviso, o cualquiera si salió sin cifra, y la causa por
    /// la que las aceptó. `nil` fuera de él. Lo leen los sitios que suben grupos y los dos recuentos finales, siempre con
    /// `CloudSignOutFlowLogic.continuesWithoutUploading`, que compara por fila.
    private var acceptedGroupsLoss: CloudSignOutFlowLogic.CausedLossAcceptance?

    /// ¿El bloqueo en pantalla ofrece salir perdiendo los cambios de grupos? Solo un motivo que abre la salida
    /// (`CloudSignOutFlowLogic.lossCause`: el attest, la sesión caducada, la otra cuenta) puesto por un CIERRE, con la
    /// oferta de esa misma causa: el mismo motivo puesto por el desasociar no tiene desde dónde retomar. Las vistas lo
    /// preguntan antes de pintar el botón, y `exitDiscardingUnsyncedGroups` lo vuelve a exigir.
    var offersGroupsLossExit: Bool {
        guard case .blocked(_, let reason) = phase, let cause = CloudSignOutFlowLogic.lossCause(reason),
              let offer = groupsLossExit else { return false }
        return offer.cause == cause
    }

    /// La salida ofrecida al cerrar sesión en la NUBE con cambios PERSONALES sin subir y un teléfono sin App Attest
    /// (`exitDiscardingUnsyncedPersonalChanges`, ticket `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`):
    /// QUÉ filas de `SyncOutbox` contó el aviso, por su `clientMutationID` (`nil` si el recuento falló y el aviso salió sin
    /// cifra), y **por qué no suben** (`cause`, desde el 2026-09-28: el attest o la sesión que no hay, ticket
    /// `cloud-sign-out-with-an-expired-session-and-personal-changes-has-no-exit`). Siempre retoma el mismo sitio —el cierre en
    /// la nube—, así que no guarda desde dónde. **Desde el 2026-10-05 cuenta también los cambios del History que el drain no
    /// capturó** (`CloudSignOutFlowLogic.PersonalLoss`, ticket
    /// `personal-drain-that-always-aborts-blocks-cloud-sign-out-with-a-wait-a-moment-copy`): con un drain que no termina nunca
    /// esos cambios no llegan al outbox, y son lo que el borrado se lleva.
    private struct PersonalLossOffer {
        let loss: CloudSignOutFlowLogic.PersonalLoss
        let cause: CloudSignOutFlowLogic.LossCause
    }
    private var personalLossExit: PersonalLossOffer?

    /// Lo que la persona aceptó perder de sus cambios PERSONALES en este cierre, con la causa del aviso que lo enseñó: retomar
    /// solo sigue sin subir mientras el bloqueo siga siendo de ESA causa. `nil` fuera de él.
    ///
    /// **Sobrevive al aviso de grupos, a propósito**: con cambios de los dos lados salen dos avisos seguidos (decisión de
    /// Jürgen), y aceptar el de grupos retoma el cierre en la nube desde el paso 1, que tiene que seguir encontrando aquí lo
    /// aceptado. Lo retiran «Ahora no» (`acknowledgeBlocked`), un gesto nuevo y el propio paso 1 cuando vuelve a bloquear.
    private var acceptedPersonalLoss: CloudSignOutFlowLogic.PersonalLossAcceptance?

    /// ¿El bloqueo en pantalla ofrece exportar y salir perdiendo los cambios personales? Solo un motivo que abre esa salida
    /// (`CloudSignOutFlowLogic.personalLossCause`: el attest, y desde el 2026-09-28 la sesión caducada) con la oferta viva de
    /// esa MISMA causa: `.cloudSessionExpired` lo pone también el paso 2, sobre los cambios de grupos, y ése tiene su propia
    /// oferta. Ajustes lo pregunta antes de pintar el aviso, y `exitDiscardingUnsyncedPersonalChanges` lo vuelve a exigir.
    var offersPersonalLossExit: Bool {
        guard case .blocked(_, let reason) = phase, let cause = CloudSignOutFlowLogic.personalLossCause(reason),
              let offer = personalLossExit else { return false }
        return offer.cause == cause
    }

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
    ///
    /// **Antes de contar, convierte en borrador lo que espera en el App Group** (Apple Pay, Siri): si no, el
    /// borrado se lo lleva sin haberlo contado. Lo que no se pudo convertir suma como pendiente
    /// (`PrivateSignOutExportGateLogic.pendingCountMaterializingInbound`).
    static func pendingPersonalExportCount(context: ModelContext) -> Int? {
        PrivateSignOutExportGateLogic.pendingCountMaterializingInbound(
            materialize: { InboundCaptureDrain.forSignOut(context: context) },
            historyPending: { _ in personalHistoryPendingCount(context: context) })
    }

    /// Solo el historial del store personal, sin tocar las colas del App Group.
    private static func personalHistoryPendingCount(context: ModelContext) -> Int? {
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

        // Lo primero, antes de subir ni esperar nada: con el paso de los datos a la nube fuera de reposo no se empieza.
        // El que decide es el de pegado al arm (`armAfterCredentials`); éste evita soltar la sesión de grupos para nada.
        if blockIfMigrationNotAtRest(kind: plan.kind) { return }
        guard await captureGroupsBeforeCountingThem(context: context, kind: plan.kind) else { return }
        if blockIfGroupsCannotUpload(context: context, kind: plan.kind, lossExit: .sessionExit(plan)) { return }
        if plan.waitsForExport {
            if plan.kind.pushesGroups {
                guard await pushGroupsForSignOut(context: context, lossExit: .sessionExit(plan)) else { return }
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

    /// **«Cerrar sesión y perderlos»**: el cierre de un teléfono que lleva más de un día sin App Attest sigue sin subir
    /// los cambios de grupos que no llegan (decisión de Jürgen del 2026-09-15, ticket
    /// `groups-phone-that-never-attests-is-told-to-retry-forever`). Es la excepción ACOTADA a «nunca descarta»: solo la
    /// alcanza un bloqueo `.attestUnavailable` que puso un CIERRE (`offersGroupsLossExit`), y solo corre si la persona la
    /// elige en ese aviso.
    ///
    /// **Aquí no se borra nada.** Retoma el cierre donde paró con las filas del aviso como lo aceptado
    /// (`acceptedGroupsLoss`): los sitios que suben grupos lo intentan una vez —si el attest volvió, suben— y siguen sin
    /// ellas mientras el bloqueo siga siendo el attest y las que queden estén entre las aceptadas; si aparece otra, vuelve
    /// el aviso con la cifra nueva. Los
    /// cambios mueren con el boot-wipe de siempre, por archivos, y un bloqueo posterior por otro motivo deja todo como
    /// estaba.
    ///
    /// **Desde el 2026-09-28 la abren también la sesión que no hay y la otra cuenta** (ticket
    /// `groups-outbox-rows-without-a-live-session-have-no-exit`, decisión 1 del encargo): quien no puede volver a entrar
    /// —cuenta borrada, correo perdido— no tenía forma de cerrar sesión en ese teléfono. «Vuelve a entrar» sigue siendo el
    /// camino por defecto del aviso; esto es lo que hace el botón que nombra la pérdida.
    func exitDiscardingUnsyncedGroups(context: ModelContext) async {
        guard offersGroupsLossExit, case .blocked(let shown, _) = phase, let offer = groupsLossExit else { return }
        groupsLossExit = nil
        // Lo aceptado son las filas que contó el aviso. Sin cifra honesta —el recuento falló— cubre cualquiera: es el «no
        // pudimos contar» que se le enseñó. Con la causa del aviso: retomar solo sigue mientras el bloqueo sea de ESA causa.
        // Desde el 2026-10-05, también los cambios del History que el aviso contó con la captura atascada.
        acceptedGroupsLoss = CloudSignOutFlowLogic.CausedLossAcceptance(offer: offer.loss, cause: offer.cause)
        CloudSyncBreadcrumb.signOutGroupsLossAccepted(pending: CloudSignOutFlowLogic.shownLossCount(shown))
        phase = .working
        defer { waitingForPending = false }
        switch offer.resume {
        case .sessionExit(let plan):
            await performSessionExit(context: context, plan: plan)
        case .finalize(let kind, let export):
            await finalizeSessionExit(context: context, kind: kind, export: export)
        case .cloud:
            await performCloudSecureSignOut(context: context)
        }
    }

    /// Un cierre enseñó el aviso que ofrece perder los cambios de grupos: rastro y canario, sin PII. El del attest conserva
    /// su canario (su serie viene del 2026-09-15); las otras dos causas van al suyo, con la causa en el detalle.
    private static func noteGroupsLossOffered(pending: Int, cause: CloudSignOutFlowLogic.LossCause) {
        let shown = CloudSignOutFlowLogic.shownLossCount(pending)
        let count = "pending=\(shown.map(String.init) ?? "unknown")"
        switch cause {
        case .attestUnavailable:
            CloudSyncBreadcrumb.signOutGroupsAttestUnavailable(pending: shown)
            MetricsService.canary(.groupsSignOutAttestUnavailable, detail: count)
        case .noSession, .otherAccount:
            CloudSyncBreadcrumb.signOutGroupsLossOffered(cause: cause.rawValue, pending: shown)
            MetricsService.canary(.groupsSignOutLossOffered, detail: "cause=\(cause.rawValue) \(count)")
        }
    }

    /// El cierre va a armar el borrado con cambios de grupos que la persona aceptó perder. Solo cuenta si queda alguno:
    /// con cero, lo que los frenaba se arregló entre el tap y aquí (el attest volvió, la persona entró) y subieron.
    private static func noteGroupsDiscarded(pending: Int, cause: CloudSignOutFlowLogic.LossCause) {
        guard pending > 0 else { return }
        let shown = CloudSignOutFlowLogic.shownLossCount(pending)
        let count = "pending=\(shown.map(String.init) ?? "unknown")"
        CloudSyncBreadcrumb.signOutGroupsDiscarded(pending: shown)
        switch cause {
        case .attestUnavailable:
            MetricsService.canary(.groupsSignOutAttestDiscarded, detail: count)
        case .noSession, .otherAccount:
            MetricsService.canary(.groupsSignOutLossDiscarded, detail: "cause=\(cause.rawValue) \(count)")
        }
    }

    /// **«Cerrar sesión y perderlos» en el aviso de tus datos** (decisión de Jürgen del 2026-09-15, ticket
    /// `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`): el cierre en la nube de un teléfono que lleva
    /// más de un día sin App Attest sigue sin subir los cambios PERSONALES que no llegan. Es la excepción ACOTADA a «jamás
    /// descartar» de ese cierre: solo la alcanza un bloqueo que abre la salida (`CloudSignOutFlowLogic.personalLossCause`)
    /// con su oferta viva (`offersPersonalLossExit`), y solo corre si la persona la elige, en un aviso que antes le ofreció
    /// exportar sus movimientos.
    ///
    /// **Desde el 2026-09-28 la abre también la sesión caducada** (ticket
    /// `cloud-sign-out-with-an-expired-session-and-personal-changes-has-no-exit`): quien no puede volver a entrar —cuenta
    /// borrada, correo perdido— no tenía forma de cerrar sesión en ese teléfono. «Vuelve a entrar» sigue siendo el camino por
    /// defecto del aviso; esto es lo que hace el botón que nombra la pérdida.
    ///
    /// **Aquí no se borra nada.** Retoma el cierre en la nube con las filas del aviso y su causa como lo aceptado
    /// (`acceptedPersonalLoss`): el paso 1 intenta subir una vez —si el attest volvió o la persona entró, suben— y sigue
    /// mientras el bloqueo sea otra vez de esa causa y lo que quede esté entre lo aceptado. Con otro motivo bloquea como
    /// siempre, y si aparece otra fila vuelve el aviso con la cifra nueva. Si después se para en los cambios de grupos, sale
    /// su propio aviso, y aceptarlo retoma el cierre con esto aún aceptado. Los cambios mueren con el boot-wipe de siempre,
    /// por archivos.
    func exitDiscardingUnsyncedPersonalChanges(context: ModelContext) async {
        guard offersPersonalLossExit, case .blocked(let shown, _) = phase, let offer = personalLossExit else { return }
        personalLossExit = nil
        // Lo aceptado es lo que contó el aviso, en sus dos mitades: las filas del outbox y los cambios del History que el drain
        // no capturó. Una mitad sin cifra honesta —su lectura falló— cubre cualquiera: es el «hay cambios que no llegaron» que
        // se le enseñó. Con la causa del aviso: retomar solo sigue mientras el bloqueo sea de ESA.
        acceptedPersonalLoss = CloudSignOutFlowLogic.PersonalLossAcceptance(offer: offer.loss, cause: offer.cause)
        CloudSyncBreadcrumb.signOutPersonalLossAccepted(pending: CloudSignOutFlowLogic.shownLossCount(shown))
        phase = .working
        await performCloudSecureSignOut(context: context)
    }

    /// El cierre en la nube enseñó el aviso que ofrece exportar y perder los cambios personales: rastro y canario, sin PII.
    /// El del attest conserva su canario (su serie viene del 2026-09-15); la sesión que no hay va al suyo, con la causa en el
    /// detalle, como en grupos.
    private static func notePersonalLossOffered(pending: Int, cause: CloudSignOutFlowLogic.LossCause) {
        let shown = CloudSignOutFlowLogic.shownLossCount(pending)
        let count = "pending=\(shown.map(String.init) ?? "unknown")"
        switch cause {
        case .attestUnavailable:
            CloudSyncBreadcrumb.signOutPersonalAttestUnavailable(pending: shown)
            MetricsService.canary(.cloudSignOutAttestUnavailable, detail: count)
        case .noSession, .otherAccount:
            CloudSyncBreadcrumb.signOutPersonalLossOffered(cause: cause.rawValue, pending: shown)
            MetricsService.canary(.cloudSignOutPersonalLossOffered, detail: "cause=\(cause.rawValue) \(count)")
        }
    }

    /// Desde ese aviso se generó el archivo con todos los movimientos (Ajustes, `ProfileView`): rastro y canario, sin PII.
    /// `cause` es la del aviso desde el que se exportó; `nil` —el aviso ya no está— cuenta en la serie del attest, que es la
    /// de siempre.
    static func notePersonalLossExport(rows: Int, cause: CloudSignOutFlowLogic.LossCause?) {
        CloudSyncBreadcrumb.signOutPersonalExported(rows: rows)
        switch cause {
        case .attestUnavailable, nil:
            MetricsService.canary(.cloudSignOutAttestExported, detail: "rows=\(rows)")
        case .noSession, .otherAccount:
            MetricsService.canary(.cloudSignOutPersonalLossExported, detail: "cause=\(cause?.rawValue ?? "") rows=\(rows)")
        }
    }

    /// El cierre va a armar el borrado con cambios personales que la persona aceptó perder. Solo cuenta si queda alguno: con
    /// cero, lo que los frenaba se arregló entre el tap y aquí (el attest volvió, la persona entró) y subieron.
    private static func notePersonalDiscarded(pending: Int, cause: CloudSignOutFlowLogic.LossCause) {
        guard pending > 0 else { return }
        let shown = CloudSignOutFlowLogic.shownLossCount(pending)
        let count = "pending=\(shown.map(String.init) ?? "unknown")"
        CloudSyncBreadcrumb.signOutPersonalDiscarded(pending: shown)
        switch cause {
        case .attestUnavailable:
            MetricsService.canary(.cloudSignOutAttestDiscarded, detail: count)
        case .noSession, .otherAccount:
            MetricsService.canary(.cloudSignOutPersonalLossDiscarded, detail: "cause=\(cause.rawValue) \(count)")
        }
    }

    /// **La privada (C) no sube grupos, pero antes de contar lo que se perdería los captura** (review adversarial del
    /// 2026-09-28, ticket `groups-outbox-rows-without-a-live-session-have-no-exit`). Lo que se apuntó en grupos desde el último
    /// ciclo vive solo en el History —sin sesión, el drain no corre en ningún otro sitio—, y el borrado se lo lleva igual que el
    /// outbox. Con la salida que pierde los cambios, contar solo el outbox dejaba aceptar «2 cambios» y perder cinco. Es la
    /// captura de las otras salidas (`captureLocalWritesForExit`), detrás de la misma quiescencia, porque el drain es un
    /// `save()` del contexto compartido. `false` = bloqueado, con la fase puesta y **sin** ofrecer la pérdida: la persona no
    /// puede aceptar perder lo que el aviso no contó.
    ///
    /// Solo en la celda C, que es la única que no pasa por el push-all (las otras capturan dentro de él). Corre al empezar el
    /// cierre y al entrar en `finalizeSessionExit`, tras la espera de iCloud. La comprobación pegada al arm no vuelve a
    /// capturar —ahí no puede haber `await`—: lo escrito en grupos durante la segunda espera, la de `armAfterCredentials` con
    /// la sesión ya suelta, sigue fuera (residual con ticket propio).
    private func captureGroupsBeforeCountingThem(context: ModelContext, kind: CloudSignOutFlowLogic.ExitKind) async -> Bool {
        guard !kind.pushesGroups else { return true }
        // Sin grupos del canal backend ni filas en el outbox, el drain no tiene nada que emitir: la sesión privada de siempre
        // no espera ni guarda nada que antes no guardara.
        guard Self.liveGroupsPendingCount(context: context) > 0 || Self.hasBackendGroupRows(context: context) else {
            return true
        }
        guard await Self.awaitPersonalQuiescenceForGroupsSignOut() else {
            phase = .blocked(pendingCount: Self.liveGroupsPendingCount(context: context), reason: .transient)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: Self.liveGroupsPendingCount(context: context))
            return false
        }
        // **Con la captura atascada el cierre sigue** (2026-10-05, ticket `groups-drain-that-always-aborts-takes-the-loss-exit-away`):
        // `blockIfGroupsCannotUpload` cuenta entonces también el History que el drain no capturó, y su aviso ofrece perderlo.
        // Hasta ese día esto bloqueaba con «inténtalo en un rato» en cada intento, y sin sesión esperar no lo cura nunca.
        guard await captureGroupsForExit(context: context, witness: exitWitness) != .unfinished else {
            let pending = Self.liveGroupsPendingCount(context: context)
            phase = .blocked(pendingCount: pending, reason: CloudSignOutFlowLogic.freshStartUncapturedReason)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: pending)
            return false
        }
        return true
    }

    /// **La captura previa a una salida, con sus reintentos** (2026-10-05, ticket
    /// `groups-drain-that-always-aborts-takes-the-loss-exit-away`). Hasta ese día cada sitio capturaba UNA vez y leía un
    /// `false` como «inténtalo en un rato»: con un drain que no termina nunca eso era cada intento, y el teléfono sin App
    /// Attest, la sesión caducada y los cambios de otra cuenta perdían la salida para siempre.
    ///
    /// **Reintentos espaciados con espera creciente durante varios segundos, con el mismo cambio fallando** (decisión de
    /// Jürgen del 2026-10-05): un intento al momento y uno tras cada espera de
    /// `CloudSignOutFlowLogic.groupsExitCaptureRetryDelays` (0,5 s · 1 s · 2 s · 4 s). Para en el primero que termina. Tras
    /// cada intento fallido lee la sonda del History (`GroupsExitWitness.uncapturedChanges`): vacía, el fallo no escondía
    /// nada y para. El veredicto es `CloudSignOutFlowLogic.groupsExitCapture`: atascada solo si ALGÚN cambio siguió fuera en
    /// TODOS los intentos y el History se dejó leer en cada uno —sin lectura no hay cifra exacta—. Un fallo pasajero, que se
    /// cura dentro de los reintentos, nunca la da por atascada.
    ///
    /// **Cada intento tras una espera vuelve a mirar la quiescencia del import** (review adversarial del 2026-10-05, lente 2):
    /// la captura es un `save()` del contexto compartido, y la espera que la protegía corrió ANTES del primer intento. Un
    /// import que arranque durante la espera dispararía el `_assertionFailure` de SwiftData, que no se atrapa. Sin quiescencia
    /// no se captura: los reintentos se cortan y es `.unfinished`, lo pasajero. Una cancelación durante la espera, igual.
    ///
    /// **Con el atasco ya probado en este gesto basta un intento** (`groupsCaptureStillStuck`): si falla y alguno de esos
    /// mismos cambios sigue fuera, sigue atascada; si no, vuelven los reintentos completos. Deja `groupsCaptureStuck` puesto
    /// para que la oferta sepa si tiene que contar el History.
    func captureGroupsForExit(context: ModelContext, witness: GroupsExitWitness) async
        -> CloudSignOutFlowLogic.GroupsExitCapture {
        let delays = exitCaptureRetryDelays
        let attempts = delays.count + 1
        var failedReadings: [Set<String>?] = []
        var completed = false
        var stillStuck = false
        // La espera se ve: «Guardando tus cambios pendientes…». Al salir, lo que hubiera antes.
        let wasWaiting = waitingForPending
        defer { waitingForPending = wasWaiting }
        for attempt in 0..<attempts {
            if attempt > 0 {
                waitingForPending = true
                do {
                    try await Task.sleep(for: delays[attempt - 1])
                } catch {
                    break  // cancelación del caller: no se dieron todos los intentos
                }
                guard Self.personalSaveIsSafeNow() else { break }
            }
            if witness.capture(context) {
                completed = true
                break
            }
            let reading = witness.uncapturedChanges(context).map { Set($0.map(\.key)) }
            failedReadings.append(reading)
            if reading == [] { break }  // el fallo no escondía ningún cambio
            if CloudSignOutFlowLogic.groupsCaptureStillStuck(provenStuck: provenStuckGroupsChanges, reading: reading) {
                stillStuck = true
                break
            }
        }
        let capture: CloudSignOutFlowLogic.GroupsExitCapture = stillStuck
            ? .stuck
            : CloudSignOutFlowLogic.groupsExitCapture(completed: completed, failedReadings: failedReadings,
                                                      attempts: attempts)
        if capture == .stuck {
            // Lo probado: los cambios que siguieron fuera en todos los intentos (o, con el atajo, los que siguen fuera ahora).
            let persistent = stillStuck
                ? provenStuckGroupsChanges.intersection(failedReadings.last.flatMap { $0 } ?? [])
                : CloudSignOutFlowLogic.groupsPersistentlyUncaptured(failedReadings) ?? []
            provenStuckGroupsChanges = persistent
            CloudSyncBreadcrumb.signOutGroupsCaptureStuck()
        } else {
            provenStuckGroupsChanges = []
        }
        groupsCaptureStuck = capture == .stuck
        return capture
    }

    /// Las esperas entre reintentos de `captureGroupsForExit`: las de producción, o la de los tests repetida tantas veces
    /// como esperas tiene producción —así un test recorre el MISMO número de intentos, solo que sin esperar—.
    private var exitCaptureRetryDelays: [Duration] {
        let production = CloudSignOutFlowLogic.groupsExitCaptureRetryDelays
        guard let exitCaptureDelayOverride else { return production }
        return production.map { _ in exitCaptureDelayOverride }
    }

    /// **Lo que un cierre se llevaría de grupos, en sus dos mitades** (`CloudSignOutFlowLogic.GroupsLoss`): las filas y,
    /// solo si la última captura se quedó atascada, los cambios del History que el drain no capturó. La cifra del aviso y lo
    /// que se acepta salen de aquí, para que digan lo mismo.
    private func groupsLoss(context: ModelContext) -> CloudSignOutFlowLogic.GroupsLoss {
        CloudSignOutFlowLogic.GroupsLoss(rows: groupsLossRowIDs(context: context),
                                         uncaptured: groupsLossUncaptured(context: context))
    }

    /// La mitad del History de `groupsLoss`: `[]` con la última captura completa —no se lee—, y con ella atascada las claves
    /// que lee la sonda (`nil` si no se pudo). **También con lo aceptado sobre una captura atascada** (review adversarial del
    /// 2026-10-05, lente 1): si el drain se cura entre medias, la comprobación pegada al arm de la celda C tiene que seguir
    /// leyendo el History que la persona aceptó perder, o un cambio nuevo que se quedara ahí se iría sin aviso.
    private func groupsLossUncaptured(context: ModelContext) -> Set<String>? {
        guard groupsCaptureStuck || acceptedGroupsLoss?.readsUncaptured == true else { return [] }
        return exitWitness.uncapturedChanges(context).map { Set($0.map(\.key)) }
    }

    /// **La relectura del History pegada al borrado, con la pérdida aceptada sobre una captura atascada**
    /// (`CloudSignOutFlowLogic.groupsResidualUncapturedAllowsSignOut`). Sin eso no se lee: `[]`.
    private func groupsResidualUncaptured(context: ModelContext) -> Set<String>? {
        CloudSignOutFlowLogic.groupsResidualUncapturedToCheck(acceptance: acceptedGroupsLoss) {
            exitWitness.uncapturedChanges(context).map { Set($0.map(\.key)) }
        }
    }

    /// La privada (C) no sube grupos. Si aun así le quedan cambios de grupos sin subir —el outbox de una sesión
    /// de grupos que caducó—, se bloquea pidiendo volver a entrar: el boot-wipe borra sync-meta, que es donde
    /// viven, y descartarlos rompe el «nunca descarta» (review adversarial del paso 9: se perdían en silencio
    /// mientras la hoja decía que los grupos no se tocaban). `true` = bloqueado, con la fase puesta.
    /// Síncrono a propósito: también corre pegado al arm.
    ///
    /// **Desde el 2026-09-28 el aviso ofrece perderlos** (ticket `groups-outbox-rows-without-a-live-session-have-no-exit`):
    /// quien no puede volver a entrar no tenía otra salida. `lossExit` es desde dónde retomar si los acepta perder, y lo
    /// aceptado —esas filas, sin sesión— deja seguir; una fila que no estaba en el aviso vuelve a avisar. La cifra sale de
    /// las MISMAS filas que se aceptarán.
    private func blockIfGroupsCannotUpload(context: ModelContext, kind: CloudSignOutFlowLogic.ExitKind,
                                           lossExit: GroupsLossResume) -> Bool {
        guard !kind.pushesGroups else { return false }
        // Desde el 2026-10-05, con la captura atascada, también lo que el drain no capturó (`groupsLoss`).
        let loss = groupsLoss(context: context)
        if loss.isEmpty { return false }
        if let accepted = acceptedGroupsLoss, accepted.cause == .noSession,
           CloudSignOutFlowLogic.continuesWithoutUploading(pendingRows: loss.rows, acceptance: accepted.rows),
           accepted.coversUncaptured(loss.uncaptured) {
            return false
        }
        acceptedGroupsLoss = nil
        let shown = loss.count
        // La oferta ANTES de la fase: quien reacciona a la fase pregunta `offersGroupsLossExit` y tiene que encontrarla ya.
        groupsLossExit = GroupsLossOffer(resume: lossExit, loss: loss, cause: .noSession)
        phase = .blocked(pendingCount: shown, reason: .sessionExpired)
        CloudSyncBreadcrumb.signOutPushBlocked(pending: shown)
        Self.noteGroupsLossOffered(pending: shown, cause: .noSession)
        return true
    }

    /// Una vuelta de la espera del export. `true` = confirmado (cero pendientes); `false` = bloqueado con el
    /// aviso de la salida de emergencia, fase ya puesta y `blockedExit` recordando dónde retomar.
    ///
    /// Sin ancla, el contador recorre el historial ENTERO para saber si hay algo local: se hace UNA vez por
    /// espera y se reutiliza hasta que aparece un ancla (un export que termina bien), hasta que la vuelta crea
    /// un borrador o hasta que la cola del App Group encoge sin ella —la vuelta a primer plano y el final de
    /// una ráfaga de cambios remotos también drenan durante la espera—. Otras escrituras ajenas no la tiran:
    /// las ve el recuento pegado al arm, que no usa caché (ticket
    /// `private-exit-export-wait-cached-zero-misses-outside-writes`).
    ///
    /// **Cada vuelta convierte antes en borrador lo que espera en el App Group** (Apple Pay, Siri): lo que
    /// llegue durante la espera también sube, y lo que no se pueda convertir cuenta como pendiente.
    private func confirmExportOrBlock(context: ModelContext, kind: CloudSignOutFlowLogic.ExitKind, credentialsReleased: Bool) async -> Bool {
        var withoutAnchor: Int?? = .none
        var lastQueued: Int?
        let verdict = await PrivateSignOutExportGateLogic.awaitConfirmedExport(
            pendingCount: {
                PrivateSignOutExportGateLogic.pendingCountMaterializingInbound(
                    materialize: {
                        let inbound = InboundCaptureDrain.forSignOut(context: context)
                        // La cola encogió: alguien la convirtió en borradores, aquí o fuera. El cero cacheado ya no vale.
                        if let lastQueued, inbound.stillQueued < lastQueued { withoutAnchor = .none }
                        lastQueued = inbound.stillQueued
                        return inbound
                    },
                    historyPending: { storeChanged in
                        if storeChanged { withoutAnchor = .none }
                        if iCloudSyncService.shared.confirmedExportStart == nil {
                            if case .some(let cached) = withoutAnchor { return cached }
                            let fresh = Self.personalHistoryPendingCount(context: context)
                            withoutAnchor = .some(fresh)
                            return fresh
                        }
                        return Self.personalHistoryPendingCount(context: context)
                    })
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
        // **La migración otra vez, antes de soltar nada** (review adversarial del 2026-09-27). Aquí entran también los que
        // RETOMAN un cierre sin pasar por `performSessionExit` —«Cerrar sesión igualmente», «Esperar», «Cerrar sesión y
        // perderlos»—, y lo de abajo desmonta el canal y suelta la sesión en la nube que una migración en vuelo usa.
        if blockIfMigrationNotAtRest(kind: kind) { return }
        if !kind.pushesGroups {
            // La celda C vuelve a capturar tras la espera de iCloud (2026-09-28): lo que se apuntó en grupos mientras esperaba
            // solo vive en el History, y el recuento pegado al arm, que no admite `await`, no lo vería.
            guard await captureGroupsBeforeCountingThem(context: context, kind: kind) else { return }
            if blockIfGroupsCannotUpload(context: context, kind: kind, lossExit: .finalize(kind: kind, export: export)) {
                return
            }
        }
        if kind.pushesGroups {
            // Otra vuelta de grupos: lo escrito en grupos durante la espera puede estar SOLO en el historial —
            // el recuento del outbox no lo ve— y solo el push-all lo drena (con su puerta de quiescencia).
            guard await pushGroupsForSignOut(context: context, lossExit: .finalize(kind: kind, export: export)) else {
                return
            }
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
            //
            // **Con la pérdida aceptada** (teléfono sin App Attest, 2026-09-15), las filas del aviso no bloquean: se pierden
            // con el borrado, que es lo que la persona eligió. Una fila que no estaba en el aviso sí, como siempre.
            //
            // **Y con la pérdida aceptada sobre una captura atascada, el History también** (2026-10-05): lo apuntado tras el
            // aviso no llega nunca al outbox, y sin esta relectura el borrado se lo llevaba sin contarlo.
            let residual = Self.liveGroupsPendingCount(context: context)
            guard residual == 0 || CloudSignOutFlowLogic.continuesWithoutUploading(
                pendingRows: Self.liveGroupsPendingRowIDs(context: context), acceptance: acceptedGroupsLoss?.rows),
                CloudSignOutFlowLogic.groupsResidualUncapturedAllowsSignOut(
                    now: groupsResidualUncaptured(context: context), acceptance: acceptedGroupsLoss) else {
                // Si lo único que bloquea es el History, no hay cifra de filas: `Int.max`, el «no se pudo contar» del repo
                // (el gemelo de la nube hace lo mismo; review adversarial del 2026-10-05, lente 3).
                let shown = residual == 0 ? Int.max : residual
                phase = .blocked(pendingCount: shown, reason: .permanent)
                CloudSyncBreadcrumb.signOutPushBlocked(pending: shown)
                return
            }
        }
        // **Se COMPRUEBA, y antes del arm** (ticket `sign-out-exits-do-not-verify-the-cloud-session-closed`). El borrado del
        // arranque deja el teléfono como recién instalado; con la sesión viva dentro, la persona siguiente arrancaría en la
        // cuenta de quien cerró y Grupos bajaría sus grupos. Parado aquí el borrado no se arma y los datos siguen: el teléfono
        // queda como con el bloqueo S2 de arriba —canal cortado— y reintentar es el gesto entero. Lo que `signOut()` suelta
        // antes de tocar la sesión (caché del entitlement, tipo de cuenta, Google) sí se va, igual que en el desasociar.
        guard await CloudAuthService.shared.signOut() else {
            blockBecauseSessionSurvived(path: Self.breadcrumbPath(kind))
            return
        }
        if kind.pushesGroups {
            // CR-2: sin esto, un kill entre `signOut()` y el arm dejaría el consent de una sesión que ya no
            // existe, y la cuenta siguiente se saltaría su pantalla. Desde C1 es local puro. **Detrás de la comprobación**
            // (2026-09-26): con la sesión superviviente el cierre se para, la persona sigue en la app con su cuenta de grupos,
            // y un consent borrado le volvería a pedir la pantalla y registraría otro en el servidor.
            GroupsConsentState.clear()
        }
        await armAfterCredentials(context: context, kind: kind, export: export)
    }

    /// Sustituye la lectura de la migración en los tests (`nil` = la de producción, `MigrationRestReading.live`). Mismo
    /// patrón que los `…Override` de los servicios de notificaciones: el predicado y el escritor siguen siendo los reales.
    var migrationRestReadingOverride: (() -> MigrationRestReading)?

    /// Sustituye los testigos del canal de Grupos en los cierres de sesión (`nil` = `GroupsExitWitness.live`). Hace falta
    /// porque el espejo REAL del App Group del simulador guarda lo que otras suites dejan, y sin sesión el recuento de la
    /// pérdida lo cuenta entero.
    var exitWitnessOverride: GroupsExitWitness?
    private var exitWitness: GroupsExitWitness { exitWitnessOverride ?? .live }

    /// **Lo que un cierre se llevaría de grupos si la persona acepta perderlo, por `clientMutationID`**: las filas vivas del
    /// outbox y las entradas del espejo del App Group que no llegaron a su fila, con el alcance del borrado —sin sesión,
    /// todas— (ticket `groups-outbox-rows-without-a-live-session-have-no-exit`). Es la instantánea que enseña el aviso y lo
    /// que se acepta: el teardown purga el espejo entero, y con solo las filas el aviso contaba menos de lo que se perdía
    /// (review adversarial del 2026-09-28). `nil` si alguna de las dos mitades no se pudo leer.
    private func groupsLossRowIDs(context: ModelContext) -> Set<UUID>? {
        guard let live = Self.liveGroupsPendingRowIDs(context: context),
              let mirror = exitWitness.mirrorPendingMutationIDs(context, .sessionOwnerOrEveryoneWhenSignedOut) else { return nil }
        return live.union(mirror)
    }

    /// **Con el paso de los datos entre iCloud y la nube fuera de reposo, el cierre de una sesión privada se para**
    /// (ticket `private-sign-out-proceeds-with-a-migration-in-flight`). Cerrar ahí borra lo local mientras sube. La
    /// decisión es `CloudSignOutFlowLogic.migrationBlockReason`, que es el predicado de la oferta del cambio de Apple ID
    /// (`AppleIDChangeCloseLogic.migrationAtRest`) más el texto que toca. Lo hace el ESCRITOR y no cada pantalla: Ajustes,
    /// la hoja del cambio de Apple ID y la puerta de Grupos del Welcome entran todas por aquí.
    ///
    /// **Tres sitios**: al empezar el cierre (antes de subir grupos o esperar a iCloud), al entrar en `finalizeSessionExit`
    /// (antes de soltar el canal y la sesión, y es donde entran los que retoman un cierre bloqueado) y pegado al arm, sin
    /// `await` entre medias, que es el que decide.
    ///
    /// Sin `blockedExit`: no hay nada que retomar a medias, y reintentar es el gesto entero, como el resto de bloqueos
    /// de antes del arm.
    func blockIfMigrationNotAtRest(kind: CloudSignOutFlowLogic.ExitKind) -> Bool {
        let reading = migrationRestReadingOverride?() ?? MigrationRestReading.live
        guard let reason = CloudSignOutFlowLogic.migrationBlockReason(kind: kind, reading: reading) else { return false }
        phase = .blocked(pendingCount: 0, reason: reason)
        CloudSyncBreadcrumb.signOutBlockedByMigration(reason: reason.breadcrumbSlug)
        return true
    }

    /// El cierre soltó la sesión y la sesión SIGUE guardada: se para sin armar el borrado. Ver
    /// `CloudSignOutFlowLogic.BlockReason.signOutSessionSurvived`.
    private func blockBecauseSessionSurvived(path: String) {
        phase = .blocked(pendingCount: 0, reason: .signOutSessionSurvived)
        // Fuera de `#if DEBUG`: nadie ha medido si esto pasa en la flota, y este es el sitio donde se ve.
        MetricsService.canary(.signOutSessionSurvived, detail: "path=\(path)")
    }

    /// El cierre tras BORRAR LA CUENTA no se para si la sesión sobrevive: la cuenta ya no existe en el servidor y
    /// bloquear dejaría a la persona sin salida tras un paso irreversible. Arma el retiro durable de la sesión
    /// (`CloudSessionRetirement`), que el arranque siguiente —obligatorio: la fase es `.awaitingRelaunch`— purga
    /// pre-mount, antes de que exista el SDK que podría reponerla.
    private static func retireIfSessionSurvived(_ gone: Bool, path: String) {
        guard !gone else { return }
        CloudSessionRetirement.arm(defaults: .standard)
        MetricsService.canary(.signOutSessionSurvived, detail: "path=\(path)")
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
        if blockIfGroupsCannotUpload(context: context, kind: kind, lossExit: .finalize(kind: kind, export: export)) { return }
        // **La migración se re-lee aquí, pegada al arm** (ticket `private-sign-out-proceeds-with-a-migration-in-flight`).
        // Desde el principio del cierre han pasado la subida de grupos, la espera de iCloud y la suelta de la sesión, y
        // mientras tanto una migración pudo arrancar o retomarse. Con las credenciales ya sueltas, pararse deja el teléfono
        // como el bloqueo S2 —canal cortado, datos intactos— y reintentar es el gesto entero.
        if blockIfMigrationNotAtRest(kind: kind) { return }
        // Lo que se pierde con la pérdida aceptada se cuenta pegado al arm, sin `await`.
        if let accepted = acceptedGroupsLoss {
            Self.noteGroupsDiscarded(pending: CloudSignOutFlowLogic.groupsDiscardedCount(
                rows: Self.liveGroupsPendingCount(context: context), acceptance: accepted), cause: accepted.cause)
        }
        // La MISMA fórmula que cuenta la hoja del cambio de Apple ID antes de confirmar.
        if CloudSignOutFlowLogic.wipeForgetsGroups(
            kind: kind, hasBackendGroupRows: Self.hasBackendGroupRows(context: context),
            groupsBackendCompiled: CloudSyncFlags.groupsBackendCompiledCapability) {
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

    /// Con la sesión caducada, el aviso del cierre manda a «Dónde viven tus datos» y su «Iniciar sesión»
    /// (`.cloudSessionExpired`), así que esa puerta tiene que estar ahí al llegar (ticket
    /// `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door`). La tarjeta sale con el motor en
    /// `.stoppedUntilSignIn`, y la cadencia puede tardar un minuto en chocar con el mismo 401 que el cierre acaba de ver: el
    /// motor se para ya y el controller se refresca. Va ANTES de la fase, que es lo que enciende el aviso.
    ///
    /// Solo con ese motivo. Los demás bloqueos no dicen nada de la sesión, y parar el motor por ellos cortaría la cadencia
    /// que los cura.
    private static func leaveSignInDoorOpen(ifShown shown: CloudSignOutFlowLogic.BlockReason,
                                            controller: CloudMigrationController) {
        guard shown == .cloudSessionExpired else { return }
        CloudSyncRuntime.shared?.stopUntilSignIn()
        controller.refresh()
    }

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

        // 1) Push-all PERSONAL — bloquear si no drena. **Jamás descartar, salvo lo que la persona aceptó perder** en el aviso
        // de sus datos (`exitDiscardingUnsyncedPersonalChanges`): el del teléfono sin App Attest (decisión de Jürgen del
        // 2026-09-15) y, desde el 2026-09-28, el de la sesión caducada (ticket
        // `cloud-sign-out-with-an-expired-session-and-personal-changes-has-no-exit`).
        //
        // **Qué hacer con el bloqueo lo decide una función pura** (`personalUploadBlockDecision`): seguir con lo aceptado si
        // el bloqueo es de su causa y lo que queda estaba en el aviso; si no, traducir el motivo —el attest a
        // `.personalAttestUnavailable`, el resto con `personalPushAllShownReason` (2026-09-25, ticket
        // `cloud-signout-collapses-the-personal-push-all-reason-into-permanent`)— y ofrecer la pérdida solo si el motivo
        // traducido la abre (`personalLossCause`) y, si es la sesión, con la prueba de que la del dueño se fue
        // (`ownersSessionIsGone`). Una fila nueva, o un bloqueo por otra cosa, retira lo aceptado.
        if case .blocked(let pending, let reason) = await controller.pushAllPendingForSignOut() {
            // Lo que se perdería, en sus dos mitades: las filas del outbox y lo que el drain no capturó (2026-10-05).
            let loss = controller.pendingPersonalLoss()
            // Sin runtime no hay a quién preguntar, y sin la prueba no se ofrece perder nada (`ownersSessionIsGone`).
            let ownersSessionIsGone = CloudSyncRuntime.shared?.ownersSessionIsGone ?? false
            switch CloudSignOutFlowLogic.personalUploadBlockDecision(
                reason: reason, pending: loss, acceptance: acceptedPersonalLoss, ownersSessionIsGone: ownersSessionIsGone) {
            case .continueWithAcceptedLoss:
                break
            case .block(let shown):
                acceptedPersonalLoss = nil
                Self.leaveSignInDoorOpen(ifShown: shown, controller: controller)
                phase = .blocked(pendingCount: pending, reason: shown)
                CloudSyncBreadcrumb.signOutPushBlocked(pending: pending)
                return
            case .offerLoss(let shown, let cause):
                acceptedPersonalLoss = nil
                // La oferta se anota ANTES de la fase, por lo mismo que la de grupos: quien reacciona a la fase pregunta
                // `offersPersonalLossExit` y tiene que encontrarla ya. **Y la cifra sale de lo MISMO que se aceptará**: con
                // un recuento aparte, un fetch que fallara solo en una de las dos lecturas enseñaría un número y aceptaría
                // cualquier fila. Desde el 2026-10-05 suma los cambios que el drain no capturó: con un drain atascado son lo
                // que el borrado se lleva. Con la sesión caducada, la puerta para volver a entrar se deja abierta igual: es
                // el camino por defecto del aviso.
                personalLossExit = PersonalLossOffer(loss: loss, cause: cause)
                let shownCount = loss.count
                Self.leaveSignInDoorOpen(ifShown: shown, controller: controller)
                phase = .blocked(pendingCount: shownCount, reason: shown)
                CloudSyncBreadcrumb.signOutPushBlocked(pending: shownCount)
                Self.notePersonalLossOffered(pending: shownCount, cause: cause)
                return
            }
        }

        // 2) Push-all GRUPOS (cierra LOW-3 de B2) — ANTES del teardown (la guardia de generación
        // abortaría el ciclo). Blocked ⇒ abort idéntico al personal, con el MOTIVO traducido.
        //
        // **Quién traduce es una función pura y exhaustiva** (`cloudSignOutGroupsBlockReason`), y sustituye
        // al ternario que colapsaba en `.permanent` todo lo que no fuera el canal en pausa. Con él, un corte
        // de red, un 5xx y el 403 de un cortafuegos salían los tres como «revisa tu conexión»: un fallo que
        // no existe, y sin nombrar lo único que ayuda. Desde el 2026-09-14 lo pasajero se anuncia como
        // pasajero (`.uploadRetryLater`) y el kill-switch sigue viajando tal cual.
        //
        // **La mitad PERSONAL la cierra el paso 1 desde el 2026-09-25** (`personalPushAllShownReason`): quien tenga filas
        // personales pendientes bloquea allí, con su propio motivo y no con el aviso genérico.
        //
        // **Con cambios de los dos lados y el teléfono sin App Attest salen dos avisos seguidos** (decisión de Jürgen,
        // 2026-09-15): el de tus datos en el paso 1 y, aceptado ése, el de tus grupos aquí. Aceptar este último retoma el
        // cierre desde el paso 1, con lo aceptado de lo personal todavía en pie.
        //
        // **Aquí NO hay reintento que gastar, y por eso el aviso sale al momento.** Este paso llama al
        // push-all DIRECTO: `pushGroupsForSignOut` —el del presupuesto de 45 s— es de los otros tres
        // caminos, así que `GroupsSignOutRetryDecision` no se consulta nunca en la nube. La decisión de
        // Jürgen (2026-09-14) es exactamente esa: aviso inmediato y honesto, sin quemar reintentos contra
        // un servidor que está fallando. El gesto sigue siendo reintentable: nada se ha escrito.
        switch await pushAllPendingGroupsForSignOut(context: context, witness: exitWitness) {
        case .blocked(_, let reason) where acceptedGroupsLoss.map {
            CloudSignOutFlowLogic.groupsLossAcceptanceContinues(
                $0, reason: reason, pendingRows: groupsLossRowIDs(context: context),
                uncaptured: groupsLossUncaptured(context: context))
        } ?? false:
            // **La pérdida aceptada** (`exitDiscardingUnsyncedGroups`): las filas del aviso ya no bloquean mientras el
            // bloqueo siga siendo de la misma causa —el attest, la sesión que no hay, la otra cuenta—. Si aparece otra fila,
            // o el bloqueo es otra cosa, cae en el `case` de abajo.
            break
        case .blocked(let pending, let reason):
            acceptedGroupsLoss = nil
            let shown = CloudSignOutFlowLogic.cloudSignOutGroupsBlockReason(reason)
            // Un motivo que abre la salida la anota ANTES de la fase, por lo mismo que en `pushGroupsForSignOut`. **Y la
            // cifra sale de las MISMAS filas que se aceptarán** (2026-09-28): con filas de otra cuenta, el recuento del
            // push-all y las filas vivas pueden no ser lo mismo.
            // Desde el 2026-10-05, con la captura atascada, también lo que el drain no capturó (`groupsLoss`).
            let offerLoss = groupsLoss(context: context)
            let lossCause = CloudSignOutFlowLogic.lossCause(shown)
            if let lossCause {
                groupsLossExit = GroupsLossOffer(resume: .cloud, loss: offerLoss, cause: lossCause)
            }
            let shownCount = lossCause == nil ? pending : offerLoss.count
            Self.leaveSignInDoorOpen(ifShown: shown, controller: controller)
            phase = .blocked(pendingCount: shownCount, reason: shown)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: shownCount)
            // El motivo YA traducido, que es el que decide el aviso: sin esta línea los tres desenlaces
            // dejan el mismo rastro y en campo no se puede saber cuál vio la persona.
            CloudSyncBreadcrumb.signOutGroupsBlocked(reason: shown.breadcrumbSlug)
            if let lossCause { Self.noteGroupsLossOffered(pending: shownCount, cause: lossCause) }
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
        // History (sin drain post-teardown) mueren con el wipe — **salvo con la pérdida personal aceptada**, que desde el
        // 2026-10-05 relee también lo que el drain no capturó (`residualUncapturedAllowsSignOut`): esa salida existe porque
        // el aviso contó el History, y con el drain atascado lo apuntado después no llega nunca al outbox.
        let residualPersonal = controller.livePendingUploadCount()
        let residualGroups = Self.liveGroupsPendingCount(context: context)
        let residualUncaptured = acceptedPersonalLoss == nil ? nil : controller.uncapturedPersonalChangeKeys()
        // Con la pérdida aceptada (el attest, la sesión que no hay), las filas de cada aviso ya no bloquean: las PERSONALES que contó
        // el de tus datos y las de GRUPOS que contó el suyo. **Cada aceptación cubre solo su outbox**, y una fila que no
        // estaba en su aviso bloquea como siempre.
        guard residualPersonal == 0 || CloudSignOutFlowLogic.continuesWithoutUploading(
                  pendingRows: controller.livePendingUploadRowIDs(), acceptance: acceptedPersonalLoss?.rows),
              CloudSignOutFlowLogic.residualUncapturedAllowsSignOut(now: residualUncaptured, acceptance: acceptedPersonalLoss),
              residualGroups == 0 || CloudSignOutFlowLogic.continuesWithoutUploading(
                  pendingRows: Self.liveGroupsPendingRowIDs(context: context), acceptance: acceptedGroupsLoss?.rows),
              // El gemelo de grupos (2026-10-05): con su pérdida aceptada sobre una captura atascada, el History también.
              CloudSignOutFlowLogic.groupsResidualUncapturedAllowsSignOut(
                  now: groupsResidualUncaptured(context: context), acceptance: acceptedGroupsLoss) else {
            // Suma que satura: los dos recuentos devuelven `Int.max` cuando su fetch falla, y un `+` atraparía. Si lo que
            // bloquea es solo el History, no hay cifra de filas que dar: `Int.max`, el «no se pudo contar» del repo.
            let (sum, overflow) = residualPersonal.addingReportingOverflow(residualGroups)
            let residual = overflow || sum == 0 ? Int.max : sum
            phase = .blocked(pendingCount: residual, reason: .permanent)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: residual)
            return
        }

        // 4b) La sesión se suelta y se COMPRUEBA antes del arm, por lo mismo que en `finalizeSessionExit`: sin esto el
        // teléfono quedaba recién instalado con la sesión de quien cerró dentro. Parado aquí, el estado es el del bloqueo
        // de arriba —motores cortados, borrado sin armar— y reintentar es el gesto entero.
        guard await CloudAuthService.shared.signOut() else {
            blockBecauseSessionSurvived(path: "cloud-secure")
            return
        }

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
        //
        // Lo que se pierde con la pérdida aceptada (teléfono sin App Attest) se cuenta aquí, pegado al arm: con cero, el
        // attest volvió entre el tap y aquí y los cambios subieron.
        if let accepted = acceptedGroupsLoss {
            Self.noteGroupsDiscarded(pending: CloudSignOutFlowLogic.groupsDiscardedCount(
                rows: residualGroups, acceptance: accepted), cause: accepted.cause)
        }
        if let accepted = acceptedPersonalLoss { Self.notePersonalDiscarded(pending: residualPersonal, cause: accepted.cause) }
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
    ///
    /// `lossExit` (2026-09-15): desde dónde retomaría el cierre si se bloquea porque este teléfono no consigue App Attest.
    /// **Sin valor por defecto**: los cierres pasan el suyo y el desasociar pasa `nil`, que es lo que hace que su bloqueo
    /// no ofrezca perder nada. Se anota ANTES de poner la fase, para que quien reaccione a la fase ya la vea.
    ///
    /// **Con la pérdida aceptada** (`acceptedGroupsLoss`, tras «Cerrar sesión y perderlos»): un solo intento, sin el
    /// presupuesto de 45 s. Si drena, el attest volvió y los cambios subieron; si no, el cierre sigue sin ellos mientras
    /// el bloqueo siga siendo el attest y las filas que quedan estén entre las aceptadas. La quiescencia se espera igual, porque el drain que hace honesto el recuento es un
    /// `save()`: sin ella no hay recuento que comparar, y se vuelve al camino de siempre.
    private func pushGroupsForSignOut(context: ModelContext, lossExit: GroupsLossResume?) async -> Bool {
        if let accepted = acceptedGroupsLoss {
            waitingForPending = true
            if await Self.awaitPersonalQuiescenceForGroupsSignOut() {
                switch await pushAllPendingGroupsForSignOut(context: context, witness: exitWitness) {
                case .drained:
                    return true
                case .blocked(_, let reason):
                    // Las dos mitades (2026-10-05): con la captura atascada, también lo que el drain no capturó.
                    if CloudSignOutFlowLogic.groupsLossAcceptanceContinues(
                        accepted, reason: reason, pendingRows: groupsLossRowIDs(context: context),
                        uncaptured: groupsLossUncaptured(context: context)) {
                        return true
                    }
                    // Hay filas que no estaban en el aviso, o el bloqueo ya no es de la causa aceptada: la aceptación ya no
                    // cubre lo que hay. Vuelve el camino de siempre, que enseñará el aviso con la cifra nueva si el motivo
                    // sigue abriendo la salida.
                }
            }
            acceptedGroupsLoss = nil
        }

        switch await pushGroupsWithinBudget(context: context, witness: exitWitness) {
        case .drained:
            return true
        case .surfacePermanent(let pending, let reason):
            // **El motivo viaja TAL CUAL, y esa es la corrección del 2026-09-13.** Aquí había un
            // ternario que colapsaba todo lo que no fuera `.sessionExpired` en `.permanent`: con él,
            // el canal en pausa llegaba a la pantalla convertido en «el problema es tu cuenta» y el
            // arreglo heredaba la forma del bug. `decide` solo devuelve `.surfacePermanent` para los
            // tres motivos que se muestran al momento, así que propagarlo es además byte-equivalente
            // a lo que hacía el ternario para los dos que ya existían.
            //
            // **El teléfono sin App Attest anota su salida ANTES de la fase** (2026-09-15): quien reacciona a la
            // fase pregunta `offersGroupsLossExit` y tiene que encontrarla ya. Con `lossExit == nil` (el
            // desasociar) no se anota nada y el bloqueo no ofrece perder los cambios.
            //
            // **Desde el 2026-09-28 abren la salida también la sesión caducada y la otra cuenta** (`lossCause`), y la cifra
            // sale de las MISMAS filas que se aceptarán, como en lo personal: con filas de otra cuenta, el recuento del
            // push-all no es el de las filas vivas.
            let lossCause = CloudSignOutFlowLogic.lossCause(reason)
            var shown = pending
            //
            // **Y desde el 2026-10-05, con la captura atascada, también lo que el drain no capturó** (`groupsLoss`, ticket
            // `groups-drain-that-always-aborts-takes-the-loss-exit-away`).
            if let lossCause, let lossExit {
                let loss = groupsLoss(context: context)
                groupsLossExit = GroupsLossOffer(resume: lossExit, loss: loss, cause: lossCause)
                shown = loss.count
            }
            phase = .blocked(pendingCount: shown, reason: reason)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: shown)
            if let lossCause, lossExit != nil { Self.noteGroupsLossOffered(pending: shown, cause: lossCause) }
            return false
        case .surfaceTransient(let pending):
            phase = .blocked(pendingCount: pending, reason: .transient)
            CloudSyncBreadcrumb.signOutPushBlocked(pending: pending)
            return false
        case .cancelled(let pending):
            // Cancelación del caller → fail-closed transitorio (reintentable).
            phase = .blocked(pendingCount: pending, reason: .transient)
            return false
        }
    }

    /// Cómo acabó la subida de grupos con el presupuesto de reintentos. **Separado de `pushGroupsForSignOut`
    /// para que lo comparta el borrado de «Empezar de cero»** (`drainGroupsBeforeFreshStart`), que necesita la
    /// MISMA subida sin tocar la fase del coordinador. Los cuatro desenlaces son los cuatro que la función
    /// original distinguía, y lo que cada uno le hace a la fase y al rastro lo sigue decidiendo quien llama.
    enum BudgetedGroupsPush: Equatable {
        case drained
        /// `GroupsSignOutRetryDecision` lo enseña al momento, con su motivo.
        case surfacePermanent(pending: Int, reason: CloudSignOutFlowLogic.BlockReason)
        /// Lo pasajero que agotó el presupuesto.
        case surfaceTransient(pending: Int)
        /// El `Task` del caller se canceló durante una espera.
        case cancelled(pending: Int)
    }

    /// El bucle del presupuesto (H-2026-07-18-6), sin efectos sobre la fase ni el rastro. Pone
    /// `waitingForPending`, como antes: quien llama decide cuándo bajarlo.
    private func pushGroupsWithinBudget(
        context: ModelContext, witness: GroupsExitWitness = .live
    ) async -> BudgetedGroupsPush {
        let budget = GroupsSignOutRetryDecision.budgetSeconds
        var retryClockStart: Date?

        while true {
            let hardCap: TimeInterval = retryClockStart
                .map { max(0, budget - Date().timeIntervalSince($0)) } ?? 60

            switch await attemptGroupsOnlyClose(context: context, quiescenceHardCap: hardCap, witness: witness) {
            case .drained:
                return .drained
            case .blocked(let pending, let reason):
                let elapsed = retryClockStart.map { Date().timeIntervalSince($0) } ?? 0
                switch GroupsSignOutRetryDecision.decide(
                    elapsedSeconds: elapsed, budgetSeconds: budget, reason: reason
                ) {
                case .surfacePermanent:
                    return .surfacePermanent(pending: pending, reason: reason)
                case .surfaceTransient:
                    return .surfaceTransient(pending: pending)
                case .retryAfter(let seconds):
                    if retryClockStart == nil { retryClockStart = Date() }
                    waitingForPending = true
                    do {
                        try await Task.sleep(for: .seconds(seconds))
                    } catch {
                        return .cancelled(pending: pending)
                    }
                    continue
                }
            }
        }
    }

    // MARK: - «Empezar de cero» espera a que suban los cambios de grupos

    /// Por qué «Empezar de cero» no borró: quedan cambios de grupos que no subieron. Lo lee la pantalla que enseña el
    /// fallo para decir cuántos y qué hacer.
    struct FreshStartGroupsBlock: Equatable {
        /// Cuántos cambios de grupos se quedan sin subir. `Int.max` = no se pudieron contar
        /// (`CloudSignOutFlowLogic.shownLossCount`). **Cuando el bloqueo ofrece perderlos, es lo que el borrado se llevaría**
        /// —filas vivas y entradas del espejo, `FreshStartGroupsLoss.count`—: la cifra que la persona acepta perder.
        let pendingCount: Int
        /// El motivo de la subida que no drenó, el mismo que enseñaría un cierre de sesión.
        let reason: CloudSignOutFlowLogic.BlockReason

        /// ¿Las pantallas ofrecen «Empezar de cero y perderlos»? Lo decide el motivo
        /// (`CloudSignOutFlowLogic.freshStartOffersGroupsLossExit`), y es a la vez lo que `drainGroupsBeforeFreshStart` usa
        /// para anotar la oferta: la vista no puede pintar un botón que el servicio no respalde.
        var offersLossExit: Bool { CloudSignOutFlowLogic.freshStartOffersGroupsLossExit(reason) }
    }

    /// Cómo acabó la subida previa al borrado.
    enum FreshStartGroupsDrain: Equatable {
        /// El outbox vivo quedó en 0, verificado por fetch: el borrado puede seguir.
        case drained
        /// No drenó. **No se borra nada**: el borrado para y la pantalla lo dice.
        case blocked(FreshStartGroupsBlock)
        /// El coordinador estaba con otro gesto (un cierre de sesión o un desasociar). Tampoco se borra nada.
        case busy
        /// **No drenó, y la persona aceptó perder exactamente esto** en el aviso de «Empezar de cero y perderlos». El
        /// borrado puede seguir, pasándole lo aceptado al cinturón del escritor (`requireNoUnsentGroupWrites`), que no deja
        /// pasar nada más.
        case lossAccepted(CloudSignOutFlowLogic.FreshStartGroupsLoss)
    }

    /// El fallo que devuelven los borrados de `ContentView` cuando esta subida no drenó. Las pantallas lo comparan para
    /// enseñar `FreshStartGroupsBlock` en vez del fallo genérico.
    static let freshStartGroupsPendingFailure = "groupsPendingUpload"

    /// El último bloqueo de «Empezar de cero», para que la pantalla que recibe `freshStartGroupsPendingFailure` sepa
    /// cuántos cambios y por qué. Se pone a `nil` al empezar cada intento: un bloqueo viejo no se cuela en otra pantalla.
    private(set) var freshStartGroupsBlock: FreshStartGroupsBlock?

    /// `true` mientras `drainGroupsBeforeFreshStart` sube. **La subida no toca `phase`** (ver su docblock), así que sin
    /// esto un cierre de sesión o un desasociar podían arrancar encima —la reanudación del arranque corre con la app
    /// usable— y el `defer` de la subida les apagaba el texto de «guardando…». Los dos lo miran junto a su
    /// `guard phase == .idle`.
    private(set) var freshStartDrainInFlight = false

    /// **Lo que el último bloqueo de «Empezar de cero» ofreció perder**, por fila (ticket
    /// `fresh-start-has-no-way-out-when-group-writes-can-never-upload`). Lo anota la subida en el mismo tramo síncrono en
    /// que pone `freshStartGroupsBlock`, solo con un motivo que ofrece la salida; la retira el intento siguiente.
    private var freshStartLossOffer: CloudSignOutFlowLogic.FreshStartGroupsLoss?

    /// **Lo que la persona aceptó perder en el «¿seguro?»**, a la espera del borrado que lo va a comprobar. Lo pone
    /// `acceptFreshStartGroupsLoss` y lo retira el primer paso del borrado siguiente (`takeFreshStartAcceptedLoss`), sea
    /// cual sea su desenlace: vale para un intento, no para un gesto posterior.
    private(set) var freshStartAcceptedLoss: CloudSignOutFlowLogic.FreshStartGroupsLoss?

    /// **Lo aceptado, para el borrado que empieza AHORA.** Lo toman `performICloudCorpusWipe` y `performDeviceCorpusWipe`
    /// como su PRIMER paso, antes de la espera del import (review adversarial del 2026-09-26, dos lentes): consumido en la
    /// subida, un borrado que salía antes —`importNotQuiescent`, `cancelled`— lo dejaba vivo, y un gesto posterior por otra
    /// pantalla lo gastaba sin haber enseñado el aviso de grupos. Lo devuelve y lo retira: vale para UN intento.
    func takeFreshStartAcceptedLoss() -> CloudSignOutFlowLogic.FreshStartGroupsLoss? {
        defer { freshStartAcceptedLoss = nil }
        return freshStartAcceptedLoss
    }

    /// **«Perderlos y empezar de cero»**: la persona confirmó, en la segunda pantalla, perder lo que le enseñó el aviso.
    ///
    /// **Aquí no se borra nada.** Convierte la oferta en lo aceptado, y la pantalla vuelve a lanzar su borrado. Ese borrado
    /// vuelve a subir primero —el motivo se mide en el gesto, no se hereda del aviso—: si drena, no se pierde nada; si
    /// vuelve a bloquear con un motivo que ofrece la salida y lo que queda está entre lo aceptado, sigue sin ello
    /// (`CloudSignOutFlowLogic.freshStartContinuesDiscarding`); si no, vuelve el aviso con su cifra nueva.
    ///
    /// `false` si no había oferta viva —otro intento la retiró—: la pantalla puede lanzar el borrado igual, que sin nada
    /// aceptado no descarta nada y vuelve a enseñar el aviso.
    @discardableResult
    func acceptFreshStartGroupsLoss() -> Bool {
        guard let offer = freshStartLossOffer else { return false }
        freshStartLossOffer = nil
        freshStartAcceptedLoss = offer
        CloudSyncBreadcrumb.freshStartGroupsLossAccepted(pending: CloudSignOutFlowLogic.shownLossCount(offer.count))
        return true
    }

    /// **¿Hay algo de grupos por subir?, sin red y sin esperar.** El pre-check de `pushAllPendingGroupsForSignOut`, igual
    /// y en el mismo orden: drenar el History al outbox (sin eso, un gasto de hace segundos solo vive ahí y el recuento lo
    /// daría por subido), barrer los tombstones venenosos y contar lo vivo. `true` = nada que subir.
    ///
    /// Lo usa el alert del shell para quedarse SÍNCRONO en el caso corriente: su botón borra en el mismo tap, y solo con
    /// algo pendiente pasa por `drainGroupsBeforeFreshStart`, que es asíncrona. Un productor asíncrono de presentaciones
    /// sobre ese anchor es el caso que `.claude/rules/swiftui-ds.md` manda al router; así queda acotado a quien de verdad
    /// tiene cambios sin subir.
    ///
    /// Hace el mismo `save()` que el borrado que viene detrás (`wipeAllUserData`), en el mismo tap: no añade un riesgo
    /// de import que ese camino no corriera ya.
    ///
    /// **Retira el bloqueo anterior**, como la subida: es el primer paso de un intento nuevo, y el aviso de fallo del alert
    /// lee `freshStartGroupsBlock` para elegir su texto — uno viejo diría «faltan cambios» ante un borrado que falló por
    /// otra cosa.
    ///
    /// **Y un drain que no terminó NO es «nada que subir»** (ticket `groups-drain-failure-reads-as-nothing-pending`): hasta
    /// ese día el recuento de después daba 0 con el gasto todavía en el History, y el borrado seguía. Tampoco lo es una
    /// entrada del espejo que no llegó a su fila: el borrado purga el espejo entero, así que aquí cuentan todas, también
    /// las de otra cuenta con la sesión abierta (`.wholeMirror`, ticket
    /// `fresh-start-drops-mirror-entries-of-another-identity-without-counting-them`). Con cualquiera de las dos el botón pasa
    /// por `drainGroupsBeforeFreshStart`, que lo dice.
    func groupsOutboxIsSettledEmpty(context: ModelContext, witness: GroupsExitWitness = .live) -> Bool {
        freshStartGroupsBlock = nil
        // Un intento nuevo tampoco hereda la oferta ni lo aceptado del anterior.
        freshStartLossOffer = nil
        freshStartAcceptedLoss = nil
        // Ni el atasco que probó otro intento.
        provenStuckGroupsChanges = []
        let captured = witness.capture(context)
        return CloudSignOutFlowLogic.groupsCaptureVerdict(
            captureCompleted: captured,
            livePendingCount: Self.liveGroupsPendingCount(context: context),
            unrehydratedMirrorCount: witness.mirrorPending(context, .wholeMirror)
        ) == .drained
    }

    /// Lo que un ciclo del canal de Grupos deja leer al push-all del cierre: el outcome y los tres testigos que
    /// `CloudSignOutFlowLogic.classify` necesita, leídos juntos (`GroupsExitWitness.cycle`).
    nonisolated struct GroupsCycleReading: Equatable {
        let outcome: SyncCadencePolicy.CadenceOutcome
        /// ¿Paró por el kill-switch? (`GroupsSyncClient.stoppedByChannelKill(for:)`).
        let channelKilled: Bool
        /// ¿Paró porque el teléfono lleva más de un día sin App Attest? (`stoppedByUnavailableAttest(for:)`).
        let attestUnavailable: Bool
        /// ¿Chocó con el servidor empujando? (`stoppedByFailedUpload(for:)`).
        let uploadFailed: Bool
    }

    /// **Los dos testigos del canal de Grupos que deciden si una salida puede dar el outbox por vacío** (ticket
    /// `groups-drain-failure-reads-as-nothing-pending`): la captura previa (`GroupsSyncClient.captureLocalWritesForExit`, que
    /// dice si el drain terminó) y lo que el espejo del App Group guarda fuera del outbox. Con la capacidad sin compilar no
    /// hay canal, y los dos dicen «nada»: un build sin canal no toca nada.
    ///
    /// **Es un parámetro y no una propiedad mutable**, y la razón está medida: el espejo REAL del simulador guarda lo que
    /// otras suites dejan (48 entradas de `auth-uid-1` el 2026-09-26), y el alcance del borrado lo cuenta entero cuando no
    /// hay sesión. Un seam compartido haría depender cada suite del orden de las demás.
    ///
    /// `nonisolated` porque es el valor por defecto de parámetros, y esos se evalúan en el contexto del llamador; lo que
    /// toca el canal va dentro de sus closures, que sí son `@MainActor`.
    nonisolated struct GroupsExitWitness {
        let capture: @MainActor (ModelContext) -> Bool
        let mirrorPending: @MainActor (ModelContext, GroupsSyncClient.MirrorPendingScope) -> Int
        /// Las mismas entradas que `mirrorPending`, por su clave: lo que «Empezar de cero y perderlos» enseña y acepta
        /// perder (`GroupsSyncClient.mirrorEntryKeysMissingFromOutbox`). `nil` = no se pudo leer.
        let mirrorPendingKeys: @MainActor (ModelContext, GroupsSyncClient.MirrorPendingScope) -> Set<String>?
        /// Filas vivas que la sesión de ahora no puede subir porque no son suyas
        /// (`GroupsSyncClient.liveRowsHeldForAnotherAccount`, ticket `groups-outbox-rows-without-a-live-session-have-no-exit`).
        /// Con valor por defecto —ninguna— para los testigos de los tests que no las siembran.
        var heldForAnotherAccount: @MainActor (ModelContext) -> Int = { _ in 0 }
        /// Las entradas del espejo sin fila de OTRA cuenta que la de la sesión (`.anotherAccount`; sin sesión, ninguna). Lo
        /// que «Empezar de cero» lee para decir por qué no suben (`freshStartResidualReason`) y para sumarlas a un bloqueo que
        /// no ofrece perderlas (ticket `fresh-start-drops-mirror-entries-of-another-identity-without-counting-them`). `Int.max`
        /// = no se pudo leer. Con valor por defecto —ninguna— para los testigos de los tests que no las siembran.
        var mirrorPendingOfAnotherAccount: @MainActor (ModelContext) -> Int = { _ in 0 }
        /// Las entradas del espejo sin fila, por su `clientMutationID`
        /// (`GroupsSyncClient.mirrorEntryMutationIDsMissingFromOutbox`): lo que la oferta de perder los cambios suma a las
        /// filas vivas. `nil` = no se pudo leer. Con valor por defecto —ninguna— para los testigos de los tests.
        var mirrorPendingMutationIDs: @MainActor (ModelContext, GroupsSyncClient.MirrorPendingScope) -> Set<UUID>? = { _, _ in [] }
        /// Los cambios del History de Grupos que ningún drain capturó (`GroupsSyncClient.uncapturedGroupsChanges`, ticket
        /// `groups-drain-that-always-aborts-takes-the-loss-exit-away`): lo que el aviso suma a las filas con la captura
        /// atascada. `nil` = no se pudo leer. Con valor por defecto —ninguno— para los testigos de los tests.
        var uncapturedChanges: @MainActor (ModelContext) -> [GroupsSyncClient.UncapturedChange]? = { _ in [] }
        /// **Un ciclo del canal, con sus tres testigos leídos junto al outcome** (2026-10-05). Es lo único del push-all que
        /// habla con la red; con la captura atascada el push-all cicla aunque el outbox esté a 0 —para saber si falta App
        /// Attest o sesión—, y los tests que lo recorren lo sustituyen. Por defecto, el cliente real.
        var cycle: @MainActor (ModelContext) async -> GroupsCycleReading = { context in
            await GroupsExitWitness.liveCycle(context: context)
        }

        /// El ciclo real: `syncCycleOnceCoalesced` y, con el outcome en la mano y sin `await` entre medias, los testigos del
        /// kill, del attest y de la subida (`GroupsSyncClient.stoppedBy…(for:)`).
        @MainActor
        static func liveCycle(context: ModelContext) async -> GroupsCycleReading {
            let outcome = await GroupsSyncClient.shared.syncCycleOnceCoalesced(context: context)
            return GroupsCycleReading(
                outcome: outcome,
                channelKilled: GroupsSyncClient.shared.stoppedByChannelKill(for: outcome),
                attestUnavailable: GroupsSyncClient.shared.stoppedByUnavailableAttest(for: outcome),
                uploadFailed: GroupsSyncClient.shared.stoppedByFailedUpload(for: outcome))
        }

        static var live: GroupsExitWitness {
            GroupsExitWitness(
                capture: { context in
                    guard CloudSyncFlags.groupsBackendCompiledCapability else { return true }
                    return GroupsSyncClient.shared.captureLocalWritesForExit(context: context)
                },
                mirrorPending: { context, scope in
                    guard CloudSyncFlags.groupsBackendCompiledCapability else { return 0 }
                    return GroupsSyncClient.shared.mirrorEntriesMissingFromOutbox(context: context, scope: scope)
                },
                mirrorPendingKeys: { context, scope in
                    guard CloudSyncFlags.groupsBackendCompiledCapability else { return [] }
                    return GroupsSyncClient.shared.mirrorEntryKeysMissingFromOutbox(context: context, scope: scope)
                },
                heldForAnotherAccount: { context in
                    guard CloudSyncFlags.groupsBackendCompiledCapability else { return 0 }
                    return GroupsSyncClient.shared.liveRowsHeldForAnotherAccount(context: context)
                },
                mirrorPendingOfAnotherAccount: { context in
                    guard CloudSyncFlags.groupsBackendCompiledCapability else { return 0 }
                    return GroupsSyncClient.shared.mirrorEntriesMissingFromOutbox(context: context, scope: .anotherAccount)
                },
                mirrorPendingMutationIDs: { context, scope in
                    guard CloudSyncFlags.groupsBackendCompiledCapability else { return [] }
                    return GroupsSyncClient.shared.mirrorEntryMutationIDsMissingFromOutbox(context: context, scope: scope)
                },
                uncapturedChanges: { context in
                    guard CloudSyncFlags.groupsBackendCompiledCapability else { return [] }
                    return GroupsSyncClient.shared.uncapturedGroupsChanges(context: context)
                })
        }
    }

    /// Lo que «Empezar de cero» se llevaría de grupos: las filas vivas y las entradas del espejo sin fila, **de cualquier
    /// cuenta** (`.wholeMirror`): el borrado purga el espejo entero. La cifra que enseña su bloqueo, y la que exige a cero
    /// el cinturón del escritor (`DataWipeService.requireNoUnsentGroupWrites`). `Int.max` si alguna de las dos no se pudo
    /// contar.
    static func freshStartGroupsPendingCount(context: ModelContext, witness: GroupsExitWitness = .live) -> Int {
        let live = liveGroupsPendingCount(context: context)
        let mirror = witness.mirrorPending(context, .wholeMirror)
        guard live < Int.max, mirror < Int.max else { return Int.max }
        return live + mirror
    }

    /// Lo mismo que `freshStartGroupsPendingCount`, **por fila**: lo que «Empezar de cero y perderlos» enseña y lo que la
    /// persona acepta perder (ticket `fresh-start-has-no-way-out-when-group-writes-can-never-upload`). Mismo alcance del
    /// espejo que el recuento y que el cinturón, `.wholeMirror`: el borrado lo purga entero, también lo de otra cuenta.
    ///
    /// `readsUncaptured` (2026-10-05): con la captura atascada, o con lo aceptado sobre una, la tercera mitad —los cambios del
    /// History que el drain no capturó— se lee; si no, es `[]` y el History no se toca (`FreshStartGroupsLoss`). Sin valor por
    /// defecto a propósito: quien cuenta tiene que decir si sabe que la captura se atascó.
    static func freshStartGroupsLoss(
        context: ModelContext, witness: GroupsExitWitness = .live, readsUncaptured: Bool
    ) -> CloudSignOutFlowLogic.FreshStartGroupsLoss {
        CloudSignOutFlowLogic.FreshStartGroupsLoss(
            rows: liveGroupsPendingRowIDs(context: context),
            mirrorKeys: witness.mirrorPendingKeys(context, .wholeMirror),
            uncaptured: readsUncaptured ? witness.uncapturedChanges(context).map { Set($0.map(\.key)) } : [])
    }

    /// **Sube los cambios de grupos ANTES de que «Empezar de cero» borre nada** (ticket
    /// `fresh-start-wipe-kills-unsent-group-writes-silently`). `DataWipeService.wipeLocalGroupsDomain` borra el outbox de
    /// grupos, y en la puerta privada quien empieza de cero puede ser la MISMA persona: esos gastos eran suyos y se perdían
    /// sin que nada lo dijera. Ahora el borrado hace lo que ya hacen el cierre y el desasociar en la misma situación:
    /// sube primero, con el mismo push-all y el mismo presupuesto, y si no drena **no borra**.
    ///
    /// Subir es correcto también cuando quien empieza de cero es OTRA persona: las filas van firmadas con la sesión que
    /// las escribió, así que llegan a los grupos de su dueño, que es a donde iban. Lo incorrecto era tirarlas.
    ///
    /// **La salida «perderlos», solo con los motivos que esperar no arregla** (ticket
    /// `fresh-start-has-no-way-out-when-group-writes-can-never-upload`, decisión de Jürgen del 2026-09-26). Hasta ese día no
    /// había ninguna —por la decisión del 2026-09-15 para el desasociar— y quien tenía cambios que no podían subir nunca
    /// (un iPhone heredado, una sesión que el SDK borró) solo salía desinstalando. Ver `settleFreshStartBlock`.
    ///
    /// **No toca `phase`**, y es a propósito: `.working` y `.blocked` los leen seis sitios que no tienen nada que ver con
    /// este gesto —la matriz de readiness, la fila de cierre del Perfil, la puerta de Grupos del Welcome—, y cualquiera
    /// encendería su propia pantalla. El veredicto viaja por el retorno, como el del desasociar. Sí exige la fase en
    /// `.idle`: con un cierre en vuelo, dos subidas del mismo outbox a la vez no se sabe qué dejan.
    ///
    /// **Corre ANTES del primer borrado**, sea la zona de iCloud, las filas personales o el dominio de Grupos: parado
    /// aquí, el teléfono queda exactamente como estaba.
    ///
    /// `accepted`: lo que la persona aceptó perder, tal como lo tomó el borrado al empezar (`takeFreshStartAcceptedLoss`).
    /// `nil` —el default— es la subida de siempre, que no descarta nada.
    func drainGroupsBeforeFreshStart(
        context: ModelContext, witness: GroupsExitWitness = .live,
        accepted: CloudSignOutFlowLogic.FreshStartGroupsLoss? = nil
    ) async -> FreshStartGroupsDrain {
        // Antes del `guard`: un `.busy` tampoco puede dejar a la vista el bloqueo de un intento anterior.
        freshStartGroupsBlock = nil
        freshStartLossOffer = nil
        guard phase == .idle, !freshStartDrainInFlight else { return .busy }

        // **Sin nada que subir, ni espera ni red** — el caso de casi todo el mundo. La subida de abajo abre con la
        // quiescencia estricta del cierre (primer import completado Y quieto, hasta 60 s), y con el espejo adjunto y un
        // import sin asentar eso bloqueaba «Empezar de cero» como `.transient` con CERO cambios pendientes: la regresión
        // contraria, medida con un mutante. El pre-check hace el mismo `save()` que el borrado que viene detrás, que ya
        // corre bajo la espera de import de su caller (`waitForImportQuiescence`); la estricta queda para cuando hay algo
        // que subir de verdad.
        if groupsOutboxIsSettledEmpty(context: context, witness: witness) { return .drained }

        freshStartDrainInFlight = true
        defer {
            freshStartDrainInFlight = false
            waitingForPending = false
        }
        let block: FreshStartGroupsBlock
        if let pushed = Self.freshStartBlock(
            for: await pushGroupsWithinBudget(context: context, witness: witness)) {
            // La cifra de la subida es lo que ESTA sesión puede subir; el borrado se lleva también lo de otra cuenta
            // (ticket `fresh-start-drops-mirror-entries-of-another-identity-without-counting-them`). Aquí y no en
            // `settleFreshStartBlock`: el residuo de abajo ya cuenta el espejo entero, y sumarlo allí lo contaba dos veces.
            block = Self.freshStartBlockCountingAnotherAccount(pushed, context: context, witness: witness)
        } else {
            // **La subida solo mira el espejo de la sesión, y el borrado que viene detrás purga el de TODOS** (ticket
            // `groups-drain-failure-reads-as-nothing-pending`). Sin este paso, una entrada sin fila que no es de la sesión
            // —o cualquiera, sin sesión— pasaba aquí como `.drained` y el cinturón del escritor saltaba DESPUÉS: en la
            // puerta privada, con la zona de iCloud ya borrada. Se mide con el mismo recuento que el cinturón, que desde el
            // 2026-10-05 cuenta también las de otra cuenta con la sesión abierta.
            let residual = Self.freshStartGroupsPendingCount(context: context, witness: witness)
            guard residual != 0 else { return .drained }
            // El motivo dice lo que lo cura: volver a entrar, o intentarlo en un rato (`freshStartResidualReason`).
            block = FreshStartGroupsBlock(
                pendingCount: residual,
                reason: CloudSignOutFlowLogic.freshStartResidualReason(
                    livePendingCount: Self.liveGroupsPendingCount(context: context),
                    sessionMirrorCount: witness.mirrorPending(context, .sessionOwner),
                    anotherAccountMirrorCount: witness.mirrorPendingOfAnotherAccount(context)))
        }
        return await settleFreshStartBlock(block, accepted: accepted, context: context, witness: witness)
    }

    /// **Qué hace «Empezar de cero» con un bloqueo** (ticket `fresh-start-has-no-way-out-when-group-writes-can-never-upload`).
    ///
    ///  · **Un motivo que no ofrece la salida** (`.channelPaused`, lo pasajero): el bloqueo de siempre, con su cifra y su
    ///    texto (la de la subida ya lleva sumadas las entradas de otra cuenta, `freshStartBlockCountingAnotherAccount`). Lo
    ///    aceptado, si lo había, no cuenta: la persona aceptó perderlos porque no podían subir, y ahora sí pueden.
    ///  · **Un motivo que la ofrece, con lo que queda dentro de lo aceptado**: sigue sin ello (`.lossAccepted`). El motivo es
    ///    el de ESTE intento, así que el aviso no se hereda.
    ///  · **Un motivo que la ofrece, sin aceptar o con algo nuevo**: el bloqueo, con la cifra de lo que el borrado se
    ///    llevaría —filas vivas y entradas del espejo— y la oferta anotada por fila para el «¿seguro?».
    ///
    /// Interna y no privada para poder probar cada rama con filas de verdad y sin red: la subida que la precede habla con
    /// el gateway.
    func settleFreshStartBlock(
        _ block: FreshStartGroupsBlock, accepted: CloudSignOutFlowLogic.FreshStartGroupsLoss?,
        context: ModelContext, witness: GroupsExitWitness
    ) async -> FreshStartGroupsDrain {
        guard block.offersLossExit else {
            noteFreshStartBlocked(block)
            return .blocked(block)
        }
        // **Antes de contar lo que se perdería, todo dentro del outbox** (review adversarial del 2026-09-26, dos lentes).
        // El ciclo solo re-captura tras un bloqueo por App Attest; con `.sessionExpired` o `.permanent`, un gasto que un
        // drain a medias dejó en el History no está ni en las filas ni en el espejo, así que el aviso no lo contaba y el
        // borrado se lo llevaba. Lo recapturado entra en la cifra; lo que no se pudo capturar bloquea sin salida de
        // pérdida —la persona no puede aceptar lo que no se le enseñó—, como `attestBlockAfterRecapture`.
        //
        // **Con la captura atascada, la salida se ofrece igual desde el 2026-10-05** (ticket
        // `groups-drain-that-always-aborts-takes-the-loss-exit-away`): esperar no la cura, así que lo que el drain no capturó
        // entra en la cifra como tercera mitad (`FreshStartGroupsLoss.uncaptured`). Solo lo que no probó el atasco bloquea.
        let capture = await captureGroupsForExit(context: context, witness: witness)
        guard capture != .unfinished else {
            let uncaptured = FreshStartGroupsBlock(
                pendingCount: Self.freshStartGroupsPendingCount(context: context, witness: witness),
                reason: CloudSignOutFlowLogic.freshStartUncapturedReason)
            noteFreshStartBlocked(uncaptured)
            return .blocked(uncaptured)
        }
        let loss = Self.freshStartGroupsLoss(context: context, witness: witness, readsUncaptured: capture == .stuck)
        if CloudSignOutFlowLogic.freshStartContinuesDiscarding(reason: block.reason, now: loss, accepted: accepted) {
            Self.noteFreshStartGroupsDiscarded(loss, reason: block.reason)
            return .lossAccepted(loss)
        }
        let offered = FreshStartGroupsBlock(pendingCount: loss.count, reason: block.reason)
        freshStartLossOffer = loss
        noteFreshStartBlocked(offered)
        return .blocked(offered)
    }

    /// **El bloqueo sin salida de pérdida, con las entradas del espejo de otra cuenta sumadas** (ticket
    /// `fresh-start-drops-mirror-entries-of-another-identity-without-counting-them`, decisión A de Jürgen). La cifra de la
    /// subida es lo que ESTA sesión puede subir; el texto dice «empezar de cero se los llevaría», y el borrado purga también
    /// lo de otra cuenta. Sin entradas ajenas, el bloqueo tal cual. Si alguna mitad no se pudo contar, `Int.max`.
    static func freshStartBlockCountingAnotherAccount(
        _ block: FreshStartGroupsBlock, context: ModelContext, witness: GroupsExitWitness
    ) -> FreshStartGroupsBlock {
        let anotherAccount = witness.mirrorPendingOfAnotherAccount(context)
        // `Int.max` («no se pudo contar») más una cifra positiva desborda, y más cero se queda en `Int.max`: el
        // desbordamiento cubre las dos mitades sin comprobarlas aparte.
        let (sum, overflow) = block.pendingCount.addingReportingOverflow(anotherAccount)
        return FreshStartGroupsBlock(pendingCount: overflow ? Int.max : sum, reason: block.reason)
    }

    /// «Empezar de cero» va a borrar con cambios de grupos que la persona aceptó perder. Solo cuenta si queda alguno: con
    /// cero, subieron entre el aviso y aquí. Fuera de `#if DEBUG`, como su gemelo del cierre (`noteGroupsDiscarded`).
    private static func noteFreshStartGroupsDiscarded(
        _ loss: CloudSignOutFlowLogic.FreshStartGroupsLoss, reason: CloudSignOutFlowLogic.BlockReason
    ) {
        guard !loss.isEmpty else { return }
        let shown = CloudSignOutFlowLogic.shownLossCount(loss.count)
        MetricsService.canary(.freshStartDiscardedGroupWrites,
                              detail: "reason=\(reason) pending=\(shown.map(String.init) ?? "unknown")")
    }

    /// **El veredicto de la subida, en puro**: `nil` = drenó; si no, qué enseñar. El motivo viaja TAL CUAL —el bug del
    /// 2026-09-13 era un ternario que lo aplanaba—, y lo pasajero que agotó el presupuesto o se canceló es `.transient`,
    /// igual que en el cierre. Separado para poder probar cada desenlace sin red.
    static func freshStartBlock(for push: BudgetedGroupsPush) -> FreshStartGroupsBlock? {
        switch push {
        case .drained:
            return nil
        case .surfacePermanent(let pending, let reason):
            return FreshStartGroupsBlock(pendingCount: pending, reason: reason)
        case .surfaceTransient(let pending), .cancelled(let pending):
            return FreshStartGroupsBlock(pendingCount: pending, reason: .transient)
        }
    }

    /// **Hay cambios de grupos sin subir y este borrado no va a esperarlos**: el alert del shell, que no tiene pantalla
    /// donde enseñar una subida, y el cinturón del escritor cuando salta antes del primer borrado. Deja el bloqueo con la
    /// cifra VIVA y el motivo que se pasa, para que el aviso diga lo que pasó. `.uploadRetryLater` es el que vale sin
    /// haber intentado nada: «no llegaron al servidor, siguen aquí, inténtalo en un rato» es cierto con red y sin ella.
    func noteFreshStartGroupsPending(
        context: ModelContext, reason: CloudSignOutFlowLogic.BlockReason, witness: GroupsExitWitness = .live
    ) {
        noteFreshStartBlocked(FreshStartGroupsBlock(
            pendingCount: Self.freshStartGroupsPendingCount(context: context, witness: witness), reason: reason))
    }

    private func noteFreshStartBlocked(_ block: FreshStartGroupsBlock) {
        freshStartGroupsBlock = block
        // Fuera de `#if DEBUG`: es la medición de cuántas veces «Empezar de cero» se habría llevado cambios de grupos.
        let shown = CloudSignOutFlowLogic.shownLossCount(block.pendingCount)
        MetricsService.canary(.freshStartBlockedByGroupWrites,
                              detail: "reason=\(block.reason) pending=\(shown.map(String.init) ?? "unknown")")
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
        quiescenceHardCap: TimeInterval,
        witness: GroupsExitWitness = .live
    ) async -> CloudSignOutFlowLogic.PushAllVerdict {
        // El caption de espera cubre TAMBIÉN la quiescencia del PRIMER intento (en un restore puede
        // bloquear hasta 60s — exactamente la ventana del hallazgo H-6; sin esto el spinner corre mudo).
        waitingForPending = true
        guard await Self.awaitPersonalQuiescenceForGroupsSignOut(hardCap: quiescenceHardCap) else {
            return .blocked(
                pendingCount: Self.liveGroupsPendingCount(context: context), reason: .transient)
        }
        // Push-all de grupos con la generación INTACTA (antes del teardown).
        return await pushAllPendingGroupsForSignOut(context: context, witness: witness)
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

        // No se para si la sesión sobrevive (ver `retireIfSessionSurvived`); el retiro va ANTES del arm del borrado.
        Self.retireIfSessionSurvived(await CloudAuthService.shared.signOut(), path: "account-delete-cloud")

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

        // No se para si la sesión sobrevive (ver `retireIfSessionSurvived`). Aquí es lo ÚNICO que la retira: el borrado
        // solo-grupos del arranque no toca el llavero, porque el store personal y su sesión privada siguen.
        Self.retireIfSessionSurvived(await CloudAuthService.shared.signOut(), path: "account-delete-groups-only")

        StorageModePersistence.armGroupsOnlyWipe()
        CloudSyncBreadcrumb.signOutGroupsOnlyWipeArmed()
        phase = .awaitingRelaunch
        return true
    }

    // MARK: - Helpers del canal de Grupos (G5-B)

    /// Push-all VERIFICADO del outbox de GRUPOS (molde `CloudMigrationController.pushAllPendingForSignOut`):
    /// cicla `GroupsSyncClient.syncCycleOnceCoalesced` hasta que el outbox VIVO (no dead-letter) quede en 0
    /// verificado por fetch, o bloquea. Dead-letters (`rejectedReason != nil`) NO bloquean (son permanentes
    /// — igual que el personal excluye rejected). Pre-check: con outbox vacío (flag OFF / sin grupos), la captura
    /// completa y el espejo sin nada fuera del outbox, devuelve `.drained` SIN ciclar (no-op real — cero red); con la
    /// captura a medias bloquea sin ciclar (`CloudSignOutFlowLogic.groupsCaptureVerdict`), salvo atascada, que cicla para saber la
    /// causa (2026-10-05, `captureGroupsForExit`). DEBE correr ANTES de `teardownForSignOut`
    /// (la guardia de generación abortaría el ciclo).
    private func pushAllPendingGroupsForSignOut(
        context: ModelContext,
        maxIterations: Int = 20,
        witness: GroupsExitWitness = .live
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
        //
        // **Y el drain dice si terminó, porque el recuento de después no lo sabe** (ticket
        // `groups-drain-failure-reads-as-nothing-pending`). Hasta ese día un `fetchHistory` o un `save` que lanzaba, o el
        // corte del reloj, dejaban el gasto solo en el History, el recuento daba 0 y el cierre salía `.drained` — y el
        // teardown y el borrado se lo llevaban sin que ningún drain posterior lo encontrara. La captura
        // (`witness.capture`, en producción `GroupsSyncClient.captureLocalWritesForExit`) rehidrata además el espejo del
        // App Group antes de drenar: con el flag compuesto apagado la rehidratación del arranque no corre, y una fila que
        // solo vivía ahí llegaba aquí con el outbox a 0. Alcance del espejo: la sesión, que es lo único que este gesto
        // puede subir (`.sessionOwner`).
        //
        // La captura barre también los tombstones de `split_groups` encolados, y ése es el SEGUNDO call-site del barrido,
        // que NO es redundante con el de `GroupsSyncClient.startIfEligible`: aquel vive detrás del flag COMPUESTO y éste
        // detrás del COMPILADO (`GroupsExitWitness.live`), que es justo la asimetría que el comentario de arriba describe.
        // Con el kill remoto puesto —o con el snapshot de remote-config ausente/fuera de bucket, que es fail-closed—
        // `startIfEligible` retorna en su primer guard ⇒ el barrido nunca corre, mientras este push-all SÍ empuja porque
        // el transporte no consulta el flag. Y bajar `GROUPS_BACKEND_ROLLOUT_PERCENT` es exactamente la respuesta
        // operativa a ESE incidente, así que sin el barrido aquí estaría apagado precisamente en la cohorte donde el veneno
        // sobrevive. Va DESPUÉS del drain (que con el guard `!updateOnly` ya no puede producir uno, pero si algún día lo
        // produjera esto lo recogería) y ANTES del pre-check: si la única fila viva era la venenosa, el conteo cae a 0 y el
        // cierre sale `.drained` sin un solo request.
        //
        // **Con la captura atascada el pre-check ya no sale: cicla** (2026-10-05, ticket
        // `groups-drain-that-always-aborts-takes-the-loss-exit-away`). Con el outbox a 0 salía `.uploadRetryLater` sin un solo
        // ciclo, así que nunca se sabía si lo que impide subir es el teléfono sin App Attest, la sesión que no hay o otra
        // cuenta —lo único que abre la salida que pierde esos cambios— y la persona oía «inténtalo en un rato» para siempre.
        // Lo pasajero (una vuelta que termina con el espejo fuera del outbox, o unas vueltas cortadas) sale como antes.
        let initialCapture = await captureGroupsForExit(context: context, witness: witness)
        if initialCapture != .stuck, let settled = CloudSignOutFlowLogic.groupsCaptureVerdict(
            captureCompleted: initialCapture == .completed,
            livePendingCount: Self.liveGroupsPendingCount(context: context),
            unrehydratedMirrorCount: witness.mirrorPending(context, .sessionOwner)) {
            return settled
        }
        // El último ciclo que corrió DE VERDAD: uno `.coalesced` (la cadencia tenía otro en vuelo) no dice por qué paró nada, así
        // que la rama de la captura atascada decide con el anterior, como `captureUnfinishedAfterLap` en el personal (review
        // adversarial del 2026-10-05, lentes 2 y 3).
        var lastRealCycle: GroupsCycleReading?
        for iteration in 1...maxIterations {
            // Los tres testigos del ciclo viajan con su outcome (`GroupsExitWitness.cycle`), leídos antes de cualquier
            // `await`: los reintentos de la re-captura esperan, y un ciclo de la cadencia que corra entre medias los reescribiría.
            let reading = await witness.cycle(context)
            let outcome = reading.outcome
            let channelKilled = reading.channelKilled
            let attestUnavailable = reading.attestUnavailable
            let uploadFailed = reading.uploadFailed
            if outcome != .coalesced { lastRealCycle = reading }
            // **Lo que ESTA sesión puede subir, no el outbox entero** (ticket
            // `groups-outbox-rows-without-a-live-session-have-no-exit`). Las filas de otra cuenta no las sube nunca, así que
            // contarlas dejaba el bucle esperando las 20 vueltas y el cierre en «un momento más» para siempre. Se cuentan
            // aparte, y cuando son lo único que queda el cierre lo dice (`uploadableAfterHeld`).
            if let verdict = CloudSignOutFlowLogic.pushAllVerdict(
                livePendingCount: CloudSignOutFlowLogic.uploadableAfterHeld(
                    live: Self.liveGroupsPendingCount(context: context), held: witness.heldForAnotherAccount(context)),
                cycleOutcome: outcome,
                // ¿Paró este ciclo por el kill-switch? Se pregunta CON el outcome en la mano, que es lo que
                // impide leer el testigo de un ciclo que no es éste. Con el kill puesto, el bloqueo se
                // anuncia como «los grupos están en pausa» y no como «tu cuenta ya no vale» — ticket
                // `groups-killswitch-403-blocks-detach-forever`.
                channelKilled: channelKilled,
                // ¿Paró este ciclo porque el teléfono lleva más de un día sin App Attest? Se pregunta igual, CON el
                // outcome: la racha sola no dice por qué falló ESTE ciclo (ticket
                // `groups-phone-that-never-attests-is-told-to-retry-forever`).
                attestUnavailable: attestUnavailable,
                // ¿Chocó este ciclo con el servidor EMPUJANDO? Se pregunta igual, CON el outcome. Sin este término,
                // el `save()` local de una página del pull y el tope de páginas salían como «tus cambios no llegaron
                // al servidor» con la subida perfecta, y encima sin los 45 s de reintentos que ese caso sí cura
                // (ticket `signout-pending-copy-says-wait-seconds-when-offline`).
                uploadFailed: uploadFailed,
                iteration: iteration,
                maxIterations: maxIterations
            ) {
                guard verdict == .drained else {
                    // **Los bloqueos que abren la salida de la pérdida son los únicos que un caller deja seguir** —la
                    // pérdida aceptada (`continuesAfterBlockedUpload`) compara solo las filas VIVAS con las aceptadas—, así
                    // que antes de devolverlos se comprueba que no quede nada FUERA del outbox. Sin esto, un cambio que solo
                    // vivía en el History por un drain a medias se iba con el cierre sin haber salido en el aviso (review
                    // adversarial del 2026-09-26, dos lentes). Lo recapturado entra al outbox y la comparación por filas lo
                    // ve; lo que no se pudo capturar bloquea como subida pendiente, sin salida de pérdida hasta que se
                    // capture. Desde el 2026-09-28 abre la salida también la sesión caducada (`lossCause`).
                    guard case .blocked(_, let reason) = verdict, CloudSignOutFlowLogic.lossCause(reason) != nil else {
                        return verdict
                    }
                    //
                    // **Con la captura atascada el motivo se conserva desde el 2026-10-05**: el aviso cuenta entonces lo que
                    // el drain no capturó (`groupsLoss`), y esperar no lo iba a curar.
                    let recaptured = await captureGroupsForExit(context: context, witness: witness)
                    return CloudSignOutFlowLogic.lossBlockAfterRecapture(
                        reason: reason,
                        capture: recaptured,
                        livePendingCount: Self.liveGroupsPendingCount(context: context),
                        unrehydratedMirrorCount: witness.mirrorPending(context, .sessionOwner))
                }
                // **El outbox a 0 tras un ciclo no prueba que no quede nada**: el drain del ciclo no viaja en su outcome,
                // y uno que no terminó deja el gasto solo en el History. Se vuelve a capturar aquí, con el testigo en la
                // mano y no con un campo que otro ciclo pudo escribir. `nil` = la captura sacó filas nuevas: otra vuelta.
                //
                // **Con filas de otra cuenta, «drenado» es lo de ESTA sesión** (2026-09-28): si tras la captura solo quedan
                // ésas, el cierre bloquea con su motivo y la cifra del outbox entero, que es lo que se perdería
                // (`heldRowsVerdict`).
                //
                // **Y con la captura atascada decide quién apuntó lo que queda fuera** (2026-10-05,
                // `CloudSignOutFlowLogic.stuckCaptureVerdict`): el motivo del ciclo si abre la salida —con el outbox a 0
                // `pushAllVerdict` lo ignora—, los cambios de otra cuenta si todo lo de fuera es suyo, y si no, el drain que no
                // termina (`.groupsCaptureUnfinished`), sin salida.
                let captured = await captureGroupsForExit(context: context, witness: witness)
                let live = Self.liveGroupsPendingCount(context: context)
                let held = witness.heldForAnotherAccount(context)
                if captured == .stuck {
                    // Sin ningún ciclo real todavía, otra vuelta: decidir con un `.coalesced` diría «inténtalo en un rato» a
                    // quien no tiene App Attest o sesión.
                    if let real = lastRealCycle {
                        let uncaptured = witness.uncapturedChanges(context)
                        return CloudSignOutFlowLogic.stuckCaptureVerdict(
                            cycleReason: CloudSignOutFlowLogic.cycleBlockReason(
                                real.outcome, channelKilled: real.channelKilled,
                                attestUnavailable: real.attestUnavailable, uploadFailed: real.uploadFailed),
                            livePendingCount: live,
                            uncapturedAllHeldForAnotherAccount: uncaptured.map {
                                !$0.isEmpty && $0.allSatisfy(\.heldForAnotherAccount)
                            })
                    }
                } else if let settled = CloudSignOutFlowLogic.groupsCaptureVerdict(
                    captureCompleted: captured == .completed,
                    livePendingCount: CloudSignOutFlowLogic.uploadableAfterHeld(live: live, held: held),
                    unrehydratedMirrorCount: witness.mirrorPending(context, .sessionOwner)) {
                    return CloudSignOutFlowLogic.heldRowsVerdict(settled, livePendingCount: live, heldCount: held)
                }
            }
            // S1: un ciclo de la cadencia EN VUELO devuelve `.coalesced` SINCRÓNICO — la pausa deja
            // terminar el ciclo en vuelo; sin ella el loop quemaría las 20 iteraciones en microsegundos.
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                break  // cancelación del caller
            }
        }
        // Fuera del loop por cancelación (break), o porque la re-captura de la última vuelta sacó filas nuevas: las dos,
        // transitorio (reintentable).
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
        func safe() -> Bool { personalSaveIsSafeNow() }
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

    /// ¿Es seguro hacer `save()` sobre el contexto compartido AHORA, sin esperar? La lectura de
    /// `awaitPersonalQuiescenceForGroupsSignOut`, para quien ya esperó y solo tiene que volver a mirar tras una pausa
    /// (`captureGroupsForExit`).
    static func personalSaveIsSafeNow() -> Bool {
        CloudSignOutFlowLogic.isPersonalSaveSafe(
            mountAttachesMirror: personalMountAttachesMirror,
            accountAvailable: iCloudSyncService.shared.isAccountAvailable,
            firstImportCompleted: iCloudSyncService.shared.hasCompletedFirstImport,
            importQuiescent: iCloudSyncService.shared.isImportQuiescent)
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

    /// Las filas VIVAS del outbox de GRUPOS, por su `clientMutationID`: lo que se compara con lo que la persona aceptó
    /// perder. `nil` si el fetch falla, y eso solo lo cubre una aceptación sin cifra: una fila que no se pudo mirar no se
    /// descarta por una cifra.
    static func liveGroupsPendingRowIDs(context: ModelContext) -> Set<UUID>? {
        do {
            let rows = try context.fetch(FetchDescriptor<GroupSyncOutbox>(
                predicate: #Predicate { $0.rejectedReason == nil }))
            return Set(rows.map(\.clientMutationID))
        } catch {
            #if DEBUG
            print("CloudSessionSignOut: Error leyendo las filas vivas del outbox de grupos: \(error)")
            #endif
            return nil
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
