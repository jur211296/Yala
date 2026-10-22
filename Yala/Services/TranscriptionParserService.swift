//
//  TranscriptionParserService.swift
//  Yala
//
//  Service for parsing transcribed text into structured transaction data using OpenAI LLM.
//

import Foundation
import Observation
import OpenAI
import SwiftData

// MARK: - Parsed Transaction

// `nonisolated`: DTO de datos puros que cruza actores (lo construye el parser en @MainActor y lo
// (de)serializa `SiriPendingStore` desde contextos `nonisolated` en el proceso del intent). Sin
// esto, bajo `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` su conformance Codable queda main-actor-
// isolated y no se puede usar desde `nonisolated` (error en Swift 6 mode).
nonisolated struct ParsedTransaction: Codable, Equatable {
    let amount: Decimal?
    let date: Date?
    let note: String
    let isExpense: Bool
    let subcategoryHint: String?
    let tagHints: [String]
    let currencyHint: String?
    let confidence: TransactionConfidence

    nonisolated struct TransactionConfidence: Codable, Equatable {
        let amount: Double
        let date: Double
        let merchant: Double
        let subcategory: Double
        let tags: Double
    }
}

// MARK: - Parser Error

enum ParserError: Error, LocalizedError {
    case noAPIKey
    case emptyText
    case parsingFailed(String)
    case invalidResponse
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "OpenAI API key not configured"
        case .emptyText:
            return "Transcription text is empty"
        case .parsingFailed(let message):
            return "Parsing failed: \(message)"
        case .invalidResponse:
            return "Invalid response from LLM"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - LLM Response Models

private struct LLMTransactionItem: Codable {
    let amount: Double?
    let date: String?
    let note: String
    let isExpense: Bool
    let subcategoryHint: String?
    let tagHints: [String]?
    let currencyHint: String?
    let confidence: ConfidenceScores

    struct ConfidenceScores: Codable {
        let amount: Double
        let date: Double
        let merchant: Double
        let subcategory: Double
        let tags: Double
    }
}

private struct LLMMultipleResponse: Codable {
    let transactions: [LLMTransactionItem]
}

// MARK: - Divisas del usuario

/// Lo que la lectura de una frase necesita saber de las divisas del usuario para un nombre que varias divisas comparten
/// («pesos», «dólares», «francos»…). Mismo patrón que `VisionCurrencyContext` en la foto: la divisa principal y las de las
/// cuentas activas. La regla se RESUELVE aquí y el prompt recibe el código ya decidido, para que el modelo no tenga que
/// deducir de qué país es el usuario (ticket `voice-note-parser-prompt-knows-six-currencies`).
nonisolated struct ParserCurrencyContext: Equatable, Sendable {
    let mainCurrency: String?
    let accountCurrencies: [String]

    static let unknown = ParserCurrencyContext(mainCurrency: nil, accountCurrencies: [])

    init(mainCurrency: String?, accountCurrencies: [String]) {
        self.mainCurrency = mainCurrency?.uppercased()
        var seen = Set<String>()
        self.accountCurrencies = accountCurrencies.map { $0.uppercased() }.filter { seen.insert($0).inserted }
    }

    /// Un nombre de divisa que comparten varias divisas de la app (`CurrencyCode`). Una línea por familia: el banco
    /// (`gateway/bench/lib/textParse.ts`) las lee de este literal, así que no partas una familia en varias líneas.
    struct SharedNameFamily: Equatable, Sendable {
        let names: String
        let codes: [String]
        let fallback: String?
    }

    static let sharedNameFamilies: [SharedNameFamily] = [
        SharedNameFamily(names: #""pesos", "peso", "mangos", "varos""#, codes: ["MXN", "COP", "ARS", "CLP", "UYU", "DOP", "PHP"], fallback: nil),
        SharedNameFamily(names: #""dólares", "dólar", "dollars", "dollar", "Dollar", "dollari", "dollaro", "dolarów", "dolary", "dolar", "ドル""#, codes: ["USD", "CAD", "AUD", "NZD", "SGD", "HKD", "TWD"], fallback: "USD"),
        SharedNameFamily(names: #""francos", "franco", "francs", "franc", "Franken", "franchi", "franków", "frank", "フラン", "法郎""#, codes: ["CHF"], fallback: "CHF"),
        SharedNameFamily(names: #""coronas", "corona", "crowns", "kronor", "kroner", "Kronen", "korun", "corone", "koron", "kronen", "couronnes", "クローネ", "克朗""#, codes: ["SEK", "NOK", "DKK", "CZK"], fallback: nil),
        SharedNameFamily(names: #""libras", "libra", "pounds", "pound", "quid", "Pfund", "sterline", "sterlina", "funtów", "funty", "pond", "livres", "ポンド""#, codes: ["GBP", "EGP"], fallback: "GBP"),
        SharedNameFamily(names: #""rupias", "rupia", "rupees", "rupee", "Rupien", "rupie", "roupies", "ルピー", "卢比""#, codes: ["INR", "IDR"], fallback: nil),
        SharedNameFamily(names: #""riales", "riyales", "riyals", "rials", "Rial", "ریال""#, codes: ["SAR", "QAR"], fallback: nil),
        SharedNameFamily(names: #""dírhams", "dirhams", "dirham", "Dirham""#, codes: ["AED", "MAD"], fallback: nil)
    ]

    /// La divisa de un nombre compartido: la principal si es de la familia; si no, la única cuenta de la familia; si no,
    /// la de por defecto (o `nil`: el usuario la elige en la revisión).
    func resolve(_ family: SharedNameFamily) -> String? {
        if let main = mainCurrency, family.codes.contains(main) { return main }
        let inAccounts = accountCurrencies.filter { family.codes.contains($0) }
        if inAccounts.count == 1 { return inAccounts[0] }
        return family.fallback
    }

    /// Las líneas del prompt para los nombres compartidos, ya resueltas.
    var sharedNameRules: String {
        Self.sharedNameFamilies.map { family in
            let code = resolve(family).map { "\"\($0)\"" } ?? "null"
            return "  - \(family.names) a secas → \(code)"
        }.joined(separator: "\n")
    }

    /// Las divisas del usuario, en una línea del prompt.
    var userCurrencyLine: String {
        guard let main = mainCurrency else { return "No se conoce la divisa principal del usuario." }
        let accounts = accountCurrencies.isEmpty ? main : accountCurrencies.joined(separator: ", ")
        return "La divisa principal del usuario es \(main) y sus cuentas usan \(accounts)."
    }
}

extension ParserCurrencyContext {
    /// La principal y las divisas de las cuentas activas (sin archivar ni de sistema), como la foto
    /// (`ImageSelectionView.visionCurrencyContext`). Si el fetch falla, solo la principal.
    @MainActor
    static func load(mainCurrency: String, context: ModelContext) -> ParserCurrencyContext {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate<Account> { account in account.isArchived == false && account.isSystemAccount == false }
        )
        do {
            let codes = try context.fetch(descriptor).map(\.currencyCode)
            return ParserCurrencyContext(mainCurrency: mainCurrency, accountCurrencies: codes)
        } catch {
            #if DEBUG
            print("ParserCurrencyContext: Error fetching account currencies: \(error)")
            #endif
            return ParserCurrencyContext(mainCurrency: mainCurrency, accountCurrencies: [])
        }
    }
}

// MARK: - Esquema de la respuesta

/// El JSON estricto que pide la lectura (`response_format: json_schema`, `strict: true`). Espejo de `TEXT_PARSE_SCHEMA`
/// (`gateway/src/ai/schemas.ts`), que es el que manda de verdad: la fila `text.parse` es `managed` y el gateway ignora
/// el formato del cuerpo. En modo estricto todo campo es obligatorio; los opcionales del DTO van como `[tipo, "null"]`.
nonisolated enum TextParseResponseSchema {
    static let name = "text_parse"

    indirect enum Node: Encodable, Sendable {
        case object([(String, Node)])
        case array([Node])
        case string(String)
        case bool(Bool)

        private struct Key: CodingKey {
            let stringValue: String
            var intValue: Int? { nil }
            init(_ string: String) { stringValue = string }
            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { nil }
        }

        func encode(to encoder: Encoder) throws {
            switch self {
            case .object(let pairs):
                var container = encoder.container(keyedBy: Key.self)
                for (key, value) in pairs { try container.encode(value, forKey: Key(key)) }
            case .array(let items):
                var container = encoder.unkeyedContainer()
                for item in items { try container.encode(item) }
            case .string(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .bool(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            }
        }
    }

    private static func type(_ name: String) -> Node { .object([("type", .string(name))]) }
    private static func nullable(_ name: String) -> Node { .object([("type", .array([.string(name), .string("null")]))]) }
    private static func strings(_ values: [String]) -> Node { .array(values.map { .string($0) }) }

    static let confidenceFields = ["amount", "date", "merchant", "subcategory", "tags"]
    static let transactionFields = ["amount", "date", "note", "isExpense", "subcategoryHint", "tagHints", "currencyHint", "confidence"]

    static let schema: Node = .object([
        ("type", .string("object")),
        ("additionalProperties", .bool(false)),
        ("required", strings(["transactions"])),
        ("properties", .object([
            ("transactions", .object([
                ("type", .string("array")),
                ("items", .object([
                    ("type", .string("object")),
                    ("additionalProperties", .bool(false)),
                    ("required", strings(transactionFields)),
                    ("properties", .object([
                        ("amount", nullable("number")),
                        ("date", nullable("string")),
                        ("note", type("string")),
                        ("isExpense", type("boolean")),
                        ("subcategoryHint", nullable("string")),
                        ("tagHints", .object([("type", .string("array")), ("items", type("string"))])),
                        ("currencyHint", nullable("string")),
                        ("confidence", .object([
                            ("type", .string("object")),
                            ("additionalProperties", .bool(false)),
                            ("required", strings(confidenceFields)),
                            ("properties", .object(confidenceFields.map { ($0, type("number")) }))
                        ]))
                    ]))
                ]))
            ]))
        ]))
    ])

    static var responseFormat: ChatQuery.ResponseFormat {
        .jsonSchema(.init(name: name, schema: .dynamicJsonSchema(schema), strict: true))
    }
}

// MARK: - Transcription Parser Service

/// Service for parsing transcriptions into transaction data.
/// Supports @Environment injection in SwiftUI views.
@MainActor @Observable
final class TranscriptionParserService {

    // MARK: - Singleton (for backward compatibility)

    /// Shared instance for backward compatibility. Prefer @Environment injection in Views.
    static let shared = TranscriptionParserService()

    init() {}

    // MARK: - Properties

    @ObservationIgnored
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    // MARK: - System Prompt

    /// Palabras clave para elegir, de la lista del usuario, la subcategoría de cada ejemplo del prompt. Un ejemplo solo
    /// enseña una subcategoría que EXISTE en esa lista (si no casa ninguna, `null`): uno con «Transporte» fijo enseñaba a
    /// inventar. Se comparan sin tildes ni mayúsculas. El banco las lee de estas líneas: no las partas.
    static let restaurantKeywords = ["restaur", "ristorant", "レストラン", "餐厅"]
    static let parkingKeywords = ["estacionamiento", "parking", "parken", "parkeren", "stationnement", "parcheggi", "駐車", "停车"]
    static let supermarketKeywords = ["supermerc", "supermark", "supermarch", "スーパー", "超市"]

    /// La primera subcategoría de la lista que contiene alguna palabra clave, como literal JSON (`"Restaurantes"` o `null`).
    static func exampleHint(_ list: [String], keywords: [String]) -> String {
        let fold: (String) -> String = { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }
        let folded = keywords.map(fold)
        guard let name = list.first(where: { candidate in folded.contains { fold(candidate).contains($0) } }) else { return "null" }
        return jsonString(name)
    }

    /// La confianza de subcategoría de un ejemplo: 0.85 con pista, 0.0 sin ella.
    static func exampleScore(_ hint: String) -> String { hint == "null" ? "0.0" : "0.85" }

    private static func jsonString(_ value: String) -> String {
        do {
            let data = try JSONEncoder().encode(value)
            return String(decoding: data, as: UTF8.self)
        } catch {
            #if DEBUG
            print("TranscriptionParserService: Error encoding example hint: \(error)")
            #endif
            return "null"
        }
    }

    func buildSystemPrompt(
        expenseSubcategories: [String],
        incomeSubcategories: [String],
        currency: ParserCurrencyContext,
        now: Date = .now
    ) -> String {
        let expenseList = expenseSubcategories.isEmpty ? "No hay subcategorías de gasto definidas" : expenseSubcategories.joined(separator: ", ")
        let incomeList = incomeSubcategories.isEmpty ? "No hay subcategorías de ingreso definidas" : incomeSubcategories.joined(separator: ", ")

        let dateContext = DateContextProvider.buildDateContext(now: now)
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dayFormatter.timeZone = .current
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        let today = dayFormatter.string(from: now)
        let yesterday = dayFormatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now)

        let userCurrencyLine = currency.userCurrencyLine
        let sharedNameRules = currency.sharedNameRules

        let restaurantsHint = Self.exampleHint(expenseSubcategories, keywords: Self.restaurantKeywords)
        let restaurantsScore = Self.exampleScore(restaurantsHint)
        let parkingHint = Self.exampleHint(expenseSubcategories, keywords: Self.parkingKeywords)
        let parkingScore = Self.exampleScore(parkingHint)
        let supermarketsHint = Self.exampleHint(expenseSubcategories, keywords: Self.supermarketKeywords)
        let supermarketsScore = Self.exampleScore(supermarketsHint)

        return """
        Eres un parser de gastos para una app de finanzas personales.
        Extrae información de la frase del usuario y devuelve SOLO JSON con el esquema de abajo.

        IMPORTANTE - Múltiples transacciones:
        - Si el usuario menciona más de una transacción (ej: "50 en café y 100 en uber", "gasté 30 en almuerzo, 15 en estacionamiento y me pagaron 200"), extrae CADA una por separado
        - Cada transacción va como un objeto independiente en el array "transactions"
        - Conjunciones como "y", "además", "también", "luego" suelen separar transacciones
        - Pero un número de una o dos cifras que sigue a un importe con "y", "e", "con" o "and", sin concepto propio, son los céntimos de ESE importe: "28 euros e 30" → 28.30, "5 con 50" → 5.50, "veinte cincuenta" → 20.50. Solo es otro movimiento si lleva su propio concepto ("50 en café y 30 en taxi")

        \(dateContext)

        Regla de fecha (la única):
        - "date" SIEMPRE es una fecha "YYYY-MM-DD", nunca null. Sin mención de fecha → hoy, \(today)
        - confidence.date: 1.0 si el usuario dijo la fecha (también "hoy", "ayer" o un día de la semana); 0.5 si no la dijo y usas hoy

        Reglas de monto:
        - Extrae el número mencionado: "cincuenta" = 50, "cien" = 100, "mil" = 1000
        - "23,45" y "23.45" son 23.45; "1.850", "1,850" y "1 850" son 1850 (grupo final de tres cifras)
        - "k" multiplica por 1000 ("20k" = 20000); en japonés y chino 万 son 10 000 ("28万円" = 280000, "一万二" = 12000)
        - Jerga: "luca(s)" en Perú es un sol ("18 lucas" = 18) y en Chile, Argentina o Colombia son mil pesos ("15 lucas" = 15000); decide por la divisa principal del usuario. "pavos" (España) son euros y "块" son yuanes, uno a uno
        - Si no hay monto claro, usa null

        Reglas de tipo:
        - Por defecto asume gasto (isExpense: true)
        - Si menciona "ingreso", "cobré", "me pagaron", "recibí" → isExpense: false

        Reglas de subcategoría (MUY IMPORTANTE):
        - SIEMPRE intenta inferir la subcategoría más apropiada del contexto
        - DEBES elegir ÚNICAMENTE de las subcategorías disponibles del usuario (listadas abajo), con el nombre exacto
        - Analiza el contexto semántico: "Uber" es una app de transporte, "Netflix" es streaming, "Starbucks" es una cafetería, etc.
        - Elige la subcategoría que mejor coincida semánticamente, aunque el nombre no sea exacto
        - Solo usa null si realmente no hay ninguna subcategoría que aplique

        Subcategorías de GASTO disponibles:
        \(expenseList)

        Subcategorías de INGRESO disponibles:
        \(incomeList)

        Reglas de etiquetas/tags:
        - Si dice "etiqueta X", "tag X", "con la etiqueta X", "para X" (donde X es un proyecto/contexto) → extrae X
        - Puede haber múltiples etiquetas
        - Ejemplos: "con la etiqueta viaje" → ["viaje"], "etiqueta trabajo y cliente" → ["trabajo", "cliente"]
        - Si no hay mención explícita → []

        Reglas de moneda (siempre un código ISO 4217 o null):
        - \(userCurrencyLine)
        - Nombres de una sola divisa, en cualquier idioma:
          - "soles", "sol", "S/" → "PEN"
          - "euros", "euro", "Euro", "€" → "EUR"
          - "reais", "real", "R$" → "BRL"
          - "yenes", "yen", "円", "日元", "JP¥", o "¥" en un texto japonés → "JPY"
          - "yuanes", "yuan", "元", "块", "人民币", "RMB", o "¥" en un texto chino → "CNY"
          - "złoty", "złotych", "zł", "zlotys" → "PLN"
          - "wones", "won", "원" → "KRW"
          - "US$", "美元", "dólares americanos", "US dollars" → "USD"
        - Con el país dicho, la de ese país: "pesos mexicanos" → "MXN", "pesos colombianos" → "COP", "pesos argentinos" → "ARS", "pesos chilenos" → "CLP", "pesos uruguayos" → "UYU", "dólares canadienses" → "CAD", "dólares australianos" → "AUD", "coronas suecas" → "SEK", "coronas noruegas" → "NOK", "coronas danesas" → "DKK", "coronas checas" → "CZK"; y en cualquier idioma
        - Símbolos: "£" → "GBP", "MX$" → "MXN", "C$" o "CA$" → "CAD", "A$" o "AU$" → "AUD", "CHF" o "Fr." → "CHF"; "$" a secas → null
        - Nombres que comparten varias divisas, ya decididos para este usuario:
        \(sharedNameRules)
        - Cualquier otro código ISO 4217 dicho o escrito ("MXN", "ARS", "CAD") → ese código
        - Si no se menciona moneda → null (la app usa la divisa principal)

        Reglas de nota (IMPORTANTE):
        - La nota es el comercio o el detalle; NUNCA repite la subcategoría inferida
        - Con comercio: note = el comercio ("almorcé en Pardos" → note "Pardos")
        - Sin comercio pero con un detalle: note = el detalle ("gasté en almuerzo" → note "almuerzo")
        - Si solo nombra la subcategoría: note = ""

        Ejemplos:
        Input: "Almorcé en Pardos por 50 soles ayer"
        Output: {"transactions":[{"amount":50,"date":"\(yesterday)","note":"Pardos","isExpense":true,"subcategoryHint":\(restaurantsHint),"tagHints":[],"currencyHint":"PEN","confidence":{"amount":1.0,"date":1.0,"merchant":0.9,"subcategory":\(restaurantsScore),"tags":0.0}}]}

        Input: "I spent 25 euros on lunch"
        Output: {"transactions":[{"amount":25,"date":"\(today)","note":"lunch","isExpense":true,"subcategoryHint":\(restaurantsHint),"tagHints":[],"currencyHint":"EUR","confidence":{"amount":1.0,"date":0.5,"merchant":0.5,"subcategory":\(restaurantsScore),"tags":0.0}}]}

        Input: "30 en almuerzo y 15 en estacionamiento"
        Output: {"transactions":[{"amount":30,"date":"\(today)","note":"almuerzo","isExpense":true,"subcategoryHint":\(restaurantsHint),"tagHints":[],"currencyHint":null,"confidence":{"amount":1.0,"date":0.5,"merchant":0.5,"subcategory":\(restaurantsScore),"tags":0.0}},{"amount":15,"date":"\(today)","note":"estacionamiento","isExpense":true,"subcategoryHint":\(parkingHint),"tagHints":[],"currencyHint":null,"confidence":{"amount":1.0,"date":0.5,"merchant":0.5,"subcategory":\(parkingScore),"tags":0.0}}]}

        Input: "28 euros e 30 no Pingo Doce"
        Output: {"transactions":[{"amount":28.3,"date":"\(today)","note":"Pingo Doce","isExpense":true,"subcategoryHint":\(supermarketsHint),"tagHints":[],"currencyHint":"EUR","confidence":{"amount":1.0,"date":0.5,"merchant":0.9,"subcategory":\(supermarketsScore),"tags":0.0}}]}

        Esquema (todos los campos siempre presentes):
        {
          "transactions": [
            {
              "amount": number | null,
              "date": "YYYY-MM-DD",
              "note": "descripción breve",
              "isExpense": true | false,
              "subcategoryHint": "nombre exacto de la lista" | null,
              "tagHints": ["tag1", "tag2"] | [],
              "currencyHint": "código ISO 4217" | null,
              "confidence": {
                "amount": 0.0-1.0,
                "date": 0.0-1.0,
                "merchant": 0.0-1.0,
                "subcategory": 0.0-1.0,
                "tags": 0.0-1.0
              }
            }
          ]
        }
        """
    }

    // MARK: - Public Methods

    /// Parses transcribed text to extract structured transaction data.
    /// Returns the first transaction if multiple are detected.
    /// - Parameters:
    ///   - text: The transcribed text from voice input
    ///   - expenseSubcategories: List of user's expense subcategory names for intelligent matching
    ///   - incomeSubcategories: List of user's income subcategory names for intelligent matching
    /// - Returns: ParsedTransaction with extracted data and confidence scores
    func parse(
        text: String,
        expenseSubcategories: [String] = [],
        incomeSubcategories: [String] = [],
        currency: ParserCurrencyContext
    ) async throws -> ParsedTransaction {
        let transactions = try await parseMultiple(
            text: text,
            expenseSubcategories: expenseSubcategories,
            incomeSubcategories: incomeSubcategories,
            currency: currency
        )
        guard let first = transactions.first else {
            throw ParserError.invalidResponse
        }
        return first
    }

    /// Parses transcribed text to extract multiple transactions.
    /// Supports phrases like "50 en café y 100 en uber" returning 2 transactions.
    /// - Parameters:
    ///   - text: The transcribed text from voice input
    ///   - expenseSubcategories: List of user's expense subcategory names for intelligent matching
    ///   - incomeSubcategories: List of user's income subcategory names for intelligent matching
    /// - Returns: Array of ParsedTransaction with extracted data and confidence scores
    func parseMultiple(
        text: String,
        expenseSubcategories: [String] = [],
        incomeSubcategories: [String] = [],
        currency: ParserCurrencyContext
    ) async throws -> [ParsedTransaction] {
        let client: OpenAI
        do {
            client = try await ProxyClientFactory.makeOpenAI(task: .textParse)
        } catch {
            throw ParserError.networkError(error)
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw ParserError.emptyText
        }

        let prompt = buildSystemPrompt(
            expenseSubcategories: expenseSubcategories,
            incomeSubcategories: incomeSubcategories,
            currency: currency
        )

        let query = Self.makeQuery(prompt: prompt, text: trimmedText)

        do {
            let result = try await client.chats(query: query)

            guard let content = result.choices.first?.message.content else {
                throw ParserError.invalidResponse
            }

            return try parseMultipleResponse(content)
        } catch let error as ParserError {
            throw error
        } catch {
            throw ParserError.networkError(error)
        }
    }

    /// La petición de la lectura. Modelo y temperatura son los de las versiones sin cabecera de tarea: con ella, la fila
    /// `text.parse` del gateway (`managed`) decide modelo, parámetros y formato, y también el JSON estricto.
    static func makeQuery(prompt: String, text: String) -> ChatQuery {
        ChatQuery(
            messages: [
                .system(.init(content: .textContent(prompt))),
                .user(.init(content: .string(text)))
            ],
            model: .gpt4_1_mini,
            responseFormat: TextParseResponseSchema.responseFormat,
            temperature: 0.1
        )
    }

    // MARK: - Private Methods

    /// Quita las vallas de markdown antes de decodificar. Se mantiene a propósito (decidido el 2026-10-09): desde ese día
    /// la fila `text.parse` pide JSON estricto y las vallas son inalcanzables para TODAS las versiones, pero esa fila se
    /// cambia sin release, y con un formato de texto vuelven (5 de 528 respuestas del banco las traían).
    func parseMultipleResponse(_ content: String) throws -> [ParsedTransaction] {
        // Clean the response (remove any markdown formatting if present)
        var jsonString = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        }
        if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonString.data(using: .utf8) else {
            throw ParserError.parsingFailed("Invalid UTF-8 string")
        }

        let decoder = JSONDecoder()
        let llmResponse: LLMMultipleResponse

        do {
            llmResponse = try decoder.decode(LLMMultipleResponse.self, from: data)
        } catch {
            throw ParserError.parsingFailed("JSON decode error: \(error.localizedDescription)")
        }

        // Convert each transaction item to ParsedTransaction
        return llmResponse.transactions.map { item in
            convertToParsedTransaction(item)
        }
    }

    private func convertToParsedTransaction(_ item: LLMTransactionItem) -> ParsedTransaction {
        let amount: Decimal? = item.amount.map { Decimal($0) }

        var date: Date? = nil
        if let dateString = item.date {
            // Try simple date format with local timezone
            let simpleFormatter = DateFormatter()
            simpleFormatter.dateFormat = "yyyy-MM-dd"
            simpleFormatter.timeZone = .current
            simpleFormatter.locale = Locale(identifier: "en_US_POSIX")

            if let parsed = simpleFormatter.date(from: dateString) {
                // Set time to noon to avoid timezone edge cases
                let calendar = Calendar.current
                date = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: parsed)
            }
        }

        return ParsedTransaction(
            amount: amount,
            date: date,
            note: item.note,
            isExpense: item.isExpense,
            subcategoryHint: item.subcategoryHint,
            tagHints: item.tagHints ?? [],
            currencyHint: item.currencyHint,
            confidence: ParsedTransaction.TransactionConfidence(
                amount: item.confidence.amount,
                date: item.confidence.date,
                merchant: item.confidence.merchant,
                subcategory: item.confidence.subcategory,
                tags: item.confidence.tags
            )
        )
    }
}
