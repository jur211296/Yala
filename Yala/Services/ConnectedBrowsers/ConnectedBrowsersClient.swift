//
//  ConnectedBrowsersClient.swift
//  Yala
//
//  «Navegadores conectados» (Yala web, lote 1): las sesiones de Yala web abiertas con la cuenta, contra el Worker de la
//  web (`webapp/src/worker/app.ts`, rutas `/api/dispositivo/*`):
//    - `GET  /api/dispositivo/sesiones`               → la lista.
//    - `POST /api/dispositivo/sesiones/cerrar`        → `{id}`: cierra una.
//    - `POST /api/dispositivo/sesiones/cerrar-todas`  → cierra todas.
//    - `GET  /api/dispositivo/vincular?codigo=`        → lee un código QR de la web (lote 2): qué navegador lo pidió.
//    - `POST /api/dispositivo/vincular`                → `{codigo}`: lo aprueba, tras Face ID (lote 2).
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

/// Lo que la web cuenta del navegador que pidió un código QR (`qrPeek` en `webapp/src/worker/app.ts`).
struct WebLinkRequest: Decodable, Equatable, Sendable {
    let codigo: String
    let navegador: String
    let sistema: String
    let ciudad: String?
    /// Epoch en segundos.
    let creada: Double
    let expira: Double
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

    /// Lee un código QR de la web: desde ahí, solo esta cuenta puede aprobarlo. `rejected(404)` = caducado o ajeno.
    func peekLink(code: String) async throws -> WebLinkRequest {
        let data = try await send(method: "GET", path: "api/dispositivo/vincular", body: nil, query: [URLQueryItem(name: "codigo", value: code)])
        do {
            return try JSONDecoder().decode(WebLinkRequest.self, from: data)
        } catch {
            #if DEBUG
            print("ConnectedBrowsersClient: Error: \(error)")
            #endif
            throw ConnectedBrowsersClientError.transient(status: -1)
        }
    }

    /// Aprueba el código: ese navegador entra en Yala web. `rejected(404)` = caducado; `rejected(409)` = sin la nube.
    func approveLink(code: String) async throws {
        _ = try await send(method: "POST", path: "api/dispositivo/vincular", body: ["codigo": code])
    }

    func close(id: String) async throws {
        _ = try await send(method: "POST", path: "api/dispositivo/sesiones/cerrar", body: ["id": id])
    }

    func closeAll() async throws {
        _ = try await send(method: "POST", path: "api/dispositivo/sesiones/cerrar-todas", body: [:])
    }

    private func send(method: String, path: String, body: [String: Any]?, query: [URLQueryItem] = []) async throws -> Data {
        guard let baseURL else { throw ConnectedBrowsersClientError.unavailable }
        guard let token = await tokenProvider(), !token.isEmpty else { throw ConnectedBrowsersClientError.sessionExpired }
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems = query
            if let withQuery = components.url { url = withQuery }
        }
        var request = URLRequest(url: url)
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
