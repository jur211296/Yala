//
//  ConnectedBrowsersClientTests.swift
//  YalaTests
//
//  «Navegadores conectados» (Yala web, lote 1): el cliente contra la web y la decisión de cuándo preguntarle.
//

import Foundation
import Testing
@testable import Yala

private final class WebStubSession: SyncHTTPSession, @unchecked Sendable {
    var status = 200
    var body = Data("{}".utf8)
    var fails = false
    private(set) var requests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        if fails { throw URLError(.notConnectedToInternet) }
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else {
            throw URLError(.badURL)
        }
        return (body, response)
    }
}

private let twoSessions = Data(#"""
{"sesiones":[
 {"id":"aaaaaaaaaaaa","navegador":"Chrome","sistema":"Mac","ciudad":"Lima","creada":1,"ultimoUso":1800000000,"equipoCompartido":false,"esta":false},
 {"id":"bbbbbbbbbbbb","navegador":"","sistema":"","ciudad":null,"creada":1,"ultimoUso":1799990000,"equipoCompartido":true,"esta":false}
]}
"""#.utf8)

@Suite("Navegadores conectados · transporte", .serialized)
@MainActor
struct ConnectedBrowsersClientTests {
    private let base = URL(fileURLWithPath: "/") // nunca sale a la red: la sesión es un stub

    @Test func laLista_viajaConElTokenDeLaApp_ySeLee() async throws {
        let session = WebStubSession()
        session.body = twoSessions
        let client = ConnectedBrowsersClient(baseURL: base, tokenProvider: { "jwt-app" }, urlSession: session)
        let list = try await client.sessions()
        #expect(list.map(\.id) == ["aaaaaaaaaaaa", "bbbbbbbbbbbb"])
        #expect(list[0].ciudad == "Lima")
        #expect(list[1].ciudad == nil)
        #expect(list[1].equipoCompartido)
        let request = try #require(session.requests.last)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-app")
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path.hasSuffix("api/dispositivo/sesiones") == true)
        // Sin App Attest, a propósito (decisión P9): la web no lo pide para esto.
        #expect(request.value(forHTTPHeaderField: "X-Yala-Attest-Session") == nil)
    }

    @Test func cerrarUna_mandaSuId_yCerrarTodas_vaASuRuta() async throws {
        let session = WebStubSession()
        let client = ConnectedBrowsersClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: session)
        try await client.close(id: "aaaaaaaaaaaa")
        let one = try #require(session.requests.last)
        #expect(one.httpMethod == "POST")
        #expect(one.url?.path.hasSuffix("api/dispositivo/sesiones/cerrar") == true)
        let body = try #require(one.httpBody)
        #expect(String(data: body, encoding: .utf8) == #"{"id":"aaaaaaaaaaaa"}"#)
        try await client.closeAll()
        #expect(session.requests.last?.url?.path.hasSuffix("api/dispositivo/sesiones/cerrar-todas") == true)
    }

    @Test func sinToken_noManda_nada() async {
        let session = WebStubSession()
        let client = ConnectedBrowsersClient(baseURL: base, tokenProvider: { nil }, urlSession: session)
        await #expect(throws: ConnectedBrowsersClientError.sessionExpired) { try await client.sessions() }
        #expect(session.requests.isEmpty)
    }

    @Test func sinWeb_paraEsteBuild_noManda_nada() async {
        let session = WebStubSession()
        let client = ConnectedBrowsersClient(baseURL: nil, tokenProvider: { "jwt" }, urlSession: session)
        await #expect(throws: ConnectedBrowsersClientError.unavailable) { try await client.sessions() }
        #expect(session.requests.isEmpty)
    }

    @Test func losCodigos_seClasifican() async {
        let session = WebStubSession()
        let client = ConnectedBrowsersClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: session)
        session.status = 401
        await #expect(throws: ConnectedBrowsersClientError.sessionExpired) { try await client.sessions() }
        session.status = 429
        await #expect(throws: ConnectedBrowsersClientError.rejected(status: 429)) { try await client.closeAll() }
        session.status = 503
        await #expect(throws: ConnectedBrowsersClientError.transient(status: 503)) { try await client.sessions() }
        session.status = 200
        session.body = Data("no es json".utf8)
        await #expect(throws: ConnectedBrowsersClientError.transient(status: -1)) { try await client.sessions() }
        session.fails = true
        await #expect(throws: ConnectedBrowsersClientError.transient(status: -1)) { try await client.sessions() }
    }
}

@Suite("Navegadores conectados · cuándo pregunta el iPhone", .serialized)
@MainActor
struct ConnectedBrowsersPresenceTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let base = URL(fileURLWithPath: "/")

    @Test func toca_laPrimeraVez_yCadaDosMinutos() {
        #expect(ConnectedBrowsersPresence.isDue(lastCheck: nil, now: now))
        #expect(!ConnectedBrowsersPresence.isDue(lastCheck: now.addingTimeInterval(-119), now: now))
        #expect(ConnectedBrowsersPresence.isDue(lastCheck: now.addingTimeInterval(-120), now: now))
        // Un reloj que retrocede no deja la pregunta parada.
        #expect(ConnectedBrowsersPresence.isDue(lastCheck: now.addingTimeInterval(3600), now: now))
    }

    @Test func soloPregunta_conWeb_nube_ySesion() {
        #expect(ConnectedBrowsersPresence.shouldCheck(webAvailable: true, storageIsCloud: true, hasSession: true))
        #expect(!ConnectedBrowsersPresence.shouldCheck(webAvailable: false, storageIsCloud: true, hasSession: true))
        #expect(!ConnectedBrowsersPresence.shouldCheck(webAvailable: true, storageIsCloud: false, hasSession: true))
        #expect(!ConnectedBrowsersPresence.shouldCheck(webAvailable: true, storageIsCloud: true, hasSession: false))
    }

    @Test func pregunta_guarda_yNoVuelveAPreguntarHastaQueToque() async {
        let defaults = makeIsolatedDefaults()
        let session = WebStubSession()
        session.body = twoSessions
        let client = ConnectedBrowsersClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: session)
        let first = await ConnectedBrowsersPresence.refreshIfDue(client: client, webAvailable: true, storageIsCloud: true, hasSession: true, now: now, defaults: defaults)
        #expect(first)
        #expect(session.requests.count == 1)
        #expect(ConnectedBrowsersPresence.cachedHasSessions(defaults: defaults))
        // Un minuto después no pregunta: vale lo guardado, aunque la web ya diría otra cosa.
        session.body = Data(#"{"sesiones":[]}"#.utf8)
        let again = await ConnectedBrowsersPresence.refreshIfDue(client: client, webAvailable: true, storageIsCloud: true, hasSession: true, now: now.addingTimeInterval(60), defaults: defaults)
        #expect(again)
        #expect(session.requests.count == 1)
        // A los dos minutos pregunta: ya no hay sesiones, pero las hubo hace nada y lo apuntado en la web puede seguir en
        // la cola (quien apunta en un equipo compartido y sale no deja ninguna abierta). Sigue recogiendo 30 días.
        let later = await ConnectedBrowsersPresence.refreshIfDue(client: client, webAvailable: true, storageIsCloud: true, hasSession: true, now: now.addingTimeInterval(121), defaults: defaults)
        #expect(later)
        #expect(session.requests.count == 2)
        #expect(ConnectedBrowsersPresence.cachedHasSessions(now: now.addingTimeInterval(29 * 86_400), defaults: defaults))
        // Pasados 30 días sin ninguna, deja de preguntar a la cola.
        let month = await ConnectedBrowsersPresence.refreshIfDue(client: client, webAvailable: true, storageIsCloud: true, hasSession: true, now: now.addingTimeInterval(31 * 86_400), defaults: defaults)
        #expect(!month)
        #expect(session.requests.count == 3)
    }

    @Test func sinNingunaSesionNunca_noPreguntaALaCola() async {
        let defaults = makeIsolatedDefaults()
        let session = WebStubSession()
        session.body = Data(#"{"sesiones":[]}"#.utf8)
        let client = ConnectedBrowsersClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: session)
        let result = await ConnectedBrowsersPresence.refreshIfDue(client: client, webAvailable: true, storageIsCloud: true, hasSession: true, now: now, defaults: defaults)
        #expect(!result)
    }

    @Test func siLaWebNoContesta_valeLoGuardado() async {
        let defaults = makeIsolatedDefaults()
        ConnectedBrowsersPresence.record(sessionCount: 1, at: now.addingTimeInterval(-600), defaults: defaults)
        let session = WebStubSession()
        session.fails = true
        let client = ConnectedBrowsersClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: session)
        let result = await ConnectedBrowsersPresence.refreshIfDue(client: client, webAvailable: true, storageIsCloud: true, hasSession: true, now: now, defaults: defaults)
        #expect(result)
        #expect(session.requests.count == 1)
    }

    @Test func sinNube_niPregunta_niDiceQueHay() async {
        let defaults = makeIsolatedDefaults()
        ConnectedBrowsersPresence.record(sessionCount: 1, at: now, defaults: defaults)
        let session = WebStubSession()
        let client = ConnectedBrowsersClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: session)
        let result = await ConnectedBrowsersPresence.refreshIfDue(client: client, webAvailable: true, storageIsCloud: false, hasSession: true, now: now, defaults: defaults)
        #expect(!result)
        #expect(session.requests.isEmpty)
    }

    @Test func laRecogidaDelCorreo_tambienCorreConSesionesWeb() {
        #expect(BankEmailDraftService.shouldSync(isSetUp: false, webConnected: true, storageIsCloud: true, hasSession: true, wipeArmed: false, importQuiescent: true))
        #expect(!BankEmailDraftService.shouldSync(isSetUp: false, webConnected: false, storageIsCloud: true, hasSession: true, wipeArmed: false, importQuiescent: true))
        // Las demás puertas siguen mandando también para lo de la web.
        #expect(!BankEmailDraftService.shouldSync(isSetUp: false, webConnected: true, storageIsCloud: false, hasSession: true, wipeArmed: false, importQuiescent: true))
        #expect(!BankEmailDraftService.shouldSync(isSetUp: false, webConnected: true, storageIsCloud: true, hasSession: true, wipeArmed: true, importQuiescent: true))
        #expect(!BankEmailDraftService.shouldSync(isSetUp: false, webConnected: true, storageIsCloud: true, hasSession: true, wipeArmed: false, importQuiescent: false))
    }
}

@Suite("Navegadores conectados · textos")
@MainActor
struct ConnectedBrowsersTextTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func lasClaves_existen() {
        for key in ["title", "rowSubtitle", "intro", "empty", "close", "closeAll", "closeAllConfirmTitle", "closeAllConfirmBody",
                    "closeAllConfirm", "footer", "loadFailed", "closeFailed", "unknownBrowser", "sharedComputer", "justNow", "browserOn"] {
            #expect(ConnectedBrowsersText.text("connectedBrowsers.\(key)") != "connectedBrowsers.\(key)", "\(key)")
        }
    }

    @Test func elTitulo_juntaNavegadorYSistema_yNombraElDesconocido() {
        let both = ConnectedBrowsersText.browserTitle(navegador: "Chrome", sistema: "Mac")
        #expect(both.contains("Chrome") && both.contains("Mac") && both != "Chrome")
        #expect(ConnectedBrowsersText.browserTitle(navegador: "Safari", sistema: "") == "Safari")
        #expect(ConnectedBrowsersText.browserTitle(navegador: "", sistema: "") == ConnectedBrowsersText.unknownBrowser)
    }

    @Test func laLinea_llevaCiudad_cuandoYEquipoCompartido() {
        let s = WebSession(id: "aaaaaaaaaaaa", navegador: "Edge", sistema: "Windows", ciudad: "Arequipa",
                           ultimoUso: now.timeIntervalSince1970 - 3 * 86_400, equipoCompartido: true)
        let line = ConnectedBrowsersText.detailLine(s, now: now)
        #expect(line.hasPrefix("Arequipa · "))
        #expect(line.hasSuffix(" · \(ConnectedBrowsersText.sharedComputer)"))
        let fresh = WebSession(id: "bbbbbbbbbbbb", navegador: "Chrome", sistema: "Mac", ciudad: nil,
                               ultimoUso: now.timeIntervalSince1970 - 30, equipoCompartido: false)
        #expect(ConnectedBrowsersText.detailLine(fresh, now: now) == ConnectedBrowsersText.justNow)
    }
}
