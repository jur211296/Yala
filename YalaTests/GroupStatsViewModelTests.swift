//
//  GroupStatsViewModelTests.swift
//  YalaTests
//
//  Unit tests for GroupStatsViewModel calculations.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct GroupStatsViewModelTests {

    // MARK: - Helpers

    private func makeExpense(
        id: UUID = UUID(),
        amount: Double,
        currencyCode: String = "PEN",
        paidByMemberID: String,
        date: Date = Date.now,
        subcategoryName: String? = nil,
        isSettled: Bool = false
    ) -> SplitExpense {
        let e = SplitExpense(
            groupZoneID: "test-zone",
            amount: amount,
            currencyCode: currencyCode,
            expenseDescription: "Test",
            paidByMemberID: paidByMemberID,
            subcategoryName: subcategoryName
        )
        e.id = id
        e.date = date
        e.isSettled = isSettled
        return e
    }

    private func makeShare(expenseID: UUID, memberID: String, amount: Double) -> SplitShare {
        SplitShare(expenseID: expenseID, memberID: memberID, amount: amount)
    }

    private func makeMember(id: UUID, displayName: String, isCurrentUser: Bool = false) -> SplitMember {
        let m = SplitMember(displayName: displayName)
        m.id = id
        m.isCurrentUser = isCurrentUser
        return m
    }

    private func makeVM(
        expenses: [SplitExpense],
        shares: [SplitShare],
        members: [SplitMember],
        currentUserMemberID: String? = nil,
        currencyCode: String = "PEN",
        period: GroupStatsPeriod = .allTime,
        selection: GroupStatsCurrencySelection? = nil,
        preferredCurrency: String? = nil,
        converter: CurrencyConverting? = nil
    ) -> GroupStatsViewModel {
        let vm = GroupStatsViewModel()
        if let converter { vm.converter = converter }
        vm.selectedPeriod = period
        vm.loadStats(
            expenses: expenses,
            shares: shares,
            members: members,
            settlements: [],
            currentUserMemberID: currentUserMemberID,
            currencyCode: currencyCode,
            preferredCurrency: preferredCurrency
        )
        // Aplica la selección DESPUÉS de loadStats para poder forzar `.all` o una
        // moneda específica (loadStats reescribiría una selección no válida).
        if let selection {
            vm.currencySelection = selection
            vm.recalculate()
        }
        return vm
    }

    // MARK: - Total Spent

    @Test func totalSpent_sumsAllExpenses() {
        let e1 = makeExpense(amount: 100, paidByMemberID: "A")
        let e2 = makeExpense(amount: 200, paidByMemberID: "B")

        let vm = makeVM(expenses: [e1, e2], shares: [], members: [])
        #expect(vm.totalSpent == 300)
    }

    @Test func totalSpent_filtersByCurrency() {
        let e1 = makeExpense(amount: 100, currencyCode: "PEN", paidByMemberID: "A")
        let e2 = makeExpense(amount: 50, currencyCode: "USD", paidByMemberID: "A")

        let vm = makeVM(expenses: [e1, e2], shares: [], members: [], currencyCode: "PEN", selection: .currency("PEN"))
        #expect(vm.totalSpent == 100)
    }

    // MARK: - Multi-currency

    @Test func availableCurrencies_listsAllWithMainFirst() {
        let e1 = makeExpense(amount: 100, currencyCode: "USD", paidByMemberID: "A")
        let e2 = makeExpense(amount: 50, currencyCode: "PEN", paidByMemberID: "A")
        let vm = makeVM(expenses: [e1, e2], shares: [], members: [], currencyCode: "PEN")
        #expect(vm.availableCurrencies == ["PEN", "USD"])  // principal primero
    }

    @Test func defaultSelection_isAll_whenMultiCurrency() {
        let e1 = makeExpense(amount: 100, currencyCode: "PEN", paidByMemberID: "A")
        let e2 = makeExpense(amount: 50, currencyCode: "USD", paidByMemberID: "A")
        let vm = makeVM(expenses: [e1, e2], shares: [], members: [], currencyCode: "PEN")
        #expect(vm.currencySelection == .all)
        #expect(vm.selectedCurrencyCode == nil)
    }

    @Test func defaultSelection_isSingle_whenOneCurrency() {
        let e1 = makeExpense(amount: 100, currencyCode: "PEN", paidByMemberID: "A")
        let vm = makeVM(expenses: [e1], shares: [], members: [], currencyCode: "PEN")
        #expect(vm.selectedCurrencyCode == "PEN")
    }

    @Test func totalsByCurrency_includesAllCurrencies() {
        let e1 = makeExpense(amount: 100, currencyCode: "PEN", paidByMemberID: "A")
        let e2 = makeExpense(amount: 50, currencyCode: "USD", paidByMemberID: "A")
        let vm = makeVM(expenses: [e1, e2], shares: [], members: [], currencyCode: "PEN")
        let dict = Dictionary(vm.totalsByCurrency.map { ($0.currencyCode, $0.total) }, uniquingKeysWith: { a, _ in a })
        #expect(dict["PEN"] == 100)
        #expect(dict["USD"] == 50)
    }

    @Test func selectedCurrency_filtersGraphs() {
        let e1 = makeExpense(amount: 100, currencyCode: "PEN", paidByMemberID: "A")
        let e2 = makeExpense(amount: 50, currencyCode: "USD", paidByMemberID: "A")
        let vm = makeVM(expenses: [e1, e2], shares: [], members: [], currencyCode: "PEN", selection: .currency("PEN"))
        #expect(vm.totalSpent == 100)  // PEN
        vm.currencySelection = .currency("USD")
        vm.recalculate()
        #expect(vm.totalSpent == 50)   // ahora filtra USD
    }

    @Test func myPortionsByCurrency_perCurrency() {
        let e1ID = UUID()
        let e2ID = UUID()
        let e1 = makeExpense(id: e1ID, amount: 100, currencyCode: "PEN", paidByMemberID: "A")
        let e2 = makeExpense(id: e2ID, amount: 50, currencyCode: "USD", paidByMemberID: "A")
        let s1 = makeShare(expenseID: e1ID, memberID: "me", amount: 40)
        let s2 = makeShare(expenseID: e2ID, memberID: "me", amount: 20)
        let vm = makeVM(expenses: [e1, e2], shares: [s1, s2], members: [], currentUserMemberID: "me", currencyCode: "PEN")
        let dict = Dictionary(vm.myPortionsByCurrency.map { ($0.currencyCode, $0.amount) }, uniquingKeysWith: { a, _ in a })
        #expect(dict["PEN"] == 40)
        #expect(dict["USD"] == 20)
    }

    // MARK: - My Portion

    @Test func myPortion_sumsSharesForCurrentUser() {
        let e1ID = UUID()
        let e2ID = UUID()
        let e1 = makeExpense(id: e1ID, amount: 300, paidByMemberID: "A")
        let e2 = makeExpense(id: e2ID, amount: 200, paidByMemberID: "B")

        let shares = [
            makeShare(expenseID: e1ID, memberID: "A", amount: 150),
            makeShare(expenseID: e1ID, memberID: "B", amount: 150),
            makeShare(expenseID: e2ID, memberID: "A", amount: 100),
            makeShare(expenseID: e2ID, memberID: "B", amount: 100)
        ]

        let vm = makeVM(expenses: [e1, e2], shares: shares, members: [], currentUserMemberID: "A")
        #expect(vm.myPortion == 250)
    }

    @Test func myPortion_nilCurrentUser_returnsZero() {
        let eID = UUID()
        let e = makeExpense(id: eID, amount: 100, paidByMemberID: "A")
        let shares = [makeShare(expenseID: eID, memberID: "A", amount: 50)]

        let vm = makeVM(expenses: [e], shares: shares, members: [], currentUserMemberID: nil)
        #expect(vm.myPortion == 0)
    }

    // MARK: - Member Spending

    @Test func memberSpending_groupsByPayer_sortedDescending() {
        let alice = UUID()
        let bob = UUID()
        let members = [
            makeMember(id: alice, displayName: "Alice"),
            makeMember(id: bob, displayName: "Bob")
        ]
        let e1 = makeExpense(amount: 100, paidByMemberID: alice.uuidString)
        let e2 = makeExpense(amount: 300, paidByMemberID: bob.uuidString)
        let e3 = makeExpense(amount: 50, paidByMemberID: alice.uuidString)

        let vm = makeVM(expenses: [e1, e2, e3], shares: [], members: members)

        #expect(vm.memberSpending.count == 2)
        #expect(vm.memberSpending[0].displayName == "Bob")
        #expect(vm.memberSpending[0].totalPaid == 300)
        #expect(vm.memberSpending[1].displayName == "Alice")
        #expect(vm.memberSpending[1].totalPaid == 150)
    }

    // MARK: - Category Breakdown

    @Test func categoryBreakdown_groupsBySubcategoryName() {
        let e1 = makeExpense(amount: 200, paidByMemberID: "A", subcategoryName: "Comida")
        let e2 = makeExpense(amount: 100, paidByMemberID: "A", subcategoryName: "Transporte")
        let e3 = makeExpense(amount: 100, paidByMemberID: "B", subcategoryName: "Comida")

        let vm = makeVM(expenses: [e1, e2, e3], shares: [], members: [])

        #expect(vm.categoryBreakdown.count == 2)
        #expect(vm.categoryBreakdown[0].subcategoryName == "Comida")
        #expect(vm.categoryBreakdown[0].amount == 300)
        #expect(vm.categoryBreakdown[0].percentage == 75)
        #expect(vm.categoryBreakdown[1].subcategoryName == "Transporte")
    }

    @Test func categoryBreakdown_nilSubcategoryGroupedAsUncategorized() {
        let e1 = makeExpense(amount: 100, paidByMemberID: "A", subcategoryName: nil)

        let vm = makeVM(expenses: [e1], shares: [], members: [])

        #expect(vm.categoryBreakdown.count == 1)
        #expect(vm.categoryBreakdown[0].subcategoryName == L10n.Groups.Stats.uncategorized)
    }

    // MARK: - Monthly Trend

    @Test func monthlyTrend_groupsByMonth() {
        let cal = Calendar.current
        let jan = cal.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let feb = cal.date(from: DateComponents(year: 2026, month: 2, day: 10))!
        let feb2 = cal.date(from: DateComponents(year: 2026, month: 2, day: 20))!

        let e1 = makeExpense(amount: 100, paidByMemberID: "A", date: jan)
        let e2 = makeExpense(amount: 200, paidByMemberID: "A", date: feb)
        let e3 = makeExpense(amount: 50, paidByMemberID: "B", date: feb2)

        let vm = makeVM(expenses: [e1, e2, e3], shares: [], members: [])

        #expect(vm.monthlyTrend.count == 2)
        #expect(vm.monthlyTrend[0].totalSpent == 100) // Jan
        #expect(vm.monthlyTrend[1].totalSpent == 250) // Feb
    }

    // MARK: - Empty Data

    @Test func emptyExpenses_returnsZeros() {
        let vm = makeVM(expenses: [], shares: [], members: [])

        #expect(vm.totalSpent == 0)
        #expect(vm.myPortion == 0)
        #expect(vm.memberSpending.isEmpty)
        #expect(vm.categoryBreakdown.isEmpty)
        #expect(vm.monthlyTrend.isEmpty)
    }

    // MARK: - Period Filter

    @Test func periodFilter_thisMonth_filtersCorrectly() {
        let now = Date.now
        let cal = Calendar.current
        let lastMonth = cal.date(byAdding: .month, value: -1, to: now)!

        let e1 = makeExpense(amount: 100, paidByMemberID: "A", date: now)
        let e2 = makeExpense(amount: 200, paidByMemberID: "A", date: lastMonth)

        let vm = makeVM(
            expenses: [e1, e2], shares: [], members: [],
            period: .thisMonth
        )

        #expect(vm.totalSpent == 100)
    }

    // MARK: - All Currencies Mode

    @Test func allMode_perCurrencyStats_groupsByCurrency() {
        let pen1 = makeExpense(amount: 100, currencyCode: "PEN", paidByMemberID: "A")
        let pen2 = makeExpense(amount: 50, currencyCode: "PEN", paidByMemberID: "B")
        let usd1 = makeExpense(amount: 30, currencyCode: "USD", paidByMemberID: "A")
        let vm = makeVM(
            expenses: [pen1, pen2, usd1], shares: [], members: [],
            currencyCode: "PEN", selection: .all
        )
        #expect(vm.perCurrencyStats.count == 2)
        let pen = vm.perCurrencyStats.first { $0.currencyCode == "PEN" }
        let usd = vm.perCurrencyStats.first { $0.currencyCode == "USD" }
        #expect(pen?.memberSpending.reduce(0) { $0 + $1.totalPaid } == 150)
        #expect(usd?.memberSpending.reduce(0) { $0 + $1.totalPaid } == 30)
    }

    @Test func allMode_donutConverted_sumsConvertedAmounts() {
        // PEN es el target (preferida); USD se convierte ×2 vía el mock.
        let pen = makeExpense(amount: 100, currencyCode: "PEN", paidByMemberID: "A", subcategoryName: "Comida")
        let usd = makeExpense(amount: 50, currencyCode: "USD", paidByMemberID: "A", subcategoryName: "Comida")
        let vm = makeVM(
            expenses: [pen, usd], shares: [], members: [],
            currencyCode: "PEN", selection: .all,
            preferredCurrency: "PEN",
            converter: MockCurrencyConverter(fixedRate: 2)
        )
        // Comida = 100 (PEN) + 50×2 (USD→PEN) = 200, único bucket → 100%.
        #expect(vm.categoryBreakdown.count == 1)
        #expect(vm.categoryBreakdown[0].subcategoryName == "Comida")
        #expect(vm.categoryBreakdown[0].amount == 200)
        #expect(vm.categoryBreakdown[0].percentage == 100)
        #expect(vm.categoriesWereConverted == true)
    }

    @Test func allMode_categoriesWereConverted_falseWhenAllInTarget() {
        let pen1 = makeExpense(amount: 100, currencyCode: "PEN", paidByMemberID: "A", subcategoryName: "Comida")
        let pen2 = makeExpense(amount: 40, currencyCode: "PEN", paidByMemberID: "A", subcategoryName: "Transporte")
        let vm = makeVM(
            expenses: [pen1, pen2], shares: [], members: [],
            currencyCode: "PEN", selection: .all, preferredCurrency: "PEN"
        )
        #expect(vm.categoriesWereConverted == false)
    }

    @Test func allMode_singleStatsAreEmpty() {
        let pen = makeExpense(amount: 100, currencyCode: "PEN", paidByMemberID: "A")
        let usd = makeExpense(amount: 50, currencyCode: "USD", paidByMemberID: "A")
        let vm = makeVM(
            expenses: [pen, usd], shares: [], members: [],
            currencyCode: "PEN", selection: .all, preferredCurrency: "PEN",
            converter: MockCurrencyConverter(fixedRate: 1)
        )
        #expect(vm.totalSpent == 0)
        #expect(vm.myPortion == 0)
        #expect(vm.memberSpending.isEmpty)
        #expect(vm.monthlyTrend.isEmpty)
    }

    @Test func singleMode_perCurrencyStatsEmpty_notConverted() {
        let pen = makeExpense(amount: 100, currencyCode: "PEN", paidByMemberID: "A")
        let usd = makeExpense(amount: 50, currencyCode: "USD", paidByMemberID: "A")
        let vm = makeVM(
            expenses: [pen, usd], shares: [], members: [],
            currencyCode: "PEN", selection: .currency("PEN")
        )
        #expect(vm.perCurrencyStats.isEmpty)
        #expect(vm.categoriesWereConverted == false)
    }

    // MARK: - Duplicados por id (merges del canal de sync)
    //
    // Los gastos llegan repetidos por merges del canal de sync (premisa escrita en
    // `GroupBalanceService`). Estadísticas tiene que contarlos UNA vez, como ya hacen la barra de
    // presupuesto de Registros (`GroupBudgetLogic`), el resumen compartible y los balances. Todos los
    // tests de esta sección salen rojos con el ViewModel anterior al arreglo (control medido el
    // 2026-10-08 sobre 823cb3b79).

    /// El caso del ticket: un gasto de S/ 400 repetido y otro de S/ 1.700 son S/ 2.100, no S/ 2.500.
    @Test func duplicadosPorIdNoInflanElTotal() {
        let shared = UUID()
        let vm = makeVM(expenses: [
            makeExpense(id: shared, amount: 400, paidByMemberID: "A"),
            makeExpense(id: shared, amount: 400, paidByMemberID: "A"),
            makeExpense(amount: 1_700, paidByMemberID: "B"),
        ], shares: [], members: [])
        #expect(vm.totalSpent == 2_100)
        #expect(vm.totalsByCurrency.map { $0.total } == [2_100])
    }

    /// No basta con el total: «quién paga», el donut y la tendencia salen de la misma lista. Un arreglo
    /// que deduplicara solo la suma del total dejaría a «A» pagando el doble en la misma pantalla.
    @Test func duplicadosPorIdNoInflanNingunDesglose() {
        let shared = UUID()
        let vm = makeVM(expenses: [
            makeExpense(id: shared, amount: 400, paidByMemberID: "A", subcategoryName: "Comida"),
            makeExpense(id: shared, amount: 400, paidByMemberID: "A", subcategoryName: "Comida"),
            makeExpense(amount: 400, paidByMemberID: "B", subcategoryName: "Transporte"),
        ], shares: [], members: [])
        #expect(vm.memberSpending.first { $0.id == "A" }?.totalPaid == 400)
        let comida = vm.categoryBreakdown.first { $0.subcategoryName == "Comida" }
        #expect(comida?.amount == 400)
        #expect(comida?.percentage == 50)
        #expect(vm.monthlyTrend.reduce(0) { $0 + $1.totalSpent } == 800)
    }

    /// Modo «Todas»: el carrusel por moneda, el donut convertido y las tarjetas de total por moneda.
    @Test func duplicadosPorIdNoInflanElModoTodas() {
        let shared = UUID()
        let vm = makeVM(
            expenses: [
                makeExpense(id: shared, amount: 30, currencyCode: "USD", paidByMemberID: "A", subcategoryName: "Comida"),
                makeExpense(id: shared, amount: 30, currencyCode: "USD", paidByMemberID: "A", subcategoryName: "Comida"),
                makeExpense(amount: 100, currencyCode: "PEN", paidByMemberID: "B", subcategoryName: "Comida"),
            ],
            shares: [], members: [],
            currencyCode: "PEN", selection: .all, preferredCurrency: "PEN",
            converter: MockCurrencyConverter(fixedRate: 2)
        )
        let usd = vm.perCurrencyStats.first { $0.currencyCode == "USD" }
        #expect(usd?.memberSpending.reduce(0) { $0 + $1.totalPaid } == 30)
        #expect(usd?.monthlyTrend.reduce(0) { $0 + $1.totalSpent } == 30)
        // Comida = 100 (PEN) + 30×2 (USD→PEN), una sola vez.
        #expect(vm.categoryBreakdown.map(\.amount) == [160])
        let totals = Dictionary(vm.totalsByCurrency.map { ($0.currencyCode, $0.total) }, uniquingKeysWith: { a, _ in a })
        #expect(totals["USD"] == 30)
    }

    /// Las dos copias de un duplicado no tienen por qué ser iguales: el merge puede dejar dos versiones
    /// del mismo gasto. Se queda la PRIMERA, como en los otros tres. Y la lista de monedas sale de la
    /// lista ya deduplicada: si no, el selector ofrecería una moneda cuyo único gasto es la copia
    /// descartada, con su pestaña vacía. Deduplicar solo en `periodExpenses` deja este test en rojo.
    @Test func monedasSalenDeLaListaDeduplicada() {
        let shared = UUID()
        let vm = makeVM(expenses: [
            makeExpense(id: shared, amount: 400, currencyCode: "PEN", paidByMemberID: "A"),
            makeExpense(id: shared, amount: 120, currencyCode: "USD", paidByMemberID: "A"),
        ], shares: [], members: [], currencyCode: "PEN")
        #expect(vm.availableCurrencies == ["PEN"])
        #expect(vm.totalsByCurrency.map { $0.currencyCode } == ["PEN"])
        #expect(vm.totalSpent == 400)
    }

    /// La cifra que el usuario compara: «Total gastado» en Estadísticas y lo gastado en la barra de
    /// presupuesto de Registros, para el mismo grupo (una moneda, período «Todo»). Lleva un saldo de
    /// apertura, que las dos excluyen, y un duplicado cuyas copias difieren, para fijar que las dos
    /// pantallas se quedan con la MISMA copia.
    @Test func totalCoincideConLaBarraDePresupuesto() throws {
        let dupIgual = UUID()
        let dupDistinto = UUID()
        let opening = makeExpense(amount: 900, paidByMemberID: "B")
        opening.isOpeningBalance = true
        let expenses = [
            makeExpense(id: dupIgual, amount: 400, paidByMemberID: "A"),
            makeExpense(id: dupIgual, amount: 400, paidByMemberID: "A"),
            makeExpense(id: dupDistinto, amount: 50, paidByMemberID: "B"),
            makeExpense(id: dupDistinto, amount: 80, paidByMemberID: "B"),
            makeExpense(amount: 1_700, paidByMemberID: "B"),
            opening,
        ]
        let vm = makeVM(expenses: expenses, shares: [], members: [], currencyCode: "PEN")
        let budget = try #require(GroupBudgetLogic.progress(
            limitAmount: 3_000,
            currencyCode: "PEN",
            expenses: expenses,
            converter: MockCurrencyConverter(fixedRate: 1)
        ))
        #expect(budget.spentAmount == 2_150)
        #expect(vm.totalSpent == budget.spentAmount)
    }
}
