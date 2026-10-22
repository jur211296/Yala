//
//  GroupICloudIdentitySeedTests.swift
//  YalaTests
//
//  Tests del ESCRITOR de la identidad iCloud del container de Grupos — `cachedRecordName`, la señal que
//  permite al usuario reconocerse en los `SplitMember` de la era CloudKit (grupo MIGRADO al backend, filas
//  sin `userID`) y, sobre todo, la llave que `join_group(p_legacy_member_key)` necesita para RECLAMAR su
//  fila placeholder del historial (`migrate_group` deja a los members no-owner con `user_id NULL`).
//
//  Por qué existe esta suite (Fase 2 bis): el único escritor de la key `groups_currentUserRecordName` vivía
//  DENTRO de `GroupUserIdentityService.currentUserRecordName()`, el método que hace el fetch a
//  `CKContainer` y que la Fase 3 borra con el transporte. Conservar la propiedad `cachedRecordName` —lo que
//  el plan pedía— no basta: sin escritor, en una instalación fresca (device nuevo, reinstalación, restore)
//  la key queda `nil` PARA SIEMPRE y sus consumidores mueren en silencio.
//
//  Y las tres suites que cubren esos caminos INYECTAN la identidad con `_testSetCachedRecordName(_:)`, así
//  que compila, pasa en verde y falla solo en un device real. ⇒ estas celdas NO inyectan el cache: las dos
//  estructurales miden dónde vive el escritor, y las de comportamiento arrancan con el cache VACÍO
//  (instalación fresca) e inyectan el FETCHER, que es la identidad del device, no el cache.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Identidad iCloud de Grupos · el escritor sobrevive a la Fase 3", .serialized)
struct GroupICloudIdentitySeedTests {

    // MARK: - Entorno

    /// Raíz del repo vía `#filePath` (patrón `CloudKitGroupsSchemaParityTests`: el runner no empaqueta las
    /// fuentes como resources).
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Todas las fuentes de producción, con su ruta relativa al repo.
    private static func productionSources() -> [(path: String, source: String)] {
        let root = repoRoot.appendingPathComponent("Yala")
        guard let walker = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil) else { return [] }
        var out: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let source = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let relative = url.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
            out.append((relative, source))
        }
        return out
    }

    /// La key de `UserDefaults` que respalda `cachedRecordName`. Literal a propósito: el test mide DÓNDE
    /// vive su escritor, así que no puede leerla del símbolo que se está moviendo.
    private static let identityKey = "groups_currentUserRecordName"

    /// Carpetas que el criterio de salida de la Fase 3 vacía de CloudKit
    /// (`grep -r "import CloudKit" Yala/Services/Groups/ Yala/App/Views/Groups/` → 0). Un escritor que viva
    /// ahí se va con el transporte.
    private static let transportDirectories = [
        "Yala/Services/Groups/",
        "Yala/App/Views/Groups/",
    ]

    // MARK: - 1 · Dónde vive el escritor (el defecto medido)

    @Test("El escritor de la identidad iCloud NO vive en el transporte que la Fase 3 borra")
    func identityWriter_livesOutsideTheTransport() throws {
        // Escritor = fichero que conoce la key Y persiste algo con `set(_:forKey:)`. Hoy los dos están en
        // `GroupUserIdentityService.swift`, dentro del método que hace el fetch a CKContainer.
        let writers = Self.productionSources().filter { file in
            file.source.contains(Self.identityKey)
                && file.source.contains("set(")
                && file.source.contains("forKey:")
        }.map(\.path)

        #expect(!writers.isEmpty,
                "La key \(Self.identityKey) no tiene NINGÚN escritor: en instalación fresca queda nil para siempre.")

        for writer in writers {
            let condemned = Self.transportDirectories.first { writer.hasPrefix($0) }
            #expect(condemned == nil,
                    """
                    \(writer) escribe la identidad iCloud de Grupos y vive en \(condemned ?? "?"), \
                    que la Fase 3 vacía. Tras el borrado, `cachedRecordName` se queda sin escritor: en un \
                    device nuevo / reinstalación / restore queda nil y el re-join de un grupo migrado deja \
                    de poder reclamar la fila placeholder del historial (`join_group(p_legacy_member_key)`).
                    """)
        }
    }

    @Test("El seed de identidad del boot no depende del fetch que la Fase 3 borra")
    func bootSeed_doesNotDependOnTheTransportFetch() throws {
        let bootstrap = try #require(
            Self.productionSources().first { $0.path == "Yala/App/AppBootstrapper.swift" },
            "No se pudo leer AppBootstrapper.swift por #filePath")

        #expect(!bootstrap.source.contains("GroupUserIdentityService.shared.currentUserRecordName()"),
                """
                El seed de boot llama a `currentUserRecordName()`, el método que hace el fetch a \
                CKContainer y que la Fase 3 borra. Es el ÚNICO camino que puebla la identidad en cada \
                arranque: si muere con el transporte, ningún otro la escribe. El seed tiene que entrar por \
                el seam del canal nuevo.
                """)
    }

    // MARK: - 2 · El camino de instalación fresca (cache VACÍO, sin inyectar el cache)

    /// Estado de instalación fresca: cache in-memory a `nil` y un store de `UserDefaults` propio y vacío.
    /// Lo que se inyecta es el FETCHER —la identidad del device— nunca el cache: inyectar el cache es
    /// exactamente lo que hacen las tres suites que no cazaron este bug.
    private func withFreshInstall(
        fetcher: @escaping @MainActor () async throws -> String,
        _ body: () async throws -> Void
    ) async throws {
        let previousCache = GroupUserIdentityService.shared.cachedRecordName
        GroupUserIdentityService.shared._testSetCachedRecordName(nil)
        GroupICloudIdentitySeed.defaults = makeIsolatedDefaults(prefix: "icloudidentity")
        GroupICloudIdentitySeed.recordNameFetcher = fetcher
        defer {
            GroupICloudIdentitySeed._testReset()
            GroupUserIdentityService.shared._testSetCachedRecordName(previousCache)
        }
        try await body()
    }

    @Test("Instalación fresca: el seed puebla la identidad y la PERSISTE (el escritor sigue vivo)")
    func freshInstall_seedPopulatesAndPersists() async throws {
        try await withFreshInstall(fetcher: { "_recordNameDelDevice" }) {
            #expect(GroupUserIdentityService.shared.cachedRecordName == nil, "Precondición: device fresco.")

            let seeded = try await GroupICloudIdentitySeed.seedIfNeeded()

            #expect(seeded == "_recordNameDelDevice")
            #expect(GroupUserIdentityService.shared.cachedRecordName == "_recordNameDelDevice",
                    "Sin esto, `legacyMemberKeyForRejoin` no puede reclamar la fila placeholder del historial.")
            #expect(GroupICloudIdentitySeed.persistedRecordName == "_recordNameDelDevice",
                    "Persistir es la mitad que sobrevive al proceso: el próximo boot la lee del disco.")
        }
    }

    @Test("El seed es idempotente: con el cache poblado NO vuelve a salir a CloudKit")
    func seed_isIdempotent_andDoesNotRefetch() async throws {
        var fetches = 0
        try await withFreshInstall(fetcher: { fetches += 1; return "_recordNameDelDevice" }) {
            _ = try await GroupICloudIdentitySeed.seedIfNeeded()
            _ = try await GroupICloudIdentitySeed.seedIfNeeded()
            #expect(fetches == 1, "El boot y el tap de invitación no pueden pagar dos idas a CloudKit.")
        }
    }

    @Test("Sin iCloud el seed NO inventa identidad: el cache se queda vacío y no se persiste nada")
    func seed_withoutICloud_leavesNoIdentity() async throws {
        struct NoAccount: Error {}
        try await withFreshInstall(fetcher: { throw NoAccount() }) {
            await #expect(throws: NoAccount.self) { try await GroupICloudIdentitySeed.seedIfNeeded() }

            #expect(GroupUserIdentityService.shared.cachedRecordName == nil)
            #expect(GroupICloudIdentitySeed.persistedRecordName == nil,
                    "Una identidad en blanco persistida haría que el cache pareciera sembrado.")
        }
        // El best-effort del boot traga el error (la identidad iCloud no es bloqueante) pero no lo silencia.
        try await withFreshInstall(fetcher: { throw NoAccount() }) {
            await GroupICloudIdentitySeed.seedIfNeededBestEffort()
            #expect(GroupUserIdentityService.shared.cachedRecordName == nil)
        }
    }

    @Test("Olvidar la identidad borra el cache Y lo persistido (el par no se desincroniza)")
    func forget_clearsBothHalves() async throws {
        try await withFreshInstall(fetcher: { "_recordNameDelDevice" }) {
            _ = try await GroupICloudIdentitySeed.seedIfNeeded()

            GroupUserIdentityService.shared.clearCache()

            #expect(GroupUserIdentityService.shared.cachedRecordName == nil)
            #expect(GroupICloudIdentitySeed.persistedRecordName == nil,
                    "Si solo se limpiara el cache, el próximo boot resucitaría la identidad del Apple ID que se fue.")
        }
    }

    @Test("La fachada del transporte y el seam nuevo son el MISMO escritor")
    func transportFacade_delegatesToTheSameWriter() async throws {
        var fetches = 0
        try await withFreshInstall(fetcher: { fetches += 1; return "_recordNameDelDevice" }) {
            let viaFacade = try await GroupUserIdentityService.shared.currentUserRecordName()

            #expect(viaFacade == "_recordNameDelDevice")
            #expect(GroupICloudIdentitySeed.persistedRecordName == "_recordNameDelDevice",
                    "La fachada tiene que persistir por el mismo camino, o el comportamiento de hoy cambia.")
            #expect(fetches == 1)
        }
    }
}
