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
//   - comparar el mes en curso → `periods.last_month_to_date` y `total_last_month_to_date`: el
//     mes pasado hasta el día equivalente a hoy, la misma alineación que el hero de Tendencias
//   - tx.balanceAdjustmentType != nil → filtrado
//   - tx.date > now → filtrado (drafts en futuro)
//   - multi-currency → amountInPreferredCurrency con guard isFinite
//   - budget.limitAmount == 0 → status="no_limit", usage_pct=null
//   - 5+ años de data → fetch acotado a últimos 13 meses
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
        now: Date = .now
    ) -> FullFinancialContext {
        let calendar = Calendar.current
        let fetchStart = calendar.date(byAdding: .month, value: -13, to: now) ?? now
        let transactions = fetchTransactions(modelContext, from: fetchStart, to: now)
        // Proyección de gastos de grupo bridgeados → "mi parte" (neto). Se construye del set MÁS
        // AMPLIO (raw fetch, con AMBAS hermanas del bridge antes de filtros por cuenta/tag/eligibilidad).
        let adjustment = GroupBridgeStatsAdjustment.build(from: transactions, context: modelContext)
        return buildFromArrays(
            transactions: transactions,
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
    func buildFromArrays(
        transactions: [TransactionItem],
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
        adjustment: GroupBridgeStatsAdjustment = .none,
        now: Date = .now
    ) -> FullFinancialContext {
        if let entry = cache,
           now.timeIntervalSince(entry.timestamp) < Self.ttlSeconds,
           entry.includedGroupsInTotal == includeGroupsInTotal,
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

        // Filter excluded/balance-adjustment/future TX once
        let eligibleTx = allTx.filter { tx in
            tx.balanceAdjustmentType == nil
                && tx.account?.excludeFromStatistics != true
                && tx.date <= now
        }

        let intervals = buildIntervals(now: now, calendar: calendar)
        // `!= true` keeps tx with category=nil in the expense bucket → uncategorized
        // bucket sees them. Income tx (isIncome==true) are excluded.
        let currentMonthExpenseTx = eligibleTx.filter {
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
            includeGroupsInTotal: includeGroupsInTotal,
            allRawTx: allTx,
            preferredCurrency: currencyCode,
            converter: converter
        )

        let periods = buildPeriods(
            tx: eligibleTx,
            intervals: intervals,
            currencyCode: currencyCode,
            converter: converter,
            now: now,
            calendar: calendar,
            adjustment: adjustment
        )

        let categories = buildCategories(
            tx: eligibleTx,
            intervals: intervals,
            currencyCode: currencyCode,
            converter: converter,
            adjustment: adjustment
        )

        let uncategorized = buildUncategorized(
            tx: currentMonthExpenseTx,
            converter: converter,
            currencyCode: currencyCode,
            adjustment: adjustment
        )

        let merchantsTop20 = buildMerchantsTop20(
            tx: eligibleTx,
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
            tx: eligibleTx,
            currencyCode: currencyCode,
            converter: converter,
            now: now,
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
                allTransactions: eligibleTx,
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
            anomalies: anomalies
        )

        cache = CacheEntry(
            context: context,
            timestamp: now,
            includedAnomalies: includeAnomalies,
            includedGroupsInTotal: includeGroupsInTotal
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
    }

    private func buildIntervals(now: Date, calendar: Calendar) -> Intervals {
        let startOfToday = calendar.startOfDay(for: now)
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
            today: DateInterval(start: startOfToday, end: now),
            currentWeek: DateInterval(start: weekStart, end: now),
            lastWeek: DateInterval(start: prevWeekStart, end: weekStartMinusOneSecond),
            last4Weeks: weeks,
            currentMonth: DateInterval(start: monthStart, end: now),
            lastMonth: lastMonth,
            lastMonthToDate: Self.lastMonthToDateInterval(
                monthStart: monthStart,
                lastMonth: lastMonth,
                now: now,
                calendar: calendar
            ),
            twoMonthsAgo: DateInterval(start: twoMonthsAgoStart, end: lastMonthStartMinusOneSecond),
            threeMonthsAgo: DateInterval(start: threeMonthsAgoStart, end: twoMonthsAgoStartMinusOneSecond),
            currentYear: DateInterval(start: yearStart, end: now),
            last30Days: DateInterval(start: last30Start, end: now)
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
    /// **La corrección del -1 s es de aquí y no del helper.** El helper cierra en la medianoche del día
    /// siguiente al equivalente y `DateInterval.contains` es cerrado en los dos extremos, así que una
    /// transacción de ese día siguiente fechada a medianoche (lo que guarda el `DatePicker` de fecha)
    /// contaría en el mes pasado «hasta hoy». Se resta un segundo salvo cuando el `end` es el clamp al
    /// final del mes pasado, que ya llega restado (`CLAUDE.md`, «Cálculos con fechas»). Los dos heros
    /// que usan el helper con `.contains` tienen ese borde abierto: ticket
    /// `aligned-previous-interval-counts-the-next-midnight`.
    static func lastMonthToDateInterval(
        monthStart: Date,
        lastMonth: DateInterval,
        now: Date,
        calendar: Calendar
    ) -> DateInterval {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let aligned = DateAlignmentHelper.alignedPreviousInterval(
            currentInterval: DateInterval(start: monthStart, end: startOfTomorrow),
            previousInterval: lastMonth,
            asOf: now,
            period: .thisMonth,
            comparisonMode: .month,
            calendar: calendar
        )
        guard aligned.end < lastMonth.end else { return aligned }
        let end = calendar.date(byAdding: .second, value: -1, to: aligned.end) ?? aligned.end
        return DateInterval(start: aligned.start, end: end)
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
            excludedAccounts: excludedAccountNames
        )
    }

    /// Lista todas las cuentas que cuentan (`accounts`) y suma las del total del Panel sin filtro de cuentas:
    /// con «Grupos en el total» apagado, `accountsForTotal` quita las cuentas sistema de Grupos solo de la suma.
    private func buildBalances(
        accounts: [Account],
        includeGroupsInTotal: Bool,
        allRawTx: [TransactionItem],
        preferredCurrency: String,
        converter: CurrencyConverting
    ) -> FullFinancialContext.BalancesSection {
        let entries = accounts.map { account in
            let balance = InitialBalanceService.currentBalance(for: account, allTransactions: allRawTx)
            return FullFinancialContext.AccountEntry(
                name: account.name,
                type: account.type,
                balance: safeDouble(balance),
                currency: account.currencyCode
            )
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
            converter: converter
        )
        return FullFinancialContext.BalancesSection(
            accounts: entries,
            totalBalance: safeDouble(total),
            totalIncludesGroups: includeGroupsInTotal
        )
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
            currentYear: summarize(intervals.currentYear)
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

        // Totales por periodo de una categoría o subcategoría. `lastToDate` es la parte del mes
        // pasado hasta el día equivalente a hoy (`intervals.lastMonthToDate`, contenido en `last`).
        struct Totals {
            var current: Double = 0
            var last: Double = 0
            var lastToDate: Double = 0
            var twoBack: Double = 0
            var count: Int = 0
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

        // Top 10 categories by current month total (or last month if no current)
        let ranked = catAgg.keys.sorted { (a, b) in
            (catAgg[a]?.current ?? 0) > (catAgg[b]?.current ?? 0)
        }
        let topCats = Array(ranked.prefix(10))

        return topCats.map { catName in
            let cat = catAgg[catName] ?? Totals()

            // Subcategorías con tx > 0 en cualquiera de los 3 meses
            var subEntries: [FullFinancialContext.SubcategoryEntry] = []
            if let subDict = subAgg[catName] {
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
                        txCountCurrentMonth: val.count
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
                subcategories: subEntries
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
                                type: type
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
            )
        )
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
        calendar: Calendar,
        adjustment: GroupBridgeStatsAdjustment
    ) -> FullFinancialContext.PatternsSection {
        let last30Start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let last30Interval = DateInterval(start: last30Start, end: now)
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
        let currentMonthTx = tx.filter { $0.date >= monthStart && $0.date <= now && $0.category?.isIncome == false }
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
            let topTxs = item.txs
                .sorted { abs(adjustment.amount($0)) > abs(adjustment.amount($1)) }
                .prefix(10)
                .map { tx -> FullFinancialContext.TxLite in
                    FullFinancialContext.TxLite(
                        date: Self.isoDateFormatter.string(from: tx.date),
                        amount: safeDouble(convertAmount(tx, currencyCode: currencyCode, converter: converter, adjustment: adjustment)),
                        merchant: canonicalMerchant(tx),
                        account: tx.account?.name
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

    private func fetchTransactions(_ ctx: ModelContext, from: Date, to: Date) -> [TransactionItem] {
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate<TransactionItem> { $0.date >= from && $0.date <= to },
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
        // Pata REAL Caso A: el neto proyectado (`-myShare`, moneda preferida) difiere del monto
        // crudo → usar esa magnitud. Resto: `chatAmount` con conversión de moneda intacta.
        let adjusted = adjustment.amountInPreferredCurrency(tx)
        if adjusted != tx.amountInPreferredCurrency {
            return abs(adjusted)
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
