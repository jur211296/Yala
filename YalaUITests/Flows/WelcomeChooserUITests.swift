//
//  WelcomeChooserUITests.swift
//  YalaUITests
//
//  Chooser del Welcome de 2 niveles con las cards de sign-in cloud (Google Sign-In sesión 2).
//  Opt-in EXPLÍCITO `-uitest-cloud-chooser`: destapa las cards Apple/Google bajo uitest SOLO
//  para este test (sin él, uitest conserva el bypass a restore — byte-idéntico, verificado
//  a mano en sim). NAVEGACIÓN determinista pura: jamás se tapea el botón de sign-in real
//  (nada de red/SIWA/sheets de Google).
//

import XCTest

final class WelcomeChooserUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testExistingChooser_withCloudConfigured_showsThreeCards_andGoogleIntro() throws {
        let app = XCUIApplication()
        // Sin skipOnboarding (el flow Welcome ES el sujeto) y sin seed (no hace falta data).
        app.launchForUITest(
            reset: true,
            skipOnboarding: false,
            seed: nil,
            extraArguments: ["-uitest-cloud-chooser"]
        )
        // NOTA: `uitest_ready` vive en el root de ContentView, que queda CUBIERTO por el
        // fullScreenCover del Welcome → no usar waitForUITestReady aquí (patrón
        // OnboardingFlowUITests); se espera el Hero directamente con timeout generoso.
        let heroCTA = app.buttons["welcome_hero_cta"]
        XCTAssertTrue(heroCTA.waitForExistence(timeout: 60), "No apareció el CTA del Hero.")
        heroCTA.tap()

        // "Ya tengo una cuenta" → 2º nivel (con el opt-in hay >1 opción, no hay bypass).
        let restoreBranch = app.buttons["welcome_chooser_restore"]
        XCTAssertTrue(restoreBranch.waitForExistence(timeout: 10), "No apareció la card 'Ya tengo una cuenta'.")
        restoreBranch.tap()

        // 2º nivel: las TRES cards por identifier.
        let restoreCard = app.buttons["welcome_existing_restore"]
        XCTAssertTrue(restoreCard.waitForExistence(timeout: 10), "No apareció la card de restaurar iCloud.")
        XCTAssertTrue(app.buttons["welcome_existing_cloud"].exists, "No apareció la card de Apple.")
        let googleCard = app.buttons["welcome_existing_google"]
        XCTAssertTrue(googleCard.exists, "No apareció la card de Google.")

        // Card Google → intro con el botón Google (SIN tapearlo — nada de sign-in real).
        googleCard.tap()
        let googleButton = app.descendants(matching: .any)
            .matching(identifier: "welcome_cloud_signin_button_google").firstMatch
        XCTAssertTrue(googleButton.waitForExistence(timeout: 10), "No apareció el botón de Google en el intro.")

        // Back → de vuelta al chooser (nivel 1, por el onBack del cover).
        let backButton = app.buttons["welcome_back_button"].firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 10), "No apareció el botón Volver del intro.")
        backButton.tap()
        XCTAssertTrue(app.buttons["welcome_chooser_restore"].waitForExistence(timeout: 10),
                      "El back no volvió al chooser.")
    }

    /// A4 + A5 de D-A7: el 2º nivel de "Soy nuevo" y el destino REAL de su card de nube. Mismo
    /// opt-in `-uitest-cloud-chooser` que el hermano —sin él, `visibleNewOptions` deja una sola card
    /// y el container hace bypass, con el recorrido byte-idéntico al de hoy (lo cubre
    /// `OnboardingFlowUITests`, que lanza sin el arg).
    ///
    /// **A5 cambió el final de este test**: antes afirmaba el STUB de A4 (un alert «próximamente»);
    /// ahora afirma que la card abre el intro del ALTA. El sign-in NO se tapea — SIWA no funciona en
    /// sim y el claim iría a un backend real; lo que se prueba aquí es el recorrido hasta la
    /// pantalla, no el alta.
    func testNewChooser_withCloudConfigured_showsBothCards_andCloudCardOpensSignUp() throws {
        let app = XCUIApplication()
        app.launchForUITest(
            reset: true,
            skipOnboarding: false,
            seed: nil,
            extraArguments: ["-uitest-cloud-chooser"]
        )
        let heroCTA = app.buttons["welcome_hero_cta"]
        XCTAssertTrue(heroCTA.waitForExistence(timeout: 60), "No apareció el CTA del Hero.")
        heroCTA.tap()

        // "Soy nuevo" → 2º nivel (con el opt-in hay 2 opciones, no hay bypass).
        let newBranch = app.buttons["welcome_chooser_new"]
        XCTAssertTrue(newBranch.waitForExistence(timeout: 10), "No apareció la card 'Soy nuevo'.")
        newBranch.tap()

        let privateCard = app.buttons["welcome_new_private"]
        XCTAssertTrue(privateCard.waitForExistence(timeout: 10), "No apareció la card de privacidad total.")
        let cloudCard = app.buttons["welcome_new_cloud"]
        XCTAssertTrue(cloudCard.exists, "No apareció la card de cuenta en la nube.")

        // A5: la card de nube abre el intro del ALTA, con los dos métodos de prominencia
        // equivalente. Se afirma el intro Y sus dos botones: sin el segundo, un intro que montara
        // vacío pasaría igual.
        cloudCard.tap()
        let appleSignUp = app.descendants(matching: .any)
            .matching(identifier: "welcome_borncloud_signup_apple").firstMatch
        XCTAssertTrue(appleSignUp.waitForExistence(timeout: 10),
                      "La card de nube no abrió el alta: sigue siendo un botón muerto.")
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "welcome_borncloud_signup_google").firstMatch.exists,
                      "Falta el método Google (prominencia equivalente, guideline 4.8).")

        // Back → de vuelta al chooser (nivel 1). Nada se ha comprometido todavía: el consent ni se
        // ha pedido, así que la fase `.intro` permite salir (`canGoBack`).
        let backButton = app.buttons["welcome_back_button"].firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 10), "No apareció el botón Volver del 2º nivel.")
        backButton.tap()
        XCTAssertTrue(app.buttons["welcome_chooser_new"].waitForExistence(timeout: 10),
                      "El back no volvió al chooser.")
    }

    /// G2 de Grupos-first: la card «Vengo por un grupo» ya no sale disparada a la recuperación de
    /// invitación — abre el step de los DOS caminos. Este test es el pin del re-ruteo: devolver el
    /// `.invite` del chooser al portal directo (`leaveWelcome(to: .inviteRecovery)`) lo pone en rojo,
    /// porque las cards del step no llegan a existir.
    ///
    /// **Sin `-uitest-cloud-chooser`**: la card `.invite` se pinta desde `Branch.allCases` y no está
    /// gateada por nada, así que este recorrido es el de producción.
    ///
    /// La rama «crear» NO se afirma aquí porque en G2 **no existe**: queda inerte tras un TODO que G3
    /// consume, y su card ni se pinta. Un test que la esperase estaría afirmando un stub.
    func testGroupsChooser_inviteCardOpensTwoPaths_andJoinStillReachesInviteRecovery() throws {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil)

        let heroCTA = app.buttons["welcome_hero_cta"]
        XCTAssertTrue(heroCTA.waitForExistence(timeout: 60), "No apareció el CTA del Hero.")
        heroCTA.tap()

        // La card conserva su identifier (`Branch.invite` no se renombra: es lo que tocan los XCUI
        // deterministas del área `onboarding-flow`); lo que cambia es su destino.
        let inviteBranch = app.buttons["welcome_chooser_invite"]
        XCTAssertTrue(inviteBranch.waitForExistence(timeout: 10), "No apareció la card «Vengo por un grupo».")
        inviteBranch.tap()

        let joinCard = app.buttons["welcome_groups_join"]
        XCTAssertTrue(joinCard.waitForExistence(timeout: 10),
                      "La card de grupos no abrió el step de dos caminos.")

        // El back del step vuelve al chooser (nivel 1).
        let backButton = app.buttons["welcome_back_button"].firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 10), "No apareció el botón Volver del step.")
        backButton.tap()
        XCTAssertTrue(inviteBranch.waitForExistence(timeout: 10), "El back no volvió al chooser.")

        // Y el invitado no pierde nada: «Tengo una invitación» sale por el MISMO destino de siempre y
        // aterriza en la recuperación de invitación, que NO es una pantalla del WelcomeFlow.
        inviteBranch.tap()
        XCTAssertTrue(joinCard.waitForExistence(timeout: 10), "El step no volvió a montarse.")
        joinCard.tap()

        // El desmontaje del step es la señal de que se salió del cover (`exists` del fondo no probaría
        // nada, ver `.claude/rules/testing.md`), y el campo de pegar el enlace es contenido NUEVO que el
        // Welcome no tiene en ninguna de sus pantallas.
        XCTAssertTrue(waitForNonExistence(of: joinCard, timeout: 10),
                      "El step de grupos no se desmontó: no se salió del Welcome.")
        //
        // El campo es un `TextField` y no un `textView` pese al `axis: .vertical` — MEDIDO con
        // `app.debugDescription` sobre esta misma corrida, no supuesto: en el árbol sale como
        // `TextField … placeholderValue: 'https://yala-app.pe/invite?...'`.
        let linkField = app.textFields.firstMatch
        XCTAssertTrue(linkField.waitForExistence(timeout: 10),
                      "No apareció el campo de pegar el enlace: la card de unirse no llegó a InviteRecoveryView.")
    }

    /// G3 · el recorrido COMPLETO de la rama organizador, desde la card hasta el formulario de grupo.
    ///
    /// **Qué se finge y por qué es lo único que se puede fingir.** El simulador no tiene sesión de nube ni
    /// puede firmar con Apple/Google, así que `-uitest-fake-cloud-session` y `-uitest-groups-consent`
    /// saltan los pasos 4 y 5 poniendo sus condiciones VIVAS a `true` — que es exactamente lo que la
    /// máquina re-evalúa en cada avance. El tráfico HTTP sigue en CERO: ninguno de los dos fabrica un JWT.
    ///
    /// **La celda que este test NO puede ejercitar, y va dicho aquí para que nadie la busque:** la puerta
    /// CERRADA. Bajo `-uitest` `CloudSyncFlags.groupsBackendEnabled` es SIEMPRE `true` (`CloudRemoteConfig
    /// .decide` corta en `isUITestHost` → `absentDefault`, ON bajo `DEV_BUILD`) y no hay launch arg que lo
    /// apague. Esa celda vive en `GroupsOrganizerBranchTests` y en ningún otro sitio.
    func testGroupsOrganizer_createCardWalksToTheGroupForm() throws {
        let app = XCUIApplication()
        app.launchForUITest(
            reset: true,
            skipOnboarding: false,
            seed: nil,
            cloudSession: true,
            groupsConsent: true
        )

        let heroCTA = app.buttons["welcome_hero_cta"]
        XCTAssertTrue(heroCTA.waitForExistence(timeout: 60), "No apareció el CTA del Hero.")
        heroCTA.tap()

        let inviteBranch = app.buttons["welcome_chooser_invite"]
        XCTAssertTrue(inviteBranch.waitForExistence(timeout: 10), "No apareció la card «Vengo por un grupo».")
        inviteBranch.tap()

        // G3 cableó `onCreate`, así que la card ya se pinta: en G2 `visiblePaths` la filtraba y solo había una.
        let createCard = app.buttons["welcome_groups_create"]
        XCTAssertTrue(createCard.waitForExistence(timeout: 10),
                      "La card «Crear mi primer grupo» no se pinta: ¿`onCreate` sin cablear?")
        createCard.tap()

        // La puerta abre (canal ON bajo uitest, device sin datos) ⇒ sale del cover y la cadena
        // sign-in → consent se salta por las condiciones vivas ⇒ el siguiente paso es el nombre.
        let nameField = app.textFields["groups_organizer_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 20),
                      "La puerta no dejó pasar, o la rama no llegó al paso del nombre.")
        nameField.tap()
        nameField.typeText("Ana")

        let nameCTA = app.buttons["groups_organizer_name_cta"]
        XCTAssertTrue(nameCTA.waitForExistence(timeout: 10), "No apareció el CTA del alta.")
        nameCTA.tap()

        // El desmontaje del campo es la señal de que el cover se fue de verdad — `exists` del fondo no
        // probaría nada (`.claude/rules/testing.md`).
        XCTAssertTrue(waitForNonExistence(of: nameField, timeout: 15),
                      "El cover del nombre no se desmontó tras completar el alta.")

        // Y el último paso: el formulario de grupo, directo, sin que el usuario haya tenido que buscarlo.
        let groupNameInput = app.textFields["group_form_name_input"]
        XCTAssertTrue(groupNameInput.waitForExistence(timeout: 20),
                      "El alta terminó pero el formulario de grupo no se abrió solo.")
    }

    /// `waitForNonExistence` local: el helper compartido de `Support/` cubre `isHittable`, y aquí lo que
    /// prueba el desmontaje es la AUSENCIA del elemento.
    private func waitForNonExistence(of element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
