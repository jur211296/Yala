//
//  ConectaTuIAUITests.swift
//  YalaUITests
//
//  «Conecta tu IA» (2.3, opción C de Jürgen del 23-nov):
//  - Ajustes › Tu IA sin la cuenta de Yala: lo dice primero y los pasos salen apagados; ChatGPT avisa del plan de pago.
//  - Con el conector de mentira (`-uitest-conecta-tu-ia-demo`): Claude y ChatGPT conectados, y «Desconectar» quita uno
//    tras confirmar.
//  - La Bandeja vacía (`-uitest-inbox-empty`) tiene la puerta «Apunta desde tu IA», que abre la página en una hoja.
//  - Con borradores de una IA (`-uitest-inbox-ai-drafts`) la fila dice «Claude» o «ChatGPT», sale el chip «De tu IA» y
//    la puerta ya no.
//  Scheme Yala Dev, seed `minimal`, la app en español (`launchForUITest`).
//

import XCTest

final class ConectaTuIAUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    private func openTuIA(_ app: XCUIApplication) {
        app.openProfile()
        let row = app.buttons["profile_conecta_tu_ia"]
        var swipes = 0
        while !(row.exists && row.isHittable) && swipes < 10 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(row.exists, "Falta la fila «Tu IA» en Ajustes.")
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["conecta_ia_header"].firstMatch.waitForExistence(timeout: 10),
                      "«Tu IA» no abrió «Conecta tu IA».")
    }

    private func openInbox(_ app: XCUIApplication) {
        let inbox = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inbox.waitForExistence(timeout: 10), "No apareció el botón de la Bandeja en el Panel.")
        inbox.tap()
    }

    func test_ajustes_sinLaCuentaDeYala_loDicePrimero_yChatGPTAvisaDelPlan() {
        let app = launch()
        openTuIA(app)
        XCTAssertTrue(app.descendants(matching: .any)["conecta_ia_needs_account"].firstMatch.waitForExistence(timeout: 5),
                      "Sin la cuenta de Yala, la página tiene que decir qué falta.")
        XCTAssertTrue(app.descendants(matching: .any)["conecta_ia_step_1"].firstMatch.exists, "Faltan los pasos.")
        XCTAssertFalse(app.buttons["conecta_ia_copy"].isEnabled, "Sin la cuenta, «Copiar» va apagado.")
        XCTAssertFalse(app.descendants(matching: .any)["conecta_ia_row"].firstMatch.exists,
                       "Sin la cuenta no hay lista de conectadas.")
        capture(app, "despues-1-ajustes-tu-ia-sin-cuenta")
        app.segmentedControls["conecta_ia_provider"].buttons["ChatGPT"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["conecta_ia_chatgpt_note"].firstMatch.waitForExistence(timeout: 5),
                      "ChatGPT tiene que avisar del plan de pago y el modo desarrollador.")
    }

    func test_ajustes_conLaDemo_listaLasConectadas_yDesconectarQuitaUna() {
        let app = launch(["-uitest-conecta-tu-ia-demo"])
        openTuIA(app)
        XCTAssertFalse(app.descendants(matching: .any)["conecta_ia_needs_account"].firstMatch.exists,
                       "Con la cuenta de Yala no hay aviso.")
        let claude = app.buttons["conecta_ia_disconnect_demoClaude01"]
        var swipes = 0
        while !(claude.exists && claude.isHittable) && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(claude.exists, "Falta «Desconectar» de Claude.")
        XCTAssertTrue(app.buttons["conecta_ia_disconnect_demoChatGPT1"].exists, "Falta ChatGPT en la lista.")
        capture(app, "despues-2-ajustes-tu-ia-conectadas")
        claude.tap()
        let confirm = app.alerts.buttons["Desconectar"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Desconectar tiene que preguntar antes.")
        confirm.tap()
        XCTAssertTrue(claude.waitForNonExistence(timeout: 10), "Claude sigue en la lista tras desconectar.")
        XCTAssertTrue(app.buttons["conecta_ia_disconnect_demoChatGPT1"].exists, "ChatGPT no se tenía que ir.")
    }

    func test_bandejaVacia_tieneLaPuerta_queAbreLaPaginaEnUnaHoja() {
        let app = launch(["-uitest-inbox-empty"])
        openInbox(app)
        let card = app.descendants(matching: .any)["inbox_conecta_ia_card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "La Bandeja vacía tiene que ofrecer «Apunta desde tu IA».")
        capture(app, "despues-3-bandeja-vacia-puerta")
        app.buttons["inbox_conecta_ia_connect"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["conecta_ia_header"].firstMatch.waitForExistence(timeout: 10),
                      "«Conectar» no abrió la página.")
        let done = app.buttons["conecta_ia_done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "La hoja necesita «Listo».")
        done.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Al cerrar, vuelve la Bandeja.")
    }

    func test_bandeja_conBorradoresDeUnaIA_diceSuNombre_yFiltraDeTuIA() {
        let app = launch(["-uitest-inbox-ai-drafts"])
        openInbox(app)
        XCTAssertTrue(app.staticTexts["Claude"].firstMatch.waitForExistence(timeout: 10), "La fila tiene que decir «Claude».")
        XCTAssertTrue(app.staticTexts["ChatGPT"].firstMatch.exists, "La fila tiene que decir «ChatGPT».")
        XCTAssertFalse(app.staticTexts["Tu IA"].firstMatch.exists, "Con el nombre conocido no sale «Tu IA».")
        let chip = app.buttons["inbox_filter_fromAI"]
        XCTAssertTrue(chip.exists, "Con borradores de una IA sale el chip «De tu IA».")
        XCTAssertFalse(app.descendants(matching: .any)["inbox_conecta_ia_card"].firstMatch.exists,
                       "Quien ya usa su IA no necesita la puerta.")
        capture(app, "despues-4-bandeja-claude-y-filtro")
        chip.tap()
        XCTAssertTrue(app.staticTexts["Claude"].firstMatch.waitForExistence(timeout: 5), "El filtro tiene que dejar lo de la IA.")
    }

    func test_bandejaSinNadaDeUnaIA_noTieneElChip() {
        let app = launch()
        openInbox(app)
        XCTAssertTrue(app.buttons["inbox_filter_pending"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["inbox_filter_fromAI"].exists, "Sin borradores de una IA, el chip no sale.")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
