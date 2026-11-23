//
//  WelcomeTrasCuentaListaUITests.swift
//  YalaUITests
//
//  Ticket `welcome-returns-after-the-account-is-ready` (device-QA del 13-nov, «ERROR GRAVE»): tras «¡Tu cuenta está
//  lista!» Yala volvía a la bienvenida y había que reabrirla. Decisión de Jürgen del 13-nov: después de que la cuenta
//  queda lista, Yala nunca vuelve a la bienvenida ni pide reabrir.
//
//  La causa (medida con trazas en el iPhone el 14-nov, card c8i9): el respaldo del `onDismiss` del cover leía el
//  onboarding de un `@Binding` capturado al presentarse (`false`), y `onAdoptStarted` lo marca con el cover abierto. Los
//  cuatro casos recorren el final de cada entrada por los callbacks de producción (seam
//  `-uitest-unified-access-phase`, sin red) y afirman que se llega a la app y que la bienvenida no vuelve después.
//

import XCTest

final class WelcomeTrasCuentaListaUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Lo que enseña la bienvenida en cualquiera de sus pantallas de entrada (vitrina, Hero, elector).
    private func welcomeEntryScreen(_ app: XCUIApplication) -> XCUIElement {
        let ids = ["welcome_access_icloud", "welcome_access_google", "welcome_showcase_title", "welcome_hero_cta",
                   "welcome_existing_google"]
        let predicate = NSPredicate(format: "identifier IN %@", ids)
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    /// Se llegó a la app y la bienvenida no vuelve. El respaldo roto la reabría justo después de cerrar el cover, así que
    /// la ausencia se vigila unos segundos y no en el acto.
    private func assertLandsInTheAppAndStays(_ app: XCUIApplication, _ what: String,
                                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.waitForRootNavigation(timeout: 30),
                      "\(what): no se llegó a la app (ni barra de pestañas ni barra lateral).", file: file, line: line)
        XCTAssertFalse(welcomeEntryScreen(app).waitForExistence(timeout: 6),
                       "\(what): tras entrar, Yala volvió a la bienvenida.", file: file, line: line)
        XCTAssertTrue(app.waitForRootNavigation(timeout: 2),
                      "\(what): la app no siguió a la vista.", file: file, line: line)
    }

    /// Las tres preguntas de la conversación, con «Solo gastos» para terminar rápido.
    private func answerTheConversation(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let field = app.textFields["welcome_chat_name_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 20), "No llegó la conversación.", file: file, line: line)
        field.tap()
        field.typeText("Ana")
        app.buttons["welcome_chat_name_send"].tap()
        let currency = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "welcome_chat_currency_"))
            .firstMatch
        XCTAssertTrue(currency.waitForExistence(timeout: 10), "No llegó la pregunta de la moneda.", file: file, line: line)
        currency.tap()
        let expensesOnly = app.buttons["welcome_chat_tracking_expenses"]
        XCTAssertTrue(expensesOnly.waitForExistence(timeout: 10), "No llegó la pregunta de qué llevar.",
                      file: file, line: line)
        expensesOnly.tap()
        let enter = app.buttons["welcome_chat_enter"]
        XCTAssertTrue(enter.waitForExistence(timeout: 10), "La conversación no terminó.", file: file, line: line)
        enter.tap()
    }

    // El botón de «listo» sale con el id del contenedor (`welcome_reentry_ready`, `welcome_born_cloud_ready`): el `_cta` que
    // declara la vista lo pisa el del bloque (medido en el árbol el 2026-11-22; `.claude/rules/testing.md`).

    /// El caso del ticket: re-entrada a una cuenta del Modo Nube en la primera entrada tras instalar. «Empezar» de
    /// «¡Tu cuenta está lista!» entra en la app. Con el respaldo leyendo el `@Binding`, volvía a la vitrina.
    func test_modoNube_reentrada_empezarEntraEnLaApp() throws {
        let app = XCUIApplication()
        // Los accesos de Google y Apple llevan a la entrada solo con App Attest, que el simulador no tiene: se finge.
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil, fakeAttestSupport: true,
                            extraArguments: [XCUIApplication.welcomeProvidersArgument,
                                             "-uitest-unified-access-phase", "reentry-ready"])
        XCTAssertTrue(app.waitForWelcomeShowcase())
        app.buttons["welcome_access_google"].tap()

        let empezar = app.buttons["welcome_reentry_ready"]
        XCTAssertTrue(empezar.waitForExistence(timeout: 15), "No salió «¡Tu cuenta está lista!».")
        empezar.tap()

        assertLandsInTheAppAndStays(app, "Re-entrada en Modo Nube")
    }

    /// Cuenta nueva en el Modo Nube: «Creamos tu cuenta» sigue a la conversación y de ahí a la app, sin la bienvenida.
    func test_modoNube_cuentaNueva_pasaPorLaConversacionYEntra() throws {
        let app = XCUIApplication()
        // Los accesos de Google y Apple llevan a la entrada solo con App Attest, que el simulador no tiene: se finge.
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil, fakeAttestSupport: true,
                            extraArguments: [XCUIApplication.welcomeProvidersArgument,
                                             "-uitest-unified-access-phase", "born-ready"])
        XCTAssertTrue(app.waitForWelcomeShowcase())
        app.buttons["welcome_access_google"].tap()

        let seguir = app.buttons["welcome_born_cloud_ready"]
        XCTAssertTrue(seguir.waitForExistence(timeout: 15), "No salió «Creamos tu cuenta».")
        seguir.tap()
        XCTAssertFalse(welcomeEntryScreen(app).waitForExistence(timeout: 3),
                       "Tras «Creamos tu cuenta», Yala volvió a la bienvenida en vez de seguir a la conversación.")

        answerTheConversation(app)
        assertLandsInTheAppAndStays(app, "Cuenta nueva en Modo Nube")
    }

    /// Cuenta nueva con iCloud privado: la vitrina, iCloud sin datos, la conversación y la app.
    func test_iCloudPrivado_cuentaNueva_entraYNoVuelveALaBienvenida() throws {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil)
        XCTAssertTrue(app.waitForWelcomeShowcase())
        app.buttons["welcome_access_icloud"].tap()

        answerTheConversation(app)
        XCTAssertTrue(app.buttons["panel_account_chip_0"].waitForExistence(timeout: 20),
                      "No llegó al Panel con la cuenta de gastos.")
        assertLandsInTheAppAndStays(app, "Cuenta nueva con iCloud privado")
    }

    /// Cuenta de solo grupos: el servidor la clasifica así, la entrada pasa a la puerta de Grupos y, creado el primer
    /// grupo, aterriza en Grupos sin la bienvenida. La sesión y el consentimiento se fingen sin red.
    func test_soloGrupos_creaSuGrupoYAterrizaEnGrupos() throws {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil,
                            cloudSession: true, groupsConsent: true, groupsEducativo: true, fakeAttestSupport: true,
                            extraArguments: [XCUIApplication.welcomeProvidersArgument,
                                             "-uitest-unified-access-phase", "groups-only"])
        XCTAssertTrue(app.waitForWelcomeShowcase())
        app.buttons["welcome_access_google"].tap()

        let educationalCTA = app.buttons["groups_onboarding_cta"]
        XCTAssertTrue(educationalCTA.waitForExistence(timeout: 20), "La entrada de solo grupos no llegó a Grupos.")
        educationalCTA.tap()

        let groupName = app.textFields["group_form_name_input"]
        XCTAssertTrue(groupName.waitForExistence(timeout: 20), "No llegó el formulario del primer grupo.")
        groupName.tap()
        groupName.typeText("Depa")
        let yourName = app.textFields["group_form_your_name_input"]
        yourName.tap()
        yourName.typeText("Ana")
        let save = app.buttons["group_form_save"]
        XCTAssertTrue(save.waitUntilEnabledAfterTyping(timeout: 5), "«Crear» no se encendió con los dos nombres.")
        save.tap()

        assertLandsInTheAppAndStays(app, "Cuenta de solo grupos")
    }
}

private extension XCUIElement {
    func waitUntilEnabledAfterTyping(timeout: TimeInterval) -> Bool {
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: self)
        return XCTWaiter().wait(for: [enabled], timeout: timeout) == .completed
    }
}
