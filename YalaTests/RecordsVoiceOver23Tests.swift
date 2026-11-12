//
//  RecordsVoiceOver23Tests.swift
//  YalaTests
//
//  Lote de Registros 2.3 (decisiones 60, 61, 76 y 78 de la discusión del 9-nov). Un caso por punto; el 77 (el selector
//  Lista/Calendario con la lista vacía) y la cara visible del 78 van en `RecordsVoiceOver23UITests`.
//  - 60: VoiceOver leía cada fila sin su fecha.
//  - 61: la pista de las etiquetas de la fila decía «Tag» en inglés en todos los idiomas.
//  - 76: la tarjeta de Siri pintaba el importe a 38 pt fijos, «Cuenta: —» y la fecha en números.
//  - 78: un fallo al leer los movimientos se veía como «Sin registros», y cargando no había nada.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Registros 2.3 · VoiceOver lee la fecha de cada fila (decisión 60)")
struct RecordRowAccessibilityDateTests {

    private func makePrefs() throws -> AppPreferences {
        let defaults = try #require(testDefaults(suiteName: "RecordRowAccessibilityDateTests.\(UUID().uuidString)"))
        let prefs = AppPreferences(defaults: defaults)
        prefs.defaultCurrencyCode = .pen
        return prefs
    }

    /// Mediodía: lejos de la medianoche, la fecha no cambia de día con la zona del simulador.
    private func noon(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
    }

    @Test("La etiqueta de la fila termina con la fecha, con el mes en letras")
    func label_endsWithTheDate() throws {
        let prefs = try makePrefs()
        let record = TransactionItem(date: try noon(2026, 11, 12), amount: -45.9, currencyCode: "PEN", note: "Almuerzo")

        let label = RecordRowView.accessibilityDescription(
            for: record, appPreferences: prefs, locale: Locale(identifier: "es_PE"))

        #expect(label.hasSuffix(", 12 de noviembre de 2026"), "\(label)")
        #expect(label.hasPrefix("Almuerzo"), "\(label)")
    }

    @Test("La fecha va en el idioma de la app")
    func date_followsTheAppLanguage() throws {
        let prefs = try makePrefs()
        let record = TransactionItem(date: try noon(2026, 3, 5), amount: -10, currencyCode: "PEN")

        let label = RecordRowView.accessibilityDescription(
            for: record, appPreferences: prefs, locale: Locale(identifier: "en_US"))

        #expect(label.hasSuffix("March 5, 2026"), "\(label)")
    }

    @Test("En el modo duplicados la fecha no se lee dos veces")
    func duplicatesMode_doesNotRepeatTheDate() throws {
        let view = try RecordsVoiceOver23Source.code("Yala/App/Views/Records/Components/RecordRowView.swift")
        #expect(view.contains(".accessibilityLabel(accessibilityDescription)"))
        #expect(!view.contains("\"\\(accessibilityDescription), \\($0)\""))
    }
}

@Suite("Registros 2.3 · la pista de las etiquetas va traducida (decisión 61)")
struct RecordRowTagHintTests {

    static let locales = ["es-419", "es-ES", "es-AR", "es", "en", "en-GB", "de", "fr", "it", "pt-BR", "pt-PT", "pt",
                          "nl", "pl", "ja", "zh-Hans"]

    @Test("La fila ya no pide «Tag» a pelo")
    func row_usesTheTranslatedHint() throws {
        let view = try RecordsVoiceOver23Source.code("Yala/App/Views/Records/Components/RecordRowView.swift")
        #expect(!view.contains("String(localized: \"Tag\")"))
        #expect(view.contains(".accessibilityHint(L10n.RecordsVoiceOver23.tagHint)"))
    }

    @Test("La clave existe en los 16 idiomas, y en español no dice «Tag»", arguments: locales)
    func key_existsInEveryLanguage(locale: String) throws {
        let strings = try RecordsVoiceOver23Source.code("Yala/Resources/\(locale).lproj/Localizable.strings")
        let line = try #require(strings.split(separator: "\n").first { $0.hasPrefix("\"records.row.tagHint\" = ") },
                                "\(locale) no tiene records.row.tagHint")
        if locale.hasPrefix("es") || locale.hasPrefix("pt") {
            #expect(line == "\"records.row.tagHint\" = \"Etiqueta\";", "\(locale): \(line)")
        }
    }
}

@Suite("Registros 2.3 · cargando y error no son «Sin registros» (decisión 78)")
struct RecordsListStateTests {

    @Test func beforeTheFirstFilter_isLoading() {
        #expect(RecordsListStateLogic.state(hasAppliedFilters: false, loadFailed: false, isEmpty: true) == .loading)
    }

    @Test func aFailedReadWithNothingToShow_isTheError_notTheEmptyList() {
        #expect(RecordsListStateLogic.state(hasAppliedFilters: true, loadFailed: true, isEmpty: true) == .failed)
        #expect(RecordsListStateLogic.state(hasAppliedFilters: false, loadFailed: true, isEmpty: true) == .failed)
    }

    @Test func aGoodReadWithNothing_isTheEmptyList() {
        #expect(RecordsListStateLogic.state(hasAppliedFilters: true, loadFailed: false, isEmpty: true) == .empty)
    }

    /// Una recarga que falla con las filas de antes en memoria las sigue enseñando.
    @Test func aFailedReloadWithRecordsInMemory_keepsTheRecords() {
        #expect(RecordsListStateLogic.state(hasAppliedFilters: true, loadFailed: true, isEmpty: false) == .records)
    }

    @Test("La lista enseña el error y el indicador; el contenedor apunta el fallo y lo apaga al leer bien")
    func wiring() throws {
        let tab = try RecordsVoiceOver23Source.code("Yala/App/Views/Statistics/RecordsTabView.swift")
        #expect(tab.contains("RecordsLoadingIndicator()"))
        #expect(tab.contains("if listState == .failed {"))
        #expect(tab.contains("RecordsLoadErrorState(onRetry: onRetryLoad)"))

        let vm = try RecordsVoiceOver23Source.code("Yala/App/ViewModels/DetailContainerViewModel.swift")
        #expect(vm.contains("if transactionsLoadFailed { transactionsLoadFailed = false }"))
        #expect(vm.contains("if !transactionsLoadFailed { transactionsLoadFailed = true }"))

        for host in ["Yala/App/Views/Records/RecordsStandaloneView.swift", "Yala/App/Views/Statistics/DetailContainerView.swift"] {
            let code = try RecordsVoiceOver23Source.code(host)
            #expect(code.contains("loadFailed: dataViewModel.transactionsLoadFailed,"), "\(host)")
            #expect(code.contains("onRetryLoad: { reloadAndRecalculate() }"), "\(host)")
        }
    }
}

@Suite("Registros 2.3 · la tarjeta de Siri (decisión 76)")
struct TransactionSnippetTests {

    @Test func unknownAccount_hidesTheRow() {
        #expect(TransactionSnippetLogic.visibleAccountName(nil) == nil)
        #expect(TransactionSnippetLogic.visibleAccountName("") == nil)
        #expect(TransactionSnippetLogic.visibleAccountName("—") == nil)
        #expect(TransactionSnippetLogic.visibleAccountName("BBVA") == "BBVA")
    }

    @Test func date_hasTheMonthInLetters() throws {
        let date = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 12)))
        #expect(TransactionSnippetLogic.dateText(date, locale: Locale(identifier: "es_PE")) == "12 de noviembre de 2026")
        #expect(!TransactionSnippetLogic.dateText(date, locale: Locale(identifier: "es_PE")).contains("/"))
    }

    @Test("Importe con fuente que escala, y Siri ya no pasa «—» como cuenta")
    func wiring() throws {
        let card = try RecordsVoiceOver23Source.code("Yala/App/Intents/Views/TransactionSnippetView.swift")
        #expect(!card.contains(".system(size:"))
        #expect(card.contains(".font(.largeTitle.bold())"))
        #expect(card.contains("TransactionSnippetLogic.visibleAccountName(accountName)"))
        #expect(card.contains("TransactionSnippetLogic.dateText(date)"))
        #expect(!card.contains("date: .numeric"))

        let intent = try RecordsVoiceOver23Source.code("Yala/App/Intents/QuickExpenseIntent.swift")
        #expect(!intent.contains("accountName: \"—\""))
    }
}

enum RecordsVoiceOver23Source {
    /// El fichero sin comentarios de línea: documentar el invariante no lo rompe.
    static func code(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
        return source.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard !relative.hasSuffix(".strings"), let range = line.range(of: "//") else { return line }
                return line[..<range.lowerBound]
            }
            .joined(separator: "\n")
    }
}
