//
//  ExportarImportarIdaVueltaTests.swift
//  YalaTests
//
//  Lo que exporta Yala vuelve a entrar sin perder qué es cada fila (H8 de la auditoría del import, 23-nov-2026): el
//  export escribe `kind` y `transfer_id`, el saldo inicial vuelve como saldo inicial (no como un movimiento más), las dos
//  patas de una transferencia vuelven emparejadas también con cambio de moneda y días distintos, y un saldo inicial que
//  ya existe no se pisa.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Exportar e importar ida y vuelta: tipo de fila, pareja de transferencia y saldo inicial", .serialized)
@MainActor
struct ExportarImportarIdaVueltaTests {

    // MARK: - Lógica pura

    @Test("La celda kind se lee con el código del export, sin mayúsculas ni guiones; lo demás no es un tipo")
    func parseKind_readsTheExportCodes() {
        typealias L = ImportRecordFieldsLogic
        #expect(L.parseKind("") == .none)
        #expect(L.parseKind("  ") == .none)
        #expect(L.parseKind("initial_balance") == .kind(.initialBalance))
        #expect(L.parseKind("Initial balance") == .kind(.initialBalance))
        #expect(L.parseKind("initial-balance") == .kind(.initialBalance))
        #expect(L.parseKind("TRANSFER") == .kind(.transfer))
        #expect(L.parseKind("adjustment") == .kind(.adjustment))
        #expect(L.parseKind("expense") == .kind(.expense))
        #expect(L.parseKind("income") == .kind(.income))
        #expect(L.parseKind("receivable") == .kind(.receivable))
        #expect(L.parseKind("gastito") == .invalid)
    }

    @Test("El export escribe el tipo de cada movimiento y la pareja solo en las transferencias")
    func exportKind_andTransferID() {
        typealias L = ImportRecordFieldsLogic
        #expect(L.exportKind(balanceAdjustmentType: nil, isIncome: false) == .expense)
        #expect(L.exportKind(balanceAdjustmentType: nil, isIncome: true) == .income)
        #expect(L.exportKind(balanceAdjustmentType: "transfer", isIncome: false) == .transfer)
        #expect(L.exportKind(balanceAdjustmentType: "adjustment", isIncome: true) == .adjustment)
        #expect(L.exportKind(balanceAdjustmentType: "initial_balance", isIncome: true) == .initialBalance)
        #expect(L.exportKind(balanceAdjustmentType: "receivable", isIncome: true) == .receivable)
        #expect(L.exportTransferID(balanceAdjustmentType: "transfer", transferPairID: "P1") == "P1")
        #expect(L.exportTransferID(balanceAdjustmentType: nil, transferPairID: "P1") == "")
        #expect(L.exportTransferID(balanceAdjustmentType: "transfer", transferPairID: nil) == "")
    }

    @Test("Con transfer_id, dos patas de monedas y días distintos se emparejan; sin él, la heurística no podía")
    func pairing_byTransferID() {
        func leg(_ id: Int, _ day: String, _ amount: Int64, _ currency: String, _ account: String, _ pair: String = "")
            -> ImportTransferPairingLogic.Leg {
            ImportTransferPairingLogic.Leg(
                id: id, day: day, amount: amount, currencyCode: currency, accountKey: account, note: "",
                transferID: pair)
        }
        let withID = [leg(0, "2026-10-10", -3_800_000, "PEN", "a", "P1"), leg(1, "2026-10-11", 1_000_000, "USD", "b", "P1")]
        #expect(ImportTransferPairingLogic.pairs(withID) == [.init(outflow: 0, inflow: 1)])
        // Control: las mismas patas sin la pareja quedan sueltas.
        let withoutID = withID.map { leg($0.id, $0.day, $0.amount, $0.currencyCode, $0.accountKey) }
        #expect(ImportTransferPairingLogic.looseCount(withoutID) == 2)
        // Un id con otra forma no decide: dos patas de la misma cuenta, o una sola, siguen a la heurística.
        let sameAccount = [leg(0, "2026-10-10", -500, "PEN", "a", "P2"), leg(1, "2026-10-10", 500, "PEN", "a", "P2")]
        #expect(ImportTransferPairingLogic.pairs(sameAccount).isEmpty)
        let lone = [leg(0, "2026-10-10", -500, "PEN", "a", "P3"), leg(1, "2026-10-10", 500, "PEN", "b")]
        #expect(ImportTransferPairingLogic.pairs(lone) == [.init(outflow: 0, inflow: 1)])
    }

    // MARK: - Ida y vuelta

    @Test("CSV: el saldo inicial vuelve como saldo inicial y la transferencia PEN → USD vuelve emparejada")
    func csvRoundTrip() async throws {
        try await roundTrip(.csv)
    }

    @Test("Excel: lo mismo")
    func xlsxRoundTrip() async throws {
        try await roundTrip(.xlsx)
    }

    private enum Format { case csv, xlsx }

    private func roundTrip(_ format: Format) async throws {
        let context = try makeTestContext()
        let banco = account("Banco", "PEN", in: context)
        let dolares = account("Dólares", "USD", in: context)
        let comida = category("Comida", isIncome: false, subs: ["Restaurante"], in: context)
        let adjustmentSub = try #require(InitialBalanceService.ensureBalanceAdjustmentSubcategoryExists(context: context))
        let initial = InitialBalanceService.setInitialBalance(
            amount: 500, for: banco, subcategory: adjustmentSub, allTransactions: [], context: context)
        initial.date = Self.local(2026, 10, 1)
        tx(-45.90, "PEN", Self.local(2026, 10, 5), comida, banco, in: context)
        // Una transferencia con cambio de moneda, y la entrada llegó al día siguiente: solo la pareja la une.
        let outSub = try TransferCategoryResolver.outflow(context: context)
        let inSub = try TransferCategoryResolver.inflow(context: context)
        let out = tx(-380, "PEN", Self.local(2026, 10, 10), (try #require(outSub.category), outSub), banco, in: context)
        let into = tx(100, "USD", Self.local(2026, 10, 11), (try #require(inSub.category), inSub), dolares, in: context)
        for leg in [out, into] {
            leg.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer
            leg.transferPairID = "PAR-1"
        }
        _ = InitialBalanceService.createAdjustment(
            targetBalance: 50, currentBalance: 100, for: dolares, subcategory: adjustmentSub,
            date: Self.local(2026, 10, 12), context: context)
        try context.save()

        let transactions = try context.fetch(FetchDescriptor<TransactionItem>())
        let url: URL
        switch format {
        case .csv:
            let data = TransactionsExportService.makeCSVData(transactions: transactions, columns: .default)
            let text = try #require(String(data: data.dropFirst(3), encoding: .utf8))
            #expect(text.split(separator: "\n").first?.hasSuffix(",need,kind,transfer_id") == true)
            // El saldo inicial y el ajuste ya no salen con la categoría vacía.
            let initialLine = try #require(text.split(separator: "\n").first { $0.hasSuffix(",initial_balance,") })
            let categoryCell = initialLine.split(separator: ",", omittingEmptySubsequences: false)[4]
            #expect(!categoryCell.isEmpty)
            url = try write(data, ext: "csv")
        case .xlsx:
            let (headers, rows) = TransactionsExportService.makeExportData(transactions: transactions, columns: .default)
            #expect(Array(headers.suffix(2)) == ["kind", "transfer_id"])
            url = temporaryURL(ext: "xlsx")
            try XLSXWriter.write(to: url, headers: headers, rows: rows)
        }
        defer { remove(url) }

        let fresh = try makeTestContext()
        let result = try await TransactionCSVImportService.importAndSave(in: fresh) {
            try await TransactionCSVImportService.importFile(
                from: url, destination: .accountColumn(allowedNewAccountKeys: nil), in: fresh,
                allowCreatingNewCategories: true, skippingInvalidRows: true)
        }
        #expect(result.failures.isEmpty)
        #expect(result.createdCount == 4)  // gasto, dos patas y el ajuste: el saldo inicial no es un movimiento
        #expect(result.initialBalances.map(\.accountName) == ["Banco"])
        #expect(result.looseTransferCount == 0)
        #expect(!result.ignoredColumns.contains("kind") && !result.ignoredColumns.contains("transfer_id"))

        let back = try fresh.fetch(FetchDescriptor<TransactionItem>())
        let initials = back.filter { $0.balanceAdjustmentType == InitialBalanceService.typeInitialBalance }
        #expect(initials.count == 1)
        let initialBack = try #require(initials.first)
        #expect(initialBack.amount == 500)
        #expect(initialBack.account?.name == "Banco")
        #expect(initialBack.date <= Self.local(2026, 10, 1))
        let bancoAmounts: [Double] = back.filter { $0.account?.name == "Banco" }.map(\.amount)
        let bancoBalance: Double = bancoAmounts.reduce(0, +)
        let expectedBalance: Double = 500 - 45.90 - 380
        #expect(abs(bancoBalance - expectedBalance) < 0.0001)

        let legs = back.filter { $0.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer }
        #expect(legs.count == 2)
        let pairIDs = Set(legs.compactMap(\.transferPairID))
        #expect(pairIDs.count == 1)
        #expect(back.filter { $0.balanceAdjustmentType == InitialBalanceService.typeAdjustment }.map(\.amount) == [-50])
    }

    // MARK: - Un saldo inicial que ya existe

    @Test("Un saldo inicial distinto del que ya tiene la cuenta no se pisa; el mismo no hace nada")
    func existingInitialBalance_isNotOverwritten() async throws {
        let context = try makeTestContext()
        let banco = account("Banco", "PEN", in: context)
        _ = category("Comida", isIncome: false, subs: ["Café"], in: context)
        let adjustmentSub = try #require(InitialBalanceService.ensureBalanceAdjustmentSubcategoryExists(context: context))
        _ = InitialBalanceService.setInitialBalance(
            amount: 200, for: banco, subcategory: adjustmentSub, allTransactions: [], context: context)
        try context.save()

        let result = try await importCSV([
            "date,amount,currency,account,category,subcategory,kind",
            "2026-10-01,500,PEN,Banco,,,initial_balance",
            "2026-10-01,200,PEN,Banco,,,initial_balance",
            "2026-10-02,-10,PEN,Banco,Comida,Café,gastito",
            "2026-10-03,-12,PEN,Banco,Comida,Café,expense",
        ], in: context)

        #expect(result.failures == [
            .initialBalanceConflict(row: 2, account: "Banco"),
            .invalidKind(row: 4, value: "gastito"),
        ])
        #expect(result.createdCount == 1)
        #expect(result.initialBalances.isEmpty)
        #expect(result.duplicateRowNumbers == [3])
        let initials = try context.fetch(FetchDescriptor<TransactionItem>())
            .filter { $0.balanceAdjustmentType == InitialBalanceService.typeInitialBalance }
        #expect(initials.map(\.amount) == [200])
    }

    @Test("Lo que se debe en un grupo (receivable) no entra, como el resto de Grupos")
    func receivable_isAGroupRow() async throws {
        let context = try makeTestContext()
        account("Banco", "PEN", in: context)
        try context.save()
        let result = try await importCSV([
            "date,amount,currency,account,category,subcategory,kind",
            "2026-10-01,30,PEN,Banco,Cobros,Venta,receivable",
        ], in: context)
        #expect(result.failures == [.groupRow(row: 2)])
        #expect(result.createdCount == 0)
    }

    // MARK: - Vista previa y deshacer

    @Test("La vista previa anuncia el saldo inicial y lo quita si su cuenta nueva no se elige")
    func preview_countsInitialBalances() async throws {
        let context = try makeTestContext()
        let url = try write(Data([
            "date,amount,currency,account,category,subcategory,kind",
            "2026-10-01,500,PEN,Caja nueva,,,initial_balance",
        ].joined(separator: "\n").utf8), ext: "csv")
        defer { remove(url) }
        let result = try await TransactionCSVImportService.importFile(
            from: url, destination: .accountColumn(allowedNewAccountKeys: nil), in: context,
            allowCreatingNewCategories: true, skippingInvalidRows: true, insertsTransactions: false)
        let preview = ImportPreviewLogic.make(result: result, existingBillableAccounts: 0)
        #expect(preview.count == 0)
        #expect(preview.initialBalances.count == 1)
        #expect(preview.canImport)
        #expect(preview.newAccounts.map(\.name) == ["Caja nueva"])
        let none = ImportPreviewLogic.applying(chosen: [], to: preview)
        #expect(none.initialBalances.isEmpty)
        #expect(!none.canImport)
    }

    @Test("Deshacer la importación borra también el saldo inicial que fijó y la cuenta que creó")
    func undo_removesTheInitialBalance() async throws {
        let previous = ImportUndoService.fileURL
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("undo-\(UUID().uuidString)")
        ImportUndoService.fileURL = dir.appendingPathComponent("ultimo.json")
        defer {
            ImportUndoService.fileURL = previous
            do { try FileManager.default.removeItem(at: dir) } catch { /* puede no existir */ }
        }
        let context = try makeTestContext()
        let table = try ImportFileReader.parseCSV([
            "date,amount,currency,account,category,subcategory,kind",
            "2026-10-01,500,PEN,Caja nueva,,,initial_balance",
        ].joined(separator: "\n"))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("no-se-lee.csv")
        let result = try await ImportUndoService.importAndRemember(in: context) {
            try await TransactionCSVImportService.importFile(
                from: url, destination: .accountColumn(allowedNewAccountKeys: nil), in: context,
                allowCreatingNewCategories: true, skippingInvalidRows: true, preparedTable: table)
        }
        #expect(result.initialBalances.count == 1)
        #expect(try context.fetchCount(FetchDescriptor<TransactionItem>()) == 1)

        try await ImportUndoService.undo(in: context)
        #expect(try context.fetchCount(FetchDescriptor<TransactionItem>()) == 0)
        #expect(try context.fetch(FetchDescriptor<Account>()).filter { $0.name == "Caja nueva" }.isEmpty)
    }

    // MARK: - Ayudantes

    private func importCSV(_ lines: [String], in context: ModelContext) async throws -> TransactionImportResult {
        let table = try ImportFileReader.parseCSV(lines.joined(separator: "\n"))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("no-se-lee.csv")
        return try await TransactionCSVImportService.importAndSave(in: context) {
            try await TransactionCSVImportService.importFile(
                from: url, destination: .accountColumn(allowedNewAccountKeys: nil), in: context,
                allowCreatingNewCategories: true, skippingInvalidRows: true, skippingDuplicates: true,
                preparedTable: table)
        }
    }

    /// Mediodía de la zona del teléfono, la misma en la que el export escribe fecha y hora.
    private static func local(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? .distantPast
    }

    @discardableResult
    private func account(_ name: String, _ currency: String, in context: ModelContext) -> Account {
        let account = Account(name: name, currencyCode: currency, colorHex: "#6366F1", iconName: "creditcard",
                              type: "General")
        context.insert(account)
        return account
    }

    private func category(_ name: String, isIncome: Bool, subs: [String],
                          in context: ModelContext) -> (Yala.Category, Subcategory) {
        let category = Yala.Category(name: name, colorHex: "#22AA88", isIncome: isIncome)
        context.insert(category)
        var first: Subcategory?
        for name in subs {
            let sub = Subcategory(name: name, category: category)
            context.insert(sub)
            if first == nil { first = sub }
        }
        return (category, first ?? Subcategory(name: "—", category: category))
    }

    @discardableResult
    private func tx(_ amount: Double, _ currency: String, _ date: Date, _ cat: (Yala.Category, Subcategory),
                    _ account: Account, in context: ModelContext) -> TransactionItem {
        let item = TransactionItem(
            date: date, amount: amount, currencyCode: currency, note: nil, category: cat.0, subcategory: cat.1,
            account: account, tags: [], exchangeRate: 1, amountInPreferredCurrency: amount,
            preferredCurrencyCode: currency, isExchangeRateProvisional: false)
        context.insert(item)
        return item
    }

    private func temporaryURL(ext: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("ida-vuelta-\(UUID().uuidString).\(ext)")
    }

    private func write(_ data: Data, ext: String) throws -> URL {
        let url = temporaryURL(ext: ext)
        try data.write(to: url)
        return url
    }

    private func remove(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Issue.record("ExportarImportarIdaVueltaTests: Error: \(error)")
        }
    }
}
