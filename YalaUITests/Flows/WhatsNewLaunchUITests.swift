//
//  WhatsNewLaunchUITests.swift
//  YalaUITests
//
//  Las Novedades salen SOLO al actualizar (decisión de Jürgen, 16-oct-2026). Dos recorridos de dos
//  arranques cada uno sobre el mismo store: el segundo arranque lleva `lastSeenAppVersion: "keep"`
//  para leer lo que dejó el primero, en vez de la versión actual que el arranque uitest pone por defecto.
//  La lógica de versiones (hotfix, ya vista) está en `YalaTests/WhatsNewLaunchLogicTests`.
//

import XCTest

final class WhatsNewLaunchUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Un usuario de 2.1 que actualiza ve la hoja de 2.2 con sus cuatro tarjetas, y no vuelve a verla
    /// (card `tablero-la-hoja-de-novedades-de-2-2-pasa-a-cuatr-mbcb`).
    func test_updateFrom2_1_showsTheSheetOnce() {
        let app = XCUIApplication()
        app.launchForUITest(lastSeenAppVersion: "2.1.3")

        let title = app.staticTexts["whats_new_title"]
        XCTAssertTrue(title.waitForExistence(timeout: 60), "La hoja de Novedades no salió al venir de 2.1.3.")
        XCTAssertEqual(app.staticTexts["whats_new_feature_title_0"].label, "Tu tarjeta en dos monedas")
        XCTAssertEqual(app.staticTexts["whats_new_feature_title_1"].label, "Pregúntale a Siri")
        XCTAssertEqual(app.staticTexts["whats_new_feature_title_2"].label, "Anotar en menos toques")
        XCTAssertEqual(app.staticTexts["whats_new_feature_title_3"].label, "Lo que te falta pagar")
        XCTAssertFalse(app.staticTexts["whats_new_feature_title_4"].exists, "La hoja de 2.2 tiene cuatro tarjetas.")

        app.buttons["whats_new_continue"].tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 10), "La hoja no se cerró con Continuar.")
        app.terminate()

        app.launchForUITest(reset: false, seed: nil, lastSeenAppVersion: "keep")
        XCTAssertTrue(app.waitForUITestReady(), "La app no llegó a uitest_ready en el segundo arranque.")
        XCTAssertFalse(
            title.waitForExistence(timeout: 8),
            "La hoja volvió a salir: cerrarla no dejó la versión como vista."
        )
    }

    /// Quien actualiza desde la 2.0.4 con la oferta de prueba PENDIENTE (la deja un alta por «Restaurar») ve Novedades en el
    /// PRIMER arranque, no en el segundo (QA guiado del 19-oct, ticket `whats-new-yields-to-a-pending-trial-offer-after-updating`).
    /// Y Novedades no vuelve en el arranque siguiente.
    func test_updateFrom2_0_withATrialOfferPending_showsTheSheetOnTheFirstLaunch() {
        let app = XCUIApplication()
        app.launchForUITest(lastSeenAppVersion: "2.0.4", pendingTrialOffer: true)

        let title = app.staticTexts["whats_new_title"]
        XCTAssertTrue(title.waitForExistence(timeout: 60),
                      "Con la oferta pendiente, Novedades no salió en el primer arranque tras actualizar.")
        app.buttons["whats_new_continue"].tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 10), "La hoja no se cerró con Continuar.")
        app.terminate()

        // Con precios: desde la 2.2 la oferta solo sale si se sabe que la cuenta aún tiene la prueba (UX 2.2 · L17-5), y
        // en `xcodebuild test` la tienda de pruebas no da precios.
        app.launchForUITest(reset: false, seed: nil, lastSeenAppVersion: "keep", fakePrices: true)
        XCTAssertTrue(app.waitForUITestReady(), "La app no llegó a uitest_ready en el segundo arranque.")
        XCTAssertFalse(title.waitForExistence(timeout: 8), "Novedades volvió a salir en el segundo arranque.")
        // Y la oferta no se pierde: sale en este arranque, porque su marca solo se borra al presentarse (y su momento
        // ya llegó: el seam deja las dos marcas, UX 2.2 · L1-12).
        XCTAssertTrue(app.buttons["trial_offer_dismiss"].waitForExistence(timeout: 30),
                      "La oferta de prueba pendiente no salió en el arranque siguiente.")
    }

    /// Un dispositivo que arranca en el onboarding estrena Yala en esta versión: ya con el onboarding
    /// hecho, el arranque siguiente no saca Novedades.
    func test_freshInstall_neverShowsTheSheet() {
        let app = XCUIApplication()
        app.launchForUITest(skipOnboarding: false, seed: nil, onboarding: true, lastSeenAppVersion: "none")
        XCTAssertTrue(
            app.textFields["onboarding_name_field"].waitForExistence(timeout: 60),
            "No montó el onboarding."
        )
        app.terminate()

        app.launchForUITest(reset: false, seed: nil, lastSeenAppVersion: "keep")
        XCTAssertTrue(app.waitForUITestReady(), "La app no llegó a uitest_ready tras el onboarding.")
        XCTAssertFalse(
            app.staticTexts["whats_new_title"].waitForExistence(timeout: 8),
            "La hoja de Novedades salió en una instalación nueva."
        )
    }
}
