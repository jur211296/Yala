//
//  WidgetInsightsLogic.swift
//  Yala
//
//  Lo que los widgets rediseñados en 2.2 deducen de la foto del App Group sin pedirle nada nuevo a la app
//  (`docs/widgets/AUDITORIA-WIDGETS-2-2.md`, G1): cuánto cambió el saldo en el período, cuánto se gastó contra el
//  período anterior a la misma altura, cuánto del período de un presupuesto ya pasó, cuándo vence un pago, cómo se
//  escribe una cifra en la pantalla bloqueada y qué filas lleva la leyenda de una tarta.
//
//  Membership: Yala (para los tests, `WidgetInsightsLogicTests`) + YalaWidgetsExtension (vía exception set en el
//  pbxproj, como `WidgetAmountSplitter`). Solo trabaja con fechas y números: los DTO del widget viven duplicados en
//  dos targets y aquí no se nombran.
//

import Foundation

nonisolated enum WidgetInsightsLogic {

    // MARK: - Saldo

    /// Cuánto subió o bajó el saldo en un período: el saldo de ahora (o del cierre, en un período pasado) menos el
    /// saldo al cierre del último día ANTES de que empezara. `nil` si la curva no llega tan atrás (la persona empezó a
    /// usar Yala dentro del período): no hay con qué comparar.
    /// - Parameter closings: los puntos de la curva (fecha del día, semana o mes, y el saldo a su cierre).
    static func balanceChange(balance: Double, closings: [(date: Date, balance: Double)], periodStart: Date) -> Double? {
        guard let before = closings.filter({ $0.date < periodStart }).max(by: { $0.date < $1.date }) else { return nil }
        return balance - before.balance
    }

    // MARK: - Cifra corta del tramo estimado (decisión 34 de la revisión 2.3)

    /// Dónde acaba el tramo punteado: su último día y lo que vale ahí («Estimado S/ X al 31 dic»). `nil` sin tramo (el
    /// ancla sola no es una estimación).
    struct ProjectedEnd: Equatable {
        let date: Date
        let value: Double
    }

    static func projectedEnd(_ points: [(date: Date, value: Double)]) -> ProjectedEnd? {
        guard points.count > 1, let last = points.last else { return nil }
        return ProjectedEnd(date: last.date, value: last.value)
    }

    // MARK: - Flujo proyectado (card «Flujo proyectado en Tendencias y Panel», respuesta 12A)

    /// La continuación punteada de un widget: el ancla en el día de la foto y, cada día siguiente hasta `end`, el ancla
    /// más lo esperado acumulado. `deltas` es lo esperado por día (gasto en «Gasto», ingreso − gasto en «Saldo»), como
    /// lo deja la app en la foto. Vacío si no queda ningún día por delante. Se mide a la hora de la foto, como el resto
    /// de las cuentas del widget: el ancla es la última cifra de la curva, calculada entonces.
    static func projectedCumulative(
        anchor: Double,
        deltas: [(date: Date, value: Double)],
        asOf: Date,
        end: Date,
        calendar: Calendar
    ) -> [(date: Date, value: Double)] {
        let anchorDay = calendar.startOfDay(for: asOf)
        let lastDay = calendar.startOfDay(for: end)
        guard let firstAhead = calendar.date(byAdding: .day, value: 1, to: anchorDay), firstAhead <= lastDay else {
            return []
        }
        var byDay: [Date: Double] = [:]
        for delta in deltas { byDay[calendar.startOfDay(for: delta.date), default: 0] += delta.value }
        var points: [(date: Date, value: Double)] = [(anchorDay, anchor)]
        var value = anchor
        var cursor = firstAhead
        while cursor <= lastDay {
            value += byDay[cursor] ?? 0
            points.append((cursor, value))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return points
    }

    // MARK: - Gasto contra el período anterior

    /// Lo gastado en el período anterior hasta el mismo punto («a esta altura del mes pasado»), y la diferencia.
    struct SpendingComparison: Equatable {
        let previousToDate: Double
        let change: Double

        /// La diferencia en proporción de lo gastado entonces; `nil` si entonces no se había gastado nada.
        var fraction: Double? { previousToDate > 0 ? change / previousToDate : nil }
    }

    /// Compara lo gastado en el período en curso con lo que se llevaba gastado en el anterior al MISMO día del
    /// período (día del mes, o del año). Si el anterior es más corto (febrero), cuenta entero. `nil` si el período
    /// anterior no tiene ningún movimiento: sin datos no hay comparación honesta. Ojo: la app rellena con ceros cada
    /// día de un período de hasta un año (`WidgetDataCache.buildCashFlowByDay`), así que «sin movimientos» es «todos
    /// los puntos en cero», no «sin puntos».
    /// - Parameters:
    ///   - current: lo gastado en el período en curso hasta hoy.
    ///   - previousDaily: el gasto de cada día del período anterior (los puntos del flujo de caja).
    ///   - previousStart: inicio del período anterior.
    ///   - currentStart: inicio del período en curso.
    static func spendingComparison(
        current: Double,
        previousDaily: [(date: Date, expense: Double)],
        previousStart: Date,
        currentStart: Date,
        now: Date,
        calendar: Calendar
    ) -> SpendingComparison? {
        guard previousDaily.contains(where: { $0.expense != 0 }) else { return nil }
        let elapsedDays = daysElapsed(from: currentStart, to: now, calendar: calendar)
        guard let cutoff = calendar.date(byAdding: .day, value: elapsedDays, to: calendar.startOfDay(for: previousStart)) else {
            return nil
        }
        let previousToDate = previousDaily.filter { $0.date < cutoff }.reduce(0) { $0 + $1.expense }
        return SpendingComparison(previousToDate: previousToDate, change: current - previousToDate)
    }

    // MARK: - Entradas y salidas

    /// Lo que quedaba (entró menos salió) en el período anterior hasta el mismo punto, y la diferencia con lo de ahora.
    struct FlowComparison: Equatable {
        let previousNetToDate: Double
        /// Neto de ahora menos el de entonces: positivo = este período va mejor.
        let change: Double
    }

    /// Compara el neto del período en curso con el que llevaba el anterior al MISMO día del período, con el mismo corte
    /// que `spendingComparison`. `nil` si el anterior no tiene ningún movimiento (la app rellena con ceros cada día).
    static func flowComparison(
        currentNet: Double,
        previousDaily: [(date: Date, income: Double, expense: Double)],
        previousStart: Date,
        currentStart: Date,
        now: Date,
        calendar: Calendar
    ) -> FlowComparison? {
        guard previousDaily.contains(where: { $0.income != 0 || $0.expense != 0 }) else { return nil }
        let elapsedDays = daysElapsed(from: currentStart, to: now, calendar: calendar)
        guard let cutoff = calendar.date(byAdding: .day, value: elapsedDays, to: calendar.startOfDay(for: previousStart)) else {
            return nil
        }
        let previousNet = previousDaily.filter { $0.date < cutoff }.reduce(0) { $0 + $1.income - $1.expense }
        return FlowComparison(previousNetToDate: previousNet, change: currentNet - previousNet)
    }

    /// Lo que entró y salió en cada día (o en cada mes) del período ENTERO, de `start` a `end` incluidos: lo que pinta la
    /// gráfica de barras de «Entradas y salidas». Los días aún por llegar valen cero, así que la gráfica ocupa el período
    /// y lo de hoy cae en su sitio. Ingreso y gasto van con signo, como los totales.
    static func flowBuckets(
        _ daily: [(date: Date, income: Double, expense: Double)],
        start: Date,
        end: Date,
        byMonth: Bool,
        calendar: Calendar
    ) -> [(income: Double, expense: Double)] {
        let component: Calendar.Component = byMonth ? .month : .day
        let first = byMonth
            ? (calendar.dateInterval(of: .month, for: start)?.start ?? calendar.startOfDay(for: start))
            : calendar.startOfDay(for: start)
        let last = byMonth
            ? (calendar.dateInterval(of: .month, for: end)?.start ?? calendar.startOfDay(for: end))
            : calendar.startOfDay(for: end)
        let count = (calendar.dateComponents([component], from: first, to: last).value(for: component) ?? 0) + 1
        guard count > 0 else { return [] }
        var buckets = Array(repeating: (income: 0.0, expense: 0.0), count: count)
        for point in daily {
            let anchor = byMonth
                ? (calendar.dateInterval(of: .month, for: point.date)?.start ?? point.date)
                : calendar.startOfDay(for: point.date)
            let index = calendar.dateComponents([component], from: first, to: anchor).value(for: component) ?? -1
            guard index >= 0 && index < count else { continue }
            buckets[index].income += point.income
            buckets[index].expense += point.expense
        }
        return buckets
    }

    /// La escala vertical de esas barras: lo que se apila hacia arriba y hacia abajo en cada día. Lo que entró va hacia
    /// arriba y lo que salió hacia abajo (o hacia arriba, `expensesUp`, en «Solo gastos»); una devolución da un lado
    /// negativo y su barra va al otro lado, así que se mira cada signo, no el máximo de cada lado. Sin nada, -1…1.
    static func flowChartRange(_ buckets: [(income: Double, expense: Double)], expensesUp: Bool) -> ClosedRange<Double> {
        var upper = 0.0
        var lower = 0.0
        for bucket in buckets {
            let values = [bucket.income, expensesUp ? bucket.expense : -bucket.expense]
            upper = max(upper, values.filter { $0 > 0 }.reduce(0, +))
            lower = min(lower, values.filter { $0 < 0 }.reduce(0, +))
        }
        return upper == lower ? -1...1 : lower...upper
    }

    /// Días de calendario desde `start` hasta `now`, contando los dos (el día 1 a cualquier hora es 1).
    static func daysElapsed(from start: Date, to now: Date, calendar: Calendar) -> Int {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: now)).day ?? 0
        return max(days, 0) + 1
    }

    /// Gasto acumulado día a día desde `start`: el valor `i` es lo gastado desde el día 0 hasta el día `i` incluido.
    /// Devuelve `days` valores (los días sin movimientos repiten el acumulado).
    static func cumulativeByDay(
        _ daily: [(date: Date, value: Double)],
        start: Date,
        days: Int,
        calendar: Calendar
    ) -> [Double] {
        guard days > 0 else { return [] }
        let startDay = calendar.startOfDay(for: start)
        var perDay = Array(repeating: 0.0, count: days)
        for point in daily {
            let index = calendar.dateComponents([.day], from: startDay, to: calendar.startOfDay(for: point.date)).day ?? -1
            if index >= 0 && index < days { perDay[index] += point.value }
        }
        var running = 0.0
        return perDay.map { running += $0; return running }
    }

    /// Promedio diario del período: lo gastado entre los días que van (en curso) o los que tuvo (pasado).
    static func dailyAverage(total: Double, start: Date, end: Date, now: Date, calendar: Calendar) -> Double {
        let last = min(end, now)
        let days = daysElapsed(from: start, to: last, calendar: calendar)
        return days > 0 ? total / Double(days) : total
    }

    // MARK: - Presupuestos

    /// Cuánto del período de un presupuesto ya pasó (0…1), con los mismos períodos con que la app calcula lo gastado
    /// para el widget (`WidgetDataCache.calculateBudgetSpent`): semana, mes o año de calendario en curso. `nil` en un
    /// presupuesto único (su período no viaja en la foto) o desconocido.
    static func elapsedFraction(periodType: String, now: Date, calendar: Calendar) -> Double? {
        let component: Calendar.Component
        switch periodType {
        case "weekly": component = .weekOfYear
        case "monthly": component = .month
        case "yearly": component = .year
        default: return nil
        }
        guard let interval = calendar.dateInterval(of: component, for: now), interval.duration > 0 else { return nil }
        return min(max(now.timeIntervalSince(interval.start) / interval.duration, 0), 1)
    }

    /// Lo que queda de un presupuesto: la misma cuenta que la app (`BudgetRemainingLogic.remaining`, que el widget no
    /// compila porque su fichero importa SwiftData). Negativo = te pasaste por esa cantidad. Medio céntimo de holgura.
    /// La paridad la fija `WidgetInsightsLogicTests`.
    static func budgetRemaining(limit: Double, spent: Double) -> Double {
        let value = limit - spent
        return abs(value) < 0.005 ? 0 : value
    }

    /// Te pasaste: lo gastado SUPERA el límite (`BudgetRemainingLogic.isOver`).
    static func budgetIsOver(limit: Double, spent: Double) -> Bool {
        budgetRemaining(limit: limit, spent: spent) < 0
    }

    // MARK: - Fechas

    /// Cuándo vence un pago, como lo dice el widget.
    enum DueLabel: Equatable {
        case overdue
        case today
        case tomorrow
        /// Entre 2 y 6 días.
        case inDays(Int)
        /// Más adelante: se escribe la fecha.
        case date
    }

    static func dueLabel(due: Date, isOverdue: Bool, now: Date, calendar: Calendar) -> DueLabel {
        if isOverdue { return .overdue }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: due)).day ?? 0
        switch days {
        case ..<0: return .overdue
        case 0: return .today
        case 1: return .tomorrow
        case 2...6: return .inDays(days)
        default: return .date
        }
    }

    /// El día de un movimiento: hoy, ayer, o la fecha.
    enum DayLabel: Equatable {
        case today, yesterday, date
    }

    static func dayLabel(for date: Date, now: Date, calendar: Calendar) -> DayLabel {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case 0: return .today
        case 1: return .yesterday
        default: return .date
        }
    }

    // MARK: - Desglose del gasto

    /// Los trozos de un desglose de gasto por categoría o subcategoría: lo gastado en NETO por clave, como la tarta de
    /// Estadísticas (`TopSpendingCategoriesCalculator`), donde una devolución resta de su categoría. Cada `expense` es lo
    /// que el movimiento aporta al gasto: positivo si gasta, negativo si es una devolución. El trozo es la magnitud del
    /// neto, y uno que queda en cero no sale. Van de mayor a menor y, a igual importe, en el orden en que aparecen.
    ///
    /// Hasta la card znu5 (2026-11-03) cada trozo sumaba la magnitud de cada movimiento: un gasto de 100 y su devolución
    /// de 30 daban un trozo de 130 contra un total de 70. Los porcentajes pasaban del 100 % y el centro de la tarta era
    /// menor que la suma de sus filas.
    static func netExpenseSlices<Key: Hashable>(_ contributions: [(key: Key, expense: Double)]) -> [(key: Key, amount: Double)] {
        var order: [Key] = []
        var net: [Key: Double] = [:]
        for contribution in contributions {
            if net[contribution.key] == nil { order.append(contribution.key) }
            net[contribution.key, default: 0] += contribution.expense
        }
        var slices: [(index: Int, key: Key, amount: Double)] = []
        for (index, key) in order.enumerated() {
            let amount = abs(net[key] ?? 0)
            if amount >= breakdownNoiseFloor { slices.append((index: index, key: key, amount: amount)) }
        }
        slices.sort { lhs, rhs in
            lhs.amount != rhs.amount ? lhs.amount > rhs.amount : lhs.index < rhs.index
        }
        return slices.map { (key: $0.key, amount: $0.amount) }
    }

    /// Por debajo de medio céntimo, un neto es el redondeo de un gasto y su devolución, no un trozo.
    static let breakdownNoiseFloor = 0.005

    /// El total de un desglose: la suma de TODOS sus trozos, también los que no caben en el widget. Es la cifra del centro
    /// de la tarta y el denominador de cada porcentaje, así que los porcentajes suman 100 % y el centro coincide con las
    /// filas. Es el gasto del período salvo que una categoría quede a favor (le devolvieron más de lo que se gastó en
    /// ella): entonces su trozo cuenta su magnitud, como en Estadísticas.
    static func breakdownTotal(_ amounts: [Double]) -> Double {
        amounts.reduce(0, +)
    }

    /// El porcentaje de un trozo sobre el total del desglose; 0 sin total.
    static func breakdownPercentage(_ amount: Double, of total: Double) -> Double {
        total > 0 ? amount / total * 100 : 0
    }

    // MARK: - Reparto en tarta

    /// Lo que suma la fila «Otros» de una leyenda: importe, porcentaje del total y cuántos trozos junta.
    struct PieOthers: Equatable {
        let amount: Double
        let percentage: Double
        let count: Int
    }

    /// Lo que enseña una tarta con leyenda: los trozos con fila propia y, si no caben todos, «Otros».
    struct PieLegend<Item> {
        let shown: [Item]
        let others: PieOthers?
    }

    /// Hasta `maxRows` filas. Con más trozos, los `maxRows - 1` primeros y una fila «Otros» con la suma del resto, como
    /// la tarta del Panel. El aro se agrupa igual, así que aro y leyenda dicen lo mismo. Los trozos llegan ordenados de
    /// mayor a menor (así los escribe la app) y aquí no se reordenan; el «Sin categoría» es uno más.
    ///
    /// `total` es la cifra que el widget enseña en el centro (el total del desglose, `breakdownTotal`). Lo que los trozos no cubren va
    /// también a «Otros»: en Subcategorías, el gasto sin subcategoría; en Categorías, lo que pasa del tope de filas que
    /// escribe la app. Sin eso el aro repartía el círculo entre una parte del total y sus arcos no medían su porcentaje
    /// (lo cazó la review de S35f2: cinco filas que sumaban el 95 % del centro). El porcentaje de «Otros» se mide contra
    /// `total`, como el de los trozos.
    static func pieLegend<Item>(
        _ items: [Item], maxRows: Int, total: Double, amount: (Item) -> Double, percentage: (Item) -> Double
    ) -> PieLegend<Item> {
        let rows = max(maxRows, 2)
        let covered = items.reduce(0) { $0 + amount($1) }
        // Una milésima del total es redondeo de la app, no gasto sin trozo.
        let uncovered = total - covered > total * 0.001 ? total - covered : 0
        let needsOthers = items.count > rows || (uncovered > 0 && items.count >= rows)
        let shown = needsOthers ? Array(items.prefix(rows - 1)) : items
        let rest = items.dropFirst(shown.count)
        let othersAmount = rest.reduce(0) { $0 + amount($1) } + uncovered
        guard othersAmount > 0 else { return PieLegend(shown: shown, others: nil) }
        let othersPercentage = total > 0
            ? othersAmount / total * 100
            : rest.reduce(0) { $0 + percentage($1) }
        return PieLegend(
            shown: shown,
            others: PieOthers(amount: othersAmount, percentage: othersPercentage, count: rest.count)
        )
    }

    // MARK: - Grupos

    /// El lado de una fila del widget «Grupos».
    enum GroupSide: Int, Equatable {
        case iOwe = 0
        case owedToMe = 1
        case settled = 2
    }

    /// Qué lado enseña un grupo. Con los dos lados (una divisa a favor y otra en contra), «debes»: primero lo que debes,
    /// como en la lista (decisión de Jürgen, 2026-10-30).
    static func groupSide(owes: Bool, isOwed: Bool) -> GroupSide {
        if owes { return .iOwe }
        if isOwed { return .owedToMe }
        return .settled
    }

    /// Las filas del widget: primero los grupos en los que debes, luego en los que te deben y al final los que están al
    /// día; dentro de cada lado, el orden en que llegan (el de la lista, por nombre). Como mucho `limit`.
    static func orderedGroupRows<Row>(_ rows: [Row], limit: Int, side: (Row) -> GroupSide) -> [Row] {
        rows.enumerated()
            .sorted { lhs, rhs in
                let (left, right) = (side(lhs.element).rawValue, side(rhs.element).rawValue)
                return left != right ? left < right : lhs.offset < rhs.offset
            }
            .prefix(max(0, limit))
            .map(\.element)
    }

    // MARK: - Pantalla bloqueada

    /// Una cifra en dos o tres glifos: «79,4K» en es-ES, «79.4K» en es-PE y en-US, «1,2M», «950». Con el separador
    /// decimal del idioma (hasta 2.2 salía siempre un punto) y sin espacio: en el aro de la pantalla bloqueada caben
    /// cinco caracteres.
    static func compactAmount(_ value: Double, locale: Locale) -> String {
        let magnitude = abs(value)
        let (scaled, suffix): (Double, String)
        // Los umbrales van medio redondeo por debajo: 999 950 se escribe «1M» y no «1000K»; 999,6, «1K» y no «1,000».
        if magnitude >= 999_950 {
            (scaled, suffix) = (magnitude / 1_000_000, "M")
        } else if magnitude >= 999.5 {
            (scaled, suffix) = (magnitude / 1_000, "K")
        } else {
            (scaled, suffix) = (magnitude, "")
        }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = suffix.isEmpty
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = suffix.isEmpty ? 0 : 1
        formatter.roundingMode = .halfUp
        let number = formatter.string(from: NSNumber(value: scaled)) ?? "0"
        // Lo que se pinta como cero no lleva signo («-0» de un saldo que suma cero en coma flotante).
        let shownAsZero = number == formatter.string(from: NSNumber(value: 0))
        return (value < 0 && !shownAsZero ? "-" : "") + number + suffix
    }
}
