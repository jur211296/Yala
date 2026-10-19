//
//  GroupBatchLeaveUITests.swift
//  YalaUITests
//
//  Batch "salir de todos mis grupos" (D10, §2.1). Desde L19-12 (decisión de Jürgen, 2026-10-18) vive en Ajustes de
//  Grupos —el engranaje de la pestaña Grupos— y no en «Vaciar datos», con botón secundario y una confirmación que
//  nombra los grupos. Su ejecución real (leave/transfer) exige backend, imposible en el simulador — es device/TestFlight.
//  El seam `-uitest-groups-batch-demo` (#if DEBUG, inerte en release) fuerza la oferta y hace que la vista del batch
//  muestre un RESULTADO determinista fabricado; `-uitest-groups-batch-running` la deja EN CURSO.
//  Los casos SIN seam fijan la CONDICIÓN real de la oferta (grupos vivos y cero deuda), que un seam dejaría ciega
//  (`testing.md`).
//  Convenciones: sin sleeps, scheme Yala Dev, targeting por accessibilityIdentifier (ver CLAUDE.md).
//

import XCTest

final class GroupBatchLeaveUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Adjunta una captura al `.xcresult` (evidencia visual de QA reproducible en CI, sin depender de la
    /// automatización UI del MCP). `keepAlways` para que sobreviva a un test en verde.
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Aterriza en la pestaña Grupos (deeplink) y abre sus Ajustes.
    private func openGroupsSettings(seed: String, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: seed, deeplink: "groups", extraArguments: extraArguments)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let gear = app.buttons["groups_global_settings_button"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10), "No apareció el engranaje de Ajustes de Grupos.")
        gear.tap()
        XCTAssertTrue(app.switches["groups_bridge_toggle"].waitForExistence(timeout: 5), "Ajustes de Grupos no montó.")
        return app
    }

    /// El botón de salir de todos, bajando hasta él si hace falta. `nil` si no está.
    private func leaveAllButton(_ app: XCUIApplication) -> XCUIElement {
        let button = app.buttons["groups_settings_leave_all"]
        var swipes = 0
        while button.exists && !button.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        return button
    }

    /// Toca «Salir de todos mis grupos» y devuelve la alerta de confirmación ya en pantalla.
    private func confirmationAfterTapping(_ app: XCUIApplication) -> XCUIElement {
        let button = leaveAllButton(app)
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Ajustes de Grupos no ofrece «Salir de todos mis grupos».")
        button.tap()
        let alert = app.alerts["¿Salir de todos tus grupos?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Salir de todos empezó sin preguntar (L19-12).")
        return alert
    }

    /// Con el demo hook: Ajustes de Grupos ofrece salir de todos → la confirmación nombra los grupos → la vista del
    /// batch con el resultado (salidos/transferidos/necesitan-tu-decisión) → «Listo» la cierra.
    /// `grupos-saldado`: el lote salta los grupos con saldo, así que solo sin deudas tiene grupos que nombrar.
    func test_batchLeave_offerConfirmationAndResultFlow() {
        let app = openGroupsSettings(seed: "grupos-saldado", extraArguments: ["-uitest-groups-batch-demo"])

        let alert = confirmationAfterTapping(app)
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Viaje a")).firstMatch.exists,
                      "La confirmación no nombra los grupos que el lote va a tocar.")
        attachScreenshot(app, name: "batch_leave_confirmation")
        alert.buttons["Salir de todos"].firstMatch.tap()

        let done = app.buttons["batch_leave_done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5),
                      "No apareció 'batch_leave_done' — la vista de resultado del batch no se presentó.")
        XCTAssertTrue(app.buttons["batch_leave_view_groups"].exists,
                      "No apareció 'batch_leave_view_groups' — la lista 'necesitan tu decisión' del demo.")
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5), "La vista del batch no se cerró tras 'Listo'.")
    }

    /// «Cancelar» en la confirmación no empieza nada: ni la vista del batch, ni ninguna salida.
    func test_batchLeave_cancelInTheConfirmation_startsNothing() {
        let app = openGroupsSettings(seed: "grupos", extraArguments: ["-uitest-groups-batch-demo"])

        let alert = confirmationAfterTapping(app)
        alert.buttons["Cancelar"].firstMatch.tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), "La confirmación no se cerró con «Cancelar».")
        XCTAssertFalse(app.buttons["batch_leave_done"].exists, "«Cancelar» empezó el lote igual.")
        XCTAssertFalse(app.buttons["batch_leave_stop"].exists, "«Cancelar» empezó el lote igual.")
    }

    /// La CONDICIÓN, sin seam: con grupos y cero deuda (`grupos-saldado`) se ofrece.
    func test_leaveAll_offered_withGroupsAndNoDebt() {
        let app = openGroupsSettings(seed: "grupos-saldado")
        XCTAssertTrue(leaveAllButton(app).waitForExistence(timeout: 5),
                      "Con grupos y sin saldos, Ajustes de Grupos no ofrece «Salir de todos mis grupos».")
    }

    /// Y su control: con saldos pendientes (`grupos`) no se ofrece — cada grupo con saldo se sale a mano.
    func test_leaveAll_notOffered_withOutstandingBalances() {
        let app = openGroupsSettings(seed: "grupos")
        XCTAssertFalse(leaveAllButton(app).exists,
                       "Con saldos pendientes no debe ofrecerse salir de todos (el lote no los salda).")
    }

    /// D3 — botón «Detener»: con el batch EN CURSO la vista lo ofrece; el tap recorre la mecánica REAL
    /// (`requestStop` → `stopPending` → marcador de parada) y aterriza en el resultado honesto.
    func test_batchLeave_stopButton_endsInHonestResult() {
        let app = openGroupsSettings(seed: "grupos", extraArguments: ["-uitest-groups-batch-running"])

        let alert = confirmationAfterTapping(app)
        alert.buttons["Salir de todos"].firstMatch.tap()

        let stop = app.buttons["batch_leave_stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5),
                      "No apareció 'batch_leave_stop' — el botón Detener no se presentó con el batch en curso.")
        XCTAssertFalse(app.buttons["batch_leave_done"].exists,
                       "'batch_leave_done' no debe existir mientras el batch corre.")
        attachScreenshot(app, name: "batch_leave_running_with_stop")
        stop.tap()

        let done = app.buttons["batch_leave_done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5),
                      "No apareció 'batch_leave_done' — detener no llevó al resultado (¿spinner clavado?).")
        XCTAssertTrue(stop.waitForNonExistence(timeout: 5),
                      "'batch_leave_stop' sigue visible tras detener — la vista no pasó al resultado.")
        attachScreenshot(app, name: "batch_leave_stopped_result")
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5), "La vista del batch no se cerró tras 'Listo'.")
    }
}
