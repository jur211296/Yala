//
//  UndoNoticePlacementUITests.swift
//  YalaUITests
//
//  Dónde sale el aviso con «Deshacer» (`DraftDiscardUndoNotice`). Jürgen, 2026-10-31 (card d3qq): abajo, donde salen
//  siempre estos avisos, aunque pise el «+». Del 28 al 31-oct subía por encima de toda la pila de botones flotantes en
//  TODAS las pantallas y quedaba a media altura. Tres pantallas: el Panel (Yala IA + «+»), Registros (los mismos dos) y la Bandeja
//  (sin botones flotantes).
//

import XCTest

final class UndoNoticePlacementUITests: XCTestCase {
    /// Hueco máximo entre el borde inferior del aviso y el de la ventana. Abajo es la franja que dejan el área segura y la
    /// barra de pestañas: en el iPhone 17 Pro, 34 + 72 = 106 pt. A media altura (lo del 28-oct) eran ~270.
    private let maxGapToBottom: CGFloat = 140

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func attachScreenshot(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// El aviso queda abajo, sin meterse en la barra de pestañas. Pisar el «+» está permitido (Jürgen, 2026-10-31).
    private func assertAtTheBottom(
        _ app: XCUIApplication, notice: XCUIElement, file: StaticString = #filePath, line: UInt = #line
    ) {
        let window = app.windows.firstMatch
        let gap = window.frame.maxY - notice.frame.maxY
        XCTAssertLessThanOrEqual(gap, maxGapToBottom, "El aviso queda a \(gap) pt del borde inferior: no está abajo.",
                                 file: file, line: line)
        // La barra flotante de abajo: sus botones quedan por debajo del aviso. (El marco de la barra entera empieza unos
        // puntos por encima de lo que se ve, así que se mide con los botones.)
        let tabBar = app.tabBars.firstMatch
        guard tabBar.exists, tabBar.frame.minY > window.frame.midY else { return }
        // El marco del aviso lleva 4 pt de aire bajo la cápsula (`DS.Spacing.xs`); lo que no puede pisar la barra es la cápsula.
        let capsuleBottom = notice.frame.maxY - 4
        for button in tabBar.buttons.allElementsBoundByIndex where button.frame.height > 0 {
            XCTAssertLessThanOrEqual(capsuleBottom, button.frame.minY,
                                     "El aviso \(notice.frame) se mete en la barra: «\(button.label)» \(button.frame).",
                                     file: file, line: line)
        }
    }

    // MARK: - Panel: Yala IA + «+»

    /// Tras guardar un registro desde el Panel, el aviso va abajo, sobre la barra, y la parte del «+» que asoma por encima
    /// responde: la ventana del aviso solo se queda los toques de la cápsula. Hasta el 2026-10-31 era una franja invisible
    /// que tapaba el «+» entero.
    func test_panel_noticeSitsAtTheBottom() throws {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            throw XCTSkip("En el iPad el Panel no tiene «+» flotante que abra el formulario por este camino.")
        }
        let app = XCUIApplication()
        app.launchForUITest(seed: "una-cuenta", extraArguments: [
            "-uitest-transactions-saved", "5", "-uitest-undo-notice-seconds", "30",
        ])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.revealPanelFAB().tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del «+».")
        manual.tap()
        let amount = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "No se abrió el formulario.")
        amount.tap()
        amount.typeText("25")
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        app.buttons["new_transaction_save"].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 8), "El formulario no se cerró al guardar.")

        let notice = element(app, "saved_record_notice")
        XCTAssertTrue(notice.waitForExistence(timeout: 3), "Control: el aviso salió.")
        let plus = app.buttons["fab_new_transaction"]
        XCTAssertTrue(plus.waitForExistence(timeout: 5), "Control: el «+» sigue en el Panel.")
        attachScreenshot("aviso-panel")

        assertAtTheBottom(app, notice: notice)

        let visibleTop = plus.frame.minY + 6
        XCTAssertLessThan(visibleTop, notice.frame.minY, "Control: el «+» asoma por encima del aviso.")
        plus.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        XCTAssertTrue(manual.waitForHittable(timeout: 3), "Tocar la parte del «+» que se ve no abrió su menú: el aviso se quedó el toque.")
    }

    // MARK: - Registros: Yala IA + «+»

    func test_records_deletionNoticeSitsAtTheBottom() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "minimal", deeplink: "records",
                            extraArguments: ["-uitest-undo-notice-seconds", "30"])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let first = app.buttons.matching(identifier: "record_row").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 15), "No hay filas de registro.")
        first.press(forDuration: 1.2)
        let delete = app.buttons["Eliminar"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "El menú del registro no ofrece Eliminar.")
        delete.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Eliminar no preguntó.")
        alert.buttons["Eliminar"].firstMatch.tap()

        let notice = element(app, "record_deleted_notice")
        XCTAssertTrue(notice.waitForExistence(timeout: 5), "No salió el aviso con «Deshacer».")
        attachScreenshot("aviso-registros")

        assertAtTheBottom(app, notice: notice)
    }

    // MARK: - Bandeja: sin botones flotantes

    /// Sin botones flotantes en pantalla (la Bandeja es una hoja), el aviso va abajo y centrado.
    func test_inbox_discardNoticeSitsAtTheBottom_centered() {
        let app = XCUIApplication()
        app.launchForUITest(extraArguments: ["-uitest-undo-notice-seconds", "30"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let inboxButton = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inboxButton.waitForExistence(timeout: 10), "No apareció el botón de la Bandeja en el Panel.")
        inboxButton.tap()
        let row = app.buttons["inbox_draft_row_Almuerzo equipo"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No apareció el borrador a descartar.")
        row.tap()
        let more = app.buttons["draft_editor_more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5), "El editor no tiene el menú «⋯».")
        more.tap()
        let discard = app.buttons["draft_editor_discard"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5), "El menú «⋯» no ofrece Descartar.")
        discard.tap()

        let notice = element(app, "draft_discard_notice")
        XCTAssertTrue(notice.waitForExistence(timeout: 5), "Tras descartar no salió el aviso.")
        XCTAssertTrue(row.waitForNonExistence(timeout: 5), "Control: el borrador salió de pendientes.")
        attachScreenshot("aviso-bandeja")

        assertAtTheBottom(app, notice: notice)
        let window = app.windows.firstMatch
        let left = notice.frame.minX - window.frame.minX
        let right = window.frame.maxX - notice.frame.maxX
        XCTAssertEqual(left, right, accuracy: 2, "Sin botones flotantes, el aviso va centrado (márgenes \(left) y \(right)).")
    }
}
