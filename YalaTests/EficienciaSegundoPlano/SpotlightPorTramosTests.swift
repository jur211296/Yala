//
//  SpotlightPorTramosTests.swift
//  YalaTests
//
//  Lote 3 de eficiencia (26-nov-2026): la reconciliación de Spotlight lee los movimientos por tramos, en contextos
//  propios, y se corta al pasar a segundo plano. Uno de los dos cierres del vigilante de iOS (`0x8BADF00D`) cayó dentro
//  de `SpotlightIndexService.desiredEntries`, que leía los 16 mil movimientos con sus relaciones de una vez.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Segundo plano · Spotlight por tramos", .serialized)
@MainActor
struct SpotlightPorTramosTests {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    /// `count` gastos sin categoría (el signo los hace gasto: «Solo gastos» no los quita) en una cuenta que suma.
    private func seed(count: Int, tiedAtSliceEdge: Int = 0) throws -> ModelContext {
        let context = try makeTestContext()
        let account = Account(name: "A", currencyCode: "PEN", colorHex: "#000000", iconName: "x", type: "cash")
        context.insert(account)
        for i in 0..<count {
            let tx = TransactionItem(date: base.addingTimeInterval(-Double(i) * 3_600), amount: -Double(i + 1),
                                     currencyCode: "PEN", account: account)
            tx.createdAt = tx.date
            context.insert(tx)
        }
        // La MISMA fecha e instante alrededor del borde del primer tramo: el orden entre ellas no es estable.
        let tied = base.addingTimeInterval(-Double(SpotlightIndexService.readSliceSize - 3) * 3_600 - 1_800)
        for i in 0..<tiedAtSliceEdge {
            let tx = TransactionItem(date: tied, amount: -Double(50_000 + i), currencyCode: "PEN", account: account)
            tx.createdAt = tied
            context.insert(tx)
        }
        try context.save()
        return context
    }

    /// La sesión de la app como la ve una persona con Yala completo: otras suites dejan `SessionState.shared` en «solo
    /// grupos», y ahí el índice se vacía sin leer nada.
    private let fullApp = SpotlightIndexLogic.Context(
        isGroupsFocusedShell: false, isExpensesOnlyMode: false, includeGroupTransactions: true)

    private func transactionEntries(_ entries: [SpotlightEntry]) -> [SpotlightEntry] {
        entries.filter { $0.kind == .transaction }
    }

    @Test("Más de un tramo: cada movimiento entra una vez, ninguno se salta")
    func severalSlices_everyRecordOnce() async throws {
        let count = SpotlightIndexService.readSliceSize * 2 + 37
        let context = try seed(count: count, tiedAtSliceEdge: 12)

        let entries = transactionEntries(try await SpotlightIndexService.desiredEntries(context: context, spotlightContext: fullApp))

        #expect(entries.count == count + 12)
        #expect(Set(entries.map(\.identifier)).count == entries.count)
    }

    @Test("Cancelada entre dos tramos, la lectura se corta (CancellationError)")
    func cancelledBetweenSlices_throws() async throws {
        let context = try seed(count: SpotlightIndexService.readSliceSize * 3)
        let fullApp = fullApp
        let task = Task { @MainActor in
            try await SpotlightIndexService.desiredEntries(context: context, spotlightContext: fullApp)
        }
        task.cancel()
        await #expect(throws: CancellationError.self) { _ = try await task.value }
    }

    // MARK: - Lógica del corte al pasar a segundo plano

    @Test("Con algo en vuelo, segundo plano lo corta y olvida la firma")
    func background_withWorkInFlight_cutsAndForgets() {
        for (pending, inFlight) in [(true, false), (false, true), (true, true)] {
            let decision = ReconcileSuspension.onBackground(hasPendingRequest: pending, hasReconcileInFlight: inFlight)
            #expect(decision == .init(cancels: true, forgetsFirma: true))
        }
    }

    @Test("Sin nada en vuelo, segundo plano no toca la firma (la vuelta no reconcilia por costumbre)")
    func background_idle_keepsTheFirma() {
        let decision = ReconcileSuspension.onBackground(hasPendingRequest: false, hasReconcileInFlight: false)
        #expect(decision == .init(cancels: false, forgetsFirma: false))
    }

    @Test("La comprobación lanza con cualquiera de los tres motivos, y no lanza sin ninguno")
    func check_throwsForEachReason() throws {
        try ReconcileSuspension.check()
        #expect(throws: CancellationError.self) { try ReconcileSuspension.check(cancelled: true) }
        #expect(throws: CancellationError.self) { try ReconcileSuspension.check(generationChanged: true) }
        #expect(throws: CancellationError.self) { try ReconcileSuspension.check(suspended: true) }
    }

    @Test("Pasar a segundo plano y volver mueve el freno de escritura del índice")
    func enterAndLeaveBackground_toggleTheWriteSuspension() {
        defer { SpotlightIndexService.leaveBackground() }
        SpotlightIndexService.enterBackground()
        #expect(SpotlightIndexService.isSuspendedInBackground)
        SpotlightIndexService.leaveBackground()
        #expect(!SpotlightIndexService.isSuspendedInBackground)
    }
}
