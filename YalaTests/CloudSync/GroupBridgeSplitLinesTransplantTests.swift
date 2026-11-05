//
//  GroupBridgeSplitLinesTransplantTests.swift
//  YalaTests / CloudSync
//
//  Grupos B · card sbvw: las líneas de tu parte sobreviven a un cambio de pagador o de divisa del gasto. La receta vivía
//  en la pata que el puente conserva (la real si pagaste tú, la de «Grupos» si pagó otro); al cambiar de pagador esa pata
//  se iba y la receta con ella. Ahora se trasplanta a la pata nueva en la misma pasada.
//
//  De punta a punta con `bridgeExpense`, sobre un harness on-disk con los tres stores, sin autoguardado y con el puente
//  soltado al salir (regla de `.claude/rules/testing.md`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos B · la receta sobrevive a un cambio de pagador o de divisa", .serialized)
@MainActor
struct GroupBridgeSplitLinesTransplantTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupBridgeTransplant-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("no se pudo crear \(dir): \(error)")
        }
        return dir
    }

    private func cleanup(_ dir: URL) {
        GroupTransactionBridge.shared._testClearContext()
        discardTestStoreDirectory(dir)
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GBTP-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GBTP-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GBTP-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personalCfg, groupsCfg, syncMetaCfg)
        let context = ModelContext(container)
        // Sin autoguardado: un guardado diferido que salte después de borrar el store tumba el proceso de tests entero.
        context.autosaveEnabled = false
        return context
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

    private func withBridge(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupTransactionBridge.shared.setContext(context)
        let previous = SessionState.shared.hasPrivateSession
        SessionState.shared.hasPrivateSession = true
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            SessionState.shared.hasPrivateSession = previous
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        }
        try body()
    }

    private func expense(
        _ context: ModelContext, _ f: Fixture, total: Double, myShare: Double, paidByMe: Bool
    ) throws -> (SplitExpense, SplitShare) {
        let expense = SplitExpense(
            groupZoneID: f.group.cloudKitZoneID, amount: total, currencyCode: "PEN",
            expenseDescription: "Gasto", paidByMemberID: (paidByMe ? f.me : f.pia).id.uuidString)
        context.insert(expense)
        let share = SplitShare(expenseID: expense.id, memberID: f.me.id.uuidString, amount: myShare,
                               groupZoneID: f.group.cloudKitZoneID)
        context.insert(share)
        try context.save()
        return (expense, share)
    }

    private func bridge(
        _ context: ModelContext, _ e: SplitExpense, _ f: Fixture, account: Account? = nil, remote: Bool = false
    ) throws {
        try GroupTransactionBridge.shared.bridgeExpense(
            e, in: f.group, accountForCurrentUser: account, isRemoteSync: remote, shouldSave: false)
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

    private func groupsBalance(_ context: ModelContext) throws -> Double {
        try all(context).filter { $0.account?.isSystemAccount == true }.reduce(0) { $0 + $1.amount }
    }

    private func drafts(_ context: ModelContext, _ e: SplitExpense) throws -> [InboxDraft] {
        let id = e.id.uuidString
        return try context.fetch(FetchDescriptor<InboxDraft>(predicate: #Predicate { $0.splitExpenseID == id }))
    }

    /// Lo que Estadísticas suma por subcategoría (gasto en positivo), con el ajuste del puente.
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

    /// La pata que lleva la receta (la que el puente conserva), si hay una.
    private func recipeHolders(_ context: ModelContext, _ e: SplitExpense) throws -> [TransactionItem] {
        try legs(context, e).filter {
            if case .recipe = GroupSplitLinesRecipe.parse($0.splitLinesRaw) { return true }
            return false
        }
    }

    private func superLines(_ f: Fixture) -> [GroupSplitLinesRecipe.Line] {
        [.expense(amount: 80, subcategoryID: f.supermercado.shortcutID),
         .expense(amount: 20, subcategoryID: f.hogar.shortcutID)]
    }

    private func piaLines(_ f: Fixture) -> [GroupSplitLinesRecipe.Line] {
        [.transfer(amount: 500, destinationAccountID: f.sip.shortcutID),
         .expense(amount: 10, subcategoryID: f.comisiones.shortcutID)]
    }

    // MARK: - Pagaste tú → pagó otro

    /// El súper (200 a medias, tu parte 100 = Supermercado 80 + Hogar 20) lo pagaste tú; después resulta que pagó Pía.
    @Test func caseAToCaseB_theRecipeMovesToYourShareInGroups() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _) = try expense(context, f, total: 200, myShare: 100, paidByMe: true)
            try bridge(context, e, f, account: f.bcp)
            let real = try #require(try legs(context, e).first { $0.account?.isSystemAccount == false })
            real.splitLinesRaw = GroupSplitLinesRecipe.encode(superLines(f))
            try context.save()
            try bridge(context, e, f)
            #expect(try statsBySubcategory(context) == ["Supermercado": 80, "Hogar": 20], "Control: la receta se aplicó.")

            e.paidByMemberID = f.pia.id.uuidString
            try context.save()
            try bridge(context, e, f)

            // Sin pata real; tu parte en «Grupos», partida igual: le debes 100 a Pía, 80 de súper y 20 de hogar.
            #expect(try movements(of: f.bcp, context).isEmpty)
            let holders = try recipeHolders(context, e)
            #expect(holders.count == 1, "La receta no pasó a la pata nueva.")
            #expect(holders.first?.account?.isSystemAccount == true)
            #expect(try groupsBalance(context) == -100)
            #expect(try statsBySubcategory(context) == ["Supermercado": 80, "Hogar": 20])
            #expect(try drafts(context, e).isEmpty, "Sin nada que no cuadre, la Bandeja no avisa.")
        }
    }

    // MARK: - Pagó otro → pagaste tú

    /// La recarga de Pía (510, todo tuyo: recarga 500 a Sip + comisión 10) la pagaste tú desde BCP.
    @Test func caseBToCaseA_withAnAccount_theRecipeMovesToTheRealLeg_andTheRechargeStays() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _) = try expense(context, f, total: 510, myShare: 510, paidByMe: false)
            try bridge(context, e, f)
            let holder = try #require(try legs(context, e).first)
            holder.splitLinesRaw = GroupSplitLinesRecipe.encode(piaLines(f))
            try context.save()
            try bridge(context, e, f)
            let entryBefore = try #require(try movements(of: f.sip, context).first, "Control: la recarga llegó a Sip.")
            let entryID = entryBefore.persistentModelID

            e.paidByMemberID = f.me.id.uuidString
            try context.save()
            try bridge(context, e, f, account: f.bcp)

            let real = try #require(try movements(of: f.bcp, context).first, "Pagando tú, falta la pata en BCP.")
            #expect(real.amount == -510)
            if case .recipe = GroupSplitLinesRecipe.parse(real.splitLinesRaw) {} else {
                Issue.record("La receta no pasó a la pata real: \(String(describing: real.splitLinesRaw)).")
            }
            #expect(real.subcategory?.persistentModelID == f.comisiones.persistentModelID,
                    "La pata real lleva la categoría de la primera línea de gasto.")
            #expect(try movements(of: f.sip, context).map(\.amount) == [500])
            #expect(try movements(of: f.sip, context).first?.persistentModelID == entryID,
                    "La entrada de la recarga se rehízo en vez de conservarse.")
            #expect(try groupsBalance(context) == 0)
            #expect(try statsBySubcategory(context) == ["Comisiones": 10])
            #expect(try drafts(context, e).isEmpty)
        }
    }

    /// Residual escrito en el Paso 0: el pagador pasa a ti desde OTRO aparato (sin cuenta aquí). No nace la pata real en
    /// la pasada, así que no hay a dónde trasplantar: tu parte queda en un borrador que pide la cuenta, como hoy, sin
    /// patas derivadas sueltas en «Grupos».
    @Test func caseBToCaseA_fromAnotherDevice_leavesTheAccountDraft_andNoLooseLines() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _) = try expense(context, f, total: 200, myShare: 100, paidByMe: false)
            try bridge(context, e, f)
            let holder = try #require(try legs(context, e).first)
            holder.splitLinesRaw = GroupSplitLinesRecipe.encode(superLines(f))
            try context.save()
            try bridge(context, e, f)

            e.paidByMemberID = f.me.id.uuidString
            try context.save()
            try bridge(context, e, f, remote: true)

            #expect(try legs(context, e).allSatisfy { !GroupSplitLinesBridgeLogic.isDerivedMarker($0.splitLinesRaw) },
                    "Sin pata real, una línea derivada en «Grupos» contaría un gasto que aún no registraste.")
            #expect(try drafts(context, e).contains { $0.needsUserInput.contains(DraftInputRequirement.account) },
                    "Falta el borrador de la Bandeja que pide la cuenta.")
        }
    }

    /// Las etiquetas y la necesidad de tu parte pasan con la receta, y las líneas derivadas las siguen llevando (review).
    @Test func caseAToCaseB_yourTagsAndNeedTravelWithTheRecipe() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let tag = makeTestTag(context: context, name: "Depa")
            let (e, _) = try expense(context, f, total: 200, myShare: 100, paidByMe: true)
            try bridge(context, e, f, account: f.bcp)
            let real = try #require(try legs(context, e).first { $0.account?.isSystemAccount == false })
            real.splitLinesRaw = GroupSplitLinesRecipe.encode(superLines(f))
            real.setTags(from: [tag])
            real.needOverride = SubcategoryNeed.optional.rawValue
            try context.save()
            try bridge(context, e, f)

            e.paidByMemberID = f.pia.id.uuidString
            try context.save()
            try bridge(context, e, f)

            let holder = try #require(try recipeHolders(context, e).first)
            #expect(holder.resolvedTagIDs() == [tag.id], "La pata nueva no heredó tus etiquetas.")
            #expect(holder.needOverride == SubcategoryNeed.optional.rawValue)
            var derivedTags: [Set<UUID>?] = []
            for leg in try legs(context, e) where GroupSplitLinesBridgeLogic.isDerivedMarker(leg.splitLinesRaw) {
                derivedTags.append(leg.resolvedTagIDs())
            }
            #expect(derivedTags == [[tag.id]], "Las líneas derivadas perdieron tus etiquetas.")
        }
    }

    /// En la misma edición pasas a pagar tú y el gasto cambia de divisa: la receta pasa a la pata real (que nace en la
    /// divisa nueva) y, como ya no cuadra, la Bandeja avisa en el acto (review: la puerta miraba la pata que se iba).
    @Test func caseBToCaseA_withACurrencyChange_theInboxAsksAtOnce() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let dollars = Account(name: "Cuenta USD", currencyCode: "USD", colorHex: "#333333", iconName: "dollarsign",
                                  type: "bank")
            context.insert(dollars)
            let (e, share) = try expense(context, f, total: 200, myShare: 100, paidByMe: false)
            try bridge(context, e, f)
            let holder = try #require(try legs(context, e).first)
            holder.splitLinesRaw = GroupSplitLinesRecipe.encode(superLines(f))
            try context.save()
            try bridge(context, e, f)

            e.paidByMemberID = f.me.id.uuidString
            e.currencyCode = "USD"
            e.amount = 54
            share.amount = 27
            try context.save()
            try bridge(context, e, f, account: dollars)

            let real = try #require(try movements(of: dollars, context).first, "Falta la pata real en dólares.")
            #expect(GroupSplitLinesEntryLogic.holdsRecipe(real.splitLinesRaw), "La receta no pasó a la pata real.")
            #expect(try drafts(context, e).contains { $0.isSplitLinesMismatchNotice },
                    "La Bandeja no avisó de que las líneas ya no cuadran.")
        }
    }

    // MARK: - Cambio de divisa

    /// Pagó Pía; cambia la divisa y el importe del gasto. La receta se queda en la pata nueva y la Bandeja avisa en la
    /// misma pasada de que ya no cuadra.
    @Test func caseB_currencyChange_keepsTheRecipe_andTheInboxAsksAtOnce() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, share) = try expense(context, f, total: 200, myShare: 100, paidByMe: false)
            try bridge(context, e, f)
            let holder = try #require(try legs(context, e).first)
            holder.splitLinesRaw = GroupSplitLinesRecipe.encode(superLines(f))
            try context.save()
            try bridge(context, e, f)
            let recipe = holder.splitLinesRaw

            e.currencyCode = "USD"
            e.amount = 54
            share.amount = 27
            try context.save()
            try bridge(context, e, f)

            let holders = try recipeHolders(context, e)
            #expect(holders.map(\.splitLinesRaw) == [recipe], "La receta no sobrevivió al cambio de divisa.")
            #expect(holders.first?.currencyCode == "USD")
            #expect(try drafts(context, e).contains { $0.isSplitLinesMismatchNotice },
                    "La Bandeja no avisó de que las líneas ya no cuadran.")
        }
    }
}
