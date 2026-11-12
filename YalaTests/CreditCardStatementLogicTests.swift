//
//  CreditCardStatementLogicTests.swift
//  YalaTests
//
//  El estado de cuenta de la tarjeta (card nmtk): ciclo, facturado / por facturar y avisos. Los casos que pide el spec:
//  corte a medianoche, pago ≤ corte (mes siguiente), pago parcial, sobrepago y cambio de hora. Calendario fijo (Lima y
//  Santiago, que cambia de hora a medianoche) y `now` inyectado: nada lee el reloj.
//

import Foundation
import Testing

@testable import Yala

@Suite("Tarjeta de crédito · estado de cuenta")
struct CreditCardStatementLogicTests {

    private static func calendar(_ zone: String = "America/Lima") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private let calendar = Self.calendar()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0, _ s: Int = 0,
                      calendar: Calendar? = nil) -> Date {
        (calendar ?? self.calendar).date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
    }

    private func entry(_ date: Date, _ amount: Double, adjustment: Bool = false) -> CreditCardStatementLogic.Entry {
        .init(date: date, amount: amount, isBalanceAdjustment: adjustment)
    }

    // MARK: - Ciclo

    @Test func corte15_pago5_elPagoCaeElMesSiguiente() throws {
        let cycle = try #require(CreditCardStatementLogic.cycle(statementDay: 15, paymentDay: 5,
                                                                now: date(2026, 10, 27, 10), calendar: calendar))
        #expect(cycle.statementDate == date(2026, 10, 15))
        #expect(cycle.statementClosesAt == date(2026, 10, 16))
        #expect(cycle.paymentDate == date(2026, 11, 5))
        #expect(cycle.nextStatementDate == date(2026, 11, 15))
    }

    @Test func antesDelCorteDelMes_elUltimoCorteEsElDelMesPasado() throws {
        let cycle = try #require(CreditCardStatementLogic.cycle(statementDay: 15, paymentDay: 5,
                                                                now: date(2026, 11, 3, 10), calendar: calendar))
        #expect(cycle.statementDate == date(2026, 10, 15))
        #expect(cycle.paymentDate == date(2026, 11, 5))
    }

    @Test func elDiaDelCorte_esElUltimoCorte() throws {
        let cycle = try #require(CreditCardStatementLogic.cycle(statementDay: 15, paymentDay: 5,
                                                                now: date(2026, 11, 15, 0, 0, 1), calendar: calendar))
        #expect(cycle.statementDate == date(2026, 11, 15))
    }

    @Test func pagoMayorQueCorte_caeElMismoMes_yPagoIgualAlCorte_alSiguiente() throws {
        let later = try #require(CreditCardStatementLogic.cycle(statementDay: 5, paymentDay: 25,
                                                                now: date(2026, 10, 10), calendar: calendar))
        #expect(later.paymentDate == date(2026, 10, 25))
        let same = try #require(CreditCardStatementLogic.cycle(statementDay: 10, paymentDay: 10,
                                                               now: date(2026, 10, 12), calendar: calendar))
        #expect(same.paymentDate == date(2026, 11, 10))
    }

    @Test func cruzaElAño() throws {
        let cycle = try #require(CreditCardStatementLogic.cycle(statementDay: 20, paymentDay: 10,
                                                                now: date(2027, 1, 5), calendar: calendar))
        #expect(cycle.statementDate == date(2026, 12, 20))
        #expect(cycle.paymentDate == date(2027, 1, 10))
    }

    @Test func diasFueraDeRango_noHayCiclo() {
        #expect(CreditCardStatementLogic.cycle(statementDay: 29, paymentDay: 5, now: date(2026, 10, 1), calendar: calendar) == nil)
        #expect(CreditCardStatementLogic.cycle(statementDay: 15, paymentDay: 0, now: date(2026, 10, 1), calendar: calendar) == nil)
        #expect(CreditCardStatementLogic.validDay(31) == nil)
        #expect(CreditCardStatementLogic.validLead(2) == 0)
        #expect(CreditCardStatementLogic.validLead(5) == 5)
    }

    // MARK: - Facturado y por facturar

    private var octCycle: CreditCardStatementLogic.Cycle {
        CreditCardStatementLogic.cycle(statementDay: 15, paymentDay: 5, now: date(2026, 10, 27, 10), calendar: calendar)!
    }

    @Test func sinPagos_facturadoEsLaDeudaAlCorte_yPorFacturarLoGastadoDespues() {
        let statement = CreditCardStatementLogic.statement(entries: [
            entry(date(2026, 10, 2), -1_000),
            entry(date(2026, 10, 15, 21), -240),
            entry(date(2026, 10, 20), -386.5),
        ], cycle: octCycle, now: date(2026, 10, 27, 10), calendar: calendar)
        #expect(statement.debtAtStatement == 1_240)
        #expect(statement.billed == 1_240)
        #expect(statement.unbilled == 386.5)
        #expect(statement.debtToday == 1_626.5)
        #expect(statement.billed + statement.unbilled == statement.debtToday)
    }

    /// El corte a medianoche: lo fechado el día del corte a las 00:00 entra en el corte; lo fechado el día siguiente a
    /// las 00:00, no (la trampa del intervalo cerrado).
    @Test func corteAMedianoche_cadaMovimientoCaeEnUnSoloLado() {
        let statement = CreditCardStatementLogic.statement(entries: [
            entry(date(2026, 10, 15), -100),
            entry(date(2026, 10, 16), -50),
        ], cycle: octCycle, now: date(2026, 10, 27, 10), calendar: calendar)
        #expect(statement.billed == 100)
        #expect(statement.unbilled == 50)
    }

    @Test func pagoParcial_bajaLoFacturado() {
        let statement = CreditCardStatementLogic.statement(entries: [
            entry(date(2026, 10, 10), -1_240),
            entry(date(2026, 10, 20), -300),
            entry(date(2026, 10, 22), 1_000),
        ], cycle: octCycle, now: date(2026, 10, 27, 10), calendar: calendar)
        #expect(statement.paidSinceStatement == 1_000)
        #expect(statement.billed == 240)
        #expect(statement.unbilled == 300)
    }

    /// Pagar de más deja lo facturado en 0 y no lo vuelve negativo; lo que sobra baja también lo por facturar.
    @Test func sobrepago_facturadoEnCero_yNuncaNegativo() {
        let statement = CreditCardStatementLogic.statement(entries: [
            entry(date(2026, 10, 10), -500),
            entry(date(2026, 10, 20), -300),
            entry(date(2026, 10, 22), 700),
        ], cycle: octCycle, now: date(2026, 10, 27, 10), calendar: calendar)
        #expect(statement.billed == 0)
        #expect(statement.unbilled == 100)
        #expect(statement.debtToday == 100)
    }

    /// Un ajuste de saldo después del corte no es un pago; con el saldo de hoy por debajo de lo facturado, lo facturado
    /// se queda en la deuda de hoy y los dos siguen sumando el «Por pagar».
    @Test func ajusteDeSaldo_noEsPago_yLoFacturadoNoPasaDeLaDeudaDeHoy() {
        let statement = CreditCardStatementLogic.statement(entries: [
            entry(date(2026, 10, 10), -800),
            entry(date(2026, 10, 20), 600, adjustment: true),
        ], cycle: octCycle, now: date(2026, 10, 27, 10), calendar: calendar)
        #expect(statement.paidSinceStatement == 0)
        #expect(statement.debtToday == 200)
        #expect(statement.billed == 200)
        #expect(statement.unbilled == 0)
    }

    @Test func loFechadoDespuesDeHoy_noCuenta() {
        let statement = CreditCardStatementLogic.statement(entries: [
            entry(date(2026, 10, 10), -100),
            entry(date(2026, 10, 28), -900),
        ], cycle: octCycle, now: date(2026, 10, 27, 23, 59), calendar: calendar)
        #expect(statement.debtToday == 100)
        #expect(statement.unbilled == 0)
    }

    @Test func saldoAFavor_nadaQuePagar() {
        let statement = CreditCardStatementLogic.statement(entries: [
            entry(date(2026, 10, 10), 50),
        ], cycle: octCycle, now: date(2026, 10, 27, 10), calendar: calendar)
        #expect(statement.billed == 0)
        #expect(statement.unbilled == 0)
    }

    /// Santiago cambia de hora a medianoche (primer sábado de septiembre, 2026-09-06 00:00 → 01:00): ese día no tiene
    /// 00:00. El corte del 6 cierra al empezar el 7, y el pago cae el 5 de octubre igual.
    @Test func cambioDeHora_elCorteYElPagoNoSeMueven() throws {
        let santiago = Self.calendar("America/Santiago")
        let cycle = try #require(CreditCardStatementLogic.cycle(
            statementDay: 6, paymentDay: 5, now: date(2026, 9, 20, 12, calendar: santiago), calendar: santiago))
        #expect(santiago.component(.day, from: cycle.statementDate) == 6)
        #expect(santiago.component(.day, from: cycle.statementClosesAt) == 7)
        #expect(santiago.component(.hour, from: cycle.statementClosesAt) == 0)
        #expect(santiago.component(.day, from: cycle.paymentDate) == 5)
        #expect(santiago.component(.month, from: cycle.paymentDate) == 10)
        let statement = CreditCardStatementLogic.statement(entries: [
            entry(santiago.startOfDay(for: date(2026, 9, 6, 12, calendar: santiago)), -100),
            entry(date(2026, 9, 7, 0, 30, calendar: santiago), -40),
        ], cycle: cycle, now: date(2026, 9, 20, 12, calendar: santiago), calendar: santiago)
        #expect(statement.billed == 100)
        #expect(statement.unbilled == 40)
    }

    // MARK: - La línea de «Facturado»

    @Test func estadoDeLoFacturado() {
        let cycle = octCycle
        #expect(CreditCardStatementLogic.billedStatus(billed: 10, cycle: cycle, now: date(2026, 11, 5, 23), calendar: calendar)
                == .payBy(date(2026, 11, 5)))
        #expect(CreditCardStatementLogic.billedStatus(billed: 10, cycle: cycle, now: date(2026, 11, 6), calendar: calendar)
                == .overdue(date(2026, 11, 5)))
        #expect(CreditCardStatementLogic.billedStatus(billed: 0, cycle: cycle, now: date(2026, 10, 27), calendar: calendar)
                == .settled)
    }

    // MARK: - Avisos

    private func reminders(statementDay: Int?, paymentDay: Int = 5, lead: Int, now: Date,
                           billed: Double = 1_240) -> [CreditCardStatementLogic.Reminder] {
        CreditCardStatementLogic.reminders(
            statementDay: statementDay, paymentDay: paymentDay, leadDays: lead, hour: 9, minute: 0,
            now: now, calendar: calendar
        ) { _ in [.init(amount: billed, currencyCode: "PEN")] }
    }

    @Test func tresDiasAntes_conElImporteDelCorteCerrado_ySinImporteElDelCorteQueNoHaCerrado() {
        let list = reminders(statementDay: 15, lead: 3, now: date(2026, 10, 27, 10))
        #expect(list.count == 2)
        #expect(list[0].day == date(2026, 11, 2))
        #expect(list[0].fireDate == date(2026, 11, 2, 9))
        #expect(list[0].paymentDate == date(2026, 11, 5))
        #expect(list[0].amounts == [.init(amount: 1_240, currencyCode: "PEN")])
        #expect(list[1].paymentDate == date(2026, 12, 5))
        #expect(list[1].amounts == nil, "el corte del 15 nov aún no ha cerrado")
    }

    @Test func yaPagado_noSeProgramaElAvisoDeEseCorte() {
        let list = reminders(statementDay: 15, lead: 3, now: date(2026, 10, 27, 10), billed: 0)
        #expect(list.map(\.paymentDate) == [date(2026, 12, 5)])
    }

    @Test func elAvisoDeHoyConLaHoraPasada_seDevuelve() {
        let list = reminders(statementDay: 15, lead: 3, now: date(2026, 11, 2, 11))
        #expect(list.first?.day == date(2026, 11, 2))
        #expect(list.first.map { $0.fireDate <= date(2026, 11, 2, 11) } == true)
    }

    @Test func pagoYaPasado_saltaAlSiguiente() {
        let list = reminders(statementDay: 15, lead: 1, now: date(2026, 11, 6, 10))
        #expect(list.map(\.paymentDate) == [date(2026, 12, 5)])
    }

    @Test func sinDiaDeCorte_elMismoDia_sinImporte_yLaAntelacionSeIgnora() {
        let list = reminders(statementDay: nil, lead: 5, now: date(2026, 10, 27, 10))
        #expect(list.map(\.day) == [date(2026, 11, 5)], "el 5 de octubre ya pasó; el de noviembre es el siguiente")
        #expect(list.allSatisfy { $0.amounts == nil && $0.leadDays == 0 })
        let early = reminders(statementDay: nil, lead: 0, now: date(2026, 10, 2, 10))
        #expect(early.map(\.day) == [date(2026, 10, 5), date(2026, 11, 5)])
    }

    /// Pago el mismo día que el corte: el día del corte, el pago del ciclo anterior sigue avisándose (con antelación 0),
    /// aunque el ciclo vigente ya sea el nuevo.
    @Test func pagoIgualAlCorte_elDiaDelCorteAvisaDelPagoAnterior() {
        let list = CreditCardStatementLogic.reminders(
            statementDay: 10, paymentDay: 10, leadDays: 0, hour: 9, minute: 0,
            now: date(2026, 11, 10, 7), calendar: calendar
        ) { _ in [.init(amount: 500, currencyCode: "PEN")] }
        #expect(list.first?.paymentDate == date(2026, 11, 10))
        #expect(list.first?.amounts == [.init(amount: 500, currencyCode: "PEN")])
    }

    /// Las divisas de 3 decimales no se recortan a 2.
    @Test func divisasDeTresDecimales_noSeRedondeanADos() {
        let statement = CreditCardStatementLogic.statement(entries: [
            entry(date(2026, 10, 10), -10.125),
        ], cycle: octCycle, now: date(2026, 10, 27, 10), calendar: calendar)
        #expect(statement.billed == 10.125)
    }

    @Test func claveDelDia() {
        #expect(CreditCardStatementLogic.dayKey(date(2026, 11, 2), calendar: calendar) == "20261102")
    }
}
