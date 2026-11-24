//
//  PagosChipsVistaCapturasUITests.swift
//  YalaUITests
//
//  Capturas de Pagos planificados (encargo del 24-nov-2026: chips de vista con texto, ícono de subcategoría cuando no
//  hay logo y el enlace del pie pegado al final). No fija nada: se corre a mano con `TEST_RUNNER_CAPTURA_DIR=<carpeta>`.
//  Opcionales: `TEST_RUNNER_CAPTURA_TEXTO` (categoría de texto), `TEST_RUNNER_CAPTURA_OSCURO=1`,
//  `TEST_RUNNER_CAPTURA_GIRADO=1` y `TEST_RUNNER_CAPTURA_PREFIJO`. Sin la carpeta, se salta.
//
//  Pestaña «Todos» (los 9 pagos de la semilla `minimal`: muchos) y «Suscripciones» (4: pocos), mes actual y el
//  siguiente. Las propuestas van apagadas para que salga el enlace del pie («· Apagado»).
//

import XCTest

final class PagosChipsVistaCapturasUITests: XCTestCase {

    private var folder: String?

    override func setUpWithError() throws {
        continueAfterFailure = true
        folder = ProcessInfo.processInfo.environment["CAPTURA_DIR"]
        try XCTSkipIf(folder == nil, "Solo a mano, con TEST_RUNNER_CAPTURA_DIR.")
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        XCUIDevice.shared.appearance = .light
        super.tearDown()
    }

    func test_capturas() {
        let env = ProcessInfo.processInfo.environment
        // `-userTheme 1` es el tema Claro de Yala, que no sigue al sistema: en oscuro se deja el de fábrica.
        var extra = ["-recurringProposals.isEnabled", "<false/>"]
        if env["CAPTURA_OSCURO"] != "1" { extra += ["-userTheme", "1"] }
        if let size = env["CAPTURA_TEXTO"] { extra += ["-UIPreferredContentSizeCategoryName", size] }
        let prefijo = env["CAPTURA_PREFIJO"] ?? "despues"
        XCUIDevice.shared.appearance = env["CAPTURA_OSCURO"] == "1" ? .dark : .light

        let app = XCUIApplication()
        app.launchForUITest(pro: true, extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente.")
        if env["CAPTURA_GIRADO"] == "1" { XCUIDevice.shared.orientation = .landscapeLeft }
        app.openScheduledPaymentsList()

        // «Todos» es el tercer segmento.
        let picker = app.segmentedControls["scheduled_tab_picker"].firstMatch
        if picker.waitForExistence(timeout: 5) { picker.buttons.element(boundBy: 2).tap() }
        pause(1)

        for mode in ["list", "timeline", "calendar"] {
            choose(app, mode)
            shot(app, "\(prefijo)-todos-\(mode)-arriba")
            scrollToEnd(app)
            shot(app, "\(prefijo)-todos-\(mode)-final")
            scrollToTop(app)
        }

        // Mes siguiente, en línea de tiempo.
        choose(app, "timeline")
        let next = app.buttons["period_navigation_next"].firstMatch
        if next.waitForExistence(timeout: 5) { next.tap(); pause(1) }
        shot(app, "\(prefijo)-todos-timeline-mes-siguiente")
        let previous = app.buttons["period_navigation_previous"].firstMatch
        if previous.exists { previous.tap(); pause(1) }

        // Pocos pagos: «Suscripciones».
        if picker.exists { picker.buttons.element(boundBy: 1).tap() }
        pause(1)
        choose(app, "timeline")
        shot(app, "\(prefijo)-suscripciones-timeline-arriba")
        scrollToEnd(app)
        shot(app, "\(prefijo)-suscripciones-timeline-final")
    }

    private func choose(_ app: XCUIApplication, _ mode: String) {
        let button = app.buttons["scheduled_view_mode_\(mode)"].firstMatch
        let window = app.windows.firstMatch.frame
        // `isHittable` lanza con el chip fuera de la pantalla: se mira el marco. Con texto grande el carril de chips se
        // desplaza en horizontal, así que primero se sube la página y luego se corre el carril.
        for _ in 0..<6 {
            guard button.exists else { app.swipeDown(velocity: .fast); continue }
            let frame = button.frame
            if frame.minY < window.minY + 120 {
                app.swipeDown(velocity: .slow)
            } else if frame.maxY > window.maxY - 110 {
                app.swipeUp(velocity: .slow)
            } else if frame.maxX > window.maxX {
                app.buttons["scheduled_view_mode_list"].firstMatch.swipeLeft()
            } else if frame.minX < window.minX {
                app.buttons["scheduled_view_mode_\(mode)"].firstMatch.swipeRight()
            } else {
                break
            }
            pause(0.6)
        }
        if button.exists { button.tap() }
        pause(1)
    }

    private func scrollToEnd(_ app: XCUIApplication) {
        for _ in 0..<6 { app.swipeUp(velocity: .fast) }
        pause(1.2)
    }

    private func scrollToTop(_ app: XCUIApplication) {
        for _ in 0..<6 { app.swipeDown(velocity: .fast) }
        pause(0.8)
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        guard let folder else { return }
        let url = URL(fileURLWithPath: folder).appendingPathComponent("\(name).png")
        do {
            try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            // La de la pantalla y no la de la app: girado, la de la app sale con la orientación cambiada.
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
        } catch {
            XCTFail("No se pudo guardar \(name): \(error)")
        }
    }

    private func pause(_ seconds: TimeInterval) {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "pausa")], timeout: seconds)
    }
}
