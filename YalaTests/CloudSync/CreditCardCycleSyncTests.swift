//
//  CreditCardCycleSyncTests.swift
//  YalaTests / CloudSync
//
//  Card nmtk por el Modo Nube: `accounts.credit_card_statement_day` y `accounts.credit_card_reminder_days_before` con
//  `since: 5`. Con el molde de `FavoriteDestinationSyncTests`:
//   - con `v4` las columnas ni se emiten (un Worker v4 rechazaría la fila entera) y lo cambiado se APUNTA; con `v5`, sí;
//   - ida y vuelta: lo que un teléfono emite en v5, otro lo aplica;
//   - al subir de v4 a v5 se reemiten las tarjetas apuntadas, con SOLO esas dos columnas.
//
//  Container ON-DISK temp con los 3 stores + `.serialized`. `SyncCapability.defaults` se aísla en cada caso.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSync · tarjeta: día de corte y aviso (v5)", .serialized)
@MainActor
struct CreditCardCycleSyncTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CCCycle-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "CC-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "CC-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "CC-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private func isolateCapability(backend level: Int?) -> () -> Void {
        let previous = SyncCapability.defaults
        let suite = "test.syncCapability.\(UUID().uuidString)"
        let isolated = UserDefaults(suiteName: suite) ?? previous
        SyncCapability.defaults = isolated
        if let level { isolated.set(level, forKey: SyncCapability.backendManifestVersionKey) }
        return {
            isolated.removePersistentDomain(forName: suite)
            SyncCapability.defaults = previous
        }
    }

    private let node = "0123456789abcdef"
    private let applyNow = Date(timeIntervalSince1970: 1_700_000_100)
    private func hlc(_ counter: Int) -> String {
        "2023-11-14T22:13:20.000Z-\(String(format: "%04x", counter))-\(node)"
    }

    private func card(_ context: ModelContext) -> Account {
        let a = Account(name: "Visa", currencyCode: "PEN", colorHex: "#3D36B3", iconName: "creditcard.fill",
                        type: AccountType.creditCard.rawValue)
        a.creditCardPaymentReminder = true
        a.creditCardPaymentDay = 5
        context.insert(a)
        return a
    }

    private func outbox(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    private func fields(_ row: SyncOutbox) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(row.fieldsJSON.utf8)) as? [String: Any] ?? [:]
    }

    // MARK: - Emisión

    @Test func emission_v5_carriesBothColumns_v4_doesNot() throws {
        let context = try makeContext(freshDir())
        let visa = card(context)
        visa.creditCardStatementDay = 15
        visa.creditCardReminderDaysBefore = 3
        let emission = EntityEmissionMap.account

        let v5 = DeltaEmitter.emit(model: visa, emission: emission, changedColumns: emission.columns,
                                   hlc: hlc(1), capabilityLevel: 5)
        #expect(v5.fields["credit_card_statement_day"] == .int(15))
        #expect(v5.fields["credit_card_reminder_days_before"] == .int(3))

        let v4 = DeltaEmitter.emit(model: visa, emission: emission, changedColumns: emission.columns,
                                   hlc: hlc(1), capabilityLevel: 4)
        #expect(v4.fields["credit_card_statement_day"] == nil)
        #expect(v4.fields["credit_card_reminder_days_before"] == nil)
        #expect(v4.fields["credit_card_payment_day"] == .int(5), "el resto de la fila sí viaja")

        // Sin corte y con el aviso el mismo día, las dos viajan como NULL en v5: es lo que tiene el servidor en toda
        // cuenta de antes de la columna, y la hoja del Merkle tiene que casar (lo cazó la review: `0` divergía).
        visa.creditCardStatementDay = nil
        visa.creditCardReminderDaysBefore = 0
        let none = DeltaEmitter.emit(model: visa, emission: emission, changedColumns: emission.columns,
                                     hlc: hlc(2), capabilityLevel: 5)
        #expect(none.fields["credit_card_statement_day"] == .null)
        #expect(none.fields["credit_card_reminder_days_before"] == .null)
    }

    // MARK: - Drain

    @Test func drain_v4_neverSendsTheColumns_andNotesTheCard() throws {
        let restoreCapability = isolateCapability(backend: 4)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let visa = card(context)
        try context.save()
        engine.drainOnce(context: context)
        #expect(SyncCapability.suppressedCreditCardCycles.isEmpty, "sin corte ni aviso no hay nada que apuntar")

        visa.creditCardStatementDay = 15
        try context.save()
        engine.drainOnce(context: context)

        let rows = try outbox(context).filter { $0.syncID == visa.shortcutID }
        #expect(rows.count == 1, "cambiar solo el día de corte con v4 no saca ninguna fila")
        for row in rows { #expect(try fields(row)["credit_card_statement_day"] == nil) }
        #expect(SyncCapability.suppressedCreditCardCycles == [visa.shortcutID: ["credit_card_statement_day"]],
                "se apunta la columna que cambió, no las dos")
    }

    @Test func drain_v5_sendsOnlyTheEditedColumn() throws {
        let restoreCapability = isolateCapability(backend: 5)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let visa = card(context)
        try context.save()
        engine.drainOnce(context: context)

        visa.creditCardReminderDaysBefore = 5
        try context.save()
        engine.drainOnce(context: context)

        let rows = try outbox(context).filter { $0.syncID == visa.shortcutID }
        #expect(rows.count == 2)
        let update = try fields(try #require(rows.last))
        #expect(Set(update.keys) == ["credit_card_reminder_days_before"])
        #expect(update["credit_card_reminder_days_before"] as? Int == 5)
        #expect(SyncCapability.suppressedCreditCardCycles.isEmpty)
    }

    // MARK: - Ida y vuelta

    @Test func roundTrip_statementDayEmittedOnOnePhone_arrivesOnTheOther() throws {
        let restoreCapability = isolateCapability(backend: 5)
        defer { restoreCapability() }
        let phoneA = try makeContext(freshDir())
        let visa = card(phoneA)
        visa.creditCardStatementDay = 20
        visa.creditCardReminderDaysBefore = 1
        try phoneA.save()
        let emission = EntityEmissionMap.account
        let emitted = DeltaEmitter.emit(model: visa, emission: emission, changedColumns: emission.columns,
                                        hlc: hlc(2), capabilityLevel: 5)
        let fieldsJSON = try Canonc1Codec.encode(emitted.fields, groupedColumns: Set(emission.groupByColumn.keys))
        let hlcs = emitted.fieldHlcs.keys.sorted().map { "\"\($0)\":\"\(hlc(2))\"" }.joined(separator: ",")
        let delta = """
        {"entity_type":"accounts","sync_id":"\(visa.shortcutID.uuidString.lowercased())","op":"upsert",\
        "fields":\(fieldsJSON),"field_hlcs":{\(hlcs)},"hlc":"\(hlc(2))","server_seq":2,"schema_version":1}
        """
        let page = try SyncPullClient.decodePage(Data("{\"deltas\":[\(delta)],\"max_server_seq\":2,\"manifest_version\":5}".utf8))

        let phoneB = try makeContext(freshDir())
        #expect(CloudSyncEngine().applyPage(page, context: phoneB, now: applyNow))
        let arrived = try #require(try phoneB.fetch(FetchDescriptor<Account>()).first { $0.shortcutID == visa.shortcutID })
        #expect(arrived.creditCardStatementDay == 20)
        #expect(arrived.creditCardReminderDaysBefore == 1)

        // Y un NULL en los días de aviso (el «mismo día», o una cuenta de antes de la columna) se lee como 0.
        let syncID = visa.shortcutID.uuidString.lowercased()
        let nullDelta = "{\"entity_type\":\"accounts\",\"sync_id\":\"\(syncID)\",\"op\":\"upsert\","
            + "\"fields\":{\"credit_card_reminder_days_before\":null},"
            + "\"field_hlcs\":{\"credit_card_reminder_days_before\":\"\(hlc(3))\"},"
            + "\"hlc\":\"\(hlc(3))\",\"server_seq\":3,\"schema_version\":1}"
        let nullPage = try SyncPullClient.decodePage(
            Data("{\"deltas\":[\(nullDelta)],\"max_server_seq\":3,\"manifest_version\":5}".utf8))
        #expect(CloudSyncEngine().applyPage(nullPage, context: phoneB, now: applyNow))
        #expect(arrived.creditCardReminderDaysBefore == 0)
        #expect(arrived.creditCardStatementDay == 20, "lo que no viene no se toca")
    }

    // MARK: - La subida de v4 a v5

    @Test func upgradeToV5_reemitsTheNotedCard_withOnlyTheTwoColumns() throws {
        let restoreCapability = isolateCapability(backend: 4)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let visa = card(context)
        try context.save()
        engine.drainOnce(context: context)
        visa.creditCardStatementDay = 15
        visa.creditCardReminderDaysBefore = 3
        try context.save()
        engine.drainOnce(context: context)
        for row in try outbox(context) { context.delete(row) }   // lo demás ya subió
        try context.save()
        #expect(SyncCapability.suppressedCreditCardCycles
                == [visa.shortcutID: ["credit_card_statement_day", "credit_card_reminder_days_before"]])

        SyncCapability.recordBackendManifestVersion(5)
        #expect(SyncCapability.upgradePending)
        #expect(try engine.applyCapabilityUpgradeIfPending(context: context))

        let reemitted = try #require(try outbox(context).last { $0.syncID == visa.shortcutID })
        let reemittedFields = try fields(reemitted)
        #expect(Set(reemittedFields.keys) == SyncCapability.creditCardCycleColumns, "solo las dos columnas")
        #expect(reemittedFields["credit_card_statement_day"] as? Int == 15)
        #expect(SyncCapability.suppressedCreditCardCycles.isEmpty)
    }

    /// Solo la columna apuntada: la otra la pudo cambiar otro teléfono que ya hablaba v5, y subirla con HLC fresco la
    /// pisaría por LWW (lo cazó la review).
    @Test func upgradeToV5_reemitsOnlyTheNotedColumn() throws {
        let restoreCapability = isolateCapability(backend: 4)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let visa = card(context)
        try context.save()
        SyncCapability.noteSuppressedCreditCardCycle(visa.shortcutID, columns: ["credit_card_reminder_days_before"])
        visa.creditCardReminderDaysBefore = 3
        try context.save()

        SyncCapability.recordBackendManifestVersion(5)
        #expect(try engine.applyCapabilityUpgradeIfPending(context: context))

        let reemitted = try #require(try outbox(context).last { $0.syncID == visa.shortcutID })
        #expect(Set(try fields(reemitted).keys) == ["credit_card_reminder_days_before"])
        #expect(SyncCapability.suppressedCreditCardCycles.isEmpty)
    }

    @Test func upgradeWithTheWorkerBackAtV4_keepsTheNotedCards() throws {
        let restoreCapability = isolateCapability(backend: 4)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let visa = card(context)
        visa.creditCardStatementDay = 15
        try context.save()
        SyncCapability.noteSuppressedCreditCardCycle(visa.shortcutID, columns: ["credit_card_statement_day"])
        SyncCapability.upgradePending = true

        #expect(try engine.applyCapabilityUpgradeIfPending(context: context))

        #expect(try outbox(context).filter { $0.syncID == visa.shortcutID }.isEmpty, "con v4 las columnas no viajarían")
        #expect(SyncCapability.suppressedCreditCardCycles == [visa.shortcutID: ["credit_card_statement_day"]],
                "se quedan para la subida a v5")
    }
}
