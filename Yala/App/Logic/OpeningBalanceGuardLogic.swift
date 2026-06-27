//
//  OpeningBalanceGuardLogic.swift
//  Yala
//
//  Pure-logic helper: decide si editar/eliminar un saldo inicial debe bloquearse
//  porque ya hay liquidaciones confirmadas que lo referencian indirectamente.
//
//  A diferencia del guard GLOBAL de `deleteExpense` (bloquea con CUALQUIER settlement
//  confirmado posterior — demasiado grueso para saldos iniciales fechados en t=0), este
//  guard es TARGETED: solo bloquea si una liquidación confirmada involucra al deudor o al
//  acreedor de ESA arista. Editar el saldo de un par que ya liquidó corrompería el neto
//  histórico que se saldó.
//

import Foundation

enum OpeningBalanceGuardLogic {

    /// `true` si hay que bloquear la edición/eliminación del saldo inicial.
    /// - Parameters:
    ///   - edgeMembers: los dos miembros de la arista (deudor + acreedor).
    ///   - confirmedSettlementPairs: pares (from, to) de las liquidaciones confirmadas del grupo.
    static func isBlocked(
        edgeMembers: Set<String>,
        confirmedSettlementPairs: [(from: String, to: String)]
    ) -> Bool {
        confirmedSettlementPairs.contains {
            edgeMembers.contains($0.from) || edgeMembers.contains($0.to)
        }
    }
}
