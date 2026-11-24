//
//  ExitoGruposBandejaCapturasUITests.swift
//  YalaUITests
//
//  Las cuatro pantallas de éxito —registro personal, gasto de grupo, aprobar uno en la Bandeja y aprobar varios—, cada
//  una en oscuro (el tema por defecto), en claro y girada, con una captura por estado (encargo del 2026-11-24: llevar
//  Grupos y la Bandeja al éxito minimalista del registro personal). Se escribió ANTES de tocar las vistas y se corrió
//  sobre la base para el «antes»; con el cambio, además fija que cada pantalla trae sus salidas.
//

import XCTest

final class ExitoGruposBandejaCapturasUITests: XCTestCase {

    /// Oscuro es el tema por defecto (Liquid Glass); claro va con `-userTheme 1`.
    private let variants: [(name: String, args: [String])] = [("oscuro", []), ("claro", ["-userTheme", "1"])]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Vertical y girada. Espera a que la entrada animada termine antes de cada foto.
    private func capture(_ app: XCUIApplication, _ name: String, settledOn id: String) {
        let anchor = app.descendants(matching: .any)[id].firstMatch
        XCTAssertTrue(anchor.waitForExistence(timeout: 15), "No apareció «\(id)» en \(name).")
        _ = app.waitForSettledLayout(of: anchor)
        Thread.sleep(forTimeInterval: 1.0)
        attach(app, "\(name)-vertical")
        XCUIDevice.shared.orientation = .landscapeLeft
        // La app tarda en recolocarse tras el giro: con 1,5 s la foto salía aún en vertical dentro del lienzo apaisado.
        let turned = NSPredicate { _, _ in app.frame.width > app.frame.height }
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: turned, object: nil)], timeout: 8)
        Thread.sleep(forTimeInterval: 1.5)
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "\(name)-girado"
        landscape.lifetime = .keepAlways
        add(landscape)
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 1.0)
    }

    // MARK: - Personal (referencia)

    func test_personal() {
        for variant in variants {
            XCUIDevice.shared.orientation = .portrait
            let app = XCUIApplication()
            app.launchForUITest(extraArguments: variant.args)
            XCTAssertTrue(app.waitForUITestReady())

            app.revealPanelFAB().tap()
            let manual = app.buttons["fab_manual"]
            XCTAssertTrue(manual.waitForExistence(timeout: 5))
            manual.tap()
            let amount = app.textFields["new_transaction_amount"]
            XCTAssertTrue(amount.waitForExistence(timeout: 5))
            amount.tap()
            amount.typeText("50")
            app.chooseFirstSelectorRow(chip: "new_transaction_account_chip", rowPrefix: "account_selector_row_")
            XCTAssertTrue(app.buttons["new_transaction_subcategory_chip"].waitForExistence(timeout: 5))
            app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")
            let save = app.buttons["new_transaction_save"]
            XCTAssertTrue(save.waitForExistence(timeout: 5))
            XCTAssertTrue(app.waitForSettledLayout(of: save))
            save.tap()

            capture(app, "personal-\(variant.name)", settledOn: "transaction_success_accept")
            app.terminate()
        }
    }

    // MARK: - Grupo

    func test_grupo() {
        for variant in variants {
            XCUIDevice.shared.orientation = .portrait
            let app = XCUIApplication()
            app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups", extraArguments: variant.args)
            XCTAssertTrue(app.waitForUITestReady())

            let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 10))
            card.tap()
            let fab = app.buttons["group_detail_action_new_expense"]
            XCTAssertTrue(fab.waitForExistence(timeout: 10))
            fab.tap()
            let description = app.textFields["group_expense_description"]
            XCTAssertTrue(description.waitForExistence(timeout: 5))
            description.tap()
            description.typeText("Cena en el centro")
            let amount = app.textFields["group_expense_amount"]
            XCTAssertTrue(amount.waitForExistence(timeout: 5))
            amount.tap()
            amount.typeText("120")
            let payerRow = app.buttons["group_expense_paidby_row"]
            XCTAssertTrue(payerRow.waitForExistence(timeout: 5))
            payerRow.tap()
            let ana = app.buttons["group_expense_payer_Ana"]
            XCTAssertTrue(ana.waitForExistence(timeout: 5))
            ana.tap()
            let save = app.buttons["group_expense_save"]
            XCTAssertTrue(save.waitForExistence(timeout: 5))
            let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: save)
            XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 8), .completed)
            save.tap()

            capture(app, "grupo-\(variant.name)", settledOn: "group_expense_success_accept")
            XCTAssertTrue(app.buttons["group_expense_success_add_another"].exists, "Falta «Agregar otro».")
            XCTAssertTrue(app.buttons["group_expense_success_edit"].exists, "Falta «Editar».")
            XCTAssertTrue(app.descendants(matching: .any)["group_expense_success_debt_line"].exists,
                          "La pantalla no dice a quién debes.")
            app.terminate()
        }
    }

    // MARK: - Bandeja: aprobar uno

    func test_bandejaUno() {
        for variant in variants {
            XCUIDevice.shared.orientation = .portrait
            let app = XCUIApplication()
            app.launchForUITest(extraArguments: variant.args)
            XCTAssertTrue(app.waitForUITestReady())

            let inbox = app.buttons["panel_inbox_button"]
            XCTAssertTrue(inbox.waitForExistence(timeout: 10))
            inbox.tap()
            let row = app.buttons["inbox_draft_row_Almuerzo equipo"]
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            row.tap()
            let approve = app.buttons["inbox_approve_button"]
            XCTAssertTrue(approve.waitForExistence(timeout: 5))
            approve.tap()

            capture(app, "bandeja-uno-\(variant.name)", settledOn: "inbox_success_accept")
            app.terminate()
        }
    }

    // MARK: - Bandeja: aprobar varios

    func test_bandejaVarios() {
        for variant in variants {
            XCUIDevice.shared.orientation = .portrait
            let app = XCUIApplication()
            app.launchForUITest(extraArguments: variant.args)
            XCTAssertTrue(app.waitForUITestReady())

            let inbox = app.buttons["panel_inbox_button"]
            XCTAssertTrue(inbox.waitForExistence(timeout: 10))
            inbox.tap()
            let saveReady = app.buttons["inbox_save_ready"]
            XCTAssertTrue(saveReady.waitForExistence(timeout: 5))
            saveReady.tap()
            let confirm = app.alerts.firstMatch.buttons["inbox_save_ready_confirm"].firstMatch
            XCTAssertTrue(confirm.waitForExistence(timeout: 5))
            confirm.tap()

            capture(app, "bandeja-varios-\(variant.name)", settledOn: "inbox_bulk_success_back")
            XCTAssertTrue(app.staticTexts["inbox_bulk_success_summary"].exists, "La pantalla no dice cuánto se guardó.")
            app.terminate()
        }
    }
}
