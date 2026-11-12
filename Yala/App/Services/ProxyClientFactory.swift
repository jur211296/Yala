//
//  ProxyClientFactory.swift
//  Yala
//
//  Construye el cliente OpenAI del SDK MacPaw apuntando al gateway de Yala (no a api.openai.com),
//  con el token de sesión de App Attest como Bearer. El SDK soporta este patrón de fábrica
//  (token: nil → la auth la maneja el proxy). Reemplaza `OpenAI(apiToken:)` en todos los servicios.
//
//  Desde la sesión 2 del gateway de IA cada llamada dice QUÉ TAREA pide (`X-Yala-Task`). Con eso el gateway
//  elige proveedor, modelo y parámetros (tabla `gateway/src/ai/routes.ts`) y el cubo de cuota. El `model` que la
//  app sigue escribiendo en la petición lo exige el SDK, pero ya no decide nada.
//

import Foundation
import OpenAI

/// Las tareas de IA de la app. El `rawValue` es el nombre que entiende el gateway (`TASKS` en
/// `gateway/src/ai/tasks.ts`): cambiarlo rompe el contrato.
nonisolated enum ProxyTask: String, CaseIterable, Sendable {
    case photoRead = "photo.read"
    case chatIntent = "chat.intent"
    case chatSuggestions = "chat.suggestions"
    case chatAnswer = "chat.answer"
    /// Yala IA en modo nube con el camino ampliado: la misma pregunta que `chatAnswer`, y el gateway le da al modelo
    /// herramientas que leen las tablas del usuario. Solo la pide `YalaIAChatRouting` con el flag encendido.
    case chatExplore = "chat.explore"
    case chatRewrite = "chat.rewrite"
    case textParse = "text.parse"
    case voiceTranscribe = "voice.transcribe"
    case insightsCards = "insights.cards"
    case insightsCashflow = "insights.cashflow"
    case insightsDeviation = "insights.deviation"
    case trendsSummary = "trends.summary"

    /// El cubo de cuota de la tarea: el mismo que el gateway asigna a esa tarea. Se manda también en
    /// `X-Yala-Category` para los gateways anteriores a la sesión 2, que lo leían de ahí.
    var category: ProxyClientFactory.Category {
        switch self {
        case .photoRead: .vision
        case .chatIntent, .chatSuggestions, .chatRewrite: .suggestions
        case .chatAnswer, .chatExplore: .chat
        case .textParse, .voiceTranscribe: .voice
        case .insightsCards, .insightsCashflow, .insightsDeviation, .trendsSummary: .insights
        }
    }
}

enum ProxyClientFactory {
    /// Categoría de cuota (header X-Yala-Category) — el gateway elige el bucket de límite.
    nonisolated enum Category: String, Sendable {
        case chat, vision, voice, insights, suggestions
    }

    /// Timeout de red de cada petición, el de siempre. El camino ampliado de Yala IA pasa otro (varias llamadas al
    /// modelo dentro de una sola petición).
    nonisolated static let defaultTimeout: TimeInterval = 20

    /// Cliente OpenAI que enruta al gateway para una tarea. Refresca el token de sesión si hace falta.
    /// Lanza `AppAttestError` si no se puede atestar (el callsite degrada a su error tipado).
    /// `extraHeaders` solo AÑADE cabeceras: las tres de la tarea no se pueden pisar.
    static func makeOpenAI(
        task: ProxyTask,
        extraHeaders: [String: String] = [:],
        timeout: TimeInterval = defaultTimeout
    ) async throws -> OpenAI {
        #if DEBUG
        if let transport = testTransport {
            return OpenAI(
                configuration: configuration(token: transport.token, task: task, extraHeaders: extraHeaders, timeout: timeout),
                session: transport.session
            )
        }
        #endif
        let token = try await AppAttestClient.shared.currentSessionToken()
        return OpenAI(configuration: configuration(token: token, task: task, extraHeaders: extraHeaders, timeout: timeout))
    }

    /// Configuración del SDK para una tarea: host y ruta del gateway, timeout y las cabeceras.
    nonisolated static func configuration(
        token: String,
        task: ProxyTask,
        extraHeaders: [String: String] = [:],
        timeout: TimeInterval = defaultTimeout
    ) -> OpenAI.Configuration {
        .init(
            token: nil, // el gateway inyecta la key real; el cliente no la conoce
            host: ProxyConfig.openAIHost,
            basePath: "/v1",
            timeoutInterval: timeout,
            customHeaders: headers(token: token, task: task, extraHeaders: extraHeaders)
        )
    }

    /// Cabeceras de cada petición: el token de sesión, la tarea y su cubo, más las que pida el llamador.
    nonisolated static func headers(token: String, task: ProxyTask, extraHeaders: [String: String] = [:]) -> [String: String] {
        let base = [
            "Authorization": "Bearer \(token)",
            "X-Yala-Task": task.rawValue,
            "X-Yala-Category": task.category.rawValue,
        ]
        // Las de la tarea ganan: un extra no puede cambiar el token, la tarea ni el cubo.
        return extraHeaders.merging(base) { _, fromBase in fromBase }
    }

    #if DEBUG
    /// Solo tests: sustituye el token de App Attest y la sesión de red, para leer la petición que sale DE VERDAD
    /// de cada servicio (`ProxyTaskHeaderTests`). Producción nunca lo toca.
    static var testTransport: (token: String, session: URLSession)?
    #endif
}
