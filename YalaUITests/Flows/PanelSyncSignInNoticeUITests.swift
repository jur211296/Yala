//
//  PanelSyncSignInNoticeUITests.swift
//  YalaUITests
//
//  **Card pz4v (Jürgen, 2026-10-28): con la sesión de la nube caducada, el Panel lo dice.** Hasta este cambio la única puerta
//  era la tarjeta de Ajustes › «Dónde viven tus datos», y el Panel se veía tranquilo con 5 006 cambios sin subir.
//
//  **Dos seams que fingen la ENTRADA.** `-uitest-born-cloud-storage` hace que el controller lea modo nube (canal estable) y
//  `-uitest-sync-needs-sign-in` enciende la puerta de firmar con 5 006 cambios. Qué se pinta lo siguen decidiendo
//  `SyncSignInBannerLogic.showsPanelNotice` y la vista. **El caso de la CONDICIÓN** es el segundo: la puerta encendida
//  pero el canal sin la nube no saca el aviso, así que no sale «siempre».
//
//  **Scheme `Yala Dev`**, como el gate: con `Yala` la fila «¿Dónde viven tus datos?» no existe bajo `-uitest`.
//

import XCTest

final class PanelSyncSignInNoticeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_panelSaysSignInIsNeeded_andItsButtonLeadsToTheStorageCard() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", bornCloudStorage: true, syncNeedsSignIn: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")

        let banner = app.descendants(matching: .any)["panel_sync_signin_banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 10), "El Panel no avisa de que hay que volver a iniciar sesión.")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "5006")).firstMatch.exists
                      || app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "5.006")).firstMatch.exists
                      || app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "5,006")).firstMatch.exists,
                      "El aviso no dice cuántos cambios esperan.")

        app.buttons["panel_sync_signin_button"].tap()
        // La tarjeta de Ajustes, con su propia frase: el botón llevó a «Dónde viven tus datos».
        let card = app.descendants(matching: .any)["storage_sync_needs_signin_count"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), """
            «Iniciar sesión» del Panel no llevó a la tarjeta de «Dónde viven tus datos».
            """)
    }

    func test_withoutTheCloudChannel_thePanelSaysNothing() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", syncNeedsSignIn: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        XCTAssertTrue(app.buttons["profile_avatar"].waitForExistence(timeout: 10), "El Panel no cargó.")
        XCTAssertFalse(app.descendants(matching: .any)["panel_sync_signin_banner"].waitForExistence(timeout: 4),
                       "El aviso salió sin la nube: la condición del canal no está mirando.")
    }
}
