//
//  FlujoLimiteEnMoneda.swift
//  Yala
//
//  El límite de una línea del flujo de caja que no sale de tus registros (encargo del 2026-11-20, decisiones de Jürgen
//  `metodo`, `mezcla`, `fijo` y `borrado`, todas las recomendadas):
//  - «Pagos planificados»: la suma de los pagos de la línea que caen en ese mes, cada uno convertido por separado con el
//    promedio del mes de su moneda, más un extra opcional en la moneda del flujo. Un pago pausado, terminado o que no cae
//    en el mes suma 0; uno borrado (o que aún no llegó por iCloud) también, y sin pagos ni extra la línea cae a su
//    `manualAmount`, el último límite que se guardó.
//  - «Monto fijo» en otra moneda: el mismo monto todos los meses, convertido con el promedio de cada mes.
//
//  Lo leen el cálculo del plan (`CashFlowProjectionCalculator.resolvePlanned`), «Cálculo del monto», el detalle de la
//  línea, «Cómo se convierte» y el resumen del mes: todos dicen la misma cifra porque salen de aquí.
//

import Foundation
import SwiftData

enum FlujoLimiteEnMoneda {

    // MARK: - Los ids de la línea

    /// Los ids de `scheduledPaymentIDsRaw`, en orden y sin repetidos. Lo que no es un UUID se salta.
    static func parseIDs(_ raw: String?) -> [UUID] {
        guard let raw, !raw.isEmpty else { return [] }
        var vistos = Set<UUID>()
        return raw.split(separator: ",").compactMap { parte in
            guard let id = UUID(uuidString: parte.trimmingCharacters(in: .whitespaces)), vistos.insert(id).inserted
            else { return nil }
            return id
        }
    }

    /// La forma guardada de una lista de ids; `nil` si está vacía.
    static func serializeIDs(_ ids: [UUID]) -> String? {
        var vistos = Set<UUID>()
        let unicos = ids.filter { vistos.insert($0).inserted }
        return unicos.isEmpty ? nil : unicos.map(\.uuidString).joined(separator: ",")
    }

    // MARK: - El resultado de un mes

    enum EstadoPago: Equatable {
        case suma
        case pausado
        case terminado(Date)
        case noCae
        /// No se encontró: se borró, o aún no llegó por iCloud.
        case noEsta
    }

    struct PagoDelMes: Identifiable {
        let id: UUID
        let nombre: String
        let moneda: String
        /// El importe de cada vez, en su moneda (magnitud).
        let importe: Double
        let ocurrencias: Int
        /// Lo que suma este mes en la moneda del plan.
        let convertido: Double
        let tasa: FlujoTasaDelMes.Tasa
        let estado: EstadoPago
        let esVariable: Bool
    }

    struct Original: Equatable {
        let monto: Double
        let moneda: String
    }

    struct Resultado {
        let monto: Double
        let esAproximado: Bool
        /// Los pagos de la línea en el mes (vacío en un monto fijo).
        let pagos: [PagoDelMes]
        let extra: Double?
        /// Lo que se enseña como original («500 USD»): el monto fijo en otra moneda, o los pagos que suman este mes
        /// cuando están todos en la misma moneda extranjera y no hay extra.
        let original: Original?
        /// La tasa del mes de la moneda del original (o de la única moneda extranjera que suma).
        let tasa: FlujoTasaDelMes.Tasa?
        /// Las monedas distintas de la del plan que entran en la cifra este mes.
        let monedasExtranjeras: Set<String>
        /// Sin ningún pago encontrado ni extra: el límite es el respaldo (`manualAmount`).
        let sinNada: Bool
    }

    /// Los pagos de la línea en el mes y su suma. `tasa` da el promedio del mes de una moneda.
    static func pagosDelMes(
        ids: [UUID], pagosPorID: [UUID: ScheduledPayment], extra: Double?, mes: Date, monedaPlan: String,
        tasa: (String, Date) -> FlujoTasaDelMes.Tasa, calendar: Calendar
    ) -> Resultado {
        guard let intervalo = calendar.dateInterval(of: .month, for: mes) else {
            return Resultado(monto: 0, esAproximado: false, pagos: [], extra: extra, original: nil, tasa: nil,
                             monedasExtranjeras: [], sinNada: true)
        }
        var pagos: [PagoDelMes] = []
        var total = 0.0
        var dudoso = 0.0
        for id in ids {
            guard let pago = pagosPorID[id], !pago.isDeleted else {
                pagos.append(PagoDelMes(id: id, nombre: "", moneda: monedaPlan, importe: 0, ocurrencias: 0, convertido: 0,
                                        tasa: .identidad, estado: .noEsta, esVariable: false))
                continue
            }
            let moneda = pago.currencyCode.isEmpty ? monedaPlan : pago.currencyCode
            let tasaMes = tasa(moneda, intervalo.start)
            let importe = abs(pago.amount)
            let estado: EstadoPago
            var ocurrencias = 0
            if !pago.isActive {
                estado = .pausado
            } else if let fin = pago.endDate, calendar.startOfDay(for: fin) < intervalo.start {
                estado = .terminado(fin)
            } else {
                ocurrencias = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                    params: pago.dateCalculatorParams, month: intervalo.start, calendar: calendar
                ).count
                estado = ocurrencias > 0 ? .suma : .noCae
            }
            let convertido = importe * Double(ocurrencias) * tasaMes.factor
            if estado == .suma {
                total += convertido
                if tasaMes.esAproximada { dudoso += convertido }
            }
            pagos.append(PagoDelMes(
                id: id, nombre: pago.name, moneda: moneda, importe: importe, ocurrencias: ocurrencias,
                convertido: convertido, tasa: tasaMes, estado: estado, esVariable: pago.isVariableAmount
            ))
        }
        let extraVivo = extra.flatMap { $0 > 0 ? $0 : nil }
        total += extraVivo ?? 0
        let quesuman = pagos.filter { $0.estado == .suma }
        let extranjeras = Set(quesuman.map(\.moneda)).subtracting([monedaPlan])
        var original: Original?
        var tasaOriginal: FlujoTasaDelMes.Tasa?
        if extranjeras.count == 1, let moneda = extranjeras.first {
            tasaOriginal = quesuman.first { $0.moneda == moneda }?.tasa
            if extraVivo == nil, quesuman.allSatisfy({ $0.moneda == moneda }) {
                original = Original(monto: quesuman.reduce(0) { $0 + $1.importe * Double($1.ocurrencias) }, moneda: moneda)
            }
        }
        let sinNada = extraVivo == nil && !pagos.contains { $0.estado != .noEsta }
        // «≈» solo si lo convertido con una tasa aproximada pesa en la cifra que se pinta, la regla de toda la app
        // (`ApproximateMarkThreshold`): 3 USD de iCloud en un mes que viene no marcan una línea de S/ 1,861.
        let aproximado = dudoso > 0 && ApproximateMarkThreshold.marks(approximate: dudoso, total: total)
        return Resultado(monto: total, esAproximado: aproximado, pagos: pagos, extra: extraVivo, original: original,
                         tasa: tasaOriginal, monedasExtranjeras: extranjeras, sinNada: sinNada)
    }

    /// Un monto fijo en otra moneda, convertido con el promedio del mes.
    static func fijo(
        monto: Double, moneda: String, mes: Date, tasa: (String, Date) -> FlujoTasaDelMes.Tasa, calendar: Calendar
    ) -> Resultado {
        let inicio = calendar.dateInterval(of: .month, for: mes)?.start ?? mes
        let tasaMes = tasa(moneda, inicio)
        return Resultado(monto: abs(monto) * tasaMes.factor, esAproximado: tasaMes.esAproximada, pagos: [], extra: nil,
                         original: Original(monto: abs(monto), moneda: moneda), tasa: tasaMes,
                         monedasExtranjeras: [moneda], sinNada: false)
    }

    // MARK: - Las fuentes de un cálculo

    /// Lo que hace falta para calcular estos límites, leído una vez: los pagos por id y las tasas de cada mes.
    struct Fuentes {
        let pagosPorID: [UUID: ScheduledPayment]
        let tabla: FlujoTasaDelMes.Tabla
        let hoy: Date
        let converter: any CurrencyConverting

        /// El promedio del mes de una moneda: de la tabla, o leído en el acto si la tabla no lo tiene.
        func tasa(_ moneda: String, mes: Date, calendar: Calendar) -> FlujoTasaDelMes.Tasa {
            if let leida = tabla.tasa(moneda, mes: mes) { return leida }
            return FlujoTasaDelMes.tabla(
                codigos: [moneda], meses: [mes], a: tabla.destino, hoy: hoy, converter: converter, calendar: calendar
            ).tasa(moneda, mes: mes) ?? .identidad
        }

        /// Los pagos y las tasas de todas las líneas del plan en los meses del cálculo. Un id que `scheduledPayments`
        /// no trae se busca en el almacén de su línea (el Panel puede pasar los pagos filtrados).
        static func construir(
            lines: [CashFlowLine], scheduledPayments: [ScheduledPayment], meses: [Date], monedaPlan: String,
            converter: any CurrencyConverting, hoy: Date, calendar: Calendar
        ) -> Fuentes {
            var porID: [UUID: ScheduledPayment] = [:]
            for pago in scheduledPayments where !pago.isDeleted { porID[pago.id] = pago }
            var faltan: [UUID] = []
            var contexto: ModelContext?
            for line in lines where line.method == .scheduled {
                for id in line.scheduledPaymentIDs where porID[id] == nil {
                    faltan.append(id)
                    if contexto == nil { contexto = line.modelContext }
                }
                if let relacion = line.scheduledPayment, !relacion.isDeleted, porID[relacion.id] == nil {
                    porID[relacion.id] = relacion
                }
            }
            faltan.removeAll { porID[$0] != nil }
            if !faltan.isEmpty, let contexto {
                for pago in buscar(faltan, en: contexto) { porID[pago.id] = pago }
            }
            var monedas = Set<String>()
            for line in lines {
                if line.method == .scheduled {
                    for id in line.scheduledPaymentIDs { if let pago = porID[id] { monedas.insert(pago.currencyCode) } }
                } else if let fijo = line.foreignFixedLimit(planCurrency: monedaPlan) {
                    monedas.insert(fijo.currencyCode)
                }
            }
            let tabla = FlujoTasaDelMes.tabla(
                codigos: monedas, meses: meses, a: monedaPlan, hoy: hoy, converter: converter, calendar: calendar
            )
            return Fuentes(pagosPorID: porID, tabla: tabla, hoy: hoy, converter: converter)
        }

        /// Las de una sola línea (detalle, «Cálculo del monto»), con los pagos de su almacén.
        static func deLinea(
            _ line: CashFlowLine, meses: [Date], monedaPlan: String, converter: any CurrencyConverting, hoy: Date,
            calendar: Calendar
        ) -> Fuentes {
            construir(lines: [line], scheduledPayments: [], meses: meses, monedaPlan: monedaPlan, converter: converter,
                      hoy: hoy, calendar: calendar)
        }

        private static func buscar(_ ids: [UUID], en contexto: ModelContext) -> [ScheduledPayment] {
            let descriptor = FetchDescriptor<ScheduledPayment>(predicate: #Predicate<ScheduledPayment> { ids.contains($0.id) })
            do {
                return try contexto.fetch(descriptor)
            } catch {
                #if DEBUG
                print("FlujoLimiteEnMoneda: Error buscando pagos: \(error)")
                #endif
                return []
            }
        }
    }

    // MARK: - El límite de una línea

    /// El límite que no sale de tus registros, si la línea lo tiene: sus pagos (con el extra) o su monto fijo en otra
    /// moneda. `nil` para las demás (promedios, monto fijo en la moneda del flujo…).
    static func resultado(
        line: CashFlowLine, mes: Date, monedaPlan: String, fuentes: Fuentes, calendar: Calendar
    ) -> Resultado? {
        let tasa: (String, Date) -> FlujoTasaDelMes.Tasa = { fuentes.tasa($0, mes: $1, calendar: calendar) }
        switch line.method {
        case .scheduled:
            let ids = line.scheduledPaymentIDs
            guard !ids.isEmpty || (line.limitExtraAmount ?? 0) > 0 else { return nil }
            return pagosDelMes(
                ids: ids, pagosPorID: fuentes.pagosPorID, extra: line.limitExtraAmount, mes: mes, monedaPlan: monedaPlan,
                tasa: tasa, calendar: calendar
            )
        case .manual:
            // El monto fijo se escribió en la moneda que hoy es la del plan (la persona cambió de moneda principal):
            // vale tal cual, no el convertido que guarda `manualAmount`.
            if line.limitCurrencyCode == monedaPlan, let monto = line.limitForeignAmount {
                return Resultado(monto: abs(monto), esAproximado: false, pagos: [], extra: nil, original: nil, tasa: nil,
                                 monedasExtranjeras: [], sinNada: false)
            }
            guard let fijo = line.foreignFixedLimit(planCurrency: monedaPlan) else { return nil }
            return FlujoLimiteEnMoneda.fijo(monto: fijo.amount, moneda: fijo.currencyCode, mes: mes, tasa: tasa,
                                            calendar: calendar)
        default:
            return nil
        }
    }
}
