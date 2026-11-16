//
//  WipeDataGroupRowsInSessionUITests.swift
//  YalaUITests
//
//  Ticket `wipe-data-group-rows-return-only-on-the-next-cold-launch`: tras «Vaciar datos» con grupos, los gastos de grupo
//  vuelven a Registros en la MISMA sesión, sin cerrar y abrir Yala. Hasta el 2026-11-06 la convergencia solo la consumía
//  el arranque, así que Registros salía vacío hasta el siguiente arranque en frío.
//
//  **Qué discrimina:** el perfil `grupos` tiene gastos de grupo y, tras vaciar, ningún movimiento personal. Con el código
//  de antes, Registros abierto por enlace (sin relanzar: `XCUIDevice.shared.system.open`, no `app.open`, que relanza)
//  sale sin ninguna fila; con el arreglo, con los gastos de grupo de vuelta.
//

import XCTest

final class WipeDataGroupRowsInSessionUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.buttons[identifier]
        var tries = 0
        while !element.isHittable && tries < 14 {
            app.swipeUp()
            tries += 1
        }
        return element
    }

    /// Abre un enlace como lo haría otra app: la app que ya corre lo recibe, sin relanzar.
    private func openFromOutside(_ app: XCUIApplication, _ link: String) {
        guard let url = URL(string: link) else { return XCTFail("URL inválida: \(link)") }
        XCUIDevice.shared.system.open(url)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.alerts.buttons.element(boundBy: 1)
        if springboard.alerts.firstMatch.waitForExistence(timeout: 3), open.exists { open.tap() }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "El enlace no trajo Yala delante.")
    }

    func test_wipeData_groupExpensesComeBackToRecords_withoutRelaunching() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "grupos")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()

        let resetRow = scrollTo(app, "profile_security_reset_data")
        XCTAssertTrue(resetRow.waitForExistence(timeout: 5), "No apareció «Vaciar datos».")
        resetRow.tap()
        let start = app.buttons["wipe_data_start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "No apareció «Vaciar mis datos».")
        start.tap()
        let confirm = app.buttons["destructive_scope_confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "No apareció la hoja de alcance de Vaciar.")
        confirm.tap()
        let final = app.alerts.buttons["Vaciar definitivamente"].firstMatch
        XCTAssertTrue(final.waitForExistence(timeout: 5), "No salió «¿Seguro? Esto es definitivo.».")
        final.tap()

        // El aviso de empezar de cero: el borrado terminó y la persona sigue dentro, en el Panel. No el «Crea tu primera
        // cuenta»: con los gastos de grupo de vuelta el Panel ya no está vacío (la cuenta de grupos tiene saldo).
        let toast = app.descendants(matching: .any)["positive_toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 15), "Tras vaciar no salió el aviso de empezar de cero.")

        openFromOutside(app, "yaladev://records")
        let row = app.descendants(matching: .any)["record_row"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30), """
            Tras «Vaciar datos» los gastos de grupo no volvieron a Registros sin reabrir Yala: la convergencia sigue
            esperando al arranque siguiente.
            """)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "registros-tras-vaciar"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
