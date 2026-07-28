//
//  GroupPullRescueGate.swift
//  Yala
//
//  Decisión PURA del RESCATE de pull (C-4, PIEZA 2): un record CloudKit que llega para un grupo YA
//  MIGRADO, ¿es un eco stale que hay que descartar, o dato real que nadie va a volver a entregar?
//
//  EL BUG QUE CIERRA. El guard G6-3 (C2) de `SplitSyncManager.handleFetchedRecordZoneChanges` descarta
//  TODO record cuya zona pertenezca a un grupo `isBackendGroup=true`. El guard es correcto para el eco
//  stale (un miembro rezagado o el eco del propio marcador pisaría las ediciones backend
//  post-migración), pero NO distingue ese caso del record NUNCA VISTO — y el token de CKSyncEngine
//  avanza igual, así que ese record no se re-entrega JAMÁS. Dinero perdido en silencio, con una firma
//  (`groupsCkPullSkippedBackendGroup(site:"applyRemote")`) idéntica a la del descarte legítimo.
//
//  Dos ventanas que esto cierra y que `GroupFetchQuiescenceGate` (PIEZA 1) no puede cerrar, porque
//  aquélla acota el PASADO (el device sabe que su store no está al día) y ésta el FUTURO:
//   1. El invitado que sube su gasto DESPUÉS del flip. Su ventana no depende del reloj del owner: un
//      gasto registrado sin red hace días sube mañana.
//   2. El camino de resume: si el paso 5 del uploader falla, el grupo queda `isBackendGroup == true &&
//      movedToBackendAt == nil` durante días, con CloudKit congelado y cada escritura descartándose.
//
//  QUÉ HACE EL RESCATE, EXACTAMENTE: INSERTA la fila ausente (nunca la actualiza) y deja que el drain
//  del canal backend la capture por History → outbox → push. Es re-inyección al backend de lo que
//  CloudKit tenía y el backend no.
//
//  ── LOS CUATRO INVARIANTES (romper cualquiera reabre G6-3 C2 o es peor que el bug) ──────────────────
//
//  1. EL RESCATE JAMÁS ACTUALIZA. Enforced en el SITIO DE LA MUTACIÓN
//     (`SplitSyncManager.applyRemoteRecordIfAbsent`, que re-chequea por id con los helpers concretos),
//     no en un Set precalculado. `existsLocally` de esta señal es la decisión; el re-chequeo es el
//     candado. Los dos, a propósito: el Set del pre-fetch del batch es best-effort y su catch lo deja
//     VACÍO (ver invariante 3), y `applyRemoteRecord` UPDATEA si la fila existe.
//  2. EL RESCATE JAMÁS APLICA DELETIONS. Una deletion de una zona backend es exactamente lo que el
//     guard debe descartar: la verdad de las bajas vive en el backend. Este gate no se consulta
//     siquiera en el bucle de deletions.
//  3. EL RESCATE JAMÁS TOCA `GroupMeta` NI `SplitMember`. `GroupMeta` porque el grupo existe por
//     definición (es lo que pone la zona en `backendZoneNames`) y adoptarlo sería meta stale;
//     `SplitMember` porque es PULL-ONLY (`GroupEntityEmissionMap.emittableGroupEntityNames` lo excluye)
//     ⇒ adoptarlo insertaría filas que el drain descarta EN SILENCIO. Ver `rescuableTypes`.
//  4. CON EL FLAG APAGADO EL COMPORTAMIENTO ES BYTE-IDÉNTICO AL DE HOY. Nadie pone `isBackendGroup =
//     true` con `groupsBackendEnabled == false`, y aun así `flagOn` corta lo primero, antes de
//     cualquier lectura extra del store.
//
//  ── POR QUÉ CADA GATE (los cuatro salen de la revisión adversarial, no de la teoría) ────────────────
//
//  `backendPullCompletedThisSession` + `groupHasBackendCursor` — «conocido localmente» NO significa «el
//  backend no lo tiene». En un device que NO migró, `isBackendGroup` se enciende DENTRO del pull backend
//  (`GroupsSyncClient.applyGroupMeta`, born-remote y adopción C3) ANTES de que ese pull haya entregado
//  las filas. En esa ventana CloudKit entrega los records PRE-migración, todos parecerían «nunca vistos»
//  y adoptarlos los empujaría con HLC fresco, PISANDO en el servidor las ediciones post-migración de
//  TODO el grupo. Las dos condiciones juntas son la única lectura bajo la que «ausente localmente»
//  significa de verdad «ni CloudKit ni el backend lo tenían»: el cursor por grupo solo existe una vez
//  que el server reportó ese `group_id`, y `pullUntilExhausted` solo devuelve `.completed` cuando una
//  página trae 0 deltas, es decir cuando el corpus backend de ese grupo está aplicado hasta su
//  `server_seq`.
//
//  `replayingFullCorpus` — resurrección en masa. Tras un reset de tokens (`clearState`, o los engines
//  reconstruidos con `state: nil` en un cambio de identidad) el siguiente arranque hace re-entrega
//  COMPLETA: toda fila borrada en el backend DESPUÉS de migrar vuelve como «nunca vista» → se adopta →
//  se empuja → `apply_group_delta` la reinstaura para todo el grupo. Es de SESIÓN y no de ciclo a
//  propósito: la avalancha llega repartida en muchos ciclos de fetch a lo largo de la sesión, así que
//  suspender solo hasta el primer ciclo cerrado dejaría el rescate abierto justo cuando llega el grueso.
//  La siguiente sesión ya arranca con token.
//
//  `prefetchFailed` — el pre-fetch de IDs existentes del batch es best-effort: su `catch` deja los sets
//  VACÍOS y sigue. Aquí no decide (el candado es el re-chequeo por id), pero un store que no se ha
//  podido leer es evidencia suficiente para no adoptar nada en ese batch. Cinturón, no mecanismo.
//
//  Idioma del repo (`SplitSyncStartGate`, `GroupFetchQuiescenceGate`, `MigrationGateLogic`,
//  `SubcategoryDedupGate`): decisión PURA sobre un struct de entradas + adaptador de runtime fino.
//
//  RESIDUAL CONSCIENTE (decisión del owner, 2026-07-27): el rescate es INSERT-ONLY. Una edición que un
//  miembro hizo ANTES del freeze y que este device no había bajado llega como eco de algo conocido y se
//  descarta para siempre. Cubrirla exigiría un umbral temporal propio (`backendFreezeAt` estampado en el
//  paso 3 del uploader, viajando por CloudKit ⇒ deploy de schema a Production en los DOS containers) y
//  comparar el reloj del servidor CloudKit contra el del owner. Se acepta a cambio de mantener el
//  invariante 1 verificable de un vistazo.
//

import Foundation

/// Gate PURO «este record de una zona ya migrada, ¿se rescata o se descarta?».
nonisolated enum GroupPullRescueGate {

    // MARK: - Qué es rescatable (SSOT del cruce entre los dos namespaces)

    /// `CKConstants.RecordType` (namespace CloudKit) → nombre de clase `@Model` (namespace del canal
    /// backend). Las DOS columnas son literales estables: renombrar la clase NO debe cambiar el record
    /// type, mismo invariante que `GroupSyncEntityType`.
    ///
    /// El mapa existe —en vez de un `Set` de tipos— porque los dos namespaces NO son el mismo, y esa
    /// asimetría es justo la trampa que hay que dejar visible: `GroupMeta` (record type) es `SplitGroup`
    /// (clase). Si alguien añadiera aquí una entrada cuyo nombre de clase NO esté en
    /// `GroupEntityEmissionMap.emittableGroupEntityNames`, el rescate insertaría dinero que el drain
    /// descarta en silencio — el peor fallo posible de esta feature, y por eso lo pinnea
    /// `GroupPullRescueParityTests`.
    ///
    /// `GroupMeta` y `SplitMember` están FUERA por los invariantes 3 y no por olvido.
    static let rescuableTypes: [String: String] = [
        "SplitExpense": "SplitExpense",
        "SplitShare": "SplitShare",
        "SplitSettlement": "SplitSettlement",
    ]

    /// Nombre de clase `@Model` del record type, o `nil` si ese tipo NO es rescatable.
    static func entityName(forRecordType recordType: String) -> String? {
        rescuableTypes[recordType]
    }

    // MARK: - Señal

    /// Instantánea de la decisión para UN record. La ensambla el adaptador de `SplitSyncManager`; nada
    /// se deriva aquí por cuenta propia.
    struct Signal: Equatable, Sendable {

        /// `CloudSyncFlags.groupsBackendEnabled`. Con el canal apagado no hay grupos backend y el
        /// rescate no existe (invariante 4).
        let flagOn: Bool

        /// Algún engine de CKSyncEngine arrancó SIN estado persistido en ESTA sesión (o fue
        /// reconstruido con `state: nil`) ⇒ CloudKit está re-entregando el corpus entero.
        let replayingFullCorpus: Bool

        /// El pre-fetch de IDs existentes de este batch lanzó y sus sets quedaron vacíos.
        let prefetchFailed: Bool

        /// El canal backend completó ≥1 ciclo de pull ENTERO en esta sesión (`pullUntilExhausted`
        /// devolvió `.completed`, es decir una página con 0 deltas).
        let backendPullCompletedThisSession: Bool

        /// El `group_id` de esta zona está en `GroupSyncCursor.groupCursorsJSON` — el server ya reportó
        /// ese grupo, así que el pull de arriba habla también de ÉL.
        let groupHasBackendCursor: Bool

        /// El record type está en `rescuableTypes`.
        let isRescuableType: Bool

        /// Ya hay una fila local con ese id (eco stale). El re-chequeo por id en el sitio de la
        /// mutación es el candado; esto es la decisión.
        let existsLocally: Bool
    }

    enum Decision: Equatable, Sendable {
        /// Insertar la fila ausente y dejar que el drain la empuje al backend.
        case rescue
        /// Descartar, como hasta hoy.
        case discard
    }

    /// Orden fijo: primero lo que apaga el rescate ENTERO (flag, sesión, batch), luego lo que depende
    /// del grupo, y por último lo del record. `skipReason` espeja esta precedencia exactamente.
    static func decide(_ signal: Signal) -> Decision {
        guard signal.flagOn,
              !signal.replayingFullCorpus,
              !signal.prefetchFailed,
              signal.backendPullCompletedThisSession,
              signal.groupHasBackendCursor,
              signal.isRescuableType,
              !signal.existsLocally
        else { return .discard }
        return .rescue
    }

    /// Slug estable del MOTIVO del descarte — para el `reason` del breadcrumb. Sin PII. Espejo exacto
    /// de la precedencia de `decide`.
    ///
    /// `"rescued"` es DIAGNÓSTICO PURO: nunca sale por el breadcrumb de descarte (ahí `decide` devolvió
    /// `.rescue` y no hay descarte que explicar). Existe para que un caller que llame a `skipReason`
    /// sin pasar por `decide` no lea un motivo falso — mismo criterio que el `"noChannel"` de
    /// `GroupFetchQuiescenceGate`.
    static func skipReason(_ signal: Signal) -> String {
        if !signal.flagOn { return "flagOff" }
        if signal.replayingFullCorpus { return "replay" }
        if signal.prefetchFailed { return "prefetchFailed" }
        if !signal.backendPullCompletedThisSession { return "noBackendPull" }
        if !signal.groupHasBackendCursor { return "noCursor" }
        if !signal.isRescuableType { return "notRescuable" }
        if signal.existsLocally { return "staleEcho" }
        return "rescued"
    }
}
