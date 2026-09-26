//
//  MetricsService.swift
//  Yala
//
//  Telemetría propia mínima (2026-07-17, sustituye TelemetryDeck). Tres cosas y nada más:
//   · ping diario (usuarios activos/día — guard local once-per-day, día UTC)
//   · registro (altas/día: onboarding local completado | cuenta nube creada)
//   · canarios (diagnósticos operativos del gate de Modo Nube/Grupos/routing — la
//     condición "canarios en cero" del encendido se lee del dashboard de Analytics Engine)
//
//  Pipeline: evento → MetricsSpool (UserDefaults, kill-tolerante) → MetricsClient →
//  POST /metrics del gateway → Workers Analytics Engine. Sin SDK de terceros.
//  Privacy-first: jamás PII — solo slugs, counts y un install-hash anónimo
//  (SHA-256 truncado del bucketSeed local; el seed crudo nunca sale del device).
//
//  Sin `start()` (tests / release sin bootstrap) TODO es no-op — paridad con el
//  `isConfigured` del viejo TelemetryService. Bajo `-uitest` no se arranca y
//  `-uitest-reset` limpia `metrics.*` (keys pegajosas de `.standard`, lección #34).
//

import CryptoKit
import Foundation

// MARK: - Catálogo de canarios

/// Nombres ESTABLES de los canarios (viajan como `n` del evento `canary` — la query del
/// gate agrupa por este slug; renombrar un case rompe la serie del dashboard).
/// Semántica de cada uno: doc-comments históricos en los call-sites y qa/cloud/README.
enum MetricsCanary: String {
    // CloudKit (store personal espejado + container de grupos)
    case cloudkitExportFailed
    case cloudkitExportSucceeded
    /// Paso 9 · cierre de sesión PRIVADA: la espera del export de iCloud se agotó con cambios sin confirmar
    /// y el aviso de la salida de emergencia se enseñó. `detail` = `pending=N` o `pending=unknown` (sin PII).
    /// Sostenido en muchos dispositivos = el testigo del export no confirma (el autor del espejo o el ancla
    /// no son lo que el diseño supone) — mirar el device-QA del paso 9 antes de culpar a la red.
    case privateSignOutExportUnconfirmed
    /// Paso 9 · la persona eligió «Cerrar sesión igualmente» tras ese aviso: se borró sin confirmar el export.
    case privateSignOutExportDiscarded
    case cloudkitStalledDetected
    case cloudkitDuplicateDetected
    case cloudkitTransferOrphanRepaired
    case cloudkitTransferCollisionDetected
    case cloudkitBudgetCSVMirrorRebuilt
    case budgetFiltersAppearEmpty
    case appEntityShortcutIDsRegenerated
    case tagCatalogRebuilt
    case bridgeVirtualLentTxFailed
    /// El barrido del arranque encontró transacciones puenteadas cuyo gasto/liquidación de grupo ya no
    /// existe y las reparó. Un pico tras un release = la cola de fantasmas que dejó el borrado remoto sin
    /// des-puentear (bug device 2026-08-02), esperada y de una sola vez por usuario. **Sostenido en >0
    /// arranque tras arranque = hay OTRO camino abriendo huérfanas** y el barrido lo está tapando.
    /// `detail` separa liberadas (cuenta real) de borradas (virtuales de sistema).
    case bridgedTxOrphansRepaired
    /// El barrido encontró candidatas —punteros de grupo que no resuelven— pero NO las tocó porque el canal
    /// de su zona no había agotado su entrega (`GroupChannelFreshnessGate`). `detail` lleva el motivo y el
    /// recuento por veredicto, sin PII. **Es la superficie de observación de un gate CLAVADO**: sin él, un
    /// canal apagado durante semanas, un cursor que no lista la zona o un engine de CloudKit que nunca
    /// cierra su ciclo se leerían igual que «no había huérfanas» (`bridgedTxOrphansRepaired` en cero).
    /// Un pico aislado es normal (el barrido corre antes de que el pull termine); SOSTENIDO arranque tras
    /// arranque con el mismo veredicto = el canal de esa cohorte no está entregando.
    case bridgedTxOrphanSweepDeferred
    /// El barrido del arranque retiró grupos de la era CloudKit: los ocultó y soltó su puente personal
    /// (cuenta real → liberada; espejo virtual → borrado). **Un pico tras el release es lo esperado y de
    /// una sola vez por usuario** — es la cola de zombis que dejó el transporte muerto. `detail` separa
    /// grupos ocultados, transacciones liberadas, espejos borrados y borradores tocados, sin PII.
    /// SOSTENIDO en >0 arranque tras arranque = **hay un productor de grupos legacy otra vez**, que es lo
    /// que C4 cerró (`GroupCreateRoutingLogic` sin rama `.cloudKit`), o una zona cuyo fetch falla siempre.
    case legacyGroupsRetired
    /// El wipe de «empiezo de cero» del Welcome LANZÓ y el usuario se quedó con sus datos y sin
    /// entrar al onboarding. Antes este camino era mudo fuera de Debug: la app seguía adelante como
    /// si hubiera borrado, así que un fallo sistemático (store bloqueado, disco lleno, migración a
    /// medias) era invisible en producción. `detail` separa cuál de los dos alerts lo emitió, sin PII.
    /// Misma familia que `attestKeyDiscardedAfterAssertFailure`.
    case freshStartWipeFailed
    /// **El aviso de «tus datos fueron eliminados de iCloud» no llegó a presentarse y se desarmó.** La
    /// red de presentación (`ContentView.armRemoteWipeNoticePresentationNet`) agotó el cap de su ciclo
    /// —unos nueve segundos togglando sin que UIKit montara nada— y soltó el blocker para no dejar el
    /// router retenido el resto de la sesión. Se pierde el aviso, no la sesión.
    ///
    /// **Cualquier valor sostenido >0 es un bug de presentación**, no una cola de release: significa que
    /// algo tapa el anchor de `ContentView` de forma perpetua sin entrar a la matriz de readiness, que
    /// es justo lo que esa matriz existe para impedir. Sin `detail`: no hay nada que separar y el
    /// contexto (qué tapaba) no es observable desde aquí.
    case remoteWipeNoticeNotPresented
    /// **La hoja «Cambiaste de cuenta de iCloud» no llegó a presentarse y se soltó.** Su red de
    /// presentación (`AppleIDCloseNoticeModifier`) agotó el cap del ciclo sin que UIKit montara la hoja, y
    /// soltó la condición viva para no dejar el router retenido. Si el cierre de ese aviso estaba parado en
    /// un bloqueo, lo reconoció al soltar, para que el coordinador no quedara tapiado.
    ///
    /// **Cualquier valor sostenido >0 es un bug de presentación**, hermano de
    /// `remoteWipeNoticeNotPresented`: algo tapa el anchor de `ContentView` sin entrar a la matriz. Se
    /// pierde el aviso, que vuelve en el arranque siguiente, y no la sesión. Sin `detail`.
    case appleIDCloseNoticeNotPresented
    case iCloudRestoreOutcome
    case cloudkitGroupSyncGateHardCap
    case cloudkitGroupSyncPromotedToAuto
    case cloudkitGroupSyncNoImportPromote
    case cloudkitGroupZoneRecovered
    case cloudkitGroupRecordsRecovered
    case cloudkitGroupRecordSaveRejected
    case cloudkitGroupEnqueueDroppedNoEngine
    case groupsIdentityBootMismatch
    /// El gate de boot-saves del store personal (`awaitPersonalImportForBootSave`) difirió ≥3 veces
    /// CONSECUTIVAS sin que ningún save resolviera entremedio — señal SUAVE: los ~8 boot-tasks
    /// concurrentes comparten el contador (resets intercalados), así que el umbral puede alcanzarse
    /// dentro de UN solo boot. Firma de H-2026-07-18-8 (fresh-start wipe: el store ya está entero en
    /// el server → NSPersistentCloudKit no importa nada → `hasCompletedFirstImport` jamás vuelve a
    /// true → todos los boot-saves diferidos para siempre). `detail` desambigua el sub-modo.
    case cloudBootSaveDeferredRepeatedly

    // Modo Nube (motor personal + cuenta + auth)
    case cloudSyncIdentityGapObserved
    case cloudSyncCoherenceGroupPartial
    case cloudSignInProviderMismatch
    case cloudSyncBlockedByAttestUnavailable
    /// El keyId guardado ya no designaba una key usable y se descartó para re-registrar. >0 sostenido =
    /// algo invalida keys en masa; un pico tras un release = usuarios reinstalando (esperado, se auto-cura).
    case attestKeyDiscardedAfterAssertFailure
    /// La sesión ya no sirve y hay cambios esperando. **Desde el 2026-09-16 ya no cuenta** el token que no llega con la
    /// sesión guardada (sin red) ni el 401 `yala_attest_required`: los dos son pasajeros (ticket
    /// `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`). Una bajada de la serie con ese build no dice que
    /// caduquen menos sesiones.
    case cloudSyncBlockedByExpiredSession
    /// El gateway respondió 401 `yala_attest_required` a una ruta del canal personal (`/sync/push`, `/sync/pull`,
    /// `/sync/merkle`, `/prefs/*`). Una vez por proceso y ruta; `detail` = la ruta del cliente (`push`, `pull`,
    /// `merkle`, `prefs-push`, `prefs-pull`). **`merkle` entró el 2026-09-22**
    /// (`reverse-verify-network-bucket-hides-a-definitive-server-no`): hasta ese día ese 401 no se distinguía, y su
    /// desenlace se aplanaba en «red».
    /// Desde el motor de sync, la puerta de attest ya filtró los fallos del TELÉFONO, así que apunta al reloj, a un build que
    /// no manda la cabecera o al servidor: **un pico tras un release es una regresión**. **Salvedad:** la migración, la vuelta
    /// a iCloud y el adopt usan los mismos clientes SIN esa puerta (`CloudMigrationController.makeExecutor` pide el attest con
    /// `try?`), así que desde ahí también cuenta un teléfono sin App Attest que migra o entra a una cuenta existente. No suma
    /// a la racha del teléfono (`GroupsAttestStreakStore`). Nació el 2026-09-16 para que esa regresión no pase un día sin
    /// contarse.
    case cloudSyncAttestRequired
    case cloudSyncOutboxMirrorRehydrated
    case cloudSyncOutboxMirrorDivergence
    case cloudSyncMutationRejected
    case cloudSyncClockReceiveRejected
    case cloudSyncMerkleDivergence
    case cloudCutoverLeaderOrphanReconciled
    case cloudAdoptOrphanReconciled
    /// El adopt se paró por la guarda de linaje (ticket `markerless-adopt-stays-blocked-while-another-device-writes-to-the-account`).
    /// `detail` = `<motivo>|<escritor>`: el motivo es `noSharedRows` (el corpus no comparte ninguna fila con la cuenta) o
    /// `rowsMissing` (comparte, pero faltan filas de la cuenta que podrían tener gemela aquí); el escritor, `active` si el
    /// backend se escribió en las últimas 24 h, `quiet` o `unknown`. **Una vez por proceso y `detail`**: el re-kick de 30 s
    /// repite el mismo bloqueo. `rowsMissing|active` sostenido es el caso del ticket: otro teléfono escribe y este no entra.
    case cloudAdoptLineageBlocked
    /// Un adopt sin marcador de la cuenta y con cobertura total escribió el suyo (el relevo del mismo ticket), y su espera
    /// terminó. `detail` = `exported` (llegó a iCloud antes de armar el apagado del espejo) o `unconfirmed` (venció el plazo
    /// de 10 min sin constar exportado: los teléfonos de después pueden seguir fuera). `value` = segundos de espera. Una vez
    /// por proceso y `detail`. Distinto de cero dice que hay cuentas cuyo líder nunca exportó su marcador.
    case cloudAdoptMarkerRelayed
    /// El adopt con el espejo adjunto y nada local que pida linaje le preguntó a CloudKit si ese iCloud tiene filas que
    /// tendría que probar (ticket `adopt-on-an-empty-store-uploads-what-the-mirror-imports-before-the-relaunch`). `detail` =
    /// `found` (las hay: espera a que el espejo las baje), `none`, `noAccount` o `failed:<motivo>` (no se supo: reintenta).
    /// Una vez por proceso y `detail`. `failed:` sostenido en la flota dice que la sonda no funciona en producción, y deja
    /// esperando a quien adopta así hasta el techo de 72 h.
    case cloudAdoptICloudCorpusChecked
    case cloudConsentAccepted
    case cloudAccountUnavailable
    case cloudAccountReverting
    // C-1 — canal iCloud del cutover
    case cloudCutoverICloudBlocked
    case cloudCutoverMarkerWaived
    case cloudCutoverMarkerStalled
    case cloudCutoverAborted
    case cloudStorageModePairViolation
    // Techo de `reverseUpload` (ticket `reverse-upload-has-no-ceiling-and-no-exit`)
    case cloudReverseUploadWaiting
    case cloudReverseUploadAborted
    // Salida del claim de la reversa (ticket `reverse-claim-rejection-has-no-way-out-in-the-client`)
    case cloudReverseClaimRejected
    // La vuelta a iCloud parada por una sesión que ya no vale, antes de montar el espejo (ticket
    // `reverse-before-mount-stays-stuck-with-an-expired-session`)
    case cloudReverseBlockedByExpiredSession
    /// La vuelta a iCloud SALIÓ de una fase anterior al montaje del espejo y volvió a su origen en modo nube: por su
    /// techo de tiempo o porque la persona tocó «Cancelar y seguir en la nube» (ticket
    /// `reverse-before-mount-has-no-way-to-abandon-the-return`). `detail` = `<fase>|<motivo>`.
    case cloudReversePreMountAborted
    /// Una observación de una fase anterior al montaje que no avanza. Es lo que deja ver un atasco SISTÉMICO —un
    /// 403 en toda la flota— antes de que ningún teléfono llegue a su techo, que son 15 min o 72 h.
    case cloudReversePreMountWaiting
    /// La subida del snapshot de la ida salió de su fase: por su techo o porque la persona canceló (ticket
    /// `snapshot-upload-has-no-ceiling-and-no-way-out`). `detail` = `SnapshotExitReason.rawValue` o `cancelled`.
    case cloudSnapshotUploadAborted
    /// Una observación de la subida del snapshot que no confirmó ninguna página. Deja ver un atasco SISTÉMICO antes de
    /// que ningún teléfono llegue a sus 15 min o sus 72 h.
    case cloudSnapshotUploadWaiting
    /// Uno de los tres pasos de la ida sin cifra que baje —claim (22 %), identidad (35 %), `cutover(.pending)` (80 %)—
    /// salió: por su techo o porque la persona canceló (ticket `forward-migration-steps-have-no-ceiling-and-no-exit`).
    /// `detail` = `<paso>|<ForwardStepExitReason.rawValue o cancelled>`. Desde
    /// `displaced-migration-leader-keeps-uploading-after-a-takeover` también `upload|otherDevice` y `verify|otherDevice`:
    /// la salida del líder que perdió el lease en la subida o en la verificación.
    case cloudForwardStepAborted
    /// El líder volvió al reconcile de `done` —después del cutover— y el lease ya era de otro dispositivo (ticket
    /// `leader-displaced-after-the-cutover-pushes-its-residual-in-the-reconcile`). `detail` = `joined` (el otro cerró la
    /// migración y este teléfono se une) o `retaken` (el otro dejó caducar el lease y este vuelve a liderar). La espera
    /// mientras el otro lidera no tiene canario: se repetiría en cada re-kick. Distinto de cero dice que el relevo tras el cutover pasa de verdad.
    case cloudPostCutoverLeaseLost
    /// El espejo de iCloud le cambió por debajo la identidad a filas que la ida de ESTE teléfono ya había identificado, y
    /// se le devolvió la suya (ticket `displaced-leader-late-identity-export-can-rekey-the-relief-corpus`). `detail` = el
    /// tipo de entidad, `value` = cuántas. Distinto de cero mide lo que el ticket no pudo: que CloudKit le da la razón a la
    /// exportación tardía de un líder desplazado.
    case cloudRelayIdentityRestored
    /// Un borrado de una fila que el espejo había re-identificado salió con la identidad que el backend conoce, no con la del
    /// líder (ticket `relay-row-rekeyed-then-deleted-tombstones-the-leader-identity`). `detail` = el tipo de entidad. Sin él,
    /// el movimiento borrado reaparecía en los otros teléfonos.
    case cloudRelayTombstoneTranslated
    /// El primer drain tras el remonte de un adopt no tradujo lo que el espejo importó TARDE de filas que el backend ya
    /// conocía (ticket `adopt-window-late-imports-overwrite-newer-cloud-edits`). `detail` = el tipo de entidad, `value` =
    /// cuántos cambios. Distinto de cero mide lo que el ticket solo pudo inferir: que el import llega después del paso 3 del
    /// adopt, y cuántas ediciones de la nube se habrían pisado.
    case cloudAdoptLateImportSkipped
    /// Una observación de uno de esos tres pasos que no avanzó. Deja ver un atasco SISTÉMICO antes de que ningún teléfono
    /// llegue a sus 15 min o sus 72 h.
    case cloudForwardStepWaiting
    /// «Migrar a la nube» se paró sin escribir nada porque la cuenta elegida no puede recibir la migración (ticket
    /// `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`). `detail` = `<motivo>@<dónde>`: el motivo es
    /// `personal_data`, `other_groups_account`, `returned_to_icloud`, `fresh_start_session` o `unchecked`, y el sitio
    /// `gate` (antes del claim) o `claim`. Cuenta INTENTOS, no personas: cada toque que se para emite uno. Hasta ese día esos intentos mezclaban
    /// los datos en silencio.
    case cloudMigrationExistingAccountBlocked
    case accountDeletionCompleted
    case accountDeletionFailed
    case siwaExchangeFailed
    case siwaRevokeFailed
    case googleRevokeFailed
    case relaunchNetExhausted

    // Grupos→backend
    case groupMerkleDivergence
    case groupPushRejected
    case groupPushTokenRegisterFailed
    case groupJoinIntentPersisted
    case groupJoinIntentReconciled
    case groupJoinIntentDeferred
    case groupJoinIntentExpired
    case groupJoinFailed
    case groupLegacyRebindFailed
    /// El barrido del arranque retiró del outbox/espejo tombstones de `split_groups` que un build anterior
    /// al guard del 2026-08-02 dejó ENCOLADOS. Empujar uno borra el grupo para TODOS sus miembros
    /// (server-side la identidad de `split_groups` es la ZONA, no la fila). Un pico tras el release = la
    /// cola real de aquel bug, esperada y de UNA sola vez por device. **Sostenido en >0 = el camino de
    /// emisión volvió a abrirse** y el barrido lo está tapando. `detail` separa filas de archivos del espejo.
    case groupsOutboxGroupTombstonePurged
    /// El pull dejó de listar una zona backend que el device tiene localmente ⇒ al usuario lo sacaron del
    /// grupo (o le rechazaron la solicitud) y se dispara la limpieza local. Es un evento NORMAL y esperado:
    /// lo que se vigila es su ausencia total conviviendo con reportes de «grupo fantasma», y su exceso en un
    /// mismo device (el gateway dejando de listar grupos vivos). Único rastro en la flota de un camino que
    /// BORRA datos locales — `value` = zonas de esa página. Sin PII.
    case groupsMembershipLost
    /// C1 · Hay un consent de Grupos ACEPTADO que la cuenta todavía no tiene registrado. `value` = la edad
    /// en HORAS del intent, `detail` = intentos consumidos. Se emite en CADA retome y ANTES de cualquier
    /// early-return, a propósito: sin eso, «hay intents frenados» y «no había ninguno» se leen igual en el
    /// dashboard (misma lección que `bridgedTxOrphanSweepDeferred`). Picos cortos son normales (aceptar sin
    /// red); **edades que CRECEN arranque tras arranque = el registro no está llegando**, y es el único
    /// aviso de que el Art. 7.1 se está quedando sin prueba. ⚠️ El spool tiene cap 50 con drop-oldest, así
    /// que un canario puede caer por presión de cola: es observación, no garantía de entrega.
    case groupsConsentPending
    /// C1 · El servidor RECHAZÓ el registro del consent con un error permanente (400). No es una razón para
    /// tirar la prueba —el intent se conserva— sino un bug NUESTRO: firma del RPC, fecha fuera de rango o
    /// versión imposible. >0 sostenido = el registro legal de esa cohorte no se está creando.
    case groupsConsentRegistrationRejected

    // Batch "salir de todos mis grupos" (D10)
    case groupBatchLeaveStarted
    case groupBatchLeaveDeferred      // paso diferido por import no-quiescente (resume lo retoma)
    case groupBatchLeaveExpired       // entry .pending vencida (TTL) sin procesar
    case groupBatchLeaveNeedsDecision // grupo que cae a "necesitan tu decisión"
    case groupBatchLeaveFailed        // transfer/leave falló permanente
    case groupBatchLeaveStopped       // el usuario pulsó «Detener» (value = grupos sin procesar)

    // Routing (F9)
    case routingIntentSuperseded
    case routingIntentDeferred
    case routingReadinessBlocked
    case routingDrainHoldSustained
    case routingWelcomeChainSuperseded
    case inviteReEmittedFromStore
    case invitePendingExpired

    // Reparador de tasas provisionales (arranque)
    /// El barrido de arranque recorrió la cola de transacciones con tasa provisional y **no curó
    /// ninguna**. `value` = tamaño de la cola; `detail` separa el intento estéril (`futile`) del
    /// arranque que ya ni lo intenta porque nada cambió desde el anterior (`skipped`).
    ///
    /// **Es la superficie de observación que faltaba.** El log de este barrido vivía dentro de
    /// `if updatedCount > 0`, así que una cola atascada —el estado que este canario nombra— era el
    /// único que no imprimía nada: cuanto peor iba, más callaba. Un pico aislado es normal (el barrido
    /// corre antes de que lleguen las tasas del día). SOSTENIDO arranque tras arranque con la misma
    /// cola = hay una población que ninguna tasa disponible puede convertir, y el proveedor no cubre
    /// esa divisa en esas fechas: la cola no se va a vaciar sola y necesita mirarse.
    case fxRepairQueueStuck

    // Asociación de la cuenta de grupos (paso 10 del rediseño de sesiones)
    /// El usuario desasoció su cuenta de grupos de una sesión privada y el puente personal se soltó.
    /// `detail` lleva la salida que eligió (`keep` / `remove`) y los recuentos, sin PII.
    ///
    /// **Lo que hay que mirar es el REPARTO, no el total**: `remove` sostenido y muy por encima de `keep`
    /// significa que la gente no entiende que conservar deja el dinero en su Panel, y el copy de la
    /// confirmación es lo que hay que arreglar. Un `released=0|deleted=0` con la salida `keep` es otra
    /// cosa: el puente no tenía nada que soltar, o el fetch falló cerrado.
    case groupsAssociationDetached
    /// **El desasociar cerró la sesión en la nube pero el borrado local LANZÓ**: los grupos siguen en el
    /// teléfono y la cuenta sigue asociada, que es lo coherente. La persona ve el aviso y puede reintentar.
    /// `detail` lleva la salida que eligió para el puente, sin PII.
    ///
    /// Hermano exacto de `freshStartWipeFailed`, y por el mismo motivo está fuera de `#if DEBUG`: hasta el
    /// 2026-09-11 este camino era MUDO en producción —la pantalla decía que la cuenta estaba suelta sobre
    /// unos grupos enteros— así que un fallo sistemático (store bloqueado, disco lleno, migración a medias)
    /// no dejaba ni una señal. **Cualquier valor sostenido >0 es un bug**, no una cola de release: a
    /// diferencia del suyo, aquí no hay corpus heredado que explique un pico.
    case groupsDetachPurgeFailed
    /// **El desasociar cerró la sesión en la nube y la sesión SIGUE guardada** (el llavero no la borró, o un refresco del
    /// token en vuelo la repuso). El gesto se para antes de soltar nada y la persona reintenta; `detail` lleva la salida
    /// que eligió para el puente, sin PII. Ticket `detach-does-not-verify-the-cloud-session-actually-closed`, que no pudo
    /// medir si pasa: **es la medición**. Fuera de `#if DEBUG` por lo mismo que su vecino.
    case groupsDetachSessionSurvived
    /// **«Empezar de cero» se paró porque quedaban cambios de grupos sin subir** (ticket
    /// `fresh-start-wipe-kills-unsent-group-writes-silently`). Hasta el 2026-09-26 el borrado se los llevaba en silencio;
    /// ahora sube primero y, si no drena, no borra. `detail` = `reason=<motivo> pending=N|unknown`, sin PII. Cuenta
    /// BLOQUEOS, no personas: cada reintento que vuelve a parar suma otro. Fuera de `#if DEBUG` por lo mismo que sus
    /// vecinos.
    case freshStartBlockedByGroupWrites

    // Teléfono que no consigue App Attest (ticket `groups-phone-that-never-attests-is-told-to-retry-forever`)
    /// **La racha de App Attest del teléfono se volvió terminal**: 24 h y al menos 3 rechazos sin un solo acierto
    /// (`GroupsAttestVerdictLogic`). Una vez por racha y por teléfono. `detail` = `rejections=N hours=H`, sin PII. **Es la
    /// medición que el ticket no tenía**: cuántos teléfonos no recuperan el attest. Un pico tras un release o una rotación
    /// del secreto del gateway apunta al servidor, no a los teléfonos. Nació con el 401 `yala_attest_required` de Grupos, y
    /// desde el 2026-09-15 la racha la escribe también la puerta de attest del motor personal
    /// (`AttestSyncGate.countsTowardAttestStreak`): en la nube cuenta teléfonos aunque no usen grupos. El nombre se queda,
    /// porque renombrar un case rompe la serie del dashboard.
    case groupsAttestTerminal
    /// Un CIERRE DE SESIÓN se bloqueó con ese veredicto y dejó ofrecida la salida que pierde los cambios de grupos.
    /// `detail` = `pending=N` o `pending=unknown`. Cuenta OFERTAS, no personas: el invitado del Welcome no ve el botón y
    /// cada nuevo aviso del mismo cierre suma otra.
    case groupsSignOutAttestUnavailable
    /// El cierre siguió sin subir esos cambios, con la persona conforme: se pierden con el borrado del arranque.
    /// `detail` = `pending=N` o `pending=unknown`. Frente al anterior, dice cuántos eligieron salir.
    case groupsSignOutAttestDiscarded

    // Tus datos en la nube con un teléfono sin App Attest (ticket `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`)
    /// Un cierre de sesión en la NUBE se bloqueó en los cambios PERSONALES de un teléfono con la racha terminal y dejó
    /// ofrecido el aviso que exporta los movimientos o los pierde. `detail` = `pending=N` o `pending=unknown`. Cuenta
    /// OFERTAS, no personas: cada nuevo aviso del mismo cierre suma otra.
    case cloudSignOutAttestUnavailable
    /// Desde ese aviso se generó el archivo con todos los movimientos. `detail` = `rows=N`, sin PII. Frente al anterior,
    /// dice cuántos se llevaron una copia antes de decidir.
    case cloudSignOutAttestExported
    /// El cierre siguió sin subir esos cambios personales, con la persona conforme: se pierden con el borrado del arranque.
    /// `detail` = `pending=N` o `pending=unknown`. Frente al primero, dice cuántos eligieron salir.
    case cloudSignOutAttestDiscarded
}

// MARK: - Servicio

@MainActor
enum MetricsService {

    // MARK: Estado

    private static var isStarted = false
    private static var client: MetricsClient?
    private static var defaults: UserDefaults = .standard
    private static var trackedOnceKeys: Set<String> = []
    private static var drainTask: Task<Void, Never>?

    static let lastPingDayKey = "metrics.lastPingDay"
    static let cloudRegisteredKeyPrefix = "metrics.cloudRegistered."

    // MARK: Arranque

    /// Lo llama SOLO AppBootstrapper (cold launch). Sin start, todo el servicio es no-op
    /// (tests jamás tocan `.standard` ni la red). Bajo `-uitest` no arranca.
    static func start(
        client: MetricsClient? = nil,
        defaults: UserDefaults = .standard
    ) {
        guard !UITestHooks.isActive else { return }
        Self.client = client ?? MetricsClient()
        Self.defaults = defaults
        isStarted = true
    }

    /// Higiene de `-uitest-reset` y de tests: limpia TODAS las keys `metrics.*`
    /// (spool + guard del día + one-shots de registro cloud) — la clase exacta de
    /// keys pegajosas de `.standard` del SERIO de #34.
    static func resetLocalState(_ defaults: UserDefaults = .standard) {
        MetricsSpool.clear(defaults)
        defaults.removeObject(forKey: lastPingDayKey)
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(cloudRegisteredKeyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    /// Solo para tests del servicio (aislar `.standard` y resetear el estado estático).
    static func _testReset() {
        isStarted = false
        client = nil
        defaults = .standard
        trackedOnceKeys = []
        drainTask?.cancel()
        drainTask = nil
    }

    // MARK: KPI 1 — usuarios activos/día

    /// Ping diario dedupeado client-side (día UTC — `MetricsPingLogic`). Se llama en
    /// cold launch (bootstrap) y en cada foreground (`handleBecameActive`); solo el
    /// primero del día encola. El drain corre igual en ambos (recoge canarios pendientes).
    static func dailyActivePingIfNeeded(now: Date = .now) {
        guard isStarted else { return }
        if MetricsPingLogic.shouldPing(lastPingDay: defaults.string(forKey: lastPingDayKey), now: now) {
            defaults.set(MetricsPingLogic.dayString(for: now), forKey: lastPingDayKey)
            MetricsSpool.enqueue(.ping(), defaults: defaults)
        }
        kickDrain()
    }

    // MARK: KPI 2 — registros/día

    /// Alta LOCAL: onboarding completado. `mode` = full | groupsOnly | groupInvite.
    /// Un re-onboarding tras wipe legítimo cuenta de nuevo (semántica aceptada: nuevo alta).
    static func localRegistrationCompleted(mode: String) {
        guard isStarted else { return }
        MetricsSpool.enqueue(.register(kind: "local", detail: mode), defaults: defaults)
        kickDrain()
    }

    /// Alta NUBE: el claim devolvió `created` (cuenta backend NUEVA). One-shot persistido
    /// por userID: el re-claim del MISMO líder colapsa a `created` (AccountClaimDecision)
    /// y una migración reanudada re-emitiría → doble conteo. `detail` = migration | bornCloud.
    static func cloudRegistrationCompletedIfFirst(userID: String, detail: String) {
        guard isStarted else { return }
        let key = cloudRegisteredKeyPrefix + userID
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        MetricsSpool.enqueue(.register(kind: "cloud", detail: detail), defaults: defaults)
        kickDrain()
    }

    // MARK: Canarios — núcleo

    static func canary(_ name: MetricsCanary, detail: String? = nil, value: Double = 1) {
        guard isStarted else { return }
        #if DEBUG
        print("MetricsService: [canary] \(name.rawValue) detail=\(detail ?? "-") value=\(value)")
        #endif
        MetricsSpool.enqueue(.canary(name: name.rawValue, detail: detail, value: value), defaults: defaults)
        kickDrain()
    }

    /// Canario dedupeado por sesión de proceso (clave compuesta) — paridad `trackOnce`.
    static func canaryOnce(_ name: MetricsCanary, key: String, detail: String? = nil, value: Double = 1) {
        let compositeKey = "\(name.rawValue):\(key)"
        guard !trackedOnceKeys.contains(compositeKey) else { return }
        trackedOnceKeys.insert(compositeKey)
        canary(name, detail: detail, value: value)
    }

    // MARK: Drain

    /// Vacía el spool en batches (cap del wire: 25). Un solo drain en vuelo; el loop
    /// re-lee el spool en cada vuelta, así que eventos encolados durante un envío
    /// salen en la siguiente. `.retry` (offline/5xx) corta — el próximo trigger
    /// (foreground/boot/evento nuevo) reintenta. `.dropped` (4xx) TAMBIÉN retira:
    /// reintentar un body que el server rechaza atascaría la cabeza para siempre.
    static func kickDrain() {
        guard isStarted, drainTask == nil, let client else { return }
        let defaults = Self.defaults
        drainTask = Task { @MainActor in
            defer { drainTask = nil }
            while true {
                let batch = Array(MetricsSpool.pending(defaults).prefix(25))
                guard !batch.isEmpty else { return }
                let outcome = await client.send(install: installHash, app: appVersion, events: batch)
                switch outcome {
                case .delivered:
                    MetricsSpool.removeFirst(batch.count, defaults: defaults)
                    MetricsBreadcrumb.drained(count: batch.count)
                case .dropped:
                    MetricsSpool.removeFirst(batch.count, defaults: defaults)
                case .retry:
                    return
                }
            }
        }
    }

    // MARK: Identidad anónima

    /// SHA-256 del bucketSeed local, truncado a 16 hex. El seed crudo (cohortes de
    /// rollout, `cloudSync.remoteConfig.bucketSeed`) JAMÁS sale del device; este hash
    /// no es reversible ni enlazable a cuenta. Sirve para `count(DISTINCT)` del DAU
    /// y como sampling key de Analytics Engine.
    static var installHash: String {
        let seed = CloudRemoteConfigStore.bucketSeed(defaults)
        let digest = SHA256.hash(data: Data(seed.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    private static var appVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

// MARK: - Wrappers typed preservados (firmas idénticas al viejo TelemetryService)
// Los doc-comments completos de cada canario viven en el historial de TelemetryService
// (git) y en los call-sites; aquí solo el mapeo a wire (detail/value).

extension MetricsService {

    /// Duplicado CloudKit observado; dedup por (model, context, keySuffix) — el suffix es local-only.
    static func cloudkitDuplicateDetected(
        model: String,
        count: Int,
        context: DuplicateDetectionContext,
        keySuffix: String
    ) {
        canaryOnce(
            .cloudkitDuplicateDetected,
            key: "\(model):\(context.rawValue):\(keySuffix)",
            detail: "\(model)|\(context.rawValue)",
            value: Double(count)
        )
    }

    static func routingIntentSuperseded(droppedID: String, by incomingID: String) {
        canary(.routingIntentSuperseded, detail: "\(droppedID)>\(incomingID)")
    }

    static func routingIntentDeferred(intentID: String, reason: String) {
        canary(.routingIntentDeferred, detail: "\(intentID)|\(reason)")
    }

    // MARK: C-1 — canal iCloud del cutover

    /// La precondición del canal iCloud impidió entrar al cutover. `detail` = `ICloudChannelVerdict.rawValue`.
    static func cloudCutoverICloudBlocked(verdict: String) {
        canary(.cloudCutoverICloudBlocked, detail: verdict)
    }

    /// Waiver del gate de export del marcador (sin cuenta iCloud y sin huella CloudKit).
    static func cloudCutoverMarkerWaived() {
        canary(.cloudCutoverMarkerWaived)
    }

    /// El marcador del cutover sigue sin exportar. Se emite en CADA observación: un valor sostenido y alto
    /// aquí es la señal de un atasco SISTÉMICO (p.ej. el record type sin desplegar a CloudKit Production),
    /// visible mucho antes de que ningún device agote su presupuesto.
    static func cloudCutoverMarkerStalled(verdict: String) {
        canary(.cloudCutoverMarkerStalled, detail: verdict)
    }

    /// El presupuesto del paso 4 se agotó → el cutover abortó y el device volvió a `.icloud`.
    static func cloudCutoverAborted(verdict: String) {
        canary(.cloudCutoverAborted, detail: verdict)
    }

    // MARK: Techo de `reverseUpload` (ticket `reverse-upload-has-no-ceiling-and-no-exit`)

    /// Una observación de la espera de «Volver a iCloud». `detail` separa «va lento» de «no avanza»:
    /// `advancing|<causa>` cuando la cifra de pendientes acaba de bajar, y
    /// `stalled|<tramo sin avanzar>|<tramo de la causa>|<causa>` cuando no. Un `stalled` sostenido en tramos largos en
    /// muchos teléfonos es un mirror que no exporta para nadie.
    ///
    /// Dedupe por PROCESO y por `detail` (`canaryOnce`): la pantalla re-observa cada 30 s y el spool guarda 50
    /// eventos FIFO, así que emitirlo en cada observación —como `cloudCutoverMarkerStalled`— tiraría el resto.
    static func cloudReverseUploadWaiting(
        advancing: Bool, stalledSeconds: Double, causeStalledSeconds: Double?, blocker: String
    ) {
        let detail = reverseUploadWaitingDetail(
            advancing: advancing, stalledSeconds: stalledSeconds, causeStalledSeconds: causeStalledSeconds,
            blocker: blocker)
        canaryOnce(.cloudReverseUploadWaiting, key: detail, detail: detail)
    }

    /// Detalle del canario de la espera. Tramos cerrados por arriba y por el presupuesto: los 15 min del techo
    /// corto y las 72 h del largo son sus bordes.
    ///
    /// **Desde el 2026-09-23 son DOS tramos** (ticket `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last`,
    /// la forma de `cloudReversePreMountWaiting`): el de AVANCE y el de la CAUSA. Con solo el de avance,
    /// `stalled|1h_24h|icloudUnusable` se leería como horas con la cuenta inutilizable cuando el motivo lleva doce segundos
    /// y las horas eran sin cuenta — exactamente lo que ese ticket separa. El tramo de causa es `-` cuando el motivo no es
    /// definitivo (`icloudOff`, `unknown`): ahí no corre ningún reloj de causa. **La serie cambia de valores con este
    /// build**: `stalled|<tramo>|<causa>` pasa a tener cuatro segmentos.
    nonisolated static func reverseUploadWaitingDetail(
        advancing: Bool, stalledSeconds: Double, causeStalledSeconds: Double?, blocker: String
    ) -> String {
        guard !advancing else { return "advancing|\(blocker)" }
        let causeBucket = causeStalledSeconds.map(reversePreMountBucket) ?? "-"
        return "stalled|\(reversePreMountBucket(stalledSeconds))|\(causeBucket)|\(blocker)"
    }

    /// La espera de «Volver a iCloud» terminó sin llegar a iCloud y la reversa volvió a la nube.
    /// `detail` = `ReverseAbortReason.rawValue`: `cancelled` lo pidió la persona; el resto, el techo. Con una excepción
    /// desde el 2026-09-23: una salida journaleada como `stalled` por el techo CORTO, con motivos definitivos turnándose,
    /// sale como `mixedCauses` (`MigrationRunner.reverseUploadExitDetail`), así que `stalled` sigue siendo solo las 72 h.
    static func cloudReverseUploadAborted(reason: String) {
        canary(.cloudReverseUploadAborted, detail: reason)
    }

    /// El claim de «Volver a iCloud» no se concedió y la reversa volvió a la nube sin empezar (ticket
    /// `reverse-claim-rejection-has-no-way-out-in-the-client`). `detail` = el motivo del servidor (`not_complete`,
    /// `migration_in_progress`, `no_profile`, `other_leader`): un `not_complete` sostenido es el 2.º dispositivo de una
    /// cuenta ya revertida (`reverse-exit-on-a-reverted-account-rejects-the-retry`).
    static func cloudReverseClaimRejected(reason: String) {
        canary(.cloudReverseClaimRejected, detail: reverseClaimRejectedDetail(serverReason: reason))
    }

    /// La vuelta a iCloud se paró porque la sesión de la nube ya no vale, en una fase anterior al montaje del espejo
    /// (ticket `reverse-before-mount-stays-stuck-with-an-expired-session`). `detail` = la fase
    /// (`claim`/`drain`/`verify`/`freeze`), un literal del propio build: no viene de la red, así que no necesita el
    /// acotado a forma de código que sí lleva `cloudReverseClaimRejected`.
    ///
    /// **Una vez por proceso y fase** (`canaryOnce`): el re-kick de 30 s de la pantalla choca con la misma sesión
    /// caducada cada medio minuto, y contado por observación una tarde mirando la barra llenaría el spool con un
    /// único hecho. Cuenta TELÉFONOS que se atascan ahí, no cuántas veces lo reintentan.
    static func cloudReverseBlockedByExpiredSession(phase: String) {
        canaryOnce(.cloudReverseBlockedByExpiredSession, key: phase, detail: phase)
    }

    /// La vuelta a iCloud salió de una fase ANTERIOR al montaje del espejo (ticket
    /// `reverse-before-mount-has-no-way-to-abandon-the-return`). `detail` = `<fase>|<motivo>`, los dos literales del
    /// propio build —`claim`/`drain`/`verify`/`freeze` y un `ReverseAbortReason.rawValue`—, así que no necesitan el
    /// acotado a forma de código que sí lleva `cloudReverseClaimRejected`, cuyo motivo viene de la red.
    ///
    /// Por OBSERVACIÓN y no `canaryOnce`: una salida ocurre una vez por intento, no en cada re-kick de 30 s. Lo que
    /// sí se repite —chocar con la misma sesión caducada media hora— lo cuenta `cloudReverseBlockedByExpiredSession`,
    /// que por eso sí dedupea.
    static func cloudReversePreMountAborted(phase: String, reason: String) {
        canary(.cloudReversePreMountAborted, detail: "\(phase)|\(reason)")
    }

    /// Una observación de una fase ANTERIOR al montaje que sigue parada. `detail` = `<fase>|<tramo>|<causa>`, con
    /// la causa `stop_<blocker>` cuando el paso chocó con algo que no se arregla esperando y `waiting` cuando es red
    /// o sesión.
    ///
    /// **El prefijo era `server_` hasta el 2026-09-22 y se renombró con
    /// `reverse-verify-network-bucket-hides-a-definitive-server-no`**: ese día entraron dos motivos que NO son la
    /// palabra del servidor —`localFailure`, un `fetch` de SwiftData que lanzó, y `unknownVerdict`, un motivo que
    /// este build no sabe leer— y seguir llamándolos `server_` habría hecho que quien lee el dashboard contara
    /// averías del teléfono como incidentes del backend, que es justo lo contrario de para lo que existe la serie.
    /// **La serie cambia de valores con ese build**: los tres viejos pasan de `server_x` a `stop_x`.
    ///
    /// Existe por la misma razón que su hermano del marcador: **un fallo sistémico se ve en la flota mucho antes de
    /// que ningún teléfono degrade**. Sin esta serie, un 403 que afectara a toda la población sería invisible 15 min
    /// (techo corto) o 72 h (largo), que es justo lo que tarda en dejar de ser invisible por sí solo.
    ///
    /// Dedupe por PROCESO y por `detail` (`canaryOnce`, molde de `cloudReverseUploadWaiting`): el re-kick de 30 s de
    /// la pantalla re-observa lo mismo cada medio minuto y el spool guarda 50 eventos FIFO.
    static func cloudReversePreMountWaiting(
        phase: String, stalledSeconds: Double, causeStalledSeconds: Double, blocker: String?
    ) {
        let detail = reversePreMountWaitingDetail(
            phase: phase, stalledSeconds: stalledSeconds,
            causeStalledSeconds: causeStalledSeconds, blocker: blocker)
        canaryOnce(.cloudReversePreMountWaiting, key: detail, detail: detail)
    }

    /// Detalle de esa observación.
    ///
    /// **Desde el 2026-09-22 son DOS tramos, porque son dos relojes y cada uno gobierna un techo** (ticket
    /// `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last`): el de la FASE, contra el que corren
    /// las 72 h, y el de la CAUSA. **Publicar uno solo dejaba ciega la mitad del mecanismo**, y las dos mitades se
    /// miden:
    ///  · con solo el de la fase, `stop_localFailure|1h_24h` se leería como tres horas de avería local cuando la
    ///    avería lleva doce segundos y las tres horas eran de red;
    ///  · con solo el de la causa, un teléfono con dos motivos alternándose publica `lt_15m` en cada observación y,
    ///    con el dedupe por proceso, la flota ve **un** evento diciendo que no pasa nada — justo el atasco sistémico
    ///    que esta serie existe para enseñar antes de que nadie agote su techo.
    ///
    /// **Desde `alternating-definitive-causes-never-reach-the-short-ceiling` los 15 min ya no corren contra el
    /// tramo de causa**, sino contra un tercer reloj, el de «cualquier motivo definitivo», que no se reinicia al
    /// cambiar de motivo. La serie sigue publicando el de causa a propósito: es el que deja reconocer en la flota la
    /// alternancia —tramo de fase creciendo y de causa siempre en `lt_15m`—, y cambiarle el significado a un segmento
    /// por tercera vez en tres días rompería la lectura de la serie.
    ///
    /// El tramo de causa es `-` cuando la observación no trae motivo: ahí no hay reloj de causa que contar, y un
    /// `lt_15m` constante sería ruido que se lee como dato. La forma es fija de cuatro segmentos para que se pueda
    /// partir sin adivinar. **La serie cambia de valores con este build**, un día después del cambio anterior: una
    /// caída del tramo alto en `stop_*` es el arreglo, no una mejora de la flota.
    nonisolated static func reversePreMountWaitingDetail(
        phase: String, stalledSeconds: Double, causeStalledSeconds: Double, blocker: String?
    ) -> String {
        let causeBucket = blocker == nil ? "-" : reversePreMountBucket(causeStalledSeconds)
        return "\(phase)|\(reversePreMountBucket(stalledSeconds))|\(causeBucket)|"
            + "\(blocker.map { "stop_\($0)" } ?? "waiting")"
    }

    /// Los tramos, compartidos por los dos relojes. Reusa los de la espera de la subida: los techos de esta etapa
    /// son los mismos números, así que los bordes valen igual y las series se leen con la misma escala.
    nonisolated static func reversePreMountBucket(_ seconds: Double) -> String {
        switch seconds {
        case ..<900: return "lt_15m"
        case ..<3_600: return "15m_1h"
        case ..<86_400: return "1h_24h"
        case ..<259_200: return "24h_72h"
        default: return "gte_72h"
        }
    }

    /// Una subida del snapshot de la ida salió de su fase (ticket `snapshot-upload-has-no-ceiling-and-no-way-out`).
    /// Desde `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling` la serie gana un valor,
    /// `mixedCauses`: el techo corto con motivos turnándose. Tiene su propio valor para que `stalled` siga significando
    /// solo las 72 h sin avanzar.
    static func cloudSnapshotUploadAborted(reason: String) {
        canary(.cloudSnapshotUploadAborted, detail: reason)
    }

    /// Una observación de la subida del snapshot que no avanzó. `detail` = `<tramo de avance>|<tramo de causa>|<causa>`,
    /// la forma de `cloudReversePreMountWaiting` sin la fase (aquí solo hay una): `-` en el tramo de causa cuando la
    /// observación no trae motivo, y `stop_<blocker>` o `waiting` en la causa. Los tramos son los mismos, porque los
    /// techos son los mismos números. Dedupe por PROCESO y por `detail`, por el re-kick de 30 s de la pantalla.
    ///
    /// **Desde `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling` los 15 min ya no corren
    /// contra el tramo de causa**, sino contra el reloj de «cualquier motivo definitivo», que no se reinicia al cambiar de
    /// motivo. La serie sigue publicando el de causa a propósito, como `cloudReversePreMountWaiting`: es el que deja
    /// reconocer en la flota la alternancia —avance creciendo y causa siempre en `lt_15m`—, y cambiarle el significado a
    /// un segmento rompería la lectura de la serie.
    static func cloudSnapshotUploadWaiting(stalledSeconds: Double, causeStalledSeconds: Double, blocker: String?) {
        let detail = snapshotUploadWaitingDetail(
            stalledSeconds: stalledSeconds, causeStalledSeconds: causeStalledSeconds, blocker: blocker)
        canaryOnce(.cloudSnapshotUploadWaiting, key: detail, detail: detail)
    }

    nonisolated static func snapshotUploadWaitingDetail(
        stalledSeconds: Double, causeStalledSeconds: Double, blocker: String?
    ) -> String {
        let causeBucket = blocker == nil ? "-" : reversePreMountBucket(causeStalledSeconds)
        return "\(reversePreMountBucket(stalledSeconds))|\(causeBucket)|\(blocker.map { "stop_\($0)" } ?? "waiting")"
    }

    /// La salida de uno de los tres pasos de la ida sin cifra que baje, o del lease perdido (`upload`/`verify`).
    /// `detail` = `<paso>|<motivo>`.
    static func cloudForwardStepAborted(step: String, reason: String) {
        canary(.cloudForwardStepAborted, detail: "\(step)|\(reason)")
    }

    /// El reconcile de `done` sin el lease. `detail` = `joined` | `retaken`.
    static func cloudPostCutoverLeaseLost(outcome: String) {
        canary(.cloudPostCutoverLeaseLost, detail: outcome)
    }

    static func cloudRelayIdentityRestored(entity: String, count: Int) {
        canary(.cloudRelayIdentityRestored, detail: entity, value: Double(count))
    }

    static func cloudRelayTombstoneTranslated(entity: String) {
        canary(.cloudRelayTombstoneTranslated, detail: entity)
    }

    static func cloudAdoptLateImportSkipped(entity: String, count: Int) {
        canary(.cloudAdoptLateImportSkipped, detail: entity, value: Double(count))
    }

    /// Una observación de uno de esos tres pasos que no avanzó. `detail` = `<paso>|<tramo de avance>|<tramo de causa>|<causa>`,
    /// la forma de `cloudReversePreMountWaiting` con el paso de la ida: `-` en el tramo de causa cuando la observación no
    /// trae motivo, y `stop_<blocker>` o `waiting` en la causa. Dedupe por PROCESO y por `detail`, por el re-kick de 30 s.
    static func cloudForwardStepWaiting(
        step: String, stalledSeconds: Double, causeStalledSeconds: Double, blocker: String?
    ) {
        let detail = forwardStepWaitingDetail(
            step: step, stalledSeconds: stalledSeconds, causeStalledSeconds: causeStalledSeconds, blocker: blocker)
        canaryOnce(.cloudForwardStepWaiting, key: detail, detail: detail)
    }

    nonisolated static func forwardStepWaitingDetail(
        step: String, stalledSeconds: Double, causeStalledSeconds: Double, blocker: String?
    ) -> String {
        "\(step)|" + snapshotUploadWaitingDetail(
            stalledSeconds: stalledSeconds, causeStalledSeconds: causeStalledSeconds, blocker: blocker)
    }

    /// El motivo del servidor tal cual si tiene forma de código; si no, `other`. El gateway rechaza el LOTE entero de
    /// eventos si un detalle viene vacío o pasa de 128 caracteres (`gateway/src/metrics.ts`), y este texto llega de la
    /// red: un motivo raro no puede tirar los demás canarios del spool.
    nonisolated static func reverseClaimRejectedDetail(serverReason: String) -> String {
        let isCode = (1...64).contains(serverReason.count)
            && serverReason.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_").contains($0) }
        return isCode ? serverReason : "other"
    }

    /// Par de storage incompleto (`.cloud` + mirror ON) en fase estable ⇒ motor del dominio bloqueado.
    static func cloudStorageModePairViolation() {
        canary(.cloudStorageModePairViolation)
    }

    static func routingReadinessBlocked(blocker: String) {
        canary(.routingReadinessBlocked, detail: blocker)
    }

    static func routingDrainHoldSustained(blocker: String, consumer: String) {
        canary(.routingDrainHoldSustained, detail: "\(blocker)|\(consumer)")
    }

    static func routingWelcomeChainSuperseded(intentID: String) {
        canary(.routingWelcomeChainSuperseded, detail: intentID)
    }

    static func inviteReEmittedFromStore() {
        canary(.inviteReEmittedFromStore)
    }

    static func invitePendingExpired() {
        canary(.invitePendingExpired)
    }

    static func cloudkitTransferOrphanRepaired(orphansCleared: Int, pairedCount: Int) {
        canary(
            .cloudkitTransferOrphanRepaired,
            detail: "\(TransferReconcileContext.bootReconcile.rawValue)|paired=\(pairedCount)",
            value: Double(orphansCleared)
        )
    }

    static func cloudSyncIdentityGapObserved(entityType: String) {
        canary(.cloudSyncIdentityGapObserved, detail: entityType)
    }

    static func cloudSyncCoherenceGroupPartial(entity: String, group: String) {
        canary(.cloudSyncCoherenceGroupPartial, detail: "\(entity)|\(group)")
    }

    static func cloudSignInProviderMismatch() {
        canary(.cloudSignInProviderMismatch)
    }

    static func cloudSyncBlockedByAttestUnavailable(platform: String) {
        canary(.cloudSyncBlockedByAttestUnavailable, detail: platform)
    }

    static func cloudSyncBlockedByExpiredSession(pending: Int) {
        canary(.cloudSyncBlockedByExpiredSession, value: Double(pending))
    }

    /// Ver `MetricsCanary.cloudSyncAttestRequired`. Deduplicado por proceso y ruta: el motor reintenta con backoff y cada
    /// vuelta repetiría el mismo hecho.
    static func cloudSyncAttestRequired(edge: String) {
        canaryOnce(.cloudSyncAttestRequired, key: edge, detail: edge)
    }

    static func cloudSyncOutboxMirrorRehydrated(count: Int) {
        canary(.cloudSyncOutboxMirrorRehydrated, value: Double(count))
    }

    static func cloudSyncOutboxMirrorDivergence(delta: Int) {
        canary(.cloudSyncOutboxMirrorDivergence, value: Double(delta))
    }

    static func cloudSyncMutationRejected(reason: String) {
        canary(.cloudSyncMutationRejected, detail: reason)
    }

    static func cloudCutoverLeaderOrphanReconciled(count: Int) {
        canary(.cloudCutoverLeaderOrphanReconciled, value: Double(count))
    }

    static func cloudAdoptOrphanReconciled(count: Int) {
        canary(.cloudAdoptOrphanReconciled, value: Double(count))
    }

    static func cloudAdoptLineageBlocked(reason: String, writer: String) {
        let detail = "\(reason)|\(writer)"
        canaryOnce(.cloudAdoptLineageBlocked, key: detail, detail: detail)
    }

    static func cloudAdoptMarkerRelayed(outcome: String, waitedSeconds: TimeInterval) {
        canaryOnce(.cloudAdoptMarkerRelayed, key: outcome, detail: outcome, value: waitedSeconds.rounded())
    }

    static func cloudAdoptICloudCorpusChecked(outcome: String) {
        canaryOnce(.cloudAdoptICloudCorpusChecked, key: outcome, detail: outcome)
    }

    static func cloudConsentAccepted(path: String) {
        canary(.cloudConsentAccepted, detail: path)
    }

    static func cloudAccountUnavailable() {
        canary(.cloudAccountUnavailable)
    }

    /// Ver `MetricsCanary.cloudMigrationExistingAccountBlocked`. `detail` sin PII: dos slugs fijos del cliente.
    static func cloudMigrationExistingAccountBlocked(reason: String, stage: String) {
        canary(.cloudMigrationExistingAccountBlocked, detail: "\(reason)@\(stage)")
    }

    static func accountDeletionCompleted(step: String) {
        canary(.accountDeletionCompleted, detail: step)
    }

    static func accountDeletionFailed(step: String) {
        canary(.accountDeletionFailed, detail: step)
    }

    static func siwaExchangeFailed(reason: String) {
        canary(.siwaExchangeFailed, detail: reason)
    }

    static func siwaRevokeFailed(reason: String) {
        canary(.siwaRevokeFailed, detail: reason)
    }

    static func googleRevokeFailed(reason: String) {
        canary(.googleRevokeFailed, detail: reason)
    }

    static func cloudAccountReverting() {
        canary(.cloudAccountReverting)
    }

    static func cloudSyncClockReceiveRejected(reason: String) {
        canary(.cloudSyncClockReceiveRejected, detail: reason)
    }

    static func cloudSyncMerkleDivergence(entity: String) {
        canary(.cloudSyncMerkleDivergence, detail: entity)
    }

    static func groupMerkleDivergence(groupCount: Int) {
        canary(.groupMerkleDivergence, value: Double(groupCount))
    }

    static func cloudkitTransferCollisionDetected(count: Int) {
        canary(
            .cloudkitTransferCollisionDetected,
            detail: TransferReconcileContext.bootCollision.rawValue,
            value: Double(count)
        )
    }
}
