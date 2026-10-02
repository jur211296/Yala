//
//  MultiWindowUITests.swift
//  YalaUITests
//
//  Fase 4 del carril adaptativo: varias ventanas de Yala, cada una con su navegación.
//
//  Correr por UDID en `YalaLane-Adapt-iPad-Pro-13`. En iPhone se salta: no hay ventanas que abrir.
//
//  Las dos ventanas se distinguen por el árbol de accesibilidad (`app.windows`), que incluye la que queda detrás.
//  Medido el 2026-10-02 en iOS 27.0: **corre con «Apps en pantalla completa»** (Ajustes → Multitarea y gestos). Con
//  «Apps en ventanas», abrir la segunda ventana o arrastrar su barra tumba `backboardd` del simulador (SIGABRT en
//  `MTLSimDevice newTextureWithDescriptor`, la app muere con SIGKILL sin culpa suya) en 3 de 4 corridas.
//  `-uitest-reset` descarta las ventanas que el iPad restaura de la corrida anterior (`SceneRegistry`).
//

import XCTest

final class MultiWindowUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    private func launch(deeplink: String? = nil) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "Varias ventanas: solo en iPad.")
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: deeplink)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Ventanas de Yala que contienen un elemento con `identifier`.
    private func windows(_ app: XCUIApplication, containing identifier: String) -> XCUIElementQuery {
        app.windows.containing(NSPredicate(format: "identifier == %@", identifier))
    }

    /// Una entrada de navegación (barra lateral o de pestañas) de UNA ventana, por su etiqueta.
    private func section(_ label: String, in window: XCUIElement) -> XCUIElement {
        window.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func waitForCount(_ query: XCUIElementQuery, _ count: Int, timeout: TimeInterval = 15) -> Bool {
        let predicate = NSPredicate { _, _ in query.count == count }
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: timeout)
            == .completed
    }

    /// Abre el primer registro en una ventana nueva y espera a que aterrice con él abierto. Devuelve esa ventana.
    private func openFirstRecordInNewWindow(_ app: XCUIApplication) -> XCUIElement {
        let rows = app.buttons.matching(identifier: "record_row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 15), "No hay filas de registro.")
        XCTAssertTrue(waitForCount(windows(app, containing: "record_row"), 1), "Al arrancar había más de una ventana.")
        XCTAssertEqual(windows(app, containing: "transaction_detail_edit").count, 0,
                       "Ya había un registro abierto antes de empezar.")

        rows.element(boundBy: 0).press(forDuration: 1.2)
        let open = app.buttons["Abrir en una ventana nueva"]
        XCTAssertTrue(open.waitForExistence(timeout: 5), "El menú contextual no ofrece «Abrir en una ventana nueva».")
        open.tap()

        let withRecord = windows(app, containing: "transaction_detail_edit").firstMatch
        XCTAssertTrue(withRecord.waitForExistence(timeout: 20), "La ventana nueva no abrió el registro.")
        XCTAssertTrue(waitForCount(windows(app, containing: "record_row"), 2), "No hay dos ventanas de Yala con Registros.")
        XCTAssertEqual(windows(app, containing: "transaction_detail_edit").count, 1,
                       "El registro abierto en la ventana nueva también apareció abierto en la de partida.")
        return withRecord
    }

    /// Abrir un registro en una ventana nueva: la nueva aterriza con ESE registro abierto, la de partida sigue sin
    /// ninguno, y cambiar de sección en una no mueve la otra.
    func test_recordInNewWindow_eachWindowKeepsItsOwnNavigation() throws {
        let app = try launch(deeplink: "records")
        let withRecord = openFirstRecordInNewWindow(app)
        attachScreenshot("01-ventana-nueva-con-su-registro")

        let stats = section("Estadísticas", in: withRecord)
        XCTAssertTrue(stats.waitForExistence(timeout: 5), "La ventana nueva no enseña Estadísticas.")
        stats.tap()
        XCTAssertTrue(waitForCount(windows(app, containing: "stats_tab_insights"), 1),
                      "La ventana nueva no pasó a Estadísticas, o pasaron las dos.")
        XCTAssertTrue(waitForCount(windows(app, containing: "record_row"), 1),
                      "La ventana de partida dejó Registros al cambiar la otra.")
        XCTAssertEqual(windows(app, containing: "transaction_detail_edit").count, 0,
                       "Quedó un registro abierto donde no se abrió ninguno.")
        attachScreenshot("02-cada-una-su-seccion")
    }

    /// Un enlace con dos ventanas abiertas llega a UNA: la que el sistema pone delante. La otra no se mueve.
    func test_deepLinkWithTwoWindows_landsInOneWindowOnly() throws {
        let app = try launch(deeplink: "records")
        _ = openFirstRecordInNewWindow(app)

        guard let url = URL(string: "yaladev://statistics") else { return XCTFail("URL inválida") }
        XCUIDevice.shared.system.open(url)

        XCTAssertTrue(waitForCount(windows(app, containing: "stats_tab_insights"), 1),
                      "El enlace no abrió Estadísticas en exactamente una ventana.")
        XCTAssertTrue(waitForCount(windows(app, containing: "record_row"), 1),
                      "La otra ventana dejó Registros: el enlace llegó a las dos.")
        attachScreenshot("03-enlace-en-una-ventana")
    }
}
