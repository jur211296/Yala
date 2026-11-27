//
//  PulidoGruposVacioEstoLeiUITests.swift
//  YalaUITests
//
//  Pulido del 27-nov-2026 (encargo «Grupos vacío y Esto leí»):
//  1. Un grupo y una persona sin gastos llevan la fila de registro (Nuevo gasto, Voz, Foto, Yala IA) arriba, bajo los
//     chips, y solo «Sin gastos» centrado en lo que sobra.
//  2. «Esto leí» en grande: deslizar una lectura nueva la descarta; una ya guardada borra su registro tras confirmarlo;
//     quitar la última cierra la hoja, también con una sola tarjeta.
//
//  Capturas: cada caso adjunta las suyas (`keepAlways`). Oscuro es el tema por defecto; en claro,
//  `TEST_RUNNER_YALA_TEMA_CLARO=1`.
//

import XCTest

final class PulidoGruposVacioEstoLeiUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private var tema: [String] {
        ProcessInfo.processInfo.environment["YALA_TEMA_CLARO"] == "1" ? ["-userTheme", "1"] : []
    }

    private func adjuntar(_ app: XCUIApplication, _ nombre: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = nombre
        shot.lifetime = .keepAlways
        add(shot)
    }

    // MARK: - 1 · Grupos y Personas sin gastos

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    private func launchGroups(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups",
                            extraArguments: ["-uitest-seed-group-cross-debts", "-uitest-seed-compartido-persona"]
                                + extra + tema)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// La fila de registro queda en la mitad de arriba, por encima de «Sin gastos» y con aire entre las dos.
    private func assertActionsOnTopAndEmptyCentered(_ app: XCUIApplication, _ donde: String) {
        let newExpense = app.buttons["group_detail_action_new_expense"]
        XCTAssertTrue(newExpense.waitForExistence(timeout: 15), "\(donde): falta «Nuevo gasto».")
        let empty = app.staticTexts["Sin gastos"].firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 10), "\(donde): falta «Sin gastos».")
        let window = app.windows.firstMatch.frame
        let actions = newExpense.frame
        XCTAssertLessThan(actions.midY, window.height * 0.4,
                          "\(donde): la fila de botones no está arriba (y=\(actions.midY) de \(window.height)).")
        XCTAssertGreaterThan(empty.frame.minY - actions.maxY, 80,
                             "\(donde): «Sin gastos» sigue pegado a la fila de botones (centrados juntos).")
        XCTAssertGreaterThan(empty.frame.midY, window.height * 0.45,
                             "\(donde): «Sin gastos» no está centrado en lo que sobra.")
    }

    func test_grupoSinGastos_botonesArriba_yVacioCentrado() {
        let app = launchGroups()
        let card = app.buttons.matching(identifier: "group_card")
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Grupo sin gastos")).firstMatch
        var swipes = 0
        while !card.waitForExistence(timeout: swipes == 0 ? 15 : 2), swipes < 4 {
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
        XCTAssertTrue(card.exists, "No apareció «Grupo sin gastos».")
        card.tap()
        assertActionsOnTopAndEmptyCentered(app, "Grupo sin gastos")
        adjuntar(app, "grupo_sin_gastos")
    }

    /// Texto al máximo y girado: la fila de botones y «Sin gastos» no se montan.
    func test_grupoSinGastos_textoMaximoGirado_noSeMontan() {
        let app = launchGroups(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let card = app.buttons.matching(identifier: "group_card")
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Grupo sin gastos")).firstMatch
        var swipes = 0
        while !card.waitForExistence(timeout: swipes == 0 ? 15 : 2), swipes < 8 {
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
        XCTAssertTrue(card.exists, "No apareció «Grupo sin gastos».")
        card.tap()
        let newExpense = app.buttons["group_detail_action_new_expense"]
        XCTAssertTrue(newExpense.waitForExistence(timeout: 15), "Falta «Nuevo gasto».")
        XCUIDevice.shared.orientation = .landscapeLeft
        let empty = app.staticTexts["Sin gastos"].firstMatch
        XCTAssertTrue(empty.waitForExistence(timeout: 10), "Falta «Sin gastos».")
        // La app tarda en recolocarse tras el giro (molde de `ExitoGruposBandejaCapturasUITests`): antes, la foto y los
        // marcos salen a mitad del giro.
        let turned = NSPredicate { _, _ in app.frame.width > app.frame.height }
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: turned, object: nil)], timeout: 8)
        Thread.sleep(forTimeInterval: 1.5)
        _ = app.waitForSettledLayout(of: empty)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "grupo_sin_gastos_ax5_girado"
        shot.lifetime = .keepAlways
        add(shot)
        let actionsBottom = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'group_detail_'"))
            .allElementsBoundByIndex.filter(\.exists).map(\.frame.maxY).max() ?? newExpense.frame.maxY
        XCTAssertLessThanOrEqual(actionsBottom, empty.frame.minY,
                                 "Girado y con texto al máximo, la fila de botones pisa «Sin gastos».")
        // Si no cabe, se llega desplazando: no se queda cortado por abajo.
        if empty.frame.maxY > app.frame.maxY {
            // Arrastre corto de abajo arriba sobre la parte baja de la pantalla, lejos de la fila de chips.
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
            from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)))
            _ = app.waitForSettledLayout(of: empty)
        }
        XCTAssertLessThanOrEqual(empty.frame.maxY, app.frame.maxY,
                                 "Girado y con texto al máximo, «Sin gastos» queda cortado y no se puede bajar hasta él.")
        let after = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        after.name = "grupo_sin_gastos_ax5_girado_abajo"
        after.lifetime = .keepAlways
        add(after)
    }

    func test_personaSinGastos_botonesArriba_yVacioCentrado() {
        let app = launchGroups()
        let peopleChip = app.buttons["compartido_chip_personas"]
        XCTAssertTrue(peopleChip.waitForExistence(timeout: 15), "Faltan los chips de Compartido.")
        peopleChip.tap()
        let marta = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'compartido_person_card' AND label BEGINSWITH 'Marta'"))
            .firstMatch
        // Con la semilla de grupos hay varias personas: Marta puede quedar más abajo.
        var swipes = 0
        while !marta.waitForExistence(timeout: swipes == 0 ? 10 : 2), swipes < 5 {
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
        XCTAssertTrue(marta.exists, "No sale la tarjeta de Marta.")
        marta.tap()
        assertActionsOnTopAndEmptyCentered(app, "Persona sin gastos")
        adjuntar(app, "persona_sin_gastos")
    }

    // MARK: - 2 · «Esto leí» en grande

    private func openImageReview(result: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true, seed: "minimal", aiConsent: true,
            extraArguments: ["-uitest-image-result", result, "-uitest-undo-notice-seconds", "30",
                             "-uitest-image-autoclose-seconds", "30"] + tema)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.revealPanelFAB().tap()
        let image = app.buttons["fab_image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5), "El menú del FAB no ofreció imagen (fab_image).")
        image.tap()
        let photos = app.buttons["image_source_photos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 15), "La hoja no abrió eligiendo (image_source_photos).")
        photos.tap()
        XCTAssertTrue(app.staticTexts["image_review_title"].waitForExistence(timeout: 15), "No apareció lo leído.")
        return app
    }

    /// Desliza a la izquierda y toca el botón que asoma. Un deslizamiento largo ya puede haberlo ejecutado.
    private func swipeAndTap(_ element: XCUIElement, button id: String, in app: XCUIApplication) {
        let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        let end = element.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Al deslizar no asomó el botón \(id).")
        adjuntar(app, "deslizar_\(id)")
        button.tap()
    }

    /// Dos leídos: se guarda uno (el otro sin marcar). Deslizar el guardado pide confirmar y borra su registro; deslizar
    /// el que queda, el último, lo descarta y la hoja se cierra.
    func test_varios_eliminarGuardado_yDescartarElUltimo_cierraLaHoja() {
        let app = openImageReview(result: "two")
        let rows = app.descendants(matching: .any).matching(identifier: "multi_review_row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "La foto con dos no enseñó la lista de varios.")
        XCTAssertEqual(rows.count, 2)
        adjuntar(app, "esto_lei_grande")

        // Se desmarca el segundo y se guarda el primero.
        let checks = app.buttons.matching(identifier: "multi_review_check")
        XCTAssertTrue(checks.element(boundBy: 1).waitForHittable(timeout: 5))
        checks.element(boundBy: 1).tap()
        app.buttons["image_save"].tap()
        let saved = app.descendants(matching: .any)["voice_draft_saved"].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 10), "El primero no quedó guardado.")
        XCTAssertEqual(rows.count, 2, "Guardar uno no debe quitar filas.")

        // Eliminar el guardado: pregunta, y al confirmar sale de la lista.
        let savedRow = rows.element(boundBy: 0)
        swipeAndTap(savedRow, button: "esto_lei_swipe_delete", in: app)
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Eliminar un guardado no pidió confirmación.")
        adjuntar(app, "eliminar_confirmacion")
        alert.buttons.element(boundBy: alert.buttons.count - 1).tap()
        let oneLeft = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == 1"), object: rows)
        let fallback = app.descendants(matching: .any).matching(identifier: "voice_draft_card")
        // Con uno solo la hoja pasa a la tarjeta de un registro: vale cualquiera de las dos formas.
        if XCTWaiter().wait(for: [oneLeft], timeout: 5) != .completed {
            XCTAssertTrue(fallback.firstMatch.waitForExistence(timeout: 5), "Tras eliminar, no quedó el pendiente.")
        }
        XCTAssertTrue(app.staticTexts["image_review_title"].exists, "La hoja se cerró con uno pendiente.")
        adjuntar(app, "tras_eliminar")

        // Descartar el último: la hoja se cierra.
        let last = rows.count == 1 ? rows.firstMatch : fallback.firstMatch
        swipeAndTap(last, button: "esto_lei_swipe_discard", in: app)
        XCTAssertTrue(app.staticTexts["image_review_title"].waitForNonExistence(timeout: 10),
                      "Descartar el último no cerró la hoja.")
    }

    /// Una sola tarjeta, estirada a grande: deslizar la descarta y la hoja se cierra. A media altura no se desliza.
    func test_unica_aMediaAlturaNoSeDesliza_enGrandeSeDescartaYCierra() {
        let app = openImageReview(result: "one")
        let card = app.descendants(matching: .any)["voice_draft_card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No salió la tarjeta de un registro.")
        XCTAssertFalse(app.buttons["esto_lei_a11y_discard"].exists, "A media altura la tarjeta no debe deslizarse.")

        // Estirar la hoja a grande desde su cabecera.
        let title = app.staticTexts["image_review_title"]
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02)))
        XCTAssertTrue(app.buttons["esto_lei_a11y_discard"].waitForExistence(timeout: 5),
                      "Estirada a grande, la tarjeta no ofrece descartar.")
        adjuntar(app, "unica_en_grande")
        swipeAndTap(card, button: "esto_lei_swipe_discard", in: app)
        XCTAssertTrue(title.waitForNonExistence(timeout: 10), "Descartar la única no cerró la hoja.")
    }
}
