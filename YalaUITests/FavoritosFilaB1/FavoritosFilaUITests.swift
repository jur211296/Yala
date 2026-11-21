//
//  FavoritosFilaUITests.swift
//  YalaUITests
//
//  La fila de Favoritos de Nuevo registro (Jürgen, 21-nov-2026): «Ver todos ›» en la línea del rótulo, a la derecha;
//  los favoritos como chips completos mientras quepan todos, si no como bolitas de solo icono, y la fila centrada
//  mientras no haga scroll. Los favoritos de más los pone `-uitest-seed-extra-favorites` sobre el perfil `formulario`,
//  que ya trae «Café».
//

import XCTest

final class FavoritosFilaUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func openForm(extraFavorites: Int) -> XCUIApplication {
        let app = XCUIApplication()
        let extra = extraFavorites > 0 ? ["-uitest-seed-extra-favorites", "\(extraFavorites)"] : []
        app.launchForUITest(pro: true, seed: "formulario", extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        app.buttons["panel_action_new"].tap()
        XCTAssertTrue(app.textFields["new_transaction_amount"].waitForExistence(timeout: 5), "No se abrió el formulario.")
        XCTAssertTrue(app.buttons["new_transaction_favorites_see_all"].waitForExistence(timeout: 5),
                      "No salió la fila de favoritos.")
        XCTAssertTrue(app.waitForSettledLayout(of: app.buttons["new_transaction_favorites_see_all"]))
        return app
    }

    private func chips(_ app: XCUIApplication, _ names: [String]) -> [XCUIElement] {
        names.map { name in
            let chip = app.buttons["new_transaction_favorite_chip_\(name)"]
            XCTAssertTrue(chip.waitForExistence(timeout: 5), "Falta el favorito «\(name)».")
            return chip
        }
    }

    /// «Ver todos» va en la línea del rótulo, pegado al margen derecho (`DS.Spacing.xl`, 20 pt), y por encima de los chips (ya no al final de
    /// su fila).
    func test_seeAll_sitsOnTheLabelLine_atTheRightMargin() {
        let app = openForm(extraFavorites: 0)
        let label = app.staticTexts["new_transaction_favorites_label"]
        let seeAll = app.buttons["new_transaction_favorites_see_all"]
        XCTAssertTrue(label.exists, "Falta el rótulo «Favoritos».")
        XCTAssertEqual(seeAll.frame.midY, label.frame.midY, accuracy: 6, "«Ver todos» no está en la línea del rótulo.")
        let width = app.windows.firstMatch.frame.width
        XCTAssertEqual(seeAll.frame.maxX, width - 20, accuracy: 3, "«Ver todos» no llega al margen derecho.")
        let coffee = chips(app, ["Café"])[0]
        XCTAssertLessThan(seeAll.frame.midY, coffee.frame.minY, "«Ver todos» tenía que ir encima de los chips.")
        XCTAssertGreaterThanOrEqual(seeAll.frame.height, 43, "La zona de toque de «Ver todos» no llega a 44 pt.")
        seeAll.tap()
        XCTAssertTrue(app.buttons["favorites_row_Café"].waitForExistence(timeout: 5), "«Ver todos» no abrió los favoritos.")
    }

    /// Con tres favoritos cortos caben completos: cada chip lleva su nombre (más ancho que una bolita) y la fila va
    /// centrada.
    func test_fewFavorites_showWholeChips_centered() {
        let app = openForm(extraFavorites: 2)
        let row = chips(app, ["Café", "Taxi", "Mercado"])
        for chip in row {
            XCTAssertGreaterThan(chip.frame.width, 60, "«\(chip.identifier)» tenía que ir completo, con su nombre.")
        }
        let midX = app.windows.firstMatch.frame.midX
        XCTAssertEqual((row[0].frame.minX + row[2].frame.maxX) / 2, midX, accuracy: 3, "La fila no va centrada.")
    }

    /// Con cinco y un nombre largo ya no caben completos: bolitas de solo icono, todavía centradas porque caben.
    func test_whenWholeChipsDontFit_iconsCentered() {
        let app = openForm(extraFavorites: 4)
        let row = chips(app, ["Café", "Taxi", "Mercado", "Mantenimiento del edificio", "Farmacia"])
        for chip in row {
            XCTAssertLessThan(chip.frame.width, 50, "«\(chip.identifier)» tenía que ser una bolita de solo icono.")
        }
        let midX = app.windows.firstMatch.frame.midX
        XCTAssertEqual((row[0].frame.minX + row[4].frame.maxX) / 2, midX, accuracy: 3, "Las bolitas no van centradas.")
    }

    /// Con diez ni las bolitas caben: arrancan en el margen y se desplazan.
    func test_manyFavorites_iconsScrollFromTheMargin() {
        let app = openForm(extraFavorites: 9)
        let coffee = chips(app, ["Café"])[0]
        XCTAssertLessThan(coffee.frame.width, 50, "Con diez, «Café» tenía que ser una bolita.")
        XCTAssertEqual(coffee.frame.minX, 20, accuracy: 3, "Con scroll, la fila arranca en el margen.")
        let last = app.buttons["new_transaction_favorite_chip_Almuerzo"]
        XCTAssertTrue(last.exists)
        XCTAssertGreaterThan(last.frame.minX, app.windows.firstMatch.frame.width, "El último tenía que quedar fuera, al scroll.")
    }
}
