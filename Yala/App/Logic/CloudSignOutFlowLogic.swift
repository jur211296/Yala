//
//  CloudSignOutFlowLogic.swift
//  Yala
//
//  Pure-logic del «Cerrar sesión» (H4; un verbo por celda desde el ADR 2026-09-09 «Sesiones — dos
//  ejes»): el camino de cada celda y el veredicto del push-all previo al cierre.
//
//  Invariante de seguridad (F0), en TODOS los caminos: NUNCA se borran datos EN SESIÓN — el cleanup
//  destructivo (archivos del store personal + sync-meta, y los de grupos si toca) corre en el BOOT
//  pre-mount, gated por `signOutWipeArmed`. Borrar FILAS con el espejo de CloudKit montado exportaría
//  los deletes a iCloud (`DataWipeService`), y en `.cloud` el replay de History al remontar haría lo
//  mismo (qa/cloud/README HALLAZGO 3).
//

import Foundation

nonisolated enum CloudSignOutFlowLogic {

    /// Camino del cierre de sesión, UNO por celda del ADR 2026-09-09. El verbo que ve el usuario es
    /// siempre «Cerrar sesión»; lo que cambia por celda es qué se sube antes de borrar y qué se borra,
    /// y eso lo cuenta la hoja de alcance (`DestructiveScopeLogic.signOutOperation`).
    ///
    /// **Todas las salidas dejan el dispositivo como recién instalado por el mismo boot-wipe de
    /// archivos** (`armSignOutWipe` → `SwiftDataConfiguration.performSignOutWipeIfArmed`, que además
    /// arma el neutro duradero).
    enum Path: Equatable {
        /// Sesión PRIVADA sin cuenta en la nube (celda C). Espera a que el último cambio llegue a iCloud
        /// (`PrivateSignOutExportGateLogic`) → arma el borrado por ARCHIVOS del store personal + sync-meta →
        /// relanzamiento. iCloud queda intacto: «entrar» vuelve a ser «Restaurar desde iCloud». El store de
        /// grupos entra en el borrado solo si guarda filas del canal backend (una sesión que caducó): esas
        /// sí se pueden volver a bajar, y dejarlas enseñaría a la persona siguiente grupos ajenos.
        case privateSignOut
        /// «Equipo»: sesión privada + cuenta de grupos (celda D). Sube los grupos (push-all verificado,
        /// jamás descartar) → espera el export de iCloud → cierra la sesión de grupos → arma el borrado
        /// personal + sync-meta + GRUPOS. No existe «salir solo de grupos» (ADR §5).
        case privateWithGroupsSignOut
        /// `.cloud` (celda E): push-all personal + grupos (bloquear si falla, jamás descartar) →
        /// signOut + teardown → armar `signOutWipeArmed` → relanzamiento asistido o swap sin relanzar.
        case cloudSecureSignOut
        /// SIN sesión privada (celda F, con su sesión en la nube viva o ya caducada): push-all verificado del
        /// outbox de grupos → teardown del canal → cierra la sesión → arma el borrado personal + sync-meta +
        /// grupos → Welcome. Lo que hubiera en el store personal no era de una sesión privada.
        case groupsOnlySignOut
    }

    /// Precedencia CONGELADA:
    ///  1. `.cloud` — lo personal vive en la cuenta y lo sincroniza el motor.
    ///  2. `!hasPrivateSession` — solo grupos (F), con la sesión viva o caducada: sin vida personal que
    ///     proteger, cierra borrando lo local.
    ///  3. `groupsBackendEnabled && hasLiveSession` — privada con cuenta de grupos: el «equipo» (D).
    ///  4. else — privada sin nube (C).
    ///
    /// **La mecánica la decide `storageMode` y no el `kind` de la cuenta (paso 3).** El `kind` describe
    /// la CUENTA; qué hay que subir y qué se puede borrar lo decide dónde viven los datos EN ESTE
    /// dispositivo. Una cuenta `complete` sobre un store `.icloud` no existe en el modelo (asociarla se
    /// bloquea), y si existiera, el camino `.cloud` buscaría un outbox personal que no hay.
    ///
    /// `hasPrivateSession` es EL EJE 1 del ADR 2026-09-09, leído de `PrivateSessionMark` — el mismo
    /// eje y la misma lectura que usa «Vaciar datos» (`DestructiveScopeLogic.wipeOperation`). Sin
    /// parámetro por defecto a propósito: la vista y el coordinador tienen que pronunciarse los dos,
    /// o la hoja prometería otro borrado.
    static func path(for storageMode: StorageMode,
                     hasLiveSession: Bool,
                     groupsBackendEnabled: Bool,
                     hasPrivateSession: Bool) -> Path {
        if storageMode == .cloud { return .cloudSecureSignOut }
        if !hasPrivateSession { return .groupsOnlySignOut }
        if groupsBackendEnabled && hasLiveSession { return .privateWithGroupsSignOut }
        return .privateSignOut
    }

    /// Qué se sube antes de borrar en los tres cierres que borran por ARCHIVOS (C, D y F).
    enum ExitKind: Equatable {
        /// Privada sin cuenta en la nube (C): se espera al export de iCloud.
        case privateOnly
        /// «Equipo» (D): suben los grupos y se espera al export de iCloud.
        case privateWithGroups
        /// Solo grupos (F): suben los grupos; el export solo se espera si el store espeja.
        case groupsOnly

        var pushesGroups: Bool { self != .privateOnly }
    }

    struct ExitPlan: Equatable {
        let kind: ExitKind
        /// ¿Se espera a que lo último llegue a iCloud antes de borrar?
        let waitsForExport: Bool
    }

    /// El reparto de los tres cierres por archivos; `nil` para la nube, que tiene su propio camino.
    ///
    /// **Es la decisión que más datos protege del paso 9, y por eso es pura y va por tabla.** La review
    /// adversarial midió que invertir un solo término —C sin esperar al export, D sin subir sus grupos— no
    /// lo cazaba ningún test: los source-scans miraban el orden de las llamadas, no sus condiciones.
    ///  - C y D esperan, salvo que la persona haya confirmado con el segundo gesto que no hay copia.
    ///  - F solo espera si su store ESPEJA (p. ej. una instalación anterior al paso 5): ahí borrar sin
    ///    esperar podría llevarse cambios del Apple ID que aún no subieron.
    ///    `confirmedWithoutICloudCopy` no le aplica: F no tiene hoja «sin copia».
    static func exitPlan(path: Path, confirmedWithoutICloudCopy: Bool, mountAttachesMirror: Bool) -> ExitPlan? {
        switch path {
        case .privateSignOut:
            return ExitPlan(kind: .privateOnly, waitsForExport: !confirmedWithoutICloudCopy)
        case .privateWithGroupsSignOut:
            return ExitPlan(kind: .privateWithGroups, waitsForExport: !confirmedWithoutICloudCopy)
        case .groupsOnlySignOut:
            return ExitPlan(kind: .groupsOnly, waitsForExport: mountAttachesMirror)
        case .cloudSecureSignOut:
            return nil
        }
    }

    // D4: `ConfirmMessage`/`confirmMessage(for:)` ELIMINADOS — el copy por-path del sign-out ya no es un
    // mensaje único; lo sustituyen las filas de la hoja de alcance (`DestructiveScopeLogic`, operación
    // resuelta en ProfileView por `signOutScopeOperation`). Las keys `signOutConfirmMessage*` fueron retiradas.
    //
    // Paso 9 del rediseño (2026-09-11): `shouldShowRow`, `shouldShowExitYalaRow` y `RowLayout` RETIRADOS.
    // Ajustes enseña UNA fila «Cerrar sesión» en todas las celdas (ADR §6, «dos botones y nada más»), así
    // que no queda ninguna distribución que decidir. Con ellas se fueron «Cerrar sesión de grupos» y
    // «Salir de Yala en este dispositivo».

    /// Naturaleza del bloqueo del push-all (H-2026-07-18-6): distingue lo que se sana
    /// SOLO esperando (red intermitente, ciclo coalescido, quiescencia del import aún no
    /// asentada) de lo que NO se cura sin acción del usuario (sesión caída / cuenta no
    /// disponible). El sign-out solo-grupos reintenta internamente los transitorios y solo
    /// muestra un error cuando agota su presupuesto o el bloqueo es permanente.
    /// `CaseIterable` **no es decorado**: `GroupsSignOutRetryDecision.decide` es una cadena de `if` y no un
    /// `switch`, así que el compilador NO obliga a pronunciarse sobre un motivo nuevo — y su rama por
    /// defecto es la peor de las dos: 45 s de espera y ~22 peticiones contra algo que no se cura. La red es
    /// `GroupsSignOutRetryDecisionTests.everyReasonHasADecision`, que recorre `allCases` y se cae en cuanto
    /// aparece uno sin decidir.
    enum BlockReason: Equatable, CaseIterable {
        /// Curable esperando: red/HTTP/decode/save intermitente, ciclo coalescido, o el
        /// tope de iteraciones/quiescencia (aún drenando). Reintentable.
        case transient
        /// NO curable sin acción del usuario: 401 sesión caída, cuenta no disponible.
        ///
        /// **Desde el 2026-09-14 `classify` ya no lo produce por un 403 del canal de Grupos** —el del kill
        /// trae `.channelPaused`, el de infraestructura es `.transient`— pero eso NO significa que un 403
        /// de infraestructura deje de verse como `.permanent`, y la diferencia importa: el paso 2 de
        /// `CloudSessionSignOut.performCloudSecureSignOut` **colapsa en `.permanent` todo veredicto de
        /// grupos que no sea `.channelPaused`**, así que en el cierre de una cuenta `.cloud` un WAF sigue
        /// saliendo como «revisa tu conexión». Ese colapso es anterior y deliberado (su comentario lo dice:
        /// los otros motivos conservan su alert porque nadie ha pedido cambiarlo) y tocarlo movería también
        /// la red caída y los 5xx, que es otro objeto. Ticket:
        /// `cloud-signout-collapses-every-groups-transient-into-permanent`.
        case permanent
        /// El cierre PRIVADO esperó a que el último cambio llegara a iCloud y agotó el presupuesto. Es el
        /// único bloqueo del móvil propio con salida de emergencia (decisión de Jürgen, 2026-09-09): tras
        /// la espera normal, el aviso dice cuántos cambios no han llegado y ofrece cerrar igualmente, con
        /// confirmación. Con este motivo, `pendingCount == 0` significa «no se pudo contar» (el historial
        /// no se leyó), jamás «no hay nada pendiente»: con cero pendientes el cierre no se bloquea.
        case exportUnconfirmed
        /// La sesión en la nube ya no existe y quedan cambios de GRUPOS sin subir. Solo se suben volviendo a
        /// entrar con la cuenta, y descartarlos no es una opción («nunca descarta»). Va aparte de `.permanent`
        /// porque el aviso de siempre («revisa tu conexión») mandaba a buscar un fallo que no existe (review
        /// adversarial del paso 9).
        case sessionExpired
        /// **No se pudo mirar el puente personal al desasociar** (`GroupsAssociationDetach.detachBridge`
        /// devolvió `nil`): su fetch lanzó, o su `save()` no entró. Va aparte porque el aviso de siempre
        /// —«quedan cambios de tus grupos sin subir, inténtalo en un momento»— describe un problema que
        /// no es y da un consejo que no arregla nada: no hay nada sin subir (se llega aquí con el
        /// push-all ya drenado y `pendingCount == 0`) y esperar no cambia que el store no responda.
        /// Review adversarial del 2026-09-11.
        case bridgeUnreadable
        /// **El coordinador estaba ocupado con OTRO gesto** cuando se pidió desasociar —un cierre de
        /// sesión del Perfil en curso o parado en su propio aviso—. No hay nada sin subir: el desasociar
        /// ni siquiera arrancó (`guard phase == .idle`). Va aparte porque es el único motivo cuya fase NO
        /// la puso el gesto que lo enseña, así que su aviso **no puede llamar a `acknowledgeBlocked()`**:
        /// le borraría al cierre ajeno su fase y su `blockedExit`. Review adversarial del 2026-09-11.
        case detachBusy
        /// **El canal de Grupos está apagado A PROPÓSITO** (403 `yala_groups_disabled`, el kill-switch
        /// server-side de `gateway/src/groups/killSwitch.ts`) y quedan cambios de grupos sin subir.
        ///
        /// Va aparte de `.permanent` porque el kill es una palanca de OPERACIÓN que alguien bajó por un
        /// incidente y que se levanta con un deploy: no hay nada roto en la cuenta de quien lo sufre, y el
        /// aviso de siempre —«no pudimos conectar, revisa tu conexión»— le manda a buscar un fallo que no
        /// existe, sin nombrar lo único cierto, que es «vuelve en un rato». La distinción la trae el cliente
        /// desde el borde donde lee el 403 (`GroupsSyncClient.stoppedByChannelKill(for:)`); aquí solo se
        /// conserva.
        ///
        /// **Qué es el OTRO 403, medido el 2026-09-13 y no lo que parece.** El gateway emite exactamente dos
        /// 403 en todo `gateway/src/`: éste y `yala_pro_required`, que es de la IA y nunca alcanza estas
        /// rutas (`policy.ts` da límites de `sync` a los dos tiers); los fallos upstream de `/groups/*` salen
        /// como 502 `yala_unavailable`. **No hay ningún 403 de «cuenta suspendida» en `/groups/*`**, así que
        /// el otro viene de infraestructura — un proxy o un WAF por delante del Worker. Desde el 2026-09-13
        /// **ése ya no llega hasta aquí**: el canal de sync lo clasifica `.transient` con reintento, como su
        /// hermano `GroupsMembershipClient` llevaba haciendo desde el principio. O sea que a `.channelPaused`
        /// llega el kill y solo el kill, y quien lo enciende no compite con nada.
        ///
        /// **No se reintenta dentro del gesto, y es deliberado** (ver `GroupsSignOutRetryDecision.decide`).
        /// Nada se ha escrito y nada se pierde: el outbox queda intacto y volver a pulsar cuando el canal
        /// vuelva completa el gesto.
        case channelPaused
    }

    /// ¿Es seguro hacer `save()` sobre el contexto compartido AHORA? Es la puerta de quiescencia de los
    /// cierres que drenan el outbox de grupos (el drain es un `save()`, y con un import de CloudKit a medio
    /// asentar SwiftData lanza un `_assertionFailure` que no se puede atrapar).
    ///
    /// **Paso 9 · el término del mount va PRIMERO, y es la corrección de un bug medido.** Un store que no
    /// espeja (`attachesCloudKitMirror == false`: el mount neutro de toda sesión solo-grupos) no emite
    /// eventos de CloudKit, así que `firstImportCompleted` no se enciende nunca: con iCloud Drive activo, la
    /// puerta esperaba su tope de 60 s, reintentaba y acababa en «un momento más» — el cierre solo-grupos no
    /// podía terminar. Sin espejo no hay import con el que chocar: es seguro siempre.
    ///
    /// `accountAvailable` es el token de iCloud Drive, el predicado que gobierna el mount, y su ausencia abre
    /// la puerta. **Para una población la puerta falla ABIERTO, y se sabe** (review adversarial del paso 9;
    /// `swiftdata-cloudkit.md`, «`ubiquityIdentityToken` mide iCloud DRIVE»): con Drive apagado y CloudKit
    /// vivo el token falta y el espejo `.automatic` sigue importando. Es preexistente y se queda así porque el
    /// sustituto obvio —`mirrorReportedNotAuthenticated`— solo existe si CloudKit contesta con un `CKError`:
    /// sin él, un dispositivo sin iCloud esperaría para siempre un import que no llega y el cierre de grupos
    /// quedaría colgado. Ticket: `groups-sign-out-quiescence-gate-fails-open-with-drive-off`.
    static func isPersonalSaveSafe(mountAttachesMirror: Bool, accountAvailable: Bool,
                                   firstImportCompleted: Bool, importQuiescent: Bool) -> Bool {
        !mountAttachesMirror || !accountAvailable || (firstImportCompleted && importQuiescent)
    }

    /// Clasifica el outcome crudo de un ciclo de cadencia (H-2026-07-18-6). Base del retry interno del
    /// sign-out solo-grupos. La sesión caducada va aparte de la cuenta no disponible desde el paso 9: las dos
    /// son permanentes, pero solo la primera se arregla volviendo a entrar, y el aviso tiene que decirlo.
    ///
    /// **`.transient` no es el cajón de lo pequeño**: desde el 2026-09-13 también trae el 403 de
    /// infraestructura, que antes se anunciaba como veredicto sobre la cuenta. Su aviso reintenta dentro del
    /// gesto (45 s, `GroupsSignOutRetryDecision`) y acaba en «un momento más» — que es lo único cierto que
    /// se puede decir de un WAF: nada se escribió, el outbox está intacto y volver a pulsar lo completa.
    /// `channelKilled` es la mitad que `CadenceOutcome` no puede llevar: **si el 403 que paró el ciclo era
    /// el del kill-switch**. Hace falta porque `.accountUnavailable` tiene dos orígenes en el código que no
    /// merecen el mismo aviso: el kill del canal (403 `yala_groups_disabled` → `.channelPaused`) y el freeze
    /// de la reversa (409 `yala_account_reverting` → `.permanent`, que `/groups/push` hoy no emite). Lo
    /// contesta `GroupsSyncClient.stoppedByChannelKill(for:)`, que liga el testigo al outcome del ciclo.
    ///
    /// El tercer 403 —el de un proxy o un WAF por delante del Worker— **ya no entra por aquí** desde el
    /// 2026-09-13: el canal lo clasifica `.transient`, así que cae en la rama reintentable de abajo.
    ///
    /// **Sin valor por defecto a propósito.** Un `= false` lo heredaría en silencio todo call-site que no
    /// se pronunciara, y el camino que este parámetro abre es justo el que nadie mira hasta que hay un
    /// incidente. Quien no tenga la señal —el motor personal, cuyo 403 solo puede ser de cuenta— escribe
    /// `channelKilled: false` y lo dice.
    ///
    /// Solo cuenta cuando el ciclo paró por un 403: con cualquier otro outcome el término se ignora, que es
    /// lo que impide que un kill viejo tiña un fallo de red posterior.
    static func classify(_ outcome: SyncCadencePolicy.CadenceOutcome,
                         channelKilled: Bool) -> BlockReason {
        switch outcome {
        case .sessionExpired: return .sessionExpired
        case .accountUnavailable: return channelKilled ? .channelPaused : .permanent
        case .transient, .completed, .coalesced: return .transient
        }
    }

    /// Veredicto de una iteración del loop de push-all previo al cierre en `.cloud`.
    /// `nil` = seguir iterando.
    enum PushAllVerdict: Equatable {
        /// Outbox vivo == 0 verificado por fetch → seguro proceder al cierre.
        case drained
        /// Quedan filas vivas y el ciclo falló o se alcanzó el tope → ABORTAR el
        /// cierre. Los pendientes JAMÁS se descartan. `reason` distingue transitorio
        /// (reintentable) de permanente (H-2026-07-18-6).
        case blocked(pendingCount: Int, reason: BlockReason)
    }

    /// `cycleOutcome` (H-2026-07-18-6): el outcome CRUDO del ciclo — no el Bool colapsado —
    /// para que `.blocked` porte la naturaleza del bloqueo. "Éxito de ciclo" sigue siendo
    /// `.completed`/`.coalesced` (sin señal de fallo); el resto no drena. El tope de iteraciones
    /// con ciclo sano pero pendientes es un bloqueo TRANSITORIO (aún drenando, se agotó el margen).
    static func pushAllVerdict(
        livePendingCount: Int,
        cycleOutcome: SyncCadencePolicy.CadenceOutcome,
        channelKilled: Bool,
        iteration: Int,
        maxIterations: Int
    ) -> PushAllVerdict? {
        if livePendingCount == 0 { return .drained }
        let cycleSucceeded = cycleOutcome == .completed || cycleOutcome == .coalesced
        if !cycleSucceeded || iteration >= maxIterations {
            return .blocked(pendingCount: livePendingCount,
                            reason: classify(cycleOutcome, channelKilled: channelKilled))
        }
        return nil
    }
}

/// Decisión PURA del retry interno del sign-out solo-grupos (H-2026-07-18-6): el device-QA
/// mostró que el bloqueo típico es TRANSITORIO (writes internos del boot aún asentándose) y el
/// usuario tenía que tocar "Cerrar sesión" 2-3 veces. Aquí decidimos, ante un bloqueo, si
/// reintentar (dentro de un PRESUPUESTO GLOBAL de tiempo tras el primer bloqueo) o rendirse y
/// mostrar el error. `elapsedSeconds` es el tiempo transcurrido desde el PRIMER bloqueo (el
/// orquestador de servicio lo mide con `Date()`; la decisión lo recibe como número — regla del
/// repo: nunca `Date()`/sleep crudos en lógica testeada).
nonisolated enum GroupsSignOutRetryDecision {

    /// Presupuesto de reintentos (segundos ADICIONALES tras el primer bloqueo transitorio).
    static let budgetSeconds: Double = 45

    /// Intervalo entre reintentos (segundos).
    static let retryIntervalSeconds: Double = 2

    enum Decision: Equatable {
        /// Reintentar tras `seconds` (bloqueo transitorio, presupuesto NO agotado).
        case retryAfter(seconds: Double)
        /// Rendirse y mostrar el error transitorio ("un momento más") — presupuesto agotado.
        case surfaceTransient
        /// Rendirse y mostrar el motivo AL MOMENTO, sin reintentar: ningún reintento dentro del
        /// presupuesto puede cambiar el veredicto. Cubre la sesión caducada, la cuenta no disponible y el
        /// canal en pausa; **cuál de los tres es lo dice `reason`, que viaja aparte** — el caller lo
        /// propaga tal cual a la fase, y colapsarlo ahí fue el bug que se cerró el 2026-09-13.
        case surfacePermanent
    }

    static func decide(
        elapsedSeconds: Double,
        budgetSeconds: Double,
        reason: CloudSignOutFlowLogic.BlockReason
    ) -> Decision {
        // Sin sesión, esperar no sube nada: la sesión caducada se muestra al momento, como la permanente.
        //
        // **El canal en pausa también, y es una decisión de producto, no un descuido** (2026-09-13). El
        // kill-switch de Grupos es una palanca de operación que se levanta con un deploy: dentro de los
        // 45 s del presupuesto no se va a mover. Reintentar gastaría ~22 peticiones contra un 403 seguro
        // —en pleno incidente, que es lo contrario de lo que quiere quien bajó la palanca— y encima
        // retrasaría 45 s un aviso que ya se puede dar. Lo que sigue siendo reintentable es el GESTO: no
        // se escribió nada, el outbox queda intacto y volver a pulsar cuando el canal vuelva lo completa.
        if reason == .permanent || reason == .sessionExpired || reason == .channelPaused {
            return .surfacePermanent
        }
        if elapsedSeconds < budgetSeconds { return .retryAfter(seconds: retryIntervalSeconds) }
        return .surfaceTransient
    }
}
