//
//  DeferredIntentBufferLogic.swift
//  Yala
//
//  Pure-logic: codable layer for the DeferredIntentBuffer.
//
//  Some RouterIntents arrive when the app cannot present yet (pre-bootstrap,
//  mid-onboarding). Instead of dropping them, the gate
//  persists a serializable proxy in UserDefaults. On the next ready window
//  the buffer drains via the gate.
//
//  Not every intent is serializable (`.presentNewTransactionFromChatDraft` carries a live
//  prefill, the monetization prompts are re-decided on their own). Those have no proxy:
//  `serialize` returns nil and the gate drops them with its canary. When a payload DOES have a
//  stable identity, it gets its own case (`.navigateGroupDetail(groupID:)`).
//
//  El buffer tiene un segundo productor desde el 2026-10-11: `AppRouter.resetTransients` aparca aquí, al pasar a
//  segundo plano, las entradas pedidas desde fuera que aún no se habían presentado (`parksOnBackground`). Sin eso se
//  tiraban con el resto de transitorios (ticket `widget-and-siri-entries-lost-on-background`).
//

import Foundation

/// Persisted envelope. `version` enables schema evolution; unknown versions
/// are dropped silently in decode.
struct DeferredEntry: Codable, Equatable {
    let version: Int
    let createdAt: Date
    let payload: SerializableIntent

    static let currentVersion = 1

    init(payload: SerializableIntent, createdAt: Date = Date()) {
        self.version = Self.currentVersion
        self.createdAt = createdAt
        self.payload = payload
    }
}

/// Codable proxy for the subset of RouterIntents safe to persist across
/// app launches. Excludes intents whose payload contains live framework
/// objects (CKShare.Metadata, fetched accounts/budgets, runtime callbacks).
enum SerializableIntent: Codable, Equatable {
    case navigate(routerKey: String)
    /// `.navigate(.groupDetail(groupID:))` needs its own case: `routerKey`
    /// collapses `groupDetail` to the bare string "groupDetail", dropping the
    /// groupID. This dedicated case carries the ID across a launch.
    case navigateGroupDetail(groupID: String)
    case showInboxAlert(scheduledPayments: Int, subscriptions: Int, automations: Int)
    /// `.presentSharedImage(url)`: la foto compartida es un fichero de `PendingImages/` y su ruta basta para
    /// reconstruir el intent. Al drenar solo vuelve si el fichero sigue ahí (otra entrada pudo consumirlo). Hasta el
    /// 2026-10-10 este intent no se serializaba y el aplazamiento lo tiraba en silencio (canario «DROP
    /// non-serializable deferred intent»); lo recuperaba solo la siguiente ventana lista.
    case presentSharedImage(path: String)
    /// Entradas sin payload pedidas desde fuera (widget, Siri, Centro de Control, ⌘N) que seguían en cola al pasar a
    /// segundo plano. Las aparca `AppRouter.resetTransients`; caducan antes que el resto (`parkedEntryTTL`).
    case presentVoiceEntry
    case presentImageEntry
    case presentNewTransaction
    /// El consentimiento de IA que pidió una entrada de voz o imagen. `input` es el `rawValue` de `PendingAIInput`: un
    /// valor que este build no conozca se descarta al drenar.
    case requestAIConsent(input: String)
}

enum DeferredIntentBufferLogic {

    /// `true` if the intent has a faithful proxy in `SerializableIntent`.
    /// Returns false for intents carrying non-codable payloads.
    static func canSerialize(_ intent: RouterIntent) -> Bool {
        return serialize(intent) != nil
    }

    /// Lossy projection from RouterIntent to SerializableIntent. Returns nil
    /// for intents without a stable persistent representation:
    /// - `.navigate(.groupDetail(groupID:))` — serializes through the dedicated
    ///   `.navigateGroupDetail(groupID:)` case (the generic `.navigate(routerKey:)`
    ///   proxy would drop the groupID). This lets a group deep link
    ///   (`yala://groups/<id>`) survive a pre-bootstrap defer and re-emit on
    ///   drain in cold launch. Ver Bugs/qa_cold-launch-groupdetail-deeplink-no-routing.
    /// - `.presentSharedImage(url)` — serializa la RUTA del fichero (`.presentSharedImage(path:)`). Antes del
    ///   2026-10-10 devolvía `nil` y el aplazamiento lo perdía; la recuperación desde `PendingImages/`
    ///   (`checkForPendingSharedImage`) sigue ahí como segunda red.
    static func serialize(_ intent: RouterIntent) -> SerializableIntent? {
        switch intent {
        case .navigate(let dest):
            // groupDetail carries a groupID that `routerKey` collapses away —
            // route it through the dedicated case that preserves the ID.
            if case .groupDetail(let groupID) = dest {
                return .navigateGroupDetail(groupID: groupID)
            }
            // GUARD: any future DeepLinkDestination case with an associated value
            // needs its OWN SerializableIntent case above (like groupDetail). This
            // default drops any payload not in `routerKey` SILENTLY — and worse than
            // the original bug, the RouterEntryGate "DROP non-serializable" canary
            // won't fire (this returns a valid proxy, not nil), so a cold-launch
            // defer would lose the payload invisibly. Ver Bugs/qa_cold-launch-groupdetail-deeplink-no-routing.
            return .navigate(routerKey: dest.routerKey)
        case .showInboxAlert(let n):
            return .showInboxAlert(
                scheduledPayments: n.scheduledPayments,
                subscriptions: n.subscriptions,
                automations: n.automations
            )
        case .presentSharedImage(let url):
            guard url.isFileURL else { return nil }
            return .presentSharedImage(path: url.path)
        case .presentVoiceEntry:
            return .presentVoiceEntry
        case .presentImageEntry:
            return .presentImageEntry
        case .presentNewTransaction:
            return .presentNewTransaction
        case .requestAIConsent(let input):
            return .requestAIConsent(input: input.rawValue)
        default:
            return nil
        }
    }

    /// Lo que `AppRouter.resetTransients` aparca en el buffer al pasar a segundo plano en vez de tirarlo: las entradas
    /// que la persona pidió desde fuera y aún no ha visto. No traen datos (abren la hoja de voz, de imagen o de nuevo
    /// registro), pero sin esto el toque se perdía si había una hoja abierta u otra pestaña delante y la app salía antes
    /// de presentarlas.
    ///
    /// Fuera, a propósito: la hoja de Yala Pro (un paywall que vuelve solo al volver no es lo que la persona pidió), el
    /// borrador del chat (lo pide la propia app, con un payload vivo) y `.navigate` (otra conversación). La foto
    /// compartida tampoco: su fuente durable es `PendingImages/`.
    static func parksOnBackground(_ intent: RouterIntent) -> Bool {
        switch intent {
        case .presentVoiceEntry, .presentImageEntry, .presentNewTransaction, .requestAIConsent:
            return true
        default:
            return false
        }
    }

    /// Cuánto puede estar la app fuera con una entrada aparcada. Pasado esto, al volver no se presenta: una hoja de dictar
    /// que aparece horas después al abrir Yala desde el icono sorprende más que ayuda. El reloj arranca en cada paso a
    /// segundo plano (`createdAt` es el momento del aparcamiento), así que mide la ausencia, no la edad de la petición.
    static let parkedEntryTTL: TimeInterval = 15 * 60

    /// La caducidad de `payload`: la de las entradas aparcadas si lo es, y `fallback` (las 24 h del buffer) si no.
    static func ttl(for payload: SerializableIntent, fallback: TimeInterval) -> TimeInterval {
        switch payload {
        case .presentVoiceEntry, .presentImageEntry, .presentNewTransaction, .requestAIConsent:
            return min(parkedEntryTTL, fallback)
        case .navigate, .navigateGroupDetail, .showInboxAlert, .presentSharedImage:
            return fallback
        }
    }

    /// Inverse of `serialize`. `serialize` rejects unrecoverable cases
    /// up-front, so this function only needs the recoverable subset.
    static func deserialize(
        _ s: SerializableIntent,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> RouterIntent? {
        switch s {
        case .navigate(let key):
            guard let dest = deepLinkDestination(from: key) else { return nil }
            return .navigate(dest)
        case .navigateGroupDetail(let groupID):
            return .navigate(.groupDetail(groupID: groupID))
        case .showInboxAlert(let sched, let subs, let autos):
            return .showInboxAlert(PendingInboxNotification(
                scheduledPayments: sched,
                subscriptions: subs,
                automations: autos
            ))
        case .presentSharedImage(let path):
            // Ya consumida (la hoja la leyó y la borró) o purgada: no hay nada que presentar.
            guard fileExists(path) else { return nil }
            return .presentSharedImage(URL(fileURLWithPath: path))
        case .presentVoiceEntry:
            return .presentVoiceEntry
        case .presentImageEntry:
            return .presentImageEntry
        case .presentNewTransaction:
            return .presentNewTransaction
        case .requestAIConsent(let raw):
            guard let input = PendingAIInput(rawValue: raw) else { return nil }
            return .requestAIConsent(input)
        }
    }

    /// Encode a list of entries to JSON. Returns nil on failure.
    static func encode(_ entries: [DeferredEntry]) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(entries)
    }

    /// Decode entries from JSON with per-element tolerance. A single corrupt
    /// or unknown-schema entry does NOT sink the whole array. Used so that:
    /// - A future build serializes a new SerializableIntent case → older
    ///   builds that downgrade still recover the v1 entries they understand.
    /// - A storage corruption on one entry doesn't lose the rest.
    /// Returns `[]` only on totally-malformed input.
    static func decode(_ data: Data?) -> [DeferredEntry] {
        guard let data, !data.isEmpty else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Step 1: parse as opaque array of JSON objects (always succeeds for
        // well-formed JSON, regardless of entry shape).
        guard let rawArray = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            return []
        }
        // Step 2: decode each element independently; drop on per-element failure.
        var entries: [DeferredEntry] = []
        for element in rawArray {
            guard let elementData = try? JSONSerialization.data(withJSONObject: element) else {
                continue
            }
            guard let entry = try? decoder.decode(DeferredEntry.self, from: elementData) else {
                continue
            }
            guard entry.version == DeferredEntry.currentVersion else { continue }
            entries.append(entry)
        }
        return entries
    }

    /// Drops entries older than `ttl`. Default TTL = 24h. Las entradas aparcadas al pasar a segundo plano caducan antes
    /// (`ttl(for:fallback:)`).
    static func purgeExpired(
        _ entries: [DeferredEntry],
        now: Date,
        ttl: TimeInterval = 24 * 60 * 60
    ) -> [DeferredEntry] {
        entries.filter { now.timeIntervalSince($0.createdAt) < DeferredIntentBufferLogic.ttl(for: $0.payload, fallback: ttl) }
    }

    // MARK: - Internals

    /// Reverse-lookup of `DeepLinkDestination.routerKey`. Returns nil if the
    /// key is unknown (forward compatibility — older builds may have
    /// persisted a destination the current build no longer recognises).
    /// Note: `groupDetail` is NOT handled here — it round-trips through the
    /// dedicated `.navigateGroupDetail(groupID:)` case (its groupID isn't in `routerKey`).
    static func deepLinkDestination(from key: String) -> DeepLinkDestination? {
        switch key {
        case "panel": return .panel
        case "statistics": return .statistics
        case "records": return .records
        case "categories": return .categories
        case "planning": return .planning
        case "budgets": return .budgets
        case "inbox": return .inbox
        case "scheduledPayments": return .scheduledPayments
        case "recordsStandalone": return .recordsStandalone
        case "groups": return .groups
        default: return nil
        }
    }
}
