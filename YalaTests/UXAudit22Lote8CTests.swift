//
//  UXAudit22Lote8CTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 8 (buscar y filtrar registros), cards L8-14, L8-16 y L8-17: lo que se prueba sin store.
//  - Buscar sin texto enseñaba los 20 últimos sin decirlo: ahora el encabezado dice «Recientes».
//  - La hoja de Filtros: la X solo pregunta si lo elegido cambió, cambiar de modo solo pregunta si borraría algo, y
//    cada sección dice su estado («Todas las cuentas», «Ninguna oculta») en vez de «(Todos)» / «(Nada)».
//  - La cápsula de algo oculto dice «Sin <nombre>».
//

import Foundation
import Testing

@testable import Yala

// MARK: - Buscar (L8-14)

struct SearchHeaderLogicTests {

    @Test func withoutText_saysRecent() {
        #expect(SearchResultsLogic.headerLabel(searchText: "", total: 204) == L10n.UXL8C.searchRecent)
    }

    @Test func withText_saysHowManyResults() {
        #expect(SearchResultsLogic.headerLabel(searchText: "uber", total: 3) == L10n.Search.resultsCount(3))
        #expect(SearchResultsLogic.headerLabel(searchText: "uber", total: 3) != L10n.UXL8C.searchRecent)
    }

    /// Un día de este año va como en Registros («14 de octubre»); uno de otro año lleva el año.
    @Test func dateHeader_includesYearOnlyForOtherYears() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 12)))
        let sameYear = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let lastYear = try #require(calendar.date(from: DateComponents(year: 2025, month: 12, day: 31, hour: 23)))
        #expect(!SearchResultsLogic.headerIncludesYear(sameYear, now: now, calendar: calendar))
        #expect(SearchResultsLogic.headerIncludesYear(lastYear, now: now, calendar: calendar))
    }
}

// MARK: - Hoja de Filtros (L8-16)

struct RecordsFiltersDraftLogicTests {

    @Test func noChanges_whenNothingWasTouched() {
        let original = RecordsFiltersDraft(needs: [.essential], noteText: "uber")
        #expect(!RecordsFiltersDraftLogic.hasChanges(current: original, original: original))
    }

    @Test func noChanges_beforeTheSheetSnapshotted() {
        #expect(!RecordsFiltersDraftLogic.hasChanges(current: RecordsFiltersDraft(noteText: "x"), original: nil))
    }

    @Test func changes_whenAnythingDiffers() {
        let original = RecordsFiltersDraft()
        var note = original; note.noteText = "QA"
        var mode = original; mode.isExcludeMode = true
        var currency = original; currency.currencies = [.usd]
        var amount = original; amount.amountCondition = .greaterThan(100)
        var natures = original; natures.transactionNatures = [.expense]
        for current in [note, mode, currency, amount, natures] {
            #expect(RecordsFiltersDraftLogic.hasChanges(current: current, original: original))
        }
    }

    /// Volver a dejarlo como estaba ya no es un cambio: cerrar no pregunta.
    @Test func revertingIsNotAChange() {
        let original = RecordsFiltersDraft(needs: [.essential])
        var current = original
        current.needs.insert(.optional)
        current.needs.remove(.optional)
        #expect(!RecordsFiltersDraftLogic.hasChanges(current: current, original: original))
    }

    @Test func modeSwitch_withNothingMarked_doesNotAsk() {
        #expect(!RecordsFiltersDraftLogic.modeSwitchWouldClear(RecordsFiltersDraft(), isExpensesOnlyMode: false))
    }

    /// Con «solo gastos», el Tipo `[.expense]` lo pone la app: no cuenta como algo que se perdería.
    @Test func modeSwitch_expensesOnlyType_doesNotAsk() {
        let draft = RecordsFiltersDraft(transactionNatures: [.expense])
        #expect(!RecordsFiltersDraftLogic.modeSwitchWouldClear(draft, isExpensesOnlyMode: true))
        #expect(RecordsFiltersDraftLogic.modeSwitchWouldClear(draft, isExpensesOnlyMode: false))
    }

    @Test func modeSwitch_withSomethingMarked_asks() {
        let drafts = [
            RecordsFiltersDraft(needs: [.essential]),
            RecordsFiltersDraft(currencies: [.usd]),
            RecordsFiltersDraft(amountCondition: .lessThan(50)),
            RecordsFiltersDraft(noteText: "uber"),
        ]
        for draft in drafts {
            #expect(RecordsFiltersDraftLogic.modeSwitchWouldClear(draft, isExpensesOnlyMode: false))
        }
    }
}

@MainActor
struct RecordsFiltersSectionStatusTests {

    private let sections: [RecordsFiltersSection] = [.accounts, .categories, .tags, .needs, .currencies]

    /// Ninguna sección dice ya «Todos»/«Nada» a secas, ni sale como clave cruda.
    @Test func everySection_saysItsOwnStatus() {
        for section in sections {
            for exclude in [false, true] {
                let status = section.emptyStatus(isExcludeMode: exclude)
                #expect(!status.isEmpty)
                #expect(!status.contains("filters.l8"), "\(section) · \(exclude): clave cruda")
                #expect(status != L10n.Filters.all && status != L10n.Filters.nothingExcluded)
            }
            #expect(section.emptyStatus(isExcludeMode: false) != section.emptyStatus(isExcludeMode: true))
        }
        #expect(!RecordsFiltersSection.types.emptyStatus(isExcludeMode: false).contains("filters.l8"))
    }

    @Test func viewModelTexts_useTheSectionStatus() {
        let vm = RecordsFiltersViewModel()
        #expect(vm.selectedAccountsText(selectedAccounts: []) == RecordsFiltersSection.accounts.emptyStatus(isExcludeMode: false))
        #expect(vm.selectedAccountsText(selectedAccounts: [], isExcludeMode: true)
            == RecordsFiltersSection.accounts.emptyStatus(isExcludeMode: true))
        #expect(vm.selectedTagsText(selectedTags: [], isExcludeMode: true)
            == RecordsFiltersSection.tags.emptyStatus(isExcludeMode: true))
    }
}

// MARK: - Filtros aplicados (L8-17)

struct AppliedFilterChipTextTests {

    @Test func excluded_saysWithout() {
        #expect(FilterChipView.displayText("Ahorros USD", isExcluded: true) == L10n.UXL8C.Chip.excluded("Ahorros USD"))
        #expect(FilterChipView.displayText("Ahorros USD", isExcluded: true).contains("Ahorros USD"))
        #expect(FilterChipView.displayText("Ahorros USD", isExcluded: true) != "Ahorros USD")
    }

    @Test func included_isJustTheName() {
        #expect(FilterChipView.displayText("Ahorros USD", isExcluded: false) == "Ahorros USD")
    }
}

// MARK: - Textos en cada idioma

/// Se mide contra el `.lproj` de cada idioma (molde de `RecordsAuditLote8StringsTests`).
struct UXAudit22Lote8CStringsTests {

    private func format(_ key: String, _ code: String, _ args: CVarArg...) -> String {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) else {
            Issue.record("Falta \(code).lproj")
            return ""
        }
        let format = bundle.localizedString(forKey: key, value: "__FALTA__", table: nil)
        return String(format: format, locale: Locale(identifier: code), arguments: args)
    }

    @Test func spanish_values() {
        #expect(format("search.l8.recent", "es-419") == "Recientes")
        #expect(format("filters.l8.chipExcluded", "es-419", "Ahorros USD") == "Sin Ahorros USD")
        #expect(format("filters.l8.allAccounts", "es-419") == "Todas las cuentas")
        #expect(format("filters.l8.noneHidden.accounts", "es-419") == "Ninguna oculta")
        #expect(format("filters.l8.discardTitle", "es-419") == "¿Descartar los filtros?")
    }

    @Test func everyLocale_hasTheNewKeys() {
        let codes = ["es-419", "es", "es-ES", "es-AR", "en", "en-GB", "de", "fr", "it", "pt-BR", "pt", "pt-PT", "nl", "pl", "ja", "zh-Hans"]
        let keys = [
            "search.l8.recent",
            "filters.l8.discardTitle", "filters.l8.discardMessage", "filters.l8.keepChoosing", "filters.l8.discard",
            "filters.l8.switchToExcludeTitle", "filters.l8.switchToIncludeTitle", "filters.l8.switchMessage",
            "filters.l8.switchConfirm", "filters.l8.typeLivesInShowOnly",
            "filters.l8.amountTitle", "filters.l8.amountNeedsOneCurrency",
            "filters.l8.allAccounts", "filters.l8.allCategories", "filters.l8.allTags", "filters.l8.allNeeds",
            "filters.l8.allCurrencies", "filters.l8.allTypes",
            "filters.l8.noneHidden.accounts", "filters.l8.noneHidden.categories", "filters.l8.noneHidden.tags",
            "filters.l8.noneHidden.needs", "filters.l8.noneHidden.currencies",
            "filters.l8.chipExcludedValue", "filters.l8.chipOpenHint",
        ]
        for code in codes {
            for key in keys {
                let value = format(key, code)
                #expect(value != "__FALTA__" && value != key && !value.isEmpty, "\(code) · \(key)")
            }
            let chip = format("filters.l8.chipExcluded", code, "Ahorros USD")
            #expect(chip.contains("Ahorros USD") && chip != "Ahorros USD", "\(code) · chipExcluded")
        }
    }
}

// MARK: - Cableado

/// El cableado de las vistas, que la lógica pura no ve.
struct UXAudit22Lote8CWiringTests {

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    private static func codeOnly(_ code: String) -> String {
        code.split(separator: "\n").map { line -> Substring in
            if let range = line.range(of: "//") { return line[..<range.lowerBound] }
            return line
        }.joined(separator: "\n")
    }

    /// Un resultado abre el detalle, y el editor solo sube tras cerrarse el detalle (no dos hojas a la vez).
    @Test func search_resultOpensTheDetail_andEditChainsAfterDismiss() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/Views/Search/GlobalSearchView.swift"))
        #expect(code.contains("onTap: { openDetail(record) }"))
        let sheet = try #require(code.range(of: ".sheet(item: $detailTransaction, onDismiss: handleDetailDismiss)"))
        #expect(code.range(of: "TransactionDetailSheet(", range: sheet.upperBound..<code.endIndex) != nil)
        // Duplicar y Eliminar al pie del detalle también en Buscar (L8-4): el mismo registro se abre igual en toda la app.
        #expect(code.contains("onDuplicate: {"))
        #expect(code.contains("RecordsViewModel().deleteRecords(ids: [record.persistentModelID], context: modelContext)"))
        // `item:`: con `isPresented:` y el registro en otro `@State`, la hoja salía vacía (medido el 17-oct).
        #expect(code.contains(".sheet(item: $detailTransaction, onDismiss: handleDetailDismiss)"))
        let fn = try #require(code.range(of: "private func handleDetailDismiss()"))
        #expect(code.range(of: "editingTransaction = record", range: fn.upperBound..<code.endIndex) != nil)
        #expect(!code.contains("pinnedViews"), "la fecha volvió a fijarse sobre la primera fila")
    }

    /// El segmento no vacía lo elegido por su cuenta: pasa por la pregunta. Y la X pregunta antes de cerrar.
    @Test func filters_modeAndCloseGoThroughTheQuestion() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/Views/Records/RecordsFiltersView.swift"))
        #expect(code.contains("Picker(\"\", selection: $requestedExcludeMode)"))
        #expect(!code.contains(".onChange(of: localIsExcludeMode)"), "un onChange del modo vaciaba lo elegido al rehidratar")
        #expect(code.contains(".onSheetDismissAttempt(isActive: hasChanges)"))
        let close = try #require(code.range(of: "accessibilityIdentifier(\"filters_close_button\")"))
        let request = try #require(code.range(of: "requestClose()"))
        #expect(request.lowerBound < close.lowerBound)
    }
}
