//
//  GruposPulidoDivisionDetalleUITests.swift
//  YalaUITests
//
//  Grupos: «¿Cómo se dividió?» en tarjetas, detalle de gasto en tarjetas y la etiqueta real del reparto
//  (encargo del 2026-11-26). Recorre el caso de las capturas de Jürgen sobre el seed `grupos`: en «Viaje a Lima»
//  (tú y Caro), «Ceviche» lo pagó Caro a partes iguales; se cambia a «Pagó Caro · es todo tuyo» desde las opciones
//  rápidas y se abre su detalle. Antes, ese detalle decía «Partes iguales» junto a «Reparto».
//
//  Cada paso adjunta su captura (`keepAlways`): son las del antes/después del cierre.
//

import XCTest

final class GruposPulidoDivisionDetalleUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - Casos

    /// El gasto «es todo tuyo» ya no se etiqueta «Partes iguales», y se lee sin subir la hoja.
    func test_todoTuyo_noSeEtiquetaPartesIguales() {
        let app = launch(theme: nil)
        changeCevicheToAllMine(app, captureAs: nil)
        openCeviche(app)

        let breakdown = app.descendants(matching: .any).matching(identifier: "group_expense_detail_breakdown").firstMatch
        XCTAssertTrue(breakdown.waitForExistence(timeout: 5), "El detalle no mostró el reparto.")
        XCTAssertTrue(breakdown.staticTexts["Todo tuyo"].exists, "El reparto de un gasto todo tuyo no dijo «Todo tuyo».")
        XCTAssertFalse(breakdown.staticTexts["Partes iguales"].exists, "El reparto volvió a decir «Partes iguales».")

        // A media altura se ve lo importante sin subir: tu parte y el reparto, dentro de la pantalla.
        let yourPart = app.descendants(matching: .any).matching(identifier: "group_expense_detail_your_part").firstMatch
        XCTAssertTrue(yourPart.exists, "Falta «Tu parte».")
        let window = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(breakdown.frame.maxY, window.maxY,
                                 "A media altura el reparto se corta: \(breakdown.frame) en \(window).")
    }

    /// Las cuatro opciones siguen tocándose por su frase entera, y la elegida queda marcada.
    func test_opcionesRapidas_marcanLaElegida() {
        let app = launch(theme: nil)
        openCeviche(app)
        openQuickOptions(app)
        let selected = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Pagó Caro · partes iguales")).firstMatch
        XCTAssertTrue(selected.waitForExistence(timeout: 5), "No apareció «Pagó Caro · partes iguales».")
        XCTAssertTrue(selected.isSelected, "La opción del gasto (pagó Caro, partes iguales) no salió marcada.")
        for label in ["Pagaste · partes iguales", "Pagaste · es todo de Caro", "Pagó Caro · es todo tuyo"] {
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch.exists,
                          "Falta la opción «\(label)».")
        }
        XCTAssertTrue(app.buttons["Más opciones"].exists, "Falta «Más opciones».")
    }

    /// Capturas de las tres pantallas: tema Oscuro (el de las capturas de Jürgen), Claro y el de fábrica (Liquid Glass).
    func test_capturas_oscuro() { captureAll(theme: "2", suffix: "oscuro") }
    func test_capturas_fabrica() { captureAll(theme: nil, suffix: "fabrica") }
    func test_capturas_claro() { captureAll(theme: "1", suffix: "claro") }

    // MARK: - Recorrido

    private func captureAll(theme: String?, suffix: String) {
        let app = launch(theme: theme)
        changeCevicheToAllMine(app, captureAs: "01-division-\(suffix)")
        openCeviche(app)
        capture(app, "02-detalle-medio-\(suffix)")
        growSheet(app)
        capture(app, "03-detalle-grande-\(suffix)")
    }

    private func launch(theme: String?) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos", deeplink: "groups",
                            extraArguments: theme.map { ["-userTheme", $0] } ?? [])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        let lima = app.buttons.matching(identifier: "group_card")
            .matching(NSPredicate(format: "label BEGINSWITH 'Viaje a Lima'")).firstMatch
        XCTAssertTrue(lima.waitForExistence(timeout: 10), "No apareció «Viaje a Lima».")
        lima.tap()
        return app
    }

    private func openCeviche(_ app: XCUIApplication) {
        let row = app.buttons["group_expense_row_Ceviche"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No apareció «Ceviche».")
        row.tap()
        XCTAssertTrue(app.buttons["group_expense_detail_edit"].waitForExistence(timeout: 5), "No montó el detalle.")
    }

    private func openQuickOptions(_ app: XCUIApplication) {
        app.buttons["group_expense_detail_edit"].tap()
        let pill = app.buttons["group_expense_quick_options"]
        XCTAssertTrue(pill.waitForExistence(timeout: 5), "En un grupo de 2 falta la pastilla de opciones rápidas.")
        pill.tap()
    }

    /// Ceviche: de «Pagó Caro · partes iguales» a «Pagó Caro · es todo tuyo», y guardar.
    private func changeCevicheToAllMine(_ app: XCUIApplication, captureAs name: String?) {
        openCeviche(app)
        openQuickOptions(app)
        let allMine = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Pagó Caro · es todo tuyo")).firstMatch
        XCTAssertTrue(allMine.waitForExistence(timeout: 5), "No apareció «Pagó Caro · es todo tuyo».")
        if let name { capture(app, name) }
        allMine.tap()

        let save = app.buttons["group_expense_save"]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: save)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 8), .completed, "Guardar no se habilitó.")
        save.tap()
        let accept = app.buttons["group_expense_success_accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 10), "No apareció la pantalla de éxito.")
        accept.tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 5), "La pantalla de éxito no se cerró.")
    }

    /// Sube la hoja del detalle a altura completa arrastrando desde su barra.
    private func growSheet(_ app: XCUIApplication) {
        let edit = app.buttons["group_expense_detail_edit"]
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: window.frame.midX, dy: edit.frame.midY - 30))
        let end = window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: window.frame.midX, dy: 80))
        start.press(forDuration: 0.1, thenDragTo: end)
        let deadline = Date().addingTimeInterval(4)
        while edit.frame.minY > 200, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        // La hoja termina de asentarse antes de la foto (animación de presentación, ~0,4 s).
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
