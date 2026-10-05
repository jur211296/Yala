//
//  IPhoneLandscapeUITests.swift
//  YalaUITests
//
//  Yala gira con el iPhone (carril adaptativo, paso 11). Tres cosas fijan aquí:
//
//  - La app sigue al aparato: en horizontal la ventana es más ancha que alta, y se pasa de una página a otra.
//  - Girar con un registro abierto no lo cierra, ni al ir ni al volver.
//  - Girar con el formulario de nuevo registro a medias no pierde lo escrito.
//
//  - Con poco alto (girado), las cabeceras de Registros y de Estadísticas › Resumen se compactan y dejan ver el
//    contenido: la primera fila de Registros asoma sobre la barra de pestañas y el resumen va en banda.
//
//  En un iPhone grande girar cambia el ANCHO de la ventana (compacto ↔ regular), y es ahí donde lo abierto podría
//  perderse: la forma cambia y el estado tiene que vivir fuera de ella. Correr por UDID en `YalaLane-Adapt-iPhone-SE`
//  y `YalaLane-Adapt-iPhone-ProMax` (reglas del carril). En iPad también vale: el iPad ya giraba.
//

import XCTest

final class IPhoneLandscapeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    private func launch(deeplink: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: deeplink)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// Gira el aparato y espera a que la ventana de la app tenga la forma pedida. Antes del paso 11 el iPhone se
    /// quedaba en vertical aunque el aparato girara: esta espera es la que cae en rojo.
    private func rotate(_ app: XCUIApplication, to orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        let wantsLandscape = orientation.isLandscape
        let window = app.windows.firstMatch
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            let frame = window.frame
            if frame.width > 0, (frame.width > frame.height) == wantsLandscape { return }
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTFail("La ventana no giró a \(wantsLandscape ? "horizontal" : "vertical"): \(window.frame).")
    }

    /// Una página de la raíz, por su etiqueta: en la barra de pestañas si la hay, si no en la barra lateral.
    private func pageEntry(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        let tab = app.tabBars.buttons[label]
        if tab.exists { return tab }
        return app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// En horizontal se navega entre las páginas de siempre; cada una monta su contenido. Solo las que están en la
    /// barra en los dos anchos: en compacto Registros y Grupos van dentro de «Más» (configuración por defecto).
    func test_appFollowsTheDeviceToLandscape_andNavigatesThePages() {
        let app = launch(deeplink: "panel")
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 15), "El Panel no montó.")
        rotate(app, to: .landscapeLeft)

        let pages: [(label: String, content: String)] = [
            ("Estadísticas", "stats_tab_insights"),
            ("Planificación", "planning_chip_scheduledPayments"),
            ("Panel", "panel_action_new"),
        ]
        for page in pages {
            let entry = pageEntry(app, page.label)
            XCTAssertTrue(entry.waitForExistence(timeout: 10), "En horizontal no se ve la entrada «\(page.label)».")
            entry.tap()
            XCTAssertTrue(
                element(app, page.content).waitForExistence(timeout: 15),
                "En horizontal, «\(page.label)» no montó su contenido (\(page.content)).")
        }

        rotate(app, to: .portrait)
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 10), "Al volver a vertical se perdió el Panel.")
    }

    /// Un registro abierto sigue abierto al girar a horizontal y al volver.
    func test_rotatingKeepsTheOpenRecordOpen() {
        let app = launch(deeplink: "records")
        let row = app.buttons.matching(identifier: "record_row").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "No hay filas de registro.")
        row.tap()
        let edit = app.buttons["transaction_detail_edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "No se abrió el detalle del registro.")

        rotate(app, to: .landscapeLeft)
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "Al girar a horizontal se cerró el registro abierto.")

        rotate(app, to: .portrait)
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "Al volver a vertical se cerró el registro abierto.")
    }

    /// Al revés: abierto en horizontal (en un iPhone grande, en la columna de al lado) y vuelto a vertical (la hoja).
    func test_recordOpenedInLandscape_staysOpenBackInPortrait() {
        let app = launch(deeplink: "records")
        let row = app.buttons.matching(identifier: "record_row").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "No hay filas de registro.")
        rotate(app, to: .landscapeLeft)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "En horizontal no se ven las filas de registro.")
        row.tap()
        let edit = app.buttons["transaction_detail_edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "En horizontal no se abrió el detalle del registro.")

        rotate(app, to: .portrait)
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "Al volver a vertical se cerró el registro abierto en horizontal.")
    }

    /// Con poco alto, la cabecera de Registros deja ver la primera fila sin deslizar: al menos la mitad de la fila
    /// queda por encima de la barra de pestañas. Antes, en el SE girado empezaba 47 pt por debajo de la barra y en el
    /// Pro Max asomaba 19 pt (medido el 2026-10-01). En iPad no hay barra abajo y no aplica.
    func test_shortHeight_recordsHeaderLeavesTheFirstRowInView() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "En iPad la barra de pestañas no va abajo.")
        let app = launch(deeplink: "records")
        let row = app.buttons.matching(identifier: "record_row").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "No hay filas de registro.")
        rotate(app, to: .landscapeLeft)
        XCTAssertTrue(element(app, "stats_hero_caption").waitForExistence(timeout: 10), "En horizontal no se ve la cabecera.")

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "En horizontal no hay barra de pestañas.")
        // La cabecera cambia de forma al medir el alto: se espera a que la fila se asiente.
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, row.frame.midY > tabBar.frame.minY { Thread.sleep(forTimeInterval: 0.25) }
        XCTAssertLessThanOrEqual(
            row.frame.midY, tabBar.frame.minY,
            "Con poco alto la cabecera tapa la lista: la primera fila (\(row.frame)) queda bajo la barra de pestañas "
                + "(\(tabBar.frame)).")
    }

    /// Con poco alto, el resumen de Estadísticas va en banda —entradas y salidas al lado de la cifra, no debajo— y
    /// en vertical sigue apilado como siempre. Lo decide el alto del contenedor, así que las dos mitades se miran en
    /// el mismo aparato.
    func test_shortHeight_statisticsSummaryGoesInABand_andPortraitKeepsTheStack() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "En iPad el alto no baja de 500.")
        let app = launch(deeplink: "statistics")
        let caption = element(app, "stats_hero_caption")
        let expense = element(app, "stats_kpi_expense")
        XCTAssertTrue(caption.waitForExistence(timeout: 20), "Estadísticas › Resumen no pintó su cabecera.")
        XCTAssertTrue(expense.waitForExistence(timeout: 5), "La cabecera no enseña las salidas.")
        XCTAssertGreaterThanOrEqual(
            expense.frame.minY, caption.frame.maxY,
            "En vertical las salidas tienen que ir debajo del rótulo, como siempre: \(expense.frame) vs \(caption.frame).")

        rotate(app, to: .landscapeLeft)
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, expense.frame.minY >= caption.frame.maxY { Thread.sleep(forTimeInterval: 0.25) }
        XCTAssertLessThan(
            expense.frame.minY, caption.frame.maxY,
            "Con poco alto la cabecera sigue apilada: las salidas (\(expense.frame)) van bajo el rótulo "
                + "(\(caption.frame)) en vez de al lado de la cifra.")

        rotate(app, to: .portrait)
        let back = Date().addingTimeInterval(5)
        while Date() < back, expense.frame.minY < caption.frame.maxY { Thread.sleep(forTimeInterval: 0.25) }
        XCTAssertGreaterThanOrEqual(
            expense.frame.minY, caption.frame.maxY,
            "Al volver a vertical la cabecera no volvió a apilarse: \(expense.frame) vs \(caption.frame).")
    }

    /// Con texto de accesibilidad, un iPhone grande girado (ventana ancha) deja leer la cabecera de Planificación: «Este
    /// mes» en una línea, como en vertical, y el chip «Presupuestos» entero dentro de la lista. Antes la columna del
    /// split partía «Este mes» (de 63 a 125 pt de alto) y cortaba el chip 22 pt; con la columna ensanchada, el split la
    /// superponía sobre «Elige un…» (medido el 2026-10-01). Ahora, sin sitio para dos columnas que lean AX5, la página
    /// se pliega a la lista sola, sin detalle al lado. En iPad vale como regresión: en el Pro 13 sigue el split, con la
    /// columna más ancha. Donde girar deja la ventana compacta (SE) no había split y se salta.
    func test_accessibilityText_turnedLargeIPhone_planningHeaderStaysReadable() throws {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true, seed: "realista", deeplink: "planning",
            extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let period = element(app, "period_navigation_label")
        let chip = element(app, "planning_chip_budgets")
        XCTAssertTrue(period.waitForExistence(timeout: 20), "Planificación no pintó el período.")
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "Planificación no pintó el chip de presupuestos.")
        let portraitHeight = period.frame.height

        rotate(app, to: .landscapeLeft)
        try XCTSkipUnless(app.windows.firstMatch.frame.width >= 900, "Girado, este iPhone sigue en ventana compacta.")
        // El split mide y decide tras girar: se espera a que el período se asiente.
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, period.frame.height > portraitHeight + 1 { Thread.sleep(forTimeInterval: 0.25) }

        XCTAssertLessThanOrEqual(
            period.frame.height, portraitHeight + 1,
            "Girado con texto grande, «Este mes» se parte: \(period.frame) contra \(portraitHeight) pt en vertical.")

        // La columna de la lista es la barra de navegación que arranca más cerca del chip por su izquierda (en iPad, la
        // barra lateral de pestañas va antes) y, de las que arrancan ahí, la más estrecha (la del detalle va debajo).
        let bars = app.navigationBars.allElementsBoundByIndex
            .filter { $0.frame.width > 0 && $0.frame.minX <= chip.frame.minX + 1 }
        let start = bars.map(\.frame.minX).max() ?? 0
        let listBar = bars.filter { abs($0.frame.minX - start) <= 1 }.min { $0.frame.width < $1.frame.width }
        let listMaxX = try XCTUnwrap(listBar, "No hay barra de navegación de la lista.").frame.maxX
        XCTAssertLessThanOrEqual(
            chip.frame.maxX, listMaxX,
            "El chip «Presupuestos» (\(chip.frame)) se sale de la columna de la lista (hasta x = \(listMaxX)).")

        // En el iPhone girado no caben dos columnas que lean AX5: la lista va sola. Con el split, la superponía sobre
        // «Elige un…» y lo tapaba a medias (el texto del vacío no se expone por separado: se mira que no esté).
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCTAssertFalse(
                element(app, "planning_detail_placeholder").exists,
                "Girado con texto grande, la lista sigue en un split con «Elige un…» al lado: no caben las dos.")
        }
    }

    /// El formulario de nuevo registro a medias conserva lo escrito al girar y al volver.
    func test_rotatingKeepsAHalfWrittenNewRecord() {
        let app = launch(deeplink: "panel")
        let new = app.buttons["panel_action_new"]
        XCTAssertTrue(new.waitForExistence(timeout: 15), "El Panel no enseña «Nuevo registro».")
        new.tap()
        let amount = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10), "No se abrió el formulario de nuevo registro.")
        amount.tap()
        amount.typeText("123")

        func amountKeepsWhatWasTyped() -> Bool {
            amount.waitForExistence(timeout: 10) && ((amount.value as? String) ?? "").contains("123")
        }

        rotate(app, to: .landscapeLeft)
        XCTAssertTrue(amountKeepsWhatWasTyped(), "Al girar a horizontal el formulario perdió el importe: \(String(describing: amount.value)).")

        rotate(app, to: .portrait)
        XCTAssertTrue(amountKeepsWhatWasTyped(), "Al volver a vertical el formulario perdió el importe: \(String(describing: amount.value)).")
    }
}
