//
//  HLCTests.swift
//  YalaTests
//
//  Tests de lógica pura del HLC y del formato canónico c1 (Modo Nube, incremento I1). Sin store,
//  sin makeTestContext: todo es aritmética + valores. `now:` se inyecta siempre como `Date`
//  determinista construida desde ms Unix — nunca `Date()`/`Calendar.current`.
//

import Foundation
import Testing

@testable import Yala

@Suite("HLC")
struct HLCTests {

    // MARK: - Helpers

    private static let anchorMs: Int64 = 1_609_459_200_000  // 2021-01-01T00:00:00.000Z

    private func date(_ unixMs: Int64) -> Date {
        Date(timeIntervalSince1970: Double(unixMs) / 1_000)
    }

    private func node(_ hex: String) throws -> NodeID {
        try NodeID(validating: hex)
    }

    private let nodeA = "00000000000000aa"
    private let nodeB = "00000000000000bb"

    // MARK: - CanonicalTime: epoch e invariantes básicos

    @Test func epochUnix_isZeroMillis() throws {
        #expect(try CanonicalTime.canonicalIsoMillis(0) == "1970-01-01T00:00:00.000Z")
        #expect(try CanonicalTime.parseCanonicalIsoMillis("1970-01-01T00:00:00.000Z") == 0)
    }

    @Test func anchor_roundTrips() throws {
        let iso = try CanonicalTime.canonicalIsoMillis(Self.anchorMs)
        #expect(iso == "2021-01-01T00:00:00.000Z")
        #expect(try CanonicalTime.parseCanonicalIsoMillis(iso) == Self.anchorMs)
    }

    @Test func pre1970_floorsTowardNegativeInfinity() throws {
        // -1 ms cae en 1969-12-31T23:59:59.999Z (floorDiv/floorMod, no truncado hacia cero).
        #expect(try CanonicalTime.canonicalIsoMillis(-1) == "1969-12-31T23:59:59.999Z")
        #expect(try CanonicalTime.parseCanonicalIsoMillis("1969-12-31T23:59:59.999Z") == -1)
        // -1000 ms = exactamente un segundo antes del epoch.
        #expect(try CanonicalTime.canonicalIsoMillis(-1000) == "1969-12-31T23:59:59.000Z")
    }

    @Test func floorDiv_and_floorMod_negatives() {
        #expect(CanonicalTime.floorDiv(-1, 1000) == -1)
        #expect(CanonicalTime.floorMod(-1, 1000) == 999)
        #expect(CanonicalTime.floorDiv(-1000, 1000) == -1)
        #expect(CanonicalTime.floorMod(-1000, 1000) == 0)
        #expect(CanonicalTime.floorDiv(2500, 1000) == 2)
        #expect(CanonicalTime.floorMod(2500, 1000) == 500)
    }

    // MARK: - Bordes de año

    @Test func year0001_lowerBound_ok() throws {
        let ms: Int64 = -62_135_596_800_000
        #expect(try CanonicalTime.canonicalIsoMillis(ms) == "0001-01-01T00:00:00.000Z")
        #expect(try CanonicalTime.parseCanonicalIsoMillis("0001-01-01T00:00:00.000Z") == ms)
    }

    @Test func year9999_upperBound_ok() throws {
        let ms: Int64 = 253_402_300_799_999
        #expect(try CanonicalTime.canonicalIsoMillis(ms) == "9999-12-31T23:59:59.999Z")
        #expect(try CanonicalTime.parseCanonicalIsoMillis("9999-12-31T23:59:59.999Z") == ms)
    }

    @Test func year0000_belowRange_throws() {
        #expect(throws: CanonicalTimeError.self) {
            _ = try CanonicalTime.canonicalIsoMillis(-62_135_683_200_000)  // 0000-12-31
        }
    }

    @Test func year10000_aboveRange_throws() {
        #expect(throws: CanonicalTimeError.self) {
            _ = try CanonicalTime.canonicalIsoMillis(253_402_300_800_000)  // 10000-01-01
        }
    }

    // MARK: - FLOOR de reloj de pared → ms

    @Test func physicalMillis_floorsFraction() {
        // 0.9995 s → 999.5 ms → FLOOR → 999 (nunca redondea hacia arriba).
        #expect(CanonicalTime.physicalMillis(from: Date(timeIntervalSince1970: 0.9995)) == 999)
        #expect(CanonicalTime.physicalMillis(from: Date(timeIntervalSince1970: 1.0)) == 1000)
        // Pre-1970 fraccional también FLOOR hacia -∞.
        #expect(CanonicalTime.physicalMillis(from: Date(timeIntervalSince1970: -0.0005)) == -1)
    }

    // MARK: - Parsing estricto (rechazos)

    @Test func parse_rejectsUppercaseHex() {
        #expect(throws: (any Error).self) {
            _ = try HLC.parse("2021-01-01T00:00:00.000Z-0000-00000000000000AA")
        }
        #expect(throws: (any Error).self) {
            _ = try HLC.parse("2021-01-01T00:00:00.000Z-000A-00000000000000aa")
        }
    }

    @Test func parse_rejectsWrongLength() {
        #expect(throws: (any Error).self) {  // 45
            _ = try HLC.parse("2021-01-01T00:00:00.000Z-0000-00000000000000a")
        }
        #expect(throws: (any Error).self) {  // 47
            _ = try HLC.parse("2021-01-01T00:00:00.000Z-0000-00000000000000aaa")
        }
    }

    @Test func parse_rejectsMisplacedDash() {
        #expect(throws: (any Error).self) {
            _ = try HLC.parse("2021-01-01T00:00:00.000Z00000-00000000000000aa")
        }
    }

    @Test func parse_rejectsLowercaseZ() {
        #expect(throws: (any Error).self) {
            _ = try HLC.parse("2021-01-01T00:00:00.000z-0000-00000000000000aa")
        }
    }

    @Test func parse_rejectsInvalidHexChar() {
        #expect(throws: (any Error).self) {
            _ = try HLC.parse("2021-01-01T00:00:00.000Z-0000-0000000000000g0a")
        }
    }

    // MARK: - Round-trip string ↔ struct

    @Test func hlc_roundTripsExactly() throws {
        let strings = [
            "2021-01-01T00:00:00.000Z-0000-00000000000000aa",
            "1970-01-01T00:00:00.000Z-0001-ffffffffffffffff",
            "1969-12-31T23:59:59.999Z-abcd-0123456789abcdef",
            "0001-01-01T00:00:00.000Z-ffff-fedcba9876543210",
            "9999-12-31T23:59:59.999Z-0f0f-00000000000000bb",
        ]
        for s in strings {
            let hlc = try HLC.parse(s)
            #expect(hlc.description == s, "round-trip debe ser idéntico: \(s)")
        }
    }

    @Test func invariant_prefix24_equalsCanonicalTimestamp() throws {
        let hlc = try HLC(physicalMs: Self.anchorMs, counter: 0x1a2b, nodeID: node(nodeA))
        #expect(hlc.canonicalTimestampPrefix == CanonicalTime.canonicalIsoMillisUnchecked(hlc.physicalMs))
        #expect(String(hlc.description.prefix(24)) == "2021-01-01T00:00:00.000Z")
    }

    // MARK: - NodeID

    @Test func nodeID_generate_is16LowercaseHex() throws {
        let id = NodeID.generate()
        #expect(id.value.count == 16)
        // Debe re-validar sin lanzar.
        #expect(throws: Never.self) { _ = try NodeID(validating: id.value) }
    }

    @Test func nodeID_rejectsBadInput() {
        #expect(throws: (any Error).self) { _ = try NodeID(validating: "00000000000000AA") }  // upper
        #expect(throws: (any Error).self) { _ = try NodeID(validating: "abc") }                 // corto
        #expect(throws: (any Error).self) { _ = try NodeID(validating: "0000000000000g0a") }    // no-hex
    }

    // MARK: - Comparator estructurado

    @Test func compare_physicalMsDominates() throws {
        let a = try HLC(physicalMs: Self.anchorMs, counter: 0x0009, nodeID: node("ffffffffffffffff"))
        let b = try HLC(physicalMs: Self.anchorMs + 1000, counter: 0, nodeID: node(nodeA))
        #expect(a < b)
    }

    @Test func compare_counterBreaksTieBeforeNode() throws {
        let a = try HLC(physicalMs: Self.anchorMs, counter: 1, nodeID: node("ffffffffffffffff"))
        let b = try HLC(physicalMs: Self.anchorMs, counter: 2, nodeID: node(nodeA))
        #expect(a < b)
    }

    @Test func compare_nodeIDBreaksExactTie() throws {
        let a = try HLC(physicalMs: Self.anchorMs, counter: 3, nodeID: node(nodeA))
        let b = try HLC(physicalMs: Self.anchorMs, counter: 3, nodeID: node(nodeB))
        #expect(a < b)
        #expect(!(b < a))
        #expect(a != b)
    }

    /// El orden por STRING completa coincide con el orden ESTRUCTURADO para HLCs canónicos válidos
    /// (todos los campos son ancho fijo + lowercase monótonos). Generamos un set determinista
    /// aritméticamente (LCG con semilla fija, sin `random`) y verificamos la paridad.
    @Test func structuredOrder_matchesStringOrder_onDeterministicSet() throws {
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func nextByte() -> UInt8 {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return UInt8((seed >> 33) & 0xFF)
        }
        let nodes = ["00000000000000aa", "00000000000000bb", "0123456789abcdef", "ffffffffffffffff"]

        var hlcs: [HLC] = []
        for _ in 0..<200 {
            // Offset SIGNED centrado en el epoch (base 0): -128..127 h → cruza 1970, produciendo
            // physicalMs NEGATIVOS (pre-1970) y positivos en el mismo set. La paridad string↔estructura
            // debe sostenerse también con años pre-1970 (prefijo YYYY-... sigue siendo lexicográfico).
            let signedOffset = (Int64(nextByte()) - 128) * 3_600_000  // ±~5.3 días alrededor del epoch
            let counter = UInt16(nextByte()) &* 3   // spread de contadores
            let nodeIdx = Int(nextByte()) % nodes.count
            hlcs.append(try HLC(physicalMs: signedOffset,
                                counter: counter,
                                nodeID: node(nodes[nodeIdx])))
        }
        #expect(hlcs.contains { $0.physicalMs < 0 }, "el set debe incluir physicalMs pre-1970")

        let byStructured = hlcs.sorted(by: <)
        let byString = hlcs.sorted { $0.description < $1.description }
        #expect(byStructured.map(\.description) == byString.map(\.description))
    }

    // MARK: - HLCClock.send

    @Test func send_freshClock_adoptsWall_counterZero() throws {
        var clock = HLCClock(nodeID: try node(nodeA))
        let ts = try clock.send(now: date(Self.anchorMs))
        #expect(ts.description == "2021-01-01T00:00:00.000Z-0000-00000000000000aa")
        #expect(clock.latest == ts)
    }

    @Test func send_stuttering_incrementsCounter() throws {
        var clock = HLCClock(nodeID: try node(nodeA))
        let now = date(Self.anchorMs)
        let first = try clock.send(now: now)
        let second = try clock.send(now: now)
        let third = try clock.send(now: now)
        #expect(first.counter == 0)
        #expect(second.counter == 1)
        #expect(third.counter == 2)
        #expect(first.physicalMs == second.physicalMs)
    }

    @Test func send_wallAdvances_resetsCounter() throws {
        var clock = HLCClock(nodeID: try node(nodeA),
                             latest: try HLC(physicalMs: Self.anchorMs, counter: 9, nodeID: node(nodeA)))
        let ts = try clock.send(now: date(Self.anchorMs + 1000))
        #expect(ts.description == "2021-01-01T00:00:01.000Z-0000-00000000000000aa")
    }

    @Test func send_clockRegression_latestWins_counterAdvances() throws {
        // Reloj de pared retrocede: el physical de latest manda y el counter avanza.
        var clock = HLCClock(nodeID: try node(nodeA),
                             latest: try HLC(physicalMs: Self.anchorMs + 1000, counter: 3, nodeID: node(nodeA)))
        let ts = try clock.send(now: date(Self.anchorMs))  // pasado
        #expect(ts.physicalMs == Self.anchorMs + 1000)
        #expect(ts.counter == 4)
    }

    @Test func send_driftAtBoundary_isAllowed() throws {
        // Exactamente 5 min de adelanto (300000 ms) == maxDrift → permitido (no es > maxDrift).
        var clock = HLCClock(nodeID: try node(nodeA),
                             latest: try HLC(physicalMs: Self.anchorMs + 300_000, counter: 0, nodeID: node(nodeA)))
        let ts = try clock.send(now: date(Self.anchorMs))
        #expect(ts.physicalMs == Self.anchorMs + 300_000)
        #expect(ts.counter == 1)
    }

    @Test func send_driftBeyond5min_throws() throws {
        var clock = HLCClock(nodeID: try node(nodeA),
                             latest: try HLC(physicalMs: Self.anchorMs + 300_001, counter: 0, nodeID: node(nodeA)))
        #expect(throws: ClockDriftError.self) {
            _ = try clock.send(now: date(Self.anchorMs))
        }
        // latest NO debe mutar cuando send lanza.
        #expect(clock.latest?.physicalMs == Self.anchorMs + 300_001)
        #expect(clock.latest?.counter == 0)
    }

    @Test func send_counterOverflow_throws() throws {
        var clock = HLCClock(nodeID: try node(nodeA),
                             latest: try HLC(physicalMs: Self.anchorMs, counter: 0xFFFF, nodeID: node(nodeA)))
        // 0xFFFF es válido; el siguiente send en el mismo ms desbordaría.
        #expect(throws: ClockDriftError.self) {
            _ = try clock.send(now: date(Self.anchorMs))
        }
    }

    // MARK: - HLCClock.receive

    @Test func receive_remoteAhead_adoptsRemote_stampsLocalNode() throws {
        var clock = HLCClock(nodeID: try node(nodeA),
                             latest: try HLC(physicalMs: Self.anchorMs, counter: 2, nodeID: node(nodeA)))
        let remote = try HLC(physicalMs: Self.anchorMs + 1000, counter: 5, nodeID: node(nodeB))
        let ts = try clock.receive(remote: remote, now: date(Self.anchorMs))
        #expect(ts.description == "2021-01-01T00:00:01.000Z-0006-00000000000000aa")
    }

    @Test func receive_remoteBehind_localWins() throws {
        var clock = HLCClock(nodeID: try node(nodeA),
                             latest: try HLC(physicalMs: Self.anchorMs + 1000, counter: 3, nodeID: node(nodeA)))
        let remote = try HLC(physicalMs: Self.anchorMs, counter: 9, nodeID: node(nodeB))
        let ts = try clock.receive(remote: remote, now: date(Self.anchorMs + 1000))
        #expect(ts.physicalMs == Self.anchorMs + 1000)
        #expect(ts.counter == 4)
    }

    @Test func receive_tieAll_takesMaxCounterPlusOne() throws {
        var clock = HLCClock(nodeID: try node(nodeA),
                             latest: try HLC(physicalMs: Self.anchorMs, counter: 4, nodeID: node(nodeA)))
        let remote = try HLC(physicalMs: Self.anchorMs, counter: 7, nodeID: node(nodeB))
        let ts = try clock.receive(remote: remote, now: date(Self.anchorMs))
        #expect(ts.counter == 8)  // max(4,7)+1
    }

    @Test func receive_wallAheadOfBoth_resetsCounter() throws {
        var clock = HLCClock(nodeID: try node(nodeA),
                             latest: try HLC(physicalMs: Self.anchorMs, counter: 1, nodeID: node(nodeA)))
        let remote = try HLC(physicalMs: Self.anchorMs, counter: 1, nodeID: node(nodeB))
        let ts = try clock.receive(remote: remote, now: date(Self.anchorMs + 1000))
        #expect(ts.description == "2021-01-01T00:00:01.000Z-0000-00000000000000aa")
    }

    @Test func receive_driftBeyond5min_throws() throws {
        var clock = HLCClock(nodeID: try node(nodeA))
        let remote = try HLC(physicalMs: Self.anchorMs + 300_001, counter: 0, nodeID: node(nodeB))
        #expect(throws: ClockDriftError.self) {
            _ = try clock.receive(remote: remote, now: date(Self.anchorMs))
        }
        #expect(clock.latest == nil)  // no muta al lanzar
    }

    @Test func receive_counterOverflow_throws() throws {
        var clock = HLCClock(nodeID: try node(nodeA),
                             latest: try HLC(physicalMs: Self.anchorMs, counter: 0xFFFF, nodeID: node(nodeA)))
        let remote = try HLC(physicalMs: Self.anchorMs, counter: 0xFFFF, nodeID: node(nodeB))
        #expect(throws: ClockDriftError.self) {
            _ = try clock.receive(remote: remote, now: date(Self.anchorMs))
        }
    }

    // MARK: - Codable

    @Test func codable_encodesAsSingleValueString() throws {
        let hlc = try HLC(physicalMs: Self.anchorMs, counter: 0x00ab, nodeID: node(nodeA))
        let data = try JSONEncoder().encode(hlc)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json == "\"2021-01-01T00:00:00.000Z-00ab-00000000000000aa\"")

        let decoded = try JSONDecoder().decode(HLC.self, from: data)
        #expect(decoded == hlc)
    }

    @Test func codable_decodeRejectsMalformed() {
        let bad = "\"2021-01-01T00:00:00.000Z-0000-00000000000000AA\"".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(HLC.self, from: bad)
        }
    }
}
