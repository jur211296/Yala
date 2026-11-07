//
//  PanelQuickActionsLargeTextUITests.swift
//  YalaUITests
//
//  Mejoras necesarias 2.3 · Panel (PN-6 de la revisión por vistas): con el texto en tamaños de accesibilidad, las
//  acciones rápidas bajo la cifra del Panel se salían de la pantalla. La fila es un scroll horizontal y «Nuevo
//  registro» solo ya era más ancho que el iPhone: «Foto» cortado y «Yala IA» fuera. Desde el arreglo, con texto de
//  accesibilidad la fila se reparte en varias líneas (`PanelQuickActionsRow.accessibilityActions`) y las cuatro
//  acciones quedan enteras dentro de su fila (en el iPad, media columna). A tamaño normal la fila es la de siempre: una
//  sola línea.
//
//  Seed `realista` y scheme Yala Dev.
//

import XCTest

final class PanelQuickActionsLargeTextUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private let actionIDs = ["panel_action_new", "panel_action_voice", "panel_action_image", "panel_action_ai"]

    func test_accessibilityXXXL_everyQuickActionIsWhollyOnScreen() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", extraArguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let first = app.buttons["panel_action_new"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 15), "No aparece «Nuevo registro» en el Panel (panel_action_new).")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "panel-acciones-ax5"
        shot.lifetime = .keepAlways
        add(shot)

        // Se mide contra la propia fila, no contra la pantalla: en el iPad la fila vive en media columna y lo que se sale
        // de ella queda recortado aunque siga dentro de la ventana (medido sobre origin/2.3: «Voz» cortado, «Foto» y
        // «Yala IA» fuera, con las cuatro dentro de la ventana).
        let row = app.descendants(matching: .any)["panel_quick_actions"].firstMatch
        XCTAssertTrue(row.exists, "No aparece la fila de acciones (panel_quick_actions).")
        let bounds = row.frame.intersection(app.windows.firstMatch.frame)
        for id in actionIDs {
            let action = app.buttons[id].firstMatch
            XCTAssertTrue(action.exists, "Con AX5 falta la acción \(id) en el Panel.")
            let frame = action.frame
            XCTAssertGreaterThanOrEqual(frame.minX, bounds.minX - 0.5,
                                        "Con AX5 la acción \(id) empieza fuera de su fila (\(frame), fila \(bounds)).")
            XCTAssertLessThanOrEqual(frame.maxX, bounds.maxX + 0.5,
                                     "Con AX5 la acción \(id) se sale de su fila por la derecha (\(frame), fila \(bounds)).")
        }
    }

    /// Control a tamaño normal: la fila sigue siendo UNA línea, con las cuatro acciones a la misma altura. Sin esto el
    /// caso de arriba pasaría también apilando las acciones siempre.
    func test_defaultTextSize_quickActionsStayInOneRow() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let first = app.buttons["panel_action_new"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 15), "No aparece «Nuevo registro» en el Panel (panel_action_new).")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "panel-acciones-normal"
        shot.lifetime = .keepAlways
        add(shot)

        for id in actionIDs.dropFirst() {
            let action = app.buttons[id].firstMatch
            XCTAssertTrue(action.exists, "A tamaño normal falta la acción \(id).")
            XCTAssertEqual(action.frame.midY, first.frame.midY, accuracy: 1,
                           "A tamaño normal \(id) no va en la misma fila que «Nuevo registro».")
        }
    }
}
