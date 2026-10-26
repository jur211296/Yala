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

    // MARK: - Opción B · «Mostrar solo» y «Ocultar» se combinan (2026-10-25)

    /// Cambiar de pestaña ya no pregunta ni vacía: cada pestaña tiene su lista, y al aplicar conviven «Solo USD» y
    /// «Sin PEN». Hasta el 2026-10-25 el cambio preguntaba «Se quitará lo que marcaste» y vaciaba (L8-16).
    func test_filters_showOnlyAndHide_combine() {
        let app = launch()
        openRecords(app)
        app.openRecordsFilters()

        let usdChip = app.buttons["filters_currency_chip_USD"]
        XCTAssertTrue(usdChip.waitForExistence(timeout: 5), "No apareció el chip de moneda USD.")
        usdChip.tap()
        XCTAssertTrue(usdChip.isSelected, "El chip USD no quedó marcado en «Mostrar solo».")

        let picker = app.segmentedControls["filters_include_exclude_picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "No apareció el selector Mostrar solo / Ocultar.")
        picker.buttons.element(boundBy: 1).tap()
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2), "Cambiar de pestaña volvió a preguntar.")
        XCTAssertTrue(picker.buttons.element(boundBy: 1).isSelected, "No pasó a «Ocultar».")
        // En «Ocultar», USD no está marcado: está en la otra lista.
        XCTAssertFalse(usdChip.isSelected, "USD salió marcado en «Ocultar».")

        let penChip = app.buttons["filters_currency_chip_PEN"]
        XCTAssertTrue(penChip.waitForExistence(timeout: 5), "No apareció el chip de moneda PEN.")
        penChip.tap()
        XCTAssertTrue(penChip.isSelected, "PEN no quedó oculto.")

        // De vuelta en «Mostrar solo», USD sigue marcado: nada se vació.
        picker.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(usdChip.isSelected, "Volver a «Mostrar solo» perdió USD.")

        app.buttons["filters_apply_button"].tap()

        let chips = app.buttons.matching(identifier: "applied_filter_chip")
        XCTAssertTrue(chips.firstMatch.waitForExistence(timeout: 10), "No aparecieron las cápsulas aplicadas.")
        let labels = chips.allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(labels.contains { $0.contains("USD") && $0 != "USD" }, "Falta la cápsula «Solo USD»: \(labels)")
        XCTAssertTrue(labels.contains { $0.contains("PEN") && $0 != "PEN" }, "Falta la cápsula «Sin PEN»: \(labels)")
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
        picker.buttons.element(boundBy: 1).tap()
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2), "Cambiar de pestaña preguntó.")

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
        // Con solo cosas ocultas, la hoja abre en «Ocultar» para que se vea lo que hay.
        XCTAssertTrue(picker.buttons.element(boundBy: 1).isSelected, "Filtros no reabrió en «Ocultar».")
        XCTAssertTrue(app.buttons["filters_currency_chip_USD"].isSelected,
                      "Al reabrir en «Ocultar», USD ya no estaba marcado: la hoja vació lo oculto.")
    }

    // MARK: - Lote 12.5 · El monto en «Ocultar»

    /// En «Ocultar», con USD marcado, el monto se filtra en la moneda que queda a la vista (PEN), no en la que se oculta.
    /// Hasta el 2026-10-25 el campo decía USD (ticket `hidden-single-currency-still-filters-the-amount-in-it`).
    func test_filters_hidingOneCurrency_amountUsesTheOneLeft() {
        let app = launch()
        openRecords(app)
        app.openRecordsFilters()

        let picker = app.segmentedControls["filters_include_exclude_picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "No apareció el selector Mostrar solo / Ocultar.")
        picker.buttons.element(boundBy: 1).tap()
        let usdChip = app.buttons["filters_currency_chip_USD"]
        XCTAssertTrue(usdChip.waitForExistence(timeout: 5), "No apareció el chip de moneda USD.")
        usdChip.tap()
        XCTAssertTrue(usdChip.isSelected, "El chip USD no quedó marcado.")

        // «Mayor a» enseña la moneda del monto encima del campo.
        // Baja hasta el bloque del monto: el marco contra la ventana (`isHittable` lanza fuera de pantalla).
        let title = app.descendants(matching: .any)["filters_amount_title"]
        let window = app.windows.firstMatch.frame
        var swipes = 0
        while !(title.exists && window.contains(CGPoint(x: title.frame.midX, y: title.frame.maxY + 60))), swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        let greaterThan = app.segmentedControls.allElementsBoundByIndex.first { $0.buttons.count == 4 }
        XCTAssertNotNil(greaterThan, "No apareció el selector de la condición del monto.")
        greaterThan?.buttons.element(boundBy: 1).tap()
        let currency = app.staticTexts["filters_amount_currency"]
        XCTAssertTrue(currency.waitForExistence(timeout: 5), "El campo del monto no dice en qué moneda compara.")
        XCTAssertEqual(currency.label, "PEN", "Con USD oculto, el monto compara en \(currency.label).")
    }
}
