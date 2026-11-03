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
    private func launchWithAccountsVisible(seed: String = "minimal") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: seed)
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

    /// Card extra (2026-11-03): «Grupos PEN» y «Grupos USD» van en UNA tarjeta «Grupos», con una fila por grupo y el
    /// total de las dos cuentas. Seed `cuentas-de-grupos` (`DevSeedGroupsAccountCard`): tres grupos y una cuenta propia.
    /// Con el comportamiento anterior la primera tarjeta es «Grupos PEN» sola y la segunda «Grupos USD»: cae.
    func test_groupsSystemAccounts_shareOneCard_withARowPerGroup() {
        let app = launchWithAccountsVisible(seed: "cuentas-de-grupos")

        let groups = app.buttons["panel_account_card_0"]
        XCTAssertTrue(groups.label.hasPrefix("Grupos."), "La primera tarjeta no es «Grupos»: \(groups.label)")
        for name in ["Viaje a Cusco", "Depa Miraflores", "Japón"] {
            XCTAssertTrue(groups.label.contains(name), "Falta la fila de «\(name)» en la tarjeta: \(groups.label)")
        }
        // La segunda tarjeta ya es la cuenta propia: las dos de sistema ocupan un solo sitio.
        let second = app.buttons["panel_account_card_1"]
        XCTAssertTrue(second.waitForExistence(timeout: 5), "No apareció la segunda tarjeta.")
        XCTAssertTrue(second.label.hasPrefix("Sueldo QA."), "La segunda tarjeta debería ser «Sueldo QA»: \(second.label)")
        XCTAssertFalse(app.buttons["panel_account_card_2"].exists, "Sobra una tarjeta: «Grupos USD» sigue aparte.")
    }
}
