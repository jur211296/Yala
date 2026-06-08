//
//  ProfileGroupInviteUITests.swift
//  YalaUITests
//
//  Cobertura del Perfil reducido en modo solo-grupos (OnboardingMode.groupInvite):
//  las filas de finanzas personales se ocultan y las universales/grupos se
//  conservan. Se abre desde el toolbar del tab Grupos (único visible en ese modo).
//  Área: settings-profile-general. Convenciones: ver CLAUDE.md (sin sleeps, Yala Dev).
//

import XCTest

final class ProfileGroupInviteUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// En solo-grupos el Perfil oculta las filas de finanzas personales (Organización
    /// entera, Divisa, Icono, Personalización) y conserva las universales.
    func test_profileGroupInvite_hidesPersonalFinanceRows() {
        let app = XCUIApplication()
        app.launchForUITest(groupInvite: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        // El avatar de Perfil vive en el toolbar del tab Grupos (único activo).
        app.openProfile()

        // Presente: Notificaciones (universal — los grupos generan avisos).
        XCTAssertTrue(
            app.buttons["profile_notifications"].waitForExistence(timeout: 5),
            "No apareció la fila Notificaciones en el Perfil solo-grupos."
        )

        // Ausentes: filas de finanzas personales que no aplican a un solo-grupos.
        for hidden in [
            "profile_accounts", "profile_categories", "profile_tags",
            "profile_planned", "profile_favorites",
            "profile_personalization", "profile_currency",
        ] {
            XCTAssertFalse(
                app.buttons[hidden].exists,
                "La fila '\(hidden)' no debería aparecer en modo solo-grupos."
            )
        }
    }
}
