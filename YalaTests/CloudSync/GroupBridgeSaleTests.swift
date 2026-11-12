//
//  GroupBridgeSaleTests.swift
//  YalaTests / CloudSync
//
//  Grupos B · card 8: una venta (gasto de grupo que pagaste tú con una categoría de ingreso) queda «por cobrar» en tu
//  cuenta «Grupos»: sin pata real, una sola pata que suma al saldo y que Estadísticas no cuenta como ingreso. De punta a
//  punta con `bridgeExpense`, sobre el harness on-disk de `GroupBridgeSplitLinesTests` (los tres stores; `shouldSave:
//  false` + save manual; el host de tests deja el puente activo).
//
//  El caso del encargo: le vendes unas zapatillas a Ana por S/ 120, todo para ella ⇒ Grupos +120 por cobrar y ningún
//  ingreso en Estadísticas. Borrar la venta o cambiar su monto mueve lo por cobrar.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos B · una venta queda por cobrar en «Grupos»", .serialized)
@MainActor
struct GroupBridgeSaleTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupBridgeSale-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("no se pudo crear \(dir): \(error)")
        }
        return dir
    }

    private func cleanup(_ dir: URL) {
        do { try FileManager.default.removeItem(at: dir) } catch { print("cleanup: \(error)") }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GBS-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GBS-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GBS-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personalCfg, groupsCfg, syncMetaCfg)
        let context = ModelContext(container)
        // Sin autoguardado: un guardado diferido que salte después de borrar el store tumba el proceso de tests entero
        // (medido en la suite completa: `NSInternalInconsistencyException` al hacer fault sobre `personal.sqlite`).
        context.autosaveEnabled = false
        return context
    }

    private struct Fixture {
        let group: SplitGroup
        let me: SplitMember
        let ana: SplitMember
        let bcp: Account
        let ventas: Subcategory
        let ropa: Subcategory
    }

    private func makeFixture(_ context: ModelContext) throws -> Fixture {
        let group = SplitGroup(name: "Ventas con Ana", currencyCode: "PEN")
        context.insert(group)
        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", isCurrentUser: true)
        context.insert(me)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(ana)
        let bcp = Account(name: "BCP", currencyCode: "PEN", colorHex: "#111111", iconName: "creditcard", type: "bank")
        context.insert(bcp)
        let incomeCat = makeTestCategory(context: context, name: "Ingresos", isIncome: true)
        let ventas = makeTestSubcategory(context: context, name: "Ventas", category: incomeCat)
        let expenseCat = makeTestCategory(context: context, name: "Compras")
        let ropa = makeTestSubcategory(context: context, name: "Ropa", category: expenseCat)
        try context.save()
        return Fixture(group: group, me: me, ana: ana, bcp: bcp, ventas: ventas, ropa: ropa)
    }

    private func withBridge(_ context: ModelContext, hasPrivateSession: Bool = true, _ body: () throws -> Void) rethrows {
        GroupTransactionBridge.shared.setContext(context)
        let previous = SessionState.shared.hasPrivateSession
        SessionState.shared.hasPrivateSession = hasPrivateSession
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            SessionState.shared.hasPrivateSession = previous
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
            // El store de este caso se borra al terminar: el puente compartido no puede quedarse apuntándolo, o el
            // siguiente test que lo use revienta al leer una fila de un archivo que ya no existe (medido en la suite).
            GroupTransactionBridge.shared._testClearContext()
        }
        try body()
    }

    /// Un gasto de `total` con tu parte `myShare` y el resto para Ana.
    private func expense(
        _ context: ModelContext, _ f: Fixture, total: Double, myShare: Double, paidByMe: Bool = true,
        category: String? = "Ventas", description: String = "Venta de zapatillas"
    ) throws -> (SplitExpense, SplitShare, SplitShare) {
        let expense = SplitExpense(
            groupZoneID: f.group.cloudKitZoneID, amount: total, currencyCode: "PEN",
            expenseDescription: description, paidByMemberID: (paidByMe ? f.me : f.ana).id.uuidString)
        expense.subcategoryName = category
        context.insert(expense)
        let mine = SplitShare(expenseID: expense.id, memberID: f.me.id.uuidString, amount: myShare,
                              groupZoneID: f.group.cloudKitZoneID)
        context.insert(mine)
        let hers = SplitShare(expenseID: expense.id, memberID: f.ana.id.uuidString, amount: total - myShare,
                              groupZoneID: f.group.cloudKitZoneID)
        context.insert(hers)
        try context.save()
        return (expense, mine, hers)
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

    private func groupsBalance(_ context: ModelContext) throws -> Double {
        try all(context).filter { $0.account?.isSystemAccount == true }.reduce(0) { $0 + $1.amount }
    }

    private func drafts(_ context: ModelContext, _ e: SplitExpense) throws -> [InboxDraft] {
        let id = e.id.uuidString
        return try context.fetch(FetchDescriptor<InboxDraft>(predicate: #Predicate { $0.splitExpenseID == id }))
    }

    /// El ingreso y el gasto del mes como los cuenta Estadísticas (`CashFlowCalculator`, con el ajuste del puente).
    private func statistics(_ context: ModelContext) throws -> CashFlowSummary {
        let txs = try all(context)
        let now = Date()
        let interval = DateInterval(start: now.addingTimeInterval(-86_400 * 40), end: now.addingTimeInterval(86_400 * 40))
        return CashFlowCalculator.calculateCashFlow(
            transactions: txs, interval: interval, grouping: .month, currencyCode: "PEN",
            adjustment: GroupBridgeStatsAdjustment.build(from: txs, context: context))
    }

    // MARK: - El caso del encargo

    @Test func aSale_leavesGroupsPlus120ToCollect_withoutARealLeg() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _, _) = try expense(context, f, total: 120, myShare: 0)
            try bridge(context, e, f)

            let expenseLegs = try legs(context, e)
            #expect(expenseLegs.count == 1)
            let leg = try #require(expenseLegs.first)
            #expect(leg.amount == 120)
            #expect(leg.account?.isSystemAccount == true)
            #expect(leg.balanceAdjustmentType == TransactionItem.adjustmentTypeReceivable)
            #expect(leg.subcategory?.name == "Ventas")
            #expect(leg.note == "Venta de zapatillas")
            #expect(try groupsBalance(context) == 120)
            #expect(try drafts(context, e).isEmpty, "Una venta no pide cuenta ni categoría en la Bandeja.")
        }
    }

    /// Discriminante: la misma pata sin su tipo SÍ contaría 120 de ingreso. Con el tipo, 0.
    @Test func statistics_doNotCountTheSaleAsIncome() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _, _) = try expense(context, f, total: 120, myShare: 0)
            try bridge(context, e, f)
            let stats = try statistics(context)
            #expect(stats.totalIncome == 0)
            #expect(stats.totalExpense == 0)

            let leg = try #require(try legs(context, e).first)
            leg.balanceAdjustmentType = nil
            #expect(try statistics(context).totalIncome == 120, "Control: sin el tipo, la venta contaba como ingreso.")
            // El control no se guarda: un cambio pendiente lo guardaría tarde el autoguardado, con el store ya borrado.
            context.rollback()
        }
    }

    @Test func aSecondPass_keepsTheSameLeg() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _, _) = try expense(context, f, total: 120, myShare: 0)
            try bridge(context, e, f)
            let first = try #require(try legs(context, e).first).persistentModelID
            try bridge(context, e, f)
            let again = try legs(context, e)
            #expect(again.map(\.persistentModelID) == [first])
            #expect(again.first?.balanceAdjustmentType == TransactionItem.adjustmentTypeReceivable)
        }
    }

    /// Aunque el formulario pasara una cuenta (no lo hace: `isSale` la retira), una venta no sale de ninguna.
    @Test func aSale_withAnAccountProvided_stillHasNoRealLeg() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _, _) = try expense(context, f, total: 120, myShare: 0)
            try bridge(context, e, f, account: f.bcp)
            #expect(try legs(context, e).map(\.amount) == [120])
            #expect(try all(context).allSatisfy { $0.account?.isSystemAccount == true })
        }
    }

    @Test func aSaleYouShare_onlyWhatTheOthersOweIsToCollect() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _, _) = try expense(context, f, total: 120, myShare: 40)
            try bridge(context, e, f)
            #expect(try legs(context, e).map(\.amount) == [80])
        }
    }

    // MARK: - Cambios y borrados

    @Test func deletingTheSale_takesWhatIsToCollectWithIt() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _, _) = try expense(context, f, total: 120, myShare: 0)
            try bridge(context, e, f)
            try GroupTransactionBridge.shared.unbridgeExpense(expenseID: e.id.uuidString)
            #expect(try all(context).isEmpty)
            #expect(try groupsBalance(context) == 0)
            #expect(try statistics(context).totalIncome == 0)
        }
    }

    @Test func aRemoteDeletion_takesWhatIsToCollectWithIt() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _, _) = try expense(context, f, total: 120, myShare: 0)
            try bridge(context, e, f)
            let removed = try GroupTransactionBridge.shared.unbridgeDeletedRemotely(expenseIDs: [e.id], settlementIDs: [])
            #expect(removed.transactions == 1)
            #expect(try all(context).isEmpty)
        }
    }

    @Test func changingTheAmount_movesWhatIsToCollect_onTheSameLeg() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _, hers) = try expense(context, f, total: 120, myShare: 0)
            try bridge(context, e, f)
            let first = try #require(try legs(context, e).first).persistentModelID
            e.amount = 150
            hers.amount = 150
            try context.save()
            try bridge(context, e, f)
            let after = try legs(context, e)
            #expect(after.map(\.amount) == [150])
            #expect(after.map(\.persistentModelID) == [first])
            #expect(try groupsBalance(context) == 150)
            #expect(try statistics(context).totalIncome == 0)
        }
    }

    /// Un gasto pagado con BCP que pasa a venta: la pata real se va (no salió dinero) y queda solo lo por cobrar.
    @Test func anExpenseTurnedIntoASale_dropsTheRealLegAndTheLoan() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _, _) = try expense(context, f, total: 120, myShare: 0, category: "Ropa")
            try bridge(context, e, f, account: f.bcp)
            #expect(try legs(context, e).map(\.amount).sorted() == [-120, 120])
            e.subcategoryName = "Ventas"
            try context.save()
            try bridge(context, e, f)
            let after = try legs(context, e)
            #expect(after.count == 1)
            #expect(after.first?.amount == 120)
            #expect(after.first?.balanceAdjustmentType == TransactionItem.adjustmentTypeReceivable)
            #expect(after.first?.account?.isSystemAccount == true)
        }
    }

    /// Y al revés: una venta que pasa a gasto con su cuenta vuelve a la forma de siempre, sin pata por cobrar.
    @Test func aSaleTurnedIntoAnExpense_isTheUsualRealLegAndLoan() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _, _) = try expense(context, f, total: 120, myShare: 0)
            try bridge(context, e, f)
            e.subcategoryName = "Ropa"
            try context.save()
            try bridge(context, e, f, account: f.bcp)
            let after = try legs(context, e)
            #expect(after.map(\.amount).sorted() == [-120, 120])
            #expect(after.allSatisfy { $0.balanceAdjustmentType == nil })
            #expect(after.first { $0.account?.isSystemAccount == false }?.subcategory?.name == "Ropa")
        }
    }

    /// Ahora lo pagó Ana: la pata por cobrar vuelve a ser tu parte, sin tipo, y la categoría de ingreso no la clasifica.
    @Test func whenThePayerChanges_theReceivableBecomesYourShare_unclassified() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, mine, hers) = try expense(context, f, total: 120, myShare: 0)
            try bridge(context, e, f)
            e.paidByMemberID = f.ana.id.uuidString
            mine.amount = 60
            hers.amount = 60
            try context.save()
            try bridge(context, e, f)
            let after = try legs(context, e)
            #expect(after.map(\.amount) == [-60])
            #expect(after.first?.balanceAdjustmentType == nil)
            #expect(after.first?.subcategory == nil)
        }
    }

    // MARK: - El otro lado

    /// Ana pagó y el gasto lleva una categoría de ingreso (para el que lo apuntó, una venta): en tu aparato tu parte es
    /// un gasto sin clasificar y la Bandeja pregunta, como con un nombre que no casa. Con «Ventas» contaría 60 de ingreso.
    @Test func paidBySomeoneElse_anIncomeCategoryDoesNotClassifyYourShare() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context) {
            let (e, _, _) = try expense(context, f, total: 120, myShare: 60, paidByMe: false)
            try bridge(context, e, f)
            let leg = try #require(try legs(context, e).first)
            #expect(leg.amount == -60)
            #expect(leg.subcategory == nil)
            #expect(leg.balanceAdjustmentType == nil)
            #expect(try drafts(context, e).contains { $0.needsUserInput.contains(DraftInputRequirement.subcategory) })
            let stats = try statistics(context)
            #expect(stats.totalIncome == 0)
            #expect(stats.totalExpense == 60)
        }
    }

    // MARK: - Puente apagado

    /// Con el puente apagado, el «Sí, registrar» deja una pata real `-total` o, si no se eligió cuenta, un borrador en la
    /// Bandeja. Si el gasto pasa a venta, los dos sobran: no salió dinero (review adversarial de la card 8).
    @Test func bridgeOff_aSaleDropsTheOptInLeg_andItsPendingDraft() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        BridgeModeResolver.shared.setAppPreferences(AppPreferences(defaults: makeIsolatedDefaults()))
        defer { BridgeModeResolver.shared._testReset() }
        context.insert(GroupBridgePreference(groupZoneID: f.group.cloudKitZoneID, bridgeOverride: false))
        try context.save()
        try withBridge(context) {
            let (e, _, _) = try expense(context, f, total: 120, myShare: 0, category: "Ropa")
            try bridge(context, e, f, account: f.bcp)
            #expect(try legs(context, e).allSatisfy { $0.account?.isSystemAccount == true },
                    "Control: con el puente apagado el gasto no crea pata real por su cuenta.")
            let optInLeg = TransactionItem(date: e.date, amount: -120, currencyCode: "PEN", note: e.expenseDescription,
                                           category: f.ropa.safeCategory, subcategory: f.ropa, account: f.bcp)
            optInLeg.splitExpenseID = e.id.uuidString
            optInLeg.splitGroupZoneID = e.groupZoneID
            context.insert(optInLeg)
            let draft = InboxDraft(
                note: e.expenseDescription, amount: -120, date: e.date, sourceType: .groupExpense,
                confidenceAmount: 1.0, confidenceDate: 1.0, confidenceMerchant: 1.0, confidenceSubcategory: 1.0,
                needsUserInput: [DraftInputRequirement.account], splitExpenseID: e.id.uuidString,
                splitGroupZoneID: e.groupZoneID, targetTransactionID: nil, optInPersonalOnly: true)
            context.insert(draft)
            try context.save()

            e.subcategoryName = "Ventas"
            try context.save()
            try bridge(context, e, f)
            let after = try legs(context, e)
            #expect(after.map(\.amount) == [120])
            #expect(after.first?.balanceAdjustmentType == TransactionItem.adjustmentTypeReceivable)
            #expect(try drafts(context, e).isEmpty)
            #expect(try statistics(context).totalExpense == 0)
        }
    }

    // MARK: - Sin cuentas personales

    @Test func groupsOnlySession_aSaleIsAlsoOneLegToCollect() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withBridge(context, hasPrivateSession: false) {
            let (e, _, _) = try expense(context, f, total: 120, myShare: 0)
            try bridge(context, e, f)
            let after = try legs(context, e)
            #expect(after.map(\.amount) == [120])
            #expect(after.first?.balanceAdjustmentType == TransactionItem.adjustmentTypeReceivable)
        }
    }
}
