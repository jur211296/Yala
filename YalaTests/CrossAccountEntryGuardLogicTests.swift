//
//  CrossAccountEntryGuardLogicTests.swift
//  YalaTests
//

import Foundation
import Testing

@testable import Yala

@Suite("Guard cross-cuenta del sign-in en Welcome (F0-C)")
struct CrossAccountEntryGuardLogicTests {

    @Test
    func cleanDevice_proceeds_regardlessOfClaim() {
        #expect(CrossAccountEntryGuardLogic.decide(
            hasLocalData: false, sameAccountClaimExists: false
        ) == .proceed)
        #expect(CrossAccountEntryGuardLogic.decide(
            hasLocalData: false, sameAccountClaimExists: true
        ) == .proceed)
    }

    @Test
    func localData_sameAccount_proceeds() {
        // Re-entrada de la MISMA cuenta: el claim-store sobrevive el sign-out a propósito.
        #expect(CrossAccountEntryGuardLogic.decide(
            hasLocalData: true, sameAccountClaimExists: true
        ) == .proceed)
    }

    @Test
    func localData_foreignAccount_blocks() {
        // Caso Pia: JAMÁS adopt sobre corpus ajeno (mezcla cross-cuenta).
        #expect(CrossAccountEntryGuardLogic.decide(
            hasLocalData: true, sameAccountClaimExists: false
        ) == .blockedForeignData)
    }
}
