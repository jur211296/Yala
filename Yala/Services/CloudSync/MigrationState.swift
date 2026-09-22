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
    static let migrationState = 8
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
    var reverseUploadProgressAt: Date?

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
        reverseAbortReasonRaw: String? = nil,
        reverseOriginPendingEffectsData: Data? = nil,
        forwardClaimIntentRaw: String? = nil,
        reversePreMountProgressAt: Date? = nil,
        reversePreMountPhaseRaw: String? = nil,
        reversePreMountCauseRaw: String? = nil,
        reversePreMountCauseAt: Date? = nil,
        reversePreMountCauseAccruedSeconds: Double? = nil,
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
        self.reverseAbortReasonRaw = reverseAbortReasonRaw
        self.reverseOriginPendingEffectsData = reverseOriginPendingEffectsData
        self.forwardClaimIntentRaw = forwardClaimIntentRaw
        self.reversePreMountProgressAt = reversePreMountProgressAt
        self.reversePreMountPhaseRaw = reversePreMountPhaseRaw
        self.reversePreMountCauseRaw = reversePreMountCauseRaw
        self.reversePreMountCauseAt = reversePreMountCauseAt
        self.reversePreMountCauseAccruedSeconds = reversePreMountCauseAccruedSeconds
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
    }
}

// MARK: - Techo de las fases previas al montaje de la vuelta

extension MigrationState {

    /// Borra los CINCO campos del techo de las fases previas al montaje: el reloj de fase con su sello, y los tres
    /// del reloj por causa. Existe porque se limpian SIEMPRE juntos y en seis sitios distintos —el reset tras
    /// rollback, el arranque de una vuelta nueva, los tres cierres de intento, el cambio de fase, la salida del
    /// techo y la normalización de un journal ilegible—, y un campo que se olvide en uno solo de ellos no deja la
    /// fila fea: deja el techo venciendo con cero segundos de parada real en el intento siguiente, que es el bug
    /// que el par del reloj de fase ya tuvo una vez.
    ///
    /// **Lo que garantiza que no se olvide un campo NUEVO no es este método, es su test**
    /// (`CloudSyncSchemaParityTests`), y solo porque ese test fija el CONJUNTO de campos `reversePreMount*` del
    /// schema además de comprobar que quedan a `nil`: enumerar aquí los cinco que hay deja verde un sexto. Lo que
    /// este método garantiza es que los seis sitios no diverjan entre sí, que es el otro fallo.
    func clearReversePreMountCeiling() {
        reversePreMountProgressAt = nil
        reversePreMountPhaseRaw = nil
        reversePreMountCauseRaw = nil
        reversePreMountCauseAt = nil
        reversePreMountCauseAccruedSeconds = nil
    }
}

// MARK: - Codec del journal (fase + efectos)

extension MigrationState {

    /// Lectura PURA y NO-lanzante de la fase journaleada. `phaseData == nil` ⇒ `.notStarted` (sin fallo).
    /// Un blob PRESENTE que NO decodifica (rot del enum `MigrationPhase`) ⇒ `.notStarted` + `decodeFailed`
    /// = `true` para que el runner emita el breadcrumb RUIDOSO (si esto dispara en mid-cutover real, el
    /// gate §i.9 leería "estable"). Estructural: `MigrationStateJournalTests` congela un fixture JSON
    /// literal por CADA case (APPEND-ONLY) → renombrar/borrar un case rompe el fixture ANTES de shippear.
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

    /// Efectos PENDIENTES journaleados. `nil` ⇒ `[]`. Un blob que no decodifica ⇒ `[]` + log DEBUG
    /// (no debería pasar: solo cases `String` conocidos; APPEND-ONLY).
    func readPendingEffects() -> [MigrationEffect] {
        guard let data = pendingEffectsData else { return [] }
        do {
            return try JSONDecoder().decode([MigrationEffect].self, from: data)
        } catch {
            #if DEBUG
            print("MigrationState: pendingEffects decode falló: \(error)")
            #endif
            return []
        }
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
    /// blob que no decodifica ⇒ `[]` + log DEBUG, como `readPendingEffects`.
    func readReverseOriginPendingEffects() -> [MigrationEffect] {
        guard let data = reverseOriginPendingEffectsData else { return [] }
        do {
            return try JSONDecoder().decode([MigrationEffect].self, from: data)
        } catch {
            #if DEBUG
            print("MigrationState: reverseOriginPendingEffects decode falló: \(error)")
            #endif
            return []
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
