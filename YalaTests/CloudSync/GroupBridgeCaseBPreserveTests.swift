//
//  GroupBridgeCaseBPreserveTests.swift
//  YalaTests / CloudSync
//
//  Caso B del bridge → preserve+update de la TX virtual clasificable (`-myShare`).
//  Pinnea que la virtual clasificable se PRESERVA entre re-bridges (misma identidad +
//  subcat manual / tags / needOverride) y solo se le actualizan los campos derivados del
//  grupo (monto/fecha/nota/split*), en paridad con el Caso A real — contra la regresión
//  delete+recreate, que perdía la clasificación y re-spammeaba el draft-puntero.
//
//  Harness ON-DISK con los 3 stores (patrón GroupBridgeCloudSyncIntegrationTests — el History
//  es por-CONTAINER; `bridgeExpense(shouldSave:false)` + save manual evita los side-effects de
//  `saveIfNeeded` que causaron la blacklist R8). El host de tests salta el bootstrap ⇒
//  BridgeModeResolver.appPreferences == nil ⇒ isBridgeEnabled == true determinístico.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("GroupBridge Caso B · preserve+update de la virtual clasificable", .serialized)
@MainActor
struct GroupBridgeCaseBPreserveTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupBridgeCaseB-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GBCB-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "GBCB-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "GBCB-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg
        )
        return ModelContext(container)
    }

    private struct Fixture {
        let group: SplitGroup
        let me: SplitMember
        let ana: SplitMember
        let account: Account
        let userSubcat: Subcategory
        let matchSubcat: Subcategory  // nombre "Comida" para el test fill-if-nil
    }

    private func makeFixture(_ context: ModelContext) throws -> Fixture {
        let group = SplitGroup(name: "Viaje", currencyCode: "USD")
        context.insert(group)
        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", isCurrentUser: true)
        context.insert(me)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(ana)
        let account = Account(
            name: "Efectivo", currencyCode: "USD", colorHex: "#111111",
            iconName: "banknote", type: "cash"
        )
        context.insert(account)
        let cat = makeTestCategory(context: context, name: "Personal")
        let userSubcat = makeTestSubcategory(context: context, name: "Antojos personales", category: cat)
        let matchSubcat = makeTestSubcategory(context: context, name: "Comida", category: cat)
        try context.save()
        return Fixture(group: group, me: me, ana: ana, account: account,
                       userSubcat: userSubcat, matchSubcat: matchSubcat)
    }

    private func withBridgeEnvironment(_ context: ModelContext, mode: OnboardingMode = .full, _ body: () throws -> Void) rethrows {
        GroupTransactionBridge.shared.setContext(context)
        let previousMode = SessionState.shared.onboardingMode
        SessionState.shared.onboardingMode = mode
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            SessionState.shared.onboardingMode = previousMode
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        }
        try body()
    }

    // MARK: - Consultas

    private func txs(_ context: ModelContext, expenseID: UUID) throws -> [TransactionItem] {
        let idStr = expenseID.uuidString
        return try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID == idStr }
        ))
    }

    /// La virtual clasificable (`-myShare`): cuenta de sistema, subcat nil o de usuario.
    private func classifiableVirtual(_ context: ModelContext, expenseID: UUID) throws -> TransactionItem? {
        try txs(context, expenseID: expenseID).first { tx in
            tx.account?.isSystemAccount == true && (tx.subcategory == nil || tx.subcategory?.isAnySystem != true)
        }
    }

    private func pointerDrafts(_ context: ModelContext, expenseID: UUID) throws -> [InboxDraft] {
        let idStr = expenseID.uuidString
        return try context.fetch(FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitExpenseID == idStr }
        )).filter { $0.needsUserInput.contains(DraftInputRequirement.subcategory) }
    }

    /// Caso B: gasto pagado por Ana, mi share = `myShare` de `total`. Sin subcategoryName
    /// (auto-match falla) salvo que se indique.
    private func makeCaseBExpense(
        _ context: ModelContext, _ f: Fixture,
        total: Double = 90, myShare: Double = 30, subcategoryName: String? = nil,
        description: String = "Taxi", currency: String = "USD"
    ) throws -> (SplitExpense, SplitShare) {
        let expense = SplitExpense(
            groupZoneID: f.group.cloudKitZoneID,
            amount: total, currencyCode: currency,
            expenseDescription: description,
            paidByMemberID: f.ana.id.uuidString
        )
        expense.subcategoryName = subcategoryName
        context.insert(expense)
        let share = SplitShare(
            expenseID: expense.id, memberID: f.me.id.uuidString,
            amount: myShare, groupZoneID: f.group.cloudKitZoneID
        )
        context.insert(share)
        try context.save()
        return (expense, share)
    }

    private func bridge(_ context: ModelContext, _ expense: SplitExpense, _ group: SplitGroup, account: Account? = nil) throws {
        try GroupTransactionBridge.shared.bridgeExpense(
            expense, in: group, accountForCurrentUser: account, shouldSave: false
        )
        try context.save()
    }

    // MARK: - Test 1: preserve central

    @Test func reBridge_preservesManualSubcatAndTag_updatesGroupFields_sameIdentity() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withBridgeEnvironment(context) {
            let (expense, share) = try makeCaseBExpense(context, f, total: 90, myShare: 30)
            try bridge(context, expense, f.group)

            // Estado inicial: 1 virtual clasificable, subcat nil (auto-match falló), -30.
            let created = try #require(try classifiableVirtual(context, expenseID: expense.id))
            #expect(created.subcategory == nil)
            #expect(created.amount == -30)
            let originalID = created.persistentModelID

            // El usuario clasifica manualmente + añade un tag + override de naturaleza.
            let tag = makeTestTag(context: context, name: "Ocio")
            created.subcategory = f.userSubcat
            created.category = f.userSubcat.safeCategory
            created.setTags(from: [tag])
            created.needOverride = SubcategoryNeed.optional.rawValue
            try context.save()

            // El gasto cambia en el grupo: mi share 30→25, otra fecha, otra descripción.
            share.amount = 25
            expense.amount = 80
            expense.date = Date(timeIntervalSince1970: 999_000)
            expense.expenseDescription = "Taxi al aeropuerto"
            try context.save()

            // Re-bridge (sin subcategoryName → auto-match sigue fallando).
            try bridge(context, expense, f.group)

            // MISMA identidad (mutante: revertir el upsert a delete+recreate → este #expect ROJO).
            let after = try #require(try classifiableVirtual(context, expenseID: expense.id))
            #expect(after.persistentModelID == originalID)
            // Metadatos del usuario INTACTOS.
            #expect(after.subcategory?.persistentModelID == f.userSubcat.persistentModelID)
            #expect(after.resolvedTagIDs() == Set([tag.id]))
            #expect(after.needOverride == SubcategoryNeed.optional.rawValue)
            // Campos del grupo ACTUALIZADOS.
            #expect(after.amount == -25)
            #expect(after.date == Date(timeIntervalSince1970: 999_000))
            #expect(after.note == "Taxi al aeropuerto")
            // Sigue habiendo una sola virtual.
            #expect(try txs(context, expenseID: expense.id).count == 1)
        }
    }

    // MARK: - Test 2: fill-si-nil

    @Test func reBridge_fillsSubcatOnlyIfNil_whenExpenseResolvesOne() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withBridgeEnvironment(context) {
            let (expense, _) = try makeCaseBExpense(context, f, subcategoryName: nil)
            try bridge(context, expense, f.group)
            let created = try #require(try classifiableVirtual(context, expenseID: expense.id))
            #expect(created.subcategory == nil)
            let originalID = created.persistentModelID

            // El gasto ahora resuelve una subcategoría ("Comida" existe en el store).
            expense.subcategoryName = "Comida"
            try context.save()
            try bridge(context, expense, f.group)

            let after = try #require(try classifiableVirtual(context, expenseID: expense.id))
            #expect(after.persistentModelID == originalID)  // preserve, no recreate
            #expect(after.subcategory?.persistentModelID == f.matchSubcat.persistentModelID)
            #expect(after.category?.persistentModelID == f.matchSubcat.safeCategory.persistentModelID)
        }
    }

    // MARK: - Test 3a: payer B→A borra la clasificable

    @Test func transition_payerBtoA_deletesClassifiable_createsRealTx() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withBridgeEnvironment(context) {
            let (expense, _) = try makeCaseBExpense(context, f, total: 90, myShare: 30)
            try bridge(context, expense, f.group)
            let virtual = try #require(try classifiableVirtual(context, expenseID: expense.id))
            virtual.subcategory = f.userSubcat
            try context.save()
            let virtualID = virtual.persistentModelID

            // Ahora pago YO (Caso A), con cuenta real. Bridge-ON (appPrefs nil → true).
            expense.paidByMemberID = f.me.id.uuidString
            try context.save()
            try bridge(context, expense, f.group, account: f.account)

            // La virtual clasificable `-myShare` fue borrada.
            let all = try txs(context, expenseID: expense.id)
            #expect(!all.contains { $0.persistentModelID == virtualID })
            #expect(try classifiableVirtual(context, expenseID: expense.id) == nil)
            // Existe la TX real -90 en la cuenta del usuario.
            let real = all.first { $0.account?.isSystemAccount == false }
            #expect(real?.amount == -90)
            #expect(real?.account?.persistentModelID == f.account.persistentModelID)
        }
    }

    // MARK: - Test 3b: myShare→0 borra la clasificable

    @Test func transition_myShareToZero_deletesClassifiable() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withBridgeEnvironment(context) {
            let (expense, share) = try makeCaseBExpense(context, f, total: 90, myShare: 30)
            try bridge(context, expense, f.group)
            let virtual = try #require(try classifiableVirtual(context, expenseID: expense.id))
            virtual.subcategory = f.userSubcat
            try context.save()

            // Mi parte pasa a 0 (ya no participo en la división).
            share.amount = 0
            try context.save()
            try bridge(context, expense, f.group)

            // Sin costo personal → la virtual se borra (no queda TX huérfana con monto stale).
            #expect(try txs(context, expenseID: expense.id).isEmpty)
        }
    }

    // MARK: - Test 3c: currency change → recreate CON trasplante

    @Test func transition_currencyChange_recreatesWithMetadataTransplant() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withBridgeEnvironment(context) {
            let (expense, _) = try makeCaseBExpense(context, f, total: 90, myShare: 30, currency: "USD")
            try bridge(context, expense, f.group)
            let virtual = try #require(try classifiableVirtual(context, expenseID: expense.id))
            let tag = makeTestTag(context: context, name: "Viaje")
            virtual.subcategory = f.userSubcat
            virtual.setTags(from: [tag])
            virtual.needOverride = SubcategoryNeed.optional.rawValue
            try context.save()
            let originalID = virtual.persistentModelID

            // El gasto cambia de moneda → delete + recreate con trasplante.
            expense.currencyCode = "EUR"
            try context.save()
            try bridge(context, expense, f.group)

            let after = try #require(try classifiableVirtual(context, expenseID: expense.id))
            #expect(after.persistentModelID != originalID)  // recreate (identidad nueva)
            #expect(after.currencyCode == "EUR")
            // Metadatos del usuario TRASPLANTADOS (independientes de la moneda).
            #expect(after.subcategory?.persistentModelID == f.userSubcat.persistentModelID)
            #expect(after.resolvedTagIDs() == Set([tag.id]))
            #expect(after.needOverride == SubcategoryNeed.optional.rawValue)
            #expect(try txs(context, expenseID: expense.id).count == 1)
        }
    }

    // MARK: - Test 3d: groupInvite preserva TX1 y regenera TX2

    @Test func transition_groupInvite_preservesMyShareTx_regeneratesLentTx() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withBridgeEnvironment(context, mode: .groupInvite) {
            // Caso A pago yo (pero groupInvite → par virtual TX1 -myShare + TX2 +total).
            let expense = SplitExpense(
                groupZoneID: f.group.cloudKitZoneID, amount: 90, currencyCode: "USD",
                expenseDescription: "Cena", paidByMemberID: f.me.id.uuidString
            )
            context.insert(expense)
            context.insert(SplitShare(
                expenseID: expense.id, memberID: f.me.id.uuidString,
                amount: 30, groupZoneID: f.group.cloudKitZoneID
            ))
            try context.save()
            try bridge(context, expense, f.group)

            // TX1 = myShare clasificable (-30); TX2 = lent sistema (+90).
            let tx1 = try #require(try classifiableVirtual(context, expenseID: expense.id))
            #expect(tx1.amount == -30)
            tx1.subcategory = f.userSubcat
            try context.save()
            let tx1ID = tx1.persistentModelID
            let lentBefore = try txs(context, expenseID: expense.id)
                .first { $0.subcategory?.isAnySystem == true }
            let tx2IDBefore = try #require(lentBefore).persistentModelID

            try bridge(context, expense, f.group)

            // TX1 preservada (misma identidad + subcat de usuario).
            let tx1After = try #require(try classifiableVirtual(context, expenseID: expense.id))
            #expect(tx1After.persistentModelID == tx1ID)
            #expect(tx1After.subcategory?.persistentModelID == f.userSubcat.persistentModelID)
            // TX2 (lent) REGENERADA (identidad nueva — derivada, delete+recreate).
            let lentAfter = try #require(try txs(context, expenseID: expense.id)
                .first { $0.subcategory?.isAnySystem == true })
            #expect(lentAfter.persistentModelID != tx2IDBefore)
            #expect(lentAfter.amount == 90)
        }
    }

    // MARK: - Test 4: draft-puntero según estado FINAL de la TX

    @Test func pointer_classifiedTx_noPointerRecreatedOnReBridge() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withBridgeEnvironment(context) {
            let (expense, _) = try makeCaseBExpense(context, f, subcategoryName: nil)
            try bridge(context, expense, f.group)
            // Primera pasada sin subcat → puntero creado.
            #expect(try pointerDrafts(context, expenseID: expense.id).count == 1)

            // El usuario clasifica la virtual manualmente.
            let virtual = try #require(try classifiableVirtual(context, expenseID: expense.id))
            virtual.subcategory = f.userSubcat
            try context.save()

            try bridge(context, expense, f.group)
            // TX ya clasificada → NO se recrea el puntero (cierra el spam).
            #expect(try pointerDrafts(context, expenseID: expense.id).isEmpty)
        }
    }

    @Test func pointer_unclassifiedTx_createsPointer() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withBridgeEnvironment(context) {
            let (expense, _) = try makeCaseBExpense(context, f, subcategoryName: nil)
            try bridge(context, expense, f.group)
            #expect(try pointerDrafts(context, expenseID: expense.id).count == 1)
        }
    }

    // MARK: - Test 5: duplicadas clasificables → gana la que porta metadatos

    @Test func duplicates_classifiedVirtualWins_bareDeleted() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withBridgeEnvironment(context) {
            let (expense, _) = try makeCaseBExpense(context, f, total: 90, myShare: 30)
            try bridge(context, expense, f.group)
            let classified = try #require(try classifiableVirtual(context, expenseID: expense.id))
            classified.subcategory = f.userSubcat
            try context.save()
            let winnerID = classified.persistentModelID
            let systemAccount = try #require(classified.account)

            // Simular un duplicado histórico: 2ª virtual clasificable SIN metadatos (subcat nil),
            // misma cuenta de sistema + mismo splitExpenseID.
            let dup = TransactionItem(
                date: expense.date, amount: -30, currencyCode: "USD",
                note: expense.expenseDescription, account: systemAccount
            )
            dup.splitExpenseID = expense.id.uuidString
            dup.splitGroupZoneID = expense.groupZoneID
            context.insert(dup)
            try context.save()
            #expect(try txs(context, expenseID: expense.id).count == 2)

            try bridge(context, expense, f.group)

            // Solo sobrevive la clasificada (con metadatos); el duplicado desnudo se borró.
            let remaining = try txs(context, expenseID: expense.id)
            #expect(remaining.count == 1)
            #expect(remaining.first?.persistentModelID == winnerID)
            #expect(remaining.first?.subcategory?.persistentModelID == f.userSubcat.persistentModelID)
        }
    }

    // MARK: - Test 6: rama .lendingToCompensateReal borra la clasificable

    @Test func transition_realTxSurvivesBridgeOff_deletesClassifiable_createsLent() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withBridgeEnvironment(context) {
            // Bridge ON (prefs nil): Caso B crea la virtual clasificable -30; se clasifica.
            let (expense, _) = try makeCaseBExpense(context, f, total: 90, myShare: 30)
            try bridge(context, expense, f.group)
            let virtual = try #require(try classifiableVirtual(context, expenseID: expense.id))
            virtual.subcategory = f.userSubcat
            try context.save()
            let virtualID = virtual.persistentModelID

            // El usuario aprobó un opt-in personal: TX REAL -total en su cuenta.
            let realTx = TransactionItem(
                date: expense.date, amount: -90, currencyCode: "USD",
                note: "Taxi", account: f.account
            )
            realTx.splitExpenseID = expense.id.uuidString
            realTx.splitGroupZoneID = expense.groupZoneID
            context.insert(realTx)
            try context.save()

            // Bridge OFF (prefs inyectadas con el toggle global apagado). Restore obligatorio:
            // singleton compartido (regla CLAUDE.md) → _testReset en defer.
            let prefs = AppPreferences(defaults: makeIsolatedDefaults())
            prefs.bridgeGroupExpensesToPersonalAccounts = false
            BridgeModeResolver.shared.setAppPreferences(prefs)
            defer { BridgeModeResolver.shared._testReset() }

            try bridge(context, expense, f.group)

            // La real sobrevive (deleteStaleReal=false con bridge OFF) → rama
            // .lendingToCompensateReal: la clasificable -myShare se BORRA (sobra: net
            // real -90 + lent +60 = -30) y aparece la lent derivada +60 (subcat sistema).
            let all = try txs(context, expenseID: expense.id)
            #expect(!all.contains { $0.persistentModelID == virtualID })
            #expect(try classifiableVirtual(context, expenseID: expense.id) == nil)
            let lent = all.first { $0.account?.isSystemAccount == true }
            #expect(lent?.amount == 60)
            #expect(lent?.subcategory?.isAnySystem == true)
            let real = all.first { $0.account?.isSystemAccount == false }
            #expect(real?.persistentModelID == realTx.persistentModelID)
            #expect(real?.amount == -90)
        }
    }
}
