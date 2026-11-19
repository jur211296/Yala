//
//  ProjectedFlowBuilder.swift
//  Yala
//
//  Reúne lo que alimenta cada día de «Ver proyectado»: pagos planificados en su día (los vencidos sin registrar,
//  mañana), movimientos ya fechados por delante, y lo no planificado, del motor del mes del flujo de caja
//  (`FlujoMotorMes`): con plan, lo que les falta a sus líneas; sin plan o con filtros, «otros» con los fijos detectados en
//  tus registros y, en gastos, lo variable por la mediana de 6 meses sin aislados (`FlujoProyeccionInteligente`).
//  La aritmética vive en `ProjectedFlowCalculator`; aquí, solo de dónde sale cada importe.
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
            source: result.source(for: metric),
            metric: metric,
            endDate: days.last ?? calendar.startOfDay(for: today)
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
        /// lo que cada mes ya tiene, los movimientos ya fechados por delante y, con filtros, la mediana de «otros».
        let countedTransactions: [TransactionItem]
        /// Hay filtros de sesión: el plan no se sabe repartir por cuenta, categoría o etiqueta, y manda el motor sin
        /// líneas sobre lo filtrado (respuesta 10A; desde S6 del replanteo, la mediana en vez del ritmo).
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

        // 3. Lo no planificado, del motor del mes del flujo de caja (`FlujoMotorMes`). Con plan y sin filtros, lo que les
        // falta a las líneas y, en gastos, «otros» por la mediana de 6 meses (S1 del replanteo, 18-nov-2026). Sin plan, o
        // con filtros que el plan no sabe repartir, el mismo motor sin líneas: «otros» por la mediana (S6). En los dos,
        // los ingresos sin línea no se proyectan (P6). Hasta S6, sin plan seguía el ritmo de los últimos 90 días, por
        // día y por lado: el sueldo se proyectaba aunque no fuera a llegar y un gasto puntual se repartía en el mes.
        var incomeSource: ProjectedFlowCalculator.Source = .scheduledOnly
        var expenseSource: ProjectedFlowCalculator.Source = .scheduledOnly
        var remaining: PlanRemaining?
        if !inputs.hasSessionFilters, let plan = planRemaining(inputs, occurrences: occurrences, context: context) {
            remaining = plan
            incomeSource = .plan
            expenseSource = .plan
        } else if let others = othersRemaining(inputs, occurrences: occurrences) {
            remaining = others
            // El gasto estimado se sigue nombrando «tu ritmo de gasto»: la mediana es lo que gastas en un mes normal. Los
            // ingresos fijos detectados no tienen rótulo propio todavía (card aparte): el de ingresos no cambia.
            if others.hasExpenseLines { expenseSource = .rhythm }
        }
        if let remaining {
            if remaining.isApproximate { isApproximate = true }
            let spread = ProjectedFlowCalculator.spread(
                remainingByMonth: remaining.remainingByMonth, over: inputs.days, today: inputs.today,
                calendar: inputs.calendar
            )
            for (day, flow) in spread { flows[day, default: DayFlow()] += flow }
            // Los fijos detectados que llegan una vez al mes, en su día (o mañana si ya pasó sin llegar).
            for (day, flow) in dayPlacedFlows(remaining.byDayOfMonth, inputs: inputs) {
                flows[day, default: DayFlow()] += flow
            }
        }

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

    // MARK: - Fijos en su día

    /// Lo que les falta a los fijos de un día (mes → día del mes → lo que falta) puesto en su día: el día típico, o el
    /// último del mes si el mes es más corto; si ya pasó, mañana (como un pago vencido). Solo los días pedidos: el cierre
    /// del mes no cambia, solo en qué día se dibuja.
    static func dayPlacedFlows(_ byDay: [Date: [Int: DayFlow]], inputs: Inputs) -> [Date: DayFlow] {
        let calendar = inputs.calendar
        let pedidos = Set(inputs.days)
        var result: [Date: DayFlow] = [:]
        for (mes, porDia) in byDay {
            guard let diasDelMes = calendar.range(of: .day, in: .month, for: mes)?.count else { continue }
            for (dia, flow) in porDia {
                guard let fecha = calendar.date(byAdding: .day, value: min(dia, diasDelMes) - 1, to: mes),
                      let dibujo = ProjectedFlowCalculator.drawingDay(
                        forOccurrence: fecha, today: inputs.today, calendar: calendar),
                      calendar.isDate(dibujo, equalTo: mes, toGranularity: .month),
                      pedidos.contains(dibujo) else { continue }
                result[dibujo, default: DayFlow()] += flow
            }
        }
        return result
    }

    /// De lo que falta por día de cada lado a la forma de `dayPlacedFlows`.
    static func byDayOfMonth(income: [Int: Double], expense: [Int: Double]) -> [Int: DayFlow] {
        var result: [Int: DayFlow] = [:]
        for (dia, importe) in income { result[dia, default: DayFlow()].income += importe }
        for (dia, importe) in expense { result[dia, default: DayFlow()].expense += importe }
        return result
    }

    // MARK: - Sin plan: «otros» por la mediana

    /// Lo que falta cada mes sin plan, o con filtros de sesión: el motor del mes sin líneas, así que todo es «otros».
    /// Con lo detectado en tus registros (`FlujoProyeccionInteligente`, 19-nov-2026): los fijos de los dos lados, con su
    /// monto y su día, y en gastos lo variable por la mediana de 6 meses sin fijos ni aislados, menos lo que el mes ya
    /// tiene (sin lo enlazado a un pago, que va en su día). Los ingresos que varían no se proyectan. Sin filtros, sale
    /// de todos los movimientos, como con plan, para que Panel, Tendencias y el widget den la misma cifra; con filtros,
    /// de los filtrados («Solo Comida» proyecta lo de comida). `nil` si no hay nada que estimar (sin un mes completo de
    /// historia, o sin gasto variable ni fijos).
    static func othersRemaining(_ inputs: Inputs, occurrences: [Occurrence]) -> PlanRemaining? {
        let calendar = inputs.calendar
        guard let currentMonth = calendar.dateInterval(of: .month, for: inputs.today),
              let lastDay = inputs.days.last,
              let lastMonth = calendar.dateInterval(of: .month, for: lastDay)?.start else { return nil }
        var meses: [Date] = []
        var cursor = currentMonth.start
        while cursor <= lastMonth {
            meses.append(cursor)
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        let startOfTomorrow = LiveBalanceCalculator.TodayCutoff(asOf: inputs.today, calendar: calendar).startOfTomorrow
        let contados = FlujoMotorMesEntrada.movimientos(
            inputs.countedTransactions, currencyCode: inputs.currencyCode, adjustment: inputs.adjustment,
            converter: inputs.converter, startOfTomorrow: startOfTomorrow, calendar: calendar
        )
        let historia = inputs.hasSessionFilters ? contados.movimientos : FlujoMotorMesEntrada.movimientos(
            inputs.allTransactions, currencyCode: inputs.currencyCode, adjustment: inputs.adjustment,
            converter: inputs.converter, startOfTomorrow: startOfTomorrow, calendar: calendar
        ).movimientos
        let entrada = FlujoMotorMes.Entrada(
            meses: meses,
            mesEnCurso: currentMonth.start,
            quedanDiasEnElMes: startOfTomorrow < currentMonth.end,
            lineas: [],
            limite: { _, _ in 0 },
            movimientos: contados.movimientos,
            pendientes: FlujoMotorMesEntrada.pendientes(occurrences, calendar: calendar),
            calendar: calendar,
            historia: historia
        )
        let deteccion = FlujoMotorMes.detectar(entrada)
        let estimaGastos = deteccion.gastos.variable > 0 || !deteccion.gastos.fijos.isEmpty
        let estimaIngresos = !deteccion.ingresos.fijos.isEmpty
        guard estimaGastos || estimaIngresos else { return nil }
        var remainingByMonth: [Date: DayFlow] = [:]
        var byDay: [Date: [Int: DayFlow]] = [:]
        for mes in FlujoMotorMes.calcular(entrada) where !mes.esPasado {
            remainingByMonth[mes.inicio] = DayFlow(
                income: mes.ingresos.faltaRepartible, expense: mes.gastos.faltaRepartible
            )
            byDay[mes.inicio] = byDayOfMonth(income: mes.ingresos.faltaPorDia, expense: mes.gastos.faltaPorDia)
        }
        return PlanRemaining(
            remainingByMonth: remainingByMonth,
            hasIncomeLines: estimaIngresos,
            hasExpenseLines: estimaGastos,
            isApproximate: contados.aproximado,
            byDayOfMonth: byDay
        )
    }

    // MARK: - Plan de flujo de caja

    struct PlanRemaining {
        let remainingByMonth: [Date: DayFlow]
        /// Con plan: tiene líneas de ese lado. Sin plan: ese lado tiene algo estimado (fijos o, en gastos, lo variable).
        let hasIncomeLines: Bool
        let hasExpenseLines: Bool
        let isApproximate: Bool
        /// Lo que les falta a los fijos de un día, por mes (inicio) y día del mes: va en su día, no repartido.
        var byDayOfMonth: [Date: [Int: DayFlow]] = [:]
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
        // Un plan sin líneas también manda: el flujo de caja lo proyecta con el motor del mes (en el mes en curso, «otros»
        // por la mediana; en los que vienen, solo lo fijo, decisión del 19-nov-2026), y «Al 30» tiene que ser la misma
        // cifra en las dos pantallas.

        let calendar = inputs.calendar
        guard let currentMonth = calendar.dateInterval(of: .month, for: inputs.today)?.start,
              let lastDay = inputs.days.last,
              let lastMonth = calendar.dateInterval(of: .month, for: lastDay)?.start else { return nil }
        let monthsAhead = max(calendar.dateComponents([.month], from: currentMonth, to: lastMonth).month ?? 0, 0)

        // Lo real son los movimientos que cuentan para esta cifra (con Saldo, los de las cuentas del saldo), como en el
        // flujo de caja; los pagos pendientes, los mismos que se pintan en su día.
        let projection = CashFlowProjectionCalculator.calculate(
            plan: plan,
            lines: lines,
            transactions: inputs.countedTransactions,
            allExpenseCategories: [],
            scheduledPayments: inputs.scheduledPayments,
            monthsBack: 0,
            monthsAhead: monthsAhead,
            currencyCode: inputs.currencyCode,
            adjustment: inputs.adjustment,
            converter: inputs.converter,
            occurrences: occurrences,
            historyTransactions: inputs.allTransactions,
            includesSubcategoryBreakdown: false,
            now: inputs.today,
            calendar: calendar
        )
        var remainingByMonth: [Date: DayFlow] = [:]
        var byDay: [Date: [Int: DayFlow]] = [:]
        for month in projection.months where !month.isPast {
            guard let monthStart = calendar.dateInterval(of: .month, for: month.date)?.start else { continue }
            remainingByMonth[monthStart] = DayFlow(
                income: month.spreadableIncomeLeft, expense: month.spreadableExpenseLeft
            )
            byDay[monthStart] = byDayOfMonth(income: month.dayPlacedIncomeLeft, expense: month.dayPlacedExpenseLeft)
        }
        let approximate = projection.isApproximate
        return PlanRemaining(
            remainingByMonth: remainingByMonth,
            hasIncomeLines: hasIncomeLines,
            hasExpenseLines: hasExpenseLines,
            isApproximate: approximate,
            byDayOfMonth: byDay
        )
    }
}
