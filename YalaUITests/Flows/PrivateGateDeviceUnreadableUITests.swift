//
//  PrivateGateDeviceUnreadableUITests.swift
//  YalaUITests
//
//  Ticket `private-gate-device-notice-has-no-forward-exit` (decisión de Jürgen del 2026-10-12: «solo lo alcanzable»).
//  En «Es mi primera vez → privado», un fallo al leer lo que ya hay en el teléfono salía como «Ya hay datos en este
//  teléfono», con borrar o volver como únicas salidas. Ahora sale «No pudimos revisar este teléfono», con «Reintentar» y
//  «Volver», y de esa pantalla no cuelga ningún borrado.
//
//  En el simulador la puerta no mide (hermeticidad) y el mount nunca es neutro, así que la LECTURA del teléfono se finge
//  con `-uitest-private-gate-device-reading`; lo que se pinta lo decide la tabla de producción. iCloud cuenta «sin
//  cuenta», que es lo que el simulador es de verdad.
//

import XCTest

final class PrivateGateDeviceUnreadableUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Hero → «Es mi primera vez». Sin seed el teléfono está vacío, así que no sale el alert de «Empezar desde cero» y la
    /// rama privada llega a la puerta (con el bypass de una sola card, sin sub-chooser).
    private func openPrivateGate(_ app: XCUIApplication) {
        let heroCTA = app.buttons["welcome_hero_cta"]
        XCTAssertTrue(heroCTA.waitForExistence(timeout: 60), "No apareció el CTA del Hero.")
        heroCTA.tap()
        let newBranch = app.buttons["welcome_chooser_new"]
        XCTAssertTrue(newBranch.waitForExistence(timeout: 10), "No apareció la card «Es mi primera vez».")
        newBranch.tap()
        let privateCard = app.buttons["welcome_new_private"]
        if privateCard.waitForExistence(timeout: 3) { privateCard.tap() }
    }

    /// **EL PIN DEL TICKET.** La lectura falla: la puerta lo dice y ofrece reintentar, sin el aviso de borrar.
    func test_unreadablePhone_saysSo_offersRetry_andNoWipe() throws {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil, privateGateDeviceReading: "unreadable")
        openPrivateGate(app)

        let retry = app.buttons["welcome_private_icloud_device_unreadable_cta"]
        XCTAssertTrue(retry.waitForExistence(timeout: 15), """
            Con la lectura del teléfono fallida no salió «No pudimos revisar este teléfono». Antes salía el aviso de \
            «Ya hay datos» con borrar o volver, sin un dato detrás.
            """)
        XCTAssertTrue(app.buttons["welcome_private_icloud_device_unreadable_secondary"].exists, "Falta «Volver».")
        XCTAssertFalse(app.buttons["welcome_private_icloud_wipe_device"].exists,
                       "Ninguna pantalla de un teléfono que no se pudo leer ofrece borrarlo.")

        // «Reintentar» vuelve a medir: con la lectura todavía fallida, la misma pantalla.
        retry.tap()
        XCTAssertTrue(app.buttons["welcome_private_icloud_device_unreadable_cta"].waitForExistence(timeout: 15),
                      "«Reintentar» no volvió a medir.")

        // «Volver» sale de la puerta al chooser.
        app.buttons["welcome_private_icloud_device_unreadable_secondary"].tap()
        XCTAssertTrue(app.buttons["welcome_chooser_new"].waitForExistence(timeout: 10)
                      || app.buttons["welcome_new_private"].waitForExistence(timeout: 2),
                      "«Volver» no sacó de la puerta.")
    }

    /// **Control**: con la lectura buena y datos en el teléfono, sigue el aviso de siempre. Sin este caso, el de arriba
    /// pasaría también si el seam pintara la pantalla nueva para cualquier lectura.
    func test_readablePhoneWithData_stillShowsTheUsualNotice() throws {
        let app = XCUIApplication()
        app.launchForUITest(reset: true, skipOnboarding: false, seed: nil, privateGateDeviceReading: "present")
        openPrivateGate(app)

        XCTAssertTrue(app.buttons["welcome_private_icloud_keep_device"].waitForExistence(timeout: 15),
                      "Con datos legibles en el teléfono tiene que salir «Ya hay datos en este teléfono».")
        XCTAssertFalse(app.buttons["welcome_private_icloud_device_unreadable_cta"].exists)
    }
}
