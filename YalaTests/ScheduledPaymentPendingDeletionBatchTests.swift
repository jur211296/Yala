//
//  ScheduledPaymentPendingDeletionBatchTests.swift
//  YalaTests
//
//  Ticket `scheduled-payment-pending-deletion-loses-undo-on-a-second-delete` (2026-10-29): el borrado de un pago
//  planificado con «Deshacer» sigue el molde de los registros (`RecordPendingDeletion`). Dos borrados seguidos comparten
//  aviso y plazo, lo pendiente no cuenta fuera de Planificación y el borrado espera un poco más que el aviso.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@MainActor
@Suite("Borrar un pago planificado espera con «Deshacer» (lote)", .serialized)
struct ScheduledPaymentPendingDeletionBatchTests {

    private func makePayment(_ name: String) -> ScheduledPayment {
        ScheduledPayment(
            name: name,
            amount: 150,
            currencyCode: "PEN",
            transactionType: "expense",
            isRecurring: true,
            recurrenceType: RecurrenceType.monthly.rawValue,
            recurrenceInterval: 1,
            nextDueDate: .now,
            dayOfMonth: Calendar.current.component(.day, from: .now)
        )
    }

    /// Deja el singleton limpio aunque un caso falle a medias.
    private func reset(_ pending: ScheduledPaymentPendingDeletion, delay: Duration) {
        pending.undoAll()
        pending.commitDelayForBatch = delay
    }

    /// Dos borrados seguidos comparten aviso: su «Deshacer» devuelve los dos. Hasta el 2026-10-29 el aviso del segundo
    /// retiraba el del primero, que se borraba sin botón.
    @Test func twoDeletionsInARow_shareTheUndo() {
        let pending = ScheduledPaymentPendingDeletion.shared
        defer { reset(pending, delay: ScheduledPaymentPendingDeletion.commitDelay) }
        let gym = UUID(), rent = UUID()

        var committed: [String] = []
        pending.request(paymentID: gym, name: "Gimnasio") { committed.append("Gimnasio") }
        pending.request(paymentID: rent, name: "Alquiler") { committed.append("Alquiler") }
        #expect(pending.hides(gym))
        #expect(pending.hides(rent))

        // Lo que pulsa el «Deshacer» del aviso (y ⌘Z).
        pending.undoAll()
        #expect(!pending.hides(gym))
        #expect(!pending.hides(rent))
        #expect(committed.isEmpty)
    }

    /// Sin «Deshacer», los dos se borran juntos al terminar el plazo del último, una vez cada uno.
    @Test func twoDeletionsInARow_commitTogether() async throws {
        let pending = ScheduledPaymentPendingDeletion.shared
        let savedDelay = pending.commitDelayForBatch
        pending.commitDelayForBatch = .milliseconds(60)
        defer { reset(pending, delay: savedDelay) }
        let gym = UUID(), rent = UUID()

        var committed: [String] = []
        pending.request(paymentID: gym, name: "Gimnasio") { committed.append("Gimnasio") }
        pending.request(paymentID: rent, name: "Alquiler") { committed.append("Alquiler") }
        #expect(committed.isEmpty)
        try await Task.sleep(for: .milliseconds(300))
        #expect(committed.sorted() == ["Alquiler", "Gimnasio"])
        #expect(!pending.hides(gym))
        #expect(!pending.hides(rent))
    }

    /// El plazo es UNO y lo marca el último borrado: el primero no se borra a su hora, espera al segundo. Con un plazo por
    /// pago (el molde viejo) el primero se borraba a los 200 ms aunque su aviso ya no estuviera.
    @Test func secondDeletion_extendsTheFirstOnesDeadline() async throws {
        let pending = ScheduledPaymentPendingDeletion.shared
        let savedDelay = pending.commitDelayForBatch
        pending.commitDelayForBatch = .milliseconds(200)
        defer { reset(pending, delay: savedDelay) }
        let gym = UUID(), rent = UUID()

        var committed: [String] = []
        pending.request(paymentID: gym, name: "Gimnasio") { committed.append("Gimnasio") }
        try await Task.sleep(for: .milliseconds(120))
        pending.request(paymentID: rent, name: "Alquiler") { committed.append("Alquiler") }
        try await Task.sleep(for: .milliseconds(140))
        // A 260 ms del primero: su plazo propio ya habría vencido, el compartido (320 ms) no.
        #expect(committed.isEmpty)
        #expect(pending.hides(gym))
        try await Task.sleep(for: .milliseconds(250))
        #expect(committed.sorted() == ["Alquiler", "Gimnasio"])
    }

    /// El borrado espera un poco más que el aviso: un «Deshacer» tocado al final llega antes que el borrado.
    @Test func commitWaitsLongerThanTheNotice() {
        #expect(ScheduledPaymentPendingDeletion.commitDelay == ScheduledPaymentPendingDeletion.undoWindow + .milliseconds(400))
        #expect(ScheduledPaymentPendingDeletion.commitDelay > DraftDiscardUndoNotice.visibleDuration)
    }

    /// El tope del lote nunca es más corto que dos avisos: con el aviso alargado de un XCUITest, 30 s cortaban el lote.
    @Test func batchCap_isNeverShorterThanTwoNotices() {
        #expect(ScheduledPaymentPendingDeletion.maxBatchSpan >= .seconds(30))
        #expect(ScheduledPaymentPendingDeletion.maxBatchSpan >= ScheduledPaymentPendingDeletion.undoWindow * 2)
    }

    /// Al vencer, las pantallas recargan aunque el borrado no llegara a hacerse: el pago no se queda fuera de todas.
    @Test func batchEnd_reloadsTheScreens_evenIfNothingWasDeleted() async throws {
        let pending = ScheduledPaymentPendingDeletion.shared
        let savedDelay = pending.commitDelayForBatch
        pending.commitDelayForBatch = .milliseconds(60)
        defer { reset(pending, delay: savedDelay) }
        let gym = UUID()

        pending.request(paymentID: gym, name: "Gimnasio") { /* el borrado no se hace */ }
        let afterRequest = SessionState.shared.dataVersion
        try await Task.sleep(for: .milliseconds(250))
        #expect(!pending.hides(gym))
        #expect(SessionState.shared.dataVersion != afterRequest)
    }

    /// «Deshacer» rehace la foto de los widgets, que pudo escribirse sin el pago mientras esperaba.
    @Test func undo_refreshesTheWidgetPhoto() throws {
        let pending = ScheduledPaymentPendingDeletion.shared
        defer { reset(pending, delay: ScheduledPaymentPendingDeletion.commitDelay) }
        var refreshed = 0
        pending.request(paymentID: UUID(), name: "Gimnasio", refreshAfterUndo: { refreshed += 1 }) {}
        pending.undoAll()
        #expect(refreshed == 1)
        // Y quien borra con «Deshacer» le pasa la foto de los widgets.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let editor = try String(
            contentsOf: root.appendingPathComponent("Yala/App/Views/Planning/ScheduledPaymentEditorView.swift"), encoding: .utf8)
        #expect(editor.contains("refreshAfterUndo: { WidgetDataCache.updateCache(context: context) }"))
    }

    /// Lo que espera no sale en las pantallas que cargan por `visible(_:)`: no cuenta en sus cifras.
    @Test func pendingPayment_isLeftOutOfTheOtherScreens() {
        let pending = ScheduledPaymentPendingDeletion.shared
        defer { reset(pending, delay: ScheduledPaymentPendingDeletion.commitDelay) }
        let gym = makePayment("Gimnasio")
        let rent = makePayment("Alquiler")

        #expect(pending.visible([gym, rent]).count == 2)
        pending.request(paymentID: gym.id, name: gym.name) {}
        #expect(pending.visible([gym, rent]).map(\.id) == [rent.id])
        pending.undoAll()
        #expect(pending.visible([gym, rent]).count == 2)
    }

    /// Devolver uno deja esperando al otro, con su plazo.
    @Test func undoOne_keepsTheOtherPending() {
        let pending = ScheduledPaymentPendingDeletion.shared
        defer { reset(pending, delay: ScheduledPaymentPendingDeletion.commitDelay) }
        let gym = UUID(), rent = UUID()
        pending.request(paymentID: gym, name: "Gimnasio") {}
        pending.request(paymentID: rent, name: "Alquiler") {}
        pending.undo(gym)
        #expect(!pending.hides(gym))
        #expect(pending.hides(rent))
    }

    /// Las cargas que cuentan pagos fuera de Planificación pasan por `visible(_:)`, y el aviso deshace todo lo pendiente.
    @Test func screensLoadThroughVisible_andTheNoticeUndoesAll() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let files = [
            "Yala/App/ViewModels/ScheduledPaymentsViewModel.swift",
            "Yala/App/ViewModels/PanelViewModel.swift",
            "Yala/App/ViewModels/DetailContainerViewModel.swift",
            "Yala/Services/WidgetDataCache.swift",
            "Yala/App/Views/Statistics/CategoriesTabView.swift",
            "Yala/App/Views/Reports/FinancialReportView.swift",
            "Yala/App/Views/Reports/CashFlow/CashFlowAddLineSheet.swift",
        ]
        for file in files {
            let code = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
            #expect(code.contains("ScheduledPaymentPendingDeletion.shared.visible("), "\(file) no deja fuera lo pendiente de borrar")
        }
        let service = try String(
            contentsOf: root.appendingPathComponent("Yala/App/Services/ScheduledPaymentPendingDeletion.swift"), encoding: .utf8)
        let notice = try #require(service.range(of: "DraftDiscardUndoNotice.show("))
        #expect(service[notice.upperBound...].prefix(500).contains("self?.undoAll()"))
    }
}
