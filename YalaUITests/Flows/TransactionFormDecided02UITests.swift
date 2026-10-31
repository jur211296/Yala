//
//  TransactionFormDecided02UITests.swift
//  YalaUITests
//
//  El formulario de registro del lote decidido 2.2 · 02, sesión A (decisiones de Jürgen del 14 y el 21-oct): la cuenta
//  precargada (L2-1), lo que falta para guardar (L2-2), cerrar con algo escrito (L2-4), el aviso tras guardar (L2-5),
//  crear otra cuenta desde una transferencia (L2-6), la fecha (L2-7), la fila de favoritos (L2-13 y L2-14) y «Hacer
//  recurrente» (L2-15). Sin textos localizados: todo por identificador.
//

import XCTest

final class TransactionFormDecided02UITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Helpers

    @discardableResult
    private func launch(seed: String = "minimal", saved: Int? = nil, noticeSeconds: Int? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        var extra: [String] = []
        if let saved { extra += ["-uitest-transactions-saved", String(saved)] }
        if let noticeSeconds { extra += ["-uitest-undo-notice-seconds", String(noticeSeconds)] }
        app.launchForUITest(seed: seed, extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    private func openForm(_ app: XCUIApplication) {
        app.revealPanelFAB().tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del FAB (fab_manual).")
        manual.tap()
        XCTAssertTrue(app.textFields["new_transaction_amount"].waitForExistence(timeout: 5), "No se abrió el formulario.")
    }

    private func typeAmount(_ app: XCUIApplication, _ value: String) {
        let amount = app.textFields["new_transaction_amount"]
        amount.tap()
        amount.typeText(value)
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func formIsGone(_ app: XCUIApplication, timeout: TimeInterval = 8) -> Bool {
        app.textFields["new_transaction_amount"].waitForNonExistence(timeout: timeout)
    }

    // MARK: - L2-1 · La cuenta viene puesta

    /// Tras un onboarding de una sola cuenta: monto y categoría bastan para guardar.
    func test_oneAccount_isPrefilled_amountAndCategoryEnableSave() {
        let app = launch(seed: "una-cuenta")
        openForm(app)

        let accountChip = app.buttons["new_transaction_account_chip"]
        XCTAssertTrue(accountChip.waitForExistence(timeout: 5))
        XCTAssertTrue(accountChip.isSelected, "Con una sola cuenta, el chip de cuenta debía venir puesto (L2-1).")

        typeAmount(app, "25")
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")

        let save = app.buttons["new_transaction_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isEnabled, "Con monto y categoría, «Guardar» debía estar activo: la cuenta ya venía puesta.")
    }

    // MARK: - L2-2 · Lo que falta

    func test_missingLine_isShownWhileSaveIsOff_andGoesAwayWhenComplete() {
        let app = launch()
        openForm(app)

        let line = element(app, "new_transaction_missing_line")
        XCTAssertTrue(line.waitForExistence(timeout: 5), "Con «Guardar» apagado debía salir la línea de lo que falta.")
        let before = line.label

        typeAmount(app, "25")
        XCTAssertTrue(line.waitForExistence(timeout: 3))
        XCTAssertNotEqual(line.label, before, "Con el monto puesto, la línea debía dejar de nombrarlo.")

        app.chooseFirstSelectorRow(chip: "new_transaction_account_chip", rowPrefix: "account_selector_row_")
        XCTAssertTrue(app.buttons["new_transaction_subcategory_chip"].waitForExistence(timeout: 5))
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")

        XCTAssertTrue(line.waitForNonExistence(timeout: 5), "Completo, la línea debía desaparecer.")
        XCTAssertTrue(app.buttons["new_transaction_save"].isEnabled)
    }

    func test_missingLine_inATransfer_staysUntilBothAccountsAreChosen() {
        let app = launch() // dos cuentas y ninguna usada: origen y destino vacíos (L2-1)
        openForm(app)
        app.buttons["new_transaction_type_transfer"].tap()
        typeAmount(app, "10")
        let line = element(app, "new_transaction_missing_line")
        XCTAssertTrue(line.waitForExistence(timeout: 5), "Sin origen ni destino, la línea debía nombrarlos.")

        app.chooseFirstSelectorRow(chip: "new_transaction_source_chip", rowPrefix: "account_selector_row_")
        XCTAssertTrue(line.waitForExistence(timeout: 3), "Con origen y sin destino, aún falta el destino.")
        app.chooseFirstSelectorRow(chip: "new_transaction_destination_chip", rowPrefix: "account_selector_row_")
        XCTAssertTrue(line.waitForNonExistence(timeout: 5), "Con las dos cuentas, la línea desaparece.")
    }

    // MARK: - L2-4 · Cerrar con algo escrito

    func test_emptyForm_closesWithoutAsking() {
        let app = launch()
        openForm(app)
        app.buttons["new_transaction_close"].tap()
        XCTAssertTrue(formIsGone(app), "Vacío, la X debía cerrar sin preguntar.")
    }

    func test_filledForm_asksWithTheX_andWithTheSwipe() {
        let app = launch()
        openForm(app)
        typeAmount(app, "25")

        app.buttons["new_transaction_close"].tap()
        let keep = app.alerts.buttons["new_transaction_discard_keep"].firstMatch
        XCTAssertTrue(keep.waitForExistence(timeout: 5), "Con monto, la X debía preguntar «¿Descartar este registro?».")
        keep.tap()
        XCTAssertTrue(app.textFields["new_transaction_amount"].waitForExistence(timeout: 3), "«Seguir editando» no cierra.")

        // El gesto de bajar tampoco cierra: pregunta. Se arrastra desde la barra DEL FORMULARIO (junto a su X): la
        // primera barra del árbol es la del Panel de debajo.
        let close = app.buttons["new_transaction_close"]
        let start = close.coordinate(withNormalizedOffset: CGVector(dx: 4, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 500)))
        let discard = app.alerts.buttons["new_transaction_discard_confirm"].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 5), "Con monto, el gesto debía preguntar en vez de cerrar.")
        discard.tap()
        XCTAssertTrue(formIsGone(app), "«Descartar» cierra.")
    }

    // MARK: - L2-5 · Tras guardar

    /// Los tres primeros: pantalla completa. Volver a editar desde ahí y cerrar sin cambios no pregunta (L2-4).
    func test_firstRecords_fullScreen_editWithoutChangesClosesWithoutAsking() {
        let app = launch(seed: "una-cuenta")
        openForm(app)
        typeAmount(app, "25")
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        app.buttons["new_transaction_save"].tap()

        let edit = app.buttons["transaction_success_edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "Los tres primeros registros llevan la pantalla completa.")
        edit.tap()
        XCTAssertTrue(app.textFields["new_transaction_amount"].waitForExistence(timeout: 5))
        app.buttons["new_transaction_close"].tap()
        XCTAssertTrue(formIsGone(app), "Editar sin cambiar nada y cerrar no debía preguntar.")
    }

    /// Desde el cuarto: el formulario se cierra y sale el aviso; «Deshacer» devuelve el saldo.
    func test_afterThreeRecords_noticeWithUndo_restoresTheBalance() {
        // El aviso de 5 s se busca después de esperar a que se cierre el formulario: en el runner del CI no cabía
        // (dispatch 40939651475 y nocturna del 24-oct). Regla del aviso de 5 s en `testing.md`.
        let app = launch(seed: "una-cuenta", saved: 5, noticeSeconds: 30)
        let expensePill = app.buttons["panel_hero_expense_pill"]
        XCTAssertTrue(expensePill.waitForExistence(timeout: 10))
        let emptyLabel = expensePill.label

        openForm(app)
        typeAmount(app, "25")
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        app.buttons["new_transaction_save"].tap()

        XCTAssertTrue(formIsGone(app), "Desde el cuarto registro el formulario se cierra al guardar.")
        XCTAssertFalse(app.buttons["transaction_success_accept"].exists, "Desde el cuarto, sin pantalla completa.")
        let undo = element(app, "saved_record_undo")
        XCTAssertTrue(undo.waitForExistence(timeout: 3), "Salió sin el aviso con «Deshacer».")
        XCTAssertTrue(element(app, "saved_record_edit").exists, "El aviso lleva «Editar».")
        XCTAssertNotEqual(expensePill.label, emptyLabel, "El gasto guardado debía contar en el Panel.")

        undo.tap()
        let restored = NSPredicate(format: "label == %@", emptyLabel)
        expectation(for: restored, evaluatedWith: expensePill)
        waitForExpectations(timeout: 8)
    }

    /// Review adversarial del 2026-10-22: la franja del aviso caía sobre el formulario siguiente. Abrir otro lo retira.
    func test_afterThreeRecords_openingAnotherFormRetiresTheNotice() {
        // Con el aviso alargado, lo único que puede retirarlo es abrir el otro formulario: el caso no se cumple solo
        // porque el aviso caduque. Regla del aviso de 5 s en `testing.md`.
        let app = launch(seed: "una-cuenta", saved: 5, noticeSeconds: 30)
        openForm(app)
        typeAmount(app, "25")
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        app.buttons["new_transaction_save"].tap()
        XCTAssertTrue(formIsGone(app))
        let notice = element(app, "saved_record_notice")
        XCTAssertTrue(notice.waitForExistence(timeout: 3), "Control: el aviso salió.")

        // «Nuevo registro» de arriba del Panel: el «+» flotante queda debajo del aviso esos segundos (ticket
        // `saved-record-notice-covers-the-panel-plus-button`).
        let panelNew = app.buttons["panel_action_new"]
        if !panelNew.isHittable { app.swipeDown() }
        XCTAssertTrue(panelNew.waitForExistence(timeout: 5))
        panelNew.tap()
        XCTAssertTrue(app.textFields["new_transaction_amount"].waitForExistence(timeout: 5), "No se abrió el formulario.")
        XCTAssertTrue(notice.waitForNonExistence(timeout: 3), "Con otro formulario abierto, el aviso debía retirarse.")
    }

    /// Con el aviso en pantalla, el «+» del Panel responde al primer toque y abrir su menú retira el aviso. El aviso ya no
    /// sube por encima de los botones flotantes: Jürgen lo devolvió abajo el 2026-10-31 (card d3qq), aunque pise la parte
    /// baja del «+», y su ventana solo recoge los toques de la cápsula (`NoticePassthroughWindow`); la posición la fija
    /// `UndoNoticePlacementUITests`. El aviso se alarga a 30 s para que el
    /// plazo no decida el caso (`testing.md`).
    func test_afterThreeRecords_thePlusTakesTheFirstTapWithTheNoticeVisible() {
        let app = launch(seed: "una-cuenta", saved: 5, noticeSeconds: 30)
        openForm(app)
        typeAmount(app, "25")
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        app.buttons["new_transaction_save"].tap()
        XCTAssertTrue(formIsGone(app))
        let notice = element(app, "saved_record_notice")
        XCTAssertTrue(notice.waitForExistence(timeout: 3), "Control: el aviso salió.")

        let plus = app.buttons["fab_new_transaction"]
        XCTAssertTrue(plus.waitForExistence(timeout: 5), "Control: el «+» flotante sigue en el Panel.")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "aviso-tras-guardar-y-plus"
        shot.lifetime = .keepAlways
        add(shot)

        // La parte que asoma por encima del aviso: el aviso pisa la mitad baja del «+», centro incluido.
        plus.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForHittable(timeout: 3), "El primer toque al «+» no abrió su menú con el aviso visible.")
        XCTAssertTrue(notice.waitForNonExistence(timeout: 3),
                      "Con el menú del «+» abierto, el aviso de guardado debía retirarse: su franja caería sobre el menú.")
        manual.tap()
        XCTAssertTrue(app.textFields["new_transaction_amount"].waitForExistence(timeout: 5), "No se abrió el formulario.")
    }

    func test_afterThreeRecords_editFromTheNotice_opensTheRecord() {
        // El aviso de 5 s se busca después de esperar a que se cierre el formulario: en el runner del CI no cabía
        // (dispatch 40939651475 y nocturna del 24-oct). Regla del aviso de 5 s en `testing.md`.
        let app = launch(seed: "una-cuenta", saved: 5, noticeSeconds: 30)
        openForm(app)
        typeAmount(app, "25")
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        app.buttons["new_transaction_save"].tap()

        let edit = element(app, "saved_record_edit")
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "Salió sin «Editar».")
        // «Editar» no abre nada mientras el formulario aún se cierra (el ancla no está libre).
        XCTAssertTrue(formIsGone(app))
        edit.tap()
        XCTAssertTrue(app.buttons["new_transaction_delete_action"].waitForExistence(timeout: 8),
                      "«Editar» debía abrir el registro guardado en edición.")
    }

    // MARK: - L2-6 · Transferencia con una sola cuenta

    func test_transferWithOneAccount_createAnother_comesBackAsDestination() {
        let app = launch(seed: "una-cuenta")
        openForm(app)
        app.buttons["new_transaction_type_transfer"].tap()

        let destination = app.buttons["new_transaction_destination_chip"]
        XCTAssertTrue(destination.waitForExistence(timeout: 5))
        XCTAssertFalse(destination.isSelected, "Con una sola cuenta no hay destino que poner.")
        destination.tap()

        let create = element(app, "account_selector_create_another")
        XCTAssertTrue(create.waitForExistence(timeout: 5), "Con una sola cuenta, la hoja debía ofrecer «Crear otra cuenta».")
        create.tap()

        let name = app.textFields["account_name_field"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "No se abrió el formulario de cuenta.")
        name.tap()
        name.typeText("Ahorros QA")
        // Una cuenta nueva pide su saldo inicial.
        let balance = app.textFields["account_balance_field"]
        XCTAssertTrue(balance.waitForExistence(timeout: 5))
        XCTAssertTrue(app.waitForSettledLayout(of: balance))
        balance.tap()
        balance.typeText("100")
        // Un toque justo después de `typeText` se pierde en iOS 27.0 (`testing.md`): se espera a que la barra se quede
        // quieta y, si el formulario de cuenta sigue, se vuelve a tocar.
        let save = app.buttons["toolbar_save_button"].firstMatch
        XCTAssertTrue(app.waitForSettledLayout(of: save))
        save.tap()
        if !name.waitForNonExistence(timeout: 3) { save.tap() }
        XCTAssertTrue(name.waitForNonExistence(timeout: 5), "El formulario de cuenta no se cerró al guardar.")
        // Desde S12j, tras crear la cuenta la hoja ofrece añadirle otra divisa: «Ahora no» la cierra como antes.
        let notNow = app.buttons["account_line_offer_skip"]
        XCTAssertTrue(notNow.waitForExistence(timeout: 5), "Tras crear la cuenta no se ofreció otra divisa.")
        XCTAssertTrue(notNow.waitForHittable(timeout: 5))
        notNow.tap()

        let chip = app.buttons["new_transaction_destination_chip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 8))
        let named = NSPredicate(format: "label CONTAINS %@", "Ahorros QA")
        expectation(for: named, evaluatedWith: chip)
        waitForExpectations(timeout: 8)
    }

    // MARK: - L2-7 · La fecha

    func test_date_yesterdayInOneTap_closesTheSheet() {
        let app = launch()
        openForm(app)
        let chip = app.buttons["new_transaction_date_chip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        let today = chip.label
        chip.tap()

        let yesterday = app.buttons["date_quick_yesterday"]
        XCTAssertTrue(yesterday.waitForExistence(timeout: 5), "La hoja de fecha debía traer «Ayer».")
        yesterday.tap()

        XCTAssertTrue(yesterday.waitForNonExistence(timeout: 5), "Un toque en un atajo aplica y cierra la hoja.")
        XCTAssertNotEqual(chip.label, today, "La fecha debía pasar a ayer.")
    }

    func test_date_scheduledPaymentsLink_opensOnTop_andKeepsTheForm() {
        let app = launch()
        openForm(app)
        typeAmount(app, "25")
        app.buttons["new_transaction_date_chip"].tap()

        let note = element(app, "date_picker_future_note")
        XCTAssertTrue(note.waitForExistence(timeout: 5), "La hoja de fecha debía explicar los días en gris.")
        let link = note.links.firstMatch.exists ? note.links.firstMatch : app.links.firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 3), "La nota debía llevar el enlace a Pagos planificados.")
        link.tap()

        let close = app.buttons["date_picker_scheduled_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 8), "No se abrió Pagos planificados encima.")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))

        // La hoja de fecha sigue, y al cerrarla el formulario conserva el monto.
        let calendar = element(app, "date_picker_calendar")
        XCTAssertTrue(calendar.waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let amount = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        XCTAssertTrue((amount.value as? String)?.contains("25") == true, "El formulario perdió lo escrito.")
    }

    // MARK: - L2-13 · Favoritos

    func test_favoriteChip_fillsTheForm_andSaves() {
        let app = launch(seed: "formulario")
        openForm(app)

        XCTAssertTrue(element(app, "new_transaction_favorites_row").waitForExistence(timeout: 5),
                      "Con favoritos, la fila debía salir bajo el selector de tipo.")
        let coffee = app.buttons["new_transaction_favorite_chip_Café"]
        XCTAssertTrue(coffee.waitForExistence(timeout: 5))
        coffee.tap()

        let amount = app.textFields["new_transaction_amount"]
        XCTAssertTrue((amount.value as? String)?.contains("12") == true, "El favorito debía poner su monto.")
        XCTAssertTrue(app.buttons["new_transaction_account_chip"].isSelected, "El favorito debía poner su cuenta.")
        XCTAssertTrue(app.buttons["new_transaction_subcategory_chip"].isSelected, "El favorito debía poner su categoría.")

        let save = app.buttons["new_transaction_save"]
        XCTAssertTrue(save.isEnabled, "Con el favorito puesto, «Guardar» debía estar activo.")
        save.tap()
        app.dismissTransactionSuccess()
    }

    func test_withoutFavorites_thereIsNoRow() {
        let app = launch(seed: "una-cuenta")
        openForm(app)
        // Control: el formulario está montado.
        XCTAssertTrue(app.buttons["new_transaction_save"].waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "new_transaction_favorites_row").exists, "Sin favoritos, la fila no sale.")
    }

    /// L2-14: un favorito de transferencia pone el tipo, el origen y el destino.
    func test_transferFavorite_setsBothAccounts() {
        let app = launch(seed: "formulario")
        openForm(app)
        let saving = app.buttons["new_transaction_favorite_chip_Ahorro del mes"]
        XCTAssertTrue(saving.waitForExistence(timeout: 5))
        saving.tap()

        XCTAssertTrue(app.buttons["new_transaction_type_transfer"].isSelected, "Debía pasar a Transferencia.")
        XCTAssertTrue(element(app, "new_transaction_missing_line").waitForNonExistence(timeout: 5),
                      "Con origen, destino y monto no debía faltar nada.")
        XCTAssertTrue(app.buttons["new_transaction_save"].isEnabled)
    }

    // MARK: - L2-15 · Hacer recurrente

    func test_recurring_monthlyRow_createsThePayment_andClosesWithTheNotice() {
        // El aviso de 5 s se busca después de esperar a que se cierre el formulario: en el runner del CI no cabía
        // (dispatch 40939651475 y nocturna del 24-oct). Regla del aviso de 5 s en `testing.md`.
        let app = launch(seed: "una-cuenta", noticeSeconds: 30)
        openForm(app)
        typeAmount(app, "40")
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        app.buttons["new_transaction_recurring_action"].tap()

        for id in ["recurring_quick_weekly", "recurring_quick_monthly", "recurring_quick_yearly", "recurring_quick_more"] {
            XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 5), "Falta la fila \(id) en «Hacer recurrente».")
        }
        app.buttons["recurring_quick_monthly"].tap()

        XCTAssertTrue(formIsGone(app, timeout: 10), "Tocar una frecuencia guarda, crea el pago y cierra.")
        XCTAssertTrue(element(app, "saved_record_notice").waitForExistence(timeout: 5), "Salió sin el aviso.")

        // El pago planificado existe: la app relanzada sobre el mismo almacén aterriza en Pagos planificados.
        let relaunch = XCUIApplication()
        relaunch.launchForUITest(reset: false, seed: nil, deeplink: "scheduledPayments")
        XCTAssertTrue(relaunch.waitForUITestReady())
        XCTAssertTrue(relaunch.descendants(matching: .any)["scheduled_payment_row"].firstMatch.waitForExistence(timeout: 10),
                      "No se creó el pago planificado.")
    }

    func test_recurring_moreOptions_opensTheFullEditorWithTheDescriptionAsName() {
        let app = launch(seed: "una-cuenta")
        openForm(app)
        let note = app.textFields["new_transaction_note"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        note.typeText("Gimnasio")
        typeAmount(app, "120")
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        app.buttons["new_transaction_recurring_action"].tap()

        let more = app.buttons["recurring_quick_more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()

        let name = app.textFields["scheduled_name_field"]
        XCTAssertTrue(name.waitForExistence(timeout: 8), "«Más opciones…» debía abrir el editor completo.")
        XCTAssertEqual(name.value as? String, "Gimnasio", "El editor debía venir con la descripción como nombre.")
    }
}
