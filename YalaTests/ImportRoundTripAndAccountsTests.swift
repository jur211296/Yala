//
//  ImportRoundTripAndAccountsTests.swift
//  YalaTests
//
//  El import 2.2 de punta a punta (S27m): el CSV y el Excel que exporta Yala vuelven a entrar (H4), las patas del puente
//  de Grupos no (H5), un Excel con el texto dentro de la celda se abre (H3), cada fila va a la cuenta que nombra y las
//  que no existen se crean (H7), y los importes dudosos salen en la vista previa (H1).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Import de punta a punta: ida y vuelta, Grupos, Excel en línea y cuentas por fila", .serialized)
@MainActor
struct ImportRoundTripAndAccountsTests {

    // MARK: - Ida y vuelta del export

    @Test("El CSV exportado con las columnas por defecto vuelve a entrar: cuentas, cifras y sin las patas de Grupos")
    func csvRoundTrip_defaultColumns() async throws {
        try await roundTrip(format: .csv)
    }

    @Test("El Excel exportado con las columnas por defecto vuelve a entrar igual")
    func xlsxRoundTrip_defaultColumns() async throws {
        try await roundTrip(format: .xlsx)
    }

    private enum Format { case csv, xlsx }

    private func roundTrip(format: Format) async throws {
        let context = try makeTestContext()
        let banco = account("Banco", "PEN", in: context)
        let dolares = account("Dólares", "USD", in: context)
        let comida = category("Comida", isIncome: false, subs: ["Restaurante"], in: context)
        let ingresos = category("Ingresos", isIncome: true, subs: ["Sueldo"], in: context)
        let grupos = category("Cobros de grupos", isIncome: true, subs: ["Préstamo a grupos"], isSystem: true, in: context)

        let day = Self.day(2026, 10, 10)
        tx(-45.90, "PEN", day, comida, banco, in: context)
        tx(-1234.56, "PEN", day, comida, banco, note: "Cena, con \"amigos\"", in: context)
        tx(3000, "PEN", day, ingresos, banco, in: context)
        tx(-20, "USD", day, comida, dolares, in: context)
        tx(120, "PEN", day, grupos, banco, in: context)  // la pata del puente: no vuelve
        try context.save()

        let transactions = try context.fetch(FetchDescriptor<TransactionItem>())
        let url: URL
        switch format {
        case .csv:
            let data = TransactionsExportService.makeCSVData(transactions: transactions, columns: .default)
            url = try write(data, ext: "csv")
        case .xlsx:
            let (headers, rows) = TransactionsExportService.makeExportData(transactions: transactions, columns: .default)
            url = temporaryURL(ext: "xlsx")
            try XLSXWriter.write(to: url, headers: headers, rows: rows)
        }
        defer { remove(url) }

        // A un teléfono vacío: las cuentas se crean desde el archivo.
        let fresh = try makeTestContext()
        let result = try await TransactionCSVImportService.importAndSave(in: fresh) {
            try await TransactionCSVImportService.importFile(
                from: url, destination: .accountColumn(allowedNewAccountKeys: nil), in: fresh,
                allowCreatingNewCategories: true, skippingInvalidRows: true)
        }

        #expect(result.createdCount == 4)
        #expect(result.groupRowCount == 1)
        #expect(result.failures.count == 1)
        #expect(result.ignoredColumns.contains("split_total") && result.ignoredColumns.contains("split_portion"))
        #expect(result.newAccounts.map(\.name).sorted() == ["Banco", "Dólares"])

        let accounts = try fresh.fetch(FetchDescriptor<Account>())
        let bancoNuevo = try #require(accounts.first { $0.name == "Banco" })
        let dolaresNuevo = try #require(accounts.first { $0.name == "Dólares" })
        #expect(bancoNuevo.currencyCode == "PEN" && dolaresNuevo.currencyCode == "USD")
        let imported = try fresh.fetch(FetchDescriptor<TransactionItem>())
        #expect(sum(imported, in: bancoNuevo) == Decimal(string: "1719.54"))
        #expect(sum(imported, in: dolaresNuevo) == -20)
        #expect(imported.contains { $0.note == "Cena, con \"amigos\"" })
        #expect(!imported.contains { $0.category?.name == "Cobros de grupos" })
        let categories = try fresh.fetch(FetchDescriptor<Yala.Category>())
        #expect(!categories.contains { ImportGroupRowFilter.isGroupRow(category: $0.name, subcategory: "") },
                "La fila de Grupos no crea su categoría.")
    }

    @Test("Con las columnas reordenadas y una cuenta que ya existe en otra mayúscula, cada fila va a su cuenta")
    func reorderedColumns_existingAccountByName() async throws {
        let context = try makeTestContext()
        let efectivo = account("Efectivo", "PEN", in: context)
        try context.save()
        let csv = """
            Note,Subcategory,Category,Account,Currency,Amount,Date,split_portion
            ,Restaurante,Comida,  EFECTIVO ,PEN,-10.00,2026-10-01,
            ,Restaurante,Comida,efectivo,PEN,-5.50,2026-10-02,50 %
            """
        let url = try write(Data(csv.utf8), ext: "csv")
        defer { remove(url) }

        let result = try await TransactionCSVImportService.importAndSave(in: context) {
            try await TransactionCSVImportService.importFile(
                from: url, destination: .accountColumn(allowedNewAccountKeys: nil), in: context,
                allowCreatingNewCategories: true, skippingInvalidRows: true)
        }
        #expect(result.createdCount == 2)
        #expect(result.newAccounts.isEmpty)
        let accounts = try context.fetch(FetchDescriptor<Account>())
        #expect(accounts.count == 1)
        let imported = try context.fetch(FetchDescriptor<TransactionItem>())
        #expect(sum(imported, in: efectivo) == Decimal(string: "-15.5"))
    }

    // MARK: - Cuentas por fila

    @Test("Tarjeta con líneas, cuenta nueva, archivada, vacía y moneda que no casa: cada fila con su desenlace")
    func accountColumn_outcomes() async throws {
        let context = try makeTestContext()
        let visa = account("Visa", "PEN", in: context)
        let visaUSD = account("Visa USD", "USD", in: context)
        visaUSD.parentAccountID = visa.shortcutID
        let vieja = account("Vieja", "PEN", in: context)
        vieja.isArchived = true
        try context.save()

        let csv = """
            date,amount,currency,account,category,subcategory
            2026-10-01,-10,PEN,visa,Comida,Restaurante
            2026-10-01,-7,USD,Visa,Comida,Restaurante
            2026-10-01,-3,PEN,Nueva Cuenta,Comida,Restaurante
            2026-10-02,-4,PEN,nueva cuenta,Comida,Restaurante
            2026-10-02,-4,USD,Nueva Cuenta,Comida,Restaurante
            2026-10-02,-1,PEN,Vieja,Comida,Restaurante
            2026-10-02,-1,PEN,,Comida,Restaurante
            2026-10-02,-1,EUR,Visa,Comida,Restaurante
            2026-10-02,-1,PEN,Visa,Grupos,Liquidación enviada
            """
        let url = try write(Data(csv.utf8), ext: "csv")
        defer { remove(url) }

        let result = try await TransactionCSVImportService.importAndSave(in: context) {
            try await TransactionCSVImportService.importFile(
                from: url, destination: .accountColumn(allowedNewAccountKeys: nil), in: context,
                allowCreatingNewCategories: true, skippingInvalidRows: true)
        }

        #expect(result.createdCount == 4)
        #expect(result.failures == [
            .namedAccountCurrencyMismatch(row: 6, name: "Nueva Cuenta", fileCurrency: "USD", accountCurrency: "PEN"),
            .accountUnavailable(row: 7, name: "Vieja"),
            .emptyAccount(row: 8),
            .namedAccountCurrencyMismatch(row: 9, name: "Visa", fileCurrency: "EUR", accountCurrency: "PEN"),
            .groupRow(row: 10),
        ])
        let imported = try context.fetch(FetchDescriptor<TransactionItem>())
        #expect(sum(imported, in: visa) == -10)
        #expect(sum(imported, in: visaUSD) == -7)
        let nueva = try #require(try context.fetch(FetchDescriptor<Account>()).first { $0.name == "Nueva Cuenta" })
        #expect(nueva.currencyCode == "PEN")
        #expect(sum(imported, in: nueva) == -7)
        #expect(!imported.contains { $0.account?.persistentModelID == vieja.persistentModelID })
    }

    @Test("Las filas de la cuenta de Grupos no entran; las futuras no cuentan como no elegidas; una fila que no entra no crea su categoría")
    func accountColumn_groupAccountFutureAndNoOrphanCategories() async throws {
        let context = try makeTestContext()
        try context.save()
        let csv = """
            date,amount,currency,account,category,subcategory,tags
            2026-10-01,-10,PEN,Grupos PEN,Comida,Restaurante,
            2026-10-01,-5,PEN,Efectivo,Comida,Restaurante,
            2099-01-01,-7,PEN,Futura,Comida,Restaurante,
            2026-10-02,-1,PEN,,Huérfana,Sin cuenta,etiqueta-huerfana
            """
        let url = try write(Data(csv.utf8), ext: "csv")
        defer { remove(url) }

        let result = try await TransactionCSVImportService.importAndSave(in: context) {
            try await TransactionCSVImportService.importFile(
                from: url, destination: .accountColumn(allowedNewAccountKeys: ["efectivo"]), in: context,
                allowCreatingNewCategories: true, skippingInvalidRows: true)
        }
        #expect(result.createdCount == 1)
        #expect(result.failures == [.groupRow(row: 2), .emptyAccount(row: 5)])
        #expect(result.ignoredFutureDatesCount == 1)
        #expect(result.notChosenAccounts.isEmpty)
        #expect(try context.fetch(FetchDescriptor<Account>()).map(\.name) == ["Efectivo"])
        let categories = try context.fetch(FetchDescriptor<Yala.Category>()).map(\.name)
        #expect(!categories.contains("Huérfana"))
        #expect(try context.fetch(FetchDescriptor<Yala.Tag>()).isEmpty)
    }

    @Test("Una cuenta nueva no elegida (plan gratuito) no se crea y sus filas no entran, con su motivo")
    func accountColumn_notChosenAccountIsNotCreated() async throws {
        let context = try makeTestContext()
        try context.save()
        let csv = """
            date,amount,currency,account,category,subcategory
            2026-10-01,-10,PEN,Uno,Comida,Restaurante
            2026-10-01,-7,PEN,Dos,Comida,Restaurante
            """
        let url = try write(Data(csv.utf8), ext: "csv")
        defer { remove(url) }

        let result = try await TransactionCSVImportService.importAndSave(in: context) {
            try await TransactionCSVImportService.importFile(
                from: url, destination: .accountColumn(allowedNewAccountKeys: ["uno"]), in: context,
                allowCreatingNewCategories: true, skippingInvalidRows: true)
        }
        #expect(result.createdCount == 1)
        #expect(result.failures == [.newAccountNotChosen(row: 3, name: "Dos")])
        #expect(try context.fetch(FetchDescriptor<Account>()).map(\.name) == ["Uno"])
    }

    // MARK: - La vista previa

    @Test("La vista previa cuenta las cuentas nuevas, los importes dudosos, las columnas ignoradas y las filas de Grupos")
    func preview_reportsEverything() async throws {
        let context = try makeTestContext()
        _ = account("Banco", "PEN", in: context)
        try context.save()
        let csv = """
            date,amount,currency,account,category,subcategory,card
            2026-10-01,"1,500",PEN,Banco,Ingresos,Sueldo,
            2026-10-01,−12.50,PEN,Banco,Comida,Restaurante,
            2026-10-01,-3,USD,Viaje,Comida,Restaurante,
            2026-10-01,-3,PEN,Banco,Grupos,Préstamo a grupos,
            """
        let url = try write(Data(csv.utf8), ext: "csv")
        defer { remove(url) }

        let preview = try await ImportPreviewService.preview(
            of: url, target: .accountColumn(allowedNewAccountKeys: nil), allowCreatingNewCategories: true,
            container: context.container)

        #expect(preview.count == 3)
        #expect(preview.groupRowCount == 1)
        #expect(preview.ignoredColumns == ["card"])
        #expect(preview.newAccounts == [.init(key: "viaje", name: "Viaje", currencyCode: "USD", rowCount: 1)])
        #expect(preview.existingBillableAccounts == 1)
        // «1,500» con la convención del archivo: «−12.50» delata el punto decimal, así que «1,500» es 1500, sin duda.
        #expect(preview.doubtfulAmounts.isEmpty)
        #expect(preview.totals.first { $0.currencyCode == "PEN" }?.amount == 1487.5)
        #expect(try context.fetch(FetchDescriptor<TransactionItem>()).isEmpty, "La vista previa no guarda nada.")
    }

    @Test("Un «1,500» sin pistas en el archivo entra con la lectura de miles y sale como dudoso")
    func preview_doubtfulAmount() async throws {
        let context = try makeTestContext()
        let banco = account("Banco", "PEN", in: context)
        try context.save()
        let csv = "date,amount,currency,category,subcategory\n2026-10-01,\"1,500\",PEN,Ingresos,Sueldo\n2026-10-01,-20,PEN,Comida,Restaurante"
        let url = try write(Data(csv.utf8), ext: "csv")
        defer { remove(url) }

        let preview = try await ImportPreviewService.preview(
            of: url, target: .single(banco), allowCreatingNewCategories: true, container: context.container)
        #expect(preview.doubtfulAmounts == [.init(rowNumber: 2, raw: "1,500", amount: 1500, currencyCode: "PEN")])
        #expect(preview.count == 2)
    }

    // MARK: - Excel con el texto dentro de la celda

    @Test("Un Excel sin tabla compartida, con portada y columnas en otro orden, se lee y se importa")
    func xlsxInlineStrings() async throws {
        let cover = Self.sheet(rows: [[("A1", .inline("Resumen del año"))]])
        let data = Self.sheet(rows: [
            [("A1", .inline("Category")), ("B1", .inline("amount")), ("C1", .inline("DATE")),
             ("D1", .inline("subcategory")), ("E1", .inline("currency")), ("F1", .inline("account"))],
            [("A2", .inline("Comida")), ("B2", .inline("−1.234,56")), ("C2", .number("46296")),
             ("D2", .inline("Restaurante")), ("E2", .inline("PEN")), ("F2", .inline("Caja"))],
            [("A3", .inline("Ingresos")), ("B3", .number("2500.5")), ("C3", .inline("2026-10-02")),
             ("D3", .inline("Sueldo")), ("E3", .inline("PEN")), ("F3", .inline("Caja"))],
        ])
        let url = temporaryURL(ext: "xlsx")
        try Self.writeXLSX(sheets: [cover, data], to: url)
        defer { remove(url) }

        let table = try XLSXReader.readTable(from: url)
        #expect(table.rows.count == 2)
        #expect(table.usesAccountColumn)
        #expect(table.rows.first?.date == "2026-10-01", "El número de serie se convierte en la columna date.")
        #expect(table.rows.last?.amountIsNumber == true)

        let context = try makeTestContext()
        try context.save()
        let result = try await TransactionCSVImportService.importAndSave(in: context) {
            try await TransactionCSVImportService.importFile(
                from: url, destination: .accountColumn(allowedNewAccountKeys: nil), in: context,
                allowCreatingNewCategories: true, skippingInvalidRows: true)
        }
        #expect(result.failures.isEmpty)
        #expect(result.createdCount == 2)
        let caja = try #require(try context.fetch(FetchDescriptor<Account>()).first)
        // «−1.234,56» lleva coma decimal; el 2500.5 numérico no pasa por esa convención.
        #expect(sum(try context.fetch(FetchDescriptor<TransactionItem>()), in: caja) == Decimal(string: "1265.94"))
    }

    @Test("Con varias hojas con movimientos se lee la primera pestaña y la vista previa nombra las demás")
    func xlsxSeveralDataSheets() throws {
        func data(_ amount: String) -> String {
            Self.sheet(rows: [
                [("A1", .inline("date")), ("B1", .inline("amount")), ("C1", .inline("currency")),
                 ("D1", .inline("category")), ("E1", .inline("subcategory"))],
                [("A2", .inline("2026-10-01")), ("B2", .inline(amount)), ("C2", .inline("PEN")),
                 ("D2", .inline("Comida")), ("E2", .inline("Restaurante"))],
            ])
        }
        let url = temporaryURL(ext: "xlsx")
        try Self.writeXLSX(sheets: [data("-1"), data("-2"), data("-3")], to: url)
        defer { remove(url) }
        let table = try XLSXReader.readTable(from: url)
        #expect(table.rows.map(\.amount) == ["-1"])
        #expect(table.readSheet == "Hoja1")
        #expect(table.skippedSheets == ["Hoja2", "Hoja3"])
    }

    @Test("Un Excel sin ninguna hoja con cabecera reconocible dice qué columnas faltan")
    func xlsxWithoutRecognizableHeader() throws {
        let url = temporaryURL(ext: "xlsx")
        try Self.writeXLSX(sheets: [Self.sheet(rows: [[("A1", .inline("fecha")), ("B1", .inline("monto"))]])], to: url)
        defer { remove(url) }
        #expect(throws: ImportError.missingColumns(["date", "amount", "currency", "category", "subcategory"])) {
            try XLSXReader.readTable(from: url)
        }
    }

    // MARK: - Fixture

    private static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? .distantPast
    }

    @discardableResult
    private func account(_ name: String, _ currency: String, in context: ModelContext) -> Account {
        let account = Account(name: name, currencyCode: currency, colorHex: "#6366F1", iconName: "creditcard",
                              type: "General")
        context.insert(account)
        return account
    }

    private func category(_ name: String, isIncome: Bool, subs: [String], isSystem: Bool = false,
                          in context: ModelContext) -> (Yala.Category, Subcategory) {
        let category = Yala.Category(name: name, colorHex: "#22AA88", isIncome: isIncome, isSystem: isSystem)
        context.insert(category)
        var first: Subcategory?
        for name in subs {
            let sub = Subcategory(name: name, isSystem: isSystem, category: category)
            context.insert(sub)
            if first == nil { first = sub }
        }
        return (category, first ?? Subcategory(name: "—", category: category))
    }

    private func tx(_ amount: Double, _ currency: String, _ date: Date, _ cat: (Yala.Category, Subcategory),
                    _ account: Account, note: String? = nil, in context: ModelContext) {
        let item = TransactionItem(
            date: date, amount: amount, currencyCode: currency, note: note, category: cat.0, subcategory: cat.1,
            account: account, tags: [], exchangeRate: 1, amountInPreferredCurrency: amount,
            preferredCurrencyCode: currency, isExchangeRateProvisional: false)
        context.insert(item)
    }

    private func sum(_ items: [TransactionItem], in account: Account) -> Decimal {
        items.filter { $0.account?.persistentModelID == account.persistentModelID }
            .reduce(Decimal(0)) { $0 + Decimal(string: String(format: "%.2f", $1.amount))! }
    }

    private func temporaryURL(ext: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("import-s27m-\(UUID().uuidString).\(ext)")
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
            Issue.record("ImportRoundTripAndAccountsTests: Error: \(error)")
        }
    }

    // MARK: - Un .xlsx mínimo, como lo escribe openpyxl: texto en la celda y sin sharedStrings.xml

    private enum CellValue {
        case inline(String)
        case number(String)
    }

    private static func sheet(rows: [[(String, CellValue)]]) -> String {
        func escape(_ s: String) -> String {
            s.replacing("&", with: "&amp;").replacing("<", with: "&lt;").replacing(">", with: "&gt;")
        }
        var xml = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>"#
        for (index, cells) in rows.enumerated() {
            xml += #"<row r="\#(index + 1)">"#
            for (ref, value) in cells {
                switch value {
                case .inline(let text): xml += #"<c r="\#(ref)" t="inlineStr"><is><t>\#(escape(text))</t></is></c>"#
                case .number(let raw): xml += #"<c r="\#(ref)" t="n"><v>\#(raw)</v></c>"#
                }
            }
            xml += "</row>"
        }
        return xml + "</sheetData></worksheet>"
    }

    private static func writeXLSX(sheets: [String], to url: URL) throws {
        let ns = "http://schemas.openxmlformats.org"
        var entries: [(String, String)] = []
        let overrides = sheets.indices.map {
            #"<Override PartName="/xl/worksheets/sheet\#($0 + 1).xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>"#
        }.joined()
        entries.append(("[Content_Types].xml", #"<?xml version="1.0" encoding="UTF-8"?><Types xmlns="\#(ns)/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\#(overrides)</Types>"#))
        entries.append(("_rels/.rels", #"<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="\#(ns)/package/2006/relationships"><Relationship Id="rId1" Type="\#(ns)/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>"#))
        let sheetTags = sheets.indices.map { #"<sheet name="Hoja\#($0 + 1)" sheetId="\#($0 + 1)" r:id="rId\#($0 + 1)"/>"# }.joined()
        entries.append(("xl/workbook.xml", #"<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="\#(ns)/spreadsheetml/2006/main" xmlns:r="\#(ns)/officeDocument/2006/relationships"><sheets>\#(sheetTags)</sheets></workbook>"#))
        let rels = sheets.indices.map {
            #"<Relationship Id="rId\#($0 + 1)" Type="\#(ns)/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet\#($0 + 1).xml"/>"#
        }.joined()
        entries.append(("xl/_rels/workbook.xml.rels", #"<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="\#(ns)/package/2006/relationships">\#(rels)</Relationships>"#))
        for (index, sheet) in sheets.enumerated() {
            entries.append(("xl/worksheets/sheet\(index + 1).xml", sheet))
        }
        try StoredZip.archive(entries.map { ($0.0, Data($0.1.utf8)) }).write(to: url)
    }
}

/// Un ZIP sin comprimir (método «stored»): basta para que CoreXLSX lea un .xlsx, y no hace falta enlazar ZIPFoundation
/// al target de tests.
enum StoredZip {
    static func archive(_ files: [(String, Data)]) -> Data {
        var body = Data()
        var central = Data()
        for (name, data) in files {
            let nameData = Data(name.utf8)
            let crc = crc32(data)
            let offset = UInt32(body.count)
            body.append(le32(0x04034b50)); body.append(le16(20)); body.append(le16(0)); body.append(le16(0))
            body.append(le16(0)); body.append(le16(0x21))
            body.append(le32(crc)); body.append(le32(UInt32(data.count))); body.append(le32(UInt32(data.count)))
            body.append(le16(UInt16(nameData.count))); body.append(le16(0))
            body.append(nameData); body.append(data)

            central.append(le32(0x02014b50)); central.append(le16(20)); central.append(le16(20)); central.append(le16(0))
            central.append(le16(0)); central.append(le16(0)); central.append(le16(0x21))
            central.append(le32(crc)); central.append(le32(UInt32(data.count))); central.append(le32(UInt32(data.count)))
            central.append(le16(UInt16(nameData.count))); central.append(le16(0)); central.append(le16(0))
            central.append(le16(0)); central.append(le16(0)); central.append(le32(0)); central.append(le32(offset))
            central.append(nameData)
        }
        var end = Data()
        end.append(le32(0x06054b50)); end.append(le16(0)); end.append(le16(0))
        end.append(le16(UInt16(files.count))); end.append(le16(UInt16(files.count)))
        end.append(le32(UInt32(central.count))); end.append(le32(UInt32(body.count))); end.append(le16(0))
        return body + central + end
    }

    private static func le16(_ v: UInt16) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
    private static func le32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }

    private static let table: [UInt32] = (0..<256).map { n in
        var c = UInt32(n)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
        return c
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data { crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
        return crc ^ 0xFFFF_FFFF
    }
}
