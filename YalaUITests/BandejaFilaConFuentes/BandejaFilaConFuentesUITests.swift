//
//  BandejaFilaConFuentesUITests.swift
//  YalaUITests
//
//  Bandeja sin duplicados, lote 3: el pendiente unido dice sus fuentes, la pareja dudosa sale como «¿Es el mismo gasto?»
//  y lo que ya está guardado dice «Ya registrado». La semilla pone las tres cosas: el café unido
//  (`-uitest-inbox-joined-draft`), el delivery por Apple Pay y por el correo con propina
//  (`-uitest-inbox-same-expense-pair`) y el almuerzo con su registro gemelo (`-uitest-inbox-duplicate-draft`). Qué se
//  pregunta lo decide producción. Deja capturas para el entregable.
//

import XCTest

final class BandejaFilaConFuentesUITests: XCTestCase {

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

    private func openInbox() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(extraArguments: [
            "-uitest-inbox-joined-draft", "-uitest-inbox-same-expense-pair", "-uitest-inbox-duplicate-draft",
        ])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let inboxButton = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inboxButton.waitForExistence(timeout: 10), "No apareció el botón de la Bandeja en el Panel.")
        inboxButton.tap()
        // Se espera el filtro, no una fila: antes del mediodía el correo de la semilla (fechado hoy a las 12:00) va arriba y
        // «Almuerzo equipo» queda bajo el pliegue, fuera del árbol de una lista perezosa (rojo de 3 de 3 a las 02:00).
        XCTAssertTrue(app.buttons["inbox_filter_pending"].waitForExistence(timeout: 10), "La Bandeja no cargó.")
        return app
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
            // Si quedó arriba (bajo la cabecera), se baja la lista; si no está o está abajo, se sube.
            let from = isAbove ? 0.45 : 0.75
            let to = isAbove ? 0.7 : 0.5
            let start = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: from))
            let end = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: to))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTFail("No se pudo dejar \(element) a la vista.")
    }

    func test_inbox_showsSourcesPairAndAlreadyRecorded_andDistinctKeepsBoth() {
        let app = openInbox()

        let recorded = app.descendants(matching: .any)["inbox_already_recorded"]
        reveal(recorded, in: app)
        XCTAssertTrue(recorded.exists, "El almuerzo con su registro gemelo no dice «Ya registrado».")
        attachScreenshot("bandeja-ya-registrado", of: app)

        let distinct = app.buttons["inbox_same_expense_distinct"]
        reveal(distinct, in: app)
        XCTAssertTrue(app.descendants(matching: .any)["inbox_same_expense_title"].exists,
                      "No salió «¿Es el mismo gasto?» para el delivery por Apple Pay y por el correo.")
        attachScreenshot("bandeja-es-el-mismo-gasto", of: app)

        let joined = app.buttons["inbox_draft_row_Starbucks"]
        reveal(joined, in: app)
        XCTAssertTrue(joined.label.contains("Apple Pay"), "La fila unida no dice Apple Pay: \(joined.label)")
        XCTAssertTrue(joined.label.contains("Correo"), "La fila unida no dice el correo del banco: \(joined.label)")
        attachScreenshot("bandeja-fila-con-fuentes", of: app)

        reveal(distinct, in: app)
        distinct.tap()
        XCTAssertTrue(distinct.waitForNonExistence(timeout: 5), "«Son distintos» no quitó la pregunta.")
        // Separados, cada uno va en su día: primero el correo (hoy, más arriba) y después el de Apple Pay, que antes del
        // mediodía queda en «Ayer», bajo el pliegue. `reveal` busca hacia abajo lo que aún no existe en la lista.
        let email = app.buttons["inbox_draft_row_RAPPI*PE"]
        reveal(email, in: app)
        XCTAssertTrue(email.exists, "Desapareció el del correo.")
        let applePay = app.buttons["inbox_draft_row_Rappi"]
        reveal(applePay, in: app)
        XCTAssertTrue(applePay.exists, "Desapareció el de Apple Pay.")
    }

    func test_same_joinsIntoOnePending_withSeparate() {
        let app = openInbox()

        let same = app.buttons["inbox_same_expense_same"]
        reveal(same, in: app)
        same.tap()

        XCTAssertTrue(same.waitForNonExistence(timeout: 5), "«Es el mismo» no quitó la pregunta.")
        XCTAssertTrue(app.buttons["inbox_draft_row_RAPPI*PE"].waitForNonExistence(timeout: 5),
                      "El del correo sigue como pendiente aparte: no se unió.")
        let held = app.buttons["inbox_draft_row_Rappi"]
        XCTAssertTrue(held.waitForExistence(timeout: 5), "No quedó el pendiente unido.")
        XCTAssertTrue(held.label.contains("Correo"), "El pendiente unido no dice el correo: \(held.label)")
        attachScreenshot("bandeja-tras-es-el-mismo", of: app)

        reveal(held, in: app)
        held.tap()
        XCTAssertTrue(app.buttons["inbox_joined_separate"].waitForExistence(timeout: 5),
                      "El pendiente unido con «Es el mismo» no tiene «Separar».")
    }

    func test_alreadyRecorded_discardMovesItToArchived() {
        let app = openInbox()

        let discard = app.buttons["inbox_already_recorded_discard"]
        reveal(discard, in: app)
        discard.tap()
        XCTAssertTrue(app.buttons["inbox_draft_row_Almuerzo equipo"].waitForNonExistence(timeout: 5),
                      "«Descartar» de «Ya registrado» no quitó el pendiente.")
    }
}
