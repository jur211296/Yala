//
//  InsightsAIResultStore.swift
//  Yala
//
//  El último «Resumen con IA» de Estadísticas › Resumen, guardado por la HUELLA de lo que se le envió al servicio de IA
//  (UX 2.2 · L11-7, decisión de Jürgen del 2026-10-18: «que la IA salga automática, sin depender de un clic, pero no
//  regeneremos cada vez que abra la pestaña: si no ha habido nuevos registros o algún filtrado no deberíamos necesitar
//  nuevo dato»).
//
//  La huella sale del resumen agregado que viaja al servicio (totales, variaciones, categorías, compromisos,
//  necesidades, filtros activos, idioma y país) más el período, el tono, el enfoque y el formato de divisa: todo lo que
//  cambia la respuesta. Si nada de eso cambió, la respuesta guardada vale y no se gasta una llamada. Un registro nuevo,
//  editado o borrado que mueva algún número cambia la huella; uno que no mueve ninguno no la cambia, y eso es lo que se
//  quiere: el resumen diría lo mismo.
//
//  Antes había una caché en memoria de 5 minutos (`InsightsLLMService`) que además se vaciaba en cada recálculo: cambiar
//  de pestaña y volver ya perdía el resultado. Esta vive en disco, así que sobrevive al cambio de pestaña y al relanzar.
//

import CryptoKit
import Foundation

@MainActor
final class InsightsAIResultStore {

    static let shared = InsightsAIResultStore()

    /// Cuántas respuestas se guardan, de la más reciente a la más vieja. Cubre ir y volver entre unos pocos períodos y
    /// filtros sin crecer sin límite.
    static let capacity = 6

    /// Cambia si cambia el formato de la huella o del prompt: así no se sirve una respuesta pensada para otro.
    static let fingerprintVersion = "insights-ai-v1"

    private let defaults: UserDefaults
    private let storageKey: String

    init(defaults: UserDefaults = .standard, storageKey: String = "insightsAI.savedResults") {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    struct Entry: Codable, Equatable {
        let fingerprint: String
        let savedAt: Date
        let response: LLMInsightResponse
    }

    // MARK: - Huella

    /// SHA-256 de lo que se le envía al servicio de IA y de lo que cambia su respuesta. El JSON va con las claves
    /// ordenadas: dos diccionarios iguales dan la misma huella en cualquier lanzamiento (`hashValue` no: cambia en cada
    /// arranque, y por eso la clave de la caché en memoria no servía entre lanzamientos).
    static func fingerprint(
        aggregatedData: [String: Any],
        period: String,
        customRange: DateInterval?,
        tone: InsightTone,
        focus: InsightFocus,
        currencyFormat: String
    ) -> String? {
        var payload = aggregatedData
        payload["_period"] = period
        if let customRange {
            payload["_range"] = [customRange.start.timeIntervalSince1970, customRange.end.timeIntervalSince1970]
        }
        payload["_tone"] = tone.rawValue
        payload["_focus"] = focus.rawValue
        payload["_currencyFormat"] = currencyFormat
        payload["_version"] = fingerprintVersion
        guard JSONSerialization.isValidJSONObject(payload) else { return nil }
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        } catch {
            #if DEBUG
            print("InsightsAIResultStore: Error: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Lectura y escritura

    func response(for fingerprint: String) -> LLMInsightResponse? {
        entries().first { $0.fingerprint == fingerprint }?.response
    }

    func save(_ response: LLMInsightResponse, for fingerprint: String, now: Date = .now) {
        var list = entries().filter { $0.fingerprint != fingerprint }
        list.insert(Entry(fingerprint: fingerprint, savedAt: now, response: response), at: 0)
        if list.count > Self.capacity { list = Array(list.prefix(Self.capacity)) }
        do {
            defaults.set(try JSONEncoder().encode(list), forKey: storageKey)
        } catch {
            #if DEBUG
            print("InsightsAIResultStore: Error: \(error)")
            #endif
        }
    }

    func removeAll() {
        defaults.removeObject(forKey: storageKey)
    }

    private func entries() -> [Entry] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        do {
            return try JSONDecoder().decode([Entry].self, from: data)
        } catch {
            // Una lista que no se lee no se reusa: se regenerará y se escribirá encima.
            #if DEBUG
            print("InsightsAIResultStore: Error: \(error)")
            #endif
            return []
        }
    }
}
