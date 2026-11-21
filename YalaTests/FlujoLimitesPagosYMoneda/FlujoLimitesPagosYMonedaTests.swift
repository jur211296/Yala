//
//  FlujoLimitesPagosYMonedaTests.swift
//  YalaTests
//
//  Límites del flujo de caja atados a varios pagos planificados y en otra moneda (encargo del 2026-11-20): el promedio
//  del tipo de cambio del mes (cerrado, en curso, futuro, días sin tasa), la suma de los pagos con monedas mezcladas y
//  extra, el pago anual, pausado, terminado y borrado, el motor del mes con dos pagos en una línea, mover un pago de
//  línea, borrarlo, y la diferencia por tipo de cambio que no es «Te pasaste».
//
//  El «ahora» es fijo (20 de noviembre de 2026, Lima) y las tasas las da un conversor de prueba que distingue el
//  promedio del mes de la última tasa: con la regla vieja (la última) los casos de mes cerrado darían otra cifra.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Flujo de caja · límites con pagos planificados y en otra moneda", .serialized)
@MainActor
struct FlujoLimitesPagosYMonedaTests {

    // MARK: - Fijos

    private static let lima = TimeZone(identifier: "America/Lima") ?? .current
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = FlujoLimitesPagosYMonedaTests.lima
        return c
    }()

    private func fecha(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h)) ?? .distantPast
    }

    private var hoy: Date { fecha(2026, 11, 20) }

    /// Tasas USD → PEN por día: octubre 3.70 la primera quincena y 3.90 la segunda (promedio ≠ última), noviembre 3.60
    /// hasta hoy, septiembre solo arrastradas (3.50); la última conocida, 4.00.
    private struct ConversorDeDias: CurrencyConverting {
        let calendar: Calendar
        let ultima: Decimal = 4.0

        func tasa(_ date: Date) -> RateFactor? {
            let c = calendar.dateComponents([.year, .month, .day], from: date)
            switch (c.month, c.day) {
            case (10, let d?): return RateFactor(factor: d <= 15 ? 3.7 : 3.9, quality: .exact)
            case (11, let d?) where d <= 20: return RateFactor(factor: 3.6, quality: .exact)
            case (9, _): return RateFactor(factor: 3.5, quality: .carriedForward(fromDateKey: "2026-08-31"))
            default: return nil
            }
        }

        func rateFactors(for codes: Set<String>, to: String, on dates: [Date]) -> [Date: [String: RateFactor]] {
            var out: [Date: [String: RateFactor]] = [:]
            for date in dates {
                var byCode: [String: RateFactor] = [:]
                for code in codes where code != to { if let t = tasa(date) { byCode[code] = t } }
                out[date] = byCode
            }
            return out
        }

        func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal { amount * ultima }
        func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal {
            from == to ? amount : amount * ultima
        }
        func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date)
            -> (amount: Decimal, quality: RateQuality) { (from == to ? amount : amount * ultima, .exact) }
        func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String)
            -> (amount: Decimal, quality: RateQuality) { (from == to ? amount : amount * ultima, .exact) }
    }

    private var conversor: ConversorDeDias { ConversorDeDias(calendar: calendar) }

    private func tabla(_ meses: [Date]) -> FlujoTasaDelMes.Tabla {
        FlujoTasaDelMes.tabla(codigos: ["USD"], meses: meses, a: "PEN", hoy: hoy, converter: conversor,
                              calendar: calendar)
    }

    private func pago(_ nombre: String, _ monto: Double, _ moneda: String = "PEN", dia: Int = 12,
                      activo: Bool = true, fin: Date? = nil, anualEn mes: Int? = nil) -> ScheduledPayment {
        let p = ScheduledPayment(
            name: nombre, amount: -monto, currencyCode: moneda,
            recurrenceType: mes == nil ? "monthly" : "yearly",
            nextDueDate: fecha(2026, mes ?? 11, dia), dayOfMonth: dia,
            yearlyMonth: mes, yearlyDay: mes == nil ? nil : dia, endDate: fin, isActive: activo
        )
        p.createdAt = fecha(2025, 1, 1)
        return p
    }

    private func porID(_ pagos: [ScheduledPayment]) -> [UUID: ScheduledPayment] {
        Dictionary(uniqueKeysWithValues: pagos.map { ($0.id, $0) })
    }

    // MARK: - La tasa del mes

    @Test func mesCerrado_esElPromedioDeSusDias_noLaUltima() {
        let octubre = fecha(2026, 10, 1, 0)
        let tasa = tabla([octubre]).tasa("USD", mes: octubre)
        let esperado = (3.7 * 15 + 3.9 * 16) / 31
        #expect(abs((tasa?.factor ?? 0) - esperado) < 0.0001)
        #expect(tasa?.estado == .cerrado)
        #expect(tasa?.esAproximada == false)
        // Control: la regla vieja (la última tasa) daría 4.00.
        #expect(abs((tasa?.factor ?? 0) - 4.0) > 0.05)
    }

    @Test func mesEnCurso_esElPromedioDeLosDiasQueVan() {
        let noviembre = fecha(2026, 11, 1, 0)
        let tasa = tabla([noviembre]).tasa("USD", mes: noviembre)
        #expect(abs((tasa?.factor ?? 0) - 3.6) < 0.0001)
        #expect(tasa?.estado == .enCurso(dias: 20))
        #expect(tasa?.esAproximada == false)
    }

    @Test func mesQueViene_usaLaUltimaTasa_conAproximado() {
        let diciembre = fecha(2026, 12, 1, 0)
        let tasa = tabla([diciembre]).tasa("USD", mes: diciembre)
        #expect(tasa?.factor == 4.0)
        #expect(tasa?.estado == .estimado)
        #expect(tasa?.esAproximada == true)
    }

    @Test func diasSinTasaPropia_promedianLasArrastradas_ySinNingunaLaUltima_ambasAproximadas() {
        let septiembre = fecha(2026, 9, 1, 0)
        let agosto = fecha(2026, 8, 1, 0)
        let t = tabla([septiembre, agosto])
        #expect(t.tasa("USD", mes: septiembre)?.factor == 3.5)
        #expect(t.tasa("USD", mes: septiembre)?.esAproximada == true)
        #expect(t.tasa("USD", mes: agosto)?.factor == 4.0)
        #expect(t.tasa("USD", mes: agosto)?.esAproximada == true)
    }

    @Test func laMismaMoneda_esUno() {
        #expect(tabla([hoy]).tasa("PEN", mes: hoy) == .identidad)
    }

    // MARK: - La suma de los pagos

    @Test func variosPagos_conMonedasMezcladas_yExtra_seConviertenPorSeparadoYSeSuman() {
        let noviembre = fecha(2026, 11, 1, 0)
        let t = tabla([noviembre])
        let netflix = pago("Netflix", 44.90)
        let chatgpt = pago("ChatGPT", 20, "USD")
        let r = FlujoLimiteEnMoneda.pagosDelMes(
            ids: [netflix.id, chatgpt.id], pagosPorID: porID([netflix, chatgpt]), extra: 30, mes: noviembre,
            monedaPlan: "PEN", tasa: { t.tasa($0, mes: $1) ?? .identidad }, calendar: calendar
        )
        #expect(abs(r.monto - (44.90 + 20 * 3.6 + 30)) < 0.001)
        #expect(r.original == nil, "con mezcla y extra no hay un original que enseñar")
        #expect(r.monedasExtranjeras == ["USD"])
        #expect(r.extra == 30)
        #expect(!r.sinNada)
    }

    @Test func pagosEnUnaSolaMonedaExtranjera_sinExtra_enseñanElOriginal() {
        let noviembre = fecha(2026, 11, 1, 0)
        let t = tabla([noviembre])
        let renta = pago("Renta", 500, "USD", dia: 1)
        let r = FlujoLimiteEnMoneda.pagosDelMes(
            ids: [renta.id], pagosPorID: porID([renta]), extra: nil, mes: noviembre, monedaPlan: "PEN",
            tasa: { t.tasa($0, mes: $1) ?? .identidad }, calendar: calendar
        )
        #expect(r.original == FlujoLimiteEnMoneda.Original(monto: 500, moneda: "USD"))
        #expect(abs(r.monto - 1800) < 0.001)
    }

    @Test func pagoAnual_sumaSoloEnSuMes() {
        let prime = pago("Amazon Prime", 14.99, dia: 5, anualEn: 3)
        let ids = [prime.id]
        func monto(_ mes: Date) -> Double {
            FlujoLimiteEnMoneda.pagosDelMes(ids: ids, pagosPorID: porID([prime]), extra: nil, mes: mes,
                                            monedaPlan: "PEN", tasa: { _, _ in .identidad }, calendar: calendar).monto
        }
        #expect(monto(fecha(2026, 11, 1, 0)) == 0)
        #expect(abs(monto(fecha(2027, 3, 1, 0)) - 14.99) < 0.001)
        let noviembre = FlujoLimiteEnMoneda.pagosDelMes(ids: ids, pagosPorID: porID([prime]), extra: nil,
                                                         mes: fecha(2026, 11, 1, 0), monedaPlan: "PEN",
                                                         tasa: { _, _ in .identidad }, calendar: calendar)
        #expect(noviembre.pagos.first?.estado == .noCae)
    }

    @Test func pagoPausado_noSuma_yTerminado_noSumaDespuesDeSuFin() {
        let pausado = pago("iCloud", 9.9, activo: false)
        let terminado = pago("Gimnasio", 120, fin: fecha(2026, 9, 30))
        let ids = [pausado.id, terminado.id]
        let tabla = porID([pausado, terminado])
        func r(_ mes: Date) -> FlujoLimiteEnMoneda.Resultado {
            FlujoLimiteEnMoneda.pagosDelMes(ids: ids, pagosPorID: tabla, extra: nil, mes: mes, monedaPlan: "PEN",
                                            tasa: { _, _ in .identidad }, calendar: calendar)
        }
        let noviembre = r(fecha(2026, 11, 1, 0))
        #expect(noviembre.monto == 0)
        #expect(noviembre.pagos.map(\.estado).first == .pausado)
        if case .terminado = noviembre.pagos.last?.estado {} else { Issue.record("el terminado no dice que terminó") }
        // Antes de su fin, el terminado sí suma.
        #expect(abs(r(fecha(2026, 9, 1, 0)).monto - 120) < 0.001)
    }

    @Test func pagosQueYaNoEstan_sinExtra_dejanLaLineaSinNada() {
        let r = FlujoLimiteEnMoneda.pagosDelMes(ids: [UUID()], pagosPorID: [:], extra: nil, mes: hoy,
                                                monedaPlan: "PEN", tasa: { _, _ in .identidad }, calendar: calendar)
        #expect(r.sinNada)
        let conExtra = FlujoLimiteEnMoneda.pagosDelMes(ids: [UUID()], pagosPorID: [:], extra: 30, mes: hoy,
                                                       monedaPlan: "PEN", tasa: { _, _ in .identidad },
                                                       calendar: calendar)
        #expect(!conExtra.sinNada)
        #expect(conExtra.monto == 30)
    }

    @Test func montoFijoEnOtraMoneda_seConvierteConElPromedioDeCadaMes() {
        let octubre = fecha(2026, 10, 1, 0)
        let noviembre = fecha(2026, 11, 1, 0)
        let t = tabla([octubre, noviembre])
        let tasa: (String, Date) -> FlujoTasaDelMes.Tasa = { t.tasa($0, mes: $1) ?? .identidad }
        let oct = FlujoLimiteEnMoneda.fijo(monto: 500, moneda: "USD", mes: octubre, tasa: tasa, calendar: calendar)
        let nov = FlujoLimiteEnMoneda.fijo(monto: 500, moneda: "USD", mes: noviembre, tasa: tasa, calendar: calendar)
        #expect(abs(nov.monto - 1800) < 0.001)
        #expect(abs(oct.monto - 500 * (3.7 * 15 + 3.9 * 16) / 31) < 0.001)
        #expect(oct.monto != nov.monto, "el mismo límite en USD vale distinto cada mes")
    }

    @Test func idsGuardados_seLeenEnOrdenYSinRepetidos() {
        let a = UUID(), b = UUID()
        let raw = FlujoLimiteEnMoneda.serializeIDs([a, b, a])
        #expect(FlujoLimiteEnMoneda.parseIDs(raw) == [a, b])
        #expect(FlujoLimiteEnMoneda.serializeIDs([]) == nil)
        #expect(FlujoLimiteEnMoneda.parseIDs("basura,\(a.uuidString)") == [a])
    }

    // MARK: - El cálculo del plan

    @Test func resolvePlanned_sumaLosPagosConSuTasa_yCambiarUnPagoCambiaElLimiteSinTocarLaLinea() throws {
        let context = try makeTestContext()
        let netflix = pago("Netflix", 44.90)
        let renta = pago("Renta", 500, "USD", dia: 1)
        context.insert(netflix)
        context.insert(renta)
        let line = CashFlowLine(name: "Fijos", estimationMethod: .scheduled, scheduledPayment: netflix)
        context.insert(line)
        line.scheduledPaymentIDsRaw = FlujoLimiteEnMoneda.serializeIDs([netflix.id, renta.id])
        try context.save()

        let noviembre = fecha(2026, 11, 1, 0)
        let fuentes = FlujoLimiteEnMoneda.Fuentes.construir(
            lines: [line], scheduledPayments: [netflix, renta], meses: [noviembre], monedaPlan: "PEN",
            converter: conversor, hoy: hoy, calendar: calendar
        )
        func limite() -> Double {
            CashFlowProjectionCalculator.resolvePlanned(
                line: line, monthKey: "2026-11", monthDate: noviembre, currentMonthStart: noviembre,
                index: TransactionIndex(movimientos: [], calendar: calendar), currencyCode: "PEN", converter: conversor,
                fuentes: fuentes, calendar: calendar
            ).amount
        }
        #expect(abs(limite() - (44.90 + 1800)) < 0.001)
        netflix.amount = -54.90
        #expect(abs(limite() - (54.90 + 1800)) < 0.001, "el límite sigue al importe del pago")
    }

    @Test func lineaDeAntes_conSoloLaRelacion_leeSuPago() throws {
        let context = try makeTestContext()
        let renta = pago("Renta", 1850)
        context.insert(renta)
        let line = CashFlowLine(name: "Renta", estimationMethod: .scheduled, scheduledPayment: renta)
        context.insert(line)
        try context.save()
        #expect(line.scheduledPaymentIDsRaw == nil)
        #expect(line.scheduledPaymentIDs == [renta.id])
        #expect(CashFlowProjectionCalculator.needsLimitSources(line, currencyCode: "PEN"))
    }

    @Test func sinPagosNiExtra_elLimiteEsElUltimoGuardado() throws {
        let context = try makeTestContext()
        let line = CashFlowLine(name: "Renta", estimationMethod: .scheduled, manualAmount: 1850)
        context.insert(line)
        line.scheduledPaymentIDsRaw = UUID().uuidString   // un pago que ya no está
        try context.save()
        let noviembre = fecha(2026, 11, 1, 0)
        let limite = CashFlowProjectionCalculator.resolvePlanned(
            line: line, monthKey: "2026-11", monthDate: noviembre, currentMonthStart: noviembre,
            index: TransactionIndex(movimientos: [], calendar: calendar), currencyCode: "PEN", converter: conversor,
            fuentes: FlujoLimiteEnMoneda.Fuentes.construir(
                lines: [line], scheduledPayments: [], meses: [noviembre], monedaPlan: "PEN", converter: conversor,
                hoy: hoy, calendar: calendar
            ),
            calendar: calendar
        ).amount
        #expect(limite == 1850)
    }

    // MARK: - El motor del mes

    @Test func motor_unaLineaConDosPagos_recibeLosMovimientosDeLosDos_ninguneEnOtros() {
        let a = UUID(), b = UUID(), c = UUID()
        let linea = FlujoMotorMes.Linea(id: UUID(), esIngreso: false, categoriaID: nil, subcategoriaID: nil,
                                        pagoIDs: [a, b])
        let dueños = FlujoMotorMes.Dueños(lineas: [linea])
        #expect(dueños.dueño(esIngreso: false, categoriaID: nil, subcategoriaID: nil, pagoID: a) == .linea(linea.id))
        #expect(dueños.dueño(esIngreso: false, categoriaID: nil, subcategoriaID: nil, pagoID: b) == .linea(linea.id))
        #expect(dueños.dueño(esIngreso: false, categoriaID: nil, subcategoriaID: nil, pagoID: c) == .otros)
        #expect(dueños.pagoDe(linea.id) == [a, b])
        #expect(!dueños.esRepetida(linea.id))
    }

    @Test func motor_unPagoEnDosLineas_seLoQuedaLaPrimera_yLaQueNoSeQuedaNadaEsRepetida() {
        let a = UUID(), b = UUID()
        let primera = FlujoMotorMes.Linea(id: UUID(), esIngreso: false, categoriaID: nil, subcategoriaID: nil,
                                          pagoIDs: [a, b])
        let segunda = FlujoMotorMes.Linea(id: UUID(), esIngreso: false, categoriaID: nil, subcategoriaID: nil,
                                          pagoIDs: [a])
        let dueños = FlujoMotorMes.Dueños(lineas: [primera, segunda])
        #expect(dueños.dueño(esIngreso: false, categoriaID: nil, subcategoriaID: nil, pagoID: a) == .linea(primera.id))
        #expect(dueños.esRepetida(segunda.id))
    }

    // MARK: - Mover y borrar

    private func aislarAvisos() -> () -> Void {
        let previo = FlujoAvisoPagoQuitado.defaults
        let isolated = makeIsolatedDefaults()
        FlujoAvisoPagoQuitado.defaults = isolated
        return { FlujoAvisoPagoQuitado.defaults = previo }
    }

    @Test func moverUnPago_loQuitaDeLaOtraLinea_yLaQueQuedaVaciaPasaAMontoFijoConSuLimite() throws {
        let restaurar = aislarAvisos()
        defer { restaurar() }
        let context = try makeTestContext()
        let plan = CashFlowPlan(name: "Plan")
        context.insert(plan)
        let youtube = pago("YouTube", 23.90)
        let netflix = pago("Netflix", 44.90)
        context.insert(youtube)
        context.insert(netflix)
        let servicios = CashFlowLine(name: "Servicios", estimationMethod: .scheduled, scheduledPayment: youtube)
        let suscripciones = CashFlowLine(name: "Suscripciones", estimationMethod: .scheduled, scheduledPayment: netflix)
        context.insert(servicios)
        context.insert(suscripciones)
        servicios.plan = plan
        suscripciones.plan = plan
        try context.save()

        let movidas = try FlujoPagosDeLineaLogica.guardarPagos(
            line: suscripciones, ids: [netflix.id, youtube.id], extra: nil, monthKey: "2026-11",
            mes: fecha(2026, 11, 1, 0), monedaPlan: "PEN", converter: conversor, hoy: hoy, calendar: calendar
        )
        #expect(movidas.map(\.id) == [servicios.id])
        #expect(suscripciones.scheduledPaymentIDs == [netflix.id, youtube.id])
        #expect(suscripciones.scheduledPayment?.id == netflix.id, "la relación guarda el primero")
        #expect(abs((suscripciones.manualAmount ?? 0) - (44.90 + 23.90)) < 0.001, "una versión vieja ve el convertido")
        #expect(servicios.method == .manual, "sin pagos ni extra pasa a monto fijo")
        #expect(abs((servicios.manualAmount ?? 0) - 23.90) < 0.001, "con el límite que tenía")
        #expect(servicios.scheduledPaymentIDs.isEmpty)
        let aviso = FlujoAvisoPagoQuitado.consumir(lineID: servicios.id)
        #expect(aviso?.destino == "Suscripciones")
        #expect(FlujoAvisoPagoQuitado.consumir(lineID: servicios.id) == nil, "el aviso sale una vez")
    }

    @Test func borrarUnPago_laLineaSinNadaQuedaFijaConElLimiteDelMes_yConOtroPagoSigue() throws {
        let restaurar = aislarAvisos()
        defer { restaurar() }
        let context = try makeTestContext()
        let renta = pago("Renta", 1850, dia: 1)
        let spotify = pago("Spotify", 21.90)
        let netflix = pago("Netflix", 44.90)
        [renta, spotify, netflix].forEach { context.insert($0) }
        let lineaRenta = CashFlowLine(name: "Renta", estimationMethod: .scheduled, scheduledPayment: renta)
        let lineaSubs = CashFlowLine(name: "Suscripciones", estimationMethod: .scheduled, scheduledPayment: spotify)
        context.insert(lineaRenta)
        context.insert(lineaSubs)
        lineaSubs.scheduledPaymentIDsRaw = FlujoLimiteEnMoneda.serializeIDs([spotify.id, netflix.id])
        try context.save()

        try FlujoPagosDeLineaLogica.alBorrarPago(renta, context: context, monedaPlan: "PEN", converter: conversor,
                                                 hoy: hoy, calendar: calendar)
        try FlujoPagosDeLineaLogica.alBorrarPago(spotify, context: context, monedaPlan: "PEN", converter: conversor,
                                                 hoy: hoy, calendar: calendar)

        #expect(lineaRenta.method == .manual)
        #expect(lineaRenta.manualAmount == 1850)
        #expect(FlujoAvisoPagoQuitado.consumir(lineID: lineaRenta.id)?.fijoEn == 1850)
        #expect(lineaSubs.method == .scheduled, "le queda Netflix: sigue con sus pagos")
        #expect(lineaSubs.scheduledPaymentIDs == [netflix.id])
        #expect(lineaSubs.scheduledPayment?.id == netflix.id)
        let avisoSubs = FlujoAvisoPagoQuitado.consumir(lineID: lineaSubs.id)
        #expect(avisoSubs?.nombre == "Spotify")
        #expect(avisoSubs?.fijoEn == nil)
    }

    @Test func montoFijoEnOtraMoneda_vaATodosLosMeses_yRetiraLosAjustes() throws {
        let context = try makeTestContext()
        let line = CashFlowLine(name: "Renta", estimationMethod: .manual, manualAmount: 1800)
        context.insert(line)
        line.amountChangesRaw = "2026-12=1900.0"
        try context.save()
        try FlujoPagosDeLineaLogica.guardarFijoEnMoneda(
            line: line, monto: 500, moneda: "USD", mes: fecha(2026, 11, 1, 0), monedaPlan: "PEN", converter: conversor,
            hoy: hoy, calendar: calendar
        )
        #expect(line.amountChangesRaw == nil)
        #expect(line.limitCurrencyCode == "USD")
        #expect(line.limitForeignAmount == 500)
        #expect(abs((line.manualAmount ?? 0) - 1800) < 0.001, "el convertido del mes, para una versión vieja")
        #expect(line.foreignFixedLimit(planCurrency: "PEN")?.amount == 500)
        #expect(line.foreignFixedLimit(planCurrency: "USD") == nil, "en la moneda del flujo no es «otra moneda»")
    }

    @Test func siLosPagosNoSeDejanLeer_borrarYGuardarLanzanSinTocarLaLinea() throws {
        let restaurar = aislarAvisos()
        defer { restaurar(); FlujoPagosDeLineaLogica._testThrowOnFetch = false }
        let context = try makeTestContext()
        let renta = pago("Renta", 1850, dia: 1)
        let spotify = pago("Spotify", 21.90)
        context.insert(renta)
        context.insert(spotify)
        let linea = CashFlowLine(name: "Fijos", estimationMethod: .scheduled, manualAmount: 1871.90, scheduledPayment: renta)
        context.insert(linea)
        linea.scheduledPaymentIDsRaw = FlujoLimiteEnMoneda.serializeIDs([renta.id, spotify.id])
        try context.save()

        FlujoPagosDeLineaLogica._testThrowOnFetch = true
        #expect(throws: (any Error).self) {
            try FlujoPagosDeLineaLogica.alBorrarPago(renta, context: context, monedaPlan: "PEN", converter: conversor,
                                                     hoy: hoy, calendar: calendar)
        }
        #expect(throws: (any Error).self) {
            try FlujoPagosDeLineaLogica.guardarPagos(line: linea, ids: [spotify.id], extra: nil, monthKey: "2026-11",
                                                     mes: fecha(2026, 11, 1, 0), monedaPlan: "PEN",
                                                     converter: conversor, hoy: hoy, calendar: calendar)
        }
        #expect(linea.scheduledPayment?.id == renta.id, "con la lectura fallida no se toca la relación")
        #expect(linea.scheduledPaymentIDs == [renta.id, spotify.id])
        #expect(linea.manualAmount == 1871.90)
        #expect(FlujoAvisoPagoQuitado.consumir(lineID: linea.id) == nil)
    }

    @Test func laMarcaAproximadaSigueElUmbral_noBastaUnPagoPequeñoEnOtraMoneda() {
        let diciembre = fecha(2026, 12, 1, 0)   // mes que viene: toda tasa extranjera es aproximada
        let t = tabla([diciembre])
        let tasa: (String, Date) -> FlujoTasaDelMes.Tasa = { t.tasa($0, mes: $1) ?? .identidad }
        let renta = pago("Renta", 1850, dia: 1)
        let icloud = pago("iCloud+", 2.99, "USD")
        let chica = FlujoLimiteEnMoneda.pagosDelMes(
            ids: [renta.id, icloud.id], pagosPorID: porID([renta, icloud]), extra: nil, mes: diciembre,
            monedaPlan: "PEN", tasa: tasa, calendar: calendar
        )
        #expect(!chica.esAproximado, "12 soles aproximados no marcan un límite de 1,862")
        let dolares = pago("Renta USD", 500, "USD", dia: 1)
        let grande = FlujoLimiteEnMoneda.pagosDelMes(
            ids: [dolares.id, icloud.id], pagosPorID: porID([dolares, icloud]), extra: nil, mes: diciembre,
            monedaPlan: "PEN", tasa: tasa, calendar: calendar
        )
        #expect(grande.esAproximado)
    }

    @Test func montoFijoEnLaMonedaQuePasoASerLaDelPlan_valeTalCual() throws {
        let context = try makeTestContext()
        let line = CashFlowLine(name: "Renta", estimationMethod: .manual, manualAmount: 1850)
        context.insert(line)
        line.limitCurrencyCode = "USD"
        line.limitForeignAmount = 500
        try context.save()
        let noviembre = fecha(2026, 11, 1, 0)
        let fuentes = FlujoLimiteEnMoneda.Fuentes.construir(
            lines: [line], scheduledPayments: [], meses: [noviembre], monedaPlan: "USD", converter: conversor,
            hoy: hoy, calendar: calendar
        )
        let limite = CashFlowProjectionCalculator.resolvePlanned(
            line: line, monthKey: "2026-11", monthDate: noviembre, currentMonthStart: noviembre,
            index: TransactionIndex(movimientos: [], calendar: calendar), currencyCode: "USD", converter: conversor,
            fuentes: fuentes, calendar: calendar
        ).amount
        #expect(limite == 500, "no los 1,850 que guardó como soles")
    }

    // MARK: - La diferencia por tipo de cambio

    @Test func pagarJustoElOriginal_noEsPasarse_esElTipoDeCambio() {
        let original = FlujoLimiteEnMoneda.Original(monto: 500, moneda: "USD")
        let justo = FlujoDetalleLineaLogica.excesoPorTipoDeCambio(real: 1862, limite: 1850, original: original,
                                                                  pagadoEnOriginal: 500)
        #expect(justo?.justo == true)
        #expect(abs((justo?.exceso ?? 0) - 12) < 0.001)
        #expect(FlujoDetalleLineaLogica.excesoPorTipoDeCambio(real: 1862, limite: 1850, original: original,
                                                              pagadoEnOriginal: 480)?.justo == false)
        // Pasarse también en el original sí es pasarse.
        #expect(FlujoDetalleLineaLogica.excesoPorTipoDeCambio(real: 1900, limite: 1850, original: original,
                                                              pagadoEnOriginal: 510) == nil)
        // Sin original (límite en la moneda del flujo) no hay nada que explicar.
        #expect(FlujoDetalleLineaLogica.excesoPorTipoDeCambio(real: 1862, limite: 1850, original: nil,
                                                              pagadoEnOriginal: 500) == nil)
        // Con registros en otra moneda no se puede comparar.
        #expect(FlujoDetalleLineaLogica.excesoPorTipoDeCambio(real: 1862, limite: 1850, original: original,
                                                              pagadoEnOriginal: nil) == nil)
    }

    // MARK: - La hoja de elegir

    @Test func laHojaOfreceSoloLosPagosPersonalesDelLado_activosPrimero_yBuscadorDesdeOcho() {
        let gasto = pago("Netflix", 44.90)
        let pausado = pago("Al pausado", 10, activo: false)
        let ingreso = ScheduledPayment(name: "Sueldo", amount: 5000, currencyCode: "PEN", transactionType: "income",
                                       nextDueDate: hoy)
        #expect(FlujoPagosDeLineaLogica.ofrecible(gasto, esIngreso: false))
        #expect(!FlujoPagosDeLineaLogica.ofrecible(ingreso, esIngreso: false))
        gasto.groupZoneID = "zona"
        #expect(!FlujoPagosDeLineaLogica.ofrecible(gasto, esIngreso: false), "los de grupo siguen el camino de hoy")
        gasto.groupZoneID = nil
        #expect(FlujoPagosDeLineaLogica.ordenados([pausado, gasto]).map(\.name) == ["Netflix", "Al pausado"])
        #expect(!FlujoPagosDeLineaLogica.muestraBuscador(7))
        #expect(FlujoPagosDeLineaLogica.muestraBuscador(8))
        #expect(FlujoPagosDeLineaLogica.ofreceMetodo(lineaUsaPagos: false, pagos: [pausado], esIngreso: false) == false)
        #expect(FlujoPagosDeLineaLogica.ofreceMetodo(lineaUsaPagos: false, pagos: [gasto], esIngreso: false))
    }
}
