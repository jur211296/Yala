//
//  PendingICloudWipeMigrationUITests.swift
//  YalaUITests
//
//  **«Activar la nube» con un borrado de iCloud pendiente pregunta antes de seguir** (ticket
//  `late-wipe-arm-is-dropped-silently-when-the-device-moves-to-the-cloud`, decisión A de Jürgen del 2026-10-04). Hasta ese
//  ticket la tarjeta iba directa a la hoja de activar y el borrado se retiraba en silencio al arrancar en la nube.
//
//  Qué prueba esta suite y los unit no: que el toque de verdad abre el diálogo ANTES de la hoja de activar, que «Ahora no»
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
    private func openMigrateCard(pendingICloudWipe: Bool, halfway: Bool = false) -> (XCUIApplication, XCUIElement) {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", fakeAttestSupport: true, pendingICloudWipe: pendingICloudWipe,
                            pendingICloudWipeHalfway: halfway)
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

    /// Desde la revisión 2.3 (decisión 57) es una hoja, no un globo: sus botones no viven en `app.sheets`.
    private func proceedButton(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["storage_pending_icloud_wipe_proceed"].firstMatch
    }

    /// La hoja única de activar la nube (UX 2.2 · L20-11), por su título: desde ese día es lo que abre el toque, en vez
    /// de la hoja de activar suelto.
    private func consentAccept(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts["storage_activation_sheet"]
    }

    /// La CONDICIÓN, sin el seam: sin borrado pendiente el toque va a la hoja de activar y no hay diálogo. Sin este caso, los
    /// dos de abajo no distinguen «el diálogo sale por el borrado» de «el diálogo sale siempre».
    func test_withoutPendingWipe_goesStraightToTheConsent() {
        let (app, migrate) = openMigrateCard(pendingICloudWipe: false)
        migrate.tap()

        XCTAssertTrue(consentAccept(app).waitForExistence(timeout: 10),
                      "Sin borrado pendiente, «Activar la nube» no llegó a la hoja de activar.")
        XCTAssertFalse(proceedButton(app).exists, "El diálogo del borrado pendiente salió sin ningún borrado pendiente.")
    }

    /// El diálogo sale ANTES de la hoja de activar, y «Ahora no» no deja nada detrás.
    func test_pendingWipe_asksFirst_andWaitLeavesNothingBehind() {
        let (app, migrate) = openMigrateCard(pendingICloudWipe: true)
        migrate.tap()

        XCTAssertTrue(proceedButton(app).waitForExistence(timeout: 5), """
            Con un borrado de iCloud pendiente, «Activar la nube» no preguntó: el borrado se retiraría en silencio al \
            arrancar en la nube.
            """)
        XCTAssertFalse(consentAccept(app).exists, "El consentimiento se abrió detrás del diálogo del borrado pendiente.")

        let wait = app.buttons["storage_pending_icloud_wipe_wait"].firstMatch
        XCTAssertTrue(wait.waitForExistence(timeout: 2), "El diálogo no ofrece «Ahora no».")
        wait.tap()

        XCTAssertFalse(consentAccept(app).waitForExistence(timeout: 3),
                       "«Ahora no» abrió la hoja de activar: la activación siguió aunque la persona dijo que no.")
        XCTAssertFalse(proceedButton(app).exists, "«Ahora no» dejó el diálogo abierto.")
    }

    /// **La regresión de la decisión 57**: la hoja dice que el borrado no terminó y ofrece terminarlo; el globo de antes
    /// solo ofrecía «Activar sin borrar» y «Ahora no». Sin empezar, iCloud sigue intacto y la hoja lo dice.
    func test_pendingWipe_sheetOffersToFinishTheDeletion() {
        let (app, migrate) = openMigrateCard(pendingICloudWipe: true)
        migrate.tap()

        XCTAssertTrue(app.descendants(matching: .any)["storage_pending_icloud_wipe_sheet"].waitForExistence(timeout: 5),
                      "Con un borrado pendiente no salió la hoja.")
        let finish = app.buttons["storage_pending_icloud_wipe_finish"].firstMatch
        XCTAssertTrue(finish.exists, "La hoja no ofrece terminar el borrado.")
        XCTAssertTrue(proceedButton(app).exists, "La hoja no ofrece activar y conservar.")
        let body = app.descendants(matching: .any)["storage_pending_icloud_wipe_body"]
        XCTAssertTrue(body.label.contains("se quedan"), "Sin empezar, la hoja no dice que los datos de iCloud se quedan.")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "despues-4-borrado-pendiente"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// «Terminar de borrar y empezar de cero» no borra desde Ajustes: cierra Ajustes y abre la hoja que ya termina ese
    /// borrado, en su «¿seguro?». «Mantener» la cierra sin tocar nada (el caso no toca el botón que borra).
    func test_pendingWipe_finishOpensTheExistingWipeSheetAtItsConfirmation() {
        let (app, migrate) = openMigrateCard(pendingICloudWipe: true)
        migrate.tap()

        let finish = app.buttons["storage_pending_icloud_wipe_finish"].firstMatch
        XCTAssertTrue(finish.waitForExistence(timeout: 5), "No salió la hoja del borrado pendiente.")
        finish.tap()

        let confirm = app.descendants(matching: .any)["late_icloud_armed_finish_confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), """
            «Terminar de borrar y empezar de cero» no abrió el «¿seguro?» de la hoja que termina el borrado.
            """)
        XCTAssertFalse(app.descendants(matching: .any)["storage_migrate_button"].exists,
                       "Ajustes sigue abierto detrás de la hoja del borrado.")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "despues-5-terminar-el-borrado"
        shot.lifetime = .keepAlways
        add(shot)
        let keep = app.buttons["late_icloud_armed_finish_confirm_primary"].firstMatch
        XCTAssertTrue(keep.exists, "El «¿seguro?» no ofrece quedarse como estaba.")
        keep.tap()
        XCTAssertFalse(confirm.waitForExistence(timeout: 3), "«Mantener» dejó la hoja abierta.")
        XCTAssertFalse(app.descendants(matching: .any)["late_icloud_wiping"].exists, "«Mantener» empezó a borrar.")
    }

    /// A medias, iCloud ya está vacío: la hoja no dice que sus datos se quedan, y terminar abre el «¿seguro?» de la hoja
    /// que termina el borrado (no la pantalla cuyo botón principal es «Déjalo así»).
    func test_halfwayWipe_tellsItsOwnTruth_andFinishOpensTheHalfwayScreen() {
        let (app, migrate) = openMigrateCard(pendingICloudWipe: false, halfway: true)
        migrate.tap()

        let body = app.descendants(matching: .any)["storage_pending_icloud_wipe_body"]
        XCTAssertTrue(body.waitForExistence(timeout: 5), "A medias no salió la hoja del borrado pendiente.")
        XCTAssertTrue(body.label.contains("ya se borró"), "A medias, la hoja no dice que lo de iCloud ya se borró.")
        XCTAssertFalse(body.label.contains("se quedan"), "A medias, la hoja promete que los datos de iCloud se quedan.")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "despues-6-borrado-a-medias"
        shot.lifetime = .keepAlways
        add(shot)

        app.buttons["storage_pending_icloud_wipe_finish"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["late_icloud_left_halfway_confirm"].waitForExistence(timeout: 10),
                      "A medias, terminar no abrió el «¿seguro?» de terminar el borrado.")
        app.buttons["late_icloud_close"].firstMatch.tap()
    }

    /// «Activar la nube sin borrar» sigue a la cadena de siempre: la hoja de activar.
    func test_pendingWipe_proceedGoesOnToTheConsent() {
        let (app, migrate) = openMigrateCard(pendingICloudWipe: true)
        migrate.tap()

        let proceed = proceedButton(app)
        XCTAssertTrue(proceed.waitForExistence(timeout: 5), "No salió el diálogo del borrado pendiente.")
        proceed.tap()

        XCTAssertTrue(consentAccept(app).waitForExistence(timeout: 10), """
            «Activar la nube sin borrar» no llegó a la hoja de activar: la persona eligió activar la nube y la pantalla la \
            dejó sin camino.
            """)
    }

    /// UX 2.2 · L20-11/12 (decisión de Jürgen, opción C): activar es UNA hoja con los dos botones de entrar, «Ver los
    /// detalles», «Exportar una copia antes» y «Cancelar» a la vista. «Cancelar» la cierra sin abrir «¿Activar la nube?»,
    /// «¿Seguro?» ni el selector de Apple o Google, y la tarjeta sigue ahí: no arrancó nada.
    func test_activationSheet_isOneStep_andCancelStops() {
        let (app, migrate) = openMigrateCard(pendingICloudWipe: false)
        migrate.tap()

        XCTAssertTrue(consentAccept(app).waitForExistence(timeout: 10), "«Activar la nube» no abrió la hoja de activar.")
        XCTAssertTrue(app.buttons["storage_activation_apple"].exists, "La hoja no ofrece «Continuar con Apple».")
        XCTAssertTrue(app.buttons["storage_activation_google"].exists, "La hoja no ofrece «Continuar con Google».")
        XCTAssertTrue(app.buttons["storage_activation_export"].exists, "La hoja no ofrece «Exportar una copia antes».")

        // «Ver los detalles» despliega el texto legal entero, a un toque.
        let details = app.buttons["storage_activation_details"]
        XCTAssertTrue(details.exists, "La hoja no ofrece «Ver los detalles».")
        details.tap()
        XCTAssertTrue(app.descendants(matching: .any)["storage_activation_details_text"].waitForExistence(timeout: 3),
                      "«Ver los detalles» no desplegó el texto legal.")

        let cancel = app.buttons["storage_activation_cancel"]
        XCTAssertTrue(cancel.exists, "La hoja no enseña «Cancelar».")
        cancel.tap()

        XCTAssertFalse(consentAccept(app).waitForExistence(timeout: 3), "«Cancelar» no cerró la hoja.")
        XCTAssertFalse(app.descendants(matching: .any)["storage_signin_chooser"].exists,
                       "«Cancelar» abrió el selector de Apple o Google.")
        XCTAssertFalse(app.descendants(matching: .any)["storage_progress_card"].exists,
                       "«Cancelar» arrancó la activación.")
        XCTAssertTrue(app.descendants(matching: .any)["storage_migrate_button"].waitForExistence(timeout: 3),
                      "La tarjeta de la nube desapareció tras cancelar.")
    }
}
