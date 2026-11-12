//
//  StatsAIAutoRefreshStore.swift
//  Yala
//
//  Lo que necesitan los textos con IA de Estadísticas para generarse solos (encargo `estadisticas-ia-automatica`):
//  la última respuesta de cada RANURA (página + período + filtros + tono…) con sus cifras, para enseñarla mientras se
//  regenera, y el registro de lo que cada página generó, para el antirrebote y el techo diario
//  (`StatsAIAutoRefreshLogic`).
//
//  Vive en `UserDefaults` (inyectable en los tests), como `InsightsAIResultStore`: sobrevive al cambio de pestaña y al
//  relanzar. La respuesta va como `Data` para que las dos páginas, con respuestas de tipos distintos, compartan almacén.
//

import Foundation

@MainActor
final class StatsAIAutoRefreshStore {

    static let shared = StatsAIAutoRefreshStore()

    /// Ranuras guardadas por página: cubre ir y volver entre unos pocos períodos y filtros sin crecer sin límite.
    static let slotCapacity = 8

    /// Cambia si cambia el formato de la ranura o de lo guardado.
    static let version = "stats-ai-auto-v1"

    private let defaults: UserDefaults
    private let entriesKey: String
    private let ledgerKey: String

    /// Las dos claves del almacén de producción. «Vaciar datos» y `-uitest-reset` las borran
    /// (`DataWipeService.removeUserPreferenceKeys`): lo guardado describe los datos que se van.
    static let storageKeys = ["statsAIAuto.entries", "statsAIAuto.ledger"]

    init(defaults: UserDefaults = .standard, keyPrefix: String = "statsAIAuto") {
        self.defaults = defaults
        self.entriesKey = "\(keyPrefix).entries"
        self.ledgerKey = "\(keyPrefix).ledger"
    }

    struct Entry: Codable, Equatable {
        let page: StatsAIAutoRefreshLogic.Page
        let slot: String
        let fingerprint: String
        let savedAt: Date
        let snapshot: StatsAIAutoRefreshLogic.Snapshot
        let payload: Data
    }

    struct Generation: Codable, Equatable {
        let page: StatsAIAutoRefreshLogic.Page
        let slot: String
        let at: Date
        let automatic: Bool
    }

    // MARK: - Ranura

    /// Huella estable (SHA-256 con claves ordenadas, la de `InsightsAIResultStore`) de lo que define la ranura.
    static func slotKey(page: StatsAIAutoRefreshLogic.Page, parts: [String: Any]) -> String? {
        var payload = parts
        payload["_page"] = page.rawValue
        payload["_version"] = version
        return InsightsAIResultStore.stableHash(payload)
    }

    // MARK: - Respuestas

    func entry(page: StatsAIAutoRefreshLogic.Page, slot: String) -> Entry? {
        entries().first { $0.page == page && $0.slot == slot }
    }

    func response<R: Decodable>(_ type: R.Type, page: StatsAIAutoRefreshLogic.Page, slot: String) -> (Entry, R)? {
        guard let entry = entry(page: page, slot: slot) else { return nil }
        do {
            return (entry, try JSONDecoder().decode(R.self, from: entry.payload))
        } catch {
            #if DEBUG
            print("StatsAIAutoRefreshStore: Error: \(error)")
            #endif
            return nil
        }
    }

    func save<R: Encodable>(
        _ response: R,
        page: StatsAIAutoRefreshLogic.Page,
        slot: String,
        fingerprint: String,
        snapshot: StatsAIAutoRefreshLogic.Snapshot,
        now: Date = .now
    ) {
        do {
            let payload = try JSONEncoder().encode(response)
            var list = entries().filter { !($0.page == page && $0.slot == slot) }
            list.insert(
                Entry(page: page, slot: slot, fingerprint: fingerprint, savedAt: now, snapshot: snapshot, payload: payload),
                at: 0
            )
            var kept: [Entry] = []
            var perPage: [StatsAIAutoRefreshLogic.Page: Int] = [:]
            for item in list {
                let count = perPage[item.page, default: 0]
                guard count < Self.slotCapacity else { continue }
                perPage[item.page] = count + 1
                kept.append(item)
            }
            defaults.set(try JSONEncoder().encode(kept), forKey: entriesKey)
        } catch {
            #if DEBUG
            print("StatsAIAutoRefreshStore: Error: \(error)")
            #endif
        }
    }

    // MARK: - Registro de generaciones

    /// Apunta una generación. La automática se apunta al PEDIRLA, no al recibirla: un intento que falla también gasta,
    /// y así el techo acota los reintentos.
    func recordGeneration(page: StatsAIAutoRefreshLogic.Page, slot: String, automatic: Bool, now: Date = .now) {
        var list = ledger().filter { now.timeIntervalSince($0.at) < 2 * StatsAIAutoRefreshLogic.staleAfter }
        list.append(Generation(page: page, slot: slot, at: now, automatic: automatic))
        do {
            defaults.set(try JSONEncoder().encode(list), forKey: ledgerKey)
        } catch {
            #if DEBUG
            print("StatsAIAutoRefreshStore: Error: \(error)")
            #endif
        }
    }

    func today(
        page: StatsAIAutoRefreshLogic.Page,
        slot: String,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> StatsAIAutoRefreshLogic.Today {
        let all = ledger()
        let todays = all.filter { $0.page == page && calendar.isDate($0.at, inSameDayAs: now) }
        return StatsAIAutoRefreshLogic.Today(
            automaticCount: todays.filter(\.automatic).count,
            anyCount: todays.count,
            lastForSlot: all.filter { $0.page == page && $0.slot == slot }.map(\.at).max()
        )
    }

    // MARK: - Lectura

    private func entries() -> [Entry] { decode([Entry].self, key: entriesKey) }
    private func ledger() -> [Generation] { decode([Generation].self, key: ledgerKey) }

    private func decode<T: Decodable>(_ type: [T].Type, key: String) -> [T] {
        guard let data = defaults.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            // Lo que no se lee no se reusa: se escribirá encima con lo siguiente.
            #if DEBUG
            print("StatsAIAutoRefreshStore: Error: \(error)")
            #endif
            return []
        }
    }
}

#if DEBUG
/// Las respuestas fijas del seam `-uitest-stats-ai-reply` (`UITestHooks.statsAIReply`).
enum StatsAIUITestReply {
    static let summary = LLMInsightResponse(
        heroText: "Resumen de prueba de la IA.",
        cards: [LLMInsightCard(icon: "sparkles", text: "Observación de prueba de la IA.", sentiment: "neutral", tip: nil)],
        funFact: nil
    )
    static let trends = [TrendsAIBullet(id: 0, source: .trend, text: "Análisis de prueba de la IA.")]
}
#endif
