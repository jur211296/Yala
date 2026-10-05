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

    /// **¿El borrado de este cierre se lleva también el store de GRUPOS del teléfono?** Es la pregunta que el
    /// coordinador se hace pegado al arm (`CloudSessionSignOut.armAfterCredentials`, que escribe
    /// `markSignOutWipeIncludesGroups` si sale `true`) y la que la hoja del cambio de Apple ID contesta ANTES
    /// de que la persona confirme (ticket `apple-id-close-notice-does-not-say-what-else-the-close-does`).
    ///
    /// **Una sola fórmula para los dos a propósito**: si la hoja la copiara, el día que el cierre cambie de
    /// criterio la hoja seguiría contando el de antes.
    ///  - Los cierres que SUBEN grupos (D, F) los olvidan siempre: ya están en la cuenta.
    ///  - La privada sin sesión (C) solo si el store guarda filas del canal backend
    ///    (`CloudSessionSignOut.hasBackendGroupRows`, una sesión de grupos que caducó).
    ///  - Sin la capacidad COMPILADA del canal no hay marca, y el store de grupos sobrevive al borrado.
    static func wipeForgetsGroups(kind: ExitKind, hasBackendGroupRows: Bool, groupsBackendCompiled: Bool) -> Bool {
        (kind.pushesGroups || hasBackendGroupRows) && groupsBackendCompiled
    }

    // D4: `ConfirmMessage`/`confirmMessage(for:)` ELIMINADOS — el copy por-path del sign-out ya no es un
    // mensaje único; lo sustituyen las filas de la hoja de alcance (`DestructiveScopeLogic`, operación
    // resuelta en ProfileView por `signOutScopeOperation`). Las keys `signOutConfirmMessage*` fueron retiradas.
    //
    // Paso 9 del rediseño (2026-09-11): `shouldShowRow`, `shouldShowExitYalaRow` y `RowLayout` RETIRADOS.
    // Ajustes enseña UNA fila «Cerrar sesión» en todas las celdas (ADR §6, «dos botones y nada más»), así
    // que no queda ninguna distribución que decidir. Con ellas se fueron «Cerrar sesión de grupos» y
    // «Salir de Yala en este dispositivo».

    /// Naturaleza del bloqueo del push-all (H-2026-07-18-6): distingue lo que se sana SOLO esperando
    /// —el outbox que aún drena, un ciclo coalescido, la quiescencia del import sin asentar— de lo que
    /// NO se cura sin acción del usuario (sesión caída / cuenta no disponible). El sign-out solo-grupos
    /// reintenta internamente lo que se asienta y muestra el error al agotar su presupuesto o ante un
    /// bloqueo que esperar no arregla.
    ///
    /// **El fallo de RED dejó de ser «lo que se sana esperando» el 2026-09-16**, y es lo que este eje tenía
    /// mal desde el principio: una subida que no llega no se está guardando, así que ni el texto ni los 45 s
    /// de reintentos describían nada. Hoy es `.uploadRetryLater` y se dice al momento.
    /// `CaseIterable` **no es decorado**: `GroupsSignOutRetryDecision.decide` es una cadena de `if` y no un
    /// `switch`, así que el compilador NO obliga a pronunciarse sobre un motivo nuevo — y su rama por
    /// defecto es la peor de las dos: 45 s de espera y ~22 peticiones contra algo que no se cura. La red es
    /// `GroupsSignOutRetryDecisionTests.everyReasonHasADecision`, que recorre `allCases` y se cae en cuanto
    /// aparece uno sin decidir.
    enum BlockReason: Equatable, CaseIterable {
        /// **El guardado que aún se asienta, y desde el 2026-09-16 SOLO eso.** Reintentable esperando: el tope de
        /// iteraciones con ciclos sanos (el outbox todavía drenando), un ciclo coalescido, el gate de quiescencia
        /// del import de CloudKit que agota su margen, o la cancelación del gesto.
        ///
        /// **Lo que ya NO trae es la subida que falla**, que es la mitad por la que este motivo mentía (ticket
        /// `signout-pending-copy-says-wait-seconds-when-offline`, decisión de Jürgen del 2026-09-15). Sin red,
        /// con un 5xx o con un cortafuegos delante, su texto —«un momento más, espera unos segundos»— prometía
        /// un guardado en curso que no existía, y el gesto encima gastaba 45 s de reintentos antes de decirlo.
        /// Eso vive ahora en `.uploadRetryLater`.
        ///
        /// **La separación NO la puede hacer el outcome del ciclo solo, y creer que sí fue un bug que cazó la
        /// review adversarial.** `CadenceOutcome.transient` es el cajón de todo lo pasajero —red, HTTP, decode,
        /// el `save()` LOCAL de una página del pull, el tope de páginas— y además **el veredicto del ciclo es el
        /// del PULL siempre que el push vaya bien** (`GroupsSyncClient.syncCycleOnce`). Quien la hace es un
        /// testigo del ciclo, `stoppedByFailedUpload(for:)`, que solo enciende el push (en el motor personal, también su
        /// puerta de attest: `CloudSyncRuntime.lastCycleFailedUpload`): sin él, al `save()` local
        /// de una página se le decía «tus cambios no llegaron al servidor» con la subida perfecta, y se le
        /// quitaban los 45 s que ese caso sí cura — que es H-2026-07-18-6, el que motivó el presupuesto.
        ///
        /// **Sus productores son cuatro, y tres no pasan por `classify`**: por ahí llegan el tope de iteraciones
        /// (`.completed`/`.coalesced` con filas vivas) y todo ciclo fallido sin el testigo; la quiescencia
        /// agotada, la cancelación del gesto y el corte del bucle escriben este motivo a mano en
        /// `CloudSessionSignOut`. Los cuatro son asentamiento.
        case transient
        /// NO curable sin acción del usuario: 401 sesión caída, cuenta no disponible.
        ///
        /// **`classify` ya no lo produce por un 403 del canal de Grupos** (2026-09-14): el del kill trae
        /// `.channelPaused` y el de infraestructura es `.transient`.
        ///
        /// **Y desde el 2026-09-14 el cierre en la NUBE tampoco lo fabrica aplanando** (ticket
        /// `cloud-signout-collapses-every-groups-transient-into-permanent`, cerrado): el paso 2 de
        /// `CloudSessionSignOut.performCloudSecureSignOut` tenía un ternario que colapsaba aquí todo
        /// veredicto de grupos que no fuera `.channelPaused`, y hoy traduce con
        /// `cloudSignOutGroupsBlockReason`. Desde el 2026-09-16 ese productor ya recibe lo pasajero separado en
        /// sus dos mitades y solo conserva lo que le llega: la subida fallida como `.uploadRetryLater` y el
        /// outbox que drena como `.transient`.
        ///
        /// **Y desde el 2026-09-15 la sesión caducada tampoco se colapsa aquí**: el paso 2 la deja pasar tal
        /// cual (decisión 3A de Jürgen, ticket `cloud-signout-collapses-a-groups-session-expiry-into-permanent`).
        ///
        /// **Y desde el 2026-09-25 el paso 1 —el push-all PERSONAL, que corre ANTES— tampoco** (ticket
        /// `cloud-signout-collapses-the-personal-push-all-reason-into-permanent`): la subida que no llegó, la sesión caducada y
        /// el guardado que se asienta viajan con su motivo (`personalPushAllShownReason`). Aquí solo llega ya lo que de verdad
        /// no se puede nombrar mejor: la cuenta no disponible, o no tener motor.
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
        ///
        /// **Desde el 2026-09-15 lo enseñan las cuatro celdas del cierre**, la nube incluida
        /// (`cloudSignOutGroupsBlockReason`).
        ///
        /// **Y desde ese mismo día ya no le llega a quien solo está sin conexión.** Con el token caducado y sin
        /// red, el SDK conserva la sesión y el canal de Grupos lo lee como pasajero
        /// (`GroupsSyncClient.sdkRemovedTheSession`). Aquí entra la sesión que el SDK borró, o un 401
        /// `yala_attest_invalid` que el refresh no rescata con la sesión guardada: el servidor rechaza un token que el
        /// SDK da por bueno. Ticket `groups-push-reads-an-offline-token-refresh-as-a-session-expiry`.
        ///
        /// **Ni a quien tiene la sesión buena y le falta App Attest.** Con `yala_attest_required` el JWT verificó, así
        /// que el canal lo lee pasajero y el cierre enseña el aviso de lo pasajero
        /// (`GatewayErrorEnvelope.isAttestRequired`, ticket `groups-sync-reads-a-missing-attest-401-as-a-session-expiry`).
        ///
        /// Lo que su aviso todavía no resuelve, leído en el código sin ejecutar: **en la nube, «vuelve a iniciar
        /// sesión» no dice dónde.** Si el SDK borró la sesión, la única puerta encontrada es «Nuevo grupo» en la
        /// pestaña Grupos; si sigue guardada —ese 401—, no hay ninguna. Ticket
        /// `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door`.
        case sessionExpired
        /// **No se pudo mirar el puente personal al desasociar** (`GroupsAssociationDetach.detachBridge`
        /// devolvió `nil`): su fetch lanzó, o su `save()` no entró. Va aparte porque el aviso de siempre
        /// —«quedan cambios de tus grupos sin subir, inténtalo en un momento»— describe un problema que
        /// no es y da un consejo que no arregla nada: no hay nada sin subir (se llega aquí con el
        /// push-all ya drenado y `pendingCount == 0`) y esperar no cambia que el store no responda.
        /// Review adversarial del 2026-09-11.
        ///
        /// **Desde el 2026-10-02 lo pone también el store personal que no se quedó quieto** a tiempo para el `save()`
        /// del puente (`CloudSessionSignOut.writeDetachUnderQuiescence`, ticket
        /// `detach-saves-the-personal-graph-outside-the-quiescence-window`). Ahí esperar SÍ lo arregla —el import
        /// termina—, y el aviso sigue siendo verdad entero: no habla de esperar, dice que los movimientos del Panel no
        /// se revisaron, que no se soltó nada y que se vuelva a intentar.
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
        /// **La subida de grupos NO llegó al servidor, y esperar dentro del gesto no lo arregla** (2026-09-14): un
        /// corte de red, un 5xx, un decode fallido de la respuesta, o el 403 de un cortafuegos.
        ///
        /// **Desde el 2026-09-16 lo producen los CUATRO caminos del cierre, no solo la nube** (ticket
        /// `signout-pending-copy-says-wait-seconds-when-offline`, decisión de Jürgen del 2026-09-15). Nació como
        /// traducción del paso 2 del cierre en la nube (`cloudSignOutGroupsBlockReason`), pero la causa que
        /// describe no era exclusiva de ahí: el cierre solo-grupos, el desasociar y la puerta del Welcome la
        /// tenían mezclada dentro de `.transient` y por eso le decían «un momento más» a quien estaba sin
        /// conexión. Hoy lo emite `classify` cuando el ciclo paró **habiendo chocado con el servidor EMPUJANDO**
        /// (`GroupsSyncClient.stoppedByFailedUpload(for:)`), y lo ven los cuatro. Lo que decide no es que el
        /// ciclo fallara —eso incluye fallos de este teléfono y del pull— sino QUIÉN falló.
        ///
        /// Va aparte de `.transient` porque el consejo que toca **no es el mismo**. `.transient` es el outbox que
        /// todavía drena: se cura esperando unos segundos y volviendo a pulsar. Aquí lo que falló es una SUBIDA,
        /// no un guardado, y «espera unos segundos» sería falso ante un WAF que estará ahí diez minutos o ante un
        /// teléfono sin cobertura. El aviso dice lo único cierto: no se pudo subir, no se pierde nada, y se
        /// vuelve a intentar en un rato.
        ///
        /// **Y por eso el aviso sale AL MOMENTO también en los caminos que sí tienen retry.**
        /// `GroupsSignOutRetryDecision.decide` ya lo listaba entre los que no se reintentan, así que al nacer el
        /// segundo productor el cierre solo-grupos dejó de gastar 45 s —unas 22 peticiones— contra una red que no
        /// está. Es la misma decisión que Jürgen tomó para `.channelPaused` el 2026-09-13 y para este motivo el
        /// 2026-09-14, y es lo que retira el «Guardando tus cambios pendientes…» que se veía tres cuartos de
        /// minuto sin que se guardara nada. El gesto sigue siendo reintentable: no se ha escrito nada.
        ///
        /// Va aparte de `.permanent` porque ahí estaba el bug: hasta el 2026-09-14 el paso 2 colapsaba todo
        /// veredicto de grupos que no fuera `.channelPaused`, así que un 5xx o un cortafuegos salían como
        /// «revisa tu conexión» —mandando a buscar un fallo que no existe— y sin nombrar lo único que ayuda,
        /// que es esperar. Ticket `cloud-signout-collapses-every-groups-transient-into-permanent`.
        ///
        /// **En la NUBE, si lo trae el motor PERSONAL, el paso 1 lo traduce a `.personalUploadRetryLater`** (2026-09-25):
        /// el hecho es el mismo, pero este texto habla de tus grupos. Desde ese día el motor personal también tiene el
        /// testigo (`CloudSyncRuntime.stoppedByFailedUpload(for:)`).
        ///
        /// **Quién lo pinta, medido el 2026-09-16 con los cuatro caminos produciéndolo.** Ajustes y la hoja del
        /// cambio de Apple ID ya lo enseñaban por el camino de la nube, con el título genérico —«No pudimos
        /// cerrar tu sesión», exacto: el cierre no se completó— y el mensaje de la subida (`SignOutBlockedCopy`).
        /// El desasociar y la puerta de Grupos del Welcome lo estrenan aquí, y a los dos había que abrirles
        /// rama: el desasociar lo tenía agrupado con `.transient` en el texto que no afirma causa, y la puerta
        /// del Welcome lo habría dejado caer en su catch-all, que dice «vuelve y entra con esa cuenta» — el
        /// consejo equivocado, porque volver a entrar no arregla una red que no está. Ese catch-all lo
        /// anticipaba la versión anterior de este mismo docblock.
        case uploadRetryLater
        /// **Este teléfono lleva más de un día sin conseguir App Attest y quedan cambios de grupos sin subir**
        /// (2026-09-15, ticket `groups-phone-that-never-attests-is-told-to-retry-forever`). El servidor rechaza la
        /// subida con 401 `yala_attest_required` —la sesión vale, falta el attest— y la racha ya es terminal
        /// (`GroupsAttestVerdictLogic`: 24 h y 3 rechazos sin un solo acierto).
        ///
        /// Va aparte de `.transient` porque «un momento más» deja de ser verdad para quien lo oye desde ayer, y aparte
        /// de `.permanent` porque su texto manda a revisar una conexión que funciona. Lo produce `classify`, y solo con
        /// el testigo del ciclo: una racha vieja no puede disfrazar un fallo de hoy que es otra cosa.
        ///
        /// **Es el único bloqueo de Grupos con una salida que pierde los cambios, y es una excepción ACOTADA** a «nunca
        /// descarta» (decisión de Jürgen, 2026-09-15). La ofrecen los cierres de sesión
        /// (`CloudSessionSignOut.exitDiscardingUnsyncedGroups`), con un aviso cuyo botón nombra la pérdida. El
        /// desasociar comparte el motivo y no ofrece ninguna salida.
        ///
        /// **En la nube, si lo trae el motor PERSONAL, el paso 1 del cierre lo traduce a `.personalAttestUnavailable`**
        /// (2026-09-15): `classify` no sabe de qué outbox viene, y el aviso de tus datos es otro.
        case attestUnavailable
        /// **Este teléfono lleva más de un día sin conseguir App Attest y quedan cambios PERSONALES sin subir a la cuenta en
        /// la nube** (2026-09-15, ticket `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`). El motor
        /// personal corta en su puerta de attest antes de subir nada, así que esos cambios no están en ninguna otra parte.
        ///
        /// Lo produce SOLO el paso 1 del cierre en la nube (`CloudSessionSignOut.performCloudSecureSignOut`), traduciendo el
        /// `.attestUnavailable` que `classify` devuelve con el testigo del motor personal
        /// (`CloudSyncRuntime.stoppedByUnavailableAttest(for:)`). Va aparte de `.attestUnavailable` porque su aviso habla de
        /// tus datos y no de tus grupos, y ofrece otra cosa.
        ///
        /// **Su aviso ofrece exportar los movimientos y cerrar sesión perdiendo esos cambios** (decisión de Jürgen,
        /// 2026-09-15): la excepción a «jamás descartar» del cierre en la nube, acotada a este motivo y, desde el 2026-09-28,
        /// a `.cloudSessionExpired` (`personalLossCause`, `CloudSessionSignOut.exitDiscardingUnsyncedPersonalChanges`). En
        /// las demás pantallas es inerte: ninguna otra corre el cierre en la nube.
        case personalAttestUnavailable
        /// **La sincronización con la nube está parada a propósito porque no se pudo leer en qué punto va el paso de los
        /// datos** (el journal de la migración es ilegible), y quedan cambios personales sin subir (ticket
        /// `cloud-signout-with-the-engine-stopped-says-check-your-connection`, 2026-09-25). El cierre bloquea sin descartar,
        /// como con cualquier pendiente.
        ///
        /// Va aparte de `.permanent` porque aquel aviso dice «revisa tu conexión», y la conexión no tiene nada que ver.
        /// **El texto no afirma la causa**, porque el código no la conoce: `.unreadable` es un `fetch` que lanzó, y puede
        /// ser una versión anterior que no entiende el registro o un fallo pasajero del store. Así que dice primero lo que
        /// dice la tarjeta de Almacenamiento para el mismo journal —cerrar y abrir Yala, que además cura el relanzamiento de
        /// ida pendiente— y después actualizarla. Lo produce SOLO el push-all personal con el candado cerrado
        /// (`engineStoppedReason(read:)`).
        case syncStoppedNeedsUpdate
        /// **La sincronización con la nube está parada a propósito porque el paso de los datos entre la nube e iCloud no
        /// terminó** —una fase en vuelo, una vuelta a iCloud que falló o quedó a medias, el espejo de iCloud aún montado—, y
        /// quedan cambios personales sin subir (mismo ticket que `.syncStoppedNeedsUpdate`). La salida está en «Dónde viven
        /// tus datos»: «Reintentar» si falló, o terminar lo que ahí se pida. Lo produce SOLO el push-all personal con el
        /// candado del motor cerrado y una fase legible y NO estable (`engineStoppedReason(read:)`). En esas fases la pantalla
        /// enseña progreso, el fallo con «Reintentar» o el relanzamiento.
        case syncStoppedMidMigration
        /// **La sincronización con la nube está parada a propósito con el paso de los datos TERMINADO** (fase estable `done`
        /// o `notStarted`), y quedan cambios personales sin subir. El candado se cierra ahí por el espejo de iCloud todavía
        /// montado —el par de modo a medio escribir, o el store montado con espejo en un proceso que ya es nube—, y
        /// «Dónde viven tus datos» enseña la nube activa: no hay nada que terminar, y su único botón es «Volver a iCloud»
        /// (review adversarial del 2026-09-25, dos lentes). Lo que lo cura es reabrir la app. Mismo ticket que los dos de
        /// arriba.
        case syncStoppedNeedsRelaunch
        /// **La subida de tus cambios PERSONALES a la nube no llegó al servidor** —sin red, un 5xx, una respuesta ilegible—,
        /// y el cierre en la nube bloquea sin borrar nada (ticket `cloud-signout-collapses-the-personal-push-all-reason-into-permanent`,
        /// 2026-09-25). Es `.uploadRetryLater` dicho de tus datos y no de tus grupos: lo produce SOLO el paso 1 del cierre en
        /// la nube, traduciendo el `.uploadRetryLater` que `classify` devuelve con el testigo del motor personal
        /// (`CloudSyncRuntime.stoppedByFailedUpload(for:)`).
        ///
        /// Hasta ese día este caso salía como `.permanent` —«revisa tu conexión»— a quien tenía la conexión bien y el
        /// servidor fallando, y sin decir lo único cierto: no se pierde nada y se vuelve a intentar en un rato. Va al final del
        /// `enum` para no mover el orden de los que ya existían.
        case personalUploadRetryLater
        /// **La sesión en la nube caducó y quedan cambios sin subir —tuyos o de tus grupos—** (2026-09-25, ticket
        /// `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door`). Es `.sessionExpired` dicho donde la puerta
        /// existe: lo producen SOLO los pasos 1 y 2 del cierre en la nube (`personalPushAllShownReason` y
        /// `cloudSignOutGroupsBlockReason`), y su aviso nombra «Dónde viven tus datos» y su «Iniciar sesión».
        ///
        /// Va aparte de `.sessionExpired` porque ése lo enseñan también las celdas PRIVADAS del cierre, y ahí la puerta es
        /// otra: «vuelve a iniciar sesión» sin decir dónde era todo lo que se podía decir con un solo texto. En la nube la
        /// puerta es la tarjeta de sincronización de Almacenamiento, que desde el mismo día cuenta también las filas de
        /// grupos (`SyncSignInBannerLogic`) y que el cierre deja encendida al bloquear (`CloudSyncRuntime.stopUntilSignIn`).
        /// Al final del `enum` para no mover el orden de los que ya existían.
        ///
        /// **Con cambios PERSONALES, desde el 2026-09-28 abre también su salida** (ticket
        /// `cloud-sign-out-with-an-expired-session-and-personal-changes-has-no-exit`): el aviso cuenta los movimientos que se
        /// perderían, dice cómo subirlos volviendo a entrar, ofrece exportarlos y, solo si la persona lo elige, cerrar sesión
        /// perdiéndolos (`personalLossCause`). Con cambios de grupos, la suya desde el mismo día (`lossCause`).
        case cloudSessionExpired
        /// **El desasociar cerró la sesión en la nube y la sesión SIGUE guardada** (ticket
        /// `detach-does-not-verify-the-cloud-session-actually-closed`): el llavero no la borró, o un refresco del token en
        /// vuelo la repuso (`CloudAuthService.signOut()` devuelve `false`). El gesto se para ANTES del punto de no retorno,
        /// así que no se soltó nada y reintentar es el gesto entero. Solo lo pone el desasociar. Va aparte porque ningún
        /// otro texto es verdad aquí: no queda nada sin subir (`pendingCount == 0`) y el puente ni se ha mirado. Al final del
        /// `enum` por lo mismo que el anterior.
        case sessionNotClosed
        /// **Un CIERRE DE SESIÓN soltó la sesión en la nube y la sesión SIGUE guardada** (ticket
        /// `sign-out-exits-do-not-verify-the-cloud-session-closed`, 2026-09-26). Es `.sessionNotClosed` dicho del cierre y no
        /// del desasociar: los cuatro cierres que arman el borrado se paran ANTES del arm, así que no se ha borrado nada y
        /// reintentar es el gesto entero. Sin esa parada el teléfono quedaba como recién instalado con la sesión de quien
        /// cerró dentro, y la siguiente persona bajaba sus grupos.
        ///
        /// Va aparte por dos razones medidas: Ajustes silencia `.sessionNotClosed` porque es del desasociar (el cierre se
        /// quedaría mudo), y el mensaje genérico dice «hay cambios sin subir, revisa tu conexión», que aquí es falso. Al
        /// final del `enum` por lo mismo que los anteriores.
        case signOutSessionSurvived
        /// **El cierre de una sesión PRIVADA se paró porque el paso de los datos entre iCloud y la nube no está en reposo**
        /// (ticket `private-sign-out-proceeds-with-a-migration-in-flight`, 2026-09-27): una ida o una vuelta en marcha, un
        /// relanzamiento pendiente, un fallo que espera «Reintentar», o el controller trabajando. Cerrar ahí borra lo local
        /// mientras sube. Lo pone solo `CloudSessionSignOut`, antes de escribir nada o pegado al arm, así que no se ha
        /// borrado nada y reintentar es el gesto entero. Su aviso manda a «Dónde viven tus datos», que con la migración
        /// fuera de reposo se ve (`StorageRowGateLogic.isEngaged`). Al final del `enum` por lo mismo que los anteriores.
        case migrationInFlight
        /// **Lo mismo, pero lo único que se sabe es que el journal de la migración no se pudo leer.** Va aparte porque la
        /// fila de «Dónde viven tus datos» NO se enciende con `.journalUnreadable` (medido en `StorageRowGateLogic.isEngaged`),
        /// así que mandar allí sería mandar a una pantalla que puede no existir. Su texto dice lo que cura la lectura en este
        /// proceso —cerrar y abrir Yala— y, si sigue, actualizarla, como el motor parado del cierre en la nube.
        case migrationUnreadable
        /// **Quedan cambios de grupos que la sesión abierta no puede subir porque no son suyos**: los apuntó otra cuenta en
        /// este teléfono —su sesión caducó y entró otra—, o no hay prueba de quién los apuntó (ticket
        /// `groups-outbox-rows-without-a-live-session-have-no-exit`, 2026-09-28). Desde ese día cada fila del outbox lleva
        /// su dueño y la subida solo manda las de la sesión, así que esperar no los sube nunca: los sube su cuenta, o se
        /// pierden con el aviso que los cuenta.
        ///
        /// Lo produce SOLO el push-all del cierre (`CloudSessionSignOut.pushAllPendingGroupsForSignOut`), cuando lo único
        /// que queda son filas ajenas. Va aparte de `.sessionExpired` porque aquí la sesión SÍ está viva —«tu sesión
        /// caducó» sería falso— y de `.permanent` porque no hay nada que revisar. Como la sesión caducada, **abre la salida
        /// que los pierde** en los cierres y en «Empezar de cero» (`lossCause`, `freshStartOffersGroupsLossExit`); el
        /// desasociar no la ofrece, como con el attest. Al final del `enum` por lo mismo que los anteriores.
        case groupsChangesFromAnotherAccount
        /// **Este teléfono no consigue preparar para subir algunos cambios PERSONALES: el drain no termina en ninguna vuelta**
        /// (ticket `personal-drain-that-always-aborts-blocks-cloud-sign-out-with-a-wait-a-moment-copy`, decisión A de Jürgen del
        /// 2026-10-04). Un `save` del outbox que falla siempre, un reloj por unidad o un testigo del relevo que no se dejan
        /// leer, o una traducción que se corta en cada vuelta: el cambio se queda en el History y no llega nunca al outbox.
        ///
        /// Va aparte de `.transient` porque «espera unos segundos» no es verdad: esperar no lo arregla. Y aparte de
        /// `.personalUploadRetryLater` porque la subida no tiene nada que ver: el fallo es de este teléfono. Su texto dice que
        /// no se pierde nada y lo único que puede curarlo —cerrar y abrir Yala, y si sigue, actualizarla—, sin prometer plazo.
        ///
        /// Lo produce SOLO el push-all del cierre en la nube (`personalVerdictAfterProbe`), con el testigo del ciclo
        /// (`CloudSyncRuntime.stoppedWithUnfinishedCapture(for:)`) y la sonda del History. **No abre salida de pérdida**: en un
        /// teléfono que atesta y con sesión, el camino es el de arriba. El teléfono sin App Attest y la sesión caducada con el
        /// drain atascado conservan su propio motivo, con su salida. Al final del `enum` por lo mismo que los anteriores.
        case personalCaptureUnfinished
        /// **Este teléfono no consigue preparar para subir algunos cambios de GRUPOS: el drain no termina en ninguna vuelta, y
        /// nada de lo que queda fuera abre la salida que los pierde** (ticket
        /// `groups-stuck-drain-on-a-healthy-phone-says-try-again-later`, opción A de Jürgen del 2026-10-05). Es
        /// `.personalCaptureUnfinished` dicho de tus grupos: el teléfono tiene App Attest, la sesión vale y lo de fuera es
        /// suyo, así que lo único que impide subir es este teléfono.
        ///
        /// Va aparte de `.uploadRetryLater` porque aquel texto —«no llegaron al servidor, inténtalo en un rato»— promete que
        /// esperar lo cura, y no lo cura: la subida no tiene nada que ver. Su texto dice que no se pierde nada y lo único que
        /// puede curarlo —cerrar y abrir Yala, y si sigue, actualizarla—, sin plazo.
        ///
        /// Lo produce SOLO el push-all de grupos con la captura atascada (`stuckCaptureVerdict`), así que llega a los tres
        /// gestos que lo comparten: los cierres de sesión, el desasociar y «Empezar de cero». **No abre salida de pérdida**
        /// (decisión A: un teléfono con attest y sesión no la tiene). El teléfono sin App Attest, la sesión caducada y los
        /// cambios de otra cuenta conservan su propio motivo, con su salida. Al final del `enum` por lo mismo que los
        /// anteriores.
        case groupsCaptureUnfinished

        /// Slug corto para los logs (`CloudSyncBreadcrumb.signOutGroupsBlocked`). Va aquí y no en el
        /// emisor para que un motivo nuevo tenga que nombrarse una sola vez: el `switch` es exhaustivo.
        var breadcrumbSlug: String {
            switch self {
            case .transient: return "transient"
            case .permanent: return "permanent"
            case .exportUnconfirmed: return "export-unconfirmed"
            case .sessionExpired: return "session-expired"
            case .bridgeUnreadable: return "bridge-unreadable"
            case .detachBusy: return "detach-busy"
            case .channelPaused: return "channel-paused"
            case .uploadRetryLater: return "upload-retry-later"
            case .attestUnavailable: return "attest-unavailable"
            case .personalAttestUnavailable: return "personal-attest-unavailable"
            case .syncStoppedNeedsUpdate: return "sync-stopped-needs-update"
            case .syncStoppedMidMigration: return "sync-stopped-mid-migration"
            case .syncStoppedNeedsRelaunch: return "sync-stopped-needs-relaunch"
            case .personalUploadRetryLater: return "personal-upload-retry-later"
            case .cloudSessionExpired: return "cloud-session-expired"
            case .sessionNotClosed: return "session-not-closed"
            case .signOutSessionSurvived: return "sign-out-session-survived"
            case .migrationInFlight: return "migration-in-flight"
            case .migrationUnreadable: return "migration-unreadable"
            case .groupsChangesFromAnotherAccount: return "groups-changes-from-another-account"
            case .personalCaptureUnfinished: return "personal-capture-unfinished"
            case .groupsCaptureUnfinished: return "groups-capture-unfinished"
            }
        }
    }

    /// **¿Se para el cierre de la sesión privada porque el paso de los datos entre iCloud y la nube no está en reposo?**
    /// `nil` = sigue. Ticket `private-sign-out-proceeds-with-a-migration-in-flight` (2026-09-27).
    ///
    /// **La decisión es la del predicado compartido y nada más**: devuelve `nil` exactamente cuando
    /// `AppleIDChangeCloseLogic.migrationAtRest` dice reposo. Lo que se añade aquí es solo QUÉ texto toca.
    ///
    /// - **Vale para las tres celdas que borran por archivos, solo-grupos incluida.** La primera versión la excluía («su
    ///   store es el neutro vacío») y la review lo midió falso: nada impide migrar desde una sesión solo-grupos —la fila de
    ///   Almacenamiento y «Migrar a la nube» no miran la marca del eje—, y su cierre espera al export justo porque en una
    ///   instalación antigua ese store puede espejar datos reales. `kind` se queda en la firma para que la decisión por
    ///   celda, si algún día hace falta, tenga dónde vivir.
    /// - `.migrationUnreadable` solo cuando nadie sabe más que «el journal no se lee»: ni el controller trabaja ni enseña
    ///   otro estado. Si el controller sabe algo, manda él: su estado es el que pinta la pantalla a la que se envía.
    static func migrationBlockReason(kind: ExitKind, reading: MigrationRestReading) -> BlockReason? {
        guard !AppleIDChangeCloseLogic.migrationAtRest(reading) else { return nil }
        if reading.controllerIsWorking { return .migrationInFlight }
        let state: CloudMigrationUIState
        if let controllerState = reading.controllerState, controllerState != .idle {
            state = controllerState
        } else {
            state = CloudMigrationUIStateDeriver.derive(
                storageMode: reading.persistedStorageMode, read: reading.journalRead,
                mirrorOffArmed: reading.mirrorOffArmed, mountedDecision: reading.mountedDecision)
        }
        return state == .journalUnreadable ? .migrationUnreadable : .migrationInFlight
    }

    /// Traduce el veredicto del push-all de GRUPOS al motivo que el cierre en la NUBE enseña
    /// (`CloudSessionSignOut.performCloudSecureSignOut`, paso 2).
    ///
    /// **Es un `switch` exhaustivo y no un ternario, y esa es la mitad del arreglo.** Lo que había aquí
    /// —`reason == .channelPaused ? .channelPaused : .permanent`— no obligaba a nadie a pronunciarse: cada
    /// motivo nuevo del canal de Grupos caía en `.permanent` en silencio, que es como un corte de red, un
    /// 5xx y un cortafuegos acabaron los tres diciéndole a la persona que revisara una conexión que
    /// funciona. Con un `switch` sin `default`, el compilador no deja añadir un motivo sin decidir qué se
    /// enseña aquí.
    ///
    /// **La sesión caducada viaja tal cual desde el 2026-09-15**, como en las otras tres celdas del cierre.
    /// Hasta entonces salía como `.permanent`, o sea «revisa tu conexión», a quien tenía la conexión bien y
    /// lo que necesitaba era volver a entrar con su cuenta: es lo único que sube esos cambios. Quedaba por
    /// decidir si a alguien que acaba de pedir cerrar sesión se le dice «vuelve a iniciar sesión», y Jürgen
    /// dijo que sí (opción 1 del ticket `cloud-signout-collapses-a-groups-session-expiry-into-permanent`).
    /// Lo que ese aviso todavía no distingue está medido en el docblock de `.sessionExpired`.
    ///
    /// **Desde el 2026-09-16 este productor casi no traduce, y esa es la señal de que el arreglo fue río
    /// arriba.** `classify` ya emite seis de los diez motivos con la causa separada, así que aquí los seis
    /// viajan tal cual; lo que queda es el catch-all de los cuatro que `classify` no puede emitir, que caen en
    /// `.permanent` — el aviso que no afirma ninguna causa concreta.
    static func cloudSignOutGroupsBlockReason(_ reason: BlockReason) -> BlockReason {
        switch reason {
        // **Desde el 2026-09-16, lo pasajero llega ya separado y esta línea se invierte.** Hasta entonces
        // `.transient` era el cajón de las dos causas y este productor lo mandaba entero a `.uploadRetryLater`,
        // que era lo más honesto que se podía decir sin saber cuál de las dos era. Hoy `classify` ya manda aquí
        // la subida fallida con su propio motivo, así que el `.transient` que queda es SOLO el outbox que aún
        // drena —el tope de iteraciones con ciclos sanos—, y para ése «espera unos segundos y vuelve a
        // intentarlo» es exacto: lo cura esperando y volviendo a pulsar, con retry interno o sin él.
        case .transient: return .transient
        // El kill-switch de Grupos viaja tal cual desde el 2026-09-13 y aquí no se toca.
        case .channelPaused: return .channelPaused
        // La subida que no llegó, tal cual. Hasta el 2026-09-16 esto era solo idempotencia —el motivo nacía
        // aquí y no entraba nunca—; hoy `classify` lo emite y ésta es la rama por la que pasa de verdad.
        case .uploadRetryLater: return .uploadRetryLater
        // La sesión caducada, tal cual (decisión 3A de Jürgen, 2026-09-15): su aviso pide volver a entrar, que es
        // lo único que sube estos cambios. Colapsada en `.permanent` le decía «revisa tu conexión».
        //
        // **Desde el 2026-09-25 viaja como `.cloudSessionExpired`**, que nombra la puerta: en la nube se vuelve a entrar
        // desde «Dónde viven tus datos» (ticket `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door`). Hasta
        // ese día el aviso decía «vuelve a iniciar sesión» y, con solo cambios de grupos, no había dónde.
        case .sessionExpired, .cloudSessionExpired: return .cloudSessionExpired
        // El teléfono sin App Attest, tal cual (2026-09-15): su aviso es el que ofrece salir perdiendo los cambios de
        // grupos. Traducido a `.uploadRetryLater` volvería a decir «inténtalo en un rato» a quien lleva un día sin poder.
        case .attestUnavailable: return .attestUnavailable
        // Los cambios de otra cuenta, tal cual (2026-09-28): la sesión de la nube está viva, así que ni «tu sesión caducó»
        // ni «revisa tu conexión» son verdad. Su aviso ofrece perderlos.
        case .groupsChangesFromAnotherAccount: return .groupsChangesFromAnotherAccount
        // El drain de grupos que no termina, tal cual (2026-10-05): colapsado en `.permanent` diría «revisa tu conexión» a
        // quien tiene la conexión bien y un drain que esperar no cura.
        case .groupsCaptureUnfinished: return .groupsCaptureUnfinished
        case .permanent: return .permanent
        // `.personalAttestUnavailable` es del paso 1, sobre el outbox PERSONAL: este productor, que traduce el de grupos, no
        // lo recibe nunca.
        case .exportUnconfirmed, .bridgeUnreadable, .detachBusy, .personalAttestUnavailable, .sessionNotClosed,
             .signOutSessionSurvived: return .permanent
        // Los del motor parado y la subida personal que no llegó son del paso 1, sobre el outbox PERSONAL: este productor no
        // los recibe nunca.
        case .syncStoppedNeedsUpdate, .syncStoppedMidMigration, .syncStoppedNeedsRelaunch, .personalUploadRetryLater,
             .personalCaptureUnfinished:
            return .permanent
        // Los de la migración los pone solo el cierre PRIVADO, antes del push-all o pegados al arm: este productor, que es
        // de la nube, no los recibe nunca (2026-09-27).
        case .migrationInFlight, .migrationUnreadable:
            return .permanent
        }
    }

    /// El motivo que el cierre en la NUBE enseña cuando su paso 1 —el push-all PERSONAL— bloquea por algo que no es el
    /// teléfono sin App Attest (ese lo traduce el propio paso a `.personalAttestUnavailable`, con su oferta).
    ///
    /// **Hasta el 2026-09-25 todo lo que no fuera el motor parado se colapsaba aquí en `.permanent`** —«revisa tu conexión»—,
    /// también un 5xx y una sesión caducada (ticket `cloud-signout-collapses-the-personal-push-all-reason-into-permanent`).
    /// Hoy es la gemela de `cloudSignOutGroupsBlockReason` para el motor personal, con la misma decisión que Jürgen tomó
    /// para grupos el 2026-09-14/15:
    ///  · **la subida que no llegó** pasa a `.personalUploadRetryLater`: el mismo hecho que `.uploadRetryLater`, dicho de tus
    ///    datos. Llega separada porque el motor personal ya tiene su testigo (`CloudSyncRuntime.stoppedByFailedUpload(for:)`).
    ///  · **la sesión caducada**, tal cual: su aviso pide volver a entrar, que es lo único que sube esos cambios.
    ///  · **el guardado que se asienta** (`.transient`, sin el testigo), tal cual: «un momento más» es exacto para el tope
    ///    de iteraciones con el outbox aún drenando, y para el que se agota con ciclos `.coalesced` —un ciclo de la
    ///    cadencia en vuelo que el cierre no puede adelantar—. Un fallo local del ciclo (el `fetch` del outbox) también
    ///    cae aquí: es de este teléfono y no del servidor.
    ///  · **los tres del motor parado**, tal cual (ticket `cloud-signout-with-the-engine-stopped-says-check-your-connection`).
    ///  · **`.permanent`** —la cuenta no disponible— se queda donde está: es el texto que no afirma ninguna causa.
    ///
    /// El teléfono sin App Attest no pasa por aquí: `personalUploadBlockDecision` lo traduce a `.personalAttestUnavailable`,
    /// con su oferta. Lo que el motor personal no puede emitir cae en `.permanent`. `switch` exhaustivo para que un motivo nuevo
    /// tenga que decidir si viaja.
    static func personalPushAllShownReason(_ reason: BlockReason) -> BlockReason {
        switch reason {
        case .uploadRetryLater, .personalUploadRetryLater: return .personalUploadRetryLater
        // Con el texto que nombra la puerta (2026-09-25): la misma que la de grupos, porque «Iniciar sesión» en «Dónde viven
        // tus datos» reanuda el motor y sube las dos colas.
        case .sessionExpired, .cloudSessionExpired: return .cloudSessionExpired
        case .transient: return .transient
        case .syncStoppedNeedsUpdate: return .syncStoppedNeedsUpdate
        case .syncStoppedMidMigration: return .syncStoppedMidMigration
        case .syncStoppedNeedsRelaunch: return .syncStoppedNeedsRelaunch
        // El drain que no termina, tal cual (2026-10-05): su texto no promete segundos y no culpa a la conexión.
        case .personalCaptureUnfinished: return .personalCaptureUnfinished
        case .permanent, .exportUnconfirmed, .bridgeUnreadable, .detachBusy, .channelPaused, .attestUnavailable,
             .personalAttestUnavailable, .sessionNotClosed, .signOutSessionSurvived, .migrationInFlight, .migrationUnreadable,
             .groupsChangesFromAnotherAccount, .groupsCaptureUnfinished:
            return .permanent
        }
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
    ///
    /// `attestUnavailable` es la otra mitad que `CadenceOutcome` no lleva (2026-09-15): **si el ciclo paró porque este
    /// teléfono lleva más de un día sin App Attest**. En Grupos lo contesta `GroupsSyncClient.stoppedByUnavailableAttest(for:)`
    /// con el 401 de un `.transient`; en el motor personal, `CloudSyncRuntime.stoppedByUnavailableAttest(for:)` con su puerta
    /// de attest, que devuelve `.transient` mientras reintenta y `.accountUnavailable` cuando la da por terminal. Los dos
    /// exigen el testigo del ciclo además de la racha. Sin valor por defecto, por lo mismo que `channelKilled`.
    ///
    /// **Cuenta con `.transient` y con un `.accountUnavailable` que no sea el kill**; con cualquier otro outcome se ignora. El
    /// kill gana: su testigo solo existe en Grupos, y el testigo del attest de Grupos no sale con `.accountUnavailable`, así
    /// que esa rama solo la alcanza el motor personal (ticket
    /// `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`).
    /// `uploadFailed` es la tercera mitad que `CadenceOutcome` no lleva (2026-09-16): **si el ciclo chocó con el
    /// servidor EMPUJANDO**. Lo contesta `GroupsSyncClient.stoppedByFailedUpload(for:)`, y hace falta porque
    /// `.transient` nunca fue «la subida falló» — es el cajón de red, HTTP, decode, el `save()` LOCAL de una página
    /// del pull y el tope de páginas, y **el veredicto del ciclo es el del PULL siempre que el push vaya bien**
    /// (`GroupsSyncClient.syncCycleOnce`). Sin el testigo, a quien no le entraba un save local se le decía que sus
    /// cambios no habían llegado al servidor, con la subida perfecta y sin los 45 s de reintentos que ese caso sí
    /// cura — y ése es literalmente H-2026-07-18-6, el que motivó el presupuesto. Lo cazó la review adversarial.
    ///
    /// **Cuenta solo con `.transient`**, como el del attest; y va DESPUÉS de él, porque un teléfono que lleva un día
    /// sin App Attest tiene su propio aviso y no es un problema de subida. Sin valor por defecto, por lo mismo que
    /// los otros dos: quien no tenga la señal la escribe `false` y lo dice. Desde el 2026-09-25 el motor personal la tiene
    /// (`CloudSyncRuntime.stoppedByFailedUpload(for:)`).
    static func classify(_ outcome: SyncCadencePolicy.CadenceOutcome,
                         channelKilled: Bool,
                         attestUnavailable: Bool,
                         uploadFailed: Bool) -> BlockReason {
        switch outcome {
        case .sessionExpired: return .sessionExpired
        case .accountUnavailable:
            if channelKilled { return .channelPaused }
            return attestUnavailable ? .attestUnavailable : .permanent
        // **Las dos mitades de lo pasajero, separadas desde el 2026-09-16** (ticket
        // `signout-pending-copy-says-wait-seconds-when-offline`, decisión de Jürgen del 2026-09-15). La subida que
        // chocó con el servidor —sin red, un 5xx, el 403 de un cortafuegos— es `.uploadRetryLater`: ahí «espera unos
        // segundos» era falso (no se estaba guardando nada) y volver a pulsar costaba otros 45 s de lo mismo.
        //
        // **Todo lo demás se queda en `.transient`, y esa asimetría es el arreglo, no un descuido.** El testigo lo
        // enciende el push y solo el push (y en el motor personal su puerta de attest, que no sube sin el pase del
        // servidor), así que sin él aquí caen el `save()` local de una página que no entra, el
        // tope de páginas del pull, el `fetch` del outbox y la fila poison — cosas de este teléfono, para las que
        // «un momento más» es lo honesto y los 45 s de reintentos son justo lo que hace que el gesto termine solo.
        //
        // **El attest gana a los dos**: con la racha terminal el bloqueo tiene su propio aviso, que no habla ni de
        // guardar ni de la red.
        case .transient:
            if attestUnavailable { return .attestUnavailable }
            return uploadFailed ? .uploadRetryLater : .transient
        // El ciclo fue BIEN y quedan filas: el tope de iteraciones con el outbox aún drenando.
        case .completed, .coalesced: return .transient
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
        attestUnavailable: Bool,
        uploadFailed: Bool,
        iteration: Int,
        maxIterations: Int
    ) -> PushAllVerdict? {
        if livePendingCount == 0 { return .drained }
        let cycleSucceeded = cycleOutcome == .completed || cycleOutcome == .coalesced
        if !cycleSucceeded || iteration >= maxIterations {
            return .blocked(pendingCount: livePendingCount,
                            reason: classify(cycleOutcome, channelKilled: channelKilled,
                                             attestUnavailable: attestUnavailable,
                                             uploadFailed: uploadFailed))
        }
        return nil
    }

    /// Veredicto del push-all personal cuando **no hay motor que pueda subir**: no existe el runtime, o existe y el
    /// candado del dominio (`CloudSyncRuntime.canRunDomain()`) está cerrado — journal ilegible, fase transitoria, espejo de
    /// iCloud montado. Ahí no se corre ningún ciclo (ticket `sign-out-push-all-runs-a-sync-cycle-past-the-migration-gate`).
    ///
    /// Sin pendientes es seguro seguir: el cierre llega al borrado, que se lleva sesión, sync-meta y la fila del journal — y
    /// ésa es la salida del estado. Con pendientes bloquea y **no descarta**: suben cuando el motor pueda correr.
    ///
    /// **Pendiente no es solo el outbox.** Con el motor parado, lo que la persona edita vive únicamente en el History: sin
    /// drain no llega al outbox, y el borrado se lo llevaría sin aviso — y el motor puede estar parado días (una reversa
    /// fallida que nadie reintenta). `uncapturedChanges` es la lectura del History sin escribir; `nil` (no se pudo leer)
    /// cuenta como «sí», y la cifra de ese bloqueo es `Int.max`, el «no se pudo contar» del repo. Sin runtime no hay a quién
    /// preguntar y llega `false`.
    ///
    /// **El motivo lo decide quien sabe POR QUÉ no hay motor** (ticket
    /// `cloud-signout-with-the-engine-stopped-says-check-your-connection`): con el candado cerrado es
    /// `engineStoppedReason(read:)`, cuyo aviso nombra la salida real; sin runtime, `.permanent`. Sin valor por defecto a
    /// propósito: un `= .permanent` devolvería en silencio el «revisa tu conexión» a quien no lo pasara.
    static func pushAllVerdictWithoutEngine(livePendingCount: Int, uncapturedChanges: Bool?,
                                            reason: BlockReason) -> PushAllVerdict {
        if livePendingCount > 0 { return .blocked(pendingCount: livePendingCount, reason: reason) }
        if uncapturedChanges != false { return .blocked(pendingCount: Int.max, reason: reason) }
        return .drained
    }

    /// **¿Queda algo personal fuera del outbox?** El veredicto del push-all personal CON motor, releído con la sonda del
    /// History (`CloudSyncRuntime.hasUncapturedPersonalChanges`) — ticket
    /// `personal-sign-out-reads-an-unfinished-drain-as-nothing-pending`, gemelo de `groupsCaptureVerdict`.
    ///
    /// El outbox a 0 tras un ciclo no prueba que no quede nada: un drain que aborta (una lectura o un `save` que falla) hace
    /// `rollback()` y deja la edición solo en el History. El borrado que viene detrás se la llevaría sin aviso. Se relee en:
    ///  · `.drained` — el cierre sigue hasta el borrado.
    ///  · `.blocked(_, .attestUnavailable)` y, desde el 2026-09-28, `.blocked(_, .sessionExpired)` — el paso 1 ofrece
    ///    perder lo que enseña el aviso (`personalUploadBlockDecision`), y lo que no sale en él no se puede aceptar perder.
    ///  · `.blocked(_, .transient)`, solo con el drain atascado (2026-10-05): ver abajo.
    /// El resto de bloqueos no descarta nada y no pregunta: la sonda es una lectura del History, no gratis.
    ///
    /// **Lo que decide es el testigo del ciclo, `captureUnfinished`** (`CloudSyncRuntime.stoppedWithUnfinishedCapture(for:)`,
    /// ticket `personal-drain-that-always-aborts-blocks-cloud-sign-out-with-a-wait-a-moment-copy`). La sonda sola no distingue
    /// un drain que no termina de una escritura POSTERIOR a un drain que sí terminó —los reconciliadores del pull, el puente
    /// de Grupos, un ciclo que coalesció—, que el drain siguiente captura:
    ///  · **con el drain sano**, lo que queda es pasajero: `.transient` —«un momento más»—, y el push-all da otra vuelta
    ///    mientras le quede tope. Con el attest o la sesión, igual: ese cambio entrará en el outbox y el aviso lo contará.
    ///  · **con el drain atascado**, esperar no lo cura. El teléfono sin App Attest y la sesión caducada CONSERVAN su motivo
    ///    —su puerta de «Iniciar sesión» y su salida de pérdida—, también cuando el outbox está vacío (`.drained`, releído con
    ///    el motivo del ciclo, `cycleReason`): el paso 1 cuenta entonces los cambios del History junto a las filas
    ///    (`PersonalLoss`). Cualquier otro sale `.personalCaptureUnfinished`, cuyo texto no promete segundos.
    ///
    /// `true` o `nil` (no se pudo leer) cuentan como «queda algo». La cifra de `.drained` es `Int.max`, el «no se pudo contar»
    /// del repo.
    static func personalVerdictAfterProbe(_ verdict: PushAllVerdict,
                                          cycleReason: BlockReason,
                                          captureUnfinished: Bool,
                                          uncapturedChanges: () -> Bool?) -> PushAllVerdict {
        switch verdict {
        case .drained:
            guard uncapturedChanges() != false else { return .drained }
            let reason: BlockReason
            if !captureUnfinished {
                reason = .transient
            } else if cycleReason == .attestUnavailable || cycleReason == .sessionExpired {
                reason = cycleReason
            } else {
                reason = .personalCaptureUnfinished
            }
            return .blocked(pendingCount: .max, reason: reason)
        case .blocked(let pending, .attestUnavailable), .blocked(let pending, .sessionExpired):
            guard !captureUnfinished, uncapturedChanges() != false else { return verdict }
            return .blocked(pendingCount: pending, reason: .transient)
        case .blocked(let pending, .transient):
            guard captureUnfinished, uncapturedChanges() != false else { return verdict }
            return .blocked(pendingCount: pending, reason: .personalCaptureUnfinished)
        case .blocked:
            return verdict
        }
    }

    /// **¿Sigue atascado el drain, vuelta a vuelta del push-all?** El testigo de un ciclo `.coalesced` no habla de ese ciclo
    /// —`CloudSyncRuntime.stoppedWithUnfinishedCapture(for:)` da `false`—, así que esa vuelta conserva lo que vio la última
    /// que corrió de verdad. Sin esto, un ciclo de la cadencia en vuelo en la última vuelta devolvía «un momento más» a un
    /// drain que llevaba diecinueve vueltas atascado (review adversarial del 2026-10-05, lente 1).
    static func captureUnfinishedAfterLap(previous: Bool, outcome: SyncCadencePolicy.CadenceOutcome,
                                          cycleWitness: Bool) -> Bool {
        outcome == .coalesced ? previous : cycleWitness
    }

    /// **¿Deja el recuento final seguir con lo que el drain no capturó?** El paso 4 del cierre en la nube relee el outbox
    /// tras cortar los motores; con la pérdida personal ACEPTADA relee también el History (review adversarial del
    /// 2026-10-05, lente 2): con el drain atascado, un cambio apuntado entre el paso 1 y el borrado —mientras suben los
    /// grupos, una captura de Siri que se materializa— no llega nunca al outbox, y sin esta relectura el borrado se lo
    /// llevaba sin que ningún aviso lo contara. Tiene que estar entre lo aceptado (`coversUncaptured`); un History que no
    /// se deja leer solo lo cubre una aceptación sin cifra.
    ///
    /// **Sin aceptación no cambia nada, a propósito**: ese hueco —lo escrito tras el último drain, con el drain sano— es el
    /// del ticket `cloud-sign-out-final-recount-misses-edits-left-only-in-history`, y bloquear ahí por cualquier «sí» de la
    /// sonda cerraría el cierre por la frontera del respaldo del token. Con la pérdida aceptada, en cambio, la salida solo
    /// existe porque el aviso CONTÓ el History, y lo que llegue después tiene que volver a contarse.
    static func residualUncapturedAllowsSignOut(now: Set<String>?, acceptance: PersonalLossAcceptance?) -> Bool {
        guard let acceptance else { return true }
        return acceptance.coversUncaptured(now)
    }

    /// **¿Queda algo de grupos fuera del outbox?** El veredicto de la captura previa a una salida (ticket
    /// `groups-drain-failure-reads-as-nothing-pending`). `nil` = hay filas vivas y toca subirlas; el recuento solo no decide
    /// nada más, porque un outbox vacío no prueba que no quede nada:
    ///  · un drain que no terminó (`captureCompleted == false`) deja lo apuntado solo en el History, y
    ///  · el espejo del App Group puede guardar cambios que nunca llegaron a su fila (`unrehydratedMirrorCount`).
    /// Con cualquiera de las dos, bloquea y **no descarta** —el molde es `pushAllVerdictWithoutEngine` del personal—. La
    /// cifra es la del espejo si la hay, o `Int.max`, el «no se pudo contar» del repo.
    ///
    /// **El motivo es `.uploadRetryLater`, y ninguno nuevo.** Su texto —«no llegaron al servidor, siguen guardados en este
    /// teléfono y no se pierden; inténtalo en un rato»— es verdad para lo que se cura con otro intento: una lectura o un
    /// `save` que falló. `.transient` diría «espera unos segundos» ante algo que puede durar más. Hasta el 2026-09-26 no lo
    /// era para el corte del reloj: un reloj lógico más de 5 min por delante de la transacción cortaba en cada vuelta y no
    /// se curaba esperando. Desde `groups-clock-rollback-wedges-the-drain-forever` el drain estampa con
    /// `HLCClock.sendLocal`, que no corta por la deriva, así que esa causa ya no llega aquí.
    static func groupsCaptureVerdict(captureCompleted: Bool, livePendingCount: Int,
                                     unrehydratedMirrorCount: Int) -> PushAllVerdict? {
        if livePendingCount > 0 { return nil }
        if captureCompleted && unrehydratedMirrorCount == 0 { return .drained }
        return .blocked(pendingCount: unrehydratedMirrorCount > 0 ? unrehydratedMirrorCount : Int.max,
                        reason: .uploadRetryLater)
    }

    /// **Lo que la sesión de ahora puede subir**: el outbox vivo menos lo de otra cuenta (ticket
    /// `groups-outbox-rows-without-a-live-session-have-no-exit`). Un recuento que falló (`Int.max`) sigue siendo «no se pudo
    /// contar», nunca un número restado.
    static func uploadableAfterHeld(live: Int, held: Int) -> Int {
        guard live < Int.max, held < Int.max else { return Int.max }
        return max(0, live - held)
    }

    /// **El push-all del cierre drenó lo de ESTA sesión y solo quedan filas de otra cuenta.** Es el `.drained` de
    /// `groupsCaptureVerdict` releído con esas filas: con alguna, el cierre bloquea con `.groupsChangesFromAnotherAccount`
    /// y la cifra del outbox ENTERO, que es lo que el borrado se llevaría. Cualquier otro veredicto pasa tal cual.
    static func heldRowsVerdict(_ verdict: PushAllVerdict, livePendingCount: Int, heldCount: Int) -> PushAllVerdict {
        guard verdict == .drained, heldCount > 0 else { return verdict }
        return .blocked(pendingCount: livePendingCount, reason: .groupsChangesFromAnotherAccount)
    }

    // MARK: - La captura de Grupos que no termina (ticket `groups-drain-that-always-aborts-takes-the-loss-exit-away`)

    /// **Las esperas entre los reintentos de la captura previa a una salida, crecientes** (decisión de Jürgen del 2026-10-05:
    /// «reintentos espaciados con espera creciente durante varios segundos, mismo cambio fallando; luego ofrece la salida con
    /// la cifra»). Cinco intentos: el primero al momento y los otros tras 0,5 s, 1 s, 2 s y 4 s —7,5 s en total—.
    ///
    /// **Por qué crecientes y por qué esos.** La captura de Grupos es síncrona y local, y lo que la tumba de forma pasajera
    /// —un `save` que choca con otra escritura, un drain re-entrante, un store un momento ocupado— se cura en cuestión de
    /// milisegundos o de un par de segundos. Las primeras esperas cortas curan lo rápido sin hacer esperar a nadie; las
    /// largas dan su ocasión a lo que tarda. Tras 7,5 s con el MISMO cambio fallando en cada intento, lo que queda no se
    /// cura esperando dentro del gesto. El tope no sube más porque la persona está mirando «Guardando tus cambios
    /// pendientes…», y el gesto puede repetir esta espera hasta tres veces (la captura inicial, la de tras el ciclo y la de
    /// la oferta) si el atasco no se hubiera probado ya (`groupsCaptureStillStuck`).
    static let groupsExitCaptureRetryDelays: [Duration] = [.milliseconds(500), .seconds(1), .seconds(2), .seconds(4)]

    /// Cuántas veces se intenta la captura antes de darla por atascada: el primer intento y uno tras cada espera.
    static var groupsExitCaptureAttempts: Int { groupsExitCaptureRetryDelays.count + 1 }

    /// Cómo acabó la captura previa a una salida, con sus reintentos (`CloudSessionSignOut.captureGroupsForExit`).
    enum GroupsExitCapture: Equatable {
        /// Terminó en algún intento, o los que fallaron no dejaban nada fuera del outbox: todo lo local está en el outbox, o
        /// en el espejo que el aviso ya cuenta.
        case completed
        /// **Atascada: no terminó en ningún intento y el MISMO cambio del History siguió sin capturar en todos** (`persistent`
        /// lee las claves). Esperar no lo cura: el aviso de una salida cuenta esos cambios junto a las filas, con cifra
        /// exacta (`GroupsLoss.uncaptured`).
        case stuck
        /// No terminó y no se probó el atasco: los reintentos se cortaron (el gesto se canceló, o el import dejó de estar
        /// quieto), el History no se dejó leer en algún intento —sin él no hay cifra exacta ni «mismo cambio»—, o lo que
        /// quedaba fuera cambió de un intento a otro. Es lo pasajero: no abre la salida del atasco.
        case unfinished
    }

    /// **El veredicto de los reintentos, en puro.** `failedReadings` es lo que la sonda del History leyó tras cada intento
    /// fallido, en orden (`nil` = no se pudo leer); `attempts`, cuántos intentos tocaban.
    ///  · Un intento terminó → `.completed`.
    ///  · El último intento fallido leyó el History vacío → `.completed`: el fallo no escondía ningún cambio.
    ///  · No se dieron todos los intentos → `.unfinished`.
    ///  · Algún intento no pudo leer el History → `.unfinished`: sin lectura no hay cifra exacta que enseñar.
    ///  · Algún cambio siguió fuera en TODOS los intentos (la intersección no está vacía) → `.stuck`; si no, el drain avanzaba
    ///    entre intentos y es `.unfinished`.
    static func groupsExitCapture(completed: Bool, failedReadings: [Set<String>?],
                                  attempts: Int = groupsExitCaptureAttempts) -> GroupsExitCapture {
        if completed { return .completed }
        if let last = failedReadings.last, last == [] { return .completed }
        guard failedReadings.count >= attempts else { return .unfinished }
        return groupsPersistentlyUncaptured(failedReadings).map { $0.isEmpty ? .unfinished : .stuck } ?? .unfinished
    }

    /// **Los cambios que siguieron sin capturar en TODOS los intentos**: la intersección de las lecturas. `nil` si alguna no se
    /// pudo leer o no hay ninguna. Es «el mismo cambio fallando» de la decisión de Jürgen.
    static func groupsPersistentlyUncaptured(_ failedReadings: [Set<String>?]) -> Set<String>? {
        guard let first = failedReadings.first, var common = first else { return nil }
        for reading in failedReadings.dropFirst() {
            guard let reading else { return nil }
            common.formIntersection(reading)
        }
        return common
    }

    /// **¿Sigue atascado lo que ya se probó atascado en este gesto?** Un gesto captura hasta tres veces (al empezar, tras el
    /// ciclo y al ofrecer); con el atasco ya probado, repetir 7,5 s de reintentos en cada una no prueba nada nuevo. Basta un
    /// intento que falle con alguno de esos MISMOS cambios todavía fuera. Si el cambio se capturó o cambió, se vuelve a
    /// los reintentos completos.
    static func groupsCaptureStillStuck(provenStuck: Set<String>, reading: Set<String>?) -> Bool {
        guard let reading, !provenStuck.isEmpty else { return false }
        return !reading.isDisjoint(with: provenStuck)
    }

    /// **Un bloqueo que abre la salida de la pérdida, después de volver a capturar.** Son los únicos que un caller deja
    /// seguir —la pérdida aceptada compara las filas VIVAS con las que la persona aceptó perder
    /// (`continuesAfterBlockedUpload`)—, así que solo se devuelven tal cual si el aviso puede contar todo lo que se
    /// perdería. Si no, es una subida pendiente sin salida de pérdida: la persona no puede aceptar perder lo que el aviso no
    /// le enseñó (review adversarial del 2026-09-26). La cifra es la del outbox después de capturar.
    ///
    /// Nació para el attest (`attestBlockAfterRecapture`); desde el 2026-09-28 cubre también la sesión caducada y los
    /// cambios de otra cuenta, que abren la misma salida (`lossCause`). Un motivo que no la abre vuelve tal cual.
    ///
    /// **Con la captura atascada el motivo se CONSERVA desde el 2026-10-05** (ticket
    /// `groups-drain-that-always-aborts-takes-the-loss-exit-away`): un drain que no termina en ninguna vuelta no se cura con
    /// otro intento, y traducirlo a `.uploadRetryLater` le quitaba la salida para siempre al teléfono sin App Attest, a la
    /// sesión caducada y a los cambios de otra cuenta. Lo que no está en el outbox lo cuenta el aviso por su clave del
    /// History (`GroupsLoss.uncaptured`), y el espejo por su `clientMutationID`. **Lo pasajero sigue sin salida**: la captura
    /// que terminó con entradas del espejo fuera del outbox (una rehidratación que no entró) y la que no probó el atasco
    /// (`GroupsExitCapture.unfinished`).
    static func lossBlockAfterRecapture(reason: BlockReason, capture: GroupsExitCapture, livePendingCount: Int,
                                        unrehydratedMirrorCount: Int) -> PushAllVerdict {
        guard lossCause(reason) != nil else { return .blocked(pendingCount: livePendingCount, reason: reason) }
        let keepsReason: Bool
        switch capture {
        case .completed: keepsReason = unrehydratedMirrorCount == 0
        case .stuck: keepsReason = true
        case .unfinished: keepsReason = false
        }
        return .blocked(pendingCount: livePendingCount, reason: keepsReason ? reason : .uploadRetryLater)
    }

    /// **Qué dice el push-all cuando el ciclo vació lo que esta sesión puede subir y la captura sigue atascada** (2026-10-05).
    /// Lo que queda solo vive en el History, así que decide quién lo apuntó y qué paró el ciclo:
    ///  · el ciclo paró por un motivo que abre la salida (sin App Attest, sin sesión): ese motivo. Con el outbox a 0 el
    ///    veredicto del ciclo se ignoraba y la salida no se ofrecía nunca.
    ///  · queda algo de otra cuenta: filas retenidas en el outbox (`heldRowsForAnotherAccount`) o lo que el History apunta a
    ///    otra cuenta (`uncapturedPointsToAnotherAccount`, fechado contra el registro de sesiones como hace el drain):
    ///    `.groupsChangesFromAnotherAccount`, con su salida, que pierde lo ajeno y lo atascado.
    ///  · si no, `.groupsCaptureUnfinished` y sin salida: con attest y sesión buenos lo único que impide subir es este
    ///    teléfono, y la decisión A de Jürgen no da salida a un teléfono normal. También un ciclo que paró por algo que no abre
    ///    la salida (el canal en pausa, una subida fallida): lo que el drain no captura no llega al outbox aunque eso se
    ///    arregle. Hasta el 2026-10-05 esta rama decía `.uploadRetryLater`, «inténtalo en un rato», y esperar no lo cura (ticket
    ///    `groups-stuck-drain-on-a-healthy-phone-says-try-again-later`).
    ///
    /// **Las filas retenidas del outbox también cuentan** (ticket `stuck-groups-drain-hides-held-rows-of-another-account`,
    /// decisión A de Jürgen del 2026-10-05). Hasta ese día no se miraban: con un cambio propio atascado salía solo el atasco, la
    /// persona lo arreglaba y al reintentar le salía «otra cuenta». Las dos causas, de una en una. Ahora sale «otra cuenta» y
    /// el aviso cuenta también lo atascado (`GroupsLoss.readsUncaptured`), y su texto nombra las dos.
    ///
    /// **Falla cerrado ante lo que no se sabe** (review adversarial del 2026-10-05, lente de datos), porque lo que decide aquí
    /// abre una salida que PIERDE cambios:
    ///  · un recuento de filas ajenas que falló (`Int.max`) no prueba nada;
    ///  · un History ilegible (`nil`) tampoco deja abrirla, haya o no filas ajenas: sin él, lo aceptado sin cifra cubriría
    ///    también lo propio que se apunte después del aviso. Es el atasco, sin salida.
    static func stuckCaptureVerdict(cycleReason: BlockReason?, livePendingCount: Int, heldRowsForAnotherAccount: Int,
                                    uncapturedPointsToAnotherAccount: Bool?) -> PushAllVerdict {
        if let cycleReason, lossCause(cycleReason) != nil {
            return .blocked(pendingCount: livePendingCount, reason: cycleReason)
        }
        if let uncapturedPointsToAnotherAccount {
            let heldRowsProven = heldRowsForAnotherAccount > 0 && heldRowsForAnotherAccount < Int.max
            if heldRowsProven || uncapturedPointsToAnotherAccount {
                return .blocked(pendingCount: livePendingCount, reason: .groupsChangesFromAnotherAccount)
            }
        }
        return .blocked(pendingCount: livePendingCount > 0 ? livePendingCount : Int.max, reason: .groupsCaptureUnfinished)
    }

    /// **¿Apunta lo que el drain no capturó a otra cuenta?** (2026-10-05). Sí si TODO es de otra cuenta o sin dueño probado
    /// —el criterio de siempre: entonces nada de eso lo sube esta sesión—, o si ALGO es de otra cuenta CONCRETA
    /// (`UncapturedChange.provenAnotherAccount`). Lo «sin dueño» mezclado con cambios propios no cuenta: la sonda es ancha a
    /// propósito y lee también cambios anteriores al registro de sesiones, y ese ruido abriría la salida que pierde cambios a
    /// un teléfono cuyo único problema es su drain (review adversarial, lente de datos). `nil` = no se pudo leer.
    static func uncapturedPointsToAnotherAccount(_ changes: [GroupsSyncClient.UncapturedChange]?) -> Bool? {
        guard let changes else { return nil }
        if !changes.isEmpty, changes.allSatisfy(\.heldForAnotherAccount) { return true }
        return changes.contains(where: \.provenAnotherAccount)
    }

    /// **Lo que dice el aviso del desasociar bloqueado: una causa, o dos** (ticket
    /// `detach-with-a-stuck-groups-drain-names-only-the-first-of-two-causes`, opción B de Jürgen del 2026-10-05).
    ///
    /// Va aparte de `BlockReason` a propósito. `BlockReason` es por qué paró el push-all, y lo comparten los cierres, el
    /// desasociar y «Empezar de cero» con una docena de `switch` exhaustivos; las dos causas a la vez solo cambian el TEXTO de
    /// un gesto, el que no tiene salida que pierda nada. Un case nuevo allí obligaría a cada lector a declarar que no le llega.
    enum DetachBlockedNotice: Equatable {
        /// Una causa, con el texto de ese motivo.
        case reason(BlockReason)
        /// **Dos causas a la vez**: lo que en un cierre abriría la salida que pierde los cambios (`lossCause`: sin sesión, sin
        /// App Attest, otra cuenta) y, además, la captura de grupos atascada en este teléfono (lo que sería
        /// `.groupsCaptureUnfinished`). Los cierres lo resuelven todo con «Cerrar sesión y perderlos»; el desasociar no la
        /// ofrece (decisión del 2026-09-15), así que con un solo motivo la persona arreglaba uno y al reintentar le salía el
        /// otro. Su texto nombra los dos y dice qué hacer para todo.
        case alsoCaptureUnfinished(LossCause)
    }

    /// **Qué aviso enseña el desasociar** para el motivo con el que bloqueó y si la última captura de grupos del gesto se
    /// quedó atascada (`CloudSessionSignOut.groupsCaptureStuck`).
    ///
    /// Dos causas solo cuando las dos están probadas: la captura atascada (lo que no se cura con otro intento) y un motivo
    /// de la salida (`lossCause`). Ese motivo con la captura atascada lo producen los dos caminos del push-all que lo
    /// conservan: `stuckCaptureVerdict` con el outbox a 0 y `lossBlockAfterRecapture` con filas vivas. Sin el atasco, el
    /// motivo va solo; y un motivo que no abre la salida también, porque o ya nombra el drain (`.groupsCaptureUnfinished`) o
    /// no es una causa que la persona pueda arreglar aparte.
    static func detachBlockedNotice(reason: BlockReason, captureStuck: Bool) -> DetachBlockedNotice {
        guard captureStuck, let cause = lossCause(reason) else { return .reason(reason) }
        return .alsoCaptureUnfinished(cause)
    }

    /// **Lo que un cierre se llevaría de grupos, en sus dos mitades** (2026-10-05, ticket
    /// `groups-drain-that-always-aborts-takes-the-loss-exit-away`): las filas vivas del outbox y las entradas del espejo sin
    /// fila, por su `clientMutationID` (`CloudSessionSignOut.groupsLossRowIDs`), y los cambios del History que ningún drain
    /// capturó, por su clave (`GroupsSyncClient.uncapturedGroupsChanges`). `nil` en una mitad = no se pudo leer.
    ///
    /// **La segunda mitad solo se lee con la captura atascada**: con la captura completa es `[]` por construcción, y leer el
    /// History de un teléfono sin cursor de Grupos contaría ediciones de la era CloudKit que nunca suben. Es `PersonalLoss`
    /// para el outbox de grupos.
    struct GroupsLoss: Equatable {
        let rows: Set<UUID>?
        let uncaptured: Set<String>?

        /// La cifra del aviso: `Int.max` si alguna mitad no se pudo leer, el «no se pudo contar» del repo.
        var count: Int {
            guard let rows, let uncaptured else { return .max }
            return rows.count + uncaptured.count
        }

        /// No hay nada que perder: las dos mitades leídas y vacías.
        var isEmpty: Bool { rows?.isEmpty == true && uncaptured?.isEmpty == true }

        /// **¿El aviso cuenta cambios que el drain no capturó?** Algo leído, o la mitad sin leer (`nil`), que también puede
        /// tenerlos. Es el gemelo de `CausedLossAcceptance.readsUncaptured` para la oferta, y decide si el aviso de «otra
        /// cuenta» nombra además el atasco (`SignOutBlockedCopy.groupsLossMessage`, 2026-10-05): con cambios propios
        /// atascados, «solo se suben con la cuenta que los apuntó» sería falso para ellos.
        var readsUncaptured: Bool { uncaptured != [] }
    }

    /// **¿Deja el recuento final seguir con lo que el drain de Grupos no capturó?** El gemelo de
    /// `residualUncapturedAllowsSignOut` (2026-10-05): con la pérdida aceptada sobre una captura atascada, lo apuntado después
    /// del aviso no llega nunca al outbox y el borrado se lo llevaría sin contarlo. Sin aceptación, o con una aceptada sobre
    /// una captura completa (`readsUncaptured == false`), no cambia nada: el History no se lee (`GroupsLoss`).
    static func groupsResidualUncapturedAllowsSignOut(now: Set<String>?, acceptance: CausedLossAcceptance?) -> Bool {
        guard let acceptance, acceptance.readsUncaptured else { return true }
        return acceptance.coversUncaptured(now)
    }

    /// **El motivo por el que paró un ciclo del canal, o `nil` si no paró** (`.completed`/`.coalesced`). Es lo que la rama de
    /// la captura atascada lee del último ciclo REAL del push-all (`stuckCaptureVerdict`): con el outbox a 0,
    /// `pushAllVerdict` da `.drained` aunque el ciclo fallara, y ese fallo —sin App Attest, sin sesión— es justo lo que abre
    /// la salida.
    static func cycleBlockReason(_ outcome: SyncCadencePolicy.CadenceOutcome, channelKilled: Bool,
                                 attestUnavailable: Bool, uploadFailed: Bool) -> BlockReason? {
        switch outcome {
        case .completed, .coalesced: return nil
        case .transient, .sessionExpired, .accountUnavailable:
            return classify(outcome, channelKilled: channelKilled, attestUnavailable: attestUnavailable,
                            uploadFailed: uploadFailed)
        }
    }

    /// **Qué History relee el recuento pegado al borrado** (`CloudSessionSignOut.groupsResidualUncaptured`): con lo aceptado
    /// sobre una captura atascada, lo que lee la sonda (`read`); si no, `[]` y la sonda no se toca (`GroupsLoss`).
    static func groupsResidualUncapturedToCheck(acceptance: CausedLossAcceptance?,
                                                read: () -> Set<String>?) -> Set<String>? {
        guard acceptance?.readsUncaptured == true else { return [] }
        return read()
    }

    /// **Cuántos cambios de grupos se lleva un cierre con la pérdida aceptada**, para el canario: las filas que quedan más
    /// los cambios del History que lo aceptado contó. `Int.max` si alguna mitad no tiene cifra (`shownLossCount`).
    static func groupsDiscardedCount(rows: Int, acceptance: CausedLossAcceptance) -> Int {
        guard rows < Int.max, let uncaptured = acceptance.uncaptured else { return Int.max }
        let (sum, overflow) = rows.addingReportingOverflow(uncaptured.count)
        return overflow ? Int.max : sum
    }

    /// **¿Sigue valiendo lo aceptado de grupos tras volver a subir?** Que el bloqueo sea de su causa y que lo que queda esté
    /// entre lo aceptado, en las DOS mitades: las filas (`continuesAfterBlockedUpload`) y los cambios del History.
    static func groupsLossAcceptanceContinues(_ acceptance: CausedLossAcceptance, reason: BlockReason,
                                              pendingRows: Set<UUID>?, uncaptured: Set<String>?) -> Bool {
        continuesAfterBlockedUpload(reason: reason, cause: acceptance.cause, pendingRows: pendingRows,
                                    acceptance: acceptance.rows)
            && acceptance.coversUncaptured(uncaptured)
    }

    /// **¿Cubre lo aceptado lo de ahora?**, para una mitad. Sin nada ahora, siempre; aceptado sin leer (el aviso salió sin
    /// cifra), cualquiera; ahora sin leer, solo eso; y si no, todo lo de ahora tiene que estar entre lo aceptado.
    ///
    /// **Una sola función para las tres comparaciones** (2026-10-05): la mitad del History del cierre en la nube
    /// (`PersonalLossAcceptance`), las mitades de «Empezar de cero» (`FreshStartGroupsLoss`) y la del History de Grupos
    /// (`CausedLossAcceptance`) eran tres copias idénticas, y una que divergiera aceptaría lo que las otras rechazan.
    static func lossHalfCovers<T: Hashable>(accepted: Set<T>?, now: Set<T>?) -> Bool {
        if let now, now.isEmpty { return true }
        guard let accepted else { return true }
        guard let now else { return false }
        return now.isSubset(of: accepted)
    }

    /// **Por qué «Empezar de cero» no borra lo que la subida dejó** (`CloudSessionSignOut.drainGroupsBeforeFreshStart`). Si
    /// solo quedan entradas del espejo que esta sesión no puede subir —el borrado las cuenta todas y la rehidratación solo
    /// toca las de la sesión—, esperar no las sube nunca: lo que las sube es volver a entrar con su cuenta. Sin sesión eso
    /// dice `.sessionExpired`, el mismo motivo que el push-all ya da a las filas vivas sin sesión; con la sesión de OTRA
    /// cuenta abierta (`anotherAccountMirrorCount > 0`, ticket
    /// `fresh-start-drops-mirror-entries-of-another-identity-without-counting-them`) dice `.groupsChangesFromAnotherAccount`,
    /// cuyo texto es justo ese caso: «su sesión ya no está» sería falso con una sesión abierta. Los dos ofrecen perderlos.
    /// Con filas vivas nuevas, o entradas de la sesión que no se pudieron rehidratar, otro intento sí lo cura (review
    /// adversarial del 2026-09-26).
    static func freshStartResidualReason(livePendingCount: Int, sessionMirrorCount: Int,
                                         anotherAccountMirrorCount: Int) -> BlockReason {
        guard livePendingCount == 0, sessionMirrorCount == 0 else { return .uploadRetryLater }
        return anotherAccountMirrorCount > 0 ? .groupsChangesFromAnotherAccount : .sessionExpired
    }

    // MARK: - «Empezar de cero y perderlos» (ticket `fresh-start-has-no-way-out-when-group-writes-can-never-upload`)

    /// **¿Este bloqueo de «Empezar de cero» ofrece perder los cambios de grupos?** Solo con los motivos que esperar no
    /// arregla (decisión de Jürgen del 2026-09-26):
    ///  · `.sessionExpired` — solo suben con la cuenta que los apuntó, y su sesión ya no está. En un iPhone heredado esa
    ///    cuenta ni siquiera es de quien empieza de cero.
    ///  · `.permanent` — la cuenta no está disponible, o no hay motor.
    ///  · `.attestUnavailable` — el teléfono lleva más de un día sin App Attest. Es el molde: el cierre de sesión ya ofrece
    ///    «Cerrar sesión y perderlos» con este motivo.
    ///
    /// **Con cualquier otro, no.** `.channelPaused` se levanta con un deploy, y lo pasajero —`.uploadRetryLater`,
    /// `.transient`— se cura con otro intento: ofrecer perderlos ahí sería cambiar cambios que van a subir por una salida
    /// más rápida. Los motivos que este gesto no produce (los del cierre personal, los del desasociar) tampoco.
    ///
    /// `switch` exhaustivo y sin `default`: un motivo nuevo tiene que decidir aquí si deja perder cambios de otras personas.
    static func freshStartOffersGroupsLossExit(_ reason: BlockReason) -> Bool {
        switch reason {
        // `.groupsChangesFromAnotherAccount` (2026-09-28) por lo mismo que la sesión caducada: solo suben con la cuenta que
        // los apuntó, y la sesión de ahora es otra.
        case .sessionExpired, .permanent, .attestUnavailable, .groupsChangesFromAnotherAccount:
            return true
        case .transient, .exportUnconfirmed, .bridgeUnreadable, .detachBusy, .channelPaused, .uploadRetryLater,
             .personalAttestUnavailable, .syncStoppedNeedsUpdate, .syncStoppedMidMigration, .syncStoppedNeedsRelaunch,
             .personalUploadRetryLater, .cloudSessionExpired, .sessionNotClosed, .signOutSessionSurvived,
             .migrationInFlight, .migrationUnreadable, .personalCaptureUnfinished,
             // El drain de grupos que no termina (2026-10-05): decisión A de Jürgen, ninguna salida pierde esos cambios.
             .groupsCaptureUnfinished:
            return false
        }
    }

    /// **Lo que «Empezar de cero» se llevaría de grupos, por fila.** El borrado purga el outbox y el espejo del App Group,
    /// así que cuentan las dos cosas: las filas VIVAS del outbox por su `clientMutationID`, y las entradas del espejo sin
    /// fila por su clave `(syncID, hlc, op)`. `nil` en cualquiera de las dos = no se pudo leer.
    ///
    /// Es la instantánea que enseña el aviso y lo que la persona acepta perder. **Por fila y no por cifra**, por lo mismo
    /// que `LossAcceptance`: con la cifra, aceptar 2 cambios cubría cualquier par, y uno apuntado después se iba sin aviso.
    ///
    /// **Desde el 2026-10-05 tiene una tercera mitad** (ticket `groups-drain-that-always-aborts-takes-the-loss-exit-away`): los
    /// cambios del History de Grupos que ningún drain capturó, por su clave (`uncaptured`). Con un drain que no termina nunca
    /// esos cambios no llegan ni al outbox ni al espejo, y el borrado del dominio se los lleva igual. **Solo se lee con la
    /// captura atascada** (`readsUncaptured`): con la captura completa es `[]`, por lo mismo que `GroupsLoss`.
    struct FreshStartGroupsLoss: Equatable {
        let rows: Set<UUID>?
        let mirrorKeys: Set<String>?
        let uncaptured: Set<String>?

        init(rows: Set<UUID>?, mirrorKeys: Set<String>?, uncaptured: Set<String>? = []) {
            self.rows = rows
            self.mirrorKeys = mirrorKeys
            self.uncaptured = uncaptured
        }

        /// La cifra del aviso: `Int.max` si alguna mitad no se pudo leer, el «no se pudo contar» del repo
        /// (`shownLossCount`).
        var count: Int {
            guard let rows, let mirrorKeys, let uncaptured else { return .max }
            return rows.count + mirrorKeys.count + uncaptured.count
        }

        var isEmpty: Bool { rows?.isEmpty == true && mirrorKeys?.isEmpty == true && uncaptured?.isEmpty == true }

        /// ¿Lo aceptado contó el History? Entonces el cinturón del borrado lo vuelve a leer antes de borrar
        /// (`DataWipeService.requireNoUnsentGroupWrites`); si no, no lo lee.
        var readsUncaptured: Bool { uncaptured != [] }

        /// ¿Aceptar ESTO cubre lo que hay AHORA? Cada mitad por separado: lo de ahora tiene que estar entre lo aceptado.
        /// Una mitad aceptada sin leer (`nil`, el aviso salió sin cifra) cubre cualquiera, como `LossAcceptance.uncounted`;
        /// una mitad de ahora que no se pudo leer solo la cubre eso.
        func covers(_ now: FreshStartGroupsLoss) -> Bool {
            CloudSignOutFlowLogic.lossHalfCovers(accepted: rows, now: now.rows)
                && CloudSignOutFlowLogic.lossHalfCovers(accepted: mirrorKeys, now: now.mirrorKeys)
                && CloudSignOutFlowLogic.lossHalfCovers(accepted: uncaptured, now: now.uncaptured)
        }
    }

    /// **¿Puede «Empezar de cero» borrar con estos cambios sin subir?** Solo si la subida de ESTE intento acaba de
    /// bloquear con un motivo que ofrece la salida **y** lo que queda está entre lo que la persona aceptó perder. Con otro
    /// motivo —el attest volvió y ahora falla la red, por ejemplo— se llevaría cambios que otro intento subiría: vuelve el
    /// aviso. Es `continuesAfterBlockedUpload`, con los tres motivos de este gesto y las dos mitades que borra.
    /// **Qué dice «Empezar de cero» cuando la captura previa no terminó** justo antes de ofrecer perder los cambios
    /// (`CloudSessionSignOut.settleFreshStartBlock`). Es el motivo de `groupsCaptureVerdict` para lo mismo —un drain o una
    /// rehidratación que otro intento cura— y no ofrece la salida: la persona no puede aceptar perder lo que el aviso no
    /// cuenta. Vive aquí y no escrito a mano en el coordinador, donde `.uploadRetryLater` lo decide el testigo del ciclo.
    /// **Desde el 2026-10-05 solo lo produce la captura que no probó el atasco** (`GroupsExitCapture.unfinished`): la
    /// atascada conserva el motivo y cuenta el History (`FreshStartGroupsLoss.uncaptured`).
    static let freshStartUncapturedReason: BlockReason = .uploadRetryLater

    static func freshStartContinuesDiscarding(reason: BlockReason, now: FreshStartGroupsLoss,
                                              accepted: FreshStartGroupsLoss?) -> Bool {
        guard let accepted, freshStartOffersGroupsLossExit(reason) else { return false }
        return accepted.covers(now)
    }

    /// Por qué el candado del motor (`CloudSyncRuntime.canRunDomain()`) está cerrado, dicho como el motivo que el cierre
    /// enseña. **Se clasifica por lo que enseña «Dónde viven tus datos» en ese mismo estado**, porque es ahí adonde manda
    /// el aviso (`CloudMigrationUIStateDeriver.derive`):
    ///  · journal ilegible → `.syncStoppedNeedsUpdate` (la tarjeta dice «cierra y abre»; el aviso añade actualizar).
    ///  · fase NO estable —ida o vuelta en vuelo, fallo, espera del líder— → `.syncStoppedMidMigration`: la pantalla
    ///    enseña su progreso, su «Reintentar» o su relanzamiento.
    ///  · fase ESTABLE (`MigrationRuntimeGate.isDomainStablePhase`) → `.syncStoppedNeedsRelaunch`: el candado solo se
    ///    cierra ahí por el espejo montado, la pantalla enseña la nube activa y lo que cura es reabrir. Hasta la review
    ///    adversarial del 2026-09-25 esto caía en «termínalo en Almacenamiento», donde no había nada que terminar.
    ///
    /// `switch` exhaustivo sobre la lectura: un caso nuevo de `JournaledPhaseRead` tiene que decidir aquí qué se dice.
    static func engineStoppedReason(read: JournaledPhaseRead) -> BlockReason {
        switch read {
        case .unreadable: return .syncStoppedNeedsUpdate
        case .phase(let phase):
            return MigrationRuntimeGate.isDomainStablePhase(phase) ? .syncStoppedNeedsRelaunch : .syncStoppedMidMigration
        }
    }

    // MARK: - Las salidas que pierden los cambios que no suben (teléfono sin App Attest 2026-09-15 · sin sesión y otra
    // cuenta 2026-09-28)

    /// **Por qué un cambio de grupos no va a subir, dicho como lo que la persona puede aceptar perder.** Es la causa que
    /// viaja con la oferta y con lo aceptado: retomar el cierre solo sigue sin subir mientras el bloqueo siga siendo de la
    /// MISMA causa (`continuesAfterBlockedUpload`).
    enum LossCause: String, Equatable {
        /// El teléfono lleva más de un día sin App Attest (`.attestUnavailable`).
        case attestUnavailable
        /// No hay sesión con la que subirlos: el SDK la borró, o el servidor rechaza su token (`.sessionExpired`, y
        /// `.cloudSessionExpired` en el paso 2 del cierre en la nube).
        case noSession
        /// La sesión viva es de otra cuenta, o no hay prueba de quién los apuntó (`.groupsChangesFromAnotherAccount`).
        case otherAccount
    }

    /// **¿Abre este motivo la salida que pierde los cambios de GRUPOS en un cierre de sesión?** Solo los que esperar no
    /// arregla y que se curan con algo que la persona puede no tener: App Attest, una sesión de esa cuenta
    /// (decisión 1 del encargo del 2026-09-28: «vuelve a entrar» sigue siendo el camino por defecto, y quien no puede
    /// volver a entrar —cuenta borrada, correo perdido— necesita salir). `nil` = no la abre.
    ///
    /// **La de «Empezar de cero» es otra tabla** (`freshStartOffersGroupsLossExit`): aquel gesto la abre también con
    /// `.permanent`. Aquí `.permanent` no, porque en un cierre lo producen el motor que falta y el recuento de después del
    /// teardown, y ninguno de los dos dice que esos cambios no puedan subir nunca.
    ///
    /// `switch` exhaustivo y sin `default`: un motivo nuevo tiene que decidir aquí si deja perder cambios de otras personas.
    static func lossCause(_ reason: BlockReason) -> LossCause? {
        switch reason {
        case .attestUnavailable: return .attestUnavailable
        case .sessionExpired, .cloudSessionExpired: return .noSession
        case .groupsChangesFromAnotherAccount: return .otherAccount
        case .transient, .permanent, .exportUnconfirmed, .bridgeUnreadable, .detachBusy, .channelPaused,
             .uploadRetryLater, .personalAttestUnavailable, .syncStoppedNeedsUpdate, .syncStoppedMidMigration,
             .syncStoppedNeedsRelaunch, .personalUploadRetryLater, .sessionNotClosed, .signOutSessionSurvived,
             .migrationInFlight, .migrationUnreadable, .personalCaptureUnfinished,
             // El drain de grupos que no termina (2026-10-05): sin salida, decisión A de Jürgen.
             .groupsCaptureUnfinished:
            return nil
        }
    }

    /// Lo que la persona aceptó perder en «Cerrar sesión y perderlos», con la causa del aviso que lo enseñó. **Lo usan los
    /// dos lados**: los cambios de GRUPOS (`CloudSessionSignOut.acceptedGroupsLoss`) y, desde el 2026-09-28, los PERSONALES
    /// de la nube (`acceptedPersonalLoss`), que hasta ese día no llevaban causa porque su única salida era el attest (ticket
    /// `cloud-sign-out-with-an-expired-session-and-personal-changes-has-no-exit`).
    ///
    /// **Desde el 2026-10-05 lleva también la mitad del History** (`uncaptured`, ticket
    /// `groups-drain-that-always-aborts-takes-the-loss-exit-away`): los cambios de grupos que el drain no capturó y que el aviso
    /// contó (`GroupsLoss`). `[]` = el aviso salió con la captura completa y no leyó el History; `nil` = lo leyó y no pudo, y
    /// lo aceptado cubre cualquier cambio de esa mitad, como `LossAcceptance.uncounted` con las filas.
    struct CausedLossAcceptance: Equatable {
        let rows: LossAcceptance
        let cause: LossCause
        let uncaptured: Set<String>?

        init(rows: LossAcceptance, cause: LossCause, uncaptured: Set<String>? = []) {
            self.rows = rows
            self.cause = cause
            self.uncaptured = uncaptured
        }

        /// Lo aceptado al elegir «Cerrar sesión y perderlos» sobre lo que contó el aviso de grupos.
        init(offer loss: GroupsLoss, cause: LossCause) {
            self.init(rows: loss.rows.map { .rows($0) } ?? .uncounted, cause: cause, uncaptured: loss.uncaptured)
        }

        /// ¿El aviso contó el History? Entonces los recuentos finales lo vuelven a leer pegados al borrado
        /// (`groupsResidualUncapturedAllowsSignOut`).
        var readsUncaptured: Bool { uncaptured != [] }

        /// ¿Cubre lo aceptado los cambios sin capturar de AHORA? (`lossHalfCovers`).
        func coversUncaptured(_ now: Set<String>?) -> Bool {
            CloudSignOutFlowLogic.lossHalfCovers(accepted: uncaptured, now: now)
        }
    }

    /// **Lo que el cierre en la nube se llevaría de los cambios PERSONALES, en sus dos mitades** (2026-10-05, ticket
    /// `personal-drain-that-always-aborts-blocks-cloud-sign-out-with-a-wait-a-moment-copy`): las filas vivas del outbox, por su
    /// `clientMutationID`, y los cambios del History que ningún drain capturó, por su clave
    /// (`CloudSyncEngine.uncapturedPersonalChangeKeys`). `nil` en cualquiera de las dos = no se pudo leer.
    ///
    /// **La segunda mitad es la que hace honesto el aviso cuando el drain no termina nunca**: esos cambios no llegan al
    /// outbox, el borrado se los lleva igual y, contando solo las filas, la persona aceptaba perder «2 cambios» y perdía los
    /// que el aviso no le enseñó. El molde es `FreshStartGroupsLoss` (filas + espejo).
    struct PersonalLoss: Equatable {
        let rows: Set<UUID>?
        let uncaptured: Set<String>?

        /// La cifra del aviso: `Int.max` si alguna mitad no se pudo leer, el «no se pudo contar» del repo (`shownLossCount`).
        var count: Int {
            guard let rows, let uncaptured else { return .max }
            return rows.count + uncaptured.count
        }
    }

    /// Lo que la persona aceptó perder de sus cambios PERSONALES en el cierre en la nube, con la causa del aviso que lo
    /// enseñó. Es `CausedLossAcceptance` con la mitad del History (2026-10-05): **cada mitad se compara con la suya**, y una
    /// fila o un cambio que no estaban en el aviso hacen que vuelva. `uncaptured == nil` = el aviso salió sin poder leer el
    /// History, y lo aceptado cubre cualquier cambio de esa mitad, como `LossAcceptance.uncounted` con las filas.
    struct PersonalLossAcceptance: Equatable {
        let rows: LossAcceptance
        let uncaptured: Set<String>?
        let cause: LossCause

        /// Lo aceptado al elegir «Cerrar sesión y perderlos» sobre lo que contó el aviso.
        init(offer loss: PersonalLoss, cause: LossCause) {
            self.rows = loss.rows.map { .rows($0) } ?? .uncounted
            self.uncaptured = loss.uncaptured
            self.cause = cause
        }

        init(rows: LossAcceptance, uncaptured: Set<String>?, cause: LossCause) {
            self.rows = rows
            self.uncaptured = uncaptured
            self.cause = cause
        }

        /// ¿Cubre lo aceptado los cambios sin capturar de AHORA? Sin ninguno, siempre; aceptado sin leer, cualquiera; ahora
        /// sin leer, solo eso; y si no, todos tienen que estar entre los aceptados.
        func coversUncaptured(_ now: Set<String>?) -> Bool {
            CloudSignOutFlowLogic.lossHalfCovers(accepted: uncaptured, now: now)
        }
    }

    /// **¿Abre este motivo YA TRADUCIDO la salida que pierde los cambios PERSONALES del cierre en la nube?** Es la tabla
    /// gemela de `lossCause` para el paso 1 (`CloudSessionSignOut.performCloudSecureSignOut`), que la lee sobre lo que
    /// enseña:
    ///  · `.personalAttestUnavailable` — el teléfono sin App Attest (decisión de Jürgen del 2026-09-15).
    ///  · `.cloudSessionExpired` — no hay sesión con la que subirlos, o la abierta es de otra cuenta, que el motor lee igual
    ///    (encargo del 2026-09-28, decisión 1): «vuelve a entrar» sigue siendo el camino por defecto, y quien no puede —cuenta
    ///    borrada, correo perdido— necesita salir. El dato es más caro que el de grupos, así que el aviso ofrece antes
    ///    exportar los movimientos.
    ///
    /// El resto no la abre: esperar, reintentar o reabrir la app los sube. `switch` exhaustivo y sin `default`: un motivo
    /// nuevo tiene que decidir aquí si deja perder los movimientos de alguien.
    static func personalLossCause(_ shown: BlockReason) -> LossCause? {
        switch shown {
        case .personalAttestUnavailable: return .attestUnavailable
        case .cloudSessionExpired: return .noSession
        case .transient, .permanent, .exportUnconfirmed, .sessionExpired, .bridgeUnreadable, .detachBusy, .channelPaused,
             .uploadRetryLater, .attestUnavailable, .syncStoppedNeedsUpdate, .syncStoppedMidMigration,
             .syncStoppedNeedsRelaunch, .personalUploadRetryLater, .sessionNotClosed, .signOutSessionSurvived,
             .migrationInFlight, .migrationUnreadable, .groupsChangesFromAnotherAccount, .personalCaptureUnfinished,
             .groupsCaptureUnfinished:
            return nil
        }
    }

    /// Qué hace el paso 1 del cierre en la nube cuando la subida PERSONAL acaba de bloquear.
    enum PersonalUploadBlockDecision: Equatable {
        /// Lo que queda es lo que la persona aceptó perder, y por la misma causa: el cierre sigue sin subirlo.
        case continueWithAcceptedLoss
        /// Bloquea como siempre, sin salida que pierda nada, con el motivo que enseña el aviso.
        case block(shown: BlockReason)
        /// Bloquea y ofrece exportar y perder esos cambios, por `cause`.
        case offerLoss(shown: BlockReason, cause: LossCause)
    }

    /// **La decisión del paso 1 del cierre en la nube, pura** (2026-09-28): hasta ese día vivía en el coordinador, con el
    /// attest escrito a mano como única salida. `reason` es el motivo CRUDO del push-all personal; `pending`, lo que se
    /// perdería —las filas vivas de su outbox y, desde el 2026-10-05, los cambios del History que el drain no capturó
    /// (`PersonalLoss`)—; `acceptance`, lo que la persona aceptó perder en este cierre; y
    /// `ownersSessionIsGone`, si de verdad no queda sesión del dueño con la que subir (`CloudSyncRuntime.ownersSessionIsGone`:
    /// el SDK la borró, o la abierta es de otra cuenta).
    ///
    /// 1. **Lo aceptado solo cubre su causa, sus filas y sus cambios sin capturar** (`continuesAfterBlockedUpload`,
    ///    `PersonalLossAcceptance.coversUncaptured`). Aceptado sin sesión, si la persona volvió a entrar y la subida falla por
    ///    la red, bloquea como siempre: esos cambios ya pueden subir.
    /// 2. **El motivo se traduce**: el attest a `.personalAttestUnavailable` —el push-all lo trae como `.attestUnavailable`
    ///    con el testigo del motor personal—, y el resto con `personalPushAllShownReason`.
    /// 3. **Ofrece la pérdida solo si el motivo traducido la abre** (`personalLossCause`).
    /// 4. **Y la sesión que no hay tiene que PROBARSE** (review adversarial del 2026-09-28). Todo 401 del gateway llega como
    ///    `.sessionExpired`, también con la sesión guardada y renovable: un deploy roto o un reloj desfasado lo daría a toda la
    ///    flota, y ofrecer ahí perder los movimientos se llevaría lo que un arreglo del servidor habría subido. Sin la prueba,
    ///    el aviso de siempre —«vuelve a entrar», que no pierde nada—; y lo aceptado sin sesión deja de cubrir.
    static func personalUploadBlockDecision(reason: BlockReason, pending: PersonalLoss,
                                            acceptance: PersonalLossAcceptance?,
                                            ownersSessionIsGone: Bool) -> PersonalUploadBlockDecision {
        if let acceptance, acceptance.cause != .noSession || ownersSessionIsGone, continuesAfterBlockedUpload(
            reason: reason, cause: acceptance.cause, pendingRows: pending.rows, acceptance: acceptance.rows),
           acceptance.coversUncaptured(pending.uncaptured) {
            return .continueWithAcceptedLoss
        }
        let shown = reason == .attestUnavailable ? .personalAttestUnavailable : personalPushAllShownReason(reason)
        guard let cause = personalLossCause(shown), cause != .noSession || ownersSessionIsGone else {
            return .block(shown: shown)
        }
        return .offerLoss(shown: shown, cause: cause)
    }

    /// Lo que la persona aceptó perder al elegir «Cerrar sesión y perderlos», por fila. **Una por outbox**, cada una dentro
    /// de su `CausedLossAcceptance`: la de grupos (`CloudSessionSignOut.acceptedGroupsLoss`) y, en la nube, la de los cambios
    /// personales (`acceptedPersonalLoss`). Cada una se compara solo con las filas de su outbox.
    enum LossAcceptance: Equatable {
        /// Las filas vivas del outbox que había cuando se le enseñó la cifra, por su `clientMutationID`.
        case rows(Set<UUID>)
        /// Se le enseñó sin cifra, porque el recuento falló: lo aceptado cubre cualquier fila.
        case uncounted
    }

    /// ¿Puede el cierre seguir con estas filas sin subir? Sin filas, siempre. Con filas, solo si la persona aceptó perder
    /// ESAS: la comparación es por fila, no por cifra. `acceptance == nil` = no aceptó nada, y el cierre es el de siempre, que
    /// no descarta.
    ///
    /// **Por fila y no por cifra, por un bug de la review adversarial (2026-09-15).** Con la cifra, aceptar 2 cambios
    /// cubría CUALQUIER par: si uno subía entre medias y la persona apuntaba otro sin red durante la espera del export, el
    /// cierre se llevaba el nuevo sin que ningún aviso lo contara. Ahora una fila que no estaba en el aviso lo hace volver.
    ///
    /// `pendingRows == nil` es un recuento que falló: solo lo cubre una aceptación sin cifra.
    static func continuesWithoutUploading(pendingRows: Set<UUID>?, acceptance: LossAcceptance?) -> Bool {
        if let pendingRows, pendingRows.isEmpty { return true }
        guard let acceptance else { return false }
        switch acceptance {
        case .uncounted:
            return true
        case .rows(let accepted):
            guard let pendingRows else { return false }
            return pendingRows.isSubset(of: accepted)
        }
    }

    /// ¿Puede el cierre seguir cuando la subida de ESTE intento acaba de bloquear? Solo si el bloqueo sigue siendo de la
    /// causa por la que se aceptó (`lossCause(reason) == cause`) **y** lo que queda está entre lo aceptado.
    ///
    /// **El motivo cuenta, por un hallazgo de la review adversarial (2026-09-15).** La persona aceptó perder esos cambios
    /// porque el teléfono no podía sincronizar. Si al retomar el cierre el attest ya pasa y la subida falla por otra cosa —un
    /// 5xx, un 403 de cuenta, la sesión caducada—, seguir se llevaría cambios que un reintento habría subido. Con otro motivo
    /// el cierre bloquea como siempre y la aceptación se retira. Los recuentos finales, tras soltar el canal, usan
    /// `continuesWithoutUploading`: ahí ya no hay subida que pueda contradecir lo aceptado.
    ///
    /// **Por causa y no por motivo desde el 2026-09-28**: la sesión caducada llega como `.sessionExpired` al push-all y como
    /// `.cloudSessionExpired` al aviso de la nube, y son el mismo hecho. Aceptada sin sesión, si la persona volvió a entrar y
    /// la subida falla por la red, no sigue: esos cambios ya pueden subir.
    static func continuesAfterBlockedUpload(reason: BlockReason, cause: LossCause, pendingRows: Set<UUID>?,
                                            acceptance: LossAcceptance?) -> Bool {
        lossCause(reason) == cause && continuesWithoutUploading(pendingRows: pendingRows, acceptance: acceptance)
    }

    /// La cifra que el aviso de la pérdida puede enseñar, o `nil` si no hay número honesto: `Int.max` es un recuento
    /// que falló, y un bloqueo nunca lleva cero cambios.
    static func shownLossCount(_ pending: Int) -> Int? {
        pending > 0 && pending < Int.max ? pending : nil
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
        //
        // **`.uploadRetryLater` también, y desde el 2026-09-16 este camino SÍ lo produce.** Se decidió aquí el
        // 2026-09-14, cuando solo nacía en el paso 2 del cierre en la nube, por prudencia: la rama por defecto
        // de esta cadena de `if` es la peor —45 s reintentando— y su significado ya era «esto no se arregla
        // dentro del gesto». Al separarse las dos mitades de lo pasajero (`classify`), esa previsión pasó a ser
        // el arreglo: quien está sin conexión ve el aviso honesto al primer intento en vez de mirar 45 s un
        // «Guardando tus cambios pendientes…» que no describe nada. Lo que SÍ sigue gastando el presupuesto es
        // `.transient`, que ahora es solo el outbox drenando — el caso para el que se escribió (H-2026-07-18-6),
        // donde esperar es exactamente lo que hace que el gesto termine solo.
        //
        // **`.attestUnavailable` también** (2026-09-15): un teléfono que lleva más de un día sin App Attest no lo
        // recupera en 45 s, y reintentar serían ~23 subidas con un 401 seguro antes de un aviso que ya se puede dar.
        //
        // **Y `.personalAttestUnavailable`, que este camino no produce** (2026-09-15): nace en el paso 1 del cierre en la
        // nube. Se decide igual por lo mismo que `.uploadRetryLater`: la rama por defecto es la peor, y su aviso ya dice que
        // esperar no lo arregla.
        //
        // **Y los dos del motor parado** (2026-09-25), que tampoco nacen aquí: esperar 45 s no actualiza la app ni termina
        // una vuelta a iCloud.
        //
        // **Y `.personalUploadRetryLater`** (2026-09-25), que tampoco nace aquí: es `.uploadRetryLater` dicho de tus datos, y
        // se decide igual.
        //
        // **Y los cambios de otra cuenta** (2026-09-28): la sesión de ahora no los sube nunca, así que 45 s de reintentos
        // serían 45 s de «Guardando…» sin guardar nada.
        //
        // **Y el drain personal que no termina** (2026-10-05), que tampoco nace aquí: su aviso existe justo porque esperar no
        // lo arregla.
        //
        // **Y el de grupos, que SÍ nace aquí** (2026-10-05, ticket `groups-stuck-drain-on-a-healthy-phone-says-try-again-later`):
        // el push-all ya probó el atasco con sus reintentos espaciados, y 45 s más de «Guardando…» no lo curan. Hasta ese día
        // salía como `.uploadRetryLater`, que también se enseñaba al momento, así que el tiempo hasta el aviso no cambia.
        if reason == .permanent || reason == .sessionExpired || reason == .channelPaused
            || reason == .uploadRetryLater || reason == .attestUnavailable || reason == .personalAttestUnavailable
            || reason == .syncStoppedNeedsUpdate || reason == .syncStoppedMidMigration
            || reason == .syncStoppedNeedsRelaunch || reason == .personalUploadRetryLater
            || reason == .cloudSessionExpired || reason == .groupsChangesFromAnotherAccount
            || reason == .personalCaptureUnfinished || reason == .groupsCaptureUnfinished {
            return .surfacePermanent
        }
        if elapsedSeconds < budgetSeconds { return .retryAfter(seconds: retryIntervalSeconds) }
        return .surfaceTransient
    }
}
