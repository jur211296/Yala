//
//  SignOutProgressScreenUITests.swift
//  YalaUITests
//
//  Card p9q0 (recorrido de la bienvenida, 13-nov-2026): tras confirmar «Cerrar sesión», la app tapaba nada: volvía a
//  Ajustes con la fila girando y se podía navegar. Ahora sale su propia pantalla mientras trabaja.
//
//  Celda C (iCloud privado, seed `minimal`), con `-uitest-sign-out-keeps-session` como FRENO: el cierre se para en
//  `signOut()` antes del arm y no borra el simulador (molde de `SessionExitsPerCellUITests`). La espera del export a
//  iCloud dura lo bastante para ver la pantalla.
//

import XCTest

final class SignOutProgressScreenUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.buttons[identifier]
        var tries = 0
        while !element.isHittable && tries < 14 {
            app.swipeUp()
            tries += 1
        }
        return element
    }

    func test_signOut_showsItsOwnScreen_andGivesAjustesBackWhenItStops() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", signOutKeepsSession: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()

        scrollTo(app, "profile_security_signout").tap()
        let confirm = app.buttons["destructive_scope_confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "La hoja de «Cerrar sesión» no ofrece confirmar.")
        confirm.tap()

        let screen = app.descendants(matching: .any)["signout_progress_screen"]
        XCTAssertTrue(screen.waitForExistence(timeout: 5), """
            Tras confirmar no salió la pantalla propia del cierre: la app volvió a Ajustes con la fila girando.
            """)
        XCTAssertTrue(app.staticTexts["signout_progress_title"].exists, "La pantalla del cierre no dice qué está haciendo.")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "despues-pantalla-cerrando-sesion"
        shot.lifetime = .keepAlways
        add(shot)
        // Mientras trabaja, Ajustes no se toca: la pantalla queda encima (es una ventana de nivel alto).
        XCTAssertFalse(app.buttons["profile_security_signout"].isHittable,
                       "Con el cierre en marcha, la fila de Ajustes sigue al alcance del dedo.")

        // Al pararse (aquí, por el freno de la sesión), la pantalla se retira y sale el aviso de siempre en Ajustes.
        let survived = app.alerts.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "sigue abierta")).firstMatch
        let exportPending = app.alerts.buttons.matching(NSPredicate(
            format: "label IN %@", ["Cerrar sesión igualmente", "Quitar mis datos igualmente"])).firstMatch
        let deadline = Date().addingTimeInterval(120)
        while !survived.exists && Date() < deadline {
            if exportPending.exists { exportPending.tap() }
            _ = survived.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(survived.exists, "El cierre no llegó a su aviso.")
        XCTAssertFalse(screen.exists, "Con el cierre parado, la pantalla propia sigue tapando el aviso.")
        app.alerts.buttons.firstMatch.tap()
    }
}
