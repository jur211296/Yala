//
//  GroupBatchLeaveUITests.swift
//  YalaUITests
//
//  Batch "salir de todos mis grupos" (D10, §2.1). El flujo es DARK (groupsBackendEnabled OFF) y su ejecución
//  real (leave/transfer) exige backend/iCloud, imposibles en el simulador — es device/TestFlight. El seam
//  `-uitest-groups-batch-demo` (#if DEBUG, inerte en release) fuerza que la hoja de Vaciar OFREZCA
//  «También salir de mis grupos» y hace que la vista del batch muestre un RESULTADO determinista fabricado.
//  Estos tests cubren el CABLEADO/UI (hoja → secundaria → vista dedicada → resultado); la lógica del
//  orquestador va por unit tests (GroupBatchLeaveOrchestratorTests, kill-sim).
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

    /// Baja por el ScrollView de Ajustes hasta que una fila sea hittable (sin sleeps, tope de intentos).
    private func scrollTo(_ id: String, in app: XCUIApplication) -> XCUIElement {
        let el = app.buttons[id]
        var tries = 0
        while !el.isHittable && tries < 12 {
            app.swipeUp()
            tries += 1
        }
        return el
    }

    /// Con el demo hook: la hoja de Vaciar ofrece «También salir de mis grupos» → abre la vista del batch con
    /// el resultado (salidos/transferidos/necesitan-tu-decisión) → «Listo» la cierra.
    func test_batchLeave_offerAndResultFlow() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", extraArguments: ["-uitest-groups-batch-demo"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        let resetRow = scrollTo("profile_security_reset_data", in: app)
        XCTAssertTrue(resetRow.waitForExistence(timeout: 5), "No apareció la fila 'Vaciar mis datos'.")
        resetRow.tap()

        let startBtn = app.buttons["wipe_data_start"]
        XCTAssertTrue(startBtn.waitForExistence(timeout: 5), "No apareció el botón 'Vaciar mis datos'.")
        startBtn.tap()

        // La hoja de alcance ofrece la secundaria del batch (forzada por el demo hook).
        let offer = app.buttons["wipe_leave_groups"]
        XCTAssertTrue(offer.waitForExistence(timeout: 5),
                      "No apareció 'wipe_leave_groups' — la oferta del batch D10 no se presentó.")
        offer.tap()

        // La vista dedicada del batch muestra el resultado determinista (demo) + botón «Listo».
        let done = app.buttons["batch_leave_done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5),
                      "No apareció 'batch_leave_done' — la vista de resultado del batch no se presentó.")
        // El demo incluye un grupo «necesita tu decisión» → el desvío «Ver mis grupos» está presente.
        XCTAssertTrue(app.buttons["batch_leave_view_groups"].exists,
                      "No apareció 'batch_leave_view_groups' — la lista 'necesitan tu decisión' del demo.")
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5), "La vista del batch no se cerró tras 'Listo'.")
    }

    /// Sin el hook (flag OFF, DARK): la hoja de Vaciar NO ofrece la secundaria del batch — byte-idéntico al
    /// comportamiento pre-D10. Ancla la garantía de que la superficie es DARK en prod/sim.
    func test_batchLeave_notOffered_whenFlagOff() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        let resetRow = scrollTo("profile_security_reset_data", in: app)
        XCTAssertTrue(resetRow.waitForExistence(timeout: 5), "No apareció la fila 'Vaciar mis datos'.")
        resetRow.tap()

        let startBtn = app.buttons["wipe_data_start"]
        XCTAssertTrue(startBtn.waitForExistence(timeout: 5), "No apareció el botón 'Vaciar mis datos'.")
        startBtn.tap()

        // La hoja aparece (botón de confirmación) pero SIN la secundaria del batch.
        let confirm = app.buttons["destructive_scope_confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "No apareció la hoja de alcance de Vaciar.")
        XCTAssertFalse(app.buttons["wipe_leave_groups"].exists,
                       "'wipe_leave_groups' NO debe aparecer con el flag OFF (DARK).")
    }

    /// D3 — botón «Detener»: con el batch EN CURSO la vista lo ofrece; el tap recorre la mecánica REAL
    /// (`requestStop` → `stopPending` → marcador de parada) y aterriza en el resultado honesto, que ya NO
    /// muestra el spinner y sí la fila «Sin procesar».
    func test_batchLeave_stopButton_endsInHonestResult() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", extraArguments: ["-uitest-groups-batch-running"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        let resetRow = scrollTo("profile_security_reset_data", in: app)
        XCTAssertTrue(resetRow.waitForExistence(timeout: 5), "No apareció la fila 'Vaciar mis datos'.")
        resetRow.tap()

        let startBtn = app.buttons["wipe_data_start"]
        XCTAssertTrue(startBtn.waitForExistence(timeout: 5), "No apareció el botón 'Vaciar mis datos'.")
        startBtn.tap()

        let offer = app.buttons["wipe_leave_groups"]
        XCTAssertTrue(offer.waitForExistence(timeout: 5), "No apareció la oferta del batch D10.")
        offer.tap()

        // Batch EN CURSO → la vista ofrece «Detener» (y aún no hay resultado).
        let stop = app.buttons["batch_leave_stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5),
                      "No apareció 'batch_leave_stop' — el botón Detener no se presentó con el batch en curso.")
        XCTAssertFalse(app.buttons["batch_leave_done"].exists,
                       "'batch_leave_done' no debe existir mientras el batch corre.")
        attachScreenshot(app, name: "batch_leave_running_with_stop")
        stop.tap()

        // Tras detener: resultado honesto — el botón de parada desaparece y aparece el cierre.
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
