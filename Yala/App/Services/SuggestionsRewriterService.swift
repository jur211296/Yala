//
//  SuggestionsRewriterService.swift
//  Yala
//
//  Detecta sugerencias del LLM que mencionan elementos inexistentes (categorías,
//  budgets, subcategorías, tags) y las reescribe usando una segunda LLM call que
//  preserva intención + gramática usando solo nombres reales del whitelist.
//
//  Si todas las sugerencias son válidas, no hay LLM call (zero overhead).
//  Si tras rewrite hay <minItems válidas, throws .tooFewItems → caller cae a
//  rule-based fallback.
//

import Foundation
import OpenAI

@MainActor @Observable
final class SuggestionsRewriterService {

    // MARK: - Singleton

    static let shared = SuggestionsRewriterService()
    private init() {}

    // MARK: - Whitelist

    /// Whitelist de nombres reales del user — categorías, subcategorías, budgets, tags.
    /// Se usa para detectar sugerencias inválidas y para el prompt de reescritura.
    struct Whitelist: Sendable {
        let categories: [String]
        let subcategories: [String]
        let budgets: [String]
        let tags: [String]
        let merchants: [String]

        /// Lista plana case-insensitive para validación rápida.
        var lowercasedAll: Set<String> {
            Set(
                (categories + subcategories + budgets + tags + merchants)
                    .map { $0.lowercased() }
            )
        }

        /// Snippet legible para incluir en el prompt LLM.
        func toPromptSnippet() -> String {
            var parts: [String] = []
            if !categories.isEmpty {
                parts.append("Categorías: \(categories.joined(separator: ", "))")
            }
            if !subcategories.isEmpty {
                parts.append("Subcategorías: \(subcategories.joined(separator: ", "))")
            }
            if !budgets.isEmpty {
                parts.append("Presupuestos: \(budgets.joined(separator: ", "))")
            }
            if !tags.isEmpty {
                parts.append("Etiquetas: \(tags.joined(separator: ", "))")
            }
            if !merchants.isEmpty {
                parts.append("Comercios frecuentes: \(merchants.joined(separator: ", "))")
            }
            return parts.joined(separator: "\n")
        }
    }

    // MARK: - Public API

    /// Procesa sugerencias: si hay inválidas, las reescribe via LLM. Si todas son válidas,
    /// retorna as-is (zero LLM cost). Throws `.tooFewItems` si tras rewrite hay menos
    /// de `minItems` sugerencias válidas — caller debe fallback a rule-based.
    func process(
        suggestions: [ChatSuggestion],
        whitelist: Whitelist,
        language: String,
        minItems: Int = ChatSuggestionsConstants.minItems
    ) async throws -> [ChatSuggestion] {
        guard !suggestions.isEmpty else { throw ChatSuggestionsParseError.emptyArray }

        let invalid = suggestions.filter { !isValid($0, whitelist: whitelist, language: language) }
        if invalid.isEmpty { return suggestions }

        // Hay inválidas → re-prompt al LLM
        let client: OpenAI
        do {
            client = try await ProxyClientFactory.makeOpenAI(task: .chatRewrite)
        } catch {
            throw ChatSuggestionsLLMError.noAPIKey
        }
        guard NetworkMonitor.shared.isConnected else { throw ChatSuggestionsLLMError.offline }

        let rewritten = try await rewrite(
            invalidTexts: invalid.map(\.text),
            whitelist: whitelist,
            language: language,
            client: client
        )

        // Reemplazar las inválidas con las nuevas (en mismo orden), mantener válidas tal cual.
        var result: [ChatSuggestion] = []
        var rewriteIdx = 0
        for original in suggestions {
            if isValid(original, whitelist: whitelist, language: language) {
                result.append(original)
            } else if rewriteIdx < rewritten.count {
                let newText = rewritten[rewriteIdx]
                rewriteIdx += 1
                let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty,
                      trimmed.count <= ChatSuggestionsConstants.maxTextLength else { continue }
                // Re-validar la reescrita; si LLM aún la dejó inválida, descartar.
                let candidate = ChatSuggestion(text: trimmed, icon: original.icon, type: original.type)
                if isValid(candidate, whitelist: whitelist, language: language) {
                    result.append(candidate)
                }
            }
        }

        guard result.count >= minItems else { throw ChatSuggestionsParseError.tooFewItems }
        return result
    }

    // MARK: - Validation

    /// Una sugerencia es válida si NO menciona ningún elemento conocido cuyo nombre
    /// no esté en el whitelist. Es decir, si la sugerencia menciona "Restaurantes"
    /// y el user tiene "Restaurantes", OK. Si menciona "Entretenimiento" y el user
    /// no tiene esa cat/budget/etc, inválida.
    ///
    /// Estrategia conservadora: extraemos palabras "candidatas" (con mayúscula inicial, menos
    /// la primera) y cada una tiene que ser una palabra común del idioma, estar en el whitelist
    /// o ser una forma declinada de un nombre del whitelist (polaco, y el plural con diéresis
    /// del alemán). Una desconocida invalida la frase:
    /// un falso rechazo cae a las sugerencias fijas, un falso acierto enseña algo que el
    /// usuario no tiene.
    ///
    /// `language` es `AppLocale.current.identifier` («de», «de-DE», «zh-Hans»): en alemán
    /// todo sustantivo va con mayúscula, así que sin su lista ninguna frase pasaba.
    ///
    /// ⚠️ El banco (`gateway/bench/lib/chatRewrite.ts`) replica esta función y LEE las dos
    /// listas de este fichero: cambia la lógica aquí y allí a la vez.
    func isValid(_ suggestion: ChatSuggestion, whitelist: Whitelist, language: String) -> Bool {
        let lowerWhitelist = whitelist.lowercasedAll
        let common = Self.commonWordSet(for: language)
        let candidates = extractCandidates(from: suggestion.text)

        for candidate in candidates {
            let lower = candidate.lowercased()
            if common.contains(lower) { continue }
            // Si la candidata aparece en el whitelist, OK.
            if lowerWhitelist.contains(lower) { continue }
            // Si la candidata es substring de algún whitelist item, OK ("Bus" matchea "Bus" dentro de "Transporte/Bus")
            if lowerWhitelist.contains(where: { $0.contains(lower) || lower.contains($0) }) { continue }
            // Forma declinada de un nombre real: en polaco «w Biedronce» es «Biedronka»; en alemán,
            // el plural con diéresis: «Supermärkte» es «Supermarkt».
            switch Self.baseLanguage(language) {
            case "pl":
                if lowerWhitelist.contains(where: { Self.isPolishInflection(lower, of: $0) }) { continue }
            case "de":
                let folded = Self.foldingUmlauts(lower)
                if lowerWhitelist.contains(where: { folded.contains(Self.foldingUmlauts($0)) }) { continue }
            default:
                break
            }
            // Candidata desconocida → suggestion inválida.
            return false
        }
        return true
    }

    /// ¿`word` es una forma declinada de alguna palabra de `name`, en polaco? Una palabra del
    /// nombre de 4 letras o más, sin su vocal final, es la raíz: «żabka» → «żabk». `word` vale si
    /// empieza por esa raíz, o por la raíz con la alternancia del locativo/dativo en la última
    /// consonante (k→c, g→dz, ch→sz, ł→l, t→ci, d→dzi, r→rz), y lo que sigue mide 4 letras o
    /// menos: «żabce», «biedronce», «aptece», «rozrywkę», «restauracjach», «kinie».
    /// Solo polaco: es el único idioma de la app que declina los nombres propios.
    nonisolated static func isPolishInflection(_ word: String, of name: String) -> Bool {
        let vowels: Set<Character> = ["a", "e", "i", "o", "u", "y", "ą", "ę", "ó"]
        let alternations: [(String, String)] = [
            ("ch", "sz"), ("k", "c"), ("g", "dz"), ("ł", "l"), ("t", "ci"), ("d", "dzi"), ("r", "rz")
        ]
        for part in name.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            guard part.count >= 4 else { continue }
            var stem = String(part)
            if let last = stem.last, vowels.contains(last) { stem.removeLast() }
            var stems = [stem]
            if let alternation = alternations.first(where: { stem.hasSuffix($0.0) }) {
                stems.append(String(stem.dropLast(alternation.0.count)) + alternation.1)
            }
            for s in stems where s.count >= 3 && word.hasPrefix(s) && word.count - s.count <= 4 {
                return true
            }
        }
        return false
    }

    /// «ä», «ö», «ü» → «a», «o», «u»: el plural alemán pone diéresis a la raíz («Markt» → «Märkte»).
    nonisolated static func foldingUmlauts(_ text: String) -> String {
        String(text.map { character -> Character in
            switch character {
            case "ä": return "a"
            case "ö": return "o"
            case "ü": return "u"
            default: return character
            }
        })
    }

    /// «de-DE», «de_DE», «de» → «de».
    nonisolated static func baseLanguage(_ language: String) -> String {
        language
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .first
            .map { $0.lowercased() } ?? ""
    }

    /// Extrae palabras "candidatas" para validar — palabras capitalizadas dentro del texto
    /// (suelen ser nombres de categorías/budgets en español tipo "Restaurantes", "Mercado").
    /// Ignora la primera palabra (típicamente capitalizada por inicio de oración).
    private func extractCandidates(from text: String) -> [String] {
        let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        guard words.count > 1 else { return [] }
        var candidates: [String] = []
        // Skip la primera palabra (inicio de oración). Las "?" del comienzo
        // ya se filtraron por whereSeparator.
        for word in words.dropFirst() {
            let s = String(word)
            if let first = s.first, first.isUppercase {
                candidates.append(s)
            }
        }
        return candidates
    }

    /// Palabras comunes de cualquier idioma más las del idioma de la app.
    nonisolated static func commonWordSet(for language: String) -> Set<String> {
        commonWords.union(commonWordsByLanguage[baseLanguage(language)] ?? [])
    }

    /// Palabras capitalizadas comunes que NO son nombres de elementos del user.
    /// Listado conservador — si una palabra falsa-positiva ocurre, se considera "desconocida"
    /// y la suggestion se marca inválida (caso aceptable: el rewriter la arregla).
    nonisolated private static let commonWords: Set<String> = [
        // Spanish common
        "este", "esta", "cómo", "como", "cuánto", "cuanto", "cuándo", "cuando",
        "porqué", "porque", "qué", "que", "dónde", "donde", "cuáles", "cuales",
        "cuál", "cual", "mes", "semana", "año", "día", "mes", "días", "meses",
        "anteriores", "anterior", "promedio", "total", "mayor", "menor",
        // English common
        "this", "that", "how", "much", "many", "when", "where", "what", "which",
        "month", "week", "year", "day", "previous", "average", "total"
    ]

    /// Palabras con mayúscula por gramática en cada idioma, que no nombran nada del usuario.
    /// Alemán: todo sustantivo va con mayúscula; aquí solo los genéricos de una pregunta de
    /// finanzas (tiempo, totales, comparación), meses, días y el «Sie» formal. NO entran los
    /// que podrían ser una categoría inventada («Abos», «Rechnungen», «Miete»): esos tienen que
    /// estar en el whitelist. Polaco: el «Ty/Twój» de cortesía, que se escribe con mayúscula.
    /// Inglés: «I», meses y días.
    nonisolated private static let commonWordsByLanguage: [String: Set<String>] = [
        "de": [
            "monat", "monate", "monats", "monaten", "monatlich", "woche", "wochen", "wochenende",
            "jahr", "jahre", "jahres", "jahren", "tag", "tage", "tagen", "tages", "quartal",
            "vormonat", "vormonats", "vorjahr", "vorjahres", "vorwoche", "monatsende", "monatsanfang",
            "wochentag", "wochentage", "wochentagen",
            "ausgaben", "ausgabe", "einnahmen", "einnahme", "einkommen", "kosten", "budget", "budgets",
            "geld", "summe", "gesamt", "gesamtausgaben", "gesamtsumme", "betrag", "beträge",
            "durchschnitt", "schnitt", "vergleich", "kategorie", "kategorien", "unterkategorie",
            "unterkategorien", "konto", "konten", "kontostand", "saldo", "bilanz", "überblick",
            "übersicht", "trend", "prozent", "euro", "rest", "anteil", "höhe", "verlauf",
            "entwicklung", "prognose", "ersparnis", "ersparnisse", "sparquote", "limit", "ende",
            "anfang", "mitte", "zahlungen", "zahlung", "transaktionen", "transaktion", "buchungen",
            "januar", "jänner", "februar", "märz", "april", "mai", "juni", "juli", "august",
            "september", "oktober", "november", "dezember",
            "montag", "dienstag", "mittwoch", "donnerstag", "freitag", "samstag", "sonnabend", "sonntag",
            "sie", "ihr", "ihre", "ihren", "ihrem", "ihrer", "ihnen"
        ],
        "pl": [
            "ty", "ci", "cię", "ciebie", "tobie", "tobą", "twój", "twoja", "twoje", "twojego", "twojej",
            "twojemu", "twoim", "twoją", "twoich", "twoimi", "wy", "was", "wam", "wami", "wasz", "wasza",
            "wasze", "waszego", "waszej", "waszym", "waszych"
        ],
        "en": [
            "i",
            "january", "february", "march", "april", "may", "june", "july", "august",
            "september", "october", "november", "december",
            "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"
        ]
    ]

    // MARK: - LLM Rewrite

    private func rewrite(
        invalidTexts: [String],
        whitelist: Whitelist,
        language: String,
        client: OpenAI
    ) async throws -> [String] {
        let systemPrompt = """
        You rewrite chat suggestion phrases for a personal finance app.

        CRITICAL RULES:
        - RESPOND ONLY IN \(language). Do NOT translate names. Do NOT mix languages.
        - Output STRICT JSON: { "suggestions": ["frase 1", "frase 2", ...] } — same length as input.
        - Each phrase must:
          - Preserve the user's original INTENT (asking about spending, comparison, projection, etc.).
          - Use ONLY names from the user's real data (categories, subcategories, budgets, tags, merchants).
          - Be a natural-sounding question the user could ask the assistant.
          - Stay ≤ 80 chars.
          - Be grammatically correct in \(language).
        - Tone: cercano, 2nd person ("tú"). NUNCA regañes.
        """

        let userMessage = """
        El user tiene SOLO los siguientes elementos reales:
        \(whitelist.toPromptSnippet())

        Reescribe estas frases preservando intención pero usando SOLO los nombres reales arriba:
        \(invalidTexts.enumerated().map { "\($0.offset + 1). \"\($0.element)\"" }.joined(separator: "\n"))

        Devuelve un JSON con la misma cantidad de frases reescritas, en el mismo orden.
        """

        let messages: [ChatQuery.ChatCompletionMessageParam] = [
            .init(role: .system, content: systemPrompt),
            .init(role: .user, content: userMessage)
        ].compactMap { $0 }

        let query = ChatQuery(
            messages: messages,
            model: .gpt4_1_mini,
            responseFormat: .jsonObject,
            temperature: 0.3
        )

        let result = try await callWithTimeout(query, client: client)
        guard let content = result.choices.first?.message.content else {
            throw ChatSuggestionsLLMError.parseFailed
        }
        return try parseRewritten(json: content)
    }

    private func callWithTimeout(_ query: ChatQuery, client: OpenAI) async throws -> ChatResult {
        try await withThrowingTaskGroup(of: ChatResult.self) { group in
            group.addTask { try await client.chats(query: query) }
            group.addTask {
                try await Task.sleep(for: .seconds(ChatSuggestionsConstants.timeoutSeconds))
                throw ChatSuggestionsLLMError.timeout
            }
            guard let first = try await group.next() else {
                throw ChatSuggestionsLLMError.timeout
            }
            group.cancelAll()
            return first
        }
    }

    private func parseRewritten(json: String) throws -> [String] {
        guard let data = json.data(using: .utf8) else {
            throw ChatSuggestionsParseError.malformedJSON
        }
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ChatSuggestionsParseError.malformedJSON
        }
        guard let dict = parsed as? [String: Any],
              let array = dict["suggestions"] as? [String] else {
            throw ChatSuggestionsParseError.malformedJSON
        }
        guard !array.isEmpty else { throw ChatSuggestionsParseError.emptyArray }
        return array
    }
}
