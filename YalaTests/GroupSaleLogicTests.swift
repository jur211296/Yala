//
//  GroupSaleLogicTests.swift
//  YalaTests
//
//  Grupos B · cards 7 y 8: un gasto de grupo que pagaste tú con una categoría de ingreso es una venta. Reglas puras
//  (`GroupSaleBridgeLogic`, la frase del formulario, el tipo con que abre el selector y la fila de Registros) y lo que el
//  formulario deja de pedir con una venta.
//

import Foundation
import Testing

@testable import Yala

@Suite("Grupos B · ventas por cobrar: reglas")
@MainActor
struct GroupSaleLogicTests {

    // MARK: - Qué es una venta

    @Test(arguments: [
        (true, true as Bool?, false, true),
        (false, true as Bool?, false, false),   // pagó otro: no es tu venta
        (true, false as Bool?, false, false),   // categoría de gasto
        (true, nil as Bool?, false, false),     // sin categoría
        (true, true as Bool?, true, false)      // de sistema: nunca decide
    ])
    func isSale(_ caseA: Bool, _ income: Bool?, _ system: Bool, _ expected: Bool) {
        #expect(GroupSaleBridgeLogic.isSale(isCaseA: caseA, subcategoryIsIncome: income, subcategoryIsSystem: system)
                == expected)
    }

    @Test func anIncomeCategoryOutsideASale_doesNotClassifyYourShare() {
        #expect(GroupSaleBridgeLogic.classifiesShare(isSale: false, subcategoryIsIncome: true) == false)
        #expect(GroupSaleBridgeLogic.classifiesShare(isSale: true, subcategoryIsIncome: true))
        #expect(GroupSaleBridgeLogic.classifiesShare(isSale: false, subcategoryIsIncome: false))
        #expect(GroupSaleBridgeLogic.classifiesShare(isSale: false, subcategoryIsIncome: nil))
    }

    @Test func receivable_isTheExpenseMinusYourShare_andNothingBelowHalfACent() {
        #expect(GroupSaleBridgeLogic.receivableAmount(total: 120, myShare: 0) == 120)
        #expect(GroupSaleBridgeLogic.receivableAmount(total: 120, myShare: 40) == 80)
        #expect(GroupSaleBridgeLogic.receivableAmount(total: 120, myShare: 120) == nil)
        #expect(GroupSaleBridgeLogic.receivableAmount(total: 120, myShare: 119.996) == nil)
        #expect(GroupSaleBridgeLogic.receivableAmount(total: 120, myShare: -5) == 120)
    }

    @Test func theReceivableType_isTheOneTheModelNames() {
        #expect(TransactionItem.adjustmentTypeReceivable == "receivable")
        #expect(TransactionItem.adjustmentTypeReceivable != TransactionItem.adjustmentTypeTransfer)
    }

    // MARK: - La pata que el puente conserva

    private let receivable = "receivable"
    private let transfer = "transfer"

    @Test func aPlainKeptLeg_isNeverReverted() {
        for sale in [true, false] {
            for caseA in [true, false] {
                #expect(!GroupSaleBridgeLogic.revertsKeptLeg(
                    currentType: nil, isSale: sale, isCaseA: caseA, anchorIsTransfer: false))
            }
        }
    }

    @Test func aReceivableLeg_staysInASale_andIsRevertedOtherwise() {
        #expect(!GroupSaleBridgeLogic.revertsKeptLeg(
            currentType: receivable, isSale: true, isCaseA: true, anchorIsTransfer: false))
        // Cambió el pagador (Caso B) o la categoría: vuelve a ser tu parte, también con una receta de recarga.
        #expect(GroupSaleBridgeLogic.revertsKeptLeg(
            currentType: receivable, isSale: false, isCaseA: false, anchorIsTransfer: true))
        #expect(GroupSaleBridgeLogic.revertsKeptLeg(
            currentType: receivable, isSale: false, isCaseA: true, anchorIsTransfer: false))
    }

    @Test func aRechargeLeg_keepsTheRuleItHad_andIsRevertedForASale() {
        #expect(GroupSaleBridgeLogic.revertsKeptLeg(
            currentType: transfer, isSale: true, isCaseA: true, anchorIsTransfer: false))
        #expect(!GroupSaleBridgeLogic.revertsKeptLeg(
            currentType: transfer, isSale: false, isCaseA: false, anchorIsTransfer: true))
        #expect(GroupSaleBridgeLogic.revertsKeptLeg(
            currentType: transfer, isSale: false, isCaseA: false, anchorIsTransfer: false))
        #expect(GroupSaleBridgeLogic.revertsKeptLeg(
            currentType: transfer, isSale: false, isCaseA: true, anchorIsTransfer: true))
    }

    // MARK: - La frase del formulario

    private let me = "me"
    private let ana = "ana"
    private let beto = "beto"

    private func saleLine(
        isSale: Bool = true, groupsOnly: Bool = false, amount: Double = 120, balanced: Bool = true,
        shares: [(memberID: String, amount: Double)]?
    ) -> GroupExpenseOutflowLineLogic.SaleLine? {
        GroupExpenseOutflowLineLogic.saleLine(
            isSale: isSale, isGroupsOnlySession: groupsOnly, amount: amount, hasParticipants: true,
            sharesBalanced: balanced, shares: shares, myMemberID: me)
    }

    @Test func oneDebtor_isNamed() {
        let line = saleLine(shares: [(ana, 120)])
        #expect(line == .init(owedToYou: 120, debtorMemberID: ana))
    }

    @Test func youInTheSplit_owesNothingToYourself() {
        let line = saleLine(shares: [(me, 60), (ana, 60)])
        #expect(line == .init(owedToYou: 60, debtorMemberID: ana))
    }

    @Test func severalDebtors_areNotNamed() {
        let line = saleLine(shares: [(me, 40), (ana, 40), (beto, 40)])
        #expect(line == .init(owedToYou: 80, debtorMemberID: nil))
    }

    @Test func noLine_whenItIsNotASale_inGroupsOnly_unbalanced_orNobodyOwes() {
        #expect(saleLine(isSale: false, shares: [(ana, 120)]) == nil)
        #expect(saleLine(groupsOnly: true, shares: [(ana, 120)]) == nil)
        #expect(saleLine(balanced: false, shares: [(ana, 100)]) == nil)
        #expect(saleLine(shares: nil) == nil)
        #expect(saleLine(shares: [(me, 120)]) == nil)
        #expect(saleLine(amount: 0, shares: [(ana, 0)]) == nil)
    }

    // MARK: - El selector

    @Test func theSelector_opensOnTheTypeOfWhatIsChosen_onlyWhenItOffersIncome() {
        #expect(SubcategorySelectorTypeLogic.initialType(requested: .expense, offersIncome: true, selectedIsIncome: true)
                == .income)
        #expect(SubcategorySelectorTypeLogic.initialType(requested: .expense, offersIncome: true, selectedIsIncome: false)
                == .expense)
        #expect(SubcategorySelectorTypeLogic.initialType(requested: .expense, offersIncome: true, selectedIsIncome: nil)
                == .expense)
        #expect(SubcategorySelectorTypeLogic.initialType(requested: .expense, offersIncome: false, selectedIsIncome: true)
                == .expense)
    }

    // MARK: - Editor, lote y menú

    /// La pata por cobrar la escribe entera el puente: ni el editor ni «Editar varios» cambian su categoría (el puente
    /// la pisaba en la pasada siguiente). Control: la misma pata sin el tipo es la de tu parte de siempre, clasificable.
    @Test func theReceivableLeg_isLockedLikeAnyBridgeLeg() {
        let groups = Account(name: "Grupos", currencyCode: "PEN", colorHex: "#000000", iconName: "person.3", type: "system")
        groups.isSystemAccount = true
        let leg = TransactionItem(date: .now, amount: 120, currencyCode: "PEN", note: "Venta",
                                  category: nil, subcategory: nil, account: groups)
        leg.splitExpenseID = UUID().uuidString
        leg.balanceAdjustmentType = TransactionItem.adjustmentTypeReceivable
        let locked = RecordContextActionLogic.Shape(record: leg)
        #expect(!RecordBulkActionLogic.allows(.subcategory, locked))
        #expect(!RecordBulkActionLogic.allows(.tags, locked))
        #expect(!RecordContextActionLogic.actions(locked).canChangeCategory)

        leg.balanceAdjustmentType = nil
        #expect(RecordBulkActionLogic.allows(.subcategory, RecordContextActionLogic.Shape(record: leg)))
    }

    // MARK: - Registros

    @Test func theRow_saysReceivable_onlyForAReceivableLeg() {
        #expect(RecordRowPresentationLogic.categoryCaption("Ventas", adjustmentType: "receivable")
                == "Ventas • \(L10n.Records.receivable)")
        #expect(RecordRowPresentationLogic.categoryCaption("Ventas", adjustmentType: nil) == "Ventas")
        #expect(RecordRowPresentationLogic.categoryCaption("Ajuste", adjustmentType: "adjustment") == "Ajuste")
        #expect(RecordRowPresentationLogic.categoryCaption("Transferencia", adjustmentType: "transfer") == "Transferencia")
    }
}

// MARK: - El formulario (card 7)

@Suite("Grupos B · el formulario con una categoría de ingreso")
@MainActor
struct GroupSaleFormTests {

    private func makeVM() -> (GroupExpenseViewModel, me: SplitMember, ana: SplitMember) {
        let me = SplitMember(displayName: "Yo", isCurrentUser: true)
        let ana = SplitMember(displayName: "Ana")
        let group = SplitGroup(name: "Ventas con Ana", currencyCode: "PEN")
        let vm = GroupExpenseViewModel(group: group, members: [me, ana], memberNameLookup: [:])
        vm.currencyCode = "PEN"
        vm.isGroupsOnlyOverride = false
        vm.effectiveBridgeEnabledOverride = true
        vm.amountString = "120"
        vm.expenseDescription = "Venta de zapatillas"
        vm.paidByMemberID = me.id.uuidString
        vm.selectedMemberIDs = [ana.id.uuidString]
        return (vm, me, ana)
    }

    private func subcategory(name: String, income: Bool) -> Subcategory {
        let category = YalaCategory(name: income ? "Ingresos" : "Gastos", colorHex: "#00C2CB", isIncome: income)
        return Subcategory(name: name, colorHex: nil, natureRawValue: SubcategoryNeed.essential.rawValue,
                           iconName: "tag", category: category)
    }

    @Test func withAnExpenseCategory_theAccountIsStillAsked() {
        let (vm, _, _) = makeVM()
        vm.selectedSubcategory = subcategory(name: "Supermercado", income: false)
        #expect(vm.isSale == false)
        #expect(vm.isAccountRequired)
        #expect(vm.canSave == false)
    }

    @Test func withAnIncomeCategory_noAccountIsAsked_andItCanBeSaved() {
        let (vm, _, _) = makeVM()
        vm.selectedSubcategory = subcategory(name: "Ventas", income: true)
        #expect(vm.isSale)
        #expect(vm.isAccountRequired == false)
        #expect(vm.canSave)
    }

    @Test func anIncomeCategory_paidBySomeoneElse_isNotASale() {
        let (vm, _, ana) = makeVM()
        vm.paidByMemberID = ana.id.uuidString
        vm.selectedSubcategory = subcategory(name: "Ventas", income: true)
        #expect(vm.isSale == false)
    }
}
