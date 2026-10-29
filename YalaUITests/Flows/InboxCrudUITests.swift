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

    /// Rechazar deslizando lo lleva a Archivados EN EL ACTO (auditoría UX 2.2 · lote 4 · B3). La retirada optimista lo
    /// quitaba de la lista y nadie recargaba: Archivados decía «Sin borradores archivados» hasta cerrar y volver a abrir.
    func test_rejectingDraftBySwipeShowsItInArchivedRightAway() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openInbox(app)

        let rowA = app.buttons["inbox_draft_row_\(draftA)"]
        XCTAssertTrue(rowA.waitForExistence(timeout: 5), "No apareció el draft a rechazar.")

        // Deslizamiento CORTO: el largo dispara la primera acción (Eliminar), que es otro caso.
        let start = rowA.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        let end = rowA.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)

        let reject = app.buttons["inbox_swipe_reject"]
        XCTAssertTrue(reject.waitForExistence(timeout: 5), "El deslizamiento no mostró Rechazar.")
        reject.tap()
        XCTAssertTrue(rowA.waitForNonExistence(timeout: 5), "El draft rechazado sigue en pendientes.")

        let archived = app.buttons["inbox_filter_archived"]
        XCTAssertTrue(archived.waitForExistence(timeout: 5), "No apareció el filtro Archivados.")
        archived.tap()

        XCTAssertTrue(
            app.buttons["inbox_draft_row_\(draftA)"].waitForExistence(timeout: 5),
            "El draft rechazado no salió en Archivados sin cerrar y volver a abrir la Bandeja."
        )
    }

    /// Descartar desde el editor (auditoría UX 2.2 · lote 4 · L4-5, variante 2): la ⓧ roja sin texto pasó a un menú
    /// «⋯» con «Descartar (va a Archivados)», y al descartar sale «Lo moviste a Archivados · Deshacer». «Deshacer» lo
    /// devuelve a pendientes y la Bandeja lo enseña sin cerrar y volver a abrir.
    func test_discardingFromEditorMenuOffersUndoThatBringsItBack() {
        let app = XCUIApplication()
        // El aviso dura 5 s y aquí se espera además a que la fila se vaya: en un runner frío del CI eso pasaba de 5 s y
        // «Deshacer» ya no estaba al tocarlo (nocturna 40899279330). Molde: `UXAudit22Lote08UITests`.
        app.launchForUITest(extraArguments: ["-uitest-undo-notice-seconds", "30"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openInbox(app)

        let rowA = app.buttons["inbox_draft_row_\(draftA)"]
        XCTAssertTrue(rowA.waitForExistence(timeout: 5), "No apareció el draft a descartar.")
        rowA.tap()

        let more = app.buttons["draft_editor_more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5), "El editor no tiene el menú «⋯».")
        more.tap()

        let discard = app.buttons["draft_editor_discard"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5), "El menú «⋯» no ofrece Descartar.")
        XCTAssertTrue(
            app.buttons["draft_editor_delete_forever"].exists, "El menú «⋯» no ofrece Eliminar para siempre."
        )
        discard.tap()

        // El editor se cierra, el borrador sale de pendientes y el aviso dice a dónde fue.
        let undo = app.buttons["draft_discard_undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "Tras descartar no salió el aviso con «Deshacer».")
        XCTAssertTrue(rowA.waitForNonExistence(timeout: 5), "El draft descartado sigue en pendientes.")

        undo.tap()

        XCTAssertTrue(
            app.buttons["inbox_draft_row_\(draftA)"].waitForExistence(timeout: 5),
            "«Deshacer» no devolvió el draft a pendientes (o la Bandeja no recargó)."
        )
        XCTAssertTrue(undo.waitForNonExistence(timeout: 5), "El aviso no se fue tras tocar «Deshacer».")
    }

    /// Deslizar DEL TODO descarta: el borrador va a Archivados y se puede recuperar (auditoría UX 2.2 · lote 4 · L4-6).
    /// Antes la primera acción era Eliminar y el gesto largo borraba para siempre, sin preguntar.
    func test_fullSwipeDiscardsToArchived_insteadOfDeletingForGood() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openInbox(app)

        let rowA = app.buttons["inbox_draft_row_\(draftA)"]
        XCTAssertTrue(rowA.waitForExistence(timeout: 5), "No apareció el draft a descartar.")

        let start = rowA.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        let end = rowA.coordinate(withNormalizedOffset: CGVector(dx: -0.6, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)

        XCTAssertTrue(rowA.waitForNonExistence(timeout: 5), "Deslizar del todo no sacó el draft de pendientes.")

        let archived = app.buttons["inbox_filter_archived"]
        XCTAssertTrue(archived.waitForExistence(timeout: 5), "No apareció el filtro Archivados.")
        archived.tap()
        XCTAssertTrue(
            app.buttons["inbox_draft_row_\(draftA)"].waitForExistence(timeout: 5),
            "Deslizar del todo no lo dejó en Archivados: lo borró para siempre."
        )
    }

    /// Deslizamiento corto sobre una fila: deja a la vista sus acciones (Descartar, Eliminar) sin dispararlas.
    private func revealSwipeActions(of row: XCUIElement) {
        let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        let end = row.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// Espera del borrado diferido de la Bandeja en estos casos (`-uitest-inbox-removal-delay-seconds`): más larga que lo
    /// que tarda el test entre dos gestos (en iOS 27.0, más de 4 s), para que el segundo caiga SIEMPRE dentro de la
    /// espera del primero.
    private let removalDelaySeconds = 10.0

    /// La app sigue viva y la Bandeja en pantalla pasado el borrado diferido de las filas, con margen.
    private func assertInboxStillAlive(_ app: XCUIApplication, _ message: String) {
        let pendingFilter = app.buttons["inbox_filter_pending"]
        XCTAssertFalse(pendingFilter.waitForNonExistence(timeout: removalDelaySeconds + 2), message)
        XCTAssertEqual(app.state, .runningForeground, message)
    }

    /// Crash de TestFlight 2.2 (2), 2026-10-29: borrar dos borradores seguidos cerraba Yala. La retirada de cada fila
    /// es optimista y el borrado real va 400 ms después; la recarga del primero devolvía a la lista el segundo, aún sin
    /// borrar, y su fila leía después el `InboxDraft` borrado (SIGTRAP de SwiftData). Card f8rj.
    func test_deletingTwoDraftsInARow_keepsTheAppAlive() {
        let app = XCUIApplication()
        app.launchForUITest(extraArguments: ["-uitest-inbox-removal-delay-seconds", "\(removalDelaySeconds)"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openInbox(app)

        let rowA = app.buttons["inbox_draft_row_\(draftA)"]
        let rowB = app.buttons["inbox_draft_row_\(draftB)"]
        XCTAssertTrue(rowA.waitForExistence(timeout: 5), "No apareció el primer draft a borrar.")
        XCTAssertTrue(rowB.exists, "No apareció el segundo draft a borrar.")

        let delete = app.buttons["inbox_swipe_delete"]
        revealSwipeActions(of: rowA)
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "El deslizamiento no mostró Eliminar en el primero.")
        delete.tap()

        revealSwipeActions(of: rowB)
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "El deslizamiento no mostró Eliminar en el segundo.")
        delete.tap()

        // El primero termina su espera mientras el segundo aún espera la suya: su recarga no puede devolver el segundo
        // a la lista (era el que se pintaba con su borrador ya borrado).
        XCTAssertTrue(rowB.waitForNonExistence(timeout: 5), "El segundo borrador no salió de la lista.")
        XCTAssertFalse(
            rowB.waitForExistence(timeout: removalDelaySeconds + 1),
            "Al terminar el primer borrado, el segundo —aún sin borrar— volvió a la lista."
        )
        assertInboxStillAlive(app, "Borrar dos borradores seguidos cerró la Bandeja (o la app).")
        XCTAssertFalse(rowA.exists, "El primer borrador borrado sigue en pendientes.")
        XCTAssertFalse(rowB.exists, "El segundo borrador borrado sigue en pendientes.")

        app.buttons["inbox_filter_archived"].tap()
        assertInboxStillAlive(app, "Tras borrar dos seguidos, abrir Archivados cerró la app.")
        XCTAssertFalse(rowA.exists, "El primer borrador no se borró: está en Archivados.")
        XCTAssertFalse(rowB.exists, "El segundo borrador no se borró: está en Archivados.")
    }

    /// Borra un borrador desde su editor: «⋯» → «Eliminar para siempre» → confirmar.
    private func deleteFromEditor(_ app: XCUIApplication, row: XCUIElement) {
        XCTAssertTrue(row.waitForExistence(timeout: 5), "No apareció el draft a borrar desde el editor.")
        row.tap()
        let more = app.buttons["draft_editor_more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5), "El editor no tiene el menú «⋯».")
        more.tap()
        let deleteForever = app.buttons["draft_editor_delete_forever"]
        XCTAssertTrue(deleteForever.waitForExistence(timeout: 5), "El menú «⋯» no ofrece Eliminar para siempre.")
        deleteForever.tap()
        let confirm = app.alerts.firstMatch.buttons["draft_editor_delete_confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "No se pidió confirmación antes de borrar.")
        confirm.tap()
    }

    /// La otra entrada del mismo gesto: borrar dos seguidos desde el editor. El editor borraba el borrador con su fila
    /// montada debajo de la hoja y sin podarla, y la fila lo leía al volver a pintarse.
    func test_deletingTwoDraftsInARowFromTheEditor_keepsTheAppAlive() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openInbox(app)

        let rowA = app.buttons["inbox_draft_row_\(draftA)"]
        let rowB = app.buttons["inbox_draft_row_\(draftB)"]
        deleteFromEditor(app, row: rowA)
        XCTAssertTrue(rowA.waitForNonExistence(timeout: 5), "El borrador borrado desde el editor sigue en la lista.")
        deleteFromEditor(app, row: rowB)

        assertInboxStillAlive(app, "Borrar dos borradores seguidos desde el editor cerró la Bandeja (o la app).")
        XCTAssertFalse(rowA.exists, "El primer borrador borrado sigue en pendientes.")
        XCTAssertFalse(rowB.exists, "El segundo borrador borrado sigue en pendientes.")
    }

    /// La misma pareja con «Deshacer» de por medio: descartar el primero (deslizar del todo), borrar el segundo y
    /// deshacer el descarte. El primero vuelve a pendientes y la app no se cierra.
    func test_discardThenDeleteThenUndo_keepsTheAppAlive() {
        let app = XCUIApplication()
        app.launchForUITest(extraArguments: [
            "-uitest-undo-notice-seconds", "30", "-uitest-inbox-removal-delay-seconds", "\(removalDelaySeconds)",
        ])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openInbox(app)

        let rowA = app.buttons["inbox_draft_row_\(draftA)"]
        let rowB = app.buttons["inbox_draft_row_\(draftB)"]
        XCTAssertTrue(rowA.waitForExistence(timeout: 5), "No apareció el draft a descartar.")

        let start = rowA.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        let end = rowA.coordinate(withNormalizedOffset: CGVector(dx: -0.6, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)

        let delete = app.buttons["inbox_swipe_delete"]
        XCTAssertTrue(rowB.waitForExistence(timeout: 5), "No apareció el draft a borrar.")
        revealSwipeActions(of: rowB)
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "El deslizamiento no mostró Eliminar.")
        delete.tap()

        // El aviso sale cuando el descarte se guarda, al terminar la espera.
        let undo = app.buttons["draft_discard_undo"]
        XCTAssertTrue(
            undo.waitForExistence(timeout: removalDelaySeconds + 5), "Tras descartar no salió el aviso con «Deshacer»."
        )
        undo.tap()

        XCTAssertTrue(rowA.waitForExistence(timeout: 5), "«Deshacer» no devolvió el draft descartado a pendientes.")
        assertInboxStillAlive(app, "Descartar, borrar y deshacer seguidos cerró la Bandeja (o la app).")
        XCTAssertFalse(rowB.exists, "El borrador borrado volvió a pendientes.")
    }

    /// «Guardar los N listos» guarda de un toque todo lo completo, tras confirmar (auditoría UX 2.2 · lote 4 · L4-7).
    /// Antes eran cuatro toques: ✓, Seleccionar todo, Editar y Aprobar.
    func test_saveReadyButton_savesEveryCompleteDraftAfterConfirming() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openInbox(app)

        let saveReady = app.buttons["inbox_save_ready"]
        XCTAssertTrue(saveReady.waitForExistence(timeout: 5), "Con dos borradores completos no salió «Guardar los listos».")
        saveReady.tap()

        let confirm = app.alerts.firstMatch.buttons["inbox_save_ready_confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "No se pidió confirmación antes de guardar todo.")
        confirm.tap()

        let back = app.buttons["inbox_bulk_success_back"]
        XCTAssertTrue(back.waitForExistence(timeout: 10), "No salió la pantalla final tras guardar los listos.")
        XCTAssertTrue(app.staticTexts["inbox_bulk_success_summary"].exists, "La pantalla final no dice cuánto se guardó.")
        back.tap()

        // Sin pendientes la Bandeja se cierra sola: se vuelve a abrir para mirar la lista, no su ausencia.
        let pendingFilter = app.buttons["inbox_filter_pending"]
        if !pendingFilter.waitForExistence(timeout: 3) {
            openInbox(app)
            XCTAssertTrue(pendingFilter.waitForExistence(timeout: 5), "No se pudo volver a abrir la Bandeja.")
        }
        XCTAssertFalse(app.buttons["inbox_draft_row_\(draftA)"].exists, "El primer borrador completo sigue en pendientes.")
        XCTAssertFalse(app.buttons["inbox_draft_row_\(draftB)"].exists, "El segundo borrador completo sigue en pendientes.")
        app.buttons["inbox_filter_archived"].tap()
        XCTAssertTrue(
            app.buttons["inbox_draft_row_\(draftA)"].waitForExistence(timeout: 5),
            "El borrador guardado no está en Archivados: no se guardó."
        )
    }
}
