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

    /// La de las liquidaciones viaja con la convergencia: retirar una intención convergida sin ella la dejaría dormida,
    /// y la próxima convergencia —la de un restaurar, que no la pidió— re-puentearía liquidaciones por nada.
    @Test("la petición de liquidaciones se marca aparte y se retira con la convergencia")
    func settlementLegsRoundTrip() {
        let defaults = makeIsolatedDefaults()
        #expect(!GroupsBridgeRestoreConvergenceStore.isSettlementLegsPending(defaults))
        GroupsBridgeRestoreConvergenceStore.markSettlementLegsPending(defaults)
        #expect(GroupsBridgeRestoreConvergenceStore.isSettlementLegsPending(defaults))
        #expect(!GroupsBridgeRestoreConvergenceStore.isPending(defaults), "no enciende la convergencia por su cuenta")
        GroupsBridgeRestoreConvergenceStore.markPending(defaults)
        GroupsBridgeRestoreConvergenceStore.clear(defaults)
        #expect(!GroupsBridgeRestoreConvergenceStore.isSettlementLegsPending(defaults))
    }

    /// Qué se re-puentea tras un borrado de filas: las confirmadas que se quedaron sin ninguna pata. Una pata, la que
    /// sea, dice que alguien la re-puenteó después, y su borrador pudo aprobarse ya (sin rastro en `splitSettlementID`).
    @Test("se re-puentean las confirmadas sin ninguna pata; con cualquier pata se dejan quietas")
    func settlementsToReBridge_onlyTheBareOnes() {
        let bare = UUID(), withVirtual = UUID(), withReal = UUID()
        let legs: Set<String> = [withVirtual.uuidString, withReal.uuidString, UUID().uuidString]
        #expect(Logic.settlementsToReBridge(confirmed: [bare, withVirtual, withReal], legSettlementIDs: legs) == [bare])
        #expect(Logic.settlementsToReBridge(confirmed: [], legSettlementIDs: legs).isEmpty, "solo las confirmadas")
    }

    /// El receptor de la señal de vaciado pide la convergencia solo si su borrado se lleva una fila puenteada POSTERIOR a
    /// la señal. El corte, clavado con sus dos vecinos: un segundo después cuenta, el mismo instante no.
    @Test("el receptor pide solo si hay una fila puenteada posterior a la señal (corte estricto, sin hora no pide)")
    func remoteWipeTakesRowsTheOriginReconverged_strictCut() {
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(Logic.remoteWipeTakesRowsTheOriginReconverged(
            bridgedRowsCreatedAt: [t0.addingTimeInterval(-3600), t0.addingTimeInterval(1)], signaledAt: t0))
        #expect(!Logic.remoteWipeTakesRowsTheOriginReconverged(bridgedRowsCreatedAt: [t0], signaledAt: t0),
                "una fila del mismo instante no es posterior a la señal")
        #expect(!Logic.remoteWipeTakesRowsTheOriginReconverged(
            bridgedRowsCreatedAt: [t0.addingTimeInterval(-1)], signaledAt: t0))
        #expect(!Logic.remoteWipeTakesRowsTheOriginReconverged(bridgedRowsCreatedAt: [], signaledAt: t0),
                "sin filas puenteadas no hay nada que el origen haya repuesto")
        #expect(!Logic.remoteWipeTakesRowsTheOriginReconverged(
            bridgedRowsCreatedAt: [t0], signaledAt: Date(timeIntervalSince1970: 0)),
                "sin hora de señal toda fila parece posterior: pedir ahí es pedir siempre, y duplica")
    }
}

@Suite("Paso 8 · convergencia tras restaurar, contra el bridge real", .serialized, .wipeAppGroupMirrorIsolated)
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
    ///
    /// El dominio de `UserDefaults.standard` también se restaura: los casos del borrado de filas ejecutan el
    /// `wipeAllUserData` real, que reabre las puertas del seed y barre claves derivadas del host de test. El App Group
    /// lo cubre el trait `.wipeAppGroupMirrorIsolated` de la suite.
    private func withEnvironment(_ context: ModelContext, _ body: (UserDefaults) throws -> Void) rethrows {
        let standard = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier ?? "com.yala.app"
        let standardSnapshot = standard.persistentDomain(forName: domain) ?? [:]
        defer { standard.setPersistentDomain(standardSnapshot, forName: domain) }
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

    // MARK: - Tras un borrado de filas que conservó los grupos (ticket `activation-start-fresh-drops-group-settlement-legs`)

    private struct Settlements {
        /// Yo le pagué 40 a Ana (Caso C).
        let paid: SplitSettlement
        /// Ana me pagó 25 (Caso D).
        let received: SplitSettlement
        /// Sin confirmar: el bridge no la crea nunca.
        let unconfirmed: SplitSettlement
    }

    private func makeSettlements(_ context: ModelContext, _ f: Fixture) throws -> Settlements {
        let zone = f.group.cloudKitZoneID
        let paid = SplitSettlement(groupZoneID: zone, fromMemberID: f.me.id.uuidString,
                                   toMemberID: f.ana.id.uuidString, amount: 40, currencyCode: "USD")
        paid.isConfirmed = true
        let received = SplitSettlement(groupZoneID: zone, fromMemberID: f.ana.id.uuidString,
                                       toMemberID: f.me.id.uuidString, amount: 25, currencyCode: "USD")
        received.isConfirmed = true
        let unconfirmed = SplitSettlement(groupZoneID: zone, fromMemberID: f.me.id.uuidString,
                                          toMemberID: f.ana.id.uuidString, amount: 10, currencyCode: "USD")
        for s in [paid, received, unconfirmed] { context.insert(s) }
        try context.save()
        return Settlements(paid: paid, received: received, unconfirmed: unconfirmed)
    }

    private func legs(_ context: ModelContext, _ settlement: SplitSettlement) throws -> [TransactionItem] {
        let idStr = settlement.id.uuidString
        return try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitSettlementID == idStr }))
    }

    private func drafts(_ context: ModelContext, _ settlement: SplitSettlement) throws -> [InboxDraft] {
        let idStr = settlement.id.uuidString
        return try context.fetch(FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitSettlementID == idStr }))
    }

    /// Lo que deja el borrado REAL de «Empezar desde cero» (`.importedRows`): las liquidaciones puenteadas en modo
    /// completo, y luego `wipeAllUserData` sin tocar preferencias. El control fija la premisa del ticket.
    private func bridgeThenWipe(_ context: ModelContext, _ s: Settlements) throws {
        SessionState.shared.hasPrivateSession = true
        try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.paid.id, s.received.id, s.unconfirmed.id])
        #expect(try legs(context, s.paid).count == 1 && legs(context, s.received).count == 1,
                "el fixture no puentea las liquidaciones antes del borrado")
        try DataWipeService.wipeAllUserData(in: context, reseedInitialData: false, broadcastSignal: false,
                                            resetsPreferences: false)
        #expect(try legs(context, s.paid).isEmpty && legs(context, s.received).isEmpty,
                "el borrado ya no se lleva las patas: la premisa del ticket cambió")
        #expect(try context.fetchCount(FetchDescriptor<SplitSettlement>()) == 3, "el borrado conserva los grupos")
    }

    /// El recorrido del ticket: borrado → un arranque todavía en solo-grupos (corte antes de completar la activación)
    /// → la activación completa → la convergencia. Las patas vuelven con la forma del modo completo, una por
    /// liquidación, y otra convergencia no las duplica.
    @Test("tras el borrado, las liquidaciones confirmadas vuelven a lo personal cuando la sesión es privada, y una vez")
    func afterImportedRowsWipe_confirmedSettlementLegsComeBackOnce() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let s = try makeSettlements(context, f)
            try bridgeThenWipe(context, s)

            // Lo que piden las dos puertas del borrado.
            GroupsBridgeRestoreConvergenceStore.markSettlementLegsPending(defaults)
            GroupsBridgeRestoreConvergenceStore.markPending(defaults)

            // Todavía solo-grupos: se espera, con las dos peticiones intactas.
            SessionState.shared.hasPrivateSession = false
            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)
            #expect(try legs(context, s.paid).isEmpty, "en solo-grupos se re-puentea con la forma que nadie funde después")
            #expect(GroupsBridgeRestoreConvergenceStore.isSettlementLegsPending(defaults))

            SessionState.shared.hasPrivateSession = true
            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)

            let paid = try legs(context, s.paid)
            let received = try legs(context, s.received)
            #expect(paid.count == 1, "la liquidación que pagué no volvió, o volvió dos veces")
            #expect(received.count == 1, "la que me pagaron no volvió, o volvió dos veces")
            #expect(paid.first?.account?.isSystemAccount == true && paid.first?.amount == 40)
            #expect(received.first?.account?.isSystemAccount == true && received.first?.amount == -25)
            #expect(try drafts(context, s.received).count == 1,
                    "con sesión privada vuelve también el borrador de «¿a qué cuenta llegó?»")
            let paidDrafts = try drafts(context, s.paid).count
            #expect(try legs(context, s.unconfirmed).isEmpty, "sin confirmar no se crea nunca")
            #expect(!GroupsBridgeRestoreConvergenceStore.isPending(defaults))
            #expect(!GroupsBridgeRestoreConvergenceStore.isSettlementLegsPending(defaults))
            #expect(GroupsPendingBridgeIntent.pending.isEmpty, "todo quedó atendido")

            // Ninguna sale dos veces: con sus patas ya puestas, otra petición igual no las toca.
            let legIDs = Set(try (legs(context, s.paid) + legs(context, s.received)).map(\.persistentModelID))
            GroupsBridgeRestoreConvergenceStore.markSettlementLegsPending(defaults)
            GroupsBridgeRestoreConvergenceStore.markPending(defaults)
            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)
            #expect(Set(try (legs(context, s.paid) + legs(context, s.received)).map(\.persistentModelID)) == legIDs)
            #expect(try drafts(context, s.received).count == 1)
            #expect(try drafts(context, s.paid).count == paidDrafts)
        }
    }

    /// El restaurar pide la convergencia SIN las liquidaciones, porque ahí re-puentear borra las patas reales que
    /// vuelven con el corpus. Es el control del término: sin la petición, nada.
    @Test("sin la petición de liquidaciones la convergencia no las re-puentea")
    func withoutSettlementRequest_settlementsAreNotReBridged() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let s = try makeSettlements(context, f)
            try bridgeThenWipe(context, s)

            GroupsBridgeRestoreConvergenceStore.markPending(defaults)
            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)

            #expect(try legs(context, s.paid).isEmpty)
            #expect(try legs(context, s.received).isEmpty)
            #expect(!GroupsBridgeRestoreConvergenceStore.isPending(defaults))
        }
    }

    /// Entre el borrado y la convergencia el sync puede re-puentear una liquidación, y la persona aprobar su borrador.
    /// Aprobarlo crea la transacción real SIN `splitSettlementID` (`DraftService`, D7) y borra el borrador. Re-puentear
    /// esa liquidación sacaría otro borrador del mismo pago: aprobado dos veces, cuenta doble. Es el hallazgo de la
    /// review, y el control fija su premisa: la real no lleva el ID, así que ningún guard sobre patas reales la ve.
    @Test("un borrador aprobado después del borrado no vuelve a salir")
    func draftApprovedAfterTheWipe_isNotAskedAgain() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let s = try makeSettlements(context, f)
            try bridgeThenWipe(context, s)

            // El sync re-puentea la que me pagaron (sesión privada: pata virtual + borrador) y la persona lo aprueba.
            try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.received.id])
            let draft = try #require(try drafts(context, s.received).first, "el fixture no crea el borrador")
            let bank = Account(name: "Banco", currencyCode: "USD", colorHex: "#222222",
                               iconName: "building.columns", type: "bank")
            context.insert(bank)
            let approved = TransactionItem(date: s.received.date, amount: 25, currencyCode: "USD",
                                           note: "Ana me pagó", account: bank)
            context.insert(approved)
            context.delete(draft)
            try context.save()
            #expect(approved.splitSettlementID == nil, "D7: la aprobada no lleva el ID de la liquidación")
            let before = Set(try legs(context, s.received).map(\.persistentModelID))

            GroupsBridgeRestoreConvergenceStore.markSettlementLegsPending(defaults)
            GroupsBridgeRestoreConvergenceStore.markPending(defaults)
            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)

            #expect(try drafts(context, s.received).isEmpty,
                    "la convergencia re-puenteó una liquidación ya atendida: el pago aprobado vuelve a pedirse")
            #expect(Set(try legs(context, s.received).map(\.persistentModelID)) == before)
            #expect(try legs(context, s.paid).count == 1, "la que se quedó sin nada sí vuelve")
        }
    }

    /// Una liquidación de un grupo donde todavía no se sabe quién soy vuelve sin atender: a la intención durable, con
    /// el canal del backend, igual que los gastos.
    @Test("la liquidación que el bridge no atiende pasa a la intención durable, con el canal del backend")
    func unattendedSettlement_goesToTheDurableIntent() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = try makeFixture(context)
        try withEnvironment(context) { defaults in
            SessionState.shared.hasPrivateSession = true
            let flat = SplitGroup(name: "Piso", currencyCode: "USD")
            context.insert(flat)
            let luis = SplitMember(groupZoneID: flat.cloudKitZoneID, displayName: "Luis")
            let eva = SplitMember(groupZoneID: flat.cloudKitZoneID, displayName: "Eva")
            context.insert(luis)
            context.insert(eva)
            let settlement = SplitSettlement(groupZoneID: flat.cloudKitZoneID, fromMemberID: luis.id.uuidString,
                                             toMemberID: eva.id.uuidString, amount: 20, currencyCode: "USD")
            settlement.isConfirmed = true
            context.insert(settlement)
            try context.save()

            GroupsBridgeRestoreConvergenceStore.markSettlementLegsPending(defaults)
            GroupsBridgeRestoreConvergenceStore.markPending(defaults)
            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)

            let pending = GroupsPendingBridgeIntent.pending
            #expect(pending.settlementIDs.contains(settlement.id))
            #expect(pending.backendSettlementIDs.contains(settlement.id),
                    "con el canal CloudKit el retome la soltaría como abandonada sin intentarlo")
            #expect(!GroupsBridgeRestoreConvergenceStore.isSettlementLegsPending(defaults), "lo que falta ya tiene dueño")
        }
    }

    // MARK: - «Vaciar datos» de Ajustes (ticket `wipe-data-keeps-groups-but-drops-their-bridged-rows`)

    private func expenseDrafts(_ context: ModelContext, _ expense: SplitExpense) throws -> [InboxDraft] {
        let idStr = expense.id.uuidString
        return try context.fetch(FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitExpenseID == idStr }))
    }

    /// Lo que la persona tiene en lo personal antes de vaciar: el gasto y las dos liquidaciones puenteados en modo
    /// completo. Luego el borrado REAL de «Vaciar datos», el que resetea también las preferencias. Los controles fijan la
    /// premisa del ticket: el borrado se lleva las filas puenteadas y conserva los grupos.
    private func bridgeThenEmptyMyData(
        _ context: ModelContext, _ expense: SplitExpense, _ s: Settlements, defaults: UserDefaults
    ) throws {
        SessionState.shared.hasPrivateSession = true
        try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id])
        try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.paid.id, s.received.id])
        #expect(try !txs(context, expenseID: expense.id).isEmpty && legs(context, s.paid).count == 1,
                "el fixture no puentea antes de vaciar")
        try DataWipeService.wipePersonalDataKeepingGroups(in: context, broadcastSignal: false, defaults: defaults)
        #expect(try txs(context, expenseID: expense.id).isEmpty && legs(context, s.paid).isEmpty,
                "«Vaciar datos» ya no se lleva las filas puenteadas: la premisa del ticket cambió")
        #expect(try context.fetchCount(FetchDescriptor<SplitExpense>()) == 1
                && context.fetchCount(FetchDescriptor<SplitSettlement>()) == 3, "«Vaciar datos» conserva los grupos")
        #expect(PrivateSessionMark.confirmedPrivateSession(),
                "vaciar no cambia quién eres: la marca persistida de sesión privada, la que lee el arranque, sigue")
    }

    /// El recorrido del ticket: «Vaciar datos» con grupos → el arranque siguiente converge. El gasto y las dos
    /// liquidaciones confirmadas vuelven a lo personal, con su borrador de «¿de qué cuenta?» donde toca, y otra
    /// convergencia no duplica nada.
    @Test("tras «Vaciar datos» los gastos y las liquidaciones de grupo vuelven a lo personal, una vez")
    func emptyMyData_groupRowsComeBackOnce() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            try bridgeThenEmptyMyData(context, expense, s, defaults: defaults)

            #expect(GroupsBridgeRestoreConvergenceStore.isPending(defaults), "«Vaciar datos» no pidió la convergencia")
            #expect(GroupsBridgeRestoreConvergenceStore.isSettlementLegsPending(defaults),
                    "«Vaciar datos» no pidió las liquidaciones: la cuenta de grupos contaría lo ya cobrado o pagado")

            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)

            let expenseRows = try txs(context, expenseID: expense.id)
            #expect(!expenseRows.isEmpty, "el gasto de grupo no volvió a lo personal")
            #expect(expenseRows.allSatisfy { $0.account?.isSystemAccount == true },
                    "sin cuentas personales solo vuelve la parte de la cuenta de grupos")
            #expect(try expenseDrafts(context, expense).count == 1, "el Inbox no pregunta de qué cuenta salió el gasto")
            #expect(try legs(context, s.paid).count == 1, "la liquidación que pagué no volvió, o volvió dos veces")
            #expect(try legs(context, s.received).count == 1, "la que me pagaron no volvió, o volvió dos veces")
            #expect(try drafts(context, s.received).count == 1, "el Inbox no pregunta a qué cuenta llegó el pago")
            #expect(try legs(context, s.unconfirmed).isEmpty, "sin confirmar no se crea nunca")
            #expect(!GroupsBridgeRestoreConvergenceStore.isPending(defaults))
            #expect(GroupsPendingBridgeIntent.pending.isEmpty, "todo quedó atendido")

            // Ninguna fila sale dos veces: otra petición igual no crea nada nuevo. Las patas del gasto se comparan por
            // importe y no por identidad: el bridge re-crea la virtual en cada re-puenteo (delete+recreate). Las de las
            // liquidaciones, que ya tienen pata, no se tocan y se comparan por identidad.
            let expenseAmounts = try txs(context, expenseID: expense.id).map(\.amount).sorted()
            let legIDs = Set(try (legs(context, s.paid) + legs(context, s.received)).map(\.persistentModelID))
            let draftCount = try context.fetchCount(FetchDescriptor<InboxDraft>())
            GroupsBridgeRestoreConvergenceStore.markSettlementLegsPending(defaults)
            GroupsBridgeRestoreConvergenceStore.markPending(defaults)
            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)
            #expect(try txs(context, expenseID: expense.id).map(\.amount).sorted() == expenseAmounts,
                    "una segunda convergencia duplicó el gasto")
            #expect(Set(try (legs(context, s.paid) + legs(context, s.received)).map(\.persistentModelID)) == legIDs,
                    "una segunda convergencia duplicó una liquidación")
            #expect(try context.fetchCount(FetchDescriptor<InboxDraft>()) == draftCount, "una segunda convergencia duplicó borradores")
        }
    }

    /// Un gasto y una liquidación que la persona conservó como movimiento personal al desasociar, y luego re-asoció la
    /// misma cuenta. El libro de conservados dice «ya está en el Panel» y frena el bridge, que es lo correcto mientras el
    /// movimiento exista. «Vaciar datos» se lo lleva: si el libro sigue, la convergencia los da por atendidos sin crear
    /// nada y se quedan sin rastro en lo personal.
    @Test("tras «Vaciar datos» vuelve también lo que el libro de conservados daba por puesto")
    func emptyMyData_conservedOnDetach_comesBackToo() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            // La misma cuenta, re-asociada; el espejo local se lee antes que el iCloud-KV. `.standard` lo restaura
            // `withEnvironment`.
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            UserDefaults.standard.set(
                try encoder.encode(GroupsAssociationRecord(sub: "sub-mia", provider: "apple", email: nil, kind: nil,
                                                           associatedAt: .now)),
                forKey: GroupsAccountAssociation.localKey)
            try #require(GroupsAccountAssociation.shared.associatedSub == "sub-mia", "el fixture no asocia la cuenta")
            GroupsDetachedBridgeLedger.record(sub: "sub-mia", expenseIDs: [expense.id.uuidString],
                                              settlementIDs: [s.paid.id.uuidString])

            // Control: con el libro puesto, el bridge da el gasto por atendido sin crear nada.
            SessionState.shared.hasPrivateSession = true
            #expect(try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id]) == [expense.id])
            #expect(try txs(context, expenseID: expense.id).isEmpty, "el libro ya no frena el bridge: el fixture no vale")

            try DataWipeService.wipePersonalDataKeepingGroups(in: context, broadcastSignal: false, defaults: defaults)
            #expect(GroupsAccountAssociation.shared.associatedSub == "sub-mia",
                    "vaciar soltó la asociación: el libro ya no casaría y el caso no mide nada")
            #expect(GroupsDetachedBridgeLedger.read() == nil,
                    "el libro sobrevive a un borrado que se llevó los movimientos que afirma")

            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)

            #expect(!(try txs(context, expenseID: expense.id)).isEmpty,
                    "el gasto conservado no volvió: el libro lo dio por puesto en el Panel")
            #expect(try legs(context, s.paid).count == 1, "la liquidación conservada no volvió")
        }
    }

    /// Un grupo borrado (oculto) conserva su dominio. Vaciar se lleva sus patas —la del gasto y la de la liquidación, que
    /// se compensaban—, y el gasto de un grupo oculto no vuelve nunca (`bridgeExpense` lo salta). Si volviera solo la
    /// liquidación, la cuenta de grupos enseñaría una deuda que no existe y el Inbox pediría un pago viejo. Es el
    /// hallazgo de la review; el control fija que el bridge, pedido a mano, sí la crearía.
    @Test("tras «Vaciar datos» la liquidación de un grupo borrado no vuelve sola")
    func emptyMyData_hiddenGroupSettlement_staysOut() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let s = try makeSettlements(context, f)
            f.group.isHiddenForAll = true
            try context.save()
            SessionState.shared.hasPrivateSession = true

            try DataWipeService.wipePersonalDataKeepingGroups(in: context, broadcastSignal: false, defaults: defaults)
            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)

            #expect(try legs(context, s.paid).isEmpty && legs(context, s.received).isEmpty,
                    "la liquidación de un grupo borrado volvió sin el gasto que la compensaba: deuda fantasma")
            #expect(try drafts(context, s.received).isEmpty, "el Inbox pide un pago de un grupo borrado")
            #expect(!GroupsBridgeRestoreConvergenceStore.isSettlementLegsPending(defaults))

            // Control: el bridge no mira el grupo oculto, así que lo que la deja fuera es el filtro de la convergencia.
            try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.paid.id])
            #expect(try legs(context, s.paid).count == 1, "el bridge ya salta los grupos ocultos: revisa el porqué del filtro")
        }
    }

    /// El libro lo retira el borrado de filas EN CUALQUIER ALCANCE, no solo «Vaciar datos»: los dos borrados de iCloud
    /// que conservan grupos (`resetsPreferences: false`) también se llevan los movimientos que afirma.
    @Test("el borrado que conserva las preferencias también retira el libro de conservados")
    func importedRowsWipe_alsoClearsTheLedger() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        _ = try makeFixture(context)
        try withEnvironment(context) { _ in
            GroupsDetachedBridgeLedger.record(sub: "sub-mia", expenseIDs: ["g1"], settlementIDs: [])
            try #require(GroupsDetachedBridgeLedger.read() != nil, "el fixture no escribe el libro")
            try DataWipeService.wipeAllUserData(in: context, reseedInitialData: false, broadcastSignal: false,
                                                resetsPreferences: false)
            #expect(GroupsDetachedBridgeLedger.read() == nil,
                    "el libro sobrevive al borrado de filas de la activación o del aviso tardío")
        }
    }

    // MARK: - El dispositivo que RECIBE la señal (ticket `late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged`)

    /// Puentea el gasto y las dos liquidaciones en modo completo, como las deja la convergencia del origen o el sync de
    /// grupos. El control fija que este dispositivo no había pedido nada: la petición que haya después la pone su borrado.
    private func bridgeGroupRows(
        _ context: ModelContext, _ expense: SplitExpense, _ s: Settlements, defaults: UserDefaults
    ) throws {
        SessionState.shared.hasPrivateSession = true
        try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id])
        try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.paid.id, s.received.id])
        #expect(try !txs(context, expenseID: expense.id).isEmpty && legs(context, s.paid).count == 1
                && legs(context, s.received).count == 1, "el fixture no puentea las filas de grupo")
        #expect(!GroupsBridgeRestoreConvergenceStore.isPending(defaults)
                && !GroupsBridgeRestoreConvergenceStore.isSettlementLegsPending(defaults),
                "el fixture ya trae una petición: el caso no mediría la del borrado del receptor")
    }

    /// El orden del ticket: el origen vació sus datos y ya convergió, y este dispositivo —cerrado o sin red hasta ahora—
    /// procesa la señal tarde. Lo que tiene puenteado es POSTERIOR a la señal (la reposición del origen, que llegó por el
    /// espejo). Su borrado se lo lleva y ese borrado viaja al origen: si este dispositivo no lo pide, no lo pide nadie.
    /// Con la petición, vuelve en su arranque siguiente, una vez.
    @Test("la señal de «Vaciar datos» procesada tarde no deja sin gastos de grupo: el receptor los pide")
    func lateRemoteWipe_afterTheOriginReconverged_rowsComeBackOnce() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            let signaledAt = Date.now.addingTimeInterval(-60)
            try bridgeGroupRows(context, expense, s, defaults: defaults)

            try DataWipeService.wipeLocallyForRemoteWipeSignal(in: context, signaledAt: signaledAt, defaults: defaults)
            #expect(try txs(context, expenseID: expense.id).isEmpty && legs(context, s.paid).isEmpty
                    && legs(context, s.received).isEmpty,
                    "el borrado del receptor ya no se lleva las filas puenteadas: la premisa del ticket cambió")
            #expect(try context.fetchCount(FetchDescriptor<SplitExpense>()) == 1
                    && context.fetchCount(FetchDescriptor<SplitSettlement>()) == 3, "el borrado del receptor conserva los grupos")
            #expect(GroupsBridgeRestoreConvergenceStore.isPending(defaults), """
                el receptor no pidió la convergencia: su borrado viaja por el espejo al origen, que ya convergió, y los \
                gastos de grupo desaparecen de lo personal en todo el parque
                """)
            #expect(GroupsBridgeRestoreConvergenceStore.isSettlementLegsPending(defaults),
                    "el receptor no pidió las liquidaciones: la cuenta de grupos contaría lo ya cobrado o pagado")
            #expect(PrivateSessionMark.confirmedPrivateSession(),
                    "el borrado del receptor soltó la sesión privada: la convergencia no correría en el arranque siguiente")

            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)

            #expect(!(try txs(context, expenseID: expense.id)).isEmpty, "el gasto de grupo no volvió a lo personal")
            #expect(try expenseDrafts(context, expense).count == 1, "el Inbox no pregunta de qué cuenta salió el gasto")
            #expect(try legs(context, s.paid).count == 1, "la liquidación que pagué no volvió, o volvió dos veces")
            #expect(try legs(context, s.received).count == 1, "la que me pagaron no volvió, o volvió dos veces")
            #expect(try drafts(context, s.received).count == 1, "el Inbox no pregunta a qué cuenta llegó el pago")
            #expect(try legs(context, s.unconfirmed).isEmpty, "sin confirmar no se crea nunca")
            #expect(!GroupsBridgeRestoreConvergenceStore.isPending(defaults))
        }
    }

    /// Una liquidación sola también es prueba: si lo único posterior a la señal es la pata de una liquidación (el origen
    /// repuso solo eso, o solo eso llegó por el espejo), el borrado se la lleva igual y nadie más la pide.
    @Test("una liquidación repuesta sola también hace pedir al receptor")
    func lateRemoteWipe_onlyASettlementLeg_alsoAsks() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let s = try makeSettlements(context, f)
            let signaledAt = Date.now.addingTimeInterval(-60)
            SessionState.shared.hasPrivateSession = true
            try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.paid.id])
            try #require(try legs(context, s.paid).count == 1, "el fixture no puentea la liquidación")
            try #require(try context.fetchCount(FetchDescriptor<TransactionItem>(
                predicate: #Predicate { $0.splitExpenseID != nil })) == 0, "el fixture trae un gasto puenteado")

            try DataWipeService.wipeLocallyForRemoteWipeSignal(in: context, signaledAt: signaledAt, defaults: defaults)

            #expect(GroupsBridgeRestoreConvergenceStore.isSettlementLegsPending(defaults)
                    && GroupsBridgeRestoreConvergenceStore.isPending(defaults),
                    "el receptor no ve la pata de liquidación repuesta: su borrado se la lleva de todo el parque")
        }
    }

    /// El orden normal: este dispositivo procesa la señal ANTES de que el origen converja, así que lo que tiene puenteado
    /// es anterior al vaciado (las filas viejas cuyo borrado aún no llegó por el espejo). Reponerlo es cosa de la petición
    /// del origen. Si el receptor también la pidiera, los dos convergerían, y si lo hacen antes de cruzarse por el espejo
    /// cada uno crea su copia de todo el histórico de grupos: virtuales dobles y dos borradores por gasto y por
    /// liquidación, que aprobados cuentan dos veces (review adversarial, lentes de dinero y de sync).
    @Test("en el orden normal el receptor no pide la convergencia: la del origen basta, y dos duplicarían")
    func remoteWipe_beforeTheOriginConverges_doesNotAsk() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            try bridgeGroupRows(context, expense, s, defaults: defaults)
            let signaledAt = Date.now.addingTimeInterval(60)

            try DataWipeService.wipeLocallyForRemoteWipeSignal(in: context, signaledAt: signaledAt, defaults: defaults)

            #expect(try txs(context, expenseID: expense.id).isEmpty && legs(context, s.paid).isEmpty,
                    "el borrado del receptor ya no se lleva las filas viejas: el caso no mide nada")
            #expect(!GroupsBridgeRestoreConvergenceStore.isPending(defaults)
                    && !GroupsBridgeRestoreConvergenceStore.isSettlementLegsPending(defaults), """
                el receptor pidió la convergencia sin que su borrado se llevara nada que el origen hubiera repuesto: si los \
                dos convergen antes de cruzarse por el espejo, cada gasto y cada liquidación de grupo sale dos veces
                """)
        }
    }

    /// Lo que los otros casos no pueden ver, porque piden en unos `defaults` aislados: en producción la petición va a
    /// `.standard`, y el borrado del receptor RESETEA las preferencias de `.standard` justo después de pedirla. Si sus keys
    /// entraran en esa lista, el receptor dejaría de pedir sin que nada fallara a la vista. Y la otra mitad: este borrado
    /// es la RESPUESTA a una señal, así que no puede emitir otra — rebotaría el vaciado entre dispositivos.
    @Test("en `.standard` la petición del receptor sobrevive a su reset de preferencias, y no re-emite la señal")
    func remoteWipe_requestSurvivesThePreferencesReset_andDoesNotResignal() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            let signaledAt = Date.now.addingTimeInterval(-60)
            try bridgeGroupRows(context, expense, s, defaults: defaults)
            let standard = UserDefaults.standard
            let start = Date.now.timeIntervalSince1970
            // `PreferenceSyncService.signalWipeInitiated` escribe aquí (`WipeKey.localWipe`) la hora de la señal que emite.
            standard.set(42.0, forKey: "lastKnownWipeTimestamp")
            standard.set("Alguien", forKey: "userName")
            GroupsBridgeRestoreConvergenceStore.clear(standard)

            try DataWipeService.wipeLocallyForRemoteWipeSignal(in: context, signaledAt: signaledAt)

            #expect(standard.object(forKey: "userName") == nil,
                    "el borrado del receptor ya no resetea las preferencias: el caso no mide la supervivencia de la petición")
            #expect(GroupsBridgeRestoreConvergenceStore.isPending(standard), """
                el reset de preferencias del receptor se llevó su petición de convergencia: los gastos de grupo que el \
                origen repuso no vuelven
                """)
            #expect(GroupsBridgeRestoreConvergenceStore.isSettlementLegsPending(standard),
                    "el reset de preferencias del receptor se llevó la petición de las liquidaciones")
            #expect(standard.double(forKey: "lastKnownWipeTimestamp") < start,
                    "el borrado del receptor re-emitió la señal de vaciado: rebotaría entre los dispositivos del Apple ID")
        }
    }
}
