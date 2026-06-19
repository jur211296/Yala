//
//  IdentityUUIDCollisionLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para la auto-cura de UUIDs de identidad colapsados:
//  - `collidedUUIDItems`: detecta items cuyo UUID colisiona (read-only).
//  - `MigrationGateLogic.shouldDeferMigration`: defer del one-shot en timeout de import.
//  Sin SwiftData context (regla R8).
//

import Foundation
import Testing

@testable import Yala

// MARK: - Test helper

private final class TestItem {
    var id: UUID = UUID()
}

// MARK: - collidedUUIDItems

@MainActor
struct IdentityUUIDCollisionLogicTests {

    @Test func allUnique_returnsEmpty() {
        let items = (0..<3).map { _ in TestItem() }
        let collided = collidedUUIDItems(items, keyPath: \.id)
        #expect(collided.isEmpty)
    }

    @Test func allCollapsedToSame_returnsAll() {
        let shared = UUID()
        let items = (0..<3).map { _ -> TestItem in
            let item = TestItem()
            item.id = shared
            return item
        }
        let collided = collidedUUIDItems(items, keyPath: \.id)
        #expect(collided.count == 3)
        #expect(collided.allSatisfy { $0.id == shared })
    }

    @Test func partialCollision_returnsOnlyColliding() {
        let unique = TestItem()
        let dup1 = TestItem()
        let dup2 = TestItem()
        let shared = UUID()
        dup1.id = shared
        dup2.id = shared

        let collided = collidedUUIDItems([unique, dup1, dup2], keyPath: \.id)

        #expect(collided.count == 2)
        #expect(collided.allSatisfy { $0.id == shared })
        #expect(!collided.contains { $0 === unique })
        // Read-only: no muta los ids.
        #expect(dup1.id == shared)
    }

    @Test func emptyArray_returnsEmpty() {
        let collided = collidedUUIDItems([TestItem](), keyPath: \.id)
        #expect(collided.isEmpty)
    }

    @Test func singleItem_returnsEmpty() {
        // count==1 NO es colisión — un id único (aunque sea el default) está bien.
        let collided = collidedUUIDItems([TestItem()], keyPath: \.id)
        #expect(collided.isEmpty)
    }

    @Test func twoSeparateCollisionGroups_returnsBothGroups() {
        let a1 = TestItem(); let a2 = TestItem()
        let b1 = TestItem(); let b2 = TestItem()
        let unique = TestItem()
        let groupA = UUID(); let groupB = UUID()
        a1.id = groupA; a2.id = groupA
        b1.id = groupB; b2.id = groupB

        let collided = collidedUUIDItems([a1, a2, b1, b2, unique], keyPath: \.id)

        #expect(collided.count == 4)
        #expect(!collided.contains { $0 === unique })
    }

    // MARK: - MigrationGateLogic.shouldDeferMigration

    @Test func defer_notWaited_neverDefers() {
        #expect(MigrationGateLogic.shouldDeferMigration(waitedForSync: false, importSettled: true) == false)
        #expect(MigrationGateLogic.shouldDeferMigration(waitedForSync: false, importSettled: false) == false)
    }

    @Test func defer_waitedAndSettled_doesNotDefer() {
        #expect(MigrationGateLogic.shouldDeferMigration(waitedForSync: true, importSettled: true) == false)
    }

    @Test func defer_waitedButTimedOut_defers() {
        #expect(MigrationGateLogic.shouldDeferMigration(waitedForSync: true, importSettled: false) == true)
    }
}
