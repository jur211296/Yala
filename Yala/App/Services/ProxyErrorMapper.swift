//
//  ProxyErrorMapper.swift
//  Yala
//
//  Mapea los errores tipados del gateway (envelopes OpenAI-compatibles `{"error":{type,…}}` que el
//  SDK MacPaw decodifica como `APIErrorResponse`) a los errores tipados del cliente. Sin esto, una
//  cuota agotada (429) o Pro requerido (403) caen al banner genérico; con esto el usuario ve el
//  mensaje preciso. Es aditivo: si no reconoce el tipo, devuelve el error original.
//

import Foundation
import OpenAI

enum ProxyErrorMapper {
    /// El `error.type` del envelope del gateway, si el Error lo es.
    static func gatewayType(from error: Error) -> String? {
        (error as? APIErrorResponse)?.error.type
    }

    /// ¿El gateway dice que el plan free agotó su cupo de prueba de voz o de foto (403 `yala_trial_exhausted`, sesión 2
    /// del gateway de IA)? No se repone esperando: la salida es Yala Pro.
    static func isTrialExhausted(_ error: Error) -> Bool {
        gatewayType(from: error) == "yala_trial_exhausted"
    }

    /// El error EXACTO que decodifica el SDK cuando el gateway contesta 403 `yala_trial_exhausted` (el sobre de
    /// `gateway/src/errors.ts`). `APIErrorResponse` no tiene init público, así que se construye decodificando.
    /// Lo usan los seams de UI test y los tests unitarios.
    static func trialExhaustedResponse() -> Error {
        let json = #"{"error":{"message":"Ya usaste tu prueba gratuita. Con Yala Pro puedes seguir.","type":"yala_trial_exhausted","param":null,"code":"yala_trial_exhausted"}}"#
        do {
            return try JSONDecoder().decode(APIErrorResponse.self, from: Data(json.utf8))
        } catch {
            return error
        }
    }

    /// Re-mapea un `ChatAssistantError.networkError` que en realidad envuelve un error de cuota
    /// del proxy, al error tipado correcto que el ViewModel del chat ya sabe mostrar.
    static func remap(_ error: ChatAssistantError) -> ChatAssistantError {
        guard case .networkError(let inner) = error else { return error }
        switch gatewayType(from: inner) {
        case "yala_quota_daily": return .dailyLimitReached
        case "yala_quota_burst": return .rateLimited
        default: return error
        }
    }
}
