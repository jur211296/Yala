//
//  CashFlowMonthSummaryLogic.swift
//  Yala
//
//  Auditoría UX 2.2 · L18-11 (opción C, variante 2): el resumen del mes en frases en vez de «Disponible» y «Acumulado»
//  con «?»: «Este mes te sobran S/ 3,283», «Si sigue así, a fin de diciembre tendrías S/ 12,028», «Empezaste con S/ 0 ·
//  Cambiar» y «Llevas el 68 % de lo que planeaste gastar». Las frases cambian con el mes elegido: lo que ya pasó se dice
//  en pasado y lo que viene en condicional, y «te faltan» cuando sale más de lo que entra.
//
//  Lógica pura: lo que pinta la vista sale de aquí.
//

import Foundation

enum CashFlowMonthSummaryLogic {

    /// El rótulo de la cifra grande del mes (sin el monto): «Este mes te sobran», «En noviembre te sobrarían»…
    static func heroLabel(for month: CashFlowMonth) -> String {
        let surplus = month.netFlow >= 0
        let name = monthInSentence(month.date)
        if month.isCurrent {
            return surplus ? L10n.UXL18.surplusThisMonth : L10n.UXL18.shortfallThisMonth
        }
        if month.isPast {
            return surplus ? L10n.UXL18.surplusPast(name) : L10n.UXL18.shortfallPast(name)
        }
        return surplus ? L10n.UXL18.surplusFuture(name) : L10n.UXL18.shortfallFuture(name)
    }

    /// El último mes del plan con saldo acumulado: el «a fin de diciembre» de la frase. `nil` si ningún mes lo tiene.
    static func projectedEnd(of months: [CashFlowMonth]) -> CashFlowMonth? {
        months.last { $0.accumulatedBalance != nil }
    }

    /// El nombre del mes para «a fin de …»: con año si no es el año en curso.
    static func monthName(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        calendar.component(.year, from: date) == calendar.component(.year, from: now)
            ? monthInSentence(date)
            : date.formatted(.dateTime.month(.wide).year())
    }

    /// El mes para dentro de una frase («en noviembre», «Monto para noviembre»). `.month(.wide)` a secas da la forma
    /// suelta del mes, que en español va con mayúscula («Noviembre»); `MMMM` es la de dentro de una frase.
    static func monthInSentence(_ date: Date, calendar: Calendar = .current, locale: Locale = AppLocale.current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date)
    }

    /// Cuánto se lleva gastado de lo planeado en el mes en curso, en %. `nil` fuera del mes en curso o sin plan de gasto.
    static func spentShare(of month: CashFlowMonth) -> Int? {
        guard month.isCurrent else { return nil }
        let planned = month.expenseLines.reduce(0.0) { $0 + $1.plannedAmount }
        guard planned > 0 else { return nil }
        let real = month.expenseLines.reduce(0.0) { $0 + ($1.realAmount ?? 0) }
        return Int((real / planned) * 100)
    }
}
