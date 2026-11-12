//
//  YalaIASinConexionUITests.swift
//  YalaUITests
//
//  Decisión 42 de la revisión 2.3 (9-nov, F1 + F3): Yala IA sin conexión.
//
//  - F1: sin conexión, el chat lo dice al abrir («Necesitas conexión para usar Yala IA.») y ofrece «Nuevo registro»,
//    aunque las sugerencias del día ya estén puestas. Con red y el servidor caído, el mensaje de siempre.
//  - F3: sin Pro y sin conexión, el muro de Yala IA no deja un botón apagado y «No pudimos cargar los precios»: dice
//    cuándo se verá el precio y ofrece lo gratis (apuntar a mano; Siri con el modelo del propio iPhone).
//
//  `-uitest-network-offline` deja la app sin red (`NetworkMonitor`); `-uitest-chat-suggestions` pone las sugerencias
//  del día, que es el caso que antes ocultaba la falta de red. La lógica la fija `YalaIASinConexionTests`.
//

import XCTest

final class YalaIASinConexionUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(pro: Bool, aiChatReady: Bool = false, extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: pro, deeplink: "records", aiChatReady: aiChatReady, extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        let entry = app.buttons["stats_action_ai"]
        XCTAssertTrue(entry.waitForExistence(timeout: 15), "No aparece la entrada de Yala IA en Registros.")
        XCTAssertTrue(entry.waitForHittable(timeout: 10), "La entrada de Yala IA no se puede tocar.")
        entry.tap()
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertNewRecordOpens(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.buttons["new_transaction_save"].waitForExistence(timeout: 10),
                      "«Apuntar a mano» no abrió Nuevo registro.", file: file, line: line)
    }

    // MARK: - F1 · el chat

    /// Sin conexión y con las sugerencias del día puestas: antes el chat parecía vivo y la pregunta fallaba al enviar.
    /// Ahora lo dice al abrir, apaga la caja y «Nuevo registro» abre el formulario.
    func test_chatSinConexion_loDiceAlAbrir_yNuevoRegistroAbreElFormulario() {
        let app = launch(pro: true, aiChatReady: true,
                         extra: ["-uitest-chat-suggestions", "-uitest-network-offline"])
        let input = app.textFields["chat_input"]
        XCTAssertTrue(input.waitForExistence(timeout: 10), "No se abrió Yala IA.")

        let notice = app.staticTexts["chat_offline_title"]
        XCTAssertTrue(notice.waitForExistence(timeout: 10), "Sin conexión, el chat no lo dice al abrir.")
        capture(app, "despues-1-chat-sin-conexion")
        XCTAssertEqual(notice.label, "Necesitas conexión para usar Yala IA.")
        XCTAssertFalse(app.buttons.matching(identifier: "chat_suggestion").firstMatch.exists,
                       "Sin conexión no se ofrecen sugerencias que no se pueden enviar.")
        XCTAssertFalse(input.isEnabled, "Sin conexión, la caja de escribir tiene que estar apagada.")

        let newRecord = app.buttons["chat_offline_new_record"]
        XCTAssertTrue(newRecord.waitForHittable(timeout: 5), "Falta la salida «Nuevo registro».")
        newRecord.tap()
        assertNewRecordOpens(app)
    }

    /// Control: con red y sin servidor, el mensaje de siempre y ni rastro del de «sin conexión».
    func test_chatConRedYServidorCaido_dejaElMensajeDeSiempre() {
        let app = launch(pro: true, aiChatReady: true, extra: [])
        let unavailable = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "no está disponible"))
            .firstMatch
        XCTAssertTrue(unavailable.waitForExistence(timeout: 40), "Sin servidor tenía que salir el mensaje de siempre.")
        capture(app, "chat-servidor-caido")
        XCTAssertFalse(app.staticTexts["chat_offline_title"].exists, "Con red no se dice «sin conexión».")
    }

    // MARK: - F3 · el muro de Yala IA

    /// Sin Pro y sin conexión: nada apagado. Dice cuándo se verá el precio, ofrece apuntar a mano y, con el modelo del
    /// iPhone listo, Siri. «Apuntarlo a mano» abre el formulario.
    func test_muroSinConexion_diceCuandoSeVeraElPrecio_yOfreceLoGratis() {
        let app = launch(pro: false, extra: ["-uitest-network-offline", "-uitest-siri-model", "available"])
        XCTAssertTrue(app.staticTexts["upgrade_prompt_title"].waitForExistence(timeout: 10), "No salió el muro.")
        // Deja asentar la carga de precios antes de la foto: sin red falla en el acto.
        _ = app.staticTexts["upgrade_prompt_offline_prices"].waitForExistence(timeout: 10)
        capture(app, "despues-2-muro-sin-conexion")

        XCTAssertTrue(app.staticTexts["upgrade_prompt_offline_prices"].exists, "Falta cuándo se verá el precio.")
        XCTAssertFalse(app.staticTexts["subscription_prices_unavailable"].exists,
                       "Sin conexión no se dice «No pudimos cargar los precios».")
        XCTAssertFalse(app.buttons["upgrade_prompt_cta"].exists, "Sin precios no queda un botón de compra apagado.")
        XCTAssertTrue(app.descendants(matching: .any)["upgrade_prompt_offline_siri"].exists,
                      "Con el modelo del iPhone listo, Siri es gratis y se ofrece.")
        XCTAssertTrue(app.buttons["upgrade_prompt_not_now"].exists, "Falta «Ahora no».")

        let manual = app.buttons["upgrade_prompt_offline_manual"]
        XCTAssertTrue(manual.waitForHittable(timeout: 5), "Falta «Apuntarlo a mano».")
        manual.tap()
        assertNewRecordOpens(app)
    }

    /// Sin el modelo del iPhone, Siri no es gratis: no se ofrece. Apuntar a mano sí. El estado se finge: el simulador de
    /// una Mac con Apple Intelligence tiene el modelo listo.
    func test_muroSinConexion_sinModeloPropio_noOfreceSiri() {
        let app = launch(pro: false, extra: ["-uitest-network-offline", "-uitest-siri-model", "deviceNotEligible"])
        XCTAssertTrue(app.staticTexts["upgrade_prompt_offline_prices"].waitForExistence(timeout: 15),
                      "Falta cuándo se verá el precio.")
        XCTAssertTrue(app.buttons["upgrade_prompt_offline_manual"].exists, "Falta «Apuntarlo a mano».")
        XCTAssertFalse(app.descendants(matching: .any)["upgrade_prompt_offline_siri"].exists,
                       "Sin el modelo del iPhone, Siri pide Pro: no se ofrece como gratis.")
    }
}
