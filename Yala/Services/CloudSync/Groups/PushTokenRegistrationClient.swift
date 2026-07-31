//
//  PushTokenRegistrationClient.swift
//  Yala
//
//  Cliente HTTP mínimo del registro/desregistro del device token APNs contra el gateway del canal
//  Grupos → backend (incremento G8-2, DARK detrás de `CloudSyncFlags.groupsBackendEnabled`). Molde de red
//  REDUCIDO de `GroupsMembershipClient` (init inyectable: baseURL/tokenProvider/attestProvider/urlSession):
//    - `POST /push/register`   body `{device_token, platform}` — upsert idempotente server-side.
//    - `POST /push/unregister` body `{device_token}`           — best-effort (lo llama el seam de sign-out).
//
//  SIN retry loop propio: el re-registro por boot (`PushTokenRegistrar.attemptUpload` en `AppBootstrapper`)
//  ES el retry, y auto-sana rotaciones del token por el OS. CERO logging de token/PII; logs bajo `#if DEBUG`.
//

import Foundation
import OSLog

// MARK: - Errores tipados (mínimos)

/// Error del registro de push token. Distingue el fallo de SERVIDOR (permanente, dispara el canario) del
/// TRANSITORIO (offline / 5xx — no canario, reintenta el próximo boot) y de la sesión expirada.
enum PushTokenRegistrationError: Error, Equatable {
    /// 401, o token de sesión nil/vacío (sin request). No es un fallo del token de push per se.
    case sessionExpired
    /// 4xx (≠ 401): el server RECHAZÓ el registro de forma permanente. Canario `groupPushTokenRegisterFailed`.
    /// `status == -2` = el body no serializó (defensivo — nunca ocurre con `device_token`/`platform` string).
    case serverRejected(status: Int)
    /// 5xx / transporte / respuesta no-HTTP. `status == -1` = error de transporte/no-HTTP (offline).
    case transient(status: Int)
}

// MARK: - Cliente

@MainActor
final class PushTokenRegistrationClient {

    private let baseURL: URL
    private let tokenProvider: @MainActor () async -> String?
    private let attestProvider: @MainActor () async -> String?
    private let urlSession: SyncHTTPSession
    private let logger = Logger(subsystem: "com.yala.app", category: "PushRegister")

    /// El default `{ nil }` de `attestProvider` es **SOLO PARA TESTS**: sus dos rutas (`/push/register`,
    /// `/push/unregister`) pasan por `requireUserAndAttest` (`gateway/src/push/register.ts:24,64`, que
    /// REUSA la guard de `groups/routes.ts`). Producción DEBE pasar `AttestSessionProvider.live`.
    /// Pinneado por `AttestWiringTests` — el compilador no lo comprueba.
    init(
        baseURL: URL = ProxyConfig.baseURL,
        tokenProvider: @escaping @MainActor () async -> String? = { await CloudAuthService.shared.accessToken() },
        attestProvider: @escaping @MainActor () async -> String? = { nil },
        urlSession: SyncHTTPSession = URLSession.shared
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.attestProvider = attestProvider
        self.urlSession = urlSession
    }

    /// Registra (upsert) el `deviceToken` de este device para la sesión viva. `platform` = `ios-sandbox`
    /// (Debug/dev) o `ios-prod` (Release), aproximación al `aps-environment` del provisioning.
    func register(deviceToken: String, platform: String) async throws {
        try await post(path: "push/register", body: ["device_token": deviceToken, "platform": platform])
    }

    /// Desregistra el par (sesión, `deviceToken`) del backend. Lo invoca el seam de sign-out (best-effort).
    func unregister(deviceToken: String) async throws {
        try await post(path: "push/unregister", body: ["device_token": deviceToken])
    }

    // MARK: - Núcleo de red

    private func post(path: String, body: [String: Any]) async throws {
        guard let token = await tokenProvider(), !token.isEmpty else {
            throw PushTokenRegistrationError.sessionExpired
        }

        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let attest = await attestProvider(), !attest.isEmpty {
            request.setValue("Bearer \(attest)", forHTTPHeaderField: "X-Yala-Attest-Session")
        }
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        } catch {
            #if DEBUG
            logger.error("PushRegister: serializar body de \(path, privacy: .public) falló: \(error)")
            #endif
            throw PushTokenRegistrationError.serverRejected(status: -2)
        }

        let response: URLResponse
        do {
            (_, response) = try await urlSession.data(for: request)
        } catch {
            throw PushTokenRegistrationError.transient(status: -1)
        }
        guard let http = response as? HTTPURLResponse else {
            throw PushTokenRegistrationError.transient(status: -1)
        }

        switch http.statusCode {
        case 200, 201, 204:
            return
        case 401:
            throw PushTokenRegistrationError.sessionExpired
        case 400...499:
            throw PushTokenRegistrationError.serverRejected(status: http.statusCode)
        default:
            throw PushTokenRegistrationError.transient(status: http.statusCode)
        }
    }
}
