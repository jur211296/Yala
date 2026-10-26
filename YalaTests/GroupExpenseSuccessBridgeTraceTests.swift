//
//  GroupExpenseSuccessBridgeTraceTests.swift
//  YalaTests
//
//  Card dx3m · ticket `group-expense-success-claims-a-bridge-write-that-did-not-happen`: la línea «qué se apuntó en tus
//  finanzas» de «¡Gasto agregado!» sale de lo que el puente dejó escrito, o se calla.
//
//  Dos mitades. La tabla pura (`confirmedOutcome`) cubre los seis casos en que el puente no escribe nada —dominio
//  sellado, grupo oculto, gasto en el libro de conservados, sin miembro propio, sin contexto, error—: en los seis el
//  store queda sin rastro del gasto (o con `bridgePending`, el del error). La otra mitad monta el puente de verdad y
//  lee con `GroupExpenseBridgeTraceReader`: dos de esos casos (oculto, sin miembro propio) de punta a punta, con sus
//  dos controles positivos (Caso A en cuenta real, Caso B con tu parte). El sello del dominio no se puede montar en un
//  test (`isDomainOpenForBridge` lo ignora con `isRunningTests`), por eso queda en la tabla.
//
//  Montaje del puente: el de `GroupJoinerBridgeReachesRealAccountTests` (container on-disk con los tres stores,
//  `shouldSave: false` y save manual, `.serialized` por el singleton).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - La decisión

@Suite("Gasto agregado · la línea sale de lo que el puente escribió")
struct GroupExpenseSuccessConfirmedOutcomeTests {

    private let empty = GroupExpenseBridgeTrace(
        realAccountName: nil, hasVirtualShare: false, hasPendingOptInDraft: false, bridgePending: false)

    private let claims: [GroupExpensePersonalOutcome] = [
        .chargedToAccount(accountName: "Cuenta Principal"),
        .waitingInInbox,
        .shareAsGroupExpense(amount: 40),
    ]

    /// Dominio sellado, grupo oculto, libro de conservados, sin miembro propio y sin contexto: el puente sale antes de
    /// escribir, el store no tiene nada de este gasto y la pantalla no afirma nada.
    @Test func nothingWritten_saysNothing_forEveryClaim() {
        for claim in claims {
            #expect(GroupExpenseSuccessLogic.confirmedOutcome(claim, trace: empty) == .none, "\(claim)")
        }
    }

    /// El sexto caso: `bridgeExpense` lanzó y el gasto quedó para reintentar. Aunque algo hubiera llegado a escribirse,
    /// la pantalla no lo da por hecho.
    @Test func bridgeError_saysNothing_evenWithSomethingWritten() {
        let failed = GroupExpenseBridgeTrace(
            realAccountName: "Cuenta Principal", hasVirtualShare: true, hasPendingOptInDraft: true, bridgePending: true)
        for claim in claims {
            #expect(GroupExpenseSuccessLogic.confirmedOutcome(claim, trace: failed) == .none, "\(claim)")
        }
    }

    @Test func unreadableStore_saysNothing() {
        for claim in claims {
            #expect(GroupExpenseSuccessLogic.confirmedOutcome(claim, trace: nil) == .none, "\(claim)")
        }
    }

    // MARK: Controles: con el rastro, la línea sale

    @Test func realTransaction_namesTheAccountItLandedIn() {
        let trace = GroupExpenseBridgeTrace(
            realAccountName: "Ahorros", hasVirtualShare: false, hasPendingOptInDraft: false, bridgePending: false)
        // La cuenta que se nombra es la de la transacción, no la elegida en el formulario.
        #expect(GroupExpenseSuccessLogic.confirmedOutcome(.chargedToAccount(accountName: "Cuenta Principal"),
                                                          trace: trace) == .chargedToAccount(accountName: "Ahorros"))
    }

    @Test func pendingOptInDraft_confirmsTheInbox() {
        let trace = GroupExpenseBridgeTrace(
            realAccountName: nil, hasVirtualShare: true, hasPendingOptInDraft: true, bridgePending: false)
        #expect(GroupExpenseSuccessLogic.confirmedOutcome(.waitingInInbox, trace: trace) == .waitingInInbox)
    }

    @Test func virtualShare_confirmsYourShare() {
        let trace = GroupExpenseBridgeTrace(
            realAccountName: nil, hasVirtualShare: true, hasPendingOptInDraft: false, bridgePending: false)
        #expect(GroupExpenseSuccessLogic.confirmedOutcome(.shareAsGroupExpense(amount: 40), trace: trace)
                == .shareAsGroupExpense(amount: 40))
    }

    /// Un rastro de otro tipo no confirma la afirmación: una virtual de tu parte no prueba un cargo en tu cuenta.
    @Test func aDifferentTrace_doesNotConfirmTheClaim() {
        let onlyVirtual = GroupExpenseBridgeTrace(
            realAccountName: nil, hasVirtualShare: true, hasPendingOptInDraft: false, bridgePending: false)
        #expect(GroupExpenseSuccessLogic.confirmedOutcome(.chargedToAccount(accountName: "X"), trace: onlyVirtual) == .none)
        #expect(GroupExpenseSuccessLogic.confirmedOutcome(.waitingInInbox, trace: onlyVirtual) == .none)
        let onlyReal = GroupExpenseBridgeTrace(
            realAccountName: "X", hasVirtualShare: false, hasPendingOptInDraft: false, bridgePending: false)
        #expect(GroupExpenseSuccessLogic.confirmedOutcome(.shareAsGroupExpense(amount: 40), trace: onlyReal) == .none)
    }
}

// MARK: - El puente de verdad

@Suite("Gasto agregado · el rastro del puente real", .serialized)
@MainActor
struct GroupExpenseSuccessBridgeTraceReaderTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuccessTrace-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("No se creó el directorio del test: \(error)")
        }
        return dir
    }

    private func remove(_ dir: URL) {
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            Issue.record("No se borró el directorio del test: \(error)")
        }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration(
            "ST-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "ST-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "ST-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        return ModelContext(container)
    }

    private struct Scene {
        let group: SplitGroup
        let expense: SplitExpense
        let account: Account
    }

    /// Gasto de 100 a medias entre «Yo» y Ana. `paidByMe` decide Caso A o B; `meResolvable` apaga la identidad.
    private func mount(
        _ context: ModelContext, paidByMe: Bool, hidden: Bool = false, meResolvable: Bool = true
    ) throws -> Scene {
        let group = SplitGroup(name: "Viaje", currencyCode: "USD")
        group.isHiddenForAll = hidden
        context.insert(group)
        let me = SplitMember(
            groupZoneID: group.cloudKitZoneID, displayName: "Yo",
            cloudKitUserRecordID: "_otro-humano", isCurrentUser: meResolvable)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(me)
        context.insert(ana)
        let account = Account(
            name: "Cuenta Principal", currencyCode: "USD", colorHex: "#111111", iconName: "banknote", type: "cash")
        context.insert(account)
        let expense = SplitExpense(
            groupZoneID: group.cloudKitZoneID, amount: 100, currencyCode: "USD",
            expenseDescription: "Cena", paidByMemberID: (paidByMe ? me : ana).id.uuidString)
        context.insert(expense)
        for member in [me, ana] {
            context.insert(SplitShare(
                expenseID: expense.id, memberID: member.id.uuidString, amount: 50, groupZoneID: group.cloudKitZoneID))
        }
        try context.save()
        return Scene(group: group, expense: expense, account: account)
    }

    private func bridgeAndRead(_ context: ModelContext, _ scene: Scene) throws -> GroupExpenseBridgeTrace {
        GroupTransactionBridge.shared.setContext(context)
        let previousSession = SessionState.shared.hasPrivateSession
        let previousRecordName = GroupUserIdentityService.shared.cachedRecordName
        SessionState.shared.hasPrivateSession = true
        GroupUserIdentityService.shared._testSetCachedRecordName(nil)
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            SessionState.shared.hasPrivateSession = previousSession
            GroupUserIdentityService.shared._testSetCachedRecordName(previousRecordName)
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        }
        try GroupTransactionBridge.shared.bridgeExpense(
            scene.expense, in: scene.group, accountForCurrentUser: scene.account, shouldSave: false)
        try context.save()
        return try GroupExpenseBridgeTraceReader.read(expenseID: scene.expense.id.uuidString, context: context)
    }

    // MARK: Controles: el puente escribe y la línea sale

    @Test func caseA_bridgeOn_confirmsTheCharge() throws {
        let dir = freshDir()
        defer { remove(dir) }
        let context = try makeContext(dir)
        let trace = try bridgeAndRead(context, try mount(context, paidByMe: true))

        #expect(trace.realAccountName == "Cuenta Principal")
        #expect(GroupExpenseSuccessLogic.confirmedOutcome(.chargedToAccount(accountName: "Cuenta Principal"),
                                                          trace: trace) == .chargedToAccount(accountName: "Cuenta Principal"))
    }

    @Test func caseB_confirmsYourShare() throws {
        let dir = freshDir()
        defer { remove(dir) }
        let context = try makeContext(dir)
        let trace = try bridgeAndRead(context, try mount(context, paidByMe: false))

        #expect(trace.hasVirtualShare)
        #expect(trace.realAccountName == nil)
        #expect(GroupExpenseSuccessLogic.confirmedOutcome(.shareAsGroupExpense(amount: 50), trace: trace)
                == .shareAsGroupExpense(amount: 50))
    }

    // MARK: Los casos del ticket: el puente no escribe y la línea se calla

    @Test func hiddenGroup_writesNothing_andTheLineIsSilent() throws {
        let dir = freshDir()
        defer { remove(dir) }
        let context = try makeContext(dir)
        let trace = try bridgeAndRead(context, try mount(context, paidByMe: true, hidden: true))

        #expect(trace == GroupExpenseBridgeTrace(
            realAccountName: nil, hasVirtualShare: false, hasPendingOptInDraft: false, bridgePending: false))
        #expect(GroupExpenseSuccessLogic.confirmedOutcome(.chargedToAccount(accountName: "Cuenta Principal"),
                                                          trace: trace) == .none)
    }

    @Test func ownMemberUnresolved_writesNothing_andTheLineIsSilent() throws {
        let dir = freshDir()
        defer { remove(dir) }
        let context = try makeContext(dir)
        let trace = try bridgeAndRead(context, try mount(context, paidByMe: false, meResolvable: false))

        #expect(!trace.hasVirtualShare)
        #expect(GroupExpenseSuccessLogic.confirmedOutcome(.shareAsGroupExpense(amount: 50), trace: trace) == .none)
    }

    // MARK: El lector

    @Test func reader_seesAPendingOptInDraft_andTheRetryMark() throws {
        let dir = freshDir()
        defer { remove(dir) }
        let context = try makeContext(dir)
        let scene = try mount(context, paidByMe: true)
        let id = scene.expense.id.uuidString
        context.insert(InboxDraft(note: "Cena", amount: -100, splitExpenseID: id, optInPersonalOnly: true))
        // Un borrador ya aprobado no es «te espera en la Bandeja».
        context.insert(InboxDraft(note: "Cena", amount: -100, status: .approved, splitExpenseID: id,
                                  optInPersonalOnly: true))
        scene.expense.bridgePending = true
        try context.save()

        let trace = try GroupExpenseBridgeTraceReader.read(expenseID: id, context: context)
        #expect(trace.hasPendingOptInDraft)
        #expect(trace.bridgePending)
    }

    @Test func reader_ignoresAnApprovedOptInDraft() throws {
        let dir = freshDir()
        defer { remove(dir) }
        let context = try makeContext(dir)
        let scene = try mount(context, paidByMe: true)
        let id = scene.expense.id.uuidString
        context.insert(InboxDraft(note: "Cena", amount: -100, status: .approved, splitExpenseID: id,
                                  optInPersonalOnly: true))
        try context.save()

        let trace = try GroupExpenseBridgeTraceReader.read(expenseID: id, context: context)
        #expect(!trace.hasPendingOptInDraft)
        #expect(!trace.bridgePending)
    }
}
