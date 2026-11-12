//
//  KeyboardSaveBar23UITests.swift
//  YalaUITests
//
//  Revisión 2.3 · Nuevo registro, decisiones 20 y 68 del 9-nov
//  (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`, ficha en
//  `docs/ux/revision-vistas-2.3/32-nuevo-registro/`):
//
//  - G1: con el teclado abierto, una barra fina encima del teclado con lo que falta (cuenta y categoría, u origen y
//    destino) y «Guardar». Se elige la categoría desde la barra y se guarda sin cerrar el teclado.
//  - «Para guardar, falta…» deja de montarse sobre «Etiquetas»: con el teclado abierto la línea no está en el contenido
//    (la dice la barra); sin teclado, lo de detrás pasa difuminado bajo la barra de «Guardar» (arreglo de 2.2).
//  - iPad: el importe abre el teclado acoplado, no un teclado numérico flotante encima de la hoja (decisión 68).
//
//  Cada caso adjunta su captura (`keepAlways`): son el antes y el después de la entrega.
//

import XCTest

final class KeyboardSaveBar23UITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private static let largeText = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]

    @discardableResult
    private func launch(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", extraArguments: largeText ? Self.largeText : [])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// «Nuevo» de la fila de acciones del Panel, que está en iPhone y en iPad.
    private func openForm(_ app: XCUIApplication) {
        let new = app.buttons["panel_action_new"]
        XCTAssertTrue(new.waitForExistence(timeout: 10), "No apareció «Nuevo» en el Panel.")
        XCTAssertTrue(new.waitForHittable(timeout: 10), "«Nuevo» existe pero no se puede tocar.")
        new.tap()
        XCTAssertTrue(app.textFields["new_transaction_amount"].waitForExistence(timeout: 5), "No se abrió el formulario.")
    }

    private func typeAmount(_ app: XCUIApplication, _ value: String) {
        let amount = app.textFields["new_transaction_amount"]
        // Con el texto al máximo el importe queda debajo de la guía: se sube el formulario hasta tenerlo a mano.
        var swipes = 0
        while !app.windows.firstMatch.frame.contains(amount.frame) && swipes < 4 {
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
        amount.tap()
        amount.typeText(value)
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Espera a que el teclado esté abierto y quieto, y a la barra si la hay.
    private func waitForKeyboardAndBar(_ app: XCUIApplication) {
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "El teclado no se abrió al tocar el importe.")
        _ = app.waitForSettledLayout(of: app.textFields["new_transaction_amount"])
        _ = app.buttons["new_transaction_save"].waitForExistence(timeout: 3)
    }

    // MARK: - G1 · La barra sobre el teclado

    /// El café de Ana: escribe 4.50 y, con el teclado abierto, ve lo que falta y «Guardar» justo encima del teclado.
    func test_g1_withTheKeyboardOpen_whatIsMissingAndSaveSitAboveTheKeyboard() {
        let app = launch()
        openForm(app)
        typeAmount(app, "4.50")
        waitForKeyboardAndBar(app)
        capture(app, "g1-barra-sobre-el-teclado")

        let save = app.buttons["new_transaction_save"]
        XCTAssertTrue(save.exists, "Con el teclado abierto tiene que haber «Guardar» en una barra encima del teclado.")
        XCTAssertTrue(save.isHittable, "«Guardar» de la barra se puede tocar con el teclado abierto.")
        let keyboardTop = app.keyboards.firstMatch.frame.minY
        XCTAssertLessThanOrEqual(save.frame.maxY, keyboardTop + 1,
                                 "«Guardar» va encima del teclado (\(save.frame.maxY) > \(keyboardTop)).")
        XCTAssertFalse(save.isEnabled, "Sin categoría, «Guardar» sigue apagado.")

        let category = app.buttons["new_transaction_keyboard_category_chip"]
        XCTAssertTrue(category.exists, "La barra dice que falta la categoría.")
        XCTAssertTrue(category.isHittable, "La categoría de la barra se puede tocar con el teclado abierto.")
        XCTAssertLessThanOrEqual(category.frame.maxY, keyboardTop + 1, "La categoría de la barra va encima del teclado.")
        XCTAssertTrue(app.buttons["new_transaction_keyboard_account_chip"].exists, "Y la cuenta, a su lado.")
    }

    /// Elige desde una pastilla de la barra la primera fila de su hoja, y comprueba que se vuelve con el teclado.
    private func chooseFromBar(_ app: XCUIApplication, chip chipID: String, rowPrefix: String, what: String) {
        let chip = app.buttons[chipID]
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "Falta \(what) en la barra.")
        XCTAssertTrue(app.waitForSettledLayout(of: chip), "La pastilla de \(what) no dejó de moverse.")
        chip.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", rowPrefix)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Tocar \(what) en la barra abre su hoja.")
        row.tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 5), "La hoja de \(what) se cierra al elegir.")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5),
                      "Al elegir \(what) se vuelve al importe con el teclado abierto.")
    }

    /// Recorrido entero: cuenta y categoría desde la barra, vuelve con el teclado y «Guardar» encendido, y guarda sin
    /// cerrarlo.
    func test_g1_chooseFromTheBar_returnsWithTheKeyboard_andSaves() {
        let app = launch()
        openForm(app)
        typeAmount(app, "4.50")
        waitForKeyboardAndBar(app)

        // La semilla `minimal` no deja cuenta precargada; si algún día la deja, ya está elegida (pastilla seleccionada).
        if !app.buttons["new_transaction_keyboard_account_chip"].isSelected {
            chooseFromBar(app, chip: "new_transaction_keyboard_account_chip", rowPrefix: "account_selector_row_",
                          what: "la cuenta")
        }
        chooseFromBar(app, chip: "new_transaction_keyboard_category_chip", rowPrefix: "subcategory_selector_row_",
                      what: "la categoría")
        let save = app.buttons["new_transaction_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Y con la barra.")
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: save)
        waitForExpectations(timeout: 5)
        capture(app, "g1-barra-lista-para-guardar")

        save.tap()
        XCTAssertTrue(app.textFields["new_transaction_amount"].waitForNonExistence(timeout: 8),
                      "«Guardar» de la barra guarda el registro y cierra el formulario.")
    }

    /// En una transferencia la barra pide origen y destino, no categoría.
    func test_g1_transfer_barAsksForTheTwoAccounts() {
        let app = launch()
        openForm(app)
        app.buttons["new_transaction_type_transfer"].tap()
        typeAmount(app, "100")
        waitForKeyboardAndBar(app)
        capture(app, "g1-barra-transferencia")
        XCTAssertTrue(app.buttons["new_transaction_keyboard_source_chip"].exists, "La barra pide la cuenta de origen.")
        XCTAssertTrue(app.buttons["new_transaction_keyboard_destination_chip"].exists, "Y la de destino.")
        XCTAssertFalse(app.buttons["new_transaction_keyboard_category_chip"].exists, "Una transferencia no lleva categoría.")
        XCTAssertTrue(app.buttons["new_transaction_save"].exists, "Y «Guardar».")
    }

    /// Con el texto al máximo la barra cabe: al menos lo primero que falta y «Guardar», encima del teclado.
    func test_g1_largeText_theBarStillFitsAboveTheKeyboard() {
        let app = launch(largeText: true)
        openForm(app)
        typeAmount(app, "4.50")
        waitForKeyboardAndBar(app)
        capture(app, "g1-barra-texto-grande")
        let save = app.buttons["new_transaction_save"]
        XCTAssertTrue(save.exists && save.isHittable, "Con texto grande, «Guardar» sigue en la barra y se puede tocar.")
        XCTAssertTrue(app.windows.firstMatch.frame.contains(save.frame), "«Guardar» de la barra cabe en la pantalla.")
        XCTAssertLessThanOrEqual(save.frame.maxY, app.keyboards.firstMatch.frame.minY + 1, "Y va encima del teclado.")
    }

    // MARK: - iPad · el importe no abre un teclado flotante encima de la hoja (decisión 68)

    /// En el iPad el teclado del importe sale acoplado abajo, a todo el ancho; antes salía además un teclado numérico
    /// flotante encima de la descripción y la pregunta del importe (`amountKeyboard()`). Solo en iPad; discrimina en el
    /// iPad Air 11 (en el Pro 13 el flotante no salía ni antes, medido el 2026-11-11).
    func test_iPad_amountKeyboardIsDockedNotFloatingOverTheSheet() throws {
        let app = launch()
        let window = app.windows.firstMatch.frame
        try XCTSkipUnless(window.width >= 700, "Solo en iPad (ventana de \(window.width) pt).")
        openForm(app)
        typeAmount(app, "4.50")
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "El teclado no se abrió al tocar el importe.")
        _ = app.waitForSettledLayout(of: app.textFields["new_transaction_amount"])
        capture(app, "ipad-teclado-del-importe")
        // Un teclado de verdad en pantalla: con la marca de teclado físico del simulador no se pinta ninguno y el caso
        // pasaría sin medir nada (`HardwareKeyboardLastSeen`, `testing.md`).
        XCTAssertGreaterThan(keyboard.frame.height, 150, "No hay teclado en pantalla (\(keyboard.frame)): ¿teclado físico?")
        XCTAssertLessThan(keyboard.frame.minY, window.maxY - 150, "El teclado tiene que verse (\(keyboard.frame)).")
        XCTAssertGreaterThanOrEqual(keyboard.frame.width, window.width * 0.9,
                                    "El teclado del importe sale acoplado a todo el ancho, no flotando (\(keyboard.frame)).")
        XCTAssertGreaterThanOrEqual(keyboard.frame.maxY, window.maxY - 8, "Y pegado abajo (las esquinas lo dejan a 3 pt).")
        // El flotante es un segundo teclado numérico en un globo sobre la hoja (iPad Air 11, iOS 27.2): sus teclas salen
        // en el árbol encima del acoplado. Ninguna «1» puede quedar por encima de él.
        let dockedTop = app.keyboards.allElementsBoundByIndex.map(\.frame.minY).max() ?? keyboard.frame.minY
        for key in app.keys.matching(NSPredicate(format: "label == '1'")).allElementsBoundByIndex {
            XCTAssertGreaterThanOrEqual(key.frame.minY, dockedTop - 1,
                                        "Hay un teclado numérico flotando encima de la hoja (tecla «1» en \(key.frame)).")
        }
        let amount = app.textFields["new_transaction_amount"]
        XCTAssertLessThanOrEqual(amount.frame.maxY, dockedTop, "El importe queda a la vista, encima del teclado.")
    }

    // MARK: - «Para guardar, falta…» no se monta sobre «Etiquetas»

    /// Baja el formulario a arrastres cortos hasta que «Etiquetas» quede entera por encima de `top` (lo primero de la
    /// barra de abajo). Devuelve si lo consiguió.
    private func scrollTagsChip(_ app: XCUIApplication, above top: () -> CGFloat) -> Bool {
        let tags = app.buttons["new_transaction_tags_chip"]
        guard tags.waitForExistence(timeout: 5) else { return false }
        var swipes = 0
        while tags.frame.maxY > top() && swipes < 8 {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -160)))
            swipes += 1
        }
        return tags.frame.maxY <= top() + 1
    }

    /// El caso de la captura de la revisión, sin teclado: con la guía arriba y el texto al máximo el formulario no cabe.
    /// Lo de detrás pasa por debajo de la barra de «Guardar» (difuminado, arreglo de 2.2), y al bajar del todo
    /// «Etiquetas» queda entera por encima de la línea de lo que falta.
    func test_missingLine_withTheGuideAndNoKeyboard_theTagsChipEndsAboveIt() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", extraArguments: ["-uitest-show-guides"] + Self.largeText)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openForm(app)
        let line = element(app, "new_transaction_missing_line")
        XCTAssertTrue(line.waitForExistence(timeout: 5), "Sin nada escrito, la línea dice lo que falta.")
        let reached = scrollTagsChip(app) { line.frame.minY }
        capture(app, "linea-de-lo-que-falta-con-la-guia-al-final")
        XCTAssertTrue(reached, "Al bajar del todo, «Etiquetas» tiene que quedar por encima de «Para guardar, falta…».")
    }

    /// Con el teclado abierto la barra va encima del teclado: al bajar el formulario, «Etiquetas» (que no está en la
    /// barra) tiene que poder quedar por encima de ella, no escondida debajo.
    func test_withTheKeyboardOpen_theTagsChipCanScrollAboveTheBar() {
        let app = launch()
        openForm(app)
        typeAmount(app, "4.50")
        waitForKeyboardAndBar(app)
        let save = app.buttons["new_transaction_save"]
        let barTop = { min(save.frame.minY, app.buttons["new_transaction_keyboard_account_chip"].frame.minY) }
        let reached = scrollTagsChip(app, above: barTop)
        capture(app, "g1-etiquetas-sobre-la-barra")
        XCTAssertTrue(app.keyboards.firstMatch.exists, "Bajar el formulario no cierra el teclado.")
        XCTAssertTrue(reached, "Con el teclado abierto, «Etiquetas» tiene que poder quedar por encima de la barra.")
    }

    /// Con el teclado abierto lo que falta lo dice la barra: la línea del formulario no está, así que no puede quedar
    /// encima de «Etiquetas» ni a medias bajo «Guardar».
    func test_missingLine_withTheKeyboardOpen_isNotALineOverTheChips() {
        let app = launch()
        openForm(app)
        typeAmount(app, "4.50")
        waitForKeyboardAndBar(app)
        let line = element(app, "new_transaction_missing_line")
        let tags = app.buttons["new_transaction_tags_chip"]
        if line.exists && tags.exists {
            XCTAssertFalse(line.frame.intersects(tags.frame),
                           "«Para guardar, falta…» se monta sobre «Etiquetas» (\(line.frame) ∩ \(tags.frame)).")
        }
        XCTAssertFalse(line.exists, "Con el teclado abierto lo que falta va en la barra, no en una línea del formulario.")
    }
}
