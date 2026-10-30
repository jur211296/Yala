//
//  ImportReadingLogicTests.swift
//  YalaTests
//
//  Lógica pura del import 2.2 (S27m): montos por archivo (H1, card jvgc), cabecera por nombre (H4, mnox), filas de
//  Grupos (H5, l2g9), cuenta por fila (H7, 34qe) y la elección de cuentas nuevas con el plan gratuito.
//

import Foundation
import Testing

@testable import Yala

@Suite("Montos del import: separador por archivo y signos")
struct ImportAmountParserTests {

    private func read(_ raw: String, _ file: ImportAmountParser.Separator? = nil, digits: Int = 2)
        -> ImportAmountParser.Reading?
    {
        ImportAmountParser.parse(raw, fileDecimal: file, fractionDigits: digits)
    }

    /// La tabla medida en la auditoría (H1): lo que entraba mal, y lo que ya entraba bien.
    @Test("Sin pistas en el archivo: lo ambiguo entra con la lectura de miles y sale dudoso; lo demás, bien")
    func auditTable_withoutFileEvidence() {
        let cases: [(String, Decimal, Bool)] = [
            ("1,500", 1500, true),
            ("1.500", 1500, true),
            ("-1,234", -1234, true),
            ("1.234.567", 1_234_567, false),
            ("1,234,567", 1_234_567, false),
            ("\u{2212}12.50", Decimal(string: "-12.5")!, false),
            ("\u{2013}12,50", Decimal(string: "-12.5")!, false),
            ("\u{2014}7", -7, false),
            ("1.500,00", 1500, false),
            ("1,500.00", 1500, false),
            ("1 500,00", 1500, false),
            ("1\u{00A0}500,00", 1500, false),
            ("(12.50)", Decimal(string: "-12.5")!, false),
            ("S/ 12.50", Decimal(string: "12.5")!, false),
            ("S/. 12.50", Decimal(string: "12.5")!, false),
            ("12.50 S/.", Decimal(string: "12.5")!, false),
            ("-S/ 3.49", Decimal(string: "-3.49")!, false),
            ("12.50-", Decimal(string: "-12.5")!, false),
            ("+30", 30, false),
            ("0,500", Decimal(string: "0.5")!, false),
            ("1234,567", Decimal(string: "1234.567")!, false),
            ("3.49", Decimal(string: "3.49")!, false),
            ("12", 12, false),
            ("$.50", Decimal(string: "0.5")!, false),
            ("US$ .75", Decimal(string: "0.75")!, false),
            ("S/ (12.50)", Decimal(string: "-12.5")!, false),
            ("(12.50) \u{20AC}", Decimal(string: "-12.5")!, false),
            ("1.500,\u{2013}", 1500, false),
            ("Fr. 50.\u{2013}", 50, false),
            ("1,23,456.78", Decimal(string: "123456.78")!, false),
            ("12.50 PEN", Decimal(string: "12.5")!, false),
        ]
        for (raw, value, doubtful) in cases {
            let reading = read(raw)
            #expect(reading?.value == value, "«\(raw)» entró como \(String(describing: reading?.value))")
            #expect(reading?.isDoubtful == doubtful, "«\(raw)» dudoso: \(String(describing: reading?.isDoubtful))")
        }
    }

    @Test("Lo que no es un importe no entra")
    func notAmounts() {
        for raw in ["", "abc", "1-2", "1.2.3", "--5", "1,23.45", "1.234,5,6", "1.5E3", "12 DR 5"] {
            #expect(read(raw) == nil, "«\(raw)» no debería leerse")
        }
    }

    @Test("El archivo decide: con coma decimal «1,500» es 1,5; con punto decimal es 1500")
    func fileDecides() {
        #expect(read("1.500", .comma) == .init(value: 1500, isDoubtful: false))
        #expect(read("1,500", .dot) == .init(value: 1500, isDoubtful: false))
        #expect(read("1,500", .comma, digits: 3) == .init(value: Decimal(string: "1.5")!, isDoubtful: false))
        // Leído como decimal deja más decimales de los que tiene la moneda: entra, pero dudoso.
        #expect(read("1,500", .comma) == .init(value: Decimal(string: "1.5")!, isDoubtful: true))
        #expect(read("15.990", .dot, digits: 0) == .init(value: Decimal(string: "15.99")!, isDoubtful: true))
        // Una celda que delata su propio decimal no se fuerza a la convención del archivo.
        #expect(read("3.49", .comma)?.value == Decimal(string: "3.49"))
    }

    @Test("Si el archivo se contradice, lo ambiguo sale dudoso aunque gane un separador")
    func contested() {
        let convention = ImportAmountParser.fileConvention(for: ["3.49", "12.50", "1,5"])
        #expect(convention == .init(decimal: .dot, isContested: true))
        #expect(ImportAmountParser.parse("1,500", convention: convention, fractionDigits: 2)
            == .init(value: 1500, isDoubtful: true))
    }

    @Test("Con una moneda de tres decimales la lectura propuesta de «1,500» es 1,5")
    func threeDecimalCurrency() {
        #expect(read("1,500", digits: 3) == .init(value: Decimal(string: "1.5")!, isDoubtful: true))
    }

    @Test("El separador del archivo sale de las celdas que lo delatan, y gana el que más")
    func fileSeparator() {
        #expect(ImportAmountParser.fileDecimalSeparator(for: ["1,500", "3.49", "-20.19"]) == .dot)
        #expect(ImportAmountParser.fileDecimalSeparator(for: ["1.500,00", "1,500"]) == .comma)
        #expect(ImportAmountParser.fileDecimalSeparator(for: ["1,500", "2.000", "12"]) == nil)
        #expect(ImportAmountParser.fileDecimalSeparator(for: ["1.234.567"]) == .comma)
        #expect(ImportAmountParser.fileDecimalSeparator(for: ["3.49", "1,5"]) == nil)
    }

    @Test("Una celda numérica de Excel no pasa por el separador del archivo")
    func numericCell() {
        #expect(ImportAmountParser.parseNumericCell("1500.5") == Decimal(string: "1500.5"))
        #expect(ImportAmountParser.parseNumericCell("-3.49") == Decimal(string: "-3.49"))
        #expect(ImportAmountParser.parseNumericCell("1.5E3") == 1500)
        #expect(ImportAmountParser.parseNumericCell("x") == nil)
    }
}

@Suite("Cabecera por nombre")
struct ImportHeaderTests {

    @Test("En cualquier orden, sin mayúsculas ni espacios; las desconocidas se ignoran y se nombran")
    func byName() throws {
        let header = try ImportHeader.map(
            ["Amount", " DATE ", "currency", "card", "Category", "Sub Category", "subcategory", "Split Total", ""])
        #expect(header.indexByField[.amount] == 0)
        #expect(header.indexByField[.date] == 1)
        #expect(header.indexByField[.subcategory] == 6)
        #expect(header.indexByField[.account] == nil)
        #expect(header.ignoredColumns == ["card", "Sub Category", "Split Total"])
    }

    @Test("Si falta una obligatoria, el error dice cuál")
    func missing() {
        #expect(throws: ImportError.missingColumns(["currency", "subcategory"])) {
            try ImportHeader.map(["date", "amount", "account", "category"])
        }
        let text = ImportError.missingColumns(["currency"]).errorDescription ?? ""
        #expect(text.contains("currency"))
    }

    @Test("Una columna conocida repetida no se elige en silencio")
    func duplicate() {
        #expect(throws: ImportError.duplicateColumn(name: "amount")) {
            try ImportHeader.map(["date", "amount", "currency", "category", "subcategory", "AMOUNT"])
        }
    }

    @Test("El CSV se lee por nombre: columnas reordenadas, extra y con comillas")
    func csvByName() throws {
        let csv = """
            note;category;subcategory;currency;amount;date;card;account
            "Cena; con amigos";Comida;Restaurante;PEN;-45,90;14/10/2026;;Efectivo
            ;Ingresos;Sueldo;USD;"1.500,00";2026-10-01;Visa;Banco
            """
        let table = try ImportFileReader.parseCSV(csv)
        #expect(table.rows.count == 2)
        #expect(table.ignoredColumns == ["card"])
        #expect(table.usesAccountColumn)
        let first = try #require(table.rows.first)
        #expect(first.note == "Cena; con amigos")
        #expect(first.amount == "-45,90")
        #expect(first.account == "Efectivo")
        #expect(first.rowNumber == 2)
    }

    @Test("Una nota con delimitadores sin comillas se recompone solo si es la última columna")
    func noteMerge() throws {
        let last = try ImportFileReader.parseCSV("date,amount,currency,category,subcategory,note\n2026-10-01,-5,PEN,A,B,uno, dos")
        #expect(last.rows.first?.note == "uno, dos")
        let middle = try ImportFileReader.parseCSV("date,amount,note,currency,category,subcategory\n2026-10-01,-5,uno, dos,PEN,A,B")
        #expect(middle.rows.first?.readFailure == .invalidColumnCount(row: 2, expected: 6, found: 7))
    }

    @Test("Un BOM delante de una cabecera entre comillas no la rompe; una fila con celdas de menos no desplaza columnas")
    func bomAndShortRows() throws {
        let table = try ImportFileReader.parseCSV(
            "\u{FEFF}\"date\",\"amount\",\"currency\",\"category\",\"subcategory\",\"tags\",\"note\"\n"
                + "2025-01-01,-50,PEN,Comida,Restaurante,cena con Ana")
        #expect(table.rows.first?.readFailure == .invalidColumnCount(row: 2, expected: 7, found: 6))
    }

    @Test("Sin columna account, o con la columna vacía en todas las filas, el flujo es el de siempre")
    func accountColumnUse() throws {
        let none = try ImportFileReader.parseCSV("date,amount,currency,category,subcategory\n2026-10-01,-5,PEN,A,B")
        #expect(!none.usesAccountColumn)
        let empty = try ImportFileReader.parseCSV("date,amount,currency,account,category,subcategory\n2026-10-01,-5,PEN,,A,B")
        #expect(!empty.usesAccountColumn)
    }
}

@Suite("Filas de Grupos")
@MainActor
struct ImportGroupRowFilterTests {

    @Test("Las subcategorías del puente y las categorías de Grupos se reconocen en varios idiomas; las transferencias no")
    func names() {
        #expect(ImportGroupRowFilter.isGroupRow(category: "Grupos", subcategory: "Liquidación enviada"))
        #expect(ImportGroupRowFilter.isGroupRow(category: "Otra", subcategory: "préstamo a grupos"))
        #expect(ImportGroupRowFilter.isGroupRow(category: "Groups", subcategory: "Lo que sea"))
        #expect(ImportGroupRowFilter.isGroupRow(category: "Cobros de grupos", subcategory: "X"))
        #expect(!ImportGroupRowFilter.isGroupRow(category: "Otros", subcategory: "Transferencia entre cuentas"))
        #expect(!ImportGroupRowFilter.isGroupRow(category: "Otros", subcategory: "Ajustes de saldo"))
        #expect(!ImportGroupRowFilter.isGroupRow(category: "Comida", subcategory: "Restaurante"))
    }

    @Test("La cuenta interna de Grupos se reconoce en cualquier idioma y moneda, también con « (Yala)»")
    func groupAccount() {
        for name in ["Grupos PEN", "groups usd", "Groups USD (Yala)", "Gruppen EUR", "グループ JPY", "  Grupos   MXN "] {
            #expect(ImportGroupRowFilter.isGroupAccountName(name), "«\(name)»")
        }
        for name in ["Grupos", "Grupos de amigos", "Banco PEN", "Grupos PEN 2", ""] {
            #expect(!ImportGroupRowFilter.isGroupAccountName(name), "«\(name)»")
        }
    }
}

@Suite("Cuenta por fila")
@MainActor
struct ImportAccountResolverTests {

    private let efectivo = UUID(), efectivoUSD = UUID(), visa = UUID(), visaUSD = UUID(), vieja = UUID(),
        grupos = UUID(), ahorroA = UUID(), ahorroB = UUID()

    private func resolver() -> ImportAccountResolver {
        ImportAccountResolver(accounts: [
            .init(id: efectivo, name: "Efectivo", currencyCode: "PEN", isArchived: false, isSystem: false, parentID: nil),
            .init(id: efectivoUSD, name: "efectivo", currencyCode: "USD", isArchived: false, isSystem: false, parentID: nil),
            .init(id: visa, name: "Visa", currencyCode: "PEN", isArchived: false, isSystem: false, parentID: nil),
            .init(id: visaUSD, name: "Visa Dólares", currencyCode: "USD", isArchived: false, isSystem: false, parentID: visa),
            .init(id: vieja, name: "Vieja", currencyCode: "PEN", isArchived: true, isSystem: false, parentID: nil),
            .init(id: grupos, name: "Grupos PEN", currencyCode: "PEN", isArchived: false, isSystem: true, parentID: nil),
            .init(id: ahorroA, name: "Ahorro", currencyCode: "EUR", isArchived: false, isSystem: false, parentID: nil),
            .init(id: ahorroB, name: "Ahorro", currencyCode: "EUR", isArchived: false, isSystem: false, parentID: nil),
        ])
    }

    @Test("Por nombre sin mayúsculas; con dos del mismo nombre, la de la moneda de la fila")
    func existing() {
        var r = resolver()
        #expect(r.resolve(name: "  EFECTIVO ", currency: "PEN") == .success(.existing(efectivo)))
        #expect(r.resolve(name: "Efectivo", currency: "USD") == .success(.existing(efectivoUSD)))
    }

    @Test("Una tarjeta con líneas: la línea de la moneda de la fila; sin línea de esa moneda, fuera")
    func card() {
        var r = resolver()
        #expect(r.resolve(name: "visa", currency: "USD") == .success(.existing(visaUSD)))
        #expect(r.resolve(name: "Visa Dólares", currency: "PEN") == .success(.existing(visa)))
        #expect(r.resolve(name: "Visa", currency: "EUR") == .failure(.currencyMismatch(name: "Visa", accountCurrency: "PEN")))
    }

    @Test("Archivadas, la de Grupos, vacías y ambiguas no reciben filas")
    func failures() {
        var r = resolver()
        #expect(r.resolve(name: "vieja", currency: "PEN") == .failure(.unavailable(name: "vieja")))
        #expect(r.resolve(name: "Grupos PEN", currency: "PEN") == .failure(.unavailable(name: "Grupos PEN")))
        #expect(r.resolve(name: "  ", currency: "PEN") == .failure(.empty))
        #expect(r.resolve(name: nil, currency: "PEN") == .failure(.empty))
        #expect(r.resolve(name: "AHORRO", currency: "EUR") == .failure(.ambiguous(name: "AHORRO")))
        #expect(r.resolve(name: "Ahorro", currency: "EUR") == .failure(.ambiguous(name: "Ahorro")))
    }

    @Test("Las tildes no separan cuentas")
    func accents() {
        let id = UUID()
        var r = ImportAccountResolver(accounts: [
            .init(id: id, name: "Crédito BCP", currencyCode: "PEN", isArchived: false, isSystem: false, parentID: nil),
        ])
        #expect(r.resolve(name: "credito  bcp", currency: "PEN") == .success(.existing(id)))
    }

    @Test("Una cuenta nueva se apunta una vez, con la moneda de su primera fila")
    func newAccount() {
        var r = resolver()
        #expect(r.resolve(name: "BCP Sueldo", currency: "PEN") == .success(.new(key: "bcp sueldo")))
        #expect(r.resolve(name: "bcp  sueldo", currency: "PEN") == .success(.new(key: "bcp sueldo")))
        #expect(r.resolve(name: "BCP Sueldo", currency: "USD")
            == .failure(.currencyMismatch(name: "BCP Sueldo", accountCurrency: "PEN")))
        #expect(r.newAccounts == [.init(key: "bcp sueldo", name: "BCP Sueldo", currencyCode: "PEN")])
    }
}

@Suite("Cuentas nuevas y el plan gratuito")
@MainActor
struct ImportNewAccountsChoiceTests {

    private let accounts = [
        ImportNewAccountSummary(key: "a", name: "A", currencyCode: "PEN", rowCount: 5),
        ImportNewAccountSummary(key: "b", name: "B", currencyCode: "USD", rowCount: 10),
        ImportNewAccountSummary(key: "c", name: "C", currencyCode: "EUR", rowCount: 7),
    ]

    @Test("Huecos: sin Pro, el límite menos las que ya hay; con Pro, sin límite")
    func slots() {
        #expect(ImportPreviewLogic.newAccountSlots(isPro: false, existingBillableAccounts: 3) == 1)
        #expect(ImportPreviewLogic.newAccountSlots(isPro: false, existingBillableAccounts: 9) == 0)
        #expect(ImportPreviewLogic.newAccountSlots(isPro: true, existingBillableAccounts: 9) == nil)
    }

    @Test("Si no caben, se preseleccionan las de más filas; si caben o hay Pro, todas")
    func defaults() {
        #expect(ImportPreviewLogic.defaultChosenAccounts(accounts, slots: 2) == ["b", "c"])
        #expect(ImportPreviewLogic.defaultChosenAccounts(accounts, slots: 3) == ["a", "b", "c"])
        #expect(ImportPreviewLogic.defaultChosenAccounts(accounts, slots: nil) == ["a", "b", "c"])
        #expect(ImportPreviewLogic.defaultChosenAccounts(accounts, slots: 0).isEmpty)
        #expect(!ImportPreviewLogic.canChoose("a", chosen: ["b", "c"], slots: 2))
        #expect(ImportPreviewLogic.canChoose("a", chosen: ["b"], slots: 2))
    }

    @Test("Las filas de una cuenta no elegida pasan a no entrar, con su motivo")
    func applying() {
        let day = Date(timeIntervalSince1970: 1_790_000_000)
        func row(_ n: Int, _ key: String?, _ amount: Double) -> ImportPreview.Row {
            .init(date: day, amount: amount, currencyCode: "PEN", categoryName: "X", subcategoryName: "Y",
                  rowNumber: n, newAccountKey: key)
        }
        let rows = [row(2, nil, -10), row(3, "a", -20), row(4, "b", -30)]
        var preview = ImportPreviewLogic.make(
            rows: rows, accountNames: ["Existente", "A", "B"], failures: ["Fila 9: mal"], ignoredFutureCount: 0)
        preview.newAccounts = Array(accounts.prefix(2))
        preview.allRows = rows
        preview.fileFailures = ["Fila 9: mal"]

        let applied = ImportPreviewLogic.applying(chosen: ["b"], to: preview)
        #expect(applied.count == 2)
        #expect(applied.accountNames == ["Existente", "B"])
        #expect(applied.failures.count == 2)
        #expect(applied.failures.last?.contains("3") == true && applied.failures.last?.contains("A") == true)
        #expect(applied.totals.first?.amount == -40)
    }
}
