//
//  FlujoCambiarLimiteUITests.swift
//  YalaUITests
//
//  S4 del replanteo del flujo de caja (18-nov-2026): cambiar el límite pregunta qué meses cambian, trae «desde este mes en
//  adelante» elegido y admite 0. Desde el 19-nov-2026 se llega por el único «Cambiar» del detalle, que abre «Cálculo del
//  monto»: «Monto fijo» pone el campo arriba y el alcance debajo (`FlujoCalculoMontoSheet`).
//

import XCTest

final class FlujoCambiarLimiteUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func monthKey(_ offset: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .month, value: offset, to: .now) ?? .now
        let comps = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
    }

    /// «Solo este mes» con 0: al guardar, el mes en curso toma el 0 y el mes siguiente sigue igual.
    func test_soloEsteMes_conCero_cambiaSoloEseMes() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente.")
        app.openReport("flujoDeCaja")
        XCTAssertTrue(app.descendants(matching: .any)["cashflow_setup_view"].firstMatch.waitForExistence(timeout: 15),
                      "La vista de Flujo de caja no montó.")
        skipCoachMark(app)
        let create = app.buttons["primary_button"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), "No apareció «Crear mi plan».")
        create.tap()
        XCTAssertTrue(app.staticTexts["cashflow_month_title"].waitForExistence(timeout: 15), "El plan no se creó.")
        skipCoachMark(app)

        // La primera línea de gastos (las dos primeras filas son los ingresos de la semilla).
        let first = app.buttons.matching(identifier: "cashflow_detail_line").element(boundBy: 2)
        XCTAssertTrue(first.waitForExistence(timeout: 10), "No hay líneas de gasto en el mes.")
        let name = String(first.label.split(separator: ",").first ?? "")
        XCTAssertFalse(name.isEmpty)
        showMonth(app, monthKey(1))
        let nextBefore = lineRow(app, named: name).label
        showMonth(app, monthKey(0))
        let row = lineRow(app, named: name)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let currentBefore = row.label
        var tries = 0
        while row.frame.maxY > app.frame.height * 0.7, tries < 8 { app.swipeUp(velocity: .slow); tries += 1 }
        row.tap()
        let detail = app.scrollViews["cashflow_cell_detail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "No se abrió el detalle de la línea.")
        let adjust = app.buttons["cashflow_adjust_amount"]
        tries = 0
        while !adjust.isHittable, tries < 6 { detail.swipeUp(); tries += 1 }
        adjust.tap()

        // «Cálculo del monto»: «Monto fijo» trae el campo arriba y el alcance con «desde este mes» elegido (P3).
        let manual = app.buttons["cashflow_method_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5), "No se abrió «Cálculo del monto».")
        manual.tap()
        let from = app.buttons["cashflow_method_scope_desdeEsteMes"]
        XCTAssertTrue(from.waitForExistence(timeout: 5), "Con «Monto fijo» no aparece qué meses cambian.")
        XCTAssertTrue(from.isSelected, "«Desde este mes en adelante» tiene que venir elegido.")
        let field = app.textFields["cashflow_method_manual_amount"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "No apareció el campo del monto.")
        XCTAssertLessThan(field.frame.minY, from.frame.minY, "El campo va arriba, antes que el alcance.")

        let only = app.buttons["cashflow_method_scope_soloEsteMes"]
        only.tap()
        XCTAssertTrue(only.isSelected)

        field.tap()
        let fieldText = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: fieldText.count + 2))
        field.typeText("0")

        let save = app.buttons["cashflow_method_save"]
        XCTAssertTrue(save.isEnabled, "0 se puede guardar.")
        XCTAssertTrue(app.waitForSettledLayout(of: save), "«Guardar» no se quedó quieto.")
        save.tap()
        XCTAssertTrue(manual.waitForNonExistence(timeout: 5), "«Cálculo del monto» no se cerró al guardar.")
        let close = app.buttons["cashflow_cell_detail_close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(detail.waitForNonExistence(timeout: 5), "El detalle no se cerró.")

        showMonth(app, monthKey(0))
        let currentAfter = lineRow(app, named: name)
        XCTAssertTrue(currentAfter.waitForExistence(timeout: 5))
        XCTAssertNotEqual(currentAfter.label, currentBefore, "El mes en curso no tomó el 0.")
        showMonth(app, monthKey(1))
        let nextAfter = lineRow(app, named: name)
        XCTAssertTrue(nextAfter.waitForExistence(timeout: 5))
        XCTAssertEqual(nextAfter.label, nextBefore, "«Solo este mes» cambió también el mes siguiente.")
    }

    private func lineRow(_ app: XCUIApplication, named name: String) -> XCUIElement {
        app.buttons.matching(identifier: "cashflow_detail_line")
            .matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    private func showMonth(_ app: XCUIApplication, _ key: String) {
        app.swipeDown()
        app.swipeDown()
        let capsule = app.buttons["cashflow_month_capsule_\(key)"]
        XCTAssertTrue(capsule.waitForExistence(timeout: 5), "No está el mes \(key) en la tira.")
        let title = app.staticTexts["cashflow_month_title"]
        let before = title.label
        capsule.tap()
        _ = XCTWaiter().wait(
            for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", before), object: title)],
            timeout: 2
        )
        XCTAssertTrue(app.waitForSettledLayout(of: title), "El mes \(key) no se asentó.")
    }

    private func skipCoachMark(_ app: XCUIApplication) {
        let skip = app.buttons["coach_mark_skip"]
        if skip.waitForExistence(timeout: 4) {
            skip.tap()
            _ = skip.waitForNonExistence(timeout: 5)
        }
    }
}
