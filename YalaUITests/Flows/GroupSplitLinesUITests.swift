//
//  GroupSplitLinesUITests.swift
//  YalaUITests
//
//  Grupos B, cards 5 y 6: «Partir» en la Bandeja y «Partir tu parte» en la pantalla de éxito y en el detalle del
//  registro (`docs/disenos/grupos-tu-parte-en-lineas/README.md`, «Versión final acordada»).
//
//  El caso Pía lo siembra `-uitest-seed-group-split-lines` (`DevSeedGroupSplitLines`): Pía paga «Recarga Sip» S/ 510 en
//  «Pía y yo» y es todo tuyo; el puente real deja el borrador en la Bandeja.
//

import XCTest

final class GroupSplitLinesUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Capturas de antes y después

    /// Recorre las tres pantallas y las guarda, solo si la corrida lo pide (`TEST_RUNNER_YALA_CAPTURE_DIR`). Las mismas
    /// pantallas antes y después del cambio; el modo oscuro lo pone quien lanza (`simctl ui appearance`).
    func test_captureScreens() throws {
        guard ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"] != nil else {
            throw XCTSkip("Solo para capturas: sin YALA_CAPTURE_DIR no hay nada que hacer.")
        }
        let app = launch()

        // 1 · La hoja de la Bandeja del caso Pía.
        openPiaDraft(app)
        capture(app, "1-bandeja")
        if app.buttons["group_draft_split_button"].exists {
            app.buttons["group_draft_split_button"].tap()
            XCTAssertTrue(element(app, "split_lines_card").waitForExistence(timeout: 5))
            capture(app, "1b-bandeja-partir")
        }

        // 2 · La pantalla de éxito de un gasto que pagas tú en «Pía y yo».
        relaunch(app, deeplink: "groups")
        createSuperInPiaGroup(app)
        capture(app, "2-exito")
        let link = app.buttons["group_expense_success_split"]
        if link.exists {
            link.tap()
            XCTAssertTrue(element(app, "split_lines_card").waitForExistence(timeout: 5))
            capture(app, "2b-exito-partir")
            app.buttons["xmark"].firstMatch.tap()
        }
        app.buttons["group_expense_success_accept"].tap()

        // 3 · El detalle del registro del súper.
        relaunch(app, deeplink: "records")
        openSuperRecord(app)
        capture(app, "3-detalle")
        // «Partir tu parte» es la última fila de la tarjeta: con la hoja a media altura queda debajo.
        element(app, "transaction_detail_sheet").swipeUp()
        if app.buttons["transaction_detail_split"].waitForExistence(timeout: 3) { capture(app, "3b-detalle-partir") }
    }

    // MARK: - Card 5 · Bandeja

    /// El caso Pía: «Partir» en la hoja de la Bandeja, recarga 500 a Sip + comisión 10, y «Aprobar» solo cuando cuadra.
    func test_inbox_piaSplitsIntoRechargeAndFee() {
        let app = launch()
        openPiaDraft(app)
        let approve = app.buttons["primary_button"]
        XCTAssertFalse(approve.isEnabled, "Sin categoría, «Aprobar» tiene que estar apagado como hoy.")

        let split = app.buttons["group_draft_split_button"]
        XCTAssertTrue(split.waitForExistence(timeout: 5), "La hoja no ofrece «Partir».")
        split.tap()
        XCTAssertTrue(element(app, "split_lines_card").waitForExistence(timeout: 5), "«Partir» no abrió la tarjeta.")
        XCTAssertFalse(app.buttons["group_draft_subcategory_chip"].exists, "Con la tarjeta, sobra la pastilla de categoría.")

        // La primera línea pasa a Recarga de 500 a Sip.
        app.buttons["split_lines_row_0"].tap()
        let transfer = element(app, "split_line_kind_transfer")
        XCTAssertTrue(transfer.waitForExistence(timeout: 5), "No abrió la hoja de la línea.")
        transfer.tap()
        replaceAmount(app, with: "500")
        app.chooseFirstSelectorRow(chip: "split_line_destination", rowPrefix: "account_selector_row_Sip")
        saveLine(app)
        XCTAssertFalse(approve.isEnabled, "Con 500 de 510, «Aprobar» tiene que esperar a que cuadre.")

        // «Añadir línea» abre con lo que falta (10) y se le pone categoría.
        app.buttons["split_lines_add"].tap()
        let amount = app.textFields["split_line_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "No abrió la línea nueva.")
        XCTAssertEqual(amount.value as? String, "10", "La línea nueva no abre con lo que falta.")
        app.chooseFirstSelectorRow(chip: "split_line_subcategory", rowPrefix: "subcategory_selector_row_")
        saveLine(app)

        XCTAssertTrue(app.buttons["split_lines_row_1"].waitForExistence(timeout: 5), "No quedó la segunda línea.")
        XCTAssertTrue(approve.isEnabled, "Con las líneas cuadradas, «Aprobar» se enciende.")
        capture(app, "flujo-bandeja-cuadra")
        approve.tap()
        XCTAssertTrue(element(app, "group_draft_banner").waitForNonExistence(timeout: 8), "La hoja no se cerró al aprobar.")
        XCTAssertTrue(app.buttons["inbox_draft_row_Recarga Sip"].waitForNonExistence(timeout: 8),
                      "El borrador sigue en la Bandeja tras aprobar.")

        // Lo que queda: la recarga y la comisión, dos registros del mismo gasto.
        relaunch(app, deeplink: "records")
        let rows = app.buttons.matching(identifier: "record_row").matching(NSPredicate(format: "label CONTAINS 'Recarga Sip'"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "No está «Recarga Sip» en Registros.")
        XCTAssertGreaterThanOrEqual(rows.count, 2, "Partido en dos líneas, «Recarga Sip» tiene que dejar dos registros.")
    }

    /// Sin tocar «Partir», la hoja aprueba como hoy: se elige la categoría y el borrador se va.
    func test_inbox_withoutSplit_approvesAsToday() {
        let app = launch()
        openPiaDraft(app)
        app.chooseFirstSelectorRow(chip: "group_draft_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        let approve = app.buttons["primary_button"]
        XCTAssertTrue(approve.isEnabled, "Con la categoría elegida, «Aprobar» se enciende como hoy.")
        approve.tap()
        XCTAssertTrue(element(app, "group_draft_banner").waitForNonExistence(timeout: 8), "La hoja no se cerró al aprobar.")
        XCTAssertTrue(app.buttons["inbox_draft_row_Recarga Sip"].waitForNonExistence(timeout: 8),
                      "El borrador sigue en la Bandeja tras aprobar.")

        relaunch(app, deeplink: "records")
        let rows = app.buttons.matching(identifier: "record_row").matching(NSPredicate(format: "label CONTAINS 'Recarga Sip'"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "No está «Recarga Sip» en Registros.")
        XCTAssertEqual(rows.count, 1, "Sin partir, tu parte es un solo registro, como hoy.")
    }

    // MARK: - Card 6 · Pantalla de éxito y detalle del registro

    /// Apuntas el súper (200, a medias con Pía) y partes tu parte (100) en dos categorías desde la pantalla de éxito.
    /// Después, el detalle del registro ofrece lo mismo y abre con las dos líneas guardadas.
    func test_success_splitsTheSuper_andTheRecordKeepsTheLines() {
        let app = launch()
        relaunch(app, deeplink: "groups")
        createSuperInPiaGroup(app)

        let link = app.buttons["group_expense_success_split"]
        XCTAssertTrue(link.waitForExistence(timeout: 5), "La pantalla de éxito no ofrece «Partir tu parte».")
        link.tap()
        XCTAssertTrue(element(app, "split_lines_card").waitForExistence(timeout: 5), "El enlace no abrió la tarjeta.")
        let save = app.buttons["split_lines_save"]

        app.buttons["split_lines_row_0"].tap()
        XCTAssertTrue(app.textFields["split_line_amount"].waitForExistence(timeout: 5), "No abrió la línea.")
        replaceAmount(app, with: "80")
        app.chooseFirstSelectorRow(chip: "split_line_subcategory", rowPrefix: "subcategory_selector_row_")
        saveLine(app)
        XCTAssertFalse(save.isEnabled, "Con 80 de 100, «Guardar» tiene que esperar a que cuadre.")

        app.buttons["split_lines_add"].tap()
        XCTAssertTrue(app.textFields["split_line_amount"].waitForExistence(timeout: 5), "No abrió la línea nueva.")
        app.chooseFirstSelectorRow(chip: "split_line_subcategory", rowPrefix: "subcategory_selector_row_")
        saveLine(app)
        XCTAssertTrue(save.isEnabled, "Con las líneas cuadradas, «Guardar» se enciende.")
        save.tap()
        XCTAssertTrue(element(app, "split_lines_card").waitForNonExistence(timeout: 8), "La hoja no se cerró al guardar.")
        app.buttons["group_expense_success_accept"].tap()

        relaunch(app, deeplink: "records")
        openSuperRecord(app)
        let detailSplit = app.buttons["transaction_detail_split"]
        XCTAssertTrue(detailSplit.waitForExistence(timeout: 5), "El detalle del registro no ofrece «Partir tu parte».")
        detailSplit.tap()
        XCTAssertTrue(app.buttons["split_lines_row_1"].waitForExistence(timeout: 8),
                      "La hoja del detalle no abre con las dos líneas guardadas.")
    }

    /// En una sesión solo-grupos no hay finanzas personales que partir: la pantalla de éxito no ofrece el enlace.
    func test_groupsOnlySession_successHasNoSplitLink() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos-invitado", deeplink: "groups", groupInvite: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let cusco = app.buttons.matching(identifier: "group_card")
            .matching(NSPredicate(format: "label BEGINSWITH 'Viaje a Cusco'")).firstMatch
        XCTAssertTrue(cusco.waitForExistence(timeout: 15), "No apareció la tarjeta de «Viaje a Cusco».")
        cusco.tap()
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
        app.buttons["group_expense_save"].tap()
        XCTAssertTrue(app.buttons["group_expense_success_accept"].waitForExistence(timeout: 10),
                      "No llegó la pantalla de éxito.")
        XCTAssertFalse(app.buttons["group_expense_success_split"].exists,
                       "En una sesión solo-grupos la pantalla de éxito no puede ofrecer «Partir tu parte».")
    }

    // MARK: - Navegación

    private func launch(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos",
                            extraArguments: ["-uitest-seed-group-split-lines"] + captureArguments + extraArguments)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// Relanza sobre el mismo almacén, SIN sembrar (los datos ya están en disco: sembrar otra vez los duplica).
    private func relaunch(_ app: XCUIApplication, deeplink: String) {
        app.terminate()
        app.launchForUITest(reset: false, pro: true, seed: nil, deeplink: deeplink, extraArguments: captureArguments)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente tras relanzar.")
    }

    /// En capturas, el tema «Sistema» (`-userTheme 0`): así claro u oscuro lo decide el simulador. Sin él la app pinta su
    /// tema por defecto, que es oscuro.
    private var captureArguments: [String] {
        let environment = ProcessInfo.processInfo.environment
        guard environment["YALA_CAPTURE_DIR"] != nil else { return [] }
        var arguments = ["-userTheme", "0"]
        if environment["YALA_CAPTURE_AX"] == "1" {
            arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        }
        return arguments
    }

    private func openPiaDraft(_ app: XCUIApplication) {
        let inbox = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inbox.waitForExistence(timeout: 10), "No apareció el botón de la Bandeja.")
        inbox.tap()
        let row = app.buttons["inbox_draft_row_Recarga Sip"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No está el borrador de «Recarga Sip» en la Bandeja.")
        row.tap()
        XCTAssertTrue(element(app, "group_draft_banner").waitForExistence(timeout: 8), "No abrió la hoja del gasto.")
    }

    /// Súper S/ 200 pagado por ti en «Pía y yo», a medias: tu parte es 100. Termina en la pantalla de éxito.
    private func createSuperInPiaGroup(_ app: XCUIApplication) {
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
        let accept = app.buttons["group_expense_success_accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 10), "No llegó la pantalla de éxito.")
        // La pantalla entra con animación sobre el formulario que se va: sin esperar, la captura sale del formulario.
        XCTAssertTrue(element(app, "group_expense_description").waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.waitForSettledLayout(of: accept))
    }

    private func openSuperRecord(_ app: XCUIApplication) {
        let row = app.buttons.matching(identifier: "record_row")
            .matching(NSPredicate(format: "label CONTAINS 'Súper'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No está el registro del súper en Registros.")
        row.tap()
        XCTAssertTrue(element(app, "transaction_detail_sheet").waitForExistence(timeout: 8), "No abrió el detalle.")
    }

    /// Sustituye el importe de la línea abierta.
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
        app.descendants(matching: .any)[id]
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"] else { return }
        let prefix = ProcessInfo.processInfo.environment["YALA_CAPTURE_PREFIX"] ?? "captura"
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(prefix)-\(name).png")
        do {
            try app.screenshot().pngRepresentation.write(to: url)
        } catch {
            print("GroupSplitLinesUITests: captura no guardada: \(error)")
        }
    }
}
