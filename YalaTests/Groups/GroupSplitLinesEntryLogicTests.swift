//
//  GroupSplitLinesEntryLogicTests.swift
//  YalaTests
//
//  Grupos B, cards 5 y 6: cuándo una pantalla ofrece partir tu parte y con qué líneas abre la tarjeta.
//

import Foundation
import Testing

@testable import Yala

@Suite("Grupos B · cuándo se ofrece «Partir»")
@MainActor
struct GroupSplitLinesEntryLogicTests {

    private let open = GroupSplitLinesEntryLogic.Input(
        bridgeEnabled: true, hasPrivateSession: true, isGroupsFocusedShell: false, share: 510, isOpeningBalance: false)

    @Test func withTheBridgeOn_andYourAccounts_itIsOffered() {
        #expect(GroupSplitLinesEntryLogic.offersSplit(open))
    }

    @Test func eachConditionClosesIt_onItsOwn() {
        var bridgeOff = open
        bridgeOff.bridgeEnabled = false
        var groupsOnly = open
        groupsOnly.hasPrivateSession = false
        var focusedShell = open
        focusedShell.isGroupsFocusedShell = true
        var noShare = open
        noShare.share = 0
        var openingBalance = open
        openingBalance.isOpeningBalance = true
        var sale = open
        sale.isSale = true
        for closed in [bridgeOff, groupsOnly, focusedShell, noShare, openingBalance, sale] {
            #expect(!GroupSplitLinesEntryLogic.offersSplit(closed))
        }
    }

    @Test func withoutARecipe_itOpensWithOneExpenseLineForYourWholeShare() {
        let category = UUID()
        let lines = GroupSplitLinesEntryLogic.initialLines(
            stored: .none, share: Decimal(string: "170.333")!, subcategoryID: category, currencyCode: "PEN")
        #expect(lines.count == 1)
        #expect(lines[0].kind == .expense)
        #expect(lines[0].amount == Decimal(string: "170.33")!)
        #expect(lines[0].subcategoryID == category)
    }

    @Test func withAStoredRecipe_itOpensWithThoseLines() {
        let stored: [GroupSplitLinesRecipe.Line] = [
            .transfer(amount: 500, destinationAccountID: UUID()),
            .expense(amount: 10, subcategoryID: UUID()),
        ]
        let lines = GroupSplitLinesEntryLogic.initialLines(
            stored: .recipe(stored), share: 520, subcategoryID: UUID(), currencyCode: "PEN")
        #expect(lines == stored)
    }

    @Test func aRecipeFromALaterVersion_opensWithOneLine_insteadOfGuessing() {
        let lines = GroupSplitLinesEntryLogic.initialLines(
            stored: .newerVersion, share: 510, subcategoryID: nil, currencyCode: "PEN")
        #expect(lines.count == 1)
        #expect(lines[0].amount == 510)
    }

    @Test func oneExpenseLine_isTodaysShape_withItsCategory() {
        let category = UUID()
        let single: [GroupSplitLinesRecipe.Line] = [.expense(amount: 510, subcategoryID: category)]
        #expect(GroupSplitLinesEntryLogic.singleExpenseSubcategoryID(single) == category)
        let recharge: [GroupSplitLinesRecipe.Line] = [.transfer(amount: 510, destinationAccountID: UUID())]
        #expect(GroupSplitLinesEntryLogic.singleExpenseSubcategoryID(recharge) == nil)
    }

    @Test func theAnchorCategory_isTheFirstExpenseLine() {
        let fees = UUID()
        let lines: [GroupSplitLinesRecipe.Line] = [
            .transfer(amount: 500, destinationAccountID: UUID()),
            .expense(amount: 10, subcategoryID: fees),
            .expense(amount: 5, subcategoryID: UUID()),
        ]
        #expect(GroupSplitLinesEntryLogic.anchorSubcategoryID(lines) == fees)
        #expect(GroupSplitLinesEntryLogic.anchorSubcategoryID([.transfer(amount: 1, destinationAccountID: UUID())]) == nil)
    }
}

@Suite("Grupos B · una recarga no vuelve a su cuenta de origen")
@MainActor
struct GroupDraftSplitSourceTests {

    @Test func aRechargeToTheAccountItLeavesFrom_isRejected() {
        let bcp = UUID()
        let lines: [GroupSplitLinesRecipe.Line] = [
            .transfer(amount: 50, destinationAccountID: bcp),
            .expense(amount: 50, subcategoryID: UUID()),
        ]
        #expect(GroupDraftSplitState.rechargesToItsOwnSource(lines, sourceID: bcp))
        #expect(!GroupDraftSplitState.rechargesToItsOwnSource(lines, sourceID: UUID()))
        #expect(!GroupDraftSplitState.rechargesToItsOwnSource(lines, sourceID: nil))
    }
}
