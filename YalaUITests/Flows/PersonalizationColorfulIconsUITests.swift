//
//  PersonalizationColorfulIconsUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del toggle "Iconos coloridos" (commit 44fad0f2). Verifica que
//  el toggle existe en Perfil → Personalización y que alterna su estado. El efecto
//  visual (iconos coloreados en Perfil Y en Más, y que Liquid Glass/Traslúcido no
//  fuerzan monocromo) se valida por device-qa/agentic — XCUI no compara colores.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev, targetear por a11y id).
//

import XCTest

final class PersonalizationColorfulIconsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_colorfulIconsToggle_existsAndTogglesInPersonalization() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)  // seed minimal + skip onboarding + Pro
        XCTAssertTrue(app.waitForUITestReady(), "La app no señaló uitest_ready.")

        // Perfil → Personalización
        let profile = app.buttons["profile_avatar"]
        XCTAssertTrue(profile.waitForExistence(timeout: 20), "No apareció profile_avatar.")
        profile.tap()

        let personalization = app.buttons["profile_personalization"]
        XCTAssertTrue(personalization.waitForExistence(timeout: 10), "No apareció la fila Personalización.")
        personalization.tap()

        // El toggle existe y alterna.
        let toggle = app.switches["settings_colorful_icons_toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "No apareció settings_colorful_icons_toggle.")
        let before = toggle.value as? String
        toggle.tap()
        // Esperar el cambio de valor (Toggle de SwiftUI → el sub-switch refleja el nuevo estado).
        let changed = NSPredicate(format: "value != %@", before ?? "")
        expectation(for: changed, evaluatedWith: toggle)
        waitForExpectations(timeout: 5)
    }
}
