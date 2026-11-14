//
//  ConnectedBrowsersClient.swift
//  Yala
//
//  «Navegadores conectados» (Yala web, lote 1): las sesiones de Yala web abiertas con la cuenta, contra el Worker de la
//  web (`webapp/src/worker/app.ts`, rutas `/api/dispositivo/*`):
//    - `GET  /api/dispositivo/sesiones`               → la lista.
//    - `POST /api/dispositivo/sesiones/cerrar`        → `{id}`: cierra una.
//    - `POST /api/dispositivo/sesiones/cerrar-todas`  → cierra todas.
//
//  Se identifica con el token de la sesión de la nube (`CloudAuthService`), sin App Attest: la web solo deja ver y cerrar
//  las sesiones web PROPIAS (decisión P9 del lote 1). Solo hay web en staging, así que solo Yala Dev la conoce
//  (`ConnectedBrowsersConfig.baseURL`); en producción no hay URL y la fila no sale. Logs bajo `#if DEBUG`.
//

import Foundation

nonisolated enum ConnectedBrowsersConfig {
    /// La web de staging, la única que existe en 2.3. `nil` fuera de Yala Dev: no hay web de producción todavía.
    static var baseURL: URL? {
        #if DEV_BUILD
        return URL(string: "https://yala-web-staging.misty-surf-6866.workers.dev")
        #else
        return nil
        #endif
    }

    static var isAvailable: Bool { baseURL != nil }
}

enum ConnectedBrowsersClientError: Error, Equatable {
    /// Sin token, o la web no lo aceptó (401).
    case sessionExpired
    /// 4xx distinto de 401. `-2` = el cuerpo no serializó.
    case rejected(status: Int)
    /// 5xx, transporte o respuesta ilegible. `-1` = sin respuesta HTTP.
    case transient(status: Int)
    /// No hay web para este build.
    case unavailable
}

/// Una sesión de Yala web, como la cuenta la web (`PublicSession` en `webapp/src/worker/sessions.ts`).
struct WebSession: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let navegador: String
    let sistema: String
    let ciudad: String?
    /// Epoch en segundos.
    let ultimoUso: Double
    let equipoCompartido: Bool
}

@MainActor
final class ConnectedBrowsersClient {
    private let baseURL: URL?
    private let tokenProvider: @MainActor () async -> String?
    private let urlSession: SyncHTTPSession

    init(
        baseURL: URL? = ConnectedBrowsersConfig.baseURL,
        tokenProvider: @escaping @MainActor () async -> String? = { await CloudAuthService.shared.accessToken() },
        urlSession: SyncHTTPSession = URLSession.shared
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.urlSession = urlSession
    }

    func sessions() async throws -> [WebSession] {
        struct Envelope: Decodable { let sesiones: [WebSession] }
        let data = try await send(method: "GET", path: "api/dispositivo/sesiones", body: nil)
        do {
            return try JSONDecoder().decode(Envelope.self, from: data).sesiones
        } catch {
            #if DEBUG
            print("ConnectedBrowsersClient: Error: \(error)")
            #endif
            throw ConnectedBrowsersClientError.transient(status: -1)
        }
    }

    func close(id: String) async throws {
        _ = try await send(method: "POST", path: "api/dispositivo/sesiones/cerrar", body: ["id": id])
    }

    func closeAll() async throws {
        _ = try await send(method: "POST", path: "api/dispositivo/sesiones/cerrar-todas", body: [:])
    }

    private func send(method: String, path: String, body: [String: Any]?) async throws -> Data {
        guard let baseURL else { throw ConnectedBrowsersClientError.unavailable }
        guard let token = await tokenProvider(), !token.isEmpty else { throw ConnectedBrowsersClientError.sessionExpired }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
            } catch {
                #if DEBUG
                print("ConnectedBrowsersClient: Error: \(error)")
                #endif
                throw ConnectedBrowsersClientError.rejected(status: -2)
            }
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw ConnectedBrowsersClientError.transient(status: -1)
        }
        guard let http = response as? HTTPURLResponse else { throw ConnectedBrowsersClientError.transient(status: -1) }
        switch http.statusCode {
        case 200...299: return data
        case 401: throw ConnectedBrowsersClientError.sessionExpired
        case 400...499: throw ConnectedBrowsersClientError.rejected(status: http.statusCode)
        default: throw ConnectedBrowsersClientError.transient(status: http.statusCode)
        }
    }
}
