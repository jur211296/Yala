//
//  BalanceValuation.swift
//  Yala
//
//  Cuánto vale un saldo en la divisa principal en una fecha: lo que había en cada divisa NATIVA ese día, por el
//  tipo de cambio de ESA fecha. Es la regla contable para el dinero en cuenta, y la que eligió Jürgen el
//  2026-10-16 para las curvas de saldo (ticket `panel-balance-chart-contradicts-its-own-figure`).
//
//  **Hoy no se valora con la tasa del día: se valora con la regla del saldo vivo** (`LiveBalanceCalculator`,
//  `convertAtLatestRate`). Es la cifra que la curva tiene al lado, y así su último punto la iguala por
//  construcción, no por casualidad de que las dos rutas del converter coincidan.
//
//  Antes cada curva sumaba cada movimiento al tipo de SU fecha. Para un saldo eso no es ningún valor: con una
//  cuenta en dólares la curva acababa lejos de la cifra («+179,062» y la curva en ~201K).
//

import Foundation

@MainActor
struct BalanceValuation {

    private let preferredCurrencyCode: String
    private let converter: CurrencyConverting
    private let startOfToday: Date
    private let calendar: Calendar
    private let factorsByDay: [Date: [String: RateFactor]]

    /// - Parameters:
    ///   - currencies: las divisas nativas que pueden aparecer en los saldos que se van a valorar.
    ///   - closingDates: los instantes en que se valorará (`closingInstant`). Las tasas de los que caen antes de
    ///     hoy se leen aquí, de una vez (`CurrencyConverting.rateFactors`).
    init(
        currencies: Set<String>,
        to preferredCurrencyCode: String,
        closingDates: [Date],
        converter: CurrencyConverting,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        self.preferredCurrencyCode = preferredCurrencyCode
        self.converter = converter
        self.calendar = calendar
        let startOfToday = calendar.startOfDay(for: now)
        self.startOfToday = startOfToday
        let foreign = currencies.subtracting([preferredCurrencyCode])
        let pastDays = Set(closingDates.filter { $0 < startOfToday }.map { Self.rateDay(of: $0, calendar: calendar) })
        if foreign.isEmpty || pastDays.isEmpty {
            factorsByDay = [:]
        } else {
            factorsByDay = converter.rateFactors(for: foreign, to: preferredCurrencyCode, on: Array(pastDays))
        }
    }

    /// El instante con el que se pide la tasa del día LOCAL de `instant`: ese mismo día del calendario, a mediodía
    /// UTC. El converter indexa las filas por fecha en UTC, así que este instante cae siempre en la fila de ese día,
    /// en cualquier zona (la medianoche local cae en el día anterior al este de Greenwich, y el mediodía local
    /// también en UTC+13 y +14).
    static func rateDay(of instant: Date, calendar: Calendar) -> Date {
        let parts = calendar.dateComponents([.year, .month, .day], from: instant)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return utc.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day, hour: 12))
            ?? calendar.startOfDay(for: instant)
    }

    /// Cuándo cierra un bucket que empieza en `bucketStart`: el último instante antes del siguiente, sin pasar de
    /// `cap` (hoy, o el final del periodo mostrado).
    static func closingInstant(
        bucketStart: Date, grouping: TrendGrouping, cap: Date, calendar: Calendar
    ) -> Date {
        let next = calendar.date(byAdding: grouping.calendarComponent, value: 1, to: bucketStart) ?? bucketStart
        return min(next.addingTimeInterval(-1), cap)
    }

    /// El saldo `native` valorado en `instant`, en la divisa principal, con la magnitud convertida con una tasa que
    /// no era exacta (el numerador de `ApproximateMarkThreshold`).
    func value(_ native: [String: Decimal], at instant: Date) -> (total: Decimal, approximateMagnitude: Decimal) {
        if instant >= startOfToday {
            return LiveBalanceCalculator.convertAtLatestRate(native, to: preferredCurrencyCode, converter: converter)
        }
        let day = Self.rateDay(of: instant, calendar: calendar)
        let factors = factorsByDay[day]
        var total: Decimal = 0
        var approximateMagnitude: Decimal = 0
        for code in native.keys.sorted() {
            guard let amount = native[code] else { continue }
            if code == preferredCurrencyCode {
                total += amount
                continue
            }
            let factor: RateFactor
            if let known = factors?[code] {
                factor = known
            } else {
                // Una divisa que no se anunció al construir: la misma tasa, pedida sola.
                let converted = converter.convertChecked(1, from: code, to: preferredCurrencyCode, on: day)
                factor = RateFactor(factor: converted.amount, quality: converted.quality)
            }
            let converted = amount * factor.factor
            total += converted
            if !factor.quality.isExact {
                approximateMagnitude += abs(converted)
            }
        }
        return (total, approximateMagnitude)
    }

    func doubleValue(_ native: [String: Decimal], at instant: Date) -> Double {
        (value(native, at: instant).total as NSDecimalNumber).doubleValue
    }
}
