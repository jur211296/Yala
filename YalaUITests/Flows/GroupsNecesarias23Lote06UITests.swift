//
//  GroupsNecesarias23Lote06UITests.swift
//  YalaUITests
//
//  Mejoras necesarias 2.3 · lote 06 (Grupos: saldos que se contradicen y lectura con VoiceOver).
//
//  Siembra `-uitest-seed-group-cross-debts`: «Piso compartido» con «Menos pagos» apagado (debes S/ 40 a Ana, Beto te
//  debe S/ 30 y ya te pagó S/ 10; tu nombre es «Lucía») y «Grupo sin gastos», sin nada apuntado.
//
//  Discriminante, punto por punto, con el código de antes:
//  1 · la frase de la cifra decía «Nadie te debe nada.» con Beto debiéndote S/ 30;
//  2 · la tarjeta de Beto se leía «Beto paga a Tú»;
//  3 · «¿Quién puso más?» era una gráfica con tu fila «Lucía» y sin filas propias;
//  4 · el importe del gasto no tenía nombre y la fila del pago se leía a trozos («Tú», «Confirmada», «·»…);
//  5 · Saldos de un grupo sin gastos decía «¡Están al día!».
//
//  Capturas: con `TEST_RUNNER_YALA_CAPTURE_DIR` (y `TEST_RUNNER_YALA_CAPTURE_PREFIX`), `test_captureScreens` deja Saldos,
//  Estadísticas y Saldos del grupo vacío.
//
//  Convenciones: sin sleeps, scheme Yala Dev, ids y no textos (salvo los sembrados y los que el punto pide decir).
//

import XCTest

final class GroupsNecesarias23Lote06UITests: XCTestCase {

    private let crossGroup = "Piso compartido"
    private let emptyGroup = "Grupo sin gastos"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Capturas de antes y después

    func test_captureScreens() throws {
        guard ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"] != nil else {
            throw XCTSkip("Solo para capturas: sin YALA_CAPTURE_DIR no hay nada que hacer.")
        }
        let app = openGroup(crossGroup, tab: "balances")
        XCTAssertTrue(element(app, "group_balance_summary").waitForExistence(timeout: 10))
        capture(app, "1-saldos")
        app.swipeUp()
        capture(app, "2-saldos-pagos")
        selectTab(app, "stats")
        XCTAssertTrue(app.staticTexts["¿Quién puso más?"].waitForExistence(timeout: 10))
        capture(app, "3-estadisticas")

        let empty = openGroup(emptyGroup, tab: "balances")
        XCTAssertTrue(element(empty, "balances_opening_balance_add").waitForExistence(timeout: 10))
        capture(empty, "4-saldos-grupo-sin-gastos")
    }

    // MARK: - 1 · La frase de la cifra dice lo que debes y lo que te deben

    func test_balancesSentence_saysWhatYouOweAndWhatYouAreOwed() {
        let app = openGroup(crossGroup, tab: "balances")
        let summary = element(app, "group_balance_summary")
        XCTAssertTrue(summary.waitForExistence(timeout: 10), "No apareció la cifra de Saldos.")
        let label = summary.label
        XCTAssertFalse(label.contains("Nadie te debe"), "Beto te debe S/ 30.00 y la frase dice que nadie: «\(label)».")
        XCTAssertTrue(label.contains("Te deben S/ 30.00 y tú debes S/ 40.00"),
                      "La frase no dice lo que te deben y lo que debes: «\(label)».")
    }

    // MARK: - 2 · «Beto te paga», no «Beto paga a Tú»

    func test_debtToYou_readsPaysYou() {
        let app = openGroup(crossGroup, tab: "balances")
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Beto' AND label CONTAINS '30.00'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No apareció la deuda de Beto contigo.")
        XCTAssertTrue(card.label.hasPrefix("Beto te paga"), "La deuda de Beto se lee «\(card.label)».")
        XCTAssertFalse(card.label.contains("a Tú"), "Sigue diciendo «paga a Tú»: «\(card.label)».")
    }

    // MARK: - 3 · «¿Quién puso más?»: filas legibles y la tuya dice «Tú»

    func test_whoPaidMost_rowsAreReadable_andYoursSaysYou() {
        let app = openGroup(crossGroup, tab: "stats")
        let rows = app.descendants(matching: .any).matching(identifier: "group_stats_who_paid_row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "«¿Quién puso más?» no tiene filas.")
        let labels = rows.allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(labels.contains { $0.hasPrefix("Tú:") && $0.contains("80.00") },
                      "Tu fila no dice «Tú»: \(labels).")
        XCTAssertFalse(labels.contains { $0.hasPrefix("Lucía") }, "Tu fila dice tu nombre: \(labels).")
        // Las filas no se pisan: cada una empieza donde acaba la anterior (antes, 44 pt fijos con la barra encima).
        let frames = rows.allElementsBoundByIndex.map(\.frame).sorted { $0.minY < $1.minY }
        for (upper, lower) in zip(frames, frames.dropFirst()) {
            XCTAssertLessThanOrEqual(upper.maxY, lower.minY + 0.5, "Dos filas se pisan: \(upper) y \(lower).")
        }
    }

    /// Con texto AX3 y en el carrusel de «Todas» de «Viaje a Cusco» (soles y dólares), donde el alto de la página se
    /// estimaba con 44 pt fijos por persona: las filas tampoco se pisan, y la última cabe en la página.
    func test_whoPaidMost_atAX3_inTheCurrencyCarousel_rowsDoNotOverlap() {
        let app = openGroup("Viaje a Cusco", tab: "stats", extraArguments: Self.ax3)
        let rows = app.descendants(matching: .any).matching(identifier: "group_stats_who_paid_row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "«¿Quién puso más?» no tiene filas a AX3.")
        let frames = rows.allElementsBoundByIndex.filter { $0.frame.width > 0 && $0.frame.minX >= 0
            && $0.frame.minX < app.frame.width }.map(\.frame).sorted { $0.minY < $1.minY }
        XCTAssertGreaterThanOrEqual(frames.count, 3, "Faltan filas en la página visible: \(frames).")
        for (upper, lower) in zip(frames, frames.dropFirst()) {
            XCTAssertLessThanOrEqual(upper.maxY, lower.minY + 0.5, "Dos filas se pisan a AX3: \(upper) y \(lower).")
        }
        capture(app, "5-estadisticas-ax3")
    }

    private static let ax3 = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]

    // MARK: - 4 · VoiceOver: el importe con nombre y los pagos en una frase

    func test_expenseAmount_hasAName() {
        let app = openGroup(crossGroup, tab: "records")
        let fab = app.buttons["group_detail_fab_new_expense"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10), "No apareció «Nuevo gasto».")
        fab.tap()
        let amount = app.textFields["group_expense_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10), "No abrió el formulario de gasto.")
        XCTAssertEqual(amount.label, "Importe del gasto", "El importe se lee «\(amount.label)».")
    }

    func test_settlementAmount_hasAName() {
        let app = openGroup(crossGroup, tab: "balances")
        let settle = app.buttons["group_debt_settle"].firstMatch
        XCTAssertTrue(settle.waitForExistence(timeout: 10), "No apareció «Saldar».")
        settle.tap()
        let amount = app.textFields["settlement_form_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10), "No abrió el formulario de pago.")
        XCTAssertEqual(amount.label, "Importe del pago", "El importe del pago se lee «\(amount.label)».")
    }

    func test_paymentRow_readsAsOneSentence() {
        let app = openGroup(crossGroup, tab: "balances")
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'group_settlement_menu_'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No apareció el pago de Beto.")
        XCTAssertTrue(row.label.hasPrefix("Beto te pagó S/ 10.00"), "El pago se lee «\(row.label)».")
        XCTAssertTrue(row.label.contains("Confirmada"), "El pago no dice su estado: «\(row.label)».")
    }

    // MARK: - 5 · Un grupo sin gastos no está «al día»

    func test_groupWithoutExpenses_balancesDoesNotSayAllSettled() {
        let app = openGroup(emptyGroup, tab: "balances")
        XCTAssertTrue(element(app, "balances_opening_balance_add").waitForExistence(timeout: 10),
                      "No montó Saldos del grupo vacío.")
        XCTAssertFalse(app.staticTexts["¡Están al día!"].exists, "Un grupo sin gastos dice «¡Están al día!».")
        XCTAssertTrue(app.staticTexts["Sin gastos"].exists, "Saldos de un grupo sin gastos no lo dice.")
    }

    /// Control: un grupo con gastos y todo pagado sigue «al día». Aquí, «Piso compartido» no lo está, así que el control
    /// es que la frase vacía no salga en él.
    func test_groupWithDebts_doesNotShowTheEmptyState() {
        let app = openGroup(crossGroup, tab: "balances")
        XCTAssertTrue(element(app, "group_balance_summary").waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Sin gastos"].exists)
        XCTAssertFalse(app.staticTexts["¡Están al día!"].exists)
    }

    // MARK: - Helpers

    private func openGroup(_ name: String, tab: String, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups",
                            extraArguments: ["-uitest-seed-group-cross-debts"] + extraArguments + captureArguments)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let card = app.buttons.matching(identifier: "group_card")
            .matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "No apareció la tarjeta de «\(name)».")
        card.tap()
        if tab != "records" { selectTab(app, tab) }
        return app
    }

    private func selectTab(_ app: XCUIApplication, _ tab: String) {
        let chip = app.buttons["group_detail_tab_\(tab)"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "No apareció la pestaña «\(tab)».")
        chip.tap()
    }

    private var captureArguments: [String] {
        ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"] != nil ? ["-userTheme", "0"] : []
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
            print("GroupsNecesarias23Lote06UITests: captura no guardada: \(error)")
        }
    }
}
