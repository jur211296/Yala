//
//  AsistentePagoPlanificadoUITests.swift
//  YalaUITests
//
//  «Nuevo pago planificado» por pasos (encargo del 17-nov): el recorrido completo crea el pago, «Usar formulario» lleva
//  lo respondido al formulario de siempre, y cerrar con algo respondido pregunta antes de descartar (en el asistente y
//  en el formulario abierto desde él). El caso de capturas recorre cada pantalla y deja una foto por paso (las del
//  artifact), en las variantes de `YALA_CAPTURAS` (tema claro, letra grande).
//

import XCTest

final class AsistentePagoPlanificadoUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Recorrido completo

    func test_recorridoCompleto_creaElPago() {
        let app = abrirAsistente()

        pregunta(app, es: "¿Qué pagas cada cierto tiempo?")
        XCTAssertFalse(app.buttons["asistente_back"].exists, "En la primera pregunta no hay Atrás.")
        XCTAssertFalse(app.buttons["asistente_next"].isEnabled, "Sin tipo elegido, «Siguiente» va apagado.")
        app.buttons["asistente_pago_tipo_utilities"].tap()
        siguiente(app)

        pregunta(app, es: "¿Cómo lo llamamos?")
        let nombre = app.textFields["asistente_pago_nombre"]
        XCTAssertTrue(nombre.waitForExistence(timeout: 5))
        XCTAssertFalse((nombre.value as? String ?? "").isEmpty, "El nombre no llega propuesto por el tipo.")
        nombre.tap()
        nombre.clearAndType("Luz QA")
        siguiente(app)

        pregunta(app, es: "¿Cuánto pagas cada vez?")
        let monto = app.textFields["asistente_pago_monto"]
        XCTAssertTrue(monto.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["asistente_next"].isEnabled, "Sin monto, «Siguiente» va apagado.")
        monto.tap()
        monto.typeText("85")
        siguiente(app)

        pregunta(app, es: "¿Cada cuánto toca pagar?")
        XCTAssertTrue(app.buttons["asistente_pago_frecuencia_monthly"].isSelected, "«Cada mes» no llega marcado.")
        siguiente(app)

        pregunta(app, es: "¿Qué día del mes toca?")
        siguiente(app)

        pregunta(app, es: "¿Te avisamos antes de que toque pagar?")
        XCTAssertTrue(app.buttons["asistente_pago_aviso_threeDaysBefore"].isSelected, "«3 días antes» no llega marcado.")
        app.buttons["asistente_pago_aviso_oneDayBefore"].tap()
        siguiente(app)

        pregunta(app, es: "¿Lo creamos así?")
        XCTAssertTrue(app.buttons["asistente_pago_resumen_nombre"].label.contains("Luz QA"))
        XCTAssertTrue(app.buttons["asistente_pago_resumen_aviso"].label.contains("1 día"))

        // Cambiar una respuesta desde el resumen vuelve al resumen con «Siguiente».
        app.buttons["asistente_pago_resumen_frecuencia"].tap()
        pregunta(app, es: "¿Cada cuánto toca pagar?")
        siguiente(app)
        pregunta(app, es: "¿Lo creamos así?")

        let crear = app.buttons["asistente_next"]
        XCTAssertEqual(crear.label, "Crear pago")
        crear.tap()

        let fila = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label BEGINSWITH %@",
                                                    "scheduled_payment_row", "Luz QA")).firstMatch
        XCTAssertTrue(fila.waitForExistence(timeout: 10), "El pago creado no aparece en la lista.")
        XCTAssertFalse(app.buttons["asistente_next"].exists, "La hoja del asistente sigue abierta tras crear.")
    }

    // MARK: - «Usar formulario»

    func test_usarFormulario_llevaLoRespondido() {
        let app = abrirAsistente()
        XCTAssertTrue(app.buttons["asistente_use_form"].exists, "«Usar formulario» no está arriba en la primera pregunta.")
        app.buttons["asistente_pago_tipo_rent"].tap()
        siguiente(app)
        let nombre = app.textFields["asistente_pago_nombre"]
        XCTAssertTrue(nombre.waitForExistence(timeout: 5))
        nombre.tap()
        nombre.clearAndType("Depa QA")
        siguiente(app)
        let monto = app.textFields["asistente_pago_monto"]
        XCTAssertTrue(monto.waitForExistence(timeout: 5))
        monto.tap()
        monto.typeText("1200")
        XCTAssertTrue(app.buttons["asistente_use_form"].exists, "«Usar formulario» desapareció a mitad del asistente.")
        app.buttons["asistente_use_form"].tap()

        let campoNombre = app.textFields["scheduled_name_field"]
        XCTAssertTrue(campoNombre.waitForExistence(timeout: 5), "«Usar formulario» no abrió el formulario.")
        XCTAssertEqual(campoNombre.value as? String, "Depa QA", "El nombre no pasó al formulario.")
        let campoMonto = app.textFields["scheduled_amount_field"]
        XCTAssertTrue((campoMonto.value as? String ?? "").hasPrefix("1"),
                      "El monto no pasó al formulario: \(campoMonto.value ?? "")")
        XCTAssertFalse(app.buttons["scheduled_subcategory_row"].label.contains("Seleccionar"),
                       "El tipo no pasó al formulario: \(app.buttons["scheduled_subcategory_row"].label)")
        adjuntar(app, "formulario-con-lo-respondido")

        // Con lo respondido, la X del formulario pregunta.
        app.buttons["xmark"].firstMatch.tap()
        let seguir = app.buttons["asistente_discard_keep"].firstMatch
        XCTAssertTrue(seguir.waitForExistence(timeout: 5), "La X del formulario tiró lo respondido sin preguntar.")
        seguir.tap()
        XCTAssertTrue(campoNombre.exists, "«Seguir» cerró el formulario.")
    }

    /// Sin nada respondido, «Usar formulario» abre el formulario de siempre: vacío y con su X de siempre.
    func test_usarFormulario_sinRespuestas_abreElFormularioVacio() {
        let app = abrirAsistente()
        app.buttons["asistente_use_form"].tap()
        let campoNombre = app.textFields["scheduled_name_field"]
        XCTAssertTrue(campoNombre.waitForExistence(timeout: 5), "«Usar formulario» no abrió el formulario.")
        XCTAssertTrue((campoNombre.value as? String ?? "").isEmpty || campoNombre.value as? String == "Nombre del pago")
        app.buttons["xmark"].firstMatch.tap()
        XCTAssertTrue(app.buttons["scheduled_payments_create_button"].waitForHittable(timeout: 5),
                      "La X del formulario vacío no cerró directo.")
    }

    // MARK: - Descartar

    func test_cerrarConRespuestas_preguntaAntes() {
        let app = abrirAsistente()
        // Sin nada respondido, la X cierra directo.
        app.buttons["asistente_close"].tap()
        XCTAssertTrue(app.buttons["scheduled_payments_create_button"].waitForHittable(timeout: 5))
        XCTAssertFalse(app.buttons["asistente_discard_confirm"].exists)

        app.buttons["scheduled_payments_create_button"].tap()
        pregunta(app, es: "¿Qué pagas cada cierto tiempo?")
        app.buttons["asistente_pago_tipo_phone"].tap()
        siguiente(app)
        app.buttons["asistente_close"].tap()
        let seguir = app.buttons["asistente_discard_keep"].firstMatch
        XCTAssertTrue(seguir.waitForExistence(timeout: 5), "Con algo respondido, la X no preguntó.")
        seguir.tap()
        pregunta(app, es: "¿Cómo lo llamamos?")

        // Atrás vuelve a la pregunta anterior con lo elegido.
        app.buttons["asistente_back"].tap()
        pregunta(app, es: "¿Qué pagas cada cierto tiempo?")
        XCTAssertTrue(app.buttons["asistente_pago_tipo_phone"].isSelected, "Atrás perdió el tipo elegido.")

        app.buttons["asistente_close"].tap()
        let descartar = app.buttons["asistente_discard_confirm"].firstMatch
        XCTAssertTrue(descartar.waitForExistence(timeout: 5))
        descartar.tap()
        XCTAssertTrue(app.buttons["scheduled_payments_create_button"].waitForHittable(timeout: 5),
                      "Descartar no cerró la hoja.")

        // Al volver a abrir, empieza de cero.
        app.buttons["scheduled_payments_create_button"].tap()
        pregunta(app, es: "¿Qué pagas cada cierto tiempo?")
        XCTAssertFalse(app.buttons["asistente_pago_tipo_phone"].isSelected, "Lo descartado volvió al abrir otra vez.")
    }

    // MARK: - Capturas

    /// Una foto por pantalla. `YALA_CAPTURAS` (en el runner, `TEST_RUNNER_YALA_CAPTURAS`) lista las variantes
    /// separadas por `|`, cada una `nombre:argumentos` («claro:-userTheme 1»); sin ella, solo la de siempre.
    func test_capturas_cadaPaso() {
        let variantes = (ProcessInfo.processInfo.environment["YALA_CAPTURAS"] ?? "base:")
            .split(separator: "|").map(String.init)
        for variante in variantes {
            let partes = variante.split(separator: ":", maxSplits: 1).map(String.init)
            let nombre = partes.first ?? "base"
            let extra = partes.count > 1 ? partes[1].split(separator: " ").map(String.init) : []
            recorrerConCapturas(prefijo: nombre, extra: extra)
        }
    }

    private func recorrerConCapturas(prefijo: String, extra: [String]) {
        let app = abrirAsistente(extra: extra)
        adjuntar(app, "\(prefijo)-0-vacio")
        app.buttons["asistente_pago_tipo_utilities"].tap()
        adjuntar(app, "\(prefijo)-1-tipo")
        siguiente(app)
        adjuntar(app, "\(prefijo)-2-nombre")
        siguiente(app)
        let monto = app.textFields["asistente_pago_monto"]
        XCTAssertTrue(monto.waitForExistence(timeout: 5))
        monto.tap()
        monto.typeText("85")
        adjuntar(app, "\(prefijo)-3-monto")
        cerrarTeclado(app)
        siguiente(app)
        adjuntar(app, "\(prefijo)-4-frecuencia")
        siguiente(app)
        adjuntar(app, "\(prefijo)-5-dia")
        siguiente(app)
        adjuntar(app, "\(prefijo)-6-aviso")
        siguiente(app)
        adjuntar(app, "\(prefijo)-7-resumen")
        app.buttons["asistente_use_form"].tap()
        XCTAssertTrue(app.textFields["scheduled_name_field"].waitForExistence(timeout: 5))
        adjuntar(app, "\(prefijo)-8-formulario")
        app.terminate()
    }

    // MARK: - Ayudas

    private func abrirAsistente(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: "scheduledPayments", extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        let crear = app.buttons["scheduled_payments_create_button"]
        XCTAssertTrue(crear.waitForExistence(timeout: 15), "No apareció «Nuevo pago planificado».")
        crear.tap()
        XCTAssertTrue(app.staticTexts["asistente_question"].waitForExistence(timeout: 5),
                      "«Nuevo pago planificado» no abrió el asistente.")
        return app
    }

    private func pregunta(_ app: XCUIApplication, es texto: String, file: StaticString = #filePath, line: UInt = #line) {
        let titulo = app.staticTexts["asistente_question"]
        let predicado = NSPredicate(format: "label == %@", texto)
        let espera = expectation(for: predicado, evaluatedWith: titulo)
        let resultado = XCTWaiter.wait(for: [espera], timeout: 5)
        XCTAssertEqual(resultado, .completed, "Se esperaba «\(texto)» y se ve «\(titulo.label)».", file: file, line: line)
    }

    private func siguiente(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let boton = app.buttons["asistente_next"]
        XCTAssertTrue(boton.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(boton.isEnabled, "«Siguiente» apagado.", file: file, line: line)
        boton.tap()
    }

    /// Para la foto sin teclado: el teclado numérico no tiene Intro, y la barra de abajo deja ver el scroll.
    private func cerrarTeclado(_ app: XCUIApplication) {
        guard app.keyboards.count > 0 else { return }
        app.staticTexts["asistente_question"].tap()
        _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 3)
    }

    private func adjuntar(_ app: XCUIApplication, _ nombre: String) {
        // La pregunta nueva entra fundiéndose (~0,3 s): la foto, ya quieta.
        Thread.sleep(forTimeInterval: 0.45)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = nombre
        shot.lifetime = .keepAlways
        add(shot)
    }
}

// MARK: - Para los casos que prueban el formulario de crear

extension XCUIApplication {
    /// «Nuevo pago planificado» abre el asistente; los casos que prueban el FORMULARIO de crear pasan por «Usar
    /// formulario» (encargo del 17-nov). Toca el botón de arriba (o el que se pase) y deja el formulario delante.
    func abrirFormularioDeNuevoPago(desde boton: XCUIElement? = nil, file: StaticString = #filePath, line: UInt = #line) {
        let crear = boton ?? buttons["scheduled_payments_create_button"]
        XCTAssertTrue(crear.waitForExistence(timeout: 15), "No apareció «Nuevo pago planificado».", file: file, line: line)
        crear.tap()
        let usarFormulario = buttons["asistente_use_form"]
        XCTAssertTrue(usarFormulario.waitForExistence(timeout: 10), "No se abrió el asistente.", file: file, line: line)
        usarFormulario.tap()
    }
}

private extension XCUIElement {
    func clearAndType(_ texto: String) {
        guard let actual = value as? String, !actual.isEmpty else {
            typeText(texto)
            return
        }
        let borrar = String(repeating: XCUIKeyboardKey.delete.rawValue, count: actual.count)
        typeText(borrar + texto)
    }
}
