//
//  AsistentePresupuestoUITests.swift
//  YalaUITests
//
//  «Nuevo presupuesto» por pasos (encargo del 17-nov): el recorrido completo crea el presupuesto, «Usar formulario»
//  lleva lo respondido al formulario de siempre, y cerrar con algo respondido pregunta antes de descartar. El caso de
//  capturas recorre cada pantalla y deja una foto por paso (las del artifact), en las variantes de `YALA_CAPTURAS`
//  (tema claro, letra grande).
//

import XCTest

final class AsistentePresupuestoUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Recorrido completo

    func test_recorridoCompleto_creaElPresupuesto() {
        let app = abrirAsistente()

        pregunta(app, es: "¿Qué gastos cuenta?")
        XCTAssertTrue(app.buttons["asistente_presupuesto_alcance_todos"].isSelected,
                      "«Todos mis gastos» no llega marcado: «Siguiente» tiene que servir con lo sugerido.")
        XCTAssertFalse(app.buttons["asistente_back"].exists, "En la primera pregunta no hay Atrás.")
        app.buttons["asistente_presupuesto_alcance_categorias"].tap()
        siguiente(app)

        pregunta(app, es: "¿Cuáles?")
        XCTAssertFalse(app.buttons["asistente_next"].isEnabled, "Sin categorías elegidas, «Siguiente» va apagado.")
        app.buttons.matching(identifier: "asistente_presupuesto_categoria").firstMatch.tap()
        siguiente(app)

        pregunta(app, es: "¿Cada cuánto se renueva?")
        XCTAssertTrue(app.buttons["asistente_presupuesto_periodo_monthly"].isSelected, "Mensual no llega marcado.")
        siguiente(app)

        pregunta(app, es: "¿Cuánto quieres gastar como máximo al mes?")
        let tope = app.textFields["asistente_presupuesto_tope"]
        XCTAssertTrue(tope.waitForExistence(timeout: 5))
        tope.tap()
        tope.typeText("450")
        siguiente(app)

        pregunta(app, es: "¿Cómo lo llamamos?")
        let nombre = app.textFields["asistente_presupuesto_nombre"]
        XCTAssertTrue(nombre.waitForExistence(timeout: 5))
        XCTAssertFalse((nombre.value as? String ?? "").isEmpty, "El nombre no llega propuesto.")
        nombre.tap()
        nombre.clearAndType("Asistente QA")
        siguiente(app)

        pregunta(app, es: "¿Te avisamos cuando vayas llegando al tope?")
        app.buttons["asistente_presupuesto_aviso_100"].tap()
        siguiente(app)

        pregunta(app, es: "¿Lo creamos así?")
        XCTAssertTrue(app.buttons["asistente_presupuesto_resumen_nombre"].label.contains("Asistente QA"))
        XCTAssertTrue(app.buttons["asistente_presupuesto_resumen_aviso"].label.contains("100"))

        // Cambiar una respuesta desde el resumen vuelve al resumen con «Siguiente».
        app.buttons["asistente_presupuesto_resumen_periodo"].tap()
        pregunta(app, es: "¿Cada cuánto se renueva?")
        siguiente(app)
        pregunta(app, es: "¿Lo creamos así?")

        let crear = app.buttons["asistente_next"]
        XCTAssertEqual(crear.label, "Crear presupuesto")
        crear.tap()

        XCTAssertTrue(app.buttons["budget_row_Asistente QA"].waitForExistence(timeout: 10),
                      "El presupuesto creado no aparece en la lista.")
        XCTAssertFalse(app.buttons["asistente_next"].exists, "La hoja del asistente sigue abierta tras crear.")
    }

    // MARK: - «Usar formulario»

    func test_usarFormulario_llevaLoRespondido() {
        let app = abrirAsistente()
        XCTAssertTrue(app.buttons["asistente_use_form"].exists, "«Usar formulario» no está arriba en la primera pregunta.")
        siguiente(app)                                   // Todos mis gastos
        app.buttons["asistente_presupuesto_periodo_weekly"].tap()
        siguiente(app)                                   // Semanal
        let tope = app.textFields["asistente_presupuesto_tope"]
        XCTAssertTrue(tope.waitForExistence(timeout: 5))
        tope.tap()
        tope.typeText("300")
        XCTAssertTrue(app.buttons["asistente_use_form"].exists, "«Usar formulario» desapareció a mitad del asistente.")
        app.buttons["asistente_use_form"].tap()

        let monto = app.textFields["budget_amount_field"]
        XCTAssertTrue(monto.waitForExistence(timeout: 5), "«Usar formulario» no abrió el formulario.")
        XCTAssertTrue((monto.value as? String ?? "").hasPrefix("300"), "El tope no pasó al formulario: \(monto.value ?? "")")
        let tipo = app.descendants(matching: .any)["budget_editor_period_picker"].firstMatch
        XCTAssertTrue(tipo.exists)
        XCTAssertTrue((tipo.value as? String ?? "").contains("Semanal") || app.buttons["Semanal"].isSelected,
                      "El período no pasó al formulario.")
        adjuntar(app, "formulario-con-lo-respondido")

        // Con lo respondido, la X del formulario pregunta.
        app.buttons["xmark"].firstMatch.tap()
        let seguir = app.buttons["asistente_discard_keep"].firstMatch
        XCTAssertTrue(seguir.waitForExistence(timeout: 5), "La X del formulario tiró lo respondido sin preguntar.")
        seguir.tap()
        XCTAssertTrue(monto.exists, "«Seguir» cerró el formulario.")
    }

    // MARK: - Descartar

    func test_cerrarConRespuestas_preguntaAntes() {
        let app = abrirAsistente()
        // Sin nada respondido, la X cierra directo.
        app.buttons["asistente_close"].tap()
        XCTAssertTrue(app.buttons["budgets_create_button"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["asistente_discard_confirm"].exists)

        app.buttons["budgets_create_button"].tap()
        pregunta(app, es: "¿Qué gastos cuenta?")
        siguiente(app)
        app.buttons["asistente_close"].tap()
        let seguir = app.buttons["asistente_discard_keep"].firstMatch
        XCTAssertTrue(seguir.waitForExistence(timeout: 5), "Con algo respondido, la X no preguntó.")
        seguir.tap()
        pregunta(app, es: "¿Cada cuánto se renueva?")

        // Atrás vuelve a la pregunta anterior con lo elegido.
        app.buttons["asistente_back"].tap()
        pregunta(app, es: "¿Qué gastos cuenta?")

        app.buttons["asistente_close"].tap()
        let descartar = app.buttons["asistente_discard_confirm"].firstMatch
        XCTAssertTrue(descartar.waitForExistence(timeout: 5))
        descartar.tap()
        XCTAssertTrue(app.buttons["budgets_create_button"].waitForHittable(timeout: 5), "Descartar no cerró la hoja.")
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
        adjuntar(app, "\(prefijo)-1-alcance")
        // Con letra grande «Solo algunas categorías» queda bajo la barra de abajo y el toque caería en «Siguiente»
        // (`testing.md`, `isHittable` bajo una `.safeAreaBar`): esa variante sigue por «Todos mis gastos».
        if !prefijo.hasPrefix("letra") {
            app.buttons["asistente_presupuesto_alcance_categorias"].tap()
            siguiente(app)
            let tiles = app.buttons.matching(identifier: "asistente_presupuesto_categoria")
            XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 5), "No hay categorías que elegir.")
            tiles.element(boundBy: 0).tap()
            if tiles.count > 1 { tiles.element(boundBy: 1).tap() }
            adjuntar(app, "\(prefijo)-2-categorias")
        }
        siguiente(app)
        adjuntar(app, "\(prefijo)-3-periodo")
        siguiente(app)
        let tope = app.textFields["asistente_presupuesto_tope"]
        XCTAssertTrue(tope.waitForExistence(timeout: 5))
        let sugerencia = app.buttons["asistente_presupuesto_sugerencia_1"]
        // Con letra grande las sugerencias quedan bajo la barra de abajo: se escribe el tope.
        if sugerencia.exists, !prefijo.hasPrefix("letra") {
            sugerencia.tap()
        } else {
            tope.tap()
            tope.typeText("800")
        }
        adjuntar(app, "\(prefijo)-4-tope")
        siguiente(app)
        adjuntar(app, "\(prefijo)-5-nombre")
        siguiente(app)
        adjuntar(app, "\(prefijo)-6-aviso")
        siguiente(app)
        adjuntar(app, "\(prefijo)-7-resumen")
        app.buttons["asistente_use_form"].tap()
        XCTAssertTrue(app.textFields["budget_amount_field"].waitForExistence(timeout: 5))
        adjuntar(app, "\(prefijo)-8-formulario")
        app.terminate()
    }

    // MARK: - Ayudas

    private func abrirAsistente(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: "budgets", extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        let crear = app.buttons["budgets_create_button"]
        XCTAssertTrue(crear.waitForExistence(timeout: 15), "No apareció «Nuevo presupuesto».")
        crear.tap()
        XCTAssertTrue(app.staticTexts["asistente_question"].waitForExistence(timeout: 5),
                      "«Nuevo presupuesto» no abrió el asistente.")
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
    /// «Nuevo presupuesto» abre el asistente; los casos que prueban el FORMULARIO de crear pasan por «Usar formulario»
    /// (encargo del 17-nov). Toca el botón de arriba (o el que se pase) y deja el formulario delante.
    func abrirFormularioDeNuevoPresupuesto(desde boton: XCUIElement? = nil, file: StaticString = #filePath,
                                          line: UInt = #line) {
        let crear = boton ?? buttons["budgets_create_button"]
        XCTAssertTrue(crear.waitForExistence(timeout: 15), "No apareció «Nuevo presupuesto».", file: file, line: line)
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
