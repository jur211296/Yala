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
//  confirma «Cerrar sesión»/«Eliminar cuenta» (bajo el seam el path real es el privado, `.privateSignOut`, y
//  confirmar borraría el store del simulador). En el sim el modo es `.icloud` ⇒ «Volver a iCloud» NO aparece
//  (solo en `.cloud`).
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

    /// Card n533 · la sesión que entra con Ajustes delante. `CloudAuthService` no es observable, así que la fila «Tu cuenta
    /// de Yala» —que solo existe con sesión— no aparecía hasta cerrar y volver a abrir Ajustes: medido con este test antes
    /// del arreglo (rojo en la espera de la fila). `-uitest-fake-cloud-session-after 25` hace llegar la sesión 25 s después
    /// de abrir Ajustes, como cuando se conecta la cuenta desde una pantalla de dentro y se vuelve. 25 y no menos: bajar
    /// hasta el final de Ajustes tarda más de 8 s en iOS 27.0, y con 8 la sesión llegaba antes de comprobar que no estaba.
    func test_sessionArrivingWithSettingsOpen_showsTheYalaAccountRow() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", cloudSessionAfterSeconds: 25)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")

        app.openProfile()
        // Al final de Ajustes antes de que llegue la sesión: sin ella, la fila no está.
        let footer = app.descendants(matching: .any)["profile_version_footer"].firstMatch
        var tries = 0
        while !footer.exists && tries < 14 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(footer.exists, "No se llegó al final de Ajustes.")
        let row = app.buttons["profile_yala_account"]
        XCTAssertFalse(row.exists, "Sin sesión todavía, «Tu cuenta de Yala» no debe estar.")

        // Los 25 s de la sesión, como mucho, más margen. Sin repintar, no llegaba nunca en esta corrida.
        XCTAssertTrue(row.waitForExistence(timeout: 40),
                      "Con la sesión ya conectada y Ajustes abierto, «Tu cuenta de Yala» debe aparecer sin cerrar Ajustes.")
    }
}
