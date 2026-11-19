//
//  RegistrosEstadisticasCapturasUITests.swift
//  YalaUITests
//
//  Conductor de capturas del encargo «Estadísticas › Registros idéntica a Registros» (17-nov). No afirma nada: deja
//  Registros y Estadísticas › Registros, en lista y en calendario, en la carpeta de `YALA_CAPTURES` (vía
//  `TEST_RUNNER_YALA_CAPTURES`). Sin esa variable no arranca la app y sale verde: en el CI no cuesta nada.
//  Seed `realista`, scheme Yala Dev.
//

import XCTest

final class RegistrosEstadisticasCapturasUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    private var captureDir: String? {
        let dir = ProcessInfo.processInfo.environment["YALA_CAPTURES"]
        return (dir?.isEmpty == false) ? dir : nil
    }

    private var useScreen = false

    private func capture(_ app: XCUIApplication, _ name: String) {
        guard let dir = captureDir else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        sleep(1)
        let shot = useScreen ? XCUIScreen.main.screenshot() : app.screenshot()
        do {
            try shot.pngRepresentation.write(to: url)
        } catch {
            XCTFail("No se pudo guardar \(name): \(error)")
        }
    }

    func test_capturas_claro() { recorrer(theme: "1", prefix: "claro") }

    func test_capturas_oscuro() { recorrer(theme: "2", prefix: "oscuro") }

    /// Girado: `app.screenshot()` en horizontal salió con media pantalla en negro (iOS 27.2); se captura la pantalla
    /// entera (`XCUIScreen`), que sale en el búfer vertical y se endereza al montar la evidencia.
    func test_capturas_girado() { recorrer(theme: "1", prefix: "girado", landscape: true) }

    private func recorrer(theme: String, prefix: String, landscape: Bool = false) {
        guard captureDir != nil else { return }
        let app = XCUIApplication()
        app.launchForUITest(seed: "realista", deeplink: "records", extraArguments: ["-userTheme", theme])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        if landscape { XCUIDevice.shared.orientation = .landscapeLeft }
        defer { XCUIDevice.shared.orientation = .portrait }
        useScreen = landscape

        // Registros (la pestaña).
        _ = app.buttons.matching(identifier: "record_row").firstMatch.waitForExistence(timeout: 15)
        sleep(1)
        capture(app, "\(prefix)-registros-lista")
        switchMode(app, to: "calendar")
        capture(app, "\(prefix)-registros-calendario")
        switchMode(app, to: "list")

        // Estadísticas › Registros.
        app.selectTab(.statistics)
        openStatsRecordsChip(app)
        _ = app.buttons.matching(identifier: "record_row").firstMatch.waitForExistence(timeout: 15)
        sleep(2)
        capture(app, "\(prefix)-estadisticas-lista")
        switchMode(app, to: "calendar")
        capture(app, "\(prefix)-estadisticas-calendario")
        switchMode(app, to: "list")
    }

    private func openStatsRecordsChip(_ app: XCUIApplication) {
        let chip = app.buttons["detail_chip_registros"].firstMatch
        if !chip.waitForExistence(timeout: 10) || !chip.isHittable {
            let chipsBar = app.scrollViews.containing(.button, identifier: "detail_chip_insights").firstMatch
            if chipsBar.exists { chipsBar.swipeLeft() }
        }
        chip.tap()
    }

    private func switchMode(_ app: XCUIApplication, to mode: String) {
        let button = app.buttons["records_view_mode_\(mode)"].firstMatch
        guard button.waitForExistence(timeout: 5) else { return }
        button.tap()
        sleep(1)
    }
}
