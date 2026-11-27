//
//  ReferenciaFotoPreLote7.swift
//  YalaTests / EficienciaFotoWidgetsArranque
//
//  Copia CONGELADA de las funciones de la foto de los widgets tal como estaban en `origin/2.3` (`a5e93673f`), antes del
//  lote 7 de eficiencia, que las pasó a filas leídas una vez (`FilaFotoWidget`). Es la referencia de la paridad: la foto
//  de hoy tiene que dar exactamente lo mismo que este código. No se mantiene: si la regla de una cifra cambia a
//  propósito, este fichero se retira junto con su test.
//

import Foundation
import SwiftData

@testable import Yala

@MainActor
enum ReferenciaFotoPreLote7 {
    static func buildPeriodSummary(
        transactions: [TransactionItem],
        periodStart: Date,
        periodEnd: Date,
        currencyCode: String,
        allTransactionsForBalance: [TransactionItem]? = nil,
        adjustment: GroupBridgeStatsAdjustment = .none,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> WidgetPeriodSummary {
        // Filter transactions for the period, excluding balance adjustments
        let periodTransactions = transactions.filter { tx in
            tx.date >= periodStart && tx.date <= periodEnd && tx.balanceAdjustmentType == nil
        }

        // Calculate totals (income-aware): suprime la pata de préstamo derivada y
        // proyecta el gasto de grupo Caso A a "mi parte".
        var totalIncome: Double = 0
        var totalExpense: Double = 0
        // Magnitudes de la parte aproximada, por lado. Suman |contribución|, nunca netos: los
        // errores de dos conversiones distintas no se cancelan entre sí (mismo razonamiento que
        // `ApproximateMarkThreshold` documenta y que `CashFlowCalculator` aplica).
        var incomeApproximateMagnitude: Double = 0
        var expenseApproximateMagnitude: Double = 0
        // Denominadores del umbral «≈»: magnitudes por lado, como `CashFlowCalculator`. Los totales van con signo desde el
        // 2026-10-23, y una devolución que los encoge disparaba el cociente (la marca). Los porcentajes de las categorías
        // tienen su propio total desde la card znu5 (`expenseBreakdownTotal`, abajo).
        var incomeTotalMagnitude: Double = 0
        var expenseTotalMagnitude: Double = 0
        // El reparto por cuenta (extragrande vertical de «Entradas y salidas») se acumula en el MISMO bucle y con la
        // misma suma, para que las cuentas sumen el neto. Las filas de producción llegan filtradas por
        // `countsForWidgets`, que exige cuenta; una sin cuenta (solo en tests que llaman aquí a pelo) no entra.
        var flowsByAccount: [PersistentIdentifier: (name: String, income: Double, expense: Double)] = [:]

        for tx in periodTransactions {
            if adjustment.isSuppressed(tx) { continue }
            // La regla de la app (`CashFlowCalculator.resolvedAmount`): el monto guardado si se
            // guardó en la divisa vigente —y entonces la señal es la del `adjustment`, que en un
            // gasto de grupo cuenta todas las patas—; si no, el nativo reconvertido con la tasa de
            // su fecha, y la señal es la de esa conversión.
            let resolved = CashFlowCalculator.resolvedAmount(
                tx, currencyCode: currencyCode, adjustment: adjustment, converter: converter
            )
            let amount = resolved.value
            let approximate = resolved.approximateMagnitude
            // Con signo, como el Flujo de caja de la app: una devolución en una categoría de gasto resta del gasto.
            let isIncome = WidgetDataCache.isIncomeTx(tx)
            if isIncome {
                totalIncome += amount
                incomeApproximateMagnitude += approximate
                incomeTotalMagnitude += abs(amount)
            } else {
                totalExpense -= amount
                expenseApproximateMagnitude += approximate
                expenseTotalMagnitude += abs(amount)
            }
            if let account = tx.account {
                var flow = flowsByAccount[account.persistentModelID] ?? (account.name, 0, 0)
                if isIncome { flow.income += amount } else { flow.expense -= amount }
                flowsByAccount[account.persistentModelID] = flow
            }
        }

        let netCashFlow = totalIncome - totalExpense
        let accountFlows = flowsByAccount
            .map { id, flow in
                WidgetAccountFlow(
                    id: id.hashValue.description,
                    name: flow.name,
                    income: flow.income,
                    expense: flow.expense,
                    net: flow.income - flow.expense
                )
            }
            // De más a menos movimiento; a igualdad, por nombre, para que el orden no dependa del diccionario.
            .sorted {
                let lhs = abs($0.income) + abs($0.expense), rhs = abs($1.income) + abs($1.expense)
                return lhs != rhs ? lhs > rhs : $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }

        // Calculate historical balance at end of period
        // This is the sum of ALL transactions up to periodEnd (not just period transactions)
        // Matches TrendDataProcessor.fillBalanceBuckets logic: la fila ENTERA en su divisa nativa, y el saldo por
        // divisa valorado al cierre del período con el tipo de cambio de ese día —o, si el período llega a hoy,
        // con la regla del saldo vivo— (`BalanceValuation`). Así el saldo de un período en el widget es el último
        // punto de la curva de la app (ticket `panel-balance-chart-contradicts-its-own-figure`).
        var periodBalance: Double = 0
        // Numerador en MAGNITUDES aunque el saldo sea una resta: los errores de dos conversiones
        // distintas no se cancelan entre sí. El denominador, en cambio, es el saldo mismo — ver el
        // comentario del `return`.
        var balanceApproximateMagnitude: Double = 0
        if let allTx = allTransactionsForBalance {
            var native: [String: Decimal] = [:]
            // Las mismas filas que el saldo vivo y que la curva del widget (`LiveBalanceCalculator.entersBalance`): un
            // movimiento sin cuenta no está en ningún saldo, y contarlo aquí separaba la cifra del último punto de la
            // curva (card `tablero-la-cifra-y-la-curva-del-widget-de-saldo-zyah`).
            // Fin exclusivo: un período que cierra en 23:59:59 (todos los de `WidgetPeriod`, los en curso desde el
            // 2026-10-25) cuenta ese último segundo; uno que cierra en medianoche, no cuenta la medianoche.
            let nextSecond = periodEnd.addingTimeInterval(1)
            let exclusiveEnd = Calendar.current.startOfDay(for: nextSecond) == nextSecond ? nextSecond : periodEnd
            for tx in allTx where tx.date < exclusiveEnd && LiveBalanceCalculator.entersBalance(tx) {
                LiveBalanceCalculator.addNative(tx, to: &native)
            }
            let closing = min(periodEnd, Date.now)
            let valuation = BalanceValuation(
                currencies: Set(native.keys), to: currencyCode, closingDates: [closing], converter: converter
            )
            let converted = valuation.value(native, at: closing)
            periodBalance = (converted.total as NSDecimalNumber).doubleValue
            balanceApproximateMagnitude = (converted.approximateMagnitude as NSDecimalNumber).doubleValue
        }

        // Las categorías del gasto, en neto y todas: su suma es el total del desglose (card znu5). La foto lleva las 20
        // primeras (las tartas grandes) y el total, para que centro, «Otros» y porcentajes se midan contra lo mismo.
        let categorySlices = categoryExpenseSlices(
            transactions: periodTransactions, currencyCode: currencyCode, adjustment: adjustment, converter: converter
        )
        let expenseBreakdownTotal = WidgetInsightsLogic.breakdownTotal(categorySlices.map(\.amount))
        let topCategories = WidgetDataCache.topCategories(from: categorySlices, breakdownTotal: expenseBreakdownTotal, limit: 20)

        // Las subcategorías, con el total de su propio desglose (top 20 para las tartas grandes).
        let subcategoryBreakdown = subcategoryExpenseBreakdown(
            transactions: periodTransactions,
            limit: 20,
            currencyCode: currencyCode,
            adjustment: adjustment,
            converter: converter
        )
        let topSubcategories = subcategoryBreakdown.rows

        // Build cash flow by day
        let cashFlowPoints = buildCashFlowByDay(
            transactions: periodTransactions,
            periodStart: periodStart,
            periodEnd: periodEnd,
            currencyCode: currencyCode,
            adjustment: adjustment,
            converter: converter
        )

        return WidgetPeriodSummary(
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            netCashFlow: netCashFlow,
            topCategories: topCategories,
            topSubcategories: topSubcategories,
            cashFlowPoints: cashFlowPoints,
            periodBalance: allTransactionsForBalance != nil ? periodBalance : nil,
            incomeIsApproximate: ApproximateMarkThreshold.marks(
                approximate: incomeApproximateMagnitude, total: incomeTotalMagnitude
            ),
            expenseIsApproximate: ApproximateMarkThreshold.marks(
                approximate: expenseApproximateMagnitude, total: expenseTotalMagnitude
            ),
            // El neto lleva la incertidumbre de los DOS lados contra el número que se muestra, no
            // el OR de las dos marcas: un ingreso grande con un 4,9 % dudoso y un gasto grande
            // exacto dejan un neto pequeño cuya incertidumbre puede superarlo, y ninguna de las
            // dos marcas por lado lo habría dicho.
            netCashFlowIsApproximate: ApproximateMarkThreshold.marks(
                approximate: incomeApproximateMagnitude + expenseApproximateMagnitude,
                total: netCashFlow
            ),
            // El denominador es el SALDO, no la facturación bruta que lo formó. `periodBalance` es
            // una resta —ingresos menos gastos de todo el histórico— y el contrato de
            // `ApproximateMarkThreshold` es explícito: cuando el número es una resta, el
            // denominador honesto es lo que el usuario ve. Con `Σ|monto|` la marca no salía casi
            // nunca y fallaba justo en quien más historial tiene: 400 dudosos sobre un saldo de 500
            // dan un 80 %, pero sobre una facturación de 300.000 dan un 0,13 %.
            periodBalanceIsApproximate: allTransactionsForBalance != nil
                ? ApproximateMarkThreshold.marks(
                    approximate: balanceApproximateMagnitude, total: periodBalance
                )
                // Sin `periodBalance` no hay número que marcar.
                : false,
            accountFlows: accountFlows,
            expenseBreakdownTotal: expenseBreakdownTotal,
            expenseSubcategoryBreakdownTotal: subcategoryBreakdown.total
        )
    }

    static func categoryExpenseSlices(
        transactions: [TransactionItem],
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment = .none,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> [(category: Yala.Category?, amount: Double)] {
        var categories: [String: Yala.Category?] = [:]
        var contributions: [(key: String, expense: Double)] = []

        for tx in transactions {
            // Skip balance adjustments
            guard tx.balanceAdjustmentType == nil else { continue }
            // Skip la pata de préstamo derivada (bridge) e income (clasif. por categoría)
            guard !adjustment.isSuppressed(tx) else { continue }
            guard !WidgetDataCache.isIncomeTx(tx) else { continue }
            let category = tx.category
            // Una clave que ningún nombre de categoría puede tener (el nombre es texto del usuario).
            let key = category?.name ?? WidgetDataCache.uncategorizedWidgetKey
            if categories[key] == nil { categories[key] = .some(category) }
            // Con signo, como el total del período: el gasto aporta en positivo y la devolución resta.
            let value = CashFlowCalculator.resolvedAmount(
                tx, currencyCode: currencyCode, adjustment: adjustment, converter: converter
            ).value
            contributions.append((key: key, expense: -value))
        }

        return WidgetInsightsLogic.netExpenseSlices(contributions).map { slice in
            (category: categories[slice.key] ?? nil, amount: slice.amount)
        }
    }

    static func subcategoryExpenseBreakdown(
        transactions: [TransactionItem],
        limit: Int,
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment = .none,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> (rows: [WidgetSubcategory], total: Double) {
        var subcategories: [String: (subcategory: Subcategory, category: Yala.Category)] = [:]
        var contributions: [(key: String, expense: Double)] = []

        for tx in transactions {
            // Skip balance adjustments
            guard tx.balanceAdjustmentType == nil else { continue }
            // Skip la pata de préstamo derivada (bridge) e income (clasif. por categoría)
            guard !adjustment.isSuppressed(tx) else { continue }
            guard !WidgetDataCache.isIncomeTx(tx) else { continue }
            let key: String
            if let subcategory = tx.subcategory, let category = tx.category {
                key = "\(category.name)_\(subcategory.name)"
                if subcategories[key] == nil { subcategories[key] = (subcategory, category) }
            } else if let category = tx.category {
                // Sin subcategoría: su resto, por categoría (una clave que ningún nombre puede dar).
                key = "\u{1}rest_\(category.name)"
            } else {
                key = WidgetDataCache.uncategorizedWidgetKey
            }
            let value = CashFlowCalculator.resolvedAmount(
                tx, currencyCode: currencyCode, adjustment: adjustment, converter: converter
            ).value
            contributions.append((key: key, expense: -value))
        }

        let slices = WidgetInsightsLogic.netExpenseSlices(contributions)
        let total = WidgetInsightsLogic.breakdownTotal(slices.map(\.amount))
        let rows: [WidgetSubcategory] = slices.compactMap { slice in
            guard let item = subcategories[slice.key] else { return nil }
            return WidgetSubcategory(
                id: item.subcategory.persistentModelID.hashValue.description,
                name: item.subcategory.name,
                categoryName: item.category.name,
                iconName: item.subcategory.iconName ?? item.category.iconName,
                colorHex: item.category.colorHex,
                amount: slice.amount,
                percentage: WidgetInsightsLogic.breakdownPercentage(slice.amount, of: total)
            )
        }
        return (Array(rows.prefix(limit)), total)
    }

    static func buildCashFlowByDay(
        transactions: [TransactionItem],
        periodStart: Date,
        periodEnd: Date,
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment = .none,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> [WidgetCashFlowPoint] {
        let calendar = Calendar.current

        // Group transactions by day
        var dailyData: [Date: (income: Double, expense: Double)] = [:]

        for tx in transactions {
            // Skip balance adjustments
            guard tx.balanceAdjustmentType == nil else { continue }
            // Suprime la pata de préstamo derivada (bridge): mata el ingreso fantasma +lent.
            if adjustment.isSuppressed(tx) { continue }

            let day = calendar.startOfDay(for: tx.date)
            let rawAmount = CashFlowCalculator.resolvedAmount(
                tx, currencyCode: currencyCode, adjustment: adjustment, converter: converter
            ).value

            var existing = dailyData[day] ?? (income: 0, expense: 0)
            // Con signo, como los totales del período (`buildPeriodSummary`).
            if WidgetDataCache.isIncomeTx(tx) {
                existing.income += rawAmount
            } else {
                existing.expense -= rawAmount
            }
            dailyData[day] = existing
        }

        // Build points for each day in period
        // For very long periods (allTime), only include days with actual transactions
        // to avoid generating millions of empty points
        var points: [WidgetCashFlowPoint] = []

        // Aquí no es un denominador sino un umbral, así que el día perdido solo importa en la
        // frontera exacta; se normaliza igual porque es la misma instancia del patrón y dejar una suelta
        // es lo que hace que el próximo barrido la encuentre como si fuera nueva.
        let daysBetween = DateIntervalDayCount.days(
            from: periodStart, to: periodEnd, calendar: calendar)
        let isLongPeriod = daysBetween > 365  // More than 1 year

        if isLongPeriod {
            // For long periods, only include days that have data
            for (day, data) in dailyData {
                points.append(WidgetCashFlowPoint(
                    date: day,
                    income: data.income,
                    expense: data.expense,
                    net: data.income - data.expense
                ))
            }
            points.sort { $0.date < $1.date }
        } else {
            // For short periods, fill in all days (including empty ones)
            var currentDate = calendar.startOfDay(for: periodStart)
            let endDay = calendar.startOfDay(for: periodEnd)

            while currentDate <= endDay {
                let data = dailyData[currentDate] ?? (income: 0, expense: 0)
                points.append(WidgetCashFlowPoint(
                    date: currentDate,
                    income: data.income,
                    expense: data.expense,
                    net: data.income - data.expense
                ))

                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = nextDay
            }
        }

        return points
    }

    static func buildTrendData(
        transactions: [TransactionItem],
        totalBalance: Double,
        currencyCode: String,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> WidgetTrendData {
        let calendar = Calendar.current

        // Lo que cambió cada día, en divisa NATIVA. Cada punto es el saldo al cierre de su día (o de su semana o
        // mes) valorado con el tipo de cambio de esa fecha, la regla de la curva de la app (`BalanceValuation`,
        // `panel-balance-chart-contradicts-its-own-figure`). El punto de hoy es `totalBalance`, el saldo vivo.
        var nativeByDay: [Date: [String: Decimal]] = [:]
        var totalNative: [String: Decimal] = [:]
        // Solo las filas que entran en un saldo, como el saldo vivo (`LiveBalanceCalculator.entersBalance`): si no, el
        // punto de hoy —que es ese saldo— y los de antes contarían filas distintas y la curva pintaría un escalón en hoy.
        for tx in transactions where LiveBalanceCalculator.entersBalance(tx) {
            let day = calendar.startOfDay(for: tx.date)
            LiveBalanceCalculator.addNative(tx, to: &nativeByDay[day, default: [:]])
            LiveBalanceCalculator.addNative(tx, to: &totalNative)
        }

        // Find the earliest transaction date to avoid showing flat line before data exists
        let earliestTransactionDate = transactions.map(\.date).min()
        let daysOfData: Int
        if let earliest = earliestTransactionDate {
            // Acotado a 0: si todo el libro es futuro (lo más antiguo es de mañana o después), la cuenta sale negativa
            // y `0..<días` revienta el proceso. La curva empieza hoy, como con un libro vacío.
            daysOfData = max(0, calendar.dateComponents([.day], from: earliest, to: Date.now).day ?? 90)
        } else {
            daysOfData = 0
        }

        let dailyDays = min(daysOfData + 1, 90)  // +1 to include the first transaction day
        let weeklyPeriods = min((daysOfData / 7) + 1, 104)
        let monthlyPeriods = min((daysOfData / 30) + 1, 120)

        let dailyClosings = dailyTrendClosings(days: dailyDays, calendar: calendar)
        let weeklyClosings = aggregatedTrendClosings(periods: weeklyPeriods, component: .weekOfYear, calendar: calendar)
        let monthlyClosings = aggregatedTrendClosings(periods: monthlyPeriods, component: .month, calendar: calendar)
        let valuation = BalanceValuation(
            currencies: Set(totalNative.keys),
            to: currencyCode,
            closingDates: (dailyClosings + weeklyClosings + monthlyClosings).map(\.closing),
            converter: converter,
            calendar: calendar
        )

        func points(_ closings: [(date: Date, closing: Date)]) -> [WidgetTrendPoint] {
            closings.map { entry in
                // El primero es hoy: el saldo vivo tal cual, que es el número que pinta el widget al lado.
                if entry.closing >= calendar.startOfDay(for: Date.now) {
                    return WidgetTrendPoint(date: entry.date, balance: totalBalance)
                }
                var native = totalNative
                for (day, delta) in nativeByDay where day > entry.closing {
                    for (code, amount) in delta { native[code, default: 0] -= amount }
                }
                return WidgetTrendPoint(date: entry.date, balance: valuation.doubleValue(native, at: entry.closing))
            }.reversed()
        }

        return WidgetTrendData(
            dailyPoints: points(dailyClosings),
            weeklyPoints: points(weeklyClosings),
            monthlyPoints: points(monthlyClosings)
        )
    }

    /// Los días de la curva diaria, de hoy hacia atrás: cada punto lleva la fecha del día y cierra al final de él.
    static func dailyTrendClosings(days: Int, calendar: Calendar) -> [(date: Date, closing: Date)] {
        (0..<days).compactMap { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date.now) else { return nil }
            let day = calendar.startOfDay(for: date)
            let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            return (day, min(next.addingTimeInterval(-1), Date.now))
        }
    }

    /// Las semanas o meses de la curva, del actual hacia atrás: cada punto lleva la fecha de inicio del periodo y
    /// cierra al final de él (el actual, ahora).
    static func aggregatedTrendClosings(
        periods: Int, component: Calendar.Component, calendar: Calendar
    ) -> [(date: Date, closing: Date)] {
        let today = Date.now
        let currentPeriodStart: Date
        if component == .weekOfYear {
            currentPeriodStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        } else {
            currentPeriodStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        }
        return (0..<periods).compactMap { periodIndex in
            guard let periodStart = calendar.date(byAdding: component, value: -periodIndex, to: currentPeriodStart),
                  let periodEnd = calendar.date(byAdding: component, value: 1, to: periodStart)
            else { return nil }
            return (periodStart, min(periodEnd.addingTimeInterval(-1), today))
        }
    }
}
