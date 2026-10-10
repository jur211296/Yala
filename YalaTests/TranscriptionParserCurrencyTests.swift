//
//  TranscriptionParserCurrencyTests.swift
//  YalaTests
//
//  La lectura de una frase (voz, chat, Siri) conoce las divisas del usuario y pide JSON estricto
//  (tickets `voice-note-parser-prompt-knows-six-currencies` y `voice-parser-sends-no-json-mode`, 2026-10-09).
//  Lo que fija, sin red:
//
//  1. Los nombres que comparten varias divisas («pesos», «francos», «dólares») salen RESUELTOS en el prompt con la
//     divisa principal y las de las cuentas.
//  2. Ningún ejemplo del prompt contradice la regla de fecha ni enseña una subcategoría fuera de la lista del usuario.
//  3. La petición lleva `json_schema` estricto con TODOS los campos del DTO, y es el mismo esquema que el gateway.
//
//  Qué hace el MODELO con ese prompt lo mide el banco (`npm run bench -- --task text.parse`), no un unit test.
//

import Foundation
import OpenAI
import Testing

@testable import Yala

@MainActor
struct TranscriptionParserCurrencyTests {

    private static let peso = ParserCurrencyContext.sharedNameFamilies[0]
    private static let dollar = ParserCurrencyContext.sharedNameFamilies[1]
    private static let franc = ParserCurrencyContext.sharedNameFamilies[2]

    private static let now: Date = {
        var components = DateComponents()
        components.year = 2026; components.month = 10; components.day = 7; components.hour = 12
        return Calendar.current.date(from: components) ?? .now
    }()

    nonisolated static let esExpense = ["Restaurantes", "Supermercados y bodegas", "Estacionamientos", "Transporte público", "Combustible"]
    nonisolated static let esIncome = ["Sueldo", "Freelance"]

    private func prompt(
        _ currency: ParserCurrencyContext,
        expense: [String] = esExpense,
        income: [String] = esIncome
    ) -> String {
        TranscriptionParserService().buildSystemPrompt(
            expenseSubcategories: expense, incomeSubcategories: income, currency: currency, now: Self.now
        )
    }

    // MARK: - 1. Divisas

    @Test("las familias son las que dice el prompt: pesos, dólares y francos, en ese orden")
    func familiesAreInTheExpectedOrder() {
        #expect(Self.peso.names.contains("\"pesos\""))
        #expect(Self.dollar.names.contains("\"dollars\""))
        #expect(Self.franc.names.contains("\"francos\""))
    }

    @Test("con la principal ARS, «pesos» es ARS (nunca MXN ni PEN)")
    func pesosWithArgentineMainCurrency() {
        let ctx = ParserCurrencyContext(mainCurrency: "ARS", accountCurrencies: ["ARS", "USD"])
        #expect(ctx.resolve(Self.peso) == "ARS")
        let text = prompt(ctx)
        #expect(text.contains("\(Self.peso.names) a secas → \"ARS\""))
        #expect(text.contains("La divisa principal del usuario es ARS y sus cuentas usan ARS, USD."))
    }

    @Test("con la principal CHF, «francos» es CHF; y con EUR también, porque es la única franco")
    func francsAreSwissFrancs() {
        let swiss = ParserCurrencyContext(mainCurrency: "CHF", accountCurrencies: ["CHF"])
        #expect(swiss.resolve(Self.franc) == "CHF")
        #expect(prompt(swiss).contains("\(Self.franc.names) a secas → \"CHF\""))
        #expect(ParserCurrencyContext(mainCurrency: "EUR", accountCurrencies: ["EUR"]).resolve(Self.franc) == "CHF")
    }

    @Test("la principal manda; si no es de la familia, la única cuenta de la familia; si no, el valor por defecto")
    func resolutionOrder() {
        // Principal USD con una sola cuenta en pesos argentinos: «pesos» es esa cuenta.
        #expect(ParserCurrencyContext(mainCurrency: "USD", accountCurrencies: ["USD", "ARS"]).resolve(Self.peso) == "ARS")
        // Dos cuentas en pesos y la principal no lo es: no se sabe cuál.
        #expect(ParserCurrencyContext(mainCurrency: "USD", accountCurrencies: ["MXN", "COP"]).resolve(Self.peso) == nil)
        // Sin pesos en ningún sitio: null, y la app usa la principal.
        #expect(ParserCurrencyContext(mainCurrency: "PEN", accountCurrencies: ["PEN"]).resolve(Self.peso) == nil)
        // «dollars» en Canadá es CAD; en Perú, USD.
        #expect(ParserCurrencyContext(mainCurrency: "CAD", accountCurrencies: []).resolve(Self.dollar) == "CAD")
        #expect(ParserCurrencyContext(mainCurrency: "PEN", accountCurrencies: ["PEN"]).resolve(Self.dollar) == "USD")
        // La principal gana a una cuenta de la misma familia.
        #expect(ParserCurrencyContext(mainCurrency: "MXN", accountCurrencies: ["ARS"]).resolve(Self.peso) == "MXN")
    }

    @Test("los códigos se normalizan y las cuentas no se repiten")
    func normalizesCodes() {
        let ctx = ParserCurrencyContext(mainCurrency: "ars", accountCurrencies: ["ars", "USD", "ARS"])
        #expect(ctx.mainCurrency == "ARS")
        #expect(ctx.accountCurrencies == ["ARS", "USD"])
    }

    @Test("sin divisa principal, el prompt lo dice y no inventa ninguna")
    func unknownCurrency() {
        let text = prompt(.unknown)
        #expect(text.contains("No se conoce la divisa principal del usuario."))
        #expect(text.contains("\(Self.peso.names) a secas → null"))
        #expect(text.contains("\(Self.franc.names) a secas → \"CHF\""))
    }

    @Test("toda familia usa solo divisas que la app conoce")
    func familiesUseKnownCurrencies() {
        for family in ParserCurrencyContext.sharedNameFamilies {
            for code in family.codes { #expect(CurrencyCode(rawValue: code) != nil, "\(code) no está en CurrencyCode") }
            if let fallback = family.fallback { #expect(family.codes.contains(fallback)) }
        }
    }

    @Test("Siri: la caché del App Group lleva las cuentas, y una caché vieja sin ellas sigue leyéndose")
    func siriCacheCarriesAccountCurrencies() throws {
        let old = #"{"expenseSubcategories":["A"],"incomeSubcategories":[],"defaultCurrency":"ARS","hasRealAccount":true}"#
        let decoded = try JSONDecoder().decode(SiriIntentContext.self, from: Data(old.utf8))
        #expect(decoded.accountCurrencies == nil)
        #expect(decoded.parserCurrency == ParserCurrencyContext(mainCurrency: "ARS", accountCurrencies: []))

        let fresh = SiriIntentContext(expenseSubcategories: [], incomeSubcategories: [], defaultCurrency: "USD", hasRealAccount: true, accountCurrencies: ["USD", "ARS"])
        let roundTrip = try JSONDecoder().decode(SiriIntentContext.self, from: JSONEncoder().encode(fresh))
        #expect(roundTrip.parserCurrency.resolve(Self.peso) == "ARS")
    }

    @Test("los tres llamadores pasan las divisas del usuario, no `.unknown`")
    func callersPassTheUserCurrencies() throws {
        let sites: [(String, String)] = [
            ("Yala/App/Views/Voice/VoiceRecordingView.swift", "currency: ParserCurrencyContext.load(mainCurrency: appPreferences.defaultCurrencyCode.rawValue, context: modelContext)"),
            ("Yala/Services/ChatAssistantService.swift", "currency: ParserCurrencyContext("),
            ("Yala/App/Intents/QuickExpenseIntent.swift", "currency: cachedContext?.parserCurrency ?? .unknown"),
            ("Yala/App/Intents/SiriIntentContextCache.swift", "accountCurrencies: ParserCurrencyContext.load(mainCurrency: defaultCurrency, context: context).accountCurrencies")
        ]
        for (path, needle) in sites {
            let source = try String(contentsOf: repoURL(path), encoding: .utf8)
            #expect(source.contains(needle), "\(path) no pasa las divisas del usuario")
        }
    }

    // MARK: - 2. Los ejemplos del prompt

    /// Los `Output:` de los ejemplos, decodificados como JSON.
    private func exampleOutputs(_ text: String) throws -> [[String: Any]] {
        let lines = text.components(separatedBy: "\n").filter { $0.hasPrefix("Output: ") }
        #expect(lines.count == 4, "el prompt tiene \(lines.count) ejemplos")
        return try lines.flatMap { line -> [[String: Any]] in
            let json = String(line.dropFirst("Output: ".count))
            let object = try #require(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
            return try #require(object["transactions"] as? [[String: Any]])
        }
    }

    @Test("una sola regla de fecha: todo ejemplo trae una fecha, y la confianza dice si el usuario la dijo")
    func examplesFollowTheDateRule() throws {
        let text = prompt(ParserCurrencyContext(mainCurrency: "PEN", accountCurrencies: ["PEN"]))
        #expect(text.contains("\"date\" SIEMPRE es una fecha \"YYYY-MM-DD\", nunca null. Sin mención de fecha → hoy, 2026-10-07"))
        #expect(!text.contains("\"date\":null"))
        let txs = try exampleOutputs(text)
        #expect(txs.count == 5)
        for tx in txs {
            let date = try #require(tx["date"] as? String, "un ejemplo sin fecha")
            let confidence = try #require((tx["confidence"] as? [String: Any])?["date"] as? Double)
            switch date {
            case "2026-10-06": #expect(confidence == 1.0, "«ayer» es una fecha dicha")
            case "2026-10-07": #expect(confidence == 0.5, "hoy sin mencionarlo no es una fecha dicha")
            default: Issue.record("fecha inesperada en un ejemplo: \(date)")
            }
        }
    }

    @Test("los ejemplos solo enseñan subcategorías de la lista del usuario", arguments: [
        TranscriptionParserCurrencyTests.esExpense,
        ["Restaurants", "Supermarkets & groceries", "Parking"],
        ["レストラン", "スーパーと食料品", "駐車場"],
        ["Alquiler", "Gimnasio"],
        []
    ])
    func examplesOnlyUseListedSubcategories(expense: [String]) throws {
        let text = prompt(ParserCurrencyContext(mainCurrency: "EUR", accountCurrencies: ["EUR"]), expense: expense, income: [])
        for tx in try exampleOutputs(text) {
            let score = try #require((tx["confidence"] as? [String: Any])?["subcategory"] as? Double)
            if let hint = tx["subcategoryHint"] as? String {
                #expect(expense.contains(hint), "«\(hint)» no está en la lista del usuario")
                #expect(score == 0.85)
            } else {
                #expect(tx["subcategoryHint"] is NSNull)
                #expect(score == 0.0)
            }
        }
        #expect(!text.contains("\"subcategoryHint\":\"Transporte\""))
    }

    @Test("con una lista que las tiene, los ejemplos eligen la subcategoría que toca")
    func examplesPickTheMatchingSubcategory() throws {
        let hints = try exampleOutputs(prompt(.unknown)).map { $0["subcategoryHint"] as? String }
        #expect(hints == ["Restaurantes", "Restaurantes", "Restaurantes", "Estacionamientos", "Supermercados y bodegas"])
    }

    @Test("los ejemplos son respuestas que la app sabe leer")
    func examplesDecodeWithTheAppParser() throws {
        let service = TranscriptionParserService()
        let lines = prompt(.unknown).components(separatedBy: "\n").filter { $0.hasPrefix("Output: ") }
        for line in lines {
            let parsed = try service.parseMultipleResponse(String(line.dropFirst("Output: ".count)))
            #expect(!parsed.isEmpty)
            #expect(parsed.allSatisfy { $0.date != nil && $0.amount != nil })
        }
    }

    // MARK: - 3. JSON estricto

    private func encodedQuery() throws -> [String: Any] {
        let query = TranscriptionParserService.makeQuery(prompt: "p", text: "taxi 12")
        let data = try JSONEncoder().encode(query)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("la petición lleva json_schema estricto con todos los campos del DTO")
    func queryAsksForStrictJSONSchema() throws {
        let format = try #require(try encodedQuery()["response_format"] as? [String: Any], "la petición no lleva response_format")
        #expect(format["type"] as? String == "json_schema")
        let jsonSchema = try #require(format["json_schema"] as? [String: Any])
        #expect(jsonSchema["strict"] as? Bool == true)
        #expect(jsonSchema["name"] as? String == "text_parse")
        let schema = try #require(jsonSchema["schema"] as? [String: Any])
        #expect(schema["additionalProperties"] as? Bool == false)
        #expect(schema["required"] as? [String] == ["transactions"])

        let item = try #require(((schema["properties"] as? [String: Any])?["transactions"] as? [String: Any])?["items"] as? [String: Any])
        let properties = try #require(item["properties"] as? [String: Any])
        let required = try #require(item["required"] as? [String])
        #expect(item["additionalProperties"] as? Bool == false)
        #expect(Set(required) == Set(properties.keys), "en modo estricto todo campo es obligatorio")
        #expect(Set(required) == ["amount", "date", "note", "isExpense", "subcategoryHint", "tagHints", "currencyHint", "confidence"])
        for optional in ["amount", "date", "subcategoryHint", "currencyHint"] {
            let type = (properties[optional] as? [String: Any])?["type"] as? [String]
            #expect(type?.last == "null", "\(optional) es opcional en el DTO: va como [tipo, \"null\"]")
        }
        #expect((properties["note"] as? [String: Any])?["type"] as? String == "string")
        #expect((properties["isExpense"] as? [String: Any])?["type"] as? String == "boolean")

        let confidence = try #require(properties["confidence"] as? [String: Any])
        let confidenceProperties = try #require(confidence["properties"] as? [String: Any])
        #expect(Set(confidence["required"] as? [String] ?? []) == Set(confidenceProperties.keys))
        #expect(Set(confidenceProperties.keys) == ["amount", "date", "merchant", "subcategory", "tags"])
        #expect(confidence["additionalProperties"] as? Bool == false)
    }

    @Test("el esquema de la app es el TEXT_PARSE_SCHEMA del gateway, que es el que manda")
    func schemaMatchesTheGateway() throws {
        let ts = try String(contentsOf: repoURL("gateway/src/ai/schemas.ts"), encoding: .utf8)
        let start = try #require(ts.range(of: "export const TEXT_PARSE_SCHEMA"))
        let end = try #require(ts.range(of: "} as const;", range: start.upperBound..<ts.endIndex))
        let block = String(ts[start.upperBound..<end.lowerBound])
        let requiredLists = block.components(separatedBy: "required: [").dropFirst().map { chunk in
            (chunk.components(separatedBy: "]").first ?? "").components(separatedBy: ",").map {
                $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        #expect(requiredLists == [["transactions"], TextParseResponseSchema.transactionFields, TextParseResponseSchema.confidenceFields])
        #expect(block.contains("name: \"\(TextParseResponseSchema.name)\""))
    }

    @Test("la fila text.parse del gateway pide JSON estricto con ese esquema")
    func gatewayRowIsStrict() throws {
        let routes = try String(contentsOf: repoURL("gateway/src/ai/routes.ts"), encoding: .utf8)
        let start = try #require(routes.range(of: "  \"text.parse\": {"))
        let end = try #require(routes.range(of: "  },", range: start.upperBound..<routes.endIndex))
        let row = String(routes[start.upperBound..<end.lowerBound])
        #expect(row.contains("responseFormat: \"json_object\""))
        #expect(row.contains("jsonSchema: TEXT_PARSE_SCHEMA"))
        #expect(row.contains("strictSchema: true"))
    }

    private func repoURL(_ relative: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(relative)
    }
}
