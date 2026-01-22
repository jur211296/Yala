//
//  APIKeyService.swift
//  Neto
//
//  Service for accessing API keys injected via xcconfig at build time.
//  Keys are stored in Secrets.xcconfig (git-ignored) and injected into Info.plist.
//

import Foundation

enum APIKeyService {

    // MARK: - OpenAI

    /// OpenAI API key for voice transcription and LLM parsing.
    /// Injected from Secrets.xcconfig via Info.plist at build time.
    static var openAIAPIKey: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
              !key.isEmpty,
              key != "$(OPENAI_API_KEY)",  // Not substituted
              !key.hasPrefix("sk-REPLACE")  // Placeholder
        else {
            return nil
        }
        return key
    }

    /// Returns true if a valid OpenAI API key is configured.
    static var hasOpenAIAPIKey: Bool {
        openAIAPIKey != nil
    }
}
