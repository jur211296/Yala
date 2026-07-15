//
//  PendingJoinEntryBackCompatTests.swift
//  YalaTests
//
//  Contrato C3: PendingJoinEntry v2 (backendGroupID/inviteToken opcionales) decodifica JSON VIEJO sin
//  esos campos (decodeIfPresent sintetizado) y `isBackendJoin` deriva del token.
//

import Foundation
import Testing

@testable import Yala

struct PendingJoinEntryBackCompatTests {

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    @Test func decodesLegacyJSON_withoutBackendFields() throws {
        // Forma EXACTA de una entry v1 persistida (sin backendGroupID/inviteToken).
        let json = """
        {"zoneName":"SplitGroup-OLD","zoneOwnerName":"_owner","createdAt":"2026-07-01T12:00:00Z"}
        """.data(using: .utf8)!
        let entry = try Self.decoder().decode(PendingJoinEntry.self, from: json)
        #expect(entry.zoneName == "SplitGroup-OLD")
        #expect(entry.backendGroupID == nil)
        #expect(entry.inviteToken == nil)
        #expect(entry.isBackendJoin == false)
    }

    @Test func decodesLegacyJSON_withDisplayName() throws {
        let json = """
        {"zoneName":"Z","zoneOwnerName":"O","displayName":"Pia","regionFallbackCurrency":"PEN","createdAt":"2026-07-01T12:00:00Z"}
        """.data(using: .utf8)!
        let entry = try Self.decoder().decode(PendingJoinEntry.self, from: json)
        #expect(entry.displayName == "Pia")
        #expect(entry.regionFallbackCurrency == "PEN")
        #expect(entry.isBackendJoin == false)
    }

    @Test func backendEntry_isBackendJoin_true_andRoundTrips() throws {
        let entry = PendingJoinEntry(
            zoneName: "SplitGroup-NEW", zoneOwnerName: "",
            backendGroupID: "SplitGroup-NEW", inviteToken: "tok01")
        #expect(entry.isBackendJoin)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)
        let round = try Self.decoder().decode(PendingJoinEntry.self, from: data)
        #expect(round.backendGroupID == "SplitGroup-NEW")
        #expect(round.inviteToken == "tok01")
        #expect(round.isBackendJoin)
    }
}
