//
//  TransferPairReconcileService.swift
//  Yala
//
//  Boot-time reconciler for transfer pair integrity. Calca el patrón de
//  `SplitGroupDeduplicationService`. Detecta y repara:
//    1. TXs con `balanceAdjustmentType == transfer` + `transferPairID == nil` (CSV legacy)
//       → empareja por heurística (date day, abs(amount), currency) + signo opuesto balanced.
//    2. `transferPairID` con solo 1 TX (partner missing, multi-device sync race)
//       → clear `transferPairID` y `balanceAdjustmentType` para que se trate como TX normal.
//    3. `transferPairID` compartido por 3+ TXs (collision)
//       → NO auto-repair; reporta telemetría para no borrar data potencialmente válida.
//    4. `transferPairID` malformado (no-UUID, whitespace)
//       → clear (cae al caso 2 si no hay partner válido).
//

import Foundation
import SwiftData

@MainActor
enum TransferPairReconcileService {

    // MARK: - Pure-logic plan

    /// Snapshot mínimo de una TX para la lógica pura. Permite tests sin `ModelContext`.
    struct TransferInfo: Hashable {
        let id: UUID  // identifier local (usa `TransactionItem.id` o un UUID fresh en tests)
        let date: Date
        let amount: Double
        let currencyCode: String
        let transferPairID: String?
        let isTransferType: Bool  // balanceAdjustmentType == "transfer"
    }

    struct ReconcilePlan: Equatable {
        let orphansToClearIDs: [UUID]       // partner missing (1-of-1)
        let malformedToClearIDs: [UUID]     // pairID inválido (no UUID o whitespace)
        let pairings: [Pairing]             // orphans paired by heuristic
        let collisions: [Collision]         // pairID shared by 3+ TXs
    }

    struct Pairing: Equatable {
        let txAID: UUID
        let txBID: UUID
        let pairID: String
    }

    struct Collision: Equatable {
        let pairID: String
        let count: Int
    }

    /// Pure function: dado un set de TransferInfo, devuelve el plan de reconciliación.
    /// Canonicaliza pairIDs a uppercase antes de agrupar — evita false-positive split de TXs
    /// pareadas legítimamente que tengan el mismo UUID en cases distintos (legacy/sync drift).
    nonisolated static func computeReconcilePlan(transactions: [TransferInfo]) -> ReconcilePlan {
        var orphansToClearIDs: [UUID] = []
        var malformedToClearIDs: [UUID] = []
        var collisions: [Collision] = []

        // Agrupa por transferPairID canonical (uppercase) — case-insensitive.
        let withPairID = transactions.filter { $0.transferPairID != nil }
        let byPairID = Dictionary(grouping: withPairID) { $0.transferPairID!.uppercased() }

        for (pairID, group) in byPairID {
            let trimmed = pairID.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || UUID(uuidString: trimmed) == nil {
                // Malformed — clear todos los TXs con este pairID.
                malformedToClearIDs.append(contentsOf: group.map(\.id))
            } else if group.count == 1 {
                // Partner missing — clear este TX.
                orphansToClearIDs.append(contentsOf: group.map(\.id))
            } else if group.count >= 3 {
                // Collision — telemetry only (no auto-repair, heuristic could destroy valid data).
                collisions.append(Collision(pairID: pairID, count: group.count))
            }
            // count == 2: válido, sin acción.
        }

        // Pair orphans: TXs con balanceAdjustmentType=transfer + pairID=nil.
        let unpaired = transactions.filter { $0.isTransferType && $0.transferPairID == nil }
        let pairings = computePairingPlan(orphans: unpaired)

        return ReconcilePlan(
            orphansToClearIDs: orphansToClearIDs,
            malformedToClearIDs: malformedToClearIDs,
            pairings: pairings,
            collisions: collisions
        )
    }

    /// Empareja orphans por (día, abs(amount), currency). SKIP cuando grupo tiene N>2 (ambiguity:
    /// no podemos saber qué negativo va con qué positivo si hay múltiples pares posibles).
    /// Pure function — compartida con `TransactionCSVImportService`.
    nonisolated static func computePairingPlan(orphans: [TransferInfo]) -> [Pairing] {
        struct GroupKey: Hashable {
            let dateKey: Date
            let amountAbs: Double
            let currencyCode: String
        }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: orphans) { tx -> GroupKey in
            GroupKey(
                dateKey: calendar.startOfDay(for: tx.date),
                amountAbs: abs(tx.amount),
                currencyCode: tx.currencyCode
            )
        }

        var result: [Pairing] = []
        for (_, group) in grouped {
            let negatives = group.filter { $0.amount < 0 }
            let positives = group.filter { $0.amount > 0 }

            // Solo emparejar grupos N=2 (1 neg + 1 pos). N>2 es ambiguous — no podemos saber
            // qué negativo corresponde a qué positivo sin más contexto (cuentas, descripción).
            // Skip para evitar emparejar transfers no relacionadas.
            guard negatives.count == 1, positives.count == 1 else { continue }

            result.append(Pairing(
                txAID: negatives[0].id,
                txBID: positives[0].id,
                pairID: UUID().uuidString
            ))
        }
        return result
    }

    // MARK: - Context wrapper

    /// Reconcilia transfer pairs en el contexto. Idempotente — re-ejecuciones sin orphans no hacen nada.
    @discardableResult
    static func reconcileTransferPairs(in context: ModelContext) -> ReconcilePlan {
        let transferTypeRaw = TransactionItem.adjustmentTypeTransfer
        let txs: [TransactionItem]
        do {
            // Predicate específico filtra al subset transfer-related (evita full-table scan en
            // DBs grandes). Nil guard explícito en balanceAdjustmentType evita edge case en
            // stores CloudKit-backed donde Optional + OR clauses pueden devolver resultados
            // vacíos silenciosamente.
            let descriptor = FetchDescriptor<TransactionItem>(
                predicate: #Predicate { tx in
                    (tx.balanceAdjustmentType != nil && tx.balanceAdjustmentType == transferTypeRaw)
                    || tx.transferPairID != nil
                }
            )
            txs = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("TransferPairReconcile: fetch failed: \(error)")
            #endif
            return ReconcilePlan(orphansToClearIDs: [], malformedToClearIDs: [], pairings: [], collisions: [])
        }

        // Mapping local UUID → TX para resolver de vuelta tras pure-logic. TransactionItem
        // no tiene UUID propio (solo persistentModelID), así que generamos identifiers locales.
        var idMap: [UUID: TransactionItem] = [:]
        let infos = txs.map { tx -> TransferInfo in
            let localID = UUID()
            idMap[localID] = tx
            return TransferInfo(
                id: localID,
                date: tx.date,
                amount: tx.amount,
                currencyCode: tx.currencyCode,
                transferPairID: tx.transferPairID,
                isTransferType: tx.balanceAdjustmentType == transferTypeRaw
            )
        }

        let plan = computeReconcilePlan(transactions: infos)

        let hasChanges = !plan.orphansToClearIDs.isEmpty
            || !plan.malformedToClearIDs.isEmpty
            || !plan.pairings.isEmpty
        guard hasChanges || !plan.collisions.isEmpty else { return plan }

        // Apply: clear orphans + malformed.
        let toClearSet = Set(plan.orphansToClearIDs + plan.malformedToClearIDs)
        for id in toClearSet {
            if let tx = idMap[id] {
                tx.transferPairID = nil
                tx.balanceAdjustmentType = nil
            }
        }

        // Apply: pairings (asigna mismo pairID a ambos lados).
        for pairing in plan.pairings {
            idMap[pairing.txAID]?.transferPairID = pairing.pairID
            idMap[pairing.txBID]?.transferPairID = pairing.pairID
        }

        // Save + telemetry.
        if hasChanges {
            do {
                try context.save()
                #if DEBUG
                print("TransferPairReconcile: cleared=\(toClearSet.count) paired=\(plan.pairings.count) collisions=\(plan.collisions.count)")
                #endif
                TelemetryService.cloudkitTransferOrphanRepaired(
                    orphansCleared: toClearSet.count,
                    pairedCount: plan.pairings.count
                )
            } catch {
                #if DEBUG
                print("TransferPairReconcile: save failed: \(error)")
                #endif
            }
        }
        for collision in plan.collisions {
            TelemetryService.cloudkitTransferCollisionDetected(count: collision.count)
        }
        return plan
    }
}
