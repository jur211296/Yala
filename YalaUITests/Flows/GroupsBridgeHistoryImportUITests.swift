//
//  GroupsBridgeHistoryImportUITests.swift
//  YalaUITests
//
//  Ticket `bridge-history-import-is-only-offered-when-something-was-already-bridged` (lote 2.3 de Grupos, 10-nov).
//  En Ajustes de Grupos, encender «Registrar gastos de grupos en mis cuentas personales» por primera vez —con gastos de
//  grupo y nada reflejado todavía— no ofrecía importar el historial: la hoja solo salía si ya había movimientos
//  reflejados. La semilla `grupos` no pasa sus gastos por el puente (solo la venta, que aquí no se siembra), así que con
//  el puente apagado al arrancar es justo ese caso.
//

import XCTest

final class GroupsBridgeHistoryImportUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_turningTheBridgeOnForTheFirstTime_offersToImportTheHistory() {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true, seed: "grupos", deeplink: "groups",
            extraArguments: ["-bridgeGroupExpensesToPersonalAccounts", "NO"]
        )
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let settings = app.buttons["groups_global_settings_button"]
        XCTAssertTrue(settings.waitForExistence(timeout: 30), "No apareció Ajustes de Grupos.")
        settings.tap()

        let toggle = app.switches["groups_bridge_toggle"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "No apareció el interruptor del puente.")
        XCTAssertEqual(toggle.value as? String, "0", "Control: el puente no arrancó apagado.")
        toggle.switches.firstMatch.tap()

        let importAll = app.staticTexts["Importar todo el historial"].firstMatch
        XCTAssertTrue(importAll.waitForExistence(timeout: 10),
                      "Encender el puente por primera vez no ofreció importar el historial.")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "puente-importar-historial"
        shot.lifetime = .keepAlways
        add(shot)

        // «Continuar» con la opción de siempre («Empezar desde ahora») cierra la hoja. No se afirma el interruptor después:
        // el argumento de arranque `-bridgeGroupExpensesToPersonalAccounts NO` manda sobre lo que la app guarda, así que
        // en este test lee «apagado» pase lo que pase.
        app.buttons["Continuar"].firstMatch.tap()
        XCTAssertTrue(importAll.waitForNonExistence(timeout: 10), "La hoja no se cerró.")
    }
}
