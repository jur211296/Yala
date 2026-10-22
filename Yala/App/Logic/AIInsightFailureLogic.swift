//
//  AIInsightFailureLogic.swift
//  Yala
//
//  Por qué falló un análisis de IA de Estadísticas (Resumen, Distribución y Tendencias). El ViewModel guarda el
//  motivo y la vista elige el texto (`AIInsightCardComponents.message(for:)`): antes el ViewModel guardaba
//  `error.localizedDescription` y la tarjeta enseñaba «Network error: …» en inglés con la app en cualquier idioma.
//

import Foundation

/// El motivo de un fallo del análisis de IA, tal como lo cuenta la tarjeta.
enum AIInsightFailure: Equatable {
    /// Sin conexión: lo único que el usuario puede arreglar él mismo.
    case offline
    /// La respuesta no llegó a tiempo.
    case timeout
    /// El gateway contestó 429 `yala_quota_daily`: se agotó el cupo de análisis de hoy.
    case dailyLimit
    /// Demasiadas peticiones seguidas: el 429 `yala_quota_burst` del gateway o la espera de 5 s del propio servicio.
    case tooManyRequests
    /// El gateway contestó 403 `yala_pro_required` con la app creyéndose Pro (el plan no se pudo confirmar).
    case proRequired
    /// Cualquier otra cosa: «inténtalo otra vez».
    case generic
}

enum AIInsightFailureLogic {

    /// Clasifica el error que lanzan `InsightsLLMService` y `TrendsAIService`. Los errores del gateway llegan
    /// envueltos en `InsightsLLMError.networkError` y se leen con `ProxyErrorMapper`, igual que en el chat.
    static func failure(for error: Error, isConnected: Bool) -> AIInsightFailure {
        guard let llmError = error as? InsightsLLMError else {
            return failure(forTransport: error, isConnected: isConnected)
        }
        switch llmError {
        case .offline: return .offline
        case .rateLimited: return .tooManyRequests
        case .notProUser: return .proRequired
        case .noAPIKey, .noAIConsent, .parseFailed: return .generic
        case .networkError(let inner): return failure(forTransport: inner, isConnected: isConnected)
        }
    }

    /// Un error de red o del gateway, ya desenvuelto.
    private static func failure(forTransport error: Error, isConnected: Bool) -> AIInsightFailure {
        switch ProxyErrorMapper.gatewayType(from: error) {
        case "yala_quota_daily": return .dailyLimit
        case "yala_quota_burst": return .tooManyRequests
        case "yala_pro_required": return .proRequired
        default: break
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut: return .timeout
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: return .offline
            default: break
            }
        }
        return isConnected ? .generic : .offline
    }
}
