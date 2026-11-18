//
//  MerchantLogosUITests.swift
//  YalaUITests
//
//  Pagos planificados: logos reales y banco amplio de comercios (card `scheduled-payments-real-brand-logos`).
//  Los pagos son los de la captura de TestFlight de Jürgen (SmartFit, Claro, Spotify, Cloudflare): antes del cambio
//  solo Spotify y SmartFit tenían distintivo.
//

import XCTest

final class MerchantLogosUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        XCUIDevice.shared.appearance = .light
        super.tearDown()
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

    private func openNewPayment(_ app: XCUIApplication) -> XCUIElement {
        let addButton = app.buttons["scheduled_payments_create_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "No apareció el + de Pagos planificados.")
        addButton.tap()
        let nameField = app.textFields["scheduled_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "No se montó el editor.")
        nameField.tap()
        return nameField
    }

    private func createPayment(_ app: XCUIApplication, name: String, amount: String) {
        let nameField = openNewPayment(app)
        nameField.typeText(name)
        let amountField = app.textFields["scheduled_amount_field"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText(amount)
        app.buttons["scheduled_account_menu"].tap()
        let firstAccount = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "scheduled_account_option_")).firstMatch
        XCTAssertTrue(firstAccount.waitForExistence(timeout: 5), "No se abrió el menú de cuentas.")
        firstAccount.tap()
        app.buttons["scheduled_subcategory_row"].tap()
        let firstSubcat = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "subcategory_selector_row_")).firstMatch
        XCTAssertTrue(firstSubcat.waitForExistence(timeout: 5), "No se abrió el selector de subcategoría.")
        firstSubcat.tap()
        let save = app.buttons["toolbar_save_button"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "«\(name)» no aparece en la lista.")
    }

    /// El editor propone el logo de cada comercio de la captura, también con sufijos («J1») y sin estar entre las
    /// suscripciones de antes (Claro, Cloudflare).
    func test_editor_proposesTheLogoOfEachMerchantOfTheScreenshot() {
        let app = XCUIApplication()
        app.launchForUITest()
        app.openScheduledPaymentsList()

        let cases = [("SmartFit J1", "smartfit"), ("Claro", "claro"), ("Spotify", "spotify"), ("Cloudflare", "cloudflare")]
        let field = openNewPayment(app)
        var typed = ""
        for (name, id) in cases {
            // Mismo editor: se borra lo anterior y se escribe el siguiente nombre.
            if !typed.isEmpty {
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: typed.count))
            }
            field.typeText(name)
            typed = name
            XCTAssertTrue(element(app, "scheduled_editor_brand_badge_\(id)").waitForExistence(timeout: 5),
                          "El editor no propuso el logo de «\(name)».")
        }
    }

    /// Elegir a mano: la hoja busca entre todo el banco y el elegido queda puesto.
    func test_editor_pickerSearchesTheWholeBank_andTheChosenLogoSticks() {
        let app = XCUIApplication()
        app.launchForUITest()
        app.openScheduledPaymentsList()

        let field = openNewPayment(app)
        // Un nombre con logo propio, para que salga la fila; se cambia por otro del banco que no es suscripción.
        field.typeText("Netflix")
        let logoRow = app.buttons["scheduled_logo_row"]
        if !logoRow.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(logoRow.waitForExistence(timeout: 5), "No apareció la fila Logo.")
        logoRow.tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5), "La hoja del logo no tiene buscador.")
        search.tap()
        search.typeText("yape")
        let yape = app.buttons["scheduled_logo_option_yape"]
        XCTAssertTrue(yape.waitForExistence(timeout: 5), "El buscador no encontró Yape.")
        yape.tap()
        XCTAssertTrue(element(app, "scheduled_editor_brand_badge_yape").waitForExistence(timeout: 5),
                      "El logo elegido no quedó puesto.")
    }

    /// Deja los pagos de la captura a la vista: arrastres cortos hasta que la fila de SmartFit quede en la mitad de arriba.
    private func bringPaymentsIntoView(_ app: XCUIApplication) {
        let smartFit = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "SmartFit J1")).firstMatch
        XCTAssertTrue(smartFit.waitForExistence(timeout: 10), "No está la fila de SmartFit.")
        for _ in 0..<12 where smartFit.frame.minY > app.frame.height * 0.45 {
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)))
        }
        sleep(1)
    }

    /// Capturas para el PR: la lista con los cuatro pagos en el tema claro y en el oscuro de Yala (la app no sigue al
    /// sistema: `-userTheme`), girada, y el calendario.
    func test_capture_listWithTheScreenshotPayments() {
        let app = XCUIApplication()
        app.launchForUITest(extraArguments: ["-userTheme", "1"])
        app.openScheduledPaymentsList()

        createPayment(app, name: "SmartFit J1", amount: "129")
        createPayment(app, name: "Claro", amount: "89.90")
        createPayment(app, name: "Spotify", amount: "20.90")
        createPayment(app, name: "Cloudflare", amount: "25")

        // Que se vaya el aviso «Listo. Primer pago…».
        sleep(6)
        bringPaymentsIntoView(app)
        keepScreenshot(app, "lista-claro")

        // El calendario: cada pago con su marca en su día.
        let calendar = app.buttons["scheduled_view_mode_calendar"]
        for _ in 0..<8 where !(calendar.exists && calendar.isHittable) {
            app.swipeDown(velocity: .slow)
        }
        if calendar.exists, calendar.isHittable {
            calendar.tap()
            sleep(2)
            keepScreenshot(app, "detalle-claro")
        }

        // Tema oscuro de Yala, con los mismos datos (sin borrar).
        app.terminate()
        app.launchForUITest(reset: false, extraArguments: ["-userTheme", "2"])
        app.openScheduledPaymentsList()
        let list = app.buttons["scheduled_view_mode_list"]
        if list.waitForExistence(timeout: 3), list.isHittable { list.tap() }
        bringPaymentsIntoView(app)
        keepScreenshot(app, "lista-oscuro")
        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(2)
        bringPaymentsIntoView(app)
        keepScreenshot(app, "lista-girada")
        XCUIDevice.shared.orientation = .portrait
    }
}
