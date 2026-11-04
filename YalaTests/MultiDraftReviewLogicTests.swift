//
//  MultiDraftReviewLogicTests.swift
//  YalaTests
//
//  La hoja de varios registros de foto y voz (card va62): marcado por defecto, resumen de lo marcado, bloques por día,
//  y que «Guardar» apruebe solo lo marcado y completo.
//

import Foundation
import Testing
@testable import Yala

@Suite("Hoja de varios registros")
struct MultiDraftReviewLogicTests {
    typealias Logic = MultiDraftReviewLogic
    typealias Item = Logic.Item<Int>

    private let calendar = Calendar(identifier: .gregorian)
    private var today: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 12)) ?? .distantPast }

    private func item(
        _ id: Int, _ amount: Double?, daysAgo: Int = 0, category: String? = "food", currency: String = "PEN",
        pending: Bool = true, complete: Bool = true
    ) -> Item {
        Item(
            id: id, amount: amount, currencyCode: currency,
            date: calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today,
            categoryKey: category, categoryName: category ?? "Sin categoría", colorHex: category == nil ? nil : "#00AA00",
            isPending: pending, isSaved: !pending, isComplete: complete
        )
    }

    private func selection(_ items: [Item]) -> Logic.Selection<Int> {
        var selection = Logic.Selection<Int>()
        selection.sync(with: items.map(\.id))
        return selection
    }

    @Test("Todo lo que llega sale marcado, y lo desmarcado se queda así aunque lleguen más")
    func newDraftsArriveMarked() {
        var selection = Logic.Selection<Int>()
        selection.sync(with: [1, 2])
        #expect(selection.contains(1) && selection.contains(2))
        selection.toggle(2)
        selection.sync(with: [1, 2, 3])
        #expect(selection.contains(3))
        #expect(!selection.contains(2))
        selection.sync(with: [])
        selection.sync(with: [2])
        #expect(selection.contains(2), "Sin borradores la hoja empieza de cero.")
    }

    @Test("El total, los subtotales y el botón cuentan solo lo marcado, sin signo")
    func totalsCountOnlyMarked() {
        let items = [item(1, -83.47), item(2, -6.25), item(3, -18.90, daysAgo: 1), item(4, 50, daysAgo: 1)]
        var selection = selection(items)
        selection.toggle(3)
        #expect(abs(Logic.total(items, selection) - 139.72) < 0.001)
        #expect(abs(Logic.saveTotal(items, selection) - 139.72) < 0.001)
        let yesterday = Logic.days(items, calendar: calendar)[1]
        #expect(abs(Logic.subtotal(yesterday.ids, items: items, selection) - 50) < 0.001)
        #expect(Logic.toSave(items, selection).map(\.id) == [1, 2, 4])
    }

    @Test("Un bloque por día, del más reciente al más antiguo, en el orden en que llegaron")
    func groupsByDayNewestFirst() {
        let items = [item(1, -1, daysAgo: 3), item(2, -1), item(3, -1, daysAgo: 3), item(4, -1, daysAgo: 1)]
        let days = Logic.days(items, calendar: calendar)
        #expect(days.map(\.ids) == [[2], [4], [1, 3]])
        let range = Logic.dateRange(items)
        #expect(range.map { calendar.isDate($0.lowerBound, inSameDayAs: items[0].date) } == true)
    }

    @Test("Guardar se enciende solo si todo lo marcado está completo; desmarcar lo incompleto lo enciende")
    func incompleteMarkedBlocksSave() {
        let items = [item(1, -10), item(2, -5, category: nil, complete: false)]
        var selection = selection(items)
        #expect(!Logic.canSave(items, selection))
        #expect(Logic.incompleteMarked(items, selection) == 1)
        selection.toggle(2)
        #expect(Logic.canSave(items, selection))
        #expect(Logic.leavesUnmarkedInInbox(items, selection))
        selection.setAll(false, pending: [1, 2])
        #expect(!Logic.canSave(items, selection), "Sin nada marcado no hay nada que guardar.")
    }

    @Test("Tras guardar lo marcado la hoja termina, aunque queden desmarcados en la Bandeja")
    func finishedAfterSavingMarked() {
        var items = [item(1, -10), item(2, -5)]
        var selection = selection(items)
        selection.toggle(2)
        #expect(!Logic.isFinished(items, selection))
        items[0].isPending = false
        items[0].isSaved = true
        #expect(Logic.isFinished(items, selection))
        #expect(Logic.toSave(items, selection).isEmpty)
        selection.setAll(true, pending: [2])
        #expect(!Logic.isFinished(items, selection), "Si vuelve a marcar el que quedaba, aún hay qué guardar.")
    }

    @Test("La barra junta lo que no tiene categoría y la leyenda solo nombra categorías")
    func slicesAndLegend() {
        let items = [
            item(1, -80, category: "food"), item(2, -20, category: nil, complete: false),
            item(3, -30, category: "car"), item(4, -10, category: "food"), item(5, -5, category: nil, complete: false),
        ]
        let selection = selection(items)
        let slices = Logic.slices(items, selection)
        #expect(slices.map(\.key) == ["food", "car", nil])
        #expect(slices.last?.value == 25)
        #expect(Logic.legend(slices).map(\.key) == ["food", "car"])
    }

    @Test("Sumar soles con dólares no es un total: con divisas mezcladas no hay cifra")
    func mixedCurrenciesHaveNoTotal() {
        let items = [item(1, -10, currency: "PEN"), item(2, -5, currency: "USD")]
        #expect(Logic.sharedCurrency(items) == nil)
        #expect(Logic.sharedCurrency([items[0]]) == "PEN")
    }
}
