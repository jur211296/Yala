//
//  ArchivedAccountKeepsHistoryUITests.swift
//  YalaUITests
//
//  Archivar una cuenta conserva su historial (opción A del 8-oct, adelantada a 2.3 en la decisión 6 del 9-nov; card
//  «Archivar una cuenta: decidir si oculta su historial…»). Hasta entonces archivar desde el formulario encendía
//  «Excluir de las estadísticas», y con él los movimientos de la cuenta desaparecían de Registros y de los totales de
//  todos los períodos.
//
//  El caso es el de la semilla `cuenta-con-movimientos`: se archiva «Efectivo QA», que tiene dos gastos (Taxi y
//  Teléfono), y Registros los sigue enseñando. Las capturas se guardan siempre (`keepAlways`): son la evidencia del
//  antes y el después.
//

import XCTest

final class ArchivedAccountKeepsHistoryUITests: XCTestCase {
    private let account = "Efectivo QA"

    /// La pestaña Registros en la barra (por defecto no está). Entre comillas de plist: ver `LoadTimesUITests`.
    private static let recordsTabArgs = [
        "-tabBarConfiguration", #""{\"activeTabs\":[\"panel\",\"statistics\",\"records\"]}""#,
    ]

    override func setUp() {
        super.setUp()
        // Sigue tras un fallo para que el recorrido entero deje sus capturas (sin el arreglo, el «antes»).
        continueAfterFailure = true
    }

    func test_archivingAnAccount_keepsExcludeOff_andItsRecordsStayInRegistros() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "cuenta-con-movimientos", extraArguments: Self.recordsTabArgs)
        guard app.waitForUITestReady() else { return XCTFail("uitest_ready ausente — bootstrap/seed no completó.") }
        snapshot(app, "1-panel-antes-de-archivar")

        app.openProfile()
        app.openSettingsSection("profile_accounts")
        let row = app.buttons["accounts_row_\(account)"]
        guard row.waitForExistence(timeout: 5) else { return XCTFail("El seed no dejó «\(account)».") }
        row.tap()

        let archive = app.switches["account_archive_toggle"]
        guard archive.waitForExistence(timeout: 5) else { return XCTFail("No apareció el interruptor de archivar.") }
        var swipes = 0
        while !archive.isHittable && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(archive.waitForHittable(timeout: 3), "El interruptor de archivar no quedó a la vista.")
        archive.switches.firstMatch.tap()

        // Archivar ya no enciende «Excluir»: con la cuenta archivada ese interruptor no se enseña (no haría nada), y el
        // aviso dice lo que pasa de verdad.
        let notice = app.staticTexts["account_archive_keeps_history_notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5), "Archivar no dijo que el historial se queda.")
        snapshot(app, "2-formulario-al-archivar")
        let exclude = app.switches["account_exclude_stats_toggle"]
        XCTAssertFalse(exclude.exists && exclude.value as? String == "1", "Archivar encendió «Excluir de las estadísticas».")

        // Guardar vuelve unas veces a Ajustes › Cuentas, con la hoja de Ajustes aún abierta, y otras al Panel (medido el
        // 2026-11-11, dos corridas). Con la hoja abierta el Panel sigue ENTERO en el árbol de accesibilidad por debajo,
        // así que nada de lo que sigue se afirma hasta tener el Panel alcanzable de verdad.
        app.buttons["toolbar_save_button"].tap()
        let avatar = app.buttons["profile_avatar"]
        if !avatar.waitForHittable(timeout: 4) {
            // La barra de Cuentas, no la del Panel de debajo, que también está en el árbol.
            let back = app.navigationBars["Cuentas"].buttons.firstMatch
            XCTAssertTrue(back.waitForHittable(timeout: 5), "No quedó a mano el «‹» de Cuentas.")
            back.tap()
            let close = app.buttons["Cerrar"].firstMatch
            XCTAssertTrue(close.waitForHittable(timeout: 5), "No quedó a mano «Cerrar» en Ajustes.")
            close.tap()
        }
        XCTAssertTrue(avatar.waitForHittable(timeout: 10), "El Panel no quedó a la vista.")

        // El Panel sigue contando lo que salió de la cuenta archivada: Taxi 25 + Teléfono 33. Sin el arreglo, «Salió S/ 0.00».
        let expense = app.buttons["panel_hero_expense_pill"]
        XCTAssertTrue(expense.waitForHittable(timeout: 10), "No quedó a la vista el gasto del hero del Panel.")
        let counted = NSPredicate(format: "label CONTAINS %@", "58.00")
        wait(for: [expectation(for: counted, evaluatedWith: expense)], timeout: 10)
        snapshot(app, "3-panel-tras-archivar")

        // Sus gastos siguen en Registros.
        app.selectTab(.records)
        let taxi = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Taxi")).firstMatch
        XCTAssertTrue(taxi.waitForExistence(timeout: 10), "El gasto «Taxi» de la cuenta archivada desapareció de Registros.")
        XCTAssertTrue(taxi.waitForHittable(timeout: 5), "«Taxi» está en el árbol pero no a la vista en Registros.")
        snapshot(app, "4-registros-tras-archivar")
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        // Un respiro para que la pantalla termine de pintar (recálculo del Panel o de Registros) antes de la foto.
        _ = app.wait(for: .runningForeground, timeout: 1.5)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
