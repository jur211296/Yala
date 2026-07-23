//
//  FinancialScoreCalculator.swift
//  Yala
//
//  Financial Score period-aware (Panel 2.0 + Statistics → Insights).
//
//  Invariantes:
//  - Sub-scores `Int?`. `nil` no diluye el total; el resto re-pondera. Todos
//    `nil` → total `nil`.
//  - Composite con piso suave de 50 (brand-voice). Sub-scores sin piso.
//  - Compromisos opera sobre el ciclo natural completo del período (no truncado
//    a hoy) para incluir pendientes del resto del mes/año.
//

import Foundation

struct FinancialScore: Equatable {
    /// Composite score (0–100) o `nil` cuando todos los sub-scores son `nil`.
    let total: Int?

    /// Presupuestos (0–100) o `nil` cuando no hay buckets aplicables al período.
    let budget: Int?

    /// Ritmo (0–100) o `nil` cuando no hay transacciones en el intervalo.
    /// Mantiene el nombre de propiedad `activity` por compatibilidad con la UI/L10n.
    let activity: Int?

    /// Compromisos (0–100) o `nil` para períodos cortos / sin pagos activos.
    /// Mantiene el nombre de propiedad `bills` por compatibilidad con la UI/L10n.
    let bills: Int?
}

enum FinancialScoreCalculator {

    // MARK: - Tuning

    /// Soft floor del total para no mostrar números desalentadores en escenarios extremos.
    private static let totalSoftFloor = 50

    /// Pesos del composite (re-normalizados cuando algún sub-score es `nil`).
    private static let weightBudget       = 0.40
    private static let weightRhythm       = 0.25
    private static let weightCommitments  = 0.35

    // Budget penalties por bucket (réplica de la lógica monthly anterior aplicada localmente).
    private static let budgetPenaltyExceeded     = 8
    private static let budgetPenaltyNearAndLate  = 3
    private static let budgetBonusUnder75        = 2
    private static let budgetBonusCap            = 10

    // Ritmo: curva lineal con tolerancia. score = 100 − max(0, gap − 2) × 12.
    private static let rhythmTolerance = 2
    private static let rhythmSlope     = 12

    // Cobertura: ratio del saldo proyectado vs pendientes que produce score 100.
    private static let coverageFullMargin = 1.0  // 0..1× ⇒ 70..100; ≥1× ⇒ 100.

    // MARK: - Public API

    /// Computes the composite financial score for the selected period.
    ///
    /// - Parameters:
    ///   - transactions: Todas las transacciones (filtradas internamente por período/buckets).
    ///   - budgets: Presupuestos activos.
    ///   - scheduledPayments: Pagos programados (filtrados por `isActive` aquí).
    ///   - accounts: Cuentas (para `LiveBalanceCalculator` en Compromisos).
    ///   - paidAmounts: Mapa `[paymentID: [PaidOccurrenceInfo]]` para el rango del período.
    ///   - period: Período seleccionado por el usuario.
    ///   - customRange: Rango cuando `period == .custom`.
    ///   - preferredCurrencyCode: Moneda preferida (Compromisos convierte montos al TC actual).
    ///   - converter: `CurrencyConverting` (default `.shared`).
    ///   - now: Fecha de referencia (inyectable para tests).
    ///   - calendar: Calendar para month/day boundaries.
    static func calculate(
        transactions: [TransactionItem],
        budgets: [Budget],
        scheduledPayments: [ScheduledPayment],
        accounts: [Account],
        paidAmounts: [String: [PaidOccurrenceInfo]],
        period: DetailPeriod,
        customRange: DateInterval? = nil,
        preferredCurrencyCode: String,
        converter: CurrencyConverting = CurrencyConverter.shared,
        now: Date = .now,
        calendar: Calendar = .current,
        includeBridgedGroupTx: Bool = true,
        adjustment: GroupBridgeStatsAdjustment = .none
    ) -> FinancialScore {
        let interval = period.dateInterval(customRange: customRange, now: now)
        let intervalTransactions = transactions.filter {
            interval.contains($0.date) && BridgedTransactionFilter.shouldInclude(
                splitExpenseID: $0.splitExpenseID,
                splitSettlementID: $0.splitSettlementID,
                includeGroupsToggle: includeBridgedGroupTx
            )
        }

        let budget = calculateBudget(
            budgets: budgets,
            transactions: transactions,
            interval: interval,
            now: now,
            calendar: calendar,
            adjustment: adjustment
        )
        let rhythm = calculateRhythm(
            transactions: intervalTransactions,
            interval: interval,
            period: period,
            calendar: calendar
        )
        let commitments = calculateCommitments(
            scheduledPayments: scheduledPayments,
            paidAmounts: paidAmounts,
            transactions: transactions,
            accounts: accounts,
            interval: interval,
            period: period,
            preferredCurrencyCode: preferredCurrencyCode,
            converter: converter,
            now: now,
            calendar: calendar,
            adjustment: adjustment
        )
        let total = computeTotal(budget: budget, rhythm: rhythm, commitments: commitments)
        return FinancialScore(total: total, budget: budget, activity: rhythm, bills: commitments)
    }

    // MARK: - Weighted total con re-normalización

    private static func computeTotal(budget: Int?, rhythm: Int?, commitments: Int?) -> Int? {
        var weightedSum: Double = 0
        var totalWeight: Double = 0

        if let budget {
            weightedSum += Double(budget) * weightBudget
            totalWeight += weightBudget
        }
        if let rhythm {
            weightedSum += Double(rhythm) * weightRhythm
            totalWeight += weightRhythm
        }
        if let commitments {
            weightedSum += Double(commitments) * weightCommitments
            totalWeight += weightCommitments
        }
        guard totalWeight > 0 else { return nil }

        let raw = weightedSum / totalWeight
        let floored = max(Double(totalSoftFloor), raw)
        return clamp(Int(floored.rounded()))
    }

    // MARK: - Budget sub-score (period-aware con buckets ponderados)

    private static func calculateBudget(
        budgets: [Budget],
        transactions: [TransactionItem],
        interval: DateInterval,
        now: Date,
        calendar: Calendar,
        adjustment: GroupBridgeStatsAdjustment
    ) -> Int? {
        guard !budgets.isEmpty else { return nil }

        var bucketScores: [Int] = []

        for budget in budgets {
            guard budget.limitAmount > 0 else { continue }
            let buckets = generateBuckets(for: budget, withinInterval: interval, calendar: calendar)
            for bucket in buckets {
                guard bucketIsValid(bucket, for: budget, calendar: calendar) else { continue }
                let spending = BudgetsViewModel.calculateSpending(
                    budget: budget, transactions: transactions, interval: bucket, adjustment: adjustment
                )
                let score = scoreForBucket(
                    spending: spending,
                    limit: budget.limitAmount,
                    bucket: bucket,
                    now: now,
                    calendar: calendar
                )
                bucketScores.append(score)
            }
        }

        guard !bucketScores.isEmpty else { return nil }
        let avg = bucketScores.reduce(0, +) / bucketScores.count
        return clamp(avg)
    }

    /// Para `unique`, el bucket = rango del propio budget. Para los demás,
    /// exige `bucket.start >= startOfDay(createdAt)`.
    private static func bucketIsValid(
        _ bucket: DateInterval, for budget: Budget, calendar: Calendar
    ) -> Bool {
        if budget.periodType == BudgetPeriodType.unique.rawValue {
            return true
        }
        let createdDay = calendar.startOfDay(for: budget.createdAt)
        return bucket.start >= createdDay
    }

    /// Buckets aplicables al período según `budget.periodType`.
    private static func generateBuckets(
        for budget: Budget, withinInterval interval: DateInterval, calendar: Calendar
    ) -> [DateInterval] {
        guard let periodType = BudgetPeriodType(rawValue: budget.periodType) else { return [] }
        switch periodType {
        case .monthly:
            return enumerateBuckets(component: .month, interval: interval, calendar: calendar)
        case .weekly:
            return enumerateBuckets(component: .weekOfYear, interval: interval, calendar: calendar)
        case .yearly:
            return enumerateBuckets(component: .year, interval: interval, calendar: calendar)
        case .unique:
            guard let start = budget.startDate, let end = budget.endDate, start < end else { return [] }
            let bucket = DateInterval(start: start, end: end)
            return interval.intersects(bucket) ? [bucket] : []
        }
    }

    /// Genera todos los ciclos `component` que intersectan `interval`.
    private static func enumerateBuckets(
        component: Calendar.Component, interval: DateInterval, calendar: Calendar
    ) -> [DateInterval] {
        var result: [DateInterval] = []
        guard var cycleStart = calendar.dateInterval(of: component, for: interval.start)?.start else {
            return []
        }
        while cycleStart < interval.end {
            guard let cycle = calendar.dateInterval(of: component, for: cycleStart) else { break }
            result.append(cycle)
            guard let next = calendar.date(byAdding: component, value: 1, to: cycleStart) else { break }
            cycleStart = next
        }
        return result
    }

    /// Lógica de score per-bucket — aplicada localmente (réplica del cálculo monthly anterior).
    /// - exceeded (≥100%): penalty 8 → 92.
    /// - 90-100% en bucket en curso con `remainingRatio < 0.3`: penalty 3 → 97.
    /// - <75% en bucket cerrado o segunda mitad: bonus 2 (cap 10).
    private static func scoreForBucket(
        spending: Double, limit: Double, bucket: DateInterval, now: Date, calendar: Calendar
    ) -> Int {
        var score = 100
        var bonusAccumulated = 0
        let ratio = spending / limit

        let totalDays = max(1, calendar.dateComponents([.day], from: bucket.start, to: bucket.end).day ?? 30)
        let isClosed = bucket.end <= now
        let daysElapsed = max(0, calendar.dateComponents([.day], from: bucket.start, to: now).day ?? 0)
        let daysRemaining = max(0, totalDays - daysElapsed)
        let remainingRatio = isClosed ? 0 : Double(daysRemaining) / Double(totalDays)
        let isSecondHalf = isClosed || daysElapsed >= totalDays / 2

        if ratio >= 1.0 {
            score -= budgetPenaltyExceeded
        } else if ratio >= 0.9, remainingRatio < 0.3 {
            score -= budgetPenaltyNearAndLate
        } else if ratio < 0.75, isSecondHalf, bonusAccumulated < budgetBonusCap {
            let add = min(budgetBonusUnder75, budgetBonusCap - bonusAccumulated)
            score += add
            bonusAccumulated += add
        }
        return clamp(score)
    }

    // MARK: - Rhythm sub-score (antes Activity)

    private static func calculateRhythm(
        transactions: [TransactionItem],
        interval: DateInterval,
        period: DetailPeriod,
        calendar: Calendar
    ) -> Int? {
        let nonAdjustment = transactions
            .filter { $0.balanceAdjustmentType == nil }
            .sorted { $0.date < $1.date }
        guard !nonAdjustment.isEmpty else { return nil }

        let useMonthlyAvg = shouldUseMonthlyAverage(
            period: period, interval: interval, calendar: calendar
        )

        let gap: Double
        if useMonthlyAvg {
            let monthlyGaps = computeMonthlyMaxGaps(
                transactions: nonAdjustment, calendar: calendar
            )
            guard !monthlyGaps.isEmpty else { return nil }
            gap = Double(monthlyGaps.reduce(0, +)) / Double(monthlyGaps.count)
        } else {
            gap = Double(computeMaxGap(transactions: nonAdjustment, calendar: calendar))
        }

        let raw = 100.0 - max(0.0, gap - Double(rhythmTolerance)) * Double(rhythmSlope)
        return clamp(Int(raw.rounded()))
    }

    /// Períodos multi-mes ⇒ promedio de gaps mensuales (evita que un gap antiguo
    /// aplaste el score absoluto).
    private static func shouldUseMonthlyAverage(
        period: DetailPeriod, interval: DateInterval, calendar: Calendar
    ) -> Bool {
        switch period {
        case .thisYear, .lastYear, .allTime: return true
        case .custom:
            let months = calendar.dateComponents([.month], from: interval.start, to: interval.end).month ?? 0
            return months >= 2
        default: return false
        }
    }

    /// maxGap en días entre transacciones consecutivas (excluye balance adjustments).
    /// Días consecutivos = 0 días sin registrar.
    private static func computeMaxGap(
        transactions: [TransactionItem], calendar: Calendar
    ) -> Int {
        let days = transactions.map { calendar.startOfDay(for: $0.date) }
        let unique = Array(Set(days)).sorted()
        guard unique.count > 1 else { return 0 }
        var maxGap = 0
        for i in 1..<unique.count {
            let diff = calendar.dateComponents([.day], from: unique[i-1], to: unique[i]).day ?? 0
            maxGap = max(maxGap, diff - 1)
        }
        return maxGap
    }

    /// Agrupa tx por `(year, month)` y devuelve el array de maxGap por mes.
    /// Meses sin transacciones no contribuyen.
    private static func computeMonthlyMaxGaps(
        transactions: [TransactionItem], calendar: Calendar
    ) -> [Int] {
        let grouped = Dictionary(grouping: transactions) { tx -> DateComponents in
            calendar.dateComponents([.year, .month], from: tx.date)
        }
        return grouped.values.map { computeMaxGap(transactions: $0, calendar: calendar) }
    }

    // MARK: - Commitments sub-score (antes Bills)

    private static func calculateCommitments(
        scheduledPayments: [ScheduledPayment],
        paidAmounts: [String: [PaidOccurrenceInfo]],
        transactions: [TransactionItem],
        accounts: [Account],
        interval: DateInterval,
        period: DetailPeriod,
        preferredCurrencyCode: String,
        converter: CurrencyConverting,
        now: Date,
        calendar: Calendar,
        adjustment: GroupBridgeStatsAdjustment
    ) -> Int? {
        if isShortPeriod(period) { return nil }

        let active = scheduledPayments.filter {
            $0.isActive && $0.transactionType != TransactionType.income.rawValue
        }
        guard !active.isEmpty else { return nil }

        // Compromisos opera sobre el CICLO NATURAL completo del período (no
        // truncado a hoy como hace `period.dateInterval` para `.thisMonth`/
        // `.thisYear`). Si el usuario está a mitad de mes y miramos `thisMonth`,
        // los pagos pendientes del resto del mes deben contar.
        let cmtInterval = Self.commitmentsInterval(
            period: period, fallback: interval, now: now, calendar: calendar
        )

        // 1. Cobertura
        let pendingTotal = sumPendingPayments(
            active: active,
            paidAmounts: paidAmounts,
            interval: cmtInterval,
            preferredCurrencyCode: preferredCurrencyCode,
            converter: converter,
            calendar: calendar
        )
        let liveBalance = LiveBalanceCalculator.liveBalance(
            accounts: accounts,
            transactions: transactions,
            preferredCurrencyCode: preferredCurrencyCode,
            converter: converter
        )
        let coverageScore = computeCoverageScore(
            liveBalance: liveBalance, pendingTotal: pendingTotal
        )

        // 2. Carga
        let income = sumIncomeTransactions(transactions, interval: cmtInterval, adjustment: adjustment)
        let loadScore = computeLoadScore(
            commitmentsTotal: pendingTotal, income: income
        )

        let composite = (coverageScore + loadScore) / 2.0
        return clamp(Int(composite.rounded()))
    }

    /// Intervalo natural del período para Compromisos. `.thisMonth` → mes
    /// calendario completo (no truncado a hoy); `.thisYear` → año completo.
    /// Otros períodos retornan el `fallback` recibido (ya cerrado o no aplica).
    /// Expuesto como `static` para que los callers (PanelViewModel,
    /// DetailContainerView) carguen `paidAmounts` para el mismo rango.
    static func commitmentsInterval(
        period: DetailPeriod, fallback: DateInterval, now: Date = .now, calendar: Calendar = .current
    ) -> DateInterval {
        switch period {
        case .thisMonth:
            guard let monthInterval = calendar.dateInterval(of: .month, for: now) else { return fallback }
            return monthInterval
        case .thisYear:
            guard let yearInterval = calendar.dateInterval(of: .year, for: now) else { return fallback }
            return yearInterval
        default:
            return fallback
        }
    }

    private static func computeCoverageScore(liveBalance: Double, pendingTotal: Double) -> Double {
        if pendingTotal <= 0 { return 100 }
        let projected = liveBalance - pendingTotal
        if projected < 0 {
            // Negativo: ratio en (-∞, 0). ratio = -1 ⇒ score 0.
            let ratio = projected / pendingTotal
            return max(0, 50 + ratio * 50)
        }
        // Positivo: 0 ⇒ 70, hasta margin 1.0× ⇒ 100.
        let ratio = projected / pendingTotal
        return min(100, 70 + min(ratio, coverageFullMargin) * 30)
    }

    private static func computeLoadScore(commitmentsTotal: Double, income: Double) -> Double {
        guard income > 0 else { return 50 }  // sin datos de ingreso → neutral.
        let ratio = commitmentsTotal / income
        switch ratio {
        case ..<0.3:  return 100 - (ratio / 0.3) * 20             // 0..0.3 ⇒ 100..80
        case ..<0.5:  return 80 - ((ratio - 0.3) / 0.2) * 20      // 0.3..0.5 ⇒ 80..60
        case ..<0.7:  return 60 - ((ratio - 0.5) / 0.2) * 30      // 0.5..0.7 ⇒ 60..30
        case ..<1.0:  return 30 - ((ratio - 0.7) / 0.3) * 30      // 0.7..1.0 ⇒ 30..0
        default:      return 0
        }
    }

    /// Períodos cortos donde Compromisos no aporta (pagos son típicamente mensuales).
    private static func isShortPeriod(_ period: DetailPeriod) -> Bool {
        switch period {
        case .thisWeek, .last7Days: return true
        default: return false
        }
    }

    /// Suma pagos pendientes (no pagados, no skipped) en `interval`, convertidos a moneda preferida.
    /// Itera mes por mes dentro del intervalo (el `ScheduledPaymentDateCalculator` solo soporta month).
    private static func sumPendingPayments(
        active: [ScheduledPayment],
        paidAmounts: [String: [PaidOccurrenceInfo]],
        interval: DateInterval,
        preferredCurrencyCode: String,
        converter: CurrencyConverting,
        calendar: Calendar
    ) -> Double {
        var total: Double = 0

        for payment in active {
            var paidRemaining = paidAmounts[payment.id.uuidString]?.count ?? 0
            let occurrences = enumerateOccurrences(
                payment: payment, interval: interval, calendar: calendar
            )

            for date in occurrences {
                if payment.isDateSkipped(date) { continue }
                if paidRemaining > 0 {
                    paidRemaining -= 1
                    continue
                }
                let converted = converter.convertWithLatestRate(
                    Decimal(abs(payment.amount)),
                    from: payment.currencyCode,
                    to: preferredCurrencyCode
                )
                total += NSDecimalNumber(decimal: converted).doubleValue
            }
        }
        return total
    }

    /// Suma ingresos del período (excluye balance adjustments). Income-aware: suprime las patas
    /// de préstamo derivadas del bridge de grupos (ingreso fantasma +lent) y netea la pata real.
    private static func sumIncomeTransactions(
        _ transactions: [TransactionItem], interval: DateInterval,
        adjustment: GroupBridgeStatsAdjustment
    ) -> Double {
        transactions
            .filter {
                interval.contains($0.date)
                    && $0.balanceAdjustmentType == nil
                    && ($0.category?.isIncome ?? false)
                    && !adjustment.isSuppressed($0)
            }
            .reduce(0) { $0 + abs(adjustment.amountInPreferredCurrency($1)) }
    }

    /// Itera occurrences mes por mes dentro del intervalo, filtrando al rango exacto.
    private static func enumerateOccurrences(
        payment: ScheduledPayment, interval: DateInterval, calendar: Calendar
    ) -> [Date] {
        var result: [Date] = []
        guard var cursor = calendar.dateInterval(of: .month, for: interval.start)?.start else {
            return []
        }
        while cursor < interval.end {
            let monthDates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                params: payment.dateCalculatorParams,
                month: cursor,
                calendar: calendar
            )
            for date in monthDates where interval.contains(date) {
                result.append(date)
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result.sorted()
    }

    // MARK: - Utilities

    private static func clamp(_ value: Int, min: Int = 0, max: Int = 100) -> Int {
        Swift.max(min, Swift.min(max, value))
    }
}
