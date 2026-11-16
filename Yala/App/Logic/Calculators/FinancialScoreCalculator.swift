//
//  FinancialScoreCalculator.swift
//  Yala
//
//  Financial Score period-aware (Panel 2.0 + Statistics → Insights).
//
//  Invariantes:
//  - Sub-scores `Int?`. `nil` no diluye el total; el resto re-pondera. Con menos
//    de dos partes con datos → total `nil` (decisión 9 de la revisión 2.3, PN-2:
//    una sola parte daba 100 con pocos datos).
//  - Sin suelo: la nota va de 0 a 100, como dice Configurar Panel (lote 1 de la nota de salud, 11-nov-2026). La
//    amabilidad está en las curvas: 3 días de gracia en Ritmo y una bajada suave al pasarse de un presupuesto.
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

    /// Lo que va mal hoy y la nota mira o no (decisión 9 de la revisión 2.3, PN-2 · B). Vacío si el período no
    /// incluye hoy.
    var alerts = FinancialScoreAlerts()

    /// Las partes sin datos, en el orden de la tarjeta.
    var partsWithoutData: [FinancialScoreDetailKind] {
        [(FinancialScoreDetailKind.budget, budget), (.activity, activity), (.bills, bills)]
            .filter { $0.1 == nil }
            .map(\.0)
    }
}

enum FinancialScoreCalculator {

    /// La parte que más sube el total si llega a 100 (UX 2.2 · L3-14): lo que le falta, por su peso. No siempre es la
    /// de nota más baja: con Presupuestos 80 y Ritmo 75, Presupuestos suma 8 puntos y Ritmo 6,25. A igualdad, la de nota
    /// más baja. `nil` si no hay ninguna con nota o si todas van bien (90 o más).
    static func weakestPart(of score: FinancialScore) -> FinancialScoreDetailKind? {
        let parts: [(FinancialScoreDetailKind, Int?, Double)] = [
            (.budget, score.budget, weightBudget),
            (.activity, score.activity, weightRhythm),
            (.bills, score.bills, weightCommitments)
        ]
        let candidates = parts.compactMap { kind, value, weight -> (FinancialScoreDetailKind, Int, Double)? in
            guard let value, value < 90 else { return nil }
            return (kind, value, Double(100 - value) * weight)
        }
        let best = candidates.max { lhs, rhs in
            lhs.2 == rhs.2 ? lhs.1 > rhs.1 : lhs.2 < rhs.2
        }
        return best?.0
    }

    // MARK: - Tuning

    /// Pesos del composite (re-normalizados cuando algún sub-score es `nil`). Visibles: la hoja de la nota los enseña
    /// (UX 2.2 · L3-14), y así no pueden divergir de lo que se calcula.
    static let weightBudget       = 0.40
    static let weightRhythm       = 0.25
    static let weightCommitments  = 0.35

    /// Partes con datos que hacen falta para dar una nota (decisión 9 de la revisión 2.3, PN-2 · A: «dos de tres»).
    /// Con una sola, la nota era esa parte re-ponderada al 100 % y daba 100 con dos registros.
    static let minimumPartsForTotal = 2

    // Presupuestos: rozar el límite al final del ciclo resta 3. Pasarse resta según cuánto (lote 1 de la nota de
    // salud): 100 − 70 × exceso², con el exceso sobre el límite topado en el doble. Pasarse un 10 % resta 1; un 50 %, 18;
    // el doble, 70 → 30, que es el suelo de UN presupuesto: ninguno solo hunde la nota total.
    private static let budgetPenaltyNearAndLate  = 3
    static let budgetOverspendCurve              = 70.0
    static let budgetOverspendFloor              = 30

    // Ritmo: 3 días de gracia y luego 8 puntos por día, en línea recta. score = 100 − max(0, hueco − 3) × 8.
    // El hueco incluye los días desde el último registro hasta hoy en un período en curso (lote 1 de la nota de salud).
    static let rhythmGraceDays = 3
    static let rhythmSlope     = 8

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
            lastRecordDate: lastRecordDate(
                transactions: transactions,
                interval: interval,
                now: now,
                includeBridgedGroupTx: includeBridgedGroupTx
            ),
            interval: interval,
            period: period,
            now: now,
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
        let alerts = FinancialScoreAlertsLogic.alerts(
            transactions: transactions,
            budgets: budgets,
            accounts: accounts,
            periodInterval: interval,
            now: now,
            calendar: calendar,
            adjustment: adjustment,
            converter: converter
        )
        return FinancialScore(total: total, budget: budget, activity: rhythm, bills: commitments, alerts: alerts)
    }

    // MARK: - Weighted total con re-normalización

    private static func computeTotal(budget: Int?, rhythm: Int?, commitments: Int?) -> Int? {
        let partsWithData = [budget, rhythm, commitments].compactMap { $0 }.count
        guard partsWithData >= minimumPartsForTotal else { return nil }

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
        return clamp(Int(raw.rounded()))
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
                // El gasto se cuenta en el bucket CERRADO en su último segundo: `bucket` termina en la
                // medianoche del siguiente y un gasto de ese instante contaba en los dos.
                let spending = BudgetsViewModel.calculateSpending(
                    budget: budget,
                    transactions: transactions,
                    interval: BudgetPeriodInterval.closing(bucket, calendar: calendar),
                    adjustment: adjustment
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
    /// exige `bucket.start >= startOfDay(createdAt)`. Interno: las alertas de la nota lo usan para decir si un
    /// presupuesto pasado cuenta en ella (`FinancialScoreAlertsLogic`).
    static func bucketIsValid(
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
            guard let start = budget.startDate, let end = budget.endDate,
                  calendar.startOfDay(for: start) <= calendar.startOfDay(for: end) else { return [] }
            // Días enteros, como en Presupuestos (`BudgetPeriodInterval.unique`).
            let bucket = BudgetPeriodInterval.unique(start: start, end: end, calendar: calendar)
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

    /// La nota de un ciclo de un presupuesto.
    /// - Hasta el límite: 100; entre el 90 % y el 100 % con menos del 30 % del ciclo por delante, 97.
    /// - Pasado el límite: `overspendScore` (curva suave, suelo 30).
    private static func scoreForBucket(
        spending: Double, limit: Double, bucket: DateInterval, now: Date, calendar: Calendar
    ) -> Int {
        let ratio = spending / limit
        if ratio > 1.0 { return overspendScore(ratio: ratio) }

        let totalDays = max(1, calendar.dateComponents([.day], from: bucket.start, to: bucket.end).day ?? 30)
        let isClosed = bucket.end <= now
        let daysElapsed = max(0, calendar.dateComponents([.day], from: bucket.start, to: now).day ?? 0)
        let daysRemaining = max(0, totalDays - daysElapsed)
        let remainingRatio = isClosed ? 0 : Double(daysRemaining) / Double(totalDays)

        if ratio >= 0.9, remainingRatio < 0.3 {
            return 100 - budgetPenaltyNearAndLate
        }
        return 100
    }

    /// Pasarse de un presupuesto pesa según cuánto: `100 − 70 × exceso²`, con el exceso (lo gastado sobre el límite,
    /// en veces el límite) topado en 1 y la nota en 30. Pasarse un poco casi no resta; el castigo fuerte llega cerca
    /// del doble. Interno para los tests.
    static func overspendScore(ratio: Double) -> Int {
        let excess = min(max(ratio - 1.0, 0), 1.0)
        let raw = 100.0 - budgetOverspendCurve * excess * excess
        return max(budgetOverspendFloor, clamp(Int(raw.rounded())))
    }

    // MARK: - Rhythm sub-score (antes Activity)

    /// El último día con un registro real (sin ajustes de saldo ni transferencias) hasta el fin del período y hasta
    /// hoy, mirando TODO el historial: quien dejó de registrar antes de que empezara el período sigue teniendo un
    /// hueco que cuenta. `nil` si nunca registró nada.
    private static func lastRecordDate(
        transactions: [TransactionItem],
        interval: DateInterval,
        now: Date,
        includeBridgedGroupTx: Bool
    ) -> Date? {
        let limit = min(interval.end, now)
        return transactions
            .filter {
                $0.balanceAdjustmentType == nil && $0.date <= limit && BridgedTransactionFilter.shouldInclude(
                    splitExpenseID: $0.splitExpenseID,
                    splitSettlementID: $0.splitSettlementID,
                    includeGroupsToggle: includeBridgedGroupTx
                )
            }
            .map(\.date)
            .max()
    }

    private static func calculateRhythm(
        transactions: [TransactionItem],
        lastRecordDate: Date?,
        interval: DateInterval,
        period: DetailPeriod,
        now: Date,
        calendar: Calendar
    ) -> Int? {
        let nonAdjustment = transactions
            .filter { $0.balanceAdjustmentType == nil }
            .sorted { $0.date < $1.date }

        // Período en curso: el hueco desde el último registro hasta hoy también cuenta (lote 1 de la nota de salud).
        // Hoy no cuenta como día sin registrar: aún no ha terminado.
        let trailingGap: Int? = {
            guard interval.start <= now, now <= interval.end, let lastRecordDate else { return nil }
            let days = calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: lastRecordDate), to: calendar.startOfDay(for: now)
            ).day ?? 0
            return max(0, days - 1)
        }()
        guard !nonAdjustment.isEmpty || trailingGap != nil else { return nil }

        let useMonthlyAvg = shouldUseMonthlyAverage(
            period: period, interval: interval, calendar: calendar
        )

        let gap: Double
        if useMonthlyAvg {
            var monthlyGaps = computeMonthlyMaxGaps(
                transactions: nonAdjustment, calendar: calendar
            )
            // El hueco hasta hoy entra en el mes en curso, entero.
            if let trailingGap {
                let currentMonth = calendar.dateComponents([.year, .month], from: now)
                monthlyGaps[currentMonth] = max(monthlyGaps[currentMonth] ?? 0, trailingGap)
            }
            guard !monthlyGaps.isEmpty else { return nil }
            gap = Double(monthlyGaps.values.reduce(0, +)) / Double(monthlyGaps.count)
        } else {
            gap = Double(max(computeMaxGap(transactions: nonAdjustment, calendar: calendar), trailingGap ?? 0))
        }

        return rhythmScore(gap: gap)
    }

    /// 3 días de gracia y luego 8 puntos por día, sin saltos. Interno para los tests.
    static func rhythmScore(gap: Double) -> Int {
        let raw = 100.0 - max(0.0, gap - Double(rhythmGraceDays)) * Double(rhythmSlope)
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

    /// Agrupa tx por `(year, month)` y devuelve el maxGap de cada mes.
    /// Meses sin transacciones no contribuyen.
    private static func computeMonthlyMaxGaps(
        transactions: [TransactionItem], calendar: Calendar
    ) -> [DateComponents: Int] {
        let grouped = Dictionary(grouping: transactions) { tx -> DateComponents in
            calendar.dateComponents([.year, .month], from: tx.date)
        }
        return grouped.mapValues { computeMaxGap(transactions: $0, calendar: calendar) }
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
        // La cobertura cuenta TODO lo apuntado, también lo fechado en el futuro, y no el saldo de hoy de la pantalla
        // (`LiveBalanceCalculator.TodayCutoff`). Lo pendiente descuenta lo ya pagado con un movimiento enlazado aunque
        // su fecha sea futura: el alquiler apuntado hoy para el día 25 no está ni en el saldo de hoy ni en lo pendiente,
        // y con el saldo de hoy la cobertura salía mejor de lo real en su importe (review del 2026-10-18).
        let liveBalance = LiveBalanceCalculator.liveBalance(
            accounts: accounts,
            transactions: transactions,
            preferredCurrencyCode: preferredCurrencyCode,
            asOf: .distantFuture,
            converter: converter
        )
        let coverageScore = computeCoverageScore(
            liveBalance: liveBalance, pendingTotal: pendingTotal
        )

        // 2. Carga
        let income = sumIncomeTransactions(
            transactions,
            interval: cmtInterval,
            currencyCode: preferredCurrencyCode,
            adjustment: adjustment,
            converter: converter
        )
        let loadScore = computeLoadScore(
            commitmentsTotal: pendingTotal, income: income
        )

        let composite = (coverageScore + loadScore) / 2.0
        return clamp(Int(composite.rounded()))
    }

    /// Intervalo natural del período para Compromisos. `.thisWeek` → semana
    /// completa; `.thisMonth` → mes calendario completo (no truncado a hoy);
    /// `.thisYear` → año completo. Otros períodos retornan el `fallback` recibido
    /// (ya cerrado, móvil hasta hoy o sin fin).
    /// Lo usa también «Lo que te falta pagar» de Estadísticas › Resumen
    /// (`InsightsCalculator`, decisión A de Jürgen del 2026-10-27: hasta el fin del período).
    /// Aquí `.thisWeek` no llega: la puntuación descarta los períodos cortos antes.
    static func commitmentsInterval(
        period: DetailPeriod, fallback: DateInterval, now: Date = .now, calendar: Calendar = .current
    ) -> DateInterval {
        // El mes y el año naturales de `Calendar` acaban en la medianoche del siguiente, y `DateInterval` es cerrado: un
        // pago que vence el día 1 del mes siguiente contaba como compromiso de este. Acaban en 23:59:59.
        func closed(_ interval: DateInterval) -> DateInterval {
            DateInterval(start: interval.start, end: max(interval.start, interval.end.addingTimeInterval(-1)))
        }
        switch period {
        case .thisWeek:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else { return fallback }
            return closed(weekInterval)
        case .thisMonth:
            guard let monthInterval = calendar.dateInterval(of: .month, for: now) else { return fallback }
            return closed(monthInterval)
        case .thisYear:
            guard let yearInterval = calendar.dateInterval(of: .year, for: now) else { return fallback }
            return closed(yearInterval)
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
    ///
    /// Cada fila se resuelve con `CashFlowCalculator.resolvedAmount`, la regla de Estadísticas: una
    /// fila guardada con otra divisa principal (cambio de divisa sin recalcular) se reconvierte a
    /// `currencyCode` con la tasa de su día. Sumar su `amountInPreferredCurrency` tal cual mezclaba
    /// dos escalas en el denominador de la carga de Compromisos.
    /// Interno (no privado) para poder probarlo sin montar pagos programados.
    static func sumIncomeTransactions(
        _ transactions: [TransactionItem],
        interval: DateInterval,
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment,
        converter: CurrencyConverting
    ) -> Double {
        transactions
            .filter {
                interval.contains($0.date)
                    && $0.balanceAdjustmentType == nil
                    && TransactionClassificationLogic.isIncome($0)
                    && !adjustment.isSuppressed($0)
            }
            .reduce(0) {
                $0 + abs(CashFlowCalculator.resolvedAmount(
                    $1, currencyCode: currencyCode, adjustment: adjustment, converter: converter
                ).value)
            }
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
