//
//  AdoptOrphanDiffTests.swift
//  YalaTests / CloudSync
//
//  Lógica PURA del diff de huérfanas del adopt (DIFERIDOS #30). Sin `ModelContext` ni I/O: se le pasan el
//  inventario `(table, syncID?)` + el set del backend y se asserta el plan. Order-independiente/determinista.
//

import Foundation
import Testing

@testable import Yala

@Suite("AdoptOrphanDiff · lógica pura (DIFERIDOS #30)")
struct AdoptOrphanDiffTests {

    private func uuid(_ n: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!
    }

    @Test("identidad presente ∉ backend → huérfana; ∈ backend (upsert) → NO")
    func presentNotInBackend_isOrphan() {
        let a = uuid(1)  // ausente del backend → huérfana
        let b = uuid(2)  // presente (upsert) → conocida
        let plan = AdoptOrphanDiff.compute(
            inventory: [("tx_items", a), ("tx_items", b)],
            backendSyncIDs: [b])
        #expect(plan.orphans == ["tx_items": [a]])
        #expect(plan.needsIdentity.isEmpty)
        #expect(plan.uploadCount == 1)
    }

    @Test("∈ backend por TOMBSTONE → NO huérfana (zombie del apply, jamás re-subir)")
    func presentAsTombstone_isNotOrphan() {
        let a = uuid(1)  // el backend lo conoce (tombstone) → la copia viva local es zombie
        let plan = AdoptOrphanDiff.compute(
            inventory: [("accounts", a)],
            backendSyncIDs: [a])  // el set NO distingue upsert/tombstone: ambos = "el backend YA sabe"
        #expect(plan.orphans.isEmpty)
        #expect(plan.uploadCount == 0)
    }

    @Test("nil → needsIdentity SOLO en tablas sintéticas; id-estables jamás producen nil (contrato)")
    func nilIdentity_countsNeedsIdentity() {
        let plan = AdoptOrphanDiff.compute(
            inventory: [("tx_items", nil), ("tx_items", nil), ("inbox_drafts", nil)],
            backendSyncIDs: [])
        #expect(plan.needsIdentity == ["tx_items": 2, "inbox_drafts": 1])
        #expect(plan.identityCount == 3)
        // Sin identidad → no aparece en orphans (el executor las materializa vía backfill antes de subir).
        #expect(plan.orphans.isEmpty)
    }

    @Test("determinista y order-independiente: mismo plan sin importar el orden del inventario")
    func deterministic_orderIndependent() {
        let a = uuid(10); let b = uuid(20); let c = uuid(30)
        let backend: Set<UUID> = [c]
        let plan1 = AdoptOrphanDiff.compute(
            inventory: [("tx_items", a), ("tx_items", b), ("tx_items", c)], backendSyncIDs: backend)
        let plan2 = AdoptOrphanDiff.compute(
            inventory: [("tx_items", c), ("tx_items", b), ("tx_items", a)], backendSyncIDs: backend)
        #expect(plan1 == plan2)
        // Orden interno = identidades asc por uuidString.
        #expect(plan1.orphans == ["tx_items": [a, b]])
    }

    @Test("inventario vacío → plan vacío (no-op)")
    func emptyInventory_emptyPlan() {
        let plan = AdoptOrphanDiff.compute(inventory: [], backendSyncIDs: [uuid(1)])
        #expect(plan.orphans.isEmpty)
        #expect(plan.needsIdentity.isEmpty)
        #expect(plan.uploadCount == 0)
    }

    @Test("backend vacío (born-cloud-like): TODO lo local con identidad es huérfano — correcto para el caso teórico")
    func emptyBackend_allWithIdentityAreOrphans() {
        let a = uuid(1); let b = uuid(2)
        let plan = AdoptOrphanDiff.compute(
            inventory: [("accounts", a), ("tags", b)], backendSyncIDs: [])
        #expect(plan.orphans == ["accounts": [a], "tags": [b]])
        #expect(plan.uploadCount == 2)
        // El guard anti mass-upload del executor (backend vacío + huérfanas) vive FUERA de la lógica pura.
    }

    @Test("múltiples tablas mezclando conocidas, huérfanas y nils")
    func mixedTables() {
        let known = uuid(1); let orphanTx = uuid(2)
        let orphanAcc = uuid(3)
        let plan = AdoptOrphanDiff.compute(
            inventory: [
                ("tx_items", known), ("tx_items", orphanTx), ("tx_items", nil),
                ("accounts", orphanAcc),
            ],
            backendSyncIDs: [known])
        #expect(plan.orphans == ["tx_items": [orphanTx], "accounts": [orphanAcc]])
        #expect(plan.needsIdentity == ["tx_items": 1])
        #expect(plan.uploadCount == 2)
        #expect(plan.identityCount == 1)
    }
}
