//
//  AjustesYProNecesariasLote10UITests.swift
//  YalaUITests
//
//  Lote 10 de las mejoras necesarias 2.3 (zona 40, Perfil y Ajustes): tres textos que mandaban al sitio equivocado o
//  callaban algo. Cada caso deja su captura como adjunto del `.xcresult`.
//
//  1. La prueba de Pro decía «Cancela en Ajustes»: el texto nombra ahora los ajustes del dispositivo.
//  2. «Resumen con IA» es de Pro y su fila no lo decía: sin Pro lleva la marca, y encenderla abre la hoja de Pro, como
//     la de Yala IA (L14-11, opción D).
//  3. Sin registros, «Exportar registros» salía gris sin motivo: el motivo va a la vista, en el subtítulo de la fila.
//

import XCTest

@MainActor
final class AjustesYProNecesariasLote10UITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - 1 · La prueba de Pro

    func test_trialTimeline_saysWhereToCancel() {
        let app = XCUIApplication()
        app.launchForUITest(fakePrices: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()
        let row = app.buttons["profile_yala_pro"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No salió la fila «Yala Pro».")
        row.tap()

        let timeline = app.descendants(matching: .any)["pro_trial_timeline"]
        XCTAssertTrue(timeline.waitForExistence(timeout: 10), "Falta «Así funciona la prueba».")
        var swipes = 0
        while !timeline.isHittable && swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        capture(app, "1-prueba-pro")
        XCTAssertTrue(app.staticTexts["Cancela en los ajustes de tu dispositivo y no se cobra nada."].exists,
                      "La prueba tiene que decir dónde se cancela: en los ajustes del dispositivo.")
        XCTAssertFalse(app.staticTexts["Cancela en Ajustes y no se cobra nada."].exists,
                       "Sigue el texto viejo, que mandaba a los Ajustes de Yala.")
    }

    // MARK: - 2 · Resumen con IA es de Pro

    func test_aiPrivacy_withoutPro_insightsRowIsMarkedPro_andOpensPro() {
        let app = XCUIApplication()
        app.launchForUITest(pro: false, fakePrices: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openAIPrivacy(app)

        let insightsRow = app.switches["ai_privacy_insights_row"]
        XCTAssertTrue(insightsRow.waitForExistence(timeout: 10), "Falta la fila de Resumen con IA en Privacidad.")
        capture(app, "2-privacidad-ia-sin-pro")
        XCTAssertTrue(app.switches["ai_privacy_chat_row"].label.contains("PRO"),
                      "Control: la fila de Yala IA lleva la marca sin Pro (\(app.switches["ai_privacy_chat_row"].label)).")
        XCTAssertTrue(insightsRow.label.contains("PRO"),
                      "Resumen con IA es de Pro y su fila no lleva la marca: «\(insightsRow.label)».")

        insightsRow.switches.firstMatch.tap()
        XCTAssertTrue(app.buttons["upgrade_prompt_cta"].waitForExistence(timeout: 10),
                      "Sin Pro, encender Resumen con IA tiene que abrir la hoja de Pro, no pedir un permiso que no sirve.")
        XCTAssertFalse(app.alerts.firstMatch.exists, "Sin Pro no se pide el permiso.")
        app.buttons["upgrade_prompt_not_now"].tap()
        XCTAssertTrue(insightsRow.waitForExistence(timeout: 10))
        XCTAssertEqual(insightsRow.value as? String, "0", "Sin comprar, la fila vuelve a apagado.")
    }

    /// Control: con Pro no hay marca y encenderla pide el permiso de siempre.
    func test_aiPrivacy_withPro_insightsRowHasNoMark_andAsksTheConsent() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openAIPrivacy(app)

        let insightsRow = app.switches["ai_privacy_insights_row"]
        XCTAssertTrue(insightsRow.waitForExistence(timeout: 10), "Falta la fila de Resumen con IA en Privacidad.")
        XCTAssertFalse(insightsRow.label.contains("PRO"), "Con Pro la fila no lleva la marca: «\(insightsRow.label)».")
        insightsRow.switches.firstMatch.tap()
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 10), "Con Pro, encenderla pide el permiso.")
        XCTAssertFalse(app.buttons["upgrade_prompt_cta"].exists, "Con Pro no sale la hoja de Pro.")
    }

    // MARK: - 3 · Exportar sin registros

    func test_exportRow_withoutRecords_saysWhy() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()

        let exportRow = scrollToExportRow(app)
        XCTAssertTrue(exportRow.exists, "No apareció la fila «Exportar registros» en Ajustes.")
        capture(app, "3-exportar-sin-registros")
        XCTAssertFalse(exportRow.isEnabled, "Sin registros la fila sigue apagada.")
        XCTAssertTrue(exportRow.label.contains("No hay registros para exportar"),
                      "La fila apagada tiene que decir por qué, a la vista: «\(exportRow.label)».")
        XCTAssertFalse(exportRow.label.contains("Para Excel o Google Sheets"),
                       "Apagada, la fila no promete para qué sirve: dice por qué no se puede.")
    }

    /// Control: con registros la fila se enciende y conserva su subtítulo de siempre.
    func test_exportRow_withRecords_keepsItsSubtitle() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()

        let exportRow = scrollToExportRow(app)
        XCTAssertTrue(exportRow.exists, "No apareció la fila «Exportar registros» en Ajustes.")
        XCTAssertTrue(exportRow.isEnabled, "Con registros la fila está encendida.")
        XCTAssertTrue(exportRow.label.contains("Para Excel o Google Sheets"), "Subtítulo de siempre: «\(exportRow.label)».")
        XCTAssertFalse(exportRow.label.contains("No hay registros para exportar"))
    }

    // MARK: - Helpers

    private func scrollToExportRow(_ app: XCUIApplication) -> XCUIElement {
        let exportRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Exportar registros")).firstMatch
        var swipes = 0
        while !(exportRow.exists && exportRow.isHittable) && swipes < 10 {
            app.swipeUp()
            swipes += 1
        }
        return exportRow
    }

    private func openAIPrivacy(_ app: XCUIApplication) {
        app.openProfile()
        let privacy = app.buttons["profile_ai_privacy"]
        var swipes = 0
        while !(privacy.exists && privacy.isHittable) && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        privacy.tap()
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
