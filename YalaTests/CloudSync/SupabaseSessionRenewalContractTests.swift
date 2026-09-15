//
//  SupabaseSessionRenewalContractTests.swift
//  YalaTests / CloudSync
//
//  La premisa del SDK sobre la que el canal de Grupos separa «sin conexión» de «sesión caducada»
//  (`GroupsSyncClient.sdkRemovedTheSession`, que lee `CloudAuthService.canRenewSession`), EJECUTADA contra el
//  `AuthClient` real de supabase-swift en vez de leída en su código:
//
//   · un refresh que falla por la RED lanza y deja la sesión guardada;
//   · un 5xx, lo mismo;
//   · las cuatro respuestas terminales del servidor la BORRAN antes de lanzar;
//   · un rechazo que no está en esa lista (`user_banned`) no la borra.
//
//  Si una versión nueva del SDK cambia cualquiera de las cuatro, la clasificación del canal deja de ser verdad
//  en silencio: o vuelve a decir «Tu sesión caducó» a quien solo está sin red, o reintenta para siempre con una
//  sesión muerta. Los casos que borran son además el control de los que conservan: prueban que en este montaje
//  `currentSession` SÍ puede quedarse en `nil`.
//
//  Sin red ni Keychain: `AuthClient` con almacén en memoria y `fetch` inyectado. El SDK reintenta una vez los POST
//  que fallan por red o con un 5xx (`RetryRequestInterceptor`, 1 s de espera), así que esos dos casos tardan un
//  segundo: es el SDK, no el test.
//

import Auth
import Foundation
import Testing

@Suite("supabase-swift · qué hace un refresh fallido con la sesión guardada")
struct SupabaseSessionRenewalContractTests {

    /// Almacén en memoria: el Keychain del simulador no se toca.
    final class MemoryStorage: AuthLocalStorage, @unchecked Sendable {
        private let lock = NSLock()
        private var values: [String: Data] = [:]

        func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
        func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
        func remove(key: String) throws { lock.withLock { values[key] = nil } }
    }

    /// El servidor de auth. Contesta una sesión ya caducada hasta que el caso le diga otra cosa.
    final class AuthServer: @unchecked Sendable {
        enum Reply {
            case expiredSession
            case offline
            case serverError
            /// Rechazo con código. Va con `X-Supabase-Api-Version: 2024-01-01`, que es la cabecera con la que el SDK
            /// lee el `code` del cuerpo.
            case rejected(status: Int, code: String)
        }

        private let lock = NSLock()
        private var reply: Reply = .expiredSession
        private var count = 0

        /// Peticiones recibidas, reintentos del SDK incluidos.
        var requests: Int { lock.withLock { count } }

        func set(_ reply: Reply) { lock.withLock { self.reply = reply } }

        func respond(to request: URLRequest) throws -> (Data, URLResponse) {
            let current = lock.withLock { () -> Reply in
                count += 1
                return reply
            }
            guard let url = request.url else { throw URLError(.badURL) }
            switch current {
            case .offline:
                throw URLError(.notConnectedToInternet)
            case .expiredSession:
                return (Self.expiredSessionJSON, try Self.response(url, status: 200))
            case .serverError:
                return (Data(#"{"message":"boom"}"#.utf8), try Self.response(url, status: 500))
            case .rejected(let status, let code):
                return (Data(#"{"code":"\#(code)","message":"rechazado"}"#.utf8), try Self.response(url, status: status))
            }
        }

        private static func response(_ url: URL, status: Int) throws -> HTTPURLResponse {
            guard let response = HTTPURLResponse(
                url: url, statusCode: status, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json", "X-Supabase-Api-Version": "2024-01-01"])
            else { throw URLError(.badServerResponse) }
            return response
        }

        /// Una sesión que el SDK da por caducada: su `expires_at` es de 2001.
        private static let expiredSessionJSON = Data("""
            {"access_token":"at","token_type":"bearer","expires_in":3600,"expires_at":1000000000,\
            "refresh_token":"rt","user":{"id":"7b5d3c8e-2f41-4c6a-9e0b-1a2b3c4d5e6f","aud":"authenticated",\
            "created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}}
            """.utf8)
    }

    /// Un `AuthClient` con una sesión CADUCADA guardada por el propio SDK: un refresh que contestó 200.
    private func clientWithExpiredSession() async throws -> (AuthClient, AuthServer) {
        let server = AuthServer()
        let url = try #require(URL(string: "https://auth.invalid/auth/v1"))
        let client = AuthClient(configuration: AuthClient.Configuration(
            url: url,
            localStorage: MemoryStorage(),
            fetch: { try server.respond(to: $0) },
            autoRefreshToken: false))
        _ = try await client.refreshSession(refreshToken: "rt-alta")
        try #require(client.currentSession != nil, "el alta no dejó la sesión guardada: el caso no mediría nada")
        return (client, server)
    }

    @Test func offline_keepsTheStoredSession() async throws {
        let (client, server) = try await clientWithExpiredSession()
        server.set(.offline)

        await #expect(throws: (any Error).self) { _ = try await client.session }

        #expect(server.requests > 1, "el refresh ni se intentó: el caso no mide el SDK")
        #expect(client.currentSession != nil, """
            Sin red, el SDK borró la sesión: `canRenewSession` ya no separa «sin conexión» de «sesión caducada», y el \
            canal de Grupos volvería a decir «Tu sesión caducó» a quien solo está sin red.
            """)
    }

    @Test func serverError_keepsTheStoredSession() async throws {
        let (client, server) = try await clientWithExpiredSession()
        server.set(.serverError)

        await #expect(throws: (any Error).self) { _ = try await client.session }

        #expect(server.requests > 1, "el refresh ni se intentó: el caso no mide el SDK")
        #expect(client.currentSession != nil, "un 5xx del servidor de auth borró la sesión guardada")
    }

    @Test(arguments: ["session_not_found", "session_expired", "refresh_token_not_found", "refresh_token_already_used"])
    func terminalRejection_removesTheStoredSession(code: String) async throws {
        let (client, server) = try await clientWithExpiredSession()
        server.set(.rejected(status: 400, code: code))

        await #expect(throws: (any Error).self) { _ = try await client.session }

        #expect(server.requests > 1, "el refresh ni se intentó: el caso no mide el SDK")
        #expect(client.currentSession == nil, """
            «\(code)» ya no borra la sesión: el canal de Grupos leería pasajera una sesión muerta y reintentaría para \
            siempre en vez de pedir volver a entrar.
            """)
    }

    @Test func rejectionOutsideTheList_keepsTheStoredSession() async throws {
        let (client, server) = try await clientWithExpiredSession()
        server.set(.rejected(status: 403, code: "user_banned"))

        await #expect(throws: (any Error).self) { _ = try await client.session }

        #expect(server.requests > 1, "el refresh ni se intentó: el caso no mide el SDK")
        #expect(client.currentSession != nil, """
            Un rechazo fuera de los cuatro códigos terminales borró la sesión: la lista del SDK cambió y el docblock de \
            `GroupsSyncClient.sdkRemovedTheSession` ya no la describe.
            """)
    }
}
