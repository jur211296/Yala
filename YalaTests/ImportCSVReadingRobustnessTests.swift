//
//  ImportCSVReadingRobustnessTests.swift
//  YalaTests
//
//  Leer un CSV sin perder filas (H13 de la auditoría del import, card 6gh7) y leer la hora, la tasa fija y la naturaleza
//  de un registro (H18, card xx0g). Lógica pura: sin contexto de SwiftData.
//

import Foundation
import Testing

@testable import Yala

@Suite("CSV sin filas perdidas: comillas sueltas, líneas sin separador, codificaciones y tabulador")
struct ImportCSVReadingRobustnessTests {

    private let header = "date,amount,currency,category,subcategory,note"

    @Test("Una comilla suelta en mitad de una nota no se traga las filas siguientes")
    func strayQuote_keepsEveryRow() throws {
        let csv = """
            \(header)
            2026-10-01,-10,PEN,Hogar,Electrónica,Tele de 50" nueva
            2026-10-02,-20,PEN,Comida,Restaurante,Cena
            2026-10-03,-30,PEN,Comida,Restaurante,Almuerzo
            2026-10-04,-40,PEN,Comida,Restaurante,Desayuno
            """
        let table = try ImportFileReader.parseCSV(csv)
        #expect(table.rows.count == 4)
        #expect(table.rows.allSatisfy { $0.readFailure == nil })
        #expect(table.rows.map(\.amount) == ["-10", "-20", "-30", "-40"])
        #expect(table.rows.first?.note == "Tele de 50\" nueva")
        #expect(table.rows.last?.note == "Desayuno")

        // Dos notas que acaban en comilla de pulgadas: una comilla en mitad del campo no abre nada.
        let inches = try ImportFileReader.parseCSV("""
            \(header)
            2026-10-01,-10,PEN,Hogar,Electrónica,Tele 50"
            2026-10-02,-20,PEN,Hogar,Electrónica,Monitor 27"
            2026-10-03,-30,PEN,Comida,Restaurante,Cena
            """)
        #expect(inches.rows.map(\.amount) == ["-10", "-20", "-30"])
        #expect(inches.rows.map(\.note) == ["Tele 50\"", "Monitor 27\"", "Cena"])
    }

    @Test("La partición en filas solo abre comillas al principio de un campo; entre comillas, el salto de línea sigue dentro")
    func rowSplit_quoteOpensOnlyAtFieldStart() {
        let rows = TransactionCSVImportService.splitCSVRows(
            "a,b\n1,Tele de 50\" nueva\n2,\"uno\ndos\"\n3, \"con espacio\"\n4,\"comilla \"\"doble\"\"\"\n", delimiter: ",")
        #expect(rows.map(\.text) == [
            "a,b", "1,Tele de 50\" nueva", "2,\"uno\ndos\"", "3, \"con espacio\"", "4,\"comilla \"\"doble\"\"\"",
        ])
        // La fila del salto de línea empieza en la línea 3 y la siguiente, en la 5.
        #expect(rows.map(\.line) == [1, 2, 3, 5, 6])
    }

    @Test("Una comilla de apertura sin cierre no se lleva el resto del archivo")
    func unterminatedQuote_doesNotSwallowTheRest() throws {
        // En la nota, la última columna: la fila entra con lo que hay detrás de la comilla.
        let inNote = try ImportFileReader.parseCSV("""
            \(header)
            2026-10-01,-10,PEN,Comida,Restaurante,"sin cerrar
            2026-10-02,-20,PEN,Comida,Restaurante,Cena
            2026-10-03,-30,PEN,Comida,Restaurante,Almuerzo
            """)
        #expect(inNote.rows.map(\.amount) == ["-10", "-20", "-30"])
        #expect(inNote.rows.allSatisfy { $0.readFailure == nil })
        #expect(inNote.rows[0].note == "sin cerrar")
        // En medio de la fila: esa fila sale como no leída, con su número, y las demás entran.
        let inMiddle = try ImportFileReader.parseCSV("""
            \(header)
            2026-10-01,"-10,PEN,Comida,Restaurante,Tele
            2026-10-02,-20,PEN,Comida,Restaurante,Cena
            2026-10-03,-30,PEN,Comida,Restaurante,Almuerzo
            """)
        #expect(inMiddle.rows.count == 3)
        #expect(inMiddle.rows[0].readFailure != nil && inMiddle.rows[0].rowNumber == 2)
        #expect(inMiddle.rows[1].amount == "-20" && inMiddle.rows[1].readFailure == nil)
        #expect(inMiddle.rows[2].amount == "-30" && inMiddle.rows[2].rowNumber == 4)
    }

    @Test("Una comilla sin cerrar no se empareja con la comilla de apertura de otra fila más abajo")
    func unterminatedQuote_doesNotPairWithALaterRow() throws {
        let table = try ImportFileReader.parseCSV("""
            \(header)
            2026-10-01,-10,PEN,Comida,Restaurante,"sin cerrar
            2026-10-02,-20,PEN,Comida,Restaurante,Cena
            2026-10-03,-30,PEN,Comida,Restaurante,"Pan, leche"
            2026-10-04,-40,PEN,Comida,Restaurante,Desayuno
            """)
        #expect(table.rows.map(\.amount) == ["-10", "-20", "-30", "-40"])
        #expect(table.rows.map(\.rowNumber) == [2, 3, 4, 5])
        #expect(table.rows.allSatisfy { $0.readFailure == nil })
        #expect(table.rows.map(\.note) == ["sin cerrar", "Cena", "Pan, leche", "Desayuno"])
        // Un campo entre comillas con salto de línea, bien cerrado, sigue siendo una sola fila.
        let multiline = try ImportFileReader.parseCSV("\(header)\n2026-10-01,-10,PEN,Comida,Restaurante,\"uno\ndos\"\n2026-10-02,-20,PEN,Comida,Restaurante,x")
        #expect(multiline.rows.map(\.note) == ["uno\ndos", "x"])
        #expect(multiline.rows.map(\.rowNumber) == [2, 4])
    }

    @Test("Un archivo UTF-8 con un byte roto se sigue leyendo como UTF-8: las demás tildes no se rompen")
    func mostlyUTF8_withOneBadByte() throws {
        var data = Data("\(header)\n2026-10-01,-12.50,PEN,Alimentación,Café,ok\n".utf8)
        data.append(contentsOf: [0x32, 0x30, 0xFF, 0x0A])  // un byte que no es UTF-8 en una línea suelta
        let text = try #require(ImportFileReader.decodeText(data))
        #expect(text.contains("Alimentación"))
        #expect(!ImportFileReader.containsMultibyteUTF8(try #require("Señor Pérez".data(using: .windowsCP1252))))
    }

    @Test("Una línea con texto y sin separador se cuenta como no leída, con el número de línea que ve la persona")
    func lineWithoutDelimiter_isCountedWithItsLineNumber() throws {
        let csv = "\(header)\n\n2026-10-01,-10,PEN,Comida,Restaurante,Cena\nTotal del mes\n\n,,,,,\n2026-10-02,-20,PEN,Comida,Restaurante,\n"
        let table = try ImportFileReader.parseCSV(csv)
        #expect(table.rows.count == 3)
        #expect(table.rows[0].rowNumber == 3)  // la línea en blanco de la 2 ya no desplaza el número
        let unread = try #require(table.rows.first { $0.readFailure != nil })
        #expect(unread.readFailure == .unreadableRow(row: 4))
        #expect(unread.readFailure?.rowNumber == 4)
        #expect(table.rows[2].rowNumber == 7)  // la fila de solo separadores (6) se salta: está vacía
        let message = try #require(ImportError.unreadableRow(row: 4).errorDescription)
        #expect(message.contains("4"))
        #expect(!message.contains("import.error"))
    }

    @Test("Un CSV de Excel en Windows (Windows-1252) se lee con sus tildes")
    func windows1252() throws {
        let text = "\(header)\n2026-10-01,-12.50,PEN,Alimentación,Café,Señor Pérez\n"
        let data = try #require(text.data(using: .windowsCP1252))
        #expect(String(data: data, encoding: .utf8) == nil)  // no es UTF-8 válido: antes no se abría
        let url = try write(data)
        defer { remove(url) }
        let table = try ImportFileReader.readCSV(from: url)
        #expect(table.rows.count == 1)
        #expect(table.rows[0].category == "Alimentación")
        #expect(table.rows[0].subcategory == "Café")
        #expect(table.rows[0].note == "Señor Pérez")
    }

    @Test("UTF-16 con BOM («texto Unicode» de Excel) y UTF-8 siguen leyéndose")
    func utf16AndUtf8() throws {
        let text = "\(header)\n2026-10-01,-12.50,PEN,Alimentación,Café,ñ\n"
        var utf16 = Data([0xFF, 0xFE])
        utf16.append(try #require(text.data(using: .utf16LittleEndian)))
        #expect(ImportFileReader.decodeText(utf16)?.contains("Alimentación") == true)
        var utf8 = Data([0xEF, 0xBB, 0xBF])
        utf8.append(Data(text.utf8))
        let url = try write(utf8)
        defer { remove(url) }
        let table = try ImportFileReader.readCSV(from: url)
        #expect(table.rows.first?.subcategory == "Café")
    }

    @Test("Separado por tabuladores: se detecta, y una celda vacía al principio o al final no desplaza columnas")
    func tabSeparated() throws {
        #expect(TransactionCSVImportService.detectDelimiter(from: "date\tamount\tcurrency") == "\t")
        #expect(TransactionCSVImportService.detectDelimiter(from: "date;amount;currency") == ";")
        #expect(TransactionCSVImportService.detectDelimiter(from: "date,amount,currency") == ",")
        let csv = "note\tdate\tamount\tcurrency\tcategory\tsubcategory\ttags\n"
            + "\t2026-10-01\t-1,500.00\tPEN\tComida\tRestaurante\t\n"
            + "Con, coma\t2026-10-02\t-20\tPEN\tComida\tRestaurante\tviaje\n"
        let table = try ImportFileReader.parseCSV(csv)
        #expect(table.rows.count == 2)
        #expect(table.rows.allSatisfy { $0.readFailure == nil })
        #expect(table.rows[0].note == "" && table.rows[0].date == "2026-10-01" && table.rows[0].amount == "-1,500.00")
        #expect(table.rows[1].note == "Con, coma" && table.rows[1].tags == "viaje")
    }

    // MARK: - Ayudantes

    private func write(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("import-h13-\(UUID().uuidString).csv")
        try data.write(to: url)
        return url
    }

    private func remove(_ url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Issue.record("ImportCSVReadingRobustnessTests: Error: \(error)")
        }
    }
}

@Suite("Hora, tasa fija y necesidad de un registro en el archivo")
struct ImportRecordFieldsLogicTests {

    private typealias L = ImportRecordFieldsLogic

    @Test("La hora se lee en sus formas habituales y lo que no es una hora no pasa")
    func parseTime() {
        #expect(L.parseTime("14:30") == .init(hour: 14, minute: 30, second: 0))
        #expect(L.parseTime("09:05:07") == .init(hour: 9, minute: 5, second: 7))
        #expect(L.parseTime("9:05:07.250") == .init(hour: 9, minute: 5, second: 7))
        #expect(L.parseTime("2:30 PM") == .init(hour: 14, minute: 30, second: 0))
        #expect(L.parseTime("12:10 a. m.") == .init(hour: 0, minute: 10, second: 0))
        #expect(L.parseTime("12:10 p.m.") == .init(hour: 12, minute: 10, second: 0))
        #expect(L.parseTime("14:30:00Z")?.timeZone == TimeZone(secondsFromGMT: 0))
        #expect(L.parseTime("14:30:00-05:00")?.timeZone == TimeZone(secondsFromGMT: -5 * 3600))
        for bad in ["", "25:00", "14:60", "14", "a las dos", "13:00 PM", "1.5", "14:3", "-1:00", "0.30", "0", "12:00 XM"] {
            #expect(L.parseTime(bad) == nil, "\(bad)")
        }
        #expect(L.timeInDateCell("2026-10-01") == nil)
        #expect(L.timeInDateCell("2026-10-01 18:45") == .init(hour: 18, minute: 45, second: 0))
        #expect(L.timeInDateCell("2026-10-01T18:45:10") == .init(hour: 18, minute: 45, second: 10))
    }

    @Test("La hora se pone sobre el día que leyó el import, en la zona del teléfono o en la que trae")
    func combine() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let noonUTC = try #require(utc.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 12)))
        let lima = try #require(TimeZone(identifier: "America/Lima"))
        let combined = try #require(L.combine(day: noonUTC, time: .init(hour: 23, minute: 15, second: 5), localTimeZone: lima))
        var limaCalendar = Calendar(identifier: .gregorian)
        limaCalendar.timeZone = lima
        let parts = limaCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: combined)
        #expect(parts == DateComponents(year: 2026, month: 10, day: 1, hour: 23, minute: 15, second: 5))
        let zoned = try #require(L.combine(
            day: noonUTC, time: .init(hour: 8, minute: 0, second: 0, timeZone: TimeZone(secondsFromGMT: 0)),
            localTimeZone: lima))
        #expect(utc.component(.hour, from: zoned) == 8)
    }

    @Test("La tasa: mayor que cero; lo ambiguo solo con la convención del archivo; nada de letras ni notación rara")
    func parseRate() {
        #expect(L.parseRate("3.75") == 3.75)
        #expect(L.parseRate(" 3,75 ") == 3.75)
        #expect(L.parseRate("0.000063") == 0.000063)
        #expect(L.parseRate("1,350.5") == 1350.5)
        // «1,350» o «3.751» sin más pistas: 1350 o 1,35 — no se adivina una tasa fija.
        #expect(L.parseRate("1,350") == nil)
        #expect(L.parseRate("3.751") == nil)
        let dot = ImportAmountParser.FileConvention(decimal: .dot, isContested: false)
        let comma = ImportAmountParser.FileConvention(decimal: .comma, isContested: false)
        #expect(L.parseRate("1,350", convention: dot) == 1350)
        #expect(L.parseRate("3.751", convention: dot) == 3.751)
        #expect(L.parseRate("4.000", convention: comma) == 4000)
        // Excel: un número en forma canónica, también con exponente.
        #expect(L.parseRate("3.93E-05", isNumber: true) == 0.0000393)
        for bad in ["", "0", "-3.75", "abc", "1.2.3", "inf", "nan", "3e2", "0x10", "."] {
            #expect(L.parseRate(bad, convention: dot) == nil, "\(bad)")
        }
    }

    @Test("Una hora que Excel guardó como número llega como texto: «0» es medianoche y la fecha delante no cuenta")
    func excelTime() {
        #expect(XLSXReader.excelTimeText(0) == "00:00:00")
        #expect(XLSXReader.excelTimeText(0.5) == "12:00:00")
        #expect(XLSXReader.excelTimeText(45941.9077) == "21:47:05")
        #expect(L.parseTime(XLSXReader.excelTimeText(0) ?? "") == .init(hour: 0, minute: 0, second: 0))
        #expect(XLSXReader.excelTimeText(-1) == nil)
    }

    @Test("La tasa se aplica solo en otra moneda y si es a la preferida del teléfono")
    func fixedRate() {
        #expect(L.fixedRate(rate: 3.8, rateCurrency: "PEN", rowCurrency: "USD", preferredCurrency: "PEN") == 3.8)
        #expect(L.fixedRate(rate: 3.8, rateCurrency: nil, rowCurrency: "USD", preferredCurrency: "PEN") == 3.8)
        #expect(L.fixedRate(rate: 3.8, rateCurrency: "", rowCurrency: "USD", preferredCurrency: "PEN") == 3.8)
        #expect(L.fixedRate(rate: 3.8, rateCurrency: "EUR", rowCurrency: "USD", preferredCurrency: "PEN") == nil)
        #expect(L.fixedRate(rate: 3.8, rateCurrency: "PEN", rowCurrency: "PEN", preferredCurrency: "PEN") == nil)
    }

    @Test("La necesidad: el código del export, el valor interno o el nombre visible; vacía es la de la subcategoría")
    func parseNeed() {
        let names: [SubcategoryNeed: String] = [.essential: "Esencial", .priority: "Prioritaria",
                                                .optional: "Opcional", .unclassified: "Sin clasificar"]
        #expect(L.parseNeed("", displayNames: names) == .none)
        #expect(L.parseNeed("  ", displayNames: names) == .none)
        #expect(L.parseNeed("essential", displayNames: names) == .need(.essential))
        #expect(L.parseNeed("PRIORITY", displayNames: names) == .need(.priority))
        #expect(L.parseNeed("opcional", displayNames: names) == .need(.optional))
        #expect(L.parseNeed("sin_clasificacion", displayNames: names) == .need(.unclassified))
        #expect(L.parseNeed("Sin clasificación", displayNames: names) == .need(.unclassified))
        #expect(L.parseNeed("sin clasificar", displayNames: names) == .need(.unclassified))
        #expect(L.parseNeed("urgente", displayNames: names) == .invalid)
        for need in SubcategoryNeed.allCases {
            #expect(L.parseNeed(L.exportCode(for: need), displayNames: names) == .need(need))
        }
        #expect(L.exportNeedCode(override: nil) == "")
        #expect(L.exportNeedCode(override: SubcategoryNeed.optional.rawValue) == "optional")
    }
}
