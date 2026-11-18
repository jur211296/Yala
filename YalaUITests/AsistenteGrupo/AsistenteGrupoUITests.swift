//
//  AsistenteGrupoUITests.swift
//  YalaUITests
//
//  «Nuevo grupo» por pasos (encargo del 17-nov): el recorrido completo llega hasta «Crear grupo» (y lo intenta: sin red
//  en el simulador el canal falla y el asistente se queda con lo respondido), «Usar formulario» lleva lo respondido al
//  formulario de siempre, y cerrar con algo respondido pregunta antes de descartar, también desde el formulario. El caso
//  de capturas deja una foto por paso (las del artifact) en las variantes de `YALA_CAPTURAS` (tema claro, letra grande).
//
//  Sin teclear: el nombre sale de una idea («Viaje», «Casa»), así ningún toque se pierde con el teclado entrando
//  (`testing.md`, «Tocar algo justo después de `typeText`»).
//

import XCTest

final class AsistenteGrupoUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Recorrido completo

    func test_recorridoCompleto_hastaCrearGrupo() {
        let app = abrirAsistente()

        pregunta(app, es: "¿Cómo se llama el grupo?")
        XCTAssertFalse(app.buttons["asistente_back"].exists, "En la primera pregunta no hay Atrás.")
        XCTAssertFalse(app.buttons["asistente_next"].isEnabled, "Sin nombre, «Siguiente» va apagado.")
        XCTAssertTrue(app.buttons["group_import_entry"].exists, "Falta «Traer un grupo de Splitwise o Tricount».")
        app.buttons["asistente_grupo_idea_viaje"].tap()
        XCTAssertEqual(app.textFields["asistente_grupo_nombre"].value as? String, "Viaje",
                       "La idea no escribió el nombre.")
        siguiente(app)

        pregunta(app, es: "¿Con qué icono lo reconoces?")
        XCTAssertTrue(app.buttons["asistente_grupo_icono_2"].isSelected,
                      "La idea «Viaje» no dejó marcado su icono (el avión, segundo de la rejilla).")
        app.buttons["asistente_grupo_icono_9"].tap()
        siguiente(app)

        pregunta(app, es: "¿Cómo suelen dividir los gastos?")
        XCTAssertTrue(app.buttons["asistente_grupo_reparto_equal"].isSelected, "«Partes iguales» no llega marcado.")
        app.buttons["asistente_grupo_reparto_shares"].tap()
        siguiente(app)

        pregunta(app, es: "¿Juntamos las deudas para que haya menos pagos?")
        XCTAssertTrue(app.buttons["asistente_grupo_deudas_si"].isSelected, "«Sí, menos pagos» no llega marcado.")
        app.buttons["asistente_grupo_deudas_no"].tap()
        siguiente(app)

        pregunta(app, es: "¿Cómo ven lo que se deben?")
        XCTAssertTrue(app.buttons["asistente_grupo_moneda_cada"].isSelected, "«Cada gasto en su moneda» no llega marcado.")
        XCTAssertFalse(app.buttons["asistente_grupo_moneda_elegir"].exists, "La moneda sale sin pedir una sola.")
        app.buttons["asistente_grupo_moneda_una"].tap()
        XCTAssertTrue(app.buttons["asistente_grupo_moneda_elegir"].waitForExistence(timeout: 5),
                      "«Todo en una sola moneda» no enseña cuál.")
        siguiente(app)

        pregunta(app, es: "¿Lo creamos así?")
        XCTAssertTrue(fila(app, "reparto").label.contains("Proporciones"), "El resumen no dice cómo dividen.")
        XCTAssertTrue(fila(app, "deudas").label.contains("No, cada deuda aparte"), "El resumen no dice lo de las deudas.")
        XCTAssertTrue(fila(app, "nombre").label.contains("Viaje"), "El resumen no dice el nombre.")

        // Cambiar una respuesta desde el resumen y volver a él con «Siguiente».
        fila(app, "reparto").tap()
        pregunta(app, es: "¿Cómo suelen dividir los gastos?")
        app.buttons["asistente_grupo_reparto_percentage"].tap()
        siguiente(app)
        pregunta(app, es: "¿Lo creamos así?")
        XCTAssertTrue(fila(app, "reparto").label.contains("Porcentaje"), "El cambio no llegó al resumen.")

        // Atrás desde el resumen vuelve a la que se acaba de cambiar; desde ahí se sigue en orden, con lo respondido.
        app.buttons["asistente_back"].tap()
        pregunta(app, es: "¿Cómo suelen dividir los gastos?")
        XCTAssertTrue(app.buttons["asistente_grupo_reparto_percentage"].isSelected, "Atrás perdió la respuesta.")
        siguiente(app)
        pregunta(app, es: "¿Juntamos las deudas para que haya menos pagos?")
        XCTAssertTrue(app.buttons["asistente_grupo_deudas_no"].isSelected, "Atrás perdió la respuesta de las deudas.")
        siguiente(app)
        pregunta(app, es: "¿Cómo ven lo que se deben?")
        siguiente(app)
        pregunta(app, es: "¿Lo creamos así?")

        // El último gesto: «Crear grupo». En el simulador no hay sesión real, así que el canal falla: el asistente
        // tiene que decirlo y quedarse con lo respondido, no cerrarse en silencio.
        let crear = app.buttons["asistente_next"]
        XCTAssertEqual(crear.label, "Crear grupo", "El botón del resumen no dice «Crear grupo».")
        crear.tap()
        let aviso = app.alerts.firstMatch
        XCTAssertTrue(aviso.waitForExistence(timeout: 20), "Crear sin canal no avisó de nada.")
        aviso.buttons.firstMatch.tap()
        pregunta(app, es: "¿Lo creamos así?")
    }

    // MARK: - «Usar formulario»

    func test_usarFormulario_llevaLoRespondido_yPreguntaAntesDeDescartar() {
        let app = abrirAsistente()
        app.buttons["asistente_grupo_idea_casa"].tap()
        siguiente(app)
        siguiente(app)
        pregunta(app, es: "¿Cómo suelen dividir los gastos?")
        app.buttons["asistente_grupo_reparto_exact"].tap()   // elegido, sin tocar «Siguiente»

        app.buttons["asistente_use_form"].tap()
        let nombre = app.textFields["group_form_name_input"]
        XCTAssertTrue(nombre.waitForExistence(timeout: 10), "«Usar formulario» no abrió el formulario de grupo.")
        XCTAssertEqual(nombre.value as? String, "Casa", "El formulario no trae el nombre respondido.")
        XCTAssertTrue(app.switches["group_form_simplify_toggle"].waitForExistence(timeout: 5),
                      "Con una opción cambiada, «Más opciones» tiene que llegar desplegada.")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Monto exacto")).firstMatch.exists
                        || app.staticTexts["Monto exacto"].exists,
                      "El formulario no trae cómo dividen («Monto exacto»).")

        // Con lo respondido, la X pregunta. «Seguir editando» se queda; «Descartar» cierra.
        app.buttons["group_form_close"].tap()
        let seguir = app.buttons["group_form_discard_keep"].firstMatch
        XCTAssertTrue(seguir.waitForExistence(timeout: 5), "Cerrar el formulario con lo respondido no preguntó.")
        seguir.tap()
        XCTAssertTrue(nombre.waitForExistence(timeout: 5), "«Seguir editando» cerró el formulario.")
        app.buttons["group_form_close"].tap()
        let descartar = app.buttons["group_form_discard_confirm"].firstMatch
        XCTAssertTrue(descartar.waitForExistence(timeout: 5))
        descartar.tap()
        XCTAssertTrue(nombre.waitForNonExistence(timeout: 5), "«Descartar» no cerró el formulario.")
    }

    func test_usarFormulario_sinNada_abreElFormularioVacio_queCierraSinPreguntar() {
        let app = abrirAsistente()
        app.buttons["asistente_use_form"].tap()
        let nombre = app.textFields["group_form_name_input"]
        XCTAssertTrue(nombre.waitForExistence(timeout: 10), "«Usar formulario» no abrió el formulario de grupo.")
        XCTAssertEqual(nombre.placeholderValue, "Ej.: Viaje a Cusco")
        app.buttons["group_form_close"].tap()
        XCTAssertTrue(nombre.waitForNonExistence(timeout: 5), "El formulario vacío preguntó o no se cerró.")
    }

    // MARK: - Cerrar

    func test_cerrar_conElNombreElegido_pregunta_ySinNada_cierraDirecto() {
        let app = abrirAsistente()
        app.buttons["asistente_close"].tap()
        XCTAssertTrue(app.staticTexts["asistente_question"].waitForNonExistence(timeout: 5),
                      "Sin nada respondido, la X tiene que cerrar sin preguntar.")

        abrirDeNuevo(app)
        app.buttons["asistente_grupo_idea_amigos"].tap()   // un nombre, sin tocar «Siguiente»
        app.buttons["asistente_close"].tap()
        let seguir = app.buttons["asistente_discard_keep"].firstMatch
        XCTAssertTrue(seguir.waitForExistence(timeout: 5), "Con el nombre elegido, la X no preguntó.")
        seguir.tap()
        pregunta(app, es: "¿Cómo se llama el grupo?")
        app.buttons["asistente_close"].tap()
        let descartar = app.buttons["asistente_discard_confirm"].firstMatch
        XCTAssertTrue(descartar.waitForExistence(timeout: 5))
        descartar.tap()
        XCTAssertTrue(app.staticTexts["asistente_question"].waitForNonExistence(timeout: 5), "«Descartar» no cerró.")

        // Volver a abrir arranca de cero.
        abrirDeNuevo(app)
        XCTAssertNotEqual(app.textFields["asistente_grupo_nombre"].value as? String, "Amigos",
                          "El asistente se abrió con lo de la vez anterior.")
        XCTAssertFalse(app.buttons["asistente_next"].isEnabled)
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
        adjuntar(app, "\(prefijo)-1-nombre-vacio")
        // Con letra grande en un SE las ideas quedan bajo la barra de abajo y el toque caería en «Siguiente»
        // (`testing.md`, `isHittable` bajo una `.safeAreaBar`): se suben antes de tocar.
        if prefijo.hasPrefix("letra") { app.staticTexts["asistente_question"].swipeUp() }
        app.buttons["asistente_grupo_idea_viaje"].tap()
        adjuntar(app, "\(prefijo)-1-nombre")
        siguiente(app)
        adjuntar(app, "\(prefijo)-2-icono")
        siguiente(app)
        adjuntar(app, "\(prefijo)-3-reparto")
        siguiente(app)
        adjuntar(app, "\(prefijo)-4-deudas")
        siguiente(app)
        // Con letra grande «Todo en una sola moneda» puede quedar bajo la barra de abajo (`testing.md`): ahí se deja.
        if !prefijo.hasPrefix("letra") {
            app.buttons["asistente_grupo_moneda_una"].tap()
            _ = app.buttons["asistente_grupo_moneda_elegir"].waitForExistence(timeout: 5)
        }
        adjuntar(app, "\(prefijo)-5-moneda")
        siguiente(app)
        adjuntar(app, "\(prefijo)-6-resumen")
        app.buttons["asistente_close"].tap()
        if app.buttons["asistente_discard_keep"].firstMatch.waitForExistence(timeout: 5) {
            adjuntar(app, "\(prefijo)-7-descartar")
            app.buttons["asistente_discard_keep"].firstMatch.tap()
        }
        app.buttons["asistente_use_form"].tap()
        XCTAssertTrue(app.textFields["group_form_name_input"].waitForExistence(timeout: 10))
        adjuntar(app, "\(prefijo)-8-formulario")
        app.terminate()
    }

    // MARK: - Ayudas

    private func abrirAsistente(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "grupos", deeplink: "groups", cloudSession: true, groupsConsent: true,
                            extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        abrirDeNuevo(app)
        return app
    }

    private func abrirDeNuevo(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let nuevo = app.buttons.matching(NSPredicate(format: "identifier IN %@",
                                                     ["groups_toolbar_new_group", "groups_action_new_group"])).firstMatch
        XCTAssertTrue(nuevo.waitForExistence(timeout: 30), "No apareció «Nuevo grupo».", file: file, line: line)
        nuevo.tap()
        XCTAssertTrue(app.staticTexts["asistente_question"].waitForExistence(timeout: 10),
                      "«Nuevo grupo» no abrió el asistente.", file: file, line: line)
    }

    private func fila(_ app: XCUIApplication, _ paso: String) -> XCUIElement {
        let elemento = app.descendants(matching: .any)["asistente_grupo_resumen_\(paso)"].firstMatch
        XCTAssertTrue(elemento.waitForExistence(timeout: 5), "Falta la fila «\(paso)» del resumen.")
        return elemento
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
    /// «Nuevo grupo» abre el asistente; los casos que prueban el FORMULARIO de crear pasan por «Usar formulario»
    /// (encargo del 17-nov). Espera al asistente (abierto por el botón que sea) y deja el formulario delante.
    func pasarDelAsistenteAlFormularioDeGrupo(file: StaticString = #filePath, line: UInt = #line) {
        let usarFormulario = buttons["asistente_use_form"]
        XCTAssertTrue(usarFormulario.waitForExistence(timeout: 15), "No se abrió el asistente de «Nuevo grupo».",
                      file: file, line: line)
        usarFormulario.tap()
    }
}
