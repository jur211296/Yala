//
//  ProxyClientFactory.swift
//  Yala
//
//  Construye el cliente OpenAI del SDK MacPaw apuntando al gateway de Yala (no a api.openai.com),
//  con el token de sesión de App Attest como Bearer. El SDK soporta este patrón de fábrica
//  (token: nil → la auth la maneja el proxy). Reemplaza `OpenAI(apiToken:)` en todos los servicios.
//

import Foundation
import OpenAI

enum ProxyClientFactory {
    /// Categoría de cuota (header X-Yala-Category) — el gateway elige el bucket de límite.
    enum Category: String {
        case chat, vision, voice, insights, suggestions
    }

    /// Cliente OpenAI que enruta al gateway. Refresca el token de sesión si hace falta.
    /// Lanza `AppAttestError` si no se puede atestar (el callsite degrada a su error tipado).
    static func makeOpenAI(category: Category) async throws -> OpenAI {
        let token = try await AppAttestClient.shared.currentSessionToken()
        return OpenAI(configuration: .init(
            token: nil, // el gateway inyecta la key real; el cliente no la conoce
            host: ProxyConfig.openAIHost,
            basePath: "/v1",
            timeoutInterval: 20,
            customHeaders: [
                "Authorization": "Bearer \(token)",
                "X-Yala-Category": category.rawValue,
            ],
        ))
    }
}
