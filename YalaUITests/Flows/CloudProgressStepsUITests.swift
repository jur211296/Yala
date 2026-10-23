//
//  CloudProgressStepsUITests.swift
//  YalaUITests
//
//  «Dónde viven tus datos» mientras se activa la nube o se vuelve a iCloud: pasos con su cifra (opción B del lienzo,
//  decisión de Jürgen del 2026-10-22; ticket `cloud-progress-shows-real-steps-and-counts`, cards igt9, ppxk y 27z3).
//
//  **El seam finge la ENTRADA** (`-uitest-cloud-progress`): la fase sale de la lectura del journal del controller y la cifra
//  y la espera de lo que el runner publicaría, porque el simulador no tiene iCloud ni puede llevar una migración real hasta
//  ahí. Qué pasos se pintan, cuál está en marcha y qué botones salen lo deciden el controller y `CloudProgressStepsLogic`.
//  Cada caso deja su captura (las de la aprobación de Jürgen salen de aquí).
//
//  **Scheme `Yala Dev`**, como el gate y el CI: con `Yala` la fila «¿Dónde viven tus datos?» no existe bajo `-uitest`.
//

import XCTest

final class CloudProgressStepsUITests: XCTestCase {
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

    /// Abre «¿Dónde viven tus datos?» con el escenario fingido y espera la tarjeta de pasos.
    private func openStorage(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", cloudProgress: scenario)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()
        let row = scrollTo(app, "storage_settings_row")
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No aparece la fila «¿Dónde viven tus datos?» (¿scheme `Yala`?).")
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["storage_steps"].waitForExistence(timeout: 10),
                      "No salió la tarjeta de pasos con el escenario \(scenario).")
        return app
    }

    private func step(_ app: XCUIApplication, _ kind: String, _ state: String) -> XCUIElement {
        app.descendants(matching: .any)["storage_step_\(kind)_\(state)"]
    }

    private func expectSteps(_ app: XCUIApplication, _ expected: [(String, String)], file: StaticString = #filePath,
                             line: UInt = #line) {
        for (kind, state) in expected {
            XCTAssertTrue(step(app, kind, state).exists, "falta el paso \(kind) en estado \(state)", file: file, line: line)
        }
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func countLabel(_ app: XCUIApplication) -> String {
        app.staticTexts["storage_step_count"].firstMatch.label
    }

    /// igt9: subiendo, el paso en marcha lleva la cifra real («650 de 1.537») y lo anterior sale hecho. Sin «Retomar» (el
    /// lienzo B no lo lleva) y con «Cancelar la activación».
    func test_upload_showsTheStepsWithTheRealCount() {
        let app = openStorage("upload")
        expectSteps(app, [("connect", "done"), ("prepare", "done"), ("upload", "active"), ("confirm", "pending")])
        let count = countLabel(app)
        XCTAssertTrue(count.contains("650") && count.contains("537"), "la cifra no es la de la subida: «\(count)»")
        XCTAssertTrue(app.staticTexts["storage_steps_footer"].exists)
        XCTAssertFalse(app.buttons["storage_resume_button"].exists, "«Retomar» no está en el lienzo B")
        XCTAssertTrue(app.buttons["storage_cancel_migration_button"].exists)
        attach(app, "despues-1-activar-subiendo")
    }

    /// ppxk: mientras la app espera a que iCloud termine de traer datos, el paso lo dice con su nombre y su explicación, y
    /// «Cancelar la activación» se puede tocar.
    func test_waitingForICloud_saysSo_andCancelIsAvailable() {
        let app = openStorage("waitingICloud")
        expectSteps(app, [("connect", "done"), ("waitICloud", "active"), ("upload", "pending"), ("confirm", "pending")])
        XCTAssertTrue(app.staticTexts["storage_step_detail_waitICloud"].exists, "falta la explicación de la espera")
        let cancel = app.buttons["storage_cancel_migration_button"]
        XCTAssertTrue(cancel.exists)
        XCTAssertTrue(cancel.isEnabled, "durante la espera a iCloud la activación se puede cancelar")
        attach(app, "despues-2-activar-esperando-icloud")
    }

    /// 27z3: en el último paso de la vuelta, mientras la cifra no baja, iCloud está revisando lo que ya tiene — y se dice.
    func test_reverseReview_saysICloudIsChecking_withThePendingCount() {
        let app = openStorage("reverseReview")
        expectSteps(app, [("bring", "done"), ("review", "active"), ("uploadToICloud", "pending")])
        XCTAssertTrue(app.staticTexts["storage_step_detail_review"].exists)
        XCTAssertTrue(countLabel(app).contains("448"))
        XCTAssertTrue(app.buttons["storage_cancel_reverse_button"].exists)
        attach(app, "despues-3-volver-icloud-revisa")
    }

    /// 27z3: en cuanto la cifra baja, el paso en marcha es subir, con lo que falta.
    func test_reverseUpload_showsWhatIsLeft() {
        let app = openStorage("reverseUpload")
        expectSteps(app, [("bring", "done"), ("review", "done"), ("uploadToICloud", "active")])
        XCTAssertTrue(countLabel(app).contains("212"))
        attach(app, "despues-4-volver-icloud-subiendo")
    }

    /// 27z3: recién confirmada la vuelta, con el journal aún en «nube activa», la pantalla ya dice qué hace (antes:
    /// «Volver a iCloud» apagado y nada más).
    func test_reverseJustConfirmed_showsTheStepsBeforeTheJournalMoves() {
        let app = openStorage("reverseStarting")
        expectSteps(app, [("waitICloud", "active"), ("bring", "pending"), ("review", "pending"),
                          ("uploadToICloud", "pending")])
        XCTAssertFalse(app.buttons["storage_revert_button"].exists, "la tarjeta de volver se sustituye por los pasos")
        attach(app, "despues-5-volver-icloud-recien-confirmado")
    }
}
