//
//  GroupsDetachedLedgerExitTests.swift
//  YalaTests
//
//  Ticket `groups-detach-ledger-has-no-exit` · **el libro de conservados ya tiene salida.**
//
//  La persona soltó su cuenta de grupos conservando los movimientos, volvió a asociar la misma cuenta y el libro
//  impide el duplicado. Hasta el 2026-10-01, si después borraba a mano uno de esos movimientos, el gasto del grupo
//  se quedaba sin ninguna transacción personal para siempre: el puente lo daba por atendido sin crear nada.
//
//  Contra el bridge real, con los tres stores en disco (molde `GroupsBridgeRestoreConvergenceTests`): el libro
//  compara identidades de un store CONCRETO, y un store en memoria no tiene fichero que lo identifique.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Libro de conservados · la salida cuando el movimiento ya no está", .serialized)
@MainActor
struct GroupsDetachedLedgerExitTests {

    // MARK: - Infra

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GDLExit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            #if DEBUG
            print("GroupsDetachedLedgerExitTests: cleanup: \(error)")
            #endif
        }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration(
            "GDLE-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "GDLE-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "GDLE-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        let context = ModelContext(container)
        // Sin autosave: un guardado diferido tras el `cleanup` tumba el proceso de tests (ver la suite molde).
        context.autosaveEnabled = false
        return context
    }

    private struct Fixture {
        let group: SplitGroup
        let me: SplitMember
        let ana: SplitMember
        let cash: Account
    }

    /// Grupo del canal BACKEND: desasociar solo suelta esas zonas.
    private func makeFixture(_ context: ModelContext) throws -> Fixture {
        let group = SplitGroup(name: "Viaje", currencyCode: "USD")
        group.isBackendGroup = true
        context.insert(group)
        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", isCurrentUser: true)
        context.insert(me)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(ana)
        let cash = Account(name: "Efectivo", currencyCode: "USD", colorHex: "#111111",
                           iconName: "banknote", type: "cash")
        context.insert(cash)
        // Un movimiento personal que no tiene nada que ver con el grupo, sin cuenta para que `conserved` no
        // lo cuente. Un teléfono real nunca tiene el Panel vacío, y un store SIN transacciones el libro lo lee
        // como «no se sabe» (la purga del espejo lo vacía antes de re-importar): sin esta fila, borrar el único
        // movimiento conservado mediría ese caso y no el del ticket.
        context.insert(TransactionItem(date: .distantPast, amount: -3, currencyCode: "USD", note: "Café"))
        try context.save()
        return Fixture(group: group, me: me, ana: ana, cash: cash)
    }

    /// Caso A: pagué yo 90, mi parte es 30 y la de Ana 60.
    private func makeExpense(_ context: ModelContext, _ f: Fixture, description: String = "Cena") throws -> SplitExpense {
        let expense = SplitExpense(groupZoneID: f.group.cloudKitZoneID, amount: 90, currencyCode: "USD",
                                   expenseDescription: description, paidByMemberID: f.me.id.uuidString)
        context.insert(expense)
        context.insert(SplitShare(expenseID: expense.id, memberID: f.me.id.uuidString, amount: 30,
                                  groupZoneID: f.group.cloudKitZoneID))
        context.insert(SplitShare(expenseID: expense.id, memberID: f.ana.id.uuidString, amount: 60,
                                  groupZoneID: f.group.cloudKitZoneID))
        try context.save()
        return expense
    }

    /// Le pagué 40 a Ana (Caso C), confirmada.
    private func makeSettlement(_ context: ModelContext, _ f: Fixture) throws -> SplitSettlement {
        let s = SplitSettlement(groupZoneID: f.group.cloudKitZoneID, fromMemberID: f.me.id.uuidString,
                                toMemberID: f.ana.id.uuidString, amount: 40, currencyCode: "USD")
        s.isConfirmed = true
        context.insert(s)
        try context.save()
        return s
    }

    /// Lo que el puente tiene para este gasto: transacciones y borradores con su puntero.
    private func bridgedRows(_ context: ModelContext, expenseID: UUID) throws -> Int {
        let idStr = expenseID.uuidString
        return try context.fetchCount(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.splitExpenseID == idStr }))
            + context.fetchCount(FetchDescriptor<InboxDraft>(predicate: #Predicate { $0.splitExpenseID == idStr }))
    }

    private func bridgedRows(_ context: ModelContext, settlementID: UUID) throws -> Int {
        let idStr = settlementID.uuidString
        return try context.fetchCount(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.splitSettlementID == idStr }))
            + context.fetchCount(FetchDescriptor<InboxDraft>(predicate: #Predicate { $0.splitSettlementID == idStr }))
    }

    private func allTransactions(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<TransactionItem>())
    }

    /// Las transacciones de la cuenta real sin puntero de grupo: los movimientos conservados.
    private func conserved(_ context: ModelContext, _ f: Fixture) throws -> [TransactionItem] {
        try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID == nil && $0.splitSettlementID == nil }))
            .filter { $0.account?.persistentModelID == f.cash.persistentModelID }
    }

    /// El entorno del bridge, restaurado al salir: su contexto, la sesión privada, la intención durable aislada
    /// y el dominio de `UserDefaults.standard`, donde viven el libro y la asociación que lee el bridge.
    private func withEnvironment(_ context: ModelContext, _ body: () throws -> Void) rethrows {
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
        GroupsDetachedBridgeLedger.clear()
        SessionState.shared.hasPrivateSession = true
        try body()
    }

    /// Re-asocia la misma cuenta (el espejo local se lee antes que el iCloud-KV).
    private func associate(_ sub: String) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        UserDefaults.standard.set(
            try encoder.encode(GroupsAssociationRecord(sub: sub, provider: "apple", email: nil, kind: nil,
                                                       associatedAt: .now)),
            forKey: GroupsAccountAssociation.localKey)
        try #require(GroupsAccountAssociation.shared.associatedSub == sub, "el fixture no asocia la cuenta")
    }

    /// Puentea con la cuenta real, desasocia conservando y re-asocia la MISMA cuenta. Deja el escenario del
    /// ticket: el movimiento personal en el Panel, sin puntero, y el libro frenando el puente.
    private func conserveAndReassociate(_ context: ModelContext, _ f: Fixture,
                                        expenses: [SplitExpense] = [], settlements: [SplitSettlement] = []) throws {
        for expense in expenses {
            try GroupTransactionBridge.shared.bridgeExpense(expense, in: f.group, accountForCurrentUser: f.cash)
        }
        for settlement in settlements {
            try GroupTransactionBridge.shared.bridgeSettlement(settlement, in: f.group, accountForCurrentUser: f.cash)
        }
        try #require(try conserved(context, f).isEmpty, "el fixture ya trae movimientos sin puntero")
        let outcome = try #require(GroupsAssociationDetach.detachBridge(
            context: context, choice: .keep, associatedSub: "sub-mia"))
        try #require(outcome.released == expenses.count + settlements.count,
                     "el fixture no deja un movimiento real por gasto y por liquidación")
        try associate("sub-mia")
    }

    // MARK: - El recorrido del ticket

    @Test("gasto: mientras el movimiento conservado vive no hay duplicado; borrado a mano, el puente lo vuelve a crear")
    func expense_deletedByHand_bridgeCreatesAgain() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let expense = try makeExpense(context, f)
            try conserveAndReassociate(context, f, expenses: [expense])
            let kept = try #require(try conserved(context, f).first)
            let total = try allTransactions(context)

            // Vivo: el libro frena, sin duplicado.
            #expect(try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id]) == [expense.id])
            #expect(try bridgedRows(context, expenseID: expense.id) == 0, "re-asociar duplicó el gasto conservado")
            #expect(try allTransactions(context) == total)

            // Una edición remota del gasto mientras el movimiento vive tampoco duplica.
            expense.expenseDescription = "Cena (editada por Ana)"
            try context.save()
            try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id])
            #expect(try bridgedRows(context, expenseID: expense.id) == 0, "la edición remota duplicó el gasto")

            // La persona borra el movimiento conservado.
            context.delete(kept)
            try context.save()

            // El ciclo siguiente: la edición remota (o cualquier re-puente) lo vuelve a crear.
            #expect(try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id]) == [expense.id])
            #expect(try bridgedRows(context, expenseID: expense.id) > 0,
                    "el gasto se quedó sin movimiento personal: el libro lo sigue dando por puesto")
            #expect(GroupsDetachedBridgeLedger.isConserved(expenseID: expense.id.uuidString, associatedSub: "sub-mia") == false,
                    "la entrada sigue en el libro")
        }
    }

    @Test("liquidación: borrado a mano el movimiento conservado, el puente vuelve a crear sus patas")
    func settlement_deletedByHand_bridgeCreatesAgain() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let settlement = try makeSettlement(context, f)
            try conserveAndReassociate(context, f, settlements: [settlement])
            let kept = try #require(try conserved(context, f).first)

            #expect(try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [settlement.id]) == [settlement.id])
            #expect(try bridgedRows(context, settlementID: settlement.id) == 0, "re-asociar duplicó la liquidación")

            context.delete(kept)
            try context.save()

            #expect(try GroupTransactionBridge.shared.bridgeRemoteSettlements(ids: [settlement.id]) == [settlement.id])
            #expect(try bridgedRows(context, settlementID: settlement.id) > 0,
                    "la liquidación se quedó sin movimiento personal")
            #expect(GroupsDetachedBridgeLedger.isConserved(settlementID: settlement.id.uuidString,
                                                           associatedSub: "sub-mia") == false)
        }
    }

    @Test("el arranque recupera el gasto borrado aunque nadie lo vuelva a editar")
    func boot_revivesWhatNoOneEdits() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let expense = try makeExpense(context, f)
            let settlement = try makeSettlement(context, f)
            try conserveAndReassociate(context, f, expenses: [expense], settlements: [settlement])
            for tx in try conserved(context, f) { context.delete(tx) }
            try context.save()

            // Control: sin el paso del arranque, el retome no tiene nada que hacer.
            GroupsPendingBridgeResume.resumeIfNeeded(context: context)
            #expect(try bridgedRows(context, expenseID: expense.id) == 0, "el fixture ya re-puentea sin el arranque")

            let revived = GroupsDetachedBridgeLedger.reviveVanished(context: context)
            #expect(revived.expenses == 1 && revived.settlements == 1)
            #expect(GroupsPendingBridgeIntent.pending.expenseIDs == [expense.id], "no se pidió el gasto")
            #expect(GroupsPendingBridgeIntent.pending.settlementIDs == [settlement.id], "no se pidió la liquidación")
            #expect(GroupsDetachedBridgeLedger.read() == nil, "el libro sigue afirmando lo que ya no es cierto")

            GroupsPendingBridgeResume.resumeIfNeeded(context: context)
            #expect(try bridgedRows(context, expenseID: expense.id) > 0, "el gasto no volvió")
            #expect(try bridgedRows(context, settlementID: settlement.id) > 0, "la liquidación no volvió")
            #expect(GroupsPendingBridgeIntent.pending.isEmpty, "todo quedó atendido")
        }
    }

    @Test("el arranque no toca lo que sigue en el Panel")
    func boot_leavesWhatIsStillThere() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let expense = try makeExpense(context, f)
            try conserveAndReassociate(context, f, expenses: [expense])
            let ledger = try #require(GroupsDetachedBridgeLedger.read(), "el fixture no escribe el libro")

            let revived = GroupsDetachedBridgeLedger.reviveVanished(context: context)
            #expect(revived.expenses == 0 && revived.settlements == 0)
            #expect(GroupsPendingBridgeIntent.pending.isEmpty)
            #expect(GroupsDetachedBridgeLedger.read() == ledger)
        }
    }

    // MARK: - Fallar hacia «atendido»: lo que no se puede afirmar no se recrea

    @Test("dos movimientos idénticos de dos gastos: borrar uno revive solo el suyo")
    func twins_onlyTheDeletedOneRevives() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let first = try makeExpense(context, f)
            let second = try makeExpense(context, f)
            second.date = first.date
            try context.save()
            try conserveAndReassociate(context, f, expenses: [first, second])
            let kept = try conserved(context, f)
            try #require(kept.count == 2)
            try #require(kept[0].date == kept[1].date && kept[0].amount == kept[1].amount && kept[0].note == kept[1].note,
                         "los dos movimientos no son gemelos: el caso no mide la huella")
            let ledger = try #require(GroupsDetachedBridgeLedger.read())
            let firstMovement = try #require(ledger.expenseMovements?[first.id.uuidString]?.first?.id)
            let doomed = try #require(kept.first { $0.persistentModelID == firstMovement })
            context.delete(doomed)
            try context.save()

            let gone = GroupsDetachedBridgeLedger.vanished(associatedSub: "sub-mia", context: context)
            #expect(gone.expenseIDs == [first.id.uuidString],
                    "el gemelo vivo de OTRO gasto tapó el borrado, o el borrado arrastró al gemelo")
        }
    }

    @Test("la misma transacción re-importada con otra identidad sigue contando como presente")
    func reimportedWithAnotherIdentity_stillHolds() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let expense = try makeExpense(context, f)
            try conserveAndReassociate(context, f, expenses: [expense])
            let kept = try #require(try conserved(context, f).first)
            // Lo que deja una purga y re-importación del espejo: la misma fila, otra identidad.
            let reimported = TransactionItem(date: kept.date, amount: kept.amount, currencyCode: kept.currencyCode,
                                             note: kept.note, account: f.cash)
            context.delete(kept)
            context.insert(reimported)
            try context.save()

            #expect(try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id]) == [expense.id])
            #expect(try bridgedRows(context, expenseID: expense.id) == 0, "la re-importación se leyó como un borrado")
            #expect(GroupsDetachedBridgeLedger.isConserved(expenseID: expense.id.uuidString, associatedSub: "sub-mia"))
            #expect(GroupsDetachedBridgeLedger.read()?.expenseMovements?[expense.id.uuidString]?.first?.id
                        == reimported.persistentModelID,
                    "la huella encontró la fila y el libro no tomó su identidad nueva")

            // Y como ya conoce su identidad, borrarla después sí se ve.
            context.delete(reimported)
            try context.save()
            try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id])
            #expect(try bridgedRows(context, expenseID: expense.id) > 0, "tras re-anclar, el borrado no se vio")
        }
    }

    @Test("el movimiento conservado EDITADO sigue frenando: lo encuentra su identidad, y la huella se pone al día")
    func editedMovement_stillHolds_andTheFingerprintFollows() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let expense = try makeExpense(context, f)
            try conserveAndReassociate(context, f, expenses: [expense])
            let kept = try #require(try conserved(context, f).first)
            // Lo que la conservación le permite: es un movimiento personal normal.
            kept.amount = -12.5
            kept.note = "Cena (mi parte, corregida)"
            kept.date = kept.date.addingTimeInterval(-86_400 * 3)
            try context.save()

            #expect(try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id]) == [expense.id])
            #expect(try bridgedRows(context, expenseID: expense.id) == 0, "editar el movimiento se leyó como borrarlo")
            let movement = try #require(GroupsDetachedBridgeLedger.read()?.expenseMovements?[expense.id.uuidString]?.first)
            #expect(movement.amount == -12.5 && movement.note == "Cena (mi parte, corregida)" && movement.date == kept.date,
                    "la huella sigue siendo la de antes de editar: una re-importación posterior ya no casaría")
        }
    }

    @Test("la fila de un store RECREADO que vuelve con la re-importación sigue frenando, y queda anclada al store nuevo")
    func recreatedStore_reimportedRow_holdsAndReanchors() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let oldDir = try freshDir()
        defer { cleanup(oldDir) }
        let context = try makeContext(dir)
        let oldStore = try makeContext(oldDir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let expense = try makeExpense(context, f)
            let date = Date(timeIntervalSinceReferenceDate: 800_000_000)
            // El movimiento conservado tal cual lo apuntó el store de antes…
            let before = TransactionItem(date: date, amount: -30, currencyCode: "USD", note: "Cena")
            oldStore.insert(before)
            try oldStore.save()
            // …y la misma fila, re-importada en el store de ahora con otra identidad.
            let back = TransactionItem(date: date, amount: -30, currencyCode: "USD", note: "Cena", account: f.cash)
            context.insert(back)
            try context.save()
            try associate("sub-mia")
            GroupsDetachedBridgeLedger.record(sub: "sub-mia", expenseIDs: [expense.id.uuidString], settlementIDs: [],
                                              expenseMovements: [expense.id.uuidString: [.init(before)]])

            #expect(try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id]) == [expense.id])
            #expect(try bridgedRows(context, expenseID: expense.id) == 0)
            #expect(GroupsDetachedBridgeLedger.read()?.expenseMovements?[expense.id.uuidString]?.first?.id
                        == back.persistentModelID,
                    "el libro sigue con la identidad del store viejo: borrarla después no se vería nunca")

            context.delete(back)
            try context.save()
            try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id])
            #expect(try bridgedRows(context, expenseID: expense.id) > 0, "tras recrear el store, el borrado no se vio")
        }
    }

    @Test("un store personal sin ninguna transacción no se lee como un borrado")
    func emptyPersonalStore_stillHolds() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let expense = try makeExpense(context, f)
            try conserveAndReassociate(context, f, expenses: [expense])
            // Lo que deja la purga del espejo antes de re-importar: ni una transacción.
            for tx in try context.fetch(FetchDescriptor<TransactionItem>()) { context.delete(tx) }
            try context.save()

            #expect(try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id]) == [expense.id])
            #expect(try bridgedRows(context, expenseID: expense.id) == 0, "el store vacío se leyó como un borrado")
            let revived = GroupsDetachedBridgeLedger.reviveVanished(context: context)
            #expect(revived.expenses == 0 && revived.settlements == 0)
        }
    }

    @Test("con un desasociar a medias de esa cuenta, el libro sigue frenando aunque el movimiento no esté")
    func pendingDetachPurge_stillHolds() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let expense = try makeExpense(context, f)
            try conserveAndReassociate(context, f, expenses: [expense])
            for tx in try conserved(context, f) { context.delete(tx) }
            try context.save()
            // El borrado local del desasociar no entró: las filas del grupo siguen y se vacían después, sin
            // volver a soltar el puente. Lo que el puente creara ahora quedaría atrapado.
            GroupsDetachPendingPurge.arm(sub: "sub-mia")

            #expect(try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id]) == [expense.id])
            #expect(try bridgedRows(context, expenseID: expense.id) == 0,
                    "el puente creó sobre una zona que el desasociar a medias va a vaciar")
            let revived = GroupsDetachedBridgeLedger.reviveVanished(context: context)
            #expect(revived.expenses == 0, "el arranque pidió un gasto de una zona que se va a vaciar")
            #expect(GroupsDetachedBridgeLedger.isConserved(expenseID: expense.id.uuidString, associatedSub: "sub-mia"))

            // Control: terminado el desasociar a medias (y re-asociada la cuenta), el borrado sí se ve.
            GroupsDetachPendingPurge.clear()
            try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id])
            #expect(try bridgedRows(context, expenseID: expense.id) > 0, "el control no recrea: el caso no mide la marca")
        }
    }

    @Test("una huella con la nota vacía casa con otra nota vacía")
    func nilNote_fingerprintMatches() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let date = Date(timeIntervalSinceReferenceDate: 800_000_000)
        context.insert(TransactionItem(date: .distantPast, amount: -3, currencyCode: "USD", note: "Café"))
        let original = TransactionItem(date: date, amount: -40, currencyCode: "USD", note: nil)
        context.insert(original)
        try context.save()
        let movement = GroupsDetachedBridgeLedger.Movement(original)
        context.delete(original)
        context.insert(TransactionItem(date: date, amount: -40, currencyCode: "USD", note: nil))
        try context.save()
        let storeID = GroupsDetachedBridgeLedger.personalStoreIdentifier(context: context)
        try #require(storeID != nil)

        #expect(GroupsDetachedBridgeLedger.presence(of: [movement], storeID: storeID, context: context).presence == .present,
                "una nota nula no casa con otra nula: la re-importación se leería como un borrado")
        #expect(GroupsDetachedBridgeLedger.presence(of: [movement], storeID: "otro", context: context).presence == .present,
                "con la identidad de otro store, la huella debería encontrarla igual")
    }

    @Test("una identidad de OTRO store (el personal se recreó) no se da por borrada")
    func identityFromAnotherStore_stillHolds() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let otherDir = try freshDir()
        defer { cleanup(otherDir) }
        let context = try makeContext(dir)
        let other = try makeContext(otherDir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let expense = try makeExpense(context, f)
            let foreign = TransactionItem(date: .distantPast, amount: -1, currencyCode: "EUR", note: "otro store")
            other.insert(foreign)
            try other.save()
            try #require(foreign.persistentModelID.storeIdentifier != GroupsDetachedBridgeLedger.personalStoreIdentifier(context: context))
            try associate("sub-mia")
            GroupsDetachedBridgeLedger.record(sub: "sub-mia", expenseIDs: [expense.id.uuidString], settlementIDs: [],
                                              expenseMovements: [expense.id.uuidString: [.init(foreign)]])

            #expect(try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id]) == [expense.id])
            #expect(try bridgedRows(context, expenseID: expense.id) == 0, "una identidad ajena se leyó como un borrado")
            #expect(GroupsDetachedBridgeLedger.isConserved(expenseID: expense.id.uuidString, associatedSub: "sub-mia"))
        }
    }

    @Test("un libro sin identidades (anterior a este cambio) sigue frenando como antes")
    func ledgerWithoutMovements_stillHolds() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let expense = try makeExpense(context, f)
            try associate("sub-mia")
            // El formato del libro antes del 2026-10-01, escrito a mano: sin los mapas de movimientos.
            let legacy = #"{"sub":"sub-mia","expenseIDs":["\#(expense.id.uuidString)"],"settlementIDs":[]}"#
            UserDefaults.standard.set(Data(legacy.utf8), forKey: GroupsDetachedBridgeLedger.userDefaultsKey)
            try #require(GroupsDetachedBridgeLedger.read()?.expenseMovements == nil, "el libro viejo no se lee")

            #expect(try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id]) == [expense.id])
            #expect(try bridgedRows(context, expenseID: expense.id) == 0)
            let revived = GroupsDetachedBridgeLedger.reviveVanished(context: context)
            #expect(revived.expenses == 0 && revived.settlements == 0, "un libro sin identidades se dio por borrado")
        }
    }

    @Test("un gasto conservado como BORRADOR no lleva identidad: no se puede comprobar")
    func draftConserved_hasNoMovement() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let withTx = try makeExpense(context, f)
            let withDraft = try makeExpense(context, f, description: "Taxi")
            try GroupTransactionBridge.shared.bridgeExpense(withTx, in: f.group, accountForCurrentUser: f.cash)
            let draft = InboxDraft(note: "Taxi", amount: -20, date: .now, sourceType: .groupExpense,
                                   needsUserInput: [DraftInputRequirement.account],
                                   splitExpenseID: withDraft.id.uuidString, splitGroupZoneID: f.group.cloudKitZoneID)
            context.insert(draft)
            try context.save()
            try #require(GroupsAssociationDetach.detachBridge(context: context, choice: .keep, associatedSub: "sub-mia") != nil)

            let ledger = try #require(GroupsDetachedBridgeLedger.read())
            #expect(ledger.expenseIDs == [withTx.id.uuidString, withDraft.id.uuidString])
            #expect(ledger.expenseMovements?[withTx.id.uuidString]?.isEmpty == false, "el movimiento real no se anotó")
            #expect(ledger.expenseMovements?[withDraft.id.uuidString] == nil,
                    "un borrador conservado lleva identidad: aprobarlo lo haría parecer borrado")
        }
    }

    /// El borrador que ningún plan nombra (`groupScheduledExpense`) se convierte a manual aunque su gasto TAMBIÉN deje una
    /// transacción. Si el libro anotara la transacción, borrarla haría recrear el gasto con el borrador todavía en el
    /// Inbox: aprobado, el gasto contaría dos veces.
    @Test("un gasto que conserva transacción Y borrador no lleva identidad, y borrar la transacción no lo recrea")
    func expenseWithTransactionAndDraft_hasNoMovement() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let expense = try makeExpense(context, f)
            try GroupTransactionBridge.shared.bridgeExpense(expense, in: f.group, accountForCurrentUser: f.cash)
            context.insert(InboxDraft(note: "Cena", amount: -30, date: .now, sourceType: .groupScheduledExpense,
                                      splitExpenseID: expense.id.uuidString, splitGroupZoneID: f.group.cloudKitZoneID))
            try context.save()
            try #require(GroupsAssociationDetach.detachBridge(context: context, choice: .keep, associatedSub: "sub-mia") != nil)
            try associate("sub-mia")
            let ledger = try #require(GroupsDetachedBridgeLedger.read())
            try #require(ledger.expenseIDs.contains(expense.id.uuidString))
            #expect(ledger.expenseMovements?[expense.id.uuidString] == nil,
                    "el gasto con un borrador conservado lleva identidad: borrar la transacción lo recrearía junto al borrador")

            for tx in try conserved(context, f) { context.delete(tx) }
            try context.save()
            try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [expense.id])
            #expect(try bridgedRows(context, expenseID: expense.id) == 0, "recreó el gasto con su borrador todavía en el Inbox")
        }
    }

    @Test("el libro se lee y se escribe con sus identidades, y retirar una entrada deja el resto")
    func ledger_roundTripAndRetire() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let defaults = makeIsolatedDefaults()
        let tx = TransactionItem(date: .now, amount: -5, currencyCode: "USD", note: "x")
        context.insert(tx)
        try context.save()
        GroupsDetachedBridgeLedger.record(sub: "s", expenseIDs: ["a", "b"], settlementIDs: ["c"],
                                          expenseMovements: ["a": [.init(tx)], "zz": [.init(tx)]],
                                          settlementMovements: ["c": [.init(tx)]], defaults: defaults)
        let stored = try #require(GroupsDetachedBridgeLedger.read(defaults: defaults))
        #expect(stored.expenseMovements?["a"]?.first?.id == tx.persistentModelID, "la identidad no sobrevive al JSON")
        #expect(stored.expenseMovements?["zz"] == nil, "se anotó un movimiento de un gasto que no está en el libro")

        GroupsDetachedBridgeLedger.retire(expenseIDs: ["a"], settlementIDs: [], defaults: defaults)
        let after = try #require(GroupsDetachedBridgeLedger.read(defaults: defaults))
        #expect(after.expenseIDs == ["b"])
        #expect(after.expenseMovements?["a"] == nil)
        #expect(after.settlementIDs == ["c"] && after.settlementMovements?["c"] != nil)

        GroupsDetachedBridgeLedger.retire(expenseIDs: ["b"], settlementIDs: ["c"], defaults: defaults)
        #expect(GroupsDetachedBridgeLedger.read(defaults: defaults) == nil, "un libro vacío no se borra")
    }

    @Test("unos movimientos que no se dejan leer no se llevan el libro: los gastos siguen frenando")
    func unreadableMovements_keepTheLedger() throws {
        let defaults = makeIsolatedDefaults()
        let json = #"{"sub":"s","expenseIDs":["a"],"settlementIDs":["c"],"expenseMovements":{"a":[{"id":42}]},"settlementMovements":"x"}"#
        defaults.set(Data(json.utf8), forKey: GroupsDetachedBridgeLedger.userDefaultsKey)
        let stored = try #require(GroupsDetachedBridgeLedger.read(defaults: defaults),
                                  "un fallo en los movimientos tiró el libro entero: re-asociar duplicaría todo")
        #expect(stored.expenseIDs == ["a"] && stored.settlementIDs == ["c"])
        #expect(stored.expenseMovements == nil && stored.settlementMovements == nil)
        #expect(GroupsDetachedBridgeLedger.isConserved(expenseID: "a", associatedSub: "s", defaults: defaults))
    }
}

// MARK: - El cableado del arranque

@Suite("Libro de conservados · el arranque pide lo que ya no está (source-scan)")
struct GroupsDetachedLedgerBootWiringTests {

    /// `AppBootstrapper` sin comentarios, sin indentación y en una línea: un `contains` sobre el fichero crudo
    /// depende de dónde caiga el salto de línea.
    private static func flattenedBootstrapper() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("Yala/App/AppBootstrapper.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        return source
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
    }

    /// Lo que el test de comportamiento no ve: que el arranque llama a `reviveVanished` JUSTO antes del retome de
    /// la intención —si va después, lo que arma espera un arranque entero— y DETRÁS de los dos gates de
    /// `retryPendingBridges` (store listo y dominio abierto), porque el retome guarda el `mainContext`.
    @Test("retryPendingBridges revisa el libro justo antes del retome, detrás de sus gates")
    func reviveRunsRightBeforeTheResume() throws {
        let src = try Self.flattenedBootstrapper()
        let function = try #require(src.range(of: "func retryPendingBridges(context: ModelContext) async {"),
                                    "no encuentro retryPendingBridges")
        let body = src[function.upperBound...]
        let pair = try #require(body.range(of: """
            GroupsDetachedBridgeLedger.reviveVanished(context: context) GroupsPendingBridgeResume.resumeIfNeeded(context: context)
            """), "el arranque ya no revisa el libro justo antes del retome")
        let storeGate = try #require(body.range(of: "guard await awaitPersonalStoreReady() else {"))
        let domainGate = try #require(body.range(of: "guard GroupTransactionBridge.isDomainOpenForBridge() else {"))
        #expect(storeGate.upperBound < pair.lowerBound && domainGate.upperBound < pair.lowerBound,
                "la revisión del libro corre antes de los gates de retryPendingBridges")
        #expect(src.components(separatedBy: "GroupsDetachedBridgeLedger.reviveVanished(").count == 2,
                "hay más de una llamada a reviveVanished en el arranque")
    }
}
