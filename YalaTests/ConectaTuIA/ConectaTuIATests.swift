//
//  ConectaTuIATests.swift
//  YalaTests
//
//  «Conecta tu IA» (2.3, opción C de Jürgen del 23-nov): las reglas, el cliente contra el conector (`/connections`), el
//  modelo de la lista, la etiqueta de la Bandeja, el filtro «De tu IA», la sexta manera del paso 7 y los textos.
//

import Foundation
import Testing
@testable import Yala

private final class ConnectorStubSession: SyncHTTPSession, @unchecked Sendable {
    var status = 200
    var body = Data(#"{"conexiones":[]}"#.utf8)
    var deleteStatus = 204
    var fails = false
    private(set) var requests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        if fails { throw URLError(.notConnectedToInternet) }
        guard let url = request.url else { throw URLError(.badURL) }
        let code = request.httpMethod == "DELETE" ? deleteStatus : status
        guard let response = HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil) else {
            throw URLError(.badURL)
        }
        return (request.httpMethod == "DELETE" ? Data() : body, response)
    }
}

private let twoConnections = Data(#"""
{"conexiones":[
 {"id":"gClaude01","ia":"Claude","vuelta":"claude.ai","local":false,"conectadaEl":1800000000},
 {"id":"gLocal002","ia":null,"vuelta":"localhost","local":true,"conectadaEl":1799000000}
]}
"""#.utf8)

// MARK: - Reglas

@Suite("Conecta tu IA · reglas")
struct ConectaTuIALogicTests {
    private typealias L = ConectaTuIALogic

    @Test func soloLosTresNombres_seEnseñan_tuIA_siNo() {
        #expect(L.aiName(evidence: "Claude") == "Claude")
        #expect(L.aiName(evidence: "ChatGPT") == "ChatGPT")
        #expect(L.aiName(evidence: " Grok ") == "Grok")
        for raro in [nil, "", "claude", "Claude Code", "<b>Claude</b>", "OpenAI"] {
            #expect(L.aiName(evidence: raro) == nil, "\(String(describing: raro))")
        }
    }

    @Test func cadaBuild_hablaConElConectorDeSuNube() {
        #expect(L.connectorAddress(isDevBuild: false) == "https://mcp.yala-app.pe/mcp")
        #expect(L.connectorAddress(isDevBuild: true) == "https://yala-mcp-staging.misty-surf-6866.workers.dev/mcp")
    }

    @Test func sinLaCuentaDeYala_noHayNadaQueLeer() {
        #expect(L.availability(storageIsCloud: true, hasSession: true) == .ready)
        #expect(L.availability(storageIsCloud: false, hasSession: true) == .needsAccount)
        #expect(L.availability(storageIsCloud: true, hasSession: false) == .needsAccount)
    }

    @Test func laPuertaDeLaBandeja_saleHastaQueUnaIAApunte() {
        #expect(L.showsInboxDoor(isPendingFilter: true, hasAnyAIDraft: false, isSelectionMode: false))
        #expect(!L.showsInboxDoor(isPendingFilter: true, hasAnyAIDraft: true, isSelectionMode: false))
        #expect(!L.showsInboxDoor(isPendingFilter: false, hasAnyAIDraft: false, isSelectionMode: false))
        #expect(!L.showsInboxDoor(isPendingFilter: true, hasAnyAIDraft: false, isSelectionMode: true))
    }

    @Test func elFiltroDeTuIA_soloConAlgoQueFiltrar_oElegido() {
        #expect(!L.showsAIFilter(aiPendingCount: 0, isSelected: false))
        #expect(L.showsAIFilter(aiPendingCount: 2, isSelected: false))
        #expect(L.showsAIFilter(aiPendingCount: 0, isSelected: true))
    }

    @Test func deTuIA_secomportaComoPendientes() {
        #expect(InboxFilter.fromAI.isPendingList)
        #expect(InboxFilter.pending.isPendingList)
        #expect(!InboxFilter.archived.isPendingList)
    }

    @Test func tuIA_esLaSextaManera_soloConLaCuentaDeYala() {
        let H = HomeScreenTutorialLogic.self
        #expect(H.methods(showsMail: true, showsAI: true) == [.widget, .applePay, .share, .mail, .siri, .ai])
        #expect(H.methods(showsMail: true) == [.widget, .applePay, .share, .mail, .siri])
        #expect(H.methods(showsMail: false, showsAI: false).contains(.ai) == false)
        #expect(!HomeScreenTutorialLogic.Method.ai.isPro)
    }
}

// MARK: - Cliente

@Suite("Conecta tu IA · cliente", .serialized)
@MainActor
struct ConectaTuIAClientTests {
    private let base = URL(fileURLWithPath: "/")

    @Test func laLista_viajaConElTokenDeLaApp_ySeLee() async throws {
        let session = ConnectorStubSession()
        session.body = twoConnections
        let client = ConectaTuIAClient(baseURL: base, tokenProvider: { "jwt-app" }, urlSession: session)
        let list = try await client.connections()
        #expect(list.map(\.id) == ["gClaude01", "gLocal002"])
        #expect(list[0].ia == "Claude")
        #expect(list[1].ia == nil)
        #expect(list[1].local)
        let request = try #require(session.requests.last)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-app")
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path.hasSuffix("/connections") == true)
    }

    @Test func desconectar_mandaDELETE_aSuId() async throws {
        let session = ConnectorStubSession()
        let client = ConectaTuIAClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: session)
        try await client.disconnect(id: "gClaude01")
        let request = try #require(session.requests.last)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.path.hasSuffix("/connections/gClaude01") == true)
    }

    @Test func unIdQueNoCabeEnLaRuta_noSale() async {
        let session = ConnectorStubSession()
        let client = ConectaTuIAClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: session)
        for id in ["", "../x", "a/b", "a b", "a:b"] {
            await #expect(throws: ConectaTuIAClientError.notFound) { try await client.disconnect(id: id) }
        }
        #expect(session.requests.isEmpty)
    }

    @Test func losCodigos_seTraducen() async {
        let session = ConnectorStubSession()
        let client = ConectaTuIAClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: session)
        session.status = 401
        await #expect(throws: ConectaTuIAClientError.sessionExpired) { try await client.connections() }
        session.status = 503
        await #expect(throws: ConectaTuIAClientError.transient(status: 503)) { try await client.connections() }
        session.deleteStatus = 404
        await #expect(throws: ConectaTuIAClientError.notFound) { try await client.disconnect(id: "x") }
        session.fails = true
        await #expect(throws: ConectaTuIAClientError.transient(status: -1)) { try await client.connections() }
    }

    @Test func sinSesion_noLlamaANadie() async {
        let session = ConnectorStubSession()
        let client = ConectaTuIAClient(baseURL: base, tokenProvider: { nil }, urlSession: session)
        await #expect(throws: ConectaTuIAClientError.sessionExpired) { try await client.connections() }
        #expect(session.requests.isEmpty)
    }
}

// MARK: - Modelo

@Suite("Conecta tu IA · lista", .serialized)
@MainActor
struct ConectaTuIAModelTests {
    @Test func desconectar_laQuita_yNoVuelveAunqueLaListaVengaAtrasada() async throws {
        let session = ConnectorStubSession()
        session.body = twoConnections
        let model = ConectaTuIAModel(client: ConectaTuIAClient(baseURL: URL(fileURLWithPath: "/"), tokenProvider: { "jwt" },
                                                               urlSession: session))
        await model.load()
        #expect(model.connections.count == 2)
        await model.disconnect(try #require(model.connections.first))
        #expect(model.connections.map(\.id) == ["gLocal002"])
        // El conector todavía la lista (su listado va hasta un minuto atrasado): no vuelve a salir.
        await model.load()
        #expect(model.connections.map(\.id) == ["gLocal002"])
    }

    @Test func siYaNoEstaba_cuentaComoQuitada() async throws {
        let session = ConnectorStubSession()
        session.body = twoConnections
        session.deleteStatus = 404
        let model = ConectaTuIAModel(client: ConectaTuIAClient(baseURL: URL(fileURLWithPath: "/"), tokenProvider: { "jwt" },
                                                               urlSession: session))
        await model.load()
        await model.disconnect(try #require(model.connections.first))
        #expect(!model.disconnectFailed)
        #expect(model.connections.count == 1)
    }

    @Test func siFalla_loDice_yLaDeja() async throws {
        let session = ConnectorStubSession()
        session.body = twoConnections
        session.deleteStatus = 500
        let model = ConectaTuIAModel(client: ConectaTuIAClient(baseURL: URL(fileURLWithPath: "/"), tokenProvider: { "jwt" },
                                                               urlSession: session))
        await model.load()
        await model.disconnect(try #require(model.connections.first))
        #expect(model.disconnectFailed)
        #expect(model.connections.count == 2)
        #expect(model.disconnecting == nil)
    }

    @Test func sinRed_laPrimeraCarga_fallaConReintento() async {
        let session = ConnectorStubSession()
        session.fails = true
        let model = ConectaTuIAModel(client: ConectaTuIAClient(baseURL: URL(fileURLWithPath: "/"), tokenProvider: { "jwt" },
                                                               urlSession: session))
        await model.load()
        #expect(model.phase == .failed)
    }
}

// MARK: - Bandeja

@Suite("Conecta tu IA · etiqueta de la Bandeja")
@MainActor
struct ConectaTuIABandejaTests {
    @Test func laFila_diceElNombreDeLaIA_oTuIA() {
        let draft = InboxDraft(sourceType: .aiConnector)
        draft.evidence = "Claude"
        #expect(draft.sourceDisplayName == "Claude")
        draft.evidence = "ChatGPT"
        #expect(draft.sourceDisplayName == "ChatGPT")
        draft.evidence = nil
        #expect(draft.sourceDisplayName == L10n.Inbox.sourceAIConnector)
        draft.evidence = "Una IA cualquiera"
        #expect(draft.sourceDisplayName == L10n.Inbox.sourceAIConnector)
    }
}

// MARK: - Textos

@Suite("Conecta tu IA · textos", .serialized)
struct ConectaTuIATextosTests {
    private static let repoRoot = URL(fileURLWithPath: "\(#filePath)")
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                                  "pt-BR", "pt-PT", "pt", "zh-Hans"]

    private static func strings(_ locale: String) throws -> [String: String] {
        let url = repoRoot.appending(path: "Yala/Resources/\(locale).lproj/ConectaTuIA.strings")
        return try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
    }

    @Test func losTextos_enLos16Idiomas_conLasMismasClaves_yNingunoVacio() throws {
        let reference = try Self.strings("es-419")
        #expect(reference.count == 48)
        for locale in Self.locales {
            let dict = try Self.strings(locale)
            #expect(Set(dict.keys) == Set(reference.keys), "\(locale)")
            for (key, value) in dict {
                #expect(!value.trimmingCharacters(in: .whitespaces).isEmpty, "\(locale) \(key)")
                // Los que llevan %@, lo llevan en todos los idiomas, y solo uno.
                let expected = reference[key]?.components(separatedBy: "%@").count ?? 0
                #expect(value.components(separatedBy: "%@").count == expected, "\(locale) \(key)")
            }
        }
    }

    @Test func losNombresDeLasIA_noSeTraducen() throws {
        for locale in Self.locales {
            let dict = try Self.strings(locale)
            #expect(dict["conectaTuIA.row.subtitle"]?.contains("Claude") == true, "\(locale)")
            #expect(dict["conectaTuIA.row.subtitle"]?.contains("ChatGPT") == true, "\(locale)")
            #expect(dict["conectaTuIA.row.subtitle"]?.contains("Grok") == true, "\(locale)")
        }
    }

    /// El sitio de los datos se nombra como en toda la app (decisión 51 de 2.3): la ida es «Pasar a tu cuenta de Yala»
    /// y su pareja en cada idioma, la misma que el botón de «Dónde viven tus datos».
    @Test func laIdaALaCuenta_esLaDeTodaLaApp() throws {
        for locale in Self.locales {
            let app = try #require(
                NSDictionary(contentsOf: Self.repoRoot.appending(path: "Yala/Resources/\(locale).lproj/Localizable.strings"))
                    as? [String: String])
            #expect(try Self.strings(locale)["conectaTuIA.account.button"] == app["storage.migrate.button"], "\(locale)")
        }
    }

    @Test func elEspanol_esNeutro_yNoUsaNombresRetirados() throws {
        for locale in ["es", "es-419", "es-ES", "es-AR"] {
            for value in try Self.strings(locale).values {
                for palabra in ["vosotros", "tenés", "querés", "pegá", "tocá", "la nube de Yala", "Activar la nube", "iCloud privado"] {
                    #expect(!value.contains(palabra), "\(locale): \(value)")
                }
            }
        }
    }
}
