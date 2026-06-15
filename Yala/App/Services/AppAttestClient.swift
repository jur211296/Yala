//
//  AppAttestClient.swift
//  Yala
//
//  Cliente de App Attest: prueba que el request viene de la app legítima en un device genuino,
//  obtiene un token de sesión corto del gateway y lo refresca. El token se adjunta como Bearer en
//  cada llamada al proxy (ProxyClientFactory). Reemplaza la API key embebida en el cliente.
//
//  - actor: serializa el refresh (single-flight) → una sola assertion en vuelo (el counter de App
//    Attest debe crecer monotónicamente; varias en paralelo se rechazarían).
//  - Recuperación: si el server no conoce la key (reinstall / reset), re-registra y reintenta.
//  - Simulador / DEBUG: App Attest no corre en simulador → usa el bypass de dev (staging) si está
//    configurado el secret; si no, la IA queda deshabilitada (degradación, sin crash).
//

import CryptoKit
import DeviceCheck
import Foundation

enum AppAttestError: Error {
    case unavailable // App Attest no soportado y sin bypass configurado
    case unknownKey // el gateway no reconoce la key → re-registrar
    case server(String) // error tipado del gateway (error.type)
    case network(Error)
}

@MainActor
final class AppAttestClient {
    static let shared = AppAttestClient()
    private init() {}

    private static let keyIdKeychainKey = "appattest.keyId"
    /// Margen para refrescar antes de la expiración real del token.
    private static let refreshMargin: TimeInterval = 30

    private var cached: (token: String, expiry: Date)?
    private var refreshTask: Task<String, Error>?

    // MARK: - API pública

    /// Token de sesión vigente (refresca si expiró). Single-flight ante llamadas concurrentes.
    func currentSessionToken() async throws -> String {
        if let cached, cached.expiry > Date.now.addingTimeInterval(Self.refreshMargin) {
            return cached.token
        }
        if let refreshTask {
            return try await refreshTask.value
        }
        let task = Task<String, Error> { try await self.performRefresh() }
        refreshTask = task
        do {
            let token = try await task.value
            refreshTask = nil
            return token
        } catch {
            refreshTask = nil
            throw error
        }
    }

    /// Calienta el token en background (tras el consent de IA / al launch si ya hay Pro), para que
    /// el primer uso no pague la latencia de attestación. Errores se tragan (best-effort).
    func ensureRegistered() async {
        do {
            _ = try await currentSessionToken()
        } catch {
            #if DEBUG
            print("AppAttestClient: ensureRegistered falló: \(error)")
            #endif
        }
    }

    // MARK: - Refresh

    private func performRefresh() async throws -> String {
        let service = DCAppAttestService.shared
        guard service.isSupported else {
            return try await devTokenOrThrow()
        }
        if let keyId = KeychainService.getString(forKey: Self.keyIdKeychainKey) {
            do {
                return try await runAssert(service: service, keyId: keyId)
            } catch AppAttestError.unknownKey {
                return try await runRegister(service: service)
            }
        }
        return try await runRegister(service: service)
    }

    private func runRegister(service: DCAppAttestService) async throws -> String {
        let keyId = try await service.generateKey()
        let challenge = try await fetchChallenge()
        let clientDataHash = Data(SHA256.hash(data: Data(challenge.utf8)))
        let attestation = try await service.attestKey(keyId, clientDataHash: clientDataHash)
        let storeKitJWS = await StoreKitManager.shared.fetchActiveTransactionJWS()
        let resp: SessionResponse = try await postJSON(
            "v1/attest/register",
            body: [
                "keyId": keyId,
                "attestation": attestation.base64EncodedString(),
                "challenge": challenge,
                "storeKitJWS": storeKitJWS,
            ],
        )
        KeychainService.setString(keyId, forKey: Self.keyIdKeychainKey)
        return cache(resp)
    }

    private func runAssert(service: DCAppAttestService, keyId: String) async throws -> String {
        let challenge = try await fetchChallenge()
        let clientDataHash = Data(SHA256.hash(data: Data(challenge.utf8)))
        let assertion = try await service.generateAssertion(keyId, clientDataHash: clientDataHash)
        let storeKitJWS = await StoreKitManager.shared.fetchActiveTransactionJWS()
        let resp: SessionResponse = try await postJSON(
            "v1/attest/assert",
            body: [
                "keyId": keyId,
                "assertion": assertion.base64EncodedString(),
                "challenge": challenge,
                "storeKitJWS": storeKitJWS,
            ],
        )
        return cache(resp)
    }

    private func devTokenOrThrow() async throws -> String {
        #if DEBUG
        let secret = ProxyConfig.devSharedSecret
        guard !secret.isEmpty else { throw AppAttestError.unavailable }
        let resp: SessionResponse = try await postJSON(
            "v1/attest/dev",
            body: [:],
            headers: ["X-Yala-Dev-Secret": secret, "X-Yala-Dev-Tier": "pro"],
        )
        return cache(resp)
        #else
        throw AppAttestError.unavailable
        #endif
    }

    private func fetchChallenge() async throws -> String {
        let resp: ChallengeResponse = try await postJSON("v1/attest/challenge", body: [:])
        return resp.challenge
    }

    private func cache(_ resp: SessionResponse) -> String {
        cached = (resp.sessionToken, Date(timeIntervalSince1970: resp.expMs / 1000))
        return resp.sessionToken
    }

    // MARK: - Red

    private func postJSON<T: Decodable>(
        _ path: String,
        body: [String: String?],
        headers: [String: String] = [:],
    ) async throws -> T {
        var request = URLRequest(url: ProxyConfig.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        do {
            request.httpBody = try JSONEncoder().encode(body.compactMapValues { $0 })
        } catch {
            throw AppAttestError.server("encode")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AppAttestError.network(error)
        }

        guard let http = response as? HTTPURLResponse else { throw AppAttestError.unavailable }
        guard http.statusCode == 200 else {
            // Best-effort: leer el `error.type` del envelope OpenAI-compatible del gateway.
            let type = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error.type
            if type == "yala_attest_unknown_key" { throw AppAttestError.unknownKey }
            throw AppAttestError.server(type ?? "http_\(http.statusCode)")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AppAttestError.server("decode")
        }
    }
}

// MARK: - Modelos de respuesta

private struct SessionResponse: Decodable {
    let sessionToken: String
    let expMs: Double
    let tier: String
}

private struct ChallengeResponse: Decodable {
    let challenge: String
}

private struct ErrorEnvelope: Decodable {
    struct Payload: Decodable {
        let type: String
        let message: String
    }
    let error: Payload
}
