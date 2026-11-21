//
//  FavoritosFilaCapturasUITests.swift
//  YalaUITests
//
//  Capturas de la fila de Favoritos de Nuevo registro (encargo del 2026-11-21: «Ver todos» junto al rótulo, chips
//  completos mientras quepan, centrados), con el mismo guion antes y después del cambio: 1, 3, 5 (con nombres largos) y
//  10 favoritos de gasto, más Ingreso y Transferencia. Solo corre si la corrida lo pide (`TEST_RUNNER_YALA_CAPTURE_DIR`);
//  el claro u oscuro lo pone quien lanza (`simctl ui appearance`) y la app va con el tema «Sistema».
//

import XCTest

final class FavoritosFilaCapturasUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func requireCaptureRun() throws {
        guard ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"] != nil else {
            throw XCTSkip("Solo para capturas: sin YALA_CAPTURE_DIR no hay nada que hacer.")
        }
    }

    private func openForm(extraFavorites: Int, longNames: Bool = false) -> XCUIApplication {
        var extra = ["-userTheme", "0"]
        if extraFavorites > 0 { extra += ["-uitest-seed-extra-favorites", "\(extraFavorites)"] }
        if longNames { extra.append("-uitest-seed-long-names") }
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "formulario", extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        app.buttons["panel_action_new"].tap()
        XCTAssertTrue(app.textFields["new_transaction_amount"].waitForExistence(timeout: 5), "No se abrió el formulario.")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "new_transaction_favorites_row").firstMatch
            .waitForExistence(timeout: 5), "No salió la fila de favoritos.")
        _ = app.waitForSettledLayout(of: app.buttons["new_transaction_favorites_see_all"])
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"] else { return }
        let prefix = ProcessInfo.processInfo.environment["YALA_CAPTURE_PREFIX"] ?? "captura"
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(prefix)-\(name).png")
        do {
            try app.screenshot().pngRepresentation.write(to: url)
        } catch {
            print("FavoritosFilaCapturasUITests: captura no guardada: \(error)")
        }
    }

    func test_capture_1_unFavorito_ingreso_transferencia() throws {
        try requireCaptureRun()
        let app = openForm(extraFavorites: 0)
        capture(app, "gasto-1")
        app.chooseNewTransactionType("income")
        _ = app.buttons["new_transaction_favorite_chip_Sueldo"].waitForExistence(timeout: 5)
        capture(app, "ingreso")
        app.chooseNewTransactionType("transfer")
        _ = app.buttons["new_transaction_favorite_chip_Ahorro del mes"].waitForExistence(timeout: 5)
        capture(app, "transferencia")
    }

    func test_capture_2_tresFavoritos() throws {
        try requireCaptureRun()
        capture(openForm(extraFavorites: 2), "gasto-3")
    }

    func test_capture_3_cincoConNombresLargos() throws {
        try requireCaptureRun()
        capture(openForm(extraFavorites: 3, longNames: true), "gasto-5-largos")
    }

    func test_capture_4_diezFavoritos() throws {
        try requireCaptureRun()
        capture(openForm(extraFavorites: 9), "gasto-10")
    }
}
