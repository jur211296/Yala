//
//  BulkEditUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `transactions-bulk-edit` (escenarios 5.14-5.22):
//  modo selección en la lista de Registros (Estadísticas → chip Registros) +
//  edición masiva de la nota de varias transacciones. La verificación es de
//  FLUJO (el modo selección termina y vuelve a la lista normal), no de contenido,
//  porque las filas no tienen texto estable. Seed `minimal`.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class BulkEditUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Navega a Estadísticas (2º tab del config por defecto) → chip Registros
    /// (el chip por defecto es Insights) → activa el modo selección. La barra de
    /// chips es un ScrollView horizontal y Registros (el último) puede quedar fuera
    /// de vista → se revela con swipe sobre un chip visible antes de tocarlo.
    private func enterRecordsSelectionMode(_ app: XCUIApplication) {
        app.selectTab(.statistics)

        let recordsChip = app.buttons["detail_chip_registros"]
        XCTAssertTrue(recordsChip.waitForExistence(timeout: 10), "No apareció el chip Registros en Estadísticas.")
        // Scrollear el contenedor horizontal de chips para revelar Registros (último).
        // (Consultar .isHittable de un elemento fuera de vista lanza, así que se
        // scrollea el ScrollView que contiene los chips directamente.)
        let chipsBar = app.scrollViews.containing(.button, identifier: "detail_chip_insights").firstMatch
        if chipsBar.exists {
            chipsBar.swipeLeft()
        }
        recordsChip.tap()

        enterSelectMode(app)
    }

    /// Entra en el modo selección por «Seleccionar» de la barra de arriba (L8-12) y comprueba que entró.
    ///
    /// Antes entraba por el menú «···», y en el runner del CI el toque en «Seleccionar» del menú se perdía a veces: la
    /// barra seguía en modo normal, tocar una fila abría su detalle y el caso moría en `bulk_edit_button` (nocturnas del
    /// 26 al 29-oct). Sin comprobar el modo, el rojo salía tres pasos más tarde y apuntaba a la edición masiva.
    private func enterSelectMode(_ app: XCUIApplication) {
        let select = app.buttons["records_select_visible"]
        XCTAssertTrue(select.waitForExistence(timeout: 10), "«Seleccionar» no está en la barra de Registros.")
        select.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["records_selection_hint"].waitForExistence(timeout: 10),
            "Tocar «Seleccionar» no activó el modo selección (records_selection_hint)."
        )
    }

    /// Elige las dos primeras filas y espera a que la barra diga «2 seleccionados». Cada fila se toca cuando es
    /// alcanzable: en el CI la primera salía a veces con el punto de impacto en `{-1, -1}` y el toque se perdía.
    private func selectFirstTwoRows(_ app: XCUIApplication) {
        let rows = app.buttons.matching(identifier: "record_row")
        XCTAssertTrue(rows.element(boundBy: 0).waitForExistence(timeout: 10), "No hay filas de transacción para seleccionar.")
        XCTAssertGreaterThanOrEqual(rows.count, 2, "El seed no produjo ≥2 transacciones para edición masiva.")
        for index in 0..<2 {
            let row = rows.element(boundBy: index)
            bringIntoFreeBand(app, row)
            XCTAssertTrue(row.waitForHittable(timeout: 10), "La fila \(index) no es alcanzable para elegirla.")
            row.tap()
        }
        let count = app.staticTexts["records_selection_count"]
        let two = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH '2'"), object: count)
        XCTAssertEqual(XCTWaiter().wait(for: [two], timeout: 10), .completed,
                       "Tras tocar dos filas la barra no dice «2 seleccionados» (dice «\(count.exists ? count.label : "nada")»).")
    }

    /// Desplaza la página hasta que `row` quede entera en la franja libre: por debajo del primer cuarto de la ventana
    /// (título y chips) y por encima de lo que flota abajo (la barra de selección y la de pestañas).
    ///
    /// En el iPhone SE (667 pt) la segunda fila nace en y≈590-670, debajo de la barra «1 seleccionado» (medido el
    /// 2026-11-05 en el vídeo del `.xcresult`, iOS 27.2): `isHittable` no llegaba nunca y los tres casos caían en
    /// «la fila 1 no es alcanzable». En el iPhone 17 Pro cabe sin desplazar, y este bucle no hace nada.
    /// El arrastre empieza en el centro de la ventana con una pulsación corta, que la lista lee como desplazamiento y
    /// no como toque: no elige ninguna fila.
    private func bringIntoFreeBand(_ app: XCUIApplication, _ row: XCUIElement) {
        let window = app.windows.firstMatch.frame
        let top = window.minY + window.height * 0.25
        for _ in 0..<5 {
            var bottom = window.maxY
            let tabBar = app.compactTabBar
            if tabBar.exists { bottom = min(bottom, tabBar.frame.minY) }
            let count = app.staticTexts["records_selection_count"]
            // La cifra va dentro de la tarjeta de la barra, con su margen (`DS.Spacing.md`) por encima.
            if count.exists { bottom = min(bottom, count.frame.minY - 24) }
            let frame = row.frame
            let delta: CGFloat
            if frame.maxY > bottom {
                delta = -(frame.maxY - bottom + 24)
            } else if frame.minY < top {
                delta = top - frame.minY + 24
            } else {
                return
            }
            let step = max(-window.height * 0.3, min(window.height * 0.3, delta))
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: step)))
            _ = app.waitForSettledLayout(of: row, timeout: 3)
        }
    }

    /// Abre «Editar» de la barra de selección.
    private func openBulkEdit(_ app: XCUIApplication) {
        let editButton = app.buttons["bulk_edit_button"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 10), "No apareció el botón de editar masivo.")
        editButton.tap()
    }

    /// Smoke: modo selección → seleccionar 2 TX → editar masivo abre BulkEditSheet.
    /// (Con una sola TX seleccionada el botón abre el editor individual, no el masivo.)
    func test_opensBulkEditSheet() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        enterRecordsSelectionMode(app)

        selectFirstTwoRows(app)
        openBulkEdit(app)

        XCTAssertTrue(
            app.buttons["bulk_edit_option_note"].waitForExistence(timeout: 5),
            "No se montó BulkEditSheet (bulk_edit_option_note)."
        )
    }

    /// CRUD — editar masivamente la nota de 2 transacciones y verificar que el flujo
    /// completa (aplica el cambio y vuelve a la lista en modo normal).
    func test_bulkEditNoteCompletes() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        enterRecordsSelectionMode(app)

        // Seleccionar 2 transacciones (el seed minimal produce varias).
        selectFirstTwoRows(app)

        // Abrir editar masivo → opción Nota.
        openBulkEdit(app)
        let noteOption = app.buttons["bulk_edit_option_note"]
        XCTAssertTrue(noteOption.waitForExistence(timeout: 5), "No se montó BulkEditSheet (bulk_edit_option_note).")
        noteOption.tap()

        // Editor de nota: escribir y guardar (el campo auto-enfoca).
        let noteField = app.textFields["bulk_note_field"]
        XCTAssertTrue(noteField.waitForExistence(timeout: 5), "No se montó BulkNoteEditorSheet (bulk_note_field).")
        noteField.tap()
        noteField.typeText("QA Nota Masiva")

        let saveNote = app.buttons["toolbar_save_button"]
        XCTAssertTrue(saveNote.waitForExistence(timeout: 5), "No apareció toolbar_save_button en el editor de nota.")
        saveNote.tap()

        // De vuelta en BulkEditSheet (L8-13): la nota queda PENDIENTE en el resumen y «Aplicar» la aplica.
        XCTAssertTrue(
            app.staticTexts["bulk_edit_summary_note"].waitForExistence(timeout: 5),
            "La nota no quedó en el resumen de lo que va a cambiar (bulk_edit_summary_note)."
        )
        let apply = app.buttons["bulk_edit_apply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 5), "No apareció «Aplicar a N registros» (bulk_edit_apply).")
        XCTAssertTrue(apply.isEnabled, "«Aplicar» sigue apagado con un cambio pendiente.")
        apply.tap()

        // El flujo completó: vuelve a la lista en modo normal (menú (···) disponible).
        XCTAssertTrue(
            app.recordsOverflowMenu.waitForExistence(timeout: 5),
            "Tras la edición masiva no se volvió a la lista en modo normal."
        )
    }

    /// Auditoría UX 2.2 · L8-13: elegir primero y aplicar después. Elegir una cuenta NO la aplica: queda en el resumen
    /// («Cuenta → …») con «Aplicar» encendido; al aplicar, los dos registros pasan a esa cuenta, y al volver a abrir
    /// «Editar varios» con los mismos elegidos la fila dice «Ahora: <esa cuenta>» (decisión 75 de 2.3; antes «Hoy:»).
    func test_bulkEditAccount_isPendingUntilApply_andThenTheRecordsChange() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        enterRecordsSelectionMode(app)
        selectFirstTwoRows(app)
        openBulkEdit(app)

        let apply = app.buttons["bulk_edit_apply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 5), "No se montó BulkEditSheet (bulk_edit_apply).")
        XCTAssertFalse(apply.isEnabled, "«Aplicar» encendido sin nada pendiente.")

        // Elegir la primera cuenta del selector (sin acoplarse al nombre del seed).
        let accountRow = app.openSelectorFirstRow(chip: "bulk_edit_option_account", rowPrefix: "account_selector_row_")
        let accountName = String(accountRow.identifier.dropFirst("account_selector_row_".count))
        accountRow.tap()

        let summaryLine = app.staticTexts["bulk_edit_summary_account"]
        XCTAssertTrue(summaryLine.waitForExistence(timeout: 5), "La cuenta elegida no quedó en el resumen (bulk_edit_summary_account).")
        XCTAssertTrue(summaryLine.label.contains(accountName), "El resumen no nombra la cuenta elegida: «\(summaryLine.label)».")
        XCTAssertTrue(apply.isEnabled, "«Aplicar» sigue apagado con la cuenta pendiente.")
        apply.tap()

        XCTAssertTrue(
            app.recordsOverflowMenu.waitForExistence(timeout: 5),
            "Tras aplicar no se volvió a la lista en modo normal."
        )
        // Desde la decisión 18 de 2.3 aplicar deja un aviso con «Deshacer» abajo, encima de la barra de selección: se
        // espera a que se retire antes de volver a tocar esa franja.
        XCTAssertTrue(
            app.descendants(matching: .any)["records_bulk_edit_notice"].waitForNonExistence(timeout: 15),
            "El aviso del lote no se retiró."
        )

        // Los mismos dos registros ya tienen esa cuenta.
        enterSelectMode(app)
        selectFirstTwoRows(app)
        openBulkEdit(app)
        let accountOption = app.buttons["bulk_edit_option_account"]
        XCTAssertTrue(accountOption.waitForExistence(timeout: 5), "No se volvió a montar BulkEditSheet.")
        XCTAssertTrue(
            accountOption.label.contains(accountName),
            "Tras aplicar, los registros no dicen «Ahora: \(accountName)»: «\(accountOption.label)»."
        )
    }
}
