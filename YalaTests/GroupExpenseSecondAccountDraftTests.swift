//
//  GroupExpenseSecondAccountDraftTests.swift
//  YalaTests
//
//  Ticket `two-account-drafts-for-one-group-expense-can-create-two-real-legs` (card 9o4n): dos borradores de cuenta del
//  MISMO gasto de grupo conviven en la Bandeja —el opt-in («Sí, registrar» con el puente apagado) sobrevive a los
//  re-puentes, y encender el puente con «Importar todo el historial» crea otro—. Aprobar los dos dejaba dos movimientos
//  `-total` en las cuentas de la persona: el gasto contado dos veces. Desde este arreglo el segundo no crea pata, lo
//  dice, y la hoja lo retira al cerrarse.
//
//  Contra el bridge REAL con los tres stores en disco (harness de `GroupsBridgeRestoreConvergenceTests`): lo que cuesta
//  dinero vive en lo que el bridge hace con la pata real recién creada.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Bandeja · el segundo borrador de cuenta de un gasto de grupo no crea otra pata", .serialized)
@MainActor
struct GroupExpenseSecondAccountDraftTests {

    // MARK: - Infra

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupSecondAccountDraft-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            #if DEBUG
            print("GroupExpenseSecondAccountDraftTests: cleanup: \(error)")
            #endif
        }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration(
            "GSAD-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "GSAD-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "GSAD-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        let context = ModelContext(container)
        // Sin autosave: un `approveDraft` que lanza deja cambios sin guardar, y el temporizador los guardaría con la
        // carpeta ya borrada (ver el harness de `GroupsBridgeRestoreConvergenceTests`).
        context.autosaveEnabled = false
        return context
    }

    private struct Fixture {
        let group: SplitGroup
        let expense: SplitExpense
        let cash: Account
        let bank: Account
    }

    /// Caso A: pagué yo 90; mi parte es 30 y la de Ana 60.
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
        let bank = Account(name: "Banco", currencyCode: "USD", colorHex: "#222222",
                           iconName: "building.columns", type: "bank")
        context.insert(bank)
        let expense = SplitExpense(groupZoneID: group.cloudKitZoneID, amount: 90, currencyCode: "USD",
                                   expenseDescription: "Cena", paidByMemberID: me.id.uuidString)
        context.insert(expense)
        context.insert(SplitShare(expenseID: expense.id, memberID: me.id.uuidString, amount: 30,
                                  groupZoneID: group.cloudKitZoneID))
        context.insert(SplitShare(expenseID: expense.id, memberID: ana.id.uuidString, amount: 60,
                                  groupZoneID: group.cloudKitZoneID))
        try context.save()
        return Fixture(group: group, expense: expense, cash: cash, bank: bank)
    }

    /// Un borrador de cuenta del gasto, con los campos de `GroupTransactionBridge.createDraftCaseA`; `optIn` es el de
    /// «Sí, registrar» con el puente apagado, el que sobrevive a los re-puentes.
    private func insertAccountDraft(
        _ context: ModelContext, _ f: Fixture, account: Account, optIn: Bool
    ) throws -> InboxDraft {
        let draft = InboxDraft(
            note: f.expense.expenseDescription,
            amount: -f.expense.amount,
            date: f.expense.date,
            account: account,
            sourceType: .groupExpense,
            confidenceAmount: 1.0,
            confidenceDate: 1.0,
            confidenceMerchant: 1.0,
            needsUserInput: GroupDraftFinalizationLogic.caseADraftNeedsUserInput(needsSubcategory: false),
            splitExpenseID: f.expense.id.uuidString,
            splitGroupZoneID: f.expense.groupZoneID,
            originGroupName: f.group.name,
            optInPersonalOnly: optIn
        )
        context.insert(draft)
        try context.save()
        return draft
    }

    private func realLegs(_ context: ModelContext, _ f: Fixture) throws -> [TransactionItem] {
        let idStr = f.expense.id.uuidString
        return try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.splitExpenseID == idStr }))
            .filter { $0.account.map { !$0.isSystemAccount } ?? false }
    }

    private func drafts(_ context: ModelContext, _ f: Fixture) throws -> [InboxDraft] {
        let idStr = f.expense.id.uuidString
        return try context.fetch(FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.splitExpenseID == idStr }))
    }

    /// El entorno del bridge y de la Bandeja: singletons que comparten las demás suites, restaurados al salir.
    private func withEnvironment(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupTransactionBridge.shared.setContext(context)
        DraftService.shared.setContext(context)
        let previousPrivateSession = SessionState.shared.hasPrivateSession
        SessionState.shared.hasPrivateSession = true
        let previousIntentDefaults = GroupsPendingBridgeIntent.defaults
        GroupsPendingBridgeIntent.defaults = makeIsolatedDefaults()
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            DraftService.shared.setContext(nil)
            SessionState.shared.hasPrivateSession = previousPrivateSession
            GroupsPendingBridgeIntent.defaults = previousIntentDefaults
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        }
        try body()
    }

    // MARK: - Casos

    @Test("aprobar el segundo borrador no crea otra pata y dice que ya está registrado")
    func secondDraft_isRetired_withoutASecondRealLeg() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let optIn = try insertAccountDraft(context, f, account: f.cash, optIn: true)
            let second = try insertAccountDraft(context, f, account: f.bank, optIn: false)

            let first = try DraftService.shared.approveDraft(optIn, currencyConverter: CurrencyConverter())
            #expect(first.account?.persistentModelID == f.cash.persistentModelID)
            #expect(try realLegs(context, f).count == 1, "el fixture no crea la primera pata real")

            // `DraftServiceError` no es `Equatable` (lleva valores asociados): el caso se mira a mano.
            do {
                _ = try DraftService.shared.approveDraft(second, currencyConverter: CurrencyConverter())
                Issue.record("aprobar el segundo borrador no lanzó: creó otra pata")
            } catch DraftServiceError.groupExpenseAlreadyRegistered {
                // Lo esperado.
            } catch {
                Issue.record("error inesperado: \(error)")
            }

            let legs = try realLegs(context, f)
            #expect(legs.count == 1, "el gasto quedó contado dos veces en las cuentas")
            #expect(legs.first?.account?.persistentModelID == f.cash.persistentModelID,
                    "la pata que queda es la de la primera aprobación")
            // Con la hoja montada el borrador sigue ahí (borrarlo la tumbaría); la hoja lo retira al cerrarse.
            #expect(try drafts(context, f).count == 1, "el servicio borró el borrador con su hoja aún montada")
            try DraftService.shared.retireGroupExpenseDraftIfAlreadyRegistered(second)
            #expect(try drafts(context, f).isEmpty, "el borrador que ya no sirve sigue en la Bandeja")
        }
    }

    /// La retirada vuelve a medir: sin pata real el borrador se queda, que es el que crearía la pata.
    @Test("sin pata real, retirar no hace nada")
    func retire_withoutARealLeg_keepsTheDraft() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let draft = try insertAccountDraft(context, f, account: f.bank, optIn: false)
            try DraftService.shared.retireGroupExpenseDraftIfAlreadyRegistered(draft)
            #expect(try drafts(context, f).count == 1)
        }
    }

    /// Las dos hojas de la Bandeja retiran el borrador al CERRARSE, nunca en el `catch` (con la hoja montada).
    @Test("las dos hojas retiran el borrador al desaparecer")
    func sheets_retireOnDisappear() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        for name in ["GroupExpenseAccountFinalizationSheet", "GroupExpenseAccountAndSubcategoryFinalizationSheet"] {
            let code = try String(contentsOf: root.appendingPathComponent("Yala/App/Views/Inbox/\(name).swift"),
                                  encoding: .utf8)
            #expect(code.contains(".onDisappear { retireDraftIfAlreadyRegistered() }"), "\(name)")
            #expect(code.contains("if case DraftServiceError.groupExpenseAlreadyRegistered = error { retiresDraftOnClose = true }"),
                    "\(name)")
            #expect(code.contains("Button(L10n.Common.ok) { closeIfAlreadyRegistered() }"), "\(name)")
        }
        let service = try String(contentsOf: root.appendingPathComponent("Yala/Services/DraftService.swift"),
                                 encoding: .utf8)
        let guardStart = try #require(service.range(of: "if try hasRealLeg(splitID: splitID, in: context) {"))
        let guardBody = service[guardStart.upperBound...].prefix(400)
        #expect(!guardBody.contains("deleteInboxDraftPruningRow"), "el servicio vuelve a borrar con la hoja montada")
    }

    /// Control: con un solo borrador la aprobación sigue creando su pata. Sin él, un arreglo que rechazara TODA
    /// aprobación saldría verde en el caso de arriba.
    @Test("con un solo borrador, aprobarlo crea su pata como siempre")
    func singleDraft_stillCreatesItsRealLeg() throws {
        let dir = try freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try makeFixture(context)
        try withEnvironment(context) {
            let draft = try insertAccountDraft(context, f, account: f.bank, optIn: false)
            let tx = try DraftService.shared.approveDraft(draft, currencyConverter: CurrencyConverter())
            #expect(tx.amount == -90)
            #expect(try realLegs(context, f).count == 1)
        }
    }

    @Test("el aviso tiene su propio texto, no el genérico de guardar")
    func alreadyRegistered_hasItsOwnCopy() {
        let message = DraftServiceError.groupExpenseAlreadyRegistered.errorDescription
        #expect(message == L10n.Inbox.GroupExpenseDraft.alreadyRegistered)
        #expect(message != L10n.Common.saveError)
    }
}
