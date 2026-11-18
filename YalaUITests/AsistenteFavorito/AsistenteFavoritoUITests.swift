//
//  AsistenteFavoritoUITests.swift
//  YalaUITests
//
//  «Nuevo favorito» por pasos (encargo del 17-nov): el recorrido completo de un gasto y el de una transferencia crean
//  el favorito, «Usar formulario» lleva lo respondido al formulario de siempre, y cerrar con algo respondido pregunta
//  antes de descartar (en el asistente y en el formulario abierto desde él). El caso de capturas recorre cada pantalla
//  y deja una foto por paso (las del artifact), en las variantes de `YALA_CAPTURAS` (tema claro, letra grande).
//

import XCTest

final class AsistenteFavoritoUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Recorridos completos

    func test_recorridoCompleto_gasto_creaElFavorito() {
        let app = abrirAsistente()

        pregunta(app, es: "¿Qué quieres guardar?")
        XCTAssertFalse(app.buttons["asistente_back"].exists, "En la primera pregunta no hay Atrás.")
        XCTAssertTrue(app.buttons["asistente_favorito_tipo_expense"].isSelected, "«Gasto» no llega marcado.")
        siguiente(app)

        pregunta(app, es: "¿En qué categoría va?")
        XCTAssertTrue(app.buttons["asistente_favorito_sin_categoria"].isSelected, "«Sin categoría» no llega marcada.")
        siguiente(app)

        pregunta(app, es: "¿Cómo lo llamamos?")
        let nombre = app.textFields["asistente_favorito_nombre"]
        XCTAssertTrue(nombre.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["asistente_next"].isEnabled, "Sin categoría ni nombre, «Siguiente» va apagado.")
        nombre.tap()
        nombre.typeText("QA Favorito")
        siguiente(app)

        pregunta(app, es: "¿Cuánto pagas normalmente?")
        XCTAssertTrue(app.buttons["asistente_next"].isEnabled, "Vacío vale: el monto se pone al usarlo.")
        let monto = app.textFields["asistente_favorito_monto"]
        XCTAssertTrue(monto.waitForExistence(timeout: 5))
        monto.tap()
        monto.typeText("12")
        siguiente(app)

        pregunta(app, es: "¿Con qué cuenta pagas?")
        app.buttons["asistente_favorito_cuenta_Cuenta Principal"].tap()
        siguiente(app)

        pregunta(app, es: "¿Lo creamos así?")
        XCTAssertTrue(app.buttons["asistente_favorito_resumen_nombre"].label.contains("QA Favorito"))
        XCTAssertTrue(app.buttons["asistente_favorito_resumen_cuenta"].label.contains("Cuenta Principal"))
        XCTAssertEqual(app.buttons["asistente_next"].label, "Crear favorito")
        app.buttons["asistente_next"].tap()

        XCTAssertTrue(app.buttons["favorites_row_QA Favorito"].waitForExistence(timeout: 5),
                      "El favorito creado no apareció en la lista.")
    }

    func test_recorridoCompleto_transferencia_preguntaOrigenYDestino() {
        let app = abrirAsistente()

        pregunta(app, es: "¿Qué quieres guardar?")
        app.buttons["asistente_favorito_tipo_transfer"].tap()
        siguiente(app)

        pregunta(app, es: "¿Cómo lo llamamos?")
        let nombre = app.textFields["asistente_favorito_nombre"]
        XCTAssertTrue(nombre.waitForExistence(timeout: 5))
        XCTAssertEqual(nombre.value as? String, "Transferencia", "El nombre no llega propuesto.")
        siguiente(app)

        pregunta(app, es: "¿Cuánto mueves normalmente?")
        siguiente(app)

        pregunta(app, es: "¿De qué cuenta sale?")
        app.buttons["asistente_favorito_cuenta_Cuenta Principal"].tap()
        siguiente(app)

        pregunta(app, es: "¿A qué cuenta va?")
        XCTAssertFalse(app.buttons["asistente_favorito_destino_Cuenta Principal"].exists,
                       "El destino ofrece la cuenta de origen.")
        XCTAssertTrue(app.buttons["asistente_favorito_destino_Ahorros USD"].isSelected,
                      "El destino no llega sugerido.")
        siguiente(app)

        pregunta(app, es: "¿Lo creamos así?")
        XCTAssertFalse(app.buttons["asistente_favorito_resumen_categoria"].exists, "Una transferencia no lleva categoría.")
        XCTAssertTrue(app.buttons["asistente_favorito_resumen_destino"].label.contains("Ahorros USD"))
        app.buttons["asistente_next"].tap()

        XCTAssertTrue(app.buttons["favorites_row_Transferencia"].waitForExistence(timeout: 5),
                      "El favorito de transferencia no apareció en la lista.")
    }

    // MARK: - «Usar formulario»

    func test_usarFormulario_llevaLoRespondido_yPreguntaAntesDeDescartar() {
        let app = abrirAsistente()
        app.buttons["asistente_favorito_tipo_income"].tap()
        siguiente(app)
        siguiente(app)
        let nombre = app.textFields["asistente_favorito_nombre"]
        XCTAssertTrue(nombre.waitForExistence(timeout: 5))
        nombre.tap()
        nombre.typeText("Sueldo QA")
        siguiente(app)

        app.buttons["asistente_use_form"].tap()
        let campo = app.textFields["favorite_name_field"]
        XCTAssertTrue(campo.waitForExistence(timeout: 5), "«Usar formulario» no abrió el formulario.")
        XCTAssertEqual(campo.value as? String, "Sueldo QA", "El formulario no trae el nombre respondido.")
        XCTAssertTrue(app.buttons["favorite_editor_type_income"].isSelected, "El formulario no trae el tipo respondido.")

        // La X del formulario abierto desde el asistente pregunta antes de tirar lo respondido.
        app.navigationBars["Nuevo favorito"].buttons["Cerrar"].firstMatch.tap()
        let seguir = app.buttons["asistente_discard_keep"].firstMatch
        XCTAssertTrue(seguir.waitForExistence(timeout: 5), "Cerrar el formulario con respuestas no preguntó.")
        seguir.tap()
        XCTAssertTrue(campo.waitForExistence(timeout: 5), "«Seguir» cerró el formulario.")
    }

    func test_usarFormulario_sinRespuestas_abreElFormularioVacio() {
        let app = abrirAsistente()
        app.buttons["asistente_use_form"].tap()
        let campo = app.textFields["favorite_name_field"]
        XCTAssertTrue(campo.waitForExistence(timeout: 5), "«Usar formulario» no abrió el formulario.")
        XCTAssertTrue((campo.value as? String ?? "").isEmpty || campo.value as? String == campo.placeholderValue,
                      "El formulario sin respuestas no llega vacío.")
    }

    func test_cerrarConRespuestas_preguntaAntes_yDescartarCierra() {
        let app = abrirAsistente()
        siguiente(app)
        app.buttons["asistente_close"].tap()
        let descartar = app.buttons["asistente_discard_confirm"].firstMatch
        XCTAssertTrue(descartar.waitForExistence(timeout: 5), "Cerrar con una respuesta no preguntó.")
        descartar.tap()
        XCTAssertTrue(app.buttons["favorites_add_button"].waitForExistence(timeout: 5), "«Descartar» no cerró la hoja.")
        XCTAssertFalse(app.staticTexts["asistente_question"].exists)

        // Lo descartado no vuelve al abrir otra vez.
        app.buttons["favorites_add_button"].tap()
        pregunta(app, es: "¿Qué quieres guardar?")
        XCTAssertFalse(app.buttons["asistente_back"].exists, "Al volver a abrir no empezó de cero.")
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
        siguiente(app)
        adjuntar(app, "\(prefijo)-2-categoria")
        siguiente(app)
        let nombre = app.textFields["asistente_favorito_nombre"]
        XCTAssertTrue(nombre.waitForExistence(timeout: 5))
        nombre.tap()
        nombre.typeText("Café")
        adjuntar(app, "\(prefijo)-3-nombre")
        siguiente(app)
        let monto = app.textFields["asistente_favorito_monto"]
        XCTAssertTrue(monto.waitForExistence(timeout: 5))
        monto.tap()
        monto.typeText("8.50")
        adjuntar(app, "\(prefijo)-4-monto")
        cerrarTeclado(app)
        siguiente(app)
        adjuntar(app, "\(prefijo)-5-cuenta")
        siguiente(app)
        adjuntar(app, "\(prefijo)-6-resumen")
        app.buttons["asistente_use_form"].tap()
        XCTAssertTrue(app.textFields["favorite_name_field"].waitForExistence(timeout: 5))
        cerrarTeclado(app)
        adjuntar(app, "\(prefijo)-7-formulario")
        app.terminate()
    }

    // MARK: - Ayudas

    private func abrirAsistente(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "formulario", extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()
        app.openSettingsSection("profile_favorites")
        let crear = app.buttons["favorites_add_button"]
        XCTAssertTrue(crear.waitForExistence(timeout: 15), "No apareció el «+» de Favoritos.")
        crear.tap()
        XCTAssertTrue(app.staticTexts["asistente_question"].waitForExistence(timeout: 5),
                      "«Nuevo favorito» no abrió el asistente.")
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

    /// Para la foto sin teclado: la barra de abajo deja ver el scroll.
    private func cerrarTeclado(_ app: XCUIApplication) {
        guard app.keyboards.count > 0 else { return }
        let pregunta = app.staticTexts["asistente_question"]
        if pregunta.exists { pregunta.tap() } else { app.navigationBars.firstMatch.staticTexts.firstMatch.tap() }
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
    /// El «+» de Favoritos abre el asistente; los casos que prueban el FORMULARIO de crear pasan por «Usar formulario»
    /// (encargo del 17-nov). Toca el «+» y deja el formulario delante.
    func abrirFormularioDeNuevoFavorito(file: StaticString = #filePath, line: UInt = #line) {
        let crear = buttons["favorites_add_button"]
        XCTAssertTrue(crear.waitForExistence(timeout: 15), "No apareció el «+» de Favoritos.", file: file, line: line)
        crear.tap()
        let usarFormulario = buttons["asistente_use_form"]
        XCTAssertTrue(usarFormulario.waitForExistence(timeout: 10), "No se abrió el asistente.", file: file, line: line)
        usarFormulario.tap()
    }
}

