//
//  GroupBridgeSplitLinesTests.swift
//  YalaTests / CloudSync
//
//  Grupos B · cards 2 y 3: el puente crea tus registros desde las líneas de tu parte (gasto o recarga) y Estadísticas no
//  cuenta la recarga. De punta a punta con `bridgeExpense`, sobre el harness on-disk de `GroupBridgeCaseBPreserveTests`
//  (los tres stores; `shouldSave: false` + save manual; el host de tests deja el puente activo).
//
//  Los casos del encargo: Pía (pagó otro, 500 de recarga a Sip + 10 de comisión) deja Grupos −510, Sip +500 y 10 de gasto;
//  el súper (pagaste 200, tu parte 100 = Supermercado 80 + Hogar 20) da 80 + 20 en Estadísticas.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos B · el puente crea tus registros desde las líneas", .serialized)
@MainActor
struct GroupBridgeSplitLinesTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupBridgeSplitLines-\(UUID().uuidString)", isDirectory: true)
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
            "GBSL-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GBSL-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GBSL-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
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

    // MARK: - Caso B: Pía

    @Test func pia_leavesGroupsMinus510_sipPlus500_andAnExpenseOf10() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let lines = pia(f)
            let (e, _, holder) = try bridgeCaseBWithRecipe(context, f, total: 510, myShare: 510, lines: lines)

            // La pata conservada es la línea de gasto (la ancla) y lleva la receta.
            #expect(holder.amount == -10)
            #expect(holder.subcategory?.persistentModelID == f.comisiones.persistentModelID)
            #expect(holder.balanceAdjustmentType == nil)
            #expect(GroupSplitLinesRecipe.parse(holder.splitLinesRaw) == .recipe(lines))

            // La recarga sale de «Grupos» como transferencia, con el gasto y la marca de su línea.
            let rechargeLine = lines[0]
            let out = try #require(try transferOut(context, e))
            #expect(out.amount == -500)
            #expect(out.account?.isSystemAccount == true)
            #expect(out.transferPairID == rechargeLine.id.uuidString)
            #expect(GroupSplitLinesBridgeLogic.derivedLineID(out.splitLinesRaw) == rechargeLine.id)

            // Y entra en Sip sin puntero de grupo (D4), con el mismo par y la marca.
            let entry = try #require(try movements(of: f.sip, context).first)
            #expect(entry.amount == 500)
            #expect(entry.splitExpenseID == nil && entry.splitGroupZoneID == nil)
            #expect(entry.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer)
            #expect(entry.transferPairID == out.transferPairID)
            #expect(GroupSplitLinesBridgeLogic.isDerivedMarker(entry.splitLinesRaw))

            #expect(try groupsBalance(context) == -510)
            #expect(try balance(of: f.sip, context) == 500)
            // Card 3: Estadísticas cuenta 10 de Comisiones y nada de la recarga.
            #expect(try statsBySubcategory(context) == ["Comisiones": 10])
            // Ningún puntero de la Bandeja: la receta ya clasifica tu parte.
            #expect(try drafts(context, e).isEmpty)
        }
    }

    @Test func pia_aSecondPass_keepsTheSameRecords() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _, _) = try bridgeCaseBWithRecipe(context, f, total: 510, myShare: 510, lines: pia(f))
            let before = Set(try all(context).map(\.persistentModelID))
            try bridge(context, e, f)
            try bridge(context, e, f)
            #expect(Set(try all(context).map(\.persistentModelID)) == before)
            #expect(try all(context).count == 3)
        }
    }

    @Test func onlyARecharge_theKeptLegIsTheTransferOut() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let lines: [GroupSplitLinesRecipe.Line] = [.transfer(amount: 510, destinationAccountID: f.sip.shortcutID)]
            let (e, _, holder) = try bridgeCaseBWithRecipe(context, f, total: 510, myShare: 510, lines: lines)
            #expect(holder.amount == -510)
            #expect(holder.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer)
            #expect(holder.transferPairID == lines[0].id.uuidString)
            #expect(try legs(context, e).count == 1)
            #expect(try movements(of: f.sip, context).map(\.amount) == [510])
            #expect(try statsBySubcategory(context).isEmpty)
        }
    }

    // MARK: - Caso A: el súper

    @Test func super_caseA_isSupermercado80_andHogar20_inStatistics() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _) = try expense(context, f, total: 200, myShare: 100, paidByMe: true, description: "Súper")
            try bridge(context, e, f, account: f.bcp)
            let real = try #require(try realLeg(context, e))
            let lines: [GroupSplitLinesRecipe.Line] = [
                .expense(amount: 80, subcategoryID: f.supermercado.shortcutID),
                .expense(amount: 20, subcategoryID: f.hogar.shortcutID),
            ]
            real.splitLinesRaw = GroupSplitLinesRecipe.encode(lines)
            try context.save()
            try bridge(context, e, f)

            // BCP −200 con la categoría de la primera línea; Grupos +120 − 20 = +100 (Pía te debe 100).
            #expect(real.amount == -200)
            #expect(real.subcategory?.persistentModelID == f.supermercado.persistentModelID)
            #expect(try systemAmounts(context, e) == [-20, 120])
            #expect(try groupsBalance(context) == 100)
            #expect(try statsBySubcategory(context) == ["Supermercado": 80, "Hogar": 20])
        }
    }

    @Test func caseA_withARecharge_goesThroughGroups_andStatisticsIgnoreIt() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _) = try expense(context, f, total: 200, myShare: 100, paidByMe: true)
            try bridge(context, e, f, account: f.bcp)
            let real = try #require(try realLeg(context, e))
            real.splitLinesRaw = GroupSplitLinesRecipe.encode([
                .expense(amount: 80, subcategoryID: f.supermercado.shortcutID),
                .transfer(amount: 20, destinationAccountID: f.sip.shortcutID),
            ])
            try context.save()
            try bridge(context, e, f)

            #expect(try balance(of: f.bcp, context) == -200)
            #expect(try balance(of: f.sip, context) == 20)
            #expect(try groupsBalance(context) == 100)
            #expect(try statsBySubcategory(context) == ["Supermercado": 80])
        }
    }

    // MARK: - Cambio de monto (D6)

    @Test func whenTheShareChanges_yourShareGoesBackToOneLine_keepsTheRecipe_andAsksInTheInbox() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, share, holder) = try bridgeCaseBWithRecipe(context, f, total: 510, myShare: 510, lines: pia(f))
            let recipe = holder.splitLinesRaw

            e.amount = 520
            share.amount = 520
            try context.save()
            try bridge(context, e, f)

            // Una sola pata de 520; la recarga y su entrada en Sip, fuera; la receta, intacta.
            #expect(try legs(context, e).map(\.amount) == [-520])
            #expect(try movements(of: f.sip, context).isEmpty)
            #expect(holder.splitLinesRaw == recipe)
            let notice = try #require(try drafts(context, e).first)
            #expect(try drafts(context, e).count == 1)
            #expect(notice.isSplitLinesMismatchNotice)
            #expect(notice.requiresApprovalForm)
            #expect(notice.needsUserInput == [DraftInputRequirement.subcategory])
            #expect(notice.amount == -520)

            // Vuelve a cuadrar: la receta se aplica otra vez y el aviso se va.
            e.amount = 510
            share.amount = 510
            try context.save()
            try bridge(context, e, f)
            #expect(try groupsBalance(context) == -510)
            #expect(try movements(of: f.sip, context).map(\.amount) == [500])
            #expect(try drafts(context, e).isEmpty)
        }
    }

    @Test func approvingTheMismatchNotice_leavesOneLineWithThatCategory_andDropsTheRecipe() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        DraftService.shared.setContext(context)
        defer { DraftService.shared.setContext(nil) }
        try withBridge(context) {
            let (e, share, holder) = try bridgeCaseBWithRecipe(context, f, total: 510, myShare: 510, lines: pia(f))
            e.amount = 520
            share.amount = 520
            try context.save()
            try bridge(context, e, f)
            let notice = try #require(try drafts(context, e).first)
            notice.subcategory = f.hogar

            let approved = try DraftService.shared.approveDraft(notice, currencyConverter: CurrencyConverter())

            #expect(approved.persistentModelID == holder.persistentModelID)
            #expect(holder.splitLinesRaw == nil)
            #expect(holder.subcategory?.persistentModelID == f.hogar.persistentModelID)
            #expect(try all(context).count == 1)
            #expect(try drafts(context, e).isEmpty)
        }
    }

    @Test func approvingTheNotice_afterAnotherDeviceFixedTheRecipe_keepsTheRecipe() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        DraftService.shared.setContext(context)
        defer { DraftService.shared.setContext(nil) }
        try withBridge(context) {
            let (e, share, holder) = try bridgeCaseBWithRecipe(context, f, total: 510, myShare: 510, lines: pia(f))
            e.amount = 520
            share.amount = 520
            try context.save()
            try bridge(context, e, f)
            let notice = try #require(try drafts(context, e).first)
            // Otro aparato reescribe las líneas para que sumen 520 antes de que aquí se apruebe el aviso.
            let fixed: [GroupSplitLinesRecipe.Line] = [.transfer(amount: 500, destinationAccountID: f.sip.shortcutID),
                                                      .expense(amount: 20, subcategoryID: f.comisiones.shortcutID)]
            holder.splitLinesRaw = GroupSplitLinesRecipe.encode(fixed)
            try context.save()
            notice.subcategory = f.hogar

            _ = try DraftService.shared.approveDraft(notice, currencyConverter: CurrencyConverter())

            #expect(GroupSplitLinesRecipe.parse(holder.splitLinesRaw) == .recipe(fixed))
            #expect(holder.subcategory?.persistentModelID != f.hogar.persistentModelID)
            #expect(try drafts(context, e).isEmpty)
        }
    }

    // MARK: - Borrado

    @Test func deletingTheExpense_takesTheRechargeEntryWithIt() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _, _) = try bridgeCaseBWithRecipe(context, f, total: 510, myShare: 510, lines: pia(f))
            #expect(try all(context).count == 3)
            try GroupTransactionBridge.shared.unbridgeExpense(expenseID: e.id.uuidString)
            #expect(try all(context).isEmpty)
        }
    }

    @Test func aRemoteDeletion_takesTheRechargeEntryWithIt() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _, _) = try bridgeCaseBWithRecipe(context, f, total: 510, myShare: 510, lines: pia(f))
            let removed = try GroupTransactionBridge.shared.unbridgeDeletedRemotely(expenseIDs: [e.id], settlementIDs: [])
            #expect(removed.transactions == 3)
            #expect(try all(context).isEmpty)
        }
    }

    @Test func leavingTheGroup_leavesTheRechargeAsANormalTransfer() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            _ = try bridgeCaseBWithRecipe(context, f, total: 510, myShare: 510, lines: pia(f))
            try GroupTransactionBridge.shared.freezeForSoftDelete(zoneID: f.group.cloudKitZoneID)
            let entry = try #require(try movements(of: f.sip, context).first)
            #expect(entry.splitLinesRaw == nil)
            #expect(entry.transferPairID != nil)
            #expect(try all(context).count == 3)
        }
    }

    // MARK: - Sin puente o sin vida personal (D5)

    @Test func groupsOnlySession_doesNotApplyTheRecipe_andKeepsIt() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        var holder: TransactionItem?
        var e: SplitExpense?
        try withBridge(context) {
            let built = try bridgeCaseBWithRecipe(context, f, total: 510, myShare: 510, lines: pia(f))
            holder = built.2
            e = built.0
        }
        let kept = try #require(holder)
        let expense = try #require(e)
        let recipe = kept.splitLinesRaw
        try withBridge(context, hasPrivateSession: false) {
            try bridge(context, expense, f)
            #expect(try legs(context, expense).map(\.amount) == [-510])
            #expect(try movements(of: f.sip, context).isEmpty)
            #expect(kept.splitLinesRaw == recipe)
            #expect(!(try drafts(context, expense).contains(where: \.isSplitLinesMismatchNotice)))
        }
    }

    @Test func aDestinationThatIsGone_isOneLine_withoutAnInboxNotice() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let lines: [GroupSplitLinesRecipe.Line] = [.transfer(amount: 500, destinationAccountID: UUID()),
                                                      .expense(amount: 10, subcategoryID: f.comisiones.shortcutID)]
            let (e, _, holder) = try bridgeCaseBWithRecipe(context, f, total: 510, myShare: 510, lines: lines)
            #expect(try legs(context, e).map(\.amount) == [-510])
            #expect(holder.splitLinesRaw != nil)
            #expect(!(try drafts(context, e).contains(where: \.isSplitLinesMismatchNotice)))
        }
    }

    // MARK: - Lo que no debe borrar las líneas

    @Test func theSplitReconciler_doesNotPruneDerivedLines() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _) = try expense(context, f, total: 200, myShare: 100, paidByMe: true)
            try bridge(context, e, f, account: f.bcp)
            let real = try #require(try realLeg(context, e))
            real.splitLinesRaw = GroupSplitLinesRecipe.encode([
                .expense(amount: 80, subcategoryID: f.supermercado.shortcutID),
                .transfer(amount: 20, destinationAccountID: f.sip.shortcutID),
            ])
            try context.save()
            try bridge(context, e, f)
            let before = try all(context).count

            let stats = CloudSyncReconciler.reconcileSplitRepresentations(context: context)
            try context.save()
            #expect(stats.pruned == 0)
            #expect(try all(context).count == before)
        }
    }

    @Test func theTransferReconciler_leavesAHalfArrivedRechargeAlone() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _, _) = try bridgeCaseBWithRecipe(context, f, total: 510, myShare: 510, lines: pia(f))
            // La salida aún no bajó a este teléfono: solo está la entrada.
            let out = try #require(try transferOut(context, e))
            context.delete(out)
            try context.save()

            _ = TransferPairReconcileService.reconcileTransferPairs(in: context)

            let entry = try #require(try movements(of: f.sip, context).first)
            #expect(entry.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer)
            #expect(entry.transferPairID != nil)
            // Y la pasada siguiente rehace la salida sobre la misma entrada.
            try bridge(context, e, f)
            #expect(try movements(of: f.sip, context).map(\.persistentModelID) == [entry.persistentModelID])
            #expect(try groupsBalance(context) == -510)
        }
    }

    // MARK: - La review del puente (2026-11-01)

    @Test func whenTheRechargeBecomesTheAnchor_itsEntryIsKept_notDeletedByTheLegItLeaves() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let lines = pia(f)
            let (e, _, holder) = try bridgeCaseBWithRecipe(context, f, total: 510, myShare: 510, lines: lines)
            let entry = try #require(try movements(of: f.sip, context).first)

            // La misma recarga, ahora sola: pasa de derivada a ancla.
            holder.splitLinesRaw = GroupSplitLinesRecipe.encode(
                [.transfer(id: lines[0].id, amount: 510, destinationAccountID: f.sip.shortcutID)])
            try context.save()
            try bridge(context, e, f)

            #expect(try movements(of: f.sip, context).map(\.persistentModelID) == [entry.persistentModelID])
            #expect(entry.amount == 510)
            #expect(holder.transferPairID == lines[0].id.uuidString)
            #expect(try groupsBalance(context) == -510)
        }
    }

    @Test func whenTheAnchorRechargeIsReplaced_theOldEntryGoes() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let first: [GroupSplitLinesRecipe.Line] = [.transfer(amount: 510, destinationAccountID: f.sip.shortcutID)]
            let (e, _, holder) = try bridgeCaseBWithRecipe(context, f, total: 510, myShare: 510, lines: first)
            let second: [GroupSplitLinesRecipe.Line] = [.transfer(amount: 510, destinationAccountID: f.sip.shortcutID)]
            holder.splitLinesRaw = GroupSplitLinesRecipe.encode(second)
            try context.save()
            try bridge(context, e, f)

            let sip = try movements(of: f.sip, context)
            #expect(sip.count == 1)
            #expect(sip.first?.transferPairID == second[0].id.uuidString)
            #expect(try balance(of: f.sip, context) == 510)
        }
    }

    @Test func twoCopiesOfADerivedLine_keepTheOldest_onBothDevices() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let lines = pia(f)
            let (e, _, _) = try bridgeCaseBWithRecipe(context, f, total: 510, myShare: 510, lines: lines)
            let out = try #require(try transferOut(context, e))
            // La copia que creó el otro aparato, más nueva.
            let copy = TransactionItem(date: out.date, amount: out.amount, currencyCode: "PEN", account: out.account)
            copy.splitExpenseID = out.splitExpenseID
            copy.splitGroupZoneID = out.splitGroupZoneID
            copy.splitLinesRaw = out.splitLinesRaw
            copy.balanceAdjustmentType = out.balanceAdjustmentType
            copy.transferPairID = out.transferPairID
            copy.createdAt = out.createdAt.addingTimeInterval(5)
            context.insert(copy)
            try context.save()

            let outID = out.persistentModelID
            try bridge(context, e, f)

            // Sobrevive la más antigua, la misma que elegiría el otro aparato; no una nueva.
            #expect(try transferOut(context, e)?.persistentModelID == outID)
            #expect(try legs(context, e).count == 2)
            #expect(try groupsBalance(context) == -510)
            #expect(try movements(of: f.sip, context).count == 1)
        }
    }

    @Test func leavingTheGroup_thenBooting_keepsTheRechargeAsATransfer() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            _ = try bridgeCaseBWithRecipe(context, f, total: 510, myShare: 510, lines: pia(f))
            try GroupTransactionBridge.shared.freezeForSoftDelete(zoneID: f.group.cloudKitZoneID)
            _ = TransferPairReconcileService.reconcileTransferPairs(in: context)
            let entry = try #require(try movements(of: f.sip, context).first)
            #expect(entry.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer)
            #expect(entry.transferPairID != nil)
        }
    }

    @Test func derivedExpenseLines_carryTheTagsOfYourShare() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _) = try expense(context, f, total: 200, myShare: 100, paidByMe: true)
            try bridge(context, e, f, account: f.bcp)
            let real = try #require(try realLeg(context, e))
            let viaje = makeTestTag(context: context, name: "Viaje")
            real.setTags(from: [viaje])
            real.splitLinesRaw = GroupSplitLinesRecipe.encode([
                .expense(amount: 80, subcategoryID: f.supermercado.shortcutID),
                .expense(amount: 20, subcategoryID: f.hogar.shortcutID),
            ])
            try context.save()
            try bridge(context, e, f)

            let hogar = try #require(try leg(context, e, subcategoryNamed: "Hogar"))
            #expect(hogar.resolvedTagIDs() == [viaje.id])
        }
    }

    @Test func aSweeperReleasingTheRealLegFirst_stillDeletesTheEntryWithItsOutLeg() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _) = try expense(context, f, total: 200, myShare: 100, paidByMe: true)
            try bridge(context, e, f, account: f.bcp)
            let real = try #require(try realLeg(context, e))
            real.splitLinesRaw = GroupSplitLinesRecipe.encode([
                .expense(amount: 80, subcategoryID: f.supermercado.shortcutID),
                .transfer(amount: 20, destinationAccountID: f.sip.shortcutID),
            ])
            try context.save()
            try bridge(context, e, f)
            let out = try #require(try transferOut(context, e))

            // El orden de un barrido: la real se suelta antes de borrar la salida.
            GroupTransactionBridge.releaseSplitLines(of: real, context: context)
            GroupTransactionBridge.deleteSplitLineEntries(of: out, context: context)
            context.delete(out)
            try context.save()

            #expect(real.splitLinesRaw == nil)
            #expect(try movements(of: f.sip, context).isEmpty)
        }
    }

    // MARK: - Lo que la persona puede tocar

    @Test func theRechargeEntry_isLockedLikeAnyBridgeLeg() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            _ = try bridgeCaseBWithRecipe(context, f, total: 510, myShare: 510, lines: pia(f))
            let entry = try #require(try movements(of: f.sip, context).first)
            let actions = RecordContextActionLogic.actions(.init(record: entry))
            #expect(!actions.canDelete)
            #expect(!actions.canDuplicate)
            #expect(!RecordBulkActionLogic.allows(.delete, .init(record: entry)))
        }
    }
}
