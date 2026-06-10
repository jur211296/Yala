//
//  TransactionDetailSheetLogicTests.swift
//  YalaTests
//
//  Tests pure-logic para `TransactionDetailSheetLogic` (sheet de detalle de
//  transacción en Records). Sin SwiftData ni ModelContext — verifica la matriz
//  de detents iPhone/iPad × mode, el trigger drag-to-edit y la clasificación
//  visual de la TX.
//

import Foundation
import Testing

@testable import Yala

struct TransactionDetailSheetLogicTests {

    // MARK: - initialDetent

    @Test func initialDetent_iPhone_isMedium() {
        #expect(TransactionDetailSheetLogic.initialDetent(usesLargeSheets: false) == .medium)
    }

    @Test func initialDetent_iPad_isLarge() {
        #expect(TransactionDetailSheetLogic.initialDetent(usesLargeSheets: true) == .large)
    }

    // MARK: - availableDetents

    @Test func availableDetents_detailOniPhone_allowsMediumAndLarge() {
        #expect(
            TransactionDetailSheetLogic.availableDetents(mode: .detail, usesLargeSheets: false)
                == [.medium, .large]
        )
    }

    @Test func availableDetents_detailOniPad_isLargeOnly() {
        #expect(
            TransactionDetailSheetLogic.availableDetents(mode: .detail, usesLargeSheets: true)
                == [.large]
        )
    }

    @Test func availableDetents_editOniPhone_isLargeOnly() {
        #expect(
            TransactionDetailSheetLogic.availableDetents(mode: .edit, usesLargeSheets: false)
                == [.large]
        )
    }

    @Test func availableDetents_editOniPad_isLargeOnly() {
        #expect(
            TransactionDetailSheetLogic.availableDetents(mode: .edit, usesLargeSheets: true)
                == [.large]
        )
    }

    // MARK: - shouldSwitchToEdit

    @Test func shouldSwitchToEdit_largeFromDetailOniPhone_switches() {
        #expect(
            TransactionDetailSheetLogic.shouldSwitchToEdit(
                newDetent: .large, mode: .detail, usesLargeSheets: false))
    }

    @Test func shouldSwitchToEdit_largeFromDetailOniPad_doesNotSwitch() {
        #expect(
            !TransactionDetailSheetLogic.shouldSwitchToEdit(
                newDetent: .large, mode: .detail, usesLargeSheets: true))
    }

    @Test func shouldSwitchToEdit_mediumFromDetail_doesNotSwitch() {
        #expect(
            !TransactionDetailSheetLogic.shouldSwitchToEdit(
                newDetent: .medium, mode: .detail, usesLargeSheets: false))
    }

    @Test func shouldSwitchToEdit_largeWhileEditing_doesNotRefire() {
        #expect(
            !TransactionDetailSheetLogic.shouldSwitchToEdit(
                newDetent: .large, mode: .edit, usesLargeSheets: false))
    }

    // MARK: - kind

    @Test func kind_transfer_winsOverCategoryAndAmount() {
        #expect(
            TransactionDetailSheetLogic.kind(isTransfer: true, categoryIsIncome: true, amount: 50)
                == .transfer
        )
    }

    @Test func kind_incomeCategory_winsOverNegativeAmount() {
        #expect(
            TransactionDetailSheetLogic.kind(isTransfer: false, categoryIsIncome: true, amount: -5)
                == .income
        )
    }

    @Test func kind_expenseCategory_winsOverPositiveAmount() {
        #expect(
            TransactionDetailSheetLogic.kind(isTransfer: false, categoryIsIncome: false, amount: 10)
                == .expense
        )
    }

    @Test func kind_noCategory_negativeAmount_isExpense() {
        #expect(
            TransactionDetailSheetLogic.kind(isTransfer: false, categoryIsIncome: nil, amount: -10)
                == .expense
        )
    }

    @Test func kind_noCategory_zeroAmount_isIncome() {
        #expect(
            TransactionDetailSheetLogic.kind(isTransfer: false, categoryIsIncome: nil, amount: 0)
                == .income
        )
    }

    // MARK: - transferOwnAccountIsOrigin

    @Test func transferOrigin_negativeAmount_isOrigin() {
        #expect(TransactionDetailSheetLogic.transferOwnAccountIsOrigin(amount: -10))
    }

    @Test func transferOrigin_positiveAmount_isDestination() {
        #expect(!TransactionDetailSheetLogic.transferOwnAccountIsOrigin(amount: 10))
    }

    @Test func transferOrigin_zeroAmount_isDestination() {
        #expect(!TransactionDetailSheetLogic.transferOwnAccountIsOrigin(amount: 0))
    }
}
