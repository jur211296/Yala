//
//  AsistentePagoCompartidoUITests.swift
//  YalaUITests
//
//  El pago planificado compartido por el asistente y por el formulario (encargo del 21-nov): con un grupo activo, el
//  asistente pregunta si es compartido, ofrece solo los grupos en los que sigues, pide la división y crea el pago; en
//  el formulario, «¿Es un gasto compartido?» está a la vista junto a sus campos y, si falta algo al guardar, lo dice
//  debajo de la fila. Semilla `minimal` + `-uitest-seed-reusar-grupo` («Jurpi», «Casa vieja» archivado y «Depa
//  Miraflores», del que saliste).
//

import XCTest

final class AsistentePagoCompartidoUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func adjuntar(_ app: XCUIApplication, _ nombre: String) {
        let foto = XCTAttachment(screenshot: app.screenshot())
        foto.name = nombre
        foto.lifetime = .keepAlways
        add(foto)
    }

    private func abrirAsistente() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", deeplink: "scheduledPayments",
                            extraArguments: ["-uitest-seed-reusar-grupo"])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        let crear = app.buttons["scheduled_payments_create_button"]
        XCTAssertTrue(crear.waitForExistence(timeout: 15), "No apareció «Nuevo pago planificado».")
        crear.tap()
        XCTAssertTrue(app.staticTexts["asistente_question"].waitForExistence(timeout: 5), "No se abrió el asistente.")
        return app
    }

    private func pregunta(_ app: XCUIApplication, es texto: String, file: StaticString = #filePath, line: UInt = #line) {
        let titulo = app.staticTexts["asistente_question"]
        let espera = expectation(for: NSPredicate(format: "label == %@", texto), evaluatedWith: titulo)
        XCTAssertEqual(XCTWaiter.wait(for: [espera], timeout: 10), .completed,
                       "Se esperaba «\(texto)» y se ve «\(titulo.label)».", file: file, line: line)
    }

    private func siguiente(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let boton = app.buttons["asistente_next"]
        XCTAssertTrue(boton.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(boton.isEnabled, "«Siguiente» apagado.", file: file, line: line)
        boton.tap()
    }

    func test_asistente_preguntaSiEsCompartido_yCreaElPagoDelGrupo() {
        let app = abrirAsistente()
        app.buttons["asistente_pago_tipo_utilities"].tap()
        siguiente(app)
        let nombre = app.textFields["asistente_pago_nombre"]
        XCTAssertTrue(nombre.waitForExistence(timeout: 5))
        nombre.tap()
        let actual = nombre.value as? String ?? ""
        nombre.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: actual.count) + "Luz compartida")
        siguiente(app)
        let monto = app.textFields["asistente_pago_monto"]
        XCTAssertTrue(monto.waitForExistence(timeout: 5))
        monto.tap()
        monto.typeText("120")
        siguiente(app)

        pregunta(app, es: "¿Es un gasto compartido?")
        XCTAssertTrue(app.buttons["asistente_pago_compartido_no"].isSelected, "«No, es solo mío» no llega elegido.")
        let grupos = app.buttons.matching(identifier: "asistente_pago_compartido_grupo")
        XCTAssertEqual(grupos.count, 1, "Solo «Jurpi»: ni el archivado ni el grupo del que saliste.")
        let jurpi = grupos.firstMatch
        XCTAssertTrue(jurpi.label.contains("Jurpi"), "Se ofrece «\(jurpi.label)».")
        jurpi.tap()
        adjuntar(app, "asistente-compartido")
        siguiente(app)

        pregunta(app, es: "¿Cómo lo dividen?")
        let division = app.buttons["asistente_pago_reparto_division"]
        XCTAssertTrue(division.waitForExistence(timeout: 5))
        XCTAssertTrue(division.label.contains("Entre 2"), "La división no llega puesta: «\(division.label)».")
        XCTAssertTrue(division.label.contains("60"), "Tu parte de 120 entre 2 no es 60: «\(division.label)».")
        adjuntar(app, "asistente-reparto")
        siguiente(app)

        pregunta(app, es: "¿Cada cuánto toca pagar?")
        siguiente(app)
        siguiente(app)   // ¿Qué día?
        siguiente(app)   // ¿Te avisamos?
        pregunta(app, es: "¿Algo más?")
        adjuntar(app, "asistente-algo-mas")
        siguiente(app)

        pregunta(app, es: "¿Lo creamos así?")
        let compartido = app.buttons["asistente_pago_resumen_compartido"]
        XCTAssertTrue(compartido.exists && compartido.label.contains("Jurpi"), "El resumen no dice con quién.")
        XCTAssertTrue(app.buttons["asistente_pago_resumen_reparto"].label.contains("60"))
        adjuntar(app, "asistente-resumen")
        // Tocar lo compartido lleva a su pregunta y «Siguiente» vuelve al resumen. La fila queda bajo la barra de abajo
        // hasta desplazar el resumen.
        var intentos = 0
        while compartido.frame.maxY > app.buttons["asistente_next"].frame.minY - 8 && intentos < 4 {
            app.swipeUp(); intentos += 1
        }
        compartido.tap()
        pregunta(app, es: "¿Es un gasto compartido?")
        siguiente(app)
        pregunta(app, es: "¿Lo creamos así?")

        app.buttons["asistente_next"].tap()
        let pago = app.buttons.matching(NSPredicate(format: "identifier == 'scheduled_payment_row' AND label BEGINSWITH 'Luz compartida'")).firstMatch
        XCTAssertTrue(pago.waitForExistence(timeout: 10), "El pago compartido no aparece en la lista.")
        // Se guarda tu parte: 60.
        XCTAssertTrue(pago.label.contains("60"), "La fila no enseña tu parte: «\(pago.label)».")

        pago.tap()
        let editar = app.buttons["pencil"].firstMatch
        if editar.waitForExistence(timeout: 5) { editar.tap() }
        XCTAssertTrue(app.buttons["scheduled_group_row"].waitForExistence(timeout: 10), "El pago no quedó compartido.")
        XCTAssertTrue(app.buttons["scheduled_group_row"].label.contains("Jurpi"))
    }

    func test_formulario_elCompartidoEstaALaVista_yDiceQueFalta() {
        let app = abrirAsistente()
        app.buttons["asistente_use_form"].tap()
        let nombre = app.textFields["scheduled_name_field"]
        XCTAssertTrue(nombre.waitForExistence(timeout: 5))
        nombre.tap()
        nombre.typeText("Agua QA")
        let monto = app.textFields["scheduled_amount_field"]
        monto.tap()
        monto.typeText("90")
        // Antes de tocar nada debajo: sin teclado (`testing.md`, tocar tras escribir). En una hoja no se arrastra la
        // barra (sería intentar cerrarla): un toque en el título de la caja «Información básica».
        app.staticTexts["Información básica"].firstMatch.tap()
        let sinTeclado = expectation(for: NSPredicate(format: "count == 0"), evaluatedWith: app.keyboards)
        XCTAssertEqual(XCTWaiter.wait(for: [sinTeclado], timeout: 5), .completed, "El teclado no se cerró.")

        // Sin abrir «Más opciones»: el interruptor está en su propia caja.
        let interruptor = app.switches["scheduled_group_expense_toggle"]
        var intentos = 0
        while !(interruptor.exists && interruptor.isHittable) && intentos < 4 { app.swipeUp(); intentos += 1 }
        XCTAssertTrue(interruptor.isHittable, "«¿Es un gasto compartido?» no está a la vista sin abrir «Más opciones».")
        XCTAssertFalse(app.buttons["scheduled_more_options"].isSelected)
        if interruptor.switches.firstMatch.exists { interruptor.switches.firstMatch.tap() } else { interruptor.tap() }
        let grupo = app.buttons["scheduled_group_row"]
        XCTAssertTrue(grupo.waitForExistence(timeout: 5), "Encendido, «Grupo» no aparece debajo.")
        XCTAssertGreaterThan(grupo.frame.minY, interruptor.frame.minY, "«Grupo» no está debajo del interruptor.")

        app.buttons["toolbar_save_button"].tap()
        let falta = app.descendants(matching: .any)["scheduled_missing_line"].firstMatch
        XCTAssertTrue(falta.waitForExistence(timeout: 5), "Al guardar sin grupo, no dice qué falta.")
        XCTAssertTrue(falta.isHittable, "Lo que falta no quedó a la vista.")
        adjuntar(app, "formulario-falta-grupo")

        grupo.tap()
        let jurpi = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Jurpi'")).firstMatch
        XCTAssertTrue(jurpi.waitForExistence(timeout: 5), "El selector de grupo no ofrece «Jurpi».")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Depa Miraflores'")).firstMatch.exists,
                       "El selector ofrece un grupo del que saliste.")
        jurpi.tap()
        XCTAssertTrue(grupo.waitForExistence(timeout: 5))
        XCTAssertTrue(grupo.label.contains("Jurpi"))
    }
}
