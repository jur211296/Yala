//
//  FlujoLineaDuplicadaUITests.swift
//  YalaUITests
//
//  «Agregar línea › Desde mis gastos» no deja crear una segunda línea sobre lo mismo (encargo del 27-nov-2026, flujo de
//  caja duplicado y promedios). Pide una subcategoría que ya tiene línea (la agrega primero si hace falta): su fila dice
//  «En tu plan», no se puede elegir y «Guardar» sigue apagado.
//
//  Con `TEST_RUNNER_CAPTURA_DIR=<carpeta>` guarda capturas (`TEST_RUNNER_CAPTURA_PREFIJO=antes|despues`); con la build
//  de antes del arreglo la prueba cae y la captura enseña la línea repetida.
//

import XCTest

final class FlujoLineaDuplicadaUITests: XCTestCase {

    private var folder: String?
    private var prefijo = "despues"

    override func setUpWithError() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        folder = env["CAPTURA_DIR"]
        prefijo = env["CAPTURA_PREFIJO"] ?? "despues"
    }

    func test_agregarLinea_laMismaSubcategoriaDosVeces_laSegundaNoSePuede() {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true, seed: "realista",
            extraArguments: ["-tabBarConfiguration", #""{\"activeTabs\":[\"panel\",\"statistics\",\"reports\"]}""#]
        )
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente.")
        openPlan(app)

        // La primera subcategoría de la categoría con más gasto. Con la semilla suele estar ya en el plan; si no, se
        // agrega y la segunda vuelta lo comprueba.
        openFromExpenses(app)
        guard let nombre = expandFirstCategoryWithSubcategories(app) else { return }
        shot(app, "\(prefijo)-1-desde-mis-gastos")
        if subcategoryRow(app, nombre).isEnabled {
            subcategoryRow(app, nombre).tap()
            let save = app.buttons["toolbar_save_button"].firstMatch
            XCTAssertTrue(save.waitForExistence(timeout: 5), "No hay «Guardar».")
            XCTAssertTrue(save.isEnabled, "«Guardar» apagado con una subcategoría nueva elegida.")
            save.tap()
            pause(1.2)
            shot(app, "\(prefijo)-2-primera-guardada")
            openFromExpenses(app)
            guard expandCategory(app, containing: nombre) else { return }
        }

        let otraVez = subcategoryRow(app, nombre)
        XCTAssertTrue(otraVez.waitForExistence(timeout: 5), "No volvió la fila de \(nombre).")
        shot(app, "\(prefijo)-3-otra-vez")
        if otraVez.isEnabled {
            // Build de antes: se puede elegir y guardar, y queda una línea repetida.
            otraVez.tap()
            let save = app.buttons["toolbar_save_button"].firstMatch
            if save.waitForExistence(timeout: 3), save.isEnabled { save.tap() }
            pause(1.5)
            shot(app, "\(prefijo)-4-linea-repetida")
            XCTFail("La subcategoría \(nombre) ya tiene línea y se pudo elegir otra vez.")
            return
        }
        XCTAssertEqual(otraVez.value as? String, "En tu plan", "La fila no dice que ya está en el plan.")
        let save = app.buttons["toolbar_save_button"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 3), "No hay «Guardar».")
        XCTAssertFalse(save.isEnabled, "«Guardar» encendido sin nada que agregar.")
    }

    // MARK: - Recorrido

    private func openPlan(_ app: XCUIApplication) {
        app.selectTab(.reports)
        let chip = app.buttons["report_chip_flujoDeCaja"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "No está el chip de Flujo de caja.")
        chip.tap()
        XCTAssertTrue(app.descendants(matching: .any)["cashflow_setup_view"].firstMatch.waitForExistence(timeout: 15),
                      "La vista de Flujo de caja no montó.")
        skipCoachMark(app)
        let create = app.buttons["primary_button"]
        XCTAssertTrue(create.waitForExistence(timeout: 10), "No apareció «Crear mi plan».")
        create.tap()
        XCTAssertTrue(app.staticTexts["cashflow_month_title"].waitForExistence(timeout: 15), "El plan no se creó.")
        skipCoachMark(app)
        shot(app, "\(prefijo)-0-plan")
    }

    private func openFromExpenses(_ app: XCUIApplication) {
        let add = app.buttons["cashflow_add_line_expense"].firstMatch
        var tries = 0
        while !(add.exists && add.isHittable) && tries < 20 {
            app.swipeUp(velocity: .slow)
            tries += 1
        }
        XCTAssertTrue(add.exists, "No está «Agregar línea» de gastos.")
        add.tap()
        let fromExpenses = app.buttons["cashflow_add_from_expenses"].firstMatch
        XCTAssertTrue(fromExpenses.waitForExistence(timeout: 5), "No se abrió «Agregar línea».")
        fromExpenses.tap()
        XCTAssertTrue(app.buttons["cashflow_add_category"].firstMatch.waitForExistence(timeout: 5),
                      "No salió la lista de categorías.")
    }

    /// Abre la primera categoría con subcategorías y devuelve el nombre de su primera subcategoría.
    private func expandFirstCategoryWithSubcategories(_ app: XCUIApplication) -> String? {
        let categories = app.buttons.matching(identifier: "cashflow_add_category")
        for index in 0..<min(categories.count, 6) {
            let category = categories.element(boundBy: index)
            guard category.exists else { continue }
            category.tap()
            let sub = app.buttons.matching(identifier: "cashflow_add_subcategory").firstMatch
            if sub.waitForExistence(timeout: 2) {
                return firstPart(of: sub.label)
            }
        }
        XCTFail("Ninguna categoría tiene subcategorías.")
        return nil
    }

    /// Vuelve a abrir la categoría que contiene la subcategoría `nombre`.
    private func expandCategory(_ app: XCUIApplication, containing nombre: String) -> Bool {
        let categories = app.buttons.matching(identifier: "cashflow_add_category")
        for index in 0..<min(categories.count, 6) {
            let category = categories.element(boundBy: index)
            guard category.exists else { continue }
            category.tap()
            if subcategoryRow(app, nombre).waitForExistence(timeout: 2) { return true }
        }
        XCTFail("No volvió a salir la subcategoría \(nombre).")
        return false
    }

    private func subcategoryRow(_ app: XCUIApplication, _ nombre: String) -> XCUIElement {
        app.buttons.matching(identifier: "cashflow_add_subcategory")
            .matching(NSPredicate(format: "label BEGINSWITH %@", nombre)).firstMatch
    }

    private func firstPart(of label: String) -> String {
        label.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? label
    }

    private func skipCoachMark(_ app: XCUIApplication) {
        let skip = app.buttons["coach_mark_skip"]
        if skip.waitForExistence(timeout: 4) {
            skip.tap()
            pause(0.5)
        }
    }

    private func pause(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        guard let folder else { return }
        let data = XCUIScreen.main.screenshot().pngRepresentation
        let url = URL(fileURLWithPath: folder).appendingPathComponent("\(name).png")
        do {
            try data.write(to: url)
        } catch {
            XCTFail("No se pudo guardar \(name): \(error)")
        }
    }
}
