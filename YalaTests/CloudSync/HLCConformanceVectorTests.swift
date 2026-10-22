//
//  HLCConformanceVectorTests.swift
//  YalaTests
//
//  Corre la implementación de HLC/CanonicalTime contra los vectores HAND-AUTHORED de
//  `hlc_conformance_vectors.json` (raíz del repo). Los esperados se calcularon a mano desde la spec,
//  NO ejecutando la impl — este archivo es el oráculo externo. Carga el JSON vía `#filePath` (mismo
//  patrón que LocalizationParityTests / CloudKitGroupsSchemaParityTests: el runner no empaqueta el
//  JSON como resource).
//

import Foundation
import Testing

@testable import Yala

@Suite("HLC Conformance Vectors")
struct HLCConformanceVectorTests {

    // MARK: - Carga del JSON

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static var vectorsURL: URL {
        repoRoot.appendingPathComponent("hlc_conformance_vectors.json")
    }

    private static func loadVectors() throws -> ConformanceVectors {
        let data = try Data(contentsOf: vectorsURL)
        return try JSONDecoder().decode(ConformanceVectors.self, from: data)
    }

    // MARK: - DTOs

    private struct ConformanceVectors: Decodable {
        let canonicalIsoMillis: [CanonicalCase]
        let canonicalIsoMillisErrors: [CanonicalErrorCase]
        let roundTrip: [RoundTripCase]
        let parseReject: [ParseRejectCase]
        let compareLess: [CompareCase]
        let send: [SendCase]
        let sendErrors: [SendErrorCase]
        let receive: [ReceiveCase]
        let receiveErrors: [ReceiveErrorCase]
    }

    private struct CanonicalCase: Decodable { let description: String; let unixMs: Int64; let expected: String }
    private struct CanonicalErrorCase: Decodable { let description: String; let unixMs: Int64; let expectedError: String }
    private struct RoundTripCase: Decodable { let description: String; let hlc: String }
    private struct ParseRejectCase: Decodable { let description: String; let hlc: String }
    private struct CompareCase: Decodable { let description: String; let a: String; let b: String }
    private struct SendCase: Decodable { let description: String; let nodeID: String; let latest: String?; let nowUnixMs: Int64; let expected: String }
    private struct SendErrorCase: Decodable { let description: String; let nodeID: String; let latest: String?; let nowUnixMs: Int64; let expectedError: String }
    private struct ReceiveCase: Decodable { let description: String; let nodeID: String; let latest: String?; let remote: String; let nowUnixMs: Int64; let expected: String }
    private struct ReceiveErrorCase: Decodable { let description: String; let nodeID: String; let latest: String?; let remote: String; let nowUnixMs: Int64; let expectedError: String }

    private func date(_ unixMs: Int64) -> Date { Date(timeIntervalSince1970: Double(unixMs) / 1_000) }

    private func clock(nodeID: String, latest: String?) throws -> HLCClock {
        HLCClock(nodeID: try NodeID(validating: nodeID),
                 latest: try latest.map { try HLC.parse($0) })
    }

    /// Verifica que un error corresponda a la etiqueta esperada del JSON.
    private func assertMatches(_ error: any Error, expected: String, _ description: String) {
        switch expected {
        case "yearOutOfRange":
            if case CanonicalTimeError.yearOutOfRange = error { return }
        case "counterOverflow":
            if case ClockDriftError.counterOverflow = error { return }
        case "driftExceeded":
            if case ClockDriftError.driftExceeded = error { return }
        default:
            break
        }
        Issue.record("[\(description)] error \(error) no coincide con esperado '\(expected)'")
    }

    // MARK: - canonicalIsoMillis

    @Test func canonicalIsoMillis_matchesVectors() throws {
        let vectors = try Self.loadVectors()
        #expect(!vectors.canonicalIsoMillis.isEmpty)
        for v in vectors.canonicalIsoMillis {
            let got = try CanonicalTime.canonicalIsoMillis(v.unixMs)
            #expect(got == v.expected, "[\(v.description)] got \(got)")
            // Parse inverso estricto debe devolver el ms original.
            #expect(try CanonicalTime.parseCanonicalIsoMillis(v.expected) == v.unixMs, "[\(v.description)] parse inverso")
        }
    }

    @Test func canonicalIsoMillis_errorsMatchVectors() throws {
        let vectors = try Self.loadVectors()
        #expect(!vectors.canonicalIsoMillisErrors.isEmpty)
        for v in vectors.canonicalIsoMillisErrors {
            do {
                let got = try CanonicalTime.canonicalIsoMillis(v.unixMs)
                Issue.record("[\(v.description)] se esperaba error pero devolvió \(got)")
            } catch {
                assertMatches(error, expected: v.expectedError, v.description)
            }
        }
    }

    // MARK: - round-trip

    @Test func roundTrip_matchesVectors() throws {
        let vectors = try Self.loadVectors()
        #expect(!vectors.roundTrip.isEmpty)
        for v in vectors.roundTrip {
            let hlc = try HLC.parse(v.hlc)
            #expect(hlc.description == v.hlc, "[\(v.description)]")
            // También round-trip vía Codable.
            let data = try JSONEncoder().encode(hlc)
            let decoded = try JSONDecoder().decode(HLC.self, from: data)
            #expect(decoded == hlc, "[\(v.description)] Codable")
        }
    }

    // MARK: - parse reject

    @Test func parseReject_matchesVectors() throws {
        let vectors = try Self.loadVectors()
        #expect(!vectors.parseReject.isEmpty)
        for v in vectors.parseReject {
            #expect(throws: (any Error).self, "[\(v.description)] debía rechazar: \(v.hlc)") {
                _ = try HLC.parse(v.hlc)
            }
        }
    }

    // MARK: - comparación

    @Test func compareLess_matchesVectors() throws {
        let vectors = try Self.loadVectors()
        #expect(!vectors.compareLess.isEmpty)
        for v in vectors.compareLess {
            let a = try HLC.parse(v.a)
            let b = try HLC.parse(v.b)
            #expect(a < b, "[\(v.description)] a debía ser < b")
            #expect(!(b < a), "[\(v.description)] antisimetría")
            #expect(a != b, "[\(v.description)] distintos")
        }
    }

    // MARK: - send

    @Test func send_matchesVectors() throws {
        let vectors = try Self.loadVectors()
        #expect(!vectors.send.isEmpty)
        for v in vectors.send {
            var c = try clock(nodeID: v.nodeID, latest: v.latest)
            let got = try c.send(now: date(v.nowUnixMs))
            #expect(got.description == v.expected, "[\(v.description)] got \(got.description)")
            #expect(c.latest == got, "[\(v.description)] latest debe actualizarse al resultado")
        }
    }

    @Test func sendErrors_matchVectors() throws {
        let vectors = try Self.loadVectors()
        #expect(!vectors.sendErrors.isEmpty)
        for v in vectors.sendErrors {
            var c = try clock(nodeID: v.nodeID, latest: v.latest)
            do {
                let got = try c.send(now: date(v.nowUnixMs))
                Issue.record("[\(v.description)] se esperaba error pero devolvió \(got.description)")
            } catch {
                assertMatches(error, expected: v.expectedError, v.description)
            }
        }
    }

    // MARK: - receive

    @Test func receive_matchesVectors() throws {
        let vectors = try Self.loadVectors()
        #expect(!vectors.receive.isEmpty)
        for v in vectors.receive {
            var c = try clock(nodeID: v.nodeID, latest: v.latest)
            let remote = try HLC.parse(v.remote)
            let got = try c.receive(remote: remote, now: date(v.nowUnixMs))
            #expect(got.description == v.expected, "[\(v.description)] got \(got.description)")
            #expect(c.latest == got, "[\(v.description)] latest debe actualizarse al resultado")
        }
    }

    @Test func receiveErrors_matchVectors() throws {
        let vectors = try Self.loadVectors()
        #expect(!vectors.receiveErrors.isEmpty)
        for v in vectors.receiveErrors {
            var c = try clock(nodeID: v.nodeID, latest: v.latest)
            let remote = try HLC.parse(v.remote)
            do {
                let got = try c.receive(remote: remote, now: date(v.nowUnixMs))
                Issue.record("[\(v.description)] se esperaba error pero devolvió \(got.description)")
            } catch {
                assertMatches(error, expected: v.expectedError, v.description)
            }
        }
    }
}
