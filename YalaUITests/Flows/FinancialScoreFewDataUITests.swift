//
//  FinancialScoreFewDataUITests.swift
//  YalaUITests
//
//  Decisión 9 de la revisión 2.3 (Panel, PN-2): la nota de salud daba 100 con tres registros y no veía una cuenta en
//  rojo. Con la semilla `cuenta-con-movimientos` (Taxi −25 y Teléfono −33 en «Efectivo QA», Sueldo +1.000 en «Banco
//  QA», sin presupuestos ni pagos) solo cuenta Ritmo: antes salía 100; ahora no hay nota, la tarjeta dice qué falta y
//  nombra «Efectivo QA en negativo». La tarjeta es la misma en el Panel y en Estadísticas › Resumen; se mira en Resumen
//  porque en el Panel la sección llega apagada (`PanelDefaults.hiddenSections`).
//

import XCTest

final class FinancialScoreFewDataUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_onePartWithData_noScore_saysWhatIsMissing_andNamesTheAccountBelowZero() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "cuenta-con-movimientos", deeplink: "statistics")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let missing = app.staticTexts["health_missing_parts"]
        let unseen = app.staticTexts["health_unseen"]
        var swipes = 0
        while !missing.waitForExistence(timeout: 4), swipes < 5 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(missing.exists, "Con una sola parte con datos la tarjeta no dice qué falta (¿sigue saliendo una nota?).")
        XCTAssertTrue(unseen.waitForExistence(timeout: 5), "La tarjeta no dice lo que la nota no ve.")
        XCTAssertTrue(unseen.label.contains("Efectivo QA"), "La línea no nombra la cuenta en rojo: «\(unseen.label)».")

        // Sin nota, el anillo no enseña un número: su etiqueta dice «sin datos».
        let ring = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Tu salud financiera,")).firstMatch
        XCTAssertTrue(ring.waitForExistence(timeout: 5), "No aparece el anillo de la nota.")
        XCTAssertFalse(ring.label.contains("de 100"), "El anillo sigue dando una nota: «\(ring.label)».")
    }
}
