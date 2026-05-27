//
//  BridgeBranchLogic.swift
//  Yala
//
//  Pure-logic helper que decide qué path ejecutar el bridge en Caso A según
//  el modo (usageMode + opt-out effective). Testeable sin SwiftData/ModelContext.
//
//  El bridge real (`GroupTransactionBridge.bridgeExpense`) tiene branches `if/return`
//  equivalentes — este helper espeja la lógica para validar cobertura via tests.
//

import Foundation

enum BridgeBranchLogic {

    /// Path a ejecutar en Caso A (current user es payer del expense).
    enum CaseAPath: Equatable {
        /// Mode `.groupInvite`: fallback M5 (TX1 virtual -myShare + TX2 virtual +totalAmount).
        case groupInviteVirtualPair
        /// Bridge effective OFF: solo TX virtual -myShare (idéntico a Caso B).
        case optoutVirtualOnly
        /// Mode `.full/.completed` + bridge effective ON: TX real cuenta personal + TX virtual lent.
        case fullPair
    }

    /// Resuelve el path para Caso A.
    /// - Parameters:
    ///   - isGroupInviteMode: `SessionState.onboardingMode == .groupInvite`.
    ///   - effectiveBridgeEnabled: resultado de `BridgeResolverLogic.computeEffective`.
    static func decideCaseAPath(
        isGroupInviteMode: Bool,
        effectiveBridgeEnabled: Bool
    ) -> CaseAPath {
        if isGroupInviteMode { return .groupInviteVirtualPair }
        if !effectiveBridgeEnabled { return .optoutVirtualOnly }
        return .fullPair
    }
}
