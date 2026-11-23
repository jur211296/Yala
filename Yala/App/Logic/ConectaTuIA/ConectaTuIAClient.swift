//
//  ConectaTuIAClient.swift
//  Yala
//
//  «Conecta tu IA»: qué IA tienen acceso y quitar una, contra el conector de la misma nube del build
//  (`mcp/src/connections.ts`):
//    - `GET    /connections`        → `{ conexiones: [{ id, ia, vuelta, local, conectadaEl }] }`
//    - `DELETE /connections/<id>`   → 204 (404 si ya no está)
//
//  Se identifica con el token de la sesión de la cuenta de Yala (`CloudAuthService`), nunca con el de una IA: el conector
//  rechaza cualquier otro (decisión 3 de Jürgen del 23-nov). Logs bajo `#if DEBUG`.
//

import Foundation

/// Una IA conectada, como la cuenta el conector (`PublicConnection`).
struct AIConnection: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    /// «Claude», «ChatGPT», «Grok»; `nil` si el conector no reconoce su vuelta.
    let ia: String?
    /// El dominio al que vuelve el acceso (`claude.ai`), o `nil`.
    let vuelta: String?
    /// La vuelta es de la computadora (Claude Code, Claude Desktop).
    let local: Bool
    /// Epoch en segundos.
    let conectadaEl: Double
}

enum ConectaTuIAClientError: Error, Equatable {
    /// Sin token, o el conector no lo aceptó (401).
    case sessionExpired
    /// 404 al quitar: ya no estaba.
    case notFound
    /// Otro 4xx.
    case rejected(status: Int)
    /// 5xx, transporte o respuesta ilegible. `-1` = sin respuesta HTTP.
    case transient(status: Int)
    /// No hay conector para este build.
    case unavailable
}

@MainActor
final class ConectaTuIAClient {
    private let baseURL: URL?
    private let tokenProvider: @MainActor () async -> String?
    private let urlSession: SyncHTTPSession

    nonisolated static var defaultBaseURL: URL? {
        #if DEV_BUILD
        return ConectaTuIALogic.baseURL(isDevBuild: true)
        #else
        return ConectaTuIALogic.baseURL(isDevBuild: false)
        #endif
    }

    init(
        baseURL: URL? = ConectaTuIAClient.defaultBaseURL,
        tokenProvider: @escaping @MainActor () async -> String? = { await CloudAuthService.shared.accessToken() },
        urlSession: SyncHTTPSession = URLSession.shared
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.urlSession = urlSession
    }

    func connections() async throws -> [AIConnection] {
        struct Envelope: Decodable { let conexiones: [AIConnection] }
        let data = try await send(method: "GET", path: "connections")
        do {
            return try JSONDecoder().decode(Envelope.self, from: data).conexiones
        } catch {
            #if DEBUG
            print("ConectaTuIAClient: Error: \(error)")
            #endif
            throw ConectaTuIAClientError.transient(status: -1)
        }
    }

    func disconnect(id: String) async throws {
        // El id lo dio el conector; aun así, solo lo que cabe en un segmento de ruta.
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard !id.isEmpty, id.unicodeScalars.allSatisfy(allowed.contains) else { throw ConectaTuIAClientError.notFound }
        _ = try await send(method: "DELETE", path: "connections/\(id)")
    }

    private func send(method: String, path: String) async throws -> Data {
        guard let baseURL else { throw ConectaTuIAClientError.unavailable }
        guard let token = await tokenProvider(), !token.isEmpty else { throw ConectaTuIAClientError.sessionExpired }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            #if DEBUG
            print("ConectaTuIAClient: Error: \(error)")
            #endif
            throw ConectaTuIAClientError.transient(status: -1)
        }
        guard let http = response as? HTTPURLResponse else { throw ConectaTuIAClientError.transient(status: -1) }
        switch http.statusCode {
        case 200...299: return data
        case 401: throw ConectaTuIAClientError.sessionExpired
        case 404: throw ConectaTuIAClientError.notFound
        case 400...499: throw ConectaTuIAClientError.rejected(status: http.statusCode)
        default: throw ConectaTuIAClientError.transient(status: http.statusCode)
        }
    }
}
