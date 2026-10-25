//
//  ExportFileInsidesTests.swift
//  YalaTests
//
//  Card «Por dentro, el Excel sigue diciendo "Transacciones" y el archivo de grupos lleva la hora en cifras» (lote
//  12.4). Desde L20-4 el archivo se llama con la palabra y la fecha del idioma; la pestaña del Excel y el CSV de grupos
//  se habían quedado fuera.
//

import Foundation
import Testing
@testable import Yala

@MainActor
struct ExportFileInsidesTests {

    // MARK: - La pestaña del Excel

    @Test func workbook_namesTheSheetWithTheRecordsWord() {
        let xml = XLSXWriter.workbookXML(sheetName: L10n.UXL20D.fileStem)
        #expect(xml.contains("<sheet name=\"\(L10n.UXL20D.fileStem)\" sheetId=\"1\""))
        #expect(!xml.contains("Transacciones"))
    }

    @Test func workbook_usesWhateverNameItIsGiven() {
        #expect(XLSXWriter.workbookXML(sheetName: "Einträge").contains("<sheet name=\"Einträge\""))
        #expect(XLSXWriter.workbookXML(sheetName: "记录").contains("<sheet name=\"记录\""))
    }

    @Test func sheetName_dropsWhatExcelRejects() {
        #expect(XLSXWriter.validSheetName("Reg[is]tros: 2026/10?*\\") == "Registros 202610")
        #expect(XLSXWriter.validSheetName("   ") == "Sheet1")
        #expect(XLSXWriter.validSheetName(String(repeating: "a", count: 40)).count == 31)
    }

    @Test func sheetName_isEscapedInsideTheXML() {
        #expect(XLSXWriter.workbookXML(sheetName: "A & B").contains("<sheet name=\"A &amp; B\""))
    }

    @Test func everyLocale_hasASheetWord() throws {
        for locale in SupportedLocale.allCases {
            let path = try #require(Bundle.main.path(forResource: locale.bundleResourceName, ofType: "lproj"))
            let bundle = try #require(Bundle(path: path))
            let word = NSLocalizedString("l20d.export.fileStem", bundle: bundle, value: "∅", comment: "")
            #expect(word != "∅" && word != "l20d.export.fileStem", "\(locale.code) sin palabra para la pestaña")
            #expect(XLSXWriter.validSheetName(word) == word, "\(locale.code): «\(word)» no vale como pestaña de Excel")
        }
    }

    // MARK: - El archivo de grupos

    @Test func groupsFile_hasTheWordAndAReadableDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 9, minute: 35, second: 12)))
        let name = GroupsExportBuilder.exportFileName(date: date, locale: Locale(identifier: "es-419"))
        let stem = ExportRecordsLogic.sanitizedForFileName(L10n.Groups.title)
        #expect(name.hasPrefix("Yala_\(stem)_"))
        #expect(name.hasSuffix(".csv"))
        #expect(name.contains("17"))
        #expect(name.contains("2026"))
        // La hora ya no va en cifras pegadas.
        #expect(!name.contains("20261017"))
        #expect(!name.contains("093512"))
    }

    @Test func groupsFile_followsTheLocaleOrder() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 17)))
        let us = GroupsExportBuilder.exportFileName(date: date, locale: Locale(identifier: "en_US"))
        #expect(us.contains("Oct-17-2026"), "en-US escribe el mes primero: \(us)")
    }
}
