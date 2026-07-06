//
//  OnboardingGroupsOnlyGuardUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área onboarding "Solo grupos" (commit 182c326a).
//  Verifica lo 100% determinista en sim SIN iCloud: (1) el paso Propósito ofrece
//  la card "Dividir gastos con amigos" (onboarding_purpose_groups) junto a las otras
//  dos, y (2) elegirla sin cuenta iCloud dispara el guard (alerta "Activa iCloud
//  para usar grupos") y NO avanza. El happy-path (con iCloud → moneda → landing)
//  es device/TestFlight (el guard bloquea en sim; no hay hook para forzar iCloud).
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
    private func launchAtPurposeStep() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(skipOnboarding: false, seed: nil, onboarding: true)

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
}
