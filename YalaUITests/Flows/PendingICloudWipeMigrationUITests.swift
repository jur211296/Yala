//
//  PendingICloudWipeMigrationUITests.swift
//  YalaUITests
//
//  **«Activar la nube» con un borrado de iCloud pendiente pregunta antes de seguir** (ticket
//  `late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud`, decisión A de Jürgen del 2026-10-04). Hasta ese
//  ticket la tarjeta iba directa al consentimiento y el borrado se retiraba en silencio al arrancar en la nube.
//
//  Qué prueba esta suite y los unit no: que el toque de verdad abre el diálogo ANTES del consentimiento, que «Ahora no»
//  no deja nada abierto detrás y que «Activar la nube sin borrar» sigue a la cadena de siempre.
//
//  **El seam finge la ENTRADA** (`-uitest-pending-icloud-wipe`): el arm real lo reanudaría el propio arranque del XCUITest
//  y borraría la semilla. El caso de la CONDICIÓN corre sin él: sin borrado pendiente, el toque va directo al
//  consentimiento (`.claude/rules/testing.md`). Que la renuncia se apunte al arrancar la migración y no retire el borrado
//  hasta llegar a la nube lo fijan `PendingICloudWipeCloudTests`: aquí no se llega a firmar.
//
//  **Scheme `Yala Dev`**, como el gate y el CI: con `Yala` la fila «¿Dónde viven tus datos?» no existe bajo `-uitest`.
//

import XCTest

final class PendingICloudWipeMigrationUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Baja por Ajustes hasta que el elemento sea alcanzable. Determinista: tope de intentos, sin sleeps.
    private func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.buttons[identifier]
        var tries = 0
        while !element.isHittable && tries < 14 {
            app.swipeUp()
            tries += 1
        }
        return element
    }

    /// Lanza con App Attest fingido (sin él la tarjeta de la nube no sale en el simulador), abre «¿Dónde viven tus datos?»
    /// y devuelve «Activar la nube».
    private func openMigrateCard(pendingICloudWipe: Bool) -> (XCUIApplication, XCUIElement) {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", fakeAttestSupport: true, pendingICloudWipe: pendingICloudWipe)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()

        let row = scrollTo(app, "storage_settings_row")
        XCTAssertTrue(row.waitForExistence(timeout: 5), """
            No aparece la fila «¿Dónde viven tus datos?» en Ajustes. Si la corrida usa el scheme `Yala`, es el kill de la \
            nube bajo `-uitest` y no este cambio: estos casos van con `Yala Dev`.
            """)
        row.tap()

        let migrate = app.descendants(matching: .any)["storage_migrate_button"]
        XCTAssertTrue(migrate.waitForExistence(timeout: 5), "La tarjeta de la nube no salió con App Attest fingido.")
        return (app, migrate)
    }

    private func proceedButton(_ app: XCUIApplication) -> XCUIElement {
        app.sheets.buttons["storage_pending_icloud_wipe_proceed"].firstMatch
    }

    private func consentAccept(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["storage_consent_accept"]
    }

    /// La CONDICIÓN, sin el seam: sin borrado pendiente el toque va al consentimiento y no hay diálogo. Sin este caso, los
    /// dos de abajo no distinguen «el diálogo sale por el borrado» de «el diálogo sale siempre».
    func test_withoutPendingWipe_goesStraightToTheConsent() {
        let (app, migrate) = openMigrateCard(pendingICloudWipe: false)
        migrate.tap()

        XCTAssertTrue(consentAccept(app).waitForExistence(timeout: 10),
                      "Sin borrado pendiente, «Activar la nube» no llegó al consentimiento.")
        XCTAssertFalse(proceedButton(app).exists, "El diálogo del borrado pendiente salió sin ningún borrado pendiente.")
    }

    /// El diálogo sale ANTES del consentimiento, y «Ahora no» no deja nada detrás.
    func test_pendingWipe_asksFirst_andWaitLeavesNothingBehind() {
        let (app, migrate) = openMigrateCard(pendingICloudWipe: true)
        migrate.tap()

        XCTAssertTrue(proceedButton(app).waitForExistence(timeout: 5), """
            Con un borrado de iCloud pendiente, «Activar la nube» no preguntó: el borrado se retiraría en silencio al \
            arrancar en la nube.
            """)
        XCTAssertFalse(consentAccept(app).exists, "El consentimiento se abrió detrás del diálogo del borrado pendiente.")

        let wait = app.sheets.buttons["storage_pending_icloud_wipe_wait"].firstMatch
        XCTAssertTrue(wait.waitForExistence(timeout: 2), "El diálogo no ofrece «Ahora no».")
        wait.tap()

        XCTAssertFalse(consentAccept(app).waitForExistence(timeout: 3),
                       "«Ahora no» abrió el consentimiento: la activación siguió aunque la persona dijo que no.")
        XCTAssertFalse(proceedButton(app).exists, "«Ahora no» dejó el diálogo abierto.")
    }

    /// «Activar la nube sin borrar» sigue a la cadena de siempre: el consentimiento.
    func test_pendingWipe_proceedGoesOnToTheConsent() {
        let (app, migrate) = openMigrateCard(pendingICloudWipe: true)
        migrate.tap()

        let proceed = proceedButton(app)
        XCTAssertTrue(proceed.waitForExistence(timeout: 5), "No salió el diálogo del borrado pendiente.")
        proceed.tap()

        XCTAssertTrue(consentAccept(app).waitForExistence(timeout: 10), """
            «Activar la nube sin borrar» no llegó al consentimiento: la persona eligió activar la nube y la pantalla la \
            dejó sin camino.
            """)
    }
}
