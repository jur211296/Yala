//
//  GroupsBridgeRestoreConvergenceTests.swift
//  YalaTests
//
//  Paso 8 · tras restaurar de iCloud dentro de «Activar Yala completo», cada gasto de grupo existe dos veces
//  en lo personal: el par que el bridge creó en la etapa solo-grupos y la transacción que vuelve con el corpus
//  restaurado. Dos suites: la decisión pura (`GroupsBridgeRestoreConvergenceLogic`) y la convergencia contra
//  el bridge REAL con los tres stores en disco (harness de `GroupBridgeCaseBPreserveTests`), que es donde vive
//  lo que cuesta dinero: que la transacción real restaurada sobreviva, y que el orden «modo completo antes de
//  converger» sea el que la salva — con su control en la dirección contraria.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Paso 8 · convergencia tras restaurar: la decisión pura")
struct GroupsBridgeRestoreConvergenceLogicTests {

    typealias Logic = GroupsBridgeRestoreConvergenceLogic
    typealias Leg = Logic.SettlementLeg

    private static let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("por liquidación se queda la pata de sistema más antigua; las demás de sistema sobran")
    func keepsTheOldestSystemLeg() {
        let legs = [
            Leg(settlementID: "S1", isSystemAccount: true, createdAt: Self.t0.addingTimeInterval(10)),
            Leg(settlementID: "S1", isSystemAccount: true, createdAt: Self.t0),
            Leg(settlementID: "S1", isSystemAccount: true, createdAt: Self.t0.addingTimeInterval(20)),
        ]
        #expect(Logic.settlementLegsToDelete(legs) == [0, 2])
    }

    /// La pata real es el dinero que la persona movió con su cuenta. Aunque sea la más nueva, o la única de su
    /// liquidación junto a otras reales, no se decide nada sobre ella.
    @Test("las patas de cuenta real no se borran nunca")
    func realLegsAreNeverDeleted() {
        let legs = [
            Leg(settlementID: "S1", isSystemAccount: false, createdAt: Self.t0),
            Leg(settlementID: "S1", isSystemAccount: false, createdAt: Self.t0.addingTimeInterval(5)),
            Leg(settlementID: "S1", isSystemAccount: true, createdAt: Self.t0.addingTimeInterval(1)),
        ]
        #expect(Logic.settlementLegsToDelete(legs).isEmpty)
    }

    @Test("una sola pata de sistema no es un duplicado, y cada liquidación decide por su cuenta")
    func settlementsAreIndependent() {
        let legs = [
            Leg(settlementID: "S1", isSystemAccount: true, createdAt: Self.t0),
            Leg(settlementID: "S2", isSystemAccount: true, createdAt: Self.t0.addingTimeInterval(30)),
            Leg(settlementID: "S2", isSystemAccount: true, createdAt: Self.t0.addingTimeInterval(1)),
        ]
        #expect(Logic.settlementLegsToDelete(legs) == [1])
    }

    @Test("empate de fecha: se queda la primera del array, y el resultado es determinista")
    func tieKeepsTheFirst() {
        let legs = [
            Leg(settlementID: "S1", isSystemAccount: true, createdAt: Self.t0),
            Leg(settlementID: "S1", isSystemAccount: true, createdAt: Self.t0),
        ]
        #expect(Logic.settlementLegsToDelete(legs) == [1])
    }

    @Test("lo no atendido es lo pedido menos lo atendido")
    func unattended() {
        let a = UUID(), b = UUID(), c = UUID()
        #expect(Logic.unattended(requested: [a, b, c], attended: [b]) == [a, c])
        #expect(Logic.unattended(requested: [a], attended: [a]).isEmpty)
    }

    @Test("la intención se marca, se lee y se retira")
    func storeRoundTrip() {
        let defaults = makeIsolatedDefaults()
        #expect(!GroupsBridgeRestoreConvergenceStore.isPending(defaults))
        GroupsBridgeRestoreConvergenceStore.markPending(defaults)
        #expect(GroupsBridgeRestoreConvergenceStore.isPending(defaults))
        GroupsBridgeRestoreConvergenceStore.clear(defaults)
        #expect(!GroupsBridgeRestoreConvergenceStore.isPending(defaults))
    }
}

@Suite("Paso 8 · convergencia tras restaurar, contra el bridge real", .serialized)
@MainActor
struct GroupsBridgeRestoreConvergenceBehaviourTests {

    // MARK: - Infra (harness de GroupBridgeCaseBPreserveTests: tres stores en disco, `cloudKitDatabase: .none`)

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupsConvergence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            // Un temporal que no se pudo borrar no invalida el caso.
            #if DEBUG
            print("GroupsBridgeRestoreConvergenceTests: cleanup: \(error)")
            #endif
        }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration(
            "GBRC-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "GBRC-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "GBRC-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        return ModelContext(container)
    }

    private struct Fixture {
        let group: SplitGroup
        let me: SplitMember
        let ana: SplitMember
        let cash: Account
    }

    private func makeFixture(_ context: ModelContext) throws -> Fixture {
        let group = SplitGroup(name: "Viaje", currencyCode: "USD")
        context.insert(group)
        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", isCurrentUser: true)
        context.insert(me)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(ana)
        let cash = Account(name: "Efectivo", currencyCode: "USD", colorHex: "#111111",
                           iconName: "banknote", type: "cash")
        context.insert(cash)
        try context.save()
        return Fixture(group: group, me: me, ana: ana, cash: cash)
    }

    /// Caso A: pagué yo 90, mi parte es 30 y la de Ana 60.
    private func makeCaseAExpense(_ context: ModelContext, _ f: Fixture) throws -> SplitExpense {
        let expense = SplitExpense(groupZoneID: f.group.cloudKitZoneID, amount: 90, currencyCode: "USD",
                                   expenseDescription: "Cena", paidByMemberID: f.me.id.uuidString)
        context.insert(expense)
        context.insert(SplitShare(expenseID: expense.id, memberID: f.me.id.uuidString, amount: 30,
                                  groupZoneID: f.group.cloudKitZoneID))
        context.insert(SplitShare(expenseID: expense.id, memberID: f.ana.id.uuidString, amount: 60,
                                  groupZoneID: f.group.cloudKitZoneID))
        try context.save()
        return expense
    }

    /// La etapa solo-grupos: el bridge crea su par virtual en la cuenta de sistema «Grupos».
    private func bridgeAsGroupsOnly(_ context: ModelContext, _ expense: SplitExpense, _ f: Fixture) throws {
        SessionState.shared.hasPrivateSession = false
        try GroupTransactionBridge.shared.bridgeExpense(expense, in: f.group, shouldSave: false)
        try context.save()
    }

    /// La transacción REAL que vuelve con el corpus restaurado: la que la persona registró con su cuenta en su
    /// vida anterior en modo completo, con su nota.
    private func insertRestoredRealTransaction(
        _ context: ModelContext, _ f: Fixture, for expense: SplitExpense
    ) throws -> PersistentIdentifier {
        let tx = TransactionItem(date: expense.date, amount: -90, currencyCode: "USD",
                                 note: "Cena de mi vida anterior", account: f.cash)
        tx.splitExpenseID = expense.id.uuidString
        tx.splitGroupZoneID = expense.groupZoneID
        tx.splitTotalAmount = 90
        context.insert(tx)
        try context.save()
        return tx.persistentModelID
    }

    private func txs(_ context: ModelContext, expenseID: UUID) throws -> [TransactionItem] {
        let idStr = expenseID.uuidString
        return try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID == idStr }))
    }

    private func spending(_ rows: [TransactionItem]) -> Double {
        rows.filter { $0.amount < 0 }.map(\.amount).reduce(0, +)
    }

    /// El entorno del bridge: su contexto, el eje de sesión privada y la intención durable en defaults aislados. Todo
    /// se restaura al salir: son singletons que comparten las demás suites.
    private func withEnvironment(_ context: ModelContext, _ body: (UserDefaults) throws -> Void) rethrows {
        GroupTransactionBridge.shared.setContext(context)
        let previousPrivateSession = SessionState.shared.hasPrivateSession
        let previousIntentDefaults = GroupsPendingBridgeIntent.defaults
        GroupsPendingBridgeIntent.defaults = makeIsolatedDefaults()
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            SessionState.shared.hasPrivateSession = previousPrivateSession
            GroupsPendingBridgeIntent.defaults = previousIntentDefaults
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        }
        try body(makeIsolatedDefaults())
    }

    // MARK: - Casos

    @Test("en modo completo la transacción real restaurada SOBREVIVE y el gasto cuenta una sola vez")
    func completedMode_keepsTheRestoredRealTransaction() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let expense = try makeCaseAExpense(context, f)
            try bridgeAsGroupsOnly(context, expense, f)
            let restoredID = try insertRestoredRealTransaction(context, f, for: expense)
            // Control del escenario: sin converger, el gasto se cuenta como gasto dos veces (-90 y -30).
            #expect(spending(try txs(context, expenseID: expense.id)) == -120, "el fixture no reproduce el duplicado")

            SessionState.shared.hasPrivateSession = true
            GroupsBridgeRestoreConvergenceStore.markPending(defaults)
            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)

            let after = try txs(context, expenseID: expense.id)
            let real = try #require(after.first { $0.persistentModelID == restoredID },
                                    "la transacción real restaurada desapareció")
            #expect(real.account?.persistentModelID == f.cash.persistentModelID)
            #expect(real.note == "Cena de mi vida anterior", "preserve+update no toca lo que clasificó la persona")
            #expect(real.amount == -90)
            #expect(after.filter { $0.account?.isSystemAccount == false }.count == 1)
            #expect(spending(after) == -90, "el gasto sigue contado dos veces")
            #expect(after.map(\.amount).reduce(0, +) == -30, "mi coste es mi parte")
            #expect(!GroupsBridgeRestoreConvergenceStore.isPending(defaults))
            #expect(GroupsPendingBridgeIntent.pending.isEmpty, "todo quedó atendido")
        }
    }

    /// El control del orden, con el mismo escenario. Sin sesión privada la convergencia no toca nada y deja la
    /// intención puesta; y el mismo re-puenteo SIN esa guarda borra la transacción real restaurada. Es la razón de
    /// que `commitPlan` ponga `.completeActivation` delante y de que la convergencia espere al modo.
    @Test("en solo-grupos la convergencia espera, porque re-puentear ahí BORRA la real restaurada")
    func groupsOnlySession_waits_becauseTheBridgeWouldDeleteTheRealTransaction() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let expense = try makeCaseAExpense(context, f)
            try bridgeAsGroupsOnly(context, expense, f)
            let restoredID = try insertRestoredRealTransaction(context, f, for: expense)

            GroupsBridgeRestoreConvergenceStore.markPending(defaults)
            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)
            #expect(try txs(context, expenseID: expense.id).contains { $0.persistentModelID == restoredID })
            #expect(GroupsBridgeRestoreConvergenceStore.isPending(defaults), "sin completar la activación, se espera")

            // El mutante del orden: el mismo re-puenteo, sin la guarda del modo.
            try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id])
            #expect(!(try txs(context, expenseID: expense.id).contains { $0.persistentModelID == restoredID }),
                    "si esto deja de borrarla, la guarda del modo ya no es lo que la salva: revisa el porqué")
        }
    }

    @Test("sin intención no se toca nada")
    func withoutIntent_nothingHappens() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let expense = try makeCaseAExpense(context, f)
            try bridgeAsGroupsOnly(context, expense, f)
            _ = try insertRestoredRealTransaction(context, f, for: expense)
            let before = Set(try txs(context, expenseID: expense.id).map(\.persistentModelID))

            SessionState.shared.hasPrivateSession = true
            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)

            #expect(Set(try txs(context, expenseID: expense.id).map(\.persistentModelID)) == before)
        }
    }

    /// Re-puentear una liquidación borraría también sus patas REALES; por eso solo se quita la pata virtual
    /// repetida, y de las de sistema se queda la más antigua (la restaurada).
    @Test("liquidaciones: sobra la pata virtual repetida; la real y la más antigua se quedan")
    func settlementDuplicates_keepRealAndOldest() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            SessionState.shared.hasPrivateSession = true
            let system = try GroupBridgeSystemEntities.ensureSystemAccount(currencyCode: "USD", context: context)
            let t0 = Date(timeIntervalSince1970: 1_700_000_000)
            func leg(_ settlementID: String, _ account: Account, _ amount: Double,
                     _ offset: TimeInterval) -> TransactionItem {
                let tx = TransactionItem(date: t0, amount: amount, currencyCode: "USD", account: account)
                tx.splitSettlementID = settlementID
                tx.createdAt = t0.addingTimeInterval(offset)
                context.insert(tx)
                return tx
            }
            let restoredVirtual = leg("S1", system, 40, 0)
            let realPayment = leg("S1", f.cash, -40, 5)
            let groupsOnlyVirtual = leg("S1", system, 40, 10)
            let loneVirtual = leg("S2", system, 15, 20)
            try context.save()
            let kept = Set([restoredVirtual, realPayment, loneVirtual].map(\.persistentModelID))

            GroupsBridgeRestoreConvergenceStore.markPending(defaults)
            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)

            let remaining = Set(try context.fetch(FetchDescriptor<TransactionItem>(
                predicate: #Predicate { $0.splitSettlementID != nil })).map(\.persistentModelID))
            #expect(remaining == kept)
            #expect(!remaining.contains(groupsOnlyVirtual.persistentModelID))
            #expect(!GroupsBridgeRestoreConvergenceStore.isPending(defaults))
        }
    }

    /// Un gasto de un grupo donde todavía no se sabe quién soy vuelve del bridge sin atender. Retirar la
    /// intención con él dentro lo dejaría dos veces para siempre: pasa a la intención durable que ya existe.
    @Test("lo que el bridge no atiende pasa a la intención durable, con el canal del backend")
    func unattended_goesToTheDurableIntent() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = try makeFixture(context)
        try withEnvironment(context) { defaults in
            SessionState.shared.hasPrivateSession = true
            let flat = SplitGroup(name: "Piso", currencyCode: "USD")
            context.insert(flat)
            let luis = SplitMember(groupZoneID: flat.cloudKitZoneID, displayName: "Luis")
            context.insert(luis)
            let expense = SplitExpense(groupZoneID: flat.cloudKitZoneID, amount: 50, currencyCode: "USD",
                                       expenseDescription: "Luz", paidByMemberID: luis.id.uuidString)
            context.insert(expense)
            try context.save()

            GroupsBridgeRestoreConvergenceStore.markPending(defaults)
            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)

            let pending = GroupsPendingBridgeIntent.pending
            #expect(pending.expenseIDs.contains(expense.id))
            #expect(pending.backendExpenseIDs.contains(expense.id),
                    "con el canal CloudKit el retome lo soltaría como abandonado sin intentarlo")
            #expect(!GroupsBridgeRestoreConvergenceStore.isPending(defaults), "lo que falta ya tiene dueño")
        }
    }
}
