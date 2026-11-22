//
//  GruposGuardadoFallidoTests.swift
//  YalaTests
//
//  Encargo «Grupos: un guardado que falla no duplica gastos, no deja pagos a medias y no rompe el préstamo»
//  (2026-11-22). Cuatro tickets, un caso que falla sin su arreglo por cada uno:
//
//  1. `group-expense-retry-after-a-failed-save-duplicates-the-expense`: el gasto y sus repartos se quedaban pendientes
//     de insertar tras un guardado fallido, y el reintento escribía dos.
//  2. `confirming-a-settlement-whose-save-fails-leaves-it-confirmed-without-bridge`: la marca de confirmado se quedaba
//     en el contexto y cualquier guardado posterior la escribía sin pasar por el puente.
//  3. `deleting-a-scheduled-payment-deletes-group-legs-without-unbridging`: borrar el pago planificado se llevaba el
//     registro que es la pata real de un gasto de grupo.
//  4. `groups-opening-balance-edit-can-duplicate-a-pair`: editar un saldo inicial hacia una pareja y moneda que ya
//     tenían otro dejaba dos.
//
//  Harness ON-DISK con los 3 stores (molde de `SettlementRetryDuplicateTests`): servicios singleton ⇒ `.serialized`,
//  y todo se suelta en `defer`. Lo que se afirma se lee de DISCO, con un contexto nuevo.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos: un guardado que falla no duplica ni deja nada a medias", .serialized, .privateSessionCellPinned)
@MainActor
struct GruposGuardadoFallidoTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GruposGuardadoFallido-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("GruposGuardadoFallidoTests: no se pudo crear \(dir.path): \(error)")
        }
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GGF-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "GGF-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "GGF-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg
        )
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private struct Fixture {
        let group: SplitGroup
        let me: SplitMember
        let ana: SplitMember
        let luis: SplitMember
    }

    /// Grupo vivo (no congelado) del que soy dueño, con Ana y Luis.
    private func makeFixture(_ context: ModelContext) throws -> Fixture {
        let group = SplitGroup(name: "Viaje", currencyCode: "PEN", isOwner: true)
        context.insert(group)
        let me = SplitMember(
            groupZoneID: group.cloudKitZoneID, displayName: "Yo", role: "admin",
            isGroupOwner: true, isCurrentUser: true
        )
        context.insert(me)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(ana)
        let luis = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Luis")
        context.insert(luis)
        try context.save()
        return Fixture(group: group, me: me, ana: ana, luis: luis)
    }

    private func withServices(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupExpenseService.shared.setContext(context)
        GroupService.shared.setContext(context)
        GroupTransactionBridge.shared.setContext(context)
        EntityDeletionService.shared.setContext(context)
        // La sesión privada la enciende y la deja como estaba `.privateSessionCellPinned`: asignar
        // `SessionState.shared.hasPrivateSession` escribiría la marca en `UserDefaults.standard`.
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            GroupExpenseService._testFailNextExpenseSave = false
            GroupExpenseService._testFailNextConfirmSave = false
            GroupExpenseService.shared._testResetContext()
            GroupService.shared._testResetContext()
            GroupTransactionBridge.shared._testClearContext()
            EntityDeletionService.shared.setContext(nil)
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        }
        try body()
    }

    private let fixedDate = Date(timeIntervalSince1970: 1_793_000_000)

    // MARK: - 1. Reintentar un gasto cuyo guardado falló

    private func addDinner(_ f: Fixture) throws {
        try GroupExpenseService.shared.createExpense(
            in: f.group,
            amount: 90,
            currencyCode: "PEN",
            description: "Cena",
            note: nil,
            date: fixedDate,
            paidByMemberID: f.ana.id.uuidString,
            splitType: "equal",
            subcategoryName: nil,
            shares: [(f.me.id.uuidString, 45), (f.ana.id.uuidString, 45)]
        )
    }

    @Test("Si el guardado de un gasto falla y se reintenta, queda UN gasto con sus dos repartos")
    func expenseRetryAfterAFailedSave_leavesOneExpense() throws {
        let dir = freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withServices(context) {
            GroupExpenseService._testFailNextExpenseSave = true
            #expect(throws: GroupExpenseServiceError.self) { try addDinner(f) }
            // Lo que hace el formulario al tocar otra vez «Guardar».
            try addDinner(f)
        }

        let fresh = ModelContext(context.container)
        let zoneID = f.group.cloudKitZoneID
        let expenses = try fresh.fetch(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zoneID }))
        #expect(expenses.count == 1)
        let shares = try fresh.fetch(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == zoneID }))
        #expect(shares.count == 2)
        #expect(Set(shares.map(\.expenseID)) == Set(expenses.map(\.id)))
    }

    @Test("Un guardado fallido de un gasto no deja nada que otro guardado ajeno escriba después")
    func expenseFailedSave_leavesNothingForALaterSave() throws {
        let dir = freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        withServices(context) {
            GroupExpenseService._testFailNextExpenseSave = true
            #expect(throws: GroupExpenseServiceError.self) { try addDinner(f) }
        }
        f.group.name = "Viaje a Cusco"
        try context.save()

        let fresh = ModelContext(context.container)
        let zoneID = f.group.cloudKitZoneID
        #expect(try fresh.fetchCount(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zoneID })) == 0)
        #expect(try fresh.fetchCount(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == zoneID })) == 0)
    }

    // MARK: - 2. Confirmar un pago cuyo guardado falla

    private func recordPendingPayment(_ f: Fixture) throws -> SplitSettlement {
        // Ana me pagó y lo apuntó otro: nace pendiente y yo lo confirmo desde el detalle del grupo.
        try GroupExpenseService.shared.createSettlement(
            in: f.group,
            fromMemberID: f.ana.id.uuidString,
            toMemberID: f.me.id.uuidString,
            amount: 30,
            currencyCode: "PEN",
            note: nil,
            date: fixedDate,
            confirmed: false
        )
    }

    @Test("Un pago cuya confirmación falla sigue pendiente en disco aunque después se guarde otra cosa")
    func confirmFailedSave_doesNotLeaveTheSettlementConfirmed() throws {
        let dir = freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        var settlementID = UUID()
        try withServices(context) {
            let settlement = try recordPendingPayment(f)
            settlementID = settlement.id
            GroupExpenseService._testFailNextConfirmSave = true
            #expect(throws: GroupExpenseServiceError.self) {
                try GroupExpenseService.shared.confirmSettlement(settlement, in: f.group)
            }
            #expect(settlement.isConfirmed == false)
        }
        // Un guardado de cualquier otra cosa después del fallo.
        f.group.name = "Viaje a Cusco"
        try context.save()

        let fresh = ModelContext(context.container)
        let id = settlementID
        let stored = try fresh.fetch(FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.id == id }))
        #expect(stored.count == 1)
        #expect(stored.first?.isConfirmed == false)
    }

    @Test("Tras un fallo, reintentar la confirmación la deja confirmada en disco")
    func confirmRetryAfterAFailedSave_confirms() throws {
        let dir = freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        var settlementID = UUID()
        try withServices(context) {
            let settlement = try recordPendingPayment(f)
            settlementID = settlement.id
            GroupExpenseService._testFailNextConfirmSave = true
            #expect(throws: GroupExpenseServiceError.self) {
                try GroupExpenseService.shared.confirmSettlement(settlement, in: f.group)
            }
            try GroupExpenseService.shared.confirmSettlement(settlement, in: f.group)
        }

        let fresh = ModelContext(context.container)
        let id = settlementID
        let stored = try fresh.fetch(FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.id == id }))
        #expect(stored.first?.isConfirmed == true)
    }

    // MARK: - 3. Borrar un pago planificado con la pata real de un gasto de grupo

    @Test("Borrar un pago planificado conserva el registro de este mes que es pata de un gasto de grupo, y borra el resto")
    func deletingAScheduledPayment_keepsTheGroupLeg() throws {
        let dir = freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)

        let payment = ScheduledPayment(name: "Internet", amount: 80, currencyCode: "PEN", nextDueDate: fixedDate)
        context.insert(payment)
        let paymentID = payment.id.uuidString
        let monthStart = Calendar.current.startOfMonth(for: Date.now)

        // Pagado este mes y pasado luego a un gasto de grupo («Convertir a gasto compartido»): es su pata real.
        let groupLeg = TransactionItem(date: monthStart, amount: -80, currencyCode: "PEN", note: "Internet")
        groupLeg.scheduledPaymentID = paymentID
        let expenseID = UUID().uuidString
        groupLeg.splitExpenseID = expenseID
        groupLeg.splitGroupZoneID = "zona-viaje"
        context.insert(groupLeg)
        // Un registro planificado del mismo mes que no es de ningún grupo: se borra como siempre.
        let plain = TransactionItem(date: monthStart, amount: -80, currencyCode: "PEN", note: "Internet")
        plain.scheduledPaymentID = paymentID
        context.insert(plain)
        try context.save()
        let groupLegID = groupLeg.persistentModelID

        try withServices(context) {
            try EntityDeletionService.shared.deleteScheduledPayment(payment)
        }

        let fresh = ModelContext(context.container)
        let remaining = try fresh.fetch(FetchDescriptor<TransactionItem>())
        #expect(remaining.count == 1)
        let kept = try #require(remaining.first)
        #expect(kept.persistentModelID == groupLegID)
        #expect(kept.splitExpenseID == expenseID)
        #expect(kept.scheduledPaymentID == nil)
        #expect(try fresh.fetchCount(FetchDescriptor<ScheduledPayment>()) == 0)
    }

    // MARK: - 4. Editar un saldo inicial hacia una pareja que ya tiene otro

    private func openingBalances(_ context: ModelContext, _ f: Fixture) throws -> [SplitExpense] {
        let fresh = ModelContext(context.container)
        let zoneID = f.group.cloudKitZoneID
        return try fresh.fetch(FetchDescriptor<SplitExpense>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.isOpeningBalance == true }
        ))
    }

    private func debtor(of expense: SplitExpense, in context: ModelContext) throws -> String? {
        let fresh = ModelContext(context.container)
        let id = expense.id
        return try fresh.fetch(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.expenseID == id })).first?.memberID
    }

    /// «Ana debe a Yo 100 PEN» y «Luis debe a Yo 50 PEN».
    private func seedTwoPairs(_ f: Fixture) throws -> (ana: SplitExpense, luis: SplitExpense) {
        let ana = try GroupExpenseService.shared.setOpeningBalance(
            in: f.group, debtorMemberID: f.ana.id.uuidString, creditorMemberID: f.me.id.uuidString,
            amount: 100, currencyCode: "PEN", date: fixedDate
        )
        let luis = try GroupExpenseService.shared.setOpeningBalance(
            in: f.group, debtorMemberID: f.luis.id.uuidString, creditorMemberID: f.me.id.uuidString,
            amount: 50, currencyCode: "PEN", date: fixedDate
        )
        return (ana, luis)
    }

    @Test("Editar un saldo hacia una pareja y moneda que ya tienen otro, sin confirmar, no guarda nada")
    func editingIntoATakenPair_withoutConfirmation_changesNothing() throws {
        let dir = freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withServices(context) {
            let seeded = try seedTwoPairs(f)
            #expect(throws: GroupExpenseServiceError.self) {
                try GroupExpenseService.shared.updateOpeningBalance(
                    seeded.luis, in: f.group,
                    debtorMemberID: f.ana.id.uuidString, creditorMemberID: f.me.id.uuidString,
                    amount: 50, currencyCode: "PEN", date: fixedDate
                )
            }
        }

        let stored = try openingBalances(context, f)
        #expect(stored.count == 2)
        let debtors = Set(try stored.compactMap { try debtor(of: $0, in: context) })
        #expect(debtors == [f.ana.id.uuidString, f.luis.id.uuidString])
    }

    @Test("Al editar, el formulario sabe qué saldo reemplazaría; confirmado, queda uno solo con lo editado")
    func editingIntoATakenPair_confirmed_leavesOne() throws {
        let dir = freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        var luisID = UUID()
        try withServices(context) {
            let seeded = try seedTwoPairs(f)
            luisID = seeded.luis.id
            let wouldReplace = try GroupExpenseService.shared.openingBalancesThatEditingWouldReplace(
                seeded.luis, in: f.group,
                debtorMemberID: f.ana.id.uuidString, creditorMemberID: f.me.id.uuidString, currencyCode: "PEN"
            )
            #expect(wouldReplace.map(\.id) == [seeded.ana.id])
            // Sin cambiar la pareja no hay nada que preguntar.
            let untouched = try GroupExpenseService.shared.openingBalancesThatEditingWouldReplace(
                seeded.luis, in: f.group,
                debtorMemberID: f.luis.id.uuidString, creditorMemberID: f.me.id.uuidString, currencyCode: "PEN"
            )
            #expect(untouched.isEmpty)

            try GroupExpenseService.shared.updateOpeningBalance(
                seeded.luis, in: f.group,
                debtorMemberID: f.ana.id.uuidString, creditorMemberID: f.me.id.uuidString,
                amount: 70, currencyCode: "PEN", date: fixedDate,
                replacing: wouldReplace
            )
        }

        let stored = try openingBalances(context, f)
        #expect(stored.count == 1)
        let only = try #require(stored.first)
        #expect(only.id == luisID)
        #expect(only.amount == 70)
        #expect(try debtor(of: only, in: context) == f.ana.id.uuidString)
    }

    @Test("La misma pareja en otra moneda no cuenta como ocupada")
    func editingIntoTheSamePairInAnotherCurrency_isNotTaken() throws {
        let dir = freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withServices(context) {
            let seeded = try seedTwoPairs(f)
            let wouldReplace = try GroupExpenseService.shared.openingBalancesThatEditingWouldReplace(
                seeded.luis, in: f.group,
                debtorMemberID: f.ana.id.uuidString, creditorMemberID: f.me.id.uuidString, currencyCode: "USD"
            )
            #expect(wouldReplace.isEmpty)
            try GroupExpenseService.shared.updateOpeningBalance(
                seeded.luis, in: f.group,
                debtorMemberID: f.ana.id.uuidString, creditorMemberID: f.me.id.uuidString,
                amount: 20, currencyCode: "USD", date: fixedDate
            )
        }

        #expect(try openingBalances(context, f).count == 2)
    }

    @Test("Una pareja con dos saldos de antes de la regla queda con uno al poner su saldo")
    func addingOverLegacyDuplicates_leavesOne() throws {
        let dir = freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)

        try withServices(context) {
            // Dos saldos Ana–Yo en PEN, como los dejaba la app antes del 2026-10-28 (sin la regla del alta).
            for amount in [100.0, 40.0] {
                try GroupExpenseService.shared.createExpense(
                    in: f.group, amount: amount, currencyCode: "PEN",
                    description: L10n.Groups.OpeningBalance.entryDescription, note: nil, date: fixedDate,
                    paidByMemberID: f.me.id.uuidString, splitType: "exact", subcategoryName: nil,
                    shares: [(f.ana.id.uuidString, amount)], isOpeningBalance: true
                )
            }
            #expect(try openingBalances(context, f).count == 2)

            try GroupExpenseService.shared.setOpeningBalance(
                in: f.group, debtorMemberID: f.ana.id.uuidString, creditorMemberID: f.me.id.uuidString,
                amount: 120, currencyCode: "PEN", date: fixedDate
            )
        }

        let stored = try openingBalances(context, f)
        #expect(stored.count == 1)
        #expect(stored.first?.amount == 120)
    }
}
