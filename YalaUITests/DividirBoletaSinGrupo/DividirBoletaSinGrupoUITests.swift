//
//  DividirBoletaSinGrupoUITests.swift
//  YalaUITests
//
//  «Dividir una boleta» sin grupo (maqueta 1A, 26-nov-2026), de punta a punta. `-uitest-receipt-split boleta` hace que
//  Fotos «elija» el recibo de ejemplo y que la lectura conteste sin red la boleta de la maqueta: Cevichería El Muelle,
//  7 líneas para Yo, Carla, Martín y Rocío, con la propina del 10 % sin incluir.
//
//  Lo que fija: las dos entradas (hoja de foto personal y Grupos), los nombres al vuelo, por líneas y por igual al
//  céntimo, «¿Quién pagó?» que cambia la cifra, los dos tipos y los tres diseños de la imagen, mi parte a la Bandeja,
//  «Listo» que cierra, y que no aparece ningún grupo nuevo.
//
//  Las capturas del recorrido (claro y oscuro) se piden con `CAPTURA_OSCURO=1` en el entorno del runner.
//

import XCTest

final class DividirBoletaSinGrupoUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private var themeArguments: [String] {
        ProcessInfo.processInfo.environment["CAPTURA_OSCURO"] == "1" ? [] : ["-userTheme", "1"]
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Escribe los nombres con Intro: cada uno entra al soltarlo y el campo sigue con el foco.
    private func addPeople(_ names: [String], in app: XCUIApplication) {
        let field = app.textFields["dividir_boleta_name_field"]
        XCTAssertTrue(field.waitForHittable(timeout: 10), "Falta el campo del nombre.")
        field.tap()
        // Uno por vez: tecleados de un tirón, las letras del siguiente llegaban mientras el campo se vaciaba tras el
        // Intro y se perdían («Rocío» entraba como «ío»).
        for name in names {
            field.typeText("\(name)\n")
            XCTAssertTrue(app.descendants(matching: .any)["dividir_boleta_person_\(name)"].waitForExistence(timeout: 5),
                          "No entró \(name).")
        }
    }

    private func split(_ app: XCUIApplication) {
        let button = app.buttons["dividir_boleta_split"]
        XCTAssertTrue(button.waitForHittable(timeout: 10), "Falta «Repartir».")
        button.tap()
        XCTAssertTrue(app.buttons["dividir_boleta_review_continue"].waitForExistence(timeout: 20), "No llegó la revisión.")
    }

    /// La revisión es una lista que monta solo lo visible: baja con arrastres cortos hasta que la fila exista.
    private func label(_ app: XCUIApplication, _ id: String) -> String {
        let element = app.descendants(matching: .any)[id].firstMatch
        for _ in 0..<8 where !element.exists {
            let list = app.collectionViews.firstMatch
            let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            start.press(forDuration: 0.05, thenDragTo: list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
        }
        return element.exists ? element.label : "(sin \(id))"
    }

    // MARK: - Desde la foto personal

    func test_personal_byLines_payerAndImage_andMyShareToInbox() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, deeplink: "records", aiConsent: true,
                            extraArguments: ["-uitest-receipt-split", "boleta", "-userName", "Jürgen"] + themeArguments)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        let action = app.buttons["stats_action_image"]
        XCTAssertTrue(action.waitForHittable(timeout: 15), "Falta la acción de foto de Registros.")
        action.tap()

        let entry = app.buttons["image_dividir_boleta"]
        XCTAssertTrue(entry.waitForHittable(timeout: 15), "Falta «Dividir una boleta» bajo las fichas.")
        attach(app, "01-entrada-personal")
        entry.tap()

        let photos = app.buttons["dividir_boleta_source_photos"]
        XCTAssertTrue(photos.waitForHittable(timeout: 10), "La hoja no abrió en Cámara, Fotos y Archivo.")
        attach(app, "02-foto")
        photos.tap()

        addPeople(["Carla", "Martín", "Rocío"], in: app)
        attach(app, "03-entre-quienes")
        split(app)
        attach(app, "04-revision")

        // Por líneas, sin la propina: Yo 62,00 · Carla 49,00 · Martín 61,00 · Rocío 65,00.
        XCTAssertTrue(label(app, "dividir_boleta_share_me").contains("62.00"), label(app, "dividir_boleta_share_me"))
        XCTAssertTrue(label(app, "dividir_boleta_share_Rocío").contains("65.00"), label(app, "dividir_boleta_share_Rocío"))
        app.buttons["dividir_boleta_review_continue"].tap()

        let hero = app.descendants(matching: .any)["dividir_boleta_hero_amount"]
        XCTAssertTrue(hero.waitForExistence(timeout: 10), "No llegó el resultado.")
        XCTAssertTrue(hero.label.contains("175.00"), "Pagué yo: me deben 237 − 62. \(hero.label)")
        XCTAssertTrue(app.descendants(matching: .any)["dividir_boleta_image_preview"].waitForExistence(timeout: 10),
                      "Falta la vista previa de la imagen.")
        XCTAssertTrue(app.buttons["dividir_boleta_done"].exists, "«Listo» va arriba a la derecha.")
        attach(app, "05-resultado-pague-yo")

        // Pagó Carla: ahora la cifra es lo que yo le debo.
        app.buttons["dividir_boleta_payer"].tap()
        let carla = app.buttons["Carla"].firstMatch
        XCTAssertTrue(carla.waitForHittable(timeout: 5), "El selector de quién pagó no lista a Carla.")
        carla.tap()
        XCTAssertTrue(hero.label.contains("62.00"), "Pagó Carla: le debo mi parte. \(hero.label)")
        attach(app, "06-resultado-pago-carla")

        // Los dos tipos y los tres diseños.
        let kind = app.segmentedControls["dividir_boleta_image_kind"]
        XCTAssertTrue(kind.waitForExistence(timeout: 5))
        app.scrollViews["dividir_boleta_result"].swipeUp()
        for style in ["light", "brand", "receipt"] {
            let chip = app.buttons["dividir_boleta_style_\(style)"]
            if !chip.isHittable { app.swipeUp() }
            XCTAssertTrue(chip.waitForHittable(timeout: 5), "Falta el diseño \(style).")
            chip.tap()
            kind.buttons.element(boundBy: 0).tap()
            attach(app, "07-imagen-\(style)-resumen")
            kind.buttons.element(boundBy: 1).tap()
            attach(app, "08-imagen-\(style)-detalle")
        }

        // Mi parte a la Bandeja: una vez, y queda dicho.
        let inbox = app.buttons["dividir_boleta_send_inbox"]
        XCTAssertTrue(inbox.waitForHittable(timeout: 5), "En Yala completo se puede mandar mi parte a la Bandeja.")
        inbox.tap()
        XCTAssertTrue(app.descendants(matching: .any)["dividir_boleta_registration_status"].waitForExistence(timeout: 5),
                      "Tras mandarla, la hoja dice que quedó en la Bandeja.")
        attach(app, "09-mi-parte-en-bandeja")

        app.buttons["dividir_boleta_done"].tap()
        XCTAssertTrue(app.buttons["stats_action_image"].waitForHittable(timeout: 10),
                      "«Listo» cierra la boleta y también la hoja de foto.")
        XCTAssertFalse(app.buttons["image_source_photos"].exists)
    }

    // MARK: - Desde Grupos

    func test_groups_equalSplit_noNewGroup() {
        let app = XCUIApplication()
        // Nombre vacío a propósito: el perfil sin nombre es el caso que pide escribirlo para la imagen.
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups", aiConsent: true,
                            extraArguments: ["-uitest-receipt-split", "boleta", "-userName", ""] + themeArguments)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        let cards = app.descendants(matching: .any).matching(identifier: "group_card")
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 15), "Falta el grupo sembrado.")
        let groupsBefore = cards.count

        let entry = app.buttons["groups_dividir_boleta"]
        XCTAssertTrue(entry.waitForHittable(timeout: 10), "Falta «Dividir una boleta» bajo la fila de Grupos.")
        attach(app, "10-entrada-grupos")
        entry.tap()
        let photos = app.buttons["dividir_boleta_source_photos"]
        XCTAssertTrue(photos.waitForHittable(timeout: 10))
        photos.tap()

        addPeople(["Carla", "Martín", "Rocío"], in: app)
        app.segmentedControls["dividir_boleta_mode"].buttons.element(boundBy: 0).tap()
        split(app)
        // Por igual: 237,00 entre cuatro, 59,25 cada uno.
        for id in ["dividir_boleta_share_me", "dividir_boleta_share_Carla", "dividir_boleta_share_Rocío"] {
            XCTAssertTrue(label(app, id).contains("59.25"), "\(id): \(label(app, id))")
        }
        attach(app, "11-revision-por-igual")
        app.buttons["dividir_boleta_review_continue"].tap()
        let hero = app.descendants(matching: .any)["dividir_boleta_hero_amount"]
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        XCTAssertTrue(hero.label.contains("177.75"), "Me deben tres partes de 59,25. \(hero.label)")
        attach(app, "12-resultado-grupos")

        // Sin nombre en el perfil, la imagen lo pide antes de salir: va a otras personas y no puede decir «Yo».
        let name = app.textFields["dividir_boleta_my_name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "Sin nombre en el perfil, falta el campo del nombre.")
        // Siempre se sube: con la barra de abajo encima, `isHittable` dice que sí y el toque cae en la barra.
        app.scrollViews["dividir_boleta_result"].swipeUp()
        name.tap()
        name.typeText("Jürgen\n")
        XCTAssertTrue(app.descendants(matching: .any)["dividir_boleta_image_preview"].waitForExistence(timeout: 10),
                      "Con el nombre escrito, sale la vista previa.")
        XCTAssertFalse(name.exists, "El nombre se guarda en el perfil y el campo ya no hace falta.")
        attach(app, "13-imagen-con-nombre")

        let share = app.buttons["dividir_boleta_share"]
        XCTAssertTrue(share.waitForHittable(timeout: 10), "Falta «Compartir imagen».")

        app.buttons["dividir_boleta_done"].tap()
        XCTAssertTrue(entry.waitForHittable(timeout: 10), "«Listo» vuelve a Grupos.")
        XCTAssertEqual(cards.count, groupsBefore, "Dividir una boleta no crea ningún grupo.")
    }
}
