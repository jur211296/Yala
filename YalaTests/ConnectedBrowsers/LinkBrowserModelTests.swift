//
//  LinkBrowserModelTests.swift
//  YalaTests
//
//  «Vincular un navegador» (Yala web, lote 2): leer el código de la web, confirmar con Face ID y aprobarlo. El servidor
//  (`webapp/test/lote2.test.ts`) prueba que un código ajeno no abre nada; aquí, que el iPhone lee bien el código, que no
//  aprueba sin la confirmación y que cada respuesta de la web acaba en su texto.
//

import Foundation
import Testing
@testable import Yala

private final class LinkStubSession: SyncHTTPSession, @unchecked Sendable {
    /// Por ruta y método: (estado, cuerpo).
    var replies: [String: (Int, String)] = [:]
    private(set) var requests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let key = "\(request.httpMethod ?? "GET") \(request.url?.path ?? "")"
        let (status, body) = replies.first { key.hasSuffix($0.key) }?.value ?? (404, "{}")
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else {
            throw URLError(.badURL)
        }
        return (Data(body.utf8), response)
    }
}

private let peekReply = #"{"codigo":"K7Q4-MD2X","navegador":"Safari","sistema":"Mac","ciudad":"Lima","creada":1800000000,"expira":1800000120}"#

@Suite("Vincular un navegador · código QR de la web", .serialized)
@MainActor
struct LinkBrowserModelTests {
    private let base = URL(fileURLWithPath: "/")

    private func make(
        replies: [String: (Int, String)],
        auth: LinkBrowserAuthResult = .confirmed
    ) -> (LinkBrowserModel, LinkStubSession, () -> Int) {
        let session = LinkStubSession()
        session.replies = replies
        let client = ConnectedBrowsersClient(baseURL: base, tokenProvider: { "jwt-app" }, urlSession: session)
        var asked = 0
        let model = LinkBrowserModel(client: client, authenticate: { _ in
            asked += 1
            return auth
        })
        return (model, session, { asked })
    }

    @Test func elCodigo_seLeeDeLaDireccion_oEscritoAMano() {
        #expect(WebLinkCode.normalize("https://yala-web-staging.misty-surf-6866.workers.dev/v/K7Q4MD2X") == "K7Q4MD2X")
        #expect(WebLinkCode.normalize("k7q4-md2x") == "K7Q4MD2X")
        #expect(WebLinkCode.normalize("  K7Q4 MD2X ") == "K7Q4MD2X")
        #expect(WebLinkCode.normalize("K7q4'MD2X") == "K7Q4MD2X") // el teclado puso un apóstrofo en vez del guion
        // Mismo alfabeto que la web: sin 0/O ni 1/I, y 8 símbolos.
        #expect(WebLinkCode.normalize("K7Q4MD2O") == nil)
        #expect(WebLinkCode.normalize("K7Q4MD21") == nil)
        #expect(WebLinkCode.normalize("K7Q4MD2") == nil)
        #expect(WebLinkCode.normalize("https://otra.web/qr?K7Q4MD2X") == nil)
        #expect(WebLinkCode.display("K7Q4MD2X") == "K7Q4-MD2X")
    }

    @Test func deCaboARabo_lee_confirma_yAprueba() async throws {
        let (model, session, asked) = make(replies: [
            "GET /api/dispositivo/vincular": (200, peekReply),
            "POST /api/dispositivo/vincular": (200, #"{"ok":true}"#),
        ])
        await model.submit("https://x.invalid/v/K7Q4MD2X")
        let request = try #require({ if case .confirm(let r) = model.phase { return r } else { return nil } }())
        #expect(request.navegador == "Safari")
        #expect(request.ciudad == "Lima")
        let peek = try #require(session.requests.first)
        #expect(peek.httpMethod == "GET")
        #expect(peek.url?.query == "codigo=K7Q4MD2X")
        #expect(peek.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-app")

        await model.confirm(reason: "r")
        #expect(asked() == 1)
        #expect(model.phase == .linked(request))
        let approve = try #require(session.requests.last)
        #expect(approve.httpMethod == "POST")
        #expect(String(data: try #require(approve.httpBody), encoding: .utf8) == #"{"codigo":"K7Q4MD2X"}"#)
    }

    @Test func sinFaceID_noSeAprueba() async throws {
        for result in [LinkBrowserAuthResult.cancelled, .failed] {
            let (model, session, _) = make(replies: ["GET /api/dispositivo/vincular": (200, peekReply)], auth: result)
            await model.submit("K7Q4MD2X")
            await model.confirm(reason: "r")
            #expect(session.requests.allSatisfy { $0.httpMethod == "GET" }, "con \(result) no debe salir el POST")
            if case .confirm = model.phase {} else { Issue.record("con \(result) sigue en la confirmación: \(model.phase)") }
        }
    }

    @Test func unIphoneSinCodigo_aprueba_porqueNoHayNadaMasQuePedir() async {
        let (model, session, _) = make(
            replies: ["GET /api/dispositivo/vincular": (200, peekReply), "POST /api/dispositivo/vincular": (200, "{}")],
            auth: .noPasscode
        )
        await model.submit("K7Q4MD2X")
        await model.confirm(reason: "r")
        #expect(session.requests.last?.httpMethod == "POST")
    }

    @Test func cadaRespuesta_acabaEnSuTexto_yVuelveAEscanear() async {
        let cases: [(Int, String, LinkBrowserModel.Problem)] = [
            (404, "GET", .expired),
            (409, "POST", .noCloud),
            (401, "GET", .sessionExpired),
            (503, "GET", .network),
        ]
        for (status, failingMethod, problem) in cases {
            var replies: [String: (Int, String)] = ["GET /api/dispositivo/vincular": (200, peekReply)]
            replies["\(failingMethod) /api/dispositivo/vincular"] = (status, "{}")
            let (model, _, _) = make(replies: replies)
            let before = model.attempt
            await model.submit("K7Q4MD2X")
            if failingMethod == "POST" { await model.confirm(reason: "r") }
            #expect(model.problem == problem, "HTTP \(status) en \(failingMethod)")
            #expect(model.phase == .entering)
            #expect(model.attempt > before, "un escáner nuevo para volver a leer")
        }
    }

    @Test func unCodigoMalEscrito_noSaleALaRed() async {
        let (model, session, _) = make(replies: [:])
        await model.submit("hola")
        #expect(model.problem == .invalidCode)
        #expect(session.requests.isEmpty)
    }
}
