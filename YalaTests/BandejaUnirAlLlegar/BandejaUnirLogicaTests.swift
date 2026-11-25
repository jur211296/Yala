//
//  BandejaUnirLogicaTests.swift
//  YalaTests
//
//  Bandeja sin duplicados, lote 2 · la lógica pura del registro de unión (`InboxJoinRecord`, `InboxJoinLogic`): leerlo,
//  qué cambia al unir y qué devuelve «Separar».
//

import Foundation
import Testing

@testable import Yala

@Suite("Bandeja sin duplicados · registro de unión")
struct BandejaUnirLogicaTests {

    private let visa = UUID()
    private let cafe = UUID()
    private let day = Date(timeIntervalSince1970: 1_795_000_000)

    private func fields(_ note: String, _ amount: Double?, account: UUID? = nil, sub: UUID? = nil,
                        date: Date? = nil) -> InboxJoinRecord.Fields {
        InboxJoinRecord.Fields(note: note, amount: amount, date: date ?? day, accountShortcutID: account,
                               subcategoryShortcutID: sub, cachedCurrencyCode: nil)
    }

    private func facts(_ source: InboxMatchLogic.Source, exact: Bool = false) -> InboxJoinRecord.SourceFacts {
        InboxJoinRecord.SourceFacts(source: source.rawValue, currencyCode: "PEN", last4: nil, hasExactTime: exact)
    }

    private func record(before: InboxJoinRecord.Fields, after: InboxJoinRecord.Fields) -> InboxJoinRecord {
        InboxJoinRecord(
            version: 1, holderSource: facts(.applePay, exact: true), holderBefore: before, holderAfter: after,
            members: [InboxJoinRecord.Member(
                facts: facts(.bankEmail), fields: fields("STARBUCKS", -42.51), sourceTypeRaw: "emailAlert",
                createdAt: day, rawText: nil, evidence: "BCP · ****4821", confidenceAmount: 0.9, confidenceDate: 0.9,
                confidenceMerchant: 0.9, confidenceSubcategory: nil, joinedAt: day)])
    }

    @Test func leer_loQueSeEscribio() throws {
        let original = record(before: fields("Starbucks", -42.5), after: fields("Starbucks", -42.51))
        let raw = try #require(original.encoded())
        #expect(InboxJoinRecord.read(raw) == .record(original))
        #expect(InboxJoinRecord.read(nil) == .none)
        #expect(InboxJoinRecord.read("") == .none)
    }

    @Test func leer_loQueNoSeEntiende_noEsNada() throws {
        var future = record(before: fields("a", -1), after: fields("a", -1))
        future.version = InboxJoinRecord.currentVersion + 1
        #expect(InboxJoinRecord.read(try #require(future.encoded())) == .unreadable, "una versión futura no se toca")
        #expect(InboxJoinRecord.read("{roto") == .unreadable)
        var empty = record(before: fields("a", -1), after: fields("a", -1))
        empty.members = []
        #expect(InboxJoinRecord.read(try #require(empty.encoded())) == .unreadable, "un registro sin absorbidos no separa nada")
    }

    @Test func separar_devuelveSoloLoQueSigueComoLoDejoLaUnion() {
        let before = fields("Starbucks", -42.5, date: day)
        let after = fields("Starbucks", -42.51, account: visa, date: day.addingTimeInterval(3600))
        let rec = record(before: before, after: after)

        #expect(InboxJoinLogic.restoredFields(current: after, record: rec) == before, "sin ediciones vuelve todo")

        var edited = after
        edited.note = "Café con Ana"
        edited.subcategoryShortcutID = cafe
        let restored = InboxJoinLogic.restoredFields(current: edited, record: rec)
        #expect(restored.note == "Café con Ana", "lo que la persona cambió se queda")
        #expect(restored.subcategoryShortcutID == cafe)
        #expect(restored.amount == -42.5)
        #expect(restored.accountShortcutID == nil)
        #expect(restored.date == day)
    }

    @Test func unir_rellenaCuentaYCategoriaSoloSiFaltaban() throws {
        let holder = fields("Starbucks", -42.5, account: nil, sub: cafe)
        let arriving = fields("STARBUCKS", -42.51, account: visa, sub: UUID())
        let holderCandidate = try #require(InboxJoinLogic.candidate(
            id: UUID(), facts: facts(.applePay, exact: true), fields: holder, fallbackDate: day))
        let arrivingCandidate = try #require(InboxJoinLogic.candidate(
            id: UUID(), facts: facts(.bankEmail), fields: arriving, fallbackDate: day))
        var consumption = InboxMatchLogic.Consumption(holderCandidate)
        let absorbed = consumption.absorb(arrivingCandidate)
        #expect(absorbed)

        let merged = InboxJoinLogic.mergedFields(holder: holder, arriving: arriving, resolved: consumption.resolved)
        #expect(merged.amount == -42.51, "el importe del banco")
        #expect(merged.note == "Starbucks", "el comercio de Apple Pay")
        #expect(merged.accountShortcutID == visa, "la cuenta faltaba: la trae el correo")
        #expect(merged.subcategoryShortcutID == cafe, "la categoría ya estaba: no se pisa")
    }

    @Test func fuentes_enOrdenDeLlegada() {
        let rec = record(before: fields("a", -1), after: fields("a", -1))
        #expect(InboxJoinLogic.sources(of: rec) == [.applePay, .bankEmail])
    }
}
