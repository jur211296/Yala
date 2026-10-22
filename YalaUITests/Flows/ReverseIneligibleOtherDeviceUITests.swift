//
//  ReverseIneligibleOtherDeviceUITests.swift
//  YalaUITests
//
//  **«Volver a iCloud» en un teléfono que entró en una cuenta de la nube creada en otro** (card i9qh del QA guiado del
//  2026-10-19). `ReverseEligibility` decide `.degradedNoMap` y no es pasajero, así que la tarjeta ya no dice «Ahora mismo
//  no puedes…»: dice por qué y dónde sí se puede.
//
//  `-uitest-adopted-cloud-storage` finge la ENTRADA (modo nube, la cuenta no nació aquí); el simulador no tiene mapa de
//  CloudKit, así que la decisión la sigue tomando `ReverseEligibility`. **El caso de la CONDICIÓN** es el nacido aquí: con
//  la misma pantalla, el botón sale y el texto nuevo no.
//
//  **Scheme `Yala Dev`**: con `Yala` la fila «¿Dónde viven tus datos?» no existe bajo `-uitest`.
//

import XCTest

final class ReverseIneligibleOtherDeviceUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func scrollTo(_ app: XCUIApplication, _ element: XCUIElement) {
        var tries = 0
        while !(element.exists && element.isHittable) && tries < 14 {
            app.swipeUp()
            tries += 1
        }
    }

    private func openStorage(bornCloud: Bool, adopted: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", bornCloudStorage: bornCloud, adoptedCloudStorage: adopted)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()
        let row = app.buttons["storage_settings_row"]
        scrollTo(app, row)
        XCTAssertTrue(row.waitForExistence(timeout: 5), """
            No aparece la fila «¿Dónde viven tus datos?». Si la corrida usa el scheme `Yala`, es el kill de la nube bajo \
            `-uitest`: este caso va con `Yala Dev`.
            """)
        row.tap()
        return app
    }

    /// La cuenta llegó desde otro dispositivo: sin botón, y el texto que dice por qué (no el «ahora mismo»).
    func test_adoptedAccount_explainsItCannotGoBackFromThisDevice() {
        let app = openStorage(bornCloud: false, adopted: true)
        let note = app.staticTexts["storage_revert_ineligible_other_device"]
        scrollTo(app, note)
        XCTAssertTrue(note.waitForExistence(timeout: 5),
                      "Con la cuenta llegada de otro dispositivo, la tarjeta no explicó por qué no se puede volver desde aquí.")
        XCTAssertFalse(app.staticTexts["storage_revert_ineligible"].exists,
                       "Salió el texto pasajero («Ahora mismo…») para un caso que no se cura esperando.")
        XCTAssertFalse(app.buttons["storage_revert_button"].exists,
                       "«Volver a iCloud» salió en un teléfono sin mapa de CloudKit.")
    }

    /// La CONDICIÓN: nacida aquí, la vuelta se ofrece y el texto nuevo no sale.
    func test_bornHere_offersTheReturnAndNoNote() {
        let app = openStorage(bornCloud: true, adopted: false)
        let revert = app.buttons["storage_revert_button"]
        scrollTo(app, revert)
        XCTAssertTrue(revert.waitForExistence(timeout: 5), "Nacida aquí, «Volver a iCloud» no salió.")
        XCTAssertFalse(app.staticTexts["storage_revert_ineligible_other_device"].exists,
                       "El texto de «otro dispositivo» salió con la cuenta nacida aquí.")
    }
}
