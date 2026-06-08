//
//  PendingInviteStoreTests.swift
//  YalaTests
//
//  Pure-logic del store persistente de invites de grupo pendientes. Serializado
//  porque `PendingInviteStore.defaults` es estado estático compartido. Cada test
//  inyecta un UserDefaults aislado y lo restaura al salir.
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite("PendingInviteStore", .serialized)
struct PendingInviteStoreTests {

    /// Fecha de referencia fija para los tests de TTL (evita `Date()` real).
    private let ref = Date(timeIntervalSince1970: 1_700_000_000)

    /// Inyecta un UserDefaults aislado en el store; devuelve el cleanup que lo
    /// restaura y borra el suite. Patrón para singletons mutables (CLAUDE.md R).
    private func makeStore() -> () -> Void {
        let suiteName = "test.pendinginvite.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suiteName)!
        PendingInviteStore.defaults = d
        return {
            PendingInviteStore.defaults = .standard
            d.removePersistentDomain(forName: suiteName)
        }
    }

    private func makeEntry(createdAt: Date) -> PendingInviteEntry {
        PendingInviteEntry(
            shareURL: URL(string: "https://www.icloud.com/share/abc123")!,
            branded: InviteLinkService.BrandedMetadata(
                name: "Amigos", icon: "person.3.fill", color: "FF00AA",
                members: ["Sofía", "Juan"]
            ),
            createdAt: createdAt
        )
    }

    // MARK: - Round-trip

    @Test func saveThenCurrent_roundTrips() {
        let cleanup = makeStore(); defer { cleanup() }
        let entry = makeEntry(createdAt: ref)
        PendingInviteStore.save(entry)
        #expect(PendingInviteStore.current(now: ref) == entry)
    }

    @Test func resolved_reconstructsURLAndBranded() {
        let entry = makeEntry(createdAt: ref)
        let resolved = entry.resolved()
        #expect(resolved?.url.absoluteString == "https://www.icloud.com/share/abc123")
        #expect(resolved?.branded.name == "Amigos")
        #expect(resolved?.branded.members == ["Sofía", "Juan"])
    }

    // MARK: - TTL

    @Test func current_withinTTL_returnsEntry() {
        let cleanup = makeStore(); defer { cleanup() }
        PendingInviteStore.save(makeEntry(createdAt: ref))
        // 1h después → dentro del TTL de 24h.
        #expect(PendingInviteStore.current(now: ref.addingTimeInterval(3600)) != nil)
    }

    @Test func current_expired_returnsNilAndPurges() {
        let cleanup = makeStore(); defer { cleanup() }
        PendingInviteStore.save(makeEntry(createdAt: ref))
        // 25h después → expirada.
        #expect(PendingInviteStore.current(now: ref.addingTimeInterval(25 * 3600)) == nil)
        // Y la purga es persistente: una lectura posterior dentro de TTL sigue nil.
        #expect(PendingInviteStore.current(now: ref.addingTimeInterval(25 * 3600 + 1)) == nil)
    }

    // MARK: - Last-write-wins

    @Test func saveTwice_lastWriteWins() {
        let cleanup = makeStore(); defer { cleanup() }
        PendingInviteStore.save(makeEntry(createdAt: ref))
        let second = PendingInviteEntry(
            shareURL: URL(string: "https://www.icloud.com/share/xyz789")!,
            branded: InviteLinkService.BrandedMetadata(
                name: "Trabajo", icon: "briefcase.fill", color: "00AAFF", members: nil
            ),
            createdAt: ref
        )
        PendingInviteStore.save(second)
        #expect(PendingInviteStore.current(now: ref) == second)
    }

    // MARK: - Clear

    @Test func clear_removesEntry() {
        let cleanup = makeStore(); defer { cleanup() }
        PendingInviteStore.save(makeEntry(createdAt: ref))
        PendingInviteStore.clear()
        #expect(PendingInviteStore.current(now: ref) == nil)
    }

    // MARK: - Robustez

    @Test func corruptJSON_returnsNilWithoutCrash() {
        let cleanup = makeStore(); defer { cleanup() }
        PendingInviteStore.defaults.set(Data([0xFF, 0x00, 0x42]), forKey: PendingInviteStore.userDefaultsKey)
        #expect(PendingInviteStore.current(now: ref) == nil)
    }

    @Test func brandedAllNil_preservesNil() {
        let cleanup = makeStore(); defer { cleanup() }
        let entry = PendingInviteEntry(
            shareURL: URL(string: "https://www.icloud.com/share/abc123")!,
            branded: .empty,
            createdAt: ref
        )
        PendingInviteStore.save(entry)
        let loaded = PendingInviteStore.current(now: ref)
        #expect(loaded?.branded.name == nil)
        #expect(loaded?.branded.members == nil)
        #expect(loaded == entry)
    }
}
