//
//  FlujoTasaDelMes.swift
//  Yala
//
//  El tipo de cambio con el que el flujo de caja pasa un límite en otra moneda a la del plan (encargo del 2026-11-20,
//  pregunta `tasa`, opción A de Jürgen): «el promedio del mes».
//
//  - Mes cerrado: promedio de las tasas diarias de ese mes. No cambia más.
//  - Mes en curso: promedio de los días que van. Se mueve un poco cada día.
//  - Meses que vienen: la última tasa conocida, siempre con «≈».
//  - Días sin tasa: se promedian los que haya. Sin ningún día con su propia fila, el promedio de lo que la escalera del
//    converter arrastró (aproximado), y sin nada, la última tasa (aproximada).
//
//  Las tasas se piden en bloque (`CurrencyConverting.rateFactors`, una consulta para todos los días de todos los meses),
//  leídas a mediodía local como `BalanceValuation.rateDay`: las filas se indexan por fecha UTC.
//

import Foundation

enum FlujoTasaDelMes {

    /// De qué tramo del tiempo sale la tasa.
    enum Estado: Equatable {
        case cerrado
        /// `dias` = los días del mes que van (hoy incluido).
        case enCurso(dias: Int)
        case estimado
    }

    /// Cuánto vale una unidad de la moneda en la del plan ese mes, y de dónde sale.
    struct Tasa: Equatable {
        let factor: Double
        let estado: Estado
        /// La cifra lleva «≈»: un mes que viene, o uno sin días con su propia tasa.
        let esAproximada: Bool

        static let identidad = Tasa(factor: 1, estado: .cerrado, esAproximada: false)
    }

    // MARK: - El promedio (puro)

    /// El primer instante del mes y su estado frente a `hoy`.
    static func estado(mes: Date, hoy: Date, calendar: Calendar) -> Estado {
        guard let mesHoy = calendar.dateInterval(of: .month, for: hoy)?.start,
              let inicio = calendar.dateInterval(of: .month, for: mes)?.start else { return .estimado }
        if inicio < mesHoy { return .cerrado }
        if inicio > mesHoy { return .estimado }
        return .enCurso(dias: calendar.component(.day, from: hoy))
    }

    /// Los días del mes cuya tasa entra en el promedio, a mediodía local: todos en un mes cerrado, hasta hoy en el mes en
    /// curso y ninguno en uno que viene.
    static func dias(mes: Date, hoy: Date, calendar: Calendar) -> [Date] {
        guard let intervalo = calendar.dateInterval(of: .month, for: mes),
              let cuantos = calendar.range(of: .day, in: .month, for: intervalo.start)?.count else { return [] }
        let tope: Int
        switch estado(mes: mes, hoy: hoy, calendar: calendar) {
        case .cerrado: tope = cuantos
        case .enCurso(let dias): tope = min(dias, cuantos)
        case .estimado: return []
        }
        return (0..<tope).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: intervalo.start)
                .flatMap { calendar.date(bySettingHour: 12, minute: 0, second: 0, of: $0) }
        }
    }

    /// El promedio del mes de `codigo` en la moneda del plan, con las tasas de cada día ya leídas (`factores`, de
    /// `rateFactors`) y la última conocida (`ultima`). Misma moneda: 1.
    static func promedio(
        mes: Date, de codigo: String, a destino: String, hoy: Date,
        factores: [Date: [String: RateFactor]], ultima: RateFactor?, calendar: Calendar
    ) -> Tasa {
        let estado = estado(mes: mes, hoy: hoy, calendar: calendar)
        guard codigo != destino else { return Tasa(factor: 1, estado: estado, esAproximada: false) }
        let delUltimo = ultima.map { NSDecimalNumber(decimal: $0.factor).doubleValue } ?? 0
        if case .estimado = estado {
            return Tasa(factor: delUltimo, estado: .estimado, esAproximada: true)
        }
        var exactas: [Double] = []
        var arrastradas: [Double] = []
        for dia in dias(mes: mes, hoy: hoy, calendar: calendar) {
            guard let tasa = factores[dia]?[codigo] else { continue }
            let valor = NSDecimalNumber(decimal: tasa.factor).doubleValue
            guard valor.isFinite, valor > 0 else { continue }
            switch tasa.quality {
            case .exact: exactas.append(valor)
            case .carriedForward: arrastradas.append(valor)
            case .staticFallback: break
            }
        }
        if !exactas.isEmpty {
            return Tasa(factor: exactas.reduce(0, +) / Double(exactas.count), estado: estado, esAproximada: false)
        }
        if !arrastradas.isEmpty {
            return Tasa(factor: arrastradas.reduce(0, +) / Double(arrastradas.count), estado: estado, esAproximada: true)
        }
        return Tasa(factor: delUltimo, estado: estado, esAproximada: true)
    }

    // MARK: - La tabla de un cálculo

    /// Las tasas de las monedas y los meses que pide un cálculo, leídas una vez.
    struct Tabla {
        let destino: String
        private let tasas: [String: Tasa]
        private let calendar: Calendar

        init(destino: String, tasas: [String: Tasa], calendar: Calendar) {
            self.destino = destino
            self.tasas = tasas
            self.calendar = calendar
        }

        /// La tasa de `codigo` en el mes de `mes`. Una moneda o un mes que la tabla no leyó: `nil`.
        func tasa(_ codigo: String, mes: Date) -> Tasa? {
            if codigo == destino { return .identidad }
            return tasas[Tabla.clave(codigo, mes: mes, calendar: calendar)]
        }

        static func clave(_ codigo: String, mes: Date, calendar: Calendar) -> String {
            "\(codigo)|\(CashFlowProjectionCalculator.monthKey(for: mes, calendar: calendar))"
        }
    }

    /// Lee de una vez las tasas de `codigos` en los `meses` (una consulta a `rateFactors` y una última tasa por moneda).
    static func tabla(
        codigos: Set<String>, meses: [Date], a destino: String, hoy: Date,
        converter: any CurrencyConverting, calendar: Calendar
    ) -> Tabla {
        let extranjeras = codigos.subtracting([destino]).filter { !$0.isEmpty }
        guard !extranjeras.isEmpty, !meses.isEmpty else { return Tabla(destino: destino, tasas: [:], calendar: calendar) }
        let todosLosDias = Array(Set(meses.flatMap { dias(mes: $0, hoy: hoy, calendar: calendar) })).sorted()
        let factores = todosLosDias.isEmpty
            ? [:] : converter.rateFactors(for: extranjeras, to: destino, on: todosLosDias)
        var tasas: [String: Tasa] = [:]
        for codigo in extranjeras {
            let ultima = converter.convertCheckedWithLatestRate(1, from: codigo, to: destino)
            let ultimaTasa = RateFactor(factor: ultima.amount, quality: ultima.quality)
            for mes in meses {
                tasas[Tabla.clave(codigo, mes: mes, calendar: calendar)] = promedio(
                    mes: mes, de: codigo, a: destino, hoy: hoy, factores: factores, ultima: ultimaTasa, calendar: calendar
                )
            }
        }
        return Tabla(destino: destino, tasas: tasas, calendar: calendar)
    }
}
