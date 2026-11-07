//
//  ProjectedFlowBuilder.swift
//  Yala
//
//  Reúne lo que alimenta cada día de «Ver proyectado»: pagos planificados en su día (los vencidos sin registrar,
//  mañana), movimientos ya fechados por delante, y lo no planificado —del plan de flujo de caja o del ritmo de los
//  últimos meses—. La aritmética vive en `ProjectedFlowCalculator`; aquí, solo de dónde sale cada importe.
//
//  Lo usan Tendencias (`StatisticsViewModel`), el Panel (`PanelViewModel`) y la foto de los widgets
//  (`WidgetDataCache`).
//

import Foundation
import SwiftData

@MainActor
enum ProjectedFlowBuilder {

    typealias DayFlow = ProjectedFlowCalculator.DayFlow

    /// Los filtros de sesión que también acotan los pagos planificados: cuenta, categoría y subcategoría (lo demás no
    /// clasifica un pago igual que un movimiento, como en `PlannedOccurrenceBuilder`).
    struct PaymentFilter {
        var accounts = EntityFilter<PersistentIdentifier>(included: [], excluded: [])
        var categories = EntityFilter<PersistentIdentifier>(included: [], excluded: [])
        var subcategories = EntityFilter<PersistentIdentifier>(included: [], excluded: [])

        static let none = PaymentFilter()

        func matches(_ payment: ScheduledPayment) -> Bool {
            accounts.matches(payment.account?.persistentModelID)
                && categories.matches(payment.subcategory?.category?.persistentModelID)
                && subcategories.matches(payment.subcategory?.persistentModelID)
        }
    }

    /// ¿Acotan los filtros de sesión los datos? La métrica elegida (el chip de ingresos o gastos) no cuenta: elige qué
    /// se pinta, no qué movimientos entran.
    static func filtersNarrowData(_ criteria: FilterCriteria) -> Bool {
        var copy = criteria
        copy.selectedTransactionNatures = []
        return copy.hasActiveFilters
    }

    /// Los filtros de sesión que acotan también los pagos planificados.
    static func paymentFilter(from criteria: FilterCriteria) -> PaymentFilter {
        PaymentFilter(
            accounts: EntityFilter(included: criteria.selectedAccounts, excluded: criteria.excludedAccounts),
            categories: EntityFilter(included: criteria.selectedCategories, excluded: criteria.excludedCategories),
            subcategories: EntityFilter(included: criteria.selectedSubcategories, excluded: criteria.excludedSubcategories)
        )
    }

    /// Inicio de la ventana de pagos vencidos: el mes en curso, sea cual sea el período. Con el inicio del período,
    /// «Este año» traía a mañana los vencidos de todo el año y la misma cuenta daba otra cifra según el período (lo cazó
    /// la review del 2026-11-06).
    static func overdueWindowStart(today: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: today)?.start ?? calendar.startOfDay(for: today)
    }

    /// La línea punteada de una gráfica: el ancla (el saldo vivo en Saldo, el último punto de hoy en Ingresos y
    /// Gastos), los días acumulados y, con la gráfica por semanas o meses, un punto por grupo.
    static func chartProjection(
        metric: TrendType,
        grouping: TrendGrouping,
        realPoints: [BarPoint],
        liveAnchorValue: Double?,
        result: Result,
        days: [Date],
        today: Date,
        calendar: Calendar
    ) -> ProjectedFlowCalculator.Projection? {
        guard !days.isEmpty else { return nil }
        let anchor = metric == .balance
            ? (liveAnchorValue ?? ProjectedFlowCalculator.anchorValue(
                in: realPoints, today: today, grouping: grouping, calendar: calendar))
            : ProjectedFlowCalculator.anchorValue(in: realPoints, today: today, grouping: grouping, calendar: calendar)
        let daily = ProjectedFlowCalculator.accumulate(
            metric: metric, anchorValue: anchor, today: today, days: days, flows: result.flows, calendar: calendar
        )
        guard let closing = daily.last?.value else { return nil }
        return ProjectedFlowCalculator.Projection(
            points: ProjectedFlowCalculator.bucketed(daily, grouping: grouping, calendar: calendar),
            closingValue: closing,
            isApproximate: result.isApproximate,
            source: result.source(for: metric)
        )
    }

    struct Inputs {
        let today: Date
        let calendar: Calendar
        /// Inicio de la ventana de pagos vencidos: el inicio del mes en curso o del período, el que vaya antes.
        let overdueWindowStart: Date
        /// Días por delante que se proyectan (`ProjectedFlowCalculator.futureDays`).
        let days: [Date]
        /// Todos los movimientos: con ellos se sabe qué ocurrencias de un pago ya se pagaron y se calcula el plan.
        let allTransactions: [TransactionItem]
        /// Los movimientos que cuentan para esta gráfica (filtros de sesión y cuentas elegibles, sin recorte de fecha):
        /// alimentan el ritmo y los movimientos ya fechados por delante.
        let countedTransactions: [TransactionItem]
        /// Hay filtros de sesión: el plan no se sabe repartir por cuenta, categoría o etiqueta, y manda el ritmo
        /// (respuesta 10A).
        let hasSessionFilters: Bool
        let scheduledPayments: [ScheduledPayment]
        let paymentFilter: PaymentFilter
        let currencyCode: String
        let adjustment: GroupBridgeStatsAdjustment
        let converter: any CurrencyConverting
    }

    struct Result: Equatable {
        let flows: [Date: DayFlow]
        let incomeSource: ProjectedFlowCalculator.Source
        let expenseSource: ProjectedFlowCalculator.Source
        let isApproximate: Bool

        /// La fuente que nombra el rótulo para una métrica: la del lado que se pinta; en el saldo, el plan si alguno
        /// de los dos lados salió de él.
        func source(for metric: TrendType) -> ProjectedFlowCalculator.Source {
            switch metric {
            case .income: return incomeSource
            case .expense: return expenseSource
            case .balance:
                if incomeSource == .plan || expenseSource == .plan { return .plan }
                if incomeSource == .rhythm || expenseSource == .rhythm { return .rhythm }
                return .scheduledOnly
            }
        }
    }

    // MARK: - Entrada

    static func build(_ inputs: Inputs, context: ModelContext?) -> Result {
        guard !inputs.days.isEmpty else {
            return Result(flows: [:], incomeSource: .scheduledOnly, expenseSource: .scheduledOnly, isApproximate: false)
        }
        var flows: [Date: DayFlow] = [:]
        var isApproximate = false

        // 1. Pagos planificados, en su día o mañana si vencieron sin registrarse.
        let occurrences = scheduledOccurrences(inputs)
        for occurrence in occurrences {
            flows[occurrence.day, default: DayFlow()] += occurrence.flow
            if occurrence.isApproximate { isApproximate = true }
        }

        // 2. Movimientos ya fechados por delante (respuesta 7A: entran en la proyección).
        let futureDated = futureDatedFlows(inputs)
        for (day, flow) in futureDated.flows { flows[day, default: DayFlow()] += flow }
        if futureDated.isApproximate { isApproximate = true }

        // 3. Lo no planificado: del plan por lado, si lo hay y no hay filtros; si no, del ritmo.
        let plan = inputs.hasSessionFilters ? nil : planRemaining(inputs, occurrences: occurrences, context: context)
        let rhythm = rhythmPerDay(inputs)
        if rhythm.isApproximate { isApproximate = true }

        var incomeSource: ProjectedFlowCalculator.Source = .scheduledOnly
        var expenseSource: ProjectedFlowCalculator.Source = .scheduledOnly
        var unplanned: [Date: DayFlow] = [:]
        if let plan {
            if plan.isApproximate { isApproximate = true }
            let spread = ProjectedFlowCalculator.spread(
                remainingByMonth: plan.remainingByMonth, over: inputs.days, today: inputs.today, calendar: inputs.calendar
            )
            for day in inputs.days {
                let fromPlan = spread[day] ?? DayFlow()
                var flow = DayFlow()
                flow.income = plan.hasIncomeLines ? fromPlan.income : (rhythm.perDay?.income ?? 0)
                flow.expense = plan.hasExpenseLines ? fromPlan.expense : (rhythm.perDay?.expense ?? 0)
                unplanned[day] = flow
            }
            incomeSource = plan.hasIncomeLines ? .plan : (rhythm.perDay == nil ? .scheduledOnly : .rhythm)
            expenseSource = plan.hasExpenseLines ? .plan : (rhythm.perDay == nil ? .scheduledOnly : .rhythm)
        } else if let perDay = rhythm.perDay {
            for day in inputs.days { unplanned[day] = perDay }
            incomeSource = .rhythm
            expenseSource = .rhythm
        }
        for (day, flow) in unplanned { flows[day, default: DayFlow()] += flow }

        return Result(flows: flows, incomeSource: incomeSource, expenseSource: expenseSource, isApproximate: isApproximate)
    }

    // MARK: - Pagos planificados

    struct Occurrence {
        let paymentID: UUID
        let subcategoryID: PersistentIdentifier?
        let categoryID: PersistentIdentifier?
        /// Mes de la ocurrencia ORIGINAL (no el de dibujo): con él se descuenta de la línea de su mes.
        let monthStart: Date
        let day: Date
        let flow: DayFlow
        let isApproximate: Bool
    }

    static func scheduledOccurrences(_ inputs: Inputs) -> [Occurrence] {
        let calendar = inputs.calendar
        guard let lastDay = inputs.days.last,
              let horizonEnd = calendar.date(byAdding: .day, value: 1, to: lastDay) else { return [] }
        let windowStart = calendar.startOfDay(for: inputs.overdueWindowStart)

        var paidDays: [String: Set<Date>] = [:]
        for tx in inputs.allTransactions {
            guard let id = tx.scheduledPaymentID else { continue }
            paidDays[id, default: []].insert(calendar.startOfDay(for: tx.date))
        }

        var months: [Date] = []
        if var cursor = calendar.dateInterval(of: .month, for: windowStart)?.start {
            while cursor < horizonEnd {
                months.append(cursor)
                guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
                cursor = next
            }
        }

        var result: [Occurrence] = []
        // Un pago de grupo se guarda por su importe entero y la curva cuenta «mi parte»: proyectarlo entero inventaría
        // gasto. Se queda fuera (residual anotado en el ticket).
        for payment in inputs.scheduledPayments
        where payment.isActive && !payment.isGroupPayment && inputs.paymentFilter.matches(payment) {
            let isIncome = payment.type == .income
            let paid = paidDays[payment.id.uuidString] ?? []
            let lastPaidDay = payment.lastPaidDate.map { calendar.startOfDay(for: $0) }
            // La próxima fecha solo avanza al pagar o saltar una ocurrencia (crear el borrador no la mueve): lo que va
            // antes ya está resuelto. Sin esta frontera, un alquiler pagado el día 5 para el 20 se contaba dos veces.
            let firstPending = calendar.startOfDay(for: payment.nextDueDate)
            let conversion = ScheduledPaymentAmountConversion.magnitude(
                of: payment, in: inputs.currencyCode, converter: inputs.converter
            )
            guard conversion.amount.isFinite, conversion.amount > 0 else { continue }
            for month in months {
                let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                    params: payment.dateCalculatorParams, month: month, calendar: calendar
                )
                for date in dates {
                    let day = calendar.startOfDay(for: date)
                    guard day >= windowStart, day >= firstPending, day < horizonEnd else { continue }
                    guard !payment.isDateSkipped(date), !paid.contains(day) else { continue }
                    if let lastPaidDay, day <= lastPaidDay { continue }
                    guard let drawing = ProjectedFlowCalculator.drawingDay(
                        forOccurrence: date, today: inputs.today, calendar: calendar
                    ) else { continue }
                    result.append(Occurrence(
                        paymentID: payment.id,
                        subcategoryID: payment.subcategory?.persistentModelID,
                        categoryID: payment.subcategory?.category?.persistentModelID,
                        monthStart: month,
                        day: drawing,
                        flow: isIncome ? DayFlow(income: conversion.amount) : DayFlow(expense: conversion.amount),
                        isApproximate: conversion.isApproximate
                    ))
                }
            }
        }
        return result
    }

    // MARK: - Movimientos ya fechados

    static func futureDatedFlows(_ inputs: Inputs) -> (flows: [Date: DayFlow], isApproximate: Bool) {
        let calendar = inputs.calendar
        guard let first = inputs.days.first, let last = inputs.days.last,
              let horizonEnd = calendar.date(byAdding: .day, value: 1, to: last) else { return ([:], false) }
        var flows: [Date: DayFlow] = [:]
        var approximate = false
        for tx in inputs.countedTransactions where tx.date >= first && tx.date < horizonEnd {
            // Las patas de préstamo de un gasto de grupo y los ajustes de saldo no son ingreso ni gasto.
            guard tx.balanceAdjustmentType == nil, !inputs.adjustment.isSuppressed(tx) else { continue }
            let resolved = CashFlowCalculator.resolvedAmount(
                tx, currencyCode: inputs.currencyCode, adjustment: inputs.adjustment, converter: inputs.converter
            )
            if resolved.approximateMagnitude > 0 { approximate = true }
            let day = calendar.startOfDay(for: tx.date)
            if TransactionClassificationLogic.isIncome(tx) {
                flows[day, default: DayFlow()].income += resolved.value
            } else {
                flows[day, default: DayFlow()].expense -= resolved.value
            }
        }
        return (flows, approximate)
    }

    // MARK: - Ritmo

    static func rhythmPerDay(_ inputs: Inputs) -> (perDay: DayFlow?, isApproximate: Bool) {
        let calendar = inputs.calendar
        let todayStart = calendar.startOfDay(for: inputs.today)
        guard let windowStart = calendar.date(
            byAdding: .day, value: -ProjectedFlowCalculator.rhythmWindowDays, to: todayStart
        ) else { return (nil, false) }

        var income: Double = 0
        var expense: Double = 0
        var firstDate: Date?
        var approximate = false
        for tx in inputs.countedTransactions where tx.date < todayStart {
            guard tx.balanceAdjustmentType == nil, !inputs.adjustment.isSuppressed(tx) else { continue }
            if firstDate.map({ tx.date < $0 }) ?? true { firstDate = tx.date }
            // Lo enlazado a un pago planificado ya se proyecta en su día: contarlo también en el ritmo lo duplicaría.
            guard tx.date >= windowStart, tx.scheduledPaymentID == nil else { continue }
            let resolved = CashFlowCalculator.resolvedAmount(
                tx, currencyCode: inputs.currencyCode, adjustment: inputs.adjustment, converter: inputs.converter
            )
            if resolved.approximateMagnitude > 0 { approximate = true }
            if TransactionClassificationLogic.isIncome(tx) {
                income += resolved.value
            } else {
                expense -= resolved.value
            }
        }
        guard let firstDate else { return (nil, false) }
        let historyStart = max(windowStart, calendar.startOfDay(for: firstDate))
        let historyDays = calendar.dateComponents([.day], from: historyStart, to: todayStart).day ?? 0
        guard let perDay = ProjectedFlowCalculator.rhythm(
            incomeTotal: income, expenseTotal: expense, historyDays: historyDays
        ) else { return (nil, false) }
        return (perDay, approximate)
    }

    // MARK: - Plan de flujo de caja

    struct PlanRemaining {
        let remainingByMonth: [Date: DayFlow]
        let hasIncomeLines: Bool
        let hasExpenseLines: Bool
        let isApproximate: Bool
    }

    static func planRemaining(_ inputs: Inputs, occurrences: [Occurrence], context: ModelContext?) -> PlanRemaining? {
        guard let context else { return nil }
        let plan: CashFlowPlan?
        do {
            var descriptor = FetchDescriptor<CashFlowPlan>()
            descriptor.fetchLimit = 1
            plan = try context.fetch(descriptor).first
        } catch {
            #if DEBUG
            print("ProjectedFlowBuilder: Error loading cash flow plan: \(error)")
            #endif
            return nil
        }
        guard let plan else { return nil }
        let lines = (plan.lines ?? []).filter(\.isEnabled)
        let hasIncomeLines = lines.contains(where: \.isIncome)
        let hasExpenseLines = lines.contains { !$0.isIncome }
        guard hasIncomeLines || hasExpenseLines else { return nil }

        let calendar = inputs.calendar
        guard let currentMonth = calendar.dateInterval(of: .month, for: inputs.today)?.start,
              let lastDay = inputs.days.last,
              let lastMonth = calendar.dateInterval(of: .month, for: lastDay)?.start else { return nil }
        let monthsAhead = max(calendar.dateComponents([.month], from: currentMonth, to: lastMonth).month ?? 0, 0)

        let projection = CashFlowProjectionCalculator.calculate(
            plan: plan,
            lines: lines,
            transactions: inputs.allTransactions,
            allExpenseCategories: [],
            scheduledPayments: inputs.scheduledPayments,
            monthsBack: 0,
            monthsAhead: monthsAhead,
            currencyCode: inputs.currencyCode,
            adjustment: inputs.adjustment,
            converter: inputs.converter
        )
        let linesByID = Dictionary(lines.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var remainingByMonth: [Date: DayFlow] = [:]
        var approximate = false
        for month in projection.months {
            guard let monthStart = calendar.dateInterval(of: .month, for: month.date)?.start,
                  monthStart >= currentMonth else { continue }
            let monthOccurrences = occurrences.filter { $0.monthStart == monthStart }
            var remaining = DayFlow()
            for result in month.incomeLines + month.expenseLines {
                guard let line = linesByID[result.lineID] else { continue }
                // Una línea de método «pago planificado» ya está entera en sus pagos, que van en su día.
                guard line.method != .scheduled else { continue }
                if result.isPlannedApproximate { approximate = true }
                let pending = monthOccurrences
                    .filter { occurrence in covers(line, occurrence) }
                    .reduce(0.0) { $0 + (line.isIncome ? $1.flow.income : $1.flow.expense) }
                let left = ProjectedFlowCalculator.lineRemaining(
                    planned: result.plannedAmount, real: result.realAmount ?? 0, pendingScheduled: pending
                )
                if line.isIncome { remaining.income += left } else { remaining.expense += left }
            }
            remainingByMonth[monthStart] = remaining
        }
        return PlanRemaining(
            remainingByMonth: remainingByMonth,
            hasIncomeLines: hasIncomeLines,
            hasExpenseLines: hasExpenseLines,
            isApproximate: approximate
        )
    }

    /// ¿El pago cae en la línea? Por subcategoría si la línea tiene una; si no, por categoría.
    private static func covers(_ line: CashFlowLine, _ occurrence: Occurrence) -> Bool {
        if let subcategoryID = line.subcategory?.persistentModelID {
            return occurrence.subcategoryID == subcategoryID
        }
        if let categoryID = line.category?.persistentModelID {
            return occurrence.categoryID == categoryID
        }
        return false
    }
}
