//
//  RecordsAuditLote8Tests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 8 (Registros): los arreglos pequeños que se prueban sin store.
//  - Buscar contaba 204 resultados y «Ver todos» enseñaba cero: ahora despliega aquí mismo los que contó.
//  - El calendario titulaba «Octubre De 2026».
//  - VoiceOver leía «, S/ 45.00, …» (sin nota, con una coma suelta), nunca decía si era gasto o ingreso, y leía en soles
//    los registros de una cuenta en dólares.
//  - «1 seleccionados», «1 resultados».
//  - La ayuda decía que mantener pulsado un registro entra en la edición masiva (abre el menú del registro).
//

import Foundation
import Testing

@testable import Yala

struct SearchResultsLogicTests {

    @Test func preview_showsTheFirstTwenty() {
        let matches = Array(1...204)
        #expect(SearchResultsLogic.visible(matches, showsAll: false) == Array(1...20))
    }

    /// «Ver todos» enseña TODOS los que cuenta el encabezado: la cifra y la lista dicen lo mismo.
    @Test func showAll_showsEveryMatch() {
        let matches = Array(1...204)
        #expect(SearchResultsLogic.visible(matches, showsAll: true).count == 204)
    }

    @Test func showAll_isOfferedOnlyWhenThereIsMoreThanWhatIsSeen() {
        #expect(SearchResultsLogic.offersShowAll(total: 204, showsAll: false))
        #expect(!SearchResultsLogic.offersShowAll(total: 20, showsAll: false), "con 20 ya se ven todos")
        #expect(!SearchResultsLogic.offersShowAll(total: 21, showsAll: true), "ya desplegado")
        #expect(SearchResultsLogic.offersShowAll(total: 21, showsAll: false))
    }
}

struct CapitalizingFirstLetterTests {

    @Test func monthWithYear_onlyTheFirstLetter() {
        #expect("octubre de 2026".capitalizingFirstLetter(locale: Locale(identifier: "es_PE")) == "Octubre de 2026")
        #expect("outubro de 2026".capitalizingFirstLetter(locale: Locale(identifier: "pt_BR")) == "Outubro de 2026")
    }

    @Test func accentedFirstLetter_andEmpty() {
        #expect("évolution".capitalizingFirstLetter(locale: Locale(identifier: "fr_FR")) == "Évolution")
        #expect("".capitalizingFirstLetter(locale: Locale(identifier: "es")) == "")
        #expect("October 2026".capitalizingFirstLetter(locale: Locale(identifier: "en")) == "October 2026")
    }
}

struct RecordRowAccessibilityLabelTests {

    /// Sin nota no empieza por una coma.
    @Test func withoutNote_noLeadingComma() {
        let label = TransactionDetailSheetLogic.rowAccessibilityLabel(
            note: nil, kind: "Gasto", amount: "S/ 45.00", category: "Cuidado personal y belleza", account: "Cuenta Principal")
        #expect(label == "Gasto, S/ 45.00, Cuidado personal y belleza, Cuenta Principal")
    }

    /// Una nota en blanco cuenta como ninguna.
    @Test func blankNote_isSkipped() {
        let label = TransactionDetailSheetLogic.rowAccessibilityLabel(
            note: "  ", kind: "Ingreso", amount: "$ 2,000.00", category: nil, account: "Ahorros USD")
        #expect(label == "Ingreso, $ 2,000.00, Ahorros USD")
    }

    /// Un ajuste de saldo va sin tipo: no es un gasto ni un ingreso.
    @Test func balanceAdjustment_hasNoKind() {
        let label = TransactionDetailSheetLogic.rowAccessibilityLabel(
            note: "Saldo inicial", kind: nil, amount: "S/ 5,000.00", category: "Ajustes de saldo", account: "Cuenta Principal")
        #expect(label == "Saldo inicial, S/ 5,000.00, Ajustes de saldo, Cuenta Principal")
    }

    @Test func fullRow_inOrder() {
        let label = TransactionDetailSheetLogic.rowAccessibilityLabel(
            note: "Uber", kind: "Gasto", amount: "S/ 26.00", category: "Taxis y apps", account: "Cuenta Principal")
        #expect(label == "Uber, Gasto, S/ 26.00, Taxis y apps, Cuenta Principal")
    }
}

/// El cableado de las vistas, que la lógica pura no ve (review adversarial del lote 8).
struct RecordsAuditLote8WiringTests {

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    /// Sin comentarios, para que documentar el invariante no lo cuente como código.
    private static func codeOnly(_ code: String) -> String {
        code.split(separator: "\n").map { line -> Substring in
            if let range = line.range(of: "//") { return line[..<range.lowerBound] }
            return line
        }.joined(separator: "\n")
    }

    /// La confirmación del borrado en lote se mide al tocar la papelera: sin `prepareBulkDelete` justo antes, el diálogo
    /// enseñaría lo de la selección anterior (o nada que borrar) en los dos sitios que lo montan.
    @Test func trash_preparesTheDialogBeforeShowingIt() throws {
        for file in ["Yala/App/Views/Records/RecordsStandaloneView.swift", "Yala/App/Views/Statistics/DetailContainerView.swift"] {
            let code = Self.codeOnly(try Self.source(file))
            let prepare = try #require(code.range(of: "recordsViewModel.prepareBulkDelete(context: modelContext)"), "\(file)")
            let show = try #require(code.range(of: "showDeleteConfirmation = true", range: prepare.upperBound..<code.endIndex), "\(file)")
            let between = code[prepare.upperBound..<show.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(between.isEmpty, "\(file): algo se metió entre preparar el diálogo y mostrarlo")
        }
    }

    /// VoiceOver lee el importe en la moneda del registro, no en la preferida.
    @Test func rowAccessibility_usesTheRecordCurrency() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/Views/Records/Components/RecordRowView.swift"))
        #expect(code.contains(": appPreferences.currency(abs(record.amount), currencyCode: record.currencyCode)"))
        #expect(code.contains("? appPreferences.currency(record.amount, currencyCode: record.currencyCode)"))
        #expect(code.contains("kind: isBalanceAdjustment ? nil : kind.displayName"))
    }

    /// El mes del calendario no vuelve a `capitalized` (mayúscula en cada palabra).
    @Test func calendarMonth_doesNotCapitalizeEveryWord() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/Views/Records/Components/RecordsCalendarView.swift"))
        #expect(code.contains(".capitalizingFirstLetter(locale: AppLocale.current)"))
        #expect(!code.contains(".capitalized"))
    }

    /// «Ver todos» despliega con la misma bandera que decide cuántos se ven.
    @Test func search_visibleResultsFollowShowAll() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/Views/Search/GlobalSearchView.swift"))
        #expect(code.contains("SearchResultsLogic.visible(matchingTransactions, showsAll: showsAllResults)"))
        #expect(code.contains("showsAllResults = true"))
        #expect(!code.contains("navigateToDetail(.records)"), "«Ver todos» volvió a llevar a Estadísticas › Registros")
    }

    /// Tras Duplicar, el formulario deja de ser el registro guardado EN EL ACTO, antes de la espera de la animación.
    @Test func duplicate_switchesToNewRecordBeforeTheAnimationWait() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/Views/Transactions/NewTransactionView.swift"))
        let fn = try #require(code.range(of: "private func duplicateTransaction()"))
        let flag = try #require(code.range(of: "isDuplicating = true", range: fn.upperBound..<code.endIndex))
        let cleared = try #require(code.range(of: "viewModel.editingTransaction = nil", range: fn.upperBound..<code.endIndex))
        let wait = try #require(code.range(of: "Task.sleep(for: .milliseconds(150))", range: fn.upperBound..<code.endIndex))
        #expect(flag.lowerBound < wait.lowerBound)
        #expect(cleared.lowerBound < wait.lowerBound)
    }

    /// Las funciones nuevas de `L10n` apuntan a claves que existen (una errata saldría como clave cruda).
    @Test func l10nAccessors_resolve() {
        #expect(!L10n.Records.selectedCount(1).contains("records."))
        #expect(!L10n.Records.groupRecordsKept(1).contains("records."))
        #expect(!L10n.Records.groupRecordsOnlyTitle.contains("records."))
        #expect(!L10n.Records.groupRecordsDeleteFromGroup.contains("records."))
        #expect(!L10n.BulkEdit.cannotEditGroupRecords.contains("bulkEdit."))
        #expect(!L10n.Search.resultsCount(2).contains("search."))
    }
}

/// Se mide contra el `.lproj` de cada idioma (molde de `InboxPluralsTests`): el idioma del proceso de test no es fijo.
struct RecordsAuditLote8StringsTests {

    private func format(_ key: String, _ code: String, _ args: CVarArg...) -> String {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) else {
            Issue.record("Falta \(code).lproj")
            return ""
        }
        let format = bundle.localizedString(forKey: key, value: "__FALTA__", table: nil)
        return String(format: format, locale: Locale(identifier: code), arguments: args)
    }

    @Test func spanish_selectedAndResults_singularAndPlural() {
        #expect(format("records.selectedCount", "es-419", 1) == "1 seleccionado")
        #expect(format("records.selectedCount", "es-419", 3) == "3 seleccionados")
        #expect(format("search.resultsCount", "es-419", 1) == "1 resultado")
        #expect(format("search.resultsCount", "es-419", 204) == "204 resultados")
        #expect(format("records.groupRecordsKept", "es-419", 1) == "1 viene de un grupo y no se borra aquí: se borra desde el grupo.")
        #expect(format("records.groupRecordsKept", "es-419", 2) == "2 vienen de un grupo y no se borran aquí: se borran desde el grupo.")
    }

    @Test func english_singularAndPlural() {
        #expect(format("search.resultsCount", "en", 1) == "1 result")
        #expect(format("search.resultsCount", "en", 2) == "2 results")
        #expect(format("records.selectedCount", "en", 1) == "1 selected")
    }

    @Test func polish_fourForms() {
        #expect(format("records.selectedCount", "pl", 1) == "1 wybrany")
        #expect(format("records.selectedCount", "pl", 3) == "3 wybrane")
        #expect(format("records.selectedCount", "pl", 5) == "5 wybranych")
    }

    /// Todos los idiomas con las claves nuevas resueltas (ninguno devuelve la clave cruda ni el marcador).
    @Test func everyLocale_hasTheNewKeys() {
        let codes = ["es-419", "es", "es-ES", "es-AR", "en", "en-GB", "de", "fr", "it", "pt-BR", "pt", "pt-PT", "nl", "pl", "ja", "zh-Hans"]
        let keys = ["records.selectedCount", "records.groupRecordsKept", "records.groupRecordsOnlyTitle",
                    "records.groupRecordsDeleteFromGroup", "bulkEdit.cannotEditGroupRecords", "search.resultsCount"]
        for code in codes {
            for key in keys {
                let value = format(key, code, 2)
                #expect(value != "__FALTA__" && value != key && !value.isEmpty, "\(code) · \(key)")
            }
        }
    }

    /// La ayuda ya no manda a mantener pulsado para la edición masiva: describe el menú y «Seleccionar».
    @Test func faq_describesTheRealGestures() {
        let codes = ["es-419", "es-ES", "es-AR", "en", "en-GB", "de", "fr", "it", "pt-BR", "pt-PT", "nl", "pl", "ja", "zh-Hans"]
        for code in codes {
            let answer = format("faq.changeCategory.a", code)
            #expect(answer.contains("···"), "\(code): la respuesta no menciona el menú ···")
        }
        let spanish = format("faq.changeCategory.a", "es-419")
        #expect(spanish.contains("«Seleccionar»") && spanish.contains("«Cambiar categoría»"))
        #expect(!spanish.contains("edición masiva: mantén presionado"))
        #expect(format("faq.changeCategory.a", "es-AR").contains("mantené presionado"), "es-AR con voseo")
    }
}
