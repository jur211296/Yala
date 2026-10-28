//
//  MultiCurrencyDiscoveryUITests.swift
//  YalaUITests
//
//  Encargo S12j (2026-10-28), tres apuntes de Jürgen:
//  - A · Al terminar de crear una cuenta, Yala ofrece añadirle una línea en otra divisa (antes solo se descubría
//    editando la cuenta). «Sí» abre «Añadir línea»; «Ahora no» cierra como siempre.
//  - B · «Tus finanzas»: desplegada, todas las tarjetas del carrusel miden lo que la más alta (la de varias divisas);
//    plegada, «Agregar» mide lo que una pastilla de cuenta.
//  - C · «¿Aceptar a X en el grupo?» es una alerta centrada con «Aceptar» destacado, no un globo de cristal que deja
//    ver la pantalla de detrás.
//  Convenciones: sin sleeps, scheme Yala Dev, ids y no textos. Con `YALA_CAPTURES` deja capturas en esa carpeta.
//

import XCTest

final class MultiCurrencyDiscoveryUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        guard let dir = ProcessInfo.processInfo.environment["YALA_CAPTURES"], !dir.isEmpty else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        try? app.screenshot().pngRepresentation.write(to: url)
    }

    // MARK: - A · Ofrecer otra divisa tras crear

    /// Abre «Nueva cuenta» desde Ajustes › Cuentas, la rellena y la guarda.
    private func createAccount(named name: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()
        app.openSettingsSection("profile_accounts")

        let addButton = app.buttons["accounts_add_button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "No apareció accounts_add_button.")
        addButton.tap()

        let nameField = app.textFields["account_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "No apareció el formulario de cuenta.")
        nameField.tap()
        nameField.typeText(name)
        let balanceField = app.textFields["account_balance_field"]
        XCTAssertTrue(balanceField.waitForExistence(timeout: 5), "No apareció account_balance_field.")
        balanceField.tap()
        balanceField.typeText("100")

        let save = app.buttons["toolbar_save_button"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "No apareció toolbar_save_button.")
        save.tap()
        return app
    }

    /// Tras guardar, la pregunta sale en la misma hoja y «Sí» abre «Añadir línea» sobre la cuenta recién creada.
    func test_newAccount_offersALineInAnotherCurrency_andYesOpensAddLine() {
        let app = createAccount(named: "QA Oferta Sí")

        let offer = app.descendants(matching: .any)["account_line_offer"]
        let appeared = offer.waitForExistence(timeout: 8)
        capture(app, "a-tras-crear")
        XCTAssertTrue(appeared, "Tras crear la cuenta no se ofreció añadir otra divisa.")
        // Ya guardada: el formulario no puede volver a guardarla.
        XCTAssertFalse(app.buttons["toolbar_save_button"].exists, "Con la pregunta a la vista sigue el «Guardar».")

        let yes = app.buttons["account_line_offer_add"]
        XCTAssertTrue(yes.waitForHittable(timeout: 5))
        yes.tap()

        XCTAssertTrue(app.buttons["account_line_add_confirm"].waitForExistence(timeout: 8),
                      "«Añadir línea» no se abrió sobre la cuenta nueva.")
        capture(app, "a-anadir-linea")
    }

    /// «Ahora no» deja la cuenta creada y cierra el formulario, como antes.
    func test_newAccount_notNow_closesTheForm() {
        let name = "QA Oferta No"
        let app = createAccount(named: name)

        let skip = app.buttons["account_line_offer_skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 8), "Tras crear la cuenta no se ofreció añadir otra divisa.")
        XCTAssertTrue(skip.waitForHittable(timeout: 5))
        skip.tap()

        XCTAssertTrue(app.buttons["accounts_row_\(name)"].waitForExistence(timeout: 8),
                      "La cuenta no aparece en la lista tras «Ahora no».")
        XCTAssertFalse(app.descendants(matching: .any)["account_line_offer"].exists, "La pregunta sigue a la vista.")
    }

    // MARK: - B · «Tus finanzas»

    private func launchPanelWithCard() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "tarjeta-dos-lineas")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 10), "La app no llegó al Panel.")
        return app
    }

    /// Desplegada: la tarjeta de «Visa QA» (dos divisas y total) marca el alto, y las demás —«Agregar cuenta»
    /// incluida— lo igualan.
    func test_panel_expanded_everyCardMatchesTheTallest() {
        let app = launchPanelWithCard()
        let first = app.buttons["panel_account_card_0"]
        if !first.waitForExistence(timeout: 3) {
            app.buttons["panel_panorama_header"].tap()
        }
        XCTAssertTrue(first.waitForExistence(timeout: 5), "No apareció la primera tarjeta.")
        capture(app, "b-desplegada")

        var heights: [CGFloat] = []
        var index = 0
        while app.buttons["panel_account_card_\(index)"].exists {
            heights.append(app.buttons["panel_account_card_\(index)"].frame.height)
            index += 1
        }
        XCTAssertEqual(heights.count, 3, "El seed trae tres tarjetas: \(heights).")
        let add = app.buttons["panel_add_account_card"]
        XCTAssertTrue(add.exists, "«Agregar cuenta» no está en el carrusel.")
        heights.append(add.frame.height)

        let tallest = heights.max() ?? 0
        for height in heights {
            XCTAssertEqual(height, tallest, accuracy: 1, "Hay una tarjeta más baja que la de varias divisas: \(heights).")
        }
        // Para la captura: la tarjeta de varias divisas y «Agregar cuenta» quedan a la derecha.
        first.swipeLeft()
        capture(app, "b-desplegada-2")
        let second = app.buttons["panel_account_card_1"]
        if second.isHittable {
            second.swipeLeft()
            capture(app, "b-desplegada-3")
        }
    }

    /// Plegada: «Agregar» mide lo que la pastilla de una cuenta.
    func test_panel_collapsed_addChipMatchesAnAccountChip() {
        let app = launchPanelWithCard()
        if app.buttons["panel_account_card_0"].waitForExistence(timeout: 3) {
            app.buttons["panel_panorama_header"].tap()
        }
        let chip = app.buttons["panel_account_chip_0"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "No salieron los chips.")
        let add = app.buttons["panel_account_chip_add"]
        XCTAssertTrue(add.exists, "No está el chip de «Agregar».")
        capture(app, "b-plegada")

        XCTAssertEqual(add.frame.height, chip.frame.height, accuracy: 1,
                       "«Agregar» (\(add.frame.height)) no mide lo que una pastilla de cuenta (\(chip.frame.height)).")
        // Para la captura: «Agregar» va al final de la fila.
        chip.swipeLeft()
        capture(app, "b-plegada-2")
    }

    // MARK: - C · Aceptar a un miembro

    /// «Aceptar» en la tarjeta de la solicitud pregunta con una alerta del sistema (centrada, con su velo), no con un
    /// globo anclado. Aceptar de verdad llama al servidor: el caso solo comprueba la pregunta y no la contesta con «Sí».
    func test_acceptMember_asksWithACenteredAlert() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos-sin-flag", deeplink: "groups", icloudIdentity: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente.")
        let card = app.buttons["group_card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20))
        XCTAssertTrue(card.waitForHittable(timeout: 10))
        card.tap()

        let review = app.buttons["group_join_requests_review"]
        XCTAssertTrue(review.waitForExistence(timeout: 20), "La solicitud de Carla no se ve dentro del grupo.")
        XCTAssertTrue(review.waitForHittable(timeout: 10))
        review.tap()

        let approve = app.buttons["group_member_approve_Carla"]
        XCTAssertTrue(approve.waitForExistence(timeout: 10), "«Revisar» no llevó a la tarjeta de Carla.")
        XCTAssertTrue(approve.waitForHittable(timeout: 10))
        approve.tap()

        let alert = app.alerts.firstMatch
        let appeared = alert.waitForExistence(timeout: 8)
        capture(app, "c-aceptar-miembro")
        XCTAssertTrue(appeared, "«Aceptar» no preguntó con una alerta.")
        XCTAssertGreaterThanOrEqual(alert.buttons.count, 2, "La alerta no trae «Aceptar» y «Cancelar».")
    }
}
