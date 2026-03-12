//
//  ImageVisionService.swift
//  Yala
//
//  Service for extracting transactions from images using GPT-4o Vision.
//  Falls back to local OCR pipeline if API unavailable.
//

import UIKit
import Observation
import OpenAI

// MARK: - Response Models

/// A single transaction extracted from an image
struct VisionTransaction: Codable {
    let amount: Double?
    let date: String?        // YYYY-MM-DD format
    let merchant: String?
    let note: String?
    let currency: String?    // "USD", "EUR", "PEN", etc.
}

/// Confidence scores for the vision extraction
struct VisionConfidence: Codable {
    let overall: Double       // 0.0-1.0
    let imageType: Double     // Confidence in image classification
}

/// Complete response from GPT-4o Vision
struct VisionResponse: Codable {
    let imageType: String     // "single", "list", "receipt", "unknown"
    let transactions: [VisionTransaction]
    let confidence: VisionConfidence
}

// MARK: - Errors

enum VisionError: Error, LocalizedError {
    case noAPIKey
    case imageEncodingFailed
    case networkError(Error)
    case invalidResponse
    case noTransactionsFound

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "OpenAI API key not configured"
        case .imageEncodingFailed:
            return "Failed to encode image"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from Vision API"
        case .noTransactionsFound:
            return "No transactions found in image"
        }
    }
}

// MARK: - Service

/// Service for extracting transactions from images using GPT-4o Vision API.
/// Supports @Environment injection in SwiftUI views.
@MainActor @Observable
final class ImageVisionService {

    // MARK: - Singleton (for backward compatibility)

    /// Shared instance for backward compatibility. Prefer @Environment injection in Views.
    static let shared = ImageVisionService()

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

    /// Returns true if the Vision API is available (API key configured)
    var isAvailable: Bool {
        openAI != nil
    }

    // MARK: - System Prompt

    private var systemPrompt: String {
        let dateContext = DateContextProvider.buildDateContext()

        return """
        You are a financial transaction extractor. Analyze images and extract transaction data.

        Image types:
        - "single": One transaction (bank alert, notification)
        - "list": Multiple transactions (bank history, statement)
        - "receipt": Photo of a receipt (extract TOTAL only)
        - "unknown": Cannot identify as financial

        Rules:
        - Amounts: No currency symbol, expenses are NEGATIVE, income is POSITIVE
        - Dates: ALWAYS convert to YYYY-MM-DD format
        - Currency: Extract from symbols or explicit mentions

        Currency extraction rules:
        - "$" symbol alone or "US$" → "USD"
        - "€" symbol → "EUR"
        - "S/" symbol → "PEN"
        - "£" symbol → "GBP"
        - Explicit mentions: "dollars", "dólares", "USD" → "USD"
        - Explicit mentions: "soles", "PEN" → "PEN"
        - Explicit mentions: "euros", "EUR" → "EUR"
        - If no currency indicator found → null

        \(dateContext)

        Date formats to recognize and convert:
        - Spanish abbreviated: "13 ene. 2026", "13 ene 2026" → 2026-01-13
        - English abbreviated: "Jan 13, 2026", "13 Jan 2026" → 2026-01-13
        - Spanish full: "13 de enero de 2026" → 2026-01-13
        - English full: "January 13, 2026" → 2026-01-13
        - Numeric short: "15/01/26", "15-01-26" → 2026-01-15
        - Numeric long: "15/01/2026", "15-01-2026" → 2026-01-15
        - ISO: "2026-01-15" → 2026-01-15
        - Day/month only (assume current year): "15/01" → current-year-01-15

        Spanish months: ene, feb, mar, abr, may, jun, jul, ago, sep, oct, nov, dic
        English months: jan, feb, mar, apr, may, jun, jul, aug, sep, oct, nov, dec

        Respond ONLY with valid JSON (no markdown, no explanation):
        {
          "imageType": "single",
          "transactions": [{"amount": -45.50, "date": "2026-01-25", "merchant": "Starbucks", "note": null, "currency": "USD"}],
          "confidence": {"overall": 0.95, "imageType": 0.90}
        }
        """
    }

    // MARK: - Public Methods

    /// Analyzes an image using GPT-4o Vision to extract transactions
    /// - Parameter image: UIImage to analyze
    /// - Returns: VisionResponse with extracted transactions
    /// - Throws: VisionError if analysis fails
    func analyze(image: UIImage) async throws -> VisionResponse {
        guard let client = openAI else {
            throw VisionError.noAPIKey
        }

        // Encode image to base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw VisionError.imageEncodingFailed
        }

        // Build content parts for multimodal message
        let textPart = ChatQuery.ChatCompletionMessageParam.ContentPartTextParam(
            text: "Extract transactions from this image. Today is \(currentDayAndDateString())."
        )
        let imagePart = ChatQuery.ChatCompletionMessageParam.ContentPartImageParam(
            imageUrl: .init(imageData: imageData, detail: .auto)
        )

        // Build the chat request with vision
        let query = ChatQuery(
            messages: [
                .system(.init(content: .textContent(systemPrompt))),
                .user(.init(content: .contentParts([.text(textPart), .image(imagePart)])))
            ],
            model: .gpt4_1_nano,
            responseFormat: .jsonObject
        )

        do {
            let result = try await client.chats(query: query)

            // Extract text content from response
            guard let contentString = result.choices.first?.message.content,
                  !contentString.isEmpty else {
                throw VisionError.invalidResponse
            }

            // Parse JSON response
            guard let jsonData = contentString.data(using: .utf8) else {
                throw VisionError.invalidResponse
            }

            let response = try JSONDecoder().decode(VisionResponse.self, from: jsonData)
            return response

        } catch let error as VisionError {
            throw error
        } catch {
            throw VisionError.networkError(error)
        }
    }

    // MARK: - Private Methods

    private func currentDayAndDateString() -> String {
        let dayFmt = DateFormatter()
        dayFmt.locale = Locale(identifier: "en")
        dayFmt.dateFormat = "EEEE"
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let now = Date.now
        return "\(dayFmt.string(from: now)), \(dateFmt.string(from: now))"
    }
}
