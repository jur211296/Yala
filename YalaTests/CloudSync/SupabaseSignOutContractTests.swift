//
//  SupabaseSignOutContractTests.swift
//  YalaTests / CloudSync
//
//  Las premisas del SDK sobre las que se escribe la postcondición de `CloudAuthService.signOut()` (ticket
//  `detach-does-not-verify-the-cloud-session-actually-closed`), EJECUTADAS contra el `AuthClient` real de
//  supabase-swift en vez de leídas en su código:
//
//   · sin red, `signOut(scope: .local)` LANZA y la sesión ya no está: el SDK la borra antes de hablar con el servidor;
//   · si el almacén no la deja borrar, `signOut` NO lanza y la sesión SIGUE: el SDK traga ese error;
//   · si el almacén no se deja LEER, `currentSession` dice `nil` aunque la sesión esté guardada.
//
//  Las tres juntas son el porqué de que la postcondición no se lea del resultado de la llamada ni de `currentSession`
//  a secas, sino releyendo el llavero y fallando cerrado (`CloudAuthService.sessionIsGone`). Si una versión nueva del
//  SDK cambia cualquiera, conviene volver a mirar ese testigo. Molde y andamio de `SupabaseSessionRenewalContractTests`.
//

import Auth
import Foundation
import Testing

@Suite("supabase-swift · qué deja en el almacén un signOut")
struct SupabaseSignOutContractTests {

    private typealias AuthServer = SupabaseSessionRenewalContractTests.AuthServer

    /// Almacén en memoria que puede negarse a borrar o a leer, como un llavero que falla.
    final class FaultyStorage: AuthLocalStorage, @unchecked Sendable {
        struct Refused: Error {}

        private let lock = NSLock()
        private var values: [String: Data] = [:]
        private var refuseRemove = false
        private var refuseRetrieve = false

        func refuse(remove: Bool = false, retrieve: Bool = false) {
            lock.withLock { refuseRemove = remove; refuseRetrieve = retrieve }
        }

        /// Lo que hay guardado, sin pasar por el SDK ni por la negativa a leer.
        var storedCount: Int { lock.withLock { values.count } }

        func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
        func retrieve(key: String) throws -> Data? {
            try lock.withLock {
                if refuseRetrieve { throw Refused() }
                return values[key]
            }
        }
        func remove(key: String) throws {
            try lock.withLock {
                if refuseRemove { throw Refused() }
                values[key] = nil
            }
        }
    }

    /// Un `AuthClient` con una sesión guardada por el propio SDK (un refresh que contestó 200).
    private func clientWithSession() async throws -> (AuthClient, AuthServer, FaultyStorage) {
        let server = AuthServer()
        let storage = FaultyStorage()
        let url = try #require(URL(string: "https://auth.invalid/auth/v1"))
        let client = AuthClient(configuration: AuthClient.Configuration(
            url: url,
            localStorage: storage,
            fetch: { try server.respond(to: $0) },
            autoRefreshToken: false))
        _ = try await client.refreshSession(refreshToken: "rt-alta")
        try #require(client.currentSession != nil, "el alta no dejó la sesión guardada: el caso no mediría nada")
        return (client, server, storage)
    }

    @Test func offline_signOutThrows_butTheSessionIsGone() async throws {
        let (client, server, storage) = try await clientWithSession()
        server.set(.offline)

        await #expect(throws: (any Error).self) { try await client.signOut(scope: .local) }

        #expect(client.currentSession == nil && storage.storedCount == 0, """
            Sin red, el SDK ya no borra la sesión antes de hablar con el servidor. Entonces el `catch` de \
            `CloudAuthService.signOut()` sí significa «la sesión sigue», y la postcondición tiene que mirarlo.
            """)
    }

    @Test func refusedRemove_signOutDoesNotThrow_andTheSessionStays() async throws {
        let (client, _, storage) = try await clientWithSession()
        storage.refuse(remove: true)

        try await client.signOut(scope: .local)

        #expect(client.currentSession != nil && storage.storedCount == 1, """
            Con el almacén negándose a borrar, la sesión ya no sobrevive al signOut. Esta es la vía por la que el \
            desasociar cruzaba el punto de no retorno con la sesión viva; si el SDK dejó de tragar el error, puede que \
            ya lance, y el testigo sigue siendo correcto pero el caso deja de representar un teléfono real.
            """)
    }

    @Test func refusedRetrieve_currentSessionReadsNil_withTheSessionStored() async throws {
        let (client, _, storage) = try await clientWithSession()
        storage.refuse(retrieve: true)

        #expect(client.currentSession == nil, """
            Con el almacén negándose a leer, `currentSession` ya no dice `nil`. Si el SDK dejó de tragar el error, el \
            testigo de `CloudAuthService.signOut()` podría volver a leerse solo de ahí.
            """)
        #expect(storage.storedCount == 1, "la sesión no estaba guardada: el caso no mide nada")
    }
}
