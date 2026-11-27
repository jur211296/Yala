//
//  ConvertirFotoAGrupoUITests.swift
//  YalaUITests
//
//  Card «Bug: al convertir a gasto compartido un registro leído de imagen, no se marca como registrado» (encargo de
//  trabas del 27-nov-2026). `CaptureConvertToGroupUITests` cubre la foto con UN registro (la hoja se cierra sola) y la
//  voz. Aquí, la foto con DOS: la lista de varios (`MultiDraftReviewList`), que es donde la fila convertida tiene que
//  quedarse a la vista marcada mientras el otro sigue pendiente. Seed `grupos-invitado`: un grupo elegible, así el
//  formulario abre directo (ver `CaptureConvertToGroupUITests`).
//

import XCTest

final class ConvertirFotoAGrupoUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Oscuro es el tema por defecto. Para las capturas en claro: `TEST_RUNNER_YALA_TEMA_CLARO=1` (`-userTheme 1`).
    private var tema: [String] {
        ProcessInfo.processInfo.environment["YALA_TEMA_CLARO"] == "1" ? ["-userTheme", "1"] : []
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true, seed: "grupos-invitado", aiConsent: true,
            extraArguments: ["-uitest-image-result", "two", "-uitest-undo-notice-seconds", "30"] + tema)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    private func adjuntar(_ app: XCUIApplication, _ nombre: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = nombre
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Dos leídos de la foto: el primero pasa a gasto de grupo y queda en la lista como guardado, con el grupo; el otro
    /// sigue pendiente y la hoja no se cierra.
    func test_fotoConDos_convertirUno_quedaMarcadoYElOtroPendiente() {
        let app = launch()
        app.revealPanelFAB().tap()
        let image = app.buttons["fab_image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5), "El menú del FAB no ofreció imagen (fab_image).")
        image.tap()
        let photos = app.buttons["image_source_photos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 15), "La hoja no abrió eligiendo (image_source_photos).")
        photos.tap()
        XCTAssertTrue(app.staticTexts["image_review_title"].waitForExistence(timeout: 15), "No apareció lo leído.")

        let rows = app.descendants(matching: .any).matching(identifier: "multi_review_row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "La foto con dos no enseñó la lista de varios.")
        XCTAssertEqual(rows.count, 2, "La lista de varios no trae los dos leídos.")
        adjuntar(app, "foto_dos_antes_de_convertir")

        // Despliega la primera fila y abre su editor completo.
        let firstRow = app.buttons.matching(identifier: "voice_draft_row").firstMatch
        XCTAssertTrue(firstRow.waitForHittable(timeout: 10), "La primera fila no se deja tocar (voice_draft_row).")
        firstRow.tap()
        let seeAll = app.buttons["esto_lei_ver_todo"].firstMatch
        XCTAssertTrue(seeAll.waitForHittable(timeout: 10), "La fila desplegada no ofrece «Ver todo».")
        seeAll.tap()

        app.chooseDraftGroupAndSave("Viaje a Cusco")
        let amount = app.textFields["group_expense_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 15), "No se abrió el formulario de gasto de grupo.")
        let save = app.buttons["group_expense_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "No apareció Guardar del gasto de grupo.")
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: save)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 8), .completed, "Guardar del gasto de grupo no se encendió.")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 10), "El formulario de grupo no se cerró al guardar.")

        // La convertida, marcada como guardada y con su grupo; la otra, pendiente; la hoja, abierta.
        let registered = app.descendants(matching: .any)["draft_registered_in_group_row"]
        XCTAssertTrue(registered.waitForExistence(timeout: 10), "La fila convertida no quedó marcada como registrada.")
        XCTAssertTrue(
            app.descendants(matching: .any)["draft_registered_in_group_saved"].exists,
            "La fila convertida no dice «Guardado».")
        XCTAssertEqual(rows.count, 1, "Tras convertir uno, la lista de varios no dejó solo el pendiente.")
        XCTAssertTrue(app.staticTexts["image_review_title"].exists, "La hoja se cerró con un registro aún pendiente.")
        adjuntar(app, "foto_dos_despues_de_convertir")
    }
}
