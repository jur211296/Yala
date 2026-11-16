//
//  BankNoticeReadingFlowTests.swift
//  YalaTests
//
//  Atajo del banco (2.3, B1): el orden de la lectura en la acción de Atajos (reglas → modelo del iPhone → «No
//  entendimos») y lo que se acepta del modelo. El modelo real no corre en el simulador: se inyecta.
//

import Foundation
import Testing

@testable import Yala

@Suite("Atajo del banco · lectura de la acción")
struct BankNoticeReadingFlowTests {

    private let bcp = "Consumo con tu tarjeta\nRealizaste un consumo de S/ 12.50 con tu Tarjeta de Débito BCP ****4821 en TAMBO+ MIRAFLORES."
    private let unknown = "Operación por USD 12.00 en AMZN Mktp US*2K4"
    private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Si una regla lo lee, el modelo no se consulta")
    func rulesFirst_modelNotAsked() async {
        var asked = false
        let entry = await BankNoticeIntent.read(text: bcp, bankHint: .bcp, now: fixedNow) { _ in
            asked = true
            return .notUnderstood
        }
        #expect(!asked)
        guard case .movement(_, let rule) = entry.reading else { Issue.record("sin movimiento"); return }
        #expect(rule == "bcp.consumo")
        #expect(entry.bank == .bcp)
        #expect(entry.rawText == bcp)
        #expect(entry.receivedAt == fixedNow.timeIntervalSince1970)
    }

    @Test("Sin regla, lee el modelo; su lectura queda sin regla")
    func modelFallback() async {
        let modeled = BankNoticeReading.movement(
            BankNoticeMovement(amount: 12, currencyCode: "USD", ambiguousSymbol: nil, isExpense: true,
                               counterparty: "AMZN Mktp", cardLast4: nil),
            ruleID: nil)
        let entry = await BankNoticeIntent.read(text: unknown, bankHint: .bcp, now: fixedNow) { _ in modeled }
        #expect(entry.reading == modeled)
    }

    @Test("Sin regla y sin modelo (iPhone sin Apple Intelligence): «No entendimos este aviso»")
    func noModel_notUnderstood() async {
        let entry = await BankNoticeIntent.read(text: unknown, bankHint: nil, now: fixedNow) { _ in nil }
        #expect(entry.reading == .notUnderstood)
        #expect(entry.reading.leavesDraft)
    }

    @Test("«No era una compra» no deja borrador")
    func notAMovement_leavesNoDraft() async {
        let entry = await BankNoticeIntent.read(text: "Tu clave dinámica es 123456", bankHint: .bcp, now: fixedNow) { _ in nil }
        #expect(entry.reading == .notAMovement)
        #expect(!entry.reading.leavesDraft)
    }

    // MARK: - Lo que se acepta del modelo

    private func reading(isMovement: Bool = true, amount: Double?, currency: String? = "USD", isExpense: Bool = true,
                         counterparty: String? = "AMZN Mktp") -> BankNoticeModelReader.Reading {
        BankNoticeModelReader.Reading(isMovement: isMovement, amount: amount, currencyCode: currency,
                                      isExpense: isExpense, counterparty: counterparty)
    }

    @Test("Un importe que el aviso no dice no se acepta: mejor no leerlo que leerlo mal")
    func model_amountNotInText_isRejected() {
        #expect(BankNoticeModelReader.accept(reading(amount: 21.0), text: unknown) == nil)
        #expect(BankNoticeModelReader.accept(reading(amount: nil), text: unknown) == nil)
        #expect(BankNoticeModelReader.accept(reading(amount: -12.0), text: unknown) == nil)
        #expect(BankNoticeModelReader.accept(reading(amount: .nan), text: unknown) == nil)
    }

    @Test("Un importe escrito en el aviso se acepta, con moneda y comercio")
    func model_amountInText_isAccepted() {
        let accepted = BankNoticeModelReader.accept(reading(amount: 12.0), text: unknown)
        guard case .movement(let m, let rule)? = accepted else { Issue.record("no aceptado"); return }
        #expect(rule == nil)
        #expect(m.amount == 12 && m.currencyCode == "USD" && m.isExpense && m.counterparty == "AMZN Mktp")
    }

    @Test("Si el modelo dice que no es un movimiento, es «No era una compra»")
    func model_notAMovement() {
        #expect(BankNoticeModelReader.accept(reading(isMovement: false, amount: nil), text: unknown) == .notAMovement)
    }

    @Test("Una moneda que no es un código ISO se descarta")
    func model_badCurrency() {
        guard case .movement(let m, _)? = BankNoticeModelReader.accept(reading(amount: 12.0, currency: "dólares"), text: unknown) else {
            Issue.record("no aceptado"); return
        }
        #expect(m.currencyCode == nil)
    }
}

@Suite(.serialized)
struct BankNoticePendingStoreTests {

    private let defaults = testDefaults(suiteName: "test.banknotice.pending.\(UUID().uuidString)")!

    private func entry(_ text: String, at time: Double) -> BankNoticePendingEntry {
        BankNoticePendingEntry(rawText: text, bank: .bcp, reading: .notUnderstood, receivedAt: time)
    }

    @Test("Encolar, leer en orden de llegada y borrar solo lo pedido")
    func appendPeekRemove() {
        BankNoticePendingStore.append(entry("b", at: 20), defaults: defaults)
        BankNoticePendingStore.append(entry("a", at: 10), defaults: defaults)
        let all = BankNoticePendingStore.peekAll(defaults: defaults)
        #expect(all.map(\.entry.rawText) == ["a", "b"])
        BankNoticePendingStore.remove(keys: [all[0].key], defaults: defaults)
        #expect(BankNoticePendingStore.peekAll(defaults: defaults).map(\.entry.rawText) == ["b"])
    }

    @Test("Una lectura con movimiento sobrevive a la cola entera (Codable)")
    func roundTrip_movement() {
        let movement = BankNoticeReading.movement(
            BankNoticeMovement(amount: Decimal(string: "12.50")!, currencyCode: "PEN", ambiguousSymbol: nil,
                               isExpense: true, counterparty: "TAMBO+", cardLast4: "4821"),
            ruleID: "bcp.consumo")
        BankNoticePendingStore.append(
            BankNoticePendingEntry(rawText: "x", bank: .yape, reading: movement, receivedAt: 1), defaults: defaults)
        let read = BankNoticePendingStore.peekAll(defaults: defaults).first?.entry
        #expect(read?.reading == movement)
        #expect(read?.bank == .yape)
    }

    @Test("Lo que no decodifica bajo una key de la cola se descarta, sin bucle")
    func corruptEntry_isDropped() {
        defaults.set(Data("no es json".utf8), forKey: BankNoticePendingStore.keyPrefix + "roto")
        defaults.set("ni siquiera Data", forKey: BankNoticePendingStore.keyPrefix + "raro")
        #expect(BankNoticePendingStore.peekAll(defaults: defaults).isEmpty)
        #expect(defaults.object(forKey: BankNoticePendingStore.keyPrefix + "roto") == nil)
        #expect(defaults.object(forKey: BankNoticePendingStore.keyPrefix + "raro") == nil)
    }

    @Test("La cola no se mezcla con la de Apple Pay ni con la de Siri")
    func ownPrefix() {
        #expect(BankNoticePendingStore.keyPrefix != ApplePayPendingStore.keyPrefix)
        #expect(BankNoticePendingStore.keyPrefix != SiriPendingStore.keyPrefix)
        #expect(!BankNoticePendingStore.keyPrefix.hasPrefix(ApplePayPendingStore.keyPrefix))
        #expect(!BankNoticePendingStore.keyPrefix.hasPrefix(SiriPendingStore.keyPrefix))
    }
}
