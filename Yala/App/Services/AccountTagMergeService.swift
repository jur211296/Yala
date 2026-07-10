//
//  AccountTagMergeService.swift
//  Yala
//
//  AUTO-CURA (§h.3 punto 3, Modo Nube I11-4) de copias idénticas de Account/Tag por
//  contenido — el problema INVERSO al colapso de UUID: contenido idéntico + `id` DISTINTO
//  (la reversa nube→CloudKit puede materializar una 2ª copia de una Account/Tag de usuario).
//
//  El fix NO regenera UUIDs (eso repara el COLAPSO — `CategoryDeduplicationService
//  .repairCollapsedIdentityUUIDs`); aquí hay dos identidades distintas → hay que ELEGIR un
//  ganador, re-apuntar todas las referencias del perdedor al ganador, y borrar el perdedor.
//  Reusa el PATRÓN de merge de `CategoryDeduplicationService.deduplicateSeedCategories`:
//  ganador determinista → reparent de inversas → delete → save → resync CSV POST-save (el
//  cascade `.nullify` debe aplicar ANTES de re-encodear los espejos, o el CSV captaría el
//  UUID del perdedor que va a morir → huérfano permanente, regla `899c1c25`).
//
//  Autor del save = DEFECTO (NO `outboxSaveAuthor`). Razonamiento DUAL:
//   • En la REVERSA (v1, único consumidor real vía `MigrationWorkExecutor.healDuplicates`) el
//     backend está congelado (drain irrelevante) y el mirror CloudKit exporta el delete/updates
//     igual (no filtra por autor) → el device queda consistente.
//   • En un uso FUTURO en modo `.cloud` vivo, el autor defecto es ADEMÁS el correcto: el
//     tombstone del perdedor DEBE viajar al backend por el drain (`Account.shortcutID`/`Tag.id`
//     llevan `.preserveValueOnDeletion` → el tombstone porta el syncID). El anti-eco
//     (`outboxSaveAuthor`) SUPRIMIRÍA ese tombstone → el perdedor quedaría vivo en el backend.
//
//  HAZARD multi-device (por qué la cura corre SOLO en la reversa, líder único con backend
//  congelado): dos devices en modo nube VIVO con conteos locales de TXs distintos elegirían
//  ganadores DISTINTOS → cada uno tombstonearía al otro → ambas filas mueren en el backend y
//  las TXs se re-apuntan divergentemente. El tiebreak por UUID solo desempata conteos IGUALES,
//  NO da convergencia cross-device. Encender esto en boot/cloud-vivo exige coordinación por
//  líder (diseño aparte). El boot sigue con `reportPotentialAccountTagDuplicates` (telemetría
//  read-only), NO con esta cura.
//
//  EXCLUSIÓN v1: `Account.isSystemAccount == true` (cuentas virtuales del bridge de Grupos) NO
//  se auto-curan — mergearlas tocaría Grupos (restricción de la épica). La identidad ya las
//  separa (`accountIdentity` incluye `isSystemAccount`); si un grupo duplicado es de sistema →
//  skip SILENCIOSO (NO entra en el retorno — la visibilidad viene de la telemetría de boot
//  `reportPotentialAccountTagDuplicates`, que sí las cuenta; decisión del owner cruza con la
//  NOTA-2 de I12 en el gate de encendido de flags).
//
//  `@MainActor`: manipula `ModelContext` (regla inviolable del repo).
//

import Foundation
import SwiftData

@MainActor
enum AccountTagMergeService {

    // MARK: - Accounts

    /// Fusiona cuentas duplicadas por contenido (`AccountTagDuplicateCountLogic.accountIdentity`).
    /// - Returns: nº de cuentas PERDEDORAS borradas (0 si no había duplicados o solo de sistema).
    ///
    /// `lastUsedDefaults`: el App Group donde `LastUsedAccountStore` (QuickExpenseIntent.swift)
    /// guarda el `shortcutID` de la última cuenta usada. Inyectable para tests (NUNCA `.standard`
    /// directo en tests — regla del repo); default = el App Group real.
    @discardableResult
    static func mergeDuplicateAccounts(
        in context: ModelContext,
        lastUsedDefaults: UserDefaults? = UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)
    ) -> Int {
        let accounts: [Account]
        do {
            accounts = try context.fetch(FetchDescriptor<Account>())
        } catch {
            #if DEBUG
            print("AccountTagMerge: fetch(Account) falló: \(error)")
            #endif
            return 0
        }

        let groups = AccountTagDuplicateCountLogic.duplicateGroupItems(
            accounts, identity: AccountTagDuplicateCountLogic.accountIdentity)
        guard !groups.isEmpty else { return 0 }

        var removedCount = 0
        var budgetsToResync: Set<PersistentIdentifier> = []
        var loserShortcutIDs: Set<UUID> = []
        var winnerByLoserShortcutID: [UUID: UUID] = [:]

        for group in groups {
            // EXCLUSIÓN: los grupos de sistema comparten `isSystemAccount == true` en su identidad
            // → basta mirar el primero. Skip completo (no se cura ninguna cuenta del bridge).
            if group.first?.isSystemAccount == true { continue }

            let winner = pickAccountWinner(group)
            for loser in group where loser.persistentModelID != winner.persistentModelID {
                loserShortcutIDs.insert(loser.shortcutID)
                winnerByLoserShortcutID[loser.shortcutID] = winner.shortcutID

                // Forward to-one: re-apuntar TXs/scheduled/favorites/drafts (Account NO tiene
                // balance denormalizado → el saldo derivado recomputa solo tras el re-apunte).
                for tx in loser.transactions ?? [] { tx.account = winner }
                for sched in loser.scheduledPayments ?? [] { sched.account = winner }
                for fav in loser.favoritePayments ?? [] { fav.account = winner }
                for draft in loser.inboxDrafts ?? [] { draft.account = winner }

                // M2M Budget.accounts: añadir winner si falta (el cascade `.nullify` quita al loser
                // al borrarlo). Guard anti-doble-append. Track para resync CSV POST-save.
                for budget in loser.budgets ?? [] {
                    budgetsToResync.insert(budget.persistentModelID)
                    if (budget.accounts ?? []).allSatisfy({ $0.persistentModelID != winner.persistentModelID }) {
                        if budget.accounts == nil { budget.accounts = [] }
                        budget.accounts?.append(winner)
                    }
                }

                context.delete(loser)
                removedCount += 1
            }
        }

        guard removedCount > 0 else { return 0 }

        do {
            try context.save()
            // POST-save resync: el cascade `.nullify` ya quitó al perdedor del M2M `accounts`.
            // Re-encode el CSV mirror desde el M2M actual (sin el shortcutID huérfano del perdedor).
            let affectedBudgets = budgetsToResync.compactMap { context.model(for: $0) as? Budget }
            for budget in affectedBudgets {
                budget.setAccountIDs(from: budget.accounts ?? [])
            }
            // Paridad de robustez con `rebuildTagCSVMirrors` (review I11-4, regla 899c1c25): cazar
            // budgets cuyo CSV referencia un shortcutID PERDEDOR pero que el descubrimiento por
            // inversa saltó (ventana M2M lazy-nil) — un CSV stale-pero-presente NO cae a M2M.
            resyncOrphanAccountCSV(loserShortcutIDs, context: context)
            // `LastUsedAccountStore` (App Group, string = shortcutID.uuidString): si apuntaba a un
            // perdedor, re-apuntar al ganador (patrón de re-encode CSV post-delete). Cross-ref:
            // `LastUsedAccountStore.read/write` en QuickExpenseIntent.swift.
            if let defaults = lastUsedDefaults,
               let stored = defaults.string(forKey: AppPreferences.Keys.lastUsedAccountID),
               let storedUUID = UUID(uuidString: stored),
               loserShortcutIDs.contains(storedUUID),
               let winnerShortcutID = winnerByLoserShortcutID[storedUUID] {
                defaults.set(winnerShortcutID.uuidString, forKey: AppPreferences.Keys.lastUsedAccountID)
            }
            if context.hasChanges { try context.save() }
            SessionState.shared.incrementDataVersion()
            #if DEBUG
            print("AccountTagMerge: mergeDuplicateAccounts — removed \(removedCount) loser(s), resynced CSV for \(affectedBudgets.count) budget(s)")
            #endif
        } catch {
            #if DEBUG
            print("AccountTagMerge: mergeDuplicateAccounts save error: \(error)")
            #endif
        }

        return removedCount
    }

    // MARK: - Tags

    /// Fusiona tags duplicados por contenido (`AccountTagDuplicateCountLogic.tagIdentity`).
    /// - Returns: nº de tags PERDEDORES borrados (0 si no había duplicados).
    @discardableResult
    static func mergeDuplicateTags(in context: ModelContext) -> Int {
        let tags: [Tag]
        do {
            tags = try context.fetch(FetchDescriptor<Tag>())
        } catch {
            #if DEBUG
            print("AccountTagMerge: fetch(Tag) falló: \(error)")
            #endif
            return 0
        }

        let groups = AccountTagDuplicateCountLogic.duplicateGroupItems(
            tags, identity: AccountTagDuplicateCountLogic.tagIdentity)
        guard !groups.isEmpty else { return 0 }

        var removedCount = 0
        var budgetsToResync: Set<PersistentIdentifier> = []
        var txsToResync: Set<PersistentIdentifier> = []
        var scheduledToResync: Set<PersistentIdentifier> = []
        var favoritesToResync: Set<PersistentIdentifier> = []
        var draftsToResync: Set<PersistentIdentifier> = []
        var loserTagIDs: Set<UUID> = []

        for group in groups {
            let winner = pickTagWinner(group)
            for loser in group where loser.persistentModelID != winner.persistentModelID {
                loserTagIDs.insert(loser.id)
                // M2M `tags` en los 5 owners: añadir winner si falta (cascade `.nullify` quita al
                // loser al borrarlo). Guard anti-doble-append (owner que porta AMBOS a la vez). Track
                // para resync CSV POST-save. Append directo al M2M (patrón `CategoryDeduplicationService
                // .reparentInverseRelationships`), NO via inout sobre propiedad @Model.
                for tx in loser.transactions ?? [] {
                    if (tx.tags ?? []).allSatisfy({ $0.persistentModelID != winner.persistentModelID }) {
                        if tx.tags == nil { tx.tags = [] }
                        tx.tags?.append(winner)
                    }
                    txsToResync.insert(tx.persistentModelID)
                }
                for budget in loser.budgets ?? [] {
                    if (budget.tags ?? []).allSatisfy({ $0.persistentModelID != winner.persistentModelID }) {
                        if budget.tags == nil { budget.tags = [] }
                        budget.tags?.append(winner)
                    }
                    budgetsToResync.insert(budget.persistentModelID)
                }
                for sched in loser.scheduledPayments ?? [] {
                    if (sched.tags ?? []).allSatisfy({ $0.persistentModelID != winner.persistentModelID }) {
                        if sched.tags == nil { sched.tags = [] }
                        sched.tags?.append(winner)
                    }
                    scheduledToResync.insert(sched.persistentModelID)
                }
                for fav in loser.favoritePayments ?? [] {
                    if (fav.tags ?? []).allSatisfy({ $0.persistentModelID != winner.persistentModelID }) {
                        if fav.tags == nil { fav.tags = [] }
                        fav.tags?.append(winner)
                    }
                    favoritesToResync.insert(fav.persistentModelID)
                }
                for draft in loser.inboxDrafts ?? [] {
                    if (draft.tags ?? []).allSatisfy({ $0.persistentModelID != winner.persistentModelID }) {
                        if draft.tags == nil { draft.tags = [] }
                        draft.tags?.append(winner)
                    }
                    draftsToResync.insert(draft.persistentModelID)
                }

                context.delete(loser)
                removedCount += 1
            }
        }

        guard removedCount > 0 else { return 0 }

        do {
            try context.save()
            // POST-save resync: el cascade `.nullify` ya quitó al perdedor de cada M2M `tags`.
            // Re-encode los CSV mirrors desde el M2M actual (sin el `id` huérfano del perdedor)
            // — CSV-first stale-pero-presente NO cae a M2M (regla `899c1c25`). Patrón directo de
            // `EntityDeletionService.deleteTag`.
            for budget in budgetsToResync.compactMap({ context.model(for: $0) as? Budget }) {
                budget.setTagIDs(from: budget.tags ?? [])
            }
            for tx in txsToResync.compactMap({ context.model(for: $0) as? TransactionItem }) {
                tx.tagIDs = CSVMirrorCodec.encode((tx.tags ?? []).map(\.id))
            }
            for sched in scheduledToResync.compactMap({ context.model(for: $0) as? ScheduledPayment }) {
                sched.tagIDs = CSVMirrorCodec.encode((sched.tags ?? []).map(\.id))
            }
            for fav in favoritesToResync.compactMap({ context.model(for: $0) as? FavoritePayment }) {
                fav.tagIDs = CSVMirrorCodec.encode((fav.tags ?? []).map(\.id))
            }
            for draft in draftsToResync.compactMap({ context.model(for: $0) as? InboxDraft }) {
                draft.tagIDs = CSVMirrorCodec.encode((draft.tags ?? []).map(\.id))
            }
            // Paridad de robustez con `rebuildTagCSVMirrors` (review I11-4, regla 899c1c25): cazar
            // owners cuyo CSV referencia un id PERDEDOR pero que el descubrimiento por inversa saltó
            // (ventana M2M lazy-nil) — un CSV stale-pero-presente NO cae a M2M.
            resyncOrphanTagCSV(loserTagIDs, context: context)
            if context.hasChanges { try context.save() }
            SessionState.shared.incrementDataVersion()
            #if DEBUG
            print("AccountTagMerge: mergeDuplicateTags — removed \(removedCount) loser(s)")
            #endif
        } catch {
            #if DEBUG
            print("AccountTagMerge: mergeDuplicateTags save error: \(error)")
            #endif
        }

        return removedCount
    }

    // MARK: - Scan de CSV huérfanos (paridad con `rebuildTagCSVMirrors`, regla 899c1c25)

    /// Re-encodea el CSV `accountIDs` de los budgets cuyo espejo referencia un shortcutID PERDEDOR
    /// aunque su M2M viniera lazy-nil durante el re-apunte (el descubrimiento por inversa los saltó
    /// → CSV huérfano permanente si no se caza aquí). Nuke-on-nil: re-encode desde el M2M actual.
    private static func resyncOrphanAccountCSV(_ loserIDs: Set<UUID>, context: ModelContext) {
        guard !loserIDs.isEmpty else { return }
        do {
            let budgets = try context.fetch(FetchDescriptor<Budget>(
                predicate: #Predicate<Budget> { $0.accountIDs != nil }))
            for budget in budgets {
                guard let csv = budget.accountIDsSet, !csv.isDisjoint(with: loserIDs) else { continue }
                budget.setAccountIDs(from: budget.accounts ?? [])
            }
        } catch {
            #if DEBUG
            print("AccountTagMerge: resyncOrphanAccountCSV fetch falló: \(error)")
            #endif
        }
    }

    /// Ídem para el CSV `tagIDs` de los 5 owners (patrón exacto de
    /// `CategoryDeduplicationService.rebuildTagCSVMirrors`: predicado `tagIDs != nil` + intersección).
    private static func resyncOrphanTagCSV(_ loserIDs: Set<UUID>, context: ModelContext) {
        guard !loserIDs.isEmpty else { return }
        do {
            for budget in try context.fetch(FetchDescriptor<Budget>(
                predicate: #Predicate<Budget> { $0.tagIDs != nil })) {
                guard let csv = budget.tagIDsSet, !csv.isDisjoint(with: loserIDs) else { continue }
                budget.setTagIDs(from: budget.tags ?? [])
            }
            for tx in try context.fetch(FetchDescriptor<TransactionItem>(
                predicate: #Predicate<TransactionItem> { $0.tagIDs != nil })) {
                guard let csv = tx.tagIDsSet, !csv.isDisjoint(with: loserIDs) else { continue }
                tx.tagIDs = CSVMirrorCodec.encode((tx.tags ?? []).map(\.id))
            }
            for sched in try context.fetch(FetchDescriptor<ScheduledPayment>(
                predicate: #Predicate<ScheduledPayment> { $0.tagIDs != nil })) {
                guard let csv = sched.tagIDsSet, !csv.isDisjoint(with: loserIDs) else { continue }
                sched.tagIDs = CSVMirrorCodec.encode((sched.tags ?? []).map(\.id))
            }
            for fav in try context.fetch(FetchDescriptor<FavoritePayment>(
                predicate: #Predicate<FavoritePayment> { $0.tagIDs != nil })) {
                guard let csv = fav.tagIDsSet, !csv.isDisjoint(with: loserIDs) else { continue }
                fav.tagIDs = CSVMirrorCodec.encode((fav.tags ?? []).map(\.id))
            }
            for draft in try context.fetch(FetchDescriptor<InboxDraft>(
                predicate: #Predicate<InboxDraft> { $0.tagIDs != nil })) {
                guard let csv = draft.tagIDsSet, !csv.isDisjoint(with: loserIDs) else { continue }
                draft.tagIDs = CSVMirrorCodec.encode((draft.tags ?? []).map(\.id))
            }
        } catch {
            #if DEBUG
            print("AccountTagMerge: resyncOrphanTagCSV fetch falló: \(error)")
            #endif
        }
    }

    // MARK: - Winner selection (cascada, ajuste del review)

    /// Ganador de un grupo de Accounts: (1) NO archivada > archivada (un ganador archivado
    /// absorbiendo TXs vivas sería una rareza visible); (2) más `transactions`; (3) tiebreak
    /// estable por `shortcutID.uuidString` ascendente.
    private static func pickAccountWinner(_ group: [Account]) -> Account {
        group.sorted { a, b in
            if a.isArchived != b.isArchived { return !a.isArchived }
            let ca = a.transactions?.count ?? 0
            let cb = b.transactions?.count ?? 0
            if ca != cb { return ca > cb }
            return a.shortcutID.uuidString < b.shortcutID.uuidString
        }[0]
    }

    /// Ganador de un grupo de Tags: (1) `isActive` > inactivo; (2) más `transactions` (conteo M2M);
    /// (3) tiebreak estable por `id.uuidString` ascendente.
    private static func pickTagWinner(_ group: [Tag]) -> Tag {
        group.sorted { a, b in
            if a.isActive != b.isActive { return a.isActive }
            let ca = a.transactions?.count ?? 0
            let cb = b.transactions?.count ?? 0
            if ca != cb { return ca > cb }
            return a.id.uuidString < b.id.uuidString
        }[0]
    }
}
