//
//  GroupBridgeCloudSyncIntegrationTests.swift
//  YalaTests / CloudSync
//
//  E2E bridge de Grupos → drain del motor Modo Nube → outbox. Cierra el hueco de
//  cobertura de la decisión Grupos-en-v1 (2026-07-13): las suites del bridge y del
//  motor eran DISJUNTAS — ningún test verificaba que un gasto de grupo bridgeado a
//  TransactionItem/InboxDraft fluye al outbox con sus columnas split_* pobladas.
//  Una regresión de integración (bridge adoptando outboxSaveAuthor, sweep dejando
//  de cubrir una entidad) no la detectaba nadie.
//
//  Container ON-DISK temp con los 3 stores (patrón CloudSyncEngineTests — el History
//  es por-CONTAINER y no es fiable in-memory). `bridgeExpense` se invoca con
//  `shouldSave: false` + save manual: los side-effects de `saveIfNeeded`
//  (incrementDataVersion / WidgetDataCache / BudgetAlertService) NO corren — eran
//  la causa histórica de la blacklist R8 de los tests full-pipeline del bridge.
//
//  El host de tests salta el bootstrap (YalaApp: isRunningTests) ⇒
//  BridgeModeResolver.appPreferences == nil ⇒ isBridgeEnabled == true determinístico.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("GroupBridge → CloudSync · e2e bridge→drain→outbox", .serialized)
@MainActor
struct GroupBridgeCloudSyncIntegrationTests {

    // MARK: - Infra (patrón CloudSyncEngineTests)

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupBridgeCloudSync-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GBCS-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "GBCS-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "GBCS-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg
        )
        return ModelContext(container)
    }

    private func outboxRows(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>())
    }

    private func fields(_ row: SyncOutbox) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(row.fieldsJSON.utf8)) as? [String: Any] ?? [:]
    }

    private func upserts(_ rows: [SyncOutbox], _ entityType: String) -> [SyncOutbox] {
        rows.filter { $0.opRaw == SyncOutboxOp.upsert.rawValue && $0.entityType == entityType }
    }

    // MARK: - Fixtures + entorno del bridge

    private struct Fixture {
        let group: SplitGroup
        let me: SplitMember
        let ana: SplitMember
        let account: Account
    }

    private func makeFixture(_ context: ModelContext) throws -> Fixture {
        let group = SplitGroup(name: "Viaje", currencyCode: "USD")
        context.insert(group)
        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Yo", isCurrentUser: true)
        context.insert(me)
        let ana = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Ana")
        context.insert(ana)
        let account = Account(
            name: "Efectivo", currencyCode: "USD", colorHex: "#111111",
            iconName: "banknote", type: "cash"
        )
        context.insert(account)
        try context.save()
        return Fixture(group: group, me: me, ana: ana, account: account)
    }

    /// Inyecta el contexto al bridge y fija el modo de onboarding a `.full` (Caso A real
    /// exige != .groupInvite), restaurando SIEMPRE: `onboardingMode` PERSISTE en
    /// UserDefaults del host vía didSet → OnboardingMode.setCurrent. El cache del
    /// BridgeModeResolver no tiene _testReset — se invalida entero en setup Y defer.
    private func withBridgeEnvironment(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupTransactionBridge.shared.setContext(context)
        let previousMode = SessionState.shared.onboardingMode
        SessionState.shared.onboardingMode = .full
        BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        defer {
            SessionState.shared.onboardingMode = previousMode
            BridgeModeResolver.shared.invalidateCache(forZoneID: nil)
        }
        try body()
    }

    /// Asserts de columnas comunes a toda fila bridgeada — INNEGOCIABLES (lección
    /// d49d2e47: el gap es exactamente un test que no asserta el contenido real).
    private func expectSplitColumns(
        _ row: SyncOutbox, expenseID: UUID, zoneID: String,
        requireTotalAmount: Bool = true
    ) throws {
        let f = try fields(row)
        #expect(f["split_expense_id"] as? String == expenseID.uuidString,
                "split_expense_id debe viajar en \(row.entityType)")
        #expect(f["split_group_zone_id"] as? String == zoneID,
                "split_group_zone_id debe viajar en \(row.entityType)")
        if requireTotalAmount {
            #expect(f["split_total_amount"] != nil, "split_total_amount debe emitirse en \(row.entityType)")
        }
    }

    // MARK: - Test 1: Caso A (yo pago) — TX real + virtual lent + draft fallback

    @Test func casoA_bridgeThenDrain_emitsTransactionsAndDraft_withSplitColumns() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fixture = try makeFixture(context)

        try withBridgeEnvironment(context) {
            // Gasto 90 USD pagado por mí, shares 30 (yo) / 60 (Ana), SIN subcategoryName:
            // el auto-match de subcat falla → además de la TX real (−90) y la virtual
            // lent (+60), el bridge crea el draft fallback [.subcategory] — cubre las
            // columnas de InboxDraft gratis. OJO: el count de drafts es sensible al
            // fixture (añadir un subcategoryName matcheable lo elimina).
            let expense = SplitExpense(
                groupZoneID: fixture.group.cloudKitZoneID,
                amount: 90, currencyCode: "USD",
                expenseDescription: "Cena",
                paidByMemberID: fixture.me.id.uuidString
            )
            context.insert(expense)
            context.insert(SplitShare(
                expenseID: expense.id, memberID: fixture.me.id.uuidString,
                amount: 30, groupZoneID: fixture.group.cloudKitZoneID
            ))
            context.insert(SplitShare(
                expenseID: expense.id, memberID: fixture.ana.id.uuidString,
                amount: 60, groupZoneID: fixture.group.cloudKitZoneID
            ))
            try context.save()

            try GroupTransactionBridge.shared.bridgeExpense(
                expense, in: fixture.group,
                accountForCurrentUser: fixture.account,
                shouldSave: false
            )
            try context.save()

            let engine = CloudSyncEngine()
            engine.drainOnce(context: context)

            let rows = try outboxRows(context)

            // TX: real −90 (cuenta Efectivo) + virtual lent +60 (cuenta sistema Grupos).
            let txRows = upserts(rows, SyncEntityType.transactionItem)
            #expect(txRows.count == 2, "Caso A bridge-ON: TX real + TX virtual lent")
            for row in txRows {
                try expectSplitColumns(row, expenseID: expense.id, zoneID: fixture.group.cloudKitZoneID)
            }

            // Draft fallback [.subcategory] (subcat sin match, TX real sin clasificar).
            let draftRows = upserts(rows, SyncEntityType.inboxDraft)
            #expect(draftRows.count == 1, "draft fallback [.subcategory] del Caso A sin subcat")
            for row in draftRows {
                try expectSplitColumns(row, expenseID: expense.id, zoneID: fixture.group.cloudKitZoneID,
                                       requireTotalAmount: false)
            }

            // Anti-fuga: los Split* viven en el store de grupos y personalEntityNames
            // los excluye del drain — el outbox JAMÁS los contiene.
            #expect(rows.allSatisfy { !$0.entityType.hasPrefix("Split") },
                    "entidades de Grupos filtradas del outbox personal")

            // Convergencia: el propio drain escribió (sweep syncID con autor default) —
            // un segundo drain no debe re-emitir nada.
            let countAfterFirstDrain = rows.count
            engine.drainOnce(context: context)
            #expect(try outboxRows(context).count == countAfterFirstDrain,
                    "segundo drain no emite filas nuevas")
        }
    }

    // MARK: - Test 2: Caso B (paga otra, path sync remoto) — virtual −myShare + draft

    @Test func casoB_remoteSync_bridgeThenDrain_emitsVirtualAndDraft_withSplitColumns() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let fixture = try makeFixture(context)

        try withBridgeEnvironment(context) {
            let expense = SplitExpense(
                groupZoneID: fixture.group.cloudKitZoneID,
                amount: 90, currencyCode: "USD",
                expenseDescription: "Taxi",
                paidByMemberID: fixture.ana.id.uuidString
            )
            context.insert(expense)
            context.insert(SplitShare(
                expenseID: expense.id, memberID: fixture.me.id.uuidString,
                amount: 30, groupZoneID: fixture.group.cloudKitZoneID
            ))
            try context.save()

            try GroupTransactionBridge.shared.bridgeExpense(
                expense, in: fixture.group,
                accountForCurrentUser: nil,
                isRemoteSync: true,
                shouldSave: false
            )
            try context.save()

            CloudSyncEngine().drainOnce(context: context)

            let rows = try outboxRows(context)

            // Virtual −30 (mi costo directo, sin TX real).
            let txRows = upserts(rows, SyncEntityType.transactionItem)
            #expect(txRows.count == 1, "Caso B: solo la TX virtual −myShare")
            for row in txRows {
                try expectSplitColumns(row, expenseID: expense.id, zoneID: fixture.group.cloudKitZoneID)
            }

            // Draft puntero [.subcategory] del Caso B (subcat sin match).
            let draftRows = upserts(rows, SyncEntityType.inboxDraft)
            #expect(draftRows.count == 1, "draft puntero del Caso B")
            for row in draftRows {
                try expectSplitColumns(row, expenseID: expense.id, zoneID: fixture.group.cloudKitZoneID,
                                       requireTotalAmount: false)
            }

            #expect(rows.allSatisfy { !$0.entityType.hasPrefix("Split") })
        }
    }
}
