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

    // MARK: - Entidades de SISTEMA: merge determinista-global (política v1, residual gate de flags)

    /// Resultado del pase de entidades de sistema (asertable en tests).
    struct SystemStats: Equatable {
        var accountsMerged = 0
        var subcategoriesMerged = 0
    }

    /// Colapsa las entidades de sistema DUPLICADAS cross-device (dos devices acuñan la suya por nombre
    /// localizado) a un ganador determinista-global (`SystemEntityMergePolicy`), re-apunta las referencias de
    /// las perdedoras y las tombstonea. Ver el doc-comment de `SystemEntityMergePolicy` para el argumento de
    /// convergencia. GESTIONA SUS PROPIOS `save()` bajo autor DEFAULT (NUNCA `outboxSaveAuthor`: el tombstone
    /// y los updates DEBEN drenar/viajar; el cascade `.nullify` debe aplicar ANTES de re-encodear los CSV
    /// mirror o el espejo captaría el `shortcutID` del perdedor que va a morir → huérfano permanente, regla
    /// `899c1c25`). Consumido por `runPostPullReconcilers` (post-páginas; corre DENTRO de la ventana
    /// `markApplyBegan/Ended` — inocuo: la ventana solo difiere la señal de quiescencia, no cambia el autor,
    /// y el save default drena igual) Y por `MigrationWorkExecutor.healDuplicates` (reversa).
    /// `lastUsedDefaults` inyectable para tests.
    @discardableResult
    static func reconcileSystemEntities(
        context: ModelContext,
        lastUsedDefaults: UserDefaults? = UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)
    ) -> SystemStats {
        var stats = SystemStats()
        stats.accountsMerged = mergeSystemAccounts(context: context, lastUsedDefaults: lastUsedDefaults)
        stats.subcategoriesMerged = mergeBalanceAdjustmentSubcategories(context: context)
        return stats
    }

    /// Cuentas `isSystemAccount` duplicadas por `currencyCode`. Ganador por `(name, shortcutID)` asc; re-apunta
    /// TXs/scheduled/favorites/drafts + M2M/CSV `Budget.accounts` + `LastUsedAccountStore`; borra perdedoras.
    private static func mergeSystemAccounts(context: ModelContext, lastUsedDefaults: UserDefaults?) -> Int {
        let accounts: [Account]
        do {
            accounts = try context.fetch(FetchDescriptor<Account>(
                predicate: #Predicate { $0.isSystemAccount == true }))
        } catch {
            #if DEBUG
            print("CloudSyncReconciler.systemAccounts fetch falló: \(error)")
            #endif
            return 0
        }
        let plans = SystemEntityMergePolicy.plan(
            accounts, groupKey: { $0.currencyCode }, name: { $0.name },
            tiebreak: { $0.shortcutID.uuidString })
        guard !plans.isEmpty else { return 0 }

        var merged = 0
        var budgetsToResync: Set<PersistentIdentifier> = []
        var loserShortcutIDs: Set<UUID> = []
        var winnerByLoserShortcutID: [UUID: UUID] = [:]

        for group in plans {
            let winner = group.winner
            // RP-2: el dedup local del bridge ARCHIVA perdedoras; el fetch de `ensureSystemAccount` NO excluye
            // archivadas (no acuñaría una tercera), pero des-archivar a la ganadora garantiza que quede VISIBLE
            // y evita cualquier loop de duplicación si el criterio del bridge cambiara.
            if winner.isArchived { winner.isArchived = false }
            for loser in group.losers {
                loserShortcutIDs.insert(loser.shortcutID)
                winnerByLoserShortcutID[loser.shortcutID] = winner.shortcutID
                for tx in loser.transactions ?? [] { tx.account = winner }
                for sched in loser.scheduledPayments ?? [] { sched.account = winner }
                for fav in loser.favoritePayments ?? [] { fav.account = winner }
                for draft in loser.inboxDrafts ?? [] { draft.account = winner }
                for budget in loser.budgets ?? [] {
                    budgetsToResync.insert(budget.persistentModelID)
                    if (budget.accounts ?? []).allSatisfy({ $0.persistentModelID != winner.persistentModelID }) {
                        if budget.accounts == nil { budget.accounts = [] }
                        budget.accounts?.append(winner)
                    }
                }
                context.delete(loser)
                merged += 1
            }
        }
        guard merged > 0 else { return 0 }

        do {
            try context.save()  // autor DEFAULT + cascade `.nullify` aplica ANTES de re-encodear CSV
            for budget in budgetsToResync.compactMap({ context.model(for: $0) as? Budget }) {
                budget.setAccountIDs(from: budget.accounts ?? [])
            }
            resyncOrphanCSV(loserAccountIDs: loserShortcutIDs, context: context)
            if let defaults = lastUsedDefaults,
               let stored = defaults.string(forKey: AppPreferences.Keys.lastUsedAccountID),
               let storedUUID = UUID(uuidString: stored),
               loserShortcutIDs.contains(storedUUID),
               let winnerShortcutID = winnerByLoserShortcutID[storedUUID] {
                defaults.set(winnerShortcutID.uuidString, forKey: AppPreferences.Keys.lastUsedAccountID)
            }
            if context.hasChanges { try context.save() }
            CloudSyncBreadcrumb.systemEntityMerged(kind: "account", count: merged)
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("CloudSyncReconciler.systemAccounts save falló: \(error)")
            #endif
        }
        return merged
    }

    /// Subcategorías `balanceAdjustment` duplicadas cross-idioma (matching `Subcategory.balanceAdjustmentNames`).
    /// v1: UN grupo lógico por store (no hay dimensión currency; es 1 lógica por usuario). Ganador
    /// `(name, shortcutID)` asc; re-apunta TXs/favorites/scheduled/drafts/merchant/cashFlowLines + M2M/CSV
    /// `Budget.subcategories`; borra perdedoras. NO mergea categorías padre (R5: cada idioma sembró la suya;
    /// la ganadora conserva SU categoría, las TXs de la perdedora van a la ganadora con esa categoría).
    private static func mergeBalanceAdjustmentSubcategories(context: ModelContext) -> Int {
        let candidates: [Subcategory]
        do {
            // Scope a sistema/sembradas (evita adoptar una homónima PERSONAL); balanceAdjustment se siembra
            // con `isDefaultSeed = true` (seed Y `ensureBalanceAdjustmentSubcategoryExists` — ninguno pone
            // `isSystem=true`, así que exigir `isSystem` mataría la política). INVARIANTE del que depende el
            // scope: el path de creación de UI (`SubcategoryDetailView`) pasa `isDefaultSeed: false` explícito
            // → las subcats tecleadas por el usuario quedan FUERA aunque el nombre coincida. Vector residual
            // aceptado: un auto-create futuro con el default (`isDefaultSeed: true`) cuyo nombre caiga en el
            // set multi-idioma entraría al merge — el modelo no registra procedencia (MAPA invariante 11), no
            // hay señal más fuerte. El nombre multi-idioma se filtra en Swift (`#Predicate` no maneja
            // `Set.contains`).
            candidates = try context.fetch(FetchDescriptor<Subcategory>(
                predicate: #Predicate { $0.isSystem || $0.isDefaultSeed }))
        } catch {
            #if DEBUG
            print("CloudSyncReconciler.balanceAdjustment fetch falló: \(error)")
            #endif
            return 0
        }
        let balanceAdj = candidates.filter { Subcategory.balanceAdjustmentNames.contains($0.name) }
        guard balanceAdj.count > 1 else { return 0 }

        let plans = SystemEntityMergePolicy.plan(
            balanceAdj, groupKey: { _ in "balanceAdjustment" }, name: { $0.name },
            tiebreak: { $0.shortcutID.uuidString })
        guard let group = plans.first else { return 0 }
        let winner = group.winner

        var merged = 0
        var budgetsToResync: Set<PersistentIdentifier> = []
        var loserShortcutIDs: Set<UUID> = []
        for loser in group.losers {
            loserShortcutIDs.insert(loser.shortcutID)
            for tx in loser.transactions ?? [] { tx.subcategory = winner }
            for fav in loser.favoritePayments ?? [] { fav.subcategory = winner }
            for sched in loser.scheduledPayments ?? [] { sched.subcategory = winner }
            for draft in loser.inboxDrafts ?? [] { draft.subcategory = winner }
            for mm in loser.merchantMemories ?? [] { mm.subcategory = winner }
            for line in loser.cashFlowLines ?? [] { line.subcategory = winner }
            for budget in loser.budgets ?? [] {
                budgetsToResync.insert(budget.persistentModelID)
                if (budget.subcategories ?? []).allSatisfy({ $0.persistentModelID != winner.persistentModelID }) {
                    if budget.subcategories == nil { budget.subcategories = [] }
                    budget.subcategories?.append(winner)
                }
            }
            context.delete(loser)
            merged += 1
        }
        guard merged > 0 else { return 0 }

        do {
            try context.save()
            for budget in budgetsToResync.compactMap({ context.model(for: $0) as? Budget }) {
                budget.setSubcategoryIDs(from: budget.subcategories ?? [])
            }
            resyncOrphanCSV(loserSubcategoryIDs: loserShortcutIDs, context: context)
            if context.hasChanges { try context.save() }
            CloudSyncBreadcrumb.systemEntityMerged(kind: "balanceAdjustment", count: merged)
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("CloudSyncReconciler.balanceAdjustment save falló: \(error)")
            #endif
        }
        return merged
    }

    /// Nuke-on-nil de los CSV mirror de `Budget` que referencian un `shortcutID` PERDEDOR aunque el
    /// descubrimiento por inversa lo saltara (ventana M2M lazy-nil): un CSV stale-pero-presente NO cae a M2M
    /// → huérfano permanente (regla `899c1c25`). Re-encode desde el M2M actual (ya sin el perdedor tras el
    /// cascade). Solo `Budget` porta CSV mirror de account/subcategory IDs.
    private static func resyncOrphanCSV(
        loserAccountIDs: Set<UUID> = [], loserSubcategoryIDs: Set<UUID> = [], context: ModelContext
    ) {
        do {
            if !loserAccountIDs.isEmpty {
                for budget in try context.fetch(FetchDescriptor<Budget>(
                    predicate: #Predicate<Budget> { $0.accountIDs != nil })) {
                    guard let csv = budget.accountIDsSet, !csv.isDisjoint(with: loserAccountIDs) else { continue }
                    budget.setAccountIDs(from: budget.accounts ?? [])
                }
            }
            if !loserSubcategoryIDs.isEmpty {
                for budget in try context.fetch(FetchDescriptor<Budget>(
                    predicate: #Predicate<Budget> { $0.subcategoryIDs != nil })) {
                    guard let csv = budget.subcategoryIDsSet, !csv.isDisjoint(with: loserSubcategoryIDs) else { continue }
                    budget.setSubcategoryIDs(from: budget.subcategories ?? [])
                }
            }
        } catch {
            #if DEBUG
            print("CloudSyncReconciler.resyncOrphanCSV fetch falló: \(error)")
            #endif
        }
    }
}
