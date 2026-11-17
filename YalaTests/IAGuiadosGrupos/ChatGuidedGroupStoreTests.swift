//
//  ChatGuidedGroupStoreTests.swift
//  YalaTests
//
//  Guiados de Grupos contra un almacén de verdad (los tres stores en disco, molde de `GroupOpeningBalanceAdminTests`):
//  qué grupos se ofrecen para cada cosa, y que la deuda de antes y el gasto se guardan por las mismas piezas que sus
//  formularios (`setOpeningBalance`, `GroupExpenseViewModel.save`), con el mismo reparto.
//
//  Los servicios de Grupos son singletons compartidos ⇒ suite `.serialized` y su contexto se suelta en el `defer`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Yala IA · guiados de Grupos: lo que se ofrece y lo que se guarda", .serialized)
@MainActor
struct ChatGuidedGroupStoreTests {

    // MARK: - Infra

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatGuidedGroupStore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "CGG-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "CGG-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "CGG-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
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

    /// «Viaje» (soy el dueño) con Ana y Luis.
    private func makeFixture(_ context: ModelContext, iAmOwner: Bool = true, myRole: String = "admin") throws -> Fixture {
        let group = SplitGroup(name: "Viaje", currencyCode: "PEN", isOwner: iAmOwner)
        context.insert(group)
        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", role: myRole,
                             isGroupOwner: iAmOwner, isCurrentUser: true)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana", role: iAmOwner ? "member" : "admin",
                              isGroupOwner: !iAmOwner)
        let luis = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Luis")
        [me, ana, luis].forEach(context.insert)
        try context.save()
        return Fixture(group: group, me: me, ana: ana, luis: luis)
    }

    private func withServices(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupExpenseService.shared.setContext(context)
        GroupService.shared.setContext(context)
        GroupTransactionBridge.shared.setContext(context)
        let previousPrivateSession = SessionState.shared.hasPrivateSession
        // Sin finanzas personales en el teléfono: el gasto no pide cuenta ni crea su reflejo (lo que se prueba es el
        // reparto que guarda el guiado, no el puente, que tiene sus propios tests).
        SessionState.shared.hasPrivateSession = false
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            GroupExpenseService.shared._testResetContext()
            GroupService.shared._testResetContext()
            GroupTransactionBridge.shared._testClearContext()
            SessionState.shared.hasPrivateSession = previousPrivateSession
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        }
        try body()
    }

    /// Un guiado ya en «Revisa antes de crear».
    private func confirmed(_ kind: ChatGuidedKind, _ answers: ChatGuidedAnswers) throws -> ChatGuidedFlowState {
        var answers = answers
        answers.wantsAdvanced = false
        let state = ChatGuidedEngine.start(kind, answers: answers)
        try #require(state.step == .confirm, "El guiado debía estar en la confirmación, está en \(state.step).")
        return state
    }

    // MARK: - Qué grupos se ofrecen

    @Test("Deuda de antes solo donde eres dueño o administrador; gasto en cualquier grupo donde estás")
    func offeredGroups() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let mine = try makeFixture(context)
        let notAdmin = try makeFixture(context, iAmOwner: false, myRole: "member")
        try withServices(context) {
            let options = ChatGuidedDataSource.groupOptions(context)
            let owned = try #require(options.first { $0.id == mine.group.cloudKitZoneID })
            let other = try #require(options.first { $0.id == notAdmin.group.cloudKitZoneID })
            #expect(owned.fits(.groupOpeningBalance))
            #expect(owned.fits(.groupExpense))
            #expect(!other.fits(.groupOpeningBalance), "Un miembro normal no anota deudas de antes.")
            #expect(other.fits(.groupExpense))
            #expect(owned.members.first?.isMe == true, "Tú primero.")
            #expect(owned.members.count == 3)
        }
    }

    // MARK: - Deuda de antes

    @Test("«Luis le debe S/ 120 a Ana»: se guarda como el formulario, con la moneda del grupo")
    func openingBalance_isSaved() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withServices(context) {
            var answers = ChatGuidedAnswers()
            answers.groupZoneID = f.group.cloudKitZoneID
            answers.debtorMemberID = f.luis.id.uuidString
            answers.creditorMemberID = f.ana.id.uuidString
            answers.amount = 120
            answers.currencyCode = "PEN"
            let state = try confirmed(.groupOpeningBalance, answers)
            let created = try ChatGuidedCreator.create(state, data: ChatGuidedData(mainCurrency: "PEN"), context: context,
                                                       budgetAlertsEnabled: false)
            #expect(created.zoneID == f.group.cloudKitZoneID)
            let zoneID = f.group.cloudKitZoneID
            let saved = try context.fetch(FetchDescriptor<SplitExpense>(
                predicate: #Predicate { $0.groupZoneID == zoneID && $0.isOpeningBalance == true }))
            #expect(saved.count == 1)
            let expense = try #require(saved.first)
            #expect(expense.amount == 120)
            #expect(expense.currencyCode == "PEN")
            #expect(expense.paidByMemberID == f.ana.id.uuidString, "A quien le deben es quien «pagó».")
            #expect(GroupExpenseService.shared.openingBalanceDebtorMemberID(of: expense) == f.luis.id.uuidString)

            // Otra vez entre los mismos: la confirmación avisa del reemplazo y se reemplaza (no queda una segunda).
            #expect(ChatGuidedCreator.openingBalanceToReplace(answers, context: context) != nil)
            answers.amount = 80
            _ = try ChatGuidedCreator.create(try confirmed(.groupOpeningBalance, answers),
                                             data: ChatGuidedData(mainCurrency: "PEN"), context: context,
                                             budgetAlertsEnabled: false)
            let after = try context.fetch(FetchDescriptor<SplitExpense>(
                predicate: #Predicate { $0.groupZoneID == zoneID && $0.isOpeningBalance == true }))
            #expect(after.count == 1)
            #expect(after.first?.amount == 80)
        }
    }

    @Test("Sin permiso, el error es el del formulario y no se guarda nada")
    func openingBalance_notAdmin_saysWhy() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context, iAmOwner: false, myRole: "member")
        withServices(context) {
            var answers = ChatGuidedAnswers()
            answers.groupZoneID = f.group.cloudKitZoneID
            answers.debtorMemberID = f.luis.id.uuidString
            answers.creditorMemberID = f.ana.id.uuidString
            answers.amount = 50
            answers.currencyCode = "PEN"
            #expect(throws: ChatGuidedCreationError.message(
                OpeningBalanceErrorCopyLogic.message(for: GroupExpenseServiceError.notAdmin))) {
                try ChatGuidedCreator.create(try confirmed(.groupOpeningBalance, answers),
                                             data: ChatGuidedData(mainCurrency: "PEN"), context: context,
                                             budgetAlertsEnabled: false)
            }
        }
    }

    // MARK: - Gasto de grupo

    @Test("«Ana pagó 90 del taxi, entre Ana y yo»: partes iguales solo entre los dos")
    func expense_equalSome() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withServices(context) {
            var answers = ChatGuidedAnswers()
            answers.groupZoneID = f.group.cloudKitZoneID
            answers.expenseDescription = "Taxi"
            answers.amount = 90
            answers.currencyCode = "PEN"
            answers.payerMemberID = f.ana.id.uuidString
            answers.splitMode = .equalSome
            answers.participantIDs = [f.me.id.uuidString, f.ana.id.uuidString]
            answers.expenseAccountRequired = ChatGuidedCreator.groupExpenseNeedsAccount(answers, context: context)
            #expect(answers.expenseAccountRequired == false, "Pagó Ana: tu cuenta no entra.")
            let created = try ChatGuidedCreator.create(try confirmed(.groupExpense, answers),
                                                       data: ChatGuidedData(mainCurrency: "PEN"), context: context,
                                                       budgetAlertsEnabled: false)
            #expect(created.name == "Taxi")
            let expense = try #require(try GroupExpenseService.shared.fetchExpenses(for: f.group).first)
            #expect(expense.amount == 90)
            #expect(expense.paidByMemberID == f.ana.id.uuidString)
            #expect(expense.splitType == "equal")
            let shares = try GroupExpenseService.shared.fetchAllShares(for: f.group).filter { $0.expenseID == expense.id }
            #expect(Set(shares.map(\.memberID)) == [f.me.id.uuidString, f.ana.id.uuidString], "Luis no entra.")
            #expect(shares.allSatisfy { abs($0.amount - 45) < 0.001 })
        }
    }

    @Test("Un monto para cada uno: se guarda tal cual, y si no cuadra no se guarda")
    func expense_exact() throws {
        let dir = try freshDir()
        defer { discardTestStoreDirectory(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withServices(context) {
            var answers = ChatGuidedAnswers()
            answers.groupZoneID = f.group.cloudKitZoneID
            answers.expenseDescription = "Cena"
            answers.amount = 120
            answers.currencyCode = "PEN"
            answers.payerMemberID = f.luis.id.uuidString
            answers.splitMode = .exact
            answers.participantIDs = [f.me.id.uuidString, f.ana.id.uuidString, f.luis.id.uuidString]
            answers.exactShares = [f.me.id.uuidString: 50, f.ana.id.uuidString: 40, f.luis.id.uuidString: 30]
            answers.expenseAccountRequired = false
            _ = try ChatGuidedCreator.create(try confirmed(.groupExpense, answers),
                                             data: ChatGuidedData(mainCurrency: "PEN"), context: context,
                                             budgetAlertsEnabled: false)
            let expense = try #require(try GroupExpenseService.shared.fetchExpenses(for: f.group).first)
            #expect(expense.splitType == "exact")
            let shares = try GroupExpenseService.shared.fetchAllShares(for: f.group).filter { $0.expenseID == expense.id }
            let byMember = Dictionary(shares.map { ($0.memberID, $0.amount) }, uniquingKeysWith: { first, _ in first })
            #expect(byMember[f.me.id.uuidString] == 50)
            #expect(byMember[f.ana.id.uuidString] == 40)
            #expect(byMember[f.luis.id.uuidString] == 30)

            // Si no cuadra, el motor no deja llegar a la confirmación.
            answers.exactShares = [f.me.id.uuidString: 50, f.ana.id.uuidString: 40, f.luis.id.uuidString: 20]
            #expect(ChatGuidedEngine.start(.groupExpense, answers: answers).step == .expenseSplit)
        }
    }
}
