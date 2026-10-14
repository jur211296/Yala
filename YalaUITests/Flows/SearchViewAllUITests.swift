//
//  SearchViewAllUITests.swift
//  YalaUITests
//
//  Auditoría UX 2.2 · lote 8. «Ver todos» de Buscar llevaba a Estadísticas › Registros con el texto como filtro de nota,
//  que solo mira la nota: «Restaurantes» contaba 204 resultados (por categoría) y allí no salía ninguno, y de paso dejaba
//  el período de toda la app en «Todo». Ahora despliega en Buscar todos los resultados que contó, sin salir de la
//  pantalla. Seed `minimal` (más de 20 registros en una semana); la cuenta exacta la prueba `SearchResultsLogicTests`.
//

import XCTest

final class SearchViewAllUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_viewAll_expandsInPlace_withoutLeavingSearch() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        // Buscar es la última pestaña (rol `.search`, anclada al final de la barra).
        let tabs = app.tabBars.buttons
        XCTAssertTrue(tabs.firstMatch.waitForExistence(timeout: 10), "No apareció la barra de pestañas.")
        tabs.element(boundBy: tabs.count - 1).tap()

        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "No se abrió Buscar.")
        field.tap()
        // Una letra que casa con casi todo el seed (notas, categorías y cuentas): más de 20 resultados.
        field.typeText("e")

        let viewAll = app.buttons["search_view_all"]
        XCTAssertTrue(viewAll.waitForExistence(timeout: 10),
                      "Con más de 20 resultados no apareció «Ver todos» (search_view_all).")
        viewAll.tap()

        XCTAssertTrue(viewAll.waitForNonExistence(timeout: 5), "«Ver todos» sigue tras desplegar los resultados.")
        XCTAssertTrue(field.exists, "«Ver todos» sacó de Buscar: debía desplegar aquí mismo.")
        XCTAssertFalse(app.buttons["detail_chip_registros"].exists,
                       "«Ver todos» llevó a Estadísticas › Registros, donde el texto solo filtra por nota.")
    }
}
