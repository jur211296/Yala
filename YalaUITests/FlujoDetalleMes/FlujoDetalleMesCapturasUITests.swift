//
//  FlujoDetalleMesCapturasUITests.swift
//  YalaUITests
//
//  Capturas del detalle del mes del flujo de caja (S2 del replanteo, 18-nov-2026): el mes en curso arriba, bajando, un
//  mes pasado y uno que viene. No fija nada. Se corre a mano con `TEST_RUNNER_CAPTURA_DIR=<carpeta>`. Opcionales:
//  `TEST_RUNNER_CAPTURA_TEXTO` (categoría de texto), `TEST_RUNNER_CAPTURA_TEMA=claro` y `TEST_RUNNER_CAPTURA_PREFIJO`.
//  Sin la carpeta, se salta.
//

import XCTest

final class FlujoDetalleMesCapturasUITests: XCTestCase {

    private var folder: String?

    override func setUpWithError() throws {
        continueAfterFailure = true
        folder = ProcessInfo.processInfo.environment["CAPTURA_DIR"]
        try XCTSkipIf(folder == nil, "Solo a mano, con TEST_RUNNER_CAPTURA_DIR.")
    }

    func test_capturas() {
        let env = ProcessInfo.processInfo.environment
        var extra: [String] = []
        if let size = env["CAPTURA_TEXTO"] { extra += ["-UIPreferredContentSizeCategoryName", size] }
        if env["CAPTURA_TEMA"] == "claro" { extra += ["-userTheme", "1"] }
        let prefijo = env["CAPTURA_PREFIJO"] ?? "despues"

        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente.")
        app.openReport("flujoDeCaja")
        XCTAssertTrue(app.descendants(matching: .any)["cashflow_setup_view"].firstMatch.waitForExistence(timeout: 15),
                      "La vista de Flujo de caja no montó.")
        skipCoachMark(app)
        let create = app.buttons["primary_button"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), "No apareció «Crear mi plan».")
        create.tap()
        XCTAssertTrue(app.staticTexts["cashflow_month_title"].waitForExistence(timeout: 15), "El plan no se creó.")
        skipCoachMark(app)
        // La guía deja la lista desplazada: arriba del todo antes de la primera.
        // `app` y no `scrollViews.firstMatch`: el primero es el carrusel de chips, que no sube la lista.
        let scroll = app
        scroll.swipeDown(velocity: .fast)
        scroll.swipeDown(velocity: .fast)
        scroll.swipeDown(velocity: .fast)
        pause(1.5)
        shot(app, "\(prefijo)-1-mes-en-curso")

        scroll.swipeUp(velocity: .slow)
        pause(1)
        shot(app, "\(prefijo)-2-bajando")
        scroll.swipeUp(velocity: .slow)
        pause(1)
        shot(app, "\(prefijo)-3-bajando-mas")

        // Un mes pasado y uno que viene, desde arriba.
        scroll.swipeDown(velocity: .fast)
        scroll.swipeDown(velocity: .fast)
        scroll.swipeDown(velocity: .fast)
        pause(0.8)
        select(app, offset: -1)
        pause(1.2)
        shot(app, "\(prefijo)-4-mes-pasado")
        select(app, offset: 1)
        pause(1.2)
        shot(app, "\(prefijo)-5-mes-que-viene")
    }

    private func select(_ app: XCUIApplication, offset: Int) {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .month, value: offset, to: Date()) ?? Date()
        let comps = calendar.dateComponents([.year, .month], from: date)
        let key = String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
        let capsule = app.buttons["cashflow_month_capsule_\(key)"]
        if capsule.waitForExistence(timeout: 5) { capsule.tap() }
    }

    private func skipCoachMark(_ app: XCUIApplication) {
        let skip = app.buttons["coach_mark_skip"]
        if skip.waitForExistence(timeout: 4) {
            skip.tap()
            _ = skip.waitForNonExistence(timeout: 5)
        }
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        guard let folder else { return }
        let url = URL(fileURLWithPath: folder).appendingPathComponent("\(name).png")
        do {
            try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            try app.screenshot().pngRepresentation.write(to: url)
        } catch {
            XCTFail("No se pudo guardar \(name): \(error)")
        }
    }

    private func pause(_ seconds: TimeInterval) {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "pausa")], timeout: seconds)
    }
}
