//
//  GroupExpenseLinkDraftTests.swift
//  YalaTests
//
//  UX 2.2 · L13-15 (decisión B de Jürgen): «¿Ya lo apuntaste?» enlaza un movimiento ya apuntado con el gasto de grupo de
//  un borrador. Lo que no puede pasar, y es lo que fijan estos casos: que el gasto quede contado dos veces, que enlazar
//  cambie el importe (o la cuenta, la nota) del movimiento, o que se enlace algo que no es el mismo gasto.
//
//  Y L13-9: lo que falta para guardar un gasto de grupo, en el orden en que se ve el formulario.
//

import Testing
import Foundation
import SwiftData
@testable import Yala

// MARK: - L13-15 · Lógica pura

@Suite("L13-15 · qué movimiento es «el mismo gasto»")
struct GroupExpenseLinkCandidateLogicTests {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return c
    }()

    private var expenseDate: Date { Date(timeIntervalSince1970: 1_760_000_000) }

    private func movement(
        date: Date? = nil, amount: Double = -90, currency: String = "USD", groupPointer: Bool = false,
        transfer: Bool = false, adjustment: Bool = false, realAccount: Bool = true, paymentRecord: Bool = false,
        conserved: Bool = false
    ) -> GroupExpenseLinkCandidateLogic.Movement {
        .init(date: date ?? expenseDate, amount: amount, currencyCode: currency, hasGroupPointer: groupPointer,
              isTransfer: transfer, isBalanceAdjustment: adjustment, isOnRealAccount: realAccount,
              isGroupPaymentRecord: paymentRecord, isConservedFromDetach: conserved)
    }

    private func isCandidate(_ m: GroupExpenseLinkCandidateLogic.Movement) -> Bool {
        GroupExpenseLinkCandidateLogic.isCandidate(
            m, expenseTotal: 90, expenseCurrency: "USD", expenseDate: expenseDate, calendar: calendar)
    }

    @Test func sameDayCurrencyAndAmount_isACandidate() {
        #expect(isCandidate(movement()))
        // Otra hora del mismo día también.
        #expect(isCandidate(movement(date: calendar.startOfDay(for: expenseDate))))
    }

    @Test func anotherAmountDayOrCurrency_isNot() {
        // Con otro importe el puente le reescribiría el suyo: no se ofrece.
        #expect(!isCandidate(movement(amount: -80)))
        #expect(!isCandidate(movement(amount: -90.01)))
        // Un ingreso del mismo importe no es este gasto.
        #expect(!isCandidate(movement(amount: 90)))
        #expect(!isCandidate(movement(currency: "PEN")))
        let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: expenseDate))!
        #expect(!isCandidate(movement(date: nextDay)))
    }

    @Test func groupLegsTransfersAdjustmentsAndPaymentRecords_areNever() {
        #expect(!isCandidate(movement(groupPointer: true)))
        #expect(!isCandidate(movement(transfer: true)))
        #expect(!isCandidate(movement(adjustment: true)))
        #expect(!isCandidate(movement(realAccount: false)))
        #expect(!isCandidate(movement(paymentRecord: true)))
        // Lo que dejó OTRO gasto al desasociar: enlazarlo dejaría ese otro contado cero veces.
        #expect(!isCandidate(movement(conserved: true)))
    }
}

// MARK: - L13-9 · Lógica pura

@Suite("L13-9 · lo que falta para guardar un gasto de grupo")
struct GroupExpenseMissingFieldLogicTests {

    private func first(
        description: Bool = true, amount: Bool = true, payer: Bool = true, participants: Bool = true,
        balanced: Bool = true, accountRequired: Bool = false, accountOK: Bool = false
    ) -> GroupExpenseMissingField? {
        GroupExpenseMissingFieldLogic.firstMissing(
            descriptionValid: description, amountValid: amount, payerValid: payer, hasParticipants: participants,
            sharesBalanced: balanced, accountRequired: accountRequired, accountCompatible: accountOK)
    }

    @Test func nothingMissing_isNil() {
        #expect(first() == nil)
        #expect(first(accountRequired: true, accountOK: true) == nil)
    }

    @Test func eachMissingField_isReported() {
        #expect(first(description: false) == .description)
        #expect(first(amount: false) == .amount)
        #expect(first(payer: false) == .payer)
        #expect(first(participants: false) == .participants)
        #expect(first(balanced: false) == .split)
        #expect(first(accountRequired: true, accountOK: false) == .account)
    }

    /// En el orden del formulario, de arriba abajo: se marca lo primero que la persona ve.
    @Test func theFirstOneFromTheTop_wins() {
        #expect(first(description: false, amount: false, accountRequired: true) == .description)
        #expect(first(amount: false, balanced: false, accountRequired: true) == .amount)
        #expect(first(balanced: false, accountRequired: true) == .split)
    }
}

// MARK: - L13-15 · Contra el bridge real

@Suite("L13-15 · enlazar un movimiento ya apuntado, contra el bridge real", .serialized, .wipeAppGroupMirrorIsolated)
@MainActor
struct GroupExpenseLinkDraftBehaviourTests {

    // Infra: el harness de `GroupsBridgeRestoreConvergenceBehaviourTests` (tres stores en disco, `cloudKitDatabase: .none`).

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupLink-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            #if DEBUG
            print("GroupExpenseLinkDraftTests: cleanup: \(error)")
            #endif
        }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration(
            "GLD-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "GLD-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "GLD-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private struct Fixture {
        let group: SplitGroup
        let me: SplitMember
        let ana: SplitMember
        let cash: Account
        let expense: SplitExpense
    }

    /// Caso A: pagué yo 90 USD, mi parte 30 y la de Ana 60. Llega por el sync sin cuenta, así que el puente deja el
    /// borrador que pide la cuenta (el de la Bandeja).
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
        let expense = SplitExpense(groupZoneID: group.cloudKitZoneID, amount: 90, currencyCode: "USD",
                                   expenseDescription: "Cena", paidByMemberID: me.id.uuidString)
        context.insert(expense)
        context.insert(SplitShare(expenseID: expense.id, memberID: me.id.uuidString, amount: 30,
                                  groupZoneID: group.cloudKitZoneID))
        context.insert(SplitShare(expenseID: expense.id, memberID: ana.id.uuidString, amount: 60,
                                  groupZoneID: group.cloudKitZoneID))
        try context.save()
        return Fixture(group: group, me: me, ana: ana, cash: cash, expense: expense)
    }

    /// Lo que la persona ya apuntó a mano: la cena, el mismo día, en su efectivo, con su nota.
    private func insertManual(_ context: ModelContext, _ f: Fixture, amount: Double = -90,
                              dayOffset: Int = 0, note: String = "Cena con Ana") throws -> TransactionItem {
        let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: f.expense.date) ?? f.expense.date
        let tx = TransactionItem(date: date, amount: amount, currencyCode: "USD", note: note, account: f.cash)
        context.insert(tx)
        try context.save()
        return tx
    }

    private func accountDraft(_ context: ModelContext, _ f: Fixture) throws -> InboxDraft {
        let idStr = f.expense.id.uuidString
        let drafts = try context.fetch(FetchDescriptor<InboxDraft>(predicate: #Predicate { $0.splitExpenseID == idStr }))
        return try #require(drafts.first { $0.needsUserInput.contains(DraftInputRequirement.account) },
                            "el puente no dejó el borrador que pide la cuenta")
    }

    private func legs(_ context: ModelContext, _ f: Fixture) throws -> [TransactionItem] {
        let idStr = f.expense.id.uuidString
        return try context.fetch(FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.splitExpenseID == idStr }))
    }

    private func withEnvironment(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupTransactionBridge.shared.setContext(context)
        DraftService.shared.setContext(context)
        let previousPrivateSession = SessionState.shared.hasPrivateSession
        let previousIntentDefaults = GroupsPendingBridgeIntent.defaults
        GroupsPendingBridgeIntent.defaults = makeIsolatedDefaults()
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        SessionState.shared.hasPrivateSession = true
        defer {
            SessionState.shared.hasPrivateSession = previousPrivateSession
            GroupsPendingBridgeIntent.defaults = previousIntentDefaults
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        }
        try body()
    }

    @Test("solo se ofrece el movimiento del mismo día, divisa e importe")
    func candidates_areOnlyTheSameExpense() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [f.expense.id])
            let same = try insertManual(context, f)
            _ = try insertManual(context, f, amount: -80, note: "Otro importe")
            _ = try insertManual(context, f, dayOffset: -2, note: "Otro día")

            let candidates = try DraftService.shared.groupExpenseLinkCandidates(for: try accountDraft(context, f))

            #expect(candidates.map(\.persistentModelID) == [same.persistentModelID])
        }
    }

    @Test("enlazar no duplica el gasto ni le cambia el importe, la cuenta o la nota al movimiento")
    func linking_keepsTheMovement_andCountsTheExpenseOnce() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [f.expense.id])
            let manual = try insertManual(context, f)
            let draft = try accountDraft(context, f)

            let linked = try DraftService.shared.linkGroupExpenseDraft(draft, to: manual)

            #expect(linked.persistentModelID == manual.persistentModelID, "enlazar creó otro movimiento")
            #expect(manual.amount == -90)
            #expect(manual.account?.persistentModelID == f.cash.persistentModelID)
            #expect(manual.note == "Cena con Ana")
            #expect(manual.splitExpenseID == f.expense.id.uuidString)

            let after = try legs(context, f)
            #expect(after.filter { $0.account?.isSystemAccount == false }.count == 1, "hay dos patas reales")
            #expect(after.filter { $0.amount < 0 }.map(\.amount).reduce(0, +) == -90, "el gasto se cuenta dos veces")
            #expect(after.map(\.amount).reduce(0, +) == -30, "mi coste es mi parte (la virtual compensa lo prestado)")

            let idStr = f.expense.id.uuidString
            let pendingAccountDrafts = try context.fetch(FetchDescriptor<InboxDraft>(
                predicate: #Predicate { $0.splitExpenseID == idStr }))
                .filter { $0.needsUserInput.contains(DraftInputRequirement.account) }
            #expect(pendingAccountDrafts.isEmpty, "el borrador sigue en la Bandeja")
        }
    }

    @Test("si el gasto ya tiene su pata real, no se enlaza nada y el movimiento queda como estaba")
    func linking_refusesWhenTheExpenseAlreadyHasItsRealLeg() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [f.expense.id])
            let draft = try accountDraft(context, f)
            // La pata real llegó por otro camino (otro dispositivo) mientras la hoja estaba abierta.
            let other = TransactionItem(date: f.expense.date, amount: -90, currencyCode: "USD", note: "Real",
                                        account: f.cash)
            other.splitExpenseID = f.expense.id.uuidString
            other.splitGroupZoneID = f.expense.groupZoneID
            context.insert(other)
            try context.save()
            let manual = try insertManual(context, f)

            #expect(try DraftService.shared.groupExpenseLinkCandidates(for: draft).isEmpty)
            #expect(throws: DraftServiceError.self) {
                try DraftService.shared.linkGroupExpenseDraft(draft, to: manual)
            }
            #expect(manual.splitExpenseID == nil, "el movimiento quedó enlazado a medias")
        }
    }

    @Test("un gasto que pagó otra persona no ofrece enlazar (el puente borraría el movimiento)")
    func noLinking_whenSomeoneElsePaid() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            try GroupTransactionBridge.shared.bridgeRemoteExpenses(ids: [f.expense.id])
            let draft = try accountDraft(context, f)
            _ = try insertManual(context, f)
            // El pagador cambió después de crear el borrador.
            f.expense.paidByMemberID = f.ana.id.uuidString
            try context.save()

            #expect(try DraftService.shared.groupExpenseLinkCandidates(for: draft).isEmpty)
        }
    }
}
