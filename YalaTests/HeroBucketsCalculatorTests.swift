//
//  HeroBucketsCalculatorTests.swift
//  YalaTests
//
//  Unit tests for HeroBucketsCalculator — produce los 6 valores que consume
//  el Hero del Panel (mes, mes anterior, período) en una sola pasada.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct HeroBucketsCalculatorTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func makeAccount(name: String = "Main") -> Account {
        Account(
            name: name,
            currencyCode: "USD",
            colorHex: "#6366F1",
            iconName: "creditcard",
            type: "bank"
        )
    }

    private func makeCategory(name: String, isIncome: Bool = false) -> YalaCategory {
        YalaCategory(name: name, colorHex: "#FF0000", isIncome: isIncome)
    }

    private func makeTransaction(
        amount: Double,
        date: Date,
        account: Account?,
        category: YalaCategory? = nil,
        balanceAdjustmentType: String? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: "USD",
            note: "",
            category: category,
            account: account,
            tags: [],
            amountInPreferredCurrency: amount
        )
        tx.preferredCurrencyCode = "USD"
        tx.balanceAdjustmentType = balanceAdjustmentType
        return tx
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    /// Mes calendario abril 2026.
    private var aprilInterval: DateInterval {
        DateInterval(start: date(2026, 4, 1), end: date(2026, 5, 1))
    }

    /// Mes calendario marzo 2026.
    private var marchInterval: DateInterval {
        DateInterval(start: date(2026, 3, 1), end: date(2026, 4, 1))
    }

    /// Última semana de abril (período distinto del mes).
    private var lastWeekInterval: DateInterval {
        DateInterval(start: date(2026, 4, 23), end: date(2026, 4, 30))
    }

    // MARK: - Empty / no-op

    @Test func calculate_emptyTransactions_returnsZeroBuckets() {
        let result = HeroBucketsCalculator.calculate(
            transactions: [],
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: aprilInterval,
            eligibleAccountIDs: []
        )

        #expect(result.monthIncome == 0)
        #expect(result.monthExpense == 0)
        #expect(result.prevExpense == 0)
        #expect(result.prevHasAnyTx == false)
        #expect(result.periodIncome == 0)
        #expect(result.periodExpense == 0)
        #expect(result.periodPrevExpense == 0)
    }

    // MARK: - Filtro de cuenta — núcleo del bug p20-12

    /// Caso central: las transacciones de cuentas NO elegibles (excluidas
    /// de estadísticas o no seleccionadas) NO deben sumar en NINGÚN bucket.
    @Test func calculate_excludesAllBucketsForIneligibleAccounts() {
        let kept = makeAccount(name: "Kept")
        let excluded = makeAccount(name: "Excluded")
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")

        let txs = [
            // Mes actual (abril): kept gasta 100, excluded gasta 999.
            makeTransaction(amount: -100, date: date(2026, 4, 5), account: kept, category: food),
            makeTransaction(amount: -999, date: date(2026, 4, 5), account: excluded, category: food),
            // Mes anterior (marzo): kept gasta 200, excluded gasta 888.
            makeTransaction(amount: -200, date: date(2026, 3, 10), account: kept, category: food),
            makeTransaction(amount: -888, date: date(2026, 3, 10), account: excluded, category: food),
            // Última semana (abril 25): kept gasta 50, excluded gasta 700.
            makeTransaction(amount: -50, date: date(2026, 4, 25), account: kept, category: food),
            makeTransaction(amount: -700, date: date(2026, 4, 25), account: excluded, category: food),
            // Ingresos abril: kept 1000, excluded 5000.
            makeTransaction(amount: 1000, date: date(2026, 4, 1), account: kept, category: salary),
            makeTransaction(amount: 5000, date: date(2026, 4, 1), account: excluded, category: salary),
        ]

        let result = HeroBucketsCalculator.calculate(
            transactions: txs,
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: lastWeekInterval,
            eligibleAccountIDs: [kept.persistentModelID]
        )

        // Mes (kept): 100 (food del 5) + 50 (food del 25) = 150 expense, 1000 income.
        #expect(result.monthIncome == 1000)
        #expect(result.monthExpense == 150)
        // Mes anterior (kept): 200 expense.
        #expect(result.prevExpense == 200)
        #expect(result.prevHasAnyTx == true)
        // Período = última semana abril (kept): solo el del 25 = 50 expense.
        #expect(result.periodIncome == 0)
        #expect(result.periodExpense == 50)
    }

    /// Sin filtro de cuenta (todas elegibles): suma agregado total.
    @Test func calculate_allAccountsEligible_sumsAllBuckets() {
        let a = makeAccount(name: "A")
        let b = makeAccount(name: "B")
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")

        let txs = [
            makeTransaction(amount: 1500, date: date(2026, 4, 1), account: a, category: salary),
            makeTransaction(amount: -300, date: date(2026, 4, 10), account: b, category: food),
            makeTransaction(amount: -250, date: date(2026, 3, 5), account: a, category: food),
        ]

        let result = HeroBucketsCalculator.calculate(
            transactions: txs,
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: aprilInterval,
            eligibleAccountIDs: [a.persistentModelID, b.persistentModelID]
        )

        #expect(result.monthIncome == 1500)
        #expect(result.monthExpense == 300)
        #expect(result.prevExpense == 250)
        #expect(result.prevHasAnyTx == true)
        #expect(result.periodIncome == 1500)
        #expect(result.periodExpense == 300)
    }

    // MARK: - Independencia entre buckets

    /// Cuando `period == month`, los buckets de mes y período tienen los
    /// mismos valores — verifica que la card "Disponible" coincide con los
    /// pills del mes cuando el usuario está en "Este mes".
    @Test func calculate_periodEqualsMonth_periodBucketsMatchMonthBuckets() {
        let account = makeAccount()
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")

        let txs = [
            makeTransaction(amount: 2000, date: date(2026, 4, 1), account: account, category: salary),
            makeTransaction(amount: -400, date: date(2026, 4, 15), account: account, category: food),
        ]

        let result = HeroBucketsCalculator.calculate(
            transactions: txs,
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: aprilInterval,
            eligibleAccountIDs: [account.persistentModelID]
        )

        #expect(result.monthIncome == result.periodIncome)
        #expect(result.monthExpense == result.periodExpense)
        #expect(result.monthIncome == 2000)
        #expect(result.monthExpense == 400)
    }

    /// Cuando `period ⊂ month`, una transacción dentro del período también
    /// suma en mes (buckets independientes, no excluyentes).
    @Test func calculate_periodSubsetOfMonth_transactionCountsInBoth() {
        let account = makeAccount()
        let food = makeCategory(name: "Food")

        let txInWeek = makeTransaction(amount: -120, date: date(2026, 4, 25), account: account, category: food)
        let txOutsideWeek = makeTransaction(amount: -80, date: date(2026, 4, 5), account: account, category: food)

        let result = HeroBucketsCalculator.calculate(
            transactions: [txInWeek, txOutsideWeek],
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: lastWeekInterval,
            eligibleAccountIDs: [account.persistentModelID]
        )

        // Mes incluye ambas (200), período solo la del 25 (120).
        #expect(result.monthExpense == 200)
        #expect(result.periodExpense == 120)
    }

    // MARK: - Guards y exclusiones

    /// Balance adjustments NO suman en ningún bucket.
    @Test func calculate_excludesBalanceAdjustments() {
        let account = makeAccount()
        let food = makeCategory(name: "Food")

        let normal = makeTransaction(amount: -200, date: date(2026, 4, 5), account: account, category: food)
        let adjustment = makeTransaction(
            amount: -9999, date: date(2026, 4, 5), account: account, category: food,
            balanceAdjustmentType: "manual"
        )

        let result = HeroBucketsCalculator.calculate(
            transactions: [normal, adjustment],
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: aprilInterval,
            eligibleAccountIDs: [account.persistentModelID]
        )

        #expect(result.monthExpense == 200)
        #expect(result.periodExpense == 200)
    }

    /// Transacciones huérfanas (sin cuenta) se excluyen siempre.
    @Test func calculate_excludesTransactionsWithoutAccount() {
        let food = makeCategory(name: "Food")
        let orphan = makeTransaction(amount: -300, date: date(2026, 4, 5), account: nil, category: food)

        let result = HeroBucketsCalculator.calculate(
            transactions: [orphan],
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: aprilInterval,
            eligibleAccountIDs: []
        )

        #expect(result.monthExpense == 0)
        #expect(result.periodExpense == 0)
    }

    /// Mes anterior solo cuenta egresos (`prevExpense`) — los ingresos del
    /// mes anterior no se exponen porque el Hero solo usa el delta de gasto
    /// para el trend "vs mes anterior".
    @Test func calculate_prevMonthOnlyTracksExpense() {
        let account = makeAccount()
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")

        let prevIncome = makeTransaction(amount: 9999, date: date(2026, 3, 15), account: account, category: salary)
        let prevExpense = makeTransaction(amount: -500, date: date(2026, 3, 15), account: account, category: food)

        let result = HeroBucketsCalculator.calculate(
            transactions: [prevIncome, prevExpense],
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: aprilInterval,
            eligibleAccountIDs: [account.persistentModelID]
        )

        #expect(result.prevExpense == 500)
        #expect(result.prevHasAnyTx == true)
    }

    /// `prevHasAnyTx` se activa con cualquier tx en mes anterior (income o
    /// expense), no solo egresos — diferencia entre "no había nada" y
    /// "había ingresos pero cero gastos".
    @Test func calculate_prevHasAnyTx_trueWhenIncomeOnly() {
        let account = makeAccount()
        let salary = makeCategory(name: "Salary", isIncome: true)

        let prevIncomeOnly = makeTransaction(amount: 1000, date: date(2026, 3, 15), account: account, category: salary)

        let result = HeroBucketsCalculator.calculate(
            transactions: [prevIncomeOnly],
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: aprilInterval,
            eligibleAccountIDs: [account.persistentModelID]
        )

        #expect(result.prevExpense == 0)
        #expect(result.prevHasAnyTx == true)
    }

    // MARK: - Solo Gastos: gasto del período anterior comparable

    /// Ventana previa del período (`.lastWeek`-1): suma SOLO gasto, mismo scope
    /// que `periodExpense` (cuenta elegible, sin income, sin balance adjustment).
    @Test func calculate_periodPrevExpense_sumsOnlyExpenseInPrevWindow() {
        let kept = makeAccount(name: "Kept")
        let excluded = makeAccount(name: "Excluded")
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")

        // Período actual = última semana de abril (23-30).
        // Ventana previa = la semana anterior (16-23).
        let prevWeek = DateInterval(start: date(2026, 4, 16), end: date(2026, 4, 23))

        let txs = [
            // En la ventana previa: gasto 80 (kept) cuenta; income y balance-adj no.
            makeTransaction(amount: -80, date: date(2026, 4, 18), account: kept, category: food),
            makeTransaction(amount: 500, date: date(2026, 4, 19), account: kept, category: salary),
            makeTransaction(amount: -999, date: date(2026, 4, 18), account: excluded, category: food),
            makeTransaction(amount: -111, date: date(2026, 4, 18), account: kept, category: food, balanceAdjustmentType: "manual"),
            // En el período actual (25): gasto 30 → periodExpense, NO periodPrev.
            makeTransaction(amount: -30, date: date(2026, 4, 25), account: kept, category: food),
        ]

        let result = HeroBucketsCalculator.calculate(
            transactions: txs,
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: lastWeekInterval,
            periodPrevInterval: prevWeek,
            eligibleAccountIDs: [kept.persistentModelID]
        )

        #expect(result.periodExpense == 30)
        #expect(result.periodPrevExpense == 80)
    }

    /// Sin ventana previa pedida (`nil`) → `periodPrevExpense == 0` aunque haya
    /// gasto en fechas pasadas.
    @Test func calculate_periodPrevInterval_nil_periodPrevExpenseZero() {
        let account = makeAccount()
        let food = makeCategory(name: "Food")

        let txs = [
            makeTransaction(amount: -80, date: date(2026, 4, 18), account: account, category: food),
        ]

        let result = HeroBucketsCalculator.calculate(
            transactions: txs,
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: lastWeekInterval,
            periodPrevInterval: nil,
            eligibleAccountIDs: [account.persistentModelID]
        )

        #expect(result.periodPrevExpense == 0)
    }

    /// Borde compartido: `DateInterval` es CERRADO en ambos extremos. Si la
    /// ventana previa cierra EXACTAMENTE en `periodInterval.start` (el caso de
    /// `.thisMonth`, cuya ventana previa alineada no resta 1s), una TX fechada a
    /// medianoche de ese instante NO debe doble-contarse: cuenta solo en el
    /// período actual, nunca en el previo. (Mutante: sin el guard
    /// `!periodInterval.contains`, `periodPrevExpense` sería 500.)
    @Test func calculate_periodPrevExpense_excludesSharedBoundaryTx() {
        let account = makeAccount()
        let food = makeCategory(name: "Food")

        // marchInterval.end == aprilInterval.start == 1 abr 00:00 (instante compartido).
        let boundaryTx = makeTransaction(amount: -500, date: date(2026, 4, 1), account: account, category: food)

        let result = HeroBucketsCalculator.calculate(
            transactions: [boundaryTx],
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: aprilInterval,      // [1 abr, 1 may]
            periodPrevInterval: marchInterval,  // [1 mar, 1 abr] — end == periodInterval.start
            eligibleAccountIDs: [account.persistentModelID]
        )

        #expect(result.periodExpense == 500)
        #expect(result.periodPrevExpense == 0)
    }

    // MARK: - periodPreviousInterval (glue MTD-alineada)

    /// `.allTime` no tiene previo acotado → `nil` (sin comparación).
    @Test func periodPreviousInterval_allTime_returnsNil() {
        let now = date(2026, 4, 15)
        let current = DetailPeriod.allTime.dateInterval(now: now)
        let result = HeroBucketsCalculator.periodPreviousInterval(
            period: .allTime, currentInterval: current, now: now
        )
        #expect(result == nil)
    }

    /// `.thisMonth` es asimétrico parcial-vs-completo (actual = MTD parcial;
    /// previo = mes COMPLETO), así que el previo se trunca al día equivalente.
    /// NO es el único caso: `.thisWeek` y `.thisYear` también pasan por el gate
    /// (`DateAlignmentHelper.aggregatePreviousNeedsAlignment`) — ver el test de
    /// `.thisWeek` justo debajo. Verifica que arranca en el inicio del mes previo
    /// pero TERMINA antes del fin del mes previo completo.
    @Test func periodPreviousInterval_thisMonth_truncatesToEquivalentDay() {
        let now = date(2026, 4, 15)
        let current = DetailPeriod.thisMonth.dateInterval(now: now)
        let fullPrev = PreviousPeriodHelper.previousInterval(for: .thisMonth, mode: .month, now: now)

        let result = HeroBucketsCalculator.periodPreviousInterval(
            period: .thisMonth, currentInterval: current, now: now
        )

        #expect(result != nil)
        #expect(result?.start == fullPrev.start)   // inicio del mes previo
        #expect((result?.end ?? .distantFuture) < fullPrev.end)  // truncado (MTD)
    }

    /// `.thisWeek` TAMBIÉN es asimétrico parcial-vs-completo: el actual va del
    /// inicio de semana a hoy (parcial) mientras `PreviousPeriodHelper` devuelve la
    /// semana calendario anterior ENTERA, así que el previo se trunca al weekday
    /// equivalente (WTD-vs-WTD). Lo invirtió `f6d4101d` (2026-08-17), que en el
    /// mismo commit sacó `.thisWeek` de la rama trailing de `.last7Days` y lo metió
    /// en el gate; antes de esa fecha el previo SÍ era una ventana trailing de igual
    /// duración y alinear era no-op de verdad. Sin el truncado, un miércoles se
    /// compararían 3 días contra 7 y el chip del hero mostraría un −57 % fantasma.
    ///
    /// La aserción que de verdad guarda la doctrina es la PARIDAD DE DURACIÓN: no
    /// depende del `firstWeekday` de la máquina (`calendar` es `.current`) ni del
    /// `now` elegido. Un `#expect(result != fullPrev)` no protegería de nada.
    @Test func periodPreviousInterval_thisWeek_truncatesToEquivalentWeekday() {
        let now = date(2026, 4, 15)
        let current = DetailPeriod.thisWeek.dateInterval(now: now)
        let fullPrev = PreviousPeriodHelper.previousInterval(for: .thisWeek, mode: .month, now: now)

        let result = HeroBucketsCalculator.periodPreviousInterval(
            period: .thisWeek, currentInterval: current, now: now
        )

        #expect(result != nil)
        #expect(result?.start == fullPrev.start)                 // inicio de la semana previa
        #expect((result?.end ?? .distantFuture) < fullPrev.end)  // truncado (WTD)
        // El invariante: la ventana previa mide lo mismo que la actual. Tolerancia
        // de 1 h por si el calendario del runner tiene horario de verano.
        let deltaHoras = abs((result?.duration ?? 0) - current.duration) / 3600
        #expect(deltaHoras <= 1)
    }
}
