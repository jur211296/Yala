//
//  YalaAccountUITests.swift
//  YalaUITests
//
//  §3.3.5: la pantalla «Tu cuenta de Yala» (mapa/explainer del enlace privado ↔ nube) se alcanza desde la
//  subsección «Tu cuenta» de Seguridad y presenta los desenlaces aplicables.
//
//  Flujo DARK: la fila solo existe con sesión backend viva, imposible en el simulador (SIWA/Google no
//  corren). El seam `-uitest-fake-backend-session` (#if DEBUG, inerte en release) fuerza el input
//  `hasSession` de la fila SOLO en ProfileView — NO crea una sesión Supabase real; por eso el test jamás
//  confirma «Cerrar sesión»/«Eliminar cuenta» (bajo el seam el path real es `.privateReset` y confirmar
//  iría al Welcome). En el sim el modo es `.icloud` ⇒ «Volver a iCloud» NO aparece (solo en `.cloud`).
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev, targeting por accessibilityIdentifier).
//

import XCTest

final class YalaAccountUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Baja por el ScrollView de Ajustes hasta que el elemento sea hittable. Determinista: tope, sin sleeps.
    private func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let el = app.buttons[identifier]
        var tries = 0
        while !el.isHittable && tries < 14 {
            app.swipeUp()
            tries += 1
        }
        return el
    }

    /// Con sesión (faked): la fila «Tu cuenta de Yala» aparece en Seguridad y abre la pantalla, que ofrece
    /// «Cerrar sesión» + «Eliminar mi cuenta»; «Volver a iCloud» NO aparece (sim `.icloud`).
    func test_yalaAccountScreen_showsExits_forSession() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", extraArguments: ["-uitest-fake-backend-session"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")

        app.openProfile()
        let row = scrollTo(app, "profile_yala_account")
        XCTAssertTrue(row.waitForExistence(timeout: 5),
                      "La fila 'profile_yala_account' no apareció con la sesión backend faked.")
        row.tap()

        // Los desenlaces prueban que la pantalla cargó.
        XCTAssertTrue(app.buttons["yala_account_signout"].waitForExistence(timeout: 5),
                      "No apareció el desenlace 'Cerrar sesión' (yala_account_signout).")
        XCTAssertTrue(app.buttons["yala_account_delete"].exists,
                      "No apareció el desenlace 'Eliminar mi cuenta' (yala_account_delete).")
        // «Volver a iCloud» solo en `.cloud` (migrado) — en el sim `.icloud` debe estar ausente.
        XCTAssertFalse(app.buttons["yala_account_return_icloud"].exists,
                       "'Volver a iCloud' NO debe aparecer en modo .icloud.")
    }

    /// Sin el seam (device prod hoy): la fila «Tu cuenta de Yala» NO existe (DARK — hasSession imposible).
    func test_yalaAccountRow_absent_withoutSession() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")

        app.openProfile()
        // Bajar hasta el final de Ajustes para dar oportunidad a que aparezca (no debe).
        var tries = 0
        while tries < 14 { app.swipeUp(); tries += 1 }
        XCTAssertFalse(app.buttons["profile_yala_account"].exists,
                       "'profile_yala_account' NO debe existir sin sesión backend (DARK).")
    }
}
