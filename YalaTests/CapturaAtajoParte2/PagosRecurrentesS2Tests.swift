//
//  PagosRecurrentesS2Tests.swift
//  YalaTests
//
//  Pagos recurrentes, lote S2 (decisión 66, encargo del 22-nov): «Netflix subió a S/ 49,90», «¿Dejaste de pagar Spotify?»
//  y la card «Dos suscripciones de la misma marca se anulan». Lógica pura con un «ahora» fijo y el calendario de Lima.
//

import Foundation
import Testing

@testable import Yala

@Suite("Pagos recurrentes S2 · precio, bajas y dos series de una marca")
@MainActor
struct PagosRecurrentesS2Tests {

    nonisolated private static let lima: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return calendar
    }()

    nonisolated private static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        lima.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? .distantPast
    }

    nonisolated private static let now = date(2026, 11, 22)

    private func planned(
        _ name: String, amount: Double, id: String = "p1", recurrence: String = "monthly", variable: Bool = false,
        created: Date = date(2026, 1, 1), lastPaid: Date? = nil, brand: String? = nil
    ) -> RecurringPaymentChanges.Planned {
        RecurringPaymentChanges.Planned(
            id: id, name: name, storedBrandID: brand, amount: amount, currencyCode: "PEN", isVariableAmount: variable,
            recurrenceType: recurrence, recurrenceInterval: 1, isActive: true, isRecurring: true, createdAt: created,
            lastPaidDate: lastPaid)
    }

    private func charge(_ name: String, _ amount: Double, _ date: Date, paymentID: String? = nil) -> RecurringPaymentChanges.Charge {
        RecurringPaymentChanges.Charge(date: date, amount: amount, currencyCode: "PEN", name: name, scheduledPaymentID: paymentID)
    }

    private func detect(_ planned: [RecurringPaymentChanges.Planned], _ charges: [RecurringPaymentChanges.Charge]) -> [RecurringPaymentChanges.Change] {
        RecurringPaymentChanges.detect(planned: planned, charges: charges, now: Self.now, calendar: Self.lima)
    }

    // MARK: - Cambio de precio

    @Test("Netflix subió: los dos últimos cobros coinciden entre sí y no con el pago")
    func priceUp_whenTheLastTwoChargesAgree() {
        let charges = [charge("NETFLIX.COM", 44.90, Self.date(2026, 9, 14)),
                       charge("NETFLIX.COM", 49.90, Self.date(2026, 10, 14)),
                       charge("Netflix", 49.90, Self.date(2026, 11, 14))]
        let changes = detect([planned("Netflix", amount: 44.90)], charges)
        #expect(changes == [RecurringPaymentChanges.Change(paymentID: "p1", kind: .priceChanged(newAmount: 49.90, increased: true))])
    }

    @Test("Un solo cobro distinto no es un cambio de precio")
    func singleDifferentCharge_isNotAChange() {
        let charges = [charge("Netflix", 44.90, Self.date(2026, 10, 14)), charge("Netflix", 49.90, Self.date(2026, 11, 14))]
        #expect(detect([planned("Netflix", amount: 44.90)], charges).isEmpty)
    }

    @Test("Bajó de precio, también con los cobros apuntados desde el propio pago")
    func priceDown_withChargesRecordedFromThePayment() {
        let charges = [charge("Pago gimnasio", 89.90, Self.date(2026, 10, 1), paymentID: "gym"),
                       charge("Pago gimnasio", 89.90, Self.date(2026, 11, 1), paymentID: "gym")]
        let changes = detect([planned("Smart Fit", amount: 99.90, id: "gym")], charges)
        #expect(changes.first?.kind == .priceChanged(newAmount: 89.90, increased: false))
    }

    @Test("Un pago de monto variable, uno cuyos cobros cuadran o uno con un salto absurdo no avisan")
    func noPriceChange_whenVariableEqualOrAbsurd() {
        let twoAt = { (amount: Double) in [charge("Luz del Sur", amount, Self.date(2026, 10, 3)),
                                           charge("Luz del Sur", amount, Self.date(2026, 11, 3))] }
        #expect(detect([planned("Luz del Sur", amount: 112, variable: true)], twoAt(131)).isEmpty)
        #expect(detect([planned("Luz del Sur", amount: 131)], twoAt(131)).isEmpty)
        #expect(detect([planned("Luz del Sur", amount: 131)], twoAt(131.5)).isEmpty) // dentro del 1 %
        #expect(detect([planned("Luz del Sur", amount: 50)], twoAt(131)).isEmpty) // más del doble
    }

    @Test("Un cambio de precio con el último cobro de hace más de 60 días no se dice")
    func priceChange_needsARecentCharge() {
        let charges = [charge("Netflix", 49.90, Self.date(2026, 8, 14)), charge("Netflix", 49.90, Self.date(2026, 9, 14))]
        let changes = detect([planned("Netflix", amount: 44.90, lastPaid: Self.date(2026, 11, 14))], charges)
        #expect(changes.isEmpty)
    }

    @Test("Otra divisa no es el mismo pago")
    func otherCurrency_doesNotCount() {
        let charges = [RecurringPaymentChanges.Charge(date: Self.date(2026, 10, 14), amount: 15.49, currencyCode: "USD",
                                                       name: "Netflix", scheduledPaymentID: nil),
                       RecurringPaymentChanges.Charge(date: Self.date(2026, 11, 14), amount: 15.49, currencyCode: "USD",
                                                       name: "Netflix", scheduledPaymentID: nil)]
        #expect(detect([planned("Netflix", amount: 44.90)], charges).isEmpty)
    }

    @Test("Con dos pagos de una marca, cada cobro va al de monto más cercano")
    func twoPaymentsOfABrand_chargesGoToTheClosestAmount() {
        let payments = [planned("YouTube Premium", amount: 25.90, id: "premium"),
                        planned("YouTube Music", amount: 15.90, id: "music")]
        let charges = [charge("YouTube", 25.90, Self.date(2026, 10, 2)), charge("YouTube", 15.90, Self.date(2026, 10, 5)),
                       charge("YouTube", 25.90, Self.date(2026, 11, 2)), charge("YouTube", 15.90, Self.date(2026, 11, 5))]
        #expect(detect(payments, charges).isEmpty)
    }

    // MARK: - Dejó de cobrarse

    @Test("¿Dejaste de pagar Spotify? Nada desde hace más de dos meses")
    func stopped_afterTwoMissedCycles() {
        let charges = [charge("Spotify", 18.90, Self.date(2026, 8, 5)), charge("Spotify", 18.90, Self.date(2026, 9, 5))]
        let changes = detect([planned("Spotify", amount: 18.90)], charges)
        #expect(changes == [RecurringPaymentChanges.Change(paymentID: "p1", kind: .stopped(lastSeen: Self.date(2026, 9, 5)))])
    }

    @Test("Un ciclo sin apuntar no es una baja, ni un «pagado» reciente, ni un pago recién creado")
    func notStopped_withOneMissOrRecentPaidOrNewPayment() {
        let oneMiss = [charge("Spotify", 18.90, Self.date(2026, 9, 5)), charge("Spotify", 18.90, Self.date(2026, 10, 5))]
        #expect(detect([planned("Spotify", amount: 18.90)], oneMiss).isEmpty)
        let old = [charge("Spotify", 18.90, Self.date(2026, 8, 5)), charge("Spotify", 18.90, Self.date(2026, 9, 5))]
        #expect(detect([planned("Spotify", amount: 18.90, lastPaid: Self.date(2026, 11, 5))], old).isEmpty)
        #expect(detect([planned("Spotify", amount: 18.90, created: Self.date(2026, 11, 1))], old).isEmpty)
    }

    @Test("Sin cobros apuntados nunca se habla de baja: puede que la persona no los apunte")
    func stopped_needsChargesToCompare() {
        #expect(detect([planned("Spotify", amount: 18.90)], [charge("Spotify", 18.90, Self.date(2026, 6, 5))]).isEmpty)
        #expect(detect([planned("Spotify", amount: 18.90)], []).isEmpty)
    }

    @Test("Semanal: tres semanas sin cobro; anual u otra cadencia, nunca")
    func stopped_weeklyAndOtherCadences() {
        let weekly = [charge("Clases de piano", 60, Self.date(2026, 10, 16)), charge("Clases de piano", 60, Self.date(2026, 10, 23))]
        #expect(detect([planned("Clases de piano", amount: 60, recurrence: "weekly")], weekly).first?.kind
                == .stopped(lastSeen: Self.date(2026, 10, 23)))
        let yearly = [charge("Seguro", 300, Self.date(2025, 1, 5)), charge("Seguro", 300, Self.date(2026, 1, 5))]
        #expect(detect([planned("Seguro", amount: 300, recurrence: "yearly")], yearly).isEmpty)
    }

    // MARK: - Lo contestado

    @Test("«Dejar así» calla ese precio, no el siguiente; «Sigue activo» calla esa baja hasta otro cobro")
    func preferences_rememberTheToken() {
        let preferences = RecurringChangePreferences(defaults: testDefaults(suiteName: "test.s2.\(UUID().uuidString)")!)
        let price = RecurringPaymentChanges.Change(paymentID: "p1", kind: .priceChanged(newAmount: 49.90, increased: true))
        #expect(preferences.isVisible(price))
        preferences.dismiss(price)
        #expect(!preferences.isVisible(price))
        #expect(preferences.isVisible(.init(paymentID: "p1", kind: .priceChanged(newAmount: 54.90, increased: true))))
        #expect(preferences.isVisible(.init(paymentID: "p2", kind: .priceChanged(newAmount: 49.90, increased: true))))

        let stop = RecurringPaymentChanges.Change(paymentID: "p3", kind: .stopped(lastSeen: Self.date(2026, 9, 5)))
        preferences.dismiss(stop)
        #expect(!preferences.isVisible(stop))
        #expect(preferences.isVisible(.init(paymentID: "p3", kind: .stopped(lastSeen: Self.date(2026, 10, 5)))))
    }

    // MARK: - Dos suscripciones de la misma marca (card nk1q)

    private func detectorCharges(_ rows: [(String, Double, Date)]) -> [RecurringPaymentDetector.Charge] {
        rows.enumerated().map { index, row in
            RecurringPaymentDetector.Charge(ref: index, date: row.2, amount: row.1, currencyCode: "PEN", name: row.0)
        }
    }

    @Test("Dos cuentas de Netflix intercaladas se proponen por separado")
    func twoNetflixAccounts_areTwoProposals() {
        var rows: [(String, Double, Date)] = []
        for month in 9...11 {
            rows.append(("Netflix", 44.90, Self.date(2026, month, 3)))
            rows.append(("Netflix", 28.90, Self.date(2026, month, 18)))
        }
        let proposals = RecurringPaymentDetector.detect(
            charges: detectorCharges(rows), plannedPayments: [], now: Self.now, calendar: Self.lima)
        #expect(proposals.count == 2)
        #expect(Set(proposals.map(\.amount)) == [44.90, 28.90])
        #expect(Set(proposals.map(\.key)).count == 2)
        #expect(proposals.allSatisfy { $0.chargeCount == 3 && $0.brandID != nil })
    }

    @Test("Una subida de precio de una marca sigue sin proponerse (los montos no se intercalan)")
    func brandPriceRise_isStillNotProposed() {
        let rows = (8...10).map { ("Netflix", 44.90, Self.date(2026, $0, 14)) } + [("Netflix", 49.90, Self.date(2026, 11, 14))]
        #expect(RecurringPaymentDetector.detect(
            charges: detectorCharges(rows), plannedPayments: [], now: Self.now, calendar: Self.lima).isEmpty)
    }

    @Test("Con un pago de una de las dos series, solo se propone la otra")
    func twoSeries_plannedCoversOnlyItsAmount() {
        var rows: [(String, Double, Date)] = []
        for month in 9...11 {
            rows.append(("Netflix", 44.90, Self.date(2026, month, 3)))
            rows.append(("Netflix", 28.90, Self.date(2026, month, 18)))
        }
        let planned = [RecurringPaymentDetector.PlannedPayment(name: "Netflix", storedBrandID: nil, amount: 44.90)]
        let proposals = RecurringPaymentDetector.detect(
            charges: detectorCharges(rows), plannedPayments: planned, now: Self.now, calendar: Self.lima)
        #expect(proposals.map(\.amount) == [28.90])
        // Sin monto (como antes), el pago de la marca tapa las dos.
        let legacy = [RecurringPaymentDetector.PlannedPayment(name: "Netflix", storedBrandID: nil)]
        #expect(RecurringPaymentDetector.detect(
            charges: detectorCharges(rows), plannedPayments: legacy, now: Self.now, calendar: Self.lima).isEmpty)
    }

    @Test("La lista de Pagos planificados monta los avisos de S2 debajo del banner de S1 (cableado)")
    func scheduledPaymentsView_mountsTheCards() throws {
        let source = try String(contentsOfFile: ComercioFotoCategoriaTests.repoFile(
            "Yala/App/Views/Planning/ScheduledPaymentsView.swift"), encoding: .utf8)
        let banner = try #require(source.range(of: "RecurringProposalsBanner {"))
        let cards = try #require(source.range(of: "RecurringChangesCards("))
        let tabs = try #require(source.range(of: "tabSelector"))
        #expect(banner.lowerBound < cards.lowerBound)
        #expect(cards.lowerBound < tabs.lowerBound)
        #expect(source.contains("viewModel.updateAmount(payment, to: amount)"))
        #expect(source.contains("viewModel.setPaused(payment, paused: true)"))
    }
}
