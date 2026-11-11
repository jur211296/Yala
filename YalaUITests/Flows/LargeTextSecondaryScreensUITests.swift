//
//  LargeTextSecondaryScreensUITests.swift
//  YalaUITests
//
//  Mejoras necesarias 2.3, lote 05: con el texto en AX3 (el tercero de los tamaños de accesibilidad), cinco pantallas
//  secundarias cortaban importes o partían palabras por sílabas porque la fila no les dejaba sitio. Un caso por punto,
//  cada uno midiendo el defecto en el árbol de accesibilidad (marcos reales de los textos, no capturas):
//
//  1. Distribución: el nombre de la categoría se partía en tres líneas («Ali-menta-ción») con el importe al lado,
//     cortado («S/2,3….00»), y el chip elegido («Distribución») se salía por la derecha.
//  2. Flujo de caja › el mes: el título se partía en una columna estrecha («No-viem-bre»).
//  3. Bandeja › seleccionar: «Editar» compartía fila con el contador y se partía («Edi-tar»).
//  4. Ajustes: los títulos de una palabra se partían junto al icono («Personaliza-ción»).
//  5. Etiquetas y Cuentas: el alto de la lista salía de filas × alto fijo y la última fila quedaba cortada.
//
//  Rojos en la base (origin/2.3 del 10-nov) y verdes con el arreglo. A tamaño normal las filas son las de siempre: eso lo
//  fija el diff de capturas del PR, no estos casos. La tabla de la Comparativa, «Te quedó», «¿Ya lo apuntaste?» y la
//  tarjeta del chat esconden sus textos a VoiceOver tras una etiqueta propia (o no tienen semilla): van en capturas.
//

import XCTest

final class LargeTextSecondaryScreensUITests: XCTestCase {

    /// AX3: `UICTContentSizeCategoryAccessibilityXL` (AX1 = M, AX2 = L, AX3 = XL, AX4 = XXL, AX5 = XXXL).
    private static let ax3 = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchAX3(
        seed: String = "realista", pro: Bool = true, deeplinkURL: String? = nil, extra: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: pro, seed: seed, deeplinkURL: deeplinkURL, extraArguments: Self.ax3 + extra)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    private func attach(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func describe(_ element: XCUIElement) -> String {
        let f = element.frame
        return "«\(element.label)» \(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))×\(Int(f.height))"
    }

    /// Arrastre corto y lento: sin inercia, para que lo medido no se mueva al leerlo.
    private func drag(_ app: XCUIApplication, by fraction: CGFloat = 0.3) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7 - fraction))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    /// Baja hasta que el elemento queda entero en la franja visible de la ventana.
    private func scrollUntilVisible(_ element: XCUIElement, in app: XCUIApplication, maxDrags: Int = 16) {
        let window = app.windows.firstMatch.frame
        var drags = 0
        while drags < maxDrags {
            if element.exists, !element.frame.isEmpty,
               element.frame.minY > window.minY + 120, element.frame.maxY < window.maxY - 120 { return }
            drag(app)
            drags += 1
        }
    }

    // MARK: - 1 · Estadísticas › Distribución (zona 35, P3)

    func test_ax3_distribution_nameAndAmountDoNotShareTheLine_andTheChosenChipIsWhole() {
        let app = launchAX3(deeplinkURL: "yaladev://statistics/categories")
        let window = app.windows.firstMatch.frame

        // El chip elegido: entero dentro de la pantalla (la fila se desplaza hasta él).
        let chip = app.buttons["detail_chip_categorías"]
        XCTAssertTrue(chip.waitForExistence(timeout: 20), "No apareció el chip de Distribución.")
        let chipInside = NSPredicate { _, _ in chip.frame.minX >= window.minX - 0.5 && chip.frame.maxX <= window.maxX + 0.5 }
        let chipWait = expectation(for: chipInside, evaluatedWith: nil)
        let chipResult = XCTWaiter().wait(for: [chipWait], timeout: 5)
        attach("distribucion-ax3-arriba", app)
        XCTAssertEqual(chipResult, .completed,
                       "Con AX3 el chip elegido de Estadísticas se sale de la pantalla: \(describe(chip)), ventana \(Int(window.width)) pt.")

        // La primera fila de categoría: el importe no comparte línea con el nombre, y el nombre no se parte.
        let row = app.buttons.matching(identifier: "distribution_category_row").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20), "No apareció la lista de categorías de Distribución.")
        scrollUntilVisible(row, in: app)
        attach("distribucion-ax3-fila", app)
        let name = row.staticTexts.element(boundBy: 0)
        let amount = row.otherElements.firstMatch
        XCTAssertTrue(name.exists && amount.exists, "La fila no expone su nombre y su importe: \(row.debugDescription)")
        print("LOTE05 distribución: nombre \(describe(name)) · importe \(describe(amount)) · fila \(describe(row))")
        XCTAssertGreaterThanOrEqual(
            amount.frame.minY, name.frame.maxY - 1,
            "Con AX3 el importe sigue al lado del nombre (se corta): nombre \(describe(name)), importe \(describe(amount)).")
        XCTAssertLessThan(
            name.frame.height, amount.frame.height * 2,
            "Con AX3 el nombre de la categoría se parte en varias líneas: \(describe(name)).")
        XCTAssertLessThanOrEqual(amount.frame.maxX, row.frame.maxX + 0.5, "El importe se sale de su fila: \(describe(amount)).")
    }

    // MARK: - 2 · Reportes › Flujo de caja, el mes (zona 36, P5)

    func test_ax3_cashFlowMonth_titleIsNotSqueezedIntoANarrowColumn() {
        // Reportes como pestaña: a AX3 su tarjeta de «Más» queda bajo la rejilla, que los arrastres sintéticos no
        // materializan (regla de `testing.md`). Molde de la configuración: `LoadTimesUITests`.
        let app = launchAX3(extra: [
            "-tabBarConfiguration", #""{\"activeTabs\":[\"panel\",\"statistics\",\"reports\"]}""#,
        ])
        app.selectTab(.reports)
        let chip = app.buttons["report_chip_flujoDeCaja"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15), "No apareció el chip del flujo de caja en Reportes.")
        let window = app.windows.firstMatch.frame
        var swipes = 0
        while chip.frame.maxX > window.maxX, swipes < 3 {
            app.buttons["report_chip_comparativa"].swipeLeft()
            swipes += 1
        }
        chip.tap()
        let skip = app.buttons["coach_mark_skip"]
        if skip.waitForExistence(timeout: 4) { skip.tap(); _ = skip.waitForNonExistence(timeout: 5) }

        let create = app.buttons["primary_button"]
        XCTAssertTrue(create.waitForExistence(timeout: 15), "No apareció «Crear mi plan».")
        var drags = 0
        while !create.isHittable, drags < 16 { drag(app, by: 0.4); drags += 1 }
        create.tap()

        let title = app.staticTexts["cashflow_month_title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15), "El plan no se creó (falta el título del mes).")
        if skip.waitForExistence(timeout: 4) { skip.tap(); _ = skip.waitForNonExistence(timeout: 5) }
        attach("flujo-mes-ax3", app)

        // Con su fila entera el mes («Noviembre de 2026») ocupa más de media pantalla; encajonado entre la cápsula y
        // «Llevas el…» medía ~90 pt y se partía por sílabas.
        print("LOTE05 mes: \(describe(title)) · ventana \(Int(window.width))")
        XCTAssertGreaterThan(
            title.frame.width, window.width / 2,
            "Con AX3 el título del mes queda en una columna estrecha y se parte por sílabas: \(describe(title)).")
    }

    // MARK: - 3 · Bandeja › seleccionar (zona 38, P7)

    func test_ax3_inboxSelectionBar_editIsBelowTheCount() {
        let app = launchAX3(seed: "minimal", pro: false)
        let inboxButton = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inboxButton.waitForExistence(timeout: 15), "No apareció el botón de la Bandeja en el Panel.")
        inboxButton.tap()
        XCTAssertTrue(app.buttons["inbox_filter_pending"].waitForExistence(timeout: 10), "No montó la Bandeja.")

        let select = app.buttons["Seleccionar"].firstMatch
        XCTAssertTrue(select.waitForExistence(timeout: 10), "No apareció el botón para elegir varios borradores.")
        select.tap()

        let edit = app.buttons["Editar"].firstMatch
        let count = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'seleccionado'")).firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 10) && count.exists, "No apareció la barra de selección.")
        attach("bandeja-seleccion-ax3", app)
        print("LOTE05 bandeja: editar \(describe(edit)) · contador \(describe(count))")
        XCTAssertGreaterThanOrEqual(
            edit.frame.minY, count.frame.maxY - 1,
            "Con AX3 «Editar» sigue al lado del contador y se parte por sílabas: \(describe(edit)), \(describe(count)).")
    }

    // MARK: - 4 · Ajustes (zona 40, P7)

    func test_ax3_settingsRowTitles_aOneWordTitleTakesOneLine() {
        let app = launchAX3()
        app.openProfile()
        XCTAssertTrue(app.buttons["profile_accounts"].waitForExistence(timeout: 10), "No se abrió Ajustes.")

        // «Favoritos» cabe en una línea con o sin arreglo: su fila es la medida de una fila cuyo título no se parte. El
        // título de una fila de Ajustes expone el marco de la fila entera (medido), así que se comparan filas: con el
        // título partido, la de Personalización mide una línea más (124 frente a 76 pt en la base).
        let favorites = app.buttons["profile_favorites"]
        scrollUntilVisible(favorites, in: app)
        let oneLine = favorites.staticTexts["Favoritos"]
        XCTAssertTrue(oneLine.exists, "La fila de Favoritos no expone su título: \(favorites.debugDescription)")
        let oneLineHeight = oneLine.frame.height

        let personalization = app.buttons["profile_personalization"]
        scrollUntilVisible(personalization, in: app)
        let title = personalization.staticTexts["Personalización"]
        XCTAssertTrue(title.exists, "La fila de Personalización no expone su título: \(personalization.debugDescription)")
        attach("ajustes-ax3", app)
        print("LOTE05 ajustes: \(describe(title)) · fila de una línea \(Int(oneLineHeight))")
        XCTAssertLessThan(
            title.frame.height, oneLineHeight * 1.5,
            "Con AX3 «Personalización» se parte por sílabas (\(describe(title)); una fila de una línea mide \(Int(oneLineHeight)) pt).")
    }

    // MARK: - 5 · Etiquetas y Cuentas (zona 39, P8 · H2)

    func test_ax3_tagsAndAccountsLists_lastRowIsNotCut() {
        let app = launchAX3()
        app.openProfile()
        app.openSettingsSection("profile_tags")
        XCTAssertTrue(app.buttons["tags_add_button"].waitForExistence(timeout: 10), "No se abrió Etiquetas.")
        assertLastRowFitsItsList(prefix: "tags_row_", what: "Etiquetas", app: app)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.openSettingsSection("profile_accounts")
        assertLastRowFitsItsList(prefix: "accounts_row_", what: "Cuentas", app: app)
    }

    /// La última fila de la lista reordenable, entera dentro de la lista: con el alto calculado a mano la lista medía
    /// menos que sus filas y la última quedaba recortada por abajo.
    private func assertLastRowFitsItsList(prefix: String, what: String, app: XCUIApplication) {
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "\(what): no aparecen filas (\(prefix)).")
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.exists, "\(what): no aparece la lista.")
        let all = rows.allElementsBoundByIndex
        guard let last = all.max(by: { $0.frame.maxY < $1.frame.maxY }) else { return XCTFail("\(what): sin filas.") }
        attach("\(what.lowercased())-ax3", app)
        print("LOTE05 \(what): lista \(describe(list)) · última \(describe(last)) · \(all.count) filas")
        XCTAssertLessThanOrEqual(
            last.frame.maxY, list.frame.maxY + 1,
            "Con AX3 la última fila de \(what) queda cortada: fila \(describe(last)), lista \(describe(list)).")
    }
}
