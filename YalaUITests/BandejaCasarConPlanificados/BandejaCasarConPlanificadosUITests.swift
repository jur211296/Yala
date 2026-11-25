//
//  BandejaCasarConPlanificadosUITests.swift
//  YalaUITests
//
//  Bandeja sin duplicados, lote 4: lo que casa con un pago planificado no crea pendiente. La semilla
//  (`-uitest-inbox-planned-match`) pone tres planificados con su cargo: Sedapal estimado y ya aprendido (su correo
//  adelanta el borrador con el monto real), Netflix fijo y aprendido (su Apple Pay se une) y Luz del Sur estimado, la
//  primera vez (la Bandeja pregunta). Los cargos entran por la unión de producción. Deja capturas para el entregable.
//

import XCTest

final class BandejaCasarConPlanificadosUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func attachScreenshot(_ name: String, of app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Arrastres cortos hasta dejar el elemento en la franja central de la ventana (un `swipeUp` lo subiría bajo la
    /// cabecera). Comprueba la condición en cada vuelta, no un número fijo de gestos.
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        let window = app.windows.firstMatch.frame
        for _ in 0..<10 {
            let isAbove = element.exists && !element.frame.isEmpty
                && element.frame.midY <= window.minY + window.height * 0.3
            if element.exists, !element.frame.isEmpty, !isAbove,
               element.frame.maxY < window.maxY - window.height * 0.1 {
                return
            }
            let from = isAbove ? 0.45 : 0.75
            let to = isAbove ? 0.7 : 0.5
            let start = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: from))
            let end = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: to))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTFail("No se pudo dejar \(element) a la vista.")
    }

    func test_plannedPayments_learnedJoinAlone_firstTimeAsks_andYesTakesTheRealAmount() {
        let app = XCUIApplication()
        app.launchForUITest(extraArguments: ["-uitest-inbox-planned-match"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let inboxButton = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inboxButton.waitForExistence(timeout: 10), "No apareció el botón de la Bandeja en el Panel.")
        inboxButton.tap()

        // Sedapal, aprendido y aún sin vencer: su correo adelantó el borrador del planificado con el monto real.
        let sedapal = app.buttons["inbox_draft_row_Sedapal"]
        XCTAssertTrue(sedapal.waitForExistence(timeout: 10), "El correo de Sedapal no completó su pago planificado.")
        XCTAssertTrue(sedapal.label.contains("72.40"), "Sedapal no tomó el monto real: \(sedapal.label)")
        XCTAssertTrue(sedapal.label.contains("60.00"), "Sedapal no dice el estimado de antes: \(sedapal.label)")
        XCTAssertFalse(app.buttons["inbox_draft_row_SEDAPAL"].exists, "El correo de Sedapal quedó también suelto.")

        // Luz del Sur, la primera vez: la Bandeja pregunta.
        let yes = app.buttons["inbox_planned_question_yes"]
        reveal(yes, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["inbox_planned_question_title"].firstMatch.exists,
                      "No salió «¿Es tu pago…?» para el correo de Luz del Sur.")
        XCTAssertTrue(app.buttons["inbox_draft_row_LUZ DEL SUR SAA"].exists, "El correo no va en la tarjeta.")
        attachScreenshot("bandeja-es-tu-pago", of: app)

        yes.tap()
        XCTAssertTrue(yes.waitForNonExistence(timeout: 5), "La pregunta siguió tras «Sí, es ese pago».")
        XCTAssertFalse(app.buttons["inbox_draft_row_LUZ DEL SUR SAA"].exists, "El correo de Luz del Sur quedó suelto.")
        let luz = app.buttons["inbox_draft_row_Luz del Sur"]
        reveal(luz, in: app)
        XCTAssertTrue(luz.label.contains("134.80"), "Luz del Sur no tomó el monto real: \(luz.label)")
        XCTAssertTrue(luz.label.contains("120.00"), "Luz del Sur no dice el estimado de antes: \(luz.label)")

        // Netflix, aprendido: su Apple Pay ya estaba dentro del borrador del planificado.
        let netflix = app.buttons["inbox_draft_row_Netflix"]
        reveal(netflix, in: app)
        XCTAssertTrue(netflix.label.contains("Apple Pay"), "El Apple Pay de Netflix no se unió: \(netflix.label)")
        XCTAssertFalse(app.buttons["inbox_draft_row_Netflix.com"].exists, "El Apple Pay de Netflix quedó suelto.")
        attachScreenshot("bandeja-tras-si", of: app)
    }
}
