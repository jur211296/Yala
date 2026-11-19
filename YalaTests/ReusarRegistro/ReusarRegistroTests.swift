//
//  ReusarRegistroTests.swift
//  YalaTests
//
//  «Reusar» en Pagos planificados (encargo del 17-nov): el botón nunca va debajo de «Nuevo pago planificado», la hoja
//  que elige el registro filtra y busca como Registros sin tocar los filtros de la sesión, y sus textos están en los 16
//  idiomas.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Qué enseña la hoja

@Suite("Reusar · la hoja filtra, busca y agrupa por día")
@MainActor
struct ReusarRegistroLogicTests {

    private static let calendar = Calendar(identifier: .gregorian)

    private static func day(_ d: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: d, hour: hour)) ?? .distantPast
    }

    private struct Fixture {
        let visa: Account
        let cash: Account
        let services: Yala.Category
        let food: Yala.Category
        let cloudflare: TransactionItem
        let lunch: TransactionItem
        let netflix: TransactionItem
        var all: [TransactionItem] { [cloudflare, lunch, netflix] }
    }

    /// Tres registros en dos días y dos cuentas, sin contexto: la lógica solo lee el modelo.
    private static func fixture() -> Fixture {
        let visa = Account(name: "Visa", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard",
                           type: "credit")
        let cash = Account(name: "Efectivo", currencyCode: "PEN", colorHex: "#111111", iconName: "banknote",
                           type: "cash")
        let services = Yala.Category(name: "Servicios", colorHex: "#123456", isIncome: false, iconName: "server.rack")
        let food = Yala.Category(name: "Comida", colorHex: "#654321", isIncome: false, iconName: "fork.knife")
        let cloudflare = TransactionItem(
            date: day(16, hour: 9), amount: -25, currencyCode: "PEN", note: "Cloudflare", category: services,
            account: visa)
        let lunch = TransactionItem(
            date: day(16, hour: 13), amount: -42.5, currencyCode: "PEN", note: "Almuerzo", category: food,
            account: cash)
        let netflix = TransactionItem(
            date: day(14), amount: -38, currencyCode: "PEN", note: "Netflix", category: services, account: visa)
        return Fixture(visa: visa, cash: cash, services: services, food: food,
                       cloudflare: cloudflare, lunch: lunch, netflix: netflix)
    }

    private static func notes(_ groups: [(date: Date, records: [TransactionItem])]) -> [[String]] {
        groups.map { $0.records.map { $0.note ?? "" } }
    }

    @Test func withoutFilters_groupsByDay_newestFirst_keepingTheOrderWithinADay() {
        let f = Self.fixture()
        let groups = ReusarRegistroLogic.groups(
            [f.lunch, f.cloudflare, f.netflix], criteria: FilterCriteria(), query: "", tags: [],
            calendar: Self.calendar)
        #expect(groups.map(\.date) == [Self.calendar.startOfDay(for: Self.day(16)),
                                       Self.calendar.startOfDay(for: Self.day(14))])
        #expect(Self.notes(groups) == [["Almuerzo", "Cloudflare"], ["Netflix"]])
    }

    @Test func theAccountChip_leavesOnlyThatAccount() {
        let f = Self.fixture()
        let filters = ReusarRegistroFilters()
        filters.selectedAccounts = [f.visa.persistentModelID]
        let groups = ReusarRegistroLogic.groups(
            f.all, criteria: filters.filterCriteria, query: "", tags: [], calendar: Self.calendar)
        #expect(Self.notes(groups) == [["Cloudflare"], ["Netflix"]])
    }

    @Test func theCategoryChip_leavesOnlyThatCategory() {
        let f = Self.fixture()
        let filters = ReusarRegistroFilters()
        filters.selectedCategories = [f.food.persistentModelID]
        let groups = ReusarRegistroLogic.groups(
            f.all, criteria: filters.filterCriteria, query: "", tags: [], calendar: Self.calendar)
        #expect(Self.notes(groups) == [["Almuerzo"]])
    }

    @Test func hidingAnAccountInMoreFilters_takesItOut() {
        let f = Self.fixture()
        let filters = ReusarRegistroFilters()
        filters.excludedAccounts = [f.visa.persistentModelID]
        let groups = ReusarRegistroLogic.groups(
            f.all, criteria: filters.filterCriteria, query: "", tags: [], calendar: Self.calendar)
        #expect(Self.notes(groups) == [["Almuerzo"]])
    }

    /// El buscador es el de Registros: descripción, categoría, cuenta o importe.
    @Test(arguments: [
        ("cloud", [["Cloudflare"]]),
        ("servicios", [["Cloudflare"], ["Netflix"]]),
        ("efectivo", [["Almuerzo"]]),
        ("38", [["Netflix"]]),
        ("42.50", [["Almuerzo"]]),
    ])
    func theSearchField_findsLikeRecords(_ query: String, _ expected: [[String]]) {
        let f = Self.fixture()
        let groups = ReusarRegistroLogic.groups(
            f.all, criteria: FilterCriteria(), query: query, tags: [], calendar: Self.calendar)
        #expect(Self.notes(groups) == expected)
    }

    @Test func searchAndFilters_combine() {
        let f = Self.fixture()
        let filters = ReusarRegistroFilters()
        filters.selectedAccounts = [f.visa.persistentModelID]
        let groups = ReusarRegistroLogic.groups(
            f.all, criteria: filters.filterCriteria, query: "netflix", tags: [], calendar: Self.calendar)
        #expect(Self.notes(groups) == [["Netflix"]])
        let none = ReusarRegistroLogic.groups(
            f.all, criteria: filters.filterCriteria, query: "almuerzo", tags: [], calendar: Self.calendar)
        #expect(none.isEmpty)
    }
}

// MARK: - Los filtros son de la hoja

@Suite("Reusar · los filtros de la hoja no tocan los de la sesión")
@MainActor
struct ReusarRegistroFiltersTests {

    @Test func theyBornEmpty_andClearToEmpty() {
        let account = Account(name: "Visa", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard",
                              type: "credit")
        let filters = ReusarRegistroFilters()
        #expect(!filters.hasActiveFilters)
        filters.selectedAccounts = [account.persistentModelID]
        filters.selectedNeeds = [.essential]
        filters.amountCondition = .greaterThan(10)
        #expect(filters.hasActiveFilters)
        filters.clearFilters()
        #expect(!filters.hasActiveFilters)
        #expect(filters.selectedAccounts.isEmpty && filters.selectedNeeds.isEmpty)
        #expect(filters.amountCondition == .any)
    }

    @Test func choosingAnAccount_doesNotFilterTheSession() {
        let account = Account(name: "Visa", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard",
                              type: "credit")
        let before = SessionState.shared.selectedAccountIDs
        let filters = ReusarRegistroFilters()
        filters.selectedAccounts = [account.persistentModelID]
        #expect(SessionState.shared.selectedAccountIDs == before)
        #expect(!SessionState.shared.selectedAccountIDs.contains(account.persistentModelID))
    }
}

// MARK: - Cableado

@Suite("Reusar · cableado del botón y de la hoja (source-scan)")
struct ReusarRegistroWiringTests {

    private static func code(_ relative: String, file: StaticString = #filePath) throws -> String {
        let root = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
        return text.split(separator: "\n").map { line -> Substring in
            if let range = line.range(of: "//") { return line[..<range.lowerBound] }
            return line
        }.joined(separator: "\n")
    }

    /// El tramo de código entre dos marcas, sin incluir la segunda.
    private static func slice(_ text: String, from start: String, to end: String) throws -> String {
        let lower = try #require(text.range(of: start)).lowerBound
        let upper = try #require(text.range(of: end, range: lower..<text.endIndex)).lowerBound
        return String(text[lower..<upper])
    }

    /// «Nunca un botón debajo del otro» (Jürgen, 17-nov): las dos formas que prueba `ViewThatFits` son filas, y la
    /// última —la que se queda si ninguna cabe— lleva el botón de solo icono.
    @Test func theTwoButtons_neverStack() throws {
        let view = try Self.code("Yala/App/Views/Planning/ScheduledPaymentsListView.swift")
        let actions = try Self.slice(view, from: "private var createActions: some View", to: "private static let reuseSystemImage")
        #expect(actions.contains("ViewThatFits(in: .horizontal)"))
        #expect(!actions.contains("VStack"))
        #expect(actions.components(separatedBy: "HStack(spacing: DS.Spacing.sm)").count - 1 == 2)
        let pillAt = try #require(actions.range(of: "reusePill(action: onCreateFromRecord)")).lowerBound
        let iconAt = try #require(actions.range(of: "reuseIconButton(action: onCreateFromRecord)")).lowerBound
        #expect(pillAt < iconAt, "La forma con nombre va primero; la de solo icono, la última.")
    }

    @Test func bothForms_keepTheIdentifier_theNameForVoiceOver_andTheHint() throws {
        let view = try Self.code("Yala/App/Views/Planning/ScheduledPaymentsListView.swift")
        let pill = try Self.slice(view, from: "private func reusePill", to: "private func reuseIconButton")
        let icon = try Self.slice(view, from: "private func reuseIconButton", to: "var body: some View")
        #expect(pill.contains("title: ReusarRegistroText.button"))
        #expect(pill.contains("\"scheduled_payments_create_from_record_button\""))
        #expect(pill.contains(".accessibilityHint(ReusarRegistroText.buttonHint)"))
        #expect(icon.contains(".accessibilityLabel(ReusarRegistroText.button)"))
        #expect(icon.contains(".accessibilityIdentifier(\"scheduled_payments_create_from_record_button\")"))
        #expect(icon.contains(".accessibilityHint(ReusarRegistroText.buttonHint)"))
        #expect(icon.contains(".frame(width: DS.Button.actionSize, height: DS.Button.actionSize)"))
    }

    @Test func thePicker_opensLarge() throws {
        let view = try Self.code("Yala/App/Views/Planning/ScheduledPaymentsView.swift")
        let sheet = try Self.slice(view, from: ".sheet(isPresented: $showsRecordPicker", to: "practiceCleanupPrompt")
        #expect(sheet.contains("RecurringRecordPickerSheet()"))
        #expect(sheet.contains(".presentationDetents([.large])"))
    }

    /// La hoja reutiliza las piezas de Registros, con filtros propios, y no las copia.
    @Test func thePicker_reusesRecordsPieces_withItsOwnFilters() throws {
        let sheet = try Self.code("Yala/App/Views/Planning/PagosRecurrentes/RecurringFromRecordSheet.swift")
        let picker = try Self.slice(sheet, from: "struct RecurringRecordPickerSheet", to: "final class ReusarRegistroFilters")
        #expect(picker.contains("RecordsListSearchField(text: $query"))
        #expect(picker.contains("RecordsQuickFilterBar(\n                    viewModel: filters,"))
        #expect(picker.contains("RecordDateSectionView("))
        #expect(picker.contains("RecordRowView("))
        #expect(picker.contains("RecordsFiltersView(recordsViewModel: filters)"))
        #expect(picker.contains("@State private var filters = ReusarRegistroFilters()"))
        // Ni el ViewModel de Registros ni escrituras a los filtros de la sesión.
        #expect(!picker.contains("RecordsViewModel("))
        #expect(!picker.contains("SessionState.shared.selected"))
        #expect(!picker.contains("SessionState.shared.excluded"))
    }

    /// «Más filtros» escribe el monto en la sesión: la hoja lo toma para sí y devuelve el de antes.
    @Test func moreFilters_givesTheSessionItsAmountBack() throws {
        let sheet = try Self.code("Yala/App/Views/Planning/PagosRecurrentes/RecurringFromRecordSheet.swift")
        let restore = try Self.slice(sheet, from: "private func takeAmountFromMoreFilters", to: "private func load()")
        #expect(restore.contains("filters.amountCondition = after.condition"))
        #expect(restore.contains("SessionState.shared.applyAmountFilter(before.condition, in: before.currency)"))
        #expect(sheet.contains(".sheet(isPresented: $filters.showFiltersSheet, onDismiss: takeAmountFromMoreFilters)"))
        #expect(sheet.contains(".onAppear(perform: rememberSessionAmount)"))
    }

    /// Los componentes de Registros siguen siendo los de Registros: la barra acepta un modelo propio y Registros le
    /// sigue pasando su ViewModel.
    @Test func theQuickFilterBar_acceptsAnyModel_andRecordsKeepsItsViewModel() throws {
        let bar = try Self.code("Yala/App/Views/Records/Components/RecordsQuickFilterBar.swift")
        #expect(bar.contains("struct RecordsQuickFilterBar<Model: RecordsQuickFilterModel, Trailing: View>: View"))
        #expect(bar.contains("extension RecordsViewModel: RecordsQuickFilterModel {}"))
        let field = try Self.code("Yala/App/Views/Records/Components/RecordsListSearchField.swift")
        #expect(field.contains("\nstruct RecordsListSearchField: View {"))
    }
}

// MARK: - Textos

@Suite("Reusar · los textos en los 16 idiomas")
struct ReusarRegistroStringsParityTests {

    static let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl",
                          "pt-BR", "pt-PT", "pt", "zh-Hans"]

    private static func table(_ locale: String, file: StaticString = #filePath) throws -> [String: String] {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = repoRoot.appending(path: "Yala/Resources/\(locale).lproj/ReusarRegistro.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: String])
    }

    @Test(arguments: locales)
    func everyLocale_hasEveryKey_withText(_ locale: String) throws {
        let reference = try Self.table("es-419")
        let strings = try Self.table(locale)
        #expect(Set(strings.keys) == Set(reference.keys), "\(locale): claves distintas de es-419.")
        for (key, value) in strings {
            #expect(!value.trimmingCharacters(in: .whitespaces).isEmpty, "\(locale): \(key) vacía.")
        }
    }

    /// `es` y `pt` sirven a quien habla esos idiomas fuera de sus regiones: copian a `es-419` y `pt-BR`.
    @Test func aliases_copyTheirReference() throws {
        #expect(try Self.table("es") == Self.table("es-419"))
        #expect(try Self.table("pt") == Self.table("pt-BR"))
    }

    @Test func variants_speakTheirOwnWay() throws {
        #expect(try Self.table("es-AR")["reusarRegistro.noMatchesHint"]?.contains("Probá") == true)
        #expect(try Self.table("pt-PT")["reusarRegistro.noMatches"]?.contains("registo") == true)
    }

    /// Lo que pidió Jürgen: un nombre corto, «Reusar», y nada de «Buscar».
    @Test func referenceSpanish_saysWhatWasAsked() throws {
        let es = try Self.table("es-419")
        #expect(es["reusarRegistro.button"] == "Reusar")
        #expect(es.values.allSatisfy { !$0.localizedCaseInsensitiveContains("buscar") })
    }

    /// La app empaqueta la tabla y la lee con la cadena de idioma de Yala (variante → padre), no con la del sistema.
    @Test(arguments: locales)
    func theAppBundle_resolvesTheTable(_ locale: String) throws {
        let path = try #require(Bundle.main.path(forResource: locale, ofType: "lproj"), "\(locale).lproj no está.")
        let bundle = try #require(Bundle(path: path))
        let resolution = LocaleResolution(bundle: bundle, parentBundle: nil, locale: Locale(identifier: locale))
        let button = ReusarRegistroText.string("button", resolution: resolution)
        #expect(button == (try Self.table(locale)["reusarRegistro.button"]))
        #expect(!button.hasPrefix("reusarRegistro."))
    }

    @Test func aMissingKey_comesBackRaw() {
        #expect(ReusarRegistroText.string("no.existe") == "reusarRegistro.no.existe")
    }
}
