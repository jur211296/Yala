//
//  GroupsBCabosSueltosUITests.swift
//  YalaUITests
//
//  Grupos B · cabos sueltos (encargo 2026-11-02-grupos-b-cabos-sueltos): lo por cobrar fuera de Registros (00xj), editar
//  la pata que lleva la receta abre «Partir» (6u5f), la entrada de una recarga lleva su grupo en Registros (oibr) y la
//  página Registros sin flotante (97gc).
//
//  Siembras: `-uitest-seed-group-sale` (una venta tuya a Ana, por cobrar, en «Ventas con Ana») y
//  `-uitest-seed-group-split-lines` (el caso Pía: «Recarga Sip» S/ 510 en «Pía y yo», en la Bandeja).
//
//  Convenciones: sin sleeps, scheme Yala Dev, ids y no textos (salvo los sembrados y los que la card pide decir).
//

import XCTest

final class GroupsBCabosSueltosUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Capturas de antes y después

    /// Las mismas pantallas antes y después del cambio, solo si la corrida lo pide (`YALA_CAPTURE_DIR`).
    func test_captureScreens() throws {
        guard ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"] != nil else {
            throw XCTSkip("Solo para capturas: sin YALA_CAPTURE_DIR no hay nada que hacer.")
        }
        // 1 · La página Registros (97gc) y 2 · el detalle de la venta por cobrar (00xj).
        let app = launch(seedArgument: "-uitest-seed-group-sale", deeplink: "records")
        XCTAssertTrue(app.buttons.matching(identifier: "record_row").firstMatch.waitForExistence(timeout: 15))
        capture(app, "1-registros")
        openRecord(app, containing: UITestFixtures.saleName)
        capture(app, "2-detalle-venta")

        // 3 · La pantalla de éxito de una venta nueva (00xj).
        relaunch(app, deeplink: "groups")
        createSaleInCusco(app)
        capture(app, "3-exito-venta")

        // 4 · La entrada de la recarga de Pía en Registros (oibr).
        let pia = launch(seedArgument: "-uitest-seed-group-split-lines", deeplink: nil)
        approvePiaSplit(pia)
        relaunch(pia, deeplink: "records")
        let entry = pia.buttons.matching(identifier: "record_row")
            .matching(NSPredicate(format: "label CONTAINS 'Sip'")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        capture(pia, "4-recarga-registros")
    }

    /// 5 · El editor de la pata con receta: lo que abre la pastilla de categoría (6u5f). Aparte, para poder sacar su
    /// «antes» solo.
    func test_captureEditorScreen() throws {
        guard ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"] != nil else {
            throw XCTSkip("Solo para capturas: sin YALA_CAPTURE_DIR no hay nada que hacer.")
        }
        let app = launch(seedArgument: "-uitest-seed-group-split-lines", deeplink: "groups")
        createSuperAndSplit(app)
        relaunch(app, deeplink: "records")
        openRecord(app, containing: "Súper", and: "200")
        openEditor(app)
        app.buttons["new_transaction_subcategory_chip"].tap()
        // Lo que abra (el selector antes, «Tu parte» después).
        if !element(app, "split_lines_card").waitForExistence(timeout: 5) {
            _ = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH 'subcategory_selector_row_'")).firstMatch
                .waitForExistence(timeout: 5)
        }
        capture(app, "5-editor-categoria")
    }

    // MARK: - 00xj · lo por cobrar fuera de Registros

    /// El detalle de la venta dice «Por cobrar» junto al tipo, como la fila.
    func test_saleDetail_typeSaysReceivable() {
        let app = launch(seedArgument: "-uitest-seed-group-sale", deeplink: "records")
        openRecord(app, containing: UITestFixtures.saleName)
        let type = element(app, "transaction_detail_type")
        XCTAssertTrue(type.waitForExistence(timeout: 5), "El detalle no tiene la fila del tipo.")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'por cobrar'")).firstMatch.exists,
                      "El detalle de una venta por cobrar no dice «Por cobrar».")
    }

    /// Guardar una venta no dice «¡Gasto agregado!».
    func test_saleSuccess_titleSaysSale() {
        let app = launch(seedArgument: nil, deeplink: "groups")
        createSaleInCusco(app)
        let title = element(app, "group_expense_success_title")
        XCTAssertTrue(title.waitForExistence(timeout: 5), "La pantalla de éxito no tiene título.")
        XCTAssertTrue(title.label.localizedCaseInsensitiveContains("venta"),
                      "Tras guardar una venta, el título dice «\(title.label)».")
    }

    // MARK: - 6u5f · la pata con receta abre «Partir»

    /// Partes tu parte del súper desde la pantalla de éxito; en el editor del registro, la categoría abre «Tu parte».
    func test_editorOfTheRecipeLeg_categoryOpensSplit() {
        let app = launch(seedArgument: "-uitest-seed-group-split-lines", deeplink: "groups")
        createSuperAndSplit(app)
        relaunch(app, deeplink: "records")
        openRecord(app, containing: "Súper", and: "200")
        openEditor(app)
        let chip = app.buttons["new_transaction_subcategory_chip"]
        XCTAssertTrue(chip.isEnabled, "La categoría de la pata con receta no se puede tocar.")
        chip.tap()
        XCTAssertTrue(element(app, "split_lines_card").waitForExistence(timeout: 5),
                      "La categoría de la pata que lleva la receta no abre «Tu parte».")
        XCTAssertTrue(app.buttons["split_lines_row_1"].exists, "«Tu parte» no abre con las dos líneas guardadas.")

        // Guardar «Tu parte» cierra también el editor: lo que cargó al abrir ya no es la pata (review de 6u5f).
        app.buttons["split_lines_save"].tap()
        XCTAssertTrue(element(app, "split_lines_card").waitForNonExistence(timeout: 8), "«Tu parte» no se cerró.")
        XCTAssertTrue(chip.waitForNonExistence(timeout: 8),
                      "Tras guardar «Tu parte», el editor sigue abierto con lo que cargó al abrir.")
    }

    // MARK: - oibr · la entrada de una recarga

    /// Tras partir la recarga de Pía, la entrada en Sip lleva el nombre del grupo en Registros.
    func test_rechargeEntry_showsItsGroup() {
        let app = launch(seedArgument: "-uitest-seed-group-split-lines", deeplink: nil)
        approvePiaSplit(app)
        relaunch(app, deeplink: "records")
        let entry = app.buttons.matching(identifier: "record_row")
            .matching(NSPredicate(format: "label CONTAINS 'Sip' AND label CONTAINS 'Pía y yo'")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "La entrada de la recarga en Sip no dice de qué grupo es.")
    }

    // MARK: - 97gc · Registros (página) sin flotante

    /// Arriba la misma fila de acciones que Estadísticas › Registros; el flotante no sale nunca, tampoco al bajar.
    func test_recordsPage_hasTheTopActions_andNeverTheFloatingButton() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: "records")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(app.buttons["stats_action_new"].waitForExistence(timeout: 15),
                      "La página Registros no lleva «Nuevo registro» arriba.")
        XCTAssertFalse(app.buttons["fab_new_transaction"].exists, "La página Registros enseña el «+» flotante.")
        for _ in 0..<4 { app.swipeUp() }
        XCTAssertFalse(app.buttons["fab_new_transaction"].waitForExistence(timeout: 2),
                       "Al bajar, la página Registros enseña el «+» flotante.")
        XCTAssertFalse(app.buttons["fab_chat"].exists, "Al bajar, la página Registros enseña Yala IA flotante.")
    }

    // MARK: - Recorridos

    private enum UITestFixtures {
        static let saleName = "Venta de bici"
    }

    private func launch(seedArgument: String?, deeplink: String?) -> XCUIApplication {
        let app = XCUIApplication()
        let extra = (seedArgument.map { [$0] } ?? []) + captureArguments
        app.launchForUITest(pro: true, seed: "grupos", deeplink: deeplink, extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// Relanza sobre el mismo almacén, SIN sembrar (sembrar otra vez duplica).
    private func relaunch(_ app: XCUIApplication, deeplink: String) {
        app.terminate()
        app.launchForUITest(reset: false, pro: true, seed: nil, deeplink: deeplink, extraArguments: captureArguments)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente tras relanzar.")
    }

    private var captureArguments: [String] {
        ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"] != nil ? ["-userTheme", "0"] : []
    }

    /// `also`: un segundo texto para distinguir la pata que lleva la receta (la de 200 en tu cuenta) de las derivadas.
    private func openRecord(_ app: XCUIApplication, containing text: String, and also: String? = nil) {
        let predicate = also.map { NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", text, $0) }
            ?? NSPredicate(format: "label CONTAINS %@", text)
        let row = app.buttons.matching(identifier: "record_row").matching(predicate).firstMatch
        XCTAssertTrue(app.buttons.matching(identifier: "record_row").firstMatch.waitForExistence(timeout: 15),
                      "Registros no tiene filas.")
        // La lista es perezosa: lo de hace unos días no está en el árbol hasta que se baja.
        var swipes = 0
        while !(row.exists && row.isHittable), swipes < 10 {
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No está «\(text)» en Registros.")
        if row.frame.maxY > app.windows.firstMatch.frame.maxY - 140 { app.swipeUp(velocity: .slow) }
        row.tap()
        XCTAssertTrue(element(app, "transaction_detail_sheet").waitForExistence(timeout: 8), "No abrió el detalle.")
    }

    private func openEditor(_ app: XCUIApplication) {
        let edit = app.buttons["transaction_detail_edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "El detalle no ofrece «Editar».")
        edit.tap()
        let chip = app.buttons["new_transaction_subcategory_chip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 8), "No abrió el editor.")
        XCTAssertTrue(app.waitForSettledLayout(of: chip))
    }

    /// Una venta de 120 en «Viaje a Cusco» (de tres, pagas tú) con la primera categoría de ingreso.
    private func createSaleInCusco(_ app: XCUIApplication) {
        let card = app.buttons.matching(identifier: "group_card")
            .matching(NSPredicate(format: "label BEGINSWITH 'Viaje a Cusco'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "No apareció la tarjeta de «Viaje a Cusco».")
        card.tap()
        let fab = app.buttons["group_detail_fab_new_expense"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció «Nuevo gasto».")
        fab.tap()
        let description = app.textFields["group_expense_description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5), "No montó el formulario.")
        description.tap()
        description.typeText("Venta de zapatillas")
        let amount = app.textFields["group_expense_amount"]
        amount.tap()
        amount.typeText("120")
        element(app, "group_expense_group_chip").tap()
        let category = app.buttons["group_expense_subcategory_chip"]
        XCTAssertTrue(category.waitForExistence(timeout: 5))
        XCTAssertTrue(app.waitForSettledLayout(of: category))
        category.tap()
        let typePill = app.buttons.matching(identifier: "subcategory_selector_type")
        XCTAssertTrue(typePill.element(boundBy: 1).waitForExistence(timeout: 5), "El selector no ofrece «Ingreso».")
        typePill.element(boundBy: 1).tap()
        let firstRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'subcategory_selector_row_'")).firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "No hay categorías de ingreso.")
        firstRow.tap()
        XCTAssertTrue(element(app, "group_expense_sale_line").waitForExistence(timeout: 5), "No quedó como venta.")
        let save = app.buttons["group_expense_save"]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: save)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 8), .completed, "«Guardar» no se encendió.")
        save.tap()
        let accept = app.buttons["group_expense_success_accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 10), "No llegó la pantalla de éxito.")
        XCTAssertTrue(element(app, "group_expense_description").waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.waitForSettledLayout(of: accept))
    }

    /// El caso Pía partido en la Bandeja: recarga 500 a Sip + comisión 10.
    private func approvePiaSplit(_ app: XCUIApplication) {
        let inbox = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inbox.waitForExistence(timeout: 10), "No apareció el botón de la Bandeja.")
        inbox.tap()
        let row = app.buttons["inbox_draft_row_Recarga Sip"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No está el borrador de «Recarga Sip».")
        row.tap()
        let split = app.buttons["group_draft_split_button"]
        XCTAssertTrue(split.waitForExistence(timeout: 8), "La hoja no ofrece «Partir».")
        split.tap()
        app.buttons["split_lines_row_0"].tap()
        let transfer = element(app, "split_line_kind_transfer")
        XCTAssertTrue(transfer.waitForExistence(timeout: 5), "No abrió la hoja de la línea.")
        transfer.tap()
        replaceAmount(app, with: "500")
        app.chooseFirstSelectorRow(chip: "split_line_destination", rowPrefix: "account_selector_row_Sip")
        saveLine(app)
        app.buttons["split_lines_add"].tap()
        XCTAssertTrue(app.textFields["split_line_amount"].waitForExistence(timeout: 5), "No abrió la línea nueva.")
        app.chooseFirstSelectorRow(chip: "split_line_subcategory", rowPrefix: "subcategory_selector_row_")
        saveLine(app)
        let approve = app.buttons["primary_button"]
        XCTAssertTrue(approve.isEnabled, "Con las líneas cuadradas, «Aprobar» se enciende.")
        approve.tap()
        XCTAssertTrue(app.buttons["inbox_draft_row_Recarga Sip"].waitForNonExistence(timeout: 8), "No se aprobó.")
    }

    /// Súper S/ 200 pagado por ti en «Pía y yo», a medias, partido en 80 + 20 desde la pantalla de éxito.
    private func createSuperAndSplit(_ app: XCUIApplication) {
        let card = app.buttons.matching(identifier: "group_card")
            .matching(NSPredicate(format: "label BEGINSWITH 'Pía y yo'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "No apareció la tarjeta de «Pía y yo».")
        card.tap()
        let fab = app.buttons["group_detail_fab_new_expense"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció «Nuevo gasto».")
        fab.tap()
        let description = app.textFields["group_expense_description"]
        XCTAssertTrue(description.waitForExistence(timeout: 5), "No montó el formulario.")
        description.tap()
        description.typeText("Súper")
        let amount = app.textFields["group_expense_amount"]
        amount.tap()
        amount.typeText("200")
        element(app, "group_expense_group_chip").tap()
        app.chooseFirstSelectorRow(chip: "group_expense_account_row", rowPrefix: "account_selector_row_")
        app.buttons["group_expense_save"].tap()
        let link = app.buttons["group_expense_success_split"]
        XCTAssertTrue(link.waitForExistence(timeout: 10), "La pantalla de éxito no ofrece «Partir tu parte».")
        link.tap()
        XCTAssertTrue(element(app, "split_lines_card").waitForExistence(timeout: 5), "El enlace no abrió la tarjeta.")
        app.buttons["split_lines_row_0"].tap()
        replaceAmount(app, with: "80")
        app.chooseFirstSelectorRow(chip: "split_line_subcategory", rowPrefix: "subcategory_selector_row_")
        saveLine(app)
        app.buttons["split_lines_add"].tap()
        XCTAssertTrue(app.textFields["split_line_amount"].waitForExistence(timeout: 5), "No abrió la línea nueva.")
        app.chooseFirstSelectorRow(chip: "split_line_subcategory", rowPrefix: "subcategory_selector_row_")
        saveLine(app)
        let save = app.buttons["split_lines_save"]
        XCTAssertTrue(save.isEnabled, "Con las líneas cuadradas, «Guardar» se enciende.")
        save.tap()
        XCTAssertTrue(element(app, "split_lines_card").waitForNonExistence(timeout: 8), "La hoja no se cerró.")
        app.buttons["group_expense_success_accept"].tap()
    }

    private func replaceAmount(_ app: XCUIApplication, with text: String) {
        let amount = app.textFields["split_line_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "No está el importe de la línea.")
        amount.tap()
        let current = (amount.value as? String) ?? ""
        amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2) + text)
    }

    private func saveLine(_ app: XCUIApplication) {
        let save = app.buttons["split_line_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "No está «Guardar línea».")
        XCTAssertTrue(app.waitForSettledLayout(of: save))
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5), "La hoja de la línea no se cerró.")
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"] else { return }
        let prefix = ProcessInfo.processInfo.environment["YALA_CAPTURE_PREFIX"] ?? "captura"
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(prefix)-\(name).png")
        do {
            try app.screenshot().pngRepresentation.write(to: url)
        } catch {
            print("GroupsBCabosSueltosUITests: captura no guardada: \(error)")
        }
    }
}
