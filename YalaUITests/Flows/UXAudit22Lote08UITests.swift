//
//  UXAudit22Lote08UITests.swift
//  YalaUITests
//
//  Lote decidido 2.2 · 08 (decisiones de Jürgen del 2026-10-18):
//  - L15-13: borrar un registro deja unos segundos para deshacerlo con «Deshacer» del aviso (⌘Z se mide con HID).
//  - L15-3: el enlace del widget «Entradas y salidas» abre Tendencias con esa tarjeta a la vista; el de subcategorías,
//    Distribución con las subcategorías.
//  - L15-14: con el iPhone girado, Yala IA y «+» van en fila abajo a la derecha.
//
//  Seed `realista` + Pro (`minimal` en los borrados).
//

import XCTest

final class UXAudit22Lote08UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    /// `minimal` para los borrados: con la lista entera en pantalla, contar filas dice si una salió. Con `realista` la
    /// lista es perezosa y, al esconder una, entra la siguiente y la cuenta no baja.
    private func launch(seed: String = "realista", deeplink: String? = nil, deeplinkURL: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: seed, deeplink: deeplink, deeplinkURL: deeplinkURL)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    private func rows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(identifier: "record_row")
    }

    /// La fila con esta etiqueta (nota, importe, categoría y cuenta): la lista es perezosa, así que contar filas no dice
    /// si una salió; buscar la que se borró, sí.
    private func row(_ app: XCUIApplication, labeled label: String) -> XCUIElement {
        rows(app).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func waitUntil(_ timeout: TimeInterval = 6, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return condition()
    }

    /// Borra la primera fila desde su menú contextual y confirma. Devuelve su etiqueta.
    private func deleteFirstRowFromContextMenu(_ app: XCUIApplication) -> String {
        let first = rows(app).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 15), "No hay filas de registro.")
        let label = first.label
        first.press(forDuration: 1.2)
        let delete = app.buttons["Eliminar"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "El menú del registro no ofrece Eliminar.")
        delete.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Eliminar no preguntó.")
        XCTAssertTrue(
            alert.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "segundos")).firstMatch.exists,
            "La pregunta tiene que decir que se puede deshacer unos segundos, no que no se puede.")
        alert.buttons["Eliminar"].firstMatch.tap()
        return label
    }

    // MARK: - L15-13

    /// El registro sale de la lista, el aviso ofrece «Deshacer» y tocarlo lo devuelve.
    func test_deletingARecord_offersUndo_andUndoBringsItBack() {
        let app = launch(seed: "minimal", deeplink: "records")
        let label = deleteFirstRowFromContextMenu(app)

        let undo = app.buttons["record_deleted_undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "No salió el aviso con «Deshacer».")
        XCTAssertTrue(waitUntil { !self.row(app, labeled: label).exists }, "El registro sigue en la lista.")

        undo.tap()
        XCTAssertTrue(waitUntil { self.row(app, labeled: label).exists }, "«Deshacer» no devolvió el registro.")
    }

    // ⌘Z (iPad con teclado) no se asierta aquí: `typeKey` no llega a un `CommandGroup` que solo existe mientras dura
    // el aviso (medido el 2026-10-20, iPad Pro 11, iOS 27.0). Con la tecla física simulada (HID, `axe key-combo
    // --modifiers 227 --key 29`) sí: 33 registros → borrar → 32 → ⌘Z → 33. Regla en `.claude/rules/testing.md`.

    // MARK: - L15-3

    /// El widget «Entradas y salidas» abre Tendencias con esa tarjeta a la vista, no el Panel.
    func test_inAndOutLink_opensTrendsOnThatCard() {
        let app = launch(deeplinkURL: "yaladev://statistics/trends/in-and-out")
        let title = app.staticTexts["Entradas y salidas"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 15), "El enlace no abrió Tendencias.")
        let window = app.windows.firstMatch.frame
        let deadline = Date().addingTimeInterval(5)
        while !window.contains(CGPoint(x: title.frame.midX, y: title.frame.midY)), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertTrue(
            window.contains(CGPoint(x: title.frame.midX, y: title.frame.midY)),
            "«Entradas y salidas» no quedó a la vista: \(title.frame) en \(window).")
    }

    /// Los widgets de subcategorías abren Distribución con la gráfica de subcategorías a la vista.
    func test_subcategoriesLink_opensDistributionOnSubcategories() {
        let app = launch(deeplinkURL: "yaladev://statistics/categories/subcategories")
        let page = app.descendants(matching: .any).matching(identifier: "distribution_page_subcategory").firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 15), "El enlace no abrió Distribución.")
        let window = app.windows.firstMatch.frame
        let deadline = Date().addingTimeInterval(5)
        while !window.contains(CGPoint(x: page.frame.midX, y: page.frame.midY)), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertTrue(
            window.contains(CGPoint(x: page.frame.midX, y: page.frame.midY)),
            "La gráfica de subcategorías no quedó a la vista: \(page.frame).")
    }

    // MARK: - L15-14

    /// Con el iPhone girado (poco alto), Yala IA y «+» van en fila, «+» a la derecha. En vertical, uno encima del otro.
    func test_landscapeIPhone_floatingButtonsGoInARow() throws {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            throw XCTSkip("El alto corto de este caso es el del iPhone girado.")
        }
        let app = launch(deeplink: "records")
        let chat = app.buttons["fab_chat"]
        let plus = app.buttons["fab_new_transaction"]
        XCTAssertTrue(plus.waitForExistence(timeout: 15) && chat.waitForExistence(timeout: 5), "Faltan los botones.")
        XCTAssertLessThan(chat.frame.midY, plus.frame.midY - 20, "En vertical, Yala IA va encima de «+».")

        // Primero que la ventana gire de verdad (molde de `IPhoneLandscapeUITests.rotate`), luego que los botones se
        // recoloquen: medir a media rotación da marcos de la forma anterior.
        XCUIDevice.shared.orientation = .landscapeLeft
        let window = app.windows.firstMatch
        let turned = Date().addingTimeInterval(10)
        while !(window.frame.width > window.frame.height), Date() < turned {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertGreaterThan(window.frame.width, window.frame.height, "La ventana no giró: \(window.frame).")
        let deadline = Date().addingTimeInterval(10)
        while abs(chat.frame.midY - plus.frame.midY) > 2, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertEqual(chat.frame.midY, plus.frame.midY, accuracy: 2, "Girado, los dos botones no van en fila.")
        XCTAssertLessThan(chat.frame.maxX, plus.frame.minX, "«+» tiene que ir a la derecha de Yala IA.")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "L15-14-girado"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
