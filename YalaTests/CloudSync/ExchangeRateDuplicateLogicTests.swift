//
//  ExchangeRateDuplicateLogicTests.swift
//  YalaTests / CloudSync
//
//  Card i9wh: qué tasas son la misma y cómo se funden antes de «Activar la nube».
//

import Foundation
import Testing

@testable import Yala

@Suite("ExchangeRateDuplicateLogic · fusión de tasas del mismo día (card i9wh)")
struct ExchangeRateDuplicateLogicTests {

    private func row(_ id: Int, _ day: String, sid: String, base: String = "USD", ts: TimeInterval? = nil,
                     _ rates: [String: Double]) -> ExchangeRateDuplicateLogic.Row {
        .init(id: id, dateKey: day, base: base, syncID: sid, timestamp: ts.map { Date(timeIntervalSince1970: $0) },
              rates: rates)
    }

    @Test("sobrevive el menor syncID, sea cual sea el orden de llegada")
    func survivorIsTheSmallestSyncID() {
        let rows = [row(0, "d", sid: "c", ["A": 1]), row(1, "d", sid: "a", ["A": 2]), row(2, "d", sid: "b", ["A": 3])]
        let fusion = ExchangeRateDuplicateLogic.fusions(rows)
        #expect(fusion.map(\.survivorID) == [1])
        #expect(fusion.first?.loserIDs == [0, 2])
        // Otro dispositivo que las ve en otro orden elige la misma.
        let other = ExchangeRateDuplicateLogic.fusions(rows.reversed())
        #expect(other.map(\.survivorID) == [1])
    }

    @Test("las tasas se funden de la más vieja a la más nueva; sin hora va primero")
    func ratesMergeOldestFirst() throws {
        let rows = [
            row(0, "d", sid: "a", ts: 200, ["PEN": 3.8, "EUR": 0.9]),
            row(1, "d", sid: "b", ts: nil, ["PEN": 1.0, "ARS": 1000]),
            row(2, "d", sid: "c", ts: 100, ["PEN": 3.7, "JPY": 150]),
        ]
        let fusion = try #require(ExchangeRateDuplicateLogic.fusions(rows).first)
        #expect(fusion.mergedRates == ["PEN": 3.8, "EUR": 0.9, "ARS": 1000, "JPY": 150])
        #expect(fusion.mergedTimestamp == Date(timeIntervalSince1970: 200))
    }

    @Test("empate de hora: decide el syncID, y gana el mayor (se aplica después)")
    func tieBreaksBySyncID() {
        let rows = [row(0, "d", sid: "b", ts: 5, ["PEN": 2]), row(1, "d", sid: "a", ts: 5, ["PEN": 1])]
        #expect(ExchangeRateDuplicateLogic.fusions(rows).first?.mergedRates == ["PEN": 2])
    }

    @Test("días distintos o bases distintas no se funden")
    func differentDayOrBaseIsNotADuplicate() {
        let rows = [row(0, "d1", sid: "a", ["A": 1]), row(1, "d2", sid: "b", ["A": 1]),
                    row(2, "d1", sid: "c", base: "EUR", ["A": 1])]
        #expect(ExchangeRateDuplicateLogic.fusions(rows).isEmpty)
    }

    @Test("el caso medido: 9 copias de un día dejan 1 y borran 8")
    func nineCopies() {
        let rows = (0..<9).map { row($0, "2026-10-20", sid: String(format: "%02d", 9 - $0), ["PEN": Double($0)]) }
        let fusion = ExchangeRateDuplicateLogic.fusions(rows)
        #expect(fusion.count == 1)
        #expect(fusion.first?.survivorID == 8)
        #expect(fusion.first?.loserIDs.count == 8)
    }
}
