//
//  SyncOutboxMirror.swift
//  Yala
//
//  Espejo durable del `SyncOutbox` en el App Group (Modo Nube, CIERRE FINAL A1 / §d.5, riesgo A31).
//
//  PROBLEMA: Yala migra con SwiftData LIGHTWEIGHT PURO. Una migración que recree la tabla `SyncOutbox`
//  VACÍA borra deltas de writes financieros aplicados-local-pero-no-subidos, SIN tombstone →
//  divergencia silenciosa (ni el Merkle la ve hasta el próximo audit). El `SyncOutbox` es el ÚNICO
//  dato irrecuperable del pipeline (los otros 3 testigos —quarantine/cursor/identity— se re-pullan o
//  se backfillean). Ver spike `SpikeA1MigrationRecreationTests` (confirma que reabrir un store
//  persistido puede recrear la tabla vacía).
//
//  MECANISMO: un directorio de archivos en el App Group (`.../CloudSyncOutboxMirror/`, un archivo
//  `.atomic` JSON por delta). El espejo se escribe DENTRO del drain (único sitio donde nace la fila
//  `SyncOutbox`), en la MISMA vuelta síncrona que el `context.insert+save()`, ANTES de él (regla Q3
//  del spike S-A1: sin `await` entremedias, autosave no puede invertir el orden fila-durable-sin-espejo).
//  Al 2xx (I8e) se purga la fila + se borra su archivo espejo. Al boot, `CloudSyncEngine.
//  rehydrateOutboxFromMirror` re-inserta por DIFF incondicional las filas que la migración se llevó.
//
//  MOLDES (dos, no confundir): el MEDIO directorio-de-archivos espeja `SharedContainerService`
//  (`containerURL(forSecurityApplicationGroupIdentifier:)`, orden por `creationDate`, remove-on-consume,
//  como `PendingImages/`); el PATRÓN `nonisolated` + consume-after-save espeja `ApplePayPendingStore`
//  (que usa UserDefaults, NO su medio). Fork owner: directorio de archivos, NO UserDefaults — los
//  deltas PATCH son grandes/numerosos en catch-up masivo y `UserDefaults.dictionaryRepresentation()`
//  degrada con miles de keys.
//
//  GUARDARRAÍL M1 (device compartido, §5.2 [[MODO-NUBE-ENLACE-OPCIONAL]]): `CloudSyncOutboxMirror/` es
//  una 5ª superficie durable del App Group compartido que contiene MONTOS (`fieldsJSON`). En `.cloud`
//  el invitado B SÍ sincroniza → sus deltas se escriben aquí. DOS redes obligatorias: (a) el teardown
//  de sesión invitada llama `purgeAll()`; (b) `rehydrateOutboxFromMirror` filtra DURO por `userID` =
//  sesión actual (los de otra identidad se IGNORAN, no se borran aquí, no se re-insertan). Sin (b),
//  los deltas de B se re-insertarían en el outbox de A y se subirían bajo el JWT de A (fuga escalada).
//

import CryptoKit
import Foundation

// MARK: - DTO

/// Una fila del outbox espejada a un archivo del App Group. `nonisolated`: es un DTO puro que cruza
/// procesos (App Group) y se codifica/decodifica fuera del main actor; sin esto su conformance
/// `Codable` sintetizada quedaría MainActor-isolated (error en Swift 6 bajo
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
///
/// **`userID` (el `sub`) OBLIGATORIO** (owner-scoping M1). `op`/`tombstoneReason` se PRESERVAN aunque
/// el DTO de §d.5 no los liste: sin `op`, un tombstone re-hidratado se subiría como un `upsert` con
/// `fields="{}"` → el borrado NO se propagaría y la entidad resucitaría en otros devices (la
/// divergencia silenciosa que A1 existe para prevenir). `author` es el CONSTANTE del motor de recovery
/// (`CloudSyncOutbox`), no el autor de la transacción de origen (que es diagnóstico y no viaja en la
/// identidad de la fila).
nonisolated struct OutboxMirrorEntry: Codable, Equatable {
    /// El `sub` de la sesión que produjo el delta (owner-scoping M1). Obligatorio.
    let userID: String
    /// Identidad de sync de la entidad mutada (PK del upsert / identidad a borrar del tombstone).
    let syncID: UUID
    /// Tipo de entidad (`SyncEntityType.*`).
    let entityType: String
    /// Operación (`SyncOutboxOp.rawValue`): "upsert" | "tombstone". Preservado para re-hidratación fiel.
    let op: String
    /// HLC canónico c1 (46 chars). FIJADO — nunca se regenera (invariante §d.5).
    let hlc: String
    /// Identidad de idempotencia end-to-end de esta mutación. Preservada.
    let clientMutationID: UUID
    /// `fields` del delta (dominio limpio, PATCH parcial) serializado por el codec c1. "{}" en tombstone.
    let fieldsJSON: String
    /// `field_hlcs` (mapa unidad-de-coherencia → HLC) como JSON plano. `nil` en tombstone.
    let fieldHlcsJSON: String?
    /// Razón del tombstone (metadata de auditoría). `nil` en upsert.
    let tombstoneReason: String?
    /// Autor con el que se re-inserta la fila = constante del motor de recovery (echo-suppression).
    let author: String
    /// Cuándo se encoló la fila original (diagnóstico/orden; la verdad temporal es `hlc`).
    let createdAt: Date
}

// MARK: - Errores

/// Errores tipados del espejo. Nunca `try?` que silencie (regla inviolable): do/catch con log.
nonisolated enum SyncOutboxMirrorError: Error {
    /// El contenedor App Group no está disponible (entitlement mal configurado).
    case appGroupUnavailable
    /// Falló codificar la entry a JSON.
    case encodeFailed(underlying: Error)
    /// Falló escribir el archivo `.atomic`.
    case writeFailed(underlying: Error)
}

// MARK: - SyncOutboxMirror

/// Espejo del `SyncOutbox` como directorio de archivos del App Group. `nonisolated` (todo el tipo):
/// hace I/O de archivos + JSON, se invoca desde el drain `@MainActor` pero no necesita aislamiento.
/// `directoryURL` inyectable para tests (un temp dir aislado).
nonisolated struct SyncOutboxMirror {

    /// Nombre del subdirectorio dentro del contenedor App Group.
    static let directoryName = "CloudSyncOutboxMirror"

    /// Autor constante con el que las filas re-hidratadas se re-insertan. DEBE coincidir con
    /// `CloudSyncEngine.outboxSaveAuthor` (echo-suppression del drain). Literal (no referencia a un
    /// `static let` de un tipo `@MainActor`, que complicaría el init de esta global nonisolated); la
    /// paridad la fija `SyncOutboxMirrorTests.mirrorAuthor_matchesEngineOutboxAuthor`.
    static let author = "CloudSyncOutbox"

    /// El directorio `CloudSyncOutboxMirror/` (App Group en prod, temp en tests).
    let directoryURL: URL

    // MARK: Init

    /// Producción: resuelve `<AppGroup>/CloudSyncOutboxMirror/`. `nil` si el App Group no está disponible
    /// (mismo fail-soft que `SharedContainerService`).
    init?(appGroupIdentifier: String = WidgetURLHelper.appGroupIdentifier) {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            #if DEBUG
            print("SyncOutboxMirror: App Group container unavailable for \(appGroupIdentifier)")
            #endif
            return nil
        }
        self.directoryURL = container.appendingPathComponent(Self.directoryName, isDirectory: true)
    }

    /// Inyectable (tests): apunta directo al directorio espejo.
    init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    // MARK: Filenames

    /// Nombre de archivo DETERMINISTA a partir de `(syncID, hlc)`, filesystem-safe. El HLC contiene
    /// `:` (inseguro en algunos FS) → se hashea. `(syncID, hlc)` identifica unívocamente una fila:
    /// `clock.send` avanza el HLC por cada `appendRow`, así que un upsert y un tombstone de la misma
    /// entidad tienen HLCs distintos → sin colisión de op. `remove(syncID:hlc:)` recomputa este nombre
    /// (O(1), sin escanear).
    static func fileName(syncID: UUID, hlc: String) -> String {
        let key = "\(syncID.uuidString)\u{1}\(hlc)"
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.map { String(format: "%02x", $0) }.joined() + ".json"
    }

    // MARK: Directorio

    /// Crea el directorio espejo si no existe (idempotente).
    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    // MARK: Escritura

    /// Escribe un archivo `.atomic` para la entry. Nombre determinista por `(syncID, hlc)`. Lanza
    /// tipado (el llamador —el drain— hace do/catch y NO aborta: la SwiftData History es backup
    /// redundante y el canario de divergencia delata un fallo persistente).
    func write(_ entry: OutboxMirrorEntry) throws {
        try ensureDirectory()
        let data: Data
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]  // contenido estable/determinista
            data = try encoder.encode(entry)
        } catch {
            throw SyncOutboxMirrorError.encodeFailed(underlying: error)
        }
        let url = directoryURL.appendingPathComponent(Self.fileName(syncID: entry.syncID, hlc: entry.hlc))
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw SyncOutboxMirrorError.writeFailed(underlying: error)
        }
    }

    // MARK: Borrado (consume-after-2xx)

    /// Borra un archivo espejo por su nombre exacto. Idempotente (no lanza si ya no existe).
    func remove(name: String) {
        let url = directoryURL.appendingPathComponent(name)
        removeItem(at: url)
    }

    /// Borra el archivo espejo de `(syncID, hlc)` (recomputa el nombre determinista). Idempotente.
    /// Lo llama `CloudSyncEngine.confirmUploaded` al 2xx (I8e).
    func remove(syncID: UUID, hlc: String) {
        remove(name: Self.fileName(syncID: syncID, hlc: hlc))
    }

    /// Red M1(a): borra TODO el directorio espejo (teardown de sesión invitada en device compartido).
    func purgeAll() {
        let files = allFileURLs()
        for url in files { removeItem(at: url) }
    }

    private func removeItem(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            #if DEBUG
            print("SyncOutboxMirror: error removing \(url.lastPathComponent): \(error)")
            #endif
        }
    }

    // MARK: Lectura

    /// Entries del `userID` dado (owner-scoping M1: las de OTRA identidad se IGNORAN — no se borran ni
    /// se procesan aquí), ordenadas por `creationDate` del archivo ASCENDENTE (más viejo primero: orden
    /// natural de re-inserción/subida).
    func entriesForUser(_ userID: String) -> [OutboxMirrorEntry] {
        allDecoded()
            .filter { $0.entry.userID == userID }
            .sorted { $0.creationDate < $1.creationDate }
            .map(\.entry)
    }

    /// Todos los archivos `.json` del directorio (sin filtrar ni decodificar).
    private func allFileURLs() -> [URL] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            return contents.filter { $0.pathExtension.lowercased() == "json" }
        } catch {
            // Directorio inexistente (aún no se escribió nada) → sin entries. No es error real.
            return []
        }
    }

    /// Decodifica todos los archivos, descartando (con log) los corruptos — NO se borran (podrían ser
    /// de otro userID o de una versión futura). Devuelve entry + fecha de creación del archivo.
    private func allDecoded() -> [(entry: OutboxMirrorEntry, creationDate: Date)] {
        let decoder = JSONDecoder()
        var result: [(entry: OutboxMirrorEntry, creationDate: Date)] = []
        for url in allFileURLs() {
            let creationDate = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            do {
                let data = try Data(contentsOf: url)
                let entry = try decoder.decode(OutboxMirrorEntry.self, from: data)
                result.append((entry, creationDate))
            } catch {
                #if DEBUG
                print("SyncOutboxMirror: error decoding \(url.lastPathComponent): \(error)")
                #endif
            }
        }
        return result
    }
}
