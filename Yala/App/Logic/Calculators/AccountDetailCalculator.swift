//
//  AccountDetailCalculator.swift
//  Yala
//
//  Los números de la vista de una cuenta (la hoja que abre su tarjeta del Panel) para el período del Panel:
//  qué entró y qué salió, la evolución del saldo día a día, en qué se fue el gasto y los últimos movimientos.
//  Lógica pura sobre `Entry`, sin SwiftData, para poder fijar los bordes con tests.
//
//  Tres decisiones que no son obvias:
//  - **El saldo es la suma de los importes de la cuenta**, igual que `AccountBalanceCalculator` (la tarjeta), y la
//    curva acumula día a día hasta HOY. Su último punto es el número de la tarjeta salvo que haya movimientos fechados
//    en el futuro: la tarjeta los suma ya y la curva no, porque todavía no han pasado (lo fija un test).
//  - **«Entró» y «Salió» son movimiento de dinero de la cuenta**: cuentan transferencias y ajustes por registro,
//    porque mueven su saldo. Lo único que no cuenta es el saldo inicial, que no es dinero que entre sino el punto de
//    partida. Así «saldo al empezar + entró − salió» cuadra con la curva salvo por ese saldo inicial.
//  - **«En qué se fue» es gasto**, con la misma regla que lo gastado por cuenta del Panel: `AccountSpendingLogic`
//    (sin ajustes ni transferencias, categoría no de ingreso, y una devolución resta).
//

import Foundation

nonisolated enum AccountDetailCalculator {

    /// Un movimiento de la cuenta, reducido a lo que la vista necesita.
    struct Entry: Equatable {
        let id: String
        let date: Date
        /// Importe con signo, en la moneda de la cuenta (como lo suma `AccountBalanceCalculator`).
        let amount: Double
        /// `TransactionItem.balanceAdjustmentType`: `nil` para un registro normal.
        let adjustmentType: String?
        let categoryKey: String?
        let categoryName: String?
        let categoryColorHex: String?
        let categoryIsIncome: Bool?
        let title: String
    }

    struct DayBalance: Equatable {
        let day: Date
        let balance: Double
    }

    struct CategoryTotal: Equatable {
        let key: String
        let name: String
        let colorHex: String?
        let amount: Double
    }

    struct Summary: Equatable {
        let moneyIn: Double
        let moneyOut: Double
        let series: [DayBalance]
        let topCategories: [CategoryTotal]
        let latest: [Entry]

        var hasActivity: Bool { !latest.isEmpty }
    }

    static let initialBalanceType = "initial_balance"
    static let topCategoriesLimit = 3
    static let latestLimit = 5

    static func summary(
        entries: [Entry],
        interval: DateInterval,
        now: Date,
        calendar: Calendar
    ) -> Summary {
        let inPeriod = entries.filter { interval.contains($0.date) }
        let flows = inPeriod.filter { $0.adjustmentType != initialBalanceType }

        let moneyIn = flows.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        let moneyOut = flows.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }

        return Summary(
            moneyIn: moneyIn,
            moneyOut: moneyOut,
            series: dailyBalances(entries: entries, interval: interval, now: now, calendar: calendar),
            topCategories: topCategories(in: inPeriod),
            latest: Array(
                flows.sorted { $0.date == $1.date ? $0.id > $1.id : $0.date > $1.date }.prefix(latestLimit)
            )
        )
    }

    /// Saldo al cierre de cada día del período, de su primer día (o del primer movimiento, si es posterior) a hoy
    /// (o al último día, si el período ya terminó). Un período que empieza en el futuro no tiene días que pintar.
    static func dailyBalances(
        entries: [Entry],
        interval: DateInterval,
        now: Date,
        calendar: Calendar
    ) -> [DayBalance] {
        // La curva empieza el día del primer movimiento si es posterior al inicio del período: antes la cuenta no
        // existía, y con «Todo el tiempo» eso era una línea plana en cero de casi todo el ancho.
        let earliest = entries.map(\.date).min()
        let periodStart = calendar.startOfDay(for: interval.start)
        let firstDay = earliest.map { max(periodStart, calendar.startOfDay(for: $0)) } ?? periodStart
        let lastDay = calendar.startOfDay(for: min(interval.end, now))
        guard firstDay <= lastDay else { return [] }

        var days: [Date] = []
        var cursor = firstDay
        while cursor <= lastDay {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        // Saldo al cierre de un día = todo lo fechado ANTES del inicio del día siguiente. Se compara contra el inicio
        // del día siguiente y no contra 23:59:59: un registro a medianoche exacta es del día que empieza, no del
        // anterior (la trampa de `DateInterval` cerrado de CLAUDE.md).
        let sorted = entries.sorted { $0.date < $1.date }
        var result: [DayBalance] = []
        var index = 0
        var running = 0.0
        for day in days {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            while index < sorted.count, sorted[index].date < nextDay {
                running += sorted[index].amount
                index += 1
            }
            result.append(DayBalance(day: day, balance: running))
        }
        return result
    }

    /// Gasto acumulado al cierre de cada día del período, con la misma regla que «En qué se fue». Es la curva del modo
    /// «solo gastos», donde el saldo no se enseña.
    static func dailySpending(
        entries: [Entry],
        interval: DateInterval,
        now: Date,
        calendar: Calendar
    ) -> [DayBalance] {
        let spending = entries
            .filter { interval.contains($0.date) }
            .compactMap { entry in spent(entry).map { Entry(
                id: entry.id, date: entry.date, amount: $0, adjustmentType: nil, categoryKey: nil,
                categoryName: nil, categoryColorHex: nil, categoryIsIncome: nil, title: ""
            ) } }
        return dailyBalances(entries: spending, interval: interval, now: now, calendar: calendar)
    }

    static func isExpense(_ entry: Entry) -> Bool {
        AccountSpendingLogic.countsAsSpending(adjustmentType: entry.adjustmentType, categoryIsIncome: entry.categoryIsIncome)
    }

    /// Lo que el movimiento aporta a lo gastado (`nil` si no es gasto): una devolución resta.
    static func spent(_ entry: Entry) -> Double? {
        AccountSpendingLogic.spending(
            amount: entry.amount, adjustmentType: entry.adjustmentType, categoryIsIncome: entry.categoryIsIncome
        )
    }

    static func topCategories(in entries: [Entry]) -> [CategoryTotal] {
        var totals: [String: CategoryTotal] = [:]
        for entry in entries {
            guard let spent = spent(entry), let key = entry.categoryKey
            else { continue }
            let previous = totals[key]?.amount ?? 0
            totals[key] = CategoryTotal(
                key: key,
                name: entry.categoryName ?? "",
                colorHex: entry.categoryColorHex,
                amount: previous + spent
            )
        }
        return Array(
            totals.values
                .filter { $0.amount > 0 }
                .sorted { $0.amount == $1.amount ? $0.name < $1.name : $0.amount > $1.amount }
                .prefix(topCategoriesLimit)
        )
    }
}
