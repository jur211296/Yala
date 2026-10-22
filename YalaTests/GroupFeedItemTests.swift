//
//  GroupFeedItemTests.swift
//  YalaTests
//
//  Lógica pura del feed mixto del grupo (gastos + liquidaciones confirmadas).
//  @Model directos sin ModelContext; fechas fijas (nunca `Date()` sin control).
//

import Foundation
import Testing

@testable import Yala

@Suite(.serialized)
@MainActor
struct GroupFeedItemTests {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeExpense(desc: String, createdAt: Date, date: Date? = nil) -> SplitExpense {
        let e = SplitExpense(expenseDescription: desc, date: date ?? createdAt)
        e.createdAt = createdAt
        return e
    }

    private func makeSettlement(date: Date, confirmed: Bool) -> SplitSettlement {
        let s = SplitSettlement(date: date)
        s.isConfirmed = confirmed
        return s
    }

    // MARK: - Filtro solo-confirmados

    @Test func feedIncludesOnlyConfirmedSettlements() {
        let expense = makeExpense(desc: "Mercado", createdAt: base)
        let confirmed = makeSettlement(date: base.addingTimeInterval(100), confirmed: true)
        let pending = makeSettlement(date: base.addingTimeInterval(200), confirmed: false)

        let items = GroupFeedItem.feedItems(expenses: [expense], settlements: [confirmed, pending])

        #expect(items.count == 2) // 1 gasto + 1 liquidación confirmada
        let settlementIDs: [String] = items.compactMap {
            if case .settlement(let s) = $0 { return s.id.uuidString }
            return nil
        }
        #expect(settlementIDs == [confirmed.id.uuidString])
        #expect(!settlementIDs.contains(pending.id.uuidString))
    }

    @Test func feedWithoutConfirmedSettlementsHasOnlyExpenses() {
        let expense = makeExpense(desc: "Café", createdAt: base)
        let pending = makeSettlement(date: base, confirmed: false)

        let items = GroupFeedItem.feedItems(expenses: [expense], settlements: [pending])

        #expect(items.count == 1)
        if case .expense = items[0] {} else { Issue.record("solo debía quedar el gasto") }
    }

    // MARK: - Merge ordenado (item más nuevo primero)

    @Test func mergeSortedNewestFirst() {
        let oldExpense = makeExpense(desc: "old", createdAt: base)
        let newExpense = makeExpense(desc: "new", createdAt: base.addingTimeInterval(3600))
        let midSettlement = makeSettlement(date: base.addingTimeInterval(1800), confirmed: true)

        let items = GroupFeedItem
            .feedItems(expenses: [oldExpense, newExpense], settlements: [midSettlement])
            .sorted { $0.sortTimestamp > $1.sortTimestamp }

        #expect(items.map(\.sortTimestamp) == [
            base.addingTimeInterval(3600),
            base.addingTimeInterval(1800),
            base
        ])
        // El settlement queda intercalado entre los dos gastos.
        if case .settlement = items[1] {} else { Issue.record("el settlement debía quedar en el medio") }
    }

    // MARK: - Ids sin colisión entre familias

    @Test func idsDoNotCollideAcrossFamilies() {
        let shared = UUID()
        let expense = makeExpense(desc: "x", createdAt: base)
        expense.id = shared
        let settlement = makeSettlement(date: base, confirmed: true)
        settlement.id = shared

        let items = GroupFeedItem.feedItems(expenses: [expense], settlements: [settlement])
        let ids = items.map(\.id)

        #expect(Set(ids).count == 2) // sin colisión pese al mismo UUID base
        #expect(ids.contains(shared.uuidString))
        #expect(ids.contains("settlement-\(shared.uuidString)"))
    }

    // MARK: - Settlement y expense el mismo día

    @Test func sameDaySettlementAndExpenseShareTheDay() {
        // Mismo día; el settlement date-only (sortTimestamp = date, medianoche) queda al fondo.
        let day = base
        let expense = makeExpense(desc: "compra", createdAt: day.addingTimeInterval(500), date: day)
        let settlement = makeSettlement(date: day, confirmed: true)

        let items = GroupFeedItem
            .feedItems(expenses: [expense], settlements: [settlement])
            .sorted { $0.sortTimestamp > $1.sortTimestamp }

        #expect(items.first?.date == day)
        #expect(items.last?.date == day)
        if case .expense = items[0] {} else { Issue.record("el gasto (createdAt mayor) debía ir primero") }
        if case .settlement = items[1] {} else { Issue.record("el settlement debía ir al fondo del día") }
    }
}
