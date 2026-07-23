//
//  InboxConvertToGroupUITests.swift
//  YalaUITests
//
//  Regresión del crash CRÍTICO 2.0.5 build 2 (iOS 27.0 beta, SIGTRAP de SwiftData):
//  convertir un borrador personal a "gasto compartido" desde la Bandeja borraba el
//  InboxDraft SIN podarlo antes del array cacheado del InboxViewModel → la fila
//  (InboxDraftRowView) re-renderizaba leyendo el @Model invalidado y la app moría al
//  guardar el form de grupo. Fix: podar el VM antes de borrar/persistir (finalizeConvertedDraft).
//
//  El test replica el flujo del crash (editor → Convertir → form de grupo → Guardar) y
//  verifica que la app sobrevive y que el draft manual queda REEMPLAZADO por el draft-puente.
//
//  Usa el seed `grupos-invitado` (UN solo grupo elegible) a propósito: con >1 grupo el flujo
//  pasa por el `GroupPickerSheet`, un sheet-sobre-sheet que XCUITest no puede tocar de forma
//  estable (el elemento se invalida durante la interrupción de la animación). Con un único
//  grupo, `startConversionFlow` abre el form directamente y el flujo es determinista.
//
//  NOTA: en iOS 26.x el flujo no crashea ni sin el fix (el assert de SwiftData es estricto
//  desde iOS 27). Este test es cobertura determinista del flujo + red para OS que asserten;
//  NO esperar rojo-antes/verde-después en un sim 26.x.
//
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev, targetear por identifier).
//

import XCTest

final class InboxConvertToGroupUITests: XCTestCase {
    // Notas fijas sembradas por DevSeedDrafts (estables entre locales).
    private let draftA = "Almuerzo equipo"   // el que convertimos
    private let draftB = "Taxi aeropuerto"   // el que debe sobrevivir intacto

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

    /// Regresión: convertir un draft a gasto de grupo NO debe matar la app (la fila del draft
    /// borrado no debe re-renderizarse) y debe reemplazar el draft personal por el draft-puente.
    func test_convertDraftToGroupExpense_survivesAndReplacesDraft() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos-invitado")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openInbox(app)

        // Abrir el editor del draft manual convertible.
        let rowA = app.buttons["inbox_draft_row_\(draftA)"]
        XCTAssertTrue(rowA.waitForExistence(timeout: 5), "No apareció el draft a convertir.")
        rowA.tap()

        // Tocar "Convertir a gasto compartido" (source convertible + hay grupo elegible).
        let convertButton = app.buttons["inbox_convert_to_shared_button"]
        XCTAssertTrue(convertButton.waitForExistence(timeout: 5), "No apareció el botón Convertir a gasto compartido.")
        convertButton.tap()

        // Único grupo elegible → el form de grupo abre directo (sin picker), prellenado con
        // monto + cuenta del draft → Guardar se habilita sin interacción extra. Se espera primero
        // el campo de monto (señal de "form montado") y luego el botón Guardar.
        XCTAssertTrue(
            app.textFields["group_expense_amount"].waitForExistence(timeout: 15),
            "No montó el form de gasto de grupo tras convertir (transición del sheet)."
        )
        let save = app.buttons["group_expense_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "No apareció el botón Guardar del gasto de grupo.")
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: save
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [enabled], timeout: 8),
            .completed,
            "El botón Guardar del gasto de grupo no se habilitó (canSave falso)."
        )
        save.tap()

        // ── Aserciones de regresión del crash ──

        // 1. La bandeja re-renderizó VIVA: el otro draft sigue presente. Si ocurriera el crash de
        //    la clase (fila leyendo el @Model borrado), la app moriría al Guardar y este wait fallaría.
        XCTAssertTrue(
            app.buttons["inbox_draft_row_\(draftB)"].waitForExistence(timeout: 10),
            "Tras convertir, la bandeja no volvió viva (posible crash al borrar el draft)."
        )

        // 2. Assert explícito anti-crash: el proceso sigue en foreground.
        XCTAssertEqual(app.state, .runningForeground, "La app no está en foreground tras Guardar (posible crash).")

        // 3. El draft manual fue REEMPLAZADO por el draft-puente de grupo: re-abrir "Almuerzo
        //    equipo" abre el sheet de finalización de grupo (YalaPrimaryButton → `primary_button`),
        //    NO el editor personal (`inbox_approve_button`) ni vuelve a ofrecer Convertir
        //    (`.groupExpense` no está en la allowlist de conversión).
        let rowConverted = app.buttons["inbox_draft_row_\(draftA)"]
        XCTAssertTrue(rowConverted.waitForExistence(timeout: 5), "No apareció la fila del draft convertido.")
        rowConverted.tap()
        XCTAssertTrue(
            app.buttons["primary_button"].waitForExistence(timeout: 5),
            "No se abrió el sheet de finalización de grupo del draft convertido."
        )
        XCTAssertFalse(
            app.buttons["inbox_approve_button"].exists,
            "El draft convertido abrió el editor personal (no se convirtió)."
        )
        XCTAssertFalse(
            app.buttons["inbox_convert_to_shared_button"].exists,
            "El draft convertido volvió a ofrecer Convertir (sigue siendo un draft personal manual)."
        )
    }
}
