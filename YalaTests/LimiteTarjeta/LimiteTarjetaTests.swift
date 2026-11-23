//
//  LimiteTarjetaTests.swift
//  YalaTests
//
//  El límite de una tarjeta de crédito (decisión de Jürgen del 22-nov-2026, opción A). Lo que fija:
//   - qué se guarda (`LimiteTarjetaLogica`): vacío, 0, negativo o no finito = sin límite; solo en tarjetas de crédito;
//   - el uso de línea de la hoja (`HojaCuentaTarjetaLogica.usoDeLinea`) con el límite: uso y disponible, sin límite,
//     límite 0, saldo a favor y pasarse del límite;
//   - el formulario: carga el límite guardado, cuenta como cambio y lo guarda, lo cambia y lo borra;
//   - la compatibilidad: una cuenta de antes no tiene límite, y iCloud lo declara en los esquemas de desarrollo;
//   - Modo Nube, `accounts.credit_limit` con `since: 10` (molde de `CuentaSolaAlLeerReglasSyncTests`): con v9 no se
//     emite y se APUNTA; con v10, sí; ida y vuelta entre dos teléfonos; un Worker v9 no lo pisa; la subida reemite.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Lo que se guarda y lo que dice la hoja

@Suite("Límite de la tarjeta · qué se guarda y qué dice la hoja")
@MainActor
struct LimiteTarjetaLogicaTests {

    private let peru = Locale(identifier: "es_PE")
    private let espana = Locale(identifier: "es_ES")

    @Test func normalizado_soloGuardaUnLimiteDeVerdad() {
        #expect(LimiteTarjetaLogica.normalizado(8_000) == 8_000)
        #expect(LimiteTarjetaLogica.normalizado(1_234.567) == 1_234.57, "Se guarda en céntimos.")
        #expect(LimiteTarjetaLogica.normalizado(nil) == nil)
        #expect(LimiteTarjetaLogica.normalizado(0) == nil, "Un 0 es «sin límite», no «sin línea».")
        #expect(LimiteTarjetaLogica.normalizado(-500) == nil)
        #expect(LimiteTarjetaLogica.normalizado(.infinity) == nil)
        #expect(LimiteTarjetaLogica.normalizado(.nan) == nil)
    }

    @Test func desdeTexto_leeElSeparadorDelIdioma() {
        #expect(LimiteTarjetaLogica.desdeTexto("8,000.00", locale: peru) == 8_000)
        #expect(LimiteTarjetaLogica.desdeTexto("8.000,50", locale: espana) == 8_000.5)
        #expect(LimiteTarjetaLogica.desdeTexto("", locale: peru) == nil)
        #expect(LimiteTarjetaLogica.desdeTexto("   ", locale: peru) == nil)
        #expect(LimiteTarjetaLogica.desdeTexto("0", locale: peru) == nil)
    }

    @Test func texto_yVuelta() {
        #expect(LimiteTarjetaLogica.texto(nil, locale: peru) == "")
        #expect(LimiteTarjetaLogica.texto(0, locale: peru) == "")
        let escrito = LimiteTarjetaLogica.texto(8_000, locale: peru)
        #expect(escrito == "8,000.00")
        #expect(LimiteTarjetaLogica.desdeTexto(escrito, locale: peru) == 8_000)
    }

    @Test func paraGuardar_soloEnTarjetasDeCredito() {
        #expect(LimiteTarjetaLogica.paraGuardar(esTarjetaDeCredito: true, texto: "8000", locale: peru) == 8_000)
        #expect(LimiteTarjetaLogica.paraGuardar(esTarjetaDeCredito: false, texto: "8000", locale: peru) == nil,
                "Cambiar el tipo de la cuenta borra el límite, como el día de corte.")
    }

    // El uso de línea con el límite: lo que debes es facturado + por facturar.

    @Test func usoDeLinea_usoYDisponible() throws {
        let uso = try #require(HojaCuentaTarjetaLogica.usoDeLinea(lineas: [(1_240, 386.5)], limite: 8_000))
        #expect(uso.usado == 1_626.5)
        #expect(abs(uso.fraccionUsada - 0.2033125) < 0.000_001)
        #expect(uso.disponible == 6_373.5)
    }

    @Test func usoDeLinea_sinLimite_oLimiteCero_noHayLinea() {
        #expect(HojaCuentaTarjetaLogica.usoDeLinea(lineas: [(1_240, 386.5)], limite: nil) == nil)
        #expect(HojaCuentaTarjetaLogica.usoDeLinea(lineas: [(1_240, 386.5)], limite: 0) == nil)
        #expect(HojaCuentaTarjetaLogica.usoDeLinea(lineas: [(1_240, 386.5)], limite: -1) == nil)
    }

    @Test func usoDeLinea_saldoAFavor_cuentaComoCero() throws {
        let uso = try #require(HojaCuentaTarjetaLogica.usoDeLinea(lineas: [(-200, 0)], limite: 8_000))
        #expect(uso.usado == 0)
        #expect(uso.fraccionUsada == 0)
        #expect(uso.disponible == 8_000, "Un pago de más no agranda la línea.")
    }

    @Test func usoDeLinea_pasarseDelLimite_loDiceTalCual() throws {
        let uso = try #require(HojaCuentaTarjetaLogica.usoDeLinea(lineas: [(8_500, 500)], limite: 8_000))
        #expect(uso.fraccionUsada == 1.125)
        #expect(uso.disponible == 0, "Lo disponible nunca es negativo.")
    }

    @Test func usoDeLinea_conVariasDivisas_noSuma() {
        #expect(HojaCuentaTarjetaLogica.usoDeLinea(lineas: [(1_240, 0), (80, 0)], limite: 8_000) == nil)
    }

    // Compatibilidad hacia atrás.

    @Test func unaCuentaDeAntes_noTieneLimite() {
        let account = Account(name: "Visa", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard.fill",
                              type: AccountType.creditCard.rawValue)
        #expect(account.creditLimit == nil)
    }

    @Test func iCloud_losEsquemasDeDesarrolloDeclaranElCampo() throws {
        for file in ["yala-development.ckdb", "yala_dev-development.ckdb",
                     "yala-production.ckdb", "yala_dev-production.ckdb"] {
            let url = HojaCuentaTarjetaTextosTests.repoRoot().appending(path: "Cloudkit Schemas/\(file)")
            let text = try String(contentsOf: url, encoding: .utf8)
            #expect(text.range(of: #"CD_creditLimit\s+DOUBLE"#, options: .regularExpression) != nil,
                    "\(file) no declara CD_creditLimit DOUBLE.")
        }
        #expect(PersonalCloudKitSchemaParityTests.pendingProductionDeploy["yala-production.ckdb"] == nil,
                "Production ya tiene CD_creditLimit: no debe quedar apuntado como pendiente.")
    }
}

// MARK: - El formulario

@Suite("Límite de la tarjeta · el formulario", .serialized)
@MainActor
struct LimiteTarjetaFormularioTests {

    private func card(_ context: ModelContext, limit: Double? = nil) -> Account {
        let account = Account(name: "Visa", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard.fill",
                              type: AccountType.creditCard.rawValue)
        account.creditLimit = limit
        context.insert(account)
        return account
    }

    @Test func abrir_cargaElLimiteGuardado() throws {
        let context = try makeTestContext()
        let vm = AccountFormViewModel(accountToEdit: card(context, limit: 8_000), existingNames: [])
        #expect(LimiteTarjetaLogica.desdeTexto(vm.creditLimitText) == 8_000)
        let sinLimite = AccountFormViewModel(accountToEdit: card(context), existingNames: [])
        #expect(sinLimite.creditLimitText.isEmpty)
    }

    @Test func ponerCambiarYBorrar_seGuarda() throws {
        let context = try makeTestContext()
        let visa = card(context)
        try context.save()

        let poner = AccountFormViewModel(accountToEdit: visa, existingNames: [])
        poner.setContext(context)
        poner.creditLimitText = LimiteTarjetaLogica.texto(8_000)
        #expect(poner.hasUnsavedChanges, "Escribir el límite es un cambio que cerrar perdería.")
        #expect(poner.saveAccount(context: context))
        #expect(visa.creditLimit == 8_000)

        let cambiar = AccountFormViewModel(accountToEdit: visa, existingNames: [])
        cambiar.setContext(context)
        cambiar.creditLimitText = LimiteTarjetaLogica.texto(2_000)
        #expect(cambiar.saveAccount(context: context))
        #expect(visa.creditLimit == 2_000)

        let borrar = AccountFormViewModel(accountToEdit: visa, existingNames: [])
        borrar.setContext(context)
        borrar.creditLimitText = ""
        #expect(borrar.saveAccount(context: context))
        #expect(visa.creditLimit == nil)
    }

    @Test func cambiarElTipo_borraElLimite() throws {
        let context = try makeTestContext()
        let visa = card(context, limit: 8_000)
        try context.save()
        let vm = AccountFormViewModel(accountToEdit: visa, existingNames: [])
        vm.setContext(context)
        vm.selectedType = .checking
        #expect(vm.saveAccount(context: context))
        #expect(visa.creditLimit == nil)
    }
}

// MARK: - Modo Nube

@Suite("Límite de la tarjeta · Modo Nube (credit_limit, v10)", .serialized)
@MainActor
struct LimiteTarjetaSyncTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LimiteTarjeta-\(UUID().uuidString)", isDirectory: true)
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
            "LT-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "LT-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "LT-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
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
    private func visa(_ context: ModelContext, limit: Double? = nil) -> Account {
        let account = Account(name: "Visa QA", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard",
                              type: AccountType.creditCard.rawValue)
        account.creditLimit = limit
        context.insert(account)
        return account
    }

    private func outbox(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    private func fields(_ row: SyncOutbox) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(row.fieldsJSON.utf8)) as? [String: Any] ?? [:]
    }

    @Test func capability_v10_estrenaLaColumna() {
        #expect(SyncCapability.creditLimitSince == 10)
        #expect(SyncCapability.clientManifestVersion >= SyncCapability.creditLimitSince)
        #expect(EntityEmissionMap.account.columns.contains("credit_limit"))
    }

    @Test func emission_v10_llevaElLimite_v9_no() throws {
        let context = try makeContext(freshDir())
        let account = visa(context, limit: 8_000)
        let emission = EntityEmissionMap.account
        let v10 = DeltaEmitter.emit(model: account, emission: emission, changedColumns: emission.columns,
                                    hlc: hlc(1), capabilityLevel: 10)
        #expect(v10.fields["credit_limit"] == .money(8_000))
        let v9 = DeltaEmitter.emit(model: account, emission: emission, changedColumns: emission.columns,
                                   hlc: hlc(1), capabilityLevel: 9)
        #expect(v9.fields["credit_limit"] == nil)
        #expect(v9.fields["name"] == .string("Visa QA"), "el resto de la fila sí viaja")
        let sinLimite = DeltaEmitter.emit(model: visa(context), emission: emission, changedColumns: emission.columns,
                                          hlc: hlc(2), capabilityLevel: 10)
        #expect(sinLimite.fields["credit_limit"] == .null, "Sin límite viaja NULL, como la columna nace en el servidor.")
    }

    @Test func drain_v9_apuntaLaCuenta_v10_mandaSoloElLimite() throws {
        let restoreCapability = isolateCapability(backend: 9)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let account = visa(context)
        try context.save()
        engine.drainOnce(context: context)

        account.creditLimit = 8_000
        try context.save()
        engine.drainOnce(context: context)
        #expect(try outbox(context).filter { $0.syncID == account.shortcutID }.count == 1,
                "con v9, cambiar solo el límite no saca ninguna fila")
        #expect(SyncCapability.suppressedCreditLimits == [account.shortcutID])

        SyncCapability.defaults.set(10, forKey: SyncCapability.backendManifestVersionKey)
        account.creditLimit = 9_000
        try context.save()
        engine.drainOnce(context: context)
        let update = try #require(try outbox(context).last { $0.syncID == account.shortcutID })
        #expect(Set(try fields(update).keys) == ["credit_limit"])
    }

    private func page(for account: Account, columns: Set<String>, counter: Int, level: Int = 10) throws -> PulledPage {
        let emission = EntityEmissionMap.account
        let emitted = DeltaEmitter.emit(model: account, emission: emission, changedColumns: columns, hlc: hlc(counter),
                                        capabilityLevel: level)
        let fieldsJSON = try Canonc1Codec.encode(emitted.fields, groupedColumns: Set(emission.groupByColumn.keys))
        let hlcs = emitted.fieldHlcs.keys.sorted().map { "\"\($0)\":\"\(hlc(counter))\"" }.joined(separator: ",")
        let delta = """
        {"entity_type":"accounts","sync_id":"\(account.shortcutID.uuidString.lowercased())","op":"upsert",\
        "fields":\(fieldsJSON),"field_hlcs":{\(hlcs)},"hlc":"\(hlc(counter))","server_seq":\(counter),"schema_version":1}
        """
        let json = "{\"deltas\":[\(delta)],\"max_server_seq\":\(counter),\"manifest_version\":\(level)}"
        return try SyncPullClient.decodePage(Data(json.utf8))
    }

    @Test func criterio_elLimiteViajaEntreDosTelefonos_yBorrarloTambien() throws {
        let restoreCapability = isolateCapability(backend: 10)
        defer { restoreCapability() }
        let phoneA = try makeContext(freshDir())
        let account = visa(phoneA, limit: 8_000)
        try phoneA.save()

        let phoneB = try makeContext(freshDir())
        let engineB = CloudSyncEngine()
        #expect(engineB.applyPage(try page(for: account, columns: EntityEmissionMap.account.columns, counter: 2),
                                  context: phoneB, now: applyNow))
        let arrived = try #require(try phoneB.fetch(FetchDescriptor<Account>()).first {
            $0.shortcutID == account.shortcutID })
        #expect(arrived.creditLimit == 8_000)

        account.creditLimit = 2_500.5
        try phoneA.save()
        #expect(engineB.applyPage(try page(for: account, columns: ["credit_limit"], counter: 3),
                                  context: phoneB, now: applyNow))
        #expect(arrived.creditLimit == 2_500.5, "cambiarlo en un teléfono lo cambia en el otro")

        account.creditLimit = nil
        try phoneA.save()
        #expect(engineB.applyPage(try page(for: account, columns: ["credit_limit"], counter: 4),
                                  context: phoneB, now: applyNow))
        #expect(arrived.creditLimit == nil, "borrarlo en un teléfono lo borra en el otro")
        #expect(arrived.name == "Visa QA")
    }

    /// Un Worker o un teléfono que aún hablan v9 no conocen la columna: lo que bajan no pisa el límite de aquí.
    @Test func compatibilidad_unaFilaSinLaColumna_noBorraElLimite() throws {
        let restoreCapability = isolateCapability(backend: 9)
        defer { restoreCapability() }
        let phoneA = try makeContext(freshDir())
        let remote = visa(phoneA)
        remote.name = "Visa QA renombrada"
        try phoneA.save()

        let phoneB = try makeContext(freshDir())
        let engineB = CloudSyncEngine()
        let local = Account(name: "Visa QA", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard",
                            type: AccountType.creditCard.rawValue)
        local.shortcutID = remote.shortcutID
        local.creditLimit = 8_000
        phoneB.insert(local)
        try phoneB.save()
        #expect(engineB.applyPage(try page(for: remote, columns: EntityEmissionMap.account.columns, counter: 2, level: 9),
                                  context: phoneB, now: applyNow))
        #expect(local.name == "Visa QA renombrada", "el cambio de la otra versión sí llega")
        #expect(local.creditLimit == 8_000, "y el límite, que esa versión no conoce, se queda")
    }

    @Test func subirAv10_reemiteLaCuentaApuntada_soloConElLimite() throws {
        let restoreCapability = isolateCapability(backend: 9)
        defer { restoreCapability() }
        let context = try makeContext(freshDir())
        let engine = CloudSyncEngine()
        let account = visa(context)
        try context.save()
        engine.drainOnce(context: context)
        account.creditLimit = 8_000
        try context.save()
        engine.drainOnce(context: context)
        for row in try outbox(context) { context.delete(row) }
        try context.save()
        #expect(SyncCapability.suppressedCreditLimits == [account.shortcutID])

        SyncCapability.defaults.set(9, forKey: SyncCapability.lastDeclaredLevelKey)
        SyncCapability.recordBackendManifestVersion(10)
        #expect(SyncCapability.upgradePending)
        #expect(try engine.applyCapabilityUpgradeIfPending(context: context))

        let reemitted = try #require(try outbox(context).last { $0.syncID == account.shortcutID })
        #expect(Set(try fields(reemitted).keys) == ["credit_limit"])
        #expect(SyncCapability.suppressedCreditLimits.isEmpty)
    }
}
