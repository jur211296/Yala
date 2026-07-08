//
//  CloudAccountClient.swift
//  Yala
//
//  Cliente del gate de identidad del Modo Nube (§f.1): `POST /account/claim` (reserva ATÓMICA de la
//  cuenta) + `GET /account/exists` (hint barato de encaminamiento). Corre INMEDIATAMENTE tras un
//  `signInWithIdToken` exitoso y ANTES de cualquier `save()` de onboarding — REGLA C4 (el consumidor
//  UI real es I14; aquí lo ejercita el panel DEBUG).
//
//  WIRE REAL (anclado a `gateway/src/sync/account.ts` + `gateway/test/account.goldens.test.ts`):
//   - Request:  `POST /account/claim`  body `{ "device_id": <string>, "provider": <string> }`.
//   - Response: `200 { "state": "created" | "existing_stable" | "claiming_in_progress", "profile"?: {…} }`.
//   - Auth: SOLO el JWT de usuario (`Authorization: Bearer <supabase jwt>`). `/account/*` NO exige App
//     Attest (precede al `/attest/bind` — el device aún no vinculó su keyId). Confirmado en el handler.
//   - Errores: envelope OpenAI-compatible `{ "error": { message, type, param, code } }` con status
//     (401 JWT ausente/inválido, 400 body inválido, 502 upstream). El panel los muestra EN CLARO.
//
//  Cero silencios: la red se traduce a un `ClaimOutcome` estructurado (estilo `PushOutcome`); NUNCA
//  lanza por red. Sin PII en logs (jamás el JWT ni el body de perfil).
//

import Foundation

/// Resultado ESTRUCTURADO de `POST /account/claim`. `detail` en los casos de error lleva `status + body`
/// del Worker (para el panel DEBUG) — nunca el JWT.
enum ClaimOutcome: Equatable {
    /// 200 OK con un `state` válido → decodificado a `ClaimState`.
    case success(AccountClaimDecision.ClaimState)
    /// 401: JWT ausente/inválido/expirado → re-firmar.
    case sessionExpired(detail: String)
    /// 403: autenticado pero prohibido (cuenta suspendida) — defensivo (`/account/*` no lo emite hoy).
    case accountUnavailable(detail: String)
    /// 5xx / red caída / respuesta no decodificable / status inesperado → reintentar.
    case transient(detail: String)
}

/// Resultado de `GET /account/exists`.
enum ExistsOutcome: Equatable {
    case exists(Bool)
    case sessionExpired(detail: String)
    case transient(detail: String)
}

@MainActor
final class CloudAccountClient {

    private let baseURL: URL
    private let urlSession: SyncHTTPSession

    /// - Parameters:
    ///   - baseURL: gateway (default `ProxyConfig.baseURL`, per-scheme).
    ///   - urlSession: inyectable para tests (reusa `SyncHTTPSession` del push client).
    init(baseURL: URL = ProxyConfig.baseURL, urlSession: SyncHTTPSession = URLSession.shared) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    // MARK: - Decoder puro (testeable sin red)

    /// Mapea el `state` del wire (§f.1) a `AccountClaimDecision.ClaimState`. `nil` = string desconocido.
    static func decodeState(_ raw: String) -> AccountClaimDecision.ClaimState? {
        switch raw {
        case "created": return .created
        case "existing_stable": return .existingStable
        case "claiming_in_progress": return .claimingInProgress
        default: return nil
        }
    }

    private struct ClaimResponse: Decodable {
        let state: String?
    }

    private struct ExistsResponse: Decodable {
        let exists: Bool
    }

    // MARK: - POST /account/claim

    /// Reserva atómica de la cuenta. `provider` = "apple" para Sign in with Apple. NO envía header de
    /// attest (el gate de cuenta no lo exige). NUNCA lanza — traduce todo a `ClaimOutcome`.
    func claim(jwt: String, deviceID: String, provider: String) async -> ClaimOutcome {
        var request = URLRequest(url: baseURL.appendingPathComponent("account/claim"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        do {
            request.httpBody = try JSONSerialization.data(
                withJSONObject: ["device_id": deviceID, "provider": provider]
            )
        } catch {
            return .transient(detail: "encode failed")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            return .transient(detail: "network: \(error.localizedDescription)")
        }
        guard let http = response as? HTTPURLResponse else {
            return .transient(detail: "non-HTTP response")
        }

        switch http.statusCode {
        case 200:
            guard
                let decoded = try? JSONDecoder().decode(ClaimResponse.self, from: data),
                let rawState = decoded.state,
                let state = Self.decodeState(rawState)
            else {
                return .transient(detail: "HTTP 200 undecodable: \(Self.bodyString(data))")
            }
            return .success(state)
        case 401:
            return .sessionExpired(detail: "HTTP 401: \(Self.bodyString(data))")
        case 403:
            return .accountUnavailable(detail: "HTTP 403: \(Self.bodyString(data))")
        default:
            return .transient(detail: "HTTP \(http.statusCode): \(Self.bodyString(data))")
        }
    }

    // MARK: - GET /account/exists

    /// Hint de encaminamiento barato (§f.1) — NO la garantía anti-doble-siembra (esa la da `claim`).
    func exists(jwt: String) async -> ExistsOutcome {
        var request = URLRequest(url: baseURL.appendingPathComponent("account/exists"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            return .transient(detail: "network: \(error.localizedDescription)")
        }
        guard let http = response as? HTTPURLResponse else {
            return .transient(detail: "non-HTTP response")
        }
        switch http.statusCode {
        case 200:
            guard let decoded = try? JSONDecoder().decode(ExistsResponse.self, from: data) else {
                return .transient(detail: "HTTP 200 undecodable")
            }
            return .exists(decoded.exists)
        case 401:
            return .sessionExpired(detail: "HTTP 401: \(Self.bodyString(data))")
        default:
            return .transient(detail: "HTTP \(http.statusCode): \(Self.bodyString(data))")
        }
    }

    // MARK: - Helpers

    /// Cuerpo como string acotado para diagnóstico del panel (el body de error del Worker es el envelope
    /// `{error:{type,message}}`, sin PII). Se recorta para no volcar payloads grandes.
    private static func bodyString(_ data: Data) -> String {
        let s = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        return s.count > 300 ? String(s.prefix(300)) + "…" : s
    }
}
