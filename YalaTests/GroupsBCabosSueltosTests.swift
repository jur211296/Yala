//
//  GroupsBCabosSueltosTests.swift
//  YalaTests
//
//  Grupos B · cabos sueltos (encargo 2026-11-02-grupos-b-cabos-sueltos), reglas puras y su cableado:
//  - 10u2: con dos subcategorías homónimas, formulario y puente eligen la misma.
//  - 00xj: lo por cobrar dice «Por cobrar» / «Venta» fuera de Registros.
//  - 6u5f: la pata que lleva la receta abre «Partir» en vez de cambiar su categoría suelta.
//  - oibr: la entrada de una recarga sabe de qué grupo es por su salida.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - 10u2 · homónimas

@Suite("Grupos B · 10u2: la categoría que viaja por nombre")
struct GroupSubcategoryMatchLogicTests {

    private typealias C = GroupSubcategoryMatchLogic.Candidate

    private func c(_ name: String, income: Bool = false, system: Bool = false, hidden: Bool = false,
                   key: String = "b") -> C {
        C(name: name, isSystem: system, isHidden: hidden, isIncome: income, key: key)
    }

    /// El selector no ofrece las ocultas: una oculta de gasto no le gana a la de ingreso que se eligió.
    @Test func aVisibleOne_winsOverAHiddenOne_beforeTheType() {
        let hiddenExpense = c("Otros", hidden: true, key: "a")
        let income = c("Otros", income: true, key: "z")
        #expect(GroupSubcategoryMatchLogic.bestIndex(for: "Otros", in: [hiddenExpense, income]) == 1)
    }

    @Test func twoHomonyms_theExpenseOneWins_inEitherOrder() {
        let income = c("Otros", income: true, key: "a")
        let expense = c("Otros", income: false, key: "z")
        #expect(GroupSubcategoryMatchLogic.bestIndex(for: "Otros", in: [income, expense]) == 1)
        #expect(GroupSubcategoryMatchLogic.bestIndex(for: "otros", in: [expense, income]) == 0)
    }

    @Test func aUserOne_winsOverASystemOne() {
        let system = c("Préstamo", system: true, key: "a")
        let user = c("Préstamo", income: true, key: "z")
        #expect(GroupSubcategoryMatchLogic.bestIndex(for: "Préstamo", in: [system, user]) == 1)
    }

    @Test func sameTypeHomonyms_theSmallestKeyWins_whateverTheFetchOrder() {
        let b = c("Taxi", key: "B"), a = c("Taxi", key: "A")
        #expect(GroupSubcategoryMatchLogic.bestIndex(for: "Taxi", in: [b, a]) == 1)
        #expect(GroupSubcategoryMatchLogic.bestIndex(for: "Taxi", in: [a, b]) == 0)
    }

    @Test func exact_beatsContains_evenIfContainsIsAnExpense() {
        let partial = c("Ventas de ropa", key: "a")
        let exact = c("Ventas", income: true, key: "z")
        #expect(GroupSubcategoryMatchLogic.bestIndex(for: "Ventas", in: [partial, exact]) == 1)
    }

    @Test func containsFallback_followsTheSameOrder() {
        let incomeLong = c("Otros ingresos", income: true, key: "a")
        let expenseLong = c("Otros gastos", key: "z")
        #expect(GroupSubcategoryMatchLogic.bestIndex(for: "Otros", in: [incomeLong, expenseLong]) == 1)
    }

    @Test func noNameOrNoMatch_isNil() {
        #expect(GroupSubcategoryMatchLogic.bestIndex(for: nil, in: [c("Taxi")]) == nil)
        #expect(GroupSubcategoryMatchLogic.bestIndex(for: "", in: [c("Taxi")]) == nil)
        #expect(GroupSubcategoryMatchLogic.bestIndex(for: "Cine", in: [c("Taxi")]) == nil)
    }
}

/// Formulario y puente con dos «Otros» de verdad en el store (la hecha-cuando de la card).
@Suite("Grupos B · 10u2: formulario y puente con dos homónimas", .serialized)
@MainActor
struct GroupSubcategoryHomonymsTests {

    private func store() throws -> (ModelContext, income: Subcategory, expense: Subcategory) {
        let context = try makeTestContext()
        let incomeCat = makeTestCategory(context: context, name: "Ingresos", isIncome: true)
        let expenseCat = makeTestCategory(context: context, name: "Gastos")
        // La de ingreso se inserta primero: con el fetch de antes era la que salía.
        let income = makeTestSubcategory(context: context, name: "Otros", category: incomeCat)
        let expense = makeTestSubcategory(context: context, name: "Otros", category: expenseCat)
        try context.save()
        return (context, income, expense)
    }

    private func makeVM(_ context: ModelContext) -> GroupExpenseViewModel {
        let me = SplitMember(displayName: "Yo", isCurrentUser: true)
        let ana = SplitMember(displayName: "Ana")
        let group = SplitGroup(name: "Ventas con Ana", currencyCode: "PEN")
        let vm = GroupExpenseViewModel(group: group, members: [me, ana], memberNameLookup: [:])
        vm.setContext(context)
        vm.currencyCode = "PEN"
        vm.isGroupsOnlyOverride = false
        vm.effectiveBridgeEnabledOverride = true
        vm.paidByMemberID = me.id.uuidString
        return vm
    }

    @Test func theBridge_picksTheExpenseOne() throws {
        let (context, _, expense) = try store()
        let matched = GroupTransactionBridge.matchSubcategory(name: "Otros", context: context)
        #expect(matched?.persistentModelID == expense.persistentModelID)
    }

    @Test func choosingTheIncomeOne_theFormAlignsWithTheBridge_andItIsNotASale() throws {
        let (context, income, _) = try store()
        let vm = makeVM(context)
        vm.selectedSubcategory = income
        #expect(vm.isSale, "Control: elegida tal cual, la de ingreso es una venta.")

        vm.alignSubcategoryWithBridge()

        let bridge = GroupTransactionBridge.matchSubcategory(name: "Otros", context: context)
        #expect(vm.selectedSubcategory?.persistentModelID == bridge?.persistentModelID,
                "El formulario y el puente no eligen la misma «Otros».")
        #expect(!vm.isSale, "El formulario decide venta con una subcategoría que el puente no verá.")
        #expect(vm.isAccountRequired, "Lo que el puente leerá es un gasto: pide la cuenta.")
    }

    @Test func editing_resolvesTheSameOneAsTheBridge() throws {
        let (context, _, expense) = try store()
        let vm = makeVM(context)
        let shared = SplitExpense(groupZoneID: "z", amount: 50, currencyCode: "PEN", expenseDescription: "Algo",
                                  paidByMemberID: vm.paidByMemberID, subcategoryName: "Otros")
        vm.prefill(from: shared, shares: [])
        #expect(vm.selectedSubcategory?.persistentModelID == expense.persistentModelID)
    }

    @Test func withoutHomonyms_aloneIncomeOne_staysASale() throws {
        let context = try makeTestContext()
        let incomeCat = makeTestCategory(context: context, name: "Ingresos", isIncome: true)
        let ventas = makeTestSubcategory(context: context, name: "Ventas", category: incomeCat)
        try context.save()
        let vm = makeVM(context)
        vm.selectedSubcategory = ventas
        vm.alignSubcategoryWithBridge()
        #expect(vm.selectedSubcategory?.persistentModelID == ventas.persistentModelID)
        #expect(vm.isSale)
    }
}

// MARK: - 00xj · lo por cobrar fuera de Registros

@Suite("Grupos B · 00xj: lo por cobrar fuera de Registros")
@MainActor
struct GroupReceivableSurfacesTests {

    @Test func theSuccessTitle_ofASale_isNotTheExpenseOne() {
        #expect(GroupExpenseSuccessLogic.title(isSale: false, isEditMode: false) == .expenseCreated)
        #expect(GroupExpenseSuccessLogic.title(isSale: false, isEditMode: true) == .expenseUpdated)
        #expect(GroupExpenseSuccessLogic.title(isSale: true, isEditMode: false) == .saleCreated)
        #expect(GroupExpenseSuccessLogic.title(isSale: true, isEditMode: true) == .saleUpdated)
    }

    @Test func theDetailType_ofAReceivableLeg_saysReceivable() {
        let caption = RecordRowPresentationLogic.categoryCaption(
            "Ingreso", adjustmentType: TransactionItem.adjustmentTypeReceivable)
        #expect(caption == "Ingreso • \(L10n.Records.receivable)")
        #expect(RecordRowPresentationLogic.categoryCaption("Ingreso", adjustmentType: nil) == "Ingreso")
    }

    @Test func theWidgetRow_ofAReceivableLeg_saysSo_andANormalOneDoesNot() {
        let leg = TransactionItem(date: .now, amount: 120, currencyCode: "PEN")
        leg.balanceAdjustmentType = TransactionItem.adjustmentTypeReceivable
        #expect(WidgetDataCache.widgetTransaction(leg, currencyCode: "PEN").isReceivable == true)
        let normal = TransactionItem(date: .now, amount: 120, currencyCode: "PEN")
        #expect(WidgetDataCache.widgetTransaction(normal, currencyCode: "PEN").isReceivable == false)
    }

    /// Un snapshot escrito por la versión anterior no trae la clave: tiene que seguir decodificando (si no, se apagan todos
    /// los widgets).
    @Test func aSnapshotRowWithoutTheKey_stillDecodes() throws {
        let json = #"""
        {"id":"1","date":0,"amount":-10,"currencyCode":"PEN","isIncome":false,"amountInPreferredCurrency":-10}
        """#
        let row = try JSONDecoder().decode(WidgetTransaction.self, from: Data(json.utf8))
        #expect(row.isReceivable == nil)
    }

    /// La copia del DTO del widget (que `YalaTests` no compila) lleva el campo opcional, como la de la app.
    @Test func theWidgetCopyOfTheRow_hasTheOptionalField_andPaintsItGray() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let dto = try String(contentsOf: root.appendingPathComponent("YalaWidgets/Services/WidgetDataService.swift"),
                             encoding: .utf8)
        #expect(dto.contains("var isReceivable: Bool? = nil"))
        let widget = try String(contentsOf: root.appendingPathComponent("YalaWidgets/Widgets/LatestRecordsWidget.swift"),
                                encoding: .utf8)
        #expect(widget.contains("if isReceivable { return .color(.secondary) }"))
        #expect(widget.contains(#"String(localized: "widget.ui.receivable", bundle: .main)"#))
    }
}

// MARK: - 6u5f · la pata con receta abre «Partir»

@Suite("Grupos B · 6u5f: la pata que lleva la receta")
struct GroupSplitRecipeLegEditingTests {

    private let recipe = GroupSplitLinesRecipe.encode([
        .expense(amount: 80, subcategoryID: UUID()), .expense(amount: 20, subcategoryID: UUID()),
    ])

    @Test func holdsRecipe_onlyForARecipe() {
        #expect(GroupSplitLinesEntryLogic.holdsRecipe(recipe))
        #expect(!GroupSplitLinesEntryLogic.holdsRecipe(nil))
        #expect(!GroupSplitLinesEntryLogic.holdsRecipe(GroupSplitLinesRecipe.encodeDerivedMarker(lineID: UUID())))
    }

    @Test func theEditorCategory_opensSplit_onlyOnTheHolderWithTheRecipeAndTheBridgeOn() {
        #expect(GroupSplitLinesEntryLogic.editorCategoryOpensSplit(holdsRecipe: true, isTheHolder: true, offersSplit: true))
        #expect(!GroupSplitLinesEntryLogic.editorCategoryOpensSplit(holdsRecipe: false, isTheHolder: true, offersSplit: true))
        #expect(!GroupSplitLinesEntryLogic.editorCategoryOpensSplit(holdsRecipe: true, isTheHolder: false, offersSplit: true))
        #expect(!GroupSplitLinesEntryLogic.editorCategoryOpensSplit(holdsRecipe: true, isTheHolder: true, offersSplit: false))
    }

    private func shape(holdsRecipe: Bool) -> RecordContextActionLogic.Shape {
        RecordContextActionLogic.Shape(
            hasBalanceAdjustmentType: false, hasSplitExpenseID: true, hasSplitSettlementID: false,
            accountIsNil: false, accountIsSystem: false, subcategoryIsSystem: false, holdsSplitRecipe: holdsRecipe)
    }

    @Test func theMenu_doesNotOfferChangingTheCategory_ofTheHolder() {
        #expect(RecordContextActionLogic.actions(shape(holdsRecipe: false)).canChangeCategory, "Control: la real sí.")
        #expect(!RecordContextActionLogic.actions(shape(holdsRecipe: true)).canChangeCategory)
    }

    @Test func theBatch_blocksTheCategory_ofTheHolder_andNothingElse() {
        #expect(RecordBulkActionLogic.allows(.subcategory, shape(holdsRecipe: false)), "Control: la real sí.")
        #expect(!RecordBulkActionLogic.allows(.subcategory, shape(holdsRecipe: true)))
        #expect(RecordBulkActionLogic.allows(.account, shape(holdsRecipe: true)), "La cuenta no la pisa el puente.")
        #expect(RecordBulkActionLogic.allows(.tags, shape(holdsRecipe: true)), "Las etiquetas tampoco.")
    }
}

// MARK: - oibr · la entrada de una recarga

@Suite("Grupos B · oibr: la entrada de una recarga sabe de qué grupo es")
struct GroupSplitLineEntryGroupLogicTests {

    private let pair = UUID().uuidString

    @Test func theEntry_takesTheZoneOfItsExit() {
        let map = GroupSplitLineEntryGroupLogic.zoneByTransferPair([
            .init(transferPairID: pair, groupZoneID: "zona-pia"),
        ])
        #expect(GroupSplitLineEntryGroupLogic.entryZone(hasGroupPointer: false, transferPairID: pair,
                                                        zoneByTransferPair: map) == "zona-pia")
        #expect(GroupSplitLineEntryGroupLogic.entryZone(hasGroupPointer: false, transferPairID: UUID().uuidString,
                                                        zoneByTransferPair: map) == nil, "Una transferencia normal no.")
        #expect(GroupSplitLineEntryGroupLogic.entryZone(hasGroupPointer: true, transferPairID: pair,
                                                        zoneByTransferPair: map) == nil,
                "La salida ya dice su grupo por su puntero.")
    }

    @Test func aRepeatedPair_keepsTheFirstNonEmptyZone() {
        let map = GroupSplitLineEntryGroupLogic.zoneByTransferPair([
            .init(transferPairID: pair, groupZoneID: nil),
            .init(transferPairID: pair, groupZoneID: "a"),
            .init(transferPairID: pair, groupZoneID: "b"),
        ])
        #expect(map == [pair: "a"])
    }

    @Test func withGroupsHidden_theEntryGoesWithItsExit() {
        let bridged: Set<String> = [pair]
        #expect(GroupSplitLineEntryGroupLogic.hiddenWithItsExit(
            hasGroupPointer: false, transferPairID: pair, bridgedTransferPairs: bridged, includeGroups: false))
        #expect(!GroupSplitLineEntryGroupLogic.hiddenWithItsExit(
            hasGroupPointer: false, transferPairID: pair, bridgedTransferPairs: bridged, includeGroups: true))
        #expect(!GroupSplitLineEntryGroupLogic.hiddenWithItsExit(
            hasGroupPointer: false, transferPairID: UUID().uuidString, bridgedTransferPairs: bridged,
            includeGroups: false), "Una transferencia normal se queda.")
    }
}
