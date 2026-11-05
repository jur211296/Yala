//
//  AccountCurrencyReceiverTests.swift
//  YalaTests / CloudSync
//
//  Card «Cambiar la divisa de una cuenta en un teléfono puede dejar el otro con movimientos en la divisa vieja»
//  (ticket `cloudsync-account-currency-orphans-receiver-history`). Decisión de la sesión del 2026-11-05, opción C:
//  el receptor NO re-expresa su histórico (decisión 2A de Jürgen: «el historial no se toca»); la cifra de la cuenta
//  convierte al pintar las filas que quedaron en la divisa vieja, a la tasa de su fecha, sin escribir nada.
//
//  Lo que fija:
//   - el apply de `accounts.currency_code` en un receptor con histórico propio cambia la divisa de la cuenta y NO toca
//     ningún movimiento (ni importe ni divisa);
//   - la cifra de la cuenta en ese intermedio ya es la de la divisa nueva, y es la MISMA que cuando la fila compartida
//     llega convertida por el emisor (que convierte con la tasa de la fecha de cada fila);
//   - la fila propia que el emisor no conocía se queda en la divisa vieja para siempre y se sigue contando bien;
//   - una divisa fuera del catálogo o una fila sin cuenta se suman tal cual (no se toman por dólares).
//
//  Container ON-DISK temp con los 3 stores (el apply necesita sync-meta) + `.serialized`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSync · el receptor de un cambio de divisa de cuenta", .serialized)
@MainActor
struct AccountCurrencyReceiverTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AccCurrRx-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        retireTestStoreDirectoryLater(dir)
        return dir
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "AR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "AR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "AR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private let node = "0123456789abcdef"
    private let applyNow = Date(timeIntervalSince1970: 1_700_000_100)
    private func hlc(_ counter: Int) -> String {
        "2023-11-14T22:13:20.000Z-\(String(format: "%04x", counter))-\(node)"
    }

    private static let utcDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    /// 1 USD = 4 PEN el día de los movimientos: la conversión es exacta y la cifra, entera.
    private func seedRates(on date: Date, into context: ModelContext) throws {
        context.insert(try ExchangeRate(dateKey: Self.utcDay.string(from: date), base: "USD",
                                        ratesDictionary: ["USD": 1, "PEN": 4]))
    }

    private func page(_ deltas: [String], maxSeq: Int) throws -> PulledPage {
        try SyncPullClient.decodePage(
            Data("{\"deltas\":[\(deltas.joined(separator: ","))],\"max_server_seq\":\(maxSeq),\"manifest_version\":5}".utf8))
    }

    private func movement(_ amount: Double, _ code: String, _ account: Account?, on date: Date) -> TransactionItem {
        TransactionItem(
            date: date, amount: amount, currencyCode: code, note: "", category: nil, subcategory: nil,
            account: account, tags: [], amountInPreferredCurrency: amount, preferredCurrencyCode: code, tagIDs: nil)
    }

    // MARK: - El receptor

    @Test func currencyChangeFromAnotherPhone_leavesTheHistoryUntouched_andTheFigureIsAlreadyInTheNewCurrency() throws {
        let date = aMomentAgoToday()

        // El teléfono A crea la cuenta en soles y la sube; el B la recibe.
        let phoneA = try makeContext(freshDir())
        let savingsA = Account(name: "Ahorros", currencyCode: "PEN", colorHex: "#3D36B3", iconName: "banknote",
                               type: AccountType.general.rawValue)
        phoneA.insert(savingsA)
        try phoneA.save()
        let emission = EntityEmissionMap.account
        let emitted = DeltaEmitter.emit(model: savingsA, emission: emission, changedColumns: emission.columns,
                                        hlc: hlc(1), capabilityLevel: 5)
        let fieldsJSON = try Canonc1Codec.encode(emitted.fields, groupedColumns: Set(emission.groupByColumn.keys))
        let hlcs = emitted.fieldHlcs.keys.sorted().map { "\"\($0)\":\"\(hlc(1))\"" }.joined(separator: ",")
        let syncID = savingsA.shortcutID.uuidString.lowercased()
        let created = "{\"entity_type\":\"accounts\",\"sync_id\":\"\(syncID)\",\"op\":\"upsert\","
            + "\"fields\":\(fieldsJSON),\"field_hlcs\":{\(hlcs)},\"hlc\":\"\(hlc(1))\",\"server_seq\":1,\"schema_version\":1}"

        let phoneB = try makeContext(freshDir())
        #expect(CloudSyncEngine().applyPage(try page([created], maxSeq: 1), context: phoneB, now: applyNow))
        let savings = try #require(try phoneB.fetch(FetchDescriptor<Account>()).first { $0.shortcutID == savingsA.shortcutID })
        #expect(savings.currencyCode == "PEN")

        // Histórico del receptor: una fila que el emisor también tiene y una que solo apuntó el receptor.
        let shared = movement(-400, "PEN", savings, on: date)
        let ownOnly = movement(200, "PEN", savings, on: date)
        phoneB.insert(shared)
        phoneB.insert(ownOnly)
        try seedRates(on: date, into: phoneB)
        try phoneB.save()

        let converter = CurrencyConverter()
        converter.setContext(phoneB)
        #expect(AccountBalanceCalculator.currentBalance(for: savings, allTransactions: [shared, ownOnly],
                                                        converter: converter) == -200,
                "Control: antes del cambio, la cuenta suma en soles.")

        // Llega el cambio de divisa de la cuenta (el emisor convirtió SU histórico y lo sube aparte).
        let currencyChange = "{\"entity_type\":\"accounts\",\"sync_id\":\"\(syncID)\",\"op\":\"upsert\","
            + "\"fields\":{\"currency_code\":\"USD\"},\"field_hlcs\":{\"currency_code\":\"\(hlc(2))\"},"
            + "\"hlc\":\"\(hlc(2))\",\"server_seq\":2,\"schema_version\":1}"
        #expect(CloudSyncEngine().applyPage(try page([currencyChange], maxSeq: 2), context: phoneB, now: applyNow))
        #expect(savings.currencyCode == "USD")

        // El historial no se toca (decisión 2A): ni importe ni divisa.
        let rows = try phoneB.fetch(FetchDescriptor<TransactionItem>())
        #expect(rows.count == 2)
        #expect(Set(rows.map(\.currencyCode)) == ["PEN"])
        #expect(Set(rows.map(\.amount)) == [-400, 200])
        #expect(!phoneB.hasChanges, "El apply no deja nada sucio que se pueda emitir después.")

        // La cifra ya está en dólares: (-400 + 200) / 4. En crudo serían -200 «dólares».
        let during = AccountBalanceCalculator.currentBalance(for: savings, allTransactions: rows, converter: converter)
        #expect(during == -50)
        let batch = AccountBalanceCalculator.batchCalculateBalances(accounts: [savings], transactions: rows,
                                                                    converter: converter)
        #expect(batch[savings.persistentModelID] == -50, "El cálculo por lotes (Panel, widgets) dice lo mismo.")

        // Llega la fila compartida convertida por el emisor, a la tasa de su fecha: la cifra no se mueve.
        shared.amount = -100
        shared.currencyCode = "USD"
        let after = AccountBalanceCalculator.currentBalance(for: savings, allTransactions: rows, converter: converter)
        #expect(after == during)
        #expect(ownOnly.currencyCode == "PEN", "La fila que el emisor no conocía se queda en soles, y cuenta bien.")
    }

    // MARK: - Lo que no se convierte

    @Test func unknownCurrencyOrNoAccount_areSummedAsTheyAre() throws {
        let context = try makeTestContext()
        let date = aMomentAgoToday()
        let account = makeTestAccount(context: context, name: "Dólares", currencyCode: "USD")
        try seedRates(on: date, into: context)
        let unknown = movement(30, "XYZ", account, on: date)
        let empty = movement(5, "", account, on: date)
        let foreign = movement(40, "PEN", account, on: date)
        let loose = movement(7, "PEN", nil, on: date)
        for row in [unknown, empty, foreign, loose] { context.insert(row) }
        try context.save()

        let converter = CurrencyConverter()
        converter.setContext(context)
        // 30 y 5 tal cual (sin tomarlas por dólares ni convertirlas), 40 PEN → 10 USD.
        #expect(AccountBalanceCalculator.currentBalance(transactions: [unknown, empty, foreign],
                                                        converter: converter) == 45)
        // Sin cuenta no hay divisa de destino.
        #expect(AccountBalanceCalculator.currentBalance(transactions: [loose], converter: converter) == 7)
    }

    @Test func recognizedCurrencyCode_isNormalizeWithoutTheDollarFallback() {
        #expect(recognizedCurrencyCode("S/") == "PEN")
        #expect(recognizedCurrencyCode(" usd ") == "USD")
        #expect(recognizedCurrencyCode("eur") == "EUR")
        #expect(recognizedCurrencyCode("") == nil)
        #expect(recognizedCurrencyCode("XYZ") == nil)
        #expect(normalizeCurrencyCode("XYZ") == "USD", "Control: la normalización sí lo toma por dólares.")
    }
}
