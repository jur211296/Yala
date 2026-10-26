//
//  ExpensesOnlyHeroesUITests.swift
//  YalaUITests
//
//  Modo «Solo gastos»: las cuatro pestañas de Estadísticas llevan la cabecera del Panel —«Gastos del período» y la
//  cifra grande— y ninguna pantalla enseña como filtro aplicado la naturaleza que fija el modo. Auditoría «Solo
//  gastos» del 2026-10-26 (card 1qfi), decisiones A de Jürgen.
//
//  Antes: Resumen y Registros se quedaban sin cifra (solo un chip pequeño y el recuento), Tendencias decía «15 % por
//  debajo · Ánimo» cuando el gasto había subido, Estadísticas pintaba «Filtros aplicados» sin nada debajo y el Panel
//  una píldora «Gasto» que no se podía quitar.
//
//  Seed `realista` (trae el mes anterior: hace falta para que haya variación) y `-uitest-expenses-only`.
//

import XCTest

final class ExpensesOnlyHeroesUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// `-uitest-expenses-only` PERSISTE: el modo queda guardado en el simulador (app y App Group) y los unit tests, que
    /// corren dentro de la misma app, salían sin ingresos — 20 rojos medidos el 2026-10-26 en `YalaTests` corrida
    /// detrás de este caso. Un arranque con `-uitest-reset` lo apaga en los dos almacenes.
    override func tearDown() {
        let cleanup = XCUIApplication()
        cleanup.launchForUITest(seed: nil)
        _ = cleanup.waitForUITestReady()
        cleanup.terminate()
        super.tearDown()
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        // «Este mes»: con «Todo el tiempo» no hay período anterior y la variación no sale (como en el Panel).
        app.launchForUITest(seed: "realista", extraArguments: ["-uitest-expenses-only", "-defaultPeriod", "thisMonth"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func openChip(_ app: XCUIApplication, _ identifier: String) {
        let chip = app.buttons[identifier]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "No apareció el chip \(identifier).")
        let window = app.windows.firstMatch.frame
        if chip.frame.maxX > window.maxX || chip.frame.minX < window.minX {
            let chipsBar = app.scrollViews.containing(.button, identifier: "detail_chip_insights").firstMatch
            if chipsBar.exists { chipsBar.swipeLeft() }
        }
        chip.tap()
    }

    /// La cabecera del Panel en «Solo gastos»: el rótulo del gasto, sin el título de filtros vacío.
    private func assertExpenseHero(_ app: XCUIApplication, in place: String,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let caption = app.staticTexts["stats_hero_caption"]
        XCTAssertTrue(caption.waitForExistence(timeout: 15),
                      "\(place): el hero no tiene rótulo; volvió la cabecera sin cifra.", file: file, line: line)
        XCTAssertEqual(caption.label, "Gastos del período",
                       "\(place): el rótulo no dice que la cifra es lo gastado.", file: file, line: line)
        XCTAssertFalse(app.staticTexts["Filtros aplicados"].exists,
                       "\(place): sale «Filtros aplicados» aunque el usuario no filtró nada.", file: file, line: line)
    }

    /// La variación del gasto bajo la cifra, como en el Panel. Registros no la lleva: no calcula el período anterior.
    private func assertExpenseVariation(_ app: XCUIApplication, in place: String,
                                        file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            app.descendants(matching: .any)["stats_hero_expense_variation"].waitForExistence(timeout: 10),
            "\(place): falta la variación del gasto bajo la cifra.", file: file, line: line)
    }

    func test_everyStatisticsTabShowsTheSpentFigure_withoutAPhantomFilter() {
        let app = launch()

        // El Panel: ni sección de filtros ni píldora «Gasto».
        XCTAssertTrue(app.buttons["profile_avatar"].waitForExistence(timeout: 15), "No se llegó al Panel.")
        XCTAssertFalse(app.buttons["applied_filter_chip"].exists,
                       "El Panel enseña la naturaleza que fija «Solo gastos» como un filtro aplicado.")
        XCTAssertFalse(app.staticTexts["Filtros aplicados"].exists, "El Panel pinta «Filtros aplicados» sin filtros.")
        capture(app, "solo-gastos-panel")

        app.tabBars.buttons.element(boundBy: 1).tap()
        assertExpenseHero(app, in: "Resumen")
        assertExpenseVariation(app, in: "Resumen")
        capture(app, "solo-gastos-resumen")

        openChip(app, "detail_chip_tendencias")
        assertExpenseHero(app, in: "Tendencias")
        assertExpenseVariation(app, in: "Tendencias")
        // La frase del balance se iba al revés: «por debajo · Ánimo» con el gasto en subida.
        let balanceLine = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'por debajo' OR label CONTAINS 'por encima' OR label CONTAINS 'Tu balance'")).firstMatch
        XCTAssertFalse(balanceLine.exists, "Tendencias sigue enseñando la frase del balance: «\(balanceLine.label)».")
        capture(app, "solo-gastos-tendencias")

        openChip(app, "detail_chip_categorías")
        assertExpenseHero(app, in: "Distribución")
        assertExpenseVariation(app, in: "Distribución")
        capture(app, "solo-gastos-distribucion")

        openChip(app, "detail_chip_registros")
        assertExpenseHero(app, in: "Registros")
        XCTAssertTrue(app.descendants(matching: .any)["records_summary_balance"].exists,
                      "Registros: el rótulo está pero falta la cifra grande.")
        capture(app, "solo-gastos-registros")
    }
}
