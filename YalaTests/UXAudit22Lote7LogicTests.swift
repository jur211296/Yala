//
//  UXAudit22Lote7LogicTests.swift
//  YalaTests
//
//  Auditoría UX 2.2, lote 7 (cuentas, categorías, etiquetas, favoritos e importar): las cuentas que
//  hacen las pantallas nuevas.
//
//  Fichero propio: `makeTestContext()` reusa el container por `#fileID`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Auditoría UX 2.2 · lote 7", .serialized)
@MainActor
struct UXAudit22Lote7LogicTests {

    // MARK: - L7-6 · Editar el saldo

    @Test func correction_positiveAccount_differenceAndNewInitial() {
        let plan = AccountBalanceCorrectionLogic.plan(current: 800, currentInitialBalance: 1_000, target: 1_000)
        #expect(plan.difference == 200)
        #expect(plan.newInitialBalance == 1_200)
        #expect(plan.resultingBalance == 1_000)
        #expect(plan.needsCorrection)
    }

    /// Tarjeta que debe S/ 1,200 y de verdad debe S/ 1,000: la diferencia es +200 y el saldo de partida pasa
    /// de −1,200 a −1,000.
    @Test func correction_creditCardInDebt_movesTowardZero() {
        let plan = AccountBalanceCorrectionLogic.plan(current: -1_200, currentInitialBalance: -1_200, target: -1_000)
        #expect(plan.difference == 200)
        #expect(plan.newInitialBalance == -1_000)
        #expect(plan.resultingBalance == -1_000)
    }

    @Test func correction_sameBalance_needsNothing() {
        let plan = AccountBalanceCorrectionLogic.plan(current: 500.004, currentInitialBalance: 0, target: 500)
        #expect(!plan.needsCorrection)
        let cent = AccountBalanceCorrectionLogic.plan(current: 500, currentInitialBalance: 0, target: 500.02)
        #expect(cent.needsCorrection)
    }

    /// Cuenta con saldo inicial 1,000 y un gasto de 200: hoy 800.
    private func makeEditViewModel(editsTodayBalance: Bool) throws -> (AccountFormViewModel, ModelContext) {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Cuenta", currencyCode: "PEN")
        let category = makeTestCategory(context: context)
        let sub = makeTestSubcategory(context: context, category: category)
        let opening = makeTestTransaction(
            context: context, amount: 1_000, date: Date().addingTimeInterval(-86_400 * 10),
            account: account, category: category, subcategory: sub)
        opening.balanceAdjustmentType = InitialBalanceService.typeInitialBalance
        _ = makeTestTransaction(context: context, amount: -200, account: account, category: category, subcategory: sub)
        try context.save()
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        vm.editsTodayBalance = editsTodayBalance
        vm.setContext(context)
        return (vm, context)
    }

    @Test func balanceEditor_startsEmpty_andBothOptionsLeadToTheTypedBalance() throws {
        let (vm, _) = try makeEditViewModel(editsTodayBalance: true)
        #expect(vm.currentBalance == 800)
        #expect(vm.balanceText.isEmpty)
        #expect(vm.isPositive)
        #expect(!vm.needsAdjustment)

        vm.balanceText = "1000"
        #expect(vm.needsAdjustment)
        #expect(vm.balanceCorrection?.difference == 200)

        // Cambiar de opción no toca el número: los dos caminos corrigen la misma diferencia.
        vm.selectedAdjustmentMode = .changeInitialBalance
        vm.adjustmentModeChanged()
        #expect(vm.balanceText == "1000")
        #expect(vm.balanceCorrection?.newInitialBalance == 1_200)
        #expect(vm.balanceCorrection?.resultingBalance == 1_000)
    }

    /// Fuera de «Editar el saldo» (modo solo gastos) el campo sigue pidiendo el saldo de partida.
    @Test func legacyEditor_keepsTheStartingBalanceMeaning() throws {
        let (vm, _) = try makeEditViewModel(editsTodayBalance: false)
        vm.selectedAdjustmentMode = .changeInitialBalance
        vm.adjustmentModeChanged()
        #expect(vm.balanceText == "1000.00")
        #expect(vm.balanceCorrection == nil)
        #expect(!vm.needsAdjustment)
    }

    // MARK: - L7-5 · Cambios sin guardar

    @Test func unsavedChanges_onlyAfterTheUserTypes() throws {
        let (vm, _) = try makeEditViewModel(editsTodayBalance: true)
        #expect(!vm.hasUnsavedChanges)
        vm.name = "Cuenta nueva"
        #expect(vm.hasUnsavedChanges)
        vm.name = "Cuenta"
        #expect(!vm.hasUnsavedChanges)
        vm.balanceText = "5"
        #expect(vm.hasUnsavedChanges)
    }

    @Test func unsavedChanges_newAccount_signAloneIsNotAChange() throws {
        let context = try makeTestContext()
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.setContext(context)
        #expect(!vm.hasUnsavedChanges)
        vm.isPositive = false
        #expect(!vm.hasUnsavedChanges)
        vm.selectedType = .savings
        #expect(vm.hasUnsavedChanges)
    }

    // MARK: - L7-7 · El saldo al cambiar la moneda

    @Test func currencyPreview_sumsEachRowConvertedOnItsDate() {
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = day1.addingTimeInterval(86_400)
        let rows = [
            AccountCurrencyBalancePreviewLogic.Row(amount: 2_000, currencyCode: "MXN", date: day1),
            AccountCurrencyBalancePreviewLogic.Row(amount: -100, currencyCode: "MXN", date: day2),
        ]
        let preview = AccountCurrencyBalancePreviewLogic.preview(rows: rows, to: "USD") { amount, _, _, date in
            // Un tipo distinto por día: el saldo no es «saldo × tipo de hoy».
            let rate: Decimal = date == day1 ? Decimal(string: "0.05")! : Decimal(string: "0.06")!
            return (Decimal(amount) * rate, true)
        }
        #expect(preview.before == 1_900)
        #expect(preview.after == 94)
        #expect(preview.isExact)
    }

    @Test func currencyPreview_inexactRateMarksEstimate_andTargetRowsStay() {
        let rows = [
            AccountCurrencyBalancePreviewLogic.Row(amount: 10, currencyCode: "USD", date: .now),
            AccountCurrencyBalancePreviewLogic.Row(amount: 100, currencyCode: "PEN", date: .now),
        ]
        let preview = AccountCurrencyBalancePreviewLogic.preview(rows: rows, to: "USD") { amount, _, _, _ in
            (Decimal(amount) / 4, false)
        }
        #expect(preview.after == 35)
        #expect(!preview.isExact)
    }

    // MARK: - L7-8 · La moneda nueva en el Panel

    @Test func secondarySuggestion_addReplaceOrNothing() {
        typealias L = SecondaryCurrencySuggestionLogic
        #expect(L.suggestion(saved: "PEN", preferred: "PEN", stored: "") == nil)
        #expect(L.suggestion(saved: "USD", preferred: "PEN", stored: "USD,EUR") == nil)
        #expect(L.suggestion(saved: "EUR", preferred: "PEN", stored: "USD") == .add("EUR"))
        #expect(L.suggestion(saved: "MXN", preferred: "PEN", stored: "USD,EUR")
            == .replace(new: "MXN", current: ["USD", "EUR"]))
    }

    @Test func secondarySuggestion_applyingKeepsTheLimitAndTheOrder() {
        typealias L = SecondaryCurrencySuggestionLogic
        #expect(L.applying("MXN", replacing: "USD", to: "USD,EUR") == "MXN,EUR")
        #expect(L.applying("MXN", replacing: "EUR", to: "USD,EUR") == "USD,MXN")
        #expect(L.applying("EUR", replacing: nil, to: "USD") == "USD,EUR")
        #expect(L.applying("USD", replacing: nil, to: "USD") == "USD")
    }

    // MARK: - L7-9 · Buscar una moneda

    @Test func currencySearch_byNameCodeAliasAndWithoutAccents() {
        #expect(CurrencySearchLogic.filter([.mxn, .pen, .usd], query: "mxn") == [.mxn])
        #expect(CurrencySearchLogic.filter([.mxn, .pen, .usd], query: "soles") == [.pen])
        #expect(CurrencySearchLogic.filter([.mxn, .pen, .usd], query: "  ").count == 3)
        #expect(CurrencySearchLogic.matches(name: "Sol peruano", code: "PEN", aliases: [], query: "PERUANO"))
        #expect(CurrencySearchLogic.matches(name: "Dólar estadounidense", code: "USD", aliases: [], query: "dolar"))
        #expect(!CurrencySearchLogic.matches(name: "Euro", code: "EUR", aliases: [], query: "dólar"))
    }

    // MARK: - L7-15 · L7-17 · Vista previa y resultado de importar

    @Test func importPreview_summarisesCountDatesTotalsAndSample() {
        let d1 = Date(timeIntervalSince1970: 1_760_000_000)
        let d2 = d1.addingTimeInterval(86_400 * 3)
        let rows = [
            ImportPreview.Row(date: d2, amount: -50, currencyCode: "PEN", categoryName: "A", subcategoryName: "a"),
            ImportPreview.Row(date: d1, amount: -25.5, currencyCode: "PEN", categoryName: "B", subcategoryName: "b"),
            ImportPreview.Row(date: d1, amount: 10, currencyCode: "USD", categoryName: "C", subcategoryName: "c"),
            ImportPreview.Row(date: d2, amount: -4.5, currencyCode: "PEN", categoryName: "D", subcategoryName: "d"),
        ]
        let preview = ImportPreviewLogic.make(
            rows: rows, accountNames: ["Cuenta"], failures: ["Fila 9: x"], ignoredFutureCount: 2)
        #expect(preview.count == 4)
        #expect(preview.firstDate == d1)
        #expect(preview.lastDate == d2)
        #expect(preview.totals == [
            ImportPreview.Total(currencyCode: "PEN", amount: -80),
            ImportPreview.Total(currencyCode: "USD", amount: 10),
        ])
        #expect(preview.sampleRows.map(\.categoryName) == ["A", "B", "C"])
        #expect(preview.canImport)
        #expect(preview.ignoredFutureCount == 2)
    }

    @Test func importPreview_emptyCannotImport() {
        let preview = ImportPreviewLogic.make(rows: [], accountNames: ["Cuenta"], failures: ["Fila 2: x"], ignoredFutureCount: 0)
        #expect(!preview.canImport)
        #expect(preview.firstDate == nil)
        #expect(preview.totals.isEmpty)
    }

    @Test func importOutcome_listsWhatDidNotGetIn_andCutsTheList() {
        let none = ImportPreviewLogic.outcomeMessage(
            importedLine: "OK", failures: [], notImportedLine: { "\($0) no" }, moreLine: { "+\($0)" })
        #expect(none == "OK")

        let failures = (1...12).map { "Fila \($0)" }
        let message = ImportPreviewLogic.outcomeMessage(
            importedLine: "OK", failures: failures, notImportedLine: { "\($0) no" }, moreLine: { "+\($0)" })
        let lines = message.components(separatedBy: "\n")
        #expect(lines.first == "OK")
        #expect(lines.contains("12 no"))
        #expect(lines.contains("Fila 10"))
        #expect(!lines.contains("Fila 11"))
        #expect(lines.last == "+2")
    }

    @Test func importErrors_rowNumberOnlyForRowErrors_andNoRawHeader() {
        #expect(ImportError.invalidHeader(found: "fecha,monto").rowNumber == nil)
        #expect(ImportError.emptyFile.rowNumber == nil)
        #expect(ImportError.invalidDate(row: 71, value: "x").rowNumber == 71)
        #expect(ImportError.missingAccountForCurrency(row: 4, currency: "USD").rowNumber == 4)

        let header = ImportError.invalidHeader(found: "fecha,monto").errorDescription ?? ""
        #expect(!header.contains("fecha,monto"), "El aviso enseñaba el encabezado crudo.")
        #expect(header.contains("subcategory"))

        let unknown = ImportError.unknownCategory(row: 71, name: "Estudios").errorDescription ?? ""
        #expect(unknown.contains("71") && unknown.contains("Estudios"))
        #expect(unknown.contains(L10n.Import.createCategories), "El aviso no nombra el interruptor que lo arregla.")
        for error in [
            ImportError.invalidFileExtension, .unreadableFile, .emptyFile, .invalidHeader(found: ""),
            .invalidColumnCount(row: 1, expected: 7, found: 4), .invalidAmount(row: 1, value: "x"),
            .invalidCurrency(row: 1, value: "x"), .currencyMismatchWithAccount(row: 1, fileCurrency: "USD", accountCurrency: "PEN"),
            .emptyCategory(row: 1), .emptySubcategory(row: 1), .unknownSubcategory(row: 1, categoryName: "a", name: "b"),
            .missingAccountForCurrency(row: 1, currency: "USD"),
        ] {
            let text = error.errorDescription ?? ""
            #expect(!text.contains("import.error."), "Clave cruda: \(text)")
            #expect(!text.isEmpty)
        }
    }

    // MARK: - L7-17 · Una fila mala no para el archivo

    private func writeCSV(_ body: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("l7-\(UUID().uuidString).csv")
        try body.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func removeFile(_ url: URL) {
        do { try FileManager.default.removeItem(at: url) } catch {
            Issue.record("UXAudit22Lote7LogicTests: Error: \(error)")
        }
    }

    private static let csvWithABadRowInTheMiddle = """
        date,amount,currency,category,subcategory
        2026-01-14,-50.00,PEN,Alimentación,Delivery
        2026-01-15,no-es-un-numero,PEN,Alimentación,Delivery
        2026-01-16,-20.00,PEN,Estudios,Libros
        2026-01-17,-30.00,PEN,Alimentación,Delivery
        """

    private func makeImportFixture() throws -> (ModelContext, Account) {
        let context = try makeTestContext()
        let category = Category(name: "Alimentación", colorHex: "#22C55E", isIncome: false)
        context.insert(category)
        context.insert(Subcategory(name: "Delivery", category: category))
        let account = Account(
            name: "Cuenta", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard", type: "general")
        context.insert(account)
        try context.save()
        return (context, account)
    }

    @Test func importSkippingRows_importsTheGoodOnes_andListsTheBad() async throws {
        let (context, account) = try makeImportFixture()
        let url = try writeCSV(Self.csvWithABadRowInTheMiddle)
        defer { removeFile(url) }

        var created = 0
        let result = try await TransactionCSVImportService.importCSV(
            from: url, into: account, in: context, allowCreatingNewCategories: false, skippingInvalidRows: true
        ) { _, _ in created += 1 }

        #expect(result.createdCount == 2)
        #expect(created == 2)
        #expect(result.failures.map(\.rowNumber) == [3, 4])
    }

    @Test func importWithoutSkipping_stillStopsAtTheFirstBadRow() async throws {
        let (context, account) = try makeImportFixture()
        let url = try writeCSV(Self.csvWithABadRowInTheMiddle)
        defer { removeFile(url) }

        await #expect(throws: ImportError.self) {
            _ = try await TransactionCSVImportService.importCSV(
                from: url, into: account, in: context, allowCreatingNewCategories: false
            ) { _, _ in }
        }
    }

    /// La vista previa corre la importación de verdad en un contexto aparte: cuenta lo mismo que hará
    /// «Importar», y no deja NADA en el store (ni registros ni la categoría que habría creado).
    @Test func importPreview_countsLikeTheImport_andLeavesTheStoreUntouched() async throws {
        let (context, account) = try makeImportFixture()
        let url = try writeCSV(Self.csvWithABadRowInTheMiddle)
        defer { removeFile(url) }

        let preview = try await ImportPreviewService.preview(
            of: url, target: .single(account), allowCreatingNewCategories: true, container: context.container)

        // Creando categorías, «Estudios › Libros» entra: 3 buenas y la del importe malo fuera.
        #expect(preview.count == 3)
        #expect(preview.failures.count == 1)
        #expect(preview.accountNames == ["Cuenta"])
        #expect(preview.totals == [ImportPreview.Total(currencyCode: "PEN", amount: -100)])

        #expect(try context.fetchCount(FetchDescriptor<TransactionItem>()) == 0)
        let studies = "Estudios"
        #expect(try context.fetchCount(FetchDescriptor<YalaCategory>(predicate: #Predicate { $0.name == studies })) == 0)
    }

    // MARK: - L7-10 · Mover los registros de una categoría y eliminarla

    @Test func moveRecords_movesEverythingAndDeletesTheCategory() throws {
        let context = try makeTestContext()
        let deletion = EntityDeletionService.shared
        let account = makeTestAccount(context: context)
        let travel = makeTestCategory(context: context, name: "Viajes")
        let hotel = makeTestSubcategory(context: context, name: "Hotel", category: travel)
        let flights = makeTestSubcategory(context: context, name: "Vuelos", category: travel)
        let food = makeTestCategory(context: context, name: "Comida")
        let restaurant = makeTestSubcategory(context: context, name: "Restaurante", category: food)

        _ = makeTestTransaction(context: context, amount: -100, account: account, category: travel, subcategory: hotel)
        _ = makeTestTransaction(context: context, amount: -300, account: account, category: travel, subcategory: flights)
        // Un registro antiguo con la subcategoría pero sin la categoría: también cuenta y también se mueve.
        let orphan = makeTestTransaction(context: context, amount: -5, account: account, category: travel, subcategory: hotel)
        orphan.category = nil
        let scheduled = ScheduledPayment(
            name: "Hotel mensual", amount: 50, currencyCode: "PEN", subcategory: hotel, nextDueDate: .now)
        context.insert(scheduled)
        let favorite = FavoritePayment(name: "Vuelo", subcategory: flights)
        context.insert(favorite)
        let budget = makeTestBudget(context: context, subcategories: [hotel, restaurant])
        budget.setSubcategoryIDs(from: [hotel, restaurant])
        try context.save()
        let hotelID = hotel.shortcutID.uuidString

        #expect(try CategoryRecordsMoveService.recordCount(of: travel, context: context) == 3)

        let moved = try CategoryRecordsMoveService.moveAllAndDelete(
            from: travel, to: restaurant, context: context, deletionService: deletion)

        #expect(moved == 3)
        let rows = try context.fetch(FetchDescriptor<TransactionItem>())
        #expect(rows.count == 3, "Mover no puede perder ningún registro.")
        #expect(rows.allSatisfy { $0.subcategory?.persistentModelID == restaurant.persistentModelID })
        #expect(rows.allSatisfy { $0.category?.persistentModelID == food.persistentModelID })
        #expect(scheduled.subcategory?.persistentModelID == restaurant.persistentModelID)
        #expect(favorite.subcategory?.persistentModelID == restaurant.persistentModelID)
        let travelName = "Viajes"
        #expect(try context.fetchCount(FetchDescriptor<YalaCategory>(predicate: #Predicate { $0.name == travelName })) == 0)
        #expect(!(budget.subcategoryIDs ?? "").contains(hotelID), "El presupuesto se quedó con el UUID de una subcategoría borrada.")
    }

    @Test func moveRecords_rejectsDestinationsOfTheSameCategoryOrOtherKind() throws {
        let context = try makeTestContext()
        let deletion = EntityDeletionService.shared
        let travel = makeTestCategory(context: context, name: "Viajes")
        let hotel = makeTestSubcategory(context: context, name: "Hotel", category: travel)
        let salary = makeTestCategory(context: context, name: "Sueldo", isIncome: true)
        let monthly = makeTestSubcategory(context: context, name: "Mensual", category: salary)
        let food = makeTestCategory(context: context, name: "Comida")
        let restaurant = makeTestSubcategory(context: context, name: "Restaurante", category: food)
        try context.save()

        #expect(throws: CategoryRecordsMoveService.Failure.invalidDestination) {
            try CategoryRecordsMoveService.moveAllAndDelete(
                from: travel, to: hotel, context: context, deletionService: deletion)
        }
        #expect(throws: CategoryRecordsMoveService.Failure.invalidDestination) {
            try CategoryRecordsMoveService.moveAllAndDelete(
                from: travel, to: monthly, context: context, deletionService: deletion)
        }

        let destinations = CategoryRecordsMoveService.destinations(
            for: travel, among: [hotel, monthly, restaurant])
        #expect(destinations.map(\.category.name) == ["Comida"])
        #expect(destinations.first?.subcategories.map(\.name) == ["Restaurante"])
    }

    // MARK: - Textos

    @Test func lote7Accessors_neverReturnTheRawKey() {
        let texts = [
            L10n.UXL7.balanceRequiredHint, L10n.UXL7.generalTypeHint,
            L10n.UXL7.BalanceEdit.question, L10n.UXL7.BalanceEdit.result("Cuenta", "S/ 1"),
            L10n.UXL7.BalanceEdit.initialChange("S/ 1", "S/ 2"),
            L10n.UXL7.currencyBalanceLine("MXN 1", "≈ USD 2"), L10n.UXL7.currencyIncludesInitialBalance,
            L10n.UXL7.Secondary.addTitle("EUR"), L10n.UXL7.Secondary.addMessage("EUR", "PEN"),
            L10n.UXL7.Secondary.replaceMessage("USD", "EUR", "MXN"), L10n.UXL7.Secondary.replaceButton("USD", "MXN"),
            L10n.UXL7.CurrencyPicker.searchPrompt, L10n.UXL7.CurrencyPicker.noResults("zz"),
            L10n.UXL7.CurrencyPicker.secondaryFull, L10n.UXL7.recordsCount(3),
            L10n.UXL7.Categories.cannotDeleteChoiceMessage(62), L10n.UXL7.Categories.moveConfirmMessage("A", "B › c", "3"),
            L10n.UXL7.Categories.needExplainer, L10n.UXL7.Tags.deleteMessage(4), L10n.UXL7.Tags.deleteMessage(0),
            L10n.UXL7.Favorites.createAction, L10n.UXL7.Favorites.delete,
            L10n.UXL7.ImportScreen.columnsTitle, L10n.UXL7.ImportScreen.createCategoriesOff,
            L10n.UXL7.ImportReview.summary(70, "Cuenta"), L10n.UXL7.ImportReview.importButton(70),
            L10n.UXL7.ImportReview.failuresHeader(1), L10n.UXL7.ImportReview.notImported(2),
            L10n.UXL7.ImportReview.futureIgnored(1), L10n.UXL7.ImportReview.more(2),
        ]
        for text in texts {
            #expect(!text.isEmpty)
            #expect(!text.contains("account.") && !text.contains("import.") && !text.contains("category.")
                && !text.contains("currencyPicker.") && !text.contains("favorites.") && !text.contains("tag.")
                && !text.contains("records.count") && !text.contains("need."), "Clave cruda: \(text)")
        }
        #expect(L10n.UXL7.recordsCount(1) != L10n.UXL7.recordsCount(2), "El recuento no tiene plural.")
    }

    @Test func typeChipHint_generalHasItsOwnSentence() {
        #expect(AccountTypeChips.hint(for: .general) == L10n.UXL7.generalTypeHint)
        #expect(AccountTypeChips.hint(for: .savings) == AccountType.savings.typeDescription)
        #expect(AccountType.allCases.allSatisfy { !AccountTypeChips.hint(for: $0).isEmpty })
    }
}
