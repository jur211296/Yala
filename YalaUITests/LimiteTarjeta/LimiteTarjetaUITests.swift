//
//  LimiteTarjetaUITests.swift
//  YalaUITests
//
//  El límite de una tarjeta de crédito (decisión de Jürgen del 22-nov-2026, opción A): se escribe en Editar cuenta y la
//  hoja de la cuenta dice «X % usado · N disponible de M» solo mientras la tarjeta lo tiene.
//  - `tarjeta-limite`: «Visa QA» solo en soles, con corte; lo que debes es 1,240 facturado + 386.50 por facturar.
//  - Las capturas del antes y el después salen de `test_capturas_hojaYFormulario` con `TEST_RUNNER_CAPTURAS_DIR`
//    (y `TEST_RUNNER_CAPTURAS_PREFIJO`, `TEST_RUNNER_CAPTURAS_SEMILLA`); sin esa variable el caso se salta.
//  Convenciones: sin sleeps, scheme Yala Dev, ids y no textos (salvo el nombre sembrado y las cifras).
//

import XCTest

final class LimiteTarjetaUITests: XCTestCase {

    private let card = "Visa QA"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Ayudantes

    private func launch(seed: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: seed, extraArguments: ["-defaultPeriod", "last30Days"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 10), "La app no llegó al Panel.")
        return app
    }

    /// Abre la hoja de la tarjeta desde el carrusel del Panel.
    private func openSheet(_ app: XCUIApplication) {
        let visa = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(card).")).firstMatch
        // En el iPad las cuentas van en rejilla y la tarjeta ya está a la vista; en el iPhone, en el carrusel.
        if !visa.waitForExistence(timeout: 5) {
            openSheetFromCarousel(app, visa)
        }
        XCTAssertTrue(visa.waitForExistence(timeout: 5), "No hay tarjeta de «\(card)».")
        visa.tap()
        XCTAssertTrue(app.descendants(matching: .any)["hoja_cuenta_estado"].firstMatch.waitForExistence(timeout: 8),
                      "La hoja no trae el estado de cuenta de la tarjeta.")
    }

    private func openSheetFromCarousel(_ app: XCUIApplication, _ visa: XCUIElement) {
        let first = app.buttons["panel_account_card_0"]
        if !first.waitForExistence(timeout: 3) {
            app.buttons["panel_panorama_header"].tap()
        }
        XCTAssertTrue(first.waitForExistence(timeout: 5), "No apareció la primera tarjeta.")
        var swipes = 0
        while !visa.exists && swipes < 6 {
            first.swipeLeft()
            swipes += 1
        }
    }

    /// Editar, desde la hoja: abre el formulario y baja hasta el campo del límite.
    private func openFormAtLimit(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["account_detail_edit"].tap()
        XCTAssertTrue(app.textFields["account_name_field"].waitForExistence(timeout: 8), "No abrió el formulario.")
        let field = app.textFields["account_cc_credit_limit"]
        var swipes = 0
        // `isHittable` y no el marco de la ventana: en el iPad el formulario es una hoja más pequeña que la ventana, el
        // campo cabía en la ventana pero quedaba bajo la hoja, y el toque caía fuera y la cerraba (medido en el vídeo).
        while swipes < 10 && !(field.exists && field.isHittable) {
            // Arrastre desde el centro de la ventana: en el iPad cae dentro de la hoja, que va centrada.
            let window = app.windows.firstMatch
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
                .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
            swipes += 1
        }
        XCTAssertTrue(field.exists && field.isHittable, "El formulario de la tarjeta no trae el campo del límite.")
        return field
    }

    /// Vacía el campo y escribe `text` (vacío = solo vaciar). Guardar se toca con el teclado puesto: en una hoja, bajarlo
    /// arrastrando cerraría la hoja (testing.md).
    private func writeLimit(_ field: XCUIElement, _ text: String, app: XCUIApplication) {
        // El número va alineado a la derecha: un toque en el centro deja el cursor a mitad del número y el borrado no lo
        // vacía (medido: «2000» entró en medio de «8,000.00»). Se toca el final.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        let current = (field.value as? String) ?? ""
        if !current.isEmpty && current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))
        }
        XCTAssertTrue(((field.value as? String) ?? "").isEmpty || field.value as? String == field.placeholderValue,
                      "El campo no quedó vacío antes de escribir: «\(field.value as? String ?? "")».")
        if !text.isEmpty { field.typeText(text) }
        app.buttons["toolbar_save_button"].tap()
        // La hoja de la tarjeta sigue en el árbol debajo del formulario: lo que prueba que Guardar llegó es que el
        // formulario se fue (revisor con checklist, `tocar-tras-escribir-en-xcuitest`).
        XCTAssertTrue(app.textFields["account_name_field"].waitForNonExistence(timeout: 8),
                      "Guardar no cerró el formulario.")
        XCTAssertTrue(app.descendants(matching: .any)["hoja_cuenta_estado"].firstMatch.waitForExistence(timeout: 8),
                      "Guardar no volvió a la hoja de la tarjeta.")
    }

    private var lineUsageID: String { "hoja_cuenta_uso_de_linea" }

    // MARK: - Poner, cambiar y borrar el límite

    /// Sin límite la hoja no dice nada de la línea; con 8,000 dice 20 % y lo disponible; con 2,000, 81 %; y al borrarlo
    /// la línea se va.
    func test_ponerCambiarYBorrarElLimite_laHojaEnseñaElUsoSoloConLimite() {
        let app = launch(seed: "tarjeta-limite")
        openSheet(app)
        let usage = app.staticTexts[lineUsageID]
        XCTAssertFalse(usage.exists, "Sin límite la hoja ya enseña el uso de línea.")

        writeLimit(openFormAtLimit(app), "8000", app: app)
        XCTAssertTrue(usage.waitForExistence(timeout: 5), "Con límite la hoja no enseña el uso de línea.")
        // 1,240 + 386.50 = 1,626.50 de 8,000: 20 % usado y 6,373.50 disponibles.
        XCTAssertTrue(usage.label.contains("20"), "No dice el 20 % usado: «\(usage.label)».")
        XCTAssertTrue(usage.label.contains("6,373.50") || usage.label.contains("6.373,50"),
                      "No dice lo disponible: «\(usage.label)».")
        XCTAssertTrue(usage.label.contains("8,000") || usage.label.contains("8.000"),
                      "No dice el límite: «\(usage.label)».")

        let field = openFormAtLimit(app)
        let shown = (field.value as? String) ?? ""
        XCTAssertTrue(shown.contains("8,000") || shown.contains("8.000"),
                      "El formulario no enseña el límite guardado: «\(shown)».")
        writeLimit(field, "2000", app: app)
        // La línea ya existía con el 20 %: se espera a que la etiqueta cambie, no a que exista.
        let eightyOne = expectation(for: NSPredicate(format: "label CONTAINS %@", "81"), evaluatedWith: usage)
        XCTAssertEqual(XCTWaiter.wait(for: [eightyOne], timeout: 5), .completed,
                       "Con 2,000 no dice el 81 % usado: «\(usage.label)».")

        writeLimit(openFormAtLimit(app), "", app: app)
        XCTAssertFalse(usage.waitForExistence(timeout: 2), "Borrar el límite deja el uso de línea en la hoja.")
    }

    /// Un 0 no es un límite: la hoja no dice «sin línea» a quien solo puso un cero.
    func test_limiteCero_noEnseñaUsoDeLinea() {
        let app = launch(seed: "tarjeta-limite")
        openSheet(app)
        writeLimit(openFormAtLimit(app), "0", app: app)
        XCTAssertFalse(app.staticTexts[lineUsageID].waitForExistence(timeout: 2), "Con límite 0 sale el uso de línea.")
        // Guardar el 0 cerró el formulario y el campo vuelve vacío. Que el 0 no se guarde como límite no se ve desde aquí
        // (el campo normaliza al cargar): lo fija `LimiteTarjetaLogicaTests.normalizado_soloGuardaUnLimiteDeVerdad`.
        let field = openFormAtLimit(app)
        let shown = (field.value as? String) ?? ""
        XCTAssertTrue(shown.isEmpty || shown == field.placeholderValue, "El 0 se guardó como límite: «\(shown)».")
    }

    // MARK: - Capturas del antes y el después

    func test_capturas_hojaYFormulario() throws {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["CAPTURAS_DIR"] else { throw XCTSkip("Sin CAPTURAS_DIR: solo para las capturas del cierre.") }
        let prefix = env["CAPTURAS_PREFIJO"] ?? "captura"
        let app = launch(seed: env["CAPTURAS_SEMILLA"] ?? "tarjeta-limite")
        openSheet(app)
        if let limit = env["CAPTURAS_LIMITE"] {
            writeLimit(openFormAtLimit(app), limit, app: app)
        }
        // El estado de cuenta va al pie de la hoja a media altura: se sube hasta ver lo último que pinta.
        let last = app.staticTexts[lineUsageID].exists
            ? app.staticTexts[lineUsageID] : app.descendants(matching: .any)["hoja_cuenta_fechas"].firstMatch
        var lifts = 0
        while lifts < 3 && !(last.exists && app.windows.firstMatch.frame.contains(last.frame)) {
            app.descendants(matching: .any)["hoja_cuenta_monto"].firstMatch.swipeUp(velocity: .slow)
            lifts += 1
        }
        save(app, to: dir, "\(prefix)-hoja")
        app.buttons["account_detail_edit"].tap()
        XCTAssertTrue(app.textFields["account_name_field"].waitForExistence(timeout: 8))
        let footer = app.staticTexts["account_cc_cycle_footer"]
        var swipes = 0
        while swipes < 10 && !(footer.exists && app.windows.firstMatch.frame.contains(footer.frame)) {
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
        app.swipeUp(velocity: .slow)
        save(app, to: dir, "\(prefix)-formulario")
    }

    private func save(_ app: XCUIApplication, to dir: String, _ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        do {
            try shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        } catch {
            XCTFail("No se pudo guardar la captura \(name): \(error)")
        }
    }
}
