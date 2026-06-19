//
//  APIKeyService.swift
//  Yala
//
//  Service for accessing API keys injected via xcconfig at build time.
//  Keys are stored in Secrets.xcconfig (git-ignored) and injected into Info.plist.
//

import Foundation

enum APIKeyService {

    // La OpenAI API key se RETIRÓ del cliente: ahora vive solo en el gateway (Worker).
    // El cliente va al proxy vía ProxyClientFactory + App Attest. Ver DESIGN-secure-proxy-gateway.md.

    // MARK: - TelemetryDeck

    /// TelemetryDeck App ID for privacy-first analytics.
    /// Injected from Secrets.xcconfig via Info.plist at build time.
    static var telemetryDeckAppID: String? {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "TELEMETRY_DECK_APP_ID") as? String,
              !key.isEmpty,
              key != "$(TELEMETRY_DECK_APP_ID)",
              !key.hasPrefix("YOUR_")
        else {
            return nil
        }
        return key
    }
}
