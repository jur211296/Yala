//
//  SplitConfigCodecTests.swift
//  YalaTests
//
//  Pure-logic tests for `SplitConfigCodec` — la plantilla de división de un pago
//  planificado de grupo (participantes CSV + valores "uuid:value"). Sin SwiftData ni UI.
//

import Foundation
import Testing

@testable import Yala

@Suite("Split Config Codec")
struct SplitConfigCodecTests {

    // MARK: - Participants

    @Test func encodeParticipants_empty_returnsNil() {
        #expect(SplitConfigCodec.encodeParticipants([]) == nil)
    }

    @Test func participants_roundTrip() {
        let a = UUID(); let b = UUID()
        let csv = SplitConfigCodec.encodeParticipants([a, b])
        #expect(Set(SplitConfigCodec.decodeParticipants(csv)) == Set([a, b]))
    }

    @Test func decodeParticipants_nilOrEmpty_returnsEmpty() {
        #expect(SplitConfigCodec.decodeParticipants(nil).isEmpty)
        #expect(SplitConfigCodec.decodeParticipants("").isEmpty)
    }

    @Test func decodeParticipants_dropsInvalidTokens() {
        let a = UUID()
        #expect(SplitConfigCodec.decodeParticipants("\(a.uuidString),not-a-uuid") == [a])
    }

    @Test func encodeParticipants_dedupesAndSorts() {
        let a = UUID(); let b = UUID()
        let csv1 = SplitConfigCodec.encodeParticipants([a, b, a])
        let csv2 = SplitConfigCodec.encodeParticipants([b, a])
        // Orden estable (sorted) + dedup → misma cadena sin importar el orden de entrada.
        #expect(csv1 == csv2)
    }

    // MARK: - Values

    @Test func encodeValues_empty_returnsNil() {
        #expect(SplitConfigCodec.encodeValues([:]) == nil)
    }

    @Test func values_roundTrip() {
        let a = UUID(); let b = UUID()
        let map: [UUID: Double] = [a: 40, b: 60]
        #expect(SplitConfigCodec.decodeValues(SplitConfigCodec.encodeValues(map)) == map)
    }

    @Test func decodeValues_nilOrEmpty_returnsEmpty() {
        #expect(SplitConfigCodec.decodeValues(nil).isEmpty)
        #expect(SplitConfigCodec.decodeValues("").isEmpty)
    }

    @Test func decodeValues_dropsMalformedPairs() {
        let a = UUID()
        let csv = "\(a.uuidString):40,garbage,\(UUID().uuidString):abc"
        #expect(SplitConfigCodec.decodeValues(csv) == [a: 40])
    }

    @Test func values_pairingIsOrderIndependent() {
        // El pareo uuid→valor es explícito, no depende de dos CSV paralelos.
        let a = UUID(); let b = UUID()
        let decoded = SplitConfigCodec.decodeValues(SplitConfigCodec.encodeValues([a: 33.3, b: 66.7]))
        #expect(decoded[a] == 33.3)
        #expect(decoded[b] == 66.7)
    }
}
