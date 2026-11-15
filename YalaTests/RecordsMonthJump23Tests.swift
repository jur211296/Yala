//
//  RecordsMonthJump23Tests.swift
//  YalaTests
//
//  Revisión 2.3, decisiones 17, 79, 73 y 74 (9-nov), lote «Registros: saltar de mes»:
//  - 17 (T1 + T2): la lista va por meses; el separador de mes sale solo si la lista cruza meses, la cabecera de día
//    lleva el año solo cuando no es el año en curso y lo gastado ese día.
//  - 79: lo único fijo de la lista es el separador de mes, y lleva banda opaca; la cabecera de día va con el scroll.
//  - 73: una sola grafía, «Período», en todos los textos en español (app, plurales y widgets).
//  - 74: «Nota contiene…» con puntos suspensivos tipográficos en los 16 idiomas, y el marcador del monto con el formato
//    de la persona.
//

import Foundation
import Testing

@testable import Yala

struct RecordsMonthJump23Tests {

    // MARK: - Fechas fijas (nunca el reloj)

    private static let lima: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return c
    }()

    private static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        lima.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? .distantPast
    }

    private static let now = day(2026, 11, 12)

    // MARK: - 17 · Meses (T2)

    @Test func days_areGroupedByMonth_inTheOrderTheyArrive() {
        let groups: [(date: Date, records: [Double])] = [
            (Self.day(2026, 11, 7), [48, 15]),
            (Self.day(2026, 10, 31), [11]),
            (Self.day(2026, 10, 17), [45.9, 12, 171]),
            (Self.day(2025, 7, 4), [104]),
        ]
        let months = RecordsMonthSectionsLogic.months(groups, calendar: Self.lima) { $0.reduce(0, +) }

        #expect(months.map { RecordsMonthSectionsLogic.monthKey($0.start, calendar: Self.lima) }
                == ["2026-11", "2026-10", "2025-07"])
        #expect(months.map(\.recordCount) == [2, 4, 1])
        #expect(abs(months[1].spent - 239.9) < 0.0001)
        #expect(months[1].days.map(\.spent).count == 2)
    }

    @Test func separator_onlyWhenTheListCrossesMonths() {
        #expect(RecordsMonthSectionsLogic.showsMonthSeparator(monthCount: 0) == false)
        #expect(RecordsMonthSectionsLogic.showsMonthSeparator(monthCount: 1) == false)
        #expect(RecordsMonthSectionsLogic.showsMonthSeparator(monthCount: 2) == true)
    }

    // MARK: - 17 · Cabecera de día (T1)

    @Test func dayHeader_carriesTheYear_onlyOutsideTheCurrentYear() {
        #expect(RecordsMonthSectionsLogic.dayHeaderIncludesYear(Self.day(2026, 1, 1), now: Self.now, calendar: Self.lima) == false)
        #expect(RecordsMonthSectionsLogic.dayHeaderIncludesYear(Self.day(2026, 10, 17), now: Self.now, calendar: Self.lima) == false)
        #expect(RecordsMonthSectionsLogic.dayHeaderIncludesYear(Self.day(2025, 12, 31), now: Self.now, calendar: Self.lima) == true)
        #expect(RecordsMonthSectionsLogic.dayHeaderIncludesYear(Self.day(2025, 7, 4), now: Self.now, calendar: Self.lima) == true)
    }

    /// Lo gastado del día: sin cifra si no hubo gasto, o si las devoluciones lo dejan en cero o en negativo.
    @Test func dayHeader_namesTheSpent_onlyWhenThereIsSome() {
        #expect(RecordsMonthSectionsLogic.shownSpent(231.4) == 231.4)
        #expect(RecordsMonthSectionsLogic.shownSpent(0) == nil)
        #expect(RecordsMonthSectionsLogic.shownSpent(0.004) == nil)
        #expect(RecordsMonthSectionsLogic.shownSpent(-12) == nil)
    }

    // MARK: - 79 · Lo único fijo lleva fondo (source-scan del cableado)

    private static let repoRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // YalaTests/
        .deletingLastPathComponent()  // repo

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// El cuerpo de `recordsList(_:)` de la lista de Registros.
    private static func recordsListBody() throws -> String {
        let text = try source("Yala/App/Views/Statistics/RecordsTabView.swift")
        let start = try #require(text.range(of: "private func recordsList("))
        let end = try #require(text.range(of: "// MARK: - Modo duplicados", range: start.upperBound..<text.endIndex))
        return String(text[start.lowerBound..<end.lowerBound])
    }

    /// Fija las cabeceras de sección, y la cabecera fija es el separador de mes, no la del día: la del día se
    /// montaba sobre las filas porque no tenía fondo.
    @Test func theOnlyPinnedHeader_isTheMonthSeparator() throws {
        let body = try Self.recordsListBody()
        #expect(body.contains("pinnedViews: .sectionHeaders"))
        let header = try #require(body.range(of: "} header: {"))
        let headerTail = body[header.upperBound...]
        let headerBlock = headerTail.prefix(while: { $0 != "}" })
        #expect(headerBlock.contains("monthSeparator("), "La cabecera fija no es el separador de mes: \(headerBlock)")
        #expect(!headerBlock.contains("RecordDateSectionView"), "La cabecera de día volvió a quedar fija.")
    }

    @Test func theMonthSeparator_paintsAnOpaqueBand() throws {
        let text = try Self.source("Yala/App/Views/Records/Components/RecordsMonthSeparator.swift")
        #expect(text.contains(".background(theme.background)"),
                "El separador fijo no lleva fondo: las filas se leerían a través al pasar por debajo.")
    }

    // MARK: - 73 · «Período» en español

    private static let spanishLocales = ["es", "es-419", "es-AR", "es-ES"]

    private static func strings(_ folder: String, _ locale: String) -> [String: String] {
        let url = repoRoot.appendingPathComponent("\(folder)/\(locale).lproj/Localizable.strings")
        return NSDictionary(contentsOf: url) as? [String: String] ?? [:]
    }

    private static func pluralStrings(_ locale: String) -> [String] {
        let url = repoRoot.appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.stringsdict")
        guard let root = NSDictionary(contentsOf: url) else { return [] }
        var found: [String] = []
        func walk(_ value: Any) {
            if let s = value as? String { found.append(s) }
            if let d = value as? NSDictionary { d.allValues.forEach(walk) }
        }
        walk(root)
        return found
    }

    private static func isUnaccented(_ text: String) -> Bool {
        text.range(of: #"(?i)\bperiodos?\b"#, options: .regularExpression) != nil
    }

    @Test(arguments: spanishLocales)
    func spanishTexts_writePeriodoWithAccent(locale: String) {
        let app = Self.strings("Yala/Resources", locale)
        let widgets = Self.strings("YalaWidgets/Resources", locale)
        #expect(!app.isEmpty && !widgets.isEmpty, "No se leyó el catálogo de \(locale): ruta rota.")
        let offending = (Array(app.values) + Array(widgets.values) + Self.pluralStrings(locale))
            .filter(Self.isUnaccented)
        #expect(offending.isEmpty, "\(locale): «periodo» sin tilde en \(offending.count) textos: \(offending.prefix(3))")
    }

    // MARK: - 74 · «Nota contiene…» y el marcador del monto

    private static let allLocales = [
        "de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "ja", "nl", "pl", "pt", "pt-BR", "pt-PT",
        "zh-Hans",
    ]

    @Test(arguments: allLocales)
    func noteContains_endsWithATypographicEllipsis(locale: String) throws {
        let value = try #require(Self.strings("Yala/Resources", locale)["filters.noteContains"])
        #expect(value.hasSuffix("…"), "\(locale): «\(value)»")
        #expect(!value.contains("..."), "\(locale): «\(value)»")
    }

    @Test func amountPlaceholder_followsDecimalsAndTheRegionSeparator() {
        #expect(AmountFilterTextLogic.placeholder(decimals: 2, locale: Locale(identifier: "en_US")) == "0.00")
        #expect(AmountFilterTextLogic.placeholder(decimals: 2, locale: Locale(identifier: "es_ES")) == "0,00")
        #expect(AmountFilterTextLogic.placeholder(decimals: 0, locale: Locale(identifier: "es_PE")) == "0")
    }

    /// Lo escrito se lee con el separador que enseña el marcador: «12,50» filtraba por 12.
    @Test func typedAmount_isReadWithTheSameSeparator() {
        let spain = Locale(identifier: "es_ES")
        #expect(AmountFilterTextLogic.amount(from: "12,50", locale: spain) == Decimal(string: "12.5"))
        #expect(AmountFilterTextLogic.amount(from: "12.50", locale: spain) == Decimal(string: "12.5"))
        #expect(AmountFilterTextLogic.amount(from: "12.50", locale: Locale(identifier: "en_US")) == Decimal(string: "12.5"))
        #expect(AmountFilterTextLogic.amount(from: "", locale: spain) == nil)
        #expect(AmountFilterTextLogic.text(for: Decimal(string: "12.5") ?? 0, locale: spain) == "12,5")
        #expect(AmountFilterTextLogic.text(for: Decimal(string: "12.5") ?? 0, locale: Locale(identifier: "en_US")) == "12.5")
    }

    @Test func amountField_noLongerShowsAFixedZero() throws {
        let text = try Self.source("Yala/App/Views/ExportWizard/FilterComponents.swift")
        #expect(!text.contains("TextField(\"0.00\""), "El marcador del monto sigue siendo «0.00» fijo.")
        #expect(text.contains("AmountFilterTextLogic.placeholder("))
        #expect(text.contains("AmountFilterTextLogic.amount(from:"))
    }
}
