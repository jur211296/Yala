//
//  PrefsOutbox.swift
//  Yala
//
//  Cola durable de preferencias salientes del Modo Nube (I13). En `.cloud`, `PreferenceSyncService.set`
//  escribe local + encola aquí (NO toca iKV); el `CloudSyncRuntime` la drena a `POST /prefs/push` en su
//  ciclo (misma cadencia que el dominio). Espeja el patrón `SyncOutboxMirror` (archivo App Group,
//  `nonisolated`, `directoryURL` inyectable para tests) pero es un ÚNICO archivo JSON (no directorio de
//  archivos): las prefs son ≤34 keys, `enqueue` SOBRESCRIBE por key (last-local-write-wins pre-push; el
//  LWW real es server-side por HLC), y el cursor del pull vive en el mismo archivo → un archivo es más
//  simple y coherente.
//
//  HLC (§d.5): el `hlc` de cada entry es la VERDAD TEMPORAL de la mutación, fijado al encolar vía un
//  `HLCClock` (mismo tipo/formato c1 que el motor). La MONOTONICIDAD se persiste en el propio archivo
//  (`lastIssuedHLC`): cada `enqueue` carga el reloj desde ese estado, emite (`send`), y re-persiste →
//  dos enqueues en el mismo ms avanzan el counter (sin `Date()` crudo: `now` inyectable).
//
//  NODE ID (desviación documentada): el motor genera un `NodeID` EFÍMERO por instancia (`NodeID.generate()`
//  en `CloudSyncEngine.init`) y NO lo persiste — no existe un SSOT persistido que reusar, y el enqueue de
//  prefs ocurre en `set()` (fuera del ciclo del runtime, sin acceso al engine). Por eso el `PrefsOutbox`
//  PERSISTE su propio `NodeID` en el archivo (se genera una vez y se reusa). El orden total del HLC es por
//  (physicalMs, counter, nodeID) → un nodeID estable persistido es estrictamente MEJOR que el efímero para
//  el desempate del LWW, y desacopla las prefs de los internos del engine.
//
//  OWNER-SCOPING M1 (device compartido): cada entry lleva el `userID` (sub) que la produjo. El push solo
//  sube las del owner actual (`entries(forUserID:)`); `purgeAll()` (teardown de sesión invitada, cableado
//  en `CloudSyncRuntime.teardownGuestSession`) borra TODO el archivo (contiene valores de prefs) para no
//  filtrar prefs de un invitado al siguiente sign-in.
//
//  `nonisolated` (todo el tipo): hace I/O de archivos + JSON; se invoca desde `@MainActor` pero no
//  necesita aislamiento. Un solo escritor (la app principal) → read-modify-write sin CAS es seguro (a
//  diferencia de `ApplePayPendingStore`, que tiene un escritor en el proceso del intent).
//

import Foundation

// MARK: - Errores

/// Errores tipados del outbox. Nunca `try?` que silencie (regla inviolable): do/catch con log.
nonisolated enum PrefsOutboxError: Error {
    /// El contenedor App Group no está disponible (entitlement mal configurado).
    case appGroupUnavailable
    /// Falló codificar/escribir el archivo.
    case persistFailed(underlying: Error)
    /// El `HLCClock` no pudo emitir (drift/overflow) — condición insegura para estampar un HLC.
    case clockFailed(underlying: Error)
}

// MARK: - PrefsOutbox

nonisolated struct PrefsOutbox {

    /// Una preferencia encolada, lista para `POST /prefs/push`.
    struct Entry: Codable, Equatable {
        /// El `sub` de la sesión que produjo la escritura (owner-scoping M1). Obligatorio.
        let userID: String
        /// El value en TEXT canónico (`PrefValueCodec.encode`). `nil` = borrar la key server-side
        /// (no lo produce `set()` hoy, pero el wire lo admite → se preserva).
        let value: String?
        /// HLC canónico c1 (46 chars) FIJADO al encolar — la verdad temporal (§d.5).
        let hlc: String
        /// `PrefKind.rawValue` de la key (referencia diagnóstica; el merge del pull usa `PrefSyncKey.kind`).
        let kind: String
    }

    /// Estado persistido del archivo (SSOT del outbox de prefs).
    private struct FileState: Codable {
        /// NodeID persistido (16 hex lowercase) para estampar el HLC. Se genera una vez.
        var nodeID: String
        /// Último HLC emitido (monotonicidad del reloj entre lanzamientos). `nil` = reloj fresco.
        var lastIssuedHLC: String?
        /// Cursor del pull de prefs (`server_seq`). Vive AQUÍ para NO acoplar `SyncCursor` (dominio) con
        /// la cadencia de prefs (decisión del plan §3: preferencia por archivo propio).
        var pullCursor: Int64
        /// Entries por key. `enqueue` sobrescribe por key.
        var entries: [String: Entry]

        init(nodeID: String, lastIssuedHLC: String? = nil, pullCursor: Int64 = 0, entries: [String: Entry] = [:]) {
            self.nodeID = nodeID
            self.lastIssuedHLC = lastIssuedHLC
            self.pullCursor = pullCursor
            self.entries = entries
        }
    }

    /// Nombre del subdirectorio dentro del contenedor App Group.
    static let directoryName = "CloudPrefsOutbox"
    /// Nombre del archivo JSON dentro del directorio.
    static let fileName = "prefs-outbox.json"

    /// El directorio contenedor (App Group en prod, temp en tests).
    let directoryURL: URL

    /// El archivo JSON del outbox.
    private var fileURL: URL { directoryURL.appendingPathComponent(Self.fileName) }

    // MARK: Init

    /// Producción: resuelve `<AppGroup>/CloudPrefsOutbox/`. `nil` si el App Group no está disponible
    /// (mismo fail-soft que `SyncOutboxMirror`).
    init?(appGroupIdentifier: String = WidgetURLHelper.appGroupIdentifier) {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            #if DEBUG
            print("PrefsOutbox: App Group container unavailable for \(appGroupIdentifier)")
            #endif
            return nil
        }
        self.directoryURL = container.appendingPathComponent(Self.directoryName, isDirectory: true)
    }

    /// Inyectable (tests): apunta directo al directorio del outbox.
    init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    // MARK: Enqueue (write side)

    /// Encola (o SOBRESCRIBE) la preferencia `key`. Estampa un HLC monótono (reloj persistido) y persiste
    /// el archivo atómicamente. `now` inyectable (nunca `Date()` crudo).
    /// - Throws: `PrefsOutboxError.clockFailed` si el reloj no puede emitir; `.persistFailed` en I/O.
    func enqueue(key: String, userID: String, value: PrefValue, now: Date = .now) throws {
        var state = try loadOrCreateState()

        // Reloj: cargar `latest` del estado durable, emitir, re-persistir el last-issued.
        let nodeID = try NodeID(validating: state.nodeID)
        let latest: HLC?
        if let raw = state.lastIssuedHLC {
            do {
                latest = try HLC.parse(raw)
            } catch {
                // HLC durable corrupto → reloj fresco desde physical-now (bajo skew podría perder un
                // LWW contra sí mismo — M2 review I13, logueado para no resetear en silencio).
                #if DEBUG
                print("PrefsOutbox: lastIssuedHLC corrupto (\(raw)) — reloj reiniciado: \(error)")
                #endif
                latest = nil
            }
        } else {
            latest = nil
        }
        var clock = HLCClock(nodeID: nodeID, latest: latest)
        let stamped: HLC
        do {
            stamped = try clock.send(now: now)
        } catch {
            throw PrefsOutboxError.clockFailed(underlying: error)
        }

        state.lastIssuedHLC = stamped.description
        state.entries[key] = Entry(
            userID: userID,
            value: PrefValueCodec.encode(value),
            hlc: stamped.description,
            kind: kind(forKey: key).rawValue
        )
        try persist(state)
    }

    // MARK: Read (push side)

    /// Entries del `userID` dado (owner-scoping M1: las de OTRA identidad se ignoran). Devuelve pares
    /// `(key, entry)` ordenados por HLC ascendente (orden causal de subida; el server LWW no lo exige,
    /// pero es determinista para el batch).
    func entries(forUserID userID: String) -> [(key: String, entry: Entry)] {
        let state: FileState?
        do {
            state = try loadState()
        } catch {
            // Archivo corrupto → push vacío ESTE ciclo, pero JAMÁS en silencio (regla inviolable).
            #if DEBUG
            print("PrefsOutbox: entries() no pudo leer el estado: \(error)")
            #endif
            state = nil
        }
        guard let state else { return [] }
        return state.entries
            .filter { $0.value.userID == userID }
            .sorted { $0.value.hlc < $1.value.hlc }
            .map { (key: $0.key, entry: $0.value) }
    }

    /// Purga las keys dadas del archivo (tras un push `applied`/`noop`). Idempotente.
    func removeEntries(keys: [String]) throws {
        guard !keys.isEmpty else { return }
        guard var state = try loadState() else { return }
        for k in keys { state.entries.removeValue(forKey: k) }
        try persist(state)
    }

    // MARK: Cursor (pull side)

    /// El cursor del pull de prefs (`server_seq`). `0` si no existe archivo aún (o ilegible — con log).
    var pullCursor: Int64 {
        do {
            return try loadState()?.pullCursor ?? 0
        } catch {
            #if DEBUG
            print("PrefsOutbox: pullCursor no pudo leer el estado: \(error)")
            #endif
            return 0
        }
    }

    /// Avanza el cursor del pull. Crea el archivo si no existía (preserva nodeID/entries si ya estaba).
    func setPullCursor(_ value: Int64) throws {
        var state = try loadOrCreateState()
        state.pullCursor = value
        try persist(state)
    }

    // MARK: Teardown (M1)

    /// Red M1: borra TODO el archivo del outbox (teardown de sesión invitada en device compartido).
    /// El archivo contiene VALORES de prefs → no puede sobrevivir a un cambio de owner. Idempotente.
    func purgeAll() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            #if DEBUG
            print("PrefsOutbox: purgeAll error: \(error)")
            #endif
        }
    }

    // MARK: - Persistencia

    /// Carga el estado del archivo, o `nil` si no existe. Lanza en corrupción (do/catch en el caller).
    private func loadState() throws -> FileState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(FileState.self, from: data)
    }

    /// Carga el estado o crea uno nuevo (con un nodeID recién generado y persistido). Un archivo corrupto
    /// se REEMPLAZA por uno nuevo (log): no bloquea el sync de prefs por basura en disco.
    private func loadOrCreateState() throws -> FileState {
        do {
            if let existing = try loadState() {
                return existing
            }
        } catch {
            // Corrupto → se REEMPLAZA por estado nuevo (nodeID+reloj reseteados) — logueado, nunca en
            // silencio (M1/M2 review I13): el reset de identidad del reloj afecta el desempate LWW.
            #if DEBUG
            print("PrefsOutbox: estado corrupto, se regenera nodeID/reloj: \(error)")
            #endif
        }
        // No existe (o corrupto): estado nuevo con nodeID persistido.
        return FileState(nodeID: NodeID.generate().value)
    }

    /// Escribe el estado atómicamente (contenido determinista con `.sortedKeys`).
    private func persist(_ state: FileState) throws {
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw PrefsOutboxError.persistFailed(underlying: error)
        }
    }

    /// El `PrefKind` de una key (para el campo diagnóstico `Entry.kind`). Fallback `.string` para una
    /// key que no sea `PrefSyncKey` (no debería ocurrir: `set()` solo recibe keys sincronizadas).
    private func kind(forKey key: String) -> PrefKind {
        PrefSyncKey(rawValue: key)?.kind ?? .string
    }
}
