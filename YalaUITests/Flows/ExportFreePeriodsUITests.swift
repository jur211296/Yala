//
//  ExportFreePeriodsUITests.swift
//  YalaUITests
//
//  Desde el 2026-10-12 exportar es gratis entero: cualquier período, en CSV o Excel (decisión de Lola con la
//  delegación de Jürgen, PR #469). Hasta entonces «Este año», «Año pasado», «Todo el tiempo» y «Personalizado»
//  llevaban la insignia Pro y abrían la oferta de Pro. La política de privacidad promete la exportación completa
//  sin pagar, así que esto es lo que la sostiene en la app.
//
//  Usuario gratis (`launchForUITest` sin `pro`), seed `minimal` (trae movimientos: sin ellos la fila de exportar sale
//  desactivada). Con la puerta vieja, elegir uno de esos períodos abre la oferta y la fila sigue en «Últimos 30 días».
//

import XCTest

final class ExportFreePeriodsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_freeUser_exportsAnyPeriod_withoutTheProOffer() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openExportWizard(app)

        let periodRow = app.buttons["export_period_row"]
        XCTAssertTrue(periodRow.waitForExistence(timeout: 10), "No se abrió el asistente de exportación.")
        XCTAssertEqual(periodRow.value as? String, "Últimos 30 días", "El asistente no arrancó en su período de siempre.")

        // Los tres períodos fijos que antes eran Pro: cada uno se elige, la hoja se cierra y la fila lo muestra.
        for (period, shown) in [("thisYear", "Este año"), ("lastYear", "Año pasado"), ("allTime", "Todo el tiempo")] {
            periodRow.tap()
            let option = app.buttons["export_period_\(period)"]
            XCTAssertTrue(option.waitForExistence(timeout: 5), "No apareció la opción \(period) en la hoja de períodos.")
            option.tap()
            XCTAssertTrue(option.waitForNonExistence(timeout: 5), "La hoja de períodos no se cerró al elegir \(period).")
            XCTAssertFalse(app.buttons["upgrade_prompt_cta"].exists, "Elegir \(period) abrió la oferta de Pro.")
            XCTAssertEqual(periodRow.value as? String, shown, "La fila de período no muestra \(period).")
        }

        // «Personalizado» abre su selector de fechas, no la oferta de Pro.
        periodRow.tap()
        let custom = app.buttons["export_period_custom"]
        XCTAssertTrue(custom.waitForExistence(timeout: 5), "No apareció la opción Personalizado.")
        custom.tap()
        XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout: 5), "Personalizado no abrió el selector de fechas.")
        XCTAssertFalse(app.buttons["upgrade_prompt_cta"].exists, "Personalizado abrió la oferta de Pro.")
    }

    /// La fila «Exportar datos» de Perfil no lleva identificador, y ponérselo tocaría `ProfileView`, que arrastra al
    /// gate 40 suites de interfaz. Se busca por su título: los XCUITest corren siempre en español
    /// (`launchForUITest` fija `-AppleLanguages (es)`).
    private func openExportWizard(_ app: XCUIApplication) {
        app.openProfile()
        let exportRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Exportar datos")).firstMatch
        XCTAssertTrue(exportRow.waitForExistence(timeout: 10), "No apareció la fila Exportar datos en el Perfil.")
        var swipes = 0
        while !exportRow.isHittable && swipes < 14 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(exportRow.isHittable, "La fila Exportar datos no se puede tocar.")
        XCTAssertTrue(exportRow.isEnabled, "La fila Exportar datos está desactivada: ¿el seed no trajo movimientos?")
        exportRow.tap()
    }
}
