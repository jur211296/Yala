//
//  VozFotoAvisos23UITests.swift
//  YalaUITests
//
//  Nuevo registro 2.3 · voz y foto, avisos, «¡Listo!» y accesibilidad (decisiones 80, 62, 81, 65 y 83 de la discusión
//  del 9-nov, `docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). Un caso por punto:
//  - 80: la foto con varios registros enseña más de una fila sin estirar la hoja.
//  - 62: voz y foto anuncian a VoiceOver cada fase y los fallos (testigo DEBUG `entry_phase_announcement`).
//  - 81: «Volver a grabar» y «Otra foto» preguntan antes de descartar lo entendido; desde un fallo, no.
//  - 65: en «¡Listo!» una descripción larga ocupa dos líneas.
//  - 83: «Registrar otro» se toca por su identificador.
//  Los seams `-uitest-voice-result` e `-uitest-image-result` son los de `VoiceEntryReviewUITests` e
//  `ImageEntryReviewUITests`. Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class VozFotoAvisos23UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Abrir voz y foto

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, aiConsent: true, extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// Abre la voz con el perfil dado y toca Listo. No espera a nada más: cada caso espera lo suyo.
    private func openVoiceAndFinish(_ profile: String) -> XCUIApplication {
        let app = launch(["-uitest-voice-result", profile])
        app.revealPanelFAB().tap()
        let voice = app.buttons["fab_voice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 5), "El menú del FAB no ofreció voz (fab_voice).")
        voice.tap()
        let done = app.buttons["voice_done"]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "La hoja no abrió escuchando (voice_done).")
        XCTAssertTrue(waitForEnabled(done), "Con el seam no hay micro que esperar: Listo tiene que estar encendido.")
        done.tap()
        return app
    }

    /// Abre la foto con el perfil dado y toca Fotos (el seam lee los recibos de ejemplo).
    private func openPhotoAndRead(_ profile: String) -> XCUIApplication {
        let app = launch(["-uitest-image-result", profile])
        app.revealPanelFAB().tap()
        let image = app.buttons["fab_image"]
        XCTAssertTrue(image.waitForExistence(timeout: 5), "El menú del FAB no ofreció imagen (fab_image).")
        image.tap()
        let photos = app.buttons["image_source_photos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 15), "La hoja no abrió eligiendo (image_source_photos).")
        photos.tap()
        return app
    }

    private func waitForEnabled(_ element: XCUIElement) -> Bool {
        let enabled = NSPredicate(format: "enabled == true")
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: enabled, object: element)], timeout: 5) == .completed
    }

    private func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    // MARK: - 80 · La foto con varios registros

    /// Siete leídos: sin tocar la hoja, entre el título y los botones caben al menos dos filas enteras. En 2.3 la hoja
    /// se quedaba a media altura y enseñaba una (captura 43 de la revisión).
    func test_photoWithSeveral_showsMoreThanOneRow_withoutStretchingTheSheet() {
        let app = openPhotoAndRead("many")
        let title = app.staticTexts["image_review_title"]
        XCTAssertTrue(title.waitForExistence(timeout: 20), "Tras leer no apareció lo leído (image_review_title).")
        let actions = app.buttons["image_other_photo"]
        XCTAssertTrue(actions.waitForExistence(timeout: 5), "Falta «Otra foto».")

        let rows = app.buttons.matching(identifier: "multi_review_check")
        let fullyVisible = NSPredicate { _, _ in
            let top = title.frame.maxY
            let bottom = actions.frame.minY
            let visible = rows.allElementsBoundByIndex.filter { $0.frame.minY >= top && $0.frame.maxY <= bottom }
            return visible.count >= 2
        }
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: fullyVisible, object: nil)], timeout: 8)
        attachScreenshot(app, "80-foto-varios")
        XCTAssertEqual(result, .completed, "Con siete leídos la hoja tenía que enseñar más de una fila sin estirarla.")
    }

    // MARK: - 62 · Anuncios a VoiceOver

    private func announcement(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts["entry_phase_announcement"]
    }

    private func waitForAnnouncement(_ app: XCUIApplication, prefix: String, _ message: String) {
        let element = announcement(app)
        let matches = NSPredicate(format: "label BEGINSWITH %@", prefix)
        let result = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: matches, object: element)], timeout: 15)
        XCTAssertEqual(result, .completed, "\(message) (último anuncio: «\(element.exists ? element.label : "ninguno")»)")
    }

    /// Voz: al empezar dice que escucha y, al entender, el título de lo entendido.
    func test_voice_announcesListening_andWhatItUnderstood() {
        let app = launch(["-uitest-voice-result", "one"])
        app.revealPanelFAB().tap()
        let voice = app.buttons["fab_voice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 5), "El menú del FAB no ofreció voz (fab_voice).")
        voice.tap()
        waitForAnnouncement(app, prefix: "Escuchando", "Al abrir la voz tenía que anunciar que escucha.")
        let done = app.buttons["voice_done"]
        XCTAssertTrue(waitForEnabled(done), "Listo tenía que estar encendido.")
        done.tap()
        waitForAnnouncement(app, prefix: "Esto entendí", "Lo entendido tenía que anunciarse.")
    }

    /// Voz: un fallo anuncia su título y su explicación.
    func test_voice_announcesTheFailure() {
        let app = openVoiceAndFinish("trial-used-up")
        XCTAssertTrue(app.buttons["voice_trial_see_pro"].waitForExistence(timeout: 15), "No salió el fallo de prueba agotada.")
        waitForAnnouncement(app, prefix: "Ya usaste tus notas de voz de prueba. ", "El fallo tenía que anunciarse con su explicación.")
    }

    /// Foto: leer anuncia el paso y, al terminar, lo leído; un fallo, su título y su explicación.
    func test_photo_announcesWhatItRead_andTheFailure() {
        let app = openPhotoAndRead("two")
        XCTAssertTrue(app.staticTexts["image_review_title"].waitForExistence(timeout: 20), "Tras leer no apareció lo leído.")
        waitForAnnouncement(app, prefix: "Leí 2 registros", "Lo leído tenía que anunciarse.")

        let failing = openPhotoAndRead("none")
        XCTAssertTrue(failing.buttons["image_other_photo"].waitForExistence(timeout: 20), "Sin importe tenía que salir el fallo.")
        waitForAnnouncement(failing, prefix: "No encontré un importe. ", "El fallo tenía que anunciarse con su explicación.")
    }

    // MARK: - 81 · Preguntar antes de descartar

    /// «Volver a grabar» con lo entendido a la vista pregunta: «Seguir revisando» lo deja como estaba y «Descartar»
    /// vuelve a escuchar.
    func test_voice_recordAgain_asksBeforeDiscarding() {
        let app = openVoiceAndFinish("two")
        XCTAssertTrue(app.staticTexts["voice_review_title"].waitForExistence(timeout: 15), "No apareció lo entendido.")
        let again = app.buttons["voice_record_again"]
        again.tap()

        let keep = app.alerts.buttons["entry_discard_keep"].firstMatch
        XCTAssertTrue(keep.waitForExistence(timeout: 5), "«Volver a grabar» tenía que preguntar antes de descartar.")
        attachScreenshot(app, "81-voz-pregunta")
        keep.tap()
        XCTAssertTrue(app.staticTexts["voice_review_title"].waitForExistence(timeout: 5), "«Seguir revisando» tenía que dejarlo.")
        XCTAssertEqual(app.buttons.matching(identifier: "voice_draft_row").count, 2, "Lo entendido tenía que seguir entero.")

        again.tap()
        let discard = app.alerts.buttons["entry_discard_confirm"].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 5), "La segunda vez tenía que volver a preguntar.")
        discard.tap()
        XCTAssertTrue(app.buttons["voice_done"].waitForExistence(timeout: 10), "«Descartar» tenía que volver a escuchar.")
    }

    /// «Otra foto» con lo leído a la vista pregunta; desde un fallo no hay nada que perder y vuelve a elegir sin más.
    func test_photo_otherPhoto_asksBeforeDiscarding_butNotFromAFailure() {
        let app = openPhotoAndRead("two")
        XCTAssertTrue(app.staticTexts["image_review_title"].waitForExistence(timeout: 20), "No apareció lo leído.")
        let other = app.buttons["image_other_photo"]
        other.tap()

        let keep = app.alerts.buttons["entry_discard_keep"].firstMatch
        XCTAssertTrue(keep.waitForExistence(timeout: 5), "«Otra foto» tenía que preguntar antes de descartar.")
        attachScreenshot(app, "81-foto-pregunta")
        keep.tap()
        XCTAssertEqual(app.buttons.matching(identifier: "voice_draft_row").count, 2, "Lo leído tenía que seguir entero.")

        other.tap()
        let discard = app.alerts.buttons["entry_discard_confirm"].firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 5), "La segunda vez tenía que volver a preguntar.")
        discard.tap()
        XCTAssertTrue(app.buttons["image_source_photos"].waitForExistence(timeout: 10), "«Descartar» tenía que volver a elegir.")

        let failing = openPhotoAndRead("none")
        let otherFromFailure = failing.buttons["image_other_photo"]
        XCTAssertTrue(otherFromFailure.waitForExistence(timeout: 20), "Sin importe tenía que salir el fallo.")
        otherFromFailure.tap()
        XCTAssertTrue(failing.buttons["image_source_photos"].waitForExistence(timeout: 10), "Desde un fallo, «Otra foto» vuelve a elegir.")
        XCTAssertEqual(failing.alerts.count, 0, "Desde un fallo no hay nada que descartar: sin pregunta.")
    }

    // MARK: - 65 y 83 · «¡Listo!»

    private let longDescription = "Almuerzo de cumpleaños con todo el equipo de la oficina en el centro de Lima"

    /// Guarda un gasto con la descripción larga y espera a «¡Listo!».
    private func saveExpenseWithLongDescription() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "una-cuenta")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.revealPanelFAB().tap()
        let manual = app.buttons["fab_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se expandió el menú del FAB (fab_manual).")
        manual.tap()
        let note = app.textFields["new_transaction_note"]
        XCTAssertTrue(note.waitForExistence(timeout: 5), "No se abrió el formulario.")
        note.tap()
        note.typeText(longDescription)
        let amount = app.textFields["new_transaction_amount"]
        amount.tap()
        amount.typeText("120")
        app.chooseFirstSelectorRow(chip: "new_transaction_subcategory_chip", rowPrefix: "subcategory_selector_row_")
        app.buttons["new_transaction_save"].tap()
        XCTAssertTrue(app.buttons["transaction_success_accept"].waitForExistence(timeout: 10), "No salió «¡Listo!».")
        return app
    }

    /// La descripción larga ocupa dos líneas (antes, una con «…»): mide el doble que la fecha, que va en una.
    func test_success_longDescription_takesTwoLines() {
        let app = saveExpenseWithLongDescription()
        let value = app.staticTexts["transaction_success_description"]
        XCTAssertTrue(value.waitForExistence(timeout: 5), "Falta la descripción en «¡Listo!».")
        let date = app.staticTexts["transaction_success_date"]
        XCTAssertTrue(date.exists, "Falta la fecha en «¡Listo!».")
        XCTAssertEqual(value.label, longDescription, "La descripción tiene que ser la escrita.")
        // La fila queda bajo los botones en un iPhone de 6,3": se sube la tarjeta hasta verla entera.
        let accept = app.buttons["transaction_success_accept"]
        var tries = 0
        while value.frame.maxY > accept.frame.minY, tries < 4 {
            app.scrollViews.firstMatch.swipeUp(velocity: .slow)
            tries += 1
        }
        attachScreenshot(app, "65-listo-descripcion")
        let lines = value.frame.height / date.frame.height
        XCTAssertGreaterThan(lines, 1.6, "La descripción larga tenía que ocupar dos líneas (alto \(value.frame.height) frente a \(date.frame.height)).")
        XCTAssertLessThan(lines, 2.6, "Y no más de dos (alto \(value.frame.height) frente a \(date.frame.height)).")
    }

    /// «Registrar otro» se encuentra por su identificador y abre un registro nuevo vacío.
    func test_success_createAnother_hasItsIdentifier() {
        let app = saveExpenseWithLongDescription()
        let another = app.buttons["transaction_success_create_another"]
        XCTAssertTrue(another.waitForHittable(timeout: 5), "«Registrar otro» tenía que tener su identificador.")
        another.tap()
        let amount = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5), "«Registrar otro» tenía que abrir el formulario.")
        XCTAssertFalse(app.buttons["transaction_success_accept"].exists, "«¡Listo!» tenía que irse.")
    }
}
