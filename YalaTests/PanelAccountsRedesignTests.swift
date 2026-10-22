//
//  PanelAccountsRedesignTests.swift
//  YalaTests
//
//  `panel-accounts-redesign` (2026-10-03): la tarjeta de cuenta del Panel, la vista de cuenta y el puente de la hoja
//  de filtros. Todo lógica pura salvo el puente, que escribe en un `SessionState` propio y no en el global.
//

import Foundation
import Testing
@testable import Yala

// MARK: - Tarjeta

@Suite("PanelAccountCardLogic")
struct PanelAccountCardLogicTests {

    @Test func style_followsTheFilter() {
        #expect(PanelAccountCardLogic.style(isSelected: false, isExcludeMode: false) == .plain)
        #expect(PanelAccountCardLogic.style(isSelected: false, isExcludeMode: true) == .plain)
        #expect(PanelAccountCardLogic.style(isSelected: true, isExcludeMode: false) == .tinted)
        #expect(PanelAccountCardLogic.style(isSelected: true, isExcludeMode: true) == .excluded)
    }

    @Test func subtitle_isTypeAndCurrency_orCurrencyAlone() {
        #expect(PanelAccountCardLogic.subtitle(typeName: "Efectivo", currencyCode: "PEN") == "Efectivo · PEN")
        #expect(PanelAccountCardLogic.subtitle(typeName: nil, currencyCode: "USD") == "USD")
        #expect(PanelAccountCardLogic.subtitle(typeName: "", currencyCode: "USD") == "USD")
    }

    /// Siempre asoma la siguiente tarjeta (80 % del ancho), con techo para que en ancha salga media más.
    @Test func cardWidth_isEightyPercent_cappedAt320() {
        #expect(PanelAccountCardLogic.cardWidth(containerWidth: 370) == 296)
        #expect(PanelAccountCardLogic.cardWidth(containerWidth: 400) == 320)
        #expect(PanelAccountCardLogic.cardWidth(containerWidth: 401) == 320)
        #expect(PanelAccountCardLogic.cardWidth(containerWidth: 900) == 320)
        #expect(PanelAccountCardLogic.cardWidth(containerWidth: 0) == 320)
    }

    @Test func amountKind_saysWhatTheNumberIs() {
        #expect(PanelAccountCardLogic.amountKind(isExpensesOnlyMode: false, isCreditCard: false, value: -50) == .balance)
        #expect(PanelAccountCardLogic.amountKind(isExpensesOnlyMode: false, isCreditCard: true, value: -50) == .toPay)
        // Una tarjeta pagada de más tiene saldo a favor, no deuda.
        #expect(PanelAccountCardLogic.amountKind(isExpensesOnlyMode: false, isCreditCard: true, value: 20) == .balance)
        #expect(PanelAccountCardLogic.amountKind(isExpensesOnlyMode: false, isCreditCard: true, value: 0) == .balance)
        // En «solo gastos» el número es lo gastado, también en tarjetas de crédito.
        #expect(PanelAccountCardLogic.amountKind(isExpensesOnlyMode: true, isCreditCard: true, value: -50) == .spent)
    }

    @Test func displayedValue_toPayIsPositive_restUntouched() {
        #expect(PanelAccountCardLogic.displayedValue(-1284.3, kind: .toPay) == 1284.3)
        #expect(PanelAccountCardLogic.displayedValue(-10, kind: .balance) == -10)
        #expect(PanelAccountCardLogic.displayedValue(10, kind: .spent) == 10)
    }

    @Test func showsConversion_onlyForBalanceOrDebtInAnotherCurrency() {
        #expect(PanelAccountCardLogic.showsConversion(kind: .balance, accountCurrency: "USD", defaultCurrency: "PEN"))
        #expect(PanelAccountCardLogic.showsConversion(kind: .toPay, accountCurrency: "USD", defaultCurrency: "PEN"))
        #expect(!PanelAccountCardLogic.showsConversion(kind: .balance, accountCurrency: "PEN", defaultCurrency: "PEN"))
        #expect(!PanelAccountCardLogic.showsConversion(kind: .spent, accountCurrency: "USD", defaultCurrency: "PEN"))
    }

    @Test func filterAction_onlyWhenNotFilteredAndIncluding() {
        #expect(PanelAccountCardLogic.showsFilterAction(isSelected: false, isExcludeMode: false))
        #expect(!PanelAccountCardLogic.showsFilterAction(isSelected: true, isExcludeMode: false))
        #expect(!PanelAccountCardLogic.showsFilterAction(isSelected: false, isExcludeMode: true))
        #expect(!PanelAccountCardLogic.showsFilterAction(isSelected: true, isExcludeMode: true))
    }

    @Test func systemAccounts_areNotEditable() {
        #expect(PanelAccountCardLogic.canEdit(isSystemAccount: false))
        #expect(!PanelAccountCardLogic.canEdit(isSystemAccount: true))
    }

    /// Una cuenta borrada no se lee: `isArchived` no se evalúa si ya se sabe que está muerta. La llamada va FUERA
    /// de `#expect`, que evalúa cada argumento por su cuenta para poder enseñarlo y se saltaría el diferido.
    @Test func detailIsStale_doesNotReadArchivedOfADeadAccount() {
        var readArchived = false
        func archived() -> Bool { readArchived = true; return false }

        let deleted = PanelAccountCardLogic.detailIsStale(isDeleted: true, hasContext: true, isArchived: archived())
        #expect(deleted)
        #expect(!readArchived)
        let detached = PanelAccountCardLogic.detailIsStale(isDeleted: false, hasContext: false, isArchived: archived())
        #expect(detached)
        #expect(!readArchived)
        let alive = PanelAccountCardLogic.detailIsStale(isDeleted: false, hasContext: true, isArchived: archived())
        #expect(!alive)
        #expect(readArchived)
        let archivedNow = PanelAccountCardLogic.detailIsStale(isDeleted: false, hasContext: true, isArchived: true)
        #expect(archivedNow)
    }
}

// MARK: - Vista de cuenta

@Suite("AccountDetailCalculator")
struct AccountDetailCalculatorTests {

    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return c
    }

    private static func day(_ d: Int, _ h: Int = 12, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: d, hour: h)) ?? .distantPast
    }

    /// Octubre entero, cerrado en 23:59:59 del 31 como `DetailPeriod.dateInterval`.
    private static var october: DateInterval {
        let start = day(1, 0)
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private static func entry(
        _ id: String,
        _ date: Date,
        _ amount: Double,
        type: String? = nil,
        category: String? = nil,
        isIncome: Bool? = nil
    ) -> AccountDetailCalculator.Entry {
        AccountDetailCalculator.Entry(
            id: id, date: date, amount: amount, adjustmentType: type,
            categoryKey: category, categoryName: category, categoryColorHex: nil,
            categoryIsIncome: isIncome, title: id
        )
    }

    @Test func moneyInAndOut_countTransfersAndAdjustments_butNotTheInitialBalance() {
        let entries = [
            Self.entry("inicial", Self.day(1, 9), 1000, type: AccountDetailCalculator.initialBalanceType),
            Self.entry("sueldo", Self.day(2), 3500, category: "Sueldo", isIncome: true),
            Self.entry("super", Self.day(3), -480, category: "Super", isIncome: false),
            Self.entry("transferIn", Self.day(4), 200, type: "transfer"),
            Self.entry("transferOut", Self.day(5), -300, type: "transfer"),
            Self.entry("ajuste", Self.day(6), -20, type: "adjustment"),
            Self.entry("septiembre", Self.day(30, month: 9), -999, category: "Super", isIncome: false),
        ]
        let s = AccountDetailCalculator.summary(
            entries: entries, interval: Self.october, now: Self.day(20), calendar: Self.calendar
        )
        #expect(s.moneyIn == 3700)
        #expect(s.moneyOut == 800)
    }

    /// El último punto de la curva es la suma de todo, que es el saldo de la tarjeta (`AccountBalanceCalculator`).
    @Test func series_endsAtTheCardBalance_andRunsUntilToday() {
        let entries = [
            Self.entry("antes", Self.day(15, month: 9), 1000),
            Self.entry("a", Self.day(2), -100),
            Self.entry("b", Self.day(5), 50),
        ]
        let s = AccountDetailCalculator.summary(
            entries: entries, interval: Self.october, now: Self.day(10), calendar: Self.calendar
        )
        #expect(s.series.count == 10)
        #expect(s.series.first?.balance == 1000)
        #expect(s.series[1].balance == 900)
        #expect(s.series.last?.balance == 950)
        #expect(s.series.last?.balance == entries.reduce(0) { $0 + $1.amount })
    }

    /// Un movimiento fechado en el futuro ya suma en la tarjeta, pero la curva se queda en hoy: todavía no ha pasado.
    @Test func series_stopsToday_evenWithFutureDatedEntries() {
        let entries = [Self.entry("hoy", Self.day(10), 1000), Self.entry("futuro", Self.day(15), 500)]
        let series = AccountDetailCalculator.dailyBalances(
            entries: entries, interval: Self.october, now: Self.day(10), calendar: Self.calendar
        )
        #expect(series.last?.balance == 1000)
        #expect(entries.reduce(0) { $0 + $1.amount } == 1500)
    }

    /// Medianoche exacta es del día que empieza: la trampa del `DateInterval` cerrado.
    @Test func series_midnightEntry_belongsToTheDayItStarts() {
        // El ancla del día 1 hace que la curva empiece el 1: si no, empezaría el día del único movimiento y el borde
        // de medianoche no se mediría.
        let entries = [Self.entry("ancla", Self.day(1), 0), Self.entry("medianoche", Self.day(3, 0), -40)]
        let series = AccountDetailCalculator.dailyBalances(
            entries: entries, interval: Self.october, now: Self.day(5), calendar: Self.calendar
        )
        #expect(series[1].balance == 0)
        #expect(series[2].balance == -40)
    }

    @Test func series_closedPeriod_coversEveryDay_andFuturePeriodIsEmpty() {
        let closed = AccountDetailCalculator.dailyBalances(
            entries: [], interval: Self.october, now: Self.day(15, month: 12), calendar: Self.calendar
        )
        #expect(closed.count == 31)
        let future = AccountDetailCalculator.dailyBalances(
            entries: [], interval: Self.october, now: Self.day(20, month: 9), calendar: Self.calendar
        )
        #expect(future.isEmpty)
    }

    /// Con «Todo el tiempo» la curva no arranca años antes de que existiera la cuenta.
    @Test func series_startsAtTheFirstEntry_whenItIsAfterThePeriodStart() {
        let entries = [Self.entry("a", Self.day(8), 100), Self.entry("b", Self.day(9), -30)]
        let series = AccountDetailCalculator.dailyBalances(
            entries: entries, interval: Self.october, now: Self.day(10), calendar: Self.calendar
        )
        #expect(series.first?.day == Self.calendar.startOfDay(for: Self.day(8)))
        #expect(series.map(\.balance) == [100, 70, 70])
    }

    @Test func topCategories_areExpensesOnly_sortedAndCapped() {
        let entries = [
            Self.entry("a", Self.day(2), -100, category: "Super", isIncome: false),
            Self.entry("b", Self.day(3), -50, category: "Super", isIncome: false),
            Self.entry("c", Self.day(3), -120, category: "Taxi", isIncome: false),
            Self.entry("d", Self.day(4), -30, category: "Cine", isIncome: false),
            Self.entry("e", Self.day(4), -10, category: "Café", isIncome: false),
            Self.entry("sueldo", Self.day(1), 3000, category: "Sueldo", isIncome: true),
            Self.entry("transfer", Self.day(4), -900, type: "transfer", category: "Super", isIncome: false),
            Self.entry("sinCategoria", Self.day(4), -700),
        ]
        let top = AccountDetailCalculator.topCategories(in: entries)
        #expect(top.map(\.name) == ["Super", "Taxi", "Cine"])
        #expect(top.first?.amount == 150)
    }

    @Test func latest_isNewestFirst_cappedAtFive_withoutTheInitialBalance() {
        var entries = (1...7).map { Self.entry("r\($0)", Self.day($0), -1) }
        entries.append(Self.entry("inicial", Self.day(9), 500, type: AccountDetailCalculator.initialBalanceType))
        let s = AccountDetailCalculator.summary(
            entries: entries, interval: Self.october, now: Self.day(20), calendar: Self.calendar
        )
        #expect(s.latest.map(\.id) == ["r7", "r6", "r5", "r4", "r3"])
        #expect(s.hasActivity)
    }

    @Test func dailySpending_accumulatesOnlyExpensesOfThePeriod() {
        let entries = [
            Self.entry("septiembre", Self.day(30, month: 9), -500, category: "Super", isIncome: false),
            Self.entry("a", Self.day(1), -40, category: "Super", isIncome: false),
            Self.entry("sueldo", Self.day(2), 3000, category: "Sueldo", isIncome: true),
            Self.entry("b", Self.day(3), -10, category: "Taxi", isIncome: false),
            Self.entry("transfer", Self.day(3), -900, type: "transfer"),
        ]
        let series = AccountDetailCalculator.dailySpending(
            entries: entries, interval: Self.october, now: Self.day(3), calendar: Self.calendar
        )
        #expect(series.map(\.balance) == [40, 40, 50])
    }
}

// MARK: - Puente de la hoja de filtros

@Suite("PanelSessionFilters")
@MainActor
struct PanelSessionFiltersTests {

    @Test func readsAndWritesTheSessionFilters() {
        let session = SessionState()
        let filters = PanelSessionFilters(session: session)

        filters.selectedCurrencies = [.usd]
        filters.searchText = "taxi"
        filters.amountCondition = .greaterThan(100)

        #expect(session.selectedCurrencies == [.usd])
        #expect(session.searchText == "taxi")
        #expect(session.amountCondition == .greaterThan(100))
        #expect(filters.activeFilterCount == 3)
        #expect(filters.hasActiveFilters)

        #expect(filters.hasUserFilters)

        filters.clearFilters()
        #expect(session.selectedCurrencies.isEmpty)
        #expect(session.searchText.isEmpty)
        #expect(filters.activeFilterCount == 0)
    }

    /// En «solo gastos» la app fija la naturaleza en gasto: eso no enciende el punto, un filtro del usuario sí. Sobre
    /// la regla pura: cambiar `isExpensesOnlyMode` de un `SessionState` escribe en los ajustes del simulador.
    @Test func expensesOnlyMode_forcedNature_doesNotCountAsAUserFilter() {
        #expect(PanelSessionFilters.hasUserFilters(activeFilterCount: 1, isExpensesOnlyMode: false, natures: [.expense]))
        #expect(!PanelSessionFilters.hasUserFilters(activeFilterCount: 1, isExpensesOnlyMode: true, natures: [.expense]))
        #expect(PanelSessionFilters.hasUserFilters(activeFilterCount: 2, isExpensesOnlyMode: true, natures: [.expense]))
        #expect(!PanelSessionFilters.hasUserFilters(activeFilterCount: 0, isExpensesOnlyMode: false, natures: []))
    }
}
