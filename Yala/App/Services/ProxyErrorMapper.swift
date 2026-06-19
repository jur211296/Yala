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
