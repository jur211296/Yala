//
//  AttestWiringTests.swift
//  YalaTests / CloudSync
//
//  El header `X-Yala-Attest-Session` en las rutas del gateway que lo EXIGEN.
//
//  POR QUÉ ESTE FICHERO EXISTE Y POR QUÉ ES SOURCE-SCAN. El 2026-07-31, con el canal de Grupos ya al 100 %
//  en producción, crear un grupo devolvía 401 `yala_attest_required`: los inits de los clients declaran
//  `attestProvider: … = { nil }` y NUEVE construcciones de producción se quedaron con el default. No era un
//  bug de lógica —cada cliente pone el header correctamente cuando su provider devuelve algo— sino de
//  CABLEADO, y el cableado no lo comprueba el compilador: `{ nil }` es un valor perfectamente legal.
//
//  Y no se pudo cazar antes porque **staging corre `ENFORCE = "observe"`** (`gateway/wrangler.toml:32`):
//  ahí el token ausente se cuenta pero NO bloquea, así que el incremento entero se construyó y se validó
//  contra un gateway que no lo exigía. Un test de integración contra staging habría pasado IGUAL de roto.
//  ⇒ la única red posible vive en el repo y es estructural: pinnear, por CONSTRUCCIÓN, que ningún fichero
//  de producción construya uno de estos clients sin pasarle un proveedor.
//
//  Contrato de decisión (leído del gateway, no de la intuición) — la guard del HANDLER es el criterio:
//    · `requireUserAndAttest` ⇒ EXIGE attest bajo `enforce` (401 sin header):
//        POST /groups/rpc/{fn}   `groups/rpc.ts:87-89`      → GroupsMembershipClient
//          (OJO: `:81-83` es la validación del JWT de Supabase, NO el enforcement del attest. Tres
//           docblocks del repo apuntaban ahí, y quien verificara la premisa por cualquiera de ellos
//           podía concluir que la ruta no exige attest. Corregido en C1.)
//        POST /groups/push       `groups/routes.ts:67-73`   → GroupsSyncClient
//        GET  /groups/pull       `groups/routes.ts:67-73`   → GroupsSyncClient
//        GET  /groups/merkle     `groups/routes.ts:67-73`   → GroupsMerkleClient
//        POST /push/register     `push/register.ts:24`      → PushTokenRegistrationClient
//        POST /push/unregister   `push/register.ts:64`      → PushTokenRegistrationClient
//        POST /sync/push · GET /sync/pull · GET /sync/merkle · POST /prefs/push · GET /prefs/pull
//                                `sync/routes.ts:73`        → SyncPush/Pull/Merkle/PrefsSyncClient
//    · `requireUser` ⇒ NO exige (y cablearlo puede romper el alta — son flujos PRE-SESIÓN):
//        /account/claim · /account/exists · /account/migration · /account/siwa/exchange ·
//        /account/entitlement. Por eso `CloudAccountClient` NO está en la lista escaneada: es el único
//        cliente que habla con rutas de las DOS clases, y su default `{ nil }` es correcto en producción.
//        Sus dos métodos que SÍ exigen attest (`deleteAccount`, `siwaRevoke`) los pinnea
//        `CloudAccountClientTests` por comportamiento (header presente/ausente por método).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Cableado de producción (source-scan)

@Suite("App Attest · cableado de producción (source-scan)")
struct AttestWiringTests {

    /// Clientes cuyas rutas EXIGEN attest sin excepción, con el número de construcciones de producción
    /// conocido al escribir el test. El conteo NO es decoración: es el anti-falso-verde. Un escáner roto,
    /// una clase renombrada o un fichero movido harían que el barrido no encontrara nada y la suite pasaría
    /// en verde sin comprobar absolutamente nada — la misma clase de fallo que «Executed 0 tests».
    ///
    /// Si añades o quitas una construcción legítima, ajusta el `expected` a conciencia.
    private static let scanned: [(type: String, expected: Int)] = [
        // Canal de Grupos + push (donde nació el 401 del 2026-07-31).
        // 8 desde C1: `GroupsConsentRegistrar` construye la suya para registrar el consent contra la
        // cuenta (`record_groups_consent` / `groups_consent_state`, los dos bajo la MISMA guard estricta).
        ("GroupsMembershipClient", 8),
        ("GroupsSyncClient", 1),
        ("GroupsMerkleClient", 1),
        ("PushTokenRegistrationClient", 2),
        // Canal PERSONAL. No estaban rotos —sus 7 construcciones ya inyectaban el provider de la sesión—,
        // pero tienen el MISMO default `{ nil }` y sus rutas (`/sync/*`, `/prefs/*`) la misma guard
        // estricta, así que el mismo descuido cabe ahí exactamente igual. Dejarlos fuera sería pinnear
        // medio invariante.
        ("SyncPushClient", 2),
        ("SyncPullClient", 2),
        ("SyncMerkleClient", 2),
        ("PrefsSyncClient", 1),
    ]

    /// Directorios de PRODUCCIÓN. `YalaTests`/`YalaUITests` quedan fuera a propósito: ahí el default
    /// `{ nil }` es lo correcto (un provider vivo llamaría al App Attest REAL —red— en un unit test).
    private static let productionRoots = ["Yala", "YalaWidgets", "YalaShare"]

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Todos los `.swift` bajo los directorios de producción, como (ruta relativa, contenido).
    private static func productionSources() -> [(path: String, text: String)] {
        var out: [(String, String)] = []
        for root in productionRoots {
            let base = repoRoot.appendingPathComponent(root)
            guard let walker = FileManager.default.enumerator(
                at: base, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension == "swift" {
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                out.append((root + "/" + url.path.replacingOccurrences(
                    of: base.path + "/", with: ""), text))
            }
        }
        return out
    }

    /// Quita las líneas que son COMENTARIO ENTERO (`//` tras el indent). Los docblocks de este repo
    /// nombran clases constantemente y sin esto un `GroupsSyncClient(` citado en prosa contaría como
    /// construcción. Los comentarios de final de línea se conservan a propósito: recortar desde el primer
    /// `//` destrozaría los `URL(string: "https://…")`.
    private static func stripWholeLineComments(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Texto completo de cada construcción `Type(...)` del fuente, con los paréntesis balanceados.
    /// Descarta los matches precedidos por un carácter de identificador o por `.` (para no confundir
    /// `MiGroupsSyncClient(` ni `Algo.GroupsSyncClient(` con el tipo buscado).
    private static func constructions(of type: String, in source: String) -> [String] {
        let chars = Array(stripWholeLineComments(source))
        let needle = Array(type + "(")
        var found: [String] = []
        var i = 0

        while i + needle.count <= chars.count {
            guard Array(chars[i..<(i + needle.count)]) == needle else { i += 1; continue }
            if i > 0 {
                let prev = chars[i - 1]
                if prev.isLetter || prev.isNumber || prev == "_" || prev == "." { i += 1; continue }
            }
            // Balancear desde el `(` de apertura, ignorando paréntesis dentro de literales de string.
            var depth = 0
            var inString = false
            var j = i + needle.count - 1
            while j < chars.count {
                let c = chars[j]
                if c == "\"" { inString.toggle() }
                if !inString {
                    if c == "(" { depth += 1 }
                    if c == ")" { depth -= 1; if depth == 0 { break } }
                }
                j += 1
            }
            let end = min(j, chars.count - 1)
            found.append(String(chars[i...end]))
            i = end + 1
        }
        return found
    }

    /// EL test. Toda construcción de producción de un client cuyas rutas exigen App Attest tiene que
    /// llevar un `attestProvider:` explícito. Es lo único que impide que la construcción número diez
    /// nazca con el default `{ nil }` y reviva el 401 — el compilador no dice nada, staging tampoco.
    @Test func everyProductionConstruction_passesAnAttestProvider() {
        let sources = Self.productionSources()
        #expect(!sources.isEmpty, "El barrido no leyó NINGÚN fuente: el test no está comprobando nada.")

        for (type, expected) in Self.scanned {
            var total = 0
            for (path, text) in sources {
                for site in Self.constructions(of: type, in: text) {
                    total += 1
                    #expect(
                        site.contains("attestProvider:"),
                        """
                        \(path): construye `\(type)` SIN `attestProvider:`.
                        Sus rutas pasan por `requireUserAndAttest` en el gateway ⇒ bajo \
                        `ENFORCE = "enforce"` (producción) esto responde 401 `yala_attest_required`, y bajo \
                        `"observe"` (staging) pasa como si nada. Pasa `AttestSessionProvider.live`.
                        Construcción encontrada: \(site.prefix(200))
                        """)
                }
            }
            #expect(
                total == expected,
                """
                Se esperaban \(expected) construcciones de `\(type)` en producción y se encontraron \
                \(total). Si el cambio es intencionado, ajusta `scanned`. Si es 0, el escáner está roto o \
                la clase se renombró — y entonces este test estaba pasando en verde sin comprobar nada.
                """)
        }
    }

    /// La otra mitad del cableado: el provider que se inyecta tiene que ser el VIVO. Un
    /// `attestProvider: { nil }` explícito satisfaría el test de arriba y volvería a producir el 401 —
    /// pasaría el escáner por la letra y fallaría por el fondo.
    @Test func productionConstructions_injectTheLiveProvider_neverAnExplicitNil() {
        for (type, _) in Self.scanned {
            for (path, text) in Self.productionSources() {
                for site in Self.constructions(of: type, in: text) where site.contains("attestProvider:") {
                    #expect(
                        !site.contains("attestProvider: { nil }"),
                        """
                        \(path): `\(type)` recibe un `{ nil }` EXPLÍCITO. Cumple la forma del escáner y \
                        reintroduce el 401 igual: usa `AttestSessionProvider.live`.
                        """)
                }
            }
        }
    }

    /// **El mismo descuido, con el token que no llega** (2026-09-16, ticket
    /// `personal-sync-reads-an-offline-token-refresh-as-a-session-expiry`). Los tres clientes del canal personal separan
    /// «sin conexión» de «sesión caducada» preguntando `canRenewSession`, y su default `{ false }` es el trato de ANTES:
    /// una construcción de producción que lo herede vuelve a parar el motor sin red y a pedir iniciar sesión, sin un
    /// solo rojo en sus tests de cliente. **Se fija el VALOR, no la etiqueta**: cada construcción pasa `canRenew`, y el
    /// fichero que la contiene define `canRenew` como la lectura del proveedor de sesión. Con solo la etiqueta, un
    /// `let canRenew = { false }`, uno invertido o uno sobre `hasSession` (que lleva el seam de uitest) salían en verde.
    @Test func personalChannelConstructions_passTheSessionRenewalWitness() {
        // `SyncMerkleClient` entró el 2026-09-22 (`reverse-verify-network-bucket-hides-a-definitive-server-no`): su
        // 401 dejó de aplanarse y ahora enciende el aviso de «vuelve a entrar» de la vuelta a iCloud, así que
        // acertar en qué es una sesión caducada pasó a importar también en el tercer cliente del canal.
        let personal: [(type: String, expected: Int)] = [
            ("SyncPushClient", 2), ("SyncPullClient", 2), ("PrefsSyncClient", 1), ("SyncMerkleClient", 2),
        ]
        let definicion = "let canRenew: @MainActor () -> Bool = { session.canRenewSession }"
        let sources = Self.productionSources()
        #expect(!sources.isEmpty, "El barrido no leyó NINGÚN fuente: el test no está comprobando nada.")
        for (type, expected) in personal {
            var total = 0
            for (path, text) in sources {
                for site in Self.constructions(of: type, in: text) {
                    total += 1
                    #expect(site.contains("canRenewSession: canRenew)") || site.contains("canRenewSession: canRenew,"),
                            """
                            \(path): construye `\(type)` sin `canRenewSession: canRenew`. Con el default `{ false }`, sin red y \
                            con el token vencido el motor personal se para y Ajustes pide iniciar sesión.
                            Construcción encontrada: \(site.prefix(200))
                            """)
                    let codigo = Self.stripWholeLineComments(text)
                    #expect(codigo.components(separatedBy: definicion).count - 1 == 1,
                            "\(path): `canRenew` tiene que definirse UNA vez como `\(definicion)`.")
                }
            }
            #expect(total == expected,
                    "Se esperaban \(expected) construcciones de `\(type)` en producción y se encontraron \(total).")
        }
    }

    /// **El mismo testigo en las acciones de Grupos, con el trato contrario** (2026-09-17, ticket
    /// `groups-actions-read-an-offline-token-refresh-as-a-session-expiry`). `GroupsMembershipClient` separa «sin conexión»
    /// de «sesión caducada» con `canRenewSession`, pero su default ES el vivo (`CloudAuthService.shared.canRenewSession`, el
    /// singleton del que sale también su token por defecto), así que la red es la contraria de la del canal personal:
    /// **ninguna construcción de producción lo pasa**, y la firma del init conserva ese default. Una construcción con
    /// `canRenewSession: { false }` —o con `hasSession`, copiado del `sessionCheck` del servicio— volvería al bug en su
    /// pantalla sin un rojo: los tests de comportamiento inyectan el testigo. Lo pidió la review adversarial.
    @Test func groupsMembershipConstructions_inheritTheLiveSessionWitness() throws {
        var total = 0
        for (path, text) in Self.productionSources() {
            for site in Self.constructions(of: "GroupsMembershipClient", in: text) {
                total += 1
                #expect(!site.contains("canRenewSession"),
                        """
                        \(path): `GroupsMembershipClient` recibe su propio `canRenewSession`. Producción tiene que heredar el \
                        default vivo, o sin red y con el token vencido esa pantalla vuelve a decir «Tu sesión caducó».
                        Construcción encontrada: \(site.prefix(200))
                        """)
            }
        }
        #expect(total == 8, "Se esperaban 8 construcciones de `GroupsMembershipClient` y se encontraron \(total).")

        // Y el default de la firma, ENTERA y en orden: un `contains` de la línea suelta pasaría con el parámetro fuera
        // del init.
        let url = Self.repoRoot.appendingPathComponent("Yala/Services/CloudSync/Groups/GroupsMembershipClient.swift")
        let lines = try String(contentsOf: url, encoding: .utf8)
            .components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let start = try #require(lines.firstIndex(of: "init("))
        let end = try #require(lines[start...].firstIndex(of: ") {"))
        #expect(Array(lines[(start + 1)..<end]) == [
            "baseURL: URL = ProxyConfig.baseURL,",
            "tokenProvider: @escaping @MainActor () async -> String? = { await CloudAuthService.shared.accessToken() },",
            "canRenewSession: @escaping @MainActor () -> Bool = { CloudAuthService.shared.canRenewSession },",
            "attestProvider: @escaping @MainActor () async -> String? = { nil },",
            "urlSession: SyncHTTPSession = URLSession.shared",
        ])
        #expect(lines[end...].prefix(8).contains("self.canRenewSession = canRenewSession"),
                "el init tiene que guardar el testigo que recibe, no una constante")
    }

    /// El proveedor vive en un sitio que se encuentra buscando «attest». Estaba anidado en
    /// `AccountDeletionService.Dependencies.liveAttest` —dentro del servicio de BORRADO DE CUENTAS—, que es
    /// la razón más probable de que seis sitios no lo encontraran. Si alguien lo devuelve ahí, esto
    /// enrojece.
    @Test func theLiveProvider_livesInItsOwnDiscoverableFile() throws {
        let path = Self.repoRoot.appendingPathComponent("Yala/Services/CloudSync/AttestSessionProvider.swift")
        #expect(FileManager.default.fileExists(atPath: path.path),
                "`AttestSessionProvider` es el sitio findable del proveedor de attest; no lo re-anides.")

        let deletion = try String(
            contentsOf: Self.repoRoot.appendingPathComponent(
                "Yala/Services/CloudSync/AccountDeletionService.swift"), encoding: .utf8)
        #expect(!deletion.contains("liveAttest"),
                "El proveedor de attest volvió a esconderse dentro del servicio de borrado de cuentas.")
    }
}

// MARK: - Comportamiento: el header viaja de verdad

/// El escáner prueba el CABLEADO; esto prueba que el cableado significa algo. Cada test hace el par
/// completo —provider vivo ⇒ header presente, provider nil ⇒ header ausente— porque solo el par demuestra
/// que es el provider, y no otra cosa, lo que pone el header.
@Suite("App Attest · el header X-Yala-Attest-Session viaja", .serialized)
@MainActor
struct AttestHeaderTransportTests {

    private let base = URL(string: "https://gw.test")!
    private let header = "X-Yala-Attest-Session"

    private func stub(_ json: String) -> GroupsSyncClientTests.StubHTTPSession {
        GroupsSyncClientTests.StubHTTPSession(responseData: Data(json.utf8), statusCode: 200)
    }

    // MARK: POST /groups/rpc/{fn} — la ruta que produjo el 401 medido

    @Test func groupsMembershipClient_sendsAttest_whenProviderIsLive() async throws {
        let session = stub(#"{"group_id":"SplitGroup-Z","member_key":"sub-1"}"#)
        let client = GroupsMembershipClient(
            baseURL: base, tokenProvider: { "jwt" },
            attestProvider: { "attest-tok" }, urlSession: session)
        client.sleeper = { _ in }

        _ = try await client.createGroup(
            groupID: "SplitGroup-Z", name: "Trip", currencyCode: "USD", iconName: "car.fill",
            colorHex: "#112233", displayName: "Alice", defaultSplitType: "equal",
            simplifyDebts: true, showDebtsInSingleCurrency: false, membersCanInvite: true)

        #expect(session.lastRequest?.value(forHTTPHeaderField: header) == "Bearer attest-tok")
    }

    @Test func groupsMembershipClient_omitsAttest_whenProviderIsNil() async throws {
        let session = stub(#"{"group_id":"SplitGroup-Z","member_key":"sub-1"}"#)
        let client = GroupsMembershipClient(
            baseURL: base, tokenProvider: { "jwt" },
            attestProvider: { nil }, urlSession: session)
        client.sleeper = { _ in }

        _ = try await client.createGroup(
            groupID: "SplitGroup-Z", name: "Trip", currencyCode: "USD", iconName: "car.fill",
            colorHex: "#112233", displayName: "Alice", defaultSplitType: "equal",
            simplifyDebts: true, showDebtsInSingleCurrency: false, membersCanInvite: true)

        #expect(session.lastRequest?.value(forHTTPHeaderField: header) == nil,
                "Este es EXACTAMENTE el request que el gateway rechazó con 401 en producción.")
    }

    // MARK: POST /groups/rpc/record_groups_consent — C1

    /// El escáner de arriba comprueba el `attestProvider:` del INIT, no que cada método pase por `call()`.
    /// Un método nuevo escrito sin pasar por ahí pondría el header a nadie y los tres tests de cableado
    /// seguirían verdes. Por eso los métodos del consent llevan su propio par: son los dos primeros que se
    /// añaden a este cliente desde que el 401 ocurrió.
    @Test func recordConsent_sendsAttest_whenProviderIsLive() async throws {
        let session = stub(#"{"text_version":1,"accepted_at":"2026-08-11T18:04:05Z","inserted":true}"#)
        let client = GroupsMembershipClient(
            baseURL: base, tokenProvider: { "jwt" },
            attestProvider: { "attest-tok" }, urlSession: session)
        client.sleeper = { _ in }

        _ = try await client.recordConsent(textVersion: 1, acceptedAt: .now, path: "invite")

        #expect(session.lastRequest?.url?.absoluteString.contains("groups/rpc/record_groups_consent") == true)
        #expect(session.lastRequest?.value(forHTTPHeaderField: header) == "Bearer attest-tok")
    }

    @Test func recordConsent_omitsAttest_whenProviderIsNil() async throws {
        let session = stub(#"{"text_version":1,"accepted_at":"2026-08-11T18:04:05Z","inserted":true}"#)
        let client = GroupsMembershipClient(
            baseURL: base, tokenProvider: { "jwt" },
            attestProvider: { nil }, urlSession: session)
        client.sleeper = { _ in }

        _ = try await client.recordConsent(textVersion: 1, acceptedAt: .now, path: nil)

        #expect(session.lastRequest?.value(forHTTPHeaderField: header) == nil,
                "bajo `enforce` esto es un 401 y el registro del consent no llega nunca a la cuenta.")
    }

    @Test func consentState_sendsAttest_whenProviderIsLive() async throws {
        let session = stub(#"{"text_version":1,"accepted_at":"2026-08-11T18:04:05Z"}"#)
        let client = GroupsMembershipClient(
            baseURL: base, tokenProvider: { "jwt" },
            attestProvider: { "attest-tok" }, urlSession: session)
        client.sleeper = { _ in }

        _ = try await client.consentState()

        #expect(session.lastRequest?.url?.absoluteString.contains("groups/rpc/groups_consent_state") == true)
        #expect(session.lastRequest?.value(forHTTPHeaderField: header) == "Bearer attest-tok")
    }

    @Test func consentState_omitsAttest_whenProviderIsNil() async throws {
        let session = stub(#"{"text_version":1,"accepted_at":"2026-08-11T18:04:05Z"}"#)
        let client = GroupsMembershipClient(
            baseURL: base, tokenProvider: { "jwt" },
            attestProvider: { nil }, urlSession: session)
        client.sleeper = { _ in }

        _ = try await client.consentState()

        #expect(session.lastRequest?.value(forHTTPHeaderField: header) == nil)
    }

    // MARK: POST /push/register

    @Test func pushTokenRegistrationClient_sendsAttest_whenProviderIsLive() async throws {
        let session = stub("{}")
        let client = PushTokenRegistrationClient(
            baseURL: base, tokenProvider: { "jwt" },
            attestProvider: { "attest-tok" }, urlSession: session)

        try await client.register(deviceToken: "dt", platform: "ios-prod")

        #expect(session.lastRequest?.value(forHTTPHeaderField: header) == "Bearer attest-tok")
    }

    @Test func pushTokenRegistrationClient_omitsAttest_whenProviderIsNil() async throws {
        let session = stub("{}")
        let client = PushTokenRegistrationClient(
            baseURL: base, tokenProvider: { "jwt" },
            attestProvider: { nil }, urlSession: session)

        try await client.register(deviceToken: "dt", platform: "ios-prod")

        #expect(session.lastRequest?.value(forHTTPHeaderField: header) == nil)
    }

    // MARK: GET /groups/pull — el request que `wrangler tail` mostró en 401

    /// Container ON-DISK propio (molde de `GroupsSyncClientTests`): el pull necesita el `GroupSyncCursor`
    /// de `syncMetaSchema`, así que no basta con un cliente suelto.
    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration(
            "AW-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "AW-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "AW-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        return ModelContext(container)
    }

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AttestWiring-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test func groupsSyncClientPull_sendsAttest_whenProviderIsLive() async throws {
        let dir = freshDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let context = try makeContext(dir)
        let session = GroupsSyncClientTests.StubHTTPSession()
        let client = GroupsSyncClient(
            baseURL: base, tokenProvider: { "jwt" },
            attestProvider: { "attest-tok" }, urlSession: session)

        _ = await client.pullAndApplyOnce(context: context, limit: 250)

        #expect(session.lastRequest?.url?.absoluteString.contains("groups/pull") == true)
        #expect(session.lastRequest?.value(forHTTPHeaderField: header) == "Bearer attest-tok")
    }

    @Test func groupsSyncClientPull_omitsAttest_whenProviderIsNil() async throws {
        let dir = freshDir(); defer { try? FileManager.default.removeItem(at: dir) }
        let context = try makeContext(dir)
        let session = GroupsSyncClientTests.StubHTTPSession()
        let client = GroupsSyncClient(
            baseURL: base, tokenProvider: { "jwt" },
            attestProvider: { nil }, urlSession: session)

        _ = await client.pullAndApplyOnce(context: context, limit: 250)

        #expect(session.lastRequest?.value(forHTTPHeaderField: header) == nil,
                "El `GET /groups/pull` sin header es el 401 literal de `wrangler tail` del 2026-07-31.")
    }
}
