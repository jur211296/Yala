//
//  Bienvenida23AltaUITests.swift
//  YalaUITests
//
//  Lote 02 de la bienvenida 2.3 (`docs/onboarding-2-3/SPEC.md`): la vitrina y sus accesos (Y23-01), entrar con iCloud
//  (Y23-03), la conversación de tres preguntas (Y23-04) y la puerta de Grupos (Y23-06).
//
//  Bajo `-uitest` la entrada a la cuenta de Yala está apagada (el simulador no inicia sesión): sin
//  `-uitest-cloud-chooser` la vitrina deja solo iCloud, que es lo que ve la persona con el kill-switch remoto puesto.
//

import XCTest

final class Bienvenida23AltaUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchWelcome(_ app: XCUIApplication, cloud: Bool) {
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil,
                            extraArguments: cloud ? ["-uitest-cloud-chooser"] : [])
        XCTAssertTrue(app.staticTexts["welcome_showcase_title"].waitForExistence(timeout: 60)
                      || app.descendants(matching: .any)["welcome_showcase_title"].waitForExistence(timeout: 5),
                      "No apareció la vitrina de la bienvenida.")
    }

    /// Y23-01 · la vitrina con sus tres accesos, sin «Empezar» ni «Ya tengo una cuenta»; tocar un segmento cambia de
    /// función y la pausa se puede tocar.
    func test_showcase_hasThreeAccesses_andMovesBetweenFunctions() throws {
        let app = XCUIApplication()
        launchWelcome(app, cloud: true)

        XCTAssertTrue(app.buttons["welcome_access_google"].exists, "Falta «Entrar con Google».")
        XCTAssertTrue(app.buttons["welcome_access_apple"].exists, "Falta «Entrar con Apple».")
        XCTAssertTrue(app.buttons["welcome_access_icloud"].exists, "Falta «Entrar con mi iCloud».")
        XCTAssertFalse(app.buttons["welcome_hero_cta"].exists, "Volvió «Empezar»: un botón por proveedor y nada más.")
        XCTAssertFalse(app.buttons["welcome_chooser_restore"].exists, "Volvió «Ya tengo una cuenta».")

        let pause = app.buttons["welcome_showcase_pause"]
        XCTAssertTrue(pause.exists)
        pause.tap()
        app.buttons["welcome_showcase_segment_budget"].tap()
        let current = app.descendants(matching: .any)["welcome_showcase_current"]
        XCTAssertTrue(current.waitForExistence(timeout: 5))
        let budgetLabel = NSPredicate(format: "label CONTAINS %@", "5")
        expectation(for: budgetLabel, evaluatedWith: current)
        waitForExpectations(timeout: 5)
    }

    /// Y23-06 · «Dividir gastos con amigos» abre la puerta de Grupos: solo Google y Apple, con la nota de la cuenta, y
    /// tocar un proveedor lleva a los tres caminos.
    func test_groupsDoor_hasNoICloud_andLeadsToThreePaths() throws {
        let app = XCUIApplication()
        launchWelcome(app, cloud: true)

        app.buttons["welcome_showcase_pause"].tap()
        app.buttons["welcome_showcase_segment_splitAny"].tap()
        let door = app.buttons["welcome_showcase_groups_door"]
        XCTAssertTrue(door.waitForExistence(timeout: 5), "La función de grupos no ofrece «Dividir gastos con amigos».")
        door.tap()

        XCTAssertTrue(app.descendants(matching: .any)["welcome_access_groups_note"].waitForExistence(timeout: 5),
                      "La puerta de Grupos no dice que hace falta una cuenta de Yala.")
        XCTAssertFalse(app.buttons["welcome_access_icloud"].exists, "Con Grupos no hay iCloud en la bienvenida.")

        app.buttons["welcome_access_google"].tap()
        XCTAssertTrue(app.buttons["welcome_groups_create"].waitForExistence(timeout: 10), "Falta «Crear un grupo».")
        XCTAssertTrue(app.buttons["welcome_groups_join"].exists, "Falta «Tengo un enlace».")
        XCTAssertTrue(app.buttons["welcome_groups_accountOnly"].exists, "Falta «Solo crear mi cuenta».")
    }

    /// Y23-03 + Y23-04 · iCloud sin datos sigue a la conversación; nombre, moneda y «Solo gastos» llenan «Tu Yala» y
    /// terminan en la app con la cuenta de gastos que Yala crea sola.
    func test_iCloud_conversationOfThreeQuestions_landsInTheApp() throws {
        let app = XCUIApplication()
        launchWelcome(app, cloud: false)

        XCTAssertFalse(app.buttons["welcome_access_google"].exists,
                       "Sin entrada a la cuenta de Yala, Google no se pinta (no llevaría a ninguna parte).")
        app.buttons["welcome_access_icloud"].tap()

        let field = app.textFields["welcome_chat_name_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 20), "iCloud sin datos no siguió a la conversación.")
        field.tap()
        field.typeText("Ana")
        app.buttons["welcome_chat_name_send"].tap()

        let region = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "welcome_chat_currency_"))
            .firstMatch
        XCTAssertTrue(region.waitForExistence(timeout: 10), "No llegó la pregunta de la moneda.")
        XCTAssertTrue(app.descendants(matching: .any)["welcome_chat_row_name"].label.contains("Ana"),
                      "«Tu Yala» no se llenó con el nombre.")
        region.tap()

        let difference = app.buttons["welcome_chat_difference"]
        XCTAssertTrue(difference.waitForExistence(timeout: 10), "No llegó la pregunta de qué llevar.")
        difference.tap()
        XCTAssertTrue(app.descendants(matching: .any)["welcome_chat_explanation"].waitForExistence(timeout: 5),
                      "«¿Cuál es la diferencia?» no se explica.")
        XCTAssertFalse(difference.exists, "La explicación tiene que reemplazar al enlace.")
        app.buttons["welcome_chat_tracking_expenses"].tap()

        let enter = app.buttons["welcome_chat_enter"]
        XCTAssertTrue(enter.waitForExistence(timeout: 10), "La conversación no terminó.")
        enter.tap()

        XCTAssertTrue(app.buttons["panel_account_chip_0"].waitForExistence(timeout: 20),
                      "No llegó a la app con la cuenta de gastos de «Solo gastos».")
    }

    /// Y23-03 · iCloud con datos: la puerta ofrece «Traer mis datos». La revisión de iCloud se finge con
    /// `-uitest-private-gate-icloud-has-data`; lo que se pinta lo decide la tabla de producción.
    func test_iCloudWithData_offersBringMyData() throws {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil,
                            extraArguments: ["-uitest-private-gate-icloud-has-data"])
        let iCloud = app.buttons["welcome_access_icloud"]
        XCTAssertTrue(iCloud.waitForExistence(timeout: 60), "No apareció la vitrina.")
        iCloud.tap()
        XCTAssertTrue(app.buttons["welcome_private_icloud_restore"].waitForExistence(timeout: 20),
                      "Con datos en iCloud no salió «Traer mis datos».")
    }

    /// Y23-02 · sin cuenta, «Vamos a crear tu cuenta» lleva el consentimiento de la nube en la misma hoja y el aviso del
    /// otro proveedor, con su salida. La fase se fija con `-uitest-unified-access-phase` (el simulador no inicia sesión).
    func test_unifiedAccess_createAccount_carriesTheConsentAndTheOtherProviderNote() throws {
        let app = XCUIApplication()
        // «Crear mi cuenta» va detrás de la puerta del alta, que exige App Attest: el simulador no lo tiene y se finge.
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil, fakeAttestSupport: true,
                            extraArguments: ["-uitest-cloud-chooser", "-uitest-unified-access-phase", "create"])
        let google = app.buttons["welcome_access_google"]
        XCTAssertTrue(google.waitForExistence(timeout: 60), "No apareció «Entrar con Google».")
        google.tap()

        XCTAssertTrue(app.descendants(matching: .any)["welcome_cloud_create_account"].waitForExistence(timeout: 15),
                      "No salió «Vamos a crear tu cuenta».")
        XCTAssertTrue(app.descendants(matching: .any)["welcome_cloud_create_consent"].exists,
                      "El consentimiento de la nube tiene que ir en la misma hoja.")
        XCTAssertTrue(app.descendants(matching: .any)["welcome_cloud_create_other_provider_note"].exists,
                      "Falta el aviso de que con el otro proveedor sería otra cuenta.")
        XCTAssertTrue(app.buttons["welcome_cloud_create_account_cta"].exists, "Falta «Crear mi cuenta».")
        XCTAssertTrue(app.buttons["welcome_cloud_create_other_provider"].exists, "Falta «Entrar con Apple».")
    }

    /// Ticket `other-account-sign-in-bounces-to-welcome` (fallo 1 del 13-nov): «Usar otra cuenta» con Google vuelve a
    /// firmar EN EL ACTO, sin pasar por la vitrina. El inicio de sesión y `exists` se fingen (`-uitest-fake-account-exists`):
    /// la cuenta «elegida» existe, así que la hoja siguiente es «¿Cargamos tus datos y entramos?». Antes volvía a la vitrina.
    func test_unifiedAccess_useAnotherAccount_signsInAgainWithoutTheShowcase() throws {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil, fakeAttestSupport: true,
                            extraArguments: ["-uitest-cloud-chooser", "-uitest-unified-access-phase", "create",
                                             "-uitest-fake-account-exists", "complete"])
        let google = app.buttons["welcome_access_google"]
        XCTAssertTrue(google.waitForExistence(timeout: 60), "No apareció «Entrar con Google».")
        google.tap()
        let useAnother = app.buttons["welcome_cloud_create_use_another"]
        XCTAssertTrue(useAnother.waitForExistence(timeout: 15), "Falta «Usar otra cuenta».")
        useAnother.tap()
        XCTAssertTrue(app.descendants(matching: .any)["welcome_cloud_confirm_load"].waitForExistence(timeout: 15),
                      "«Usar otra cuenta» no volvió a firmar: tras el nuevo inicio de sesión tenía que salir la cuenta.")
        XCTAssertFalse(app.buttons["welcome_access_google"].exists, "«Usar otra cuenta» rebotó a la vitrina.")
    }

    /// Fallo 3 del 13-nov: con Apple y sin el inicio de sesión web de Apple no hay otro Apple ID que elegir. En vez de
    /// «Usar otra cuenta» (que firmaba otra vez con el mismo Apple ID: un bucle), la nota y «Entrar con Google».
    func test_unifiedAccess_appleWithoutTheWeb_offersGoogleInsteadOfALoop() throws {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil,
                            extraArguments: ["-uitest-cloud-chooser", "-uitest-unified-access-phase", "confirm",
                                             "-uitest-apple-web-sign-in-off"])
        let apple = app.buttons["welcome_access_apple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 60), "No apareció «Entrar con Apple».")
        apple.tap()
        XCTAssertTrue(app.descendants(matching: .any)["welcome_cloud_confirm_load"].waitForExistence(timeout: 15),
                      "No salió «¿Cargamos tus datos y entramos?».")
        XCTAssertTrue(app.descendants(matching: .any)["welcome_cloud_confirm_load_use_another_apple_note"].exists,
                      "Falta la nota de que Apple usa el Apple ID de este teléfono.")
        XCTAssertTrue(app.buttons["welcome_cloud_confirm_load_use_another_google"].exists, "Falta «Entrar con Google».")
        XCTAssertFalse(app.buttons["welcome_cloud_confirm_load_use_another"].exists,
                       "Con Apple sin la web, «Usar otra cuenta» vuelve a firmar con el mismo Apple ID.")
    }

    /// Y23-02 · con cuenta, «¿Cargamos tus datos y entramos?» antes de traer nada.
    func test_unifiedAccess_existingAccount_asksBeforeLoading() throws {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil,
                            extraArguments: ["-uitest-cloud-chooser", "-uitest-unified-access-phase", "confirm"])
        let apple = app.buttons["welcome_access_apple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 60), "No apareció «Entrar con Apple».")
        apple.tap()
        XCTAssertTrue(app.descendants(matching: .any)["welcome_cloud_confirm_load"].waitForExistence(timeout: 15),
                      "No salió «¿Cargamos tus datos y entramos?».")
        XCTAssertTrue(app.buttons["welcome_cloud_confirm_load_cta"].exists, "Falta «Cargar mis datos y entrar».")
        // Con el inicio de sesión web de Apple (encendido en DEV), la salida es «Otra cuenta de Apple».
        XCTAssertTrue(app.buttons["welcome_cloud_confirm_load_use_another"].exists, "Falta «Otra cuenta de Apple».")
    }
}
