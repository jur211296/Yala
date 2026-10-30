//
//  LoadTimesUITests.swift
//  YalaUITests
//
//  Conductor de la medida de tiempos de carga por pantalla (encargo `eficiencia-carga-por-vista`, 2026-10-30).
//  NO es una regresión: no asierta tiempos, solo recorre la app para que `LoadTimeMarks` escriba sus milisegundos en el
//  log del simulador. Se salta salvo con `YALA_PERF=1` en el entorno del runner (`TEST_RUNNER_YALA_PERF=1`), así que el
//  CI y el gate no lo corren.
//
//  Receta (simulador ya arrancado, app compilada con el scheme Yala Dev):
//    TEST_RUNNER_YALA_PERF=1 TEST_RUNNER_YALA_PERF_RUNS=5 bash qa/scripts/sim-lock.sh -- xcodebuild test-without-building \
//      -scheme "Yala Dev" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
//      -only-testing:YalaUITests/LoadTimesUITests
//    xcrun simctl spawn booted log show --last 30m --style compact \
//      --predicate 'subsystem == "app.yala.perf"' | grep PERF
//
//  `test_1_seed` siembra el corpus `rendimiento` (730 días, varias monedas, presupuestos, pagos, Bandeja y grupos) una
//  vez; `test_2_tour` relanza en frío N veces SIN semilla (relanzar con `-uitest-seed` duplicaría el corpus) y recorre
//  Registros, Estadísticas, Planificación, Grupos, Flujo de caja, Bandeja, Ajustes y Ajustes › Cuentas.
//

import XCTest

final class LoadTimesUITests: XCTestCase {

    private var enabled: Bool { ProcessInfo.processInfo.environment["YALA_PERF"] == "1" }
    private var runs: Int { Int(ProcessInfo.processInfo.environment["YALA_PERF_RUNS"] ?? "") ?? 3 }

    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipUnless(enabled, "Medida de tiempos de carga: solo con YALA_PERF=1.")
    }

    func test_1_seed() {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, pro: true, seed: "rendimiento", cloudSession: true, extraArguments: Self.launchArgs)
        XCTAssertTrue(app.waitForUITestReady(timeout: 600), "La semilla `rendimiento` no terminó.")
        app.terminate()
    }

    func test_2_tour() {
        for _ in 0..<runs {
            let app = XCUIApplication()
            app.launchForUITest(reset: false, pro: true, seed: nil, cloudSession: true, extraArguments: Self.launchArgs)
            XCTAssertTrue(app.waitForUITestReady(timeout: 120))
            wait(for: "panel_inbox_button", in: app)
            settle(app)

            visitTab(index: 1, expecting: "stats_hero_caption", in: app)        // Estadísticas
            visitTab(index: 2, expecting: "report_chip_flujoDeCaja", in: app)   // Informes
            if app.buttons["report_chip_flujoDeCaja"].waitForExistence(timeout: 10) {
                app.buttons["report_chip_flujoDeCaja"].tap()                     // Flujo de caja
                settle(app)
            }
            visitMoreCard("more_card_budgets", in: app)                         // Planificación
            openLink("yaladev://records", in: app)                              // Registros
            openLink("yaladev://groups", in: app)                               // Grupos

            // Bandeja y Ajustes, desde el Panel.
            app.tabBars.buttons.element(boundBy: 0).tap()
            if app.buttons["panel_inbox_button"].waitForHittable(timeout: 10) {
                app.buttons["panel_inbox_button"].tap()
                settle(app)
                app.swipeDown(velocity: .fast)
                settle(app)
            }
            app.openProfile()
            settle(app)
            app.openSettingsSection("profile_accounts")
            settle(app)
            app.terminate()
        }
    }

    // MARK: - Ayudas

    /// La divisa principal FIJADA, como la tiene quien ya usa la app: `-uitest-reset` la borra y, sin ella, la caché de los
    /// widgets cae a USD mientras la app cae a PEN, y reconvierte el corpus entero (ticket aparte). Medir eso sería
    /// medir otro bug.
    ///
    /// Y la barra de pestañas con Informes: Flujo de caja vive en su chip, y su tarjeta de «Más» queda bajo la barra en el
    /// iPhone 17 Pro, donde ningún arrastre sintético desplaza esa rejilla en iOS 27.0 (`testing.md`). Planificación y
    /// Planificación entra por su tarjeta, que sí está a la vista; Registros y Grupos, por su enlace.
    private static let launchArgs = [
        "-defaultCurrencyCode", "PEN",
        // Entre comillas de plist: sin ellas el dominio de argumentos lee `{…}` como un diccionario y `@AppStorage`, que
        // espera un texto, lo ignora (medido el 2026-10-30).
        "-tabBarConfiguration", #""{\"activeTabs\":[\"panel\",\"statistics\",\"reports\"]}""#,
    ]

    /// Abre un enlace con la app delante, como lo abriría un widget (`XCUIApplication.open` relanzaría la app).
    private func openLink(_ link: String, in app: XCUIApplication) {
        guard let url = URL(string: link) else { return }
        XCUIDevice.shared.system.open(url)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.alerts.buttons.element(boundBy: 1)
        if springboard.alerts.firstMatch.waitForExistence(timeout: 3), open.exists { open.tap() }
        settle(app)
    }

    private func visitTab(index: Int, expecting identifier: String, in app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: index).tap()
        wait(for: identifier, in: app)
        settle(app)
    }

    private func visitMoreCard(_ card: String, in app: XCUIApplication) {
        // Por su nombre: con una pestaña temporal abierta (la que deja otra tarjeta de «Más») cambia de posición. El
        // idioma lo fija `launchForUITest` (es).
        app.tabBars.buttons["Más"].tap()
        let target = app.descendants(matching: .any)[card].firstMatch
        // Arrastres cortos: la tarjeta suele asomar bajo la barra de pestañas, y un `swipeUp` entero se la pasa.
        // `isHittable` no basta: bajo la barra de pestañas también da `true` y el toque cae en la barra.
        _ = target.waitForExistence(timeout: 10)
        let barTop = app.tabBars.firstMatch.frame.minY
        var drags = 0
        while target.exists && target.frame.maxY > barTop - 8 && drags < 6 {
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
            from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
            drags += 1
        }
        guard target.exists, target.isHittable else { return XCTFail("No apareció \(card) en Más.") }
        target.tap()
        settle(app)
    }

    private func wait(for identifier: String, in app: XCUIApplication) {
        _ = app.descendants(matching: .any)[identifier].firstMatch.waitForExistence(timeout: 20)
    }

    /// Da tiempo a que la pantalla termine de cargar y de pintar antes de seguir: lo que se mide son los milisegundos
    /// que escribe la app, no lo que tarda el test. Un conductor de medida, no un test: el plazo fijo es a propósito.
    private func settle(_ app: XCUIApplication) {
        _ = app.descendants(matching: .any)["__perf_never__"].waitForExistence(timeout: 3)
    }
}
