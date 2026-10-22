//
//  WireValueDecoderTests.swift
//  YalaTests / CloudSync
//
//  Decoder puro del valor de wire del pull (I8f-1): `WireValue` (bool vs número), accessores tipados
//  (money string/número, uuid[], text[], jsonb), y el parse inverso ISO→ms (D-2c) — round-trip contra
//  `CanonicalTime` + variantes de PostgREST (`+00:00`, microsegundos).
//

import Foundation
import Testing

@testable import Yala

@Suite("WireValueDecoder · decoder + ISO inverso")
struct WireValueDecoderTests {

    private func wire(_ json: String) throws -> WireValue {
        try JSONDecoder().decode(WireValue.self, from: Data(json.utf8))
    }

    // MARK: - bool vs número (la trampa clásica de JSONSerialization)

    @Test func decodes_bool_and_number_distinctly() throws {
        #expect(try wire("true") == .bool(true))
        #expect(try wire("false") == .bool(false))
        #expect(try wire("1") == .number(1))
        #expect(try wire("0") == .number(0))
        #expect(try wire("12.5") == .number(12.5))
        #expect(try wire("\"hola\"") == .string("hola"))
        #expect(try wire("null") == .null)
    }

    @Test func decodes_nested_object_and_array() throws {
        let v = try wire(#"{"USD":1.0,"PEN":["a"]}"#)
        guard case .object(let o) = v else { Issue.record("no object"); return }
        #expect(o["USD"] == .number(1.0))
        #expect(o["PEN"] == .array([.string("a")]))
    }

    // MARK: - money/rate: STRING decimal Y número JSON

    @Test func double_acceptsStringAndNumber() {
        #expect(WireValueDecoder.double(.string("12.5000")) == 12.5)
        #expect(WireValueDecoder.double(.number(12.5)) == 12.5)
        #expect(WireValueDecoder.double(.string("3.62000000")) == 3.62)
        #expect(WireValueDecoder.double(.null) == nil)
        #expect(WireValueDecoder.double(.bool(true)) == nil)
    }

    // MARK: - money/rate: lo NO FINITO no entra (ticket `wire-decoder-accepts-non-finite-money`)

    /// Las formas en que un no finito llega por el wire. `"NaN"` es la de Postgres para un `NUMERIC`; el resto, las que
    /// `Double(String)` acepta (medido: cualquier caja, `infinity`, y un decimal que desborda a `inf`).
    static let nonFiniteWireStrings = [
        "nan", "NaN", "NAN", "inf", "-inf", "+inf", "Inf", "INF", "Infinity", "-Infinity", "infinity",
        "1e400", "-1e400", "snan", "nan(0x1)",
    ]

    @Test(arguments: nonFiniteWireStrings)
    func double_rejectsNonFinite(_ raw: String) {
        // Premisa del caso: `Double(String)` SÍ lo convierte en un no finito. Sin ella el caso pasaría sin medir nada.
        let parsed = Double(raw)
        #expect(parsed.map { !$0.isFinite } == true, "premisa: \(raw) no da un no finito")
        #expect(WireValueDecoder.double(.string(raw)) == nil)
        #expect(WireValueDecoder.isNonFiniteNumber(.string(raw)))
    }

    @Test func double_rejectsNonFiniteNumberCase() {
        // `JSONDecoder` no produce `.number` no finito, pero el `WireValue` también se construye a mano.
        for d in [Double.nan, .infinity, -.infinity] {
            #expect(WireValueDecoder.double(.number(d)) == nil)
            #expect(WireValueDecoder.isNonFiniteNumber(.number(d)))
        }
    }

    @Test func isNonFiniteNumber_isFalseForEverythingElse() {
        for v: WireValue in [.string("12.5000"), .number(12.5), .string("0"), .string("-0.0000"), .string("1e-400"),
                             .string("abc"), .string(""), .string(" nan"), .null, .bool(true), .array([]), .object([:])] {
            #expect(!WireValueDecoder.isNonFiniteNumber(v), "\(v)")
        }
        // El subnormal sí es finito y entra.
        #expect(WireValueDecoder.double(.string("4.9e-324")) == 5e-324)
    }

    /// Un JSON con un número no finito NO llega a ser `WireValue`: `JSONDecoder` lo rechaza. Es lo que hace que el
    /// agujero sea solo la rama `.string` (medido, y fijado aquí por si un decoder futuro lo tolera).
    @Test func jsonNumberNonFinite_neverReachesTheDecoder() {
        #expect(throws: (any Error).self) { _ = try self.wire("1e400") }
        #expect(throws: (any Error).self) { _ = try self.wire("NaN") }
    }

    // MARK: - Las dos direcciones coinciden: lo que el emisor rechaza, el decoder también

    /// Ida: `Canonc1Codec` rechaza al EMITIR cada no finito. Vuelta: el decoder lo rechaza al RECIBIR. Si un día
    /// alguien relaja una de las dos, este caso las separa.
    @Test(arguments: nonFiniteWireStrings)
    func emitterAndDecoder_rejectTheSameNonFinite(_ raw: String) throws {
        let value = try #require(Double(raw))
        for scale in [Canonc1Codec.moneyScale, Canonc1Codec.rateScale] {
            #expect(throws: Canonc1Error.nonFiniteNumber) { _ = try Canonc1Codec.decimalFixed(value, scale: scale) }
        }
        #expect(WireValueDecoder.double(.string(raw)) == nil)
    }

    /// Y lo que el emisor SÍ emite, el decoder lo devuelve igual: el arreglo no se come valores buenos.
    @Test func whatTheEmitterEmits_theDecoderAccepts() throws {
        let samples: [(Double, Int)] = [(19.99, 4), (-0.0, 4), (0.00005, 4), (99_999_999_999_999.98, 4), (-12.5, 4),
                                        (3.62, 8), (0.00000001, 8), (9_999_999_999.99, 8)]
        for (value, scale) in samples {
            let emitted = try Canonc1Codec.decimalFixed(value, scale: scale)
            let back = try #require(WireValueDecoder.double(.string(emitted)), "\(emitted)")
            #expect(try Canonc1Codec.decimalFixed(back, scale: scale) == emitted)
        }
    }

    // MARK: - int: un no finito o fuera de rango no ABORTA el proceso

    @Test func int_nonFiniteOrOutOfRange_isNil_notACrash() {
        // Con el `Int(d)` de antes, cualquiera de estos abortaba el proceso en el apply.
        for raw in ["nan", "NaN", "inf", "-Infinity", "1e400", "1e300", "-9.3e18"] {
            #expect(WireValueDecoder.int(.string(raw)) == nil, "\(raw)")
        }
        for d in [Double.nan, .infinity, 1e300, -1e300] {
            #expect(WireValueDecoder.int(.number(d)) == nil, "\(d)")
        }
        // Lo de siempre sigue igual: entero, truncado hacia cero, string entero y string decimal.
        #expect(WireValueDecoder.int(.number(3)) == 3)
        #expect(WireValueDecoder.int(.number(3.9)) == 3)
        #expect(WireValueDecoder.int(.number(-3.9)) == -3)
        #expect(WireValueDecoder.int(.string("42")) == 42)
        #expect(WireValueDecoder.int(.string("42.7")) == 42)
        #expect(WireValueDecoder.int(.null) == nil)
    }

    // MARK: - uuid[] : array y null = "sin filtro"

    @Test func uuidArray_nullVsArray() {
        let a = UUID(); let b = UUID()
        #expect(WireValueDecoder.uuidArray(.null) == nil)
        #expect(WireValueDecoder.uuidArray(.array([])) == [])
        let parsed = WireValueDecoder.uuidArray(.array([.string(a.uuidString), .string(b.uuidString)]))
        #expect(Set(parsed ?? []) == [a, b])
        // Tokens malformados se descartan.
        #expect(WireValueDecoder.uuidArray(.array([.string("no-uuid"), .string(a.uuidString)])) == [a])
    }

    @Test func stringArray_decodesTextArray() {
        #expect(WireValueDecoder.stringArray(.array([.string("account"), .string("amount")])) == ["account", "amount"])
        #expect(WireValueDecoder.stringArray(.null) == nil)
    }

    @Test func jsonData_reserializesObjectSorted() throws {
        let v = try wire(#"{"b":2,"a":1}"#)
        let data = try #require(WireValueDecoder.jsonData(v))
        // sortedKeys → "a" antes que "b".
        #expect(String(decoding: data, as: UTF8.self) == #"{"a":1,"b":2}"#)
    }

    // MARK: - ISO → ms : round-trip contra CanonicalTime

    @Test func millisFromISO_roundTrips_canonicalVectors() {
        let vectors: [Int64] = [
            0,                         // epoch
            1_700_000_000_000,         // 2023-11-14T22:13:20.000Z
            1_700_000_000_123,         // con millis
            1_500_000_000_500,
            32_503_680_000_000,        // año 3000 (dentro de 0001..9999)
        ]
        for ms in vectors {
            let iso = CanonicalTime.canonicalIsoMillisUnchecked(ms)
            #expect(WireValueDecoder.millisFromISO(iso) == ms, "round-trip falló para \(ms) (\(iso))")
        }
    }

    // MARK: - ISO → ms : variantes de PostgREST

    @Test func millisFromISO_postgrestVariants() {
        // `+00:00` en vez de `Z` → mismo instante que `Z`.
        let zulu = WireValueDecoder.millisFromISO("2023-11-14T22:13:20.000Z")
        #expect(WireValueDecoder.millisFromISO("2023-11-14T22:13:20+00:00") == zulu)
        #expect(WireValueDecoder.millisFromISO("2023-11-14T22:13:20.000+00:00") == zulu)

        // Microsegundos → FLOOR sub-ms (toma los 3 primeros dígitos).
        #expect(WireValueDecoder.millisFromISO("2023-11-14T22:13:20.123456+00:00")
                == (zulu.map { $0 + 123 }))
        #expect(WireValueDecoder.millisFromISO("2023-11-14T22:13:20.9+00:00")
                == (zulu.map { $0 + 900 }))

        // Offset con signo: 05:00 antes de UTC = mismo instante que 10:00Z.
        #expect(WireValueDecoder.millisFromISO("2023-11-14T17:13:20-05:00") == zulu)
        // Offset sin `:` (±HHMM) y espacio como separador.
        #expect(WireValueDecoder.millisFromISO("2023-11-14T17:13:20-0500") == zulu)
        #expect(WireValueDecoder.millisFromISO("2023-11-14 22:13:20+00:00") == zulu)
    }

    @Test func millisFromISO_rejectsMalformed() {
        #expect(WireValueDecoder.millisFromISO("") == nil)
        #expect(WireValueDecoder.millisFromISO("2023-11-14") == nil)          // sin hora
        #expect(WireValueDecoder.millisFromISO("2023/11/14T22:13:20Z") == nil) // separador inválido
        #expect(WireValueDecoder.millisFromISO("2023-13-14T22:13:20Z") == nil) // mes 13
    }

    // MARK: - date accessor

    @Test func date_accessor_parsesTimestamptz() {
        let d = WireValueDecoder.date(.string("2023-11-14T22:13:20.000Z"))
        #expect(d == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(WireValueDecoder.date(.null) == nil)
    }
}
