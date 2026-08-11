//
//  ProfileGroupInviteUITests.swift
//  YalaUITests
//
//  Cobertura del Perfil reducido en modo solo-grupos (OnboardingMode.groupInvite):
//  las filas de finanzas personales se ocultan y las universales/grupos se
//  conservan. Se abre desde el toolbar del tab Grupos (único visible en ese modo).
//  Área: settings-profile-general. Convenciones: ver CLAUDE.md (sin sleeps, Yala Dev).
//
//  G4 (2026-08-11): el segundo test es el ÚNICO pin de la fila «Activar Yala completo».
//  `-uitest-group-invite` deja `onboardingMode = .groupInvite` y NO toca `usageFocus`
//  (AppBootstrapper), que es exactamente la cohorte que la fila se saltaba: por eso
//  devolver la condición a `usageFocus == .groupsOnly` pone este test —y solo este— rojo.
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

    /// G4: quien llegó por un grupo —invitación o alta de organizador— también tiene que poder
    /// volver a la app completa desde Ajustes. La fila la gateaba `usageFocus == .groupsOnly`, y
    /// ninguna de las cuatro escrituras de `onboardingMode = .groupInvite` escribe `usageFocus`,
    /// así que esta cohorte no la veía nunca. Aserción sobre contenido NUEVO de la vista
    /// presentada (no sobre un elemento preexistente del fondo, que se cumpliría igual).
    func test_profileGroupInvite_offersActivateFullYala() {
        let app = XCUIApplication()
        app.launchForUITest(groupInvite: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()

        XCTAssertTrue(
            app.buttons["profile_activate_full_yala"].waitForExistence(timeout: 10),
            "No apareció «Activar Yala completo» en el Perfil de un usuario solo-grupos: la vuelta a la app completa quedaría solo en el CTA de «Más»."
        )
    }
}
