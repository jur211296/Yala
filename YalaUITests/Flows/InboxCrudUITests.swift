//
//  InboxCrudUITests.swift
//  YalaUITests
//
//  Cobertura XCUITest del área `inbox-crud` (escenarios 16.x): la bandeja de
//  borradores. El seed (DevSeedDrafts) siembra 2 drafts pending completos.
//  2 tests: (a) abrir el Inbox desde el Panel y ver los drafts pendientes;
//  (b) aprobar un draft (tap fila → editor → Aprobar → pantalla de éxito →
//  Aceptar) y verificar que sale de pendientes mientras el otro permanece (queda
//  1 → el Inbox no se auto-cierra). Seed `minimal`.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class InboxCrudUITests: XCTestCase {
    // Notas fijas sembradas por DevSeedDrafts (estables entre locales).
    private let draftA = "Almuerzo equipo"
    private let draftB = "Taxi aeropuerto"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Abre el Inbox desde el botón de bandeja del toolbar del Panel.
    private func openInbox(_ app: XCUIApplication) {
        let inboxButton = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inboxButton.waitForExistence(timeout: 10), "No apareció el botón del Inbox en el Panel.")
        inboxButton.tap()
    }

    /// Smoke: el Inbox lista los drafts pendientes sembrados.
    func test_opensInboxAndListsPendingDrafts() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openInbox(app)

        XCTAssertTrue(
            app.buttons["inbox_draft_row_\(draftA)"].waitForExistence(timeout: 5),
            "El Inbox no mostró el primer draft pendiente."
        )
        XCTAssertTrue(
            app.buttons["inbox_draft_row_\(draftB)"].exists,
            "El Inbox no mostró el segundo draft pendiente."
        )
    }

    /// CRUD — aprobar un draft lo saca de pendientes; el segundo permanece.
    func test_approvingDraftRemovesItFromPending() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openInbox(app)

        // Abrir el editor del primer draft.
        let rowA = app.buttons["inbox_draft_row_\(draftA)"]
        XCTAssertTrue(rowA.waitForExistence(timeout: 5), "No apareció el draft a aprobar.")
        rowA.tap()

        // Aprobar (el draft sembrado está completo → botón habilitado).
        let approveButton = app.buttons["inbox_approve_button"]
        XCTAssertTrue(approveButton.waitForExistence(timeout: 5), "No se montó el editor del draft (botón Aprobar).")
        XCTAssertTrue(approveButton.isEnabled, "El botón Aprobar está deshabilitado (draft incompleto).")
        approveButton.tap()

        // Pantalla de éxito → Aceptar (cierra el editor y vuelve al Inbox).
        let acceptButton = app.buttons["inbox_success_accept"]
        XCTAssertTrue(acceptButton.waitForExistence(timeout: 5), "No apareció la pantalla de éxito (Aceptar).")
        acceptButton.tap()

        // El draft aprobado sale de pendientes; el otro permanece.
        XCTAssertTrue(
            app.buttons["inbox_draft_row_\(draftA)"].waitForNonExistence(timeout: 5),
            "El draft aprobado sigue en la lista de pendientes."
        )
        XCTAssertTrue(
            app.buttons["inbox_draft_row_\(draftB)"].waitForExistence(timeout: 5),
            "El segundo draft pendiente desapareció inesperadamente."
        )
    }
}
