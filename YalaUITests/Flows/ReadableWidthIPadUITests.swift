//
//  ReadableWidthIPadUITests.swift
//  YalaUITests
//
//  Lote 2.3 · decisión 7 (opción C, Jürgen, 9-nov): en una ventana ancha, Distribución, Reportes (Comparativa y flujo de
//  caja), el detalle de un grupo y la ficha de una cuenta llevan su contenido al ancho legible que ya existe
//  (`DS.Adaptive.readableWidth`, 700 pt). Antes iban de lado a lado (~1.000 pt en el iPad Pro 13) y el importe quedaba
//  lejísimos de su nombre; la ficha de una cuenta iba en una hoja centrada de media pantalla.
//
//  Cada caso mide una fila o tarjeta REAL que ocupa todo lo ancho de su columna: con el arreglo no pasa de 700 pt; sin
//  él mide lo que mida la ventana. Correr por UDID en el iPad Pro 13; en iPhone se saltan diciéndolo (ahí el ancho
//  legible no cambia nada, y el iPhone en vertical queda igual por construcción). Las dos columnas quedan para después,
//  vista por vista con maqueta: estos casos no las fijan.
//

import XCTest

final class ReadableWidthIPadUITests: XCTestCase {
    /// `DS.Adaptive.readableWidth`, más un punto de redondeo.
    private let readableWidth: CGFloat = 701

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    /// Solo decide QUÉ ESPERAR: la app no mira el aparato, mira el ancho de la ventana.
    private func requireWideWindow() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("Solo en ventana ancha (iPad Pro 13): en iPhone el ancho legible no cambia nada.")
        }
    }

    /// El iPad puede arrancar con la ventana flotante si «Apps en ventanas» está puesto: se fija a pantalla completa,
    /// como en `AdaptiveNavigationUITests`.
    private func ensureFullScreen(_ app: XCUIApplication) {
        if !app.windowIsFullScreen, app.hasResizableWindow {
            app.maximizeWindow()
        }
    }

    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertReadable(
        _ element: XCUIElement, _ what: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let width = element.frame.width
        XCTAssertGreaterThan(width, 200, "«\(what)» no tiene ancho medible (\(Int(width)) pt).", file: file, line: line)
        XCTAssertLessThanOrEqual(
            width, readableWidth,
            "«\(what)» va de lado a lado: \(Int(width)) pt, por encima del ancho legible de 700.",
            file: file, line: line)
    }

    /// La guía de pasos sale a los 0,5-1 s de montar la pantalla y tapa el contenido mientras está.
    private func skipCoachMarkIfShown(_ app: XCUIApplication) {
        let skip = app.buttons["coach_mark_skip"]
        if skip.waitForExistence(timeout: 4) {
            skip.tap()
            _ = skip.waitForNonExistence(timeout: 5)
        }
    }

    // MARK: - Estadísticas › Distribución (ficha 35)

    func test_distribution_keepsItsRowsAtTheReadableWidth() throws {
        try requireWideWindow()
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplinkURL: "yaladev://statistics/categories")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        ensureFullScreen(app)

        let row = app.buttons.matching(identifier: "distribution_category_row").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20), "No apareció la lista de categorías de Distribución.")
        attachScreenshot("distribucion")
        assertReadable(row, "Fila de categoría de Distribución")
    }

    // MARK: - Reportes: Comparativa y flujo de caja (ficha 36)

    func test_reports_keepComparisonSetupAndMonthAtTheReadableWidth() throws {
        try requireWideWindow()
        // Las tres medidas son independientes: un ancho de más en la Comparativa no impide medir el plan.
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        ensureFullScreen(app)

        // Comparativa: «Te quedó» es una tarjeta a todo lo ancho, al final de la página.
        app.openReport("comparativa")
        let net = element("report_net_summary", in: app)
        XCTAssertTrue(net.waitForExistence(timeout: 15), "No apareció «Te quedó» en la Comparativa.")
        attachScreenshot("reportes-comparativa")
        assertReadable(net, "Tarjeta «Te quedó» de la Comparativa")

        // Armar el plan.
        app.openReport("flujoDeCaja")
        XCTAssertTrue(
            element("cashflow_setup_view", in: app).waitForExistence(timeout: 15),
            "La vista de Flujo de Caja no montó (cashflow_setup_view).")
        skipCoachMarkIfShown(app)
        let summary = element("cashflow_setup_summary", in: app)
        XCTAssertTrue(summary.waitForExistence(timeout: 10), "No apareció el resumen del armado del plan.")
        attachScreenshot("flujo-armado")
        assertReadable(summary, "Resumen del armado del plan")

        // El mes del plan.
        let create = app.buttons["primary_button"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), "No apareció «Crear mi plan».")
        create.tap()
        XCTAssertTrue(
            app.staticTexts["cashflow_month_title"].waitForExistence(timeout: 15),
            "El plan no se creó (falta el título del mes).")
        skipCoachMarkIfShown(app)
        // Cada línea del mes (Salario, Alquiler…) es una tarjeta a todo lo ancho, con el importe en el borde derecho.
        let monthLine = app.buttons.matching(identifier: "cashflow_detail_line").firstMatch
        XCTAssertTrue(monthLine.waitForExistence(timeout: 10), "El mes del plan no enseña sus líneas.")
        attachScreenshot("flujo-mes")
        assertReadable(monthLine, "Línea del mes del flujo de caja")
    }

    // MARK: - Detalle de un grupo (ficha 37, P7)

    /// Con la lista al lado la columna del grupo mide ~600-660 pt (vertical, y horizontal con la barra lateral de
    /// páginas), por debajo de 700 sin arreglo (medido el 2026-11-10). Se estira de lado a lado al plegar la lista: en
    /// vertical el grupo ocupa entonces la ventana entera y su fila de gasto midió 1.000 pt.
    func test_groupDetail_keepsItsExpensesAtTheReadableWidth_withTheListFolded() throws {
        try requireWideWindow()
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        ensureFullScreen(app)

        let card = element("group_card", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 15), "No hay grupo sembrado.")
        card.tap()
        let expense = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'group_expense_row_'")).firstMatch
        XCTAssertTrue(expense.waitForExistence(timeout: 15), "El grupo abierto no enseña gastos.")

        // El botón que pliega la lista es el del sistema en la cabecera de la columna, sin identificador: se busca por
        // su etiqueta. El `ToggleSideBar` de las pestañas de arriba es otro (abre la barra lateral de páginas).
        let fold = app.buttons.matching(
            NSPredicate(format: "label IN %@", ["Ocultar barra lateral", "Hide Sidebar"])).firstMatch
        XCTAssertTrue(fold.waitForExistence(timeout: 5), "No está el botón que pliega la lista de grupos.")
        fold.tap()
        let listFolded = NSPredicate { _, _ in !card.exists || card.frame.maxX <= 1 }
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: listFolded, object: nil)], timeout: 5),
            .completed, "La lista de grupos no se plegó.")
        XCTAssertTrue(expense.waitForExistence(timeout: 5), "Al plegar la lista el grupo dejó de enseñar sus gastos.")
        attachScreenshot("grupo-detalle")
        assertReadable(expense, "Fila de gasto del grupo")
    }

    // MARK: - Ficha de una cuenta (ficha 39)

    func test_accountForm_opensAtPageSize_withItsContentAtTheReadableWidth() throws {
        try requireWideWindow()
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        ensureFullScreen(app)
        app.openProfile()
        app.openSettingsSection("profile_accounts")
        let addButton = app.buttons["accounts_add_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10), "No apareció accounts_add_button.")
        addButton.tap()

        let name = app.textFields["account_name_field"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "No apareció el formulario de cuenta.")
        attachScreenshot("cuenta-ficha")
        // La hoja centrada de media pantalla medía ~580 pt ENTERA: un campo más ancho que eso solo cabe a tamaño de
        // página. Y a tamaño de página no pasa del ancho legible.
        XCTAssertGreaterThan(
            name.frame.width, 580,
            "La ficha de la cuenta sigue en una hoja de media pantalla: el nombre mide \(Int(name.frame.width)) pt.")
        assertReadable(name, "Campo del nombre de la ficha de la cuenta")
    }
}
