//
//  PrefValueCodecTests.swift
//  YalaTests / CloudSync
//
//  Round-trip por tipo del codec TEXT ↔ PrefValue (I13). Una asimetría encode/decode corrompería prefs
//  cross-device en silencio → estos tests son el guard.
//

import Foundation
import Testing

@testable import Yala

@Suite("PrefValueCodec · I13")
struct PrefValueCodecTests {

    // MARK: - Encode

    @Test func encode_string_verbatim() {
        #expect(PrefValueCodec.encode(.string("PEN")) == "PEN")
        #expect(PrefValueCodec.encode(.string("")) == "")
        #expect(PrefValueCodec.encode(.string("es-419")) == "es-419")
    }

    @Test func encode_bool_lowercaseLiteral() {
        #expect(PrefValueCodec.encode(.bool(true)) == "true")
        #expect(PrefValueCodec.encode(.bool(false)) == "false")
    }

    @Test func encode_int_decimal() {
        #expect(PrefValueCodec.encode(.int(0)) == "0")
        #expect(PrefValueCodec.encode(.int(2)) == "2")
        #expect(PrefValueCodec.encode(.int(-5)) == "-5")
        #expect(PrefValueCodec.encode(.int(1_000_000)) == "1000000")
    }

    // MARK: - Round-trip

    @Test func roundTrip_string() {
        for s in ["PEN", "", "es-419", "  spaces  ", "emoji 🐧", "a\nb"] {
            let text = PrefValueCodec.encode(.string(s))
            #expect(PrefValueCodec.decode(text, as: .string) == .string(s))
        }
    }

    @Test func roundTrip_bool() {
        for b in [true, false] {
            let text = PrefValueCodec.encode(.bool(b))
            #expect(PrefValueCodec.decode(text, as: .bool) == .bool(b))
        }
    }

    @Test func roundTrip_int() {
        for i in [0, 1, 2, -1, -42, Int.max, Int.min, 999_999_999] {
            let text = PrefValueCodec.encode(.int(i))
            #expect(PrefValueCodec.decode(text, as: .int) == .int(i))
        }
    }

    // MARK: - Decode tolerancia

    @Test func decode_bool_onlyExactTrueIsTrue() {
        #expect(PrefValueCodec.decode("true", as: .bool) == .bool(true))
        #expect(PrefValueCodec.decode("false", as: .bool) == .bool(false))
        #expect(PrefValueCodec.decode("TRUE", as: .bool) == .bool(false))  // no exacto → false
        #expect(PrefValueCodec.decode("1", as: .bool) == .bool(false))
        #expect(PrefValueCodec.decode("", as: .bool) == .bool(false))
    }

    @Test func decode_int_unparseableIsZero() {
        #expect(PrefValueCodec.decode("abc", as: .int) == .int(0))
        #expect(PrefValueCodec.decode("", as: .int) == .int(0))
        #expect(PrefValueCodec.decode("3.5", as: .int) == .int(0))
        #expect(PrefValueCodec.decode("42", as: .int) == .int(42))
    }
}
