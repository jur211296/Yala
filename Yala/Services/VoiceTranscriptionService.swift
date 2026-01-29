//
//  VoiceTranscriptionService.swift
//  Neto
//
//  Service for transcribing voice recordings using OpenAI Whisper API.
//

import Foundation
import Observation
import OpenAI

// MARK: - Transcription Result

struct TranscriptionResult {
    let text: String
    let language: String?
}

// MARK: - Transcription Error

enum TranscriptionError: Error, LocalizedError {
    case noAPIKey
    case emptyAudio
    case transcriptionFailed(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "OpenAI API key not configured"
        case .emptyAudio:
            return "Audio data is empty"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Voice Language

enum VoiceLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case spanish = "es"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return L10n.VoiceLanguage.system
        case .spanish: return L10n.VoiceLanguage.spanish
        case .english: return L10n.VoiceLanguage.english
        }
    }

    /// Returns the ISO language code for OpenAI API
    var isoCode: String? {
        switch self {
        case .system:
            // Get system language, default to Spanish
            let preferred = Locale.preferredLanguages.first ?? "es"
            if preferred.hasPrefix("en") { return "en" }
            return "es"  // Default to Spanish for other languages
        case .spanish:
            return "es"
        case .english:
            return "en"
        }
    }
}

// MARK: - Voice Transcription Service

/// Service for transcribing voice recordings.
/// Supports @Environment injection in SwiftUI views.
@Observable
final class VoiceTranscriptionService {

    // MARK: - Singleton (for backward compatibility)

    /// Shared instance for backward compatibility. Prefer @Environment injection in Views.
    static let shared = VoiceTranscriptionService()

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

    // MARK: - Public Methods

    /// Transcribes audio data to text using OpenAI Whisper API.
    /// - Parameters:
    ///   - audioData: Audio data in supported format (m4a, mp3, wav, etc.)
    ///   - language: Preferred language for transcription
    /// - Returns: TranscriptionResult with transcribed text
    func transcribe(
        audioData: Data,
        language: VoiceLanguage = .system
    ) async throws -> TranscriptionResult {
        guard let client = openAI else {
            throw TranscriptionError.noAPIKey
        }

        guard !audioData.isEmpty else {
            throw TranscriptionError.emptyAudio
        }

        let query = AudioTranscriptionQuery(
            file: audioData,
            fileType: .m4a,
            model: .whisper_1,
            language: language.isoCode
        )

        do {
            let result = try await client.audioTranscriptions(query: query)
            return TranscriptionResult(
                text: result.text,
                language: language.isoCode
            )
        } catch {
            throw TranscriptionError.networkError(error)
        }
    }
}
