//
//  PanelAccountsUITests.swift
//  YalaUITests
//
//  `panel-accounts-redesign` (2026-10-03): en el Panel, tocar la tarjeta de una cuenta abre su vista (ya no filtra),
//  «Editar» de esa vista abre el formulario de cuenta, y el botón de filtros de la toolbar abre la hoja de filtros.
//  Seed `minimal`. Convenciones: sin sleeps, scheme Yala Dev, ids y no textos.
//

import XCTest

final class PanelAccountsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Lleva al Panel con «Tus finanzas» desplegada: la preferencia de plegado sobrevive entre arranques.
    private func launchWithAccountsVisible() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(
            app.buttons["panel_action_new"].waitForExistence(timeout: 10),
            "La app no llegó al Panel."
        )
        let card = app.buttons["panel_account_card_0"]
        if !card.waitForExistence(timeout: 3) {
            let header = app.buttons["panel_panorama_header"]
            XCTAssertTrue(header.waitForExistence(timeout: 5), "No apareció la cabecera de «Tus finanzas».")
            header.tap()
        }
        XCTAssertTrue(card.waitForExistence(timeout: 5), "No apareció la primera tarjeta de cuenta.")
        return app
    }

    /// El toque abre la vista de la cuenta, y su «Editar» abre el formulario encima. Con el comportamiento anterior
    /// (el toque filtraba) la vista no aparece y el caso cae.
    func test_tappingAnAccountCard_opensItsView_andEditOpensTheForm() {
        let app = launchWithAccountsVisible()

        app.buttons["panel_account_card_0"].tap()

        XCTAssertTrue(
            app.buttons["account_detail_close"].waitForExistence(timeout: 5),
            "Tocar la tarjeta no abrió la vista de la cuenta."
        )
        let edit = app.buttons["account_detail_edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "La vista de la cuenta no ofrece «Editar».")
        edit.tap()

        XCTAssertTrue(
            app.textFields["account_name_field"].waitForExistence(timeout: 5),
            "«Editar» no abrió el formulario de la cuenta."
        )
    }

    /// El botón de filtros de la toolbar del Panel abre la hoja de filtros, la misma de Estadísticas.
    func test_filtersToolbarButton_opensTheFiltersSheet() {
        let app = launchWithAccountsVisible()

        let filters = app.buttons["panel_filters_button"]
        XCTAssertTrue(filters.waitForExistence(timeout: 5), "No está el botón de filtros en la toolbar del Panel.")
        filters.tap()

        XCTAssertTrue(
            app.buttons["filters_apply_button"].waitForExistence(timeout: 5),
            "El botón de filtros no abrió la hoja de filtros."
        )
    }
}
