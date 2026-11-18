//
//  AsistenteCuentaUITests.swift
//  YalaUITests
//
//  «Nueva cuenta» por pasos (encargo del 18-nov): el recorrido completo de una tarjeta crea la cuenta, «Usar formulario»
//  lleva lo respondido al formulario de siempre, y cerrar con algo respondido pregunta antes de descartar. El caso de
//  capturas recorre cada pantalla y deja una foto por paso (las del artifact), en las variantes de `YALA_CAPTURAS`
//  (tema claro, letra grande).
//

import XCTest

final class AsistenteCuentaUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Recorrido completo

    func test_recorridoCompleto_deUnaTarjeta_creaLaCuenta() {
        let app = abrirAsistente()

        pregunta(app, es: "¿Qué tipo de cuenta es?")
        XCTAssertTrue(app.buttons["asistente_cuenta_tipo_checking"].isSelected,
                      "«Cuenta corriente» no llega marcada: «Siguiente» tiene que servir con lo sugerido.")
        XCTAssertFalse(app.buttons["asistente_back"].exists, "En la primera pregunta no hay Atrás.")
        app.buttons["asistente_cuenta_tipo_creditCard"].tap()
        siguiente(app)

        pregunta(app, es: "¿En qué moneda usas esta tarjeta?")
        XCTAssertTrue(app.buttons["asistente_cuenta_moneda_otra"].exists, "Falta «Otra moneda».")
        let marcada = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'asistente_cuenta_moneda_' AND selected == true"))
        XCTAssertEqual(marcada.count, 1, "La moneda principal no llega marcada.")
        siguiente(app)

        pregunta(app, es: "¿Cómo la llamamos?")
        let nombre = app.textFields["asistente_cuenta_nombre"]
        XCTAssertTrue(nombre.waitForExistence(timeout: 5))
        XCTAssertFalse((nombre.value as? String ?? "").isEmpty, "El nombre no llega propuesto.")
        nombre.tap()
        nombre.clearAndType("Cuenta Principal")
        XCTAssertTrue(app.descendants(matching: .any)["asistente_cuenta_nombre_repetido"].waitForExistence(timeout: 5),
                      "Un nombre que ya existe no avisa.")
        XCTAssertFalse(app.buttons["asistente_next"].isEnabled, "Con un nombre repetido, «Siguiente» va apagado.")
        nombre.clearAndType("Visa QA")
        siguiente(app)

        pregunta(app, es: "¿Cuánto debes hoy en esta tarjeta?")
        XCTAssertFalse(app.buttons["asistente_cuenta_signo"].exists, "En tarjeta no hay signo: lo escrito es deuda.")
        let saldo = app.textFields["asistente_cuenta_saldo"]
        XCTAssertTrue(saldo.waitForExistence(timeout: 5))
        saldo.tap()
        saldo.typeText("250")
        siguiente(app)

        pregunta(app, es: "¿Qué día cierra tu tarjeta?")
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "Día 20")
        siguiente(app)

        pregunta(app, es: "¿Hasta qué día puedes pagarla?")
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "Día 5")
        siguiente(app)

        pregunta(app, es: "¿Cuándo te recordamos pagarla?")
        app.buttons["asistente_cuenta_recordatorio_3"].tap()
        siguiente(app)

        pregunta(app, es: "¿La creamos así?")
        XCTAssertTrue(app.buttons["asistente_cuenta_resumen_nombre"].label.contains("Visa QA"))
        XCTAssertTrue(app.buttons["asistente_cuenta_resumen_cierre"].label.contains("20"))
        XCTAssertTrue(app.buttons["asistente_cuenta_resumen_pago"].label.contains("5"))

        // Cambiar una respuesta desde el resumen vuelve al resumen con «Siguiente».
        app.buttons["asistente_cuenta_resumen_tipo"].tap()
        pregunta(app, es: "¿Qué tipo de cuenta es?")
        siguiente(app)
        pregunta(app, es: "¿La creamos así?")

        let crear = app.buttons["asistente_next"]
        XCTAssertEqual(crear.label, "Crear cuenta")
        crear.tap()

        let fila = app.buttons["accounts_row_Visa QA"]
        XCTAssertTrue(fila.waitForExistence(timeout: 10), "La cuenta creada no aparece en la lista.")
        XCTAssertFalse(app.buttons["asistente_next"].exists, "La hoja del asistente sigue abierta tras crear.")
        XCTAssertTrue(fila.label.contains("250"), "La deuda no quedó como saldo de la tarjeta: «\(fila.label)».")
    }

    // MARK: - «Usar formulario»

    func test_usarFormulario_llevaLoRespondido_yPreguntaAntesDeDescartar() {
        let app = abrirAsistente()
        XCTAssertTrue(app.buttons["asistente_use_form"].exists, "«Usar formulario» no está arriba en la primera pregunta.")
        app.buttons["asistente_cuenta_tipo_cash"].tap()
        siguiente(app)                                   // Efectivo
        siguiente(app)                                   // la moneda principal
        let nombre = app.textFields["asistente_cuenta_nombre"]
        XCTAssertTrue(nombre.waitForExistence(timeout: 5))
        nombre.tap()
        nombre.clearAndType("Caja QA")
        XCTAssertTrue(app.buttons["asistente_use_form"].exists, "«Usar formulario» desapareció a mitad del asistente.")
        app.buttons["asistente_use_form"].tap()

        let campo = app.textFields["account_name_field"]
        XCTAssertTrue(campo.waitForExistence(timeout: 5), "«Usar formulario» no abrió el formulario.")
        XCTAssertEqual(campo.value as? String, "Caja QA", "El nombre no pasó al formulario.")
        XCTAssertTrue(app.buttons["account_type_chip_cash"].isSelected, "El tipo no pasó al formulario.")
        adjuntar(app, "formulario-con-lo-respondido")

        // Con lo respondido, la X del formulario pregunta.
        app.buttons["xmark"].firstMatch.tap()
        let seguir = app.buttons["account_discard_keep"].firstMatch
        XCTAssertTrue(seguir.waitForExistence(timeout: 5), "La X del formulario tiró lo respondido sin preguntar.")
        seguir.tap()
        XCTAssertTrue(campo.exists, "«Seguir editando» cerró el formulario.")
    }

    // MARK: - Descartar

    func test_cerrarConRespuestas_preguntaAntes() {
        let app = abrirAsistente()
        // Sin nada respondido, la X cierra directo.
        app.buttons["asistente_close"].tap()
        XCTAssertTrue(app.buttons["accounts_add_button"].waitForHittable(timeout: 5))
        XCTAssertFalse(app.buttons["asistente_discard_confirm"].exists)

        app.buttons["accounts_add_button"].tap()
        pregunta(app, es: "¿Qué tipo de cuenta es?")
        siguiente(app)
        app.buttons["asistente_close"].tap()
        let seguir = app.buttons["asistente_discard_keep"].firstMatch
        XCTAssertTrue(seguir.waitForExistence(timeout: 5), "Con algo respondido, la X no preguntó.")
        seguir.tap()
        pregunta(app, es: "¿En qué moneda está este dinero?")

        // Atrás vuelve a la pregunta anterior con lo elegido.
        app.buttons["asistente_back"].tap()
        pregunta(app, es: "¿Qué tipo de cuenta es?")

        app.buttons["asistente_close"].tap()
        let descartar = app.buttons["asistente_discard_confirm"].firstMatch
        XCTAssertTrue(descartar.waitForExistence(timeout: 5))
        descartar.tap()
        XCTAssertTrue(app.buttons["accounts_add_button"].waitForHittable(timeout: 5), "Descartar no cerró la hoja.")
        XCTAssertFalse(app.buttons["accounts_row_Cuenta corriente"].exists, "Descartar creó la cuenta propuesta.")
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
        adjuntar(app, "\(prefijo)-1-tipo")
        // Con letra grande «Tarjeta de crédito» queda bajo la barra de abajo y el toque caería en «Siguiente»
        // (`testing.md`, `isHittable` bajo una `.safeAreaBar`): esa variante recorre una cuenta corriente.
        let tarjeta = !prefijo.hasPrefix("letra")
        if tarjeta { app.buttons["asistente_cuenta_tipo_creditCard"].tap() }
        siguiente(app)
        adjuntar(app, "\(prefijo)-2-moneda")
        siguiente(app)
        adjuntar(app, "\(prefijo)-3-nombre")
        siguiente(app)
        let saldo = app.textFields["asistente_cuenta_saldo"]
        XCTAssertTrue(saldo.waitForExistence(timeout: 5))
        saldo.tap()
        saldo.typeText("1250")
        adjuntar(app, "\(prefijo)-4-saldo")
        siguiente(app)
        if tarjeta {
            app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "Día 20")
            adjuntar(app, "\(prefijo)-5-cierre")
            siguiente(app)
            app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "Día 5")
            adjuntar(app, "\(prefijo)-6-pago")
            siguiente(app)
            adjuntar(app, "\(prefijo)-7-recordatorio")
            siguiente(app)
        }
        adjuntar(app, "\(prefijo)-8-resumen")
        app.buttons["asistente_use_form"].tap()
        XCTAssertTrue(app.textFields["account_name_field"].waitForExistence(timeout: 5))
        adjuntar(app, "\(prefijo)-9-formulario")
        app.terminate()
    }

    // MARK: - Ayudas

    private func abrirAsistente(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()
        app.openSettingsSection("profile_accounts")
        let crear = app.buttons["accounts_add_button"]
        XCTAssertTrue(crear.waitForExistence(timeout: 15), "No apareció «Añadir» en Cuentas.")
        crear.tap()
        XCTAssertTrue(app.staticTexts["asistente_question"].waitForExistence(timeout: 5),
                      "«Nueva cuenta» no abrió el asistente.")
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
    /// «Nueva cuenta» abre el asistente; los casos que prueban el FORMULARIO de crear pasan por «Usar formulario»
    /// (encargo del 18-nov). Se llama justo después de tocar el «+» y deja el formulario delante.
    func pasarAlFormularioDeNuevaCuenta(file: StaticString = #filePath, line: UInt = #line) {
        let usarFormulario = buttons["asistente_use_form"]
        XCTAssertTrue(usarFormulario.waitForExistence(timeout: 10), "No se abrió el asistente de cuenta.",
                      file: file, line: line)
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
