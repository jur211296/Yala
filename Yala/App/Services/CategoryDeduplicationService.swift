//
//  CategoryDeduplicationService.swift
//  Yala
//
//  Merges duplicate seed categories that can arise when iCloud sync delivers
//  categories while the local device also runs seedCategoriesIfNeeded().
//

import Foundation
import SwiftData

@MainActor
enum CategoryDeduplicationService {

    /// Returns the stable identity key for a category (iconName + colorHex + isIncome).
    static func identityKey(for category: Category) -> String {
        "\(category.iconName ?? "nil")|\(category.colorHex)|\(category.isIncome)"
    }

    /// Deduplicates seed categories by stable identity (iconName + colorHex + isIncome).
    /// Keeps the category with the most transactions and re-parents orphaned data.
    /// - Returns: number of duplicate categories removed.
    @discardableResult
    static func deduplicateSeedCategories(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate<Category> { $0.isDefaultSeed == true }
        )

        let seedCategories: [Category]
        do {
            seedCategories = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("CategoryDedup: Error fetching seed categories: \(error)")
            #endif
            return 0
        }

        // Group by stable identity: iconName + colorHex + isIncome
        let grouped = Dictionary(grouping: seedCategories) { identityKey(for: $0) }

        var removedCount = 0
        // Track budgets touched durante el dedup para resync CSV mirror DESPUÉS
        // del save (cuando cascade `.nullify` de subs borradas ya aplicó al M2M).
        // Sin esto, el CSV captura UUIDs de subs duplicadas que serán borradas,
        // dejando huérfanos permanentes en el CSV.
        var budgetsToResync: Set<PersistentIdentifier> = []

        for (_, group) in grouped where group.count > 1 {
            // Keep the one with most transactions
            let sorted = group.sorted { ($0.transactions?.count ?? 0) > ($1.transactions?.count ?? 0) }
            let keeper = sorted[0]
            let duplicates = sorted.dropFirst()
            let keeperSeedSubs = (keeper.subcategories ?? []).filter { $0.isDefaultSeed }

            for duplicate in duplicates {
                for sub in (duplicate.subcategories ?? []) where sub.isDefaultSeed {
                    if let match = keeperSeedSubs.first(where: { $0.iconName == sub.iconName }) {
                        reparentInverseRelationships(from: sub, to: match, budgetsToResync: &budgetsToResync)
                        sub.category = nil
                        context.delete(sub)
                    } else {
                        sub.category = keeper
                    }
                }

                // Custom subs nunca se mergean con seed: el match por iconName es coincidencia
                // visual, no equivalencia semántica. Se re-parentean al keeper preservando identidad.
                for sub in (duplicate.subcategories ?? []) where !sub.isDefaultSeed {
                    sub.category = keeper
                }

                // Re-parent category-level transactions
                for tx in duplicate.transactions ?? [] {
                    tx.category = keeper
                }

                // Re-parent budgets
                for budget in duplicate.budgets ?? [] {
                    budget.category = keeper
                }

                context.delete(duplicate)
                removedCount += 1
            }
        }

        if removedCount > 0 {
            do {
                try context.save()
                // POST-save resync: cascade `.nullify` ya aplicó al M2M de los budgets
                // afectados. Re-encode CSV desde el M2M actual (sin UUIDs huérfanos).
                let affectedBudgets = budgetsToResync.compactMap { context.model(for: $0) as? Budget }
                for budget in affectedBudgets {
                    budget.setSubcategoryIDs(from: budget.subcategories ?? [])
                }
                try context.save()
                #if DEBUG
                print("CategoryDedup: Removed \(removedCount) duplicate seed categories — resynced CSV for \(affectedBudgets.count) budgets")
                #endif
            } catch {
                #if DEBUG
                print("CategoryDedup: Error saving after dedup: \(error)")
                #endif
            }
        }

        return removedCount
    }

    // MARK: - Subcategory-level dedup (copias intra-categoría)

    /// Deduplica subcategorías seed duplicadas DENTRO de una misma categoría —
    /// el caso que `deduplicateSeedCategories` no cubre (categorías ×1, subcats ×N).
    /// Fusiona cada grupo en su keeper determinista (ver `SubcategoryDedupLogic`),
    /// reparenta todas las relaciones inversas por UNIÓN (cero pérdida de datos) y
    /// resincroniza el CSV mirror de los budgets afectados.
    ///
    /// Nota: el dedup de categorías fusiona subcats por `iconName`; este pase usa
    /// identidad `(categoría, sortOrder, iconName, name)`. Conviven a propósito —
    /// este pase recoge lo que aquel deje. NO alinear ambos criterios.
    @discardableResult
    static func deduplicateSeedSubcategories(in context: ModelContext) -> Int {
        let subcategories: [Subcategory]
        do {
            subcategories = try context.fetch(FetchDescriptor<Subcategory>(
                predicate: #Predicate<Subcategory> { $0.isDefaultSeed == true }
            ))
        } catch {
            #if DEBUG
            print("SubcatDedup: Error fetching seed subcategories: \(error)")
            #endif
            return 0
        }

        let groups = SubcategoryDedupLogic.duplicateGroups(in: subcategories)
        guard !groups.isEmpty else { return 0 }

        var budgetsToResync: Set<PersistentIdentifier> = []
        var removedCount = 0
        for group in groups {
            for duplicate in group.duplicates {
                reparentInverseRelationships(from: duplicate, to: group.keeper, budgetsToResync: &budgetsToResync)
                duplicate.category = nil
                context.delete(duplicate)
                removedCount += 1
            }
        }

        guard removedCount > 0 else { return 0 }
        do {
            try context.save()
            // POST-save resync: cascade `.nullify` ya aplicó. Re-encode CSV desde el M2M actual.
            let affectedBudgets = budgetsToResync.compactMap { context.model(for: $0) as? Budget }
            for budget in affectedBudgets {
                budget.setSubcategoryIDs(from: budget.subcategories ?? [])
            }
            try context.save()
            #if DEBUG
            print("SubcatDedup: Removed \(removedCount) duplicate seed subcategories across \(groups.count) groups — resynced CSV for \(affectedBudgets.count) budgets")
            #endif
            for group in groups {
                TelemetryService.cloudkitDuplicateDetected(
                    model: "Subcategory",
                    count: group.duplicates.count + 1,
                    context: .bootCleanup,
                    keySuffix: group.keeper.shortcutID.uuidString
                )
            }
        } catch {
            #if DEBUG
            print("SubcatDedup: Error saving after dedup: \(error)")
            #endif
        }
        return removedCount
    }

    /// Corre el dedup completo: categorías PRIMERO (colapsa duplicados + mergea sus
    /// subcats por iconName), subcategorías DESPUÉS (limpia duplicados intra-categoría).
    @discardableResult
    static func runAllDeduplication(in context: ModelContext) -> Int {
        let categories = deduplicateSeedCategories(in: context)
        let subcategories = deduplicateSeedSubcategories(in: context)
        // Después de asentar los merges de entidad: reparar UUIDs de identidad
        // colapsados (Tag.id / Account.shortcutID / Subcategory.shortcutID).
        let identityRepairs = repairCollapsedIdentityUUIDs(in: context)
        // Backfill eager del CSV mirror de presupuestos cuya M2M ya está hidratada pero
        // cuyo espejo CSV quedó vacío/desincronizado (filtro perdido tras un restore lento
        // de iCloud → el cálculo lo lee como "sin filtros" y cuenta todo el periodo).
        let csvBackfills = backfillBudgetCSVMirrorsFromM2M(in: context)
        return categories + subcategories + identityRepairs + csvBackfills
    }

    // MARK: - Gating (quiescencia + retry diferido + throttle)

    private static var lastDedupRunAt: Date?
    private static var pendingRetryScheduled = false
    private static var accountTagDuplicatesReported = false

    /// Corre el dedup SOLO si el sync de CloudKit está quieto (ver `SubcategoryDedupGate`).
    /// Si está dentro de la ventana de silencio, programa UN retry diferido — así el
    /// trailing edge del observer (3 s) no se "pierde" cuando la quietWindow es mayor.
    /// `.syncing`/`.throttled` no hacen nada: el próximo trigger reintenta.
    static func runDedupIfQuiescent(in context: ModelContext) {
        let decision = SubcategoryDedupGate.decide(
            now: .now,
            lastImportDate: iCloudSyncService.shared.lastSuccessfulImportDate,
            isSyncing: iCloudSyncService.shared.status.isSyncing,
            lastDedupRunAt: lastDedupRunAt
        )
        switch decision {
        case .run:
            lastDedupRunAt = .now
            runAllDeduplication(in: context)
            // Detección Account/Tag: una vez por sesión basta (telemetría read-only; el
            // primer pase post-migración ya tiene el sync convergido — momento ideal).
            if !accountTagDuplicatesReported {
                accountTagDuplicatesReported = true
                reportPotentialAccountTagDuplicates(in: context)
            }
        case .syncing, .throttled:
            break
        case .waitQuiescence(let retryAfter):
            guard !pendingRetryScheduled else { break }
            pendingRetryScheduled = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(retryAfter + 1))  // +1s de margen
                pendingRetryScheduled = false  // reset garantizado (try? no propaga la cancelación)
                guard !Task.isCancelled else { return }
                runDedupIfQuiescent(in: context)
            }
        }
    }

    // MARK: - Account/Tag duplicate detection (read-only, solo telemetría)

    /// Cuenta posibles copias idénticas de Account y Tag (mismo detonante que las
    /// subcats: regen de shortcutID/id + re-sync) y las reporta a telemetría. NO borra
    /// nada — confirma con datos reales si hay que abordar un dedup de Account/Tag.
    static func reportPotentialAccountTagDuplicates(in context: ModelContext) {
        do {
            let accounts = try context.fetch(FetchDescriptor<Account>())
            for group in AccountTagDuplicateCountLogic.duplicateGroups(accounts, identity: AccountTagDuplicateCountLogic.accountIdentity) {
                TelemetryService.cloudkitDuplicateDetected(
                    model: "Account", count: group.count, context: .bootCleanup, keySuffix: group.identity
                )
            }
            let tags = try context.fetch(FetchDescriptor<Tag>())
            for group in AccountTagDuplicateCountLogic.duplicateGroups(tags, identity: AccountTagDuplicateCountLogic.tagIdentity) {
                TelemetryService.cloudkitDuplicateDetected(
                    model: "Tag", count: group.count, context: .bootCleanup, keySuffix: group.identity
                )
            }
        } catch {
            #if DEBUG
            print("AccountTagDupDetect: fetch failed: \(error)")
            #endif
        }
    }

    // MARK: - Identity UUID collision repair (Tag.id / Account.shortcutID / Subcategory.shortcutID)

    /// Repara UUIDs de identidad colapsados al mismo valor — el caso donde CloudKit
    /// entrega records sin el campo persistido y SwiftData comparte el default `UUID()`
    /// entre todos (chips/filtros de tags colapsados, presupuestos sumando todas las
    /// subcategorías). Repetible, a diferencia del one-shot
    /// `migrateShortcutIDsAndRebuildCSVMirrors`, que queda bloqueado por su sentinel si
    /// corrió con datos incompletos en un restore lento.
    ///
    /// Solo regenera los UUIDs colisionados (preserva los únicos sincronizados de otros
    /// devices) y reconstruye SOLO los CSV mirrors que referenciaban el valor viejo
    /// (sweep con guard de intersección → completo sin sync storm). Debe correr bajo
    /// quiescencia (ver `runDedupIfQuiescent`) para que la M2M esté hidratada: si una
    /// M2M forward viene `nil` se salta — nunca se nukea, para no perder tags.
    ///
    /// - Returns: número de entidades cuyo UUID fue regenerado.
    @discardableResult
    static func repairCollapsedIdentityUUIDs(in context: ModelContext) -> Int {
        do {
            let accounts = try context.fetch(FetchDescriptor<Account>())
            let subcategories = try context.fetch(FetchDescriptor<Subcategory>())
            let tags = try context.fetch(FetchDescriptor<Tag>())

            let collidedAccounts = collidedUUIDItems(accounts, keyPath: \.shortcutID)
            let collidedSubs = collidedUUIDItems(subcategories, keyPath: \.shortcutID)
            let collidedTags = collidedUUIDItems(tags, keyPath: \.id)

            guard !collidedAccounts.isEmpty || !collidedSubs.isEmpty || !collidedTags.isEmpty else {
                return 0
            }

            // Snapshot de los valores colapsados ANTES de regenerar — el sweep re-encodea
            // solo los CSV que referencian estos ids (mínimo de escrituras dirty).
            let oldAccIDs = Set(collidedAccounts.map(\.shortcutID))
            let oldSubIDs = Set(collidedSubs.map(\.shortcutID))
            let oldTagIDs = Set(collidedTags.map(\.id))

            for account in collidedAccounts { account.shortcutID = UUID() }
            for sub in collidedSubs { sub.shortcutID = UUID() }
            for tag in collidedTags { tag.id = UUID() }

            // Budget: 3 CSV mirrors. Re-encodear desde la M2M forward si el CSV intersecta un
            // id viejo. `?? []` cubre el caso M2M lazy-nil (en paths sin gate de quiescencia:
            // force-sync/botón DEBUG): re-encodear con [] NUKEA el CSV → fuerza el fallback a
            // M2M en lectura (auto-heal), en vez de dejar el CSV stale, que orfanaría permanente
            // (el resolver lee CSV-first y NO cae a M2M si el CSV no es nil). Coherente con el
            // nuke-on-nil del one-shot (`MigrationBackfillLogic.decideAction`). El guard
            // `!old*.isEmpty` evita decodear CSV de relaciones sin colisión (común: solo tags).
            let budgets = try context.fetch(FetchDescriptor<Budget>())
            for budget in budgets {
                if !oldAccIDs.isEmpty, let csv = budget.accountIDsSet, !csv.isDisjoint(with: oldAccIDs) {
                    budget.setAccountIDs(from: budget.accounts ?? [])
                }
                if !oldSubIDs.isEmpty, let csv = budget.subcategoryIDsSet, !csv.isDisjoint(with: oldSubIDs) {
                    budget.setSubcategoryIDs(from: budget.subcategories ?? [])
                }
                if !oldTagIDs.isEmpty, let csv = budget.tagIDsSet, !csv.isDisjoint(with: oldTagIDs) {
                    budget.setTagIDs(from: budget.tags ?? [])
                }
            }

            // TX/Draft/Favorite/Scheduled: solo mirror de tags.
            if !oldTagIDs.isEmpty {
                rebuildTagCSVMirrors(in: context, oldTagIDs: oldTagIDs)
            }

            try context.save()
            SessionState.shared.incrementDataVersion()

            // Telemetría por modelo (keySuffix distingue de la detección por contenido
            // de `reportPotentialAccountTagDuplicates`). El count cae tras el rollout.
            for (model, count) in [("Tag", collidedTags.count), ("Account", collidedAccounts.count), ("Subcategory", collidedSubs.count)] where count > 0 {
                TelemetryService.cloudkitDuplicateDetected(model: model, count: count, context: .bootCleanup, keySuffix: "id-collision")
            }
            #if DEBUG
            print("CategoryDeduplicationService: repairCollapsedIdentityUUIDs — tags=\(collidedTags.count) accounts=\(collidedAccounts.count) subs=\(collidedSubs.count)")
            #endif
            return collidedAccounts.count + collidedSubs.count + collidedTags.count
        } catch {
            #if DEBUG
            print("CategoryDeduplicationService: repairCollapsedIdentityUUIDs error: \(error)")
            #endif
            return 0
        }
    }

    /// Re-encodea los CSV `tagIDs` de TX/Draft/Favorite/Scheduled cuyo CSV referencia
    /// un id de tag viejo (colapsado) y cuya M2M esté hidratada. Necesario tras regenerar
    /// `Tag.id`: el resolver lee CSV-first y NO cae a M2M si el CSV está stale-pero-presente
    /// (`resolvedTagIDs` solo hace fallback cuando el CSV es nil) → sin esto, esos records
    /// quedarían con la etiqueta huérfana de forma permanente.
    private static func rebuildTagCSVMirrors(in context: ModelContext, oldTagIDs: Set<UUID>) {
        func intersectsOld(_ csv: Set<UUID>?) -> Bool {
            guard let csv else { return false }
            return !csv.isDisjoint(with: oldTagIDs)
        }
        // El `#Predicate { tagIDs != nil }` salta los records sin etiquetas en el store
        // (no los trae a memoria). `(record.tags ?? []).map(\.id)` re-encodea desde M2M, o
        // NUKEA (→ nil) si la M2M viene lazy-nil → auto-heal en lectura (mismo razonamiento
        // que el sweep de Budget; evita huérfanos permanentes por CSV stale).
        do {
            for tx in try context.fetch(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.tagIDs != nil })) where intersectsOld(tx.tagIDsSet) {
                tx.tagIDs = CSVMirrorCodec.encode((tx.tags ?? []).map(\.id))
            }
            for draft in try context.fetch(FetchDescriptor<InboxDraft>(predicate: #Predicate { $0.tagIDs != nil })) where intersectsOld(draft.tagIDsSet) {
                draft.tagIDs = CSVMirrorCodec.encode((draft.tags ?? []).map(\.id))
            }
            for favorite in try context.fetch(FetchDescriptor<FavoritePayment>(predicate: #Predicate { $0.tagIDs != nil })) where intersectsOld(favorite.tagIDsSet) {
                favorite.tagIDs = CSVMirrorCodec.encode((favorite.tags ?? []).map(\.id))
            }
            for payment in try context.fetch(FetchDescriptor<ScheduledPayment>(predicate: #Predicate { $0.tagIDs != nil })) where intersectsOld(payment.tagIDsSet) {
                payment.tagIDs = CSVMirrorCodec.encode((payment.tags ?? []).map(\.id))
            }
        } catch {
            #if DEBUG
            print("CategoryDeduplicationService: rebuildTagCSVMirrors error: \(error)")
            #endif
        }
    }

    // MARK: - Eager Budget CSV mirror backfill (sin colisión de UUIDs)

    /// Pase EAGER REPETIBLE: reconstruye el CSV mirror de cada Budget cuya relación M2M
    /// esté hidratada (no vacía) pero cuyo espejo CSV difiera de ella. Cierra el hueco que
    /// ni el one-shot (rendido tras su sentinel), ni `repairCollapsedIdentityUUIDs` (exige
    /// colisión de UUIDs), ni el auto-heal lazy (solo cura si un reader lee con el M2M ya
    /// hidratado) capturan: un Budget cuyo filtro llega lazy desde CloudKit y queda con el
    /// espejo CSV vacío → el cálculo lo lee como "sin filtros" → cuenta todo el periodo.
    ///
    /// NUNCA nukea (solo escribe desde un M2M no-vacío). `shouldRebuildCSVMirror` solo
    /// reconstruye cuando el M2M aporta ids nuevos (nunca desde un subconjunto), así un M2M
    /// a medio hidratar JAMÁS degrada un CSV correcto — por eso el pase es seguro aunque
    /// corra sin gate de quiescencia (ej. desde `forceSync`); converge en oleadas. El gate
    /// de `runDedupIfQuiescent` es optimización (evita trabajo redundante), no requisito de
    /// correctness. `shouldRebuildCSVMirror` es genérico — extensible a otros modelos con
    /// CSV mirror si lo necesitan (hoy solo Budget tiene el síntoma de número erróneo).
    /// - Returns: número de Budgets cuyo CSV mirror fue reconstruido.
    @discardableResult
    static func backfillBudgetCSVMirrorsFromM2M(in context: ModelContext) -> Int {
        do {
            let budgets = try context.fetch(FetchDescriptor<Budget>())
            var touched = 0
            for budget in budgets {
                var changed = false
                if MigrationBackfillLogic.shouldRebuildCSVMirror(
                    csvIDs: budget.subcategoryIDsSet,
                    m2mIDs: Set((budget.subcategories ?? []).map(\.shortcutID))
                ) {
                    budget.setSubcategoryIDs(from: budget.subcategories ?? [])
                    changed = true
                }
                if MigrationBackfillLogic.shouldRebuildCSVMirror(
                    csvIDs: budget.accountIDsSet,
                    m2mIDs: Set((budget.accounts ?? []).map(\.shortcutID))
                ) {
                    budget.setAccountIDs(from: budget.accounts ?? [])
                    changed = true
                }
                if MigrationBackfillLogic.shouldRebuildCSVMirror(
                    csvIDs: budget.tagIDsSet,
                    m2mIDs: Set((budget.tags ?? []).map(\.id))
                ) {
                    budget.setTagIDs(from: budget.tags ?? [])
                    changed = true
                }
                if changed { touched += 1 }
            }

            guard touched > 0 else { return 0 }

            try context.save()
            SessionState.shared.incrementDataVersion()
            TelemetryService.track(
                .cloudkitBudgetCSVMirrorRebuilt,
                parameters: ["count": String(touched)]
            )
            #if DEBUG
            print("CategoryDeduplicationService: backfillBudgetCSVMirrorsFromM2M — rebuilt \(touched) budget CSV mirror(s)")
            #endif
            return touched
        } catch {
            #if DEBUG
            print("CategoryDeduplicationService: backfillBudgetCSVMirrorsFromM2M error: \(error)")
            #endif
            return 0
        }
    }

    /// Re-parent TODAS las relaciones inversas de `sub` a `match` antes de borrar `sub`.
    /// Sin esto el deleteRule .nullify vacía silenciosamente Budget.subcategories y deja
    /// huérfanos a payments/drafts/memories/cashFlowLines.
    ///
    /// `budgetsToResync` acumula los Budgets tocados — el caller resync el CSV
    /// mirror DESPUÉS del save (cuando cascade `.nullify` de `sub` ya aplicó).
    /// Si resincronizáramos inline aquí, el CSV captaría `sub.shortcutID` (que
    /// va a ser borrada) además del `match.shortcutID`, dejando UUIDs huérfanos.
    /// `internal` (no `private`): reutilizado por `deduplicateSeedSubcategories`.
    static func reparentInverseRelationships(
        from sub: Subcategory,
        to match: Subcategory,
        budgetsToResync: inout Set<PersistentIdentifier>
    ) {
        for tx in sub.transactions ?? [] { tx.subcategory = match }
        for fav in sub.favoritePayments ?? [] { fav.subcategory = match }
        for sched in sub.scheduledPayments ?? [] { sched.subcategory = match }
        for draft in sub.inboxDrafts ?? [] { draft.subcategory = match }
        for memory in sub.merchantMemories ?? [] { memory.subcategory = match }
        for line in sub.cashFlowLines ?? [] { line.subcategory = match }
        // M2M Budget.subcategories: idempotency check evita doble append cuando dos subs
        // duplicadas comparten match en el mismo budget. Tracking del budget para
        // resync POST-save (cascade nullify de `sub` debe completar primero).
        for budget in sub.budgets ?? [] {
            budgetsToResync.insert(budget.persistentModelID)
            guard (budget.subcategories ?? []).allSatisfy({ $0.persistentModelID != match.persistentModelID }) else { continue }
            if budget.subcategories == nil { budget.subcategories = [] }
            budget.subcategories?.append(match)
        }
    }
}
