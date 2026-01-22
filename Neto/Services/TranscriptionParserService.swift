//
//  TranscriptionParserService.swift
//  Neto
//
//  Service for parsing transcribed text into structured transaction data using OpenAI LLM.
//

import Foundation
import OpenAI

// MARK: - Parsed Transaction

struct ParsedTransaction: Codable {
    let amount: Decimal?
    let date: Date?
    let note: String
    let isExpense: Bool
    let confidence: TransactionConfidence

    struct TransactionConfidence: Codable {
        let amount: Double
        let date: Double
        let merchant: Double
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

// MARK: - LLM Response Model

private struct LLMResponse: Codable {
    let amount: Double?
    let date: String?
    let note: String
    let isExpense: Bool
    let confidence: ConfidenceScores

    struct ConfidenceScores: Codable {
        let amount: Double
        let date: Double
        let merchant: Double
    }
}

// MARK: - Transcription Parser Service

final class TranscriptionParserService {

    // MARK: - Singleton

    static let shared = TranscriptionParserService()

    private init() {}

    // MARK: - Properties

    private lazy var openAI: OpenAI? = {
        guard let apiKey = APIKeyService.openAIAPIKey else {
            return nil
        }
        return OpenAI(apiToken: apiKey)
    }()

    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    // MARK: - System Prompt

    private var systemPrompt: String {
        let today = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
        let yesterday = ISO8601DateFormatter.string(
            from: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            timeZone: .current,
            formatOptions: [.withFullDate]
        )

        return """
        Eres un parser de gastos para una app de finanzas personales.
        Extrae información de la transcripción y devuelve SOLO JSON válido, sin markdown ni explicaciones.

        Reglas de fecha:
        - "hoy", "ahorita", "recién", "acabo de" → \(today)
        - "ayer" → \(yesterday)
        - Sin mención de fecha → \(today)
        - Fecha explícita → usar esa fecha en formato YYYY-MM-DD

        Reglas de monto:
        - Extrae el número mencionado
        - "cincuenta" = 50, "cien" = 100, "mil" = 1000
        - Si no hay monto claro, usa null

        Reglas de tipo:
        - Por defecto asume gasto (isExpense: true)
        - Si menciona "ingreso", "cobré", "me pagaron", "recibí" → isExpense: false

        Reglas de nota:
        - Incluye el merchant/comercio si se menciona
        - Incluye descripción breve del gasto

        Responde ÚNICAMENTE con este JSON (sin ```json ni nada más):
        {
          "amount": number | null,
          "date": "YYYY-MM-DD",
          "note": "descripción breve",
          "isExpense": true | false,
          "confidence": {
            "amount": 0.0-1.0,
            "date": 0.0-1.0,
            "merchant": 0.0-1.0
          }
        }
        """
    }

    // MARK: - Public Methods

    /// Parses transcribed text to extract structured transaction data.
    /// - Parameter text: The transcribed text from voice input
    /// - Returns: ParsedTransaction with extracted data and confidence scores
    func parse(text: String) async throws -> ParsedTransaction {
        guard let client = openAI else {
            throw ParserError.noAPIKey
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw ParserError.emptyText
        }

        let query = ChatQuery(
            messages: [
                .system(.init(content: .textContent(systemPrompt))),
                .user(.init(content: .string(trimmedText)))
            ],
            model: .gpt4_o_mini,
            temperature: 0.1  // Low temperature for consistent parsing
        )

        do {
            let result = try await client.chats(query: query)

            guard let content = result.choices.first?.message.content else {
                throw ParserError.invalidResponse
            }

            return try parseResponse(content)
        } catch let error as ParserError {
            throw error
        } catch {
            throw ParserError.networkError(error)
        }
    }

    // MARK: - Private Methods

    private func parseResponse(_ content: String) throws -> ParsedTransaction {
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
        let llmResponse: LLMResponse

        do {
            llmResponse = try decoder.decode(LLMResponse.self, from: data)
        } catch {
            throw ParserError.parsingFailed("JSON decode error: \(error.localizedDescription)")
        }

        // Convert to ParsedTransaction
        let amount: Decimal? = llmResponse.amount.map { Decimal($0) }

        var date: Date? = nil
        if let dateString = llmResponse.date {
            // Try ISO8601 format first
            if let parsed = dateFormatter.date(from: dateString) {
                date = parsed
            } else {
                // Try simple date format
                let simpleFormatter = DateFormatter()
                simpleFormatter.dateFormat = "yyyy-MM-dd"
                date = simpleFormatter.date(from: dateString)
            }
        }

        return ParsedTransaction(
            amount: amount,
            date: date,
            note: llmResponse.note,
            isExpense: llmResponse.isExpense,
            confidence: ParsedTransaction.TransactionConfidence(
                amount: llmResponse.confidence.amount,
                date: llmResponse.confidence.date,
                merchant: llmResponse.confidence.merchant
            )
        )
    }
}
