//
//  GmailBuscarCodigoTests.swift
//  YalaTests
//
//  Paso 3 de «Reenviar desde Gmail» (bug de Jürgen del 2026-11-24: «he apretado mil veces "Buscar código" y no tiene
//  una animación, ni se bloquea ni me dice nada. Ni encuentra el código»). Dos causas, medidas ese día:
//    - el correo de Gmail ya no trae código, solo un enlace de confirmación, y el gateway solo buscaba el código;
//    - el botón pedía la dirección otra vez sin enseñar nada.
//  Lo que fija, por gravedad si se rompiera:
//    - con el enlace, el paso ofrece abrirlo (y solo si es de Google con https);
//    - la respuesta de la build 8 (sin `gmail_link`) se sigue leyendo;
//    - el botón se apaga mientras busca y entre búsquedas, dice cuánto falta, y a los 2 minutos se rinde y vuelve a dejar
//      buscar;
//    - la búsqueda sola se detiene al llegar lo que se esperaba.
//

import Foundation
import Testing
@testable import Yala

@MainActor
struct GmailBuscarCodigoTests {

    // MARK: - Lo que manda el gateway

    @Test func addressWithoutGmailLink_stillDecodes() throws {
        let json = #"{"address":"auto+k7m2xq9wpb@yalainbox.com","pro":false,"trial_limit":5,"trial_used":0,"skipped_quota":0,"last_received_at_ms":null,"gmail_confirmation":null}"#
        let info = try JSONDecoder().decode(BankEmailAddressInfo.self, from: Data(json.utf8))
        #expect(info.gmailLink == nil)
        #expect(GmailConfirmationStepLogic.offer(for: info) == .search)
    }

    @Test func addressWithGmailLink_decodesIt() throws {
        let json = #"{"address":"a","pro":false,"trial_limit":5,"trial_used":0,"skipped_quota":0,"last_received_at_ms":null,"gmail_confirmation":null,"gmail_link":{"url":"https://mail-settings.google.com/mail/vf-%5BX%5D-Y","received_at_ms":1795557853934}}"#
        let info = try JSONDecoder().decode(BankEmailAddressInfo.self, from: Data(json.utf8))
        #expect(info.gmailLink?.url == "https://mail-settings.google.com/mail/vf-%5BX%5D-Y")
        guard case .link(let url) = GmailConfirmationStepLogic.offer(for: info) else {
            Issue.record("Con el enlace, el paso no ofrece abrirlo")
            return
        }
        #expect(url.host == "mail-settings.google.com")
    }

    // MARK: - Qué ofrece el paso

    @Test func linkWinsOverCode() {
        let info = BankEmailModel.uiTestInfo(withGmailCode: true, withGmailLink: true)
        #expect(GmailConfirmationStepLogic.offer(for: info) == .link(URL(string: BankEmailModel.uiTestGmailLink)!))
    }

    @Test func codeAlone_isStillOffered() {
        #expect(GmailConfirmationStepLogic.offer(for: BankEmailModel.uiTestInfo(withGmailCode: true)) == .code("482913765"))
    }

    @Test(arguments: [
        "http://mail-settings.google.com/mail/vf-x",
        "https://mail-settings.google.com.evil.pe/mail/vf-x",
        "https://evil.pe/mail/vf-x",
        "https://user@mail-settings.google.com/mail/vf-x",
        "https://mail-settings.google.com:8443/mail/vf-x",
        "javascript:alert(1)",
        "",
    ])
    func onlyGoogleHttpsLinks_areOpened(_ raw: String) {
        #expect(GmailConfirmationStepLogic.confirmationURL(raw) == nil, "Se abriría «\(raw)»")
    }

    // MARK: - La búsqueda

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func searching_disablesTheButton_andNotYetSaysHowLong() {
        var search = GmailConfirmationSearch()
        search.start(now: t0)
        #expect(search.canSearchByHand)
        let began = search.beginAuto(now: t0)
        #expect(began)
        #expect(search.isSearching)
        #expect(!search.canSearchByHand)
        search.finish(.notYet, now: t0)
        #expect(!search.canSearchByHand, "Entre una búsqueda y otra el botón espera")
        #expect(search.secondsLeft(now: t0.addingTimeInterval(2.5)) == 8)
        #expect(!search.isDueForAutoSearch(now: t0.addingTimeInterval(9)))
        #expect(search.isDueForAutoSearch(now: t0.addingTimeInterval(10)))
    }

    @Test func failure_isItsOwnState_andRetries() {
        var search = GmailConfirmationSearch()
        search.start(now: t0)
        _ = search.beginAuto(now: t0)
        search.finish(.failed, now: t0)
        guard case .failed = search.phase else {
            Issue.record("Un fallo de red se leía como «todavía no llegó»")
            return
        }
        #expect(search.isDueForAutoSearch(now: t0.addingTimeInterval(GmailConfirmationSearch.interval)))
    }

    @Test func afterTwoMinutes_itGivesUp_andTheButtonOpensANewWindow() {
        var search = GmailConfirmationSearch()
        search.start(now: t0)
        let late = t0.addingTimeInterval(GmailConfirmationSearch.window)
        _ = search.beginAuto(now: t0)
        search.finish(.notYet, now: late)
        #expect(search.phase == .gaveUp(lastFailed: false))
        #expect(!search.isDueForAutoSearch(now: late.addingTimeInterval(60)), "Rendida, no busca sola")
        #expect(search.canSearchByHand)
        let byHand = search.beginByHand(now: late)
        #expect(byHand)
        search.finish(.notYet, now: late.addingTimeInterval(1))
        guard case .notYet = search.phase else {
            Issue.record("Tras tocar, la ventana nueva no volvió a esperar: \(search.phase)")
            return
        }
    }

    @Test func comingBack_startsAgain_butNotOverAFoundOrRunningSearch() {
        var search = GmailConfirmationSearch()
        search.start(now: t0)
        _ = search.beginAuto(now: t0)
        search.start(now: t0.addingTimeInterval(1))
        #expect(search.isSearching, "Volver a la pantalla no pisa una búsqueda en vuelo")
        search.finish(.found, now: t0.addingTimeInterval(2))
        search.start(now: t0.addingTimeInterval(3))
        #expect(search.phase == .found)
    }

    // MARK: - El modelo

    private static func info(link: Bool) -> BankEmailAddressInfo {
        BankEmailModel.uiTestInfo(withGmailCode: false, withGmailLink: link)
    }

    @Test func byHand_findsTheLink_andStops() async {
        var calls = 0
        let model = BankEmailModel(fetch: {
            calls += 1
            return Self.info(link: calls >= 2)
        })
        await model.refresh()
        #expect(!model.gmailConfirmationArrived)
        await model.searchGmailConfirmationByHand(now: { self.t0 })
        #expect(model.gmailConfirmationArrived)
        #expect(model.gmailSearch.phase == .found)
        #expect(calls == 2)
    }

    @Test func byHand_isIgnoredWhileWaitingItsTurn() async {
        var calls = 0
        let model = BankEmailModel(fetch: {
            calls += 1
            return Self.info(link: false)
        })
        await model.refresh()
        await model.searchGmailConfirmationByHand(now: { self.t0 })
        #expect(calls == 2)
        // Tocar «Buscar ahora» mil veces entre una búsqueda y otra no pide nada más.
        for _ in 0..<5 { await model.searchGmailConfirmationByHand(now: { self.t0.addingTimeInterval(1) }) }
        #expect(calls == 2)
        guard case .notYet = model.gmailSearch.phase else {
            Issue.record("Sin respuesta útil, el paso no dice que todavía no llegó")
            return
        }
    }

    @Test func networkError_keepsTheAddress_andSaysItFailed() async {
        struct Down: Error {}
        var calls = 0
        let model = BankEmailModel(fetch: {
            calls += 1
            if calls > 1 { throw Down() }
            return Self.info(link: false)
        })
        await model.refresh()
        await model.searchGmailConfirmationByHand(now: { self.t0 })
        #expect(model.info != nil, "Un fallo de la búsqueda no puede borrar la dirección de la pantalla")
        guard case .failed = model.gmailSearch.phase else {
            Issue.record("Un fallo de red no se dice: \(model.gmailSearch.phase)")
            return
        }
    }

    @Test func autoWatch_stopsWhenTheLinkArrives() async {
        var calls = 0
        let model = BankEmailModel(fetch: {
            calls += 1
            return Self.info(link: calls >= 3)
        })
        await model.refresh()
        var clock = t0
        // Cada vuelta del bucle duerme 1 s de verdad; el reloj de la búsqueda avanza 10 s por vuelta para no esperar.
        let task = Task { await model.watchGmailConfirmation(now: { clock }) }
        for _ in 0..<40 where !model.gmailConfirmationArrived {
            clock = clock.addingTimeInterval(GmailConfirmationSearch.interval)
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                break
            }
        }
        task.cancel()
        #expect(model.gmailConfirmationArrived)
        #expect(calls == 3)
    }

    // MARK: - Cableado de la vista

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    @Test func theSearchButton_showsBusy_andWaitsItsTurn() throws {
        let view = try Self.source("Yala/App/Views/Settings/BankEmailForwardingView.swift")
        #expect(view.contains("isBusy: search.isSearching"))
        #expect(view.contains("isEnabled: search.canSearchByHand"))
        #expect(view.contains("step.footnote = AnyView(GmailConfirmationStatusView("))
        // El botón ya no pide la dirección a secas: eso no enseñaba nada.
        #expect(!view.contains("perform: { _ in Task { await model.refresh() } }"))
        let guide = try Self.source("Yala/App/DesignSystem/StepGuide.swift")
        #expect(guide.contains(".disabled(action.isBusy || !action.isEnabled)"))
    }
}
