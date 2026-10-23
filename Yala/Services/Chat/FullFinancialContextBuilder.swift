//
//  FullFinancialContextBuilder.swift
//  Yala
//
//  Builds the FullFinancialContext from SwiftData. Reuses existing calculators
//  to avoid duplicating financial logic. Caches the result for 60s (per builder
//  instance) to avoid recomputing across rapid successive chat questions.
//
//  Edge cases handled (per plan):
//   - 0 transacciones → shape válido con arrays vacíos
//   - tx.category == nil → bucket `uncategorized` explícito
//   - account.excludeFromStatistics → excluido + listado en metadata. Archivar NO decide la suma
//     (decisión de Jürgen, 2026-10-03, `.claude/rules/session-filters.md`): una cuenta archivada
//     que el usuario volvió a incluir suma aquí igual que en el Panel. Las cuentas que salen en
//     `balances` son las del conteo del Panel (`PanelTotalAccountsLogic.countableAccounts`).
//   - «Grupos en el total» apagado → `balances.total_balance` deja fuera las cuentas de Grupos con la misma regla
//     que el Panel (`PanelTotalAccountsLogic.accountsForTotal`); siguen listadas en `balances.accounts`
//   - «Incluir gastos de grupo en estadísticas» apagado → los movimientos de grupo (`splitExpenseID` o
//     `splitSettlementID`) salen de periodos, categorías, comercios, patrones, etiquetas, destacados y
//     anomalías con `BridgedTransactionFilter`, como el Panel, Estadísticas y las sugerencias del chat.
//     Presupuestos y saldos no lo siguen, igual que en la app: el presupuesto tiene su propio
//     «incluir gastos compartidos» y el saldo son montos reales
//   - comparar el mes en curso → `periods.last_month_to_date` y `total_last_month_to_date`: el
//     mes pasado hasta el día equivalente a hoy, la misma alineación que el hero de Tendencias
//   - tx.balanceAdjustmentType != nil → filtrado
//   - fecha futura → filtrado, con el corte del saldo de hoy (`LiveBalanceCalculator.TodayCutoff`, por DÍA): un gasto de
//     hoy fechado a las 12:00 (foto, voz) cuenta desde por la mañana, como en el Panel (card `…qrv9`, 2026-10-20)
//   - multi-currency → `chatAmount` (guardado si su divisa principal es la vigente; si no, reconvertido)
//     y la pata real de un gasto de grupo con `CashFlowCalculator.resolvedAmount`; guard isFinite
//   - budget.limitAmount == 0 → status="no_limit", usage_pct=null
//   - los SALDOS salen del libro entero, como en el Panel; los totales, de los últimos 13 meses (card `…646z`,
//     2026-10-20: con la ventana, un saldo inicial de hace más de 13 meses dejaba el saldo de Yala IA a la mitad)
//

import Foundation
import SwiftData

@MainActor
final class FullFinancialContextBuilder {

    // MARK: - Cache (60s TTL)

    private struct CacheEntry {
        let context: FullFinancialContext
        let timestamp: Date
        let includedAnomalies: Bool
        /// El ajuste con el que se calculó el total: si cambia, la caché no vale.
        let includedGroupsInTotal: Bool
        /// El interruptor de Estadísticas con el que se calcularon los movimientos: si cambia, tampoco.
        let includedGroupTransactionsInStats: Bool
    }

    private var cache: CacheEntry?
    private static let ttlSeconds: TimeInterval = 60

    // MARK: - Build

    /// Build the context. If cache is fresh (<60s) and matches the anomaly request,
    /// returns cached. Otherwise rebuilds.
    func build(
        modelContext: ModelContext,
        currencyCode: String,
        currencyDisplay: String,
        converter: CurrencyConverting,
        language: String,
        country: String,
        includeAnomalies: Bool,
        includeGroupsInTotal: Bool,
        includeGroupTransactionsInStats: Bool,
        now: Date = .now
    ) -> FullFinancialContext {
        let calendar = Calendar.current
        let fetchStart = calendar.date(byAdding: .month, value: -13, to: now) ?? now
        let cutoff = LiveBalanceCalculator.TodayCutoff(asOf: now, calendar: calendar)
        // El libro ENTERO, para los saldos (los suma el Panel así: un saldo inicial de hace dos años cuenta). Lo que se
        // resume para el modelo sigue siendo la ventana de 13 meses, hasta el final de HOY.
        let ledger = fetchAllTransactions(modelContext)
        let transactions = ledger.filter { $0.date >= fetchStart && cutoff.counts($0.date) }
        // Proyección de gastos de grupo bridgeados → "mi parte" (neto). Se construye del set MÁS
        // AMPLIO (raw fetch, con AMBAS hermanas del bridge antes de filtros por cuenta/tag/eligibilidad).
        let adjustment = GroupBridgeStatsAdjustment.build(from: transactions, context: modelContext)
        return buildFromArrays(
            transactions: transactions,
            balanceLedger: ledger,
            budgets: fetchBudgets(modelContext),
            accounts: fetchAccounts(modelContext),
            tags: fetchTags(modelContext),
            scheduledPayments: fetchScheduledPayments(modelContext),
            currencyCode: currencyCode,
            currencyDisplay: currencyDisplay,
            converter: converter,
            language: language,
            country: country,
            includeAnomalies: includeAnomalies,
            includeGroupsInTotal: includeGroupsInTotal,
            includeGroupTransactionsInStats: includeGroupTransactionsInStats,
            adjustment: adjustment,
            now: now
        )
    }

    /// Pure build entry point — operates on in-memory arrays so tests can avoid
    /// instantiating a ModelContext (whose CloudKit container has a known race
    /// condition in suite mode). Production callers use `build(modelContext:...)`
    /// which fetches and delegates here.
    ///
    /// `includeGroupsInTotal` es el ajuste «Grupos en el total» del Panel (`AppPreferences.includeGroupsInPanelTotal`):
    /// lo pasa quien construye el contexto. Su default `true` es el default del ajuste.
    ///
    /// `includeGroupTransactionsInStats` es «Incluir gastos de grupo en estadísticas»
    /// (`AppPreferences.includeGroupTransactionsInStats`), el interruptor que siguen el Panel y Estadísticas.
    /// También lo pasa quien construye el contexto, y su default `true` también es el del ajuste.
    ///
    /// `balanceLedger` son TODOS los movimientos, para los saldos. `nil` = los de `transactions` (los tests que ya pasan
    /// el libro entero).
    func buildFromArrays(
        transactions: [TransactionItem],
        balanceLedger: [TransactionItem]? = nil,
        budgets: [Budget],
        accounts: [Account],
        tags: [Tag],
        scheduledPayments: [ScheduledPayment],
        currencyCode: String,
        currencyDisplay: String,
        converter: CurrencyConverting,
        language: String,
        country: String,
        includeAnomalies: Bool,
        includeGroupsInTotal: Bool = true,
        includeGroupTransactionsInStats: Bool = true,
        adjustment: GroupBridgeStatsAdjustment = .none,
        now: Date = .now
    ) -> FullFinancialContext {
        if let entry = cache,
           now.timeIntervalSince(entry.timestamp) < Self.ttlSeconds,
           entry.includedGroupsInTotal == includeGroupsInTotal,
           entry.includedGroupTransactionsInStats == includeGroupTransactionsInStats,
           includeAnomalies == false || entry.includedAnomalies {
            return entry.context
        }

        let calendar = Calendar.current
        let allTx = transactions
        let allBudgets = budgets
        let allAccounts = accounts
        let allTags = tags
        let scheduledPayments = scheduledPayments
        // Solo «Excluir de las estadísticas» decide si una cuenta suma, igual que en el Panel
        // (`computeEligibleAccounts`). Archivar no: el usuario puede volver a incluir una archivada.
        let excludedAccountNames = allAccounts
            .filter { $0.excludeFromStatistics }
            .map(\.name)

        // Filter excluded/balance-adjustment/future TX once. «Futuro» es después de HOY, no de este instante: la foto y la
        // voz fechan a las 12:00 y el Panel las cuenta desde por la mañana (card `…qrv9`).
        let cutoff = LiveBalanceCalculator.TodayCutoff(asOf: now, calendar: calendar)
        let eligibleTx = allTx.filter { tx in
            tx.balanceAdjustmentType == nil
                && tx.account?.excludeFromStatistics != true
                && cutoff.counts(tx.date)
        }
        // Lo que cuentan las estadísticas: con el interruptor de grupos apagado, sin movimientos de grupo
        // (pata real y pata de préstamo), con la misma regla que el Panel. Los presupuestos siguen con
        // `eligibleTx`: su pantalla no mira este interruptor sino el «incluir gastos compartidos» de cada uno.
        let statsTx = eligibleTx.filter { tx in
            BridgedTransactionFilter.shouldInclude(
                splitExpenseID: tx.splitExpenseID,
                splitSettlementID: tx.splitSettlementID,
                includeGroupsToggle: includeGroupTransactionsInStats
            )
        }

        let intervals = buildIntervals(now: now, calendar: calendar, endOfToday: cutoff.startOfTomorrow.addingTimeInterval(-1))
        // `!= true` keeps tx with category=nil in the expense bucket → uncategorized
        // bucket sees them. Income tx (isIncome==true) are excluded.
        let currentMonthExpenseTx = statsTx.filter {
            intervals.currentMonth.contains($0.date) && $0.category?.isIncome != true
        }

        let metadata = buildMetadata(
            now: now,
            currency: currencyCode,
            currencyDisplay: currencyDisplay,
            language: language,
            country: country,
            excludedAccountNames: excludedAccountNames,
            calendar: calendar
        )

        let balances = buildBalances(
            accounts: PanelTotalAccountsLogic.countableAccounts(allAccounts),
            lineRoles: allAccounts.lineRoles,
            includeGroupsInTotal: includeGroupsInTotal,
            allRawTx: balanceLedger ?? allTx,
            preferredCurrency: currencyCode,
            converter: converter,
            now: now
        )

        let periods = buildPeriods(
            tx: statsTx,
            intervals: intervals,
            currencyCode: currencyCode,
            converter: converter,
            now: now,
            calendar: calendar,
            adjustment: adjustment
        )

        let categories = buildCategories(
            tx: statsTx,
            intervals: intervals,
            currencyCode: currencyCode,
            converter: converter,
            adjustment: adjustment
        )

        let incomeCategories = buildIncomeCategories(
            tx: statsTx,
            intervals: intervals,
            currencyCode: currencyCode,
            converter: converter,
            adjustment: adjustment
        )

        let monthlyHistory = buildMonthlyHistory(
            tx: statsTx,
            monthStart: intervals.currentMonth.start,
            currencyCode: currencyCode,
            converter: converter,
            calendar: calendar,
            adjustment: adjustment
        )

        let uncategorized = buildUncategorized(
            tx: currentMonthExpenseTx,
            converter: converter,
            currencyCode: currencyCode,
            adjustment: adjustment
        )

        let merchantsTop20 = buildMerchantsTop20(
            tx: statsTx,
            intervals: intervals,
            currencyCode: currencyCode,
            converter: converter,
            adjustment: adjustment
        )

        let budgets = buildBudgets(
            allBudgets: allBudgets,
            allTx: eligibleTx,
            converter: converter,
            now: now,
            calendar: calendar,
            adjustment: adjustment
        )

        let recurring = buildRecurring(
            scheduledPayments: scheduledPayments,
            currencyCode: currencyCode,
            converter: converter,
            now: now,
            calendar: calendar,
            currentMonthInterval: intervals.currentMonth
        )

        let patterns = buildPatterns(
            tx: statsTx,
            currencyCode: currencyCode,
            converter: converter,
            now: now,
            endOfToday: cutoff.startOfTomorrow.addingTimeInterval(-1),
            calendar: calendar,
            adjustment: adjustment
        )

        let tagsTop10 = buildTagsTop10(
            tx: currentMonthExpenseTx,
            allTags: allTags,
            currencyCode: currencyCode,
            converter: converter,
            currentMonthInterval: intervals.currentMonth,
            adjustment: adjustment
        )

        let topTxBySubcategory = buildTopTxBySubcategory(
            tx: currentMonthExpenseTx,
            currencyCode: currencyCode,
            converter: converter,
            adjustment: adjustment
        )

        let anomalies: [AnomalyEntry]? = includeAnomalies
            ? AnomalyDetectionCalculator.detect(
                allTransactions: statsTx,
                periodTransactions: currentMonthExpenseTx,
                interval: intervals.currentMonth,
                currencyCode: currencyCode,
                adjustment: adjustment,
                converter: converter
            )
            : nil

        let context = FullFinancialContext(
            metadata: metadata,
            balances: balances,
            periods: periods,
            categories: categories,
            uncategorized: uncategorized,
            merchantsTop20: merchantsTop20,
            budgets: budgets,
            recurring: recurring,
            patterns: patterns,
            tagsTop10: tagsTop10,
            topTxBySubcategory: topTxBySubcategory,
            anomalies: anomalies,
            monthlyHistory: monthlyHistory,
            incomeCategories: incomeCategories,
            fxRates: buildFxRates(
                accounts: PanelTotalAccountsLogic.countableAccounts(allAccounts),
                preferredCurrency: currencyCode,
                converter: converter
            ),
            monthlyHistorySummary: Self.historySummary(
                monthlyHistory, currentMonth: periods.currentMonth, now: now, calendar: calendar),
            monthOutlook: Self.monthOutlook(
                budgets: budgets,
                recurring: recurring,
                currencyCode: currencyCode,
                now: now,
                monthEnd: (calendar.dateInterval(of: .month, for: now)?.end ?? now).addingTimeInterval(-1),
                calendar: calendar
            )
        )

        cache = CacheEntry(
            context: context,
            timestamp: now,
            includedAnomalies: includeAnomalies,
            includedGroupsInTotal: includeGroupsInTotal,
            includedGroupTransactionsInStats: includeGroupTransactionsInStats
        )
        return context
    }

    /// Manually invalidate cache. Not normally needed (TTL handles staleness) but
    /// useful for tests.
    func invalidateCache() {
        cache = nil
    }

    // MARK: - Intervals

    private struct Intervals {
        let today: DateInterval
        let currentWeek: DateInterval
        let lastWeek: DateInterval
        let last4Weeks: [DateInterval] // index 0 = oldest, 3 = current
        let currentMonth: DateInterval
        let lastMonth: DateInterval
        /// El mes pasado hasta el final del día equivalente a hoy (MTD contra MTD).
        let lastMonthToDate: DateInterval
        let twoMonthsAgo: DateInterval
        let threeMonthsAgo: DateInterval
        let currentYear: DateInterval
        let last30Days: DateInterval
        let yesterday: DateInterval
        let sameMonthLastYear: DateInterval
    }

    /// Los períodos EN CURSO cierran al final de hoy (`endOfToday`), no en este instante: un gasto de hoy fechado a las
    /// 12:00 cuenta desde por la mañana (card `…qrv9`).
    private func buildIntervals(now: Date, calendar: Calendar, endOfToday: Date) -> Intervals {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        let startOfTodayMinusOneSecond = calendar.date(byAdding: .second, value: -1, to: startOfToday) ?? startOfToday
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
        let prevWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? startOfToday
        let weekStartMinusOneSecond = calendar.date(byAdding: .second, value: -1, to: weekStart) ?? weekStart
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday
        let monthStartMinusOneSecond = calendar.date(byAdding: .second, value: -1, to: monthStart) ?? monthStart
        let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart) ?? startOfToday
        let lastMonthStartMinusOneSecond = calendar.date(byAdding: .second, value: -1, to: lastMonthStart) ?? lastMonthStart
        let twoMonthsAgoStart = calendar.date(byAdding: .month, value: -2, to: monthStart) ?? startOfToday
        let twoMonthsAgoStartMinusOneSecond = calendar.date(byAdding: .second, value: -1, to: twoMonthsAgoStart) ?? twoMonthsAgoStart
        let threeMonthsAgoStart = calendar.date(byAdding: .month, value: -3, to: monthStart) ?? startOfToday
        let yearStart = calendar.dateInterval(of: .year, for: now)?.start ?? startOfToday
        let last30Start = calendar.date(byAdding: .day, value: -30, to: now) ?? startOfToday

        // DateInterval es cerrado en ambos extremos — restamos 1s al `end` de cada
        // bucket que coincide exactamente con el `start` del bucket adyacente, o
        // ese instante se cuenta dos veces (ver CLAUDE.md, gotcha DateInterval boundary).
        var weeks: [DateInterval] = []
        for i in stride(from: 3, through: 0, by: -1) {
            if let start = calendar.date(byAdding: .weekOfYear, value: -i, to: weekStart),
               let rawEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: start) {
                let end = calendar.date(byAdding: .second, value: -1, to: rawEnd) ?? rawEnd
                weeks.append(DateInterval(start: start, end: end))
            }
        }

        let lastMonth = DateInterval(start: lastMonthStart, end: monthStartMinusOneSecond)

        return Intervals(
            today: DateInterval(start: startOfToday, end: endOfToday),
            currentWeek: DateInterval(start: weekStart, end: endOfToday),
            lastWeek: DateInterval(start: prevWeekStart, end: weekStartMinusOneSecond),
            last4Weeks: weeks,
            currentMonth: DateInterval(start: monthStart, end: endOfToday),
            lastMonth: lastMonth,
            lastMonthToDate: Self.lastMonthToDateInterval(
                monthStart: monthStart,
                lastMonth: lastMonth,
                now: now,
                calendar: calendar
            ),
            twoMonthsAgo: DateInterval(start: twoMonthsAgoStart, end: lastMonthStartMinusOneSecond),
            threeMonthsAgo: DateInterval(start: threeMonthsAgoStart, end: twoMonthsAgoStartMinusOneSecond),
            currentYear: DateInterval(start: yearStart, end: endOfToday),
            last30Days: DateInterval(start: last30Start, end: endOfToday),
            yesterday: DateInterval(start: startOfYesterday, end: startOfTodayMinusOneSecond),
            sameMonthLastYear: {
                let start = calendar.date(byAdding: .month, value: -12, to: monthStart) ?? monthStart
                let next = calendar.date(byAdding: .month, value: 1, to: start) ?? start
                return DateInterval(start: start, end: calendar.date(byAdding: .second, value: -1, to: next) ?? next)
            }()
        )
    }

    /// El mes pasado hasta el final del día equivalente a hoy: lo que hay que poner al lado del mes
    /// en curso para que «¿gasto más que el mes pasado?» compare lo mismo con lo mismo.
    ///
    /// Reusa `DateAlignmentHelper.alignedPreviousInterval`, la alineación del hero de Tendencias
    /// (`InsightsCalculator`): día del mes contra día del mes, el día equivalente ENTERO, y el clamp al
    /// final del mes pasado cuando hoy no existe en él (31 frente a un mes de 30, 29-31 frente a
    /// febrero), que da el mes pasado completo. El intervalo actual se le pasa hasta el inicio de
    /// mañana, como en el hero: con `now` justo a medianoche su guard daría el mes entero.
    ///
    /// **El -1 s lo pone el helper desde el 2026-10-22** (ticket `aligned-previous-interval-counts-the-next-midnight`):
    /// cierra el día equivalente en 23:59:59 y deja el clamp al final del mes pasado como llega. Hasta ese día lo
    /// restaba esta función por su cuenta; restarlo aquí también le quitaría un segundo real al día equivalente.
    static func lastMonthToDateInterval(
        monthStart: Date,
        lastMonth: DateInterval,
        now: Date,
        calendar: Calendar
    ) -> DateInterval {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        return DateAlignmentHelper.alignedPreviousInterval(
            currentInterval: DateInterval(start: monthStart, end: startOfTomorrow),
            previousInterval: lastMonth,
            asOf: now,
            period: .thisMonth,
            comparisonMode: .month,
            calendar: calendar
        )
    }

    /// El mes más caro y el más barato de la historia, y las medias. `nil` sin historia.
    static func historySummary(
        _ months: [FullFinancialContext.MonthSummary],
        currentMonth: FullFinancialContext.PeriodSummary,
        now: Date,
        calendar: Calendar
    ) -> FullFinancialContext.MonthlyHistorySummary? {
        guard let highest = months.max(by: { $0.expense < $1.expense }),
              let lowest = months.min(by: { $0.expense < $1.expense }) else { return nil }
        let count = Double(months.count)
        // Por año natural, con el mes en curso dentro (el año en curso lleva hasta hoy).
        var years: [String: (months: Int, income: Double, expense: Double)] = [:]
        for month in months {
            let year = String(month.month.prefix(4))
            years[year, default: (0, 0, 0)].months += 1
            years[year, default: (0, 0, 0)].income += month.income
            years[year, default: (0, 0, 0)].expense += month.expense
        }
        let currentYear = String(calendar.component(.year, from: now))
        years[currentYear, default: (0, 0, 0)].months += 1
        years[currentYear, default: (0, 0, 0)].income += currentMonth.income
        years[currentYear, default: (0, 0, 0)].expense += currentMonth.expense
        let byYear = years.keys.sorted(by: >).compactMap { year -> FullFinancialContext.YearTotal? in
            guard let totals = years[year] else { return nil }
            return FullFinancialContext.YearTotal(
                year: year, months: totals.months, income: cents(totals.income), expense: cents(totals.expense))
        }
        return FullFinancialContext.MonthlyHistorySummary(
            highestExpenseMonth: highest.month,
            highestExpense: highest.expense,
            lowestExpenseMonth: lowest.month,
            lowestExpense: lowest.expense,
            averageExpense: cents(months.reduce(0) { $0 + $1.expense } / count),
            averageIncome: cents(months.reduce(0) { $0 + $1.income } / count),
            averageBalance: cents(months.reduce(0) { $0 + $1.balance } / count),
            byYear: byYear
        )
    }

    /// AAAA-MM de cada período mensual: el mes en curso y los tres anteriores.
    static func periodMonths(now: Date, calendar: Calendar) -> [String: String] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM"
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        var out: [String: String] = [:]
        for (key, back) in [("current_month", 0), ("last_month", 1), ("two_months_ago", 2), ("three_months_ago", 3)] {
            if let date = calendar.date(byAdding: .month, value: -back, to: monthStart) {
                out[key] = formatter.string(from: date)
            }
        }
        return out
    }

    /// Lo que queda del mes. Los presupuestos que suman son los mensuales en la divisa principal (otra divisa no se
    /// suma en crudo), y los programados, los de `pending_next_30_days` que vencen antes del final del mes.
    static func monthOutlook(
        budgets: [FullFinancialContext.BudgetEntry],
        recurring: FullFinancialContext.RecurringSection,
        currencyCode: String,
        now: Date,
        monthEnd: Date,
        calendar: Calendar
    ) -> FullFinancialContext.MonthOutlook {
        let budgetsRemaining = budgets
            .filter { $0.periodType == "monthly" && $0.limit > 0 && $0.currency == currencyCode }
            .reduce(0.0) { $0 + max(0, $1.limit - $1.spent) }
        let monthEndKey = isoDateFormatter.string(from: monthEnd)
        let thisMonth = recurring.pendingNext30Days.filter { $0.dueDate <= monthEndKey }
        return FullFinancialContext.MonthOutlook(
            daysLeft: daysLeftInMonth(now: now, calendar: calendar),
            budgetsRemaining: cents(budgetsRemaining),
            pendingPaymentsUntilMonthEnd: cents(thisMonth.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }),
            pendingIncomeUntilMonthEnd: cents(thisMonth.filter(\.isIncome).reduce(0) { $0 + $1.amount })
        )
    }

    /// Redondeo a céntimos: `0.1 + 0.2` escribía `6737.4000000000015` en el JSON.
    static func cents(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    /// Días que quedan del mes contando hoy (el 30 de un mes de 31 → 2).
    static func daysLeftInMonth(now: Date, calendar: Calendar) -> Int {
        guard let month = calendar.range(of: .day, in: .month, for: now) else { return 1 }
        return max(1, month.count - calendar.component(.day, from: now) + 1)
    }

    // MARK: - Sub-builders

    private func buildMetadata(
        now: Date,
        currency: String,
        currencyDisplay: String,
        language: String,
        country: String,
        excludedAccountNames: [String],
        calendar: Calendar
    ) -> FullFinancialContext.Metadata {
        let weekdaySymbols = calendar.weekdaySymbols
        let weekdayIdx = calendar.component(.weekday, from: now)
        let weekday = (weekdayIdx >= 1 && weekdayIdx <= 7) ? weekdaySymbols[weekdayIdx - 1] : ""

        let monthLabelFormatter = DateFormatter()
        monthLabelFormatter.dateFormat = "MMMM yyyy"
        monthLabelFormatter.locale = Locale(identifier: language)

        return FullFinancialContext.Metadata(
            dateToday: Self.isoDateFormatter.string(from: now),
            weekday: weekday,
            monthLabel: monthLabelFormatter.string(from: now),
            currency: currency,
            currencyDisplay: currencyDisplay,
            language: language,
            country: country,
            excludedAccounts: excludedAccountNames,
            periodMonths: Self.periodMonths(now: now, calendar: calendar)
        )
    }

    /// Lista todas las cuentas que cuentan (`accounts`) y suma las del total del Panel sin filtro de cuentas:
    /// con «Grupos en el total» apagado, `accountsForTotal` quita las cuentas sistema de Grupos solo de la suma.
    private func buildBalances(
        accounts: [Account],
        lineRoles: [UUID: AccountLineRole],
        includeGroupsInTotal: Bool,
        allRawTx: [TransactionItem],
        preferredCurrency: String,
        converter: CurrencyConverting,
        now: Date
    ) -> FullFinancialContext.BalancesSection {
        // Una tarjeta con varias divisas sale una vez, con sus líneas dentro (entrega 4): suelta, el modelo las leía como
        // dos cuentas y podía sumarlas en crudo. Como la tarjeta del Panel (`PanelViewModel.orderedActiveAccountCards`):
        // los roles salen de TODAS las cuentas, y una línea archivada no entra en la tarjeta ni en su total. Aquí sigue
        // listada aparte, porque cuenta en `total_balance` (archivar no decide la suma). Una línea cuya principal no
        // cuenta sale suelta, como en el resto de la app.
        var entries: [FullFinancialContext.AccountEntry] = []
        for card in accounts.accountCards(roles: lineRoles) {
            let live = AccountCard(head: card.head, lines: card.lines.filter { !$0.isArchived })
            entries.append(accountEntry(
                live, allRawTx: allRawTx, preferredCurrency: preferredCurrency, converter: converter, now: now))
            for archived in card.lines where archived.isArchived {
                entries.append(accountEntry(
                    AccountCard(head: archived, lines: []), allRawTx: allRawTx, preferredCurrency: preferredCurrency,
                    converter: converter, now: now))
            }
        }
        // Balance enviado al LLM: TC actual sobre saldo nativo (LiveBalanceCalculator)
        // en vez de suma de snapshots históricos — el LLM debe ver el saldo
        // disponible HOY, no la acumulación con TCs de distintos momentos.
        let total = LiveBalanceCalculator.liveBalance(
            accounts: PanelTotalAccountsLogic.accountsForTotal(
                accounts,
                includeGroups: includeGroupsInTotal,
                hasSelectedAccount: false
            ),
            transactions: allRawTx,
            preferredCurrencyCode: preferredCurrency,
            asOf: now,
            converter: converter
        )
        return FullFinancialContext.BalancesSection(
            accounts: entries,
            totalBalance: safeDouble(total),
            totalIncludesGroups: includeGroupsInTotal
        )
    }

    private func accountEntry(
        _ card: AccountCard<Account>,
        allRawTx: [TransactionItem],
        preferredCurrency: String,
        converter: CurrencyConverting,
        now: Date
    ) -> FullFinancialContext.AccountEntry {
        // El saldo de cada cuenta, como el del Panel (`AccountBalanceCalculator`): el libro entero y el corte de hoy.
        func balance(_ account: Account) -> Double {
            let value = AccountBalanceCalculator.currentBalance(for: account, allTransactions: allRawTx, asOf: now)
            return (value as NSDecimalNumber).doubleValue
        }
        var entry = FullFinancialContext.AccountEntry(
            name: card.head.name,
            type: card.head.type,
            balance: safeDouble(balance(card.head)),
            currency: card.head.currencyCode
        )
        guard card.hasLines else {
            // En otra divisa: también en la principal, con la tasa más reciente (la regla del saldo vivo).
            if normalizeCurrencyCode(card.head.currencyCode) != normalizeCurrencyCode(preferredCurrency) {
                let outcome = converter.convertCheckedWithLatestRate(
                    Decimal(entry.balance), from: card.head.currencyCode, to: preferredCurrency)
                entry.balanceInMainCurrency = safeDouble((outcome.amount as NSDecimalNumber).doubleValue)
                entry.balanceInMainCurrencyIsApproximate = !outcome.quality.isExact
            }
            return entry
        }
        entry.lines = card.lines.map { line in
            FullFinancialContext.LineEntry(name: line.name, balance: safeDouble(balance(line)), currency: line.currencyCode)
        }
        // El mismo total que la tarjeta del Panel (`AccountCardView.cardTotal`): tasa más reciente y «≈» si algo se convirtió.
        let total = AccountCardLogic.total(
            card.members.map {
                AccountCardLogic.LineAmount(value: balance($0), currencyCode: normalizeCurrencyCode($0.currencyCode))
            },
            in: normalizeCurrencyCode(preferredCurrency)
        ) { value, code in
            let outcome = converter.convertCheckedWithLatestRate(Decimal(value), from: code, to: preferredCurrency)
            return (outcome.amount as NSDecimalNumber).doubleValue
        }
        entry.cardTotal = safeDouble(total.value)
        entry.cardTotalIsApproximate = total.isConverted
        return entry
    }

    private func buildPeriods(
        tx: [TransactionItem],
        intervals: Intervals,
        currencyCode: String,
        converter: CurrencyConverting,
        now: Date,
        calendar: Calendar,
        adjustment: GroupBridgeStatsAdjustment
    ) -> FullFinancialContext.PeriodsSection {
        func summarize(_ interval: DateInterval) -> FullFinancialContext.PeriodSummary {
            let periodTx = tx.filter { interval.contains($0.date) }
            let cashFlow = CashFlowCalculator.calculateCashFlow(
                transactions: periodTx,
                interval: interval,
                grouping: .day,
                currencyCode: currencyCode,
                adjustment: adjustment,
                converter: converter
            )
            // `min(interval.end, now)` recorta el período en curso al instante actual, y eso NO se
            // toca: lo que se arregla es el otro extremo, el de los períodos ya cerrados que llegan con
            // `-1 s`. Este promedio se serializa como `daily_avg` y viaja al contexto del asistente, así
            // que un denominador corto hacía que el chat respondiera con cifras infladas — +16,7 % en
            // «semana pasada», que sobre 7 días es un día entero de más.
            let days = max(1, DateIntervalDayCount.days(
                from: interval.start, to: min(interval.end, now), calendar: calendar))
            let dailyAvg = cashFlow.totalExpense / Double(days)
            let savingsRate: Double? = cashFlow.totalIncome > 0
                ? ((cashFlow.totalIncome - cashFlow.totalExpense) / cashFlow.totalIncome) * 100
                : nil
            return FullFinancialContext.PeriodSummary(
                income: safeDouble(cashFlow.totalIncome),
                expense: safeDouble(cashFlow.totalExpense),
                balance: safeDouble(cashFlow.netFlow),
                txCount: periodTx.count,
                dailyAvg: safeDouble(dailyAvg),
                savingsRatePercent: savingsRate.map(safeDouble),
                // `cashFlow` ya trae las tres calculadas; hasta hoy se leían 3 de sus 6 campos y el
                // asistente respondía cifras multidivisa como si fueran exactas.
                incomeIsApproximate: cashFlow.incomeAmountsAreApproximate,
                expenseIsApproximate: cashFlow.expenseAmountsAreApproximate,
                balanceIsApproximate: cashFlow.amountsAreApproximate
            )
        }

        let weekSummaries: [FullFinancialContext.WeekSummary] = intervals.last4Weeks.map { interval in
            let weekTx = tx.filter { interval.contains($0.date) }
            let cashFlow = CashFlowCalculator.calculateCashFlow(
                transactions: weekTx,
                interval: interval,
                grouping: .day,
                currencyCode: currencyCode,
                adjustment: adjustment,
                converter: converter
            )
            return FullFinancialContext.WeekSummary(
                weekStart: Self.isoDateFormatter.string(from: interval.start),
                income: safeDouble(cashFlow.totalIncome),
                expense: safeDouble(cashFlow.totalExpense),
                incomeIsApproximate: cashFlow.incomeAmountsAreApproximate,
                expenseIsApproximate: cashFlow.expenseAmountsAreApproximate
            )
        }

        return FullFinancialContext.PeriodsSection(
            today: summarize(intervals.today),
            currentWeek: summarize(intervals.currentWeek),
            lastWeek: summarize(intervals.lastWeek),
            last4Weeks: weekSummaries,
            currentMonth: summarize(intervals.currentMonth),
            lastMonth: summarize(intervals.lastMonth),
            lastMonthToDate: summarize(intervals.lastMonthToDate),
            twoMonthsAgo: summarize(intervals.twoMonthsAgo),
            threeMonthsAgo: summarize(intervals.threeMonthsAgo),
            currentYear: summarize(intervals.currentYear),
            yesterday: summarize(intervals.yesterday),
            sameMonthLastYear: summarize(intervals.sameMonthLastYear)
        )
    }

    private func buildCategories(
        tx: [TransactionItem],
        intervals: Intervals,
        currencyCode: String,
        converter: CurrencyConverting,
        adjustment: GroupBridgeStatsAdjustment
    ) -> [FullFinancialContext.CategoryEntry] {
        let currentTx = tx.filter { intervals.currentMonth.contains($0.date) && $0.category?.isIncome == false }
        let lastMonthTx = tx.filter { intervals.lastMonth.contains($0.date) && $0.category?.isIncome == false }
        let twoMonthsAgoTx = tx.filter { intervals.twoMonthsAgo.contains($0.date) && $0.category?.isIncome == false }
        let currentYearTx = tx.filter { intervals.currentYear.contains($0.date) && $0.category?.isIncome == false }

        // Totales por periodo de una categoría o subcategoría. `lastToDate` es la parte del mes
        // pasado hasta el día equivalente a hoy (`intervals.lastMonthToDate`, contenido en `last`).
        struct Totals {
            var current: Double = 0
            var last: Double = 0
            var lastToDate: Double = 0
            var twoBack: Double = 0
            var count: Int = 0
            var year: Double = 0
        }

        // Group by category name for each period
        var catAgg: [String: Totals] = [:]
        // Track tx by (categoryName -> subcategoryName -> totals)
        var subAgg: [String: [String: Totals]] = [:]

        func add(_ tx: TransactionItem, _ apply: (inout Totals, Double) -> Void) {
            if adjustment.isSuppressed(tx) { return }
            let cat = tx.category?.name ?? "Other"
            let amount = convertAmount(tx, currencyCode: currencyCode, converter: converter, adjustment: adjustment)
            apply(&catAgg[cat, default: Totals()], amount)
            if let sub = tx.subcategory?.name {
                apply(&subAgg[cat, default: [:]][sub, default: Totals()], amount)
            }
        }

        for tx in currentTx {
            add(tx) { $0.current += $1; $0.count += 1 }
        }
        for tx in lastMonthTx {
            let toDate = intervals.lastMonthToDate.contains(tx.date)
            add(tx) { totals, amount in
                totals.last += amount
                if toDate { totals.lastToDate += amount }
            }
        }
        for tx in twoMonthsAgoTx {
            add(tx) { $0.twoBack += $1 }
        }
        for tx in currentYearTx {
            add(tx) { $0.year += $1 }
        }

        // Top 10 por el mes en curso; a igualdad, por lo que va del año y por nombre (orden estable: con el año dentro
        // hay muchas categorías a 0 este mes, y el orden de un diccionario no lo es).
        let ranked = catAgg.keys.sorted { (a, b) in
            let (ta, tb) = (catAgg[a] ?? Totals(), catAgg[b] ?? Totals())
            if ta.current != tb.current { return ta.current > tb.current }
            if ta.year != tb.year { return ta.year > tb.year }
            return a < b
        }
        let topCats = Array(ranked.prefix(10))

        return topCats.map { catName in
            let cat = catAgg[catName] ?? Totals()

            // Subcategorías con tx > 0 en cualquiera de los 3 meses
            var subEntries: [FullFinancialContext.SubcategoryEntry] = []
            if let subDict = subAgg[catName] {
                // Solo las que se movieron en los tres últimos meses, como antes: con el año dentro salían todas.
                let activeSubs = subDict.filter { $0.value.current > 0 || $0.value.last > 0 || $0.value.twoBack > 0 }
                let sortedSubs = activeSubs.sorted { $0.value.current > $1.value.current }
                subEntries = sortedSubs.map { (name, val) in
                    FullFinancialContext.SubcategoryEntry(
                        name: name,
                        totalCurrentMonth: safeDouble(val.current),
                        totalLastMonth: safeDouble(val.last),
                        totalLastMonthToDate: safeDouble(val.lastToDate),
                        totalTwoMonthsAgo: safeDouble(val.twoBack),
                        variationPercentVsLastMonthToDate: Self.variationPercent(val.current, vs: val.lastToDate),
                        txCountCurrentMonth: val.count,
                        totalCurrentYear: safeDouble(val.year)
                    )
                }
            }

            return FullFinancialContext.CategoryEntry(
                name: catName,
                totalCurrentMonth: safeDouble(cat.current),
                totalLastMonth: safeDouble(cat.last),
                totalLastMonthToDate: safeDouble(cat.lastToDate),
                totalTwoMonthsAgo: safeDouble(cat.twoBack),
                variationPercentVsLastMonthToDate: Self.variationPercent(cat.current, vs: cat.lastToDate),
                txCountCurrentMonth: cat.count,
                subcategories: subEntries,
                totalCurrentYear: safeDouble(cat.year)
            )
        }
    }

    /// Variación del mes en curso contra el mes pasado HASTA EL MISMO DÍA. `nil` si no hubo gasto
    /// en ese tramo. Contra el mes pasado entero, a mitad de mes, casi todo salía «menos».
    static func variationPercent(_ current: Double, vs lastToDate: Double) -> Double? {
        guard lastToDate > 0 else { return nil }
        let value = ((current - lastToDate) / lastToDate) * 100
        return value.isFinite ? value : 0
    }

    /// Ingresos por categoría y subcategoría: el mes en curso, el pasado y lo que va del año.
    private func buildIncomeCategories(
        tx: [TransactionItem],
        intervals: Intervals,
        currencyCode: String,
        converter: CurrencyConverting,
        adjustment: GroupBridgeStatsAdjustment
    ) -> [FullFinancialContext.IncomeCategoryEntry] {
        struct Totals { var current = 0.0, last = 0.0, year = 0.0 }
        var catAgg: [String: Totals] = [:]
        var subAgg: [String: [String: Totals]] = [:]
        for tx in tx where tx.category?.isIncome == true && !adjustment.isSuppressed(tx) {
            let inCurrent = intervals.currentMonth.contains(tx.date)
            let inLast = intervals.lastMonth.contains(tx.date)
            let inYear = intervals.currentYear.contains(tx.date)
            guard inCurrent || inLast || inYear else { continue }
            let amount = convertAmount(tx, currencyCode: currencyCode, converter: converter, adjustment: adjustment)
            let cat = tx.category?.name ?? "Other"
            func apply(_ t: inout Totals) {
                if inCurrent { t.current += amount }
                if inLast { t.last += amount }
                if inYear { t.year += amount }
            }
            apply(&catAgg[cat, default: Totals()])
            if let sub = tx.subcategory?.name { apply(&subAgg[cat, default: [:]][sub, default: Totals()]) }
        }
        return catAgg
            .sorted { $0.value.year != $1.value.year ? $0.value.year > $1.value.year : $0.key < $1.key }
            .prefix(10)
            .map { name, totals in
                let subs = (subAgg[name] ?? [:])
                    .sorted { $0.value.year != $1.value.year ? $0.value.year > $1.value.year : $0.key < $1.key }
                    .prefix(10)
                    .map {
                        FullFinancialContext.IncomeSubcategoryEntry(
                            name: $0.key,
                            totalCurrentMonth: safeDouble($0.value.current),
                            totalLastMonth: safeDouble($0.value.last),
                            totalCurrentYear: safeDouble($0.value.year)
                        )
                    }
                return FullFinancialContext.IncomeCategoryEntry(
                    name: name,
                    totalCurrentMonth: safeDouble(totals.current),
                    totalLastMonth: safeDouble(totals.last),
                    totalCurrentYear: safeDouble(totals.year),
                    subcategories: Array(subs)
                )
            }
    }

    /// Los 12 meses CERRADOS antes de `monthStart`, del más reciente al más antiguo: ingresos, gastos y neto con la
    /// regla de `periods` (`CashFlowCalculator`), y las categorías y subcategorías que más pesaron. Junto al mes en
    /// curso son los 13 meses del aviso. Cada mes cierra un segundo antes del siguiente (`DateInterval` es cerrado).
    private func buildMonthlyHistory(
        tx: [TransactionItem],
        monthStart: Date,
        currencyCode: String,
        converter: CurrencyConverting,
        calendar: Calendar,
        adjustment: GroupBridgeStatsAdjustment
    ) -> [FullFinancialContext.MonthSummary] {
        let keyFormatter = DateFormatter()
        keyFormatter.calendar = Calendar(identifier: .gregorian)
        keyFormatter.locale = Locale(identifier: "en_US_POSIX")
        keyFormatter.timeZone = calendar.timeZone
        keyFormatter.dateFormat = "yyyy-MM"

        var months: [FullFinancialContext.MonthSummary] = []
        for back in 1...12 {
            guard let start = calendar.date(byAdding: .month, value: -back, to: monthStart),
                  let next = calendar.date(byAdding: .month, value: 1, to: start),
                  let end = calendar.date(byAdding: .second, value: -1, to: next) else { continue }
            let interval = DateInterval(start: start, end: end)
            let monthTx = tx.filter { interval.contains($0.date) }
            let cashFlow = CashFlowCalculator.calculateCashFlow(
                transactions: monthTx,
                interval: interval,
                grouping: .day,
                currencyCode: currencyCode,
                adjustment: adjustment,
                converter: converter
            )
            var byCategory: [String: Double] = [:]
            var bySub: [String: (category: String, total: Double)] = [:]
            var incomeBySub: [String: Double] = [:]
            for tx in monthTx where !adjustment.isSuppressed(tx) {
                let amount = convertAmount(tx, currencyCode: currencyCode, converter: converter, adjustment: adjustment)
                let category = tx.category?.name ?? "Other"
                if tx.category?.isIncome == true {
                    incomeBySub[tx.subcategory?.name ?? category, default: 0] += amount
                } else if tx.category?.isIncome == false {
                    byCategory[category, default: 0] += amount
                    if let sub = tx.subcategory?.name {
                        bySub[sub, default: (category, 0)].total += amount
                    }
                }
            }
            func top(_ totals: [String: Double], _ n: Int) -> [FullFinancialContext.NamedTotal] {
                totals.filter { $0.value > 0 }
                    .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
                    .prefix(n)
                    .map { FullFinancialContext.NamedTotal(name: $0.key, total: safeDouble($0.value.rounded())) }
            }
            let topSubs = bySub.filter { $0.value.total > 0 }
                .sorted { $0.value.total != $1.value.total ? $0.value.total > $1.value.total : $0.key < $1.key }
                .prefix(5)
                .map {
                    FullFinancialContext.NamedTotal(
                        name: $0.key, category: $0.value.category, total: safeDouble($0.value.total.rounded()))
                }
            // Cifras a dos decimales y tops cortos: son 12 meses y cada carácter se paga en cada pregunta (el banco midió
            // +60 % de contexto con seis categorías, ocho subcategorías y los flags siempre escritos).
            months.append(FullFinancialContext.MonthSummary(
                month: keyFormatter.string(from: start),
                income: Self.cents(safeDouble(cashFlow.totalIncome)),
                expense: Self.cents(safeDouble(cashFlow.totalExpense)),
                balance: Self.cents(safeDouble(cashFlow.netFlow)),
                incomeIsApproximate: cashFlow.incomeAmountsAreApproximate ? true : nil,
                expenseIsApproximate: cashFlow.expenseAmountsAreApproximate ? true : nil,
                topExpenseCategories: top(byCategory, 6),
                topExpenseSubcategories: Array(topSubs),
                topIncomeSubcategories: top(incomeBySub, 2)
            ))
        }
        return months
    }

    /// La tasa más reciente de cada divisa de las cuentas que cuentan, a la principal.
    private func buildFxRates(
        accounts: [Account],
        preferredCurrency: String,
        converter: CurrencyConverting
    ) -> [FullFinancialContext.FxRateEntry] {
        let main = normalizeCurrencyCode(preferredCurrency)
        let codes = Set(accounts.map { normalizeCurrencyCode($0.currencyCode) }).subtracting([main]).sorted()
        return codes.map { code in
            let outcome = converter.convertCheckedWithLatestRate(1, from: code, to: main)
            return FullFinancialContext.FxRateEntry(
                currency: code,
                rateToMainCurrency: safeDouble((outcome.amount as NSDecimalNumber).doubleValue),
                isApproximate: !outcome.quality.isExact
            )
        }
    }

    private func buildUncategorized(
        tx: [TransactionItem],
        converter: CurrencyConverting,
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment
    ) -> FullFinancialContext.UncategorizedBucket {
        // Skip patas de préstamo suprimidas (pueden colarse como category==nil en ventana lazy).
        let unc = tx.filter { $0.category == nil && !adjustment.isSuppressed($0) }
        let total = unc.reduce(0.0) { $0 + convertAmount($1, currencyCode: currencyCode, converter: converter, adjustment: adjustment) }
        return FullFinancialContext.UncategorizedBucket(
            totalCurrentMonth: safeDouble(total),
            txCountCurrentMonth: unc.count
        )
    }

    private func buildMerchantsTop20(
        tx: [TransactionItem],
        intervals: Intervals,
        currencyCode: String,
        converter: CurrencyConverting,
        adjustment: GroupBridgeStatsAdjustment
    ) -> [FullFinancialContext.MerchantEntry] {
        let currentTx = tx.filter { intervals.currentMonth.contains($0.date) && $0.category?.isIncome == false }
        let lastTx = tx.filter { intervals.lastMonth.contains($0.date) && $0.category?.isIncome == false }

        var current: [String: (total: Double, count: Int)] = [:]
        var last: [String: Double] = [:]
        var lastToDate: [String: Double] = [:]

        for tx in currentTx {
            if adjustment.isSuppressed(tx) { continue }
            guard let merchant = canonicalMerchant(tx) else { continue }
            let amount = convertAmount(tx, currencyCode: currencyCode, converter: converter, adjustment: adjustment)
            let entry = current[merchant] ?? (total: 0, count: 0)
            current[merchant] = (total: entry.total + amount, count: entry.count + 1)
        }
        for tx in lastTx {
            if adjustment.isSuppressed(tx) { continue }
            guard let merchant = canonicalMerchant(tx) else { continue }
            let amount = convertAmount(tx, currencyCode: currencyCode, converter: converter, adjustment: adjustment)
            last[merchant, default: 0] += amount
            if intervals.lastMonthToDate.contains(tx.date) {
                lastToDate[merchant, default: 0] += amount
            }
        }

        let sorted = current.sorted { $0.value.total > $1.value.total }.prefix(20)
        return sorted.map { (name, val) in
            let lastToDateVal = lastToDate[name] ?? 0
            let avg = val.count > 0 ? val.total / Double(val.count) : 0
            return FullFinancialContext.MerchantEntry(
                name: name,
                totalCurrentMonth: safeDouble(val.total),
                totalLastMonth: safeDouble(last[name] ?? 0),
                totalLastMonthToDate: safeDouble(lastToDateVal),
                txCount: val.count,
                avgAmount: safeDouble(avg),
                variationPercentVsLastMonthToDate: Self.variationPercent(val.total, vs: lastToDateVal)
            )
        }
    }

    private func buildBudgets(
        allBudgets: [Budget],
        allTx: [TransactionItem],
        converter: CurrencyConverting,
        now: Date,
        calendar: Calendar,
        adjustment: GroupBridgeStatsAdjustment
    ) -> [FullFinancialContext.BudgetEntry] {
        let active = allBudgets.filter { $0.isActive }
        return active.map { budget in
            let interval = InsightsCalculator.currentBudgetInterval(for: budget, now: now)
            // Canonical spending path: filtra por resolvedSubcategoryIDs/AccountIDs/
            // TagIDs/natures + includeSharedExpenses y convierte con TC actual
            // (convertWithLatestRate). El sistema moderno NO setea `budget.category`
            // (relación legacy), así que filtrar por ella daría spent=0 catastrófico.
            let spent = safeDouble(
                BudgetsViewModel.calculateSpending(
                    budget: budget,
                    transactions: allTx,
                    interval: interval,
                    adjustment: adjustment,
                    converter: converter
                )
            )
            let limit = budget.limitAmount
            let usagePct: Double? = limit > 0 ? (spent / limit) * 100 : nil
            // Hoy cuenta: el último día del presupuesto queda 1, no 0 (decisión de Jürgen, 2026-09-06).
            let daysLeft = BudgetPeriodInterval.daysLeft(now: now, in: interval, calendar: calendar)
            let status: FullFinancialContext.BudgetStatus
            if limit <= 0 {
                status = .noLimit
            } else if (usagePct ?? 0) >= 100 {
                status = .exceeded
            } else if (usagePct ?? 0) >= 75 {
                status = .atRisk
            } else {
                status = .onTrack
            }
            return FullFinancialContext.BudgetEntry(
                name: budget.name,
                category: budget.category?.name,
                limit: safeDouble(limit),
                spent: safeDouble(spent),
                usagePercent: usagePct.map(safeDouble),
                daysLeft: daysLeft,
                status: status,
                periodType: budget.periodType,
                currency: budget.currencyCode
            )
        }
    }

    private func buildRecurring(
        scheduledPayments: [ScheduledPayment],
        currencyCode: String,
        converter: CurrencyConverting,
        now: Date,
        calendar: Calendar,
        currentMonthInterval: DateInterval
    ) -> FullFinancialContext.RecurringSection {
        let active = scheduledPayments.filter { $0.isActive }

        // Paid this month: dates within currentMonthInterval AND <= now
        var paid: [FullFinancialContext.RecurringPaidEntry] = []
        // Pending next 30 days: dates > now AND <= now+30
        var pending: [FullFinancialContext.RecurringPendingEntry] = []
        let cutoffPending = calendar.date(byAdding: .day, value: 30, to: now) ?? now

        // Check current and next month for pending; current and prev for paid
        let monthsToCheck = [
            calendar.date(byAdding: .month, value: -1, to: now) ?? now,
            now,
            calendar.date(byAdding: .month, value: 1, to: now) ?? now
        ]

        var seenPaid: Set<String> = []
        var seenPending: Set<String> = []

        for monthDate in monthsToCheck {
            for payment in active {
                let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                    params: payment.dateCalculatorParams,
                    month: monthDate,
                    calendar: calendar
                )
                for date in dates where !payment.isDateSkipped(date) {
                    let amount: Double
                    if payment.currencyCode == currencyCode {
                        amount = abs(payment.amount)
                    } else {
                        let converted = converter.convert(
                            Decimal(abs(payment.amount)),
                            from: payment.currencyCode,
                            to: currencyCode,
                            on: date
                        )
                        amount = safeDouble(NSDecimalNumber(decimal: converted).doubleValue)
                    }
                    let key = "\(payment.id)-\(Self.isoDateFormatter.string(from: date))"

                    if currentMonthInterval.contains(date) && date <= now && payment.transactionType == "expense" {
                        if seenPaid.insert(key).inserted {
                            paid.append(FullFinancialContext.RecurringPaidEntry(
                                name: payment.name,
                                amount: amount,
                                date: Self.isoDateFormatter.string(from: date),
                                category: payment.subcategory?.category?.name,
                                subcategory: payment.subcategory?.name
                            ))
                        }
                    } else if date > now && date <= cutoffPending {
                        if seenPending.insert(key).inserted {
                            let type = payment.isRecurring ? payment.paymentCategory : "one_time"
                            pending.append(FullFinancialContext.RecurringPendingEntry(
                                name: payment.name,
                                amount: amount,
                                dueDate: Self.isoDateFormatter.string(from: date),
                                category: payment.subcategory?.category?.name,
                                subcategory: payment.subcategory?.name,
                                type: type,
                                isIncome: payment.transactionType == "income"
                            ))
                        }
                    }
                }
            }
        }
        paid.sort { $0.date < $1.date }
        pending.sort { $0.dueDate < $1.dueDate }

        let subscriptions = monthlyTotal(for: active, paymentCategory: "subscription", currencyCode: currencyCode, converter: converter, now: now)
        let recurring = monthlyTotal(for: active, paymentCategory: "recurring", currencyCode: currencyCode, converter: converter, now: now)

        return FullFinancialContext.RecurringSection(
            paidThisMonth: paid,
            pendingNext30Days: pending,
            totals: FullFinancialContext.RecurringTotals(
                subscriptionsMonthly: safeDouble(subscriptions),
                recurringMonthly: safeDouble(recurring)
            ),
            active: buildActiveRecurring(
                active, currencyCode: currencyCode, converter: converter, now: now, calendar: calendar)
        )
    }

    /// Cada pago programado activo, con su importe en la divisa principal y su próxima fecha (la primera del calendario
    /// del pago desde hoy que no está saltada). Hasta 30, ordenados por fecha.
    private func buildActiveRecurring(
        _ payments: [ScheduledPayment],
        currencyCode: String,
        converter: CurrencyConverting,
        now: Date,
        calendar: Calendar
    ) -> [FullFinancialContext.RecurringActiveEntry] {
        let startOfToday = calendar.startOfDay(for: now)
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday
        let entries = payments.map { payment -> FullFinancialContext.RecurringActiveEntry in
            var next: Date?
            for offset in 0...13 where next == nil {
                guard let month = calendar.date(byAdding: .month, value: offset, to: monthStart) else { continue }
                next = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                    params: payment.dateCalculatorParams, month: month, calendar: calendar
                )
                .sorted()
                .first { $0 >= startOfToday && !payment.isDateSkipped($0) }
            }
            let amount: Double
            if normalizeCurrencyCode(payment.currencyCode) == normalizeCurrencyCode(currencyCode) {
                amount = abs(payment.amount)
            } else {
                let converted = converter.convert(
                    Decimal(abs(payment.amount)), from: payment.currencyCode, to: currencyCode, on: next ?? now)
                amount = safeDouble(NSDecimalNumber(decimal: converted).doubleValue)
            }
            let frequency = payment.isRecurring ? (RecurrenceType(rawValue: payment.recurrenceType) ?? .monthly).rawValue : "once"
            return FullFinancialContext.RecurringActiveEntry(
                name: payment.name,
                amount: amount,
                isIncome: payment.transactionType == "income",
                type: payment.isRecurring ? payment.paymentCategory : "one_time",
                frequency: frequency,
                every: payment.recurrenceInterval > 1 ? payment.recurrenceInterval : nil,
                nextDate: next.map { Self.isoDateFormatter.string(from: $0) },
                subcategory: payment.subcategory?.name
            )
        }
        return Array(entries.sorted { ($0.nextDate ?? "9999") < ($1.nextDate ?? "9999") }.prefix(30))
    }

    private func monthlyTotal(
        for payments: [ScheduledPayment],
        paymentCategory: String,
        currencyCode: String,
        converter: CurrencyConverting,
        now: Date
    ) -> Double {
        payments
            .filter { $0.paymentCategory == paymentCategory && $0.transactionType == "expense" }
            .reduce(0.0) { sum, p in
                let converted = converter.convert(
                    Decimal(abs(p.amount)),
                    from: p.currencyCode,
                    to: currencyCode,
                    on: now
                )
                let baseDouble = safeDouble(NSDecimalNumber(decimal: converted).doubleValue)
                return sum + baseDouble * monthlyMultiplier(p)
            }
    }

    private func monthlyMultiplier(_ payment: ScheduledPayment) -> Double {
        guard payment.isRecurring else { return 1.0 }
        let interval = max(1, payment.recurrenceInterval)
        let type = RecurrenceType(rawValue: payment.recurrenceType) ?? .monthly
        switch type {
        case .daily: return 30.0 / Double(interval)
        case .weekly: return 4.33 / Double(interval)
        case .monthly: return 1.0 / Double(interval)
        case .yearly: return 1.0 / (12.0 * Double(interval))
        }
    }

    private func buildPatterns(
        tx: [TransactionItem],
        currencyCode: String,
        converter: CurrencyConverting,
        now: Date,
        endOfToday: Date,
        calendar: Calendar,
        adjustment: GroupBridgeStatsAdjustment
    ) -> FullFinancialContext.PatternsSection {
        let last30Start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let last30Interval = DateInterval(start: last30Start, end: endOfToday)
        let last30Tx = tx.filter { last30Interval.contains($0.date) && $0.category?.isIncome == false }

        let weekdayData = WeekdaySpendingCalculator.calculate(
            transactions: last30Tx,
            interval: last30Interval,
            currencyCode: currencyCode,
            adjustment: adjustment,
            converter: converter
        )
        let weekdaySymbols = calendar.weekdaySymbols
        let weekdayEntries: [FullFinancialContext.WeekdayEntry] = weekdayData.map { day in
            let name = (day.weekday >= 1 && day.weekday <= 7) ? weekdaySymbols[day.weekday - 1] : "?"
            return FullFinancialContext.WeekdayEntry(
                weekday: name,
                total: safeDouble(day.total),
                avgPerDay: safeDouble(day.average),
                sampleSize: day.count,
                dayOccurrences: day.dayOccurrences
            )
        }

        // Needs breakdown for current month expenses
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let currentMonthTx = tx.filter { $0.date >= monthStart && $0.date <= endOfToday && $0.category?.isIncome == false }
        var essential = 0.0, priority = 0.0, optional = 0.0, unclassified = 0.0
        for tx in currentMonthTx {
            if adjustment.isSuppressed(tx) { continue }
            let amount = convertAmount(tx, currencyCode: currencyCode, converter: converter, adjustment: adjustment)
            switch tx.effectiveNeed {
            case .essential: essential += amount
            case .priority: priority += amount
            case .optional: optional += amount
            case .unclassified: unclassified += amount
            }
        }
        let needs = FullFinancialContext.NeedsBreakdownEntry(
            essential: safeDouble(essential),
            priority: safeDouble(priority),
            optional: safeDouble(optional),
            unclassified: safeDouble(unclassified),
            total: safeDouble(essential + priority + optional + unclassified)
        )

        return FullFinancialContext.PatternsSection(
            weekdayPattern30Days: weekdayEntries,
            needsBreakdownCurrentMonth: needs
        )
    }

    private func buildTagsTop10(
        tx: [TransactionItem],
        allTags: [Tag],
        currencyCode: String,
        converter: CurrencyConverting,
        currentMonthInterval: DateInterval,
        adjustment: GroupBridgeStatsAdjustment
    ) -> [FullFinancialContext.TagEntry] {
        // CSV-mirror SSOT via resolver + catalog construido del allTags inyectado.
        let tagCatalog = Tag.byIDLookup(allTags)
        var tagTotals: [String: (total: Double, count: Int)] = [:]
        for tx in tx {
            if adjustment.isSuppressed(tx) { continue }
            let amount = convertAmount(tx, currencyCode: currencyCode, converter: converter, adjustment: adjustment)
            let txTagIDs = tx.resolvedTagIDs(scheduleBackfill: true) ?? []
            for uuid in txTagIDs {
                guard let tag = tagCatalog[uuid] else { continue }
                let entry = tagTotals[tag.name] ?? (total: 0, count: 0)
                tagTotals[tag.name] = (total: entry.total + amount, count: entry.count + 1)
            }
        }
        return tagTotals
            .sorted { $0.value.total > $1.value.total }
            .prefix(10)
            .map { (name, val) in
                FullFinancialContext.TagEntry(
                    name: name,
                    totalCurrentMonth: safeDouble(val.total),
                    txCount: val.count
                )
            }
    }

    private func buildTopTxBySubcategory(
        tx: [TransactionItem],
        currencyCode: String,
        converter: CurrencyConverting,
        adjustment: GroupBridgeStatsAdjustment
    ) -> [FullFinancialContext.SubcategoryTxEntry] {
        // Group tx by subcategory
        var grouped: [String: (categoryName: String, txs: [TransactionItem])] = [:]
        for tx in tx {
            if adjustment.isSuppressed(tx) { continue }
            guard let subName = tx.subcategory?.name else { continue }
            let catName = tx.category?.name ?? "Other"
            var entry = grouped[subName] ?? (categoryName: catName, txs: [])
            entry.txs.append(tx)
            grouped[subName] = entry
        }

        // Compute total per subcat to rank top 10
        let ranked = grouped
            .map { (name: $0.key, total: $0.value.txs.reduce(0.0) { $0 + convertAmount($1, currencyCode: currencyCode, converter: converter, adjustment: adjustment) }, categoryName: $0.value.categoryName, txs: $0.value.txs) }
            .sorted { $0.total > $1.total }
            .prefix(10)

        return ranked.map { item in
            // Se eligen y se ordenan por el MISMO importe que se manda, ya en la divisa principal. Con
            // el nativo, 100 USD (≈ S/ 370) quedaban detrás de S/ 150 y, con más de 10 movimientos,
            // podían quedarse fuera (ticket `chat-top-transactions-per-subcategory-rank-by-native-amount`).
            let topTxs = item.txs
                .map { (tx: $0, amount: safeDouble(convertAmount($0, currencyCode: currencyCode, converter: converter, adjustment: adjustment))) }
                .sorted { $0.amount > $1.amount }
                .prefix(10)
                .map { entry -> FullFinancialContext.TxLite in
                    FullFinancialContext.TxLite(
                        date: Self.isoDateFormatter.string(from: entry.tx.date),
                        amount: entry.amount,
                        merchant: canonicalMerchant(entry.tx),
                        account: entry.tx.account?.name
                    )
                }
            return FullFinancialContext.SubcategoryTxEntry(
                subcategoryName: item.name,
                categoryName: item.categoryName,
                transactions: Array(topTxs)
            )
        }
    }

    // MARK: - Fetchers

    /// Todos los movimientos: los saldos los necesitan enteros (el Panel los suma así). La ventana de 13 meses se corta
    /// en memoria.
    private func fetchAllTransactions(_ ctx: ModelContext) -> [TransactionItem] {
        let descriptor = FetchDescriptor<TransactionItem>(
            sortBy: [SortDescriptor(\TransactionItem.date, order: .reverse)]
        )
        do {
            return try ctx.fetch(descriptor)
        } catch {
            #if DEBUG
            print("FullFinancialContextBuilder: fetch de transacciones falló: \(error)")
            #endif
            return []
        }
    }

    private func fetchBudgets(_ ctx: ModelContext) -> [Budget] {
        do {
            return try ctx.fetch(FetchDescriptor<Budget>())
        } catch {
            #if DEBUG
            print("FullFinancialContextBuilder: fetch de presupuestos falló: \(error)")
            #endif
            return []
        }
    }

    private func fetchAccounts(_ ctx: ModelContext) -> [Account] {
        do {
            return try ctx.fetch(FetchDescriptor<Account>())
        } catch {
            #if DEBUG
            print("FullFinancialContextBuilder: fetch de cuentas falló: \(error)")
            #endif
            return []
        }
    }

    private func fetchTags(_ ctx: ModelContext) -> [Tag] {
        do {
            return try ctx.fetch(FetchDescriptor<Tag>())
        } catch {
            #if DEBUG
            print("FullFinancialContextBuilder: fetch de tags falló: \(error)")
            #endif
            return []
        }
    }

    private func fetchScheduledPayments(_ ctx: ModelContext) -> [ScheduledPayment] {
        do {
            return try ctx.fetch(FetchDescriptor<ScheduledPayment>())
        } catch {
            #if DEBUG
            print("FullFinancialContextBuilder: fetch de pagos programados falló: \(error)")
            #endif
            return []
        }
    }

    // MARK: - Helpers

    private func convertAmount(_ tx: TransactionItem, currencyCode: String, converter: CurrencyConverting, adjustment: GroupBridgeStatsAdjustment) -> Double {
        // Pata REAL Caso A: el neto proyectado (`-myShare`) difiere del monto crudo → usar esa
        // magnitud, resuelta con la regla de Estadísticas (`CashFlowCalculator.resolvedAmount`): si
        // la fila se guardó con otra divisa principal, el neto guardado está en esa escala y se
        // reconvierte desde el nativo. Resto: `chatAmount` con conversión de moneda intacta.
        // Se pregunta al ajuste, no se comparan valores: con "mi parte" = 0 y la pata guardada a 0 los
        // dos coinciden, la fila caía en `chatAmount` y éste reconvertía el gasto ENTERO.
        if adjustment.isAdjusted(tx) {
            return abs(CashFlowCalculator.resolvedAmount(
                tx, currencyCode: currencyCode, adjustment: adjustment, converter: converter
            ).value)
        }
        return tx.chatAmount(in: currencyCode, converter: converter)
    }

    private func canonicalMerchant(_ tx: TransactionItem) -> String? {
        guard let note = tx.note, !note.isEmpty else { return nil }
        let canonical = MerchantCanonicalizer.canonicalize(note)
        return canonical.isEmpty ? nil : canonical
    }

    private func safeDouble(_ value: Double) -> Double {
        value.isFinite ? value : 0
    }

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}
