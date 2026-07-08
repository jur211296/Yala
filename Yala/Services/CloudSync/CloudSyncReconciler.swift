//
//  CloudSyncReconciler.swift
//  Yala
//
//  Reconciliadores CROSS-FILA post-pull del Modo Nube (incremento I8f-2). El LWW por-unidad de I8f-1
//  converge cada FILA, pero dos invariantes del dominio viven ENTRE filas y pueden divergir tras un
//  merge: (1) los dos lados de una transferencia deben espejar el mismo |monto| (SERIO 4) y (2) un
//  `splitExpenseID` debe tener ≤1 representación personal (C3 RED — la forma ON {real, +lent} y la
//  forma OFF {virtual −myShare} pueden coexistir tras cruzar devices con bridge distinto).
//
//  Corren al FINAL de `pullAndApplyOnce` (tras la re-resolución de danglers) SOLO si el ciclo aplicó
//  ≥1 página; cada uno en su propio save con rollback-on-fail, bajo autor NORMAL — sus writes DEBEN
//  drenar/subir (el próximo drain los captura y la expansión de grupo del emitter garantiza que el
//  money viaja ENTERO). NO tocan nada de Grupos (solo `TransactionItem`/`Account`, store personal).
//
//  Reglas duras:
//   - Desempate del transfer-pair por `SyncUnitClock['money']` (HLC de COLUMNA), JAMÁS por HLC de
//     fila ni `date`/`createdAt` — golden SERIO 4 D1/D2/D3.
//   - Rama conservadora: sin señal de clock en CUALQUIER lado → NO tocar + `reconcilerNoSignal`
//     (jamás adivinar con un monto).
//   - La poda del split BORRA datos financieros → firma de violación ESTRICTA (ambas formas
//     presentes) y nunca crea/reconstruye.
//
//  RESIDUAL declarado (review): la reparación del transfer-pair mintea un HLC fresco al drenarse y
//  puede ganarle vía LWW a una edición legítima de `money` PENDIENTE en otro device (no pusheada aún).
//  Raro, acotado, converge; observable en agregado por el canario S11 (`cloudSyncSuspectClockWin`).
//  Sin fix barato sin mutation_log — aceptado.
//

import Foundation
import SwiftData

@MainActor
enum CloudSyncReconciler {

    // MARK: - Transfer-pair divergence (SERIO 4, D-B)

    /// Resultado del pase de transfer-pairs (asertable en tests; los breadcrumbs no lo son).
    struct TransferStats: Equatable {
        var repaired = 0
        var noSignal = 0
    }

    /// Reconcilia pares de transferencia cuyos `abs(amount)` divergen. SOLO pares VÁLIDOS:
    /// `transferPairID` compartido por EXACTAMENTE 2 lados y MISMO `currencyCode` (un par
    /// cross-currency tiene |amounts| distintos POR DISEÑO → skip silencioso, no es anomalía).
    /// Ganador = el lado cuyo `SyncUnitClock['money']` es más reciente. MUTA sin `save()` — el caller
    /// (SyncApplyEngine) hace el save bajo autor normal con rollback-on-fail.
    ///
    /// NO toca `TransferPairReconcileService` (boot heurístico para orphans/malformed) — esta regla es
    /// LWW post-pull, aquella es reparación estructural sin HLCs; conviven.
    static func reconcileTransferPairDivergence(context: ModelContext) -> TransferStats {
        var stats = TransferStats()
        let txs: [TransactionItem]
        do {
            txs = try context.fetch(FetchDescriptor<TransactionItem>(
                predicate: #Predicate { $0.transferPairID != nil }
            ))
        } catch {
            #if DEBUG
            print("CloudSyncReconciler.transferPair fetch falló: \(error)")
            #endif
            return stats
        }

        var byPair: [String: [TransactionItem]] = [:]
        for tx in txs {
            guard let pairID = tx.transferPairID, !pairID.isEmpty else { continue }
            byPair[pairID, default: []].append(tx)
        }

        for (pairID, sides) in byPair {
            // Solo pares válidos de 2 lados (colisiones 3+ = scope del boot-service, fuera aquí).
            guard sides.count == 2 else { continue }
            let a = sides[0], b = sides[1]
            // Cross-currency: |amounts| distintos POR DISEÑO → no es divergencia.
            guard a.currencyCode == b.currencyCode else { continue }
            // Sin divergencia de magnitud → nada que reparar. Scope declarado: el invariante es sobre
            // |amount|; una divergencia SOLO de `amountInPreferredCurrency` (con |amount| igual) no se
            // repara aquí (corrupción rara fuera del invariante del par — la audita Merkle, I8f-3).
            guard abs(abs(a.amount) - abs(b.amount)) > 0.0001 else { continue }

            // Señal: `SyncUnitClock['money']` de AMBOS lados, parseado. Sin señal en cualquiera (sin
            // syncID / sin fila / sin unidad / no parsea) o EMPATE exacto (inordenable) → conservador.
            guard let hlcA = moneyHLC(a, context: context),
                  let hlcB = moneyHLC(b, context: context),
                  hlcA != hlcB else {
                stats.noSignal += 1
                CloudSyncBreadcrumb.reconcilerNoSignal(pairID: pairID)
                continue
            }

            let (winner, loser) = hlcA > hlcB ? (a, b) : (b, a)
            // Reparación: el grupo `money` ENTERO coherente del ganador, al perdedor — magnitudes del
            // ganador con el SIGNO del lado perdedor (las dos patas de una transferencia son espejo).
            // El SIGNO del perdedor se PRESERVA, nunca se corrige: reparar signos (par mismo-signo,
            // amount==0) es dominio del boot-heurístico `TransferPairReconcileService` — aquí solo la
            // MAGNITUD del grupo money. División de labor consciente.
            let loserSign: Double = loser.amount < 0 ? -1 : 1
            loser.amount = abs(winner.amount) * loserSign
            loser.amountInPreferredCurrency = abs(winner.amountInPreferredCurrency) * loserSign
            loser.exchangeRate = winner.exchangeRate
            loser.preferredCurrencyCode = winner.preferredCurrencyCode
            loser.isExchangeRateProvisional = winner.isExchangeRateProvisional
            stats.repaired += 1
            CloudSyncBreadcrumb.reconcilerRepairedPair(pairID: pairID)
        }
        return stats
    }

    /// `SyncUnitClock['money']` de una TX, o `nil` si no hay señal (sin syncID / sin fila / sin unidad
    /// / HLC no parseable).
    private static func moneyHLC(_ tx: TransactionItem, context: ModelContext) -> HLC? {
        guard let syncID = tx.syncID else { return nil }
        return SyncUnitClockStore.unitHLC(syncID: syncID, unit: "money", context: context)
    }

    // MARK: - Split: un `split_expense_id` → ≤1 representación (C3 RED, D-C)

    /// Resultado del pase de splits.
    struct SplitStats: Equatable {
        var pruned = 0
    }

    /// Poda la coexistencia de las dos formas del bridge para un mismo `splitExpenseID`. SOLO expenses
    /// (`splitSettlementID` FUERA del scope v1); SOLO poda, nunca crea.
    ///
    /// Firma de violación (conservadora): para el mismo `splitExpenseID` existen A LA VEZ
    /// (i) ≥1 TX REAL (`account?.isSystemAccount == false`) y (ii) ≥1 TX VIRTUAL NEGATIVA
    /// (`isSystemAccount == true && amount < 0`). La virtual POSITIVA `+lent` es parte de la forma ON,
    /// no violación; el par M5 `.groupInvite` (2 virtuales, una positiva) jamás dispara.
    ///
    /// **REGLA INTERINA (review I8f-2, anclada al DATO, no a la preferencia): cuando ambas formas están
    /// presentes gana SIEMPRE la representación REAL** → se podan las virtuales NEGATIVAS y {real, +lent}
    /// sobreviven. Razón: anclar a `effectiveBridgeEnabled` LOCAL es device-dependent (esa divergencia
    /// ES la causa de C3) → dos devices con effective opuesto podarían formas DISTINTAS y el cruce de
    /// tombstones borraría el gasto ENTERO en ambos. "Real gana" es determinista cross-device sin estado
    /// sincronizado, no puede producir borrado mutuo, y es consistente con producto (apagar el bridge
    /// nunca borra retroactivamente TXs bridgeadas). REVISAR EN I9 cuando el override sincronizado de
    /// `group_bridge_prefs` esté cableado.
    ///
    /// Los deletes van bajo autor NORMAL (vía el save del caller) → el drain emite tombstones con HLC
    /// fresco (= `deleted_hlc` server > cualquier delta stale de la forma perdedora) → terminación por
    /// la regla servidor delete-vs-upsert (§d.4 cat.3, ya desplegada) — el device rezagado NO resucita.
    static func reconcileSplitRepresentations(context: ModelContext) -> SplitStats {
        var stats = SplitStats()
        let txs: [TransactionItem]
        do {
            txs = try context.fetch(FetchDescriptor<TransactionItem>(
                predicate: #Predicate { $0.splitExpenseID != nil }
            ))
        } catch {
            #if DEBUG
            print("CloudSyncReconciler.split fetch falló: \(error)")
            #endif
            return stats
        }

        var byExpense: [String: [TransactionItem]] = [:]
        for tx in txs {
            guard let expenseID = tx.splitExpenseID, !expenseID.isEmpty else { continue }
            byExpense[expenseID, default: []].append(tx)
        }

        for (expenseID, group) in byExpense {
            var hasReal = false
            var virtualNegatives: [TransactionItem] = []
            for tx in group {
                // Guard de clasificación: `account == nil` (p.ej. dangler I8f-1 sin resolver) es
                // NO-clasificable → no participa (ni se poda ni cuenta como "forma presente").
                guard let account = tx.account else { continue }
                if account.isSystemAccount {
                    if tx.amount < 0 { virtualNegatives.append(tx) }
                } else {
                    hasReal = true
                }
            }
            // Solo poda cuando AMBAS formas están presentes — si solo existe la forma "perdedora", no
            // se toca (borrarla dejaría el gasto sin representación; bridge/pull convergen solos).
            guard hasReal, !virtualNegatives.isEmpty else { continue }
            for tx in virtualNegatives {
                context.delete(tx)
            }
            stats.pruned += virtualNegatives.count
            CloudSyncBreadcrumb.reconcilerPrunedSplit(splitExpenseID: expenseID,
                                                      count: virtualNegatives.count)
        }
        return stats
    }
}
