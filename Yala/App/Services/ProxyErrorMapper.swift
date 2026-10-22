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

    /// ¿El gateway frenó la petición por RÁFAGA (429 `yala_quota_burst`)? Se cura sola en menos de un minuto. Hasta el
    /// arreglo del gateway del 2026-10-21 esa ráfaga la llenaba también el tráfico de sincronización del teléfono, y la
    /// primera foto tras instalar salía con el texto de «falló la lectura» (card vv0k del QA guiado del 19-oct).
    static func isBurstLimited(_ error: Error) -> Bool {
        gatewayType(from: error) == "yala_quota_burst"
    }

    /// ¿El gateway dice que se acabó el cupo de HOY (429 `yala_quota_daily`)? Se repone al cambiar de día (UTC).
    static func isDailyLimitReached(_ error: Error) -> Bool {
        gatewayType(from: error) == "yala_quota_daily"
    }

    /// El error EXACTO que decodifica el SDK cuando el gateway contesta 429 con `type` (`yala_quota_burst` o
    /// `yala_quota_daily`). Para los tests unitarios y los seams de UI test.
    static func quotaResponse(type: String) -> Error {
        let json = #"{"error":{"message":"Límite de uso alcanzado. Intenta más tarde.","type":"\#(type)","param":null,"code":"\#(type)"}}"#
        do {
            return try JSONDecoder().decode(APIErrorResponse.self, from: Data(json.utf8))
        } catch {
            return error
        }
    }

    /// Qué le pasó a una petición de IA, en el idioma del gateway y sin datos de la persona: el `error.type` del sobre si lo
    /// hay, o la familia del error local. Va en el detalle del canario de los fallos de voz y foto.
    static func failureKind(_ error: Error) -> String {
        if let type = gatewayType(from: error) { return type }
        if error is AppAttestError { return "attest" }
        if let urlError = error as? URLError { return "url:\(urlError.code.rawValue)" }
        if error is DecodingError { return "decoding" }
        return "other"
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
