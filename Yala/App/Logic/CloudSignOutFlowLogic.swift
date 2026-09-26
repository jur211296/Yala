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
        /// 2026-09-15): la excepción a «jamás descartar» del cierre en la nube, acotada a este motivo
        /// (`CloudSessionSignOut.exitDiscardingUnsyncedPersonalChanges`). En las demás pantallas es inerte: ninguna otra
        /// corre el cierre en la nube.
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
        case cloudSessionExpired
        /// **El desasociar cerró la sesión en la nube y la sesión SIGUE guardada** (ticket
        /// `detach-does-not-verify-the-cloud-session-actually-closed`): el llavero no la borró, o un refresco del token en
        /// vuelo la repuso (`CloudAuthService.signOut()` devuelve `false`). El gesto se para ANTES del punto de no retorno,
        /// así que no se soltó nada y reintentar es el gesto entero. Solo lo pone el desasociar. Va aparte porque ningún
        /// otro texto es verdad aquí: no queda nada sin subir (`pendingCount == 0`) y el puente ni se ha mirado. Al final del
        /// `enum` por lo mismo que el anterior.
        case sessionNotClosed

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
            }
        }
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
        case .permanent: return .permanent
        // `.personalAttestUnavailable` es del paso 1, sobre el outbox PERSONAL: este productor, que traduce el de grupos, no
        // lo recibe nunca.
        case .exportUnconfirmed, .bridgeUnreadable, .detachBusy, .personalAttestUnavailable, .sessionNotClosed: return .permanent
        // Los del motor parado y la subida personal que no llegó son del paso 1, sobre el outbox PERSONAL: este productor no
        // los recibe nunca.
        case .syncStoppedNeedsUpdate, .syncStoppedMidMigration, .syncStoppedNeedsRelaunch, .personalUploadRetryLater:
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
    /// El teléfono sin App Attest no pasa por aquí: el propio paso 1 lo traduce a `.personalAttestUnavailable`, con su
    /// oferta. Lo que el motor personal no puede emitir cae en `.permanent`. `switch` exhaustivo para que un motivo nuevo
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
        case .permanent, .exportUnconfirmed, .bridgeUnreadable, .detachBusy, .channelPaused, .attestUnavailable,
             .personalAttestUnavailable, .sessionNotClosed:
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
    /// El outbox a 0 tras un ciclo no prueba que no quede nada: el drain del ciclo no viaja en su outcome, y uno que aborta
    /// (una lectura o un `save` que falla) hace `rollback()` y deja la edición solo en el History. El borrado que viene
    /// detrás se la llevaría sin aviso. Solo se relee en los dos veredictos que un caller deja seguir:
    ///  · `.drained` — el cierre sigue hasta el borrado.
    ///  · `.blocked(_, .attestUnavailable)` — el paso 1 ofrece perder las filas VIVAS que enseña el aviso; una edición fuera
    ///    del outbox no sale en él, y la persona no puede aceptar perder lo que no se le enseñó (el molde es
    ///    `attestBlockAfterRecapture`). Sale como bloqueo sin salida de pérdida, con la cifra del outbox.
    /// El resto de bloqueos no descarta nada y no pregunta: la sonda es una lectura del History, no gratis.
    ///
    /// `true` o `nil` (no se pudo leer) bloquean. La sonda no distingue un drain que abortó de una escritura posterior al
    /// drain —que el drain siguiente captura—, así que el push-all da otra vuelta mientras le quede tope y devuelve esto
    /// solo en la última. **El motivo es `.transient`** —«un momento más, espera unos segundos»—, el del guardado que se
    /// asienta: lo que falló es un guardado de este teléfono, no la subida. La cifra de `.drained` es `Int.max`, el «no se
    /// pudo contar» del repo.
    static func personalVerdictAfterProbe(_ verdict: PushAllVerdict,
                                          uncapturedChanges: () -> Bool?) -> PushAllVerdict {
        switch verdict {
        case .drained:
            return uncapturedChanges() == false ? .drained : .blocked(pendingCount: .max, reason: .transient)
        case .blocked(let pending, .attestUnavailable):
            return uncapturedChanges() == false ? verdict : .blocked(pendingCount: pending, reason: .transient)
        case .blocked:
            return verdict
        }
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

    /// **Un bloqueo por App Attest, después de volver a capturar.** Es el único bloqueo que un caller deja seguir —la
    /// pérdida aceptada compara las filas VIVAS con las que la persona aceptó perder (`continuesAfterBlockedUpload`)—, así
    /// que solo se devuelve como attest si no queda nada fuera del outbox. Si queda, es una subida pendiente sin salida de
    /// pérdida: la persona no puede aceptar perder lo que el aviso no le enseñó (review adversarial del 2026-09-26). La
    /// cifra es la del outbox después de capturar, que es la que el aviso de la pérdida va a enseñar.
    static func attestBlockAfterRecapture(captureCompleted: Bool, livePendingCount: Int,
                                          unrehydratedMirrorCount: Int) -> PushAllVerdict {
        let settled = captureCompleted && unrehydratedMirrorCount == 0
        return .blocked(pendingCount: livePendingCount, reason: settled ? .attestUnavailable : .uploadRetryLater)
    }

    /// **Por qué «Empezar de cero» no borra lo que la subida dejó** (`CloudSessionSignOut.drainGroupsBeforeFreshStart`). Si
    /// solo quedan entradas del espejo que esta sesión no puede subir —sin sesión, el borrado las cuenta todas y la
    /// rehidratación no toca ninguna—, esperar no las sube nunca: lo que las sube es volver a entrar con su cuenta, y eso
    /// dice `.sessionExpired`, el mismo motivo que el push-all ya da a las filas vivas sin sesión. Con filas vivas nuevas, o
    /// entradas de la sesión que no se pudieron rehidratar, otro intento sí lo cura (review adversarial del 2026-09-26).
    static func freshStartResidualReason(livePendingCount: Int, sessionMirrorCount: Int) -> BlockReason {
        livePendingCount == 0 && sessionMirrorCount == 0 ? .sessionExpired : .uploadRetryLater
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

    // MARK: - Las salidas que pierden los cambios que no suben (teléfono sin App Attest, 2026-09-15)

    /// Lo que la persona aceptó perder al elegir «Cerrar sesión y perderlos». **Una por outbox**: la de grupos
    /// (`CloudSessionSignOut.acceptedGroupsLoss`) y, en la nube, la de los cambios personales (`acceptedPersonalLoss`). Cada
    /// una se compara solo con las filas de su outbox.
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

    /// ¿Puede el cierre seguir cuando la subida de ESTE intento acaba de bloquear? Solo si el bloqueo sigue siendo el
    /// teléfono sin App Attest (`.attestUnavailable`) **y** lo que queda está entre lo aceptado.
    ///
    /// **El motivo cuenta, por un hallazgo de la review adversarial (2026-09-15).** La persona aceptó perder esos cambios
    /// porque el teléfono no podía sincronizar. Si al retomar el cierre el attest ya pasa y la subida falla por otra cosa —un
    /// 5xx, un 403 de cuenta, la sesión caducada—, seguir se llevaría cambios que un reintento habría subido. Con otro motivo
    /// el cierre bloquea como siempre y la aceptación se retira. Los recuentos finales, tras soltar el canal, usan
    /// `continuesWithoutUploading`: ahí ya no hay subida que pueda contradecir lo aceptado.
    static func continuesAfterBlockedUpload(reason: BlockReason, pendingRows: Set<UUID>?,
                                            acceptance: LossAcceptance?) -> Bool {
        reason == .attestUnavailable && continuesWithoutUploading(pendingRows: pendingRows, acceptance: acceptance)
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
        if reason == .permanent || reason == .sessionExpired || reason == .channelPaused
            || reason == .uploadRetryLater || reason == .attestUnavailable || reason == .personalAttestUnavailable
            || reason == .syncStoppedNeedsUpdate || reason == .syncStoppedMidMigration
            || reason == .syncStoppedNeedsRelaunch || reason == .personalUploadRetryLater
            || reason == .cloudSessionExpired {
            return .surfacePermanent
        }
        if elapsedSeconds < budgetSeconds { return .retryAfter(seconds: retryIntervalSeconds) }
        return .surfaceTransient
    }
}
