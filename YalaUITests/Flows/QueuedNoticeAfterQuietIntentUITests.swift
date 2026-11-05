//
//  QueuedNoticeAfterQuietIntentUITests.swift
//  YalaUITests
//
//  Ticket `drained-intent-that-presents-nothing-may-strand-the-next`: `ContentView` drena un aviso por cada cambio de la
//  cola, y el cambio que provoca su propio drenaje ocurre DENTRO de la actualización de la vista. Si el aviso drenado no
//  presenta nada (`.remoteOnboardingCompleted` con el onboarding hecho), nada más vuelve a mover la cola: si ese cambio
//  se perdiera, lo que espera detrás se quedaría hasta el siguiente aviso.
//
//  El seam `<scheme>://uitest-notice?kind=quiet-then-trial-offer` encola los dos por la puerta de siempre con Yala
//  delante. Medido el 2026-11-05 con `-test-iterations 20`: 20 de 20 verdes (13,7–14,7 s), sin tocar el router. Que el caso
//  ve un atasco está comprobado con un mutante: sin el cambio de revisión al drenar el aviso silencioso, rojo.
//

import XCTest

final class QueuedNoticeAfterQuietIntentUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openFromOutside(_ url: String) {
        guard let url = URL(string: url) else { return XCTFail("URL inválida: \(url)") }
        XCUIDevice.shared.system.open(url)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.alerts.buttons.element(boundBy: 1)
        if springboard.alerts.firstMatch.waitForExistence(timeout: 3), open.exists { open.tap() }
    }

    /// Un aviso que no enseña nada no deja esperando a la oferta que va detrás.
    func test_quietNoticeFirst_theQueuedOfferStillShows() {
        let app = XCUIApplication()
        // Con precios de prueba: sin ellos la oferta no sabe si hay prueba y se guarda para el arranque siguiente.
        app.launchForUITest(seed: "minimal", fakePrices: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 15), "La app no llegó al Panel.")

        openFromOutside("yaladev://uitest-notice?kind=quiet-then-trial-offer")
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "El enlace no trajo Yala delante.")

        let offer = app.buttons["trial_offer_dismiss"]
        let shown = offer.waitForExistence(timeout: 15)
        if !shown {
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = "oferta-que-no-salio"
            shot.lifetime = .keepAlways
            add(shot)
        }
        XCTAssertTrue(shown, "Tras un aviso que no presenta nada, la oferta de prueba que esperaba detrás no salió.")
    }
}
