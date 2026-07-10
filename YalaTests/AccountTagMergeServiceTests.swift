//
//  AccountTagMergeServiceTests.swift
//  YalaTests
//
//  AUTO-CURA de duplicados Account/Tag por contenido (Modo Nube I11-4, §h.3 punto 3).
//  Goldens de merge (re-apunte de referencias + re-encode CSV), exclusiones (moneda/sistema),
//  ganador determinista, idempotencia, y el contrato de sync (tombstone del perdedor vía drain).
//
//  `.serialized`: la suite reusa el container in-memory por archivo (`makeTestContext`) y toca
//  el singleton `SessionState.shared` (incrementDataVersion) → los tests NO deben solaparse.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("AccountTagMergeService · auto-cura de duplicados (I11-4)", .serialized)
@MainActor
struct AccountTagMergeServiceTests {

    // MARK: - Infra (on-disk para el test de tombstone: la History persistente exige store en disco)

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ATMerge-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeDiskContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "ATM-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "ATM-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "ATM-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private func dupAccount(_ currency: String = "USD", isSystem: Bool = false) -> Account {
        Account(name: "Cash", currencyCode: currency, colorHex: "#111111",
                iconName: "banknote", type: "cash", isSystemAccount: isSystem)
    }
    private func dupTag(isActive: Bool = true) -> YalaTag {
        YalaTag(name: "Trip", colorHex: "#FF0000", iconName: "airplane", isActive: isActive)
    }

    // MARK: - Golden Account

    @Test("Golden Account: fusiona duplicados, re-apunta TX/scheduled/draft/Budget(M2M+CSV)/LastUsed al ganador")
    func goldenAccount_merges() throws {
        let context = try makeTestContext()
        let defaults = makeIsolatedDefaults(prefix: "merge.lastused")
        let category = makeTestCategory(context: context)
        let sub = makeTestSubcategory(context: context, category: category)

        let winner = dupAccount()
        let loser = dupAccount()
        context.insert(winner); context.insert(loser)
        // winner 3 TX, loser 2 TX → winner gana por conteo.
        for _ in 0..<3 { _ = makeTestTransaction(context: context, amount: 10, account: winner, category: category, subcategory: sub) }
        for _ in 0..<2 { _ = makeTestTransaction(context: context, amount: 10, account: loser, category: category, subcategory: sub) }
        // scheduled + draft en el perdedor.
        let sched = ScheduledPayment(name: "Rent", amount: 100, currencyCode: "USD", account: loser, nextDueDate: Date())
        context.insert(sched)
        let draft = makeTestInboxDraft(context: context)
        draft.account = loser
        // Budget con M2M + CSV apuntando al perdedor.
        let budget = makeTestBudget(context: context)
        budget.setFilters(accounts: [loser], subcategories: [], tags: [])
        // LastUsed apuntando al perdedor.
        defaults.set(loser.shortcutID.uuidString, forKey: AppPreferences.Keys.lastUsedAccountID)
        try context.save()

        let winnerID = winner.shortcutID

        let removed = AccountTagMergeService.mergeDuplicateAccounts(in: context, lastUsedDefaults: defaults)
        #expect(removed == 1)

        let accounts = try context.fetch(FetchDescriptor<Account>())
        #expect(accounts.count == 1)
        #expect(accounts.first?.shortcutID == winnerID)
        #expect((accounts.first?.transactions?.count ?? 0) == 5, "las 5 TXs quedaron re-apuntadas (balance derivado recomputa)")
        #expect(sched.account?.shortcutID == winnerID)
        #expect(draft.account?.shortcutID == winnerID)
        // Budget M2M y CSV → ganador (no perdedor, no nil).
        #expect((budget.accounts ?? []).map(\.shortcutID) == [winnerID])
        #expect(budget.accountIDsSet == Set([winnerID]))
        // LastUsed re-apuntado al ganador.
        #expect(defaults.string(forKey: AppPreferences.Keys.lastUsedAccountID) == winnerID.uuidString)
    }

    // MARK: - Golden Tag

    @Test("Golden Tag: fusiona duplicados, re-apunta M2M y RE-ENCODEA los CSV en TX y FavoritePayment")
    func goldenTag_merges() throws {
        let context = try makeTestContext()
        let category = makeTestCategory(context: context)
        let sub = makeTestSubcategory(context: context, category: category)
        let account = makeTestAccount(context: context)

        // Identidad = name|colorHex|iconName (isActive NO cuenta) → ambos son la misma etiqueta lógica.
        // El ganador es el ACTIVO (cascada: isActive > inactivo).
        let winnerTag = dupTag(isActive: true)
        let loserTag = dupTag(isActive: false)
        context.insert(winnerTag); context.insert(loserTag)

        let tx = makeTestTransaction(context: context, amount: 10, account: account, category: category, subcategory: sub)
        tx.setTags(from: [loserTag])
        let fav = FavoritePayment(name: "Coffee")
        context.insert(fav)
        fav.setTags(from: [loserTag])
        try context.save()

        let winnerTagID = winnerTag.id

        let removed = AccountTagMergeService.mergeDuplicateTags(in: context)
        #expect(removed == 1)
        #expect(try context.fetchCount(FetchDescriptor<YalaTag>()) == 1)
        // M2M re-apuntado.
        #expect((tx.tags ?? []).map(\.id) == [winnerTagID])
        #expect((fav.tags ?? []).map(\.id) == [winnerTagID])
        // CSV RE-ENCODEADO: contiene el id ganador y NO el perdedor (ni queda stale/nil).
        #expect(tx.tagIDsSet == Set([winnerTagID]))
        #expect(fav.tagIDsSet == Set([winnerTagID]))
    }

    // MARK: - Idempotencia

    @Test("Idempotencia: re-run → 0 (sin duplicados que curar)")
    func idempotent() throws {
        let context = try makeTestContext()
        context.insert(dupAccount()); context.insert(dupAccount())
        context.insert(dupTag()); context.insert(dupTag())
        try context.save()
        #expect(AccountTagMergeService.mergeDuplicateAccounts(in: context, lastUsedDefaults: makeIsolatedDefaults()) == 1)
        #expect(AccountTagMergeService.mergeDuplicateTags(in: context) == 1)
        #expect(AccountTagMergeService.mergeDuplicateAccounts(in: context, lastUsedDefaults: makeIsolatedDefaults()) == 0)
        #expect(AccountTagMergeService.mergeDuplicateTags(in: context) == 0)
    }

    // MARK: - Exclusiones

    @Test("No cruza monedas: mismo nombre distinta divisa → NO merge")
    func noCrossCurrency() throws {
        let context = try makeTestContext()
        context.insert(dupAccount("USD")); context.insert(dupAccount("EUR"))
        try context.save()
        #expect(AccountTagMergeService.mergeDuplicateAccounts(in: context, lastUsedDefaults: makeIsolatedDefaults()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Account>()) == 2)
    }

    @Test("System accounts: 2 cuentas de sistema idénticas → NO merge (bridge de Grupos excluido)")
    func systemAccountsSkipped() throws {
        let context = try makeTestContext()
        context.insert(dupAccount(isSystem: true)); context.insert(dupAccount(isSystem: true))
        try context.save()
        #expect(AccountTagMergeService.mergeDuplicateAccounts(in: context, lastUsedDefaults: makeIsolatedDefaults()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Account>()) == 2)
    }

    // MARK: - Ganador determinista

    @Test("Ganador: gana la cuenta con más TXs")
    func winnerByTransactionCount() throws {
        let context = try makeTestContext()
        let category = makeTestCategory(context: context)
        let sub = makeTestSubcategory(context: context, category: category)
        let more = dupAccount(); let fewer = dupAccount()
        context.insert(more); context.insert(fewer)
        for _ in 0..<3 { _ = makeTestTransaction(context: context, amount: 5, account: more, category: category, subcategory: sub) }
        _ = makeTestTransaction(context: context, amount: 5, account: fewer, category: category, subcategory: sub)
        try context.save()
        let moreID = more.shortcutID
        #expect(AccountTagMergeService.mergeDuplicateAccounts(in: context, lastUsedDefaults: makeIsolatedDefaults()) == 1)
        let survivors = try context.fetch(FetchDescriptor<Account>())
        #expect(survivors.count == 1)
        #expect(survivors.first?.shortcutID == moreID, "gana la de más TXs")
    }

    @Test("Ganador: empate de TXs → gana el shortcutID menor (tiebreak estable)")
    func winnerTiebreakByUUID() throws {
        let context = try makeTestContext()
        let a = dupAccount(); let b = dupAccount()
        context.insert(a); context.insert(b)
        try context.save()
        let expectedWinner = min(a.shortcutID.uuidString, b.shortcutID.uuidString)
        #expect(AccountTagMergeService.mergeDuplicateAccounts(in: context, lastUsedDefaults: makeIsolatedDefaults()) == 1)
        let survivors = try context.fetch(FetchDescriptor<Account>())
        #expect(survivors.count == 1)
        #expect(survivors.first?.shortcutID.uuidString == expectedWinner)
    }

    // MARK: - Contrato de sync: tombstone del perdedor (autor DEFECTO NO suprimido)

    @Test("Tombstone del perdedor: merge (autor DEFECTO) + drainOnce → outbox con el syncID del perdedor")
    func loserTombstoneEmitted() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeDiskContext(dir)
        let engine = CloudSyncEngine()

        let a = dupAccount(); let b = dupAccount()
        context.insert(a); context.insert(b)
        try context.save()
        let aID = a.shortcutID
        let bID = b.shortcutID

        // Baseline: drenar los 2 inserts al outbox (autor por DEFECTO) → token avanza.
        engine.drainOnce(context: context)
        let baseline = try context.fetchCount(FetchDescriptor<SyncOutbox>())

        // Merge (save con autor DEFECTO → el delete NO es suprimido por el anti-eco `outboxSaveAuthor`).
        #expect(AccountTagMergeService.mergeDuplicateAccounts(in: context, lastUsedDefaults: makeIsolatedDefaults()) == 1)
        let survivorID = try #require(try context.fetch(FetchDescriptor<Account>()).first?.shortcutID)
        let loserID = (survivorID == aID) ? bID : aID

        // Drain → el delete del perdedor se emite como tombstone (shortcutID preservado por `.preserveValueOnDeletion`).
        engine.drainOnce(context: context)
        let outbox = try context.fetch(FetchDescriptor<SyncOutbox>())
        #expect(outbox.count > baseline, "el drain emitió el tombstone del perdedor")
        #expect(outbox.contains { $0.opRaw == SyncOutboxOp.tombstone.rawValue && $0.syncID == loserID },
                "outbox contiene un tombstone con el syncID del perdedor (autor defecto NO suprimido → viaja al backend)")
    }
}
