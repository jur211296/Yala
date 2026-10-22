//
//  WelcomeLateNoticeKeptGroupsUITests.swift
//  YalaUITests
//
//  Ticket `groups-kept-by-the-late-notice-are-purged-by-the-welcome-fresh-start`, decisión A de Jürgen (2026-10-04).
//
//  «Encontramos datos tuyos en iCloud» → «Empezar de cero» conserva los grupos y devuelve a la persona al onboarding. Si
//  cancela y vuelve a elegir «Es mi primera vez», el Welcome le ofrecía el borrado de «aquí empieza otro usuario» sobre
//  esos mismos grupos. El simulador no tiene iCloud, así que el aviso no se puede recorrer: se monta el estado que deja
//  —grupos en el teléfono sin nada personal (`solo-grupos-tras-aviso`) y su marca (`-uitest-late-notice-kept-groups`)— y se mira
//  la decisión del Welcome con los dos caminos:
//   · misma persona (con la marca): «Es mi primera vez» va al onboarding sin el alert;
//   · handover real (sin la marca, mismo seed): el alert de siempre. Es el control positivo: el seed no deja nada
//     personal (ni las categorías que siembra para construirse), así que ese alert sale por los GRUPOS. Con él en verde,
//     el caso de arriba no puede pasar porque el seed dejó de producir grupos.
//

import XCTest

final class WelcomeLateNoticeKeptGroupsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func goToFirstTime(_ app: XCUIApplication) {
        // `uitest_ready` vive en el root de ContentView, que queda cubierto por el cover del Welcome: se espera el Hero.
        let heroCTA = app.buttons["welcome_hero_cta"]
        XCTAssertTrue(heroCTA.waitForExistence(timeout: 60), "No apareció el CTA del Hero.")
        heroCTA.tap()
        let newBranch = app.buttons["welcome_chooser_new"]
        XCTAssertTrue(newBranch.waitForExistence(timeout: 10), "No apareció la card «Es mi primera vez».")
        newBranch.tap()
    }

    /// Misma persona: los grupos que conservó el aviso no levantan el alert y el onboarding abre directo.
    func test_groupsKeptByTheLateNotice_firstTimePrivate_opensTheOnboardingWithoutTheHandoverAlert() throws {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, skipOnboarding: false, seed: "solo-grupos-tras-aviso", lateNoticeKeptGroups: true)
        goToFirstTime(app)

        XCTAssertTrue(app.buttons["onboarding_next_button"].waitForExistence(timeout: 15), """
            Con los grupos que conservó el aviso tardío, «Es mi primera vez» no llegó al onboarding. Si en pantalla está \
            «Empezar desde cero», el Welcome sigue viendo esos grupos como datos de otra persona y le ofrece borrarlos.
            """)
        XCTAssertEqual(app.alerts.count, 0, "Salió un alert sobre el onboarding: el del handover no debería existir aquí.")
    }

    /// Handover real: los mismos grupos, sin el aviso previo, piden el borrado de siempre.
    func test_groupsWithoutTheLateNotice_firstTimePrivate_stillAsksTheHandoverAlert() throws {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, skipOnboarding: false, seed: "solo-grupos-tras-aviso")
        goToFirstTime(app)

        XCTAssertTrue(app.alerts.buttons.element(boundBy: 1).waitForExistence(timeout: 15), """
            Sin la marca del aviso tardío, los grupos de otra persona ya no piden «Empezar desde cero»: el handover real \
            dejó de preguntar, o el seed `solo-grupos-tras-aviso` dejó de producir grupos (y el caso de la misma persona no prueba nada).
            """)
        XCTAssertFalse(app.buttons["onboarding_next_button"].exists,
                       "El onboarding se abrió debajo del alert: el handover real siguió sin esperar la respuesta.")
    }
}
