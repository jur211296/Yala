//
//  TransactionFormDecided02BUITests.swift
//  YalaUITests
//
//  El formulario de registro del lote decidido 2.2 · 02, sesión B (decisiones de Jürgen del 14 y el 21-oct): «Etiquetas»
//  a la vista sin deslizar y la etiqueta nueva solo con el nombre (L2-10), el buscador de la hoja de categoría (L2-3), la
//  equivalencia de un gasto en dólares (L2-11), «Mi parte» abriendo en «Iguales» (L2-12) y la pista de los atajos (L2-8).
//  Sin textos localizados salvo lo que la persona escribe: todo por identificador.
//

import XCTest

final class TransactionFormDecided02BUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Helpers

    @discardableResult
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal")
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

    /// Fuera el teclado (en un SE tapa los chips): un toque en la pregunta del monto, que no es un control.
    private func dismissKeyboard(_ app: XCUIApplication) {
        let question = element(app, "new_transaction_amount_question")
        XCTAssertTrue(question.waitForExistence(timeout: 5), "Falta la pregunta del monto (L2-16).")
        question.tap()
    }

    // MARK: - L2-10 · Etiquetas a la vista y etiqueta nueva solo con el nombre

    /// Con cuenta y categoría elegidas (los chips más anchos), «Etiquetas» cabe entero en la ventana sin deslizar: los
    /// chips fluyen en dos filas. Antes quedaba cortado en el borde (x = 417 en 402 pt).
    func test_tagsChip_isVisibleWithoutScrolling() {
        let app = launch()
        openForm(app)
        typeAmount(app, "25")
        dismissKeyboard(app)
        app.chooseFirstSelectorRow(chip: "new_transaction_account_chip", rowPrefix: "account_selector_row_")
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")

        let tags = app.buttons["new_transaction_tags_chip"]
        XCTAssertTrue(tags.waitForExistence(timeout: 5))
        XCTAssertTrue(app.waitForSettledLayout(of: tags))
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.contains(tags.frame), "«Etiquetas» (\(tags.frame)) se sale de la ventana (\(window)).")
    }

    func test_newTag_withOnlyAName_isCreatedAndPut() {
        let app = launch()
        openForm(app)
        let tagsChip = app.buttons["new_transaction_tags_chip"]
        XCTAssertTrue(tagsChip.waitForExistence(timeout: 5))
        tagsChip.tap()

        let field = app.textFields["tag_selector_new_name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "La hoja de etiquetas no tiene el campo «Nueva etiqueta».")
        field.tap()
        field.typeText("Cumple QA")
        let create = app.buttons["tag_selector_create"]
        XCTAssertTrue(create.waitForExistence(timeout: 3))
        XCTAssertTrue(create.isEnabled, "Con un nombre, «Crear» se enciende.")
        create.tap()

        // Creada y puesta en la propia hoja, sin pasar por el editor de icono y color.
        let row = element(app, "tag_selector_row_Cumple QA")
        XCTAssertTrue(row.waitForExistence(timeout: 5), "La etiqueta nueva no apareció en la lista.")
        XCTAssertTrue(row.isSelected, "La etiqueta nueva tenía que quedar puesta.")
        XCTAssertFalse(app.navigationBars.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] '#'")).firstMatch.exists)
    }

    // MARK: - L2-3 · Buscar una categoría

    func test_categorySearch_tax_findsTaxis() {
        let app = launch()
        openForm(app)
        let chip = app.buttons["new_transaction_subcategory_chip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        chip.tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), "La hoja de categoría no tiene buscador.")
        search.tap()
        search.typeText("tax")

        let rows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'subcategory_selector_row_'"))
        let taxis = rows.matching(NSPredicate(format: "identifier BEGINSWITH 'subcategory_selector_row_Tax'")).firstMatch
        XCTAssertTrue(taxis.waitForExistence(timeout: 5), "«tax» tenía que traer «Taxis…».")
        XCTAssertEqual(rows.count, 1, "Solo la categoría que casa con «tax».")
    }

    // MARK: - L2-11 · Un gasto en dólares enseña su equivalencia

    func test_dollarAccount_showsTheEquivalenceAndTheRate() {
        let app = launch()
        openForm(app)
        typeAmount(app, "10")
        dismissKeyboard(app)
        let usd = app.openSelectorFirstRow(chip: "new_transaction_account_chip", rowPrefix: "account_selector_row_Ahorros")
        usd.tap()

        let equivalence = element(app, "new_transaction_equivalence")
        XCTAssertTrue(equivalence.waitForExistence(timeout: 10), "Con una cuenta en dólares, el formulario enseña «≈ S/ …».")
        XCTAssertTrue(element(app, "exchange_rate_capsule").exists, "Y la tasa en su cápsula con lápiz.")
    }

    // MARK: - L2-12 · «Mi parte» abre en «Iguales»

    func test_mySplit_opensInEqualParts_theFirstTime() {
        let app = launch()
        openForm(app)
        let split = app.buttons["new_transaction_split_action"]
        XCTAssertTrue(split.waitForExistence(timeout: 5))
        split.tap()
        let picker = app.segmentedControls.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(picker.buttons.element(boundBy: 0).isSelected, "La primera vez, «Iguales» (el primer segmento).")
    }

    // MARK: - L2-8 · La pista de los atajos

    func test_shortcutHint_isShownOnTheFirstOpening() {
        let app = launch()
        openForm(app)
        XCTAssertTrue(element(app, "new_transaction_shortcut_hint").waitForExistence(timeout: 5),
                      "Las primeras aperturas enseñan la pista de un atajo.")
    }
}
