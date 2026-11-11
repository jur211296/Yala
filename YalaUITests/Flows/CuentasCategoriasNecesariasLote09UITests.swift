//
//  CuentasCategoriasNecesariasLote09UITests.swift
//  YalaUITests
//
//  Lote 09 de las mejoras necesarias 2.3 (zona 39: cuentas, categorías, etiquetas y divisas).
//  Un caso por defecto que se ve en pantalla; la lógica pura va en `CuentasCategoriasNecesariasLote09Tests`.
//

import XCTest

final class CuentasCategoriasNecesariasLote09UITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Punto 1. Sin ninguna moneda secundaria, «Tipo de cambio» enseñaba las dos primeras divisas del catálogo, que nadie
    /// eligió. Ahora no enseña ninguna fila: solo «Ver todas».
    func test_exchangeRates_withoutSecondaryCurrencies_showsNoRateRow() {
        let app = XCUIApplication()
        // Gana a la siembra de USD y EUR del arranque de UI test: el dominio de argumentos se lee antes que el de la app.
        app.launchForUITest(extraArguments: ["-secondaryCurrencies", ""])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_currency")
        let secondaryButton = app.buttons["currency_secondary_button"]
        XCTAssertTrue(secondaryButton.waitForExistence(timeout: 5), "No se abrió Moneda y tipo de cambio.")
        app.swipeUp()
        attachScreenshot(app, named: "p1-tipo-de-cambio-sin-secundarias")

        // La fila de una tasa empieza por «1 XXX» (o por el código, si se lee al revés).
        let rateRows = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^1 [A-Z]{3}$"))
        XCTAssertEqual(rateRows.count, 0, "Tipo de cambio enseña divisas que nadie eligió: \(rateRows.allElementsBoundByIndex.map(\.label)).")
        XCTAssertEqual(
            app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "currency_rate_row_")).count,
            0, "Hay filas de tipo de cambio sin monedas secundarias."
        )
    }

    /// Punto 2. La lista de cuentas escribía el saldo con el código («PEN 2,000.00») mientras el formulario y el Panel usan
    /// el símbolo. Ahora sigue la preferencia de Personalización, que por defecto es el símbolo.
    func test_accountsList_balanceUsesTheSymbolLikeThePanel() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_accounts")
        let firstRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "accounts_row_")).firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "No se abrió la lista de cuentas.")
        attachScreenshot(app, named: "p2-lista-de-cuentas")

        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "accounts_row_")).allElementsBoundByIndex
        let labels = rows.map(\.label)
        XCTAssertFalse(labels.isEmpty, "La lista de cuentas no tiene filas.")
        XCTAssertFalse(
            labels.contains { $0.contains("PEN ") },
            "Un saldo de la lista sigue con el código: \(labels)."
        )
        XCTAssertTrue(
            labels.contains { $0.contains("S/") },
            "Ningún saldo de la lista usa el símbolo del sol: \(labels)."
        )
    }

    /// Punto 4. El formulario de etiqueta cortaba el nombre a 20 sin avisar, enseñaba el color como «#FF9F0A» y su X
    /// cerraba sin preguntar aunque hubiera cambios (Cuentas y Categorías sí preguntan).
    func test_tagForm_warnsAtTheLimit_namesTheColor_andTheCloseAsks() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_tags")
        let addButton = app.buttons["tags_add_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "No apareció tags_add_button.")

        // Control: sin cambios, la X cierra sin preguntar.
        addButton.tap()
        let nameField = app.textFields["tag_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "No apareció el formulario de etiqueta.")
        let close = app.buttons["Cerrar"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5), "No apareció la X del formulario.")
        close.tap()
        XCTAssertTrue(nameField.waitForNonExistence(timeout: 5), "Sin cambios, la X no cerró el formulario.")

        // El nombre largo se corta a 20 y lo dice.
        addButton.tap()
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "No volvió a abrir el formulario.")
        nameField.tap()
        nameField.typeText("Cumpleaños de mamá 2024")
        let limit = app.staticTexts["tag_name_count"]
        _ = limit.waitForExistence(timeout: 5)
        attachScreenshot(app, named: "p4-formulario-de-etiqueta")
        XCTAssertTrue(limit.exists, "El nombre se cortó sin avisar.")
        XCTAssertTrue(limit.label.contains("20 de 20"), "El aviso no dice el límite: «\(limit.label)».")

        // El color se nombra: nada en el formulario se lee como un código hexadecimal.
        let hexTexts = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "#"))
        XCTAssertEqual(hexTexts.count, 0, "El formulario enseña el color como código: \(hexTexts.allElementsBoundByIndex.map(\.label)).")
        let hexOptions = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "#"))
        XCTAssertEqual(hexOptions.count, 0, "VoiceOver lee los colores por su código: \(hexOptions.allElementsBoundByIndex.map(\.label)).")

        // Con cambios, la X pregunta; «Seguir editando» deja el formulario como estaba.
        close.tap()
        let keepEditing = app.alerts.buttons["Seguir editando"].firstMatch
        XCTAssertTrue(keepEditing.waitForExistence(timeout: 5), "La X cerró sin preguntar con un nombre escrito.")
        attachScreenshot(app, named: "p4-x-pregunta")
        keepEditing.tap()
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "«Seguir editando» cerró el formulario.")

        // «Descartar» cierra sin crear nada.
        close.tap()
        let discard = app.alerts.buttons["Descartar"].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 5), "La segunda X no preguntó.")
        discard.tap()
        XCTAssertTrue(nameField.waitForNonExistence(timeout: 5), "«Descartar» no cerró el formulario.")
        XCTAssertFalse(app.buttons["tags_row_Cumpleaños de mamá 2"].exists, "Descartar guardó la etiqueta.")
    }

    /// Punto 3. El «+» de Categorías inserta la categoría antes de escribir nada, y guardar su primera subcategoría guarda
    /// el contexto entero: si la app se cierra ahí, al volver queda una categoría sin nombre en la lista.
    func test_newCategory_appClosedAfterItsFirstSubcategory_leavesNoNamelessCategory() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        app.openSettingsSection("profile_categories")

        let addButton = app.buttons["categories_add_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "No apareció categories_add_button.")
        addButton.tap()

        let catNameField = app.textFields["category_name_field"]
        XCTAssertTrue(catNameField.waitForExistence(timeout: 5), "No se montó CategoryDetailView.")
        catNameField.tap()
        catNameField.typeText("QA A medias")

        let addSub = app.buttons["category_add_subcategory"]
        XCTAssertTrue(addSub.waitForExistence(timeout: 5), "No apareció category_add_subcategory.")
        addSub.tap()
        let subNameField = app.textFields["subcategory_name_field"]
        XCTAssertTrue(subNameField.waitForExistence(timeout: 5), "No se montó SubcategoryDetailView.")
        subNameField.tap()
        subNameField.typeText("QA Sub")
        let saveSub = app.buttons["toolbar_save_button"]
        XCTAssertTrue(saveSub.waitForExistence(timeout: 5), "No apareció save de subcategoría.")
        saveSub.tap()

        // De vuelta en la categoría, sin guardarla: la app se cierra aquí.
        XCTAssertTrue(catNameField.waitForExistence(timeout: 5), "No volvió a la categoría nueva.")
        app.terminate()

        app.launchForUITest(reset: false)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente en el segundo arranque.")
        app.openProfile()
        app.openSettingsSection("profile_categories")
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "No se abrió Categorías tras relanzar.")

        let nameless = app.buttons["categories_row_"]
        _ = nameless.waitForExistence(timeout: 3)
        attachScreenshot(app, named: "p3-categorias-tras-relanzar")
        XCTAssertFalse(
            nameless.waitForExistence(timeout: 3),
            "Quedó una categoría sin nombre tras cerrar la app a mitad de crearla."
        )
        XCTAssertFalse(
            app.buttons["categories_row_QA A medias"].exists,
            "La categoría a medias apareció con su nombre: nunca se guardó."
        )
    }
}
