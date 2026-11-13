//
//  ImportExportFidelityTests.swift
//  YalaTests
//
//  Exportar e importar sin perder datos, de punta a punta (encargo del 2026-11-12):
//  - la hora, la tasa de cambio fija y la necesidad cambiada a mano vuelven tras la ida y vuelta (H18, card xx0g), y un
//    archivo de antes, sin esas columnas, entra como siempre;
//  - un CSV con una comilla suelta y una línea sin separador entra entero y la línea se cuenta (H13, card 6gh7);
//  - los montos con miles, el signo «−» y lo dudoso salen igual por las cuatro rutas (H1, card jvgc).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Exportar e importar sin perder datos", .serialized)
@MainActor
struct ImportExportFidelityTests {

    // MARK: - H18 · Ida y vuelta

    @Test("CSV: la hora, la tasa fija y la necesidad vuelven iguales; lo que no las tenía, sigue sin ellas")
    func csvRoundTrip_keepsTimeRateAndNeed() async throws {
        try await roundTrip(.csv)
    }

    @Test("Excel: la hora, la tasa fija y la necesidad vuelven iguales")
    func xlsxRoundTrip_keepsTimeRateAndNeed() async throws {
        try await roundTrip(.xlsx)
    }

    private enum Format { case csv, xlsx }

    private func roundTrip(_ format: Format) async throws {
        let preferred = CurrencyDefaults.currentPreferred
        let foreign = preferred == "USD" ? "EUR" : "USD"
        let context = try makeTestContext()
        let local = account("Banco", preferred, in: context)
        let abroad = account("Afuera", foreign, in: context)
        let food = category("Comida", isIncome: false, subs: ["Restaurante"], need: .priority, in: context)

        // Un gasto a las 21:47:13 con la naturaleza cambiada a «opcional».
        let evening = try localDate(2026, 10, 10, 21, 47, 13)
        let dinner = tx(-45.90, preferred, evening, food, local, in: context)
        dinner.needOverride = SubcategoryNeed.optional.rawValue
        // Un gasto en otra moneda con la tasa escrita a mano (3,80): su importe convertido es -76.
        let morning = try localDate(2026, 10, 11, 8, 5, 0)
        let trip = tx(-20, foreign, morning, food, abroad, in: context)
        trip.exchangeRate = 3.8
        trip.amountInPreferredCurrency = -76
        trip.preferredCurrencyCode = preferred
        trip.isExchangeRateProvisional = false
        // Uno en otra moneda con la tasa PROVISIONAL: no se exporta, se vuelve a convertir.
        let provisional = tx(-5, foreign, morning, food, abroad, in: context)
        provisional.exchangeRate = 99
        provisional.preferredCurrencyCode = preferred
        provisional.isExchangeRateProvisional = true
        try context.save()

        let transactions = try context.fetch(FetchDescriptor<TransactionItem>())
        let url: URL
        switch format {
        case .csv:
            let data = TransactionsExportService.makeCSVData(transactions: transactions, columns: .default)
            #expect(data.starts(with: [0xEF, 0xBB, 0xBF]))
            let text = try #require(String(data: data.dropFirst(3), encoding: .utf8))
            let header = try #require(text.split(separator: "\n").first)
            // Las columnas de siempre en su sitio y las nuevas al final.
            #expect(header.hasPrefix("date,amount,currency,account,category,subcategory,tags,note"))
            #expect(header.hasSuffix(",time,exchange_rate,rate_currency,need"))
            url = try write(data, ext: "csv")
        case .xlsx:
            let (headers, rows) = TransactionsExportService.makeExportData(transactions: transactions, columns: .default)
            #expect(Array(headers.suffix(4)) == ["time", "exchange_rate", "rate_currency", "need"])
            #expect(rows.allSatisfy { $0.count == headers.count })
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
        #expect(result.createdCount == 3)
        #expect(!result.ignoredColumns.contains("time") && !result.ignoredColumns.contains("need"))
        #expect(!result.ignoredColumns.contains("exchange_rate") && !result.ignoredColumns.contains("rate_currency"))

        let back = try fresh.fetch(FetchDescriptor<TransactionItem>())
        let dinnerBack = try #require(back.first { $0.currencyCode == preferred })
        #expect(dinnerBack.date == evening)
        #expect(dinnerBack.needOverride == SubcategoryNeed.optional.rawValue)
        #expect(dinnerBack.effectiveNeed == .optional)

        let tripBack = try #require(back.first { $0.currencyCode == foreign && $0.amount == -20 })
        #expect(tripBack.date == morning)
        #expect(tripBack.exchangeRate == 3.8)
        #expect(abs(tripBack.amountInPreferredCurrency - -76) < 0.0001)
        #expect(tripBack.isExchangeRateProvisional == false)
        #expect(tripBack.needOverride == nil)  // sin cambio a mano: la de su subcategoría, como antes

        let provisionalBack = try #require(back.first { $0.currencyCode == foreign && $0.amount == -5 })
        #expect(provisionalBack.exchangeRate != 99)  // la tasa provisional no viaja como fija
    }

    @Test("Un archivo de antes, sin las columnas nuevas, entra como siempre: al mediodía, con la tasa del día y sin cambio de necesidad")
    func oldFile_importsAsBefore() async throws {
        let context = try makeTestContext()
        account("Banco", "PEN", in: context)
        _ = category("Comida", isIncome: false, subs: ["Restaurante"], in: context)
        try context.save()
        let csv = "date,amount,currency,account,category,subcategory,tags,note\n2026-10-10,-45.90,PEN,Banco,Comida,Restaurante,,\n"
        let url = try write(Data(csv.utf8), ext: "csv")
        defer { remove(url) }

        let result = try await TransactionCSVImportService.importAndSave(in: context) {
            try await TransactionCSVImportService.importFile(
                from: url, destination: .accountColumn(allowedNewAccountKeys: nil), in: context,
                allowCreatingNewCategories: true, skippingInvalidRows: true)
        }
        #expect(result.createdCount == 1 && result.failures.isEmpty)
        let item = try #require(try context.fetch(FetchDescriptor<TransactionItem>()).first)
        #expect(item.date == Self.noonUTC(2026, 10, 10))
        #expect(item.needOverride == nil)
    }

    @Test("Una hora, una tasa o una necesidad que no se entienden dejan la fila fuera con su motivo; las demás entran")
    func badOptionalValues_areReportedNotDropped() async throws {
        let context = try makeTestContext()
        account("Banco", "PEN", in: context)
        _ = category("Comida", isIncome: false, subs: ["Restaurante"], in: context)
        try context.save()
        let csv = """
            date,amount,currency,account,category,subcategory,time,exchange_rate,rate_currency,need
            2026-10-10,-1,PEN,Banco,Comida,Restaurante,25:99,,,
            2026-10-10,-2,USD,Banco,Comida,Restaurante,,cero,PEN,
            2026-10-10,-3,PEN,Banco,Comida,Restaurante,,,,urgente
            2026-10-10,-4,PEN,Banco,Comida,Restaurante,10:00,,,essential
            """
        let url = try write(Data(csv.utf8), ext: "csv")
        defer { remove(url) }

        let result = try await TransactionCSVImportService.importAndSave(in: context) {
            try await TransactionCSVImportService.importFile(
                from: url, destination: .accountColumn(allowedNewAccountKeys: nil), in: context,
                allowCreatingNewCategories: true, skippingInvalidRows: true)
        }
        #expect(result.createdCount == 1)
        #expect(result.failures == [
            .invalidTime(row: 2, value: "25:99"),
            .invalidExchangeRate(row: 3, value: "cero"),
            .invalidNeed(row: 4, value: "urgente"),
        ])
        for failure in result.failures {
            #expect(failure.errorDescription?.contains("import.error") == false)
        }
        // La fila mala no deja nada creado por el camino.
        let items = try context.fetch(FetchDescriptor<TransactionItem>())
        #expect(items.count == 1 && items.first?.needOverride == SubcategoryNeed.essential.rawValue)
    }

    // MARK: - H13 · De punta a punta

    @Test("Un CSV con una comilla suelta y un total al final: entran las cuatro filas y el total sale como no leído")
    func strayQuoteAndTotal_endToEnd() async throws {
        let context = try makeTestContext()
        let banco = account("Banco", "PEN", in: context)
        _ = category("Hogar", isIncome: false, subs: ["Electrónica"], in: context)
        _ = category("Comida", isIncome: false, subs: ["Restaurante"], in: context)
        try context.save()
        let csv = """
            date,amount,currency,category,subcategory,note
            2026-10-01,-10,PEN,Hogar,Electrónica,Tele de 50" nueva
            2026-10-02,-20,PEN,Comida,Restaurante,Cena
            2026-10-03,-30,PEN,Comida,Restaurante,Almuerzo
            2026-10-04,-40,PEN,Comida,Restaurante,Desayuno
            Total -100
            """
        let url = try write(Data(csv.utf8), ext: "csv")
        defer { remove(url) }

        let result = try await TransactionCSVImportService.importAndSave(in: context) {
            try await TransactionCSVImportService.importCSV(
                from: url, into: banco, in: context, allowCreatingNewCategories: false, skippingInvalidRows: true)
        }
        #expect(result.createdCount == 4)
        #expect(result.failures == [.unreadableRow(row: 6)])
        let notes = try context.fetch(FetchDescriptor<TransactionItem>()).compactMap(\.note).sorted()
        #expect(notes == ["Almuerzo", "Cena", "Desayuno", "Tele de 50\" nueva"])
    }

    // MARK: - H1 · Las cuatro rutas

    @Test("Miles, «−» y lo dudoso salen igual por las cuatro rutas: CSV y Excel, una cuenta y varias monedas")
    func amounts_sameInTheFourRoutes() async throws {
        let rows = [
            ["2026-10-01", "1,500", "PEN", "Comida", "Restaurante"],
            ["2026-10-02", "\u{2212}12.50", "PEN", "Comida", "Restaurante"],
            ["2026-10-03", "1.234.567", "PEN", "Comida", "Restaurante"],
        ]
        let headers = ["date", "amount", "currency", "category", "subcategory"]
        // En el CSV, «1,500» va entre comillas: si no, su coma parte la celda.
        let csv = ([headers] + rows).map { row in
            row.map { $0.contains(",") ? "\"\($0)\"" : $0 }.joined(separator: ",")
        }.joined(separator: "\n")

        for route in 0..<4 {
            let context = try makeTestContext()
            let banco = account("Banco", "PEN", in: context)
            _ = category("Comida", isIncome: false, subs: ["Restaurante"], in: context)
            try context.save()
            let isExcel = route >= 2
            let url: URL
            if isExcel {
                url = temporaryURL(ext: "xlsx")
                try XLSXWriter.write(to: url, headers: headers, rows: rows)
            } else {
                url = try write(Data(csv.utf8), ext: "csv")
            }
            defer { remove(url) }

            let result = try await TransactionCSVImportService.importAndSave(in: context) {
                switch route {
                case 0:
                    try await TransactionCSVImportService.importCSV(
                        from: url, into: banco, in: context, allowCreatingNewCategories: false, skippingInvalidRows: true)
                case 1:
                    try await TransactionCSVImportService.importCSVMultiCurrency(
                        from: url, currencyAccountMap: ["PEN": banco], in: context, allowCreatingNewCategories: false,
                        skippingInvalidRows: true)
                case 2:
                    try await TransactionCSVImportService.importXLSX(
                        from: url, into: banco, in: context, allowCreatingNewCategories: false, skippingInvalidRows: true)
                default:
                    try await TransactionCSVImportService.importXLSXMultiCurrency(
                        from: url, currencyAccountMap: ["PEN": banco], in: context, allowCreatingNewCategories: false,
                        skippingInvalidRows: true)
                }
            }
            #expect(result.createdCount == 3, "ruta \(route)")
            #expect(result.doubtfulAmounts.map(\.rowNumber) == [2], "ruta \(route)")
            let amounts = try context.fetch(FetchDescriptor<TransactionItem>()).map(\.amount).sorted()
            #expect(amounts == [-12.5, 1500, 1_234_567], "ruta \(route)")
        }
    }

    // MARK: - Fixture

    private static func noonUTC(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? .distantPast
    }

    /// Una fecha y hora en la zona del teléfono, la misma en la que el export escribe la hora.
    private func localDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int, _ s: Int) throws -> Date {
        let calendar = Calendar(identifier: .gregorian)
        return try #require(calendar.date(from: DateComponents(
            timeZone: .current, year: y, month: m, day: d, hour: h, minute: min, second: s)))
    }

    @discardableResult
    private func account(_ name: String, _ currency: String, in context: ModelContext) -> Account {
        let account = Account(name: name, currencyCode: currency, colorHex: "#6366F1", iconName: "creditcard",
                              type: "General")
        context.insert(account)
        return account
    }

    private func category(_ name: String, isIncome: Bool, subs: [String], need: SubcategoryNeed? = nil,
                          in context: ModelContext) -> (Yala.Category, Subcategory) {
        let category = Yala.Category(name: name, colorHex: "#22AA88", isIncome: isIncome)
        context.insert(category)
        var first: Subcategory?
        for name in subs {
            let sub = Subcategory(name: name, natureRawValue: need?.rawValue, category: category)
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
        FileManager.default.temporaryDirectory.appendingPathComponent("import-fidelity-\(UUID().uuidString).\(ext)")
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
            Issue.record("ImportExportFidelityTests: Error: \(error)")
        }
    }
}
