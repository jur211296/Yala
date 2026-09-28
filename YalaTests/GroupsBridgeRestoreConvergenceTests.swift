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
    /// Aquí la aprobación se simula como la hace una versión ANTERIOR de la app: transacción real SIN `splitSettlementID`
    /// (`DraftService`, D7) y el borrador borrado, sin marca. Es lo que protege la guarda «solo sin ninguna pata»: la
    /// liquidación conserva su pata virtual y no se re-puentea. La aprobación de hoy, con marca, la cubren los casos del
    /// ticket `settlement-approval-leaves-no-trace-so-a-rebridge-asks-again`, más abajo.
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

    // MARK: - El receptor que NO puede reponer (ticket `late-remote-wipe-on-a-device-without-groups-cannot-return-the-rows`)

    /// Una fila del origen que el espejo llevó al receptor: su identidad en el origen (el borrado alcanza a ESE registro).
    private struct MirroredRow {
        let originID: PersistentIdentifier
    }

    private func bridgedRows(_ context: ModelContext) throws -> [TransactionItem] {
        try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID != nil || $0.splitSettlementID != nil }))
    }

    private func groupRowIDs(_ context: ModelContext) throws -> Set<PersistentIdentifier> {
        Set(try bridgedRows(context).map(\.persistentModelID))
    }

    /// Las filas repuestas por el origen se crearon hace un minuto, después de la señal (hace una hora): se atrasan todas lo
    /// mismo, conservando lo que las separa. Así una fila que el origen rehaga durante el caso no cae dentro del margen de
    /// la huella de la vieja.
    private func backdateGroupRows(_ context: ModelContext) throws {
        for tx in try bridgedRows(context) { tx.createdAt = tx.createdAt.addingTimeInterval(-60) }
        try context.save()
    }

    /// El espejo lleva al receptor las filas puenteadas del origen (con `onlyGroupsAccount`, solo las de la cuenta de
    /// grupos: lo que llegó antes que la real). Devuelve las filas del ORIGEN que se llevó, para que el borrado las alcance.
    @discardableResult
    private func mirror(from origin: ModelContext, into receiver: ModelContext,
                        onlyGroupsAccount: Bool = false) throws -> [MirroredRow] {
        let groups = Account(name: "Grupos", currencyCode: "USD", colorHex: "#333333", iconName: "person.3", type: "cash",
                             isSystemAccount: true)
        let cash = Account(name: "Efectivo", currencyCode: "USD", colorHex: "#111111", iconName: "banknote", type: "cash")
        receiver.insert(groups)
        receiver.insert(cash)
        var mirrored: [MirroredRow] = []
        for source in try bridgedRows(origin) where !onlyGroupsAccount || source.account?.isSystemAccount == true {
            let tx = TransactionItem(date: source.date, amount: source.amount, currencyCode: "USD", note: "",
                                     account: source.account?.isSystemAccount == true ? groups : cash)
            tx.splitExpenseID = source.splitExpenseID
            tx.splitSettlementID = source.splitSettlementID
            // El espejo puede dejar la hora al milisegundo: la huella del receptor no es la del origen al bit.
            tx.createdAt = Date(timeIntervalSince1970: (source.createdAt.timeIntervalSince1970 * 1000).rounded() / 1000)
            receiver.insert(tx)
            mirrored.append(.init(originID: source.persistentModelID))
        }
        try receiver.save()
        return mirrored
    }

    /// Llega al origen, por el espejo, el borrado de las filas que el receptor se llevó (son los mismos registros).
    private func deletionArrives(at origin: ModelContext, of taken: [MirroredRow]) throws {
        let ids = Set(taken.map(\.originID))
        for tx in try bridgedRows(origin) where ids.contains(tx.persistentModelID) { origin.delete(tx) }
        try origin.save()
    }

    private static let signaledAt = Date.now.addingTimeInterval(-3600)

    /// La huella de una fila que aquí no existe: la de un receptor que se llevó algo que en este dispositivo ya no está.
    private static let oldStamp = GroupsRemoteWipeReturnLogic.Stamp(createdAt: 1, groupsAccount: true)

    /// **El orden del ticket.** El origen (con grupos) vació sus datos y ya repuso lo de grupo. El iPad, que nunca entró en
    /// su cuenta de grupos, procesa la señal tarde: tiene esas filas por el espejo y ningún gasto local. Declara lo que se
    /// lleva. El origen atiende la declaración: mientras esas filas sigan ahí no hace nada; cuando faltan, las repone, una vez.
    @Test("receptor sin grupos: declara lo que se lleva y el origen lo repone cuando ya falta, una vez")
    func lateRemoteWipe_onADeviceWithoutGroups_theOriginReturnsTheRowsOnce() throws {
        let dir = try freshDir(), receiverDir = try freshDir()
        defer { cleanup(dir); cleanup(receiverDir) }
        let origin = try makeContext(dir)
        let receiver = try makeContext(receiverDir)
        let f = try makeFixture(origin)
        try withEnvironment(origin) { defaults in
            let kv = InMemoryKeyValueStore()
            let expense = try makeCaseAExpense(origin, f)
            let s = try makeSettlements(origin, f)
            try bridgeGroupRows(origin, expense, s, defaults: defaults)
            try backdateGroupRows(origin)
            let taken = try mirror(from: origin, into: receiver)
            try #require(try receiver.fetchCount(FetchDescriptor<SplitExpense>()) == 0, "el receptor trae grupos")

            try DataWipeService.wipeLocallyForRemoteWipeSignal(
                in: receiver, signaledAt: Self.signaledAt, defaults: makeIsolatedDefaults(), declarationStore: kv)

            #expect(try groupRowIDs(receiver).isEmpty, "el borrado del receptor ya no se lleva las filas puenteadas")
            let declaration = try #require(GroupsRemoteWipeReturnStore.read(kv).first, """
                el receptor sin grupos no declaró lo que se lleva: su convergencia no repone nada, su borrado viaja al \
                origen y los gastos de grupo desaparecen de todo el parque
                """)
            #expect(Set(declaration.expenses.keys) == [expense.id.uuidString])
            #expect(Set(declaration.settlements.keys) == [s.paid.id.uuidString, s.received.id.uuidString])
            #expect(declaration.expenses.values.joined().count + declaration.settlements.values.joined().count
                    == taken.count, "no declara la huella de cada fila que se lleva")

            // El origen arranca ANTES de que le llegue el borrado: sus filas siguen, y reponer ahí sería reponer debajo.
            let before = try groupRowIDs(origin)
            let draftsBefore = try origin.fetchCount(FetchDescriptor<InboxDraft>())
            GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true)
            #expect(try groupRowIDs(origin) == before, "el origen re-puenteó con las filas aún presentes")
            #expect(try origin.fetchCount(FetchDescriptor<InboxDraft>()) == draftsBefore)

            // Llega el borrado por el espejo, y el arranque siguiente repone.
            try deletionArrives(at: origin, of: taken)
            GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true)

            #expect(!(try txs(origin, expenseID: expense.id)).isEmpty, "el gasto de grupo no volvió a lo personal")
            #expect(try expenseDrafts(origin, expense).count == 1, "el Inbox no pregunta de qué cuenta salió el gasto")
            #expect(try legs(origin, s.paid).count == 1, "la liquidación que pagué no volvió, o volvió dos veces")
            #expect(try legs(origin, s.received).count == 1, "la que me pagaron no volvió, o volvió dos veces")
            #expect(try drafts(origin, s.received).count == 1, "el Inbox no pregunta a qué cuenta llegó el pago")
            #expect(try legs(origin, s.unconfirmed).isEmpty, "sin confirmar no se crea nunca")
            #expect(GroupsPendingBridgeIntent.pending.isEmpty, "todo quedó atendido")

            // Una vez: otro arranque no crea nada.
            let after = try groupRowIDs(origin)
            let draftsAfter = try origin.fetchCount(FetchDescriptor<InboxDraft>())
            GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true)
            #expect(try groupRowIDs(origin) == after, "un segundo arranque volvió a reponer")
            #expect(try origin.fetchCount(FetchDescriptor<InboxDraft>()) == draftsAfter)
        }
    }

    /// **La prueba es por FILA** (review adversarial). El receptor había importado solo la virtual del gasto, no la real:
    /// en el origen la real sigue ahí cuando le llega el borrado de la virtual. Mirando «¿queda alguna fila del gasto?», el
    /// gasto se quedaba sin su pata de la cuenta de grupos para siempre. Faltando la declarada, se re-puentea: el bridge
    /// conserva la real y rehace la virtual.
    @Test("el receptor solo tenía una parte de las filas del gasto: vuelve lo que se llevó y la real se conserva")
    func lateRemoteWipe_receiverHadOnlyPartOfTheRows_returnsWhatItTook() throws {
        let dir = try freshDir(), receiverDir = try freshDir()
        defer { cleanup(dir); cleanup(receiverDir) }
        let origin = try makeContext(dir)
        let receiver = try makeContext(receiverDir)
        let f = try makeFixture(origin)
        try withEnvironment(origin) { defaults in
            let kv = InMemoryKeyValueStore()
            let expense = try makeCaseAExpense(origin, f)
            SessionState.shared.hasPrivateSession = true
            let realID = try insertRestoredRealTransaction(origin, f, for: expense)
            try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id])
            // La real y la virtual de un mismo gesto nacen a microsegundos: se ponen en el MISMO instante para que el caso
            // no dependa de lo rápido que corra, y solo las separe la cuenta.
            let bridgedNow = try txs(origin, expenseID: expense.id)
            let virtualAt = try #require(bridgedNow.first { $0.account?.isSystemAccount == true }?.createdAt,
                                         "el fixture no tiene la pata de la cuenta de grupos")
            for tx in bridgedNow where tx.persistentModelID == realID { tx.createdAt = virtualAt }
            try origin.save()
            try backdateGroupRows(origin)
            try #require(try txs(origin, expenseID: expense.id).contains { $0.account?.isSystemAccount == true },
                         "el fixture no tiene la pata de la cuenta de grupos")
            let taken = try mirror(from: origin, into: receiver, onlyGroupsAccount: true)

            try DataWipeService.wipeLocallyForRemoteWipeSignal(
                in: receiver, signaledAt: Self.signaledAt, defaults: makeIsolatedDefaults(), declarationStore: kv)
            try deletionArrives(at: origin, of: taken)
            try #require(try txs(origin, expenseID: expense.id).allSatisfy { $0.account?.isSystemAccount == false },
                         "el borrado no se llevó la pata de grupos: el caso no mide nada")

            GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true)

            let rows = try txs(origin, expenseID: expense.id)
            #expect(rows.contains { $0.account?.isSystemAccount == true },
                    "la pata de la cuenta de grupos no volvió: la real presente dejó el gasto a medias para siempre")
            #expect(rows.contains { $0.persistentModelID == realID }, "reponer se llevó la transacción real")
        }
    }

    /// El origen rehízo la virtual (otra identidad) entre la importación del receptor y su borrado: cuando llega el borrado
    /// de la vieja y de la real, en el origen queda la nueva. Por id, el gasto seguía «presente» y nunca se conciliaba. Por
    /// fila, faltando las declaradas se re-puentea (la virtual se rehace), sin duplicar el borrador.
    @Test("el origen rehízo la virtual antes del borrado: el gasto se re-puentea igual")
    func lateRemoteWipe_originRebuiltTheVirtual_stillReturns() throws {
        let dir = try freshDir(), receiverDir = try freshDir()
        defer { cleanup(dir); cleanup(receiverDir) }
        let origin = try makeContext(dir)
        let receiver = try makeContext(receiverDir)
        let f = try makeFixture(origin)
        try withEnvironment(origin) { defaults in
            let kv = InMemoryKeyValueStore()
            let expense = try makeCaseAExpense(origin, f)
            SessionState.shared.hasPrivateSession = true
            _ = try insertRestoredRealTransaction(origin, f, for: expense)
            try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id])
            try backdateGroupRows(origin)
            let taken = try mirror(from: origin, into: receiver)
            try DataWipeService.wipeLocallyForRemoteWipeSignal(
                in: receiver, signaledAt: Self.signaledAt, defaults: makeIsolatedDefaults(), declarationStore: kv)

            // El sync de grupos re-puentea el gasto en el origen antes de que llegue el borrado: la virtual es otra.
            try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id])
            try deletionArrives(at: origin, of: taken)
            let rebuilt = try #require(try txs(origin, expenseID: expense.id).first { $0.account?.isSystemAccount == true },
                                       "el fixture no deja la virtual rehecha")
            let rebuiltID = rebuilt.persistentModelID
            let draftsBefore = try expenseDrafts(origin, expense).count

            GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true)

            #expect(try txs(origin, expenseID: expense.id).allSatisfy { $0.persistentModelID != rebuiltID }, """
                el gasto no se re-puenteó: la virtual rehecha lo daba por presente y lo que se llevó el receptor no se \
                concilia nunca
                """)
            #expect(try expenseDrafts(origin, expense).count == max(draftsBefore, 1), "reponer duplicó el borrador")
        }
    }

    /// El receptor con una parte de los grupos (canal parado) converge lo que tiene y declara SOLO lo que le falta:
    /// declarar también lo suyo haría dos reponedores del mismo id.
    @Test("receptor con una parte de los grupos: converge lo suyo y declara solo lo que le falta")
    func lateRemoteWipe_partialGroups_declaresOnlyWhatItLacks() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let kv = InMemoryKeyValueStore()
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            try bridgeGroupRows(context, expense, s, defaults: defaults)
            let missing = UUID().uuidString
            let tx = TransactionItem(date: .now, amount: -60, currencyCode: "USD", note: "", account: f.cash)
            tx.splitExpenseID = missing
            context.insert(tx)
            try context.save()

            try DataWipeService.wipeLocallyForRemoteWipeSignal(
                in: context, signaledAt: Self.signaledAt, defaults: defaults, declarationStore: kv)

            let declaration = try #require(GroupsRemoteWipeReturnStore.read(kv).first, "no declaró lo que no puede reponer")
            #expect(Set(declaration.expenses.keys) == [missing], "declaró también lo que repone su convergencia")
            #expect(declaration.settlements.isEmpty)
            #expect(GroupsBridgeRestoreConvergenceStore.isPending(defaults), "no pidió su convergencia para lo que tiene")
        }
    }

    /// Una liquidación que el receptor tiene en local pero SIN confirmar (su canal se paró antes de la confirmación) no la
    /// repone su convergencia, que solo mira las confirmadas: se declara, o no la repone nadie (re-review adversarial).
    @Test("una liquidación que el receptor tiene sin confirmar se declara: su convergencia no la repone")
    func lateRemoteWipe_localButUnconfirmedSettlement_isDeclared() throws {
        let dir = try freshDir(), receiverDir = try freshDir()
        defer { cleanup(dir); cleanup(receiverDir) }
        let origin = try makeContext(dir)
        let receiver = try makeContext(receiverDir)
        let f = try makeFixture(origin)
        try withEnvironment(origin) { defaults in
            let kv = InMemoryKeyValueStore()
            let s = try makeSettlements(origin, f)
            SessionState.shared.hasPrivateSession = true
            try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.paid.id])
            try backdateGroupRows(origin)
            try mirror(from: origin, into: receiver)
            let g = try makeFixture(receiver)
            let stale = SplitSettlement(groupZoneID: g.group.cloudKitZoneID, fromMemberID: g.me.id.uuidString,
                                        toMemberID: g.ana.id.uuidString, amount: 40, currencyCode: "USD")
            stale.id = s.paid.id
            receiver.insert(stale)
            try receiver.save()
            try #require(!stale.isConfirmed, "el fixture no deja la liquidación sin confirmar en el receptor")

            try DataWipeService.wipeLocallyForRemoteWipeSignal(
                in: receiver, signaledAt: Self.signaledAt, defaults: makeIsolatedDefaults(), declarationStore: kv)

            let declaration = try #require(GroupsRemoteWipeReturnStore.read(kv).first, """
                la liquidación que el receptor tiene sin confirmar no se declaró: su convergencia no la repone y nadie más
                """)
            #expect(Set(declaration.settlements.keys) == [s.paid.id.uuidString])
        }
    }

    /// El receptor que tiene todo converge él, como desde el ticket padre, y no declara nada.
    @Test("receptor con todos los grupos: converge él y no declara nada")
    func lateRemoteWipe_withAllGroups_doesNotDeclare() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let kv = InMemoryKeyValueStore()
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            try bridgeGroupRows(context, expense, s, defaults: defaults)

            try DataWipeService.wipeLocallyForRemoteWipeSignal(
                in: context, signaledAt: Self.signaledAt, defaults: defaults, declarationStore: kv)

            #expect(GroupsRemoteWipeReturnStore.read(kv).isEmpty, "declaró lo que repone él: dos reponedores")
            #expect(GroupsBridgeRestoreConvergenceStore.isPending(defaults))
        }
    }

    /// En el orden normal (el receptor procesa la señal antes de que el origen reponga nada) no se declara: la petición del
    /// origen basta, como desde el ticket padre.
    @Test("en el orden normal el receptor sin grupos no declara")
    func remoteWipe_beforeTheOriginConverges_withoutGroups_doesNotDeclare() throws {
        let dir = try freshDir(), receiverDir = try freshDir()
        defer { cleanup(dir); cleanup(receiverDir) }
        let origin = try makeContext(dir)
        let receiver = try makeContext(receiverDir)
        let f = try makeFixture(origin)
        try withEnvironment(origin) { defaults in
            let kv = InMemoryKeyValueStore()
            let expense = try makeCaseAExpense(origin, f)
            let s = try makeSettlements(origin, f)
            try bridgeGroupRows(origin, expense, s, defaults: defaults)
            try mirror(from: origin, into: receiver)

            try DataWipeService.wipeLocallyForRemoteWipeSignal(
                in: receiver, signaledAt: Date.now.addingTimeInterval(60), defaults: makeIsolatedDefaults(),
                declarationStore: kv)

            #expect(GroupsRemoteWipeReturnStore.read(kv).isEmpty, "declaró sin llevarse nada que el origen hubiera repuesto")
        }
    }

    /// Quien declaró no atiende su propia declaración aunque después tenga los grupos: la repone otro.
    @Test("quien declara no atiende su propia declaración aunque luego tenga los grupos")
    func theDeclaringDevice_neverReturnsItsOwnDeclaration() throws {
        let dir = try freshDir(), receiverDir = try freshDir()
        defer { cleanup(dir); cleanup(receiverDir) }
        let origin = try makeContext(dir)
        let receiver = try makeContext(receiverDir)
        let f = try makeFixture(origin)
        try withEnvironment(receiver) { defaults in
            let kv = InMemoryKeyValueStore()
            let expense = try makeCaseAExpense(origin, f)
            SessionState.shared.hasPrivateSession = true
            GroupTransactionBridge.shared.setContext(origin)
            try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id])
            try backdateGroupRows(origin)
            try mirror(from: origin, into: receiver)
            GroupTransactionBridge.shared.setContext(receiver)
            try DataWipeService.wipeLocallyForRemoteWipeSignal(
                in: receiver, signaledAt: Self.signaledAt, defaults: defaults, declarationStore: kv)
            try #require(!GroupsRemoteWipeReturnStore.read(kv).isEmpty, "el fixture no declara")

            // Su canal baja después el gasto que declaró.
            let g = try makeFixture(receiver)
            let arrived = SplitExpense(groupZoneID: g.group.cloudKitZoneID, amount: 90, currencyCode: "USD",
                                       expenseDescription: "Cena", paidByMemberID: g.me.id.uuidString)
            arrived.id = expense.id
            receiver.insert(arrived)
            receiver.insert(SplitShare(expenseID: arrived.id, memberID: g.me.id.uuidString, amount: 30,
                                       groupZoneID: g.group.cloudKitZoneID))
            try receiver.save()

            GroupsRemoteWipeReturn.returnIfDeclared(context: receiver, kv: kv, defaults: defaults, obeysWipeSignal: true)
            #expect(try txs(receiver, expenseID: expense.id).isEmpty, "el que declaró repuso también: dos reponedores")
            // Control: el bridge, pedido a mano, sí lo crearía; lo que lo frena es que la declaración es suya.
            try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id])
            #expect(!(try txs(receiver, expenseID: expense.id)).isEmpty, "el bridge no crea nada: el caso no mide nada")
        }
    }

    /// **Otra declaración del mismo gasto se atiende otra vez** (review adversarial). Un segundo receptor tardío se lleva
    /// lo que el origen ya repuso: su declaración es otra, con otras huellas, y el origen la repone cuando faltan esas
    /// filas. Con un «ya repuesto» global, el gasto se quedaba fuera; uniendo las dos bajo un id nuevo, el primer receptor
    /// perdía su «es mía».
    @Test("un segundo receptor que se lleva lo repuesto: el origen repone otra vez, y el primero sigue sin atender la suya")
    func aSecondDeclaration_ofTheSameExpense_isReturnedAgain() throws {
        let dir = try freshDir(), firstDir = try freshDir(), secondDir = try freshDir()
        defer { cleanup(dir); cleanup(firstDir); cleanup(secondDir) }
        let origin = try makeContext(dir)
        let first = try makeContext(firstDir)
        let second = try makeContext(secondDir)
        let f = try makeFixture(origin)
        try withEnvironment(origin) { defaults in
            let kv = InMemoryKeyValueStore()
            let firstDefaults = makeIsolatedDefaults()
            let expense = try makeCaseAExpense(origin, f)
            SessionState.shared.hasPrivateSession = true
            try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id])
            try backdateGroupRows(origin)
            let takenByFirst = try mirror(from: origin, into: first)
            try DataWipeService.wipeLocallyForRemoteWipeSignal(
                in: first, signaledAt: Self.signaledAt, defaults: firstDefaults, declarationStore: kv)
            try deletionArrives(at: origin, of: takenByFirst)
            GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true)
            try #require(!(try txs(origin, expenseID: expense.id)).isEmpty, "el fixture no repone la primera vez")

            try backdateGroupRows(origin)
            let takenBySecond = try mirror(from: origin, into: second)
            try DataWipeService.wipeLocallyForRemoteWipeSignal(
                in: second, signaledAt: Self.signaledAt, defaults: makeIsolatedDefaults(), declarationStore: kv)
            #expect(GroupsRemoteWipeReturnStore.read(kv).count == 2, "la segunda declaración pisó a la primera")
            try deletionArrives(at: origin, of: takenBySecond)
            try #require(try txs(origin, expenseID: expense.id).isEmpty, "el borrado del segundo no se llevó lo repuesto")

            GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true)
            #expect(!(try txs(origin, expenseID: expense.id)).isEmpty,
                    "lo que se llevó el segundo receptor no vuelve: el primero ya lo había repuesto")
            let firstHandled = GroupsRemoteWipeReturnStore.handled(firstDefaults)
            #expect(firstHandled.values.filter(\.own).count == 1, "el primer receptor perdió la marca de su declaración")
        }
    }

    /// Lo repuesto de una declaración no se repone otra vez desde ella aunque vuelva a faltar: reponerlo otra vez es cosa
    /// del camino que lo quitó.
    @Test("lo ya repuesto de una declaración no se repone otra vez desde ella")
    func declaredRows_areReturnedOnlyOncePerDeclaration() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let origin = try makeContext(dir)
        let f = try makeFixture(origin)
        try withEnvironment(origin) { defaults in
            SessionState.shared.hasPrivateSession = true
            let kv = InMemoryKeyValueStore()
            let expense = try makeCaseAExpense(origin, f)
            try GroupsRemoteWipeReturn.declare(expenses: [expense.id.uuidString: [Self.oldStamp]], settlements: [:], kv: kv,
                                               defaults: makeIsolatedDefaults())
            GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true)
            try #require(!(try txs(origin, expenseID: expense.id)).isEmpty, "el fixture no repone")

            for tx in try txs(origin, expenseID: expense.id) { origin.delete(tx) }
            try origin.save()
            GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true)
            #expect(try txs(origin, expenseID: expense.id).isEmpty, "se repuso dos veces desde la misma declaración")
        }
    }

    /// Lo declarado que aquí todavía no ha bajado (el canal de grupos va por detrás) no se da por repuesto: se repone el
    /// arranque en que llega. Apuntarlo antes lo perdería.
    @Test("lo declarado que aún no ha bajado aquí se repone cuando baja")
    func declaredButNotYetLocal_isReturnedWhenItArrives() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let origin = try makeContext(dir)
        let f = try makeFixture(origin)
        try withEnvironment(origin) { defaults in
            SessionState.shared.hasPrivateSession = true
            let kv = InMemoryKeyValueStore()
            let expenseID = UUID()
            try GroupsRemoteWipeReturn.declare(expenses: [expenseID.uuidString: [Self.oldStamp]], settlements: [:], kv: kv,
                                               defaults: makeIsolatedDefaults())
            GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true)

            let expense = SplitExpense(groupZoneID: f.group.cloudKitZoneID, amount: 90, currencyCode: "USD",
                                       expenseDescription: "Cena", paidByMemberID: f.me.id.uuidString)
            expense.id = expenseID
            origin.insert(expense)
            origin.insert(SplitShare(expenseID: expense.id, memberID: f.me.id.uuidString, amount: 30,
                                     groupZoneID: f.group.cloudKitZoneID))
            try origin.save()

            GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true)
            #expect(!(try txs(origin, expenseID: expenseID)).isEmpty,
                    "lo declarado que aún no había bajado se dio por repuesto y no vuelve")
        }
    }

    /// Una declaración caducada no se atiende: nadie la borra del KV, y un dispositivo nuevo la encontraría meses después.
    @Test("una declaración caducada no se atiende")
    func expiredDeclaration_isIgnored() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let origin = try makeContext(dir)
        let f = try makeFixture(origin)
        try withEnvironment(origin) { defaults in
            SessionState.shared.hasPrivateSession = true
            let kv = InMemoryKeyValueStore()
            let expense = try makeCaseAExpense(origin, f)
            let now = Date.now
            try GroupsRemoteWipeReturn.declare(expenses: [expense.id.uuidString: [Self.oldStamp]], settlements: [:], kv: kv,
                                               defaults: makeIsolatedDefaults(),
                                               now: now.addingTimeInterval(-GroupsRemoteWipeReturnLogic.lifetime - 1))

            GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true,
                                                    now: now)
            #expect(try txs(origin, expenseID: expense.id).isEmpty, "se atendió una declaración caducada")

            // Control: la misma, dos segundos antes, sí se atiende. La frontera exacta la clava el test puro: aquí la fecha
            // pasa por el JSON del KV y el redondeo de ese viaje no es lo que se mide.
            GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true,
                                                    now: now.addingTimeInterval(-2))
            #expect(!(try txs(origin, expenseID: expense.id)).isEmpty, "el control no repone: el caso no mide el plazo")
        }
    }

    /// Solo atiende una sesión que obedece la señal de vaciado (privada y en iCloud: la declaración habla de ese espejo) y,
    /// como la convergencia, con sesión privada: en solo-grupos el bridge borra las transacciones reales que re-puentea.
    @Test("sin sesión privada, o en una sesión que no obedece la señal, no se atiende la declaración")
    func onlyASessionThatObeysTheWipeSignalReturns() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let origin = try makeContext(dir)
        let f = try makeFixture(origin)
        try withEnvironment(origin) { defaults in
            let kv = InMemoryKeyValueStore()
            let expense = try makeCaseAExpense(origin, f)
            try GroupsRemoteWipeReturn.declare(expenses: [expense.id.uuidString: [Self.oldStamp]], settlements: [:], kv: kv,
                                               defaults: makeIsolatedDefaults())

            SessionState.shared.hasPrivateSession = false
            GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true)
            #expect(try txs(origin, expenseID: expense.id).isEmpty, "se re-puenteó en una sesión solo-grupos")

            SessionState.shared.hasPrivateSession = true
            GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: false)
            #expect(try txs(origin, expenseID: expense.id).isEmpty, "se re-puenteó en una sesión que no obedece la señal")
            #expect(GroupsRemoteWipeReturnStore.handled(defaults).isEmpty, "se apuntó como atendida sin atenderla")

            // Control: con las dos, sí.
            GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true)
            #expect(!(try txs(origin, expenseID: expense.id)).isEmpty, "el control no repone")
        }
    }

    /// La liquidación de un grupo oculto no vuelve sola: el gasto que la compensaba no vuelve (mismo filtro que la
    /// convergencia).
    @Test("la liquidación declarada de un grupo borrado no vuelve")
    func declaredHiddenGroupSettlement_staysOut() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let origin = try makeContext(dir)
        let f = try makeFixture(origin)
        try withEnvironment(origin) { defaults in
            SessionState.shared.hasPrivateSession = true
            let kv = InMemoryKeyValueStore()
            let s = try makeSettlements(origin, f)
            f.group.isHiddenForAll = true
            try origin.save()
            try GroupsRemoteWipeReturn.declare(expenses: [:], settlements: [s.paid.id.uuidString: [Self.oldStamp]], kv: kv,
                                               defaults: makeIsolatedDefaults())

            GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true)
            #expect(try legs(origin, s.paid).isEmpty, "la liquidación de un grupo borrado volvió: deuda fantasma")
        }
    }

    /// Faltando la pata declarada, una liquidación que conserva otra no se re-puentea: `bridgeSettlement` borra todas sus
    /// transacciones, reales incluidas, antes de rehacerla. Criterio de la convergencia.
    @Test("una liquidación declarada que conserva otra pata no se re-puentea")
    func declaredSettlementWithASurvivingLeg_isLeftAlone() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let origin = try makeContext(dir)
        let f = try makeFixture(origin)
        try withEnvironment(origin) { defaults in
            SessionState.shared.hasPrivateSession = true
            let kv = InMemoryKeyValueStore()
            let s = try makeSettlements(origin, f)
            try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.paid.id])
            let before = Set(try legs(origin, s.paid).map(\.persistentModelID))
            try #require(!before.isEmpty, "el fixture no puentea la liquidación")
            try GroupsRemoteWipeReturn.declare(expenses: [:], settlements: [s.paid.id.uuidString: [Self.oldStamp]], kv: kv,
                                               defaults: makeIsolatedDefaults())

            GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true)
            #expect(Set(try legs(origin, s.paid).map(\.persistentModelID)) == before,
                    "se re-puenteó una liquidación que conservaba una pata: el bridge se lleva también las reales")
        }
    }

    /// Lo declarado que el bridge no atiende (el member propio sin resolver) pasa a la intención durable con el canal del
    /// backend, como en la convergencia; lo que no está confirmado no se pide, porque el bridge no lo crea nunca.
    @Test("lo declarado que el bridge no atiende va a la intención durable; lo no confirmado no se pide")
    func declaredButUnattended_goesToTheDurableIntent() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let origin = try makeContext(dir)
        let f = try makeFixture(origin)
        try withEnvironment(origin) { defaults in
            SessionState.shared.hasPrivateSession = true
            let kv = InMemoryKeyValueStore()
            let s = try makeSettlements(origin, f)
            let flat = SplitGroup(name: "Piso", currencyCode: "USD")
            origin.insert(flat)
            let luis = SplitMember(groupZoneID: flat.cloudKitZoneID, displayName: "Luis")
            let eva = SplitMember(groupZoneID: flat.cloudKitZoneID, displayName: "Eva")
            origin.insert(luis)
            origin.insert(eva)
            let foreign = SplitSettlement(groupZoneID: flat.cloudKitZoneID, fromMemberID: luis.id.uuidString,
                                          toMemberID: eva.id.uuidString, amount: 20, currencyCode: "USD")
            foreign.isConfirmed = true
            origin.insert(foreign)
            try origin.save()
            try GroupsRemoteWipeReturn.declare(
                expenses: [:], settlements: [foreign.id.uuidString: [Self.oldStamp], s.unconfirmed.id.uuidString: [Self.oldStamp]], kv: kv,
                defaults: makeIsolatedDefaults())

            GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true)

            let pending = GroupsPendingBridgeIntent.pending
            #expect(pending.backendSettlementIDs.contains(foreign.id),
                    "lo que el bridge no atendió se soltó: no vuelve nunca")
            #expect(!pending.settlementIDs.contains(s.unconfirmed.id),
                    "se pidió una liquidación sin confirmar: la intención la reintenta sin que pueda crearse")
        }
    }

    /// Lo que los otros casos no ven, porque apuntan en unos `defaults` aislados: en producción la marca de «es mía» va a
    /// `.standard`, y el borrado del receptor RESETEA las preferencias de `.standard` justo después. Si su key entrara en
    /// esa lista, el receptor atendería luego su propia declaración sin que nada fallara a la vista.
    @Test("en `.standard` la marca de la declaración propia sobrevive al reset de preferencias del borrado")
    func ownDeclarationMark_survivesThePreferencesReset() throws {
        let dir = try freshDir(), receiverDir = try freshDir()
        defer { cleanup(dir); cleanup(receiverDir) }
        let origin = try makeContext(dir)
        let receiver = try makeContext(receiverDir)
        let f = try makeFixture(origin)
        try withEnvironment(origin) { defaults in
            let kv = InMemoryKeyValueStore()
            let expense = try makeCaseAExpense(origin, f)
            SessionState.shared.hasPrivateSession = true
            try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id])
            try backdateGroupRows(origin)
            try mirror(from: origin, into: receiver)
            let standard = UserDefaults.standard
            standard.set("Alguien", forKey: "userName")
            GroupsRemoteWipeReturnStore.clearHandled(standard)

            try DataWipeService.wipeLocallyForRemoteWipeSignal(in: receiver, signaledAt: Self.signaledAt, declarationStore: kv)

            #expect(standard.object(forKey: "userName") == nil,
                    "el borrado ya no resetea las preferencias: el caso no mide la supervivencia de la marca")
            let declaration = try #require(GroupsRemoteWipeReturnStore.read(kv).first, "el fixture no declara")
            #expect(GroupsRemoteWipeReturnStore.handled(standard)[declaration.id.uuidString]?.own == true,
                    "el reset de preferencias se llevó la marca de «es mía»: el receptor atendería su propia declaración")
        }
    }

    // MARK: - La aprobación de una liquidación deja rastro (ticket `settlement-approval-leaves-no-trace-so-a-rebridge-asks-again`)

    /// El contexto de `DraftService`, que es singleton: se pone para el caso y se retira al salir.
    private func withDraftService(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        DraftService.shared.setContext(context)
        defer { DraftService.shared.setContext(nil) }
        try body()
    }

    private func makeBank(_ context: ModelContext) throws -> Account {
        let bank = Account(name: "Banco", currencyCode: "USD", colorHex: "#222222",
                           iconName: "building.columns", type: "bank")
        context.insert(bank)
        try context.save()
        return bank
    }

    /// La persona aprueba en el Inbox el borrador pendiente de la liquidación, con su cuenta del banco, por el camino REAL.
    @discardableResult
    private func approvePendingDraft(
        _ context: ModelContext, _ settlement: SplitSettlement, into bank: Account
    ) throws -> TransactionItem {
        let draft = try #require(try pendingDrafts(context, settlement).first,
                                 "el fixture no deja un borrador pendiente de la liquidación")
        draft.account = bank
        return try DraftService.shared.approveDraft(draft, currencyConverter: CurrencyConverter())
    }

    private func bankRows(_ context: ModelContext, _ bank: Account) throws -> [TransactionItem] {
        try context.fetch(FetchDescriptor<TransactionItem>()).filter {
            $0.account?.persistentModelID == bank.persistentModelID
        }
    }

    private func pendingDrafts(_ context: ModelContext, _ settlement: SplitSettlement) throws -> [InboxDraft] {
        try drafts(context, settlement).filter { $0.status == .pending }
    }

    /// Los borradores que el espejo llevó al receptor junto a las filas: en la vida real el receptor importa también los
    /// `InboxDraft` del origen, y su borrado se los lleva (nacen con las filas puenteadas).
    private func draftIDs(_ context: ModelContext, _ settlements: [SplitSettlement]) throws -> Set<PersistentIdentifier> {
        Set(try settlements.flatMap { try drafts(context, $0) }.map(\.persistentModelID))
    }

    /// Llega al origen el borrado de esos borradores. Los que el origen ya no tiene (el pendiente que la aprobación
    /// sustituyó) no se tocan: el borrado de un registro que ya no existe no hace nada.
    private func draftDeletionArrives(at origin: ModelContext, of ids: Set<PersistentIdentifier>) throws {
        for draft in try origin.fetch(FetchDescriptor<InboxDraft>()) where ids.contains(draft.persistentModelID) {
            origin.delete(draft)
        }
        try origin.save()
    }

    private func expectAlreadyRegistered(_ body: () throws -> Void) {
        do {
            try body()
            Issue.record("aprobar una liquidación ya registrada no dio error: se habría creado otra transacción")
        } catch DraftServiceError.groupSettlementAlreadyRegistered {
        } catch {
            Issue.record("error inesperado: \(error)")
        }
    }

    /// **Camino 2 del ticket: la aprobación cae en la ventana.** El origen repuso lo de grupo; el receptor sin grupos importó
    /// las filas y los borradores, procesa la señal tarde, declara y borra. Antes de que su borrado llegue al origen, la
    /// persona aprueba allí «Ana me pagó 25» en el banco. Llega el borrado —de la pata virtual y del borrador pendiente que
    /// el receptor se llevó— y la devolución re-puentea: vuelve la pata, y NO vuelve a preguntar.
    @Test("aprobada en la ventana del borrado tardío: la devolución rehace la pata virtual y no vuelve a pedir la cuenta")
    func approvedInTheWindow_theReturnDoesNotAskAgain() throws {
        let dir = try freshDir(), receiverDir = try freshDir()
        defer { cleanup(dir); cleanup(receiverDir) }
        let origin = try makeContext(dir)
        let receiver = try makeContext(receiverDir)
        let f = try makeFixture(origin)
        try withEnvironment(origin) { defaults in
            try withDraftService(origin) {
                let kv = InMemoryKeyValueStore()
                let expense = try makeCaseAExpense(origin, f)
                let s = try makeSettlements(origin, f)
                try bridgeGroupRows(origin, expense, s, defaults: defaults)
                try backdateGroupRows(origin)
                let taken = try mirror(from: origin, into: receiver)
                let takenDrafts = try draftIDs(origin, [s.paid, s.received])
                try #require(takenDrafts.count == 2, "el fixture no deja un borrador por liquidación")
                try DataWipeService.wipeLocallyForRemoteWipeSignal(
                    in: receiver, signaledAt: Self.signaledAt, defaults: makeIsolatedDefaults(), declarationStore: kv)
                try #require(GroupsRemoteWipeReturnStore.read(kv).first?.settlements[s.received.id.uuidString] != nil,
                             "el fixture no declara la liquidación")

                let bank = try makeBank(origin)
                try approvePendingDraft(origin, s.received, into: bank)
                #expect(try bankRows(origin, bank).map(\.amount) == [25])

                try deletionArrives(at: origin, of: taken)
                try draftDeletionArrives(at: origin, of: takenDrafts)
                try #require(try legs(origin, s.received).isEmpty, "el borrado no dejó la liquidación sin patas")
                try #require(try pendingDrafts(origin, s.paid).isEmpty, "el borrado no se llevó el borrador de la otra")
                GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true)

                #expect(try legs(origin, s.received).count == 1, "la pata virtual de la liquidación no volvió")
                #expect(try pendingDrafts(origin, s.received).isEmpty, """
                    la devolución volvió a pedir a qué cuenta llegó un pago ya registrado: aprobado otra vez, el banco \
                    lo cuenta doble
                    """)
                #expect(try drafts(origin, s.received).map(\.status) == [.approved],
                        "la marca no sobrevivió al borrado del receptor y a la devolución")
                #expect(try bankRows(origin, bank).map(\.amount) == [25], "el banco no cuenta el pago una sola vez")
                #expect(try pendingDrafts(origin, s.paid).count == 1, "la que no se aprobó sí vuelve a preguntar")

                // Otro re-puente de la misma liquidación tampoco pregunta.
                try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.received.id])
                #expect(try drafts(origin, s.received).map(\.status) == [.approved])
                #expect(try legs(origin, s.received).count == 1)
            }
        }
    }

    /// **Camino 1 del ticket: el receptor se llevó la virtual, no la real aprobada.** La persona aprobó antes; el receptor
    /// sin grupos solo había importado la pata de la cuenta de grupos. En el origen la liquidación queda sin patas y se
    /// re-puentea: vuelve la virtual y la real aprobada sigue sola en el banco.
    @Test("el receptor se llevó la virtual y no la real aprobada: vuelve la virtual y no se pregunta otra vez")
    func receiverTookTheVirtualButNotTheApprovedReal_notAskedAgain() throws {
        let dir = try freshDir(), receiverDir = try freshDir()
        defer { cleanup(dir); cleanup(receiverDir) }
        let origin = try makeContext(dir)
        let receiver = try makeContext(receiverDir)
        let f = try makeFixture(origin)
        try withEnvironment(origin) { defaults in
            try withDraftService(origin) {
                let kv = InMemoryKeyValueStore()
                let expense = try makeCaseAExpense(origin, f)
                let s = try makeSettlements(origin, f)
                try bridgeGroupRows(origin, expense, s, defaults: defaults)
                let bank = try makeBank(origin)
                try approvePendingDraft(origin, s.received, into: bank)
                try backdateGroupRows(origin)
                let taken = try mirror(from: origin, into: receiver)
                try DataWipeService.wipeLocallyForRemoteWipeSignal(
                    in: receiver, signaledAt: Self.signaledAt, defaults: makeIsolatedDefaults(), declarationStore: kv)

                try deletionArrives(at: origin, of: taken)
                GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true)

                #expect(try legs(origin, s.received).count == 1, "la pata virtual de la liquidación no volvió")
                #expect(try pendingDrafts(origin, s.received).isEmpty,
                        "la liquidación ya aprobada vuelve a pedir su cuenta: aprobada otra vez, cuenta doble")
                #expect(try bankRows(origin, bank).map(\.amount) == [25])
            }
        }
    }

    /// **La otra cara de «la marca corre la suerte de la real»:** si el receptor se llevó también la transacción real y su
    /// marca, el pago ya no está en ninguna cuenta y volver a preguntar es lo correcto.
    @Test("el receptor se llevó la real y su marca: la devolución vuelve a preguntar, y el banco no cuenta nada doble")
    func receiverTookTheRealAndItsMark_theReturnAsksAgain() throws {
        let dir = try freshDir(), receiverDir = try freshDir()
        defer { cleanup(dir); cleanup(receiverDir) }
        let origin = try makeContext(dir)
        let receiver = try makeContext(receiverDir)
        let f = try makeFixture(origin)
        try withEnvironment(origin) { defaults in
            try withDraftService(origin) {
                let kv = InMemoryKeyValueStore()
                let expense = try makeCaseAExpense(origin, f)
                let s = try makeSettlements(origin, f)
                try bridgeGroupRows(origin, expense, s, defaults: defaults)
                let bank = try makeBank(origin)
                let real = try approvePendingDraft(origin, s.received, into: bank)
                try backdateGroupRows(origin)
                let taken = try mirror(from: origin, into: receiver)
                let takenMark = try draftIDs(origin, [s.received])
                try DataWipeService.wipeLocallyForRemoteWipeSignal(
                    in: receiver, signaledAt: Self.signaledAt, defaults: makeIsolatedDefaults(), declarationStore: kv)

                try deletionArrives(at: origin, of: taken)
                origin.delete(real)
                try draftDeletionArrives(at: origin, of: takenMark)
                GroupsRemoteWipeReturn.returnIfDeclared(context: origin, kv: kv, defaults: defaults, obeysWipeSignal: true)

                #expect(try legs(origin, s.received).count == 1)
                #expect(try pendingDrafts(origin, s.received).count == 1, "el pago ya no está en ninguna cuenta y no se pregunta")
                #expect(try bankRows(origin, bank).isEmpty)
            }
        }
    }

    /// El mismo agujero por la convergencia: tras el borrado, el sync re-puentea la liquidación y la persona la aprueba.
    /// Después otro dispositivo se lleva la pata virtual y la convergencia la repone, porque se quedó sin ninguna.
    @Test("la convergencia rehace la pata virtual de una liquidación aprobada sin volver a preguntar")
    func convergence_reBridgesAnApprovedSettlementWithoutAskingAgain() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            try withDraftService(context) {
                let s = try makeSettlements(context, f)
                try bridgeThenWipe(context, s)
                try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.received.id])
                let bank = try makeBank(context)
                try approvePendingDraft(context, s.received, into: bank)
                for leg in try legs(context, s.received) { context.delete(leg) }
                try context.save()

                GroupsBridgeRestoreConvergenceStore.markSettlementLegsPending(defaults)
                GroupsBridgeRestoreConvergenceStore.markPending(defaults)
                GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)

                #expect(try legs(context, s.received).count == 1, "la pata virtual no volvió")
                #expect(try pendingDrafts(context, s.received).isEmpty, "la convergencia volvió a pedir un pago ya registrado")
                #expect(try bankRows(context, bank).map(\.amount) == [25])
            }
        }
    }

    /// La marca es un registro NUEVO que nace con la transacción real: el borrador pendiente nació con la pata virtual, y
    /// un receptor que importó la virtual lo importó con ella. Si la marca fuera ese registro, su borrado se la llevaría.
    @Test("aprobar deja una marca nueva, aprobada y enlazada a la transacción real, que no es el borrador pendiente")
    func approval_leavesANewApprovedMarkLinkedToTheRealTransaction() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { _ in
            try withDraftService(context) {
                SessionState.shared.hasPrivateSession = true
                let s = try makeSettlements(context, f)
                try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.received.id])
                let pendingID = try #require(try pendingDrafts(context, s.received).first).persistentModelID
                let bank = try makeBank(context)

                let real = try approvePendingDraft(context, s.received, into: bank)

                #expect(real.splitSettlementID == nil, "D7: la real no es pata del bridge")
                let all = try drafts(context, s.received)
                let mark = try #require(all.first, "aprobar no dejó rastro de la liquidación")
                #expect(all.count == 1)
                #expect(mark.status == .approved)
                #expect(mark.persistentModelID != pendingID, """
                    la marca es el mismo registro que el borrador pendiente: un receptor que lo importó con la pata \
                    virtual se lo llevaría al borrar
                    """)
                #expect(mark.approvedTransaction?.persistentModelID == real.persistentModelID)
                #expect(mark.cachedAccountName == "Banco", "sin la cuenta cacheada el Inbox no lo enseña en Archivados")
                #expect(mark.sourceType == .groupSettlement && mark.needsUserInput.isEmpty)
                #expect(mark.isLiveSettlementApprovalMark && mark.isShownInArchive)
            }
        }
    }

    /// La rama opt-in (Caso C con el bridge apagado: el formulario crea el borrador bajo demanda) deja la misma marca.
    @Test("la aprobación opt-in de una liquidación también deja marca, y aprobar otra vez no registra el pago dos veces")
    func optInApproval_leavesTheMarkToo() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { _ in
            try withDraftService(context) {
                SessionState.shared.hasPrivateSession = true
                let s = try makeSettlements(context, f)
                let bank = try makeBank(context)
                try DraftService.shared.createGroupSettlementOptInDraft(
                    splitSettlementID: s.paid.id.uuidString, groupZoneID: s.paid.groupZoneID)
                let real = try approvePendingDraft(context, s.paid, into: bank)

                let mark = try #require(try drafts(context, s.paid).first, "la aprobación opt-in no dejó rastro")
                #expect(try drafts(context, s.paid).count == 1)
                #expect(mark.status == .approved && mark.optInPersonalOnly)
                #expect(mark.approvedTransaction?.persistentModelID == real.persistentModelID)

                try DraftService.shared.createGroupSettlementOptInDraft(
                    splitSettlementID: s.paid.id.uuidString, groupZoneID: s.paid.groupZoneID)
                expectAlreadyRegistered { try approvePendingDraft(context, s.paid, into: bank) }
                #expect(try bankRows(context, bank).map(\.amount) == [-40], "el mismo pago quedó dos veces en el banco")
            }
        }
    }

    /// Un borrador pendiente puede convivir con la marca (lo creó otro dispositivo antes de que ella le llegara). Aprobarlo
    /// da error y no crea otra transacción, **aunque la marca aún no tenga su transacción enlazada** (CloudKit puede traer
    /// la marca antes que ella). El pendiente lo poda el arranque. Si la persona borró la transacción, se re-aprueba desde
    /// la marca: al tocarla vuelve a pendiente.
    @Test("aprobar un borrador de una liquidación ya aprobada da error y no crea otra transacción")
    func approvingASettlementAlreadyApproved_doesNotRegisterItTwice() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { _ in
            try withDraftService(context) {
                SessionState.shared.hasPrivateSession = true
                let s = try makeSettlements(context, f)
                try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.received.id])
                let bank = try makeBank(context)
                let first = try approvePendingDraft(context, s.received, into: bank)
                let subcategory = try #require(try drafts(context, s.received).first?.subcategory)

                func staleDraftArrives() throws {
                    let stale = InboxDraft(note: "", amount: 25, date: s.received.date, subcategory: subcategory,
                                           sourceType: .groupSettlement,
                                           needsUserInput: [DraftInputRequirement.account],
                                           splitGroupZoneID: s.received.groupZoneID,
                                           splitSettlementID: s.received.id.uuidString)
                    context.insert(stale)
                    try context.save()
                }

                try staleDraftArrives()
                expectAlreadyRegistered { try approvePendingDraft(context, s.received, into: bank) }
                #expect(try bankRows(context, bank).map(\.amount) == [25], "el mismo pago quedó dos veces en el banco")

                // La poda del arranque lo retira; la marca se queda.
                #expect(try GroupTransactionBridge.pruneSettlementDraftsAlreadyResolved(context: context) == 1)
                #expect(try drafts(context, s.received).map(\.status) == [.approved])

                // La transacción aún no ha llegado (o la persona la borró): la marca sin ella sigue protegiendo.
                context.delete(first)
                try context.save()
                let mark = try #require(try drafts(context, s.received).first)
                #expect(mark.approvedTransaction == nil && !mark.isLiveSettlementApprovalMark)
                try staleDraftArrives()
                expectAlreadyRegistered { try approvePendingDraft(context, s.received, into: bank) }
                #expect(try bankRows(context, bank).isEmpty)
                #expect(try GroupTransactionBridge.pruneSettlementDraftsAlreadyResolved(context: context) == 1)

                // Re-aprobar desde la marca: vuelve a pendiente, y aprobarla registra el pago otra vez, una vez.
                try DraftService.shared.returnToPending(mark)
                try approvePendingDraft(context, s.received, into: bank)
                #expect(try bankRows(context, bank).map(\.amount) == [25])
                #expect(try drafts(context, s.received).map(\.status) == [.approved])
            }
        }
    }

    /// Caso C: yo pagué. Con la liquidación ya aprobada, ni el re-puente sin cuenta pregunta otra vez ni el formulario con
    /// cuenta crea la pata real enlazada: los dos serían el mismo dinero otra vez.
    @Test("con la liquidación aprobada, el Caso C no pregunta ni crea la pata real aunque el formulario traiga cuenta")
    func caseC_withApprovalMark_doesNotAskNorCreateTheRealLegAgain() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { _ in
            try withDraftService(context) {
                SessionState.shared.hasPrivateSession = true
                let s = try makeSettlements(context, f)
                try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.paid.id])
                let bank = try makeBank(context)
                try approvePendingDraft(context, s.paid, into: bank)
                #expect(try bankRows(context, bank).map(\.amount) == [-40])

                try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.paid.id])
                #expect(try pendingDrafts(context, s.paid).isEmpty, "el re-puente del Caso C volvió a preguntar")

                try GroupTransactionBridge.shared.bridgeSettlement(s.paid, in: f.group, accountForCurrentUser: f.cash)
                #expect(try legs(context, s.paid).allSatisfy { $0.account?.isSystemAccount == true },
                        "se creó una pata real enlazada para un pago ya registrado")
                #expect(try legs(context, s.paid).count == 1)
                #expect(try pendingDrafts(context, s.paid).isEmpty)
                #expect(try bankRows(context, bank).map(\.amount) == [-40])
            }
        }
    }

    /// Caso C rechazado: el re-puente no vuelve a preguntar, pero una cuenta elegida ahora en el formulario sí crea la pata
    /// real enlazada (es un gesto explícito).
    @Test("Caso C rechazado: no vuelve a preguntar, y con cuenta elegida en el formulario sí crea la pata real")
    func caseC_rejected_doesNotAskAgainButAnExplicitAccountStillCounts() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { _ in
            try withDraftService(context) {
                SessionState.shared.hasPrivateSession = true
                let s = try makeSettlements(context, f)
                try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.paid.id])
                try DraftService.shared.rejectDraft(try #require(try pendingDrafts(context, s.paid).first))

                try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.paid.id])
                #expect(try pendingDrafts(context, s.paid).isEmpty, "el re-puente resucitó un borrador rechazado")
                #expect(try drafts(context, s.paid).map(\.status) == [.rejected])

                try GroupTransactionBridge.shared.bridgeSettlement(s.paid, in: f.group, accountForCurrentUser: f.cash)
                #expect(try legs(context, s.paid).contains {
                    $0.account?.persistentModelID == f.cash.persistentModelID && $0.amount == -40
                }, "con una cuenta elegida ahora, la pata real enlazada tiene que crearse")
            }
        }
    }

    /// Rechazar el borrador de una liquidación se puede, el re-puente lo respeta y sale en Archivados (sin cuenta, para
    /// poder deshacerlo). Borrarlo también se puede, y sin rastro vuelve a preguntar. El puntero de un gasto sigue sin
    /// poder descartarse.
    @Test("el borrador de una liquidación se rechaza o se borra; rechazado, el re-puente no vuelve a preguntar")
    func settlementDraft_canBeRejectedOrDeleted_andARejectionSticks() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { _ in
            try withDraftService(context) {
                SessionState.shared.hasPrivateSession = true
                let s = try makeSettlements(context, f)
                try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.received.id, s.paid.id])

                let received = try #require(try pendingDrafts(context, s.received).first)
                try DraftService.shared.rejectDraft(received)
                #expect(received.status == .rejected)
                #expect(received.isShownInArchive, "un rechazo sin cuenta que no sale en Archivados no se puede deshacer")
                try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.received.id])
                #expect(try pendingDrafts(context, s.received).isEmpty, "el re-puente resucitó un borrador rechazado")
                #expect(try drafts(context, s.received).map(\.status) == [.rejected], "el re-puente borró el rechazo")
                #expect(try legs(context, s.received).count == 1, "la pata virtual se rehace igual")

                let paid = try #require(try pendingDrafts(context, s.paid).first)
                try DraftService.shared.deleteDraft(paid)
                #expect(try drafts(context, s.paid).isEmpty)
                try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.paid.id])
                #expect(try pendingDrafts(context, s.paid).count == 1, "borrado sin rastro, el re-puente pregunta otra vez")

                let pointer = InboxDraft(note: "Cena", amount: -30, sourceType: .groupExpense,
                                         needsUserInput: [DraftInputRequirement.subcategory],
                                         splitExpenseID: UUID().uuidString)
                context.insert(pointer)
                try context.save()
                do {
                    try DraftService.shared.rejectDraft(pointer)
                    Issue.record("el puntero de un gasto se dejó rechazar")
                } catch DraftServiceError.cannotRejectGroupDraft {
                } catch { Issue.record("error inesperado: \(error)") }
                do {
                    try DraftService.shared.deleteDraft(pointer)
                    Issue.record("el puntero de un gasto se dejó borrar")
                } catch DraftServiceError.cannotDeleteGroupDraft {
                } catch { Issue.record("error inesperado: \(error)") }
            }
        }
    }

    /// Las acciones en lote del Inbox: rechazar en lote acepta el borrador de una liquidación; en Archivados, «Eliminar» y
    /// «Devolver a pendientes» se saltan la marca viva —sin ella el re-puente volvería a preguntar, y devuelta a pendientes
    /// se aprobaría otra vez—.
    @Test("en lote: se rechaza un borrador de liquidación; la marca viva no se borra ni vuelve a pendientes")
    func bulkActions_respectTheLiveMark() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { _ in
            try withDraftService(context) {
                SessionState.shared.hasPrivateSession = true
                let s = try makeSettlements(context, f)
                try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [s.received.id, s.paid.id])
                let bank = try makeBank(context)
                try approvePendingDraft(context, s.received, into: bank)
                let mark = try #require(try drafts(context, s.received).first)

                try DraftService.shared.bulkReject(try pendingDrafts(context, s.paid))
                #expect(try drafts(context, s.paid).map(\.status) == [.rejected])

                try DraftService.shared.bulkReturnToPending([mark])
                #expect(mark.status == .approved, "la marca volvió a pendientes: aprobarla registraría el pago otra vez")
                try DraftService.shared.returnToPending(mark)
                #expect(mark.status == .approved)

                try DraftService.shared.bulkDelete([mark])
                #expect(try drafts(context, s.received).map(\.status) == [.approved], "limpiar Archivados se llevó la marca")
                do {
                    try DraftService.shared.deleteDraft(mark)
                    Issue.record("la marca viva se dejó borrar")
                } catch DraftServiceError.cannotDeleteGroupDraft {
                } catch { Issue.record("error inesperado: \(error)") }
                #expect(try bankRows(context, bank).map(\.amount) == [25])
            }
        }
    }
}

/// Un iCloud-KV en memoria: lo que escribe un dispositivo lo lee el otro, sin iCloud.
private final class InMemoryKeyValueStore: OwnerKeyValueWriting {
    private var values: [String: Any] = [:]
    func setBool(_ value: Bool, forKey key: String) { values[key] = value }
    func setString(_ value: String, forKey key: String) { values[key] = value }
    func setDouble(_ value: Double, forKey key: String) { values[key] = value }
    func setInt(_ value: Int, forKey key: String) { values[key] = value }
    func removeObject(forKey key: String) { values[key] = nil }
    func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    func string(forKey key: String) -> String? { values[key] as? String }
    func double(forKey key: String) -> Double { values[key] as? Double ?? 0 }
    func longLong(forKey key: String) -> Int64 { values[key] as? Int64 ?? 0 }
    func object(forKey key: String) -> Any? { values[key] }
    @discardableResult func synchronize() -> Bool { true }
}

@Suite("Vaciado tardío en un dispositivo sin grupos: la decisión pura")
struct GroupsRemoteWipeReturnLogicTests {

    typealias Logic = GroupsRemoteWipeReturnLogic

    @Test("el receptor declara la huella de las filas posteriores a la señal que su convergencia no repone")
    func toDeclare_onlyWhatItsConvergenceWillNotReturn() {
        let signal = Date(timeIntervalSince1970: 1_800_000_000)
        let t1 = signal.addingTimeInterval(10), t2 = t1.addingTimeInterval(5)
        let rows: [Logic.BridgedRow] = [
            .init(expenseID: "a", settlementID: nil, createdAt: t1, groupsAccount: true),
            .init(expenseID: "a", settlementID: nil, createdAt: t2, groupsAccount: false),
            .init(expenseID: "a", settlementID: nil, createdAt: signal, groupsAccount: true),
            .init(expenseID: "old", settlementID: nil, createdAt: signal.addingTimeInterval(-1), groupsAccount: true),
            .init(expenseID: "b", settlementID: nil, createdAt: t1, groupsAccount: true),
            .init(expenseID: nil, settlementID: "s", createdAt: t1, groupsAccount: nil),
            .init(expenseID: nil, settlementID: "z", createdAt: t2, groupsAccount: true),
        ]
        let declared = Logic.toDeclare(rows: rows, signaledAt: signal,
                                       returnableExpenseIDs: ["b"], returnableSettlementIDs: ["z"])
        #expect(declared.expenses == ["a": [.init(createdAt: t1.timeIntervalSince1970, groupsAccount: true),
                                            .init(createdAt: t2.timeIntervalSince1970, groupsAccount: false)]],
                "lo anterior a la señal (o de su mismo instante) ya lo borró el origen: no se declara")
        #expect(declared.settlements == ["s": [.init(createdAt: t1.timeIntervalSince1970, groupsAccount: nil)]])
        #expect(Logic.toDeclare(rows: rows, signaledAt: signal, returnableExpenseIDs: ["a", "b"],
                                returnableSettlementIDs: ["s", "z"]).expenses.isEmpty)
    }

    @Test("una fila es la declarada dentro del margen de la huella y en la misma cuenta, con sus dos vecinos")
    func declaredRowsAreGone_boundaries() {
        let t = 1_800_000_000.0
        let declared = Logic.Stamp(createdAt: t, groupsAccount: true)
        func row(_ offset: Double, _ groups: Bool?) -> Logic.Stamp { .init(createdAt: t + offset, groupsAccount: groups) }
        let inside = Logic.stampTolerance - 0.0005, outside = Logic.stampTolerance + 0.0005
        #expect(!Logic.declaredRowsAreGone(declared: [declared], local: [row(inside, true)]), "dentro del margen sigue presente")
        #expect(Logic.declaredRowsAreGone(declared: [declared], local: [row(outside, true)]), "fuera del margen es otra fila")
        #expect(Logic.declaredRowsAreGone(declared: [declared], local: [row(0, false)]),
                "la real del mismo gesto no es la virtual declarada")
        #expect(!Logic.declaredRowsAreGone(declared: [declared], local: [row(0, nil)]),
                "una fila con la cuenta sin hidratar puede ser la declarada: se espera")
        #expect(!Logic.declaredRowsAreGone(declared: [.init(createdAt: t, groupsAccount: nil)], local: [row(0, false)]))
        #expect(Logic.declaredRowsAreGone(declared: [declared], local: []))
        #expect(!Logic.declaredRowsAreGone(declared: [row(-9, true), declared], local: [row(outside, true), row(0, true)]),
                "basta con UNA declarada presente para esperar")
        #expect(Logic.stampTolerance == 0.005)
    }

    @Test("el plazo de una declaración, con sus dos vecinos")
    func isLive_boundary() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func declared(ago: TimeInterval) -> Logic.Declaration {
            .init(id: UUID(), declaredAt: now.addingTimeInterval(-ago), expenses: [:], settlements: [:])
        }
        #expect(Logic.isLive(declared(ago: Logic.lifetime - 1), now: now))
        #expect(!Logic.isLive(declared(ago: Logic.lifetime), now: now))
        #expect(Logic.lifetime == 30 * 24 * 60 * 60)
    }

    /// La key del KV es formato compartido entre versiones de la app en el parque: renombrarla deja de ver las
    /// declaraciones de los dispositivos que no se han actualizado.
    @Test("la key del iCloud-KV no cambia")
    func kvKey_isPinned() {
        #expect(GroupsRemoteWipeReturnStore.kvKey == "groupsRowsToReturnAfterRemoteWipe")
        #expect(GroupsRemoteWipeReturnStore.handledKey.hasPrefix("fullModeActivation."),
                "fuera de ese prefijo el reset de preferencias podría llevársela")
    }
}

@Suite("La aprobación de una liquidación deja rastro: la decisión pura")
struct GroupSettlementDraftResolutionLogicTests {

    typealias Logic = GroupSettlementDraftResolutionLogic

    @Test("el aprobado gana al rechazado; sin nada resuelto, se pregunta")
    func resolution_approvedWinsOverRejected() {
        #expect(Logic.resolution(of: []) == nil)
        #expect(Logic.resolution(of: [.pending]) == nil)
        #expect(Logic.resolution(of: [.pending, .rejected]) == .rejected)
        #expect(Logic.resolution(of: [.rejected, .approved]) == .approved)
        #expect(Logic.resolution(of: [.approved, .pending]) == .approved)
    }

    @Test("el re-puente sustituye solo los pendientes que creó él")
    func isReplacedOnReBridge_onlyTheBridgesOwnPendingDrafts() {
        #expect(Logic.isReplacedOnReBridge(status: .pending, optInPersonalOnly: false))
        #expect(!Logic.isReplacedOnReBridge(status: .pending, optInPersonalOnly: true), "el opt-in lo creó el formulario")
        #expect(!Logic.isReplacedOnReBridge(status: .approved, optInPersonalOnly: false), "el aprobado es la marca")
        #expect(!Logic.isReplacedOnReBridge(status: .rejected, optInPersonalOnly: false), "el rechazo es de la persona")
        #expect(!Logic.isReplacedOnReBridge(status: .approved, optInPersonalOnly: true))
    }

    @Test("en frío sobran los pendientes del bridge de una liquidación resuelta, y nada más")
    func redundantPendingDrafts_onlyTheBridgesPendingOfAResolvedSettlement() {
        let drafts: [(settlementID: String?, status: DraftStatus, optInPersonalOnly: Bool)] = [
            ("A", .approved, false),   // 0 · la marca
            ("A", .pending, false),    // 1 · sobra
            ("A", .pending, true),     // 2 · opt-in: lo creó el formulario
            ("B", .pending, false),    // 3 · sin resolver: se queda
            ("C", .rejected, false),   // 4 · rechazo
            ("C", .pending, false),    // 5 · sobra
            (nil, .pending, false),    // 6 · sin liquidación
        ]
        #expect(Logic.redundantPendingDrafts(drafts) == [1, 5])
        #expect(Logic.redundantPendingDrafts([]).isEmpty)
    }

    @Test("solo el puntero de un gasto de grupo no se deja descartar")
    func blocksInboxDismissal_onlyGroupExpense() {
        #expect(DraftSourceType.groupExpense.blocksInboxDismissal)
        #expect(!DraftSourceType.groupSettlement.blocksInboxDismissal)
        #expect(!DraftSourceType.groupScheduledExpense.blocksInboxDismissal)
        #expect(!DraftSourceType.voice.blocksInboxDismissal)
        #expect(DraftSourceType.groupSettlement.isFromGroup, "el ruteo del aprobar en lote no cambia")
    }

    @MainActor @Test("en Archivados sale el rechazo sin cuenta de una liquidación, no el de un borrador personal")
    func isShownInArchive_rejectedSettlementWithoutAccount() {
        let settlement = InboxDraft(amount: 25, sourceType: .groupSettlement, status: .rejected)
        let personal = InboxDraft(amount: -10, sourceType: .voice, status: .rejected)
        let pending = InboxDraft(amount: 25, sourceType: .groupSettlement)
        #expect(settlement.isShownInArchive)
        #expect(!personal.isShownInArchive, "sin cuenta cacheada un archivado personal sigue sin salir")
        #expect(!pending.isShownInArchive)
        personal.cachedAccountName = "Banco"
        #expect(personal.isShownInArchive)
        #expect(!settlement.isLiveSettlementApprovalMark, "rechazada no es la marca")
    }
}
