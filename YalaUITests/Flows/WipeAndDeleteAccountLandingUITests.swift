//
//  WipeAndDeleteAccountLandingUITests.swift
//  YalaUITests
//
//  Encargo S27i (decisión de Jürgen, 2026-10-29): las dos acciones destructivas de Ajustes terminan en sitios distintos.
//   - «Vaciar datos» borra el contenido y deja a la persona en el Panel vacío, con su sesión y el aviso de crear la
//     primera cuenta. Ni onboarding ni Welcome.
//   - «Eliminar mi cuenta» lo borra todo, cierra la sesión y lleva al Welcome.
//
//  **Qué discrimina cada caso, medido contra la base:** bajo `-uitest-skip-onboarding` la bienvenida viene del dominio de
//  registro y sobrevive al barrido de preferencias, así que con el código de antes el vaciado TAMBIÉN acababa en el Panel
//  en el simulador (en un iPhone iba al onboarding). Lo que separa las dos versiones aquí es el aviso: la base no lo tiene.
//  El de Eliminar cuenta no tenía camino posible antes: sin el seam de borrado, «Eliminar» no completa en el simulador.
//
//  **Celda F para Eliminar cuenta**, no la D: el borrado de la D pasa por la zona de iCloud, y el simulador no tiene
//  cuenta de iCloud que borrar. La E no tiene seam de `storageMode == .cloud`. La D y la E las cubren las tablas y el
//  cableado (`DestructiveScopeLogicTests`, `WipeDataKeepsAccountWiringTests`, `AccountDeletionServiceTests`).
//

import XCTest

final class WipeAndDeleteAccountLandingUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Baja por Ajustes hasta que la fila sea alcanzable. Determinista: tope de intentos, sin sleeps.
    private func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.buttons[identifier]
        var tries = 0
        while !element.isHittable && tries < 14 {
            app.swipeUp()
            tries += 1
        }
        return element
    }

    /// «Vaciar datos» con vida personal y cuenta de Yala (celda D): se queda en el Panel, con el aviso, y la cuenta sigue.
    func test_wipeData_staysOnTheEmptyPanel_withTheToast_andKeepsTheAccount() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", cloudSession: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()

        let resetRow = scrollTo(app, "profile_security_reset_data")
        XCTAssertTrue(resetRow.waitForExistence(timeout: 5), "No apareció «Vaciar datos».")
        resetRow.tap()
        let start = app.buttons["wipe_data_start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "No apareció «Vaciar mis datos».")
        start.tap()
        let confirm = app.buttons["destructive_scope_confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "No apareció la hoja de alcance de Vaciar.")
        confirm.tap()
        // El texto de la alerta, no `app.alerts.firstMatch` (`testing.md`).
        let final = app.alerts.buttons["Vaciar definitivamente"].firstMatch
        XCTAssertTrue(final.waitForExistence(timeout: 5), "No salió «¿Seguro? Esto es definitivo.».")
        final.tap()

        let toast = app.descendants(matching: .any)["positive_toast"]
        XCTAssertTrue(toast.waitForExistence(timeout: 10), """
            Tras vaciar no salió el aviso de empezar de cero: la persona queda en un Panel vacío sin saber por dónde seguir.
            """)
        XCTAssertTrue(toast.label.contains("empezaste de cero"), "El aviso no es el de vaciar: «\(toast.label)».")
        XCTAssertTrue(app.buttons["panel_create_first_account"].waitForExistence(timeout: 5),
                      "El Panel vacío no ofrece «Crea tu primera cuenta».")
        XCTAssertFalse(app.buttons["welcome_hero_cta"].exists, "Vaciar llevó al Welcome.")

        // La cuenta de Yala sigue: Ajustes la sigue enseñando.
        app.openProfile()
        let accountRow = scrollTo(app, "profile_yala_account")
        XCTAssertTrue(accountRow.waitForExistence(timeout: 5), "Tras vaciar, Ajustes ya no enseña «Tu cuenta de Yala».")
    }

    /// «Eliminar mi cuenta» (celda F, solo grupos): el borrado completa, la sesión se cierra y la app llega al Welcome.
    func test_deleteAccount_closesTheSession_andLandsOnTheWelcome() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "solo-grupos", groupInvite: true, cloudSession: true, fakeAccountDeletion: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()

        let accountRow = scrollTo(app, "profile_yala_account")
        XCTAssertTrue(accountRow.waitForExistence(timeout: 5), "Falta «Tu cuenta de Yala».")
        accountRow.tap()
        let delete = app.buttons["yala_account_delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "Falta «Eliminar mi cuenta».")
        delete.tap()
        let proceed = app.buttons["delete_account_continue"]
        XCTAssertTrue(proceed.waitForExistence(timeout: 5), "No apareció la hoja de eliminar la cuenta.")
        proceed.tap()
        XCTAssertTrue(app.alerts.staticTexts["Esto es definitivo"].firstMatch.waitForExistence(timeout: 5),
                      "No salió la confirmación final.")
        app.alerts.buttons["Eliminar mi cuenta"].firstMatch.tap()

        // En un iPhone con el montaje neutro de solo grupos el cierre cambia el almacén en caliente y aterriza en el Welcome;
        // el simulador monta con espejo y ese cambio se salta (`swiftui-ds.md`), así que pide reabrir. Se acepta cualquiera
        // de las dos y, si pide reabrir, se reabre como lo haría la persona: el arranque hace el borrado armado.
        let welcome = app.buttons["welcome_hero_cta"]
        let reopen = app.descendants(matching: .any)["signout_relaunch_screen"]
        let deadline = Date().addingTimeInterval(30)
        while !welcome.exists && !reopen.exists && Date() < deadline {
            _ = welcome.waitForExistence(timeout: 1)
        }
        if !welcome.exists {
            XCTAssertTrue(reopen.exists, "Tras eliminar la cuenta no salió ni el Welcome ni la pantalla de reabrir.")
            app.terminate()
            // Sin reset, sin seed y sin la sesión fingida: el arranque siguiente de la misma instalación.
            app.launchForUITest(reset: false, skipOnboarding: false, seed: nil)
        }
        XCTAssertTrue(welcome.waitForExistence(timeout: 30), "Tras eliminar la cuenta la app no llegó al Welcome.")
        XCTAssertFalse(app.buttons["profile_avatar"].exists, "Tras eliminar la cuenta sigue el Panel debajo del Welcome.")
    }
}
