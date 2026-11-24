//
//  InboxMatchScenarioTests.swift
//  YalaTests
//
//  Bandeja sin duplicados, lote 1: los escenarios medidos en el informe (`docs/propuestas/bandeja-sin-duplicados/`,
//  sección 2) y los casos difíciles, pasados por el emparejador entre fuentes. Lo que fija, por gravedad si se rompiera:
//   - dos compras reales iguales por la misma fuente nunca se funden (perder un gasto es peor que verlo dos veces);
//   - el mismo café por Apple Pay, aviso y correo queda en UN pendiente, con el importe del banco y la hora de Apple Pay;
//   - el cruce de medianoche (Apple Pay 23:50, correo del día siguiente) se une;
//   - un reembolso, una cuota o un cargo parcial no se comen al gasto;
//   - lo que ya está guardado pregunta («Ya registrado»), nunca se une solo.
//

import Foundation
import Testing
@testable import Yala

@Suite("Emparejador entre fuentes · escenarios del informe")
struct InboxMatchScenarioTests {

    private typealias F = MatchFixtures

    // MARK: - E1 a E10

    @Test("E1 · el mismo café por Apple Pay, aviso y correo queda en un pendiente")
    func e1_sameCoffeeThreeSources_oneConsumption() throws {
        let applePay = F.applePay(-42.50, 13, 5, account: F.bcpVisa)
        let notice = F.notice(-42.50, 13, 6)
        let email = F.email(-42.50)

        let outcome = F.pair([applePay, notice, email])

        #expect(outcome.consumptions.count == 1)
        #expect(outcome.questions.isEmpty)
        let consumption = try #require(outcome.consumptions.first)
        #expect(consumption.sources == [.applePay, .bankNotice, .bankEmail])
        let resolved = consumption.resolved
        #expect(resolved.money == .init(amount: -42.50, currencyCode: "PEN"))
        #expect(resolved.moneySource == .bankEmail)
        #expect(resolved.merchant == "Starbucks")
        #expect(resolved.merchantSource == .applePay)
        #expect(resolved.date == F.at(day: 15, 13, 5))
        #expect(resolved.dateSource == .applePay)
        #expect(resolved.accountID == F.bcpVisa)
        #expect(resolved.originalMoney == nil)
    }

    @Test("E1 · el orden de llegada no cambia el resultado: correo primero, Apple Pay al final")
    func e1_arrivalOrderDoesNotMatter() throws {
        let outcome = F.pair([F.email(-42.50), F.notice(-42.50, 13, 6), F.applePay(-42.50, 13, 5)])

        #expect(outcome.consumptions.count == 1)
        let resolved = try #require(outcome.consumptions.first).resolved
        #expect(resolved.date == F.at(day: 15, 13, 5))
        #expect(resolved.merchant == "Starbucks")
        #expect(resolved.money.amount == -42.50)
    }

    @Test("E2 · Apple Pay a las 23:50 del 15 y correo fechado el 16 se unen, con la hora de Apple Pay")
    func e2_midnightCrossing_joins() throws {
        let applePay = F.applePay(-89.90, day: 15, 23, 50)
        let email = F.email(-89.90, day: 16)

        let outcome = F.pair([applePay, email])

        #expect(outcome.consumptions.count == 1)
        let resolved = try #require(outcome.consumptions.first).resolved
        #expect(resolved.date == F.at(day: 15, 23, 50))
        #expect(resolved.hasExactTime)
        #expect(resolved.accountID == F.bcpVisa)
    }

    @Test("E2 · al revés no: un correo fechado el día ANTES de la compra no se une solo")
    func e2_emailBeforePurchase_onlyAsks() {
        let comparison = F.compare(F.applePay(-89.90, day: 16, 0, 10), F.email(-89.90, day: 15))
        #expect(comparison.time == .doubtful)
        #expect(comparison.level == .doubtful)
    }

    @Test("E3 · Apple Pay en dólares y correo en soles: pregunta, y si es el mismo manda el importe del banco")
    func e3_foreignCurrency_asksAndBankAmountWins() throws {
        let applePay = F.applePay(-11.30, currency: "USD", 13, 5, account: nil)
        let email = F.email(-42.94)

        let outcome = F.pair([applePay, email])

        #expect(outcome.consumptions.count == 2)
        #expect(outcome.questions == [.init(arrivalID: email.id, kind: .sameExpense(consumptionID: applePay.id))])

        // La persona contesta «Es el mismo»: lo une el lote 2; aquí, lo que queda.
        var consumption = InboxMatchLogic.Consumption(applePay)
        let absorbed = consumption.absorb(email)
        #expect(absorbed)
        let resolved = consumption.resolved
        #expect(resolved.money == .init(amount: -42.94, currencyCode: "PEN"))
        #expect(resolved.originalMoney == .init(amount: -11.30, currencyCode: "USD"))
        #expect(resolved.accountID == F.bcpVisa)
        #expect(resolved.merchant == "Starbucks")
        #expect(resolved.date == F.at(day: 15, 13, 5))
    }

    @Test("E3 · sin tasa para convertir, dos monedas distintas no se parecen")
    func e3_withoutRates_noMatch() {
        let comparison = InboxMatchLogic.compare(
            F.applePay(-11.30, currency: "USD", 13, 5, account: nil), F.email(-42.94), converter: nil, calendar: F.lima)
        #expect(comparison.amount == .none)
    }

    @Test("E4 · lo que la IA apunta de un correo se une al café que ya estaba pendiente por Apple Pay")
    func e4_aiOverApplePay_joins() {
        let applePay = F.applePay(-42.50, 13, 5)
        let ai = F.ai(-42.50)

        let outcome = F.pair([applePay, ai])

        #expect(outcome.consumptions.count == 1)
        #expect(outcome.consumptions.first?.sources == [.applePay, .aiConnector])
    }

    @Test("E5 · la IA apunta el mismo correo dos veces: el emparejador no las funde (la llave es `referencia`)")
    func e5_aiTwice_sameSourceNeverMerges() {
        let outcome = F.pair([F.ai(-42.50), F.ai(-42.50)])

        // Misma fuente: puede ser dos cosas reales. El mismo correo leído dos veces lo frena la `referencia` del
        // conector al encolar, y lo que pase aún lo retiene la red al guardar (`InboxDuplicateCheck`).
        #expect(outcome.consumptions.count == 2)
        #expect(outcome.questions.isEmpty)
    }

    @Test("E6 · la IA apunta algo ya guardado a mano: «Ya registrado»")
    func e6_aiOverSaved_alreadyRecorded() {
        let saved = F.saved(-42.50, 9, 30)
        let ai = F.ai(-42.50)

        let outcome = F.pair([ai], saved: [saved])

        #expect(outcome.consumptions.count == 1)
        #expect(outcome.questions == [.init(arrivalID: ai.id, kind: .alreadyRecorded(savedID: saved.id, level: .strong))])
    }

    @Test("E7 · el planificado no entra al emparejador entre fuentes: es el lote 4")
    @MainActor
    func e7_scheduledPayment_isOutsideThisMatcher() {
        // Luz del Sur estimado S/ 120 y correo S/ 134.80: el planificado no tiene fuente aquí, así que este lote no lo
        // toca. El lote 4 casa planificados con sus propias reglas (±5 días, monto estimado, alias aprendido).
        #expect(InboxMatchLogic.source(for: .scheduledPayment, isBankNotice: false) == nil)
        #expect(InboxMatchLogic.source(for: .subscription, isBankNotice: false) == nil)
        // Y aunque lo tuviera, 120 frente a 134.80 (12 %) no se parece por importe.
        let estimated = InboxMatchLogic.Candidate(
            source: .web, amount: -120, currencyCode: "PEN", date: F.at(day: 15, 12), hasExactTime: false,
            accountID: F.bcpVisa, merchant: "Luz del Sur")
        #expect(F.compare(estimated, F.email(-134.80, merchant: "LUZ DEL SUR")).amount == .none)
    }

    @Test("E8 · dos compras reales iguales por Apple Pay quedan como dos")
    func e8_twoRealPurchases_stayTwo() {
        let morning = F.applePay(-12, 8, 10)
        let evening = F.applePay(-12, 18, 40)

        let outcome = F.pair([morning, evening])

        #expect(outcome.consumptions.count == 2)
        #expect(outcome.questions.isEmpty)
    }

    @Test("E9 · gasto por Apple Pay y reembolso por correo el mismo día: dos movimientos")
    func e9_refund_neverJoinsTheExpense() {
        let outcome = F.pair([F.applePay(-42.50, 13, 5), F.email(42.50)])

        #expect(outcome.consumptions.count == 2)
        #expect(outcome.questions.isEmpty)
    }

    @Test("E10 · registro a mano y, horas después, el aviso del banco: «Ya registrado»")
    func e10_noticeAfterManualEntry_alreadyRecorded() {
        let saved = F.saved(-30, 9, 0, merchant: "Tambo")
        let notice = F.notice(-30, 13, 20, merchant: "TAMBO+ MIRAFLORES")

        let outcome = F.pair([notice], saved: [saved])

        #expect(outcome.questions == [.init(arrivalID: notice.id, kind: .alreadyRecorded(savedID: saved.id, level: .strong))])
    }

    // MARK: - Casos difíciles

    @Test("Dos compras reales iguales: cada aviso se une a SU compra, no a la primera")
    func twoRealPurchases_eachNoticeFindsItsOwn() throws {
        let morning = F.applePay(-12, 8, 10)
        let evening = F.applePay(-12, 18, 40)
        let eveningNotice = F.notice(-12, 18, 41)
        let morningNotice = F.notice(-12, 8, 11)

        let outcome = F.pair([morning, evening, eveningNotice, morningNotice])

        #expect(outcome.consumptions.count == 2)
        #expect(outcome.questions.isEmpty)
        let first = try #require(outcome.consumptions.first { $0.id == morning.id })
        let second = try #require(outcome.consumptions.first { $0.id == evening.id })
        #expect(first.members.map(\.id) == [morning.id, morningNotice.id])
        #expect(second.members.map(\.id) == [evening.id, eveningNotice.id])
    }

    @Test("Dos compras reales iguales y dos correos (sin hora): uno por compra, nunca dos en la misma")
    func twoRealPurchases_twoEmails_oneEach() {
        let outcome = F.pair([F.applePay(-12, 8, 10), F.applePay(-12, 18, 40), F.email(-12), F.email(-12)])

        #expect(outcome.consumptions.count == 2)
        #expect(outcome.consumptions.allSatisfy { $0.sources == [.applePay, .bankEmail] })
    }

    @Test("Un consumo absorbe uno de cada fuente: el segundo aviso igual queda solo")
    func oneOfEachSource_secondNoticeStaysAlone() {
        let outcome = F.pair([F.applePay(-42.50, 13, 5), F.notice(-42.50, 13, 6), F.notice(-42.50, 13, 7)])

        #expect(outcome.consumptions.count == 2)
        #expect(outcome.consumptions.first?.sources == [.applePay, .bankNotice])
        #expect(outcome.consumptions.last?.sources == [.bankNotice])
    }

    @Test("Reversa: el extorno del banco no se come al gasto ni al aviso del cargo")
    func reversal_staysApart() {
        let charge = F.applePay(-150, 10, 0, merchant: "Saga Falabella")
        let chargeNotice = F.notice(-150, 10, 1, merchant: "SAGA FALABELLA")
        let reversal = F.notice(150, 16, 30, merchant: "EXTORNO SAGA FALABELLA")

        let outcome = F.pair([charge, chargeNotice, reversal])

        #expect(outcome.consumptions.count == 2)
        #expect(outcome.consumptions.first?.sources == [.applePay, .bankNotice])
        #expect(outcome.consumptions.last?.members.map(\.id) == [reversal.id])
        #expect(outcome.questions.isEmpty)
    }

    @Test("Cuotas: la cuota de S/ 200 no se une a la compra de S/ 600, ni las cuotas entre sí")
    func installments_neverJoin() {
        let purchase = F.applePay(-600, day: 3, 11, 0, merchant: "Hiraoka")
        let first = F.email(-200, day: 3, merchant: "HIRAOKA CUOTA 1/3")
        let second = F.email(-200, day: 4, merchant: "HIRAOKA CUOTA 2/3")

        let outcome = F.pair([purchase, first, second])

        #expect(outcome.consumptions.count == 3)
        #expect(outcome.questions.isEmpty)
    }

    @Test("Cargo parcial: la preautorización de S/ 100 y el cargo final de S/ 98.50 preguntan, no se unen solos")
    func partialCharge_withinThreePercent_asks() {
        let preauth = F.applePay(-100, 7, 45, merchant: "Primax")
        let final = F.notice(-98.50, 7, 50, merchant: "PRIMAX")

        let outcome = F.pair([preauth, final])

        #expect(outcome.consumptions.count == 2)
        #expect(outcome.questions == [.init(arrivalID: final.id, kind: .sameExpense(consumptionID: preauth.id))])
    }

    @Test("Cargo partido en dos envíos: ninguna parte se une a la compra entera")
    func splitShipment_partsDoNotJoin() {
        let outcome = F.pair([
            F.applePay(-200, 12, 0, merchant: "Amazon"),
            F.email(-120, merchant: "AMAZON MKTPLACE"),
            F.notice(-80, 12, 5, merchant: "AMAZON MKTPLACE"),
        ])

        #expect(outcome.consumptions.count == 3)
        #expect(outcome.questions.isEmpty)
    }

    @Test("Aviso después de un registro a mano con hora: «Ya registrado» aunque el comercio se escriba distinto")
    func noticeAfterManual_differentSpelling() {
        let saved = F.saved(-25, 13, 0, merchant: "Almuerzo")
        let notice = F.notice(-25, 13, 15, merchant: "RESTAURANT LA LUCHA")

        let decision = InboxMatchLogic.decide(notice, pending: [], saved: [saved], converter: F.converter, calendar: F.lima)

        // El comercio distinto baja a «dudosa»: igual pregunta, no lo deja pasar en silencio.
        #expect(decision == .alreadyRecorded(savedID: saved.id, level: .doubtful))
    }

    @Test("Un Apple Pay ya guardado no frena otro Apple Pay igual: es otra compra")
    func savedApplePay_doesNotBlockAnotherApplePay() {
        let saved = F.saved(-12, 8, 10, source: .applePay)
        let decision = InboxMatchLogic.decide(
            F.applePay(-12, 8, 30, account: F.bcpVisa), pending: [], saved: [saved], converter: F.converter, calendar: F.lima)
        #expect(decision == .new)
    }

    @Test("Un pendiente fuerte gana a lo guardado: el café se une al pendiente, no pregunta por el guardado de ayer")
    func strongPending_beatsSaved() {
        let pending = InboxMatchLogic.Consumption(F.applePay(-42.50, 13, 5))
        let savedYesterday = F.saved(-42.50, day: 14, 13, 0)

        let decision = InboxMatchLogic.decide(
            F.notice(-42.50, 13, 6), pending: [pending], saved: [savedYesterday], converter: F.converter, calendar: F.lima)

        #expect(decision == .join(consumptionID: pending.id))
    }

    @Test("Lo guardado fuerte gana a un pendiente dudoso")
    func strongSaved_beatsDoubtfulPending() {
        let doubtfulPending = InboxMatchLogic.Consumption(F.applePay(-42.50, 1, 0))
        let saved = F.saved(-42.50, 13, 0)

        let decision = InboxMatchLogic.decide(
            F.notice(-42.50, 13, 6), pending: [doubtfulPending], saved: [saved], converter: F.converter, calendar: F.lima)

        #expect(decision == .alreadyRecorded(savedID: saved.id, level: .strong))
    }
}
