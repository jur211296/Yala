//
//  BandejaPlanificadoMatchLogicTests.swift
//  YalaTests
//
//  Bandeja sin duplicados, lote 4: la regla pura que decide si un cargo es un pago planificado
//  (`BandejaPlanificadoMatchLogic`). Paso 0 del encargo, D2.
//

import Foundation
import Testing

@testable import Yala

@Suite
struct BandejaPlanificadoMatchLogicTests {

    private typealias Logic = BandejaPlanificadoMatchLogic

    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ value: Int, _ hour: Int = 12) -> Date {
        var components = DateComponents(year: 2026, month: 11, day: value, hour: hour)
        components.timeZone = TimeZone(identifier: "America/Lima")
        return calendar.date(from: components)!
    }

    private var lima: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima")!
        return calendar
    }

    private func planned(
        name: String = "Luz del Sur", aliases: [String] = [], amount: Double = -120, currency: String? = "PEN",
        isEstimate: Bool = true, account: UUID? = nil, due: Int = 15, occupied: Set<InboxMatchLogic.Source> = []
    ) -> Logic.Planned {
        Logic.Planned(paymentID: UUID(), name: name, aliases: aliases, amount: amount, currencyCode: currency,
                      isEstimate: isEstimate, accountID: account, occurrence: day(due), occupiedSources: occupied)
    }

    private func arrival(
        _ amount: Double, merchant: String = "LUZ DEL SUR SAA", currency: String? = "PEN", on value: Int = 15,
        account: UUID? = nil, source: InboxMatchLogic.Source = .bankEmail
    ) -> Logic.Arrival {
        Logic.Arrival(amount: amount, currencyCode: currency, date: day(value), accountID: account,
                      merchants: [merchant], sources: [source])
    }

    // MARK: - Quién

    @Test("Solo el nombre del planificado es dudoso (la primera vez se pregunta); un alias aprendido es fuerte")
    func identity_nameIsDoubtful_aliasIsStrong() {
        #expect(Logic.identityLevel(merchants: ["LUZ DEL SUR SAA"], name: "Luz del Sur", aliases: []) == .doubtful)
        #expect(Logic.identityLevel(merchants: ["LUZ DEL SUR SAA"], name: "Luz del Sur",
                                    aliases: ["LUZ DEL SUR SAA PAGO"]) == .strong)
        #expect(Logic.identityLevel(merchants: ["ENEL DISTRIBUCION"], name: "Luz del Sur", aliases: []) == .none)
    }

    @Test("Un comercio vacío no casa con nada: el nombre es la prueba")
    func identity_emptyMerchant_isNone() {
        #expect(Logic.identityLevel(merchants: [""], name: "Netflix", aliases: ["NETFLIX.COM"]) == .none)
        #expect(Logic.identityLevel(merchants: [], name: "Netflix", aliases: []) == .none)
        #expect(Logic.identityLevel(merchants: ["Netflix"], name: "de la", aliases: []) == .none,
                "un nombre sin palabras que cuenten no casa por nombre")
    }

    @Test("Con varias fuentes unidas basta que una diga el comercio aprendido")
    func identity_anyMemberMerchant() {
        #expect(Logic.identityLevel(merchants: ["", "NETFLIX.COM"], name: "Streaming", aliases: ["Netflix.com"])
                == .strong)
    }

    // MARK: - Importe

    @Test("Estimado: toma el cargo real entre la mitad y el doble")
    func amount_estimate_halfToDouble() {
        let estimate = planned(aliases: ["LUZ DEL SUR"], amount: -120, isEstimate: true)
        #expect(Logic.compare(arrival(-134.80), estimate, calendar: lima).amount == .strong)
        #expect(Logic.compare(arrival(-60), estimate, calendar: lima).amount == .strong)
        #expect(Logic.compare(arrival(-240), estimate, calendar: lima).amount == .strong)
        #expect(Logic.compare(arrival(-59), estimate, calendar: lima).amount == .none)
        #expect(Logic.compare(arrival(-241), estimate, calendar: lima).amount == .none)
    }

    @Test("Fijo: igual al céntimo une; distinto hasta ±25 % pregunta; más lejos, nada")
    func amount_fixed_exactAskOrNone() {
        let fixed = planned(name: "Netflix", aliases: ["NETFLIX.COM"], amount: -39.90, isEstimate: false)
        #expect(Logic.compare(arrival(-39.90, merchant: "NETFLIX.COM"), fixed, calendar: lima).level == .strong)
        let raised = Logic.compare(arrival(-44.90, merchant: "NETFLIX.COM"), fixed, calendar: lima)
        #expect(raised.amount == .doubtful, "subió el precio: se pregunta, no se actualiza solo")
        #expect(raised.level == .doubtful)
        #expect(Logic.compare(arrival(-60, merchant: "NETFLIX.COM"), fixed, calendar: lima).level == .none)
    }

    @Test("Una moneda que la fuente no dijo, u otra moneda sin tasa, no une sola")
    func amount_currency() {
        let fixed = planned(name: "Netflix", aliases: ["NETFLIX"], amount: -39.90, currency: "PEN", isEstimate: false)
        #expect(Logic.compare(arrival(-39.90, merchant: "NETFLIX", currency: nil), fixed, calendar: lima).level
                == .doubtful)
        #expect(Logic.compare(arrival(-10.60, merchant: "NETFLIX", currency: "USD"), fixed, calendar: lima).level
                == .none)
        let converter: InboxMatchLogic.Converter = { amount, from, to in
            from == "USD" && to == "PEN" ? amount * 3.764 : nil
        }
        #expect(Logic.compare(arrival(-10.60, merchant: "NETFLIX", currency: "USD"), fixed, converter: converter,
                              calendar: lima).level == .doubtful, "convertida se pregunta")
    }

    @Test("Un ingreso nunca casa con un planificado de gasto")
    func kind_signMustMatch() {
        let estimate = planned(aliases: ["LUZ DEL SUR"])
        #expect(Logic.compare(arrival(120), estimate, calendar: lima).level == .none)
    }

    // MARK: - Tiempo, cuenta y fuentes

    @Test("±5 días de calendario de la ocurrencia")
    func time_fiveDays() {
        let estimate = planned(aliases: ["LUZ DEL SUR"], due: 15)
        #expect(Logic.compare(arrival(-120, on: 10), estimate, calendar: lima).time == .strong)
        #expect(Logic.compare(arrival(-120, on: 20), estimate, calendar: lima).time == .strong)
        #expect(Logic.compare(arrival(-120, on: 9), estimate, calendar: lima).time == .none)
        #expect(Logic.compare(arrival(-120, on: 21), estimate, calendar: lima).time == .none)
    }

    @Test("Otra cuenta se pregunta; sin cuenta en un lado no resta")
    func account_otherIsDoubtful() {
        let visa = UUID()
        let estimate = planned(aliases: ["LUZ DEL SUR"], account: visa)
        #expect(Logic.compare(arrival(-120, account: visa), estimate, calendar: lima).level == .strong)
        #expect(Logic.compare(arrival(-120, account: nil), estimate, calendar: lima).level == .strong)
        #expect(Logic.compare(arrival(-120, account: UUID()), estimate, calendar: lima).level == .doubtful)
    }

    @Test("Uno a uno: una fuente que ya está en el borrador del planificado no entra otra vez")
    func sources_oneOfEach() {
        let estimate = planned(aliases: ["LUZ DEL SUR"], occupied: [.bankEmail])
        #expect(Logic.compare(arrival(-120, source: .bankEmail), estimate, calendar: lima).level == .none)
        #expect(Logic.compare(arrival(-120, source: .applePay), estimate, calendar: lima).level == .strong)
    }

    // MARK: - Elegir y preguntar

    @Test("Entre dos planificados, el fuerte gana al dudoso y luego la ocurrencia más cercana")
    func best_prefersStrongThenClosest() {
        let byName = planned(name: "Luz del Sur", aliases: [], due: 15)
        let byAlias = planned(name: "Luz", aliases: ["LUZ DEL SUR SAA"], due: 18)
        let match = Logic.best(for: arrival(-120, on: 15), among: [byName, byAlias], calendar: lima)
        #expect(match?.planned.paymentID == byAlias.paymentID)
        #expect(match?.comparison.byAlias == true)

        let near = planned(aliases: ["LUZ DEL SUR"], due: 14)
        let far = planned(aliases: ["LUZ DEL SUR"], due: 19)
        #expect(Logic.best(for: arrival(-120, on: 15), among: [far, near], calendar: lima)?.planned.paymentID
                == near.paymentID)
    }

    @Test("Las preguntas van uno a uno y saltan lo contestado con «No»")
    func questions_oneToOne_andExcluded() {
        let luz = planned(aliases: [], due: 15)
        let first = arrival(-130, on: 15)
        let second = arrival(-131, on: 16)
        let questions = Logic.questions(arrivals: [first, second], planned: [luz], calendar: lima)
        #expect(questions.count == 1, "un planificado, una pregunta")
        #expect(questions.first?.arrival == 0, "la ocurrencia más cercana primero")

        let answered = Logic.questions(arrivals: [first, second], planned: [luz],
                                       excluded: { index, _ in index == 0 }, calendar: lima)
        #expect(answered.map(\.arrival) == [1], "con «No» al primero, se pregunta por el siguiente")
    }
}
