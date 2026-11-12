//
//  InboxLargeTextUITests.swift
//  YalaUITests
//
//  Card rrpx: con el texto al máximo (AX5) la cabecera de la Bandeja —resumen, filtros, guía— ocupaba un iPhone SE
//  entero y quedaba FIJA: deslizar no movía nada y los borradores vivían en una franja de pocos puntos. Ahora, a tamaños
//  de accesibilidad, la cabecera se desplaza con la lista.
//
//  El caso discrimina en cualquier iPhone: con la cabecera fija, el filtro «Pendientes» no se mueve al deslizar; con la
//  cabecera dentro de la lista, sube. Seed `minimal` (dos borradores, `DevSeedDrafts`).
//

import XCTest

final class InboxLargeTextUITests: XCTestCase {

    private let draftA = "Almuerzo equipo"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_ax5_headerScrollsAway_andTheDraftsAreReachable() {
        let app = XCUIApplication()
        app.launchForUITest(extraArguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let inboxButton = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inboxButton.waitForExistence(timeout: 15), "No apareció el botón de la Bandeja en el Panel.")
        inboxButton.tap()

        let pending = app.buttons["inbox_filter_pending"]
        XCTAssertTrue(pending.waitForExistence(timeout: 10), "No montó la Bandeja.")
        let before = pending.frame.minY

        var moved = false
        for _ in 0..<4 {
            app.swipeUp()
            if !pending.exists || pending.frame.minY < before - 40 { moved = true; break }
        }
        XCTAssertTrue(moved, "A AX5 la cabecera de la Bandeja no se movió al deslizar: sigue fija sobre la lista (rrpx).")

        let row = app.buttons["inbox_draft_row_\(draftA)"]
        var reachable = false
        for _ in 0..<6 {
            if row.exists, !row.frame.isEmpty, app.windows.firstMatch.frame.contains(CGPoint(x: row.frame.midX, y: row.frame.midY)) {
                reachable = true
                break
            }
            app.swipeUp()
        }
        XCTAssertTrue(reachable, "A AX5 no se llega al primer borrador deslizando.")
    }
}
