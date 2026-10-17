//
//  UXAudit22Lote8CUITests.swift
//  YalaUITests
//
//  Auditoría UX 2.2 · lote 8 (buscar y filtrar registros), cards L8-14, L8-16 y L8-17.
//  - Un resultado de Buscar abre el detalle, como en Registros; su «Editar» abre el editor (antes abría el editor directo).
//  - Filtros: la X con cambios pregunta y «Descartar» cierra sin aplicar; pasar a «Ocultar» con algo marcado pregunta
//    antes de vaciarlo; lo oculto sobrevive a reabrir la hoja.
//  - Tocar una cápsula de «Filtros aplicados» abre Filtros, y la de algo oculto dice «Sin <nombre>».
//  Seed `minimal` (multi-moneda: hay chip USD). Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class UXAudit22Lote8CUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Navegación

    /// Navega a Estadísticas → chip Registros (revelando el chip si queda fuera de vista).
    private func openRecords(_ app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: 1).tap()
        let recordsChip = app.buttons["detail_chip_registros"]
        XCTAssertTrue(recordsChip.waitForExistence(timeout: 10), "No apareció el chip Registros.")
        let chipsBar = app.scrollViews.containing(.button, identifier: "detail_chip_insights").firstMatch
        if chipsBar.exists {
            chipsBar.swipeLeft()
        }
        recordsChip.tap()
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    // MARK: - L8-14 · Buscar abre el detalle

    func test_search_tapResult_opensDetail_andEditOpensEditor() {
        let app = launch()

        // Buscar es la última pestaña (rol `.search`, anclada al final de la barra).
        let tabs = app.tabBars.buttons
        XCTAssertTrue(tabs.firstMatch.waitForExistence(timeout: 10), "No apareció la barra de pestañas.")
        tabs.element(boundBy: tabs.count - 1).tap()

        // Sin texto, la lista enseña los últimos registros con su rótulo.
        let header = app.staticTexts["search_results_header"]
        XCTAssertTrue(header.waitForExistence(timeout: 10), "Sin texto, Buscar no rotuló la lista («Recientes»).")

        let firstRow = app.buttons.matching(identifier: "record_row").firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10), "Buscar no enseñó filas con el estilo de Registros (record_row).")
        XCTAssertTrue(firstRow.waitForHittable(timeout: 5), "La primera fila de Buscar no es alcanzable.")
        firstRow.tap()

        let editButton = app.buttons["transaction_detail_edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5),
                      "Tocar un resultado no abrió el detalle (transaction_detail_edit).")
        XCTAssertFalse(app.buttons["new_transaction_save"].exists, "Tocar un resultado abrió el editor directo.")

        editButton.tap()
        XCTAssertTrue(app.buttons["new_transaction_save"].waitForExistence(timeout: 5),
                      "«Editar» del detalle no abrió el editor (new_transaction_save).")
        XCTAssertFalse(editButton.exists, "El detalle sigue presentado debajo del editor.")
    }

    // MARK: - L8-16 · La X pregunta

    func test_filters_closeWithChanges_asks_andDiscardDoesNotApply() {
        let app = launch()
        openRecords(app)
        app.openRecordsFilters()

        let usdChip = app.buttons["filters_currency_chip_USD"]
        XCTAssertTrue(usdChip.waitForExistence(timeout: 5), "No apareció el chip de moneda USD.")
        usdChip.tap()

        app.buttons["filters_close_button"].tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "La X con cambios no preguntó «¿Descartar los filtros?».")
        alert.buttons["Descartar"].firstMatch.tap()

        // Con la hoja arriba, lo de debajo sigue en el árbol: se mide que la hoja se fue, no que Registros «existe».
        XCTAssertTrue(usdChip.waitForNonExistence(timeout: 5), "«Descartar» no cerró la hoja.")
        XCTAssertFalse(app.buttons["applied_filter_chip"].exists, "«Descartar» aplicó el filtro.")

        app.openRecordsFilters()
        let reopened = app.buttons["filters_currency_chip_USD"]
        XCTAssertTrue(reopened.waitForExistence(timeout: 5), "No reabrió la hoja de filtros.")
        XCTAssertFalse(reopened.isSelected, "Lo descartado volvió al reabrir.")
    }

    func test_filters_closeWithoutChanges_closesWithoutAsking() {
        let app = launch()
        openRecords(app)
        app.openRecordsFilters()

        let close = app.buttons["filters_close_button"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "No apareció la X de Filtros.")
        close.tap()

        // Antes de cualquier otro toque: el manejador de interrupciones de XCTest contestaría la alerta por nosotros.
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2), "La X preguntó sin que hubiera cambios.")
        XCTAssertTrue(app.segmentedControls["filters_include_exclude_picker"].waitForNonExistence(timeout: 5),
                      "La X sin cambios no cerró la hoja.")
    }

    // MARK: - L8-16 · Cambiar de modo pregunta

    func test_filters_switchToHideWithSomethingMarked_asksBeforeClearing() {
        let app = launch()
        openRecords(app)
        app.openRecordsFilters()

        let usdChip = app.buttons["filters_currency_chip_USD"]
        XCTAssertTrue(usdChip.waitForExistence(timeout: 5), "No apareció el chip de moneda USD.")
        usdChip.tap()
        XCTAssertTrue(usdChip.isSelected, "El chip USD no quedó marcado.")

        let picker = app.segmentedControls["filters_include_exclude_picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "No apareció el selector Mostrar solo / Ocultar.")
        // Segmento «Ocultar» = 2º (tag true).
        picker.buttons.element(boundBy: 1).tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Pasar a «Ocultar» con algo marcado no preguntó.")
        // Cancelar: el modo y lo marcado siguen como estaban.
        alert.buttons["Cancelar"].firstMatch.tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), "La pregunta no se cerró al cancelar.")
        XCTAssertTrue(picker.buttons.element(boundBy: 0).isSelected, "Cancelar dejó el modo cambiado.")
        XCTAssertTrue(usdChip.isSelected, "Cancelar vació lo marcado.")

        // Cambiar: pasa a «Ocultar» y vacía.
        picker.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "La segunda vez no preguntó.")
        alert.buttons["Cambiar"].firstMatch.tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), "La pregunta no se cerró al cambiar.")
        XCTAssertTrue(picker.buttons.element(boundBy: 1).isSelected, "«Cambiar» no pasó a «Ocultar».")
        XCTAssertFalse(app.buttons["filters_currency_chip_USD"].isSelected, "«Cambiar» no vació lo marcado.")
    }

    // MARK: - L8-17 · La cápsula abre Filtros y dice «Sin …»

    /// Ocultar USD, aplicar: la cápsula dice «Sin USD», tocarla abre Filtros, y USD sigue marcado (lo oculto no se
    /// pierde al rehidratar la hoja en «Ocultar»).
    func test_appliedChip_excluded_saysWithout_andTapOpensFilters() {
        let app = launch()
        openRecords(app)
        app.openRecordsFilters()

        let picker = app.segmentedControls["filters_include_exclude_picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "No apareció el selector Mostrar solo / Ocultar.")
        // Con nada marcado cambia sin preguntar.
        picker.buttons.element(boundBy: 1).tap()
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2), "Cambiar de modo sin nada marcado preguntó.")

        let usdChip = app.buttons["filters_currency_chip_USD"]
        XCTAssertTrue(usdChip.waitForExistence(timeout: 5), "No apareció el chip de moneda USD.")
        usdChip.tap()
        app.buttons["filters_apply_button"].tap()

        let chip = app.buttons.matching(identifier: "applied_filter_chip").firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "No apareció la cápsula del filtro aplicado.")
        XCTAssertTrue(chip.label.contains("USD") && chip.label != "USD",
                      "La cápsula de lo oculto no dice «Sin USD»: \(chip.label)")
        XCTAssertTrue(chip.waitForHittable(timeout: 5), "La cápsula no es alcanzable.")
        chip.tap()

        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Tocar la cápsula no abrió Filtros.")
        XCTAssertTrue(picker.buttons.element(boundBy: 1).isSelected, "Filtros no reabrió en «Ocultar».")
        XCTAssertTrue(app.buttons["filters_currency_chip_USD"].isSelected,
                      "Al reabrir en «Ocultar», USD ya no estaba marcado: la hoja vació lo oculto.")
    }
}
