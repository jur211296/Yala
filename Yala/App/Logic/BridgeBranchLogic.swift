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

    // MARK: - Partición del cleanup de TX virtuales (Caso B preserve+update)

    /// Forma de una TX virtual existente (cuenta sistema, mismo `splitExpenseID`) para
    /// clasificarla en el cleanup del bridge. Valores planos → testeable sin `ModelContext`.
    struct VirtualTxShape: Equatable {
        /// La TX no tiene subcategoría (nunca clasificada).
        let subcategoryIsNil: Bool
        /// Su subcategoría es de sistema (solo relevante si `!subcategoryIsNil`).
        let subcategoryIsSystem: Bool
        /// Porta metadatos del usuario: subcat de usuario, tags, o `needOverride`.
        let hasUserMetadata: Bool
        /// Fecha del gasto (para desempate por antigüedad).
        let date: Date
        /// Timestamp de creación (desempate estable secundario).
        let createdAt: Date
    }

    /// Resultado de particionar las TX virtuales: el índice de la ÚNICA clasificable a
    /// preservar (portadora de metadatos del Caso B `-myShare`), y los índices a borrar
    /// (derivadas: lent/opening-balance con subcat de sistema + clasificables duplicadas
    /// perdedoras).
    struct VirtualTxPartition: Equatable {
        /// Índice de la TX clasificable a preservar (nil si ninguna es clasificable).
        let preservedIndex: Int?
        /// Índices a borrar (orden estable ascendente).
        let deletedIndices: [Int]
    }

    /// Particiona las TX virtuales de un gasto entre la clasificable a preservar y las
    /// derivadas/duplicadas a borrar.
    ///
    /// **Clasificable** = `subcategoryIsNil || !subcategoryIsSystem`. Es la única virtual
    /// que puede portar metadatos del usuario (la `-myShare` del Caso B, cuya subcat es nil
    /// o de usuario). Las derivadas (lent `loanToGroups`, opening balance) nacen SIEMPRE con
    /// subcat de sistema → nunca clasificables.
    ///
    /// **Duplicadas clasificables** (bug histórico de delete+recreate con UUIDs distintos):
    /// gana la que tenga metadatos del usuario; empate → la más antigua por `date`, luego
    /// `createdAt`, luego índice (determinista). Las perdedoras se borran.
    ///
    /// Residual documentado: el determinismo es por-INPUT — dos devices
    /// con duplicadas aún no sincronizadas pueden elegir winners DISTINTOS y borrarse
    /// mutuamente (ventana transitoria sin `-myShare`, misma clase que el hazard I11-4 de
    /// CLAUDE.md). Auto-sana: el siguiente re-bridge recrea la virtual; en estado sincronizado
    /// ambos devices convergen al mismo winner.
    static func partitionVirtualTxs(_ shapes: [VirtualTxShape]) -> VirtualTxPartition {
        var classifiable: [Int] = []
        var derived: [Int] = []
        for (i, s) in shapes.enumerated() {
            if s.subcategoryIsNil || !s.subcategoryIsSystem {
                classifiable.append(i)
            } else {
                derived.append(i)
            }
        }
        guard !classifiable.isEmpty else {
            return VirtualTxPartition(preservedIndex: nil, deletedIndices: derived.sorted())
        }
        let winner = classifiable.min { a, b in
            let sa = shapes[a], sb = shapes[b]
            // Prioridad: con metadatos de usuario primero.
            if sa.hasUserMetadata != sb.hasUserMetadata { return sa.hasUserMetadata }
            // Empate → más antigua (date, luego createdAt, luego índice).
            if sa.date != sb.date { return sa.date < sb.date }
            if sa.createdAt != sb.createdAt { return sa.createdAt < sb.createdAt }
            return a < b
        }!
        let deleted = (derived + classifiable.filter { $0 != winner }).sorted()
        return VirtualTxPartition(preservedIndex: winner, deletedIndices: deleted)
    }
}
