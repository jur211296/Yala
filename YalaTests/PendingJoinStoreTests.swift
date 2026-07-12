//
//  PendingJoinStoreTests.swift
//  YalaTests
//
//  Pure-logic del store persistente de join intents (unión a grupos).
//  Serializado porque `PendingJoinStore.defaults` es estado estático compartido.
//  Cada test inyecta un UserDefaults aislado y lo restaura al salir (patrón
//  PendingInviteStoreTests).
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite("PendingJoinStore", .serialized)
struct PendingJoinStoreTests {

    /// Fecha de referencia fija para los tests de TTL (evita `Date()` real).
    private let ref = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeStore() -> () -> Void {
        let suiteName = "test.pendingjoin.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suiteName)!
        PendingJoinStore.defaults = d
        return {
            PendingJoinStore.defaults = .standard
            d.removePersistentDomain(forName: suiteName)
        }
    }

    private func makeEntry(
        zone: String = "SplitGroup-AAAA",
        owner: String = "_owner123",
        displayName: String? = nil,
        currency: String? = nil,
        createdAt: Date
    ) -> PendingJoinEntry {
        PendingJoinEntry(
            zoneName: zone,
            zoneOwnerName: owner,
            displayName: displayName,
            regionFallbackCurrency: currency,
            createdAt: createdAt
        )
    }

    // MARK: - Round-trip

    @Test func saveThenRead_roundTripsFullContent() {
        let cleanup = makeStore(); defer { cleanup() }
        let entry = makeEntry(displayName: "Pia", currency: "PEN", createdAt: ref)
        PendingJoinStore.save(entry)
        let loaded = PendingJoinStore.entry(zoneName: "SplitGroup-AAAA", now: ref)
        #expect(loaded == entry)
        #expect(loaded?.zoneOwnerName == "_owner123")
        #expect(loaded?.displayName == "Pia")
        #expect(loaded?.regionFallbackCurrency == "PEN")
    }

    // MARK: - TTL (7 días)

    @Test func read_withinTTL_returnsEntry() {
        let cleanup = makeStore(); defer { cleanup() }
        PendingJoinStore.save(makeEntry(createdAt: ref))
        // 6 días después → dentro del TTL de 7d.
        let sixDays = ref.addingTimeInterval(6 * 24 * 3600)
        #expect(PendingJoinStore.entry(zoneName: "SplitGroup-AAAA", now: sixDays) != nil)
    }

    @Test func read_expired_purgesPersistently() {
        let cleanup = makeStore(); defer { cleanup() }
        PendingJoinStore.save(makeEntry(createdAt: ref))
        let eightDays = ref.addingTimeInterval(8 * 24 * 3600)
        #expect(PendingJoinStore.all(now: eightDays).isEmpty)
        // La purga persiste: una lectura posterior con `now` temprano sigue vacía.
        #expect(PendingJoinStore.all(now: ref).isEmpty)
    }

    @Test func read_mixedExpiry_purgesOnlyExpired() {
        let cleanup = makeStore(); defer { cleanup() }
        PendingJoinStore.save(makeEntry(zone: "SplitGroup-OLD", createdAt: ref))
        let later = ref.addingTimeInterval(5 * 24 * 3600)
        PendingJoinStore.save(makeEntry(zone: "SplitGroup-NEW", createdAt: later))
        // A los 8 días de ref: OLD expiró, NEW (5d de vida) sigue viva.
        let eightDays = ref.addingTimeInterval(8 * 24 * 3600)
        let vigentes = PendingJoinStore.all(now: eightDays)
        #expect(vigentes.map(\.zoneName) == ["SplitGroup-NEW"])
    }

    // MARK: - Multi-entry / upsert

    @Test func saveSameZoneTwice_upsertsWithoutDuplicating() {
        let cleanup = makeStore(); defer { cleanup() }
        PendingJoinStore.save(makeEntry(createdAt: ref))
        PendingJoinStore.save(makeEntry(displayName: "Pia", createdAt: ref.addingTimeInterval(60)))
        let all = PendingJoinStore.all(now: ref.addingTimeInterval(60))
        #expect(all.count == 1)
        #expect(all.first?.displayName == "Pia")
    }

    @Test func saveTwoZones_keepsBoth() {
        let cleanup = makeStore(); defer { cleanup() }
        PendingJoinStore.save(makeEntry(zone: "SplitGroup-AAAA", createdAt: ref))
        PendingJoinStore.save(makeEntry(zone: "SplitGroup-BBBB", createdAt: ref.addingTimeInterval(1)))
        #expect(PendingJoinStore.all(now: ref.addingTimeInterval(2)).count == 2)
    }

    @Test func overCap_evictsOldest() {
        let cleanup = makeStore(); defer { cleanup() }
        for i in 0..<(PendingJoinStore.maxEntries + 1) {
            PendingJoinStore.save(makeEntry(
                zone: "SplitGroup-\(i)",
                createdAt: ref.addingTimeInterval(TimeInterval(i))
            ))
        }
        let all = PendingJoinStore.all(now: ref.addingTimeInterval(100))
        #expect(all.count == PendingJoinStore.maxEntries)
        // La más vieja (índice 0) fue evictada.
        #expect(!all.contains { $0.zoneName == "SplitGroup-0" })
        #expect(all.contains { $0.zoneName == "SplitGroup-\(PendingJoinStore.maxEntries)" })
    }

    // MARK: - updateDisplayName

    @Test func updateDisplayName_touchesAllLiveEntries() {
        let cleanup = makeStore(); defer { cleanup() }
        PendingJoinStore.save(makeEntry(zone: "SplitGroup-AAAA", createdAt: ref))
        PendingJoinStore.save(makeEntry(zone: "SplitGroup-BBBB", createdAt: ref))
        PendingJoinStore.updateDisplayName("Pia", now: ref)
        let all = PendingJoinStore.all(now: ref)
        #expect(all.allSatisfy { $0.displayName == "Pia" })
    }

    @Test func updateRegionFallbackCurrency_targetsSingleZone() {
        let cleanup = makeStore(); defer { cleanup() }
        PendingJoinStore.save(makeEntry(zone: "SplitGroup-AAAA", createdAt: ref))
        PendingJoinStore.save(makeEntry(zone: "SplitGroup-BBBB", createdAt: ref))
        PendingJoinStore.updateRegionFallbackCurrency("PEN", zoneName: "SplitGroup-AAAA")
        #expect(PendingJoinStore.entry(zoneName: "SplitGroup-AAAA", now: ref)?.regionFallbackCurrency == "PEN")
        #expect(PendingJoinStore.entry(zoneName: "SplitGroup-BBBB", now: ref)?.regionFallbackCurrency == nil)
    }

    // MARK: - Clear

    @Test func clearZone_leavesOthersIntact() {
        let cleanup = makeStore(); defer { cleanup() }
        PendingJoinStore.save(makeEntry(zone: "SplitGroup-AAAA", createdAt: ref))
        PendingJoinStore.save(makeEntry(zone: "SplitGroup-BBBB", createdAt: ref))
        PendingJoinStore.clear(zoneName: "SplitGroup-AAAA")
        let all = PendingJoinStore.all(now: ref)
        #expect(all.map(\.zoneName) == ["SplitGroup-BBBB"])
    }

    @Test func clearAll_wipes() {
        let cleanup = makeStore(); defer { cleanup() }
        PendingJoinStore.save(makeEntry(createdAt: ref))
        PendingJoinStore.clearAll()
        #expect(PendingJoinStore.all(now: ref).isEmpty)
    }

    // MARK: - Robustez

    @Test func corruptJSON_returnsEmptyWithoutCrash() {
        let cleanup = makeStore(); defer { cleanup() }
        PendingJoinStore.defaults.set(Data([0xFF, 0x00, 0x42]), forKey: PendingJoinStore.userDefaultsKey)
        #expect(PendingJoinStore.all(now: ref).isEmpty)
    }
}
