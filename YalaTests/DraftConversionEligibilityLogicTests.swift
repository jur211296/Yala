//
//  DraftConversionEligibilityLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para `DraftConversionEligibilityLogic` — decide si un draft personal
//  ofrece el botón "Convertir a gasto compartido". Sin SwiftData/ModelContext.
//

import Foundation
import Testing

@testable import Yala

@Suite("Draft Conversion Eligibility")
struct DraftConversionEligibilityLogicTests {

    /// Los 14 cases del enum (sin CaseIterable): sirve para el barrido exhaustivo.
    private static let allSources: [DraftSourceType] = [
        .voice, .receiptPhoto, .screenshotList, .screenshotSingle, .emailAlert,
        .scheduledPayment, .subscription, .applePay, .automation, .siri,
        .groupExpense, .groupSettlement, .manual, .groupScheduledExpense
    ]

    @Test func enumHasFourteenCases() {
        #expect(Self.allSources.count == 14)
    }

    @Test func allowlistSources_offerButton_whenConditionsMet() {
        for source in DraftConversionEligibilityLogic.convertibleSources {
            #expect(
                DraftConversionEligibilityLogic.canOffer(
                    sourceType: source, isExpense: true, hasAmount: true,
                    hasEligibleGroups: true, status: .pending
                ),
                "\(source) debería ofrecer el botón con todas las condiciones OK"
            )
        }
    }

    @Test func income_doesNotOffer() {
        #expect(!DraftConversionEligibilityLogic.canOffer(
            sourceType: .applePay, isExpense: false, hasAmount: true,
            hasEligibleGroups: true, status: .pending
        ))
    }

    @Test func noAmount_doesNotOffer() {
        #expect(!DraftConversionEligibilityLogic.canOffer(
            sourceType: .manual, isExpense: true, hasAmount: false,
            hasEligibleGroups: true, status: .pending
        ))
    }

    @Test func noEligibleGroups_doesNotOffer() {
        #expect(!DraftConversionEligibilityLogic.canOffer(
            sourceType: .voice, isExpense: true, hasAmount: true,
            hasEligibleGroups: false, status: .pending
        ))
    }

    @Test(arguments: [DraftStatus.approved, DraftStatus.rejected])
    func nonPendingStatus_doesNotOffer(_ status: DraftStatus) {
        #expect(!DraftConversionEligibilityLogic.canOffer(
            sourceType: .applePay, isExpense: true, hasAmount: true,
            hasEligibleGroups: true, status: status
        ))
    }

    /// Sources de grupo (ya tienen ciclo) y recurrentes (tienen flujo dedicado) NO se ofrecen
    /// aunque el resto de condiciones estén OK.
    @Test(arguments: [
        DraftSourceType.groupExpense, .groupSettlement, .groupScheduledExpense,
        .scheduledPayment, .subscription
    ])
    func nonConvertibleSources_doNotOffer(_ source: DraftSourceType) {
        #expect(!DraftConversionEligibilityLogic.canOffer(
            sourceType: source, isExpense: true, hasAmount: true,
            hasEligibleGroups: true, status: .pending
        ))
    }

    /// Barrido de los 14: solo el allowlist ofrece (con el resto de gates satisfechos).
    @Test func fullSweep_onlyAllowlistOffers() {
        for source in Self.allSources {
            let expected = DraftConversionEligibilityLogic.convertibleSources.contains(source)
            #expect(
                DraftConversionEligibilityLogic.canOffer(
                    sourceType: source, isExpense: true, hasAmount: true,
                    hasEligibleGroups: true, status: .pending
                ) == expected,
                "\(source): esperado \(expected)"
            )
        }
    }
}
