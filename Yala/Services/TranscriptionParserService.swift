//
//  TranscriptionParserService.swift
//  Yala
//
//  Service for parsing transcribed text into structured transaction data using OpenAI LLM.
//

import Foundation
import Observation
import OpenAI

// MARK: - Parsed Transaction

struct ParsedTransaction: Codable {
    let amount: Decimal?
    let date: Date?
    let note: String
    let isExpense: Bool
    let subcategoryHint: String?
    let tagHints: [String]
    let currencyHint: String?
    let confidence: TransactionConfidence

    struct TransactionConfidence: Codable {
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
    private var _openAI: OpenAI?
    @ObservationIgnored
    private var _openAIInitialized = false

    private var openAI: OpenAI? {
        if !_openAIInitialized {
            _openAIInitialized = true
            if let apiKey = APIKeyService.openAIAPIKey {
                _openAI = OpenAI(apiToken: apiKey)
            }
        }
        return _openAI
    }

    @ObservationIgnored
    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    // MARK: - System Prompt

    private func buildSystemPrompt(expenseSubcategories: [String], incomeSubcategories: [String]) -> String {
        let expenseList = expenseSubcategories.isEmpty ? "No hay subcategorías de gasto definidas" : expenseSubcategories.joined(separator: ", ")
        let incomeList = incomeSubcategories.isEmpty ? "No hay subcategorías de ingreso definidas" : incomeSubcategories.joined(separator: ", ")

        let dateContext = DateContextProvider.buildDateContext()

        return """
        Eres un parser de gastos para una app de finanzas personales.
        Extrae información de la transcripción y devuelve SOLO JSON válido, sin markdown ni explicaciones.

        IMPORTANTE - Múltiples transacciones:
        - Si el usuario menciona más de una transacción (ej: "50 en café y 100 en uber", "gasté 30 en almuerzo, 15 en estacionamiento y me pagaron 200"), extrae CADA una por separado
        - Cada transacción va como un objeto independiente en el array "transactions"
        - Conjunciones como "y", "además", "también", "luego" suelen separar transacciones

        \(dateContext)

        Reglas de monto:
        - Extrae el número mencionado
        - "cincuenta" = 50, "cien" = 100, "mil" = 1000
        - Si no hay monto claro, usa null

        Reglas de tipo:
        - Por defecto asume gasto (isExpense: true)
        - Si menciona "ingreso", "cobré", "me pagaron", "recibí" → isExpense: false

        Reglas de subcategoría (MUY IMPORTANTE):
        - SIEMPRE intenta inferir la subcategoría más apropiada del contexto
        - DEBES elegir ÚNICAMENTE de las subcategorías disponibles del usuario (listadas abajo)
        - Analiza el contexto semántico: "Uber" es taxi/app de transporte, "Netflix" es streaming, "Starbucks" es cafetería, etc.
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

        Reglas de moneda:
        - Extrae el código de moneda ISO si se menciona explícitamente
        - "dólares", "dollars", "usd" → "USD"
        - "euros", "eur" → "EUR"
        - "soles", "pen" → "PEN"
        - "pesos mexicanos", "mxn" → "MXN"
        - "pesos colombianos", "cop" → "COP"
        - "reales", "brl" → "BRL"
        - Si no se menciona moneda → null

        Reglas de nota (IMPORTANTE):
        - La nota es para el merchant/comercio específico o información adicional
        - NUNCA repetir la subcategoría inferida en la nota
        - Si hay subcategoría + merchant: note = merchant. Ej: "Starbucks" → subcategoryHint: "Cafetería", note: "Starbucks"
        - Si hay subcategoría sin merchant específico: note = "". Ej: "gasté en restaurantes" → subcategoryHint: "Restaurantes", note: ""
        - Ej: "gasté en almuerzo" → subcategoryHint: "Restaurantes", note: "almuerzo"

        Ejemplos few-shot (F7):
        Input: "Anota 50 soles en café"
        Output: {"transactions":[{"amount":50,"date":"\(Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash)))","note":"café","isExpense":true,"subcategoryHint":"Cafetería","tagHints":[],"currencyHint":"PEN","confidence":{"amount":1.0,"date":0.0,"merchant":0.9,"subcategory":0.85,"tags":0.0}}]}

        Input: "I spent 25 dollars on lunch"
        Output: {"transactions":[{"amount":25,"date":"\(Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash)))","note":"lunch","isExpense":true,"subcategoryHint":"Restaurants","tagHints":[],"currencyHint":"USD","confidence":{"amount":1.0,"date":0.0,"merchant":0.9,"subcategory":0.85,"tags":0.0}}]}

        Input: "30 en almuerzo y 15 en estacionamiento"
        Output: {"transactions":[{"amount":30,"date":null,"note":"almuerzo","isExpense":true,"subcategoryHint":"Restaurantes","tagHints":[],"currencyHint":null,"confidence":{"amount":1.0,"date":0.0,"merchant":0.9,"subcategory":0.85,"tags":0.0}},{"amount":15,"date":null,"note":"estacionamiento","isExpense":true,"subcategoryHint":"Transporte","tagHints":[],"currencyHint":null,"confidence":{"amount":1.0,"date":0.0,"merchant":0.9,"subcategory":0.7,"tags":0.0}}]}

        Responde ÚNICAMENTE con este JSON (sin ```json ni nada más):
        {
          "transactions": [
            {
              "amount": number | null,
              "date": "YYYY-MM-DD",
              "note": "descripción breve",
              "isExpense": true | false,
              "subcategoryHint": "nombre subcategoría exacto de la lista" | null,
              "tagHints": ["tag1", "tag2"] | [],
              "currencyHint": "USD" | "EUR" | "PEN" | null,
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
        incomeSubcategories: [String] = []
    ) async throws -> ParsedTransaction {
        let transactions = try await parseMultiple(
            text: text,
            expenseSubcategories: expenseSubcategories,
            incomeSubcategories: incomeSubcategories
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
        incomeSubcategories: [String] = []
    ) async throws -> [ParsedTransaction] {
        guard let client = openAI else {
            throw ParserError.noAPIKey
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw ParserError.emptyText
        }

        let prompt = buildSystemPrompt(
            expenseSubcategories: expenseSubcategories,
            incomeSubcategories: incomeSubcategories
        )

        let query = ChatQuery(
            messages: [
                .system(.init(content: .textContent(prompt))),
                .user(.init(content: .string(trimmedText)))
            ],
            model: .gpt4_1_mini,  // F7: upgrade nano→mini para mejor parsing structured ES/EN
            temperature: 0.1  // Low temperature for consistent parsing
        )

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

    // MARK: - Private Methods

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
