//
//  OnboardingGroupsOnlyGuardUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área onboarding "Solo grupos" (commit 182c326a).
//  Dos caras:
//   1. SIN iCloud (sim por defecto): el paso Propósito ofrece la card "Dividir gastos
//      con amigos" (onboarding_purpose_groups) y elegirla dispara el guard (alerta
//      "Activa iCloud para usar grupos") sin avanzar.
//   2. CON iCloud (forzado por -uitest-fake-icloud): happy-path e2e — elegir la card
//      avanza al paso de moneda, donde el botón "Continuar" está HABILITADO pese a no
//      haber nombre de cuenta (oculto en Solo Grupos), y el onboarding completa
//      aterrizando en el tab Grupos. Esto ejercita el fix del "botón Continuar muerto"
//      (2.0.5) que antes solo era verificable en device con iCloud.
//  Usa el hook -uitest-onboarding (presenta OnboardingView directo sin marcarlo
//  completado). Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class OnboardingGroupsOnlyGuardUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Avanza del step de nombre al paso Propósito y devuelve la app ya en ese paso.
    /// `fakeICloud` fuerza `isAccountAvailable=true` (para el happy-path que necesita
    /// pasar el guard de iCloud, imposible en sim sin este hook).
    ///
    /// `cloudSession` finge la sesión de NUBE, que es otro gate distinto: `-uitest-fake-icloud` habla
    /// de la cuenta de iCloud del OS y no crea sesión backend. Lo necesita el happy-path porque
    /// aterriza en el tab Grupos vacío, y con `groupsBackendEnabled` ON —todo XCUITest bajo Yala Dev—
    /// ese landing sin sesión es el empty state de RE-ENTRADA, no el estándar que este test asserta.
    private func launchAtPurposeStep(fakeICloud: Bool = false, cloudSession: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(skipOnboarding: false, seed: nil, onboarding: true,
                            fakeICloud: fakeICloud, cloudSession: cloudSession)

        let nameField = app.textFields["onboarding_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 30), "No apareció onboarding_name_field.")
        nameField.tap()
        nameField.typeText("QA")

        let next = app.buttons["onboarding_next_button"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "No apareció onboarding_next_button.")
        next.tap()
        return app
    }

    /// El paso Propósito ofrece las 3 opciones, incluida la nueva "Dividir gastos con amigos".
    func test_purposeStep_offersGroupsOnlyCard() {
        let app = launchAtPurposeStep()

        XCTAssertTrue(
            app.buttons["onboarding_purpose_groups"].waitForExistence(timeout: 10),
            "La card 'Dividir gastos con amigos' (onboarding_purpose_groups) no está en el paso Propósito."
        )
        // No-regresión de las otras dos opciones.
        XCTAssertTrue(app.buttons["onboarding_purpose_control"].exists, "Falta la card 'Llevar el control'.")
        XCTAssertTrue(app.buttons["onboarding_purpose_expenses"].exists, "Falta la card 'Solo anotar gastos'.")
    }

    /// Elegir "Solo grupos" sin cuenta iCloud (sim) dispara el guard y no avanza.
    func test_groupsOnlyCard_withoutICloud_showsGuardAlert() {
        let app = launchAtPurposeStep()

        let groupsCard = app.buttons["onboarding_purpose_groups"]
        XCTAssertTrue(groupsCard.waitForExistence(timeout: 10), "No apareció la card de solo-grupos.")
        groupsCard.tap()

        // Sin iCloud (ubiquityIdentityToken == nil en sim) el guard muestra una alerta
        // y bloquea el avance. Aserción robusta por presencia de alerta (no por texto localizado).
        XCTAssertTrue(
            app.alerts.firstMatch.waitForExistence(timeout: 5),
            "El guard de iCloud no apareció al elegir 'Solo grupos' sin cuenta."
        )
    }

    /// Happy-path con iCloud disponible (forzado por -uitest-fake-icloud): elegir "Solo
    /// grupos" avanza al paso de moneda (sin guard), donde el botón "Continuar" está
    /// HABILITADO aunque el campo de nombre de cuenta esté oculto — regresión del bug
    /// del "botón Continuar muerto" (fix 2.0.5). Completa y aterriza en el tab Grupos.
    /// La sesión de nube va fingida porque la aserción final espera el empty state ESTÁNDAR
    /// del tab (ver el docblock de `launchAtPurposeStep`); lo que este caso prueba es el
    /// onboarding, no la rama de re-entrada, que tiene su propio test en GroupsEmptyStateUITests.
    func test_groupsOnly_withICloud_currencyStepEnablesContinueAndCompletes() {
        let app = launchAtPurposeStep(fakeICloud: true, cloudSession: true)

        let groupsCard = app.buttons["onboarding_purpose_groups"]
        XCTAssertTrue(groupsCard.waitForExistence(timeout: 10), "No apareció la card de solo-grupos.")
        groupsCard.tap()

        // Con iCloud disponible NO debe aparecer el guard → avanzar al paso de moneda.
        let next = app.buttons["onboarding_next_button"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "No apareció el botón Siguiente en Propósito.")
        next.tap()

        // Estamos en el paso de moneda (el selector confirma el paso). Si el guard hubiera
        // bloqueado, el modo seguiría en fullControl y este selector no aparecería.
        XCTAssertTrue(
            app.buttons["onboarding_currency_selector"].waitForExistence(timeout: 10),
            "No se llegó al paso de moneda (onboarding_currency_selector ausente) — ¿el guard bloqueó?"
        )

        // EL FIX: en Solo Grupos el campo de nombre de cuenta está oculto y el botón
        // "Continuar" debe estar HABILITADO (antes quedaba muerto permanentemente).
        XCTAssertFalse(
            app.textFields["onboarding_account_name"].exists,
            "En Solo Grupos el campo de nombre de cuenta debe estar oculto."
        )
        let continueBtn = app.buttons["onboarding_next_button"]
        XCTAssertTrue(continueBtn.waitForExistence(timeout: 5), "No apareció el botón Continuar en el paso de moneda.")
        XCTAssertTrue(
            continueBtn.isEnabled,
            "El botón 'Continuar' debe estar HABILITADO en Solo Grupos (regresión del botón muerto)."
        )

        // Continuar → paso de confirmación → completar el onboarding.
        continueBtn.tap()
        let finish = app.buttons["onboarding_next_button"]
        XCTAssertTrue(finish.waitForExistence(timeout: 10), "No apareció el CTA final (confirmación).")
        finish.tap()

        // Aterriza en el tab Grupos (Solo Grupos, sin grupos → empty state).
        XCTAssertTrue(
            app.descendants(matching: .any)["groups_empty_state"].waitForExistence(timeout: 20),
            "No se aterrizó en el tab Grupos (groups_empty_state ausente tras completar)."
        )
    }
}
