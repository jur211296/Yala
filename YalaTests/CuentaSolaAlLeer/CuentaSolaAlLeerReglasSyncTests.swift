//
//  CuentaSolaAlLeerReglasSyncTests.swift
//  YalaTests
//
//  Reglas de captura (parte 2, 2026-11-21), la parte con almacén. Lo que fija:
//   - la escalera con reglas guardadas en la cuenta: foto, chat (comercio sin medio de pago) y Apple Pay;
//   - «Recordar» y «Pasarla» (`CuentaSolaReglasStore`), y el formulario de cuenta, que guarda y mueve reglas;
//   - las reglas mueren con su cuenta;
//   - Modo Nube, `accounts.capture_rules_raw` con `since: 9` (molde de `PagoLogoPropioSyncTests`): con v8 no se emite
//     y se APUNTA; con v9, sí; ida y vuelta entre dos teléfonos; la subida de v8 a v9 reemite lo apuntado.
//
//  Container ON-DISK temp con los 3 stores + `.serialized`. `SyncCapability.defaults` se aísla en cada caso.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Reglas de captura · almacén y Modo Nube (capture_rules_raw, v9)", .serialized)
@MainActor
struct CuentaSolaAlLeerReglasSyncTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReglasCaptura-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            Issue.record("No se pudo crear el directorio: \(error)")
        }
        retireTestStoreDirectoryLater(dir)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "RC-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "RC-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "RC-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func isolateCapability(backend level: Int?) -> () -> Void {
        let previous = SyncCapability.defaults
        let suite = "test.syncCapability.\(UUID().uuidString)"
        let isolated = testDefaults(suiteName: suite) ?? previous
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

    @discardableResult
    private func account(_ context: ModelContext, _ name: String, rules: [AccountCaptureRule] = []) -> Account {
        let account = Account(name: name, currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard",
                              type: AccountType.creditCard.rawValue)
        account.captureRulesRaw = AccountCaptureRule.encode(rules)
        context.insert(account)
        return account
    }

    private func texto(_ value: String) -> AccountCaptureRule {
        AccountCaptureRule(kind: .text, value: value, createdAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    private func outbox(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    private func fields(_ row: SyncOutbox) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(row.fieldsJSON.utf8)) as? [String: Any] ?? [:]
    }

    // MARK: - La escalera con reglas guardadas

    @Test func photo_ruleInTheAccount_beatsTheAccountCalledZip() throws {
        let context = try makeContext(freshDir())
        account(context, "Zip")
        let zipVisa = account(context, "Zip Visa", rules: [texto("zip")])
        try context.save()
        let accounts = try context.fetch(FetchDescriptor<Account>())
        let choice = DraftBuilder.chooseAccount(mention: "Zip", last4: nil, currency: "PEN", in: accounts)
        #expect(choice.account?.shortcutID == zipVisa.shortcutID)
        #expect(choice.resultado == .sola(zipVisa.shortcutID, .regla))
        #expect(choice.regla?.value == "zip")
    }

    @Test func chat_merchantRule_decidesWithoutAPaymentMention() throws {
        let context = try makeContext(freshDir())
        account(context, "Efectivo")
        let tarjeta = account(context, "Tarjeta", rules: [AccountCaptureRule(kind: .merchant, value: "Uber")])
        try context.save()
        let accounts = try context.fetch(FetchDescriptor<Account>())
        let found = DraftBuilder.findAccount(paymentMention: nil, merchant: "Uber", dictatedCurrency: nil, in: accounts)
        #expect(found?.shortcutID == tarjeta.shortcutID)
        #expect(DraftBuilder.findAccount(paymentMention: nil, merchant: "Tambo", dictatedCurrency: nil, in: accounts) == nil)
    }

    @Test func applePay_cardRule_choosesTheAccount() throws {
        let context = try makeContext(freshDir())
        account(context, "Interbank")
        let zip = account(context, "Zip", rules: [AccountCaptureRule(kind: .applePayCard, value: "Mi tarjeta azul")])
        try context.save()
        let accounts = try context.fetch(FetchDescriptor<Account>())
        let found = ApplePayDraftService.accountFromCard("Mi tarjeta azul", currency: "PEN", in: accounts)
        #expect(found?.shortcutID == zip.shortcutID)
    }

    // MARK: - Recordar, Pasarla y el formulario

    @Test func remember_thenMoveFromAnotherAccount() throws {
        let context = try makeContext(freshDir())
        let ibk = account(context, "Interbank Visa", rules: [texto("zip")])
        let zipVisa = account(context, "Zip Visa")
        try context.save()
        let accounts = try context.fetch(FetchDescriptor<Account>())

        let dup = try #require(CuentaSolaReglasStore.repetida(texto("Zip"), destino: zipVisa, among: accounts))
        #expect(dup.account.shortcutID == ibk.shortcutID)

        try CuentaSolaReglasStore.pasar(texto("Zip"), de: ibk, a: zipVisa, context: context)
        #expect(CuentaSolaReglasStore.rules(of: ibk).isEmpty)
        #expect(ibk.captureRulesRaw == nil, "sin reglas el campo vuelve a nil")
        #expect(CuentaSolaReglasStore.rules(of: zipVisa).map(\.value) == ["Zip"])

        try CuentaSolaReglasStore.guardar(texto("ZIP"), en: zipVisa, context: context)
        #expect(CuentaSolaReglasStore.rules(of: zipVisa).count == 1, "la misma regla no se repite")
    }

    @Test func accountForm_savesTheRules_andTakesAMovedOneFromTheOther() throws {
        let context = try makeContext(freshDir())
        let ibk = account(context, "Interbank Visa", rules: [texto("zip"), texto("ibk")])
        let zipVisa = account(context, "Zip Visa")
        try context.save()

        let viewModel = AccountFormViewModel(accountToEdit: zipVisa, existingNames: ["Interbank Visa"])
        viewModel.setContext(context)
        viewModel.allAccounts = try context.fetch(FetchDescriptor<Account>())
        #expect(!viewModel.hasUnsavedChanges)
        let rule = texto("zip")
        let other = try #require(viewModel.captureRuleDuplicate(for: rule))
        #expect(other.shortcutID == ibk.shortcutID)
        viewModel.moveCaptureRule(rule, from: other)
        #expect(viewModel.hasUnsavedChanges, "cerrar ahora tiraría la regla")
        #expect(viewModel.captureRuleDuplicate(for: rule) == nil, "ya movida, no vuelve a preguntar")
        #expect(viewModel.saveAccount(context: context))

        #expect(CuentaSolaReglasStore.rules(of: zipVisa).map(\.value) == ["zip"])
        #expect(CuentaSolaReglasStore.rules(of: ibk).map(\.value) == ["ibk"], "la otra regla de Interbank se queda")
    }

    @Test func rulesDieWithTheirAccount() throws {
        let context = try makeContext(freshDir())
        let zipVisa = account(context, "Zip Visa", rules: [texto("zip")])
        let efectivo = account(context, "Efectivo")
        try context.save()
        context.delete(zipVisa)
        try context.save()
        let left = try context.fetch(FetchDescriptor<Account>())
        #expect(left.map(\.shortcutID) == [efectivo.shortcutID])
        #expect(left.allSatisfy { $0.captureRulesRaw == nil })
        #expect(DraftBuilder.chooseAccount(mention: "zip", last4: nil, currency: nil, in: left).account == nil)
    }

    // MARK: - Modo Nube

    @Test func emission_v9_carriesTheRules_v8_doesNot() throws {
        let context = try makeContext(freshDir())
        let zipVisa = account(context, "Zip Visa", rules: [texto("zip")])
        let emission = EntityEmissionMap.account
        let v9 = DeltaEmitter.emit(model: zipVisa, emission: emission, changedColumns: emission.columns,
                                   hlc: hlc(1), capabilityLevel: 9)
        #expect(v9.fields["capture_rules_raw"] == .string(try #require(zipVisa.captureRulesRaw)))
        let v8 = DeltaEmitter.emit(model: zipVisa, emission: emission, changedColumns: emission.columns,
                                   hlc: hlc(1), capabilityLevel: 8)
        #expect(v8.fields["capture_rules_raw"] == nil)
        #expect(v8.fields["name"] == .string("Zip Visa"), "el resto de la fila sí viaja")
    }

    @Test func drain_v8_notesTheAccount_v9_sendsOnlyTheRules() throws {
        let restoreCapability = isolateCapability(backend: 8)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let zipVisa = account(context, "Zip Visa")
        try context.save()
        engine.drainOnce(context: context)

        CuentaSolaReglasStore.setRules([texto("zip")], on: zipVisa)
        try context.save()
        engine.drainOnce(context: context)
        #expect(try outbox(context).filter { $0.syncID == zipVisa.shortcutID }.count == 1,
                "con v8, cambiar solo las reglas no saca ninguna fila")
        #expect(SyncCapability.suppressedCaptureRules == [zipVisa.shortcutID])

        SyncCapability.defaults.set(9, forKey: SyncCapability.backendManifestVersionKey)
        CuentaSolaReglasStore.setRules([texto("zip"), texto("visa")], on: zipVisa)
        try context.save()
        engine.drainOnce(context: context)
        let update = try #require(try outbox(context).last { $0.syncID == zipVisa.shortcutID })
        #expect(Set(try fields(update).keys) == ["capture_rules_raw"])
        #expect(try fields(update)["capture_rules_raw"] as? String == zipVisa.captureRulesRaw)
    }

    private func page(for account: Account, columns: Set<String>, counter: Int) throws -> PulledPage {
        let emission = EntityEmissionMap.account
        let emitted = DeltaEmitter.emit(model: account, emission: emission, changedColumns: columns, hlc: hlc(counter),
                                        capabilityLevel: 9)
        let fieldsJSON = try Canonc1Codec.encode(emitted.fields, groupedColumns: Set(emission.groupByColumn.keys))
        let hlcs = emitted.fieldHlcs.keys.sorted().map { "\"\($0)\":\"\(hlc(counter))\"" }.joined(separator: ",")
        let delta = """
        {"entity_type":"accounts","sync_id":"\(account.shortcutID.uuidString.lowercased())","op":"upsert",\
        "fields":\(fieldsJSON),"field_hlcs":{\(hlcs)},"hlc":"\(hlc(counter))","server_seq":\(counter),"schema_version":1}
        """
        let json = "{\"deltas\":[\(delta)],\"max_server_seq\":\(counter),\"manifest_version\":9}"
        return try SyncPullClient.decodePage(Data(json.utf8))
    }

    @Test func criterion_rulesSyncBetweenTwoPhones_andRemovingThemToo() throws {
        let restoreCapability = isolateCapability(backend: 9)
        defer { restoreCapability() }
        let phoneA = try makeContext(freshDir())
        let zipVisa = account(phoneA, "Zip Visa", rules: [texto("zip")])
        try phoneA.save()

        let phoneB = try makeContext(freshDir())
        let engineB = CloudSyncEngine()
        #expect(engineB.applyPage(try page(for: zipVisa, columns: EntityEmissionMap.account.columns, counter: 2),
                                  context: phoneB, now: applyNow))
        let arrived = try #require(try phoneB.fetch(FetchDescriptor<Account>()).first {
            $0.shortcutID == zipVisa.shortcutID })
        #expect(CuentaSolaReglasStore.rules(of: arrived).map(\.value) == ["zip"])

        CuentaSolaReglasStore.setRules([], on: zipVisa)
        try phoneA.save()
        #expect(engineB.applyPage(try page(for: zipVisa, columns: ["capture_rules_raw"], counter: 3),
                                  context: phoneB, now: applyNow))
        #expect(arrived.captureRulesRaw == nil, "quitarlas en un teléfono las quita en el otro")
        #expect(arrived.name == "Zip Visa")
    }

    @Test func upgradeToV9_reemitsTheNotedAccount_withOnlyTheRules() throws {
        let restoreCapability = isolateCapability(backend: 8)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let zipVisa = account(context, "Zip Visa")
        try context.save()
        engine.drainOnce(context: context)
        CuentaSolaReglasStore.setRules([texto("zip")], on: zipVisa)
        try context.save()
        engine.drainOnce(context: context)
        for row in try outbox(context) { context.delete(row) }
        try context.save()
        #expect(SyncCapability.suppressedCaptureRules == [zipVisa.shortcutID])

        SyncCapability.defaults.set(8, forKey: SyncCapability.lastDeclaredLevelKey)
        SyncCapability.recordBackendManifestVersion(9)
        #expect(SyncCapability.upgradePending)
        #expect(try engine.applyCapabilityUpgradeIfPending(context: context))

        let reemitted = try #require(try outbox(context).last { $0.syncID == zipVisa.shortcutID })
        #expect(Set(try fields(reemitted).keys) == ["capture_rules_raw"])
        #expect(try fields(reemitted)["capture_rules_raw"] as? String == zipVisa.captureRulesRaw)
        #expect(SyncCapability.suppressedCaptureRules.isEmpty)
    }
}
