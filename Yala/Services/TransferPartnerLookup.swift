//
//  TransferPartnerLookup.swift
//  Yala
//
//  Helper compartido para resolver el partner de una transferencia por `transferPairID`.
//  Usado por bulk-update operations en `RecordsViewModel` y `TransactionService` para
//  propagar mutaciones a ambos lados del par (note, amount con signo opuesto, tags).
//

import Foundation
import SwiftData

@MainActor
enum TransferPartnerLookup {

    /// Devuelve el partner TX del transfer, excluyendo `tx` mismo.
    /// Returns `nil` si `tx` no es transferencia o el partner no existe localmente.
    /// Si hay collision (3+ TXs sharing pairID), retorna un partner arbitrario — el caller
    /// es responsable de detectar collisions vía `partnerSkipIfAmbiguous`.
    static func partner(of tx: TransactionItem, in context: ModelContext) -> TransactionItem? {
        guard tx.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer,
              let pairID = tx.transferPairID else {
            return nil
        }
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.transferPairID == pairID }
        )
        let pairs: [TransactionItem]
        do {
            pairs = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("TransferPartnerLookup: fetch failed: \(error)")
            #endif
            return nil
        }
        return pairs.first { $0.persistentModelID != tx.persistentModelID }
    }

    /// Devuelve el partner SOLO si hay exactamente UN partner (no collision).
    /// Si hay 0 partners → nil (orphan). Si hay 2+ partners → nil (collision; caller debe skip propagation).
    /// Usado por bulk operations donde propagar a un partner arbitrario en collision profundizaría desync.
    static func partnerSkipIfAmbiguous(of tx: TransactionItem, in context: ModelContext) -> TransactionItem? {
        guard tx.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer,
              let pairID = tx.transferPairID else {
            return nil
        }
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.transferPairID == pairID }
        )
        let pairs: [TransactionItem]
        do {
            pairs = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("TransferPartnerLookup: fetch failed: \(error)")
            #endif
            return nil
        }
        let others = pairs.filter { $0.persistentModelID != tx.persistentModelID }
        guard others.count == 1 else {
            #if DEBUG
            if others.count > 1 {
                print("TransferPartnerLookup: \(others.count + 1) TXs share pairID \(pairID) — skipping partner propagation")
            }
            #endif
            return nil
        }
        return others.first
    }
}
