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
//  (`lastIssuedHLC`): cada `enqueue` carga el reloj desde ese estado, emite (`sendLocal`), y re-persiste →
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
    /// El archivo EXISTE y no se dejó LEER (`Data(contentsOf:)` lanzó: permisos, protección de datos antes del primer
    /// desbloqueo, E/S). No es corrupción: lo que hay dentro puede estar perfectamente bien, así que nadie escribe
    /// encima y quien lo recibe reintenta más tarde (ticket `prefs-outbox-reads-an-unreadable-file-as-corrupt-and-overwrites-it`).
    case readFailed(underlying: Error)
    /// El archivo se leyó y no DECODIFICA. Lo lanza `removeEntries`; `syncSnapshot` lo lee vacío y
    /// `loadOrCreateState` lo reemplaza por un estado nuevo, que es el trato de siempre.
    case corrupt(underlying: Error)
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
    ///
    /// Estampa con `HLCClock.sendLocal`, no con `send` (ticket `personal-clock-rollback-wedges-the-drain-forever`): este
    /// reloj solo avanza con los `enqueue` de este teléfono, así que `lastIssuedHLC` solo queda más de 5 min por delante
    /// si una preferencia se cambió con la hora adelantada. Con `send` cada cambio posterior salía `clockFailed` hasta que
    /// la hora real lo alcanzara, y el llamador lo descarta: ese cambio no subía nunca. Con `sendLocal` sale por encima del
    /// último emitido, y la monotonicidad que protege al teléfono de su propio pasado sigue intacta.
    /// - Throws: `PrefsOutboxError.clockFailed` si el reloj no puede emitir (solo un año fuera de 0001–9999);
    ///   `.readFailed` si el archivo existe y no se deja leer (no se encola y no se escribe nada: lo pendiente se
    ///   conserva); `.persistFailed` en la escritura.
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
            stamped = try clock.sendLocal(eventTime: now)
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

    /// Lo que el ciclo de prefs necesita para decidir, en UNA lectura: las entries del owner y el cursor del pull.
    struct SyncSnapshot {
        let entries: [(key: String, entry: Entry)]
        let pullCursor: Int64
    }

    /// La lectura del ciclo de prefs (`CloudSyncRuntime.syncPrefsOnce`). **Lanza `.readFailed` si el archivo existe y no
    /// se deja leer**: ahí «no pude leer» no puede ser «no hay nada», porque con `[]` el ciclo se saltaba el push y con
    /// el cursor a `0` bajaba todas las prefs del backend, y el merge (gana el remoto) revertía en pantalla los cambios
    /// que esperaban aquí. Sin archivo: vacío y cursor `0`. Corrupto: lo mismo, con log — es el trato de siempre, y el
    /// `setPullCursor` del final del ciclo lo reemplaza.
    func syncSnapshot(forUserID userID: String) throws -> SyncSnapshot {
        let state: FileState?
        switch try readState() {
        case .absent:
            state = nil
        case .decoded(let decoded):
            state = decoded
        case .undecodable(let error):
            #if DEBUG
            print("PrefsOutbox: syncSnapshot — estado corrupto, se lee vacío: \(error)")
            #endif
            state = nil
        }
        guard let state else { return SyncSnapshot(entries: [], pullCursor: 0) }
        return SyncSnapshot(entries: Self.ownedEntries(of: state, userID: userID), pullCursor: state.pullCursor)
    }

    /// Entries del `userID` dado (owner-scoping M1: las de OTRA identidad se ignoran). Devuelve pares
    /// `(key, entry)` ordenados por HLC ascendente (orden causal de subida; el server LWW no lo exige,
    /// pero es determinista para el batch).
    ///
    /// **Tolerante**: un archivo ilegible o corrupto devuelve `[]` con log. Sirve para LEER una señal; quien DECIDE algo
    /// que no se pueda deshacer con ella usa `syncSnapshot`, que separa «no pude leer» de «no hay».
    func entries(forUserID userID: String) -> [(key: String, entry: Entry)] {
        let state: FileState?
        do {
            state = try loadState()
        } catch {
            // Ilegible o corrupto → vacío, pero JAMÁS en silencio (regla inviolable).
            #if DEBUG
            print("PrefsOutbox: entries() no pudo leer el estado: \(error)")
            #endif
            state = nil
        }
        guard let state else { return [] }
        return Self.ownedEntries(of: state, userID: userID)
    }

    private static func ownedEntries(of state: FileState, userID: String) -> [(key: String, entry: Entry)] {
        state.entries
            .filter { $0.value.userID == userID }
            .sorted { $0.value.hlc < $1.value.hlc }
            .map { (key: $0.key, entry: $0.value) }
    }

    /// Purga lo que se subió (tras un push `applied`/`noop`): `pushed` es `key → hlc` de las entries que viajaron en el
    /// batch. **Solo retira una entry si su `hlc` sigue siendo el que se subió** (ticket
    /// `prefs-push-purge-drops-a-change-made-during-the-upload`): el `await` del push suelta el main actor, y un `set()`
    /// en esa ventana reencola la misma key con un HLC nuevo. Purgar por key se llevaba ese cambio, que no subía nunca.
    /// Igualdad exacta, no «≤»: cada `enqueue` emite un HLC estrictamente mayor, así que el mismo HLC es la misma
    /// escritura, y uno distinto —más nuevo, o de otra identidad— se queda para el ciclo siguiente. Idempotente.
    func removeEntries(pushed: [String: String]) throws {
        guard !pushed.isEmpty else { return }
        guard var state = try loadState() else { return }
        for (key, hlc) in pushed where state.entries[key]?.hlc == hlc {
            state.entries.removeValue(forKey: key)
        }
        try persist(state)
    }

    // MARK: Cursor (pull side)

    /// El cursor del pull de prefs (`server_seq`). `0` si no existe archivo aún (o ilegible — con log). Tolerante,
    /// como `entries(forUserID:)`: el ciclo de prefs lee el suyo con `syncSnapshot`.
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

    /// Avanza el cursor del pull sin integrar nada en el reloj: es `recordPull` sin HLC, y por eso comparte con él la
    /// lectura y la escritura (los casos de archivo ilegible y corrupto de `PrefsOutboxTests` cubren los dos). No escribe
    /// si el cursor no cambia.
    /// - Throws: `.readFailed` sin escribir si el archivo no se deja leer; `.persistFailed` en la escritura.
    func setPullCursor(_ value: Int64) throws {
        try recordPull(newCursor: value, pulledHLCs: [])
    }

    /// Cierra la lectura de una página del pull de prefs en UNA escritura: avanza el cursor (si `newCursor` no es `nil`) e
    /// integra en el reloj (`lastIssuedHLC`) los HLC que bajaron (`HLCClock.observePulled`). Escribe solo si algo cambió.
    ///
    /// Integrar es lo que impide que este teléfono, tras VER una preferencia que otro dispositivo cambió, la cambie con un HLC
    /// más bajo, pierda en el servidor (`noop/stale`), purgue su cambio y se quede mostrando un valor que el servidor no
    /// tiene (`personal-clock-ahead-wins-every-conflict-until-real-time-catches-up`). Hasta este cambio el reloj de prefs solo
    /// lo avanzaban sus propios `enqueue`. El servidor acota todo HLC guardado a `now() + 60 s`
    /// (`qa/cloud/hlc01_cap_future_hlc.sql`), así que la guarda de 5 min solo deja fuera un remoto de verdad adelantado.
    /// - Returns: el motivo de cada HLC que no se pudo integrar (para el rastro del llamador). Uno que no supera al reloj
    ///   propio no cuenta; uno que no parsea, tampoco (no es un reloj que mover).
    /// - Throws: `.readFailed` sin escribir si el archivo no se deja leer; `.persistFailed` en la escritura.
    @discardableResult
    func recordPull(newCursor: Int64?, pulledHLCs: [String], now: Date = .now) throws -> [String] {
        var state = try loadOrCreateState()
        var changed = false
        if let newCursor, newCursor != state.pullCursor {
            state.pullCursor = newCursor
            changed = true
        }

        var rejected: [String] = []
        // Un `nodeID` del archivo que no valida no frena el cursor: sin él la misma página se volvería a bajar y a fusionar
        // (gana el remoto) en cada ciclo. Se integra con uno de paso: el reloj solo se usa aquí para `max`, y el
        // `enqueue` siguiente lanza con el mismo `nodeID` igual que antes de este cambio.
        let nodeID: NodeID
        do {
            nodeID = try NodeID(validating: state.nodeID)
        } catch {
            #if DEBUG
            print("PrefsOutbox: recordPull — nodeID del archivo inválido, se integra con uno de paso: \(error)")
            #endif
            nodeID = NodeID.generate()
        }
        if !pulledHLCs.isEmpty {
            var latest: HLC?
            if let raw = state.lastIssuedHLC {
                do {
                    latest = try HLC.parse(raw)
                } catch {
                    // Mismo trato que `enqueue`: un reloj durable corrupto arranca fresco (con log, nunca en silencio).
                    #if DEBUG
                    print("PrefsOutbox: recordPull — lastIssuedHLC corrupto (\(raw)), reloj reiniciado: \(error)")
                    #endif
                    latest = nil
                }
            }
            var clock = HLCClock(nodeID: nodeID, latest: latest)
            for raw in pulledHLCs {
                let remote: HLC
                do {
                    remote = try HLC.parse(raw)
                } catch {
                    #if DEBUG
                    print("PrefsOutbox: recordPull — HLC bajado que no parsea (\(raw)): \(error)")
                    #endif
                    continue
                }
                if case .rejected(let reason) = clock.observePulled(remote, now: now) {
                    rejected.append(reason)
                }
            }
            if let advanced = clock.latest, advanced != latest {
                state.lastIssuedHLC = advanced.description
                changed = true
            }
        }

        if changed { try persist(state) }
        return rejected
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

    /// Los tres desenlaces de mirar el archivo. El cuarto, «existe y no se deja leer», no es un caso: LANZA
    /// `.readFailed`, para que ningún `switch` pueda tratarlo como ausente o corrupto por descuido.
    private enum StateRead {
        case absent
        case decoded(FileState)
        case undecodable(Error)
    }

    /// Lee el archivo separando LECTURA de DECODE (ticket `prefs-outbox-reads-an-unreadable-file-as-corrupt-and-overwrites-it`).
    /// Hasta ese ticket los dos fallos caían en el mismo `catch` de `loadOrCreateState`, y un archivo que solo no se
    /// dejaba leer se reemplazaba por uno vacío en el siguiente `enqueue` o `setPullCursor`: las prefs pendientes no
    /// subían nunca y se reseteaban el `nodeID` y el reloj del LWW. **No fundas las dos ramas**: el `do` de la lectura
    /// envuelve SOLO `Data(contentsOf:)`.
    private func readState() throws -> StateRead {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .absent }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            #if DEBUG
            print("PrefsOutbox: el archivo existe y no se deja leer — no se toca: \(error)")
            #endif
            throw PrefsOutboxError.readFailed(underlying: error)
        }
        do {
            return .decoded(try JSONDecoder().decode(FileState.self, from: data))
        } catch {
            return .undecodable(error)
        }
    }

    /// Carga el estado del archivo, o `nil` si no existe. Lanza `.readFailed` si no se deja leer y `.corrupt` si no
    /// decodifica (do/catch en el caller).
    private func loadState() throws -> FileState? {
        switch try readState() {
        case .absent: return nil
        case .decoded(let state): return state
        case .undecodable(let error): throw PrefsOutboxError.corrupt(underlying: error)
        }
    }

    /// Carga el estado o crea uno nuevo (con un nodeID recién generado y persistido). Un archivo CORRUPTO se
    /// REEMPLAZA por uno nuevo (log): no bloquea el sync de prefs por basura en disco. Un archivo que no se deja
    /// LEER no: `readState` lanza `.readFailed`, el llamador no escribe nada y lo pendiente sigue ahí para el
    /// siguiente intento.
    private func loadOrCreateState() throws -> FileState {
        switch try readState() {
        case .decoded(let existing):
            return existing
        case .undecodable(let error):
            // Corrupto → se REEMPLAZA por estado nuevo (nodeID+reloj reseteados) — logueado, nunca en
            // silencio (M1/M2 review I13): el reset de identidad del reloj afecta el desempate LWW.
            #if DEBUG
            print("PrefsOutbox: estado corrupto, se regenera nodeID/reloj: \(error)")
            #endif
            return FileState(nodeID: NodeID.generate().value)
        case .absent:
            return FileState(nodeID: NodeID.generate().value)
        }
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
