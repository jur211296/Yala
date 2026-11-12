//
//  CloudAdoptOfferUITests.swift
//  YalaUITests
//
//  **El segundo dispositivo propone activar la nube solo** (card vbf9). Cuando el marcador de migración de otro
//  dispositivo del mismo iCloud llega aquí, el Panel enseña «Tus datos ya están en tu cuenta en la nube» y «Activar» lleva
//  a «Dónde viven tus datos» con la activación ya abierta: un paso, en vez de encontrar «Activar la nube en este
//  dispositivo» en Perfil.
//
//  **El seam finge la ENTRADA, no la decisión**: `-uitest-cloud-adopt-offer` solo hace que `markerDecision()` vea el
//  marcador (en el simulador no hay CloudKit). El resto de condiciones son las reales, y `-uitest-fake-attest-support`
//  abre la puerta de App Attest como en `StorageMigrationAttestUITests`. **El caso de la CONDICIÓN** es el segundo: sin el
//  marcador, ningún aviso. Scheme `Yala Dev`, como el gate y el CI.
//

import XCTest

final class CloudAdoptOfferUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func test_markerFromAnotherDevice_panelOffersTheCloud_andActivateOpensTheActivation() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", fakeAttestSupport: true, extraArguments: ["-uitest-cloud-adopt-offer"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")

        let activate = app.buttons["cloud_adopt_offer_action"]
        XCTAssertTrue(activate.waitForExistence(timeout: 10), """
            Con el marcador de otro dispositivo, el Panel no propone activar la nube aquí: la persona tiene que encontrar \
            «Activar la nube en este dispositivo» en Perfil (QA guiado del TestFlight 19, E2).
            """)
        attach(app, "despues-vbf9-panel")
        activate.tap()

        let sheet = app.descendants(matching: .any)["storage_activation_sheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), """
            «Activar» no llevó a la activación: la persona tiene que volver a tocar en «Dónde viven tus datos».
            """)
        attach(app, "despues-vbf9-activacion")
    }

    /// La CONDICIÓN: sin el marcador no hay aviso. Se afirma junto a una presencia (el Panel cargado), para que la ausencia
    /// discrimine.
    func test_withoutTheMarker_panelDoesNotOfferTheCloud() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", fakeAttestSupport: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")

        // El mismo ancla que `PanelDashboardUITests`: con ella a la vista, el Panel ya pintó su cabecera y sus avisos.
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 10),
                      "El Panel no cargó: la ausencia del aviso no diría nada.")
        XCTAssertFalse(app.buttons["cloud_adopt_offer_action"].exists,
                       "Sin marcador de otro dispositivo, el Panel propone activar la nube.")
    }
}
