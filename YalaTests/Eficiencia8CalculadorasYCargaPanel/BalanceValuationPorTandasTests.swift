//
//  BalanceValuationPorTandasTests.swift
//  YalaTests / Eficiencia8CalculadorasYCargaPanel
//
//  Lote 8 de eficiencia (27-nov-2026). La valoración de una curva de saldo (`BalanceValuation`) lee las tasas de todos sus
//  cierres de una vez; en la foto de los widgets eran ~146 ms sin ceder en el iPhone 14 (~300 cierres, de hoy a diez años
//  atrás). Ahora la foto las lee por tandas de días (`BalanceValuation.LecturaDeTasas`) y cede entre una y otra.
//
//  Se fija que la valoración con las tasas leídas por tandas —de cualquier tamaño— vale lo mismo, cierre a cierre, que la
//  de una vez, con el converter real sobre el fixture que hace fallar a este módulo (`currency-fx.md`): filas parciales,
//  huecos, una tasa a cero, cierres anteriores a cualquier fila, una divisa que ninguna fila trae y relleno a más de 30
//  filas. Y que la curva de la foto por etapas sale igual que la de una vez y lee sus tasas en más de una tanda.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Eficiencia 8 · la valoración con tasas leídas por tandas vale lo mismo", .serialized)
struct BalanceValuationPorTandasTests {

    private static let utc: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private let calendar = Calendar.current
    private let start = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 12)) ?? Date()

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: start) ?? start
    }

    /// 120 días con filas casi diarias: un hueco cada 7 días, EUR ausente los múltiplos de 5, PEN a cero el día 12, una fila
    /// con solo USD el día 20 y un tramo de 40 días sin filas (60-99). Nada antes del día 0.
    private func seedRows(_ context: ModelContext) throws {
        for offset in 0..<120 where offset % 7 != 3 && !(60..<100).contains(offset) {
            var rates: [String: Double] = [
                "USD": 1, "PEN": 3.6 + Double(offset) * 0.01, "MXN": 18 + Double(offset) * 0.05,
            ]
            if offset % 5 != 0 { rates["EUR"] = 0.9 + Double(offset) * 0.001 }
            if offset == 12 { rates["PEN"] = 0 }
            if offset == 20 { rates = ["USD": 1] }
            context.insert(try ExchangeRate(dateKey: Self.utc.string(from: day(offset)), base: "USD",
                                            ratesDictionary: rates))
        }
        try context.save()
    }

    @Test("Por tandas de 1, 7 y 24 días vale lo mismo que de una vez, en cada cierre y para cada divisa principal",
          arguments: ["PEN", "USD", "MXN"])
    func porTandas_igualQueDeUnaVez(_ principal: String) throws {
        let context = try makeTestContext()
        try seedRows(context)
        let converter = CurrencyConverter()
        converter.setContext(context)
        let ahora = day(130)
        // Cierres de hoy hacia atrás, a mediodía, al último segundo del día y a medianoche, también antes de la primera fila.
        let cierres = (-15..<131).flatMap { offset -> [Date] in
            let mediodia = day(offset)
            let inicio = calendar.startOfDay(for: mediodia)
            return [mediodia, inicio, inicio.addingTimeInterval(86_399)]
        }
        let divisas: Set<String> = ["PEN", "USD", "EUR", "MXN", "JPY"]
        let deUnaVez = BalanceValuation(currencies: divisas, to: principal, closingDates: cierres, converter: converter,
                                        now: ahora, calendar: calendar)
        let saldo: [String: Decimal] = ["PEN": 1_000, "USD": -250, "EUR": 80, "MXN": 3_000, "JPY": 12_000]
        var deUnaVezLeida = BalanceValuation.LecturaDeTasas(
            currencies: divisas, to: principal, closingDates: cierres, converter: converter, now: ahora, calendar: calendar)
        deUnaVezLeida.leerTodo()

        for tamano in [1, 7, 24] {
            var lectura = BalanceValuation.LecturaDeTasas(
                currencies: divisas, to: principal, closingDates: cierres, converter: converter, now: ahora,
                calendar: calendar)
            var tandas = 0
            while !lectura.terminada {
                lectura.leerTanda(dias: tamano)
                tandas += 1
            }
            let porTandas = BalanceValuation(lectura: lectura)
            #expect(tandas > 1, "una sola tanda no prueba nada (tamaño \(tamano))")
            // Las tasas leídas, día a día: si faltara una, `value` la pediría sola y daría el mismo número, así que la
            // comparación de valores no lo vería. Sin esto, una tanda que pisara a las anteriores pasaba.
            #expect(lectura.factorsByDay == deUnaVezLeida.factorsByDay, "tamaño \(tamano): las tasas leídas cambiaron")
            #expect(lectura.factorsByDay.count > 100)
            var distintos: [String] = []
            for cierre in cierres {
                let a = deUnaVez.value(saldo, at: cierre)
                let b = porTandas.value(saldo, at: cierre)
                if a.total != b.total || a.approximateMagnitude != b.approximateMagnitude {
                    distintos.append("\(cierre): \(a.total) ≠ \(b.total)")
                }
            }
            #expect(distintos.isEmpty, "tamaño \(tamano): \(distintos.prefix(5))")
        }
    }

    @Test("Sin divisas ajenas no queda ninguna tasa por leer")
    func sinDivisasAjenas_noLee() throws {
        let context = try makeTestContext()
        try seedRows(context)
        let converter = CurrencyConverter()
        converter.setContext(context)
        let lectura = BalanceValuation.LecturaDeTasas(
            currencies: ["PEN"], to: "PEN", closingDates: [day(3), day(40)], converter: converter, now: day(130),
            calendar: calendar)
        #expect(lectura.terminada)
        #expect(lectura.diasPendientes == 0)
    }

    @Test("La curva de la foto por etapas sale igual que la de una vez")
    func curvaDeLaFoto_porEtapas_igualQueDeUnaVez() throws {
        let context = try makeTestContext()
        let now = CalculadorasLote8Fixture.ahora
        try CalculadorasLote8Fixture.seed(context, count: 1_600, now: now)
        let whole = WidgetDataCache.buildSnapshot(context: context, now: now)
        let (etapas, terminar) = WidgetDataCache.buildSnapshot(etapasDe: context, now: now)
        for etapa in etapas {
            while !etapa() {}
        }
        let staged = terminar()
        #expect(try FotoFilasFixture.encoded(staged.widget.trendData) == FotoFilasFixture.encoded(whole.widget.trendData))
        #expect(whole.widget.trendData.monthlyPoints.count > 6)
    }
}
