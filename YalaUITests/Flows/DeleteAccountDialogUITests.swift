//
//  DeleteAccountDialogUITests.swift
//  YalaUITests
//
//  D5 (§3.3.4 del estudio MODO-NUBE-GESTION-DATOS-UX): el diálogo de «Eliminar mi cuenta» muestra,
//  CONDICIONAL a saldos pendientes en grupos, el aviso de deudas + el botón «Ver mis grupos», SIN dejar
//  de ofrecer «Continuar» (informa, JAMÁS bloquea — línea roja GDPR).
//
//  El flujo es DARK: la fila solo existe con sesión backend viva, imposible en el simulador (SIWA/Google
//  no corren). El seam `-uitest-fake-backend-session` (#if DEBUG, inerte en release) fuerza el input
//  `hasSession` de la fila SOLO en ProfileView — NO crea una sesión Supabase real; por eso el test jamás
//  toca «Continuar → Eliminar» (no completaría). Combinado con `-uitest-seed grupos` (el usuario queda
//  como acreedor neto en 2 grupos ⇒ saldo pendiente) verifica la rama de deuda; con `-uitest-seed minimal`
//  (sin grupos) verifica que el botón NO aparece.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev, targeting por accessibilityIdentifier).
//

import XCTest

final class DeleteAccountDialogUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Baja por el ScrollView de Ajustes hasta que la fila sea hittable (la sección Seguridad y cuenta
    /// vive al final). Determinista: tope de intentos, sin sleeps.
    private func scrollToDeleteAccountRow(_ app: XCUIApplication) -> XCUIElement {
        let row = app.buttons["profile_security_delete_account"]
        var tries = 0
        while !row.isHittable && tries < 12 {
            app.swipeUp()
            tries += 1
        }
        return row
    }

    /// Con sesión (faked) + grupos con deuda → el diálogo ofrece «Ver mis grupos» (rama D5) y también
    /// «Continuar» (no bloquea).
    func test_deleteAccountDialog_showsViewGroups_whenGroupsHaveDebt() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "grupos", extraArguments: ["-uitest-fake-backend-session"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        let row = scrollToDeleteAccountRow(app)
        XCTAssertTrue(row.waitForExistence(timeout: 5),
                      "La fila 'profile_security_delete_account' no apareció con la sesión backend faked.")
        row.tap()

        // Rama de deuda: el desvío seguro «Ver mis grupos» + «Continuar» (destructivo) conviven.
        let viewGroups = app.buttons["delete_account_view_groups"]
        let continueBtn = app.buttons["delete_account_continue"]
        XCTAssertTrue(viewGroups.waitForExistence(timeout: 5),
                      "No apareció 'delete_account_view_groups' — el aviso de deudas D5 no se presentó.")
        XCTAssertTrue(continueBtn.exists,
                      "No apareció 'delete_account_continue' — el borrado debe seguir disponible (no bloquea).")
    }

    /// Con sesión (faked) pero SIN grupos (seed minimal) → la fila aparece, pero el diálogo NO ofrece
    /// «Ver mis grupos» (sin deuda). Prueba la condicionalidad del botón.
    func test_deleteAccountDialog_noViewGroups_whenNoDebt() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", extraArguments: ["-uitest-fake-backend-session"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.openProfile()
        let row = scrollToDeleteAccountRow(app)
        XCTAssertTrue(row.waitForExistence(timeout: 5),
                      "La fila 'profile_security_delete_account' no apareció con la sesión backend faked.")
        row.tap()

        // «Continuar» presente; «Ver mis grupos» ausente (sin saldos pendientes).
        let continueBtn = app.buttons["delete_account_continue"]
        XCTAssertTrue(continueBtn.waitForExistence(timeout: 5),
                      "No apareció el diálogo de eliminar cuenta ('delete_account_continue').")
        XCTAssertFalse(app.buttons["delete_account_view_groups"].exists,
                       "'delete_account_view_groups' NO debe aparecer sin saldos pendientes.")
    }
}
