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
    static let migrationState = 2
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
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
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
