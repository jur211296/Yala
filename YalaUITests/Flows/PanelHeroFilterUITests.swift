//
//  PanelHeroFilterUITests.swift
//  YalaUITests
//
//  Auditoría UX 2.2 · lote 3 · L3-3: las píldoras ↑/↓ del hero filtran el Panel, y desde ahora lo DICEN. Con una
//  puesta sale el chip «Viendo solo gastos ✕» bajo la cifra, y tocarlo quita el filtro. Antes el filtro se ponía sin
//  ningún aviso y la cifra grande seguía igual. Seed `minimal`.
//

import XCTest

final class PanelHeroFilterUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_expensePill_showsTheFilterChip_andTheChipRemovesIt() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let expensePill = app.buttons["panel_hero_expense_pill"]
        XCTAssertTrue(expensePill.waitForExistence(timeout: 10), "No apareció la píldora de gastos del hero.")
        let chip = app.buttons["panel_hero_nature_chip"]
        XCTAssertFalse(chip.exists, "Sin filtro no debe salir el chip de «solo gastos».")

        expensePill.tap()
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "Con la píldora puesta no salió el chip que lo dice.")
        XCTAssertTrue(expensePill.isSelected, "La píldora elegida no se anuncia como seleccionada.")

        chip.tap()
        XCTAssertTrue(chip.waitForNonExistence(timeout: 5), "Tocar el chip no quitó el filtro.")
        XCTAssertFalse(expensePill.isSelected, "Tras quitar el filtro la píldora sigue seleccionada.")
    }
}
