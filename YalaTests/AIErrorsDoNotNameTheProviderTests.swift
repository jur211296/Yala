//
//  AIErrorsDoNotNameTheProviderTests.swift
//  YalaTests
//
//  Card «Un error de la foto todavía nombra al proveedor de IA» (lote 12.4). La norma es decir «un servicio de IA»: el
//  único sitio que nombra al proveedor es la política de privacidad. Las pantallas de foto y voz no enseñan
//  `localizedDescription` (`ImageEntryFlowLogic`, `VoiceEntryFlowLogic`), pero el texto llega a logs y a cualquier camino
//  futuro que lo pinte. Las cuatro enumeraciones tenían el mismo «OpenAI API key not configured».
//

import Foundation
import Testing
@testable import Yala

@MainActor
struct AIErrorsDoNotNameTheProviderTests {

    private struct Dummy: Error {}

    private var allDescriptions: [String] {
        let vision: [VisionError] = [.noAPIKey, .imageEncodingFailed, .networkError(Dummy()), .invalidResponse,
                                     .noTransactionsFound]
        let insights: [InsightsLLMError] = [.noAPIKey, .notProUser, .noAIConsent, .offline, .rateLimited, .parseFailed,
                                            .networkError(Dummy())]
        let parser: [ParserError] = [.noAPIKey, .emptyText, .parsingFailed("x"), .invalidResponse,
                                     .networkError(Dummy())]
        let transcription: [TranscriptionError] = [.noAPIKey, .emptyAudio, .transcriptionFailed("x"),
                                                   .networkError(Dummy())]
        return vision.compactMap(\.errorDescription) + insights.compactMap(\.errorDescription)
            + parser.compactMap(\.errorDescription) + transcription.compactMap(\.errorDescription)
    }

    @Test func noErrorDescriptionNamesTheProvider() {
        let descriptions = allDescriptions
        #expect(descriptions.count == 21)
        for text in descriptions {
            #expect(!text.localizedCaseInsensitiveContains("openai"), "Nombra al proveedor: «\(text)»")
            #expect(!text.localizedCaseInsensitiveContains("gpt"), "Nombra al modelo: «\(text)»")
        }
    }

    @Test func missingKeySaysAIService() {
        #expect(VisionError.noAPIKey.errorDescription == "AI service not configured")
        #expect(InsightsLLMError.noAPIKey.errorDescription == "AI service not configured")
        #expect(ParserError.noAPIKey.errorDescription == "AI service not configured")
        #expect(TranscriptionError.noAPIKey.errorDescription == "AI service not configured")
    }
}
