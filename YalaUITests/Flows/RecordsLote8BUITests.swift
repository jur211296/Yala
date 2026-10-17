//
//  RecordsLote8BUITests.swift
//  YalaUITests
//
//  Auditoría UX 2.2 · lote 8 (Registros): el resumen del día elegido en el calendario (L8-10) y «Quitar repetidos»
//  en el modo duplicados (L8-11). Se entra por Estadísticas › Registros, que monta la misma `RecordsTabView` que la
//  pestaña Registros. Seed `minimal`; los ids, no el texto.
//

import XCTest

final class RecordsLote8BUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Estadísticas (2º tab) → chip Registros, con la lista montada.
    private func openRecordsList(_ app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: 1).tap()
        let recordsChip = app.buttons["detail_chip_registros"]
        XCTAssertTrue(recordsChip.waitForExistence(timeout: 10), "No apareció el chip Registros en Estadísticas.")
        let chipsBar = app.scrollViews.containing(.button, identifier: "detail_chip_insights").firstMatch
        if chipsBar.exists {
            chipsBar.swipeLeft()
        }
        recordsChip.tap()
        XCTAssertTrue(
            app.buttons.matching(identifier: "record_row").element(boundBy: 0).waitForExistence(timeout: 5),
            "No hay filas de transacción (record_row)."
        )
    }

    /// L8-10: en la vista calendario, elegir un día con movimientos pone encima de la lista su resumen
    /// («Gastaste … · Entró …»). Antes no había total del día.
    func test_calendar_choosingADay_showsItsSummary() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openRecordsList(app)

        let calendarMode = app.buttons["records_view_mode_calendar"]
        XCTAssertTrue(calendarMode.waitForExistence(timeout: 5), "No apareció el botón de la vista calendario.")
        calendarMode.tap()

        let summary = app.descendants(matching: .any)["records_calendar_day_summary"]
        XCTAssertFalse(summary.exists, "El resumen del día salió sin elegir ningún día.")

        let activeDay = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "records_calendar_day_active_"))
            .firstMatch
        XCTAssertTrue(activeDay.waitForExistence(timeout: 5), "El calendario no tiene ningún día con gasto o ingreso.")
        activeDay.tap()

        XCTAssertTrue(summary.waitForExistence(timeout: 5), "Al elegir un día con movimientos no salió su resumen.")
    }

    /// L8-11: con un duplicado hecho a mano, el modo duplicados enseña su encabezado y «Quitar repetidos»; la
    /// confirmación es una alerta con Cancelar visible, y al confirmar los repetidos se van (el botón desaparece
    /// porque ya no queda nada que quitar).
    func test_duplicates_removeRepeated_asksFirst_andLeavesOnePerGroup() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openRecordsList(app)

        // 1. Un duplicado a mano: detalle → Editar → Duplicar → Guardar. La copia lleva la fecha de hoy, así que
        //    luego se quita «Fecha» de los criterios.
        app.buttons.matching(identifier: "record_row").element(boundBy: 0).tap()
        let editButton = app.buttons["transaction_detail_edit"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "No se montó el sheet de detalle.")
        editButton.tap()
        let duplicate = app.buttons["new_transaction_duplicate_action"]
        XCTAssertTrue(duplicate.waitForExistence(timeout: 5), "El editor no ofreció Duplicar.")
        duplicate.tap()
        let save = app.buttons["new_transaction_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Falta Guardar en el editor.")
        save.tap()
        let accept = app.buttons["transaction_success_accept"]
        if accept.waitForExistence(timeout: 5) {
            accept.tap()
            XCTAssertTrue(accept.waitForNonExistence(timeout: 5), "La pantalla de éxito no se cerró.")
        }
        XCTAssertTrue(save.waitForNonExistence(timeout: 5), "El editor no se cerró tras guardar la copia.")

        // 2. Modo duplicados, sin «Fecha».
        let menu = app.recordsOverflowMenu
        XCTAssertTrue(menu.waitForExistence(timeout: 5), "No apareció el menú (···) de Registros.")
        menu.tap()
        let toggle = app.buttons["Identificar duplicados"].firstMatch  // dentro de un Menu el id no llega a la accesibilidad (medido)
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "El menú no ofreció «Identificar duplicados».")
        toggle.tap()

        let header = app.descendants(matching: .any)["records_duplicates_header"]
        XCTAssertTrue(header.waitForExistence(timeout: 5), "No salió el encabezado del modo duplicados.")
        XCTAssertFalse(app.descendants(matching: .any)["records_summary_balance"].exists,
                       "En modo duplicados sigue el resumen del período.")

        menu.tap()
        let matchBy = app.buttons["Coincidir por"].firstMatch
        XCTAssertTrue(matchBy.waitForExistence(timeout: 5), "El menú no ofreció «Coincidir por».")
        matchBy.tap()
        let dateCriterion = app.buttons["Fecha"].firstMatch
        XCTAssertTrue(dateCriterion.waitForExistence(timeout: 5), "«Coincidir por» no ofreció «Fecha».")
        dateCriterion.tap()

        // 3. Quitar repetidos: primero pregunta, con Cancelar a la vista.
        let remove = app.buttons["records_duplicates_remove"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "Con un duplicado hecho a mano no salió «Quitar repetidos».")
        remove.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "«Quitar repetidos» no preguntó antes de borrar.")
        XCTAssertTrue(alert.buttons["records_duplicates_remove_cancel"].firstMatch.exists, "La confirmación no tiene Cancelar.")
        let confirm = alert.buttons["records_duplicates_remove_confirm"].firstMatch
        XCTAssertTrue(confirm.exists, "La confirmación no tiene «Quitar».")
        confirm.tap()

        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), "La confirmación no se cerró.")
        XCTAssertTrue(remove.waitForNonExistence(timeout: 10), "Tras quitar los repetidos sigue habiendo algo que quitar.")
    }
}
