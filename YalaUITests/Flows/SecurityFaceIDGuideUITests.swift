//
//  SecurityFaceIDGuideUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest de la remoción del bloqueo biométrico in-app → guía Face ID nativa
//  (commit 65c1fe50). Verifica que Perfil → Seguridad → "Proteger con Face ID" abre la
//  FaceIDProtectionGuideView (guía, no un lock in-app). El gesto nativo de iOS (Requerir
//  Face ID) y el cleanup real del Keychain son device-only; aquí se valida el wiring de la UI.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev, a11y ids).
//

import XCTest

final class SecurityFaceIDGuideUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_securityRow_opensFaceIDGuide() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)  // seed minimal + skip onboarding + Pro
        XCTAssertTrue(app.waitForUITestReady(), "La app no señaló uitest_ready.")

        // Abrir Perfil.
        let profile = app.buttons["profile_avatar"]
        XCTAssertTrue(profile.waitForExistence(timeout: 20), "No apareció profile_avatar.")
        profile.tap()

        // La fila de Seguridad vive al fondo del Perfil → hacer scroll hasta que sea hittable.
        let securityRow = app.buttons["profile_security_faceid"]
        var attempts = 0
        while !securityRow.isHittable && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(securityRow.waitForExistence(timeout: 5), "No apareció la fila Seguridad → Face ID.")
        securityRow.tap()

        // Se abre la guía (no un lock in-app).
        XCTAssertTrue(
            app.otherElements["faceid_guide_root"].waitForExistence(timeout: 5)
                || app.scrollViews["faceid_guide_root"].waitForExistence(timeout: 1),
            "No se abrió FaceIDProtectionGuideView (faceid_guide_root)."
        )
    }
}
