//
//  RecurringPaymentDetectorTests.swift
//  YalaTests
//
//  La regla de «Pagos que se repiten» (lote S1) con historiales sintéticos: los cinco ejemplos de la definición del
//  12-nov (Netflix fijo, Luz del Sur variable, Smart Fit corto, Uber irregular, Spotify ya planificado) y los bordes
//  que pide el plan de lotes (dólares, cambio de hora) más los de la propia regla.
//

import Foundation
import Testing
@testable import Yala

@Suite("Pagos que se repiten · detector")
struct RecurringPaymentDetectorTests {

    // «Ahora» fijo a mitad de mes, en Lima (sin cambio de hora).
    private static let lima: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return calendar
    }()

    private static func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12, minute: Int = 0, calendar: Calendar = lima) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour, minute: minute)) ?? .distantPast
    }

    private static let now = date(2026, 11, 20)

    private static func charges(
        _ name: String, _ dates: [Date], amounts: [Double], currency: String = "PEN", startRef: Int = 0
    ) -> [RecurringPaymentDetector.Charge] {
        zip(dates, amounts).enumerated().map { index, pair in
            .init(ref: startRef + index, date: pair.0, amount: pair.1, currencyCode: currency, name: name)
        }
    }

    private static func detect(
        _ charges: [RecurringPaymentDetector.Charge],
        planned: [RecurringPaymentDetector.PlannedPayment] = [],
        now: Date = now,
        calendar: Calendar = lima
    ) -> [RecurringPaymentDetector.Proposal] {
        RecurringPaymentDetector.detect(charges: charges, plannedPayments: planned, now: now, calendar: calendar)
    }

    // MARK: - Los ejemplos de la definición

    @Test func netflixFijoCadaMes_seProponeConSuMarca() throws {
        let dates = (7...11).map { Self.date(2026, $0, 14) }
        let result = Self.detect(Self.charges("NETFLIX.COM", dates, amounts: Array(repeating: 44.90, count: 5)))

        let proposal = try #require(result.first)
        #expect(result.count == 1)
        #expect(proposal.brandID == "netflix")
        #expect(proposal.displayName == "Netflix")
        #expect(proposal.cadence == .monthly(day: 14, isApproximate: false))
        #expect(proposal.chargeCount == 5)
        #expect(proposal.amount == 44.90)
        #expect(proposal.isVariableAmount == false)
        #expect(proposal.currencyCode == "PEN")
        #expect(proposal.nextDueDate == Self.lima.startOfDay(for: Self.date(2026, 12, 14)))
        #expect(proposal.lastChargeRef == 4)
    }

    @Test func luzDelSurVariable_seProponeConElUltimoMontoYDiaAproximado() throws {
        let dates = [Self.date(2026, 9, 3), Self.date(2026, 10, 2), Self.date(2026, 11, 4)]
        let result = Self.detect(Self.charges("Luz del Sur", dates, amounts: [112, 125, 131]))

        let proposal = try #require(result.first)
        #expect(proposal.brandID == nil)
        #expect(proposal.displayName == "Luz del Sur")
        #expect(proposal.isVariableAmount)
        #expect(proposal.amount == 131)
        #expect(proposal.cadence == .monthly(day: 3, isApproximate: true))
        #expect(proposal.nextDueDate == Self.lima.startOfDay(for: Self.date(2026, 12, 3)))
    }

    @Test func smartFitConDosCobros_aunNoSePropone() {
        let dates = [Self.date(2026, 10, 1), Self.date(2026, 11, 1)]
        #expect(Self.detect(Self.charges("Smart Fit", dates, amounts: [99.90, 99.90])).isEmpty)
    }

    @Test func uberIrregular_noSePropone() {
        let days = [2, 3, 5, 9, 10, 14, 15, 16, 19]
        var dates: [Date] = []
        for month in 8...11 { dates += days.map { Self.date(2026, month, $0) } }
        dates = dates.filter { $0 <= Self.now }
        let amounts = dates.indices.map { Double(9 + ($0 * 7) % 30) }
        #expect(Self.detect(Self.charges("Uber *Trip 4821", dates, amounts: amounts)).isEmpty)
    }

    @Test func spotifyYaPlanificado_noSePropone() {
        let dates = (7...11).map { Self.date(2026, $0, 5) }
        let charges = Self.charges("Spotify", dates, amounts: Array(repeating: 18.90, count: 5))
        #expect(Self.detect(charges, planned: [.init(name: "Spotify Premium", storedBrandID: nil)]).isEmpty)
        // Por marca guardada aunque el nombre no case.
        #expect(Self.detect(charges, planned: [.init(name: "Música", storedBrandID: "spotify")]).isEmpty)
        // Por nombre sin marca: «Luz del Sur» planificado tapa «LUZ DEL SUR 0042».
        let luz = Self.charges("LUZ DEL SUR 0042", (8...11).map { Self.date(2026, $0, 3) }, amounts: [120, 120, 120, 120])
        #expect(Self.detect(luz, planned: [.init(name: "Luz del sur", storedBrandID: nil)]).isEmpty)
        // Un pago planificado de otra cosa no la tapa.
        #expect(Self.detect(charges, planned: [.init(name: "Netflix", storedBrandID: nil)]).count == 1)
    }

    // MARK: - Divisas, cambio de hora y fin de mes

    @Test func cadaDivisaVaPorSeparado() throws {
        let usd = Self.charges("iCloud+", (9...11).map { Self.date(2026, $0, 22 - 10) }, amounts: [2.99, 2.99, 2.99],
                               currency: "USD")
        let pen = Self.charges("iCloud+", [Self.date(2026, 10, 25), Self.date(2026, 11, 15)], amounts: [10, 10],
                               startRef: 10)
        let result = Self.detect(usd + pen)
        let proposal = try #require(result.first)
        #expect(result.count == 1)
        #expect(proposal.currencyCode == "USD")
        #expect(proposal.key.hasSuffix("|USD"))
        #expect(proposal.chargeRefs == [0, 1, 2])
    }

    @Test func semanalCruzandoElCambioDeHora_seCuentaPorDiasDeCalendario() throws {
        var madrid = Calendar(identifier: .gregorian)
        madrid.timeZone = TimeZone(identifier: "Europe/Madrid") ?? .current
        // Domingos a las 00:30; el 29 de marzo de 2026 el reloj salta de 02:00 a 03:00. Entre el 22 y el 29 hay
        // 6 días y 23 horas: contado en segundos no llega a una semana.
        let dates = [15, 22, 29].map { Self.date(2026, 3, $0, hour: 0, minute: 30, calendar: madrid) }
            + [Self.date(2026, 4, 5, hour: 0, minute: 30, calendar: madrid)]
        let now = Self.date(2026, 4, 8, calendar: madrid)
        let result = Self.detect(Self.charges("Clases de natación", dates, amounts: [40, 40, 40, 40]),
                                 now: now, calendar: madrid)

        let proposal = try #require(result.first)
        #expect(proposal.cadence == .weekly(weekday: 1))
        #expect(proposal.nextDueDate == madrid.startOfDay(for: Self.date(2026, 4, 12, calendar: madrid)))
    }

    @Test func mensualCruzandoElCambioDeHora() {
        var madrid = Calendar(identifier: .gregorian)
        madrid.timeZone = TimeZone(identifier: "Europe/Madrid") ?? .current
        let dates = [Self.date(2026, 2, 28, hour: 23, minute: 50, calendar: madrid),
                     Self.date(2026, 3, 28, hour: 23, minute: 50, calendar: madrid),
                     Self.date(2026, 4, 28, hour: 0, minute: 10, calendar: madrid)]
        let now = Self.date(2026, 5, 2, calendar: madrid)
        #expect(Self.detect(Self.charges("Gimnasio", dates, amounts: [120, 120, 120]), now: now, calendar: madrid).count == 1)
    }

    @Test func finDeMes_del31AlUltimoDiaDeFebrero() throws {
        let dates = [Self.date(2026, 1, 31), Self.date(2026, 2, 28), Self.date(2026, 3, 31)]
        let now = Self.date(2026, 4, 10)
        let proposal = try #require(Self.detect(Self.charges("Alquiler cochera", dates, amounts: [300, 300, 300]),
                                                now: now).first)
        #expect(proposal.cadence == .monthly(day: 31, isApproximate: true))
        // Abril tiene 30 días: el pago cae el último.
        #expect(proposal.nextDueDate == Self.lima.startOfDay(for: Self.date(2026, 4, 30)))
    }

    // MARK: - La regla

    @Test func ultimoCobroDeHaceMasDe45Dias_noSePropone() {
        let dates = (6...9).map { Self.date(2026, $0, 1) } // último: 1 sep, 80 días antes del 20 nov
        #expect(Self.detect(Self.charges("Seguro", dates, amounts: [80, 80, 80, 80])).isEmpty)
        // 44 días: sí.
        let recent = [Self.date(2026, 8, 7), Self.date(2026, 9, 7), Self.date(2026, 10, 7)]
        #expect(Self.detect(Self.charges("Seguro", recent, amounts: [80, 80, 80])).count == 1)
    }

    @Test func marcaDeSuscripcion_exigeMontoExacto() {
        // Netflix subió el último mes: la serie desde el último cobro se queda en uno.
        let dates = (8...11).map { Self.date(2026, $0, 14) }
        #expect(Self.detect(Self.charges("Netflix", dates, amounts: [44.90, 44.90, 44.90, 49.90])).isEmpty)
        // Sin marca, un 10 % entra.
        #expect(Self.detect(Self.charges("Colegio", dates, amounts: [500, 500, 500, 545])).count == 1)
        // Un 20 %, no.
        #expect(Self.detect(Self.charges("Colegio", dates, amounts: [500, 500, 500, 625])).isEmpty)
    }

    @Test func serieDesdeElUltimoCobro_ignoraLoViejoQueNoEncaja() throws {
        // Un cobro suelto en junio y la serie de agosto a noviembre.
        let dates = [Self.date(2026, 6, 2)] + (8...11).map { Self.date(2026, $0, 10) }
        let proposal = try #require(Self.detect(Self.charges("Internet Movistar", dates, amounts: [70, 90, 90, 90, 90])).first)
        #expect(proposal.chargeCount == 4)
        #expect(proposal.chargeRefs == [1, 2, 3, 4])
    }

    @Test func semanal_necesitaCuatroCobros() {
        let three = [Self.date(2026, 10, 30), Self.date(2026, 11, 6), Self.date(2026, 11, 13)]
        #expect(Self.detect(Self.charges("Clases de piano", three, amounts: [60, 60, 60])).isEmpty)
        let four = [Self.date(2026, 10, 23)] + three
        #expect(Self.detect(Self.charges("Clases de piano", four, amounts: [60, 60, 60, 60])).count == 1)
    }

    @Test func nombresConNumerosDistintos_sonElMismoComercio() {
        let dates = (9...11).map { Self.date(2026, $0, 8) }
        let charges = [
            RecurringPaymentDetector.Charge(ref: 0, date: dates[0], amount: 35, currencyCode: "PEN", name: "CLARO 1234"),
            RecurringPaymentDetector.Charge(ref: 1, date: dates[1], amount: 35, currencyCode: "PEN", name: "Claro 5678"),
            RecurringPaymentDetector.Charge(ref: 2, date: dates[2], amount: 35, currencyCode: "pen", name: "claro"),
        ]
        #expect(Self.detect(charges).count == 1)
    }

    @Test func proximoCobro_hoyCuentaSiElCobroEsHoy() {
        let next = RecurringPaymentDetector.nextDueDate(
            after: Self.date(2026, 10, 20), cadence: .monthly(day: 20, isApproximate: false),
            now: Self.now, calendar: Self.lima
        )
        #expect(next == Self.lima.startOfDay(for: Self.now))
    }

    // MARK: - Hallazgos de la revisión

    @Test func marcaPorPrefijo_soloConPalabrasDeRelleno() {
        // «Prime Gym» casa en el catálogo con el alias «prime», pero no es Prime Video.
        #expect(RecurringPaymentDetector.brand(forChargeName: "PRIME GYM") == nil)
        #expect(RecurringPaymentDetector.brand(forChargeName: "Disney Store") == nil)
        #expect(RecurringPaymentDetector.brand(forChargeName: "NETFLIX.COM")?.id == "netflix")
        #expect(RecurringPaymentDetector.brand(forChargeName: "Spotify Premium Familiar")?.id == "spotify")
        #expect(RecurringPaymentDetector.brand(forChargeName: "netflix")?.id == "netflix")
    }

    @Test func comercioQueEmpiezaComoUnaMarca_seProponePorSuNombre() throws {
        let dates = (9...11).map { Self.date(2026, $0, 6) }
        let proposal = try #require(Self.detect(Self.charges("PRIME GYM", dates, amounts: [99, 99, 105])).first)
        #expect(proposal.brandID == nil)
        #expect(proposal.displayName == "PRIME GYM")
        #expect(proposal.key == "name:prime gym|PEN")
    }

    @Test func proximoCobro_trasUnCobroQueSeCorrioAlMesSiguiente() {
        // Día típico 30; el último cobro llegó el 1 de noviembre: el ciclo de noviembre sigue pendiente.
        let next = RecurringPaymentDetector.nextDueDate(
            after: Self.date(2026, 11, 1), cadence: .monthly(day: 30, isApproximate: true),
            now: Self.date(2026, 11, 5), calendar: Self.lima
        )
        #expect(next == Self.lima.startOfDay(for: Self.date(2026, 11, 30)))
    }

    @Test func proximoCobro_trasUnCobroAdelantado_noRepiteElCicloPagado() {
        // Día típico 1; se cobró el 30 de octubre: el 1 de noviembre ya está pagado.
        let next = RecurringPaymentDetector.nextDueDate(
            after: Self.date(2026, 10, 30), cadence: .monthly(day: 1, isApproximate: true),
            now: Self.date(2026, 10, 31), calendar: Self.lima
        )
        #expect(next == Self.lima.startOfDay(for: Self.date(2026, 12, 1)))
    }

    @Test func fechasFuturasYMontosCero_seIgnoran() {
        let dates = (9...11).map { Self.date(2026, $0, 18) } + [Self.date(2026, 12, 18)]
        let charges = Self.charges("Agua", dates, amounts: [50, 0, 50, 50])
        // Sin el cobro de cero la serie se corta: 18 sep → 18 nov no es un mes.
        #expect(Self.detect(charges).isEmpty)
        let future = Self.charges("Agua", dates, amounts: [50, 50, 50, 50])
        let proposal = Self.detect(future).first
        #expect(proposal?.chargeCount == 3)
        #expect(proposal?.lastChargeDate == dates[2])
    }
}
