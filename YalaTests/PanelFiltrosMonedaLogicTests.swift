//
//  PanelFiltrosMonedaLogicTests.swift
//  YalaTests
//
//  Lote 2.2 «panel / filtros / moneda» (2026-10-28): la regla única del monto (sin signo), la moneda del monto en
//  Exportar, la guarda que vacía un monto aplicado cuando su moneda deja de ser la única a la vista, y el cableado de
//  los bordes de los filtros combinados. Lógica pura y source-scan; lo que pide SwiftData vive en
//  `PanelPiesFilterParityTests`.
//

import Foundation
import Testing
@testable import Yala

// MARK: - El monto compara sin signo

@Suite("Monto: una regla, sin signo")
struct AmountFilterSignedAmountTests {

    /// El bug de las tartas y de Exportar: «Mayor a 100» con signo deja fuera un gasto de 150.
    @Test func greaterThan_letsAnExpenseOfMoreThanTheThresholdThrough() {
        let condition = AmountFilterCondition.greaterThan(100)
        #expect(condition.matches(signedAmount: -150))
        #expect(condition.matches(signedAmount: 150))
        #expect(!condition.matches(signedAmount: -50))
        #expect(!condition.matches(Decimal(-150)), "control: la comparación con signo sí lo dejaba fuera")
    }

    /// «Menor a 100» con signo dejaba pasar TODOS los gastos, también uno de 500.
    @Test func lessThan_keepsABigExpenseOut() {
        let condition = AmountFilterCondition.lessThan(100)
        #expect(!condition.matches(signedAmount: -500))
        #expect(condition.matches(signedAmount: -50))
    }

    @Test func between_isInclusiveOnTheMagnitude() {
        let condition = AmountFilterCondition.between(min: 50, max: 100)
        #expect(condition.matches(signedAmount: -50))
        #expect(condition.matches(signedAmount: -100))
        #expect(!condition.matches(signedAmount: -101))
    }

    /// Los tres consumidores pasan por la misma regla: ninguno vuelve a comparar `Decimal(transaction.amount)` a pelo.
    @Test func everyConsumerUsesTheSharedRule() throws {
        let files = [
            "Yala/Services/FilterService.swift",
            "Yala/App/ViewModels/PanelViewModel.swift",
            "Yala/Utils/TransactionsExportService.swift",
        ]
        for file in files {
            let code = codeOnly(try source(file))
            #expect(code.contains("amountCondition.matches(signedAmount: transaction.amount)"), "\(file)")
            #expect(!code.contains("amountCondition.matches(Decimal(transaction.amount))"), "\(file)")
            #expect(!code.contains("amountCondition.matches(amountDecimal)"), "\(file)")
        }
    }
}

// MARK: - Exportar: la moneda del monto

@Suite("Exportar: el monto en la moneda a la vista")
struct ExportAmountCurrencyTests {

    private let available: [CurrencyCode] = [.pen, .usd]

    /// El bug: en «Ocultar» con USD marcado, el campo decía USD, la moneda que se oculta.
    @Test func hideMode_labelsTheAmountWithTheVisibleCurrency() {
        #expect(ExportRecordsLogic.amountCurrency(marked: [.usd], available: available, isExcludeMode: true) == .pen)
        #expect(ExportRecordsLogic.amountCurrency(marked: [.pen], available: available, isExcludeMode: true) == .usd)
    }

    @Test func hideMode_withSeveralLeftOrNone_hasNoCurrency() {
        let three: [CurrencyCode] = [.pen, .usd, .eur]
        #expect(ExportRecordsLogic.amountCurrency(marked: [.usd], available: three, isExcludeMode: true) == nil)
        #expect(ExportRecordsLogic.amountCurrency(marked: [.pen, .usd], available: available, isExcludeMode: true) == nil)
    }

    /// «Mostrar solo» sigue como estaba: la marcada si es una; con todas marcadas (como arranca), ninguna.
    @Test func showMode_keepsItsRule() {
        #expect(ExportRecordsLogic.amountCurrency(marked: [.usd], available: available, isExcludeMode: false) == .usd)
        #expect(ExportRecordsLogic.amountCurrency(marked: [.pen, .usd], available: available, isExcludeMode: false) == nil)
        // El asistente arranca con las 54 marcadas: con una sola disponible, esa.
        #expect(ExportRecordsLogic.amountCurrency(
            marked: Set(CurrencyCode.allCases), available: [.pen], isExcludeMode: false) == .pen)
    }

    /// Sin moneda, el monto no se aplica: escrito con PEN y luego marcada otra, no compara cada registro en la suya.
    @Test func withoutACurrency_theAmountDoesNotApply() {
        #expect(ExportRecordsLogic.effectiveAmount(.greaterThan(100), currency: nil) == .any)
        #expect(ExportRecordsLogic.effectiveAmount(.greaterThan(100), currency: .pen) == .greaterThan(100))
    }

    /// Lo que se exporta, en «Ocultar USD» con «Mayor a 100»: los registros de PEN de más de 100 sin signo.
    @MainActor
    @Test func service_hideUSDAndMoreThan100_exportsTheBigPENRecords() {
        let txs = [
            TransactionItem(date: Date(), amount: -150, currencyCode: "PEN"),
            TransactionItem(date: Date(), amount: -50, currencyCode: "PEN"),
            TransactionItem(date: Date(), amount: 150, currencyCode: "PEN"),
            TransactionItem(date: Date(), amount: -150, currencyCode: "USD"),
        ]
        var filters = ExportFilters.default
        filters.isExcludeMode = true
        filters.selectedCurrencies = [.usd]
        filters.amountCondition = ExportRecordsLogic.effectiveAmount(
            .greaterThan(100),
            currency: ExportRecordsLogic.amountCurrency(marked: [.usd], available: available, isExcludeMode: true)
        )
        let result = TransactionsExportService.applyInMemoryFilters(txs, filters: filters)
        #expect(result.map(\.amount).sorted() == [-150, 150])
        #expect(result.allSatisfy { $0.currencyCode == "PEN" })
    }

    /// La vista decide con la regla, y en «Ocultar» la línea de ayuda es la de «deja a la vista una sola».
    @Test func exportView_usesTheRule() throws {
        let code = codeOnly(try source("Yala/App/Views/ExportWizard/ExportRecordsView.swift"))
        #expect(code.contains("ExportRecordsLogic.amountCurrency("))
        // En «Ocultar», las monedas de lo que se exporta, no las de las cuentas marcadas (que se ocultan).
        // Desde la card k4iz (2026-10-30) la decisión vive en `availableCurrencies`, que también ofrece los chips.
        #expect(code.contains("available: availableCurrencies,"))
        let offered = (code.components(separatedBy: "private var availableCurrencies: [CurrencyCode] {").dropFirst().first ?? "")
            .prefix(300).split(whereSeparator: \.isWhitespace).joined(separator: " ")
        #expect(offered.contains("isExcludeMode ? viewModel.currenciesLeftInView(hiding: selectedAccounts) : viewModel.availableCurrencies(selectedAccounts: selectedAccounts)"))
        #expect(code.contains("amountCondition: effectiveAmountCondition,"))
        #expect(code.contains("amountIsActive: effectiveAmountCondition.isActive,"))
        #expect(code.contains("currencyCode: amountCurrencyCode,"))
        #expect(code.contains("isExcludeMode ? L10n.UXL8C.Filters.amountNeedsOneVisibleCurrency : nil"))
        #expect(!code.contains("selectedCurrencies.count == 1 ? selectedCurrencies.first : nil"))
    }
}

// MARK: - El monto aplicado se vacía si su moneda deja de ser la única a la vista

/// La fuente de monedas fingida, mutable desde el test.
@MainActor
private final class FakeCurrencySource {
    var current: [CurrencyCode]?
    init(_ current: [CurrencyCode]?) { self.current = current }
}

@MainActor
@Suite("Monto aplicado: nunca mezcla monedas")
struct AppliedAmountCurrencyGuardTests {

    /// Una sesión propia (no la compartida) con la fuente de monedas fingida.
    private func session(available: [CurrencyCode]) -> (SessionState, FakeCurrencySource) {
        let session = SessionState()
        let source = FakeCurrencySource(available)
        session.currenciesWithRecords = { source.current }
        return (session, source)
    }

    /// Ticket 8vrl, camino 1 / borde 4: «Sin PEN» + «Mayor a 100» (en USD); la ✕ de «Sin PEN» dejaba el monto comparando
    /// los PEN con el umbral pensado para USD.
    @Test func removingTheHiddenCurrency_clearsTheAmount() {
        let (session, _) = session(available: [.pen, .usd])
        session.excludedCurrencies = [.pen]
        session.applyAmountFilter(.greaterThan(100), in: .usd)
        #expect(session.amountCondition == .greaterThan(100), "control: aplicado en la moneda a la vista, se queda")
        session.clearFilter(.currency(.pen))
        #expect(session.amountCondition == .any)
        #expect(session.amountCurrency == nil)
    }

    /// La ✕ de «Solo USD».
    @Test func removingTheOnlyShownCurrency_clearsTheAmount() {
        let (session, _) = session(available: [.pen, .usd])
        session.selectedCurrencies = [.usd]
        session.applyAmountFilter(.lessThan(50), in: .usd)
        session.selectedCurrencies.remove(.usd)
        #expect(session.amountCondition == .any)
    }

    /// «Ver solo» otra moneda desde un segmento.
    @Test func showingOnlyAnotherCurrency_clearsTheAmount() {
        let (session, _) = session(available: [.pen, .usd])
        session.selectedCurrencies = [.usd]
        session.applyAmountFilter(.greaterThan(100), in: .usd)
        session.selectedCurrencies = [.pen]
        #expect(session.amountCondition == .any)
    }

    /// Camino 2: el primer registro en una moneda nueva. Sin tocar el filtro, ya no queda una sola moneda a la vista.
    @Test func aFirstRecordInANewCurrency_clearsTheAmountOnTheNextDataBump() {
        let (session, source) = session(available: [.pen])
        session.applyAmountFilter(.greaterThan(100), in: .pen)
        session.incrementDataVersion()
        #expect(session.amountCondition == .greaterThan(100), "control: con las mismas monedas, se queda")
        source.current = [.pen, .usd]
        session.incrementDataVersion()
        #expect(session.amountCondition == .any)
    }

    /// Lo que no cambia la moneda a la vista no lo toca.
    @Test func aChangeThatKeepsTheSameCurrencyInView_keepsTheAmount() {
        let (session, _) = session(available: [.pen, .usd])
        session.excludedCurrencies = [.pen]
        session.applyAmountFilter(.greaterThan(100), in: .usd)
        session.excludedCurrencies.insert(.eur)
        session.selectedCurrencies = [.usd]
        #expect(session.amountCondition == .greaterThan(100))
        #expect(session.amountCurrency == .usd)
    }

    /// La hoja vuelca las listas y el monto en bloque: a mitad del volcado la guarda no actúa y al terminar mide el
    /// resultado. El caso discrimina: «Solo PEN» → «Sin USD» con el monto en PEN pasa por un instante sin moneda única
    /// (las dos listas vacías), y un monto que la hoja NO reescribe se perdería si la guarda actuara ahí.
    @Test func batchUpdate_doesNotActMidway_andDecidesAtTheEnd() {
        let (session, _) = session(available: [.pen, .usd])
        session.selectedCurrencies = [.pen]
        session.applyAmountFilter(.greaterThan(100), in: .pen)
        session.performBatchFilterUpdate {
            session.selectedCurrencies = []
            #expect(session.amountCondition == .greaterThan(100), "a mitad del volcado no actúa")
            session.excludedCurrencies = [.usd]
        }
        #expect(session.amountCondition == .greaterThan(100))
        #expect(session.amountCurrency == .pen)
    }

    /// Y si al terminar el bloque la moneda no es la única a la vista, lo vacía.
    @Test func batchUpdate_endingWithSeveralCurrenciesInView_clears() {
        let (session, _) = session(available: [.pen, .usd])
        session.performBatchFilterUpdate {
            session.applyAmountFilter(.greaterThan(100), in: .usd)
        }
        #expect(session.amountCondition == .any)
    }

    /// Sin moneda apuntada (un escritor que no la sabe) o sin fuente, la guarda no decide nada.
    @Test func withoutAStampOrASource_nothingIsTouched() {
        let (session, _) = session(available: [.pen, .usd])
        session.amountCondition = .greaterThan(100)
        session.incrementDataVersion()
        #expect(session.amountCondition == .greaterThan(100))

        let unsourced = SessionState()
        unsourced.applyAmountFilter(.greaterThan(100), in: .pen)
        unsourced.selectedCurrencies = [.usd]
        #expect(unsourced.amountCondition == .greaterThan(100))
    }

    /// Una fuente que no pudo contar (`nil`) tampoco vacía.
    @Test func anUncountableSource_doesNotClear() {
        let (session, source) = session(available: [.pen])
        session.applyAmountFilter(.greaterThan(100), in: .pen)
        source.current = nil
        session.incrementDataVersion()
        #expect(session.amountCondition == .greaterThan(100))
    }

    /// Vaciar el monto suelta su moneda.
    @Test func clearingTheAmount_dropsItsCurrency() {
        let (session, _) = session(available: [.pen])
        session.applyAmountFilter(.greaterThan(100), in: .pen)
        session.amountCondition = .any
        #expect(session.amountCurrency == nil)
    }

    @Test func keepsAmount_table() {
        let available: [CurrencyCode] = [.pen, .usd]
        #expect(RecordsAmountFilterCurrencyLogic.keepsAmount(appliedIn: .usd, included: [], excluded: [.pen], available: available))
        #expect(!RecordsAmountFilterCurrencyLogic.keepsAmount(appliedIn: .usd, included: [], excluded: [], available: available))
        #expect(!RecordsAmountFilterCurrencyLogic.keepsAmount(appliedIn: .usd, included: [.pen], excluded: [], available: available))
        #expect(RecordsAmountFilterCurrencyLogic.keepsAmount(appliedIn: .pen, included: [], excluded: [], available: [.pen]))
    }

    /// El cableado: la hoja aplica con su moneda, el arranque instala la fuente, y la guarda corre en los cuatro sitios.
    @Test func wiring() throws {
        let sheet = codeOnly(try source("Yala/App/Views/Records/RecordsFiltersView.swift"))
        #expect(sheet.contains("SessionState.shared.applyAmountFilter("))
        #expect(sheet.contains("amountCurrencyCode == nil ? .any : localAmountCondition, in: amountCurrencyCode"))
        #expect(!sheet.contains("recordsViewModel.amountCondition = amountCurrencyCode"))

        let boot = codeOnly(try source("Yala/App/AppBootstrapper.swift"))
        #expect(boot.contains("SessionState.shared.installCurrenciesWithRecordsSource(context)"))

        let session = codeOnly(try source("Yala/App/Models/SessionState.swift"))
        // Una por escritor, cada una en su sitio (más la definición).
        #expect(session.components(separatedBy: "revalidateAmountCurrency()").count - 1 == 5)
        for anchor in [
            "if overlaps(excludedCurrencies, selectedCurrencies) { excludedCurrencies.subtract(selectedCurrencies) }\n            revalidateAmountCurrency()",
            "if overlaps(selectedCurrencies, excludedCurrencies) { selectedCurrencies.subtract(excludedCurrencies) }\n            revalidateAmountCurrency()",
            "isBatchingFilterUpdate = false\n        \n        revalidateAmountCurrency()",
            "dataVersion += 1\n        \n        revalidateAmountCurrency()",
        ] {
            #expect(session.contains(anchor), "\(anchor.prefix(40))")
        }

        // La hoja y la guarda cuentan igual.
        let filters = codeOnly(try source("Yala/App/ViewModels/RecordsFiltersViewModel.swift"))
        #expect(filters.contains("CurrenciesWithRecords.load("))
    }
}

// MARK: - Filtros combinados: bordes 1 y 2 (cableado)

@Suite("Filtros combinados: bordes tras incluidos y excluidos")
struct CombinedFiltersEdgeWiringTests {

    /// Borde 1: el selector de categorías recibe la otra lista y la marca, también en la fila de la categoría.
    @Test func categorySelector_marksTheOtherList() throws {
        let sheet = codeOnly(try source("Yala/App/Views/Records/RecordsFiltersView.swift"))
        #expect(sheet.contains("otherListSubcategories: isEditingHidden ? localSelectedSubcategories : localExcludedSubcategories"))
        #expect(sheet.contains("otherListMarkColor: isEditingHidden ? theme.accent : DS.Semantic.errorForeground"))

        let selector = codeOnly(try source("Yala/App/Views/Filters/Components/CategorySelectorSheet.swift"))
        #expect(selector.contains(".overlay { otherListMark(hasSubcategoryInOtherList(category)) }"))
        #expect(selector.contains(".overlay { otherListMark(otherListSubcategories.contains(subcategory.persistentModelID)) }"))
    }

    /// Borde 2: los borrados de la persona sacan el valor del filtro, después de guardar.
    @Test func deletions_forgetTheValueAfterSaving() throws {
        let service = codeOnly(try source("Yala/Services/EntityDeletionService.swift"))
        #expect(service.contains("forgetDeletedFilterValues(categories: [categoryID], subcategories: subcategoryIDs)"))
        #expect(service.contains("forgetDeletedFilterValues(subcategories: [subcategoryID])"))
        #expect(service.contains("forgetDeletedFilterValues(tags: [tagID])"))
        // En el borrado de categoría, detrás del `save()`: un borrado que falla deja el filtro como estaba.
        let start = try #require(service.range(of: "func deleteCategory("))
        let end = try #require(service.range(of: "func deleteSubcategory("))
        let body = service[start.upperBound..<end.lowerBound]
        let save = try #require(body.range(of: "try context.save()"))
        let forget = try #require(body.range(of: "forgetDeletedFilterValues(categories: [categoryID]"))
        #expect(save.lowerBound < forget.lowerBound)

        let settings = codeOnly(try source("Yala/App/ViewModels/CategoriesSettingsListViewModel.swift"))
        #expect(settings.contains("forgetDeletedFilterValues(categories: [categoryID], subcategories: subcategoryIDs)"))
    }
}

// MARK: - Helpers

private func source(_ relative: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
}

private func codeOnly(_ code: String) -> String {
    code.split(separator: "\n").map { line -> Substring in
        if let range = line.range(of: "//") { return line[..<range.lowerBound] }
        return line
    }.joined(separator: "\n")
}
