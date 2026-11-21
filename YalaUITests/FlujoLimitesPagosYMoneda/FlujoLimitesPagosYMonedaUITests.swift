//
//  FlujoLimitesPagosYMonedaUITests.swift
//  YalaUITests
//
//  Límites del flujo de caja con varios pagos y en otra moneda (encargo del 2026-11-20), desde el único «Cambiar» del
//  detalle de una línea:
//  - «Pagos planificados» abre «Elige los pagos»; con dos pagos y un extra, la cifra de arriba es su suma y el detalle
//    enseña ese límite al guardar;
//  - «Monto fijo» en USD (el símbolo es un botón): la fila enseña el original («500.00 USD») y la cápsula del detalle
//    abre «Cómo se convierte».
//
//  Semilla `realista`: ocho pagos planificados de gasto en soles (Netflix 45, Spotify 18…).
//

import XCTest

final class FlujoLimitesPagosYMonedaUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Pagos planificados

    func test_dosPagosYUnExtra_laCifraEsSuSuma_yElDetalleLaEnseña() {
        let app = abrirCalculoDeLaPrimeraLineaDeGasto()

        let pagos = app.buttons["cashflow_method_scheduled"]
        XCTAssertTrue(pagos.waitForExistence(timeout: 5), "«Pagos planificados» no se ofrece con pagos activos de gasto.")
        pagos.tap()

        // Sin pagos elegidos, la hoja para elegirlos se abre sola.
        let hoja = app.descendants(matching: .any)["cashflow_pick_payments_sheet"]
        XCTAssertTrue(hoja.waitForExistence(timeout: 5), "No se abrió «Elige los pagos».")
        for nombre in ["Netflix", "Spotify"] {
            let fila = app.buttons.matching(identifier: "cashflow_pick_payment_row")
                .matching(NSPredicate(format: "label BEGINSWITH %@", nombre)).firstMatch
            var intentos = 0
            while !fila.exists, intentos < 6 { app.swipeUp(velocity: .slow); intentos += 1 }
            XCTAssertTrue(fila.waitForExistence(timeout: 5), "No está \(nombre) en la hoja.")
            fila.tap()
            XCTAssertTrue(fila.isSelected, "\(nombre) no quedó marcado.")
        }
        app.buttons["cashflow_pick_payments_done"].tap()
        XCTAssertTrue(hoja.waitForNonExistence(timeout: 5))

        // Las dos filas en «Pagos de esta línea» y el extra.
        let card = app.descendants(matching: .any)["cashflow_line_payments_card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "No apareció «Pagos de esta línea».")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "cashflow_line_payment_row").count, 2)
        let interruptor = app.switches["cashflow_line_extra_toggle"].firstMatch
        var intentos = 0
        while !interruptor.isHittable, intentos < 6 { app.swipeUp(velocity: .slow); intentos += 1 }
        interruptor.switches.firstMatch.tap()
        let extra = app.textFields["cashflow_line_extra_amount"]
        XCTAssertTrue(extra.waitForExistence(timeout: 5), "El extra no muestra su campo.")
        extra.tap()
        extra.typeText("30")

        // La cifra cambia con el extra y la explicación cuenta los dos pagos y el extra. (Qué pago cae este mes depende
        // de la fecha de la semilla; la suma exacta la fija `FlujoLimitesPagosYMonedaTests`.)
        let resultado = app.descendants(matching: .any)["cashflow_method_result_card"].firstMatch
        XCTAssertTrue(resultado.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForLabel(resultado, containing: "30.00 extra"),
                      "La explicación no suma el extra: «\(resultado.label)».")
        XCTAssertTrue(resultado.label.contains("2"), "La explicación no cuenta los dos pagos: «\(resultado.label)».")
        let cifra = cifraDe(resultado.label)
        XCTAssertNotNil(cifra, "No encuentro la cifra en «\(resultado.label)».")

        app.buttons["cashflow_method_save"].tap()
        let limite = app.descendants(matching: .any)["cashflow_detail_planned_amount"].firstMatch
        XCTAssertTrue(limite.waitForExistence(timeout: 5))
        if let cifra {
            XCTAssertTrue(waitForLabel(limite, containing: cifra),
                          "El detalle no enseña el límite guardado (\(cifra)): «\(limite.label)».")
        }
        let metodo = app.staticTexts["cashflow_detail_method"]
        XCTAssertTrue(metodo.exists)
    }

    // MARK: - Monto fijo en otra moneda

    func test_montoFijoEnUSD_laFilaEnseñaElOriginal_yLaCapsulaAbreComoSeConvierte() {
        let app = abrirCalculoDeLaPrimeraLineaDeGasto()

        let fijo = app.buttons["cashflow_method_manual"]
        XCTAssertTrue(fijo.waitForExistence(timeout: 5))
        fijo.tap()
        let moneda = app.buttons["cashflow_method_currency"]
        XCTAssertTrue(moneda.waitForExistence(timeout: 5), "El símbolo del monto fijo no es un botón.")
        moneda.tap()
        let usd = app.buttons["currency_selector_row_USD"].firstMatch
        XCTAssertTrue(usd.waitForExistence(timeout: 5), "No se abrió el selector de moneda.")
        usd.tap()
        XCTAssertTrue(usd.waitForNonExistence(timeout: 5))

        let campo = app.textFields["cashflow_method_manual_amount"]
        XCTAssertTrue(campo.waitForExistence(timeout: 5))
        campo.tap()
        let actual = (campo.value as? String) ?? ""
        campo.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: actual.count + 2))
        campo.typeText("500")
        XCTAssertTrue(app.staticTexts["cashflow_method_foreign_all_months"].waitForExistence(timeout: 5),
                      "En otra moneda tiene que decir que vale para todos los meses.")
        XCTAssertFalse(app.buttons["cashflow_method_scope_desdeEsteMes"].exists,
                       "En otra moneda no se elige qué meses cambian.")

        app.buttons["cashflow_method_save"].tap()
        let capsula = app.buttons["cashflow_detail_conversion_capsule"]
        XCTAssertTrue(capsula.waitForExistence(timeout: 8), "El detalle no enseña la cápsula de la conversión.")
        XCTAssertTrue(capsula.label.contains("500"), "La cápsula no dice el original: «\(capsula.label)».")
        capsula.tap()
        let hoja = app.descendants(matching: .any)["cashflow_how_converted_sheet"]
        XCTAssertTrue(hoja.waitForExistence(timeout: 5), "La cápsula no abre «Cómo se convierte».")
        XCTAssertGreaterThanOrEqual(app.descendants(matching: .any)
            .matching(identifier: "cashflow_how_converted_month").count, 5, "Faltan meses en «Cómo se convierte».")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(hoja.waitForNonExistence(timeout: 5))

        // Fuera del detalle: la fila del mes enseña «500.00 USD» bajo el nombre.
        app.buttons["cashflow_cell_detail_close"].tap()
        // VoiceOver lee la fila con el original: «…, límite S/ …, 500.00 USD convertidos».
        let fila = app.buttons.matching(identifier: "cashflow_detail_line")
            .matching(NSPredicate(format: "label CONTAINS %@", "USD")).firstMatch
        XCTAssertTrue(fila.waitForExistence(timeout: 8), "La fila no enseña ni lee el original.")
        XCTAssertTrue(fila.label.contains("500"), "La lectura de la fila no dice el original: «\(fila.label)».")
    }

    // MARK: - Ayudas

    /// Crea el plan con la semilla y abre «Cálculo del monto» de la primera línea de gasto.
    private func abrirCalculoDeLaPrimeraLineaDeGasto() -> XCUIApplication {
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

        // Las dos primeras filas son los ingresos de la semilla.
        let row = app.buttons.matching(identifier: "cashflow_detail_line").element(boundBy: 2)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No hay líneas de gasto en el mes.")
        // Arrastres cortos: un `swipeUp` la subía bajo la barra de arriba y el toque caía en el título.
        var tries = 0
        while row.frame.maxY > app.frame.height * 0.8, tries < 6 {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -120)))
            tries += 1
        }
        XCTAssertTrue(app.waitForSettledLayout(of: row), "La fila no dejó de moverse.")
        var tries2 = 0
        row.tap()
        let detail = app.scrollViews["cashflow_cell_detail"]
        // Un toque que cae mientras el mes termina de asentarse se pierde: un segundo intento.
        if !detail.waitForExistence(timeout: 4) { row.tap() }
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "No se abrió el detalle de la línea.")
        let adjust = app.buttons["cashflow_adjust_amount"]
        while !adjust.isHittable, tries2 < 6 { detail.swipeUp(); tries2 += 1 }
        adjust.tap()
        XCTAssertTrue(app.descendants(matching: .any)["cashflow_method_sheet"].waitForExistence(timeout: 5),
                      "No se abrió «Cálculo del monto».")
        return app
    }

    /// «S/ 75.00» de la lectura de la tarjeta de arriba: el primer monto con el símbolo de la moneda.
    private func cifraDe(_ label: String) -> String? {
        guard let rango = label.range(of: #"\d[\d,]*\.\d{2}"#, options: .regularExpression) else { return nil }
        return String(label[rango])
    }

    private func waitForLabel(_ element: XCUIElement, containing text: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)],
                                timeout: 5) == .completed
    }

    private func skipCoachMark(_ app: XCUIApplication) {
        let skip = app.buttons["coach_mark_skip"]
        if skip.waitForExistence(timeout: 4) {
            skip.tap()
            _ = skip.waitForNonExistence(timeout: 5)
        }
    }
}
