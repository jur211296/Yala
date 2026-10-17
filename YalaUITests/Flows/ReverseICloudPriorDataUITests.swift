//
//  ReverseICloudPriorDataUITests.swift
//  YalaUITests
//
//  **«Volver a iCloud» avisa antes si el iCloud del teléfono ya tiene datos de Yala** (ticket
//  `reverse-to-icloud-merges-prior-icloud-data-without-asking`, decisión A de Jürgen del 2026-10-15). Hasta ese ticket
//  la vuelta montaba el espejo encima y sumaba lo que hubiera, con un aviso que decía «No perderás nada».
//
//  Qué prueba esta suite y los unit no: que el toque de verdad pregunta ANTES de las confirmaciones de siempre, que cada
//  respuesta abre su diálogo, y que «Empezar sin ellos» con el borrado fallido no empieza la vuelta.
//
//  **Dos seams que fingen la ENTRADA.** `-uitest-born-cloud-storage` hace que el controller lea modo nube nacido aquí (sin
//  él la tarjeta de la vuelta no existe en el simulador: crear una cuenta en la nube pide App Attest). Y
//  `-uitest-reverse-prior-icloud` finge la respuesta de iCloud, que en el simulador no tiene CloudKit. Qué hace el botón
//  con cada respuesta lo decide `ReverseICloudPriorDataLogic`. **El caso de la CONDICIÓN** es `none`: sin nada ajeno, las
//  confirmaciones de siempre y ningún aviso nuevo. Sin él, los demás no distinguen «el aviso sale por los datos» de «el
//  aviso sale siempre».
//
//  **Ningún caso toca «Sí, volver a iCloud»**: con el modo real en `.icloud`, empezar la vuelta en el simulador no
//  significa nada. Que el borrado terminado empieza la vuelta y el fallido no lo fija `ReverseICloudPriorDataWiringTests`.
//
//  **Scheme `Yala Dev`**, como el gate y el CI: con `Yala` la fila «¿Dónde viven tus datos?» no existe bajo `-uitest`.
//

import XCTest

final class ReverseICloudPriorDataUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Baja hasta que el elemento sea alcanzable. Determinista: tope de intentos, sin sleeps.
    private func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.buttons[identifier]
        var tries = 0
        while !element.isHittable && tries < 14 {
            app.swipeUp()
            tries += 1
        }
        return element
    }

    /// Lanza con el teléfono nacido en la nube y la respuesta de iCloud fingida, abre «¿Dónde viven tus datos?» y toca
    /// «Volver a iCloud».
    private func tapRevert(prior: String, wipeFails: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", bornCloudStorage: true, reversePriorICloud: prior,
                            reversePriorICloudWipeFails: wipeFails)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        app.openProfile()

        let row = scrollTo(app, "storage_settings_row")
        XCTAssertTrue(row.waitForExistence(timeout: 5), """
            No aparece la fila «¿Dónde viven tus datos?» en Ajustes. Si la corrida usa el scheme `Yala`, es el kill de la \
            nube bajo `-uitest` y no este cambio: estos casos van con `Yala Dev`.
            """)
        row.tap()

        let revert = scrollTo(app, "storage_revert_button")
        XCTAssertTrue(revert.waitForExistence(timeout: 5),
                      "La tarjeta «Volver a iCloud» no salió con el teléfono nacido en la nube fingido.")
        revert.tap()
        return app
    }

    private func sheetButton(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.sheets.buttons[id].firstMatch
    }

    /// La CONDICIÓN: sin nada ajeno en iCloud, las confirmaciones de siempre y ningún aviso nuevo.
    func test_nothingInICloud_showsTheUsualConfirmation() {
        let app = tapRevert(prior: "none")

        XCTAssertTrue(sheetButton(app, "storage_revert_continue").waitForExistence(timeout: 5),
                      "Sin datos en iCloud, «Volver a iCloud» no abrió su confirmación de siempre.")
        XCTAssertFalse(sheetButton(app, "storage_revert_prior_merge").exists,
                       "El aviso de datos previos salió sin datos previos.")
    }

    /// Con datos ajenos, el aviso sale ANTES de las confirmaciones, y «Sumarlos» lleva al «¿Seguro?» de siempre.
    func test_priorData_asksFirst_andMergeGoesOnToTheConfirmation() {
        let app = tapRevert(prior: "found")

        let merge = sheetButton(app, "storage_revert_prior_merge")
        XCTAssertTrue(merge.waitForExistence(timeout: 5), """
            Con datos de Yala en iCloud, «Volver a iCloud» no avisó: la vuelta los sumaría sin que la persona lo sepa.
            """)
        XCTAssertTrue(sheetButton(app, "storage_revert_prior_discard").exists, "El aviso no ofrece «Empezar sin ellos».")
        XCTAssertFalse(sheetButton(app, "storage_revert_continue").exists,
                       "La confirmación de siempre se abrió detrás del aviso.")
        merge.tap()

        XCTAssertTrue(sheetButton(app, "storage_revert_confirm").waitForExistence(timeout: 5),
                      "«Sumarlos a mis datos» no llegó al «¿Seguro?» que empieza la vuelta.")
    }

    /// «Ahora no» se ve y no deja nada abierto detrás: ni la confirmación de la vuelta ni la del borrado.
    func test_priorData_notNowLeavesNothingOpen() {
        let app = tapRevert(prior: "found")

        let wait = sheetButton(app, "storage_revert_prior_wait")
        XCTAssertTrue(wait.waitForExistence(timeout: 5), "El aviso de datos previos no ofrece «Ahora no».")
        wait.tap()

        XCTAssertFalse(sheetButton(app, "storage_revert_confirm").waitForExistence(timeout: 3),
                       "«Ahora no» abrió la confirmación de la vuelta.")
        XCTAssertFalse(sheetButton(app, "storage_revert_prior_discard_confirm").exists,
                       "«Ahora no» abrió la confirmación del borrado.")
        XCTAssertFalse(sheetButton(app, "storage_revert_prior_merge").exists, "«Ahora no» dejó el aviso abierto.")
    }

    /// El caso del QA del 2026-10-15: solo gastos de grupo de otra cuenta. La sonda vieja no los contaba.
    func test_onlyGroupRecords_alsoAsks() {
        let app = tapRevert(prior: "foundGroups")

        XCTAssertTrue(sheetButton(app, "storage_revert_prior_merge").waitForExistence(timeout: 5),
                      "Con solo registros de grupos en iCloud, «Volver a iCloud» no avisó.")
    }

    /// «Empezar sin ellos» pide su «¿seguro?», y con el borrado fallido la vuelta no empieza: sale el error y la tarjeta
    /// sigue ofreciendo volver.
    func test_discardWithAFailedWipe_doesNotStartTheReverse() {
        let app = tapRevert(prior: "found", wipeFails: true)

        let discard = sheetButton(app, "storage_revert_prior_discard")
        XCTAssertTrue(discard.waitForExistence(timeout: 5), "No salió el aviso de datos previos.")
        discard.tap()

        let confirm = sheetButton(app, "storage_revert_prior_discard_confirm")
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "«Empezar sin ellos» no pidió confirmar el borrado.")
        confirm.tap()

        // El TEXTO del aviso, no `app.alerts.firstMatch`, que puede casar con otra alerta (`.claude/rules/testing.md`).
        let wipeFailed = app.alerts.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH %@", "No pudimos terminar de borrar")).firstMatch
        XCTAssertTrue(wipeFailed.waitForExistence(timeout: 5), "El borrado fallido no se dijo.")
        app.alerts.buttons.firstMatch.tap()

        XCTAssertTrue(app.buttons["storage_revert_button"].waitForExistence(timeout: 5), """
            Tras un borrado fallido, la tarjeta «Volver a iCloud» desapareció: la vuelta empezó con lo ajeno a medias en \
            iCloud.
            """)
    }

    /// Sin cuenta de iCloud la vuelta tampoco empieza: se quedaría esperando a que la persona abra iCloud, y entonces el
    /// espejo sumaría lo que hubiera sin preguntar.
    func test_noICloudAccount_doesNotOpenTheConfirmations() {
        let app = tapRevert(prior: "noAccount")

        let retry = app.alerts.buttons["storage_revert_prior_retry"].firstMatch
        XCTAssertTrue(retry.waitForExistence(timeout: 5), "Sin cuenta de iCloud no salió el aviso para abrirla.")
        XCTAssertFalse(sheetButton(app, "storage_revert_continue").exists,
                       "Sin cuenta de iCloud se abrió la confirmación de la vuelta.")
    }

    /// Sin respuesta de iCloud la vuelta no empieza: sale «No pudimos revisar tu iCloud» con «Reintentar».
    func test_failedCheck_doesNotOpenTheConfirmations() {
        let app = tapRevert(prior: "failed")

        let retry = app.alerts.buttons["storage_revert_prior_retry"].firstMatch
        XCTAssertTrue(retry.waitForExistence(timeout: 5), "Sin respuesta de iCloud no salió el aviso con «Reintentar».")
        XCTAssertFalse(sheetButton(app, "storage_revert_continue").exists,
                       "Sin respuesta de iCloud se abrió la confirmación de la vuelta.")
    }
}
