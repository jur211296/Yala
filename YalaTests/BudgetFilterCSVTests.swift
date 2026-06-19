//
//  BudgetFilterCSVTests.swift
//  YalaTests
//
//  Pure-logic tests for Budget+CSVMirror helpers (decodeCSV / encodeCSV / setters).
//  No ModelContext — tests run in isolation without SwiftData storage.
//

import Foundation
import Testing

@testable import Yala

@Suite("Budget CSV Mirror")
struct BudgetFilterCSVTests {

    // MARK: - decodeCSV

    @Test func decodeCSV_nil_returnsNil() {
        #expect(CSVMirrorCodec.decode(nil) == nil)
    }

    @Test func decodeCSV_empty_returnsNil() {
        #expect(CSVMirrorCodec.decode("") == nil)
    }

    @Test func decodeCSV_singleUUID_returnsSetOfOne() {
        let uuid = UUID()
        let result = CSVMirrorCodec.decode(uuid.uuidString)
        #expect(result == Set([uuid]))
    }

    @Test func decodeCSV_multipleUUIDs_returnsAll() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        let csv = [a, b, c].map(\.uuidString).joined(separator: ",")
        let result = CSVMirrorCodec.decode(csv)
        #expect(result == Set([a, b, c]))
    }

    @Test func decodeCSV_invalidUUIDs_areDropped() {
        let valid = UUID()
        let csv = "\(valid.uuidString),not-a-uuid,also-invalid"
        let result = CSVMirrorCodec.decode(csv)
        #expect(result == Set([valid]))
    }

    @Test func decodeCSV_allInvalidUUIDs_returnsNil() {
        #expect(CSVMirrorCodec.decode("foo,bar,baz") == nil)
    }

    @Test func decodeCSV_handlesWhitespace() {
        let a = UUID()
        let b = UUID()
        let csv = " \(a.uuidString) , \(b.uuidString) "
        let result = CSVMirrorCodec.decode(csv)
        #expect(result == Set([a, b]))
    }

    @Test func decodeCSV_duplicates_areCollapsed() {
        let a = UUID()
        let csv = "\(a.uuidString),\(a.uuidString)"
        let result = CSVMirrorCodec.decode(csv)
        #expect(result == Set([a]))
    }

    // MARK: - encodeCSV

    @Test func encodeCSV_empty_returnsNil() {
        #expect(CSVMirrorCodec.encode([UUID]()) == nil)
    }

    @Test func encodeCSV_singleUUID_returnsString() {
        let uuid = UUID()
        let result = CSVMirrorCodec.encode([uuid])
        #expect(result == uuid.uuidString)
    }

    @Test func encodeCSV_isSortedDeterministically() {
        let a = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let b = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let c = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        // Pasar en orden distinto, esperar salida ordenada
        let result = CSVMirrorCodec.encode([c, a, b])
        #expect(result == "\(a.uuidString),\(b.uuidString),\(c.uuidString)")
    }

    @Test func encodeCSV_dedupes() {
        let a = UUID()
        let result = CSVMirrorCodec.encode([a, a, a])
        #expect(result == a.uuidString)
    }

    // MARK: - Roundtrip

    @Test func roundtrip_encode_then_decode_preservesSet() {
        let original: Set<UUID> = [UUID(), UUID(), UUID()]
        let csv = CSVMirrorCodec.encode(original)
        let decoded = CSVMirrorCodec.decode(csv)
        #expect(decoded == original)
    }

    @Test func roundtrip_emptyArray_encodesNil_decodesNil() {
        let csv = CSVMirrorCodec.encode([UUID]())
        #expect(csv == nil)
        #expect(CSVMirrorCodec.decode(csv) == nil)
    }
}
