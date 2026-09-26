//
//  PrefsOutboxTests.swift
//  YalaTests / CloudSync
//
//  Cola durable de prefs (I13): enqueue sobrescribe por key, durabilidad round-trip del archivo, HLC
//  monótono entre enqueues, owner-scoping (M1) y purga total (teardown). `directoryURL` inyectable (temp).
//

import Foundation
import Testing

@testable import Yala

@Suite("PrefsOutbox · I13")
struct PrefsOutboxTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrefsOutbox-\(UUID().uuidString)", isDirectory: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    // MARK: - Enqueue + durabilidad

    @Test func enqueue_persistsAndReadsBack() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let outbox = PrefsOutbox(directoryURL: dir)

        try outbox.enqueue(key: "userName", userID: "u1", value: .string("Ana"))
        try outbox.enqueue(key: "colorfulIcons", userID: "u1", value: .bool(true))
        try outbox.enqueue(key: "decimalPlaces", userID: "u1", value: .int(0))

        // Instancia FRESCA sobre el mismo dir → durabilidad real (no estado en memoria).
        let reopened = PrefsOutbox(directoryURL: dir)
        let entries = Dictionary(uniqueKeysWithValues: reopened.entries(forUserID: "u1").map { ($0.key, $0.entry) })
        #expect(entries.count == 3)
        #expect(entries["userName"]?.value == "Ana")
        #expect(entries["colorfulIcons"]?.value == "true")
        #expect(entries["decimalPlaces"]?.value == "0")
        #expect(entries["userName"]?.kind == "string")
        #expect(entries["colorfulIcons"]?.kind == "bool")
        #expect(entries["decimalPlaces"]?.kind == "int")
    }

    /// M2 (review I13): la monotonicidad SOBREVIVE el relanzamiento con reloj físico REGRESIVO (aquí 60 s; más allá de
    /// los 5 min de deriva lo cubre `hlc_regressionBeyondDrift_…`) — el `lastIssuedHLC` persistido es el que la garantiza (si se
    /// perdiera, un HLC nuevo con physical menor perdería el LWW contra el propio pasado del device).
    @Test func hlc_monotonic_acrossReopen_withRegressiveClock() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let base = Date(timeIntervalSince1970: 2_000_000)
        let outbox = PrefsOutbox(directoryURL: dir)
        try outbox.enqueue(key: "userName", userID: "u1", value: .string("v1"), now: base)
        let first = outbox.entries(forUserID: "u1").first?.entry.hlc
        #expect(first != nil)

        // Instancia FRESCA (relanzamiento) con `now` 60s ANTERIOR.
        let reopened = PrefsOutbox(directoryURL: dir)
        try reopened.enqueue(key: "userName", userID: "u1", value: .string("v2"),
                             now: base.addingTimeInterval(-60))
        let second = reopened.entries(forUserID: "u1").first?.entry.hlc
        #expect(second != nil)
        #expect(second! > first!)   // orden lexicográfico del wire == orden causal
    }

    /// Complemento M2: una regresión MÁS ALLÁ del drift tolerado (5 min) tampoco emite un HLC stale ni rompe la
    /// monotonicidad, y además **encola**. Hasta `personal-clock-rollback-wedges-the-drain-forever` el reloj rechazaba
    /// (`clockFailed`), el llamador lo descartaba y ese cambio no subía nunca: el `lastIssuedHLC` solo baja si la hora real
    /// lo alcanza. Ahora estampa con `sendLocal`: por encima del último emitido, con la hora que sea.
    @Test func hlc_regressionBeyondDrift_stillEnqueues_aboveTheLastIssued() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let base = Date(timeIntervalSince1970: 2_000_000)
        let outbox = PrefsOutbox(directoryURL: dir)
        try outbox.enqueue(key: "userName", userID: "u1", value: .string("v1"), now: base)
        let first = try HLC.parse(try #require(outbox.entries(forUserID: "u1").first?.entry.hlc))

        let reopened = PrefsOutbox(directoryURL: dir)
        try reopened.enqueue(key: "userName", userID: "u1", value: .string("v2"),
                             now: base.addingTimeInterval(-600))  // 10 min > drift 5 min
        let entry = try #require(reopened.entries(forUserID: "u1").first?.entry)
        #expect(entry.value == "v2", "el cambio llega al outbox")
        #expect(try HLC.parse(entry.hlc) > first, "por encima del último emitido: no pierde contra su propio pasado")
    }

    /// El reloj persistido un día por delante, sin tocarlo: cada cambio de después se encola, ordenado tras el anterior.
    @Test func hlc_clockAheadByADay_everyLaterChangeEnqueues_inOrder() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let base = Date(timeIntervalSince1970: 2_000_000)
        let outbox = PrefsOutbox(directoryURL: dir)
        try outbox.enqueue(key: "userName", userID: "u1", value: .string("adelantada"),
                           now: base.addingTimeInterval(86_400))
        var last = try HLC.parse(try #require(outbox.entries(forUserID: "u1").first?.entry.hlc))

        for (i, key) in ["userName", "decimalPlaces", "userName"].enumerated() {
            let value: PrefValue = key == "decimalPlaces" ? .int(i) : .string("v\(i)")
            try PrefsOutbox(directoryURL: dir).enqueue(key: key, userID: "u1", value: value,
                                                       now: base.addingTimeInterval(Double(i * 60)))
            let hlc = try HLC.parse(try #require(outbox.entries(forUserID: "u1").first { $0.key == key }?.entry.hlc))
            #expect(hlc > last)
            last = hlc
        }
        #expect(outbox.entries(forUserID: "u1").first { $0.key == "userName" }?.entry.value == "v2")
    }

    /// El HLC sale del `now` inyectado, no de la hora del reloj de pared: en el régimen normal (sin reloj persistido por
    /// delante) su milisegundo es el de `now`. Sin eso, los tests de esta suite con fechas fijas no medirían lo que dicen.
    @Test func hlc_isStampedWithTheInjectedNow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let now = Date(timeIntervalSince1970: 1_000)
        let outbox = PrefsOutbox(directoryURL: dir)
        try outbox.enqueue(key: "userName", userID: "u1", value: .string("Ana"), now: now)
        let hlc = try HLC.parse(try #require(outbox.entries(forUserID: "u1").first?.entry.hlc))
        #expect(hlc.physicalMs == CanonicalTime.physicalMillis(from: now))
    }

    /// Lo único que aún hace fallar el estampado, un año fuera de 0001–9999, sigue saliendo `clockFailed` y no toca el
    /// fichero: la entrada previa y el último HLC emitido quedan como estaban.
    @Test func hlc_yearOutOfRange_throwsClockFailed_andLeavesTheFileIntact() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let outbox = PrefsOutbox(directoryURL: dir)
        try outbox.enqueue(key: "userName", userID: "u1", value: .string("v1"), now: Date(timeIntervalSince1970: 1_000))
        let before = try #require(outbox.entries(forUserID: "u1").first?.entry)

        #expect {
            try outbox.enqueue(key: "userName", userID: "u1", value: .string("v2"),
                               now: Date(timeIntervalSince1970: 3e11))  // año ~11476
        } throws: { error in
            if case PrefsOutboxError.clockFailed = error { return true }
            return false
        }
        let after = try #require(outbox.entries(forUserID: "u1").first?.entry)
        #expect(after.value == "v1")
        #expect(after.hlc == before.hlc)
    }

    @Test func enqueue_overwritesByKey() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let outbox = PrefsOutbox(directoryURL: dir)

        try outbox.enqueue(key: "userName", userID: "u1", value: .string("Ana"),
                           now: Date(timeIntervalSince1970: 1_000))
        try outbox.enqueue(key: "userName", userID: "u1", value: .string("Bea"),
                           now: Date(timeIntervalSince1970: 2_000))

        let entries = outbox.entries(forUserID: "u1")
        #expect(entries.count == 1)  // sobrescribe, no acumula
        #expect(entries.first?.entry.value == "Bea")
    }

    // MARK: - HLC monótono

    @Test func enqueue_hlcMonotonicAcrossEnqueues() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let outbox = PrefsOutbox(directoryURL: dir)

        // Mismo `now` en dos enqueues → el counter debe avanzar (HLC estrictamente creciente).
        let now = Date(timeIntervalSince1970: 5_000)
        try outbox.enqueue(key: "a", userID: "u1", value: .string("1"), now: now)
        try outbox.enqueue(key: "b", userID: "u1", value: .string("2"), now: now)
        try outbox.enqueue(key: "c", userID: "u1", value: .string("3"), now: now)

        let byKey = Dictionary(uniqueKeysWithValues: outbox.entries(forUserID: "u1").map { ($0.key, $0.entry.hlc) })
        let ha = try HLC.parse(#require(byKey["a"]))
        let hb = try HLC.parse(#require(byKey["b"]))
        let hc = try HLC.parse(#require(byKey["c"]))
        #expect(ha < hb)
        #expect(hb < hc)
        // Mismo nodeID en las tres (nodeID persistido/estable).
        #expect(ha.nodeID == hb.nodeID)
        #expect(hb.nodeID == hc.nodeID)
    }

    @Test func nodeID_stableAcrossReopens() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        try PrefsOutbox(directoryURL: dir).enqueue(key: "a", userID: "u1", value: .string("1"),
                                                    now: Date(timeIntervalSince1970: 1_000))
        let n1 = try HLC.parse(#require(PrefsOutbox(directoryURL: dir).entries(forUserID: "u1").first?.entry.hlc)).nodeID

        // Nuevo enqueue tras reabrir → mismo nodeID (persistido en el archivo).
        try PrefsOutbox(directoryURL: dir).enqueue(key: "b", userID: "u1", value: .string("2"),
                                                    now: Date(timeIntervalSince1970: 2_000))
        let byKey = Dictionary(uniqueKeysWithValues:
            PrefsOutbox(directoryURL: dir).entries(forUserID: "u1").map { ($0.key, $0.entry.hlc) })
        let n2 = try HLC.parse(#require(byKey["b"])).nodeID
        #expect(n1 == n2)
    }

    // MARK: - Owner-scoping (M1)

    @Test func entriesForUser_filtersByOwner() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let outbox = PrefsOutbox(directoryURL: dir)
        try outbox.enqueue(key: "userName", userID: "u1", value: .string("Ana"))
        try outbox.enqueue(key: "voiceLanguage", userID: "u2", value: .string("en"))

        #expect(outbox.entries(forUserID: "u1").map(\.key) == ["userName"])
        #expect(outbox.entries(forUserID: "u2").map(\.key) == ["voiceLanguage"])
        #expect(outbox.entries(forUserID: "u3").isEmpty)
    }

    // MARK: - removeEntries (purga tras push)

    @Test func removeEntries_purgesGivenKeys() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let outbox = PrefsOutbox(directoryURL: dir)
        try outbox.enqueue(key: "a", userID: "u1", value: .string("1"))
        try outbox.enqueue(key: "b", userID: "u1", value: .string("2"))

        try outbox.removeEntries(keys: ["a"])
        #expect(outbox.entries(forUserID: "u1").map(\.key) == ["b"])
    }

    // MARK: - Cursor del pull

    @Test func pullCursor_defaultsZero_andPersists() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let outbox = PrefsOutbox(directoryURL: dir)
        #expect(outbox.pullCursor == 0)

        try outbox.setPullCursor(42)
        #expect(outbox.pullCursor == 42)
        // Persistente + no borra entries.
        try outbox.enqueue(key: "a", userID: "u1", value: .string("1"))
        #expect(PrefsOutbox(directoryURL: dir).pullCursor == 42)
        #expect(PrefsOutbox(directoryURL: dir).entries(forUserID: "u1").count == 1)
    }

    // MARK: - purgeAll (teardown M1)

    @Test func purgeAll_removesEverything() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let outbox = PrefsOutbox(directoryURL: dir)
        try outbox.enqueue(key: "a", userID: "u1", value: .string("1"))
        try outbox.enqueue(key: "b", userID: "u2", value: .string("2"))
        try outbox.setPullCursor(9)

        outbox.purgeAll()

        #expect(outbox.entries(forUserID: "u1").isEmpty)
        #expect(outbox.entries(forUserID: "u2").isEmpty)
        #expect(outbox.pullCursor == 0)  // archivo borrado → cursor vuelve a 0
    }
}
