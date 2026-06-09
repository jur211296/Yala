//
//  BulkApproveRoutingLogic.swift
//  Yala
//
//  Pure-logic del ruteo de `DraftService.bulkApprove`: decide si un draft se finaliza por
//  el path genérico inline (crear TransactionItem nueva) o se delega a `approveDraft`, que
//  es la SSOT del ruteo de drafts de grupo (settlement opt-in, groupExpense pendiente-cuenta,
//  TX-puntero con fallback anti-fantasma, groupSettlement D7).
//
//  Razón: el path genérico inline de `bulkApprove` insertaría una TransactionItem nueva sin
//  `splitExpenseID` para un draft de grupo → doble conteo del gasto + la TX virtual del bridge
//  quedaría sin subcategoría. Delegar a `approveDraft` evita duplicar esa lógica densa.
//
//  Testeable sin SwiftData/ModelContext (R8).
//

import Foundation

enum BulkApproveRoutingLogic {

    /// Destino de un draft dentro de `bulkApprove`.
    enum DraftDestination: Equatable {
        /// Drafts de grupo: `approveDraft` es la SSOT del ruteo (no replicar inline).
        case delegateToIndividual
        /// Drafts personales: crear la TransactionItem nueva en el path genérico inline.
        case genericInline
    }

    static func destination(isFromGroup: Bool) -> DraftDestination {
        isFromGroup ? .delegateToIndividual : .genericInline
    }
}
