//
//  PagoLogoPropioUITests.swift
//  YalaUITests
//
//  Logo propio de un pago planificado con una foto (encargo del 2026-11-20). El recorrido entero, con la galería real
//  del sistema (`PhotosPicker`): un pago cuyo comercio no está en el banco («Colegio San Martín») enseña la fila «Logo»,
//  «Usar una foto» abre la galería, la foto elegida queda como logo del pago (en el editor y en la lista) y elegir «Sin
//  logo» la quita. El simulador trae fotos de muestra en Fotos; el caso toma la primera.
//
//  Seed `minimal`, scheme Yala Dev. Lo que se guarda y cómo viaja lo fija `YalaTests/PagoLogoPropio/`.
//

import XCTest

final class PagoLogoPropioUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func keepScreenshot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// El editor de un pago nuevo con un nombre que no casa con ningún comercio, y su fila «Logo» a la vista.
    private func openNewPaymentLogoRow(_ app: XCUIApplication, name: String) -> XCUIElement {
        app.abrirFormularioDeNuevoPago()
        let nameField = app.textFields["scheduled_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "No se montó el editor.")
        nameField.tap()
        nameField.typeText(name)
        let logoRow = app.buttons["scheduled_logo_row"]
        if !logoRow.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(logoRow.waitForExistence(timeout: 5),
                      "Sin comercio conocido, la fila Logo tiene que salir igual: es donde se pone la foto.")
        // Tras escribir, el teclado sigue entrando y la hoja se mueve debajo (regla de `testing.md`): la fila se toca
        // quieta, y quien la toca afirma que abrió el selector.
        XCTAssertTrue(app.waitForSettledLayout(of: logoRow), "La fila Logo no dejó de moverse tras escribir.")
        return logoRow
    }

    /// Elige una foto de la galería del sistema. La galería corre en otro proceso y sus fotos no salen en el árbol de
    /// la app (medido el 2026-11-20, iOS 27.2): se toca por coordenadas, en la columna izquierda a un 42 % del alto,
    /// que cae en una foto con el aviso de «Acceso privado» arriba (primera fila) y sin él (segunda). Se reintenta
    /// hasta que el logo aparece en el editor: la galería tarda en montarse y el primer toque puede llegar antes.
    private func pickAPhoto(_ app: XCUIApplication, badge: XCUIElement) {
        let usePhoto = app.buttons["scheduled_logo_option_use_photo"]
        XCTAssertTrue(usePhoto.waitForExistence(timeout: 5), "No está «Usar una foto».")
        keepScreenshot(app, "1-selector")
        usePhoto.tap()
        let cell = app.coordinate(withNormalizedOffset: CGVector(dx: 0.17, dy: 0.42))
        for attempt in 0..<5 {
            // La espera entre intentos es la del propio logo: si ya salió, no hay otro toque.
            if badge.waitForExistence(timeout: attempt == 0 ? 3 : 4) { return }
            if attempt == 0 { keepScreenshot(app, "2-galeria") }
            cell.tap()
        }
    }

    func test_ownPhoto_becomesThePaymentLogo_andChoosingNoLogoRemovesIt() {
        let app = XCUIApplication()
        app.launchForUITest()
        app.openScheduledPaymentsList()

        let logoRow = openNewPaymentLogoRow(app, name: "Colegio San Martín")
        logoRow.tap()
        let badge = element(app, "scheduled_editor_brand_badge_\("custom_photo")")
        pickAPhoto(app, badge: badge)

        XCTAssertTrue(badge.waitForExistence(timeout: 10), "La foto no quedó como logo del pago en el editor.")
        XCTAssertEqual(badge.label, "Colegio San Martín", "VoiceOver lee el logo propio con el nombre del pago.")
        XCTAssertTrue(logoRow.label.contains("Tu foto"), "La fila Logo dice «\(logoRow.label)»")
        keepScreenshot(app, "3-editor-con-foto")

        // Volver al selector: la foto elegida está marcada, con «Cambiar» en la misma fila.
        logoRow.tap()
        XCTAssertTrue(element(app, "scheduled_logo_option_photo").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "scheduled_logo_photo_change").exists)
        keepScreenshot(app, "4-selector-con-foto")

        // «Sin logo» quita la foto.
        app.buttons["scheduled_logo_option_none"].tap()
        XCTAssertTrue(app.buttons["scheduled_logo_row"].waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "scheduled_editor_brand_badge_\("custom_photo")").exists,
                       "Elegir «Sin logo» tiene que quitar la foto.")
        XCTAssertTrue(app.buttons["scheduled_logo_row"].label.contains("Sin logo"))
    }

    /// Guardado con foto, el pago la lleva en la lista de Pagos planificados. En tema claro (`-userTheme 1`); el caso de
    /// arriba corre en el de siempre (oscuro).
    func test_ownPhoto_showsInTheList_afterSaving_lightTheme() {
        let app = XCUIApplication()
        app.launchForUITest(extraArguments: ["-userTheme", "1"])
        app.openScheduledPaymentsList()

        let name = "Colegio San Martín"
        let logoRow = openNewPaymentLogoRow(app, name: name)
        let amountField = app.textFields["scheduled_amount_field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("850")
        // Tras escribir el importe, la fila de categoría se toca quieta (regla de `testing.md`), y el selector que abre
        // lo afirma la espera de su primera fila.
        let subcategoryRow = app.buttons["scheduled_subcategory_row"]
        XCTAssertTrue(app.waitForSettledLayout(of: subcategoryRow), "La fila de categoría no dejó de moverse.")
        subcategoryRow.tap()
        let firstSubcat = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "subcategory_selector_row_")).firstMatch
        XCTAssertTrue(firstSubcat.waitForExistence(timeout: 5), "No se abrió el selector de subcategoría.")
        firstSubcat.tap()
        app.buttons["scheduled_account_menu"].tap()
        let firstAccount = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "scheduled_account_option_")).firstMatch
        XCTAssertTrue(firstAccount.waitForExistence(timeout: 5), "No se abrió el menú de cuentas.")
        firstAccount.tap()

        XCTAssertTrue(logoRow.waitForExistence(timeout: 5))
        XCTAssertTrue(app.waitForSettledLayout(of: logoRow))
        logoRow.tap()
        let badge = element(app, "scheduled_editor_brand_badge_\("custom_photo")")
        pickAPhoto(app, badge: badge)
        XCTAssertTrue(badge.waitForExistence(timeout: 10), "La foto no quedó como logo del pago en el editor.")
        keepScreenshot(app, "5-editor-claro")

        let save = app.buttons["toolbar_save_button"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "«\(name)» no aparece en la lista.")
        keepScreenshot(app, "6-lista-claro")

        // Al volver a abrirlo, la foto sigue: se guardó en el pago.
        row.tap()
        let edit = app.buttons["pencil"].firstMatch
        if edit.waitForExistence(timeout: 5) { edit.tap() }
        XCTAssertTrue(element(app, "scheduled_editor_brand_badge_\("custom_photo")").waitForExistence(timeout: 10),
                      "Al reabrir el pago, la foto no está.")
    }
}
