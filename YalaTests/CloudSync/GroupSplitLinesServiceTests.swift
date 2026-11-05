//
//  GroupSplitLinesServiceTests.swift
//  YalaTests / CloudSync
//
//  Grupos B · cards 5 y 6: lo que las pantallas escriben al partir tu parte. «Partir» en la Bandeja
//  (`DraftService.approveDraft(splitLines:)`) y «Partir tu parte» desde la pantalla de éxito o el detalle
//  (`GroupSplitLinesService.save`). De punta a punta con el puente real, sobre el harness de `GroupBridgeSplitLinesTests`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos B · partir tu parte desde las pantallas", .serialized)
@MainActor
struct GroupSplitLinesServiceTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupSplitLinesService-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("no se pudo crear \(dir): \(error)")
        }
        return dir
    }

    private func cleanup(_ dir: URL) {
        discardTestStoreDirectory(dir)
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GSLS-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GSLS-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GSLS-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private struct Fixture {
        let group: SplitGroup
        let me: SplitMember
        let pia: SplitMember
        let bcp: Account
        let sip: Account
        let comisiones: Subcategory
        let supermercado: Subcategory
        let hogar: Subcategory
    }

    private func makeFixture(_ context: ModelContext) throws -> Fixture {
        let group = SplitGroup(name: "Depa", currencyCode: "PEN")
        context.insert(group)
        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", isCurrentUser: true)
        context.insert(me)
        let pia = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Pía")
        context.insert(pia)
        let bcp = Account(name: "BCP", currencyCode: "PEN", colorHex: "#111111", iconName: "creditcard", type: "bank")
        context.insert(bcp)
        let sip = Account(name: "Sip", currencyCode: "PEN", colorHex: "#222222", iconName: "tram", type: "card")
        context.insert(sip)
        let cat = makeTestCategory(context: context, name: "Gastos")
        let comisiones = makeTestSubcategory(context: context, name: "Comisiones", category: cat)
        let supermercado = makeTestSubcategory(context: context, name: "Supermercado", category: cat)
        let hogar = makeTestSubcategory(context: context, name: "Hogar", category: cat)
        try context.save()
        return Fixture(group: group, me: me, pia: pia, bcp: bcp, sip: sip,
                       comisiones: comisiones, supermercado: supermercado, hogar: hogar)
    }

    private func withBridge(_ context: ModelContext, hasPrivateSession: Bool = true, _ body: () throws -> Void) rethrows {
        GroupTransactionBridge.shared.setContext(context)
        let previous = SessionState.shared.hasPrivateSession
        SessionState.shared.hasPrivateSession = hasPrivateSession
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            SessionState.shared.hasPrivateSession = previous
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        }
        try body()
    }

    private func expense(
        _ context: ModelContext, _ f: Fixture, total: Double, myShare: Double, paidByMe: Bool,
        description: String = "Gasto"
    ) throws -> (SplitExpense, SplitShare) {
        let expense = SplitExpense(
            groupZoneID: f.group.cloudKitZoneID, amount: total, currencyCode: "PEN",
            expenseDescription: description, paidByMemberID: (paidByMe ? f.me : f.pia).id.uuidString)
        context.insert(expense)
        let share = SplitShare(expenseID: expense.id, memberID: f.me.id.uuidString, amount: myShare,
                               groupZoneID: f.group.cloudKitZoneID)
        context.insert(share)
        try context.save()
        return (expense, share)
    }

    private func bridge(_ context: ModelContext, _ e: SplitExpense, _ f: Fixture, account: Account? = nil) throws {
        try GroupTransactionBridge.shared.bridgeExpense(e, in: f.group, accountForCurrentUser: account, shouldSave: false)
        try context.save()
    }

    private func legs(_ context: ModelContext, _ e: SplitExpense) throws -> [TransactionItem] {
        let id = e.id.uuidString
        return try context.fetch(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.splitExpenseID == id }))
    }

    private func all(_ context: ModelContext) throws -> [TransactionItem] {
        try context.fetch(FetchDescriptor<TransactionItem>())
    }

    private func movements(of account: Account, _ context: ModelContext) throws -> [TransactionItem] {
        try all(context).filter { $0.account?.persistentModelID == account.persistentModelID }
    }

    private func leg(_ context: ModelContext, _ e: SplitExpense, subcategoryNamed name: String) throws -> TransactionItem? {
        let expenseLegs = try legs(context, e)
        return expenseLegs.first { $0.subcategory?.name == name }
    }

    private func realLeg(_ context: ModelContext, _ e: SplitExpense) throws -> TransactionItem? {
        let expenseLegs = try legs(context, e)
        return expenseLegs.first { $0.account?.isSystemAccount == false }
    }

    private func transferOut(_ context: ModelContext, _ e: SplitExpense) throws -> TransactionItem? {
        let expenseLegs = try legs(context, e)
        return expenseLegs.first { $0.balanceAdjustmentType != nil }
    }

    private func systemAmounts(_ context: ModelContext, _ e: SplitExpense) throws -> [Double] {
        let expenseLegs = try legs(context, e)
        return expenseLegs.filter { $0.account?.isSystemAccount == true }.map(\.amount).sorted()
    }

    private func balance(of account: Account, _ context: ModelContext) throws -> Double {
        let txs = try movements(of: account, context)
        return txs.reduce(0) { $0 + $1.amount }
    }

    private func groupsBalance(_ context: ModelContext) throws -> Double {
        let txs = try all(context)
        return txs.filter { $0.account?.isSystemAccount == true }.reduce(0) { $0 + $1.amount }
    }

    private func drafts(_ context: ModelContext, _ e: SplitExpense) throws -> [InboxDraft] {
        let id = e.id.uuidString
        return try context.fetch(FetchDescriptor<InboxDraft>(predicate: #Predicate { $0.splitExpenseID == id }))
    }

    /// Lo que Estadísticas suma por subcategoría: sin transferencias (`balanceAdjustmentType`), con el ajuste del puente
    /// construido con todo el corpus y las patas suprimidas fuera. Gasto en positivo.
    private func statsBySubcategory(_ context: ModelContext) throws -> [String: Double] {
        let txs = try all(context)
        let adjustment = GroupBridgeStatsAdjustment.build(from: txs, context: context)
        var result: [String: Double] = [:]
        for tx in txs where tx.balanceAdjustmentType == nil {
            guard let value = adjustment.incomeAwareNative(tx), value < 0 else { continue }
            result[tx.subcategory?.name ?? "—", default: 0] += -value
        }
        return result
    }

    private func pia(_ f: Fixture) -> [GroupSplitLinesRecipe.Line] {
        [.transfer(amount: 500, destinationAccountID: f.sip.shortcutID),
         .expense(amount: 10, subcategoryID: f.comisiones.shortcutID)]
    }

    /// Caso B: crea la pata de tu parte, le pone la receta (lo que hará «Partir») y vuelve a pasar el puente.
    private func bridgeCaseBWithRecipe(
        _ context: ModelContext, _ f: Fixture, total: Double, myShare: Double,
        lines: [GroupSplitLinesRecipe.Line]
    ) throws -> (SplitExpense, SplitShare, TransactionItem) {
        let (e, share) = try expense(context, f, total: total, myShare: myShare, paidByMe: false)
        try bridge(context, e, f)
        let holder = try #require(try legs(context, e).first)
        holder.splitLinesRaw = GroupSplitLinesRecipe.encode(lines)
        try context.save()
        try bridge(context, e, f)
        return (e, share, holder)
    }

    private func target(_ context: ModelContext, _ e: SplitExpense) throws -> GroupSplitLinesService.Target {
        try #require(try GroupSplitLinesService.target(splitExpenseID: e.id.uuidString, context: context))
    }

    private func approve(_ context: ModelContext, _ draft: InboxDraft, lines: [GroupSplitLinesRecipe.Line]?) throws {
        DraftService.shared.setContext(context)
        _ = try DraftService.shared.approveDraft(draft, currencyConverter: CurrencyConverter(), splitLines: lines)
    }

    // MARK: - Lo que lee la tarjeta

    @Test func pia_target_isYourShareInGroups_withOneLineToStart() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _) = try expense(context, f, total: 510, myShare: 510, paidByMe: false)
            try bridge(context, e, f)
            let t = try target(context, e)
            #expect(t.offersSplit)
            #expect(!t.isCaseA)
            #expect(t.share == 510)
            #expect(t.holder?.account?.isSystemAccount == true)
            #expect(t.transferSourceName == t.holder?.account?.name)
            #expect(t.transferSourceAccount == nil)
            #expect(t.initialLines.count == 1)
            #expect(t.initialLines.first?.kind == .expense)
            #expect(t.initialLines.first?.amount == 510)
        }
    }

    @Test func super_target_isTheRealLeg_andTheRechargeLeavesFromYourAccount() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _) = try expense(context, f, total: 200, myShare: 100, paidByMe: true, description: "Súper")
            try bridge(context, e, f, account: f.bcp)
            let t = try target(context, e)
            #expect(t.offersSplit)
            #expect(t.isCaseA)
            #expect(t.share == 100)
            #expect(t.holder?.account?.persistentModelID == f.bcp.persistentModelID)
            #expect(t.transferSourceAccount?.persistentModelID == f.bcp.persistentModelID)
            #expect(t.transferSourceName == "BCP")
        }
    }

    @Test func groupsOnlySession_doesNotOfferTheSplit() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        var built: SplitExpense?
        try withBridge(context) {
            let (e, _) = try expense(context, f, total: 510, myShare: 510, paidByMe: false)
            try bridge(context, e, f)
            built = e
        }
        let e = try #require(built)
        try withBridge(context, hasPrivateSession: false) {
            let offers = try target(context, e).offersSplit
            #expect(!offers)
        }
    }

    @Test func zeroShare_doesNotOfferTheSplit() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _) = try expense(context, f, total: 90, myShare: 0, paidByMe: true)
            try bridge(context, e, f, account: f.bcp)
            let offers = try target(context, e).offersSplit
            #expect(!offers)
        }
    }

    @Test func aSale_doesNotOfferTheSplit_evenWithAShareOfYourOwn() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        let incomes = makeTestCategory(context: context, name: "Ingresos", isIncome: true)
        _ = makeTestSubcategory(context: context, name: "Ventas", category: incomes)
        try context.save()
        try withBridge(context) {
            let (e, _) = try expense(context, f, total: 120, myShare: 20, paidByMe: true, description: "Zapatillas")
            e.subcategoryName = "Ventas"
            try context.save()
            try bridge(context, e, f)
            let offers = try target(context, e).offersSplit
            #expect(!offers)
        }
    }

    // MARK: - Card 5 · Bandeja

    @Test func inbox_pia_approvingWithLines_leavesTheRechargeAndTheFee_andNoDraft() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _) = try expense(context, f, total: 510, myShare: 510, paidByMe: false)
            try bridge(context, e, f)
            let draft = try #require(try drafts(context, e).first)
            let lines = pia(f)
            try approve(context, draft, lines: lines)

            #expect(try drafts(context, e).isEmpty)
            #expect(try groupsBalance(context) == -510)
            #expect(try movements(of: f.sip, context).map(\.amount) == [500])
            #expect(try statsBySubcategory(context) == ["Comisiones": 10])
            let holder = try #require(try leg(context, e, subcategoryNamed: "Comisiones"))
            #expect(GroupSplitLinesRecipe.parse(holder.splitLinesRaw) == .recipe(lines))
        }
    }

    @Test func inbox_mismatch_opensWithTheStoredRecipe_andApprovingWithLinesRewritesIt() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, share) = try expense(context, f, total: 510, myShare: 510, paidByMe: false)
            try bridge(context, e, f)
            let holder = try #require(try legs(context, e).first)
            let original = pia(f)
            holder.splitLinesRaw = GroupSplitLinesRecipe.encode(original)
            try context.save()
            try bridge(context, e, f)

            e.amount = 520
            share.amount = 520
            try context.save()
            try bridge(context, e, f)
            let notice = try #require(try drafts(context, e).first)
            #expect(notice.isSplitLinesMismatchNotice)

            // La tarjeta abre con la receta que había, para arreglarla.
            let t = try target(context, e)
            #expect(t.share == 520)
            #expect(t.initialLines == original)

            let fixed: [GroupSplitLinesRecipe.Line] = [
                .transfer(amount: 510, destinationAccountID: f.sip.shortcutID),
                .expense(amount: 10, subcategoryID: f.comisiones.shortcutID),
            ]
            try approve(context, notice, lines: fixed)
            #expect(try drafts(context, e).isEmpty)
            #expect(try groupsBalance(context) == -520)
            #expect(try movements(of: f.sip, context).map(\.amount) == [510])
            #expect(GroupSplitLinesRecipe.parse(holder.splitLinesRaw) == .recipe(fixed))
        }
    }

    @Test func inbox_withoutLines_approvesAsToday() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _) = try expense(context, f, total: 510, myShare: 510, paidByMe: false)
            try bridge(context, e, f)
            let draft = try #require(try drafts(context, e).first)
            draft.subcategory = f.comisiones
            try approve(context, draft, lines: nil)
            #expect(try drafts(context, e).isEmpty)
            #expect(try legs(context, e).map(\.amount) == [-510])
            #expect(try legs(context, e).first?.splitLinesRaw == nil)
            #expect(try movements(of: f.sip, context).isEmpty)
        }
    }

    // MARK: - Card 6 · pantalla de éxito y detalle

    @Test func success_super_savingTwoLines_isSupermercado80_andHogar20() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _) = try expense(context, f, total: 200, myShare: 100, paidByMe: true, description: "Súper")
            try bridge(context, e, f, account: f.bcp)
            let lines: [GroupSplitLinesRecipe.Line] = [
                .expense(amount: 80, subcategoryID: f.supermercado.shortcutID),
                .expense(amount: 20, subcategoryID: f.hogar.shortcutID),
            ]
            try GroupSplitLinesService.save(lines, for: try target(context, e), context: context)

            let real = try #require(try realLeg(context, e))
            #expect(real.amount == -200)
            #expect(real.subcategory?.persistentModelID == f.supermercado.persistentModelID)
            #expect(try groupsBalance(context) == 100)
            #expect(try statsBySubcategory(context) == ["Supermercado": 80, "Hogar": 20])
            #expect(try drafts(context, e).isEmpty)
        }
    }

    @Test func detail_pia_backToOneLine_dropsTheRecipe_andTheRecharge_andAsksNothing() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _) = try expense(context, f, total: 510, myShare: 510, paidByMe: false)
            try bridge(context, e, f)
            // Solo una recarga: la pata conservada es la salida del par (la forma más difícil de deshacer).
            let onlyRecharge: [GroupSplitLinesRecipe.Line] = [.transfer(amount: 510, destinationAccountID: f.sip.shortcutID)]
            try GroupSplitLinesService.save(onlyRecharge, for: try target(context, e), context: context)
            #expect(try movements(of: f.sip, context).map(\.amount) == [510])

            let back: [GroupSplitLinesRecipe.Line] = [.expense(amount: 510, subcategoryID: f.comisiones.shortcutID)]
            try GroupSplitLinesService.save(back, for: try target(context, e), context: context)
            let holder = try #require(try legs(context, e).first)
            #expect(try legs(context, e).count == 1)
            #expect(holder.amount == -510)
            #expect(holder.splitLinesRaw == nil)
            #expect(holder.balanceAdjustmentType == nil)
            #expect(holder.subcategory?.persistentModelID == f.comisiones.persistentModelID)
            #expect(try movements(of: f.sip, context).isEmpty)
            #expect(try drafts(context, e).isEmpty)
        }
    }
}
