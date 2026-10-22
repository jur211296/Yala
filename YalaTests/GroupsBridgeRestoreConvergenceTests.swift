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
        let context = ModelContext(container)
        // Sin autosave, como `makeTestContext`: un caso que acaba con cambios sin guardar (un `approveDraft` que lanza
        // deja el borrador tocado) los veía guardar por el temporizador del autosave segundos DESPUÉS, con la carpeta
        // del store ya borrada por `cleanup`, y el fault tumbaba el proceso de tests entero en otra suite (medido el
        // 2026-09-28: `NSCocoaErrorDomain 256` en `GroupsConvergence-…/personal.sqlite` desde `__NSFireTimer`).
        context.autosaveEnabled = false
        return context
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

    /// **El orden del ticket padre, con el corte** (ticket `late-remote-wipe-signal-also-wipes-rows-created-after-it`). El
    /// origen vació sus datos y ya repuso lo de grupo; este dispositivo —cerrado o sin red hasta ahora— procesa la señal
    /// tarde, con la reposición ya importada. Desde el 2026-09-27 se la llevaba y pedía la convergencia para devolverla;
    /// ahora no se la lleva —lo posterior a la señal se queda, entero— y sigue pidiendo, para lo anterior que sí se lleva
    /// y el origen no repone (una real vieja que el bridge del origen conservó, los grupos que el origen no tiene).
    @Test("la señal procesada tarde deja en su sitio la reposición de grupos del origen, y pide la convergencia")
    func lateRemoteWipe_afterTheOriginReconverged_keepsTheRows_andAsks() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            let signaledAt = Date.now.addingTimeInterval(-60)
            try bridgeGroupRows(context, expense, s, defaults: defaults)
            let before = Set(try txs(context, expenseID: expense.id).map(\.persistentModelID))
                .union(try legs(context, s.paid).map(\.persistentModelID))
                .union(try legs(context, s.received).map(\.persistentModelID))
            let draftsBefore = try context.fetchCount(FetchDescriptor<InboxDraft>())

            try DataWipeService.wipeLocallyForRemoteWipeSignal(in: context, signaledAt: signaledAt, fleetStartedOver: true,
                                                               defaults: defaults, rescheduleReminders: { _ in })

            let after = Set(try txs(context, expenseID: expense.id).map(\.persistentModelID))
                .union(try legs(context, s.paid).map(\.persistentModelID))
                .union(try legs(context, s.received).map(\.persistentModelID))
            #expect(after == before, """
                el receptor tardío se llevó la reposición de grupos del origen: su borrado viaja por el espejo y los gastos \
                de grupo desaparecen de lo personal en todo el parque
                """)
            #expect(try context.fetchCount(FetchDescriptor<InboxDraft>()) == draftsBefore,
                    "el receptor tardío se llevó los borradores de la reposición")
            #expect(GroupsBridgeRestoreConvergenceStore.isPending(defaults)
                    && GroupsBridgeRestoreConvergenceStore.isSettlementLegsPending(defaults), """
                el receptor tardío no pidió la convergencia: lo anterior que se lleva y el origen no repone no vuelve nunca
                """)
            #expect(try context.fetchCount(FetchDescriptor<SplitExpense>()) == 1
                    && context.fetchCount(FetchDescriptor<SplitSettlement>()) == 3, "el borrado del receptor conserva los grupos")
        }
    }

    /// **Lo que la petición del receptor repone** (review adversarial, lente de grupos). El iPad apuntó un gasto de grupo
    /// sin red ANTES del vaciado; su real llegó tarde al origen, que al reponer la conservó con su fecha vieja y solo rehízo
    /// la virtual. El corte se lleva esa real —existía al vaciar— y la petición del origen ya se gastó: sin la del
    /// receptor, el gasto se queda sin su pata ni su pregunta en todo el parque.
    @Test("una real vieja que el origen conservó al reponer: el corte se la lleva y la convergencia del receptor la repone")
    func lateRemoteWipe_anOldRealTheOriginKept_comesBackThroughTheReceiver() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let expense = try makeCaseAExpense(context, f)
            let signaledAt = Date.now.addingTimeInterval(-60)
            SessionState.shared.hasPrivateSession = true
            let realID = try insertRestoredRealTransaction(context, f, for: expense)
            try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id])
            let rows = try txs(context, expenseID: expense.id)
            let real = try #require(rows.first { $0.persistentModelID == realID }, "el bridge no conservó la real")
            real.createdAt = signaledAt.addingTimeInterval(-3600)
            try context.save()
            try #require(rows.contains { $0.account?.isSystemAccount == true && $0.createdAt > signaledAt },
                         "el fixture no tiene la virtual rehecha después de la señal")
            GroupsBridgeRestoreConvergenceStore.clear(defaults)

            try DataWipeService.wipeLocallyForRemoteWipeSignal(in: context, signaledAt: signaledAt, fleetStartedOver: true,
                                                               defaults: defaults, rescheduleReminders: { _ in })
            #expect(try txs(context, expenseID: expense.id).allSatisfy { $0.persistentModelID != realID },
                    "el corte no se llevó la real vieja: el caso no mide nada")
            #expect(GroupsBridgeRestoreConvergenceStore.isPending(defaults), """
                el receptor no pidió la convergencia: la real vieja que el origen conservó se va y el gasto se queda sin \
                su pata ni su pregunta en todo el parque
                """)

            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)

            #expect(try expenseDrafts(context, expense).count == 1,
                    "el Inbox no vuelve a preguntar de qué cuenta salió el gasto")
            #expect(try txs(context, expenseID: expense.id).contains { $0.account?.isSystemAccount == true },
                    "el gasto perdió su pata de la cuenta de grupos")
        }
    }

    /// El orden normal: este dispositivo procesa la señal ANTES de que el origen converja, así que lo que tiene puenteado
    /// es anterior al vaciado (las filas viejas cuyo borrado aún no llegó por el espejo). Se va, y no pide la convergencia
    /// ENTERA: si los dos convergieran enteros antes de cruzarse por el espejo, cada uno crearía su copia de todo el
    /// histórico de grupos (review adversarial, lentes de dinero y de sync). Desde el 2026-09-28 repone lo que el origen no
    /// repone, con el reparto del origen: casos «El origen sin los grupos», más abajo.
    @Test("en el orden normal el receptor se lleva lo puenteado y no pide la convergencia: la del origen basta")
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

            try DataWipeService.wipeLocallyForRemoteWipeSignal(in: context, signaledAt: signaledAt, fleetStartedOver: false,
                                                               defaults: defaults, rescheduleReminders: { _ in })

            #expect(try txs(context, expenseID: expense.id).isEmpty && legs(context, s.paid).isEmpty,
                    "el borrado del receptor ya no se lleva las filas viejas: el caso no mide nada")
            #expect(!GroupsBridgeRestoreConvergenceStore.isPending(defaults)
                    && !GroupsBridgeRestoreConvergenceStore.isSettlementLegsPending(defaults), """
                el receptor pidió la convergencia: si los dos convergen antes de cruzarse por el espejo, cada gasto y cada \
                liquidación de grupo sale dos veces
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

            try DataWipeService.wipeLocallyForRemoteWipeSignal(in: context, signaledAt: signaledAt, fleetStartedOver: true,
                                                               rescheduleReminders: { _ in })

            #expect(standard.object(forKey: "userName") == nil,
                    "el borrado del receptor ya no resetea las preferencias: el caso no mide la supervivencia de la petición")
            #expect(GroupsBridgeRestoreConvergenceStore.isPending(standard), """
                el reset de preferencias del receptor se llevó su petición de convergencia
                """)
            #expect(GroupsBridgeRestoreConvergenceStore.isSettlementLegsPending(standard),
                    "el reset de preferencias del receptor se llevó la petición de las liquidaciones")
            #expect(standard.double(forKey: "lastKnownWipeTimestamp") < start,
                    "el borrado del receptor re-emitió la señal de vaciado: rebotaría entre los dispositivos del Apple ID")
        }
    }

    // MARK: - Las filas puenteadas de un contexto

    private func bridgedRows(_ context: ModelContext) throws -> [TransactionItem] {
        try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID != nil || $0.splitSettlementID != nil }))
    }

    private func groupRowIDs(_ context: ModelContext) throws -> Set<PersistentIdentifier> {
        Set(try bridgedRows(context).map(\.persistentModelID))
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

    private func expectAlreadyRegistered(_ body: () throws -> Void) {
        do {
            try body()
            Issue.record("aprobar una liquidación ya registrada no dio error: se habría creado otra transacción")
        } catch DraftServiceError.groupSettlementAlreadyRegistered {
        } catch {
            Issue.record("error inesperado: \(error)")
        }
    }

    /// El agujero del ticket, por la convergencia: tras el borrado, el sync re-puentea la liquidación y la persona la aprueba.
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

    /// **La otra cara de «la marca corre la suerte de la real»:** si la transacción real y su marca se van —otro
    /// dispositivo se las llevó y el borrado llegó por el espejo—, el pago ya no está en ninguna cuenta y volver a
    /// preguntar es lo correcto. Por la convergencia, que es quien re-puentea una liquidación que se quedó sin patas.
    @Test("sin la real y su marca, la convergencia vuelve a preguntar, y el banco no cuenta nada doble")
    func convergence_withoutTheRealAndItsMark_asksAgain() throws {
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
                let real = try approvePendingDraft(context, s.received, into: bank)
                try #require(try drafts(context, s.received).map(\.status) == [.approved], "el fixture no deja la marca")
                for leg in try legs(context, s.received) { context.delete(leg) }
                context.delete(real)
                for mark in try drafts(context, s.received) { context.delete(mark) }
                try context.save()

                GroupsBridgeRestoreConvergenceStore.markSettlementLegsPending(defaults)
                GroupsBridgeRestoreConvergenceStore.markPending(defaults)
                GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)

                #expect(try legs(context, s.received).count == 1, "la pata virtual no volvió")
                #expect(try pendingDrafts(context, s.received).count == 1,
                        "el pago ya no está en ninguna cuenta y no se pregunta")
                #expect(try bankRows(context, bank).isEmpty)
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

    // MARK: - El origen sin los grupos (ticket `a-wipe-on-a-device-without-the-groups-loses-their-rows-everywhere`)

    /// Lo que el receptor del orden normal ve después: se llevó todo lo puenteado (anterior a la señal), no pidió nada
    /// entero y apunta que espera el reparto de ESTA señal.
    private func receiverWipesInTheNormalOrder(
        _ context: ModelContext, expense: SplitExpense, _ s: Settlements, defaults: UserDefaults, signaledAt: Date
    ) throws {
        try bridgeGroupRows(context, expense, s, defaults: defaults)
        try DataWipeService.wipeLocallyForRemoteWipeSignal(in: context, signaledAt: signaledAt, fleetStartedOver: false,
                                                           defaults: defaults, rescheduleReminders: { _ in })
        #expect(try txs(context, expenseID: expense.id).isEmpty && legs(context, s.paid).isEmpty
                && legs(context, s.received).isEmpty, "el borrado del receptor ya no se lleva lo puenteado: el caso no mide nada")
        #expect(!GroupsBridgeRestoreConvergenceStore.isPending(defaults), """
            en el orden normal el receptor pidió la convergencia antes de saber qué repone el origen: si los dos convergen \
            antes de cruzarse por el espejo, cada gasto de grupo sale dos veces
            """)
        let awaiting = try #require(GroupsRemoteWipeDivisionStore.awaiting(defaults), """
            el receptor del orden normal no apuntó que espera el reparto del origen: si el origen no tiene los grupos, \
            nadie repone lo que se llevó
            """)
        #expect(GroupsRemoteWipeDivisionLogic.sameSignal(awaiting.signaledAt, signaledAt.timeIntervalSince1970),
                "el receptor espera el reparto de otra señal")
    }

    /// **El ticket.** El iPad nunca entró en Grupos y vacía sus datos: su reparto va vacío. El iPhone con grupos procesa la
    /// señal en el orden normal —nada de grupo posterior— y se lleva lo puenteado. Hasta hoy no pedía nada y los gastos de
    /// grupo desaparecían de lo personal en todo el parque. Ahora, con el reparto del origen, el arranque pide la convergencia
    /// y vuelven una vez. El control: sin reparto, el arranque espera y no pide.
    @Test("origen sin grupos: el receptor con grupos repone los gastos y las liquidaciones de grupo, una vez")
    func normalOrder_originWithoutGroups_theReceiverReturnsTheRows() throws {
        let dir = try freshDir(), originDir = try freshDir()
        defer { cleanup(dir); cleanup(originDir) }
        let context = try makeContext(dir)
        let origin = try makeContext(originDir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let kv = InMemoryKeyValueStore()
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            let signaledAt = Date.now.addingTimeInterval(60)
            try receiverWipesInTheNormalOrder(context, expense: expense, s, defaults: defaults, signaledAt: signaledAt)

            // Control: el reparto aún no llegó. El arranque espera, sin pedir.
            GroupsRemoteWipeDivision.resolveIfArrived(kv: kv, defaults: defaults)
            #expect(!GroupsBridgeRestoreConvergenceStore.isPending(defaults), "el receptor pidió sin saber qué repone el origen")
            #expect(GroupsRemoteWipeDivisionStore.awaiting(defaults) != nil, "el receptor dejó de esperar sin reparto")

            try #require(try origin.fetchCount(FetchDescriptor<SplitExpense>()) == 0, "el origen trae grupos")
            GroupsRemoteWipeDivision.declare(context: origin, signaledAt: signaledAt, kv: kv, domainOpen: true)
            let division = try #require(GroupsRemoteWipeDivisionStore.readDivision(kv), "el origen no escribió su reparto")
            #expect(division.expenseIDs.isEmpty && division.settlementIDs.isEmpty, "el origen sin grupos dice que repone algo")

            GroupsRemoteWipeDivision.resolveIfArrived(kv: kv, defaults: defaults)
            #expect(GroupsBridgeRestoreConvergenceStore.isPending(defaults)
                    && GroupsBridgeRestoreConvergenceStore.isSettlementLegsPending(defaults), """
                con el reparto vacío del origen, el receptor no pidió la convergencia: los gastos de grupo no vuelven nunca
                """)
            #expect(GroupsRemoteWipeDivisionStore.awaiting(defaults) == nil, "el receptor sigue esperando un reparto que ya llegó")

            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)

            #expect(!(try txs(context, expenseID: expense.id)).isEmpty, "el gasto de grupo no volvió a lo personal")
            #expect(try expenseDrafts(context, expense).count == 1, "el Inbox no pregunta de qué cuenta salió el gasto")
            #expect(try legs(context, s.paid).count == 1, "la liquidación que pagué no volvió, o volvió dos veces")
            #expect(try legs(context, s.received).count == 1, "la que me pagaron no volvió, o volvió dos veces")
            #expect(try legs(context, s.unconfirmed).isEmpty, "sin confirmar no se crea nunca")
            #expect(!GroupsBridgeRestoreConvergenceStore.isPending(defaults)
                    && GroupsBridgeRestoreConvergenceStore.exclusion(defaults) == nil)

            // Una vez: el arranque siguiente no vuelve a pedir.
            let after = try groupRowIDs(context)
            GroupsRemoteWipeDivision.resolveIfArrived(kv: kv, defaults: defaults)
            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)
            #expect(try groupRowIDs(context) == after, "un segundo arranque volvió a reponer")
        }
    }

    /// **Origen con los mismos grupos: repone él, y el receptor no.** Es el orden normal del 27-sep, y lo que el reparto no
    /// puede romper: si el receptor repusiera también, cada gasto saldría dos veces al cruzarse por el espejo.
    @Test("origen con los grupos: el receptor no repone lo que repone el origen")
    func normalOrder_originWithTheGroups_theReceiverLeavesThemToTheOrigin() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let kv = InMemoryKeyValueStore()
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            let signaledAt = Date.now.addingTimeInterval(60)
            // El origen tiene los mismos grupos: su reparto sale del mismo store de Grupos.
            GroupsRemoteWipeDivision.declare(context: context, signaledAt: signaledAt, kv: kv, domainOpen: true)
            try receiverWipesInTheNormalOrder(context, expense: expense, s, defaults: defaults, signaledAt: signaledAt)

            GroupsRemoteWipeDivision.resolveIfArrived(kv: kv, defaults: defaults)
            let exclusion = try #require(GroupsBridgeRestoreConvergenceStore.exclusion(defaults),
                                         "el receptor pidió la convergencia ENTERA con un origen que repone")
            #expect(exclusion.expenseIDs == [expense.id.uuidString])
            #expect(exclusion.settlementIDs == [s.paid.id.uuidString, s.received.id.uuidString])

            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)

            #expect(try txs(context, expenseID: expense.id).isEmpty && expenseDrafts(context, expense).isEmpty, """
                el receptor repuso un gasto que repone el origen: al cruzarse por el espejo sale dos veces, con dos borradores
                """)
            #expect(try legs(context, s.paid).isEmpty && legs(context, s.received).isEmpty,
                    "el receptor repuso una liquidación que repone el origen")
            #expect(!GroupsBridgeRestoreConvergenceStore.isPending(defaults) && GroupsPendingBridgeIntent.pending.isEmpty)
        }
    }

    /// **Origen con una parte**: otra cuenta de grupos, o el canal atrasado. Repone lo suyo, y el receptor el resto: un
    /// sí/no en la señal no podía decir esto.
    @Test("origen con una parte de los grupos: el receptor repone solo lo que el origen no tiene")
    func normalOrder_originWithPartOfTheGroups_theReceiverReturnsTheRest() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let kv = InMemoryKeyValueStore()
            let known = try makeCaseAExpense(context, f)
            let unknown = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            let signaledAt = Date.now.addingTimeInterval(60)
            SessionState.shared.hasPrivateSession = true
            try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [unknown.id])
            try receiverWipesInTheNormalOrder(context, expense: known, s, defaults: defaults, signaledAt: signaledAt)
            #expect(try txs(context, expenseID: unknown.id).isEmpty)
            try GroupsRemoteWipeDivisionStore.writeDivision(.init(
                signaledAt: signaledAt.timeIntervalSince1970, expenseIDs: [known.id.uuidString],
                settlementIDs: [s.paid.id.uuidString]), to: kv)

            GroupsRemoteWipeDivision.resolveIfArrived(kv: kv, defaults: defaults)
            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)

            #expect(try txs(context, expenseID: known.id).isEmpty, "el receptor repuso el gasto que repone el origen")
            #expect(!(try txs(context, expenseID: unknown.id)).isEmpty, "el gasto que el origen no tiene no volvió")
            #expect(try expenseDrafts(context, unknown).count == 1)
            #expect(try legs(context, s.paid).isEmpty, "el receptor repuso la liquidación que repone el origen")
            #expect(try legs(context, s.received).count == 1, "la liquidación que el origen no tiene no volvió")
        }
    }

    /// **El orden tardío sigue pidiendo la convergencia ENTERA** (#284/#289) aunque haya un reparto esperando o una
    /// exclusión puesta: la entera repone más, y lo que el corte se lleva en ese orden no lo cubre el reparto.
    @Test("orden tardío: el receptor pide la convergencia entera y deja de esperar el reparto")
    func lateOrder_asksForTheWholeConvergence_andStopsAwaiting() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            let signaledAt = Date.now.addingTimeInterval(-60)
            try bridgeGroupRows(context, expense, s, defaults: defaults)
            try GroupsRemoteWipeDivisionStore.setAwaiting(.init(signaledAt: 1, since: Date.now.timeIntervalSince1970),
                                                          defaults)
            try GroupsBridgeRestoreConvergenceStore.markPending(
                excluding: .init(expenseIDs: [expense.id.uuidString], settlementIDs: []), defaults)
            GroupsBridgeRestoreConvergenceStore.markSettlementLegsPending(defaults)

            try DataWipeService.wipeLocallyForRemoteWipeSignal(in: context, signaledAt: signaledAt, fleetStartedOver: true,
                                                               defaults: defaults, rescheduleReminders: { _ in })

            #expect(GroupsBridgeRestoreConvergenceStore.isWholePending(defaults), """
                el receptor tardío ya no pide la convergencia entera: lo anterior que el corte se lleva y el origen no repone \
                no vuelve nunca
                """)
            #expect(GroupsRemoteWipeDivisionStore.awaiting(defaults) == nil, """
                el receptor tardío sigue esperando un reparto: su convergencia entera ya lo repone todo, y el reparto pediría \
                otra
                """)
        }
    }

    /// Lo que los casos de arriba no pueden ver, porque esperan en unos `defaults` aislados: en producción la espera va a
    /// `.standard`, y el borrado del receptor RESETEA las preferencias de `.standard` justo después de apuntarla.
    @Test("en `.standard` la espera del reparto sobrevive al reset de preferencias del receptor")
    func normalOrder_awaitingSurvivesThePreferencesReset() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            try bridgeGroupRows(context, expense, s, defaults: defaults)
            let standard = UserDefaults.standard
            standard.set("Alguien", forKey: "userName")
            GroupsBridgeRestoreConvergenceStore.clear(standard)
            GroupsRemoteWipeDivisionStore.clearAwaiting(standard)

            try DataWipeService.wipeLocallyForRemoteWipeSignal(in: context, signaledAt: Date.now.addingTimeInterval(60),
                                                               fleetStartedOver: false, rescheduleReminders: { _ in })

            #expect(standard.object(forKey: "userName") == nil,
                    "el borrado del receptor ya no resetea las preferencias: el caso no mide la supervivencia de la espera")
            #expect(GroupsRemoteWipeDivisionStore.awaiting(standard) != nil,
                    "el reset de preferencias del receptor se llevó la espera del reparto")
        }
    }

    /// **El reparto del origen, con los filtros de su convergencia**: todos los gastos locales, y las liquidaciones
    /// confirmadas fuera de grupos ocultos. Con el dominio cerrado su convergencia espera: reparto vacío.
    @Test("el origen reparte con los filtros de su convergencia, y con el dominio cerrado no reparte nada")
    func originDivision_usesTheConvergenceFilters() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { _ in
            let kv = InMemoryKeyValueStore()
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            let hidden = SplitGroup(name: "Borrado", currencyCode: "USD")
            hidden.isHiddenForAll = true
            context.insert(hidden)
            let hiddenSettlement = SplitSettlement(groupZoneID: hidden.cloudKitZoneID, fromMemberID: f.me.id.uuidString,
                                                   toMemberID: f.ana.id.uuidString, amount: 5, currencyCode: "USD")
            hiddenSettlement.isConfirmed = true
            context.insert(hiddenSettlement)
            try context.save()
            let signaledAt = Date(timeIntervalSince1970: 1_800_000_000.123456)

            GroupsRemoteWipeDivision.declare(context: context, signaledAt: signaledAt, kv: kv, domainOpen: true)
            let division = try #require(GroupsRemoteWipeDivisionStore.readDivision(kv))
            #expect(division.signaledAt == signaledAt.timeIntervalSince1970, "el reparto no lleva la hora de la señal")
            #expect(division.expenseIDs == [expense.id.uuidString])
            #expect(division.settlementIDs == [s.paid.id.uuidString, s.received.id.uuidString], """
                el reparto incluye una liquidación sin confirmar o de un grupo oculto: el origen no la repone y el receptor \
                tampoco lo haría
                """)

            GroupsRemoteWipeDivision.declare(context: context, signaledAt: signaledAt, kv: kv, domainOpen: false)
            let closed = try #require(GroupsRemoteWipeDivisionStore.readDivision(kv))
            #expect(closed.expenseIDs.isEmpty && closed.settlementIDs.isEmpty,
                    "con el dominio cerrado el origen no repone nada, y su reparto dice lo contrario")
        }
    }

    // MARK: - Lo que el origen prometió y no llega (ticket `wipe-division-exclusion-trusts-the-origin-to-converge`)

    /// El receptor del orden normal con un origen que tiene los mismos grupos: su reparto lo promete TODO, el receptor lo
    /// excluye de su convergencia y no repone nada. Devuelve desde cuándo confía (el arranque que resolvió el reparto), que
    /// es de donde corre el techo.
    private func receiverTrustsTheOrigin(
        _ context: ModelContext, expense: SplitExpense, _ s: Settlements, defaults: UserDefaults
    ) throws -> Date {
        let kv = InMemoryKeyValueStore()
        let signaledAt = Date.now.addingTimeInterval(60)
        try receiverWipesInTheNormalOrder(context, expense: expense, s, defaults: defaults, signaledAt: signaledAt)
        try GroupsRemoteWipeDivisionStore.writeDivision(.init(
            signaledAt: signaledAt.timeIntervalSince1970, expenseIDs: [expense.id.uuidString],
            settlementIDs: [s.paid.id.uuidString, s.received.id.uuidString]), to: kv)
        GroupsRemoteWipeDivision.resolveIfArrived(kv: kv, defaults: defaults)
        GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)
        #expect(try bridgedRows(context).isEmpty && expenseDrafts(context, expense).isEmpty,
                "el receptor repuso lo que prometió el origen: el caso no mide la promesa")
        let trusted = try #require(GroupsRemoteWipeDivisionStore.trusted(defaults), "el reparto no apuntó la promesa")
        return Date(timeIntervalSince1970: trusted.since)
    }

    /// Lo que el espejo trae del origen cuando por fin converge: la pata de la cuenta de grupos del gasto y una por
    /// liquidación, con la identidad de allí (aquí son filas nuevas que el receptor no creó) y creadas después de la señal
    /// (la de `receiverTrustsTheOrigin` va un minuto por delante). `createdAt` anterior es lo que sube tarde un tercer
    /// dispositivo sin red.
    @discardableResult
    private func originRowsArrive(
        _ context: ModelContext, expense: SplitExpense? = nil, settlements: [SplitSettlement] = [],
        createdAt: Date = Date.now.addingTimeInterval(120)
    ) throws -> Set<PersistentIdentifier> {
        let groups = Account(name: "Grupos", currencyCode: "USD", colorHex: "#333333", iconName: "person.3", type: "cash",
                             isSystemAccount: true)
        context.insert(groups)
        if let expense {
            let tx = TransactionItem(date: expense.date, amount: 60, currencyCode: "USD", note: "", account: groups)
            tx.splitExpenseID = expense.id.uuidString
            tx.createdAt = createdAt
            context.insert(tx)
        }
        for settlement in settlements {
            let tx = TransactionItem(date: settlement.date, amount: settlement.amount, currencyCode: "USD", note: "",
                                     account: groups)
            tx.splitSettlementID = settlement.id.uuidString
            tx.createdAt = createdAt
            context.insert(tx)
        }
        try context.save()
        return try groupRowIDs(context)
    }

    private func takeOver(_ defaults: UserDefaults, at date: Date, _ context: ModelContext) {
        GroupsRemoteWipeDivision.takeOverIfOverdue(context: context, defaults: defaults, now: date)
    }

    /// **El ticket.** El iPad tiene los mismos grupos, vacía y no vuelve a abrirse: su reparto lo promete todo y nunca lo
    /// repone. Hasta hoy el iPhone lo excluía para siempre y los gastos y liquidaciones de grupo no volvían. Ahora, pasado el
    /// techo, los repone el iPhone, una vez.
    @Test("origen que promete y nunca repone: pasado el techo el receptor repone él, una vez")
    func trust_originNeverReturns_theReceiverReturnsTheRowsAfterTheCeiling() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            let since = try receiverTrustsTheOrigin(context, expense: expense, s, defaults: defaults)
            let ceiling = GroupsRemoteWipeDivisionLogic.trustCeiling

            takeOver(defaults, at: since.addingTimeInterval(ceiling - 1), context)
            #expect(try bridgedRows(context).isEmpty, "el receptor dejó de confiar en el origen antes del techo")

            takeOver(defaults, at: since.addingTimeInterval(ceiling), context)
            #expect(!(try txs(context, expenseID: expense.id)).isEmpty, """
                pasado el techo el gasto de grupo sigue sin volver: el origen no repuso y nadie lo hará
                """)
            #expect(try expenseDrafts(context, expense).count == 1, "el Inbox no pregunta de qué cuenta salió el gasto")
            #expect(try legs(context, s.paid).count == 1, "la liquidación que pagué no volvió, o volvió dos veces")
            #expect(try legs(context, s.received).count == 1, "la que me pagaron no volvió, o volvió dos veces")
            #expect(try legs(context, s.unconfirmed).isEmpty, "sin confirmar no se crea nunca")
            #expect(GroupsRemoteWipeDivisionStore.trusted(defaults) == nil, "la promesa sigue puesta tras reponer")
            #expect(GroupsPendingBridgeIntent.pending.isEmpty, "todo quedó atendido")

            let after = try groupRowIDs(context)
            let draftCount = try context.fetchCount(FetchDescriptor<InboxDraft>())
            takeOver(defaults, at: since.addingTimeInterval(ceiling * 2), context)
            #expect(try groupRowIDs(context) == after, "un segundo arranque volvió a reponer")
            #expect(try context.fetchCount(FetchDescriptor<InboxDraft>()) == draftCount)
        }
    }

    /// **El origen cumple a tiempo**: sus filas bajan antes del techo. Un arranque antes del techo ve que llegaron y suelta
    /// la promesa; pasado el techo no se toca nada.
    @Test("origen que repone a tiempo: el receptor suelta la promesa y no toca nada")
    func trust_originReturnsInTime_nothingChanges() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            let since = try receiverTrustsTheOrigin(context, expense: expense, s, defaults: defaults)
            let arrived = try originRowsArrive(context, expense: expense, settlements: [s.paid, s.received])

            takeOver(defaults, at: since.addingTimeInterval(3600), context)
            #expect(GroupsRemoteWipeDivisionStore.trusted(defaults) == nil,
                    "todo lo prometido llegó y el receptor sigue esperando")
            takeOver(defaults, at: since.addingTimeInterval(GroupsRemoteWipeDivisionLogic.trustCeiling), context)
            #expect(try groupRowIDs(context) == arrived, "el receptor re-puenteó lo que el origen ya había repuesto")
            #expect(try context.fetchCount(FetchDescriptor<InboxDraft>()) == 0, "el receptor creó borradores de lo repuesto")
        }
    }

    /// **El origen cumple tarde, pasado el techo, pero antes de que el receptor mire**: sus filas ya están aquí cuando el
    /// receptor deja de confiar. No se re-puentea nada: sin copias dobles.
    @Test("origen que repone tarde, antes de que el receptor mire: sin copias dobles")
    func trust_originReturnsLate_beforeTheReceiverLooks_noSecondCopy() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            let since = try receiverTrustsTheOrigin(context, expense: expense, s, defaults: defaults)
            let arrived = try originRowsArrive(context, expense: expense, settlements: [s.paid, s.received])

            takeOver(defaults, at: since.addingTimeInterval(GroupsRemoteWipeDivisionLogic.trustCeiling + 3600), context)
            #expect(try groupRowIDs(context) == arrived, "el receptor repuso encima de lo que el origen ya repuso")
            #expect(try context.fetchCount(FetchDescriptor<InboxDraft>()) == 0, "el Inbox pregunta dos veces por lo mismo")
            #expect(GroupsRemoteWipeDivisionStore.trusted(defaults) == nil)
        }
    }

    /// **Una fila ANTERIOR a la señal que baja tarde no prueba que el origen cumpliera** (review adversarial, lente de sync).
    /// La sube tarde un tercer dispositivo que estaba sin red; su propio corte se la llevará cuando procese la señal, y si
    /// el origen no repone, nadie lo haría. Pasado el techo, el receptor repone el gasto.
    @Test("una fila anterior a la señal que baja tarde no cuenta como llegada")
    func trust_aPreSignalRowArrivingLate_doesNotCount() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            let since = try receiverTrustsTheOrigin(context, expense: expense, s, defaults: defaults)
            try originRowsArrive(context, expense: expense, createdAt: Date.now.addingTimeInterval(-3600))

            takeOver(defaults, at: since.addingTimeInterval(3600), context)
            #expect(GroupsRemoteWipeDivisionStore.trusted(defaults)?.expenseIDs == [expense.id.uuidString],
                    "una fila de antes de la señal sacó el gasto de la promesa: si el origen no repone, no vuelve")
            takeOver(defaults, at: since.addingTimeInterval(GroupsRemoteWipeDivisionLogic.trustCeiling), context)
            #expect(try expenseDrafts(context, expense).count == 1, "pasado el techo el receptor no repuso el gasto")
        }
    }

    /// **El origen cumple después de que el receptor repusiera.** Converge detrás de la quiescencia del import, sobre las
    /// filas del receptor ya bajadas por el espejo: su re-puente es el de este store, y el bridge concilia por id.
    @Test("origen que repone después de que el receptor repusiera: su convergencia concilia, sin copias dobles")
    func trust_originReturnsAfterTheReceiverTookOver_itsConvergenceReconciles() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            let since = try receiverTrustsTheOrigin(context, expense: expense, s, defaults: defaults)
            takeOver(defaults, at: since.addingTimeInterval(GroupsRemoteWipeDivisionLogic.trustCeiling), context)
            try #require(!(try txs(context, expenseID: expense.id)).isEmpty, "el receptor no repuso: el caso no mide nada")

            let expenseAmounts = try txs(context, expenseID: expense.id).map(\.amount).sorted()
            let legIDs = Set(try (legs(context, s.paid) + legs(context, s.received)).map(\.persistentModelID))
            let draftCount = try context.fetchCount(FetchDescriptor<InboxDraft>())
            // La convergencia ENTERA del origen, la que pide su «Vaciar datos», sobre el store con lo del receptor.
            GroupsBridgeRestoreConvergenceStore.markSettlementLegsPending(defaults)
            GroupsBridgeRestoreConvergenceStore.markPending(defaults)
            GroupsBridgeRestoreConvergence.convergeIfPending(context: context, defaults: defaults)
            #expect(try txs(context, expenseID: expense.id).map(\.amount).sorted() == expenseAmounts,
                    "la convergencia tardía del origen duplicó el gasto que repuso el receptor")
            #expect(Set(try (legs(context, s.paid) + legs(context, s.received)).map(\.persistentModelID)) == legIDs,
                    "la convergencia tardía del origen duplicó una liquidación")
            #expect(try context.fetchCount(FetchDescriptor<InboxDraft>()) == draftCount, "el Inbox pregunta dos veces")
        }
    }

    /// **El origen cumple a medias**: repone el gasto y una liquidación, y la otra agota sus intentos. Pasado el techo, el
    /// receptor repone solo la que falta.
    @Test("origen que repone una parte: pasado el techo el receptor repone solo lo que falta")
    func trust_originReturnsPart_theReceiverReturnsOnlyTheRest() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            let since = try receiverTrustsTheOrigin(context, expense: expense, s, defaults: defaults)
            let arrived = try originRowsArrive(context, expense: expense, settlements: [s.paid])

            takeOver(defaults, at: since.addingTimeInterval(3600), context)
            let rest = try #require(GroupsRemoteWipeDivisionStore.trusted(defaults), "la promesa se soltó con algo sin llegar")
            #expect(rest.expenseIDs.isEmpty && rest.settlementIDs == [s.received.id.uuidString]
                    && rest.since == since.timeIntervalSince1970, "la promesa no se quedó solo con lo que falta")

            takeOver(defaults, at: since.addingTimeInterval(GroupsRemoteWipeDivisionLogic.trustCeiling), context)
            #expect(try legs(context, s.received).count == 1, "la liquidación que el origen no repuso no volvió")
            #expect(try arrived.isSubset(of: groupRowIDs(context)), "el receptor rehízo lo que el origen sí repuso")
            #expect(try txs(context, expenseID: expense.id).count == 1 && expenseDrafts(context, expense).isEmpty,
                    "el receptor re-puenteó el gasto que el origen sí repuso")
            #expect(try legs(context, s.paid).count == 1, "la liquidación que el origen repuso salió dos veces")
        }
    }

    /// **Lo que la retoma NO toca, y lo que entrega a la intención durable** (review adversarial, lente de tests). Una
    /// liquidación cuyo único rastro aquí es su marca de aprobación (un borrador `.approved`, y su real sin
    /// `splitSettlementID`) ya llegó: re-puentearla volvería a preguntar por un pago registrado. Una sin confirmar o de un
    /// grupo oculto no se pide (`bridgeSettlement` no mira el oculto: sería una deuda fantasma). Un gasto cuyo member propio
    /// aún no se resuelve va a la intención durable, con el canal del backend. El control: la que falta sí vuelve.
    @Test("la retoma deja lo aprobado, lo no confirmado y lo oculto, y entrega lo no atendido a la intención durable")
    func trust_takeOver_filtersAndHandsOverTheUnattended() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            SessionState.shared.hasPrivateSession = true
            let s = try makeSettlements(context, f)
            let hidden = SplitGroup(name: "Borrado", currencyCode: "USD")
            hidden.isHiddenForAll = true
            context.insert(hidden)
            let hiddenSettlement = SplitSettlement(groupZoneID: hidden.cloudKitZoneID, fromMemberID: f.me.id.uuidString,
                                                   toMemberID: f.ana.id.uuidString, amount: 5, currencyCode: "USD")
            hiddenSettlement.isConfirmed = true
            context.insert(hiddenSettlement)
            let flat = SplitGroup(name: "Piso", currencyCode: "USD")
            context.insert(flat)
            let luis = SplitMember(groupZoneID: flat.cloudKitZoneID, displayName: "Luis")
            context.insert(luis)
            let unresolved = SplitExpense(groupZoneID: flat.cloudKitZoneID, amount: 50, currencyCode: "USD",
                                          expenseDescription: "Luz", paidByMemberID: luis.id.uuidString)
            context.insert(unresolved)
            // La marca de aprobación de `received`, llegada del origen: su única fila con el id de la liquidación.
            context.insert(InboxDraft(amount: 25, sourceType: .groupSettlement, status: .approved,
                                      splitSettlementID: s.received.id.uuidString))
            // Un gasto del que solo bajó el borrador de «¿de qué cuenta salió?»: también llegó.
            let draftOnly = try makeCaseAExpense(context, f)
            context.insert(InboxDraft(note: "Cena", amount: -90, sourceType: .groupExpense,
                                      splitExpenseID: draftOnly.id.uuidString))
            try context.save()
            let since = Date.now.addingTimeInterval(-GroupsRemoteWipeDivisionLogic.trustCeiling)
            try GroupsRemoteWipeDivisionStore.setTrusted(.init(
                signaledAt: since.timeIntervalSince1970 - 60, since: since.timeIntervalSince1970,
                expenseIDs: [unresolved.id.uuidString, draftOnly.id.uuidString],
                settlementIDs: [s.paid.id.uuidString, s.received.id.uuidString, s.unconfirmed.id.uuidString,
                                hiddenSettlement.id.uuidString]), defaults)

            takeOver(defaults, at: .now, context)

            #expect(try legs(context, s.paid).count == 1, "el control: la liquidación que falta no volvió")
            #expect(try legs(context, s.received).isEmpty && drafts(context, s.received).count == 1, """
                la retoma re-puenteó una liquidación cuya marca de aprobación ya llegó: el Inbox vuelve a preguntar por un \
                pago registrado
                """)
            #expect(try legs(context, s.unconfirmed).isEmpty, "la retoma pidió una liquidación sin confirmar")
            #expect(try txs(context, expenseID: draftOnly.id).isEmpty && expenseDrafts(context, draftOnly).count == 1, """
                la retoma re-puenteó un gasto cuyo borrador ya había llegado: sale dos veces al cruzarse por el espejo
                """)
            #expect(try legs(context, hiddenSettlement).isEmpty, """
                la retoma re-puenteó la liquidación de un grupo oculto: deuda fantasma sin el gasto que la compensaba
                """)
            let pending = GroupsPendingBridgeIntent.pending
            #expect(pending.expenseIDs.contains(unresolved.id) && pending.backendExpenseIDs.contains(unresolved.id), """
                el gasto que el bridge no atendió no pasó a la intención durable con el canal del backend: no vuelve nunca
                """)
            #expect(!pending.settlementIDs.contains(s.unconfirmed.id) && !pending.settlementIDs.contains(hiddenSettlement.id),
                    "la retoma entregó a la intención lo que no debía pedir")
            #expect(GroupsRemoteWipeDivisionStore.trusted(defaults) == nil)
        }
    }

    /// **Las puertas de la convergencia**: en solo-grupos el bridge borra las reales que re-puentea, y mientras se espera
    /// el reparto de una señal más nueva, ese reparto decide. El control: sin las dos, repone.
    @Test("sin sesión privada, o esperando el reparto de otra señal, el receptor no repone")
    func trust_waitsForAPrivateSession_andForANewerDivision() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) { defaults in
            let expense = try makeCaseAExpense(context, f)
            let s = try makeSettlements(context, f)
            let since = try receiverTrustsTheOrigin(context, expense: expense, s, defaults: defaults)
            let overdue = since.addingTimeInterval(GroupsRemoteWipeDivisionLogic.trustCeiling)

            SessionState.shared.hasPrivateSession = false
            takeOver(defaults, at: overdue, context)
            #expect(try bridgedRows(context).isEmpty, "el receptor re-puenteó en una sesión solo-grupos")
            SessionState.shared.hasPrivateSession = true

            GroupsRemoteWipeDivision.awaitOrigin(signaledAt: overdue, defaults: defaults, now: overdue)
            takeOver(defaults, at: overdue, context)
            #expect(try bridgedRows(context).isEmpty, "el receptor repuso sin esperar el reparto de la señal nueva")
            #expect(GroupsRemoteWipeDivisionStore.trusted(defaults) != nil, "la espera de otra señal se llevó la promesa")

            GroupsRemoteWipeDivisionStore.clearAwaiting(defaults)
            takeOver(defaults, at: overdue, context)
            #expect(!(try txs(context, expenseID: expense.id)).isEmpty, "el control: sin las dos puertas, repone")
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
