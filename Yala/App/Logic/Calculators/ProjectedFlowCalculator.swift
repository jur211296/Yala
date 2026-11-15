//
//  ProjectedFlowCalculator.swift
//  Yala
//
//  «Ver proyectado» (card «Flujo proyectado en Tendencias y Panel», 2026-11-06): la continuación punteada de la gráfica
//  diaria desde hoy hasta el final del período. Aquí vive solo la aritmética, sin SwiftData: qué entra cada día
//  (`DayFlow`) y cómo se acumula según la métrica. Qué pagos, qué plan y qué ritmo alimentan cada día lo reúne
//  `ProjectedFlowBuilder`.
//
//  Las decisiones de producto (todas «A», Jürgen 2026-11-06) están en
//  `tickets/backlog/flujo-proyectado-en-tendencias-y-panel.md`.
//

import Foundation

enum ProjectedFlowCalculator {

    /// Lo que se espera que entre y salga un día. Los dos lados son importes con el signo de su lado: un gasto suma en
    /// `expense`, una devolución lo resta (la regla de `ingreso-gasto.md`: se suma con signo).
    struct DayFlow: Equatable {
        var income: Double = 0
        var expense: Double = 0

        static func + (lhs: DayFlow, rhs: DayFlow) -> DayFlow {
            DayFlow(income: lhs.income + rhs.income, expense: lhs.expense + rhs.expense)
        }

        static func += (lhs: inout DayFlow, rhs: DayFlow) { lhs = lhs + rhs }
    }

    /// De dónde sale la estimación de lo que no está planificado. Elige el rótulo bajo la gráfica.
    enum Source: Equatable {
        /// El plan de flujo de caja (respuesta 1A).
        case plan
        /// El ritmo de los últimos meses (respuestas 1A y 4A: sin plan, o con filtros que el plan no sabe repartir).
        case rhythm
        /// Ni plan ni historia suficiente: solo pagos planificados y movimientos con fecha futura.
        case scheduledOnly
    }

    /// Lo que se pinta: un punto por día (o por grupo) desde hoy, la cifra al cierre y si alguna tasa fue aproximada.
    struct Projection: Equatable {
        /// El primero es el de hoy (el ancla) para que la línea punteada arranque donde acaba la sólida.
        let points: [BarPoint]
        let closingValue: Double
        let isApproximate: Bool
        let source: Source
        /// Lo que se acumula (saldo, ingresos o gastos) y el último día proyectado: el rótulo de la cifra dice de qué es
        /// y hasta cuándo («Al 30 de noviembre tendrías», decisión 30 de 2.3).
        var metric: TrendType = .balance
        var endDate: Date = .distantPast
    }

    // MARK: - Días

    /// Los días por delante dentro del período: de mañana al último día del intervalo, a medianoche. Vacío si el período
    /// termina hoy o antes (respuesta 3A: entonces no hay control).
    static func futureDays(in interval: DateInterval, today: Date, calendar: Calendar) -> [Date] {
        let todayStart = calendar.startOfDay(for: today)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart) else { return [] }
        // El `end` de un período en curso cierra a las 23:59:59; un rango propio puede cerrar en una medianoche, que
        // `DateInterval` cuenta (es cerrado) pero no es un día más del período.
        let lastInstant = calendar.startOfDay(for: interval.end) == interval.end && interval.end > interval.start
            ? interval.end.addingTimeInterval(-1)
            : interval.end
        let lastDay = calendar.startOfDay(for: lastInstant)
        guard tomorrow <= lastDay else { return [] }
        var days: [Date] = []
        var cursor = tomorrow
        while cursor <= lastDay {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    /// Hasta dónde se proyecta: el período ENTERO. Los períodos en curso cierran hoy a las 23:59:59
    /// (`DetailPeriod.dateInterval`), así que «Este mes» se alarga hasta su último día, y lo mismo la semana y el año.
    /// La semana se cuenta desde su inicio (que ya trae el primer día de la semana elegido en Ajustes). Un rango propio
    /// usa su propio final; los demás períodos («Últimos 7 días», los pasados, «Todo») terminan hoy o antes.
    static func horizon(for period: DetailPeriod, interval: DateInterval, calendar: Calendar) -> DateInterval {
        let end: Date?
        switch period {
        case .thisWeek:
            end = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: interval.start))
        case .thisMonth:
            end = calendar.dateInterval(of: .month, for: interval.start)?.end
        case .thisYear:
            end = calendar.dateInterval(of: .year, for: interval.start)?.end
        default:
            end = nil
        }
        guard let end, end > interval.start else { return interval }
        return DateInterval(start: interval.start, end: max(interval.end, end.addingTimeInterval(-1)))
    }

    /// ¿Tiene sentido el control en este período? Solo si queda al menos un día por delante.
    static func hasDaysAhead(_ interval: DateInterval, today: Date, calendar: Calendar) -> Bool {
        !futureDays(in: interval, today: today, calendar: calendar).isEmpty
    }

    /// Dónde se dibuja un pago planificado: en su día si está por delante; si es de hoy o venció sin registrarse,
    /// mañana (respuesta 6A: sigue pendiente, y hoy ya es la línea sólida).
    static func drawingDay(forOccurrence date: Date, today: Date, calendar: Calendar) -> Date? {
        let day = calendar.startOfDay(for: date)
        let todayStart = calendar.startOfDay(for: today)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart) else { return nil }
        return day > todayStart ? day : tomorrow
    }

    // MARK: - Lo que falta de una línea del plan

    /// Lo que falta de una línea en el mes: lo planeado menos lo ya gastado y menos lo que los pagos planificados de esa
    /// línea ya van a dibujar en su día. Nunca negativo (respuesta 5A: una línea superada deja de sumar).
    static func lineRemaining(planned: Double, real: Double, pendingScheduled: Double) -> Double {
        max(planned - real - pendingScheduled, 0)
    }

    /// Reparte lo que falta de cada mes entre sus días por delante (de mañana a fin de mes), y devuelve solo los días
    /// pedidos. Así una semana que cruza meses toma de cada mes su parte, y un mes entero por delante, su plan entero.
    /// Las claves de `remainingByMonth` son el inicio de cada mes.
    static func spread(
        remainingByMonth: [Date: DayFlow],
        over days: [Date],
        today: Date,
        calendar: Calendar
    ) -> [Date: DayFlow] {
        let todayStart = calendar.startOfDay(for: today)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart) else { return [:] }
        var result: [Date: DayFlow] = [:]
        for day in days {
            guard let month = calendar.dateInterval(of: .month, for: day),
                  let remaining = remainingByMonth[month.start] else { continue }
            // Días del mes que quedan por delante: desde mañana (o desde el día 1 si el mes aún no empezó).
            let firstAhead = max(month.start, tomorrow)
            let daysAhead = calendar.dateComponents([.day], from: firstAhead, to: month.end).day ?? 0
            guard daysAhead > 0 else { continue }
            result[day] = DayFlow(
                income: remaining.income / Double(daysAhead),
                expense: remaining.expense / Double(daysAhead)
            )
        }
        return result
    }

    // MARK: - Ritmo

    /// Días mínimos de historia para estimar un ritmo: con menos, un usuario nuevo proyectaría su primera semana (o un
    /// solo gasto grande) sobre el mes entero.
    static let minimumRhythmDays = 14
    /// Ventana del ritmo: los últimos tres meses.
    static let rhythmWindowDays = 90

    /// Gasto e ingreso medio por día. `historyDays` son los días de la ventana con historia (desde el primer
    /// movimiento, como mucho 90). `nil` si la historia no llega al mínimo. Un lado negativo (devolvieron más de lo que
    /// se gastó) proyecta cero: el ritmo no inventa devoluciones.
    static func rhythm(incomeTotal: Double, expenseTotal: Double, historyDays: Int) -> DayFlow? {
        guard historyDays >= minimumRhythmDays else { return nil }
        let days = Double(historyDays)
        return DayFlow(income: max(incomeTotal, 0) / days, expense: max(expenseTotal, 0) / days)
    }

    // MARK: - Acumular

    /// Acumula los días sobre el ancla según la métrica: el gasto suma `expense`, el ingreso suma `income` y el saldo
    /// suma `income − expense`. El primer punto es el ancla en `today`.
    static func accumulate(
        metric: TrendType,
        anchorValue: Double,
        today: Date,
        days: [Date],
        flows: [Date: DayFlow],
        calendar: Calendar
    ) -> [BarPoint] {
        guard !days.isEmpty else { return [] }
        var value = anchorValue
        var points = [BarPoint(date: calendar.startOfDay(for: today), value: anchorValue)]
        for day in days {
            let flow = flows[day] ?? DayFlow()
            switch metric {
            case .balance: value += flow.income - flow.expense
            case .income: value += flow.income
            case .expense: value += flow.expense
            }
            points.append(BarPoint(date: day, value: value))
        }
        return points
    }

    /// Con la gráfica por semanas o por meses, un punto por grupo: el ancla en el grupo de hoy y, en cada grupo
    /// siguiente, el valor de su último día proyectado. Es la forma de la curva real (cada punto en el inicio de su
    /// grupo, con el valor al cierre).
    static func bucketed(_ daily: [BarPoint], grouping: TrendGrouping, calendar: Calendar) -> [BarPoint] {
        guard grouping != .day, let anchor = daily.first else { return daily }
        let anchorKey = grouping.dateKey(for: anchor.date, calendar: calendar)
        var lastByKey: [Date: Double] = [anchorKey: anchor.value]
        var order: [Date] = [anchorKey]
        for point in daily.dropFirst() {
            let key = grouping.dateKey(for: point.date, calendar: calendar)
            // El grupo de hoy conserva el ancla: su punto real ya vale lo de hoy, y la línea punteada arranca ahí.
            guard key != anchorKey else { continue }
            if lastByKey[key] == nil { order.append(key) }
            lastByKey[key] = point.value
        }
        return order.compactMap { key in lastByKey[key].map { BarPoint(date: key, value: $0) } }
    }

    /// El valor de la curva real al cierre de hoy: el último punto de hoy o anterior. Con la proyección encendida, los
    /// movimientos con fecha futura pasan a la línea punteada (respuesta 7A), así que la sólida acaba aquí.
    static func anchorValue(in points: [BarPoint], today: Date, grouping: TrendGrouping, calendar: Calendar) -> Double {
        let todayKey = grouping.dateKey(for: today, calendar: calendar)
        return points.last(where: { $0.date <= todayKey })?.value ?? 0
    }

    /// La curva real sin lo que queda por delante de hoy.
    static func pointsUpToToday(_ points: [BarPoint], today: Date, grouping: TrendGrouping, calendar: Calendar) -> [BarPoint] {
        let todayKey = grouping.dateKey(for: today, calendar: calendar)
        return points.filter { $0.date <= todayKey }
    }
}
