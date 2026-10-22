//
//  VoiceTranscriptionService.swift
//  Yala
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

/// Idioma en que se transcribe la voz. Por defecto sigue al idioma de Yala, y se puede fijar a cualquiera de los 10
/// idiomas de la app (sesión 2 del gateway de IA: antes solo había «Sistema», español e inglés, «Sistema» leía el idioma
/// del iPhone y no el de la app, y un idioma que no conocía caía a inglés).
enum VoiceLanguage: String, CaseIterable, Identifiable {
    /// «Idioma de la app». Conserva el valor persistido `system` de antes, así que quien tenía «Sistema» pasa a seguir
    /// al idioma de Yala sin migración.
    case system = "system"
    case spanish = "es"
    case english = "en"
    case portuguese = "pt"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case dutch = "nl"
    case polish = "pl"
    case japanese = "ja"
    case chinese = "zh"

    var id: String { rawValue }

    /// En el selector: «Idioma de la app» y, para los demás, el nombre del idioma en su propio idioma (como el
    /// selector de idioma de la app), para que quien dicta en otro idioma lo reconozca sin traducir.
    var displayName: String {
        switch self {
        case .system: L10n.VoiceLanguage.appLanguage
        case .spanish: "Español"
        case .english: "English"
        case .portuguese: "Português"
        case .french: "Français"
        case .german: "Deutsch"
        case .italian: "Italiano"
        case .dutch: "Nederlands"
        case .polish: "Polski"
        case .japanese: "日本語"
        case .chinese: "中文"
        }
    }

    /// Código ISO 639-1 que se manda al motor de transcripción.
    var isoCode: String {
        Self.isoCode(for: self, appLocale: AppLocale.current)
    }

    /// Pura, para test: con «Idioma de la app» el código sale del idioma de Yala (no del iPhone). Yala solo corre en
    /// sus 10 idiomas, así que un idioma de la app siempre tiene su voz; si algún día no casara, se usa el idioma que
    /// la app esté enseñando, nunca inglés por defecto.
    static func isoCode(for language: VoiceLanguage, appLocale: Locale) -> String {
        guard language == .system else { return language.rawValue }
        let code = appLocale.language.languageCode?.identifier ?? ""
        if let match = VoiceLanguage(rawValue: code), match != .system { return match.rawValue }
        let base = String(appLocale.identifier.prefix(2))
        if let match = VoiceLanguage(rawValue: base), match != .system { return match.rawValue }
        return code.isEmpty ? base : code
    }
}

// MARK: - Términos del usuario

/// Los nombres que el motor de transcripción suele oír mal y el usuario dice a menudo: sus comercios y sus
/// subcategorías («Plaza Vea», «Rappi», «Mercado»). Viajan en el `prompt` de la petición, uno por línea, y el gateway
/// decide si el modelo de su fila los usa (como `keywords[]` en `gpt-transcribe`) o no (sesión 2 del gateway de IA).
enum VoiceTranscriptionKeywords {
    /// El banco de voz midió con ~70 (10 comercios y unas 60 subcategorías) y la fila del gateway pasa hasta 100.
    nonisolated static let maxTerms = 80

    /// Comercios primero (son los nombres propios, los que más se tuercen) y después subcategorías; sin repetir, sin
    /// vacíos y sin términos larguísimos.
    nonisolated static func terms(merchants: [String], subcategories: [String], max: Int = maxTerms) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in merchants + subcategories {
            let term = raw.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard term.count >= 2, term.count <= 64, seen.insert(term.lowercased()).inserted else { continue }
            out.append(term)
            if out.count >= max { break }
        }
        return out
    }
}

// MARK: - Voice Transcription Service

/// Service for transcribing voice recordings.
/// Supports @Environment injection in SwiftUI views.
@MainActor @Observable
final class VoiceTranscriptionService {

    // MARK: - Singleton (for backward compatibility)

    /// Shared instance for backward compatibility. Prefer @Environment injection in Views.
    static let shared = VoiceTranscriptionService()

    init() {}

    // MARK: - Properties

    // MARK: - Public Methods

    /// Transcribes audio data to text using OpenAI Whisper API.
    /// - Parameters:
    ///   - audioData: Audio data in supported format (m4a, mp3, wav, etc.)
    ///   - language: Preferred language for transcription
    /// - Returns: TranscriptionResult with transcribed text
    func transcribe(
        audioData: Data,
        language: VoiceLanguage = .system,
        keywords: [String] = []
    ) async throws -> TranscriptionResult {
        let client: OpenAI
        do {
            client = try await ProxyClientFactory.makeOpenAI(task: .voiceTranscribe)
        } catch {
            throw TranscriptionError.networkError(error)
        }

        guard !audioData.isEmpty else {
            throw TranscriptionError.emptyAudio
        }

        let query = AudioTranscriptionQuery(
            file: audioData,
            fileType: .m4a,
            model: .whisper_1,
            prompt: keywords.isEmpty ? nil : keywords.joined(separator: "\n"),
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
