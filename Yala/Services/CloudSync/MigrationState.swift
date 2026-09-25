//
//  MigrationState.swift
//  Yala
//
//  Journal DURABLE de la máquina de migración del Modo Nube (I10-wiring, ciclo A). Fila ÚNICA
//  (single-row) en el store sync-meta — espeja `SyncCursor`: la crea perezosamente `loadOrCreate`,
//  se reusa, y NUNCA se espeja a CloudKit (`cloudKitDatabase: .none`, metadata LOCAL por dispositivo).
//
//  Journal-then-execute (molde validado en device por `SpikeS6Harness`): `MigrationRunner` ESCRIBE la
//  transición (fase + efectos pendientes + contadores) ANTES de ejecutar cada efecto, y remueve cada
//  efecto del pending al completarlo. Un kill entre journal y execute retoma ejecutando lo journaleado
//  pendiente (idempotente); lo completo se salta. La resumibilidad NUNCA es por contador de progreso
//  del uploader — `snapshotCursorJSON` solo evita re-subir lo YA confirmado; la idempotencia real la da
//  el `client_mutation_id` (H5).
//
//  DARK: nada de producción instancia el runner ni lee este journal todavía (la UI de migración llega
//  en I14; el panel DEBUG en w7). Solo lo ejercitan los tests de este ciclo.
//
//  REGLA DEL REPO: los @Model del store sync-meta NUNCA llevan `@Attribute(.unique)` (espeja SyncCursor).
//

import Foundation
import SwiftData

extension CloudSyncSchemaVersions {
    /// Versión de schema de `MigrationState` (testigo A1 en la fila). Subió a 2 en I11-2 al añadir el campo
    /// aditivo `reverseOriginRaw` (origin de la reversa journaleado en la transición reverseConfirm→claim).
    /// Subió a 3 en C-1 con los campos aditivos `markerWrittenSince` (reloj del tope del paso 4) y
    /// `cutoverICloudVerdictRaw` (veredicto del canal iCloud, para el copy del fallo).
    /// Subió a 4 con los tres campos aditivos del techo de `reverseUpload` (`reverseUploadLowestPending`,
    /// `reverseUploadProgressAt`, `reverseAbortReasonRaw`).
    /// Subió a 5 con `reverseOriginPendingEffectsData`: los efectos pendientes del origen que la vuelta reemplaza,
    /// para reponerlos si el servidor no concede la reserva (ticket `reverse-claim-rejection-has-no-way-out-in-the-client`).
    /// Subió a 6 con `forwardClaimIntentRaw`: qué pidió la persona al llegar al claim de la ida, para que un relanzamiento
    /// con el claim aparcado no adopte lo que «Migrar a la nube» no pidió (ticket
    /// `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`).
    /// Subió a 7 con los dos campos aditivos del techo de las fases previas al montaje de la vuelta
    /// (`reversePreMountProgressAt`, `reversePreMountPhaseRaw`), ticket
    /// `reverse-before-mount-has-no-way-to-abandon-the-return`.
    /// Subió a 8 con los TRES campos del RELOJ POR CAUSA de ese mismo techo (`reversePreMountCauseRaw`,
    /// `reversePreMountCauseAt`, `reversePreMountCauseAccruedSeconds`): el techo corto mide el tiempo ACUMULADO
    /// parado bajo ESA causa, no el de la fase entera
    /// (ticket `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last`).
    /// Subió a 9 con los CINCO campos del techo de `uploadingSnapshot` (ticket
    /// `snapshot-upload-has-no-ceiling-and-no-way-out`): los cuatro de sus dos relojes (`snapshotStallProgressAt`,
    /// `snapshotStallCauseRaw`, `snapshotStallCauseAt`, `snapshotStallCauseAccruedSeconds`) y el motivo de la salida
    /// (`snapshotExitReasonRaw`).
    /// Subió a 10 con los CINCO campos del techo de los tres pasos de la ida sin cifra que baje —`claimingMigration`,
    /// `assigningIdentity` y `cutover(.pending)`— (ticket `forward-migration-steps-have-no-ceiling-and-no-exit`): los
    /// cuatro `forwardStepStall*` de sus dos relojes y el motivo de la salida (`forwardStepExitReasonRaw`).
    /// Subió a 11 con `adoptClaimExitRaw` y `adoptClaimAccountHash`: el claim de un ADOPT salió —por su techo o por
    /// «Cancelar»— y la pantalla tiene que ofrecer volver a entrar en ESA cuenta, no «Migrar» (ticket
    /// `adopt-claim-stays-parked-with-no-ceiling`).
    /// Subió a 12 con los DOS campos del reloj de «cualquier motivo definitivo» del techo previo al montaje de la vuelta
    /// (`reversePreMountDefinitiveAt`, `reversePreMountDefinitiveAccruedSeconds`): con dos motivos definitivos
    /// alternándose el reloj por causa se reiniciaba en cada observación y el techo corto no vencía nunca (ticket
    /// `alternating-definitive-causes-never-reach-the-short-ceiling`).
    /// Subió a 13 con el mismo par en la subida del snapshot de la ida (`snapshotStallDefinitiveAt`,
    /// `snapshotStallDefinitiveAccruedSeconds`): el agujero era el mismo —un fallo local al leer y el 403/409 del push
    /// se turnan pasada a pasada— (ticket `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling`).
    /// Subió a 14 con los TRES campos del techo del EFECTO del adopt (`adoptEffectStallProgressAt`,
    /// `adoptEffectStallDefinitiveAt`, `adoptEffectStallDefinitiveAccruedSeconds`): el reconcile de huérfanas que no puede
    /// terminar se reintentaba para siempre (ticket `adopt-effect-retries-forever-with-no-ceiling`).
    /// Subió a 15 con los CINCO campos de los dos relojes que le faltaban al techo de `reverseUpload`: los tres del de
    /// CAUSA (`reverseUploadCauseRaw`, `reverseUploadCauseAt`, `reverseUploadCauseAccruedSeconds`) y los dos del de
    /// «cualquier motivo definitivo» (`reverseUploadDefinitiveAt`, `reverseUploadDefinitiveAccruedSeconds`). Con un solo
    /// reloj, un `icloudUnusable` de una pasada cobraba las horas que la espera llevaba sin cuenta de iCloud (ticket
    /// `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last`).
    /// Subió a 16 con `forwardLineageUnverified`: el claim que dio el turno dijo que la cuenta ya recibió datos personales
    /// —o no lo dijo—, y la identidad tiene que comprobar que este corpus comparte linaje con ellos antes de subir (ticket
    /// `migration-takeover-uploads-without-a-lineage-check`).
    static let migrationState = 16
}

/// Journal single-row de la migración. Debe existir a lo sumo UNA fila (el runner la crea
/// perezosamente y la reusa vía `loadOrCreate`).
@Model
final class MigrationState {

    /// `MigrationPhase` codificado en JSON (Codable golden-testeado — SSOT, sin encoding paralelo).
    /// `nil` ⇒ `.notStarted`. Lectura pura vía `readPhase()` (nunca lanza).
    var phaseData: Data?

    /// `[MigrationEffect]` journaleados PENDIENTES de una transición (journal-then-execute, N1). El runner
    /// los escribe ANTES de ejecutarlos y remueve cada uno al completarlo. `nil` ⇒ `[]`.
    var pendingEffectsData: Data?

    /// Cursor de la última página CONFIRMADA del uploader del snapshot (w4). OPACO aquí (string del
    /// uploader). H5: la resumibilidad NO es por contador — siempre se re-envía el batch confiando en
    /// `client_mutation_id`; este cursor solo evita re-subir lo confirmado. `nil` = aún nada confirmado.
    var snapshotCursorJSON: String?

    /// S9: contador INDEPENDIENTE de reintentos por MISMATCH del verify (no suma con los de red).
    var verifyMismatchRetries: Int = 0

    /// S9: contador INDEPENDIENTE de reintentos por TIMEOUT de red del verify (no suma con los de mismatch).
    var verifyNetworkRetries: Int = 0

    /// `device_id` con el que ESTE device reclamó liderazgo. Se journalea ANTES del `POST /account/claim`
    /// → un re-claim tras un kill que reciba `claiming_in_progress` se reconoce como `sameDeviceReclaim`
    /// (comparando contra el `deviceID` del runner) y avanza, en vez de bloquearse siguiendo a otro líder.
    /// `nil` = este device aún no reclamó.
    var leaderDeviceID: String?

    /// `server_seq` de corte para el marcador CloudKit + `reconcileFromFrozenCloudKit` (w6). Campo desde
    /// ya para evitar churn de schema (additive cuando w6 lo use).
    var serverSeqCut: Int64 = 0

    /// I11-2: `ReverseOrigin.rawValue` (`done`/`notStarted`) journaleado en el MISMO save de la transición
    /// `reverseConfirm(origin)→reverseClaimLeader` — la máquina NO propaga el origin más allá de
    /// `reverseConfirm`, así que el runner lo persiste aquí para: (1) el desatascador `reverseOtherLeader`
    /// (volver al origin correcto), (2) `resetAfterRollback` desde `reverseFailedRollback` (reponer la fase
    /// origen, no `notStarted` ciego que mentiría a `markerReconciliation`). Se limpia en los cierres
    /// (notStarted/failedRollback/icloudActive) y tras el reset. `nil` = sin reversa en curso.
    var reverseOriginRaw: String?

    /// C-1: instante de la PRIMERA entrada a `cutover(.markerWritten)`, con el `now` INYECTADO. Es el reloj
    /// del tope del paso 4. Se sella UNA sola vez y NO se re-escribe en los resumes: si se re-sellase en cada
    /// vuelta, el presupuesto nunca vencería y el limbo seguiría siendo eterno (= el bug intacto). `nil` = el
    /// paso 4 no se ha alcanzado, o el journal se escribió con un build anterior a C-1 (el runner lo sella
    /// perezosamente en la primera observación).
    var markerWrittenSince: Date?

    /// C-1: último `ICloudChannelVerdict.rawValue` journaleado. Alimenta el copy honesto del fallo (cuota
    /// agotada vs. sin cuenta iCloud vs. sin confirmación) y deja rastro del waiver `noChannelNoFootprint`.
    /// `nil` = sin veredicto registrado.
    var cutoverICloudVerdictRaw: String?

    /// Techo de `reverseUpload`: la cifra de pendientes MÁS BAJA observada en este intento. Avanzar es bajar de
    /// ella; escribir durante la espera sube la cifra y no cuenta ni como avance ni como retroceso. `nil` = aún no
    /// se ha observado la espera (o el journal viene de un build anterior: se sella en la primera observación).
    var reverseUploadLowestPending: Int?

    /// Techo de `reverseUpload`: el instante del ÚLTIMO avance, con el `now` INYECTADO. Es el reloj del techo. Lo
    /// sella la primera observación y lo re-sella SOLO un avance: re-sellarlo en cada resume haría eterna la
    /// espera, que es el bug. `nil` = sin observar.
    ///
    /// **Desde la v15 gobierna solo el techo LARGO** (72 h, con cualquier motivo). El corto se mide contra el reloj de
    /// «cualquier motivo definitivo» de abajo: con este solo, un `icloudUnusable` de una pasada cobraba las horas que la
    /// espera llevaba sin cuenta de iCloud (ticket `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last`).
    var reverseUploadProgressAt: Date?

    /// **El reloj de CAUSA de la espera, en TRES campos** (ticket
    /// `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last`), el mismo `CauseStallClock` que la vuelta
    /// previa al montaje y la subida del snapshot. No decide la salida: decide su TEXTO, que solo es el específico si UN
    /// motivo agotó solo el plazo corto. Qué motivo se mide (`ReverseUploadBlocker.rawValue`, solo los definitivos).
    /// `nil` = ninguno desde el último avance.
    var reverseUploadCauseRaw: String?

    /// Desde cuándo corre el tramo ABIERTO de esa causa. `nil` con la causa puesta = tramo CERRADO: la última
    /// observación no traía motivo definitivo y el reloj quedó en pausa, no borrado.
    var reverseUploadCauseAt: Date?

    /// Lo que esa causa acumuló en tramos CERRADOS. Un acumulado y no una racha: el re-kick de 30 s de Almacenamiento
    /// volvería inalcanzable una racha de 900 s.
    var reverseUploadCauseAccruedSeconds: Double?

    /// Desde cuándo corre el tramo ABIERTO del reloj de «cualquier motivo definitivo»
    /// (`CauseStallClock.observeAnyDefinitive`): el que decide el techo CORTO. Suma `icloudFull` e `icloudUnusable`
    /// aunque se turnen; `icloudOff` y `unknown` lo PAUSAN, así que las horas sin cuenta no se las cobra nadie. `nil` =
    /// tramo cerrado o nunca abierto, o una fila de un build anterior a la v15: el corto le cuenta desde que este build
    /// la mira.
    var reverseUploadDefinitiveAt: Date?

    /// Lo que ese reloj acumuló en tramos CERRADOS.
    var reverseUploadDefinitiveAccruedSeconds: Double?

    /// `ReverseAbortReason.rawValue` de la última vuelta a iCloud que terminó sin llegar: por la espera de
    /// `reverseUpload` o porque el servidor no concedió el claim. SOBREVIVE a la vuelta a la fase origen a propósito: la
    /// persona puede no estar mirando cuando pasa y lee el porqué después (tras el relanzamiento, en la salida de la
    /// espera). Se limpia al empezar otra vuelta y al completarla. `nil` = nada que explicar.
    var reverseAbortReasonRaw: String?

    /// Los efectos que estaban PENDIENTES en la fase origen cuando empezó la vuelta a iCloud (`[MigrationEffect]` en
    /// JSON, el mismo codec que `pendingEffectsData`). `reverseActivated` los reemplaza, y si la vuelta regresa al
    /// origen ANTES de que el servidor conceda la reserva —rechazo, otro líder, cancelación en la confirmación o un kill
    /// ahí— se reponen: la vuelta no empezó, así que el dispositivo tiene que quedar como estaba. Sin esto se perdía el
    /// `.runLeaderReconcileFromFrozenCloudKit` de un líder cuyo `complete` aún no había llegado, que es lo único que
    /// manda `complete`, y `migration_in_progress` se quedaba puesto en el backend para siempre. Se limpia al reponerlos
    /// y al conceder la reserva. `nil` = nada guardado.
    var reverseOriginPendingEffectsData: Data?

    /// `ForwardClaimIntent.rawValue` del intento que llegó al claim de la ida. Se escribe en el MISMO save que la
    /// transición `authenticating → claimingMigration`, y lo lee `driveClaim`: con `migrateOnly`, un `existing_stable` vuelve
    /// al inicio en vez de adoptar. Journaleado y no en memoria porque el claim puede quedarse aparcado —sin red, sesión
    /// caducada— y retomarse tras un relanzamiento: en memoria, ese `resume` adoptaba lo que «Migrar a la nube» no pidió,
    /// y en una cuenta que volvió a iCloud dejaba el dispositivo en modo nube sobre un backend que rechaza todo push. Se
    /// limpia al cerrar el intento (`notStarted`, `failedRollback`, `icloudActive`). `nil` = sin intención journaleada,
    /// que se lee como `adoptIfExisting`: una fila anterior a la v6 se comporta como siempre.
    var forwardClaimIntentRaw: String?

    /// Techo de las fases PREVIAS al montaje del espejo en la vuelta a iCloud: el instante del último avance, con el
    /// `now` INYECTADO (ticket `reverse-before-mount-has-no-way-to-abandon-the-return`). Aquí no hay cifra que baje
    /// —el drenaje no expone un pendiente comparable, la verificación es un veredicto y el congelado es una sola
    /// llamada—, así que **avanzar es cambiar de fase**, y eso lo dice `reversePreMountPhaseRaw`. Un sello en el
    /// FUTURO (el reloj del teléfono puesto atrás durante la espera) se re-sella en vez de posponer el techo para
    /// siempre. `nil` = ninguna de las cuatro fases se ha observado parada todavía.
    var reversePreMountProgressAt: Date?

    /// En qué fase previa al montaje se selló `reversePreMountProgressAt` (`ReversePreMountPhase.rawValue`, no el
    /// JSON de la fase: solo hace falta compararlo). Sin este campo el reloj mediría el tiempo total de la etapa, y
    /// un drenaje largo y sano se comería el presupuesto del mismo modo que uno parado. `nil` = sin sello.
    var reversePreMountPhaseRaw: String?

    /// **El OTRO reloj de ese techo, en TRES campos** (ticket
    /// `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last`). El de arriba mide el tiempo parado de
    /// la FASE y gobierna el techo largo; éste mide el tiempo ACUMULADO parado bajo una misma causa y gobierna el
    /// CORTO. Sin él, un `fetch` local que falla UNA vez tras tres horas sin cobertura cobraba las tres horas contra
    /// su presupuesto de 15 min y sacaba de la vuelta sin un solo reintento.
    ///
    /// Qué causa se está midiendo (`ReversePreMountBlocker.rawValue`). Comparar el rawValue basta, y **es el
    /// rawValue y no el `abortReason`**: dos motivos distintos pueden compartir el texto que se le enseña a la
    /// persona (`accountUnavailable` y `refused` comparten `preMountRefused`) y fundir sus relojes sumaría dos
    /// causas como si fueran una. `nil` = todavía no se ha observado ninguna en esta fase.
    var reversePreMountCauseRaw: String?

    /// Desde cuándo corre el tramo ABIERTO de esa causa, con el `now` INYECTADO. `nil` con la causa presente
    /// significa que el tramo está CERRADO: la última observación no traía motivo —la red llega así— y el reloj
    /// quedó en pausa, no borrado.
    var reversePreMountCauseAt: Date?

    /// Lo que esa causa ya acumuló en tramos CERRADOS. **Un acumulado y no una racha consecutiva**, y la
    /// diferencia no es teórica: la pantalla de Almacenamiento re-kickea cada 30 s, así que con una cuenta
    /// suspendida y cobertura intermitente basta un timeout de red cada quince minutos para que una racha no
    /// llegue nunca a los 900 s — el techo corto se volvía inalcanzable justo cuando más se mira, y el desenlace
    /// pasaba de 15 min a 72 h. Con el acumulado, el hueco sin cobertura PAUSA el reloj en vez de borrarlo, y lo
    /// que no se pudo observar no cuenta ni a favor ni en contra.
    ///
    /// Un cambio de causa sí reinicia los tres: lo que se acumuló bajo un motivo no se le regala a otro. `nil` = la
    /// causa nunca ha tenido un tramo cerrado, o la fila viene de un build anterior a la v8.
    var reversePreMountCauseAccruedSeconds: Double?

    /// **El TERCER reloj de ese techo, en DOS campos** (ticket
    /// `alternating-definitive-causes-never-reach-the-short-ceiling`): el tiempo ACUMULADO parado bajo CUALQUIER motivo
    /// definitivo, que es el que gobierna hoy el techo CORTO. El de causa de arriba se reinicia al cambiar de motivo, y
    /// con dos motivos turnándose —una cuenta suspendida y un store que falla a ratos— no pasaba nunca de una
    /// observación: la salida se iba a las 72 h. Éste no se reinicia al cambiar de causa; como el de causa, una
    /// observación SIN motivo lo PAUSA, y eso es lo que impide que las horas de red se le cobren a un fallo aislado.
    ///
    /// Desde cuándo corre el tramo ABIERTO, con el `now` INYECTADO. `nil` con el acumulado puesto = tramo cerrado (la
    /// última observación no traía motivo).
    var reversePreMountDefinitiveAt: Date?

    /// Lo acumulado en tramos CERRADOS. No hay campo de clave: la clave es una sola («algún motivo definitivo»). `nil` =
    /// la fase no se ha observado parada todavía, o la fila viene de un build anterior a la v12: el reloj empieza cuando
    /// este build la mira.
    var reversePreMountDefinitiveAccruedSeconds: Double?

    // MARK: Techo de `uploadingSnapshot` (ticket `snapshot-upload-has-no-ceiling-and-no-way-out`)
    //
    // TRES relojes, molde del techo previo al montaje de la vuelta: el de AVANCE gobierna las 72 h, el de «cualquier
    // motivo DEFINITIVO» los 15 min, y el de CAUSA elige el copy de la salida (hasta el ticket
    // `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling` los 15 min los gobernaba el de
    // causa). Los seis `snapshotStall*` solo pueden estar puestos con la fase en `uploadingSnapshot`: `handle` los
    // limpia al ENTRAR y al SALIR de ella (`clearSnapshotStallCeiling()`), así que una vuelta desde `verifying` por
    // mismatch empieza sin reloj.

    /// El instante del último AVANCE de la subida —la última página confirmada—, con el `now` INYECTADO. Lo sella la
    /// primera observación sin avance y lo re-sella cada `pageConfirmed`. `nil` = aún sin observar en esta visita a la
    /// fase, o la fila viene de un build anterior a la v9: el presupuesto le empieza a contar desde que este build la
    /// mira.
    var snapshotStallProgressAt: Date?

    /// Qué causa DEFINITIVA se está midiendo (`SnapshotStallBlocker.rawValue`). `nil` = ninguna observada desde el
    /// último avance.
    var snapshotStallCauseRaw: String?

    /// Desde cuándo corre el tramo ABIERTO de esa causa. `nil` con la causa presente = tramo CERRADO: la última
    /// observación no traía motivo (la red llega así) y el reloj quedó en PAUSA, no borrado.
    var snapshotStallCauseAt: Date?

    /// Lo que esa causa acumuló en tramos CERRADOS. Un acumulado y no una racha, por lo mismo que en la vuelta: con el
    /// re-kick de 30 s de Almacenamiento, un timeout intercalado reiniciaría una racha y los 900 s no llegarían nunca.
    var snapshotStallCauseAccruedSeconds: Double?

    /// **El TERCER reloj de la subida, en DOS campos** (ticket
    /// `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling`): el tiempo ACUMULADO parado bajo
    /// CUALQUIER motivo definitivo desde el último avance, que es el que gobierna el techo CORTO. El de causa de arriba
    /// se reinicia al cambiar de motivo, y con dos turnándose —un `fetch` local que falla a ratos antes del push y el 403
    /// o el 409 del push— no pasaba nunca de una observación: la salida se iba a las 72 h. Éste no se reinicia al
    /// cambiar de causa; como el de causa, una observación SIN motivo lo PAUSA, y eso es lo que impide que las horas de
    /// red se le cobren a un fallo aislado.
    ///
    /// Desde cuándo corre el tramo ABIERTO, con el `now` INYECTADO. `nil` con el acumulado puesto = tramo cerrado (la
    /// última observación no traía motivo).
    var snapshotStallDefinitiveAt: Date?

    /// Lo acumulado en tramos CERRADOS. No hay campo de clave: la clave es una sola («algún motivo definitivo»). `nil` =
    /// la subida no se ha observado parada por un motivo definitivo desde el último avance, o la fila viene de un build
    /// anterior a la v13: el reloj empieza cuando este build la mira.
    var snapshotStallDefinitiveAccruedSeconds: Double?

    /// `SnapshotExitReason.rawValue` de la subida que venció su techo. Es lo que elige el texto de la tarjeta de
    /// fallo, y por eso **sobrevive a `failedRollback`**, como `cutoverICloudVerdictRaw`. Solo puede estar puesto en
    /// esa fase —lo escribe la salida del techo, que va ahí— y de esa fase solo se sale por `resetAfterRollback`
    /// («Reintentar»), que es quien lo limpia. `nil` =
    /// nada que explicar, o un fallo que no vino de la subida.
    var snapshotExitReasonRaw: String?

    // MARK: Techo de los tres pasos de la ida sin cifra que baje (ticket `forward-migration-steps-have-no-ceiling-and-no-exit`)
    //
    // `claimingMigration` (22 %), `assigningIdentity` (35 %) y `cutover(.pending)` (80 %). Un solo juego de campos para
    // los tres, y **sin campo de paso**: `handle` los limpia en CADA cambio de paso (`clearForwardStepStallCeiling()`), así
    // que solo pueden estar puestos con la fase en uno de los tres y describen siempre ESE. Pasar de paso es el avance.
    //
    // Desde `adopt-follower-waits-for-the-leader-with-no-ceiling` los usa también la espera del seguidor
    // (`waitingForLeader`), con los mismos campos y sin schema nuevo. Ahí el avance es otro: cada `claiming_in_progress`
    // borra los dos relojes (`MigrationRunner.noteLeaderAlive`), y como en los otros tres los sella la primera observación
    // que no avanza.

    /// El instante del último AVANCE del paso —su primera observación sin avanzar—, con el `now` INYECTADO. Gobierna las
    /// 72 h. `nil` = el paso aún no se ha observado parado, o la fila viene de un build anterior a la v10: el presupuesto le
    /// empieza a contar desde que este build la mira.
    var forwardStepStallProgressAt: Date?

    /// Qué causa DEFINITIVA se está midiendo (`ForwardStepBlocker.rawValue`). `nil` = ninguna observada en este paso.
    var forwardStepStallCauseRaw: String?

    /// Desde cuándo corre el tramo ABIERTO de esa causa. `nil` con la causa presente = tramo CERRADO: la última
    /// observación no traía motivo y el reloj quedó en PAUSA, no borrado.
    var forwardStepStallCauseAt: Date?

    /// Lo que esa causa acumuló en tramos CERRADOS. Un acumulado y no una racha, por el re-kick de 30 s de Almacenamiento.
    var forwardStepStallCauseAccruedSeconds: Double?

    /// `ForwardStepExitReason.rawValue` del paso que venció su techo. Elige el texto de la tarjeta de fallo y por eso
    /// **sobrevive a `failedRollback`**, como `snapshotExitReasonRaw`. Lo limpia `resetAfterRollback` («Reintentar»), que es
    /// la salida de esa fase. `nil` = el fallo no vino de estos pasos.
    /// **Desde `displaced-migration-leader-keeps-uploading-after-a-takeover` lo escribe también la salida del lease
    /// perdido**, desde la subida o la verificación y sin techo: `otherDevice`, el mismo que el `cutover` journalea para la
    /// misma respuesta del servidor.
    var forwardStepExitReasonRaw: String?

    /// `AdoptClaimExit.rawValue`: el claim de un ADOPT —«Ya tengo una cuenta», «Activar la nube en este dispositivo»—
    /// salió por su techo o porque la persona canceló (ticket `adopt-claim-stays-parked-with-no-ceiling`). Desde
    /// `adopt-effect-retries-forever-with-no-ceiling` lo escribe también la salida del EFECTO del adopt —el reconcile que no
    /// termina, tras un claim que ya contestó—: la misma pantalla, la misma cuenta, la misma salida. Hace dos cosas:
    /// elige el texto de la tarjeta de fallo, que no puede decir «tus datos siguen en este dispositivo» en un teléfono
    /// recién instalado, y hace que Almacenamiento ofrezca «Activar la nube en este dispositivo» aunque no haya marcador
    /// de CloudKit: sin esto, «Reintentar» llevaba a «Migrar a la nube», que la puerta de identidad para con esa cuenta.
    ///
    /// **Sobrevive a `failedRollback`, a «Reintentar» y a `notStarted` a propósito**: es la salida hacia delante de esa
    /// pantalla. Lo borra el `handle` que ENTRA en `claimingMigration` —otro intento empezó, y su desenlace manda— y el que
    /// llega a `icloudActive`. Un journal que este build no entiende no se toca (`isJournalUndecodable`), así que la
    /// conserva también. `nil` = ningún adopt salió desde el último claim.
    var adoptClaimExitRaw: String?

    /// `CloudBeacon.hash` de la cuenta con la que el último claim ENTRÓ en `claimingMigration`. Ata la marca de arriba a
    /// UNA cuenta: Almacenamiento solo ofrece volver a entrar sin sesión o con la sesión de esa cuenta, y tras firmar no
    /// adopta otra (`AdoptClaimScope`). Lo escribe el `handle` que entra en el claim; se va con la marca al volver a
    /// iCloud. `nil` = no se sabe, y entonces la marca no abre nada con una sesión puesta.
    var adoptClaimAccountHash: String?

    /// ¿Tiene la identidad (35 %) que comprobar el LINAJE antes de subir? (ticket
    /// `migration-takeover-uploads-without-a-lineage-check`). Lo escribe el runner en el MISMO save de la transición
    /// `created → assigningIdentity`, con la pista del claim (`has_personal_writes`, g16_03): `true` si la cuenta ya recibió
    /// datos personales o el servidor no lo dijo, `false` si no los recibió. La identidad lo pone a `false` al probarlo, para
    /// no repetir la enumeración en la pasada siguiente. Se va en los cierres de intento.
    ///
    /// **`nil` también comprueba**: es la fila de un build anterior a la v16 parada en la identidad, cuyo claim nadie
    /// journaleó. Falla cerrado a propósito: una key nueva está ausente en todo el parque, y leer su ausencia como «no hace
    /// falta» abriría el relevo sin comprobar a todo teléfono que actualice a mitad de una activación.
    var forwardLineageUnverified: Bool?

    // MARK: Techo del EFECTO del adopt (ticket `adopt-effect-retries-forever-with-no-ceiling`)
    //
    // El par `(notStarted, [.adoptBackendAccount])`: el claim ya contestó `existing_stable` y el reconcile de huérfanas no
    // termina. Solo están puestos con ese efecto pendiente: los borra cualquier `handle` —un claim nuevo, la cancelación,
    // la salida— y el save que retira el efecto cuando el adopt termina (`clearAdoptEffectStallCeiling()`).

    /// El primer intento fallido del efecto, con el `now` INYECTADO. Gobierna las 72 h con cualquier causa. `nil` = el
    /// efecto aún no ha fallado, o la fila viene de un build anterior a la v14: el presupuesto le empieza a contar desde que
    /// este build la mira.
    var adoptEffectStallProgressAt: Date?

    /// Desde cuándo corre el tramo ABIERTO del reloj de «cualquier motivo definitivo» (`CauseStallClock.observeAnyDefinitive`).
    /// Hoy el único motivo definitivo del efecto es la base local. `nil` = tramo cerrado o nunca abierto.
    var adoptEffectStallDefinitiveAt: Date?

    /// Lo que ese reloj acumuló en tramos CERRADOS. Un acumulado y no una racha: la red lo PAUSA, no lo borra, y el re-kick
    /// de Almacenamiento llega cada 30 s.
    var adoptEffectStallDefinitiveAccruedSeconds: Double?

    /// Cuándo empezó la migración (el runner lo estampa con el `now` INYECTADO al arrancar). `nil` = no
    /// iniciada.
    var startedAt: Date?

    /// Último write del journal (el runner estampa el `now` INYECTADO en cada escritura — patrón del repo).
    /// El default del `@Model` es irrelevante: siempre lo pisa el runner.
    var updatedAt: Date = Date.now

    /// Versión del schema bajo la que se materializó esta fila (testigo A1).
    var schemaVersion: Int = CloudSyncSchemaVersions.migrationState

    init(
        phaseData: Data? = nil,
        pendingEffectsData: Data? = nil,
        snapshotCursorJSON: String? = nil,
        verifyMismatchRetries: Int = 0,
        verifyNetworkRetries: Int = 0,
        leaderDeviceID: String? = nil,
        serverSeqCut: Int64 = 0,
        reverseOriginRaw: String? = nil,
        markerWrittenSince: Date? = nil,
        cutoverICloudVerdictRaw: String? = nil,
        reverseUploadLowestPending: Int? = nil,
        reverseUploadProgressAt: Date? = nil,
        reverseUploadCauseRaw: String? = nil,
        reverseUploadCauseAt: Date? = nil,
        reverseUploadCauseAccruedSeconds: Double? = nil,
        reverseUploadDefinitiveAt: Date? = nil,
        reverseUploadDefinitiveAccruedSeconds: Double? = nil,
        reverseAbortReasonRaw: String? = nil,
        reverseOriginPendingEffectsData: Data? = nil,
        forwardClaimIntentRaw: String? = nil,
        reversePreMountProgressAt: Date? = nil,
        reversePreMountPhaseRaw: String? = nil,
        reversePreMountCauseRaw: String? = nil,
        reversePreMountCauseAt: Date? = nil,
        reversePreMountCauseAccruedSeconds: Double? = nil,
        reversePreMountDefinitiveAt: Date? = nil,
        reversePreMountDefinitiveAccruedSeconds: Double? = nil,
        snapshotStallProgressAt: Date? = nil,
        snapshotStallCauseRaw: String? = nil,
        snapshotStallCauseAt: Date? = nil,
        snapshotStallCauseAccruedSeconds: Double? = nil,
        snapshotStallDefinitiveAt: Date? = nil,
        snapshotStallDefinitiveAccruedSeconds: Double? = nil,
        snapshotExitReasonRaw: String? = nil,
        forwardStepStallProgressAt: Date? = nil,
        forwardStepStallCauseRaw: String? = nil,
        forwardStepStallCauseAt: Date? = nil,
        forwardStepStallCauseAccruedSeconds: Double? = nil,
        forwardStepExitReasonRaw: String? = nil,
        adoptClaimExitRaw: String? = nil,
        adoptClaimAccountHash: String? = nil,
        adoptEffectStallProgressAt: Date? = nil,
        adoptEffectStallDefinitiveAt: Date? = nil,
        adoptEffectStallDefinitiveAccruedSeconds: Double? = nil,
        startedAt: Date? = nil,
        updatedAt: Date = Date.now,
        schemaVersion: Int = CloudSyncSchemaVersions.migrationState
    ) {
        self.phaseData = phaseData
        self.pendingEffectsData = pendingEffectsData
        self.snapshotCursorJSON = snapshotCursorJSON
        self.verifyMismatchRetries = verifyMismatchRetries
        self.verifyNetworkRetries = verifyNetworkRetries
        self.leaderDeviceID = leaderDeviceID
        self.serverSeqCut = serverSeqCut
        self.reverseOriginRaw = reverseOriginRaw
        self.markerWrittenSince = markerWrittenSince
        self.cutoverICloudVerdictRaw = cutoverICloudVerdictRaw
        self.reverseUploadLowestPending = reverseUploadLowestPending
        self.reverseUploadProgressAt = reverseUploadProgressAt
        self.reverseUploadCauseRaw = reverseUploadCauseRaw
        self.reverseUploadCauseAt = reverseUploadCauseAt
        self.reverseUploadCauseAccruedSeconds = reverseUploadCauseAccruedSeconds
        self.reverseUploadDefinitiveAt = reverseUploadDefinitiveAt
        self.reverseUploadDefinitiveAccruedSeconds = reverseUploadDefinitiveAccruedSeconds
        self.reverseAbortReasonRaw = reverseAbortReasonRaw
        self.reverseOriginPendingEffectsData = reverseOriginPendingEffectsData
        self.forwardClaimIntentRaw = forwardClaimIntentRaw
        self.reversePreMountProgressAt = reversePreMountProgressAt
        self.reversePreMountPhaseRaw = reversePreMountPhaseRaw
        self.reversePreMountCauseRaw = reversePreMountCauseRaw
        self.reversePreMountCauseAt = reversePreMountCauseAt
        self.reversePreMountCauseAccruedSeconds = reversePreMountCauseAccruedSeconds
        self.reversePreMountDefinitiveAt = reversePreMountDefinitiveAt
        self.reversePreMountDefinitiveAccruedSeconds = reversePreMountDefinitiveAccruedSeconds
        self.snapshotStallProgressAt = snapshotStallProgressAt
        self.snapshotStallCauseRaw = snapshotStallCauseRaw
        self.snapshotStallCauseAt = snapshotStallCauseAt
        self.snapshotStallCauseAccruedSeconds = snapshotStallCauseAccruedSeconds
        self.snapshotStallDefinitiveAt = snapshotStallDefinitiveAt
        self.snapshotStallDefinitiveAccruedSeconds = snapshotStallDefinitiveAccruedSeconds
        self.snapshotExitReasonRaw = snapshotExitReasonRaw
        self.forwardStepStallProgressAt = forwardStepStallProgressAt
        self.forwardStepStallCauseRaw = forwardStepStallCauseRaw
        self.forwardStepStallCauseAt = forwardStepStallCauseAt
        self.forwardStepStallCauseAccruedSeconds = forwardStepStallCauseAccruedSeconds
        self.forwardStepExitReasonRaw = forwardStepExitReasonRaw
        self.adoptClaimExitRaw = adoptClaimExitRaw
        self.adoptClaimAccountHash = adoptClaimAccountHash
        self.adoptEffectStallProgressAt = adoptEffectStallProgressAt
        self.adoptEffectStallDefinitiveAt = adoptEffectStallDefinitiveAt
        self.adoptEffectStallDefinitiveAccruedSeconds = adoptEffectStallDefinitiveAccruedSeconds
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
    }
}

// MARK: - Techo de la espera de `reverseUpload`

extension MigrationState {

    /// Borra los SIETE campos del techo de `reverseUpload`: la cifra más baja y el reloj de avance, los tres del de
    /// causa y los dos del de «cualquier motivo definitivo». Juntos siempre y en cuatro sitios —el reset tras rollback,
    /// el arranque de una vuelta nueva, los cierres de intento y la salida de la espera—: un campo que sobreviva al intento deja el techo venciendo con cero segundos de espera real en el
    /// siguiente. NO toca `reverseAbortReasonRaw`, que es el desenlace y sobrevive a la salida a propósito. Lo que
    /// garantiza que un campo NUEVO de la familia no se quede fuera es `CloudSyncSchemaParityTests`, que la deriva del
    /// schema por su prefijo `reverseUpload`.
    func clearReverseUploadCeiling() {
        reverseUploadLowestPending = nil
        reverseUploadProgressAt = nil
        reverseUploadCauseRaw = nil
        reverseUploadCauseAt = nil
        reverseUploadCauseAccruedSeconds = nil
        reverseUploadDefinitiveAt = nil
        reverseUploadDefinitiveAccruedSeconds = nil
    }
}

// MARK: - Techo de las fases previas al montaje de la vuelta

extension MigrationState {

    /// Borra los SIETE campos del techo de las fases previas al montaje: el reloj de fase con su sello, los tres del
    /// reloj por causa y los dos del de «cualquier motivo definitivo». Existe porque se limpian SIEMPRE juntos y en cinco sitios distintos —el reset tras
    /// rollback, el arranque de una vuelta nueva, los tres cierres de intento, el cambio de fase y la salida del
    /// techo—, y un campo que se olvide en uno solo de ellos no deja la
    /// fila fea: deja el techo venciendo con cero segundos de parada real en el intento siguiente, que es el bug
    /// que el par del reloj de fase ya tuvo una vez.
    ///
    /// **Lo que garantiza que no se olvide un campo NUEVO no es este método, es su test**
    /// (`CloudSyncSchemaParityTests`), y solo porque ese test fija el CONJUNTO de campos `reversePreMount*` del
    /// schema además de comprobar que quedan a `nil`: enumerar aquí los siete que hay deja verde un octavo. Lo que
    /// este método garantiza es que los seis sitios no diverjan entre sí, que es el otro fallo.
    func clearReversePreMountCeiling() {
        reversePreMountProgressAt = nil
        reversePreMountPhaseRaw = nil
        reversePreMountCauseRaw = nil
        reversePreMountCauseAt = nil
        reversePreMountCauseAccruedSeconds = nil
        reversePreMountDefinitiveAt = nil
        reversePreMountDefinitiveAccruedSeconds = nil
    }
}

// MARK: - Techo de la subida del snapshot

extension MigrationState {

    /// Borra los SEIS campos de los tres relojes del techo de `uploadingSnapshot`. Juntos siempre: un campo que
    /// sobreviva a la fase deja el techo venciendo con cero segundos de parada real en la visita siguiente. NO toca
    /// `snapshotExitReasonRaw`, que es el desenlace y no el reloj (ver su docblock). Lo que garantiza que un campo
    /// NUEVO de la familia no se quede fuera es `CloudSyncSchemaParityTests`, que deriva la familia del schema por su
    /// prefijo `snapshotStall`.
    func clearSnapshotStallCeiling() {
        snapshotStallProgressAt = nil
        snapshotStallCauseRaw = nil
        snapshotStallCauseAt = nil
        snapshotStallCauseAccruedSeconds = nil
        snapshotStallDefinitiveAt = nil
        snapshotStallDefinitiveAccruedSeconds = nil
    }
}

// MARK: - Techo de los tres pasos de la ida sin cifra que baje

extension MigrationState {

    /// Borra los CUATRO campos de los dos relojes del techo de `claimingMigration`, `assigningIdentity` y
    /// `cutover(.pending)`. Juntos siempre, por lo mismo que la subida. NO toca `forwardStepExitReasonRaw`, que es el
    /// desenlace y no el reloj. Lo que garantiza que un campo NUEVO de la familia no se quede fuera es
    /// `CloudSyncSchemaParityTests`, que deriva la familia del schema por su prefijo `forwardStepStall`.
    func clearForwardStepStallCeiling() {
        forwardStepStallProgressAt = nil
        forwardStepStallCauseRaw = nil
        forwardStepStallCauseAt = nil
        forwardStepStallCauseAccruedSeconds = nil
    }
}

// MARK: - Techo del efecto del adopt

extension MigrationState {

    /// Borra los TRES campos de los dos relojes del techo del efecto del adopt. Juntos siempre: un campo que sobreviva al
    /// intento deja el techo venciendo con cero segundos de parada real en el siguiente adopt. NO toca `adoptClaimExitRaw`,
    /// que es el desenlace y no el reloj. Lo que garantiza que un campo NUEVO de la familia no se quede fuera es
    /// `CloudSyncSchemaParityTests`, que deriva la familia del schema por su prefijo `adoptEffectStall`.
    func clearAdoptEffectStallCeiling() {
        adoptEffectStallProgressAt = nil
        adoptEffectStallDefinitiveAt = nil
        adoptEffectStallDefinitiveAccruedSeconds = nil
    }
}

// MARK: - Codec del journal (fase + efectos)

extension MigrationState {

    /// Lectura PURA y NO-lanzante de la fase journaleada. `phaseData == nil` ⇒ `.notStarted` (sin fallo).
    /// Un blob PRESENTE que NO decodifica ⇒ `.notStarted` + `decodeFailed = true`. **Ese `.notStarted` es un relleno, no
    /// una fase**: con `decodeFailed` nadie decide nada con él (ticket `an-undecodable-migration-phase-reads-as-never-started`).
    /// Los dos lectores lo devuelven como `.unreadable` y el runner no conduce (`isJournalUndecodable`).
    ///
    /// Renombrar o borrar un case lo impide `MigrationStateJournalTests`, que congela un fixture JSON literal por CADA
    /// case (APPEND-ONLY). Lo que ese test no puede impedir es el DOWNGRADE: un build con un case nuevo escribe un blob
    /// que uno anterior no entiende, y es el único camino real a este `catch`.
    func readPhase() -> (phase: MigrationPhase, decodeFailed: Bool) {
        guard let data = phaseData else { return (.notStarted, false) }
        do {
            return (try JSONDecoder().decode(MigrationPhase.self, from: data), false)
        } catch {
            return (.notStarted, true)
        }
    }

    /// Conveniencia de lectura (descarta el flag de fallo). Para el runner usar `readPhase()`.
    var phase: MigrationPhase { readPhase().phase }

    /// Efectos PENDIENTES journaleados. `nil` ⇒ `[]`. Un blob que no decodifica ⇒ `[]` + log DEBUG. Ese `[]` es un
    /// relleno: quien decide con los pendientes mira antes `isJournalUndecodable` (o usa `readPendingEffectsChecked()`).
    func readPendingEffects() -> [MigrationEffect] {
        readPendingEffectsChecked().effects
    }

    /// Los pendientes con el testigo de si el blob decodificó. Un `[]` silencioso diría «no queda nada por hacer» —ni la
    /// salida a medias de una vuelta (`hasPendingReverseExit`), ni el efecto del adopt— sobre un journal que no se entendió.
    func readPendingEffectsChecked() -> (effects: [MigrationEffect], decodeFailed: Bool) {
        guard let data = pendingEffectsData else { return ([], false) }
        do {
            return (try JSONDecoder().decode([MigrationEffect].self, from: data), false)
        } catch {
            #if DEBUG
            print("MigrationState: pendingEffects decode falló: \(error)")
            #endif
            return ([], true)
        }
    }

    /// ¿Hay algún campo del journal PRESENTE que este build no entiende y cuyo relleno CONCEDE? Ticket
    /// `an-undecodable-migration-phase-reads-as-never-started`: con `true`, el journal es ILEGIBLE, no «nunca empezó».
    ///
    /// - Fase, pendientes y pendientes del origen de la vuelta rellenan con `notStarted` y `[]`.
    /// - `forwardClaimIntentRaw` rellena con `.adoptIfExisting`, la intención que acepta una cuenta ya estable y sigue a
    ///   otro líder. Su `nil` es legítimo (filas anteriores a la v6); un valor DESCONOCIDO no.
    /// - `reverseOriginRaw` rellena con `.done` (el origen al que vuelven «Reintentar» y las salidas de la vuelta), que da
    ///   la migración por hecha. Mismo trato: `nil` legítimo, desconocido no.
    ///
    /// Los motivos de salida (`*ExitReasonRaw`, veredictos) quedan fuera a propósito: con un valor desconocido solo eligen
    /// otro texto, no conceden nada. **Si añades al journal un campo cuyo relleno concede, entra aquí.**
    var isJournalUndecodable: Bool {
        readPhase().decodeFailed || readPendingEffectsChecked().decodeFailed
            || readReverseOriginPendingEffectsChecked().decodeFailed
            || Self.isUnknown(forwardClaimIntentRaw, ForwardClaimIntent.init(rawValue:))
            || Self.isUnknown(reverseOriginRaw, ReverseOrigin.init(rawValue:))
    }

    /// Un raw PRESENTE que este build no reconoce. `nil` no es desconocido.
    private static func isUnknown<T>(_ raw: String?, _ decode: (String) -> T?) -> Bool {
        guard let raw else { return false }
        return decode(raw) == nil
    }

    /// Codifica y escribe la fase. Encode de un enum Codable golden-testeado → no puede fallar en la
    /// práctica; si fallara, se loguea (DEBUG) y `phaseData` queda intacto.
    func setPhase(_ phase: MigrationPhase) {
        do {
            phaseData = try JSONEncoder().encode(phase)
        } catch {
            #if DEBUG
            print("MigrationState: setPhase encode falló: \(error)")
            #endif
        }
    }

    /// Codifica y escribe los efectos pendientes. `[]` ⇒ escribe `[]` (no `nil`) — journal explícito.
    func setPendingEffects(_ effects: [MigrationEffect]) {
        do {
            pendingEffectsData = try JSONEncoder().encode(effects)
        } catch {
            #if DEBUG
            print("MigrationState: setPendingEffects encode falló: \(error)")
            #endif
        }
    }

    /// Los pendientes del origen guardados al empezar la vuelta (`reverseOriginPendingEffectsData`). `nil` ⇒ `[]`; un
    /// blob que no decodifica ⇒ `[]` + log DEBUG, como `readPendingEffects` (y como él, cuenta en `isJournalUndecodable`).
    func readReverseOriginPendingEffects() -> [MigrationEffect] {
        readReverseOriginPendingEffectsChecked().effects
    }

    private func readReverseOriginPendingEffectsChecked() -> (effects: [MigrationEffect], decodeFailed: Bool) {
        guard let data = reverseOriginPendingEffectsData else { return ([], false) }
        do {
            return (try JSONDecoder().decode([MigrationEffect].self, from: data), false)
        } catch {
            #if DEBUG
            print("MigrationState: reverseOriginPendingEffects decode falló: \(error)")
            #endif
            return ([], true)
        }
    }

    /// Guarda los pendientes del origen. `[]` ⇒ `nil`: sin nada que reponer no queda rastro en la fila.
    func setReverseOriginPendingEffects(_ effects: [MigrationEffect]) {
        guard !effects.isEmpty else {
            reverseOriginPendingEffectsData = nil
            return
        }
        do {
            reverseOriginPendingEffectsData = try JSONEncoder().encode(effects)
        } catch {
            #if DEBUG
            print("MigrationState: setReverseOriginPendingEffects encode falló: \(error)")
            #endif
        }
    }
}

// MARK: - Single-row load-or-create

extension MigrationState {

    /// Carga la fila única del journal o la crea perezosamente (espeja `CloudSyncEngine.loadOrCreateCursor`).
    /// Debe existir a lo sumo UNA fila. **Regla de secuenciación (runner):** llamar SOLO tras
    /// `awaitQuiescence` — el `save()` de la creación va al `mainContext` compartido en prod y flushearía
    /// el grafo personal a medio importar. Sin autor especial: el drain filtra entidades del store
    /// personal, `MigrationState` (sync-meta) nunca se drena.
    @MainActor
    static func loadOrCreate(in context: ModelContext) throws -> MigrationState {
        var descriptor = FetchDescriptor<MigrationState>()
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let state = MigrationState()
        context.insert(state)
        // Persistir de inmediato para no materializar un segundo single-row si el runner no avanza.
        try context.save()
        return state
    }
}
