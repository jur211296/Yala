//
//  RecordsCalendarWeek23UITests.swift
//  YalaUITests
//
//  Revisión 2.3 · Registros (ficha 31), decisiones 19, 66 y 67 de Jürgen (9-nov):
//
//  - 19 (C2): al tocar un día del calendario, el mes se pliega a la semana de ese día y su lista queda debajo, a la
//    vista. Antes solo cambiaba la celda: el resumen y las filas quedaban debajo del mes, fuera de la pantalla.
//  - 66: en el iPad el calendario no se aprieta en la columna de la lista (375-480 pt) con el detalle vacío al lado.
//  - 67: en el iPad el título de la columna de la lista no sale cortado («Registr…»).
//
//  Semilla «realista» (dos años, «Todo el tiempo»): el calendario es el de un mes con flechas, el caso de la ficha. Los
//  dos casos del iPad corren por UDID en un iPad Pro 13 y se saltan en el iPhone diciéndolo.
//

import XCTest

final class RecordsCalendarWeek23UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    private func launchInRecords() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "realista", deeplink: "records")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        if UIDevice.current.userInterfaceIdiom == .pad, !app.windowIsFullScreen, app.hasResizableWindow {
            app.maximizeWindow()
        }
        return app
    }

    private func requireWideWindow() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("Solo en ventana ancha (iPad Pro 13): en el iPhone no hay columna de lista.")
        }
    }

    private func openCalendar(_ app: XCUIApplication) {
        let calendarMode = app.buttons["records_view_mode_calendar"]
        XCTAssertTrue(calendarMode.waitForExistence(timeout: 20), "No apareció el botón de la vista calendario.")
        calendarMode.tap()
        XCTAssertTrue(
            dayCells(app).firstMatch.waitForExistence(timeout: 10), "El calendario no pintó ningún día.")
    }

    private func dayCells(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "records_calendar_day_"))
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Visible de verdad: dentro de la ventana, no solo en el árbol (el árbol trae también lo que queda debajo).
    private func isOnScreen(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        let window = app.windows.firstMatch.frame
        let frame = element.frame
        return element.exists && frame.height > 0 && frame.minY >= window.minY && frame.maxY <= window.maxY
    }

    // MARK: - 19 · C2: el mes se pliega a la semana

    func test_choosingADay_foldsTheMonthToItsWeek_andItsListIsOnScreen() {
        let app = launchInRecords()
        openCalendar(app)
        let monthDays = dayCells(app).count
        XCTAssertGreaterThan(monthDays, 7, "El calendario no enseña el mes entero antes de elegir un día.")

        // El último día con movimientos del mes: el de más abajo, el que más lejos dejaba su lista.
        let activeDays = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "records_calendar_day_active_"))
        XCTAssertTrue(activeDays.firstMatch.waitForExistence(timeout: 5), "El calendario no tiene días con movimientos.")
        let activeDay = activeDays.element(boundBy: activeDays.count - 1)
        let dayID = activeDay.identifier
        activeDay.tap()

        let weekHeader = app.buttons["records_calendar_week_header"]
        XCTAssertTrue(weekHeader.waitForExistence(timeout: 5), "Al elegir un día no salió la cabecera de su semana.")
        XCTAssertEqual(dayCells(app).count, 7, "Al elegir un día el mes no se plegó a su semana.")
        XCTAssertTrue(app.buttons[dayID].exists, "El día elegido no está en la semana plegada.")

        let summary = app.descendants(matching: .any)["records_calendar_day_summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "No salió el resumen del día elegido.")
        let firstRow = app.buttons.matching(identifier: "record_row").firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "El día elegido no enseña sus registros.")
        attachScreenshot("c2-semana-plegada")
        XCTAssertTrue(isOnScreen(summary, in: app), "El resumen del día quedó fuera de la pantalla: \(summary.frame).")
        XCTAssertTrue(
            isOnScreen(firstRow, in: app), "El primer registro del día quedó fuera de la pantalla: \(firstRow.frame).")

        // La cabecera de la semana vuelve a desplegar el mes.
        weekHeader.tap()
        XCTAssertTrue(weekHeader.waitForNonExistence(timeout: 5), "Tocar la semana no desplegó el mes.")
        XCTAssertEqual(dayCells(app).count, monthDays, "Al desplegar no volvió el mes entero.")
        XCTAssertFalse(summary.exists, "Al desplegar el mes siguió el resumen de un día.")
    }

    // MARK: - 66 · iPad: el calendario no se aprieta en la columna de la lista

    func test_iPad_calendarIsNotSqueezedIntoTheListColumn() throws {
        try requireWideWindow()
        let app = launchInRecords()
        let placeholder = app.descendants(matching: .any)["records_detail_placeholder"]
        XCTAssertTrue(placeholder.waitForExistence(timeout: 20), "Con la lista, el iPad no enseña el detalle al lado.")
        openCalendar(app)
        attachScreenshot("ipad-calendario")

        // Del lunes al domingo de la primera fila (centro a centro): en la columna de la lista (375-480 pt) ~270 pt; al
        // ancho legible (700) ~540; de lado a lado (~1.000) pasaría de 780. El marco de una celda sola no sirve: el de
        // un día fuera del mes mide solo su número (medido: 14 pt).
        let cells = dayCells(app)
        XCTAssertGreaterThanOrEqual(cells.count, 7, "El calendario no tiene una semana entera.")
        let span = cells.element(boundBy: 6).frame.midX - cells.element(boundBy: 0).frame.midX
        XCTAssertGreaterThan(span, 420, "El calendario sigue apretado: de lunes a domingo hay \(Int(span)) pt.")
        XCTAssertLessThan(span, 640, "El calendario va de lado a lado: de lunes a domingo hay \(Int(span)) pt.")
        XCTAssertFalse(placeholder.exists, "Con el calendario sigue al lado la columna de detalle vacía.")

        // De vuelta a la lista, la columna de detalle vuelve.
        app.buttons["records_view_mode_list"].tap()
        XCTAssertTrue(placeholder.waitForExistence(timeout: 10), "Al volver a la lista no volvió la columna de detalle.")
    }

    // MARK: - 67 · iPad: el título de la columna cabe entero

    /// La columna de la lista del iPad lleva el título en la barra (no admite título grande) junto a «Seleccionar», «···»,
    /// el avatar y el botón de la barra lateral; con «Seleccionar» en texto, el título salía «Registr…» (medido: 72 pt
    /// de ancho, 16 pt hasta el botón). Con el botón en icono, el título cabe entero y el botón sigue a la vista.
    func test_iPad_listColumnTitle_fitsWhole() throws {
        try requireWideWindow()
        let app = launchInRecords()
        let select = app.buttons["records_select_visible"]
        XCTAssertTrue(select.waitForExistence(timeout: 20), "No apareció «Seleccionar» en la barra de Registros.")
        let title = app.navigationBars.staticTexts.matching(NSPredicate(format: "label == %@", "Registros")).firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5), "No apareció el título «Registros».")
        attachScreenshot("ipad-titulo")
        XCTAssertEqual(select.label, "Seleccionar", "«Seleccionar» perdió su nombre para VoiceOver.")
        XCTAssertLessThanOrEqual(
            select.frame.width, 56, "«Seleccionar» sigue en texto en la columna: mide \(Int(select.frame.width)) pt.")
        // Un título cortado llena todo su hueco hasta el primer botón (medido: 16 pt de margen, el del sistema). Entero,
        // le sobra sitio (medido: ~90 pt).
        let room = select.frame.minX - title.frame.maxX
        XCTAssertGreaterThan(
            room, 40, "El título sigue apretado contra los botones (\(Int(room)) pt): \(title.frame), \(select.frame).")
    }
}
