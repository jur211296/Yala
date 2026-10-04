//
//  TrendsAIService.swift
//  Yala
//
//  Análisis con IA dedicado a la pestaña Tendencias (ticket
//  trends-insight-card-v2-bullets, D3). A diferencia de `InsightsLLMService`,
//  que resume todo el período, este recibe SOLO lo que pintan las cuatro
//  gráficas de Tendencias —histórico, comparativa, flujo y día de la semana— y
//  devuelve un bullet por gráfica.
//
//  Privacidad: el payload son agregados (totales por período y por día), nunca
//  movimientos sueltos ni notas.
//

import Foundation
import OpenAI

// MARK: - Input / Output

/// Lo que ve el usuario en Tendencias, ya calculado por la vista.
struct TrendsAIInput {
    let metric: TrendMetric
    let periodLabel: String
    /// Etiqueta del período comparado (ej. «Ago 26»). `nil` sin comparativa.
    let comparisonLabel: String?
    let currentTotal: Double
    let previousTotal: Double?
    let history: [TrendHistoryPoint]
    let historyUnit: TrendHistoryUnit?
    let cashFlow: CashFlowSummary?
    let weekdaySpending: [WeekdaySpending]
    /// Nombre localizado por weekday (1 = domingo … 7 = sábado).
    let weekdayNames: [Int: String]
    let currencyCode: String
    let currencyDisplay: String
    let locale: String
    let country: String
    let filtersActive: Bool
}

struct TrendsAIBullet: Equatable, Identifiable {
    let id: Int
    /// Gráfica de la que habla; decide el icono. `nil` si el modelo no la dijo.
    let source: TrendInsightBullet.Source?
    let text: String
}

// MARK: - Service

@MainActor
final class TrendsAIService {

    static let shared = TrendsAIService()

    /// R-V2-2: caché agresiva (24 h) — el análisis de un período cerrado no cambia.
    static let cacheTTL: TimeInterval = 86_400
    static let minInterval: TimeInterval = 5
    static let maxBullets = 4

    private struct CacheEntry {
        let bullets: [TrendsAIBullet]
        let timestamp: Date
    }

    private var cache: [String: CacheEntry] = [:]
    private var lastCallTime: Date?

    init() {}

    // MARK: Cache

    /// La clave cubre el payload entero (cualquier cifra distinta es otro
    /// análisis) + tono/enfoque del usuario.
    static func cacheKey(payload: [String: Any], tone: InsightTone, focus: InsightFocus) -> String {
        let json = serialize(payload)
        return "trends_\(json.hashValue)_\(tone.rawValue)_\(focus.rawValue)"
    }

    func cached(key: String, now: Date = .now) -> [TrendsAIBullet]? {
        guard let entry = cache[key], now.timeIntervalSince(entry.timestamp) < Self.cacheTTL else { return nil }
        return entry.bullets
    }

    // MARK: Generate

    /// - Parameter bypassCache: `true` desde «Regenerar»: pide un análisis nuevo
    ///   aunque haya uno guardado para estos datos.
    func generate(
        input: TrendsAIInput,
        tone: InsightTone,
        focus: InsightFocus,
        bypassCache: Bool
    ) async throws -> [TrendsAIBullet] {
        let payload = Self.buildPayload(input)
        let key = Self.cacheKey(payload: payload, tone: tone, focus: focus)

        let now = Date.now
        cache = cache.filter { now.timeIntervalSince($0.value.timestamp) < Self.cacheTTL }
        if !bypassCache, let hit = cached(key: key, now: now) { return hit }

        if let lastCall = lastCallTime, now.timeIntervalSince(lastCall) < Self.minInterval {
            throw InsightsLLMError.rateLimited
        }

        let client: OpenAI
        do {
            client = try await ProxyClientFactory.makeOpenAI(category: .insights)
        } catch {
            throw InsightsLLMError.networkError(error)
        }
        lastCallTime = Date.now

        let systemPrompt = Self.systemPrompt(input: input, tone: tone, focus: focus)
        let userMessage = "Datos de las gráficas de Tendencias:\n\(Self.serialize(payload))"
        let messages: [ChatQuery.ChatCompletionMessageParam] = [
            .init(role: .system, content: systemPrompt),
            .init(role: .user, content: userMessage),
        ].compactMap { $0 }
        guard messages.count == 2 else { throw InsightsLLMError.parseFailed }

        let query = ChatQuery(
            messages: messages,
            model: .gpt4_1_mini,
            responseFormat: .jsonObject,
            temperature: 0.4
        )

        do {
            let result = try await client.chats(query: query)
            guard let content = result.choices.first?.message.content else {
                throw InsightsLLMError.parseFailed
            }
            let bullets = try Self.parseResponse(content)
            cache[key] = CacheEntry(bullets: bullets, timestamp: Date.now)
            return bullets
        } catch let error as InsightsLLMError {
            throw error
        } catch {
            throw InsightsLLMError.networkError(error)
        }
    }

    // MARK: Payload (pure)

    static func buildPayload(_ input: TrendsAIInput) -> [String: Any] {
        var payload: [String: Any] = [
            "locale": input.locale,
            "country": input.country,
            "currency": input.currencyCode,
            "currency_display": input.currencyDisplay,
            "metric": input.metric.rawValue,
            "period": input.periodLabel,
            "filters_active": input.filtersActive,
        ]

        if !input.history.isEmpty {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            payload["history_unit"] = input.historyUnit?.rawValue ?? "period"
            payload["history_completed_periods"] = input.history.map {
                [
                    "start": formatter.string(from: $0.start),
                    "income": Int($0.income.rounded()),
                    "expense": Int($0.expense.rounded()),
                    "net": Int($0.net.rounded()),
                ] as [String: Any]
            }
        }

        if let label = input.comparisonLabel {
            var comparison: [String: Any] = [
                "previous_label": label,
                "current": Int(input.currentTotal.rounded()),
            ]
            if let previous = input.previousTotal {
                comparison["previous"] = Int(previous.rounded())
                if previous != 0 {
                    let variation = (input.currentTotal - previous) / abs(previous) * 100
                    comparison["variation_pct"] = Int(variation.rounded())
                }
            }
            payload["comparison"] = comparison
        }

        if let cashFlow = input.cashFlow {
            var flow: [String: Any] = [
                "income": Int(cashFlow.totalIncome.rounded()),
                "expense": Int(cashFlow.totalExpense.rounded()),
                "net": Int(cashFlow.netFlow.rounded()),
            ]
            if cashFlow.totalExpense > 0 {
                flow["income_covers_expense_pct"] = Int((cashFlow.totalIncome / cashFlow.totalExpense * 100).rounded())
            }
            payload["cash_flow"] = flow
        }

        let days = input.weekdaySpending.filter { $0.average > 0 }
        if !days.isEmpty {
            payload["weekday_avg_expense"] = days.sorted { $0.weekday < $1.weekday }.map {
                ["day": input.weekdayNames[$0.weekday] ?? "\($0.weekday)", "avg": Int($0.average.rounded())] as [String: Any]
            }
        }

        return payload
    }

    static func serialize(_ payload: [String: Any]) -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            #if DEBUG
            print("TrendsAIService: Error: \(error)")
            #endif
            return "{}"
        }
    }

    // MARK: Parse (pure)

    /// Espera `{"bullets":[{"chart":"trend|comparison|cashflow|weekday","text":"…"}]}`.
    /// Descarta textos vacíos y corta en `maxBullets`. Sin bullets válidos, falla.
    static func parseResponse(_ json: String) throws -> [TrendsAIBullet] {
        guard let data = json.data(using: .utf8) else { throw InsightsLLMError.parseFailed }
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw InsightsLLMError.parseFailed
        }
        guard let dict = object as? [String: Any],
              let items = dict["bullets"] as? [[String: Any]] else {
            throw InsightsLLMError.parseFailed
        }

        var result: [TrendsAIBullet] = []
        for item in items {
            guard let raw = item["text"] as? String else { continue }
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let source = (item["chart"] as? String).flatMap(source(for:))
            result.append(TrendsAIBullet(id: result.count, source: source, text: text))
            if result.count == maxBullets { break }
        }
        guard !result.isEmpty else { throw InsightsLLMError.parseFailed }
        return result
    }

    static func source(for chart: String) -> TrendInsightBullet.Source? {
        switch chart.lowercased() {
        case "trend": return .trend
        case "comparison": return .comparison
        case "cashflow", "cash_flow": return .cashFlow
        case "weekday": return .weekday
        default: return nil
        }
    }

    // MARK: Prompt

    private static func systemPrompt(input: TrendsAIInput, tone: InsightTone, focus: InsightFocus) -> String {
        let toneInstruction = InsightsLLMService.toneInstruction(for: tone, country: input.country)
        let focusInstruction = InsightsLLMService.focusInstruction(for: focus)
        let filters = input.filtersActive
            ? "\nFILTROS ACTIVOS: los datos son un subconjunto filtrado, no el total de las finanzas. Si es relevante, dilo.\n"
            : ""

        return """
        Eres un analista financiero personal. El usuario está mirando la pestaña Tendencias de su app, con estas gráficas:
        - trend: evolución de "\(input.metric.rawValue)" en el período. Usa history_completed_periods (períodos COMPLETOS anteriores, del más antiguo al más reciente) para hablar de la tendencia sostenida.
        - comparison: el período actual contra "previous_label".
        - cashflow: ingresos contra gastos del período.
        - weekday: gasto promedio por día de la semana.

        Escribe UN bullet por gráfica PRESENTE en el JSON (si falta su bloque, omítela), en ese orden: trend, comparison, cashflow, weekday. Entre 2 y 4 bullets.

        REGLAS CRÍTICAS:
        1. NUNCA menciones datos que NO estén en el JSON. Cada afirmación corresponde a un campo.
        2. Cada bullet cita al menos una cifra concreta.
        3. Máximo 110 caracteres por bullet. Una sola oración.
        4. Los montos están en \(input.currencyCode). SIEMPRE: \(input.currencyDisplay) NÚMERO (ej: \(input.currencyDisplay) 4,500). La divisa va ANTES del número.
        5. El período actual puede estar en curso: no lo compares en bruto con los períodos completos del histórico.
        \(filters)
        IDIOMA: Responde SIEMPRE en \(input.locale). Nunca mezcles idiomas.

        REGLAS DE VOZ (OBLIGATORIAS):
        - Tutea al usuario, como un amigo que sabe de finanzas. Lidera con el dato.
        - NUNCA culpar, regañar ni juzgar. Nunca preguntas.
        - NUNCA uses: "Debes...", "Tienes que...", "Es fácil", "Obviamente...".
        - Usa "gasto" o "ingreso", NUNCA "transacción".
        \(toneInstruction)\(focusInstruction)
        FORMATO: **negritas** para cifras y porcentajes.

        RESPUESTA (JSON estricto):
        {"bullets": [{"chart": "trend|comparison|cashflow|weekday", "text": "una oración"}]}
        """
    }
}
