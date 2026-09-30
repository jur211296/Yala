//
//  AdaptiveNavigationUITests.swift
//  YalaUITests
//
//  Navegación adaptativa (carril adaptativo, fases 1 y 2). La forma depende del ESPACIO de la ventana:
//
//  - Ventana ancha (iPad a pantalla completa): barra lateral con todas las páginas y sin «Más»;
//    en Registros y Planificación, la lista y el detalle a la vez.
//  - Ventana compacta (iPhone): la barra de pestañas de siempre; el registro abre su hoja y el
//    presupuesto se empuja.
//  - Fase 2: Grupos y Ajustes con lista y detalle a la vez en ancho (en iPhone, empujados), y Yala IA en
//    una columna al lado de los datos (en iPhone, la hoja de siempre).
//  - Fase 2b: el Panel y Estadísticas en pares en ancho (cabecera en banda, Resumen en dos columnas) y el
//    registro de Estadísticas › Registros en un panel al lado de la lista (en iPhone, la hoja de siempre).
//
//  El mismo test corre en los dos: el runner pregunta al propio dispositivo qué forma esperar. Correrlo
//  por UDID en `YalaLane-Adapt-iPad-Pro-13` y `YalaLane-Adapt-iPhone-ProMax` (reglas del carril).
//  Seed `realista` + Pro: hace falta más de un presupuesto y registros de varios días.
//  Los casos de «Estrechar la ventana» necesitan además Ajustes → Multitarea y gestos → «Apps en ventanas» en el
//  iPad; sin eso, o en iPhone, se saltan diciéndolo (`XCTSkip`). Redimensionan con `XCUIApplication+Window`.
//

import XCTest

final class AdaptiveNavigationUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// iPad a pantalla completa = ventana ancha. Solo decide QUÉ ESPERAR; la app no mira el aparato.
    private var expectsWideWindow: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private func launch(deeplink: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: deeplink)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// Barra lateral: las seis páginas a la vista, sin pasar por Más. En iPhone, la barra de pestañas con Más.
    func test_rootShowsSidebarInWideWindow_andTabBarInCompact() {
        // En vertical el iPad pinta las pestañas arriba (y esconde las últimas tras «›»); la barra lateral
        // a la vista es la de horizontal. El iPhone solo gira en vertical, así que no le cambia nada.
        if expectsWideWindow { XCUIDevice.shared.orientation = .landscapeLeft }
        let app = launch()
        if expectsWideWindow {
            // Las entradas de la barra lateral no salen como `Button` en el árbol: se buscan por etiqueta.
            func sidebarEntry(_ label: String) -> XCUIElement {
                app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
            }
            for page in ["Panel", "Estadísticas", "Planificación", "Registros", "Reportes", "Grupos"] {
                XCTAssertTrue(sidebarEntry(page).waitForExistence(timeout: 10), "La barra lateral no enseña «\(page)».")
            }
            XCTAssertFalse(sidebarEntry("Más").exists, "«Más» no debería existir con barra lateral.")
            sidebarEntry("Grupos").tap()
            XCTAssertTrue(
                app.navigationBars["Grupos"].waitForExistence(timeout: 10),
                "Tocar Grupos en la barra lateral no abrió Grupos.")
        } else {
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "No hay barra de pestañas en iPhone.")
            XCTAssertTrue(app.tabBars.buttons["Más"].exists, "La barra de pestañas perdió «Más».")
            XCTAssertFalse(app.tabBars.buttons["Registros"].exists, "Registros no está en la configuración por defecto.")
        }
    }

    /// Registros: en ancho, el registro se abre al lado y la lista sigue a la vista; Editar abre el editor
    /// y al cerrarlo el registro sigue abierto. En iPhone, la hoja de siempre.
    func test_recordOpensBesideTheList_inWideWindow_andAsSheetInCompact() {
        let app = launch(deeplink: "records")
        let rows = app.buttons.matching(identifier: "record_row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 15), "No hay filas de registro.")

        if expectsWideWindow {
            XCTAssertTrue(
                app.otherElements["records_detail_placeholder"].waitForExistence(timeout: 5)
                    || app.staticTexts["Elige un registro para verlo aquí"].exists,
                "La columna de detalle vacía no aparece.")
        }

        rows.element(boundBy: 0).tap()
        let edit = app.buttons["transaction_detail_edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "No se abrió el detalle del registro.")

        if expectsWideWindow {
            XCTAssertFalse(app.buttons["transaction_detail_close"].exists, "En columna el detalle no lleva X.")
            XCTAssertTrue(rows.element(boundBy: 1).isHittable, "La lista dejó de verse al abrir el registro.")

            // Otro registro sustituye al primero en la misma columna.
            rows.element(boundBy: 1).tap()
            XCTAssertTrue(edit.waitForExistence(timeout: 5))

            edit.tap()
            let save = app.buttons["new_transaction_save"]
            XCTAssertTrue(save.waitForExistence(timeout: 10), "Editar no abrió el editor.")
            app.swipeDown(velocity: .fast)
            if save.exists, app.buttons["Cancelar"].exists { app.buttons["Cancelar"].firstMatch.tap() }
            XCTAssertTrue(edit.waitForExistence(timeout: 10), "Al cerrar el editor el registro dejó de estar abierto.")
        } else {
            XCTAssertTrue(app.buttons["transaction_detail_close"].exists, "La hoja de detalle perdió su X.")
            app.buttons["transaction_detail_close"].tap()
            XCTAssertTrue(edit.waitForNonExistence(timeout: 5), "La hoja de detalle no se cerró.")
        }
    }

    /// Planificación: en ancho, el presupuesto se abre en la columna de detalle con la lista a la vista.
    /// En iPhone, se empuja y Atrás vuelve a la lista.
    func test_budgetOpensBesideTheList_inWideWindow_andPushesInCompact() {
        let app = launch(deeplink: "budgets")
        let budgetRows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'budget_row_'"))
        XCTAssertTrue(budgetRows.firstMatch.waitForExistence(timeout: 15), "No hay presupuestos sembrados.")
        budgetRows.element(boundBy: 0).tap()

        let detail = app.scrollViews["budget_detail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 10), "No se abrió el detalle del presupuesto.")

        if expectsWideWindow {
            XCTAssertTrue(budgetRows.element(boundBy: 0).isHittable, "La lista de presupuestos dejó de verse.")
            XCTAssertTrue(app.buttons["planning_chip_scheduledPayments"].isHittable, "Los chips de Planificación dejaron de verse.")
        } else {
            XCTAssertFalse(budgetRows.element(boundBy: 0).isHittable, "En iPhone el detalle se empuja sobre la lista.")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(budgetRows.firstMatch.waitForExistence(timeout: 5), "Atrás no volvió a la lista.")
        }
    }

    // MARK: - Fase 2

    /// Grupos: en ancho, el grupo se abre en la columna de detalle con la lista y la navegación de la app a la
    /// vista. En iPhone, se empuja, inmersivo y sin barra de pestañas, y su chevron vuelve a la lista.
    func test_groupOpensBesideTheList_inWideWindow_andPushesInCompact() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "No hay grupo sembrado.")
        if expectsWideWindow {
            XCTAssertTrue(
                app.descendants(matching: .any).matching(identifier: "groups_detail_placeholder").firstMatch
                    .waitForExistence(timeout: 5),
                "La columna de detalle vacía de Grupos no aparece.")
        }

        card.tap()
        let members = app.buttons["group_members_button"]
        XCTAssertTrue(members.waitForExistence(timeout: 10), "No se abrió el grupo.")

        if expectsWideWindow {
            XCTAssertTrue(card.isHittable, "La lista de grupos dejó de verse al abrir el grupo.")
            // En columna no hay «volver»: no hay adónde, la lista está al lado (la navegación sigue en las capturas).
            XCTAssertFalse(app.buttons["group_detail_back"].exists, "En columna el grupo no lleva chevron de volver.")
        } else {
            XCTAssertFalse(card.isHittable, "En iPhone el grupo se empuja sobre la lista.")
            XCTAssertFalse(app.tabBars.firstMatch.isHittable, "En iPhone el grupo abierto oculta la barra de pestañas.")
            app.buttons["group_detail_back"].tap()
            XCTAssertTrue(card.waitForHittable(timeout: 5), "El chevron no volvió a la lista.")
        }
    }

    /// Ajustes: en ancho, dos columnas dentro de su hoja (la lista y el ajuste abierto a la vez). En iPhone, la
    /// hoja de siempre, que empuja el ajuste y Atrás vuelve.
    func test_settingsShowListAndSetting_inWideWindow_andPushInCompact() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()

        let currencyRow = app.buttons["profile_currency"]
        XCTAssertTrue(currencyRow.waitForExistence(timeout: 10), "No apareció la fila Divisa en Ajustes.")
        if expectsWideWindow {
            XCTAssertTrue(
                app.descendants(matching: .any).matching(identifier: "settings_detail_placeholder").firstMatch
                    .waitForExistence(timeout: 5),
                "Ajustes no enseña su columna de detalle en una ventana ancha.")
        }

        currencyRow.tap()
        XCTAssertTrue(
            app.buttons["currency_secondary_button"].waitForExistence(timeout: 10), "No se abrió Divisa y Cambio.")

        if expectsWideWindow {
            XCTAssertTrue(app.buttons["profile_accounts"].isHittable, "La lista de Ajustes dejó de verse.")
        } else {
            XCTAssertFalse(app.buttons["profile_accounts"].isHittable, "En iPhone el ajuste se empuja sobre la lista.")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.buttons["profile_accounts"].waitForHittable(timeout: 5), "Atrás no volvió a Ajustes.")
        }
    }

    /// Yala IA: en ancho, columna al lado de Registros, que sigue a la vista y se puede tocar; al abrir un
    /// registro con el chat al lado, la lista se aparta para que el registro se lea entero, y el chat sigue. Su X lo
    /// cierra. En iPhone, la hoja de siempre, que tapa la lista.
    func test_chatOpensBesideTheData_inWideWindow_andAsSheetInCompact() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: "records", aiChatReady: true)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let rows = app.buttons.matching(identifier: "record_row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 15), "No hay filas de registro.")
        let chatEntry = app.buttons["fab_chat"]
        XCTAssertTrue(chatEntry.waitForExistence(timeout: 10), "No aparece la entrada de Yala IA en Registros.")
        chatEntry.tap()

        let input = app.textFields["chat_input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10), "No se abrió Yala IA.")

        if expectsWideWindow {
            XCTAssertTrue(rows.firstMatch.isHittable, "Con Yala IA abierto, Registros dejó de verse.")
            rows.firstMatch.tap()
            let edit = app.buttons["transaction_detail_edit"]
            XCTAssertTrue(edit.waitForExistence(timeout: 10), "Con Yala IA al lado, un registro no se abre.")
            XCTAssertTrue(edit.waitForHittable(timeout: 5), "El registro abierto queda tapado por Yala IA.")
            XCTAssertTrue(input.exists, "Abrir un registro cerró Yala IA.")
        } else {
            XCTAssertFalse(rows.firstMatch.isHittable, "En iPhone Yala IA es una hoja sobre Registros.")
        }
        app.buttons["chat_close"].tap()
        XCTAssertTrue(input.waitForNonExistence(timeout: 5), "La X no cerró Yala IA.")
    }

    // MARK: - Estrechar la ventana

    /// Las seis páginas, en la lateral y en el orden de siempre.
    private let pages = ["Panel", "Estadísticas", "Planificación", "Registros", "Reportes", "Grupos"]

    /// Toca un chip de Estadísticas. En iPhone los últimos quedan fuera del carril horizontal: se desplaza hasta verlo.
    private func tapStatisticsChip(_ id: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let chip = app.buttons[id]
        XCTAssertTrue(chip.waitForExistence(timeout: 15), "No está el chip \(id).", file: file, line: line)
        let bar = app.scrollViews.containing(.button, identifier: "detail_chip_insights").firstMatch
        var swipes = 0
        while swipes < 4 && !app.frame.insetBy(dx: 1, dy: 1).contains(chip.frame) {
            if chip.frame.minX < app.frame.minX { bar.swipeRight() } else { bar.swipeLeft() }
            swipes += 1
        }
        chip.tap()
    }

    private func label(_ text: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label == %@", text)).firstMatch
    }

    /// Fase 2b: en ancho (horizontal), «Tus finanzas» sube a la derecha del saldo y las acciones, en la misma
    /// banda; en iPhone sigue debajo de las acciones.
    func test_panelHeader_putsYourFinancesBesideTheBalance_inWideWindow() {
        if expectsWideWindow { XCUIDevice.shared.orientation = .landscapeLeft }
        let app = launch(deeplink: "panel")
        let newRecord = app.buttons["panel_action_new"]
        let finances = label("Tus finanzas", in: app)
        XCTAssertTrue(newRecord.waitForExistence(timeout: 15), "No está la fila de acciones del Panel.")
        XCTAssertTrue(finances.waitForExistence(timeout: 10), "No está «Tus finanzas».")

        if expectsWideWindow {
            XCTAssertLessThan(finances.frame.minY, newRecord.frame.maxY, "«Tus finanzas» no está en la banda de la cabecera.")
            XCTAssertGreaterThan(finances.frame.minX, newRecord.frame.maxX, "«Tus finanzas» no está a la derecha de las acciones.")
        } else {
            XCTAssertGreaterThan(finances.frame.minY, newRecord.frame.maxY, "En iPhone «Tus finanzas» dejó de ir debajo.")
        }
    }

    /// Fase 2b: Estadísticas › Resumen en pares en ancho: «Tu salud financiera» y «Resumen inteligente» en la misma
    /// fila. En iPhone, uno debajo de otro.
    func test_statisticsSummary_pairsTheCards_inWideWindow() {
        if expectsWideWindow { XCUIDevice.shared.orientation = .landscapeLeft }
        let app = launch(deeplink: "statistics")
        let health = label("Tu salud financiera", in: app)
        let smart = label("Resumen inteligente", in: app)
        XCTAssertTrue(health.waitForExistence(timeout: 15), "No está «Tu salud financiera».")
        XCTAssertTrue(smart.waitForExistence(timeout: 10), "No está «Resumen inteligente».")

        if expectsWideWindow {
            XCTAssertGreaterThan(smart.frame.minX, health.frame.maxX, "«Resumen inteligente» no está al lado de la salud financiera.")
            XCTAssertLessThan(abs(smart.frame.midY - health.frame.midY), 60, "Las dos tarjetas no están en la misma fila.")
        } else {
            XCTAssertGreaterThan(smart.frame.minY, health.frame.maxY, "En iPhone el Resumen dejó de ir en una columna.")
        }
    }

    /// Fase 2b: Estadísticas › Registros. En ancho el registro se abre en un panel al lado de la lista, sin tocar la
    /// barra de Estadísticas (sigue su título grande), y su X lo cierra. En iPhone, la hoja de siempre.
    func test_statisticsRecordOpensBesideTheList_inWideWindow_andAsSheetInCompact() {
        let app = launch(deeplink: "statistics")
        tapStatisticsChip("detail_chip_registros", in: app)
        let rows = app.buttons.matching(identifier: "record_row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 15), "No hay filas de registro.")

        if expectsWideWindow {
            XCTAssertTrue(
                app.descendants(matching: .any)["stats_records_detail_placeholder"].waitForExistence(timeout: 5),
                "El panel vacío no aparece al lado de la lista.")
        }

        rows.element(boundBy: 0).tap()
        let edit = app.buttons["transaction_detail_edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "No se abrió el detalle del registro.")
        let close = app.buttons["transaction_detail_close"]
        XCTAssertTrue(close.exists, "El detalle no tiene X.")

        if expectsWideWindow {
            XCTAssertTrue(
                app.descendants(matching: .any)["transaction_detail_pane"].exists,
                "El registro no se abrió en el panel (¿hoja?).")
            XCTAssertFalse(app.descendants(matching: .any)["transaction_detail_sheet"].exists, "En ancho no debe salir la hoja.")
            XCTAssertTrue(rows.element(boundBy: 1).isHittable, "La lista dejó de verse al abrir el registro.")
            XCTAssertTrue(app.navigationBars["Estadísticas"].exists, "El panel cambió la barra de Estadísticas.")

            // Otro registro sustituye al primero en el mismo panel.
            rows.element(boundBy: 1).tap()
            XCTAssertTrue(edit.waitForExistence(timeout: 5))

            close.tap()
            XCTAssertTrue(
                app.descendants(matching: .any)["stats_records_detail_placeholder"].waitForExistence(timeout: 5),
                "La X no devolvió el panel a vacío.")
        } else {
            XCTAssertTrue(app.descendants(matching: .any)["transaction_detail_sheet"].exists, "En iPhone el detalle es la hoja.")
            close.tap()
            XCTAssertTrue(edit.waitForNonExistence(timeout: 5), "La hoja de detalle no se cerró.")
        }
    }

    /// Arranca en horizontal con la ventana a pantalla completa. Salta si no hay ventana que estrechar: en iPhone,
    /// o en un iPad con «Apps en pantalla completa» (Ajustes → Multitarea y gestos → «Apps en ventanas» lo activa).
    private func launchInResizableWindow(seed: String) throws -> XCUIApplication {
        guard expectsWideWindow else { throw XCTSkip("Solo en iPad: en iPhone la ventana no se redimensiona.") }
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: seed)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        guard app.hasResizableWindow else {
            throw XCTSkip("El iPad no tiene «Apps en ventanas» (Ajustes → Multitarea y gestos): no hay ventana que estrechar.")
        }
        app.maximizeWindow()
        return app
    }

    private func sidebarEntry(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// Ticket `ipad-narrowing-the-window-on-groups-crashes-the-app`: estrechar la ventana con cualquiera de las seis
    /// páginas seleccionada pasa a pestañas abajo con esa página a la vista, sin cerrar la app; y al volver a ancho,
    /// la barra lateral vuelve con la misma página. Antes se cerraba con cinco de las seis: todas menos Registros.
    func test_narrowingTheWindow_keepsEveryPageOpen_andWideningBringsTheSidebarBack() throws {
        let app = try launchInResizableWindow(seed: "grupos")
        for page in pages {
            let entry = sidebarEntry(page, in: app)
            XCTAssertTrue(entry.waitForExistence(timeout: 10), "La barra lateral no enseña «\(page)».")
            entry.tap()

            app.narrowWindow()
            let tab = app.tabBars.buttons[page]
            XCTAssertTrue(tab.waitForExistence(timeout: 10), "Al estrechar con «\(page)», no hay pestaña «\(page)» abajo.")
            XCTAssertTrue(tab.isSelected, "Al estrechar con «\(page)», la pestaña seleccionada es otra.")
            XCTAssertTrue(app.tabBars.buttons["Más"].exists, "La barra estrecha perdió «Más».")
            XCTAssertEqual(app.state, .runningForeground, "La app se cerró al estrechar con «\(page)».")

            app.maximizeWindow()
            XCTAssertTrue(
                app.tabBars.buttons["Más"].waitForNonExistence(timeout: 10),
                "Al volver a ancho con «\(page)», «Más» sigue a la vista.")
            XCTAssertTrue(
                sidebarEntry(pages.last ?? page, in: app).waitForExistence(timeout: 10),
                "Al volver a ancho con «\(page)», la barra lateral no vuelve.")
        }
    }

    /// Fase 2b: en Estadísticas, estrechar la ventana vuelve a una columna sin perder el chip ni el período, y un
    /// registro abierto en el panel pasa a la hoja; al volver a ancho, la barra lateral vuelve con el mismo chip.
    func test_narrowingTheWindow_onStatistics_keepsTheChipThePeriodAndTheOpenRecord() throws {
        let app = try launchInResizableWindow(seed: "realista")
        let stats = sidebarEntry("Estadísticas", in: app)
        XCTAssertTrue(stats.waitForExistence(timeout: 10), "La barra lateral no enseña Estadísticas.")
        stats.tap()

        // Tendencias, con otro período que el de arranque.
        let trends = app.buttons["detail_chip_tendencias"]
        XCTAssertTrue(trends.waitForExistence(timeout: 10), "No está el chip Tendencias.")
        trends.tap()
        // La semilla arranca en «Todo el tiempo»: se cambia a «Este mes».
        let periodMenu = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Todo el tiempo")).firstMatch
        XCTAssertTrue(periodMenu.waitForExistence(timeout: 10), "No está el selector de período.")
        periodMenu.tap()
        let thisMonth = app.buttons["Este mes"]
        XCTAssertTrue(thisMonth.waitForExistence(timeout: 5), "El selector no ofrece «Este mes».")
        thisMonth.tap()
        let periodPill = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Este mes")).firstMatch
        XCTAssertTrue(periodPill.waitForExistence(timeout: 5), "El período no cambió.")

        app.narrowWindow()
        XCTAssertTrue(app.tabBars.buttons["Estadísticas"].waitForExistence(timeout: 10), "Al estrechar no queda Estadísticas.")
        XCTAssertTrue(app.buttons["detail_chip_tendencias"].isSelected || app.otherElements["stats_tab_trends"].exists
            || app.descendants(matching: .any)["stats_tab_trends"].exists, "Al estrechar se perdió Tendencias.")
        XCTAssertTrue(periodPill.waitForExistence(timeout: 5), "Al estrechar se perdió el período.")
        app.maximizeWindow()
        XCTAssertTrue(app.descendants(matching: .any)["stats_tab_trends"].waitForExistence(timeout: 10), "Al volver a ancho se perdió Tendencias.")
        XCTAssertTrue(periodPill.exists, "Al volver a ancho se perdió el período.")

        // Registro abierto en el panel → al estrechar, la hoja con el mismo registro.
        tapStatisticsChip("detail_chip_registros", in: app)
        let row = app.buttons.matching(identifier: "record_row").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "No hay filas de registro.")
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["transaction_detail_pane"].waitForExistence(timeout: 10), "No se abrió el panel.")
        app.narrowWindow()
        XCTAssertTrue(
            app.descendants(matching: .any)["transaction_detail_sheet"].waitForExistence(timeout: 10),
            "Al estrechar con un registro abierto, no pasó a la hoja.")
        XCTAssertEqual(app.state, .runningForeground, "La app se cerró al estrechar en Estadísticas.")
        app.buttons["transaction_detail_close"].tap()
        app.maximizeWindow()
    }

    /// Con un grupo abierto al lado de la lista, estrechar la ventana no cierra la app y el grupo sigue a la vista,
    /// empujado, con su chevron de volver.
    func test_narrowingTheWindow_withAGroupOpen_keepsTheGroupPushed() throws {
        let app = try launchInResizableWindow(seed: "grupos")
        let groups = sidebarEntry("Grupos", in: app)
        XCTAssertTrue(groups.waitForExistence(timeout: 10), "La barra lateral no enseña Grupos.")
        groups.tap()
        let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "No hay grupo sembrado.")
        card.tap()
        let members = app.buttons["group_members_button"]
        XCTAssertTrue(members.waitForExistence(timeout: 10), "No se abrió el grupo.")

        app.narrowWindow()
        XCTAssertTrue(
            app.buttons["group_detail_back"].waitForExistence(timeout: 10),
            "Al estrechar, el grupo abierto no sigue empujado con su chevron.")
        XCTAssertTrue(members.waitForHittable(timeout: 5), "Al estrechar, el grupo abierto dejó de verse.")
        XCTAssertFalse(card.isHittable, "Al estrechar, la lista tapa el grupo abierto.")
        XCTAssertEqual(app.state, .runningForeground, "La app se cerró al estrechar con un grupo abierto.")
        app.maximizeWindow()
    }
}
