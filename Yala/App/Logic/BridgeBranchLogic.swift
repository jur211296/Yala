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

    /// Qué TX virtual crear en los paths "virtual-only" (Caso B + Caso A bridge-OFF),
    /// según si coexiste una TX real `-total` para el mismo gasto.
    enum VirtualReconciliation: Equatable {
        /// Sin TX real → virtual `-myShare` (mi costo directo). Bridge-OFF puro sin opt-in.
        case myShareCost
        /// Coexiste TX real `-total` y `lent > 0` → virtual `+lent` "Préstamo a grupos".
        /// Net (real `-total` + virtual `+lent`) = `-myShare`. Idéntico a bridge-ON Caso A.
        case lendingToCompensateReal
        /// Coexiste TX real `-total` pero `lent == 0` (yo solo en el split) → sin virtual.
        /// El real `-total` ya ES mi costo total.
        case noVirtual
    }

    /// Decide el virtual a crear dado si existe una TX real `-total` y cuánto presté.
    /// Reconciliar a `+lent` cuando hay real evita el doble conteo (B6-25): el virtual
    /// `-myShare` con mismo signo que el real `-total` se sumaba en totales/feed/stats.
    /// - Parameters:
    ///   - hasRealTx: hay (o se acaba de crear) una TX en cuenta real para este gasto.
    ///   - lentAmount: `total - myShare` (lo que presté al grupo).
    static func decideVirtualReconciliation(
        hasRealTx: Bool,
        lentAmount: Double
    ) -> VirtualReconciliation {
        guard hasRealTx else { return .myShareCost }
        return lentAmount > 0 ? .lendingToCompensateReal : .noVirtual
    }
}
