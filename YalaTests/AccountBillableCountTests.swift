//
//  AccountBillableCountTests.swift
//  YalaTests
//
//  Unit tests para el límite Free de cuentas: las cuentas de sistema del bridge
//  de grupos NO consumen el límite. SSOT = `Account.isBillableUserAccount`.
//  @Model directo sin makeTestContext() ni ModelContainer (patrón preferido).
//

import Foundation
import Testing

@testable import Yala

struct AccountBillableCountTests {

    // MARK: - Helper

    private func makeAccount(isSystem: Bool, isArchived: Bool) -> Account {
        Account(
            name: isSystem ? "Grupos PEN" : "Efectivo",
            currencyCode: "PEN",
            colorHex: "#6366F1",
            iconName: "creditcard",
            type: "checking",
            isArchived: isArchived,
            isSystemAccount: isSystem
        )
    }

    // MARK: - isBillableUserAccount (tabla de 4 combos)

    @Test func isBillableUserAccount_normal_true() {
        #expect(makeAccount(isSystem: false, isArchived: false).isBillableUserAccount == true)
    }

    @Test func isBillableUserAccount_archived_false() {
        #expect(makeAccount(isSystem: false, isArchived: true).isBillableUserAccount == false)
    }

    @Test func isBillableUserAccount_system_false() {
        #expect(makeAccount(isSystem: true, isArchived: false).isBillableUserAccount == false)
    }

    @Test func isBillableUserAccount_systemArchived_false() {
        #expect(makeAccount(isSystem: true, isArchived: true).isBillableUserAccount == false)
    }

    // MARK: - billableUserAccounts (lista mixta)

    @Test func billableUserAccounts_mixedList_excludesSystemAndArchived() {
        let accounts: [Account] = [
            makeAccount(isSystem: false, isArchived: false), // propia
            makeAccount(isSystem: false, isArchived: false), // propia
            makeAccount(isSystem: false, isArchived: false), // propia
            makeAccount(isSystem: true, isArchived: false),  // sistema
            makeAccount(isSystem: true, isArchived: false),  // sistema
            makeAccount(isSystem: false, isArchived: true)   // archivada
        ]

        let billable = accounts.billableUserAccounts

        #expect(billable.count == 3)
        #expect(billable.allSatisfy { !$0.isSystemAccount })
    }

    // MARK: - Gate (dirección PERMISIVA vía singleton — insensible a Pro)

    @MainActor @Test func gate_belowLimit_permitsCreation() {
        // 3 cuentas facturables < freeLimit(4). Free y Pro dan lo mismo,
        // así que estos asserts son inmunes a la contaminación StoreKit sandbox.
        let gate = FeatureGateService.shared
        #expect(gate.canCreate(.accounts, currentCount: 3) == true)
        #expect(gate.isAtLimit(.accounts, currentCount: 3) == false)
    }

    // MARK: - Dirección BLOQUEANTE (piezas puras, sin singleton)

    @Test func fiveOwnAccounts_exceedFreeLimit() {
        let accounts = (0..<5).map { _ in makeAccount(isSystem: false, isArchived: false) }
        let billable = accounts.billableUserAccounts
        #expect(billable.count == 5)
        #expect(billable.count > (ProFeature.accounts.freeLimit ?? Int.max))
    }

    @Test func fourOwnPlusTwoSystem_doNotExceedFreeLimit() {
        // El trigger legacy `> 2` presentaba un sheet VACÍO aquí; con el helper
        // el count facturable es 4 y NO supera freeLimit=4.
        let accounts =
            (0..<4).map { _ in makeAccount(isSystem: false, isArchived: false) } +
            (0..<2).map { _ in makeAccount(isSystem: true, isArchived: false) }
        let billable = accounts.billableUserAccounts
        #expect(billable.count == 4)
        #expect(!(billable.count > (ProFeature.accounts.freeLimit ?? Int.max)))
    }
}
