//
//  AppEntityShortcutIDRegenerationTests.swift
//  YalaTests
//
//  Pure-logic tests for `regenerateDuplicateUUIDs` y `regenerateAllUUIDs`.
//  Operan sobre cualquier `AnyObject` con keyPath a UUID — sin SwiftData context.
//

import Foundation
import Testing

@testable import Yala

// MARK: - Test helper

private final class TestItem {
    var id: UUID = UUID()
}

// MARK: - Tests

@MainActor
struct AppEntityShortcutIDRegenerationTests {

    @Test func allUniqueIDs_noRegeneration() {
        let a = TestItem()
        let b = TestItem()
        let c = TestItem()
        let originals = [a.id, b.id, c.id]

        let regen = regenerateDuplicateUUIDs([a, b, c], keyPath: \.id)

        #expect(regen == 0)
        #expect(a.id == originals[0])
        #expect(b.id == originals[1])
        #expect(c.id == originals[2])
    }

    @Test func allCollapsedToSame_allRegenerated() {
        let shared = UUID()
        let items = (0..<5).map { _ -> TestItem in
            let item = TestItem()
            item.id = shared
            return item
        }

        let regen = regenerateDuplicateUUIDs(items, keyPath: \.id)

        #expect(regen == 5)
        for item in items { #expect(item.id != shared) }
        #expect(Set(items.map(\.id)).count == 5)
    }

    @Test func partialDuplicates_onlyDuplicatesRegenerated() {
        let unique = TestItem()
        let originalUnique = unique.id

        let dup1 = TestItem()
        let dup2 = TestItem()
        let sharedID = UUID()
        dup1.id = sharedID
        dup2.id = sharedID

        let regen = regenerateDuplicateUUIDs([unique, dup1, dup2], keyPath: \.id)

        #expect(regen == 2)
        #expect(unique.id == originalUnique)
        #expect(dup1.id != sharedID)
        #expect(dup2.id != sharedID)
        #expect(dup1.id != dup2.id)
    }

    @Test func emptyArray_returnsZero() {
        let regen = regenerateDuplicateUUIDs([TestItem](), keyPath: \.id)
        #expect(regen == 0)
    }

    @Test func singleItem_neverRegenerated() {
        let item = TestItem()
        let original = item.id

        let regen = regenerateDuplicateUUIDs([item], keyPath: \.id)

        #expect(regen == 0)
        #expect(item.id == original)
    }

    @Test func threeWayDuplicates_allThreeRegenerated() {
        let shared = UUID()
        let items = (0..<3).map { _ -> TestItem in
            let item = TestItem()
            item.id = shared
            return item
        }

        let regen = regenerateDuplicateUUIDs(items, keyPath: \.id)

        #expect(regen == 3)
        #expect(Set(items.map(\.id)).count == 3)
        for item in items { #expect(item.id != shared) }
    }

    // MARK: - regenerateAllUUIDs (force-regenerate sin heurística)

    @Test func regenerateAll_emptyArray_returnsZero() {
        let regen = regenerateAllUUIDs([TestItem](), keyPath: \.id)
        #expect(regen == 0)
    }

    @Test func regenerateAll_singleItem_regenerated() {
        let item = TestItem()
        let original = item.id

        let regen = regenerateAllUUIDs([item], keyPath: \.id)

        #expect(regen == 1)
        #expect(item.id != original)
    }

    @Test func regenerateAll_allItemsRegenerated() {
        let items = (0..<5).map { _ in TestItem() }
        let originals = items.map(\.id)

        let regen = regenerateAllUUIDs(items, keyPath: \.id)

        #expect(regen == 5)
        let newIDs = items.map(\.id)
        // Cada item recibió un UUID nuevo distinto del original
        for (original, new) in zip(originals, newIDs) {
            #expect(original != new)
        }
        // Los 5 nuevos UUIDs son únicos entre sí
        #expect(Set(newIDs).count == 5)
    }
}
