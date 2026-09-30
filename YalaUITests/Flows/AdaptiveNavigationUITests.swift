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
//
//  El mismo test corre en los dos: el runner pregunta al propio dispositivo qué forma esperar. Correrlo
//  por UDID en `YalaLane-Adapt-iPad-Pro-13` y `YalaLane-Adapt-iPhone-ProMax` (reglas del carril).
//  Seed `realista` + Pro: hace falta más de un presupuesto y registros de varios días.
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
}
