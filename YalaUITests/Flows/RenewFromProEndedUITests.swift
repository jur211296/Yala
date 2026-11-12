//
//  RenewFromProEndedUITests.swift
//  YalaUITests
//
//  Renovar desde «Tu suscripción terminó» (card `tablero-al-renovar-desde-tu-suscripcion-termino-7c97`, 2026-10-22). Tras
//  comprar y tocar «Comenzar», la hoja de fin de Pro se cierra a la primera: antes volvía a salir y solo una segunda
//  vuelta por «Renovar» («Eres Yala Pro») la cerraba. La compra sale bien con `-uitest-fake-purchase`, que no pasa por
//  StoreKit: este caso fija que la hoja se cierra con Pro encendido, no la causa del bug. La causa —leer la suscripción
//  vieja caducada que StoreKit lista tras renovar como el fin de Pro— la fija
//  `ProSubscriptionActivationLogicTests` (`renovar_*`).
//

import XCTest

final class RenewFromProEndedUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openFromOutside(_ app: XCUIApplication, _ link: String) {
        guard let url = URL(string: link) else { return XCTFail("URL inválida: \(link)") }
        XCUIDevice.shared.system.open(url)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.alerts.buttons.element(boundBy: 1)
        if springboard.alerts.firstMatch.waitForExistence(timeout: 3), open.exists { open.tap() }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "El enlace no trajo Yala delante.")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Renovar → comprar → «Comenzar» deja la app sin la hoja de fin de Pro y sin el paywall encima.
    func test_renewFromSubscriptionEnded_closesTheSheetAtTheFirstTry() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "realista", fakePricesTrialUsed: true, fakePurchase: true,
                            extraArguments: ["-uitest-pro-ended-paid"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openFromOutside(app, "yaladev://uitest-notice?kind=pro-ended")

        let title = app.staticTexts["downgrade_title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15), "No salió la hoja de fin de Pro.")
        XCTAssertEqual(title.label, "Tu suscripción terminó")
        capture(app, "renovar-1-suscripcion-terminada")

        let renew = app.buttons["downgrade_reactivate"]
        XCTAssertTrue(renew.waitForHittable(timeout: 10), "«Renovar» no se puede tocar.")
        renew.tap()

        let cta = app.buttons["subscription_cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 10), "No se abrió la pantalla de compra.")
        XCTAssertTrue(cta.waitForHittable(timeout: 10), "El botón de compra no se puede tocar.")
        cta.tap()

        let start = app.buttons["subscription_success_continue"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "No salió la bienvenida a Pro tras comprar.")
        start.tap()

        // La hoja de fin de Pro sigue en el árbol mientras esté presentada (también debajo del paywall), así que esta
        // espera discrimina: con la hoja de vuelta, no se cumple.
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: title)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed,
                       "Tras renovar, «Tu suscripción terminó» volvió a salir en vez de cerrarse.")
        XCTAssertFalse(app.buttons["downgrade_reactivate"].exists, "«Renovar» seguía en pantalla.")
        XCTAssertFalse(cta.exists, "La pantalla de compra seguía abierta.")
        XCTAssertFalse(app.buttons["subscription_manage"].exists, "Quedó «Eres Yala Pro» encima.")
        capture(app, "renovar-2-hoja-cerrada")
    }
}
