//
//  FormClarity23UITests.swift
//  YalaUITests
//
//  Mejoras necesarias 2.3 · Formulario: monedas claras y salida manual disponible (revisión por vistas 2.3 de Nuevo
//  registro, `docs/ux/revision-vistas-2.3/32-nuevo-registro/`). Tres correcciones mínimas:
//
//  - M1: al elegir una cuenta en otra moneda con el importe ya escrito, el formulario dice con palabras en qué moneda
//    queda ese importe. Control: con la cuenta elegida antes de escribir no hay nada que avisar.
//  - T1: en una transferencia entre monedas, cada importe dice de qué cuenta sale y a cuál llega, también para
//    VoiceOver.
//  - V3: el muro de Pro de voz y foto, que dice «Apuntar a mano sigue gratis», trae el botón que lo hace.
//
//  Cada caso adjunta su captura (`keepAlways`): son el antes y el después de la entrega.
//

import XCTest

final class FormClarity23UITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private static let largeText = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]

    @discardableResult
    private func launch(largeText: Bool = false, fakePrices: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", fakePrices: fakePrices,
                            extraArguments: largeText ? Self.largeText : [])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// «Nuevo» de la fila de acciones del Panel, que está en iPhone y en iPad (el «+» flotante no sale en ancho regular).
    private func openForm(_ app: XCUIApplication) {
        let new = app.buttons["panel_action_new"]
        XCTAssertTrue(new.waitForExistence(timeout: 10), "No apareció «Nuevo» en el Panel.")
        XCTAssertTrue(new.waitForHittable(timeout: 10), "«Nuevo» existe pero no se puede tocar.")
        new.tap()
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

    /// Fuera el teclado: un toque en la pregunta del monto, que no es un control. En iPad el teclado numérico sale en un
    /// globo ENCIMA de la pregunta y ese toque no llega: ahí se toca el tipo ya elegido, que no cambia nada.
    private func dismissKeyboard(_ app: XCUIApplication) {
        let question = element(app, "new_transaction_amount_question")
        XCTAssertTrue(question.waitForExistence(timeout: 5), "Falta la pregunta del monto.")
        question.tap()
        guard app.keyboards.firstMatch.waitForNonExistence(timeout: 2) == false else { return }
        let selectedType = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'new_transaction_type_' AND selected == true")).firstMatch
        if selectedType.exists { selectedType.tap() }
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 3)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Escribe 45 con la moneda principal y elige la cuenta en dólares: el número se queda y la moneda cambia.
    private func typeThenChooseDollarAccount(_ app: XCUIApplication) {
        openForm(app)
        typeAmount(app, "45")
        dismissKeyboard(app)
        app.openSelectorFirstRow(chip: "new_transaction_account_chip", rowPrefix: "account_selector_row_Ahorros").tap()
    }

    // MARK: - M1 · El cambio de moneda se dice con palabras

    func test_m1_choosingADollarAccount_withTheAmountWritten_saysTheCurrencyInWords() {
        let app = launch()
        typeThenChooseDollarAccount(app)

        let notice = element(app, "new_transaction_currency_notice")
        let shown = notice.waitForExistence(timeout: 8)
        capture(app, "m1-moneda-del-importe")
        XCTAssertTrue(shown, "Con 45 escrito y la cuenta en dólares, el formulario tenía que decir que el importe es en dólares.")
        XCTAssertTrue(notice.label.contains("USD"), "El aviso dice la moneda con su código: «\(notice.label)».")
        XCTAssertTrue(notice.label.contains("Ahorros"), "Y la cuenta que la trae: «\(notice.label)».")
    }

    /// Control: si la cuenta se elige ANTES de escribir, el importe nace en dólares y no cambia nada que avisar.
    func test_m1_choosingTheAccountFirst_hasNothingToWarnAbout() {
        let app = launch()
        openForm(app)
        dismissKeyboard(app)
        app.openSelectorFirstRow(chip: "new_transaction_account_chip", rowPrefix: "account_selector_row_Ahorros").tap()
        typeAmount(app, "45")
        dismissKeyboard(app)

        XCTAssertTrue(element(app, "new_transaction_equivalence").waitForExistence(timeout: 8),
                      "El escenario tiene que ser el de la cuenta en dólares (sale «≈ S/ …»).")
        XCTAssertFalse(element(app, "new_transaction_currency_notice").exists,
                       "Con la cuenta elegida antes de escribir, no hay cambio de moneda que avisar.")
    }

    func test_m1_withTheKeyboardOpen_theNoticeIsInView() {
        let app = launch()
        typeThenChooseDollarAccount(app)
        app.textFields["new_transaction_amount"].tap()
        let notice = element(app, "new_transaction_currency_notice")
        let shown = notice.waitForExistence(timeout: 8)
        capture(app, "m1-moneda-del-importe-teclado")
        XCTAssertTrue(shown, "Con el teclado abierto el aviso tiene que seguir ahí.")
    }

    func test_m1_largeText_theNoticeIsShown() {
        let app = launch(largeText: true)
        typeThenChooseDollarAccount(app)
        let notice = element(app, "new_transaction_currency_notice")
        let shown = notice.waitForExistence(timeout: 8)
        capture(app, "m1-moneda-del-importe-texto-grande")
        XCTAssertTrue(shown, "Con texto grande el aviso también sale.")
    }

    // MARK: - T1 · Cada importe de la transferencia dice su cuenta

    private func openCrossCurrencyTransfer(_ app: XCUIApplication) {
        openForm(app)
        app.buttons["new_transaction_type_transfer"].tap()
        dismissKeyboard(app)
        app.chooseFirstSelectorRow(chip: "new_transaction_source_chip", rowPrefix: "account_selector_row_Cuenta")
        app.chooseFirstSelectorRow(chip: "new_transaction_destination_chip", rowPrefix: "account_selector_row_Ahorros")
    }

    func test_t1_crossCurrencyTransfer_eachAmountNamesItsAccount() {
        let app = launch()
        openCrossCurrencyTransfer(app)

        let source = element(app, "transfer_source_caption")
        let shown = source.waitForExistence(timeout: 8)
        capture(app, "t1-transferencia-entre-monedas")
        XCTAssertTrue(shown, "El importe que sale tenía que decir de qué cuenta sale.")
        XCTAssertTrue(source.label.contains("Cuenta Principal"), "Origen: «\(source.label)».")
        let destination = element(app, "transfer_destination_caption")
        XCTAssertTrue(destination.exists, "El importe que llega tenía que decir a qué cuenta llega.")
        XCTAssertTrue(destination.label.contains("Ahorros"), "Destino: «\(destination.label)».")

        // VoiceOver: cada campo dice su cuenta y su moneda, no solo «Monto origen».
        let sourceField = app.textFields.matching(NSPredicate(format: "label CONTAINS %@", "Cuenta Principal")).firstMatch
        XCTAssertTrue(sourceField.exists, "El campo del importe que sale no nombra su cuenta para VoiceOver.")
        let destinationField = app.textFields.matching(NSPredicate(format: "label CONTAINS %@", "Ahorros")).firstMatch
        XCTAssertTrue(destinationField.exists, "El campo del importe que llega no nombra su cuenta para VoiceOver.")
    }

    func test_t1_largeText_bothCaptionsAreShown() {
        let app = launch(largeText: true)
        openCrossCurrencyTransfer(app)
        let source = element(app, "transfer_source_caption")
        let shown = source.waitForExistence(timeout: 8)
        capture(app, "t1-transferencia-entre-monedas-texto-grande")
        XCTAssertTrue(shown, "Con texto grande sale también de qué cuenta sale.")
        XCTAssertTrue(element(app, "transfer_destination_caption").exists, "Y a cuál llega.")
    }

    // MARK: - V3 · El muro de Pro ofrece «Apuntarlo a mano» de verdad

    /// Desde «Voz» del Panel; con texto grande esa fila se desplaza a lo ancho y «Voz» queda fuera, así que se entra
    /// por el menú del «+», que abre la misma voz.
    private func openVoiceGate(_ app: XCUIApplication, fromFAB: Bool = false) {
        if fromFAB {
            app.revealPanelFAB().tap()
            let voice = app.buttons["fab_voice"]
            XCTAssertTrue(voice.waitForExistence(timeout: 5), "No se expandió el menú del «+» (fab_voice).")
            voice.tap()
        } else {
            let voice = app.buttons["panel_action_voice"]
            XCTAssertTrue(voice.waitForExistence(timeout: 10), "No apareció Voz en el Panel.")
            XCTAssertTrue(voice.waitForHittable(timeout: 10), "Voz existe pero no se puede tocar.")
            voice.tap()
        }
        XCTAssertTrue(app.buttons["upgrade_prompt_not_now"].waitForExistence(timeout: 10), "No salió el muro de Pro.")
    }

    func test_v3_voiceGate_offersManualEntry_andItOpensTheForm() {
        let app = launch(fakePrices: true)
        openVoiceGate(app)

        let manual = app.buttons["upgrade_prompt_manual_entry"]
        let offered = manual.waitForExistence(timeout: 5)
        capture(app, "v3-muro-pro-voz")
        XCTAssertTrue(offered, "El muro dice «Apuntar a mano sigue gratis» y tenía que traer el botón.")

        manual.tap()
        let amount = app.textFields["new_transaction_amount"]
        let opened = amount.waitForExistence(timeout: 10)
        capture(app, "v3-formulario-tras-apuntar-a-mano")
        XCTAssertTrue(opened, "«Apuntarlo a mano» tenía que abrir Nuevo registro.")
    }

    func test_v3_largeText_manualEntryIsReachable() {
        let app = launch(largeText: true, fakePrices: true)
        openVoiceGate(app, fromFAB: true)
        let manual = app.buttons["upgrade_prompt_manual_entry"]
        var swipes = 0
        while manual.exists && !manual.isHittable && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        capture(app, "v3-muro-pro-voz-texto-grande")
        XCTAssertTrue(manual.exists && manual.isHittable, "Con texto grande «Apuntarlo a mano» tiene que alcanzarse.")
    }

    /// Control: «Ahora no» sigue cerrando sin abrir nada.
    func test_v3_voiceGate_notNow_opensNothing() {
        let app = launch(fakePrices: true)
        openVoiceGate(app)
        let notNow = app.buttons["upgrade_prompt_not_now"]
        notNow.tap()
        XCTAssertTrue(notNow.waitForNonExistence(timeout: 5), "«Ahora no» no cerró el muro.")
        XCTAssertFalse(app.textFields["new_transaction_amount"].waitForExistence(timeout: 3),
                       "«Ahora no» no abre el formulario.")
    }
}
