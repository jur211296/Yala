//
//  OnboardingFlowUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `onboarding-flow` (1.x): el OnboardingView (8 steps)
//  monta y avanza entre steps. **Desde la bienvenida 2.3 (Y23-04)** el alta es la conversación de tres
//  preguntas y el hook `-uitest-onboarding` la monta a ella; el OnboardingView vive en «Activar Yala
//  completo», y por ahí entra este fichero (`launchIntoFullActivationOnboarding`). La lógica de
//  prefill/skip de steps ya tiene cobertura pure-logic (OnboardingPrefillResolver, FullModeActivationLogic).
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class OnboardingFlowUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchIntoFullActivationOnboarding()
        return app
    }

    /// El OnboardingView de la activación monta en el step 1 (nombre).
    func test_onboardingMountsAtNameStep() {
        let app = launchOnboarding()

        XCTAssertTrue(
            app.textFields["onboarding_name_field"].waitForExistence(timeout: 30),
            "El OnboardingView no montó en el step de nombre (onboarding_name_field)."
        )
        XCTAssertTrue(
            app.buttons["onboarding_next_button"].exists,
            "El CTA de avanzar (onboarding_next_button) no está presente."
        )
    }

    /// Llenar el nombre y avanzar desmonta el step 1 (navega al siguiente step).
    func test_onboardingAdvancesFromNameStep() {
        let app = launchOnboarding()

        let nameField = app.textFields["onboarding_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 30), "No apareció onboarding_name_field.")
        nameField.tap()
        nameField.typeText("QA")

        let next = app.buttons["onboarding_next_button"]
        XCTAssertTrue(next.waitForExistence(timeout: 5), "No apareció onboarding_next_button.")
        XCTAssertTrue(next.isEnabled, "El CTA sigue deshabilitado tras escribir el nombre.")
        next.tap()

        // Al avanzar al step 2, el campo de nombre se desmonta.
        XCTAssertTrue(
            nameField.waitForNonExistence(timeout: 5),
            "El step de nombre no se desmontó tras avanzar — la navegación del onboarding no progresó."
        )
    }
}
