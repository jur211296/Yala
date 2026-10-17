//
//  AIConsentAlertUITests.swift
//  YalaUITests
//
//  El aviso «Yala lo apunta por ti» (voz y foto) se presenta desde un ancla de fondo con su propio tinte, para que el
//  texto de «Activar» salga blanco (pulido del 2026-10-17). Este caso fija que, con esa ancla, el aviso sigue saliendo
//  al tocar Voz en el Panel sin consentimiento, con sus tres salidas, sin nombrar al proveedor de IA, y que «Cancelar»
//  lo cierra sin abrir la grabación. El color no se puede aserjar aquí: lo fija `AlertActionIndigoParityTests`.
//

import XCTest

final class AIConsentAlertUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_voicePillWithoutConsent_showsTheNotice_withoutTheProviderName_andCancelCloses() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let voice = app.buttons["panel_action_voice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 10), "No apareció la píldora de Voz del Panel.")
        voice.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "El aviso de voz y foto no salió desde su ancla de fondo.")
        // Activar · Política de privacidad · Cancelar. En XCUITest los botones de una alerta pueden salir duplicados en el
        // árbol, así que se cuentan como mínimo.
        XCTAssertGreaterThanOrEqual(alert.buttons.count, 3, "El aviso perdió alguna de sus tres salidas.")
        let providerNamed = alert.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'OpenAI'")).count
        XCTAssertEqual(providerNamed, 0, "El aviso vuelve a nombrar al proveedor de IA.")

        // El botón de cancelar de una alerta lleva el id del sistema `cancel-button`; si no, el último.
        let cancel = alert.buttons["cancel-button"].exists
            ? alert.buttons["cancel-button"]
            : alert.buttons.element(boundBy: alert.buttons.count - 1)
        cancel.tap()

        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: alert)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "«Cancelar» no cerró el aviso.")
        // Aceptar abre la hoja de voz a los 500 ms; con «Cancelar» no debe aparecer su botón de cerrar.
        XCTAssertFalse(app.buttons["voice_close"].waitForExistence(timeout: 2), "Cancelar abrió la grabación igualmente.")
    }
}
