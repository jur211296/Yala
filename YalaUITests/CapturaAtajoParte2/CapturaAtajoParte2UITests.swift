//
//  CapturaAtajoParte2UITests.swift
//  YalaUITests
//
//  Atajo del banco B2 (Ajustes › «Avisos del banco») y S2 de pagos recurrentes (avisos de precio y de baja en Pagos
//  planificados), encargo del 22-nov-2026.
//
//  S2 va con `-uitest-seed-s2-changes` (`DevSeedRecurringChanges`): Disney+ que subió de precio y Spotify que dejó de
//  cobrarse. El fixture discrimina: sin la detección de S2, ninguna de las dos tarjetas existe.
//

import XCTest

final class CapturaAtajoParte2UITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// S2: las dos tarjetas salen; «Actualizar» pasa Disney+ al precio nuevo y su tarjeta se va; «Sigue activo» calla la
    /// de Spotify.
    func test_scheduledPayments_priceAndStoppedCards_answerInOneTap() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", deeplink: "scheduledPayments", extraArguments: ["-uitest-seed-s2-changes"])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let price = app.descendants(matching: .any)["recurring_change_card_price"]
        let stopped = app.descendants(matching: .any)["recurring_change_card_stopped"]
        XCTAssertTrue(price.waitForExistence(timeout: 20), "No salió la tarjeta «Disney+ subió…».")
        XCTAssertTrue(stopped.exists, "No salió la tarjeta «¿Dejaste de pagar Spotify?».")

        let update = app.buttons["recurring_change_update"]
        XCTAssertTrue(update.waitForExistence(timeout: 5))
        update.tap()
        XCTAssertTrue(price.waitForNonExistence(timeout: 10), "La tarjeta de precio sigue tras «Actualizar».")
        XCTAssertTrue(stopped.exists, "«Actualizar» se llevó también la tarjeta de Spotify.")

        let stillActive = app.buttons["recurring_change_still_active"]
        XCTAssertTrue(stillActive.waitForExistence(timeout: 5))
        stillActive.tap()
        XCTAssertTrue(stopped.waitForNonExistence(timeout: 10), "La tarjeta de Spotify sigue tras «Sigue activo».")
        app.terminate()
    }

    /// B2: la fila de Ajustes abre «¿De qué banco?»; un banco enseña su estado, la guía y la prueba con un aviso de
    /// ejemplo, que lee el monto y el comercio sin guardar nada. Desde el 23-nov-2026 abrirlo no lo activa: «Aún no está
    /// activo» (la activación la fija `AvisosDelBancoActivacionUITests`).
    func test_bankNotices_rowOpensTheBank_andTheSampleIsRead() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()
        XCTAssertTrue(app.buttons["profile_accounts"].waitForExistence(timeout: 10), "No se abrió Ajustes.")

        let row = app.buttons["profile_bank_notices"]
        var attempts = 0
        while !(row.exists && row.isHittable) && attempts < 10 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No apareció la fila «Avisos del banco».")
        row.tap()

        let bcp = app.buttons["bank_notices_bank_bcp"]
        XCTAssertTrue(bcp.waitForExistence(timeout: 10), "No se abrió «¿De qué banco?» con el BCP.")
        bcp.tap()

        let status = app.staticTexts["bank_notice_status_title"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 10), "La pantalla del BCP no enseña su estado.")
        XCTAssertTrue(status.label.hasPrefix("Aún no está activo"), "Estado: \(status.label)")

        let probar = app.buttons["bank_notice_test_button"]
        var scrolls = 0
        while !(probar.exists && probar.isHittable) && scrolls < 10 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(probar.waitForExistence(timeout: 5), "No apareció «Probar».")
        probar.tap()
        let result = app.descendants(matching: .any)["bank_notice_test_result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10), "La prueba no enseñó lo que leyó.")
        XCTAssertTrue(result.label.contains("TAMBO+ MIRAFLORES"), "Resultado: \(result.label)")
        app.terminate()
    }
}
