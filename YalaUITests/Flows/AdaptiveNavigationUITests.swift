//
//  AdaptiveNavigationUITests.swift
//  YalaUITests
//
//  Navegación adaptativa (carril adaptativo, fase 1). La forma depende del ESPACIO de la ventana:
//
//  - Ventana ancha (iPad a pantalla completa): barra lateral con todas las páginas y sin «Más»;
//    en Registros y Planificación, la lista y el detalle a la vez.
//  - Ventana compacta (iPhone): la barra de pestañas de siempre; el registro abre su hoja y el
//    presupuesto se empuja.
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
}
