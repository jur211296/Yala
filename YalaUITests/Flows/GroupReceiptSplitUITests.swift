//
//  GroupReceiptSplitUITests.swift
//  YalaUITests
//
//  Repartir un recibo con IA en un grupo (card «Grupos: repartir un recibo con IA», 2.3). Desde el 2026-11-14 se entra
//  por Voz y Foto del inicio de Grupos y de debajo del saldo del grupo, no por Nuevo gasto (ticket
//  `group-receipt-split-home-buttons`). Cupo propio: 5 recibos al día en Free y 50 en Pro, sin candado.
//  `-uitest-receipt-split cusco` hace que Fotos «elija» el recibo de ejemplo y que la lectura conteste sin red una cena
//  de cinco platos en «Viaje a Cusco» (Tú, Ana y Beto) con un servicio que llega sin incluir.
//
//  Lo que fija: cinco líneas repartidas a la primera según la frase (Ana el lomo, Beto el ají, Tú y Ana la pizza, la
//  chicha entre todos), el nombre que no es del grupo avisado, el servicio fuera del total hasta que la persona lo
//  incluye, y que «Usar este reparto» deja el formulario de siempre con el total y el reparto exacto.
//

import XCTest

final class GroupReceiptSplitUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchGroups(profile: String = "cusco", pro: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: pro, seed: "grupos", deeplink: "groups", aiConsent: true,
                            extraArguments: ["-uitest-receipt-split", profile])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    private func openGroupDetail(profile: String = "cusco", pro: Bool = true) -> XCUIApplication {
        let app = launchGroups(profile: profile, pro: pro)
        let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No apareció la tarjeta del grupo.")
        card.tap()
        return app
    }

    /// Foto bajo el saldo del grupo: abre la hoja del recibo lista para la foto.
    private func openReceiptFromGroup(profile: String = "cusco", pro: Bool = true) -> XCUIApplication {
        let app = openGroupDetail(profile: profile, pro: pro)
        let photo = app.buttons["group_detail_receipt_photo"]
        XCTAssertTrue(photo.waitForExistence(timeout: 10), "No está Foto bajo el saldo del grupo.")
        photo.tap()
        XCTAssertTrue(app.buttons["receipt_split_library"].waitForExistence(timeout: 5), "No se abrió la hoja del recibo.")
        return app
    }

    private func openNewGroupExpense(profile: String = "cusco") -> XCUIApplication {
        let app = openGroupDetail(profile: profile)
        let fab = app.buttons["group_detail_fab_new_expense"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció el + de nuevo gasto.")
        fab.tap()
        XCTAssertTrue(app.textFields["group_expense_description"].waitForExistence(timeout: 5), "El formulario no montó.")
        return app
    }

    /// La lista de la revisión monta solo lo visible: baja con arrastres cortos hasta que el elemento exista y se
    /// pueda tocar.
    @discardableResult
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<8 {
            if element.exists, element.isHittable { return true }
            let list = app.collectionViews.firstMatch
            let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            start.press(forDuration: 0.05, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
        }
        return element.exists
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// La captura del formulario tal como queda (el «antes» se sacó con este mismo paso sobre la base).
    func test_capture_newGroupExpenseForm() {
        let app = openNewGroupExpense()
        attach(app, "formulario")
    }

    /// Nuevo gasto ya no lleva la entrada al recibo: un solo camino, Voz y Foto fuera, como en personal.
    func test_newGroupExpense_hasNoReceiptEntry() {
        let app = openNewGroupExpense()
        XCTAssertTrue(app.buttons["group_expense_date_chip"].exists, "Control: el formulario está montado.")
        XCTAssertFalse(app.buttons["group_expense_from_receipt"].exists, "«Desde un recibo» sigue en Nuevo gasto.")
    }

    /// Voz y Foto en el inicio de Grupos, junto a «Nuevo gasto»; Foto abre la hoja (con varios grupos, tras elegirlo).
    func test_groupsHome_photo_opensTheReceipt() {
        let app = launchGroups()
        XCTAssertTrue(app.buttons["groups_action_new_expense"].waitForExistence(timeout: 10), "No está «Nuevo gasto».")
        XCTAssertTrue(app.buttons["groups_receipt_voice"].exists, "No está Voz en el inicio de Grupos.")
        XCTAssertTrue(app.buttons["groups_receipt_ai"].exists, "No está Yala IA en el inicio de Grupos.")
        XCTAssertTrue(app.buttons["groups_toolbar_new_group"].exists, "«Nuevo grupo» no está en la barra.")
        XCTAssertFalse(app.buttons["groups_action_new_group"].exists, "«Nuevo grupo» sigue en la fila con grupos.")
        let photo = app.buttons["groups_receipt_photo"]
        XCTAssertTrue(photo.exists, "No está Foto en el inicio de Grupos.")
        attach(app, "inicio-grupos")
        photo.tap()
        let library = app.buttons["receipt_split_library"]
        let pickerRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "group_picker_row_")).firstMatch
        if !library.waitForExistence(timeout: 3), pickerRow.waitForExistence(timeout: 3) {
            attach(app, "elegir-grupo")
            pickerRow.tap()
        }
        XCTAssertTrue(library.waitForExistence(timeout: 5), "Foto del inicio no abrió la hoja del recibo.")
    }

    func test_receiptOfFiveLines_isSplitAtFirstTry_andFillsTheForm() {
        let app = openGroupDetail()
        let photo = app.buttons["group_detail_receipt_photo"]
        XCTAssertTrue(photo.waitForExistence(timeout: 10), "No está Foto bajo el saldo del grupo.")
        attach(app, "detalle-grupo")
        photo.tap()

        let library = app.buttons["receipt_split_library"]
        XCTAssertTrue(library.waitForExistence(timeout: 5), "No se abrió la hoja del recibo.")
        library.tap()
        XCTAssertTrue(app.images["receipt_split_photo_preview"].waitForExistence(timeout: 5), "No quedó la foto.")

        let phrase = app.textFields["receipt_split_phrase"]
        phrase.tap()
        phrase.typeText("Ana el lomo, Beto el ají, Ana y yo la pizza")
        attach(app, "captura")
        app.buttons["receipt_split_split"].tap()

        XCTAssertTrue(app.buttons["receipt_split_use"].waitForExistence(timeout: 10), "No llegó la revisión.")
        attach(app, "revision")

        // Chicha y el cuy de «Carla» (que no es del grupo) van entre los tres: 46 → 15,34 / 15,33 / 15,33. Ana: 38 + 24 +
        // 15,33 · Beto: 32 + 15,33 · Tú: 24 + 15,34. Total 164: el servicio no entra hasta incluirlo.
        XCTAssertTrue(app.descendants(matching: .any)["receipt_split_unmatched"].exists,
                      "No avisa del nombre que no es del grupo.")
        let total = app.staticTexts["receipt_split_total"]
        XCTAssertTrue(scrollTo(total, in: app), "No llegué al total de la revisión.")
        XCTAssertTrue(total.label.contains("164.00"), "El total sin el servicio debería ser 164.00 y es \(total.label)")

        // Incluir el servicio con el atajo de la línea: según lo que consumió cada uno.
        let service = app.buttons["receipt_split_extra_Servicio 10 %"]
        XCTAssertTrue(scrollTo(service, in: app), "No llegué a la línea del servicio.")
        service.tap()
        let proportional = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Según lo que consumió")).firstMatch
        XCTAssertTrue(proportional.waitForExistence(timeout: 5), "No salió el atajo para incluir el servicio.")
        proportional.tap()
        XCTAssertTrue(scrollTo(total, in: app))
        let withService = NSPredicate(format: "label CONTAINS %@", "180.30")
        expectation(for: withService, evaluatedWith: total)
        waitForExpectations(timeout: 5)
        attach(app, "revision-servicio")

        app.buttons["receipt_split_use"].tap()

        let amount = app.textFields["group_expense_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 8), "No se abrió Nuevo gasto relleno.")
        XCTAssertTrue((amount.value as? String ?? "").contains("180.30"), "El formulario no quedó con el total: \(amount.value ?? "")")
        let description = app.textFields["group_expense_description"]
        XCTAssertEqual(description.value as? String, "Cusco Grill")
        attach(app, "formulario-rellenado")

        // Se guarda como un gasto de grupo normal. Pagó Ana (Caso B): sin la cuenta que pide el Caso A, guardar solo
        // depende de lo que trajo el recibo.
        let payerRow = app.buttons["group_expense_paidby_row"]
        XCTAssertTrue(payerRow.waitForExistence(timeout: 5), "No apareció «Pagado por».")
        payerRow.tap()
        let anaPays = app.buttons["group_expense_payer_Ana"]
        XCTAssertTrue(anaPays.waitForExistence(timeout: 5), "No apareció Ana en «Pagado por».")
        anaPays.tap()
        let save = app.buttons["group_expense_save"]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: save)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 8), .completed, "Guardar no se habilitó con el reparto del recibo.")
        save.tap()
        XCTAssertTrue(app.buttons["group_expense_success_accept"].waitForExistence(timeout: 10),
                      "El gasto del recibo no se guardó como gasto de grupo.")
        attach(app, "guardado")
    }

    /// Yala IA bajo el saldo: escribir el gasto lo reparte con la misma revisión y abre Nuevo gasto relleno.
    func test_groupDetail_yalaIA_typedExpense_isSplit() {
        let app = openGroupDetail()
        XCTAssertTrue(app.buttons["group_detail_action_new_expense"].waitForExistence(timeout: 10),
                      "No está «Nuevo gasto» bajo el saldo.")
        let ai = app.buttons["group_detail_receipt_ai"]
        XCTAssertTrue(ai.exists, "No está Yala IA bajo el saldo.")
        ai.tap()
        let text = app.textFields["receipt_split_text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5), "Yala IA no abrió la hoja para escribir.")
        text.typeText("lomo 38 Ana, ají 32 Beto, pizza 48 Ana y yo, chicha 18 entre todos")
        attach(app, "ia-escribir")
        // Tras teclear, el teclado sigue entrando y la hoja se mueve: el toque espera a que el botón se quede quieto.
        let split = app.buttons["receipt_split_split"]
        XCTAssertTrue(app.waitForSettledLayout(of: split), "«Repartir» no se quedó quieto.")
        split.tap()
        let use = app.buttons["receipt_split_use"]
        XCTAssertTrue(use.waitForExistence(timeout: 10), "No llegó la revisión.")
        use.tap()
        XCTAssertTrue(app.textFields["group_expense_amount"].waitForExistence(timeout: 8), "No se abrió Nuevo gasto relleno.")
        XCTAssertEqual(app.textFields["group_expense_description"].value as? String, "Cusco Grill")
    }

    private func readTheExampleReceipt(_ app: XCUIApplication) {
        app.buttons["receipt_split_library"].tap()
        XCTAssertTrue(app.buttons["receipt_split_split"].waitForExistence(timeout: 5))
        app.buttons["receipt_split_split"].tap()
    }

    /// Gateway anterior al cupo de recibos: contesta prueba agotada y se sigue ofreciendo Pro.
    func test_trialUsedUp_offersPro() {
        let app = openReceiptFromGroup(profile: "trial")
        readTheExampleReceipt(app)
        XCTAssertTrue(app.buttons["receipt_split_see_pro"].waitForExistence(timeout: 10), "La prueba agotada no ofrece Yala Pro.")
    }

    /// Free, sin candado: entra y lee; con los recibos del día gastados, se le ofrece Yala Pro.
    func test_free_withoutLock_dailyLimit_offersPro() {
        let app = openReceiptFromGroup(profile: "daily", pro: false)
        readTheExampleReceipt(app)
        XCTAssertTrue(app.buttons["receipt_split_see_pro"].waitForExistence(timeout: 10), "El cupo del día de Free no ofrece Yala Pro.")
        attach(app, "free-cupo-del-dia")
    }

    /// Pro con el cupo del día gastado: vuelve mañana, sin ofrecerle Pro.
    func test_pro_dailyLimit_saysTomorrow() {
        let app = openReceiptFromGroup(profile: "daily", pro: true)
        readTheExampleReceipt(app)
        XCTAssertTrue(app.buttons["receipt_split_retry"].waitForExistence(timeout: 10), "El cupo del día de Pro no salió.")
        XCTAssertFalse(app.buttons["receipt_split_see_pro"].exists, "A Pro no se le ofrece Pro.")
        attach(app, "pro-cupo-del-dia")
    }
}
