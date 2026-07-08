//
//  Canonc1CodecTests.swift
//  YalaTests
//
//  Tests unitarios del codec canónico c1 (`Canonc1Codec`, incremento I8a): una familia por regla de §d.7,
//  los throws (no-finito, fuera de rango, key server-authored, año fuera de rango), determinismo (mismo
//  input → mismo output N veces) y coherencia manifest↔codec (cada columna `decimal_fixed` del
//  `capability_manifest.json` se encodea a su escala declarada). Pure-logic: sin `ModelContext`, sin
//  singletons → no requiere `@Suite(.serialized)` ni `makeTestContext`.
//

import Foundation
import Testing

@testable import Yala

@Suite("Canon c1 Codec")
struct Canonc1CodecTests {

    private func encode(_ key: String, _ value: CanonValue) throws -> String {
        try Canonc1Codec.encode([key: value])
    }

    // MARK: - Dinero (escala 4, HALF_EVEN desde binario exacto)

    @Test func money_padsToFourDecimals() throws {
        #expect(try encode("v", .money(19.99)) == #"{"v":"19.9900"}"#)
        #expect(try encode("v", .money(1)) == #"{"v":"1.0000"}"#)
        #expect(try encode("v", .money(100)) == #"{"v":"100.0000"}"#)
    }

    @Test func money_negativeZero_hasNoSign() throws {
        #expect(try encode("v", .money(-0.0)) == #"{"v":"0.0000"}"#)
        #expect(try encode("v", .money(0.0)) == #"{"v":"0.0000"}"#)
    }

    @Test func money_negative_keepsSign() throws {
        #expect(try encode("v", .money(-19.99)) == #"{"v":"-19.9900"}"#)
    }

    /// HALF_EVEN sobre el BINARIO exacto — no la falacia decimal-exacto. Estos son los ejemplos que la
    /// propia spec (§d.7:1569) trae calculados: `0.12345`(double)>½→arriba; `0.12355`(double)<½→abajo.
    @Test func money_halfEven_fromExactBinary() throws {
        #expect(try encode("v", .money(0.12345)) == #"{"v":"0.1235"}"#)  // tail > ½ → arriba
        #expect(try encode("v", .money(0.12355)) == #"{"v":"0.1235"}"#)  // tail < ½ → abajo (par)
        // 0.00005 como Double = 0.0000500…01 (> ½ del 4º decimal) → 0.0001, NO 0.0000 (que daría el
        // redondeo decimal-string de `.bankos`). Es el diferenciador clave binario-vs-decimal.
        #expect(try encode("v", .money(0.00005)) == #"{"v":"0.0001"}"#)
    }

    @Test func money_dirtyIEEE_roundsToClean() throws {
        // 19.989999999999998 es el MISMO Double que 19.99 → misma salida.
        #expect(try encode("v", .money(19.989999999999998)) == #"{"v":"19.9900"}"#)
    }

    @Test func money_largeIntegerInRange() throws {
        #expect(try encode("v", .money(99_999_999_999_999)) == #"{"v":"99999999999999.0000"}"#)
    }

    // MARK: - Tasa (escala 8)

    @Test func rate_padsToEightDecimals() throws {
        #expect(try encode("v", .rate(1.1)) == #"{"v":"1.10000000"}"#)
        #expect(try encode("v", .rate(0.5)) == #"{"v":"0.50000000"}"#)
        #expect(try encode("v", .rate(1.23456789)) == #"{"v":"1.23456789"}"#)
    }

    // MARK: - Fechas / local_day

    @Test func timestamp_isCanonicalIsoMillis() throws {
        let date = Date(timeIntervalSince1970: 1_609_459_200) // 2021-01-01T00:00:00Z
        #expect(try encode("v", .timestamp(date)) == #"{"v":"2021-01-01T00:00:00.000Z"}"#)
    }

    @Test func timestamp_floorsSubMillis() throws {
        let date = Date(timeIntervalSince1970: 1_609_459_200.123999) // µs se truncan por FLOOR
        #expect(try encode("v", .timestamp(date)) == #"{"v":"2021-01-01T00:00:00.123Z"}"#)
    }

    @Test func localDay_isFirstTenCharsOfCanonicalTimestamp() throws {
        let midnight = Date(timeIntervalSince1970: 1_783_296_000) // 2026-07-06T00:00:00Z
        #expect(try encode("v", .localDay(midnight)) == #"{"v":"2026-07-06"}"#)
        let endOfDay = Date(timeIntervalSince1970: 1_609_545_599.999) // 2021-01-01T23:59:59.999Z
        #expect(try encode("v", .localDay(endOfDay)) == #"{"v":"2021-01-01"}"#)
    }

    // MARK: - UUID / arrays

    @Test func uuid_isLowercased() throws {
        let id = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!
        #expect(try encode("v", .uuid(id)) == #"{"v":"a1b2c3d4-e5f6-7890-abcd-ef1234567890"}"#)
    }

    @Test func uuidArray_sortsByUTF8BytesAndDedupes() throws {
        let a = UUID(uuidString: "FF0000AA-0000-0000-0000-000000000000")!
        let b = UUID(uuidString: "00FF0000-0000-0000-0000-000000000000")!
        #expect(try encode("v", .uuidArray([a, b, b])) ==
                #"{"v":["00ff0000-0000-0000-0000-000000000000","ff0000aa-0000-0000-0000-000000000000"]}"#)
    }

    @Test func uuidArray_empty_omitsTheKey() throws {
        // Solo esta columna, vacía → objeto vacío (key omitida por completo).
        #expect(try Canonc1Codec.encode(["tag_refs": .uuidArray([])]) == "{}")
        // Con otra columna presente, solo se omite la vacía.
        #expect(try Canonc1Codec.encode(["tag_refs": .uuidArray([]), "note": .string("x")]) == #"{"note":"x"}"#)
    }

    // MARK: - Bool tri-estado / int / null

    @Test func bool_triState() throws {
        #expect(try encode("v", .bool(true)) == #"{"v":true}"#)
        #expect(try encode("v", .bool(false)) == #"{"v":false}"#)
        #expect(try encode("v", .bool(nil)) == #"{"v":null}"#)
    }

    @Test func int_isPlainJSONNumber() throws {
        #expect(try encode("v", .int(42)) == #"{"v":42}"#)
        #expect(try encode("v", .int(-7)) == #"{"v":-7}"#)
        #expect(try encode("v", .int(0)) == #"{"v":0}"#)
    }

    @Test func null_explicit_isEmitted() throws {
        #expect(try encode("v", .null) == #"{"v":null}"#)
    }

    @Test func absentKey_isNotEmitted_butNullIs() throws {
        // key presente con .null vs key totalmente ausente del mapa.
        #expect(try Canonc1Codec.encode(["note": .null]) == #"{"note":null}"#)
        #expect(try Canonc1Codec.encode([:]) == "{}")
    }

    // MARK: - Strings (escape mínimo RFC-8785)

    @Test func string_nonASCII_isRawUTF8() throws {
        #expect(try encode("v", .string("café")) == #"{"v":"café"}"#)
        #expect(try encode("v", .string("日本")) == #"{"v":"日本"}"#)
        #expect(try encode("v", .string("emoji🙂")) == #"{"v":"emoji🙂"}"#)
    }

    @Test func string_escapesQuoteAndBackslash_notSlash() throws {
        #expect(try encode("v", .string("a\"b\\c/d")) == #"{"v":"a\"b\\c/d"}"#)
    }

    @Test func string_c0Controls_shortFormsAndLowercaseHex() throws {
        // \b \t \n \f \r con formas cortas; el resto de C0 como \u00xx lowercase.
        #expect(try encode("v", .string("\u{08}\u{09}\u{0A}\u{0C}\u{0D}")) == #"{"v":"\b\t\n\f\r"}"#)
        #expect(try encode("v", .string("\u{00}\u{01}\u{1F}")) == #"{"v":"\u0000\u0001\u001f"}"#)
    }

    // MARK: - Blobs Data-JSON (recursivo)

    @Test func blob_sortsKeysByUTF8Bytes_andNestedNumbersAsRateStrings() throws {
        let blob = Data(#"{"usd":1.1,"pen":3.75,"café":0.5}"#.utf8)
        #expect(try encode("v", .dataJSON(blob)) ==
                #"{"v":{"café":"0.50000000","pen":"3.75000000","usd":"1.10000000"}}"#)
    }

    @Test func blob_recursive_preservesArrayOrder_boolAndNull() throws {
        let blob = Data(#"{"a":[1,2.5,"x"],"b":{"z":true,"y":null}}"#.utf8)
        #expect(try encode("v", .dataJSON(blob)) ==
                #"{"v":{"a":["1.00000000","2.50000000","x"],"b":{"y":null,"z":true}}}"#)
    }

    @Test func blob_empty_isEmptyObject() throws {
        #expect(try encode("v", .dataJSON(Data("{}".utf8))) == #"{"v":{}}"#)
    }

    @Test func blob_malformed_throws() throws {
        #expect(throws: Canonc1Error.self) {
            _ = try Canonc1Codec.encode(["v": .dataJSON(Data("{not json".utf8))])
        }
    }

    // MARK: - Orden de keys por bytes UTF-8

    @Test func objectKeys_orderedByUTF8Bytes() throws {
        let out = try Canonc1Codec.encode([
            "amount": .money(19.99),
            "note": .string("café"),
            "count": .int(5),
            "is_active": .bool(nil),
            "date": .timestamp(Date(timeIntervalSince1970: 1_609_459_200)),
            "tag_refs": .uuidArray([]),
        ])
        #expect(out == #"{"amount":"19.9900","count":5,"date":"2021-01-01T00:00:00.000Z","is_active":null,"note":"café"}"#)
    }

    // MARK: - Throws

    @Test func money_nonFinite_throws() throws {
        for bad in [Double.nan, .infinity, -.infinity] {
            #expect(throws: Canonc1Error.nonFiniteNumber) { _ = try self.encode("v", .money(bad)) }
        }
    }

    @Test func money_outOfRange_throws() throws {
        #expect(throws: Canonc1Error.self) { _ = try self.encode("v", .money(1e14)) }
        #expect(throws: Canonc1Error.self) { _ = try self.encode("v", .money(-1e14)) }
        // Justo por debajo del límite NO lanza.
        #expect(throws: Never.self) { _ = try self.encode("v", .money(9.999e13)) }
    }

    @Test func rate_outOfRange_throws() throws {
        #expect(throws: Canonc1Error.self) { _ = try self.encode("v", .rate(1e10)) }
        #expect(throws: Never.self) { _ = try self.encode("v", .rate(9.999e9)) }
    }

    @Test func serverAuthoredKey_throws() throws {
        for key in ["updated_at", "server_seq", "hlc", "deleted_hlc", "schema_version", "user_id"] {
            #expect(throws: Canonc1Error.self) { _ = try Canonc1Codec.encode([key: .string("x")]) }
        }
    }

    @Test func timestamp_yearOutOfRange_throws() throws {
        // Año 0 (gregoriano proléptico) cae fuera de 0001..9999.
        let year0 = Date(timeIntervalSince1970: -62_167_219_200) // 0000-01-01T00:00:00Z
        #expect(throws: CanonicalTimeError.self) { _ = try self.encode("v", .timestamp(year0)) }
    }

    // MARK: - Determinismo

    @Test func encode_isDeterministic() throws {
        let fields: [String: CanonValue] = [
            "amount": .money(1234.5678),
            "rate": .rate(1.23456789),
            "note": .string("hola 日本 café"),
            "when": .timestamp(Date(timeIntervalSince1970: 1_700_000_000.5)),
            "tags": .uuidArray([UUID(uuidString: "00FF0000-0000-0000-0000-000000000000")!]),
            "flag": .bool(nil),
        ]
        let first = try Canonc1Codec.encode(fields)
        for _ in 0..<50 { #expect(try Canonc1Codec.encode(fields) == first) }
    }

    // MARK: - Coherencia manifest ↔ codec (escala por-columna)

    @Test func manifest_decimalColumns_encodeToDeclaredScale() throws {
        struct Manifest: Decodable {
            struct Entity: Decodable { let columns: [String: Column] }
            struct Column: Decodable { let format: String; let scale: Int? }
            let entities: [String: Entity]
        }
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("capability_manifest.json"))
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)

        var checked = 0
        for (entityName, entity) in manifest.entities {
            for (columnName, column) in entity.columns where column.format == "decimal_fixed" {
                let scale = try #require(column.scale, "\(entityName).\(columnName) decimal_fixed sin scale")
                #expect(scale == Canonc1Codec.moneyScale || scale == Canonc1Codec.rateScale,
                        "\(entityName).\(columnName): scale \(scale) no es 4 ni 8")
                // El CanonValue correcto para la escala declarada debe producir EXACTAMENTE `scale` decimales.
                let value: CanonValue = (scale == Canonc1Codec.rateScale) ? .rate(1.5) : .money(1.5)
                let out = try Canonc1Codec.encode([columnName: value])
                let decimals = try #require(out.split(separator: ".").last?.dropLast(2).count,
                                            "\(entityName).\(columnName) sin fracción")
                // out = {"col":"1.5000"} → tras el punto quedan `scale` dígitos + `"}`; dropLast(2) quita `"}`.
                #expect(decimals == scale, "\(entityName).\(columnName): esperaba \(scale) decimales, dio \(decimals)")
                checked += 1
            }
        }
        #expect(checked >= 8, "esperaba ≥8 columnas decimal_fixed en el manifest, revisó \(checked)")
    }
}
