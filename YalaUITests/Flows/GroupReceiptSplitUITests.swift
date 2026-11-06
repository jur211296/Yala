//
//  GroupReceiptSplitUITests.swift
//  YalaUITests
//
//  «Desde un recibo» en Nuevo gasto de un grupo (card «Grupos: repartir un recibo con IA», 2.3).
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

    private func openNewGroupExpense(profile: String = "cusco") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups", aiConsent: true,
                            extraArguments: ["-uitest-receipt-split", profile])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No apareció la tarjeta del grupo.")
        card.tap()
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

    func test_receiptOfFiveLines_isSplitAtFirstTry_andFillsTheForm() {
        let app = openNewGroupExpense()

        let entry = app.buttons["group_expense_from_receipt"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "No está «Desde un recibo» en Nuevo gasto.")
        attach(app, "formulario")
        entry.tap()

        let library = app.buttons["receipt_split_library"]
        XCTAssertTrue(library.waitForExistence(timeout: 5), "No se abrió «Desde un recibo».")
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
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "No volvió al formulario.")
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

    func test_trialUsedUp_offersPro() {
        let app = openNewGroupExpense(profile: "trial")
        app.buttons["group_expense_from_receipt"].tap()
        let library = app.buttons["receipt_split_library"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        library.tap()
        XCTAssertTrue(app.buttons["receipt_split_split"].waitForExistence(timeout: 5))
        app.buttons["receipt_split_split"].tap()
        XCTAssertTrue(app.buttons["receipt_split_see_pro"].waitForExistence(timeout: 10), "La prueba agotada no ofrece Yala Pro.")
    }
}
