//
//  ChatIntentClassifierService.swift
//  Yala
//
//  Step 1 del pipeline Yala IA Registrar: clasifica el texto del user en
//  `ask` (pregunta), `register` (declarativa para crear transacción) o `ambiguous`
//  (frase retórica o sin verbo claro). NO incluye contexto financiero en el prompt
//  — solo necesita el texto. Ligero (`gpt-4.1-nano`) y barato.
//
//  Threshold: confidence < 0.7 se reclasifica como `ambiguous` (canned + chips).
//  Fallback regex: si la LLM call falla por red/API/parse, usa patrones obvios
//  (ES + EN). fr/de/it/pt sin few-shot caen al regex; si tampoco hay match,
//  default `ask` (downgrade silente, limitación conocida v1).
//

import Foundation
import Observation
import OpenAI

@MainActor
@Observable
final class ChatIntentClassifierService {

    // MARK: - Singleton

    static let shared = ChatIntentClassifierService()
    private init() {}

    // MARK: - Constants

    /// Confidence mínimo para aceptar la clasificación del LLM. Por debajo
    /// se downgrade a `.ambiguous` para forzar quick-reply chips en vez de adivinar.
    static let minConfidence: Double = 0.7
    private static let timeoutSeconds: TimeInterval = 8

    // MARK: - Public API

    struct Classification {
        let intent: ChatIntent
        let confidence: Double
        /// `true` si la clasificación vino del fallback regex (LLM falló).
        let usedFallback: Bool
    }

    /// Clasifica el texto del user. Si el LLM falla por red/parse, usa regex.
    /// Si ni el regex matchea, default a `.ask`.
    func classify(text: String) async -> Classification {
        guard NetworkMonitor.shared.isConnected else {
            return Self.regexFallback(text)
        }
        let client: OpenAI
        do {
            client = try await ProxyClientFactory.makeOpenAI(task: .chatIntent)
        } catch {
            #if DEBUG
            print("ChatIntentClassifierService: proxy no disponible (\(error)) — regex fallback")
            #endif
            return Self.regexFallback(text)
        }

        do {
            let llmResult = try await classifyWithLLM(text: text, client: client)
            // Threshold: low confidence → ambiguous
            if llmResult.intent != .ambiguous, llmResult.confidence < Self.minConfidence {
                return Classification(intent: .ambiguous, confidence: llmResult.confidence, usedFallback: false)
            }
            return llmResult
        } catch {
            #if DEBUG
            print("ChatIntentClassifierService: LLM failed (\(error)) — using regex fallback")
            #endif
            return Self.regexFallback(text)
        }
    }

    // MARK: - Ruta sin modelo (revisión del 2026-10-20)

    /// Las preguntas que se reconocen sin preguntarle a nadie: la ruta `ask` sale del teléfono y se ahorra
    /// `chat.intent`, que medía ~1,4 s por pregunta (banco de `docs/ai/revision-ia-2-2.md`). `nil` = la decide el
    /// clasificador, como siempre.
    ///
    /// Solo da `ask`, y solo cuando no hay nada que registrar: sin cifras (un importe es lo que distingue un registro y
    /// el «monto sin verbo» del ambiguo) y sin un verbo de apuntar. Con eso, o termina en «?»/«？», o empieza por «¿», o
    /// por un interrogativo que no puede abrir una frase de registro («cuánto», «how much», «combien», «wie viel»…). Un
    /// interrogativo ambiguo («que», «como») sin signo de pregunta no basta: «qué caro el almuerzo» es retórica.
    /// Lo fija `YalaIAQuestionRouteTests` contra los 115 casos del banco de `chat.intent`: no puede contradecir ninguno.
    static func preRoute(_ text: String) -> ChatIntent? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let folded = trimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        guard !matchesAny(folded, patterns: registerVerbPatterns) else { return nil }
        let opening = folded.trimmingCharacters(in: CharacterSet(charactersIn: "¿¡ "))
        // «¿Puedo gastar 500…?» trae una cifra y es una pregunta: sin «¿?» el clasificador la daba por ambigua (medido en
        // el simulador el 2026-10-20). Va antes del corte por cifras.
        if matchesAny(opening, patterns: affordabilityOpenings) { return .ask }
        guard folded.rangeOfCharacter(from: .decimalDigits) == nil else { return nil }
        if folded.hasPrefix("¿") || folded.hasSuffix("?") || folded.hasSuffix("？") { return .ask }
        return matchesAny(opening, patterns: unambiguousQuestionOpenings) ? .ask : nil
    }

    /// Verbos de apuntar en los idiomas de la app (ya sin tildes): «anota», «apúntame», «log», «adiciona», «ajoute»…
    private static let registerVerbPatterns = [
        #"\b(anot|apunt|registr|agreg|anad|guard|regist|adicion|ajout|enregistr|notier|aggiung|segn|noteer|zapisz)"#,
        #"\b(log|add|record|track|note)\b"#,
        #"\btrag\b.*\bein\b"#,
    ]

    /// «¿Puedo gastar…?», «¿me alcanza…?»: preguntas aunque traigan un importe.
    private static let affordabilityOpenings = [
        #"^((cuanto )?puedo gastar|me alcanza|alcanza para|me da para|can i (afford|spend)|how much can i spend|posso gastar|da para)\b"#,
    ]

    /// Aperturas que solo pueden ser una pregunta (ya sin tildes ni mayúsculas).
    private static let unambiguousQuestionOpenings = [
        #"^(cuant[oa]s?|cual(es)?|cuando|donde|por que)\b"#,
        #"^(quant[oa]s?|qual|quais|quando|onde)\b"#,
        #"^(how (much|many|does|do|did|is|are)|what|which|when|where|why|am i|is my|are my|do i|did i|can i)\b"#,
        #"^(combien|quel(le)?s?|pourquoi|est-ce que)\b"#,
        #"^(wie viel|wieviel|welche[rsn]?|warum|wann)\b"#,
        #"^(quant[ie]|quale|quali|perche)\b"#,
        #"^(hoeveel|welke|wanneer|waarom)\b"#,
        #"^(ile|jaki|jaka|jakie|kiedy|dlaczego)\b"#,
        // «¿Cómo voy?» y sus hermanas: «como» a secas puede ser «como pan», con el verbo de estado no.
        #"^como (voy|va|van|vamos|estoy|ando|ta|esta|estou|vai|vao)\b"#,
        #"^(show me|mostra(-me)?|ou en (est|sont|suis)|wie (steht|geht)|an welche[mn]?|come (sto|va|vanno))\b"#,
        #"^(hoe (sta|staat|gaat)|jak (idzie|ida|wyglada))\b"#,
    ]

    // MARK: - LLM Classification

    private func classifyWithLLM(text: String, client: OpenAI) async throws -> Classification {
        let systemPrompt = Self.buildSystemPrompt()
        let userPrompt = "Texto del usuario: \"\(text)\"\n\nResponde SOLO con el JSON."

        let messages: [ChatQuery.ChatCompletionMessageParam] = [
            .init(role: .system, content: systemPrompt),
            .init(role: .user, content: userPrompt),
        ].compactMap { $0 }

        let query = ChatQuery(
            messages: messages,
            model: .gpt4_1_nano,
            responseFormat: .jsonObject,
            temperature: 0
        )

        let result = try await callWithTimeout(query, client: client)
        guard let content = result.choices.first?.message.content else {
            throw ChatAssistantError.parseFailed
        }
        return try Self.parseClassificationJSON(content)
    }

    private func callWithTimeout(_ query: ChatQuery, client: OpenAI) async throws -> ChatResult {
        try await withThrowingTaskGroup(of: ChatResult.self) { group in
            group.addTask { try await client.chats(query: query) }
            group.addTask {
                try await Task.sleep(for: .seconds(Self.timeoutSeconds))
                throw ChatAssistantError.timeout
            }
            guard let first = try await group.next() else {
                throw ChatAssistantError.timeout
            }
            group.cancelAll()
            return first
        }
    }

    // MARK: - JSON Parsing (testeable, pure)

    /// Parsea el JSON del LLM. Schema esperado:
    /// `{ "intent": "ask"|"register"|"ambiguous", "confidence": 0..1 }`
    static func parseClassificationJSON(_ content: String) throws -> Classification {
        guard let data = content.data(using: .utf8) else {
            throw ChatAssistantError.parseFailed
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let intentRaw = obj["intent"] as? String,
              let intent = ChatIntent(rawValue: intentRaw)
        else {
            throw ChatAssistantError.parseFailed
        }
        let confidence = (obj["confidence"] as? Double).map { max(0, min(1, $0)) } ?? 0
        return Classification(intent: intent, confidence: confidence, usedFallback: false)
    }

    // MARK: - Regex Fallback (testeable, pure)

    /// Heurística defensiva ES+EN cuando el LLM falla. Orden importante:
    /// - 1º ask: interrogativos al inicio O `?` al final (gana sobre register en
    ///   frases como "cuánto gasté este mes?" — el verbo de gasto sería falso match).
    /// - 2º register: verbos de registro/anotación o gasto en imperativo/pretérito.
    /// - default: ask (downgrade conservador — un falso ask no rompe la app).
    static func regexFallback(_ text: String) -> Classification {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            return Classification(intent: .ask, confidence: 0, usedFallback: true)
        }

        // 1º Ask: interrogativos al inicio o `?` al final
        if matchesAny(normalized, patterns: [
            #"^(cuant[ao]s?|como|que|cual|donde|cuando|por que)\b"#,
            #"^(how|what|where|when|why|which)\b"#,
            #"\?$"#,
        ]) {
            return Classification(intent: .ask, confidence: 0.8, usedFallback: true)
        }

        // 2º Register: verbos de registro/anotación o verbos de gasto/compra
        if matchesAny(normalized, patterns: [
            #"^(registr[ao]|anot[ao]|anad[eo]|agrega|guarda)\b"#,
            #"\bgast[eo]\b"#,
            #"\bcompr[eo]\b"#,
            #"\bpag[ueo][eo]?\b"#,
            #"\bspent\b"#,
            #"\bbought\b"#,
            #"\bpaid\b"#,
            #"^(add|log|record|track)\b"#,
        ]) {
            return Classification(intent: .register, confidence: 0.8, usedFallback: true)
        }

        // Default conservador: ask
        return Classification(intent: .ask, confidence: 0.5, usedFallback: true)
    }

    private static func matchesAny(_ text: String, patterns: [String]) -> Bool {
        let folded = text.folding(options: .diacriticInsensitive, locale: .current)
        for pattern in patterns {
            let foldedPattern = pattern.folding(options: .diacriticInsensitive, locale: .current)
            if let regex = try? NSRegularExpression(pattern: foldedPattern, options: [.caseInsensitive]) {
                let range = NSRange(folded.startIndex..., in: folded)
                if regex.firstMatch(in: folded, options: [], range: range) != nil {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - System Prompt

    private static func buildSystemPrompt() -> String {
        """
        Eres un clasificador de intenciones para un chat financiero. Tu única tarea es leer un mensaje del usuario y devolver UN JSON con dos campos:

        {
          "intent": "ask" | "register" | "ambiguous",
          "confidence": número entre 0 y 1
        }

        Definiciones:
        - "ask": el usuario PREGUNTA sobre sus finanzas (cuánto gastó, cómo va con presupuestos, qué tendencia tiene, etc.). Empieza típicamente con un pronombre interrogativo o termina con signo de pregunta.
        - "register": el usuario QUIERE REGISTRAR uno o más gastos/ingresos. Es declarativo, en pretérito o imperativo. Trae monto y/o concepto.
        - "ambiguous": frase retórica (queja sin intención de registrar), monto sin verbo, mezcla confusa, o intención poco clara. Cuando dudes, usa esto.

        Few-shot:
        - "hoy gasté 50 en mercado" → {"intent":"register","confidence":0.95}
        - "registra 30 soles de gasolina" → {"intent":"register","confidence":0.98}
        - "compré pan por 12" → {"intent":"register","confidence":0.92}
        - "anota 100 USD de salario" → {"intent":"register","confidence":0.95}
        - "hoy gasté 50 en mercado y 30 en gasolina" → {"intent":"register","confidence":0.95}
        - "log 25 dollars for coffee" → {"intent":"register","confidence":0.9}
        - "I spent 50 on groceries today" → {"intent":"register","confidence":0.92}
        - "cuánto gasté en mercado este mes" → {"intent":"ask","confidence":0.95}
        - "cómo voy con mis presupuestos" → {"intent":"ask","confidence":0.95}
        - "cuál es mi mayor gasto" → {"intent":"ask","confidence":0.92}
        - "how much did I spend on food?" → {"intent":"ask","confidence":0.95}
        - "what's my biggest budget" → {"intent":"ask","confidence":0.92}
        - "gasté demasiado en restaurantes" → {"intent":"ambiguous","confidence":0.5}
        - "uf, las cuentas de este mes" → {"intent":"ambiguous","confidence":0.4}
        - "50 soles en mercado" → {"intent":"ambiguous","confidence":0.55}
        - "tengo poca plata" → {"intent":"ambiguous","confidence":0.3}
        - "puedo gastar 500 en unas zapatillas" → {"intent":"ask","confidence":0.92}
        - "me alcanza para un viaje de 3000 el próximo mes" → {"intent":"ask","confidence":0.92}
        - "can I afford a 200 dollar dinner" → {"intent":"ask","confidence":0.92}

        Reglas:
        - NO inventes datos del usuario.
        - NO añadas comentarios ni texto fuera del JSON.
        - Si el mensaje mezcla pregunta + acción, prioriza "register" si el monto es claro; "ambiguous" si no.
        - Preguntar si puede gastar un monto o si le alcanza es "ask", aunque traiga el monto y no lleve signos de pregunta.
        - confidence refleja qué tan seguro estás. Por debajo de 0.7 prefiero que pongas "ambiguous" directamente.
        """
    }
}
