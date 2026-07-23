//
//  HeroMessageCacheTests.swift
//  YalaTests
//
//  Contract covered:
//   • `read()` returns nil when the key is empty or decoding fails.
//   • Write + read on the same day + same hash returns a hit.
//   • A different day (`yyyy-MM-dd`) invalidates the entry.
//   • A different hash invalidates the entry (caller compares).
//   • `contextHash` is stable for the same context across calls.
//   • `contextHash` differs when `state`, `spendingTrend` change.
//   • `contextHash` differs when crossing the 7-day bucket boundary.
//   • `contextHash` differentiates `nil` from `0` for `percentBudgetUsed`.
//   • `clear()` removes the stored entry.
//

import Foundation
import Testing

@testable import Yala

struct HeroMessageCacheTests {

    // MARK: - Fixtures

    private let calendar = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func makeContext(
        state: HeroMonthState = .neutral,
        financialScore: Int? = 50,
        percentBudgetUsed: Double? = 0.20,
        spendingTrend: HeroSpendingTrend? = .flat,
        monthName: String = "Abril",
        userName: String? = "Jur",
        daysRemaining: Int = 15,
        daysElapsed: Int = 15,
        locale: String = "es",
        income: Double = 4500,
        expense: Double = 900,
        available: Double = 3600,
        previousExpense: Double? = 800,
        expenseDelta: Double? = 100,
        topCategory: String? = nil,
        formattedTopCategoryAmount: String? = nil,
        topCategoryDeltaPercent: Double? = nil,
        topWeekday: String? = nil,
        formattedTopWeekdayAmount: String? = nil,
        monthProgress: Double = 0.5,
        expensesOnly: Bool = false
    ) -> HeroContext {
        HeroContext(
            state: state,
            financialScore: financialScore,
            percentBudgetUsed: percentBudgetUsed,
            spendingTrend: spendingTrend,
            monthName: monthName,
            userName: userName,
            daysRemaining: daysRemaining,
            daysElapsed: daysElapsed,
            locale: locale,
            income: income,
            expense: expense,
            available: available,
            formattedIncome: "S/ \(Int(income))",
            formattedExpense: "S/ \(Int(expense))",
            formattedAvailable: "S/ \(Int(available))",
            previousExpense: previousExpense,
            formattedPreviousExpense: previousExpense.map { "S/ \(Int($0))" },
            expenseDelta: expenseDelta,
            formattedExpenseDelta: expenseDelta.map { "S/ \(Int(abs($0)))" },
            topCategory: topCategory,
            formattedTopCategoryAmount: formattedTopCategoryAmount,
            topCategoryDeltaPercent: topCategoryDeltaPercent,
            topWeekday: topWeekday,
            formattedTopWeekdayAmount: formattedTopWeekdayAmount,
            monthProgress: monthProgress,
            expensesOnly: expensesOnly
        )
    }

    /// Ephemeral UserDefaults instance to keep tests hermetic — never touches
    /// the actual `.standard` defaults of the running test host.
    private func makeDefaults() -> UserDefaults {
        let suite = "HeroMessageCacheTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    // MARK: - read()

    @Test func readEmpty_returnsNil() {
        let defaults = makeDefaults()
        #expect(HeroMessageCache.read(defaults: defaults, today: date(2026, 4, 17)) == nil)
    }

    @Test func writeThenRead_sameDayAndHash_returnsHit() {
        let defaults = makeDefaults()
        let ctx = makeContext()
        let today = date(2026, 4, 17)
        let entry = HeroMessageCacheEntry(
            day: HeroMessageCache.dayString(from: today),
            hash: HeroMessageCache.contextHash(ctx),
            text: "Abril te está yendo bien, Jur."
        )
        HeroMessageCache.write(entry, defaults: defaults)

        let cached = HeroMessageCache.read(defaults: defaults, today: today)
        #expect(cached == entry)
    }

    @Test func read_differentDay_returnsNil() {
        let defaults = makeDefaults()
        let yesterday = date(2026, 4, 16)
        let today = date(2026, 4, 17)
        let entry = HeroMessageCacheEntry(
            day: HeroMessageCache.dayString(from: yesterday),
            hash: "anyhash",
            text: "Mensaje viejo"
        )
        HeroMessageCache.write(entry, defaults: defaults)

        #expect(HeroMessageCache.read(defaults: defaults, today: today) == nil)
    }

    @Test func read_differentHash_callerDetectsMiss() {
        let defaults = makeDefaults()
        let today = date(2026, 4, 17)
        let ctxA = makeContext(state: .onTrack)
        let ctxB = makeContext(state: .tight)

        let entry = HeroMessageCacheEntry(
            day: HeroMessageCache.dayString(from: today),
            hash: HeroMessageCache.contextHash(ctxA),
            text: "Mensaje para onTrack"
        )
        HeroMessageCache.write(entry, defaults: defaults)

        // read() devuelve el entry (día coincide); el caller valida hash y debe
        // descartar porque el contexto actual es otro.
        let cached = HeroMessageCache.read(defaults: defaults, today: today)
        #expect(cached != nil)
        #expect(cached?.hash != HeroMessageCache.contextHash(ctxB))
    }

    // MARK: - contextHash()

    @Test func contextHash_stable_forSameContext() {
        let ctx = makeContext()
        let a = HeroMessageCache.contextHash(ctx)
        let b = HeroMessageCache.contextHash(ctx)
        #expect(a == b)
    }

    @Test func contextHash_differs_onStateChange() {
        let base = HeroMessageCache.contextHash(makeContext(state: .neutral))
        let mutated = HeroMessageCache.contextHash(makeContext(state: .tight))
        #expect(base != mutated)
    }

    @Test func contextHash_differs_onTrendChange() {
        let base = HeroMessageCache.contextHash(makeContext(spendingTrend: .flat))
        let mutated = HeroMessageCache.contextHash(makeContext(spendingTrend: .up))
        #expect(base != mutated)
    }

    @Test func contextHash_differs_crossingDayBucket() {
        // 7 días → bucket 1; 14 días → bucket 2
        let base = HeroMessageCache.contextHash(makeContext(daysRemaining: 7))
        let mutated = HeroMessageCache.contextHash(makeContext(daysRemaining: 14))
        #expect(base != mutated)
    }

    @Test func contextHash_differs_nilVsZero_percentBudget() {
        // "na" vs "000" — explícita la diferencia entre "no hay presupuesto"
        // y "hay presupuesto pero usaste 0%"
        let withBudget = HeroMessageCache.contextHash(makeContext(percentBudgetUsed: 0))
        let noBudget = HeroMessageCache.contextHash(makeContext(percentBudgetUsed: nil))
        #expect(withBudget != noBudget)
    }

    // MARK: - contextHash() — PP2-07 enriquecimiento contextual

    @Test func contextHash_differs_onTopCategoryChange() {
        let a = HeroMessageCache.contextHash(makeContext(topCategory: "Comida"))
        let b = HeroMessageCache.contextHash(makeContext(topCategory: "Transporte"))
        #expect(a != b)
    }

    /// El delta del topCategory se bucketea al 5%. Cambios dentro del mismo
    /// bucket NO invalidan cache; cruzar el bucket SÍ.
    @Test func contextHash_stableWithinDeltaBucket_differsAcross() {
        // Mismo bucket (redondeo a 15% para ambos).
        let inside1 = HeroMessageCache.contextHash(makeContext(topCategoryDeltaPercent: 14))
        let inside2 = HeroMessageCache.contextHash(makeContext(topCategoryDeltaPercent: 16))
        #expect(inside1 == inside2)

        // Cruza bucket (15 → 25).
        let across = HeroMessageCache.contextHash(makeContext(topCategoryDeltaPercent: 25))
        #expect(inside1 != across)
    }

    @Test func contextHash_differs_onTopWeekdayChange() {
        let a = HeroMessageCache.contextHash(makeContext(topWeekday: "Lunes"))
        let b = HeroMessageCache.contextHash(makeContext(topWeekday: "Viernes"))
        #expect(a != b)
    }

    /// Cambiar de/hacia Solo Gastos invalida el cache: un mensaje generado en
    /// modo normal (que pudo citar ingresos/disponible) no debe servirse tras
    /// activar Solo Gastos. Contextos que SOLO difieren en `expensesOnly` → hash distinto.
    @Test func contextHash_differs_onExpensesOnlyChange() {
        let normal = HeroMessageCache.contextHash(makeContext(expensesOnly: false))
        let expensesOnly = HeroMessageCache.contextHash(makeContext(expensesOnly: true))
        #expect(normal != expensesOnly)
    }

    // MARK: - clear()

    @Test func clear_removesEntry() {
        let defaults = makeDefaults()
        let today = date(2026, 4, 17)
        let entry = HeroMessageCacheEntry(
            day: HeroMessageCache.dayString(from: today),
            hash: "anyhash",
            text: "Mensaje"
        )
        HeroMessageCache.write(entry, defaults: defaults)
        HeroMessageCache.clear(defaults: defaults)

        #expect(HeroMessageCache.read(defaults: defaults, today: today) == nil)
    }
}
