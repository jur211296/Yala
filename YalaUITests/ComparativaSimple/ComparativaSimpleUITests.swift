//
//  ComparativaSimpleUITests.swift
//  YalaUITests
//
//  Comparativa de Reportes más simple (pedido de Jürgen del 17-nov). En «Mes pasado», con la semilla realista:
//  - la cabecera nombra los dos períodos una vez y las filas ya no repiten «en <período>» bajo cada monto;
//  - VoiceOver lee cada fila con el monto y el cambio frente al período anterior («subió 27 % frente a octubre»);
//  - «Te quedó» dice también su cambio.
//  Deja una captura (`XCTAttachment`) de la tabla.
//

import XCTest

final class ComparativaSimpleUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    /// «frente a» en español, «compared with» si el simulador corre en inglés.
    private func saysVersus(_ label: String) -> Bool {
        label.contains("frente a") || label.contains("compared with")
    }

    func test_comparative_rowsReadTheChange_andDoNotRepeatThePeriod() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", extraArguments: ["-defaultPeriod", "lastMonth"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openReport("comparativa")

        XCTAssertTrue(element(app, "report_comparison_heading").waitForExistence(timeout: 10),
                      "No apareció la frase de qué se compara.")
        let header = element(app, "pivot_header_row")
        XCTAssertTrue(header.waitForExistence(timeout: 10), "No se pintó la tabla.")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "comparativa-simple"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Cada fila de la tabla dice el cambio frente al período anterior.
        let rows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'pivot_row_'"))
        XCTAssertGreaterThan(rows.count, 2, "La tabla no tiene filas.")
        let first = rows.element(boundBy: 0)
        XCTAssertTrue(saysVersus(first.label), "La fila no dice frente a qué cambia: «\(first.label)».")

        // El «en <período>» ya no se repite bajo cada monto: lo dice la cabecera.
        let repeated = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'en ' OR label BEGINSWITH 'in '"))
        XCTAssertEqual(repeated.count, 0, "Las filas siguen repitiendo el período bajo cada monto.")
        XCTAssertFalse(app.staticTexts["N/A"].exists, "La tabla dice «N/A».")

        // «Te quedó» lleva la misma marca y VoiceOver la lee.
        let net = element(app, "report_net_summary")
        var drags = 0
        while !net.exists, drags < 8 { app.swipeUp(); drags += 1 }
        XCTAssertTrue(net.waitForExistence(timeout: 5), "No está «Te quedó».")
        XCTAssertTrue(saysVersus(net.label), "«Te quedó» no lee su cambio: «\(net.label)».")
    }
}
