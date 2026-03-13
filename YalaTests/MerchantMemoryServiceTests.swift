//
//  MerchantMemoryServiceTests.swift
//  YalaTests
//
//  Tests for MerchantMemory computed properties and decideSuggestion pure logic.
//

import Foundation
import Testing

@testable import Yala

struct MerchantMemoryServiceTests {

    // MARK: - MerchantMemory.correctionRate

    @Test func correctionRate_zeroCorrected_returnsZero() {
        let memory = MerchantMemory(
            merchantCanonical: "starbucks",
            subcategory: nil,
            countApproved: 5,
            countCorrected: 0,
            lastApprovedAt: Date(),
            aliases: []
        )
        #expect(memory.correctionRate == 0.0)
    }

    @Test func correctionRate_allCorrected_returnsOne() {
        let memory = MerchantMemory(
            merchantCanonical: "starbucks",
            subcategory: nil,
            countApproved: 0,
            countCorrected: 5,
            lastApprovedAt: Date(),
            aliases: []
        )
        #expect(memory.correctionRate == 1.0)
    }

    @Test func correctionRate_mixed_returnsRatio() {
        let memory = MerchantMemory(
            merchantCanonical: "starbucks",
            subcategory: nil,
            countApproved: 8,
            countCorrected: 2,
            lastApprovedAt: Date(),
            aliases: []
        )
        #expect(memory.correctionRate == 0.2)
    }

    @Test func correctionRate_bothZero_returnsZero() {
        let memory = MerchantMemory(
            merchantCanonical: "starbucks",
            subcategory: nil,
            countApproved: 0,
            countCorrected: 0,
            lastApprovedAt: Date(),
            aliases: []
        )
        #expect(memory.correctionRate == 0.0)
    }

    @Test func correctionRate_half_returnsHalf() {
        let memory = MerchantMemory(
            merchantCanonical: "starbucks",
            subcategory: nil,
            countApproved: 1,
            countCorrected: 1,
            lastApprovedAt: Date(),
            aliases: []
        )
        #expect(memory.correctionRate == 0.5)
    }

    // MARK: - MerchantMemory.confidence

    @Test func confidence_fiveApprovals_noCorrection_one() {
        let memory = MerchantMemory(
            merchantCanonical: "starbucks",
            subcategory: nil,
            countApproved: 5,
            countCorrected: 0,
            lastApprovedAt: Date(),
            aliases: []
        )
        #expect(memory.confidence == 1.0)
    }

    @Test func confidence_tenApprovals_capsAtOne() {
        let memory = MerchantMemory(
            merchantCanonical: "starbucks",
            subcategory: nil,
            countApproved: 10,
            countCorrected: 0,
            lastApprovedAt: Date(),
            aliases: []
        )
        #expect(memory.confidence == 1.0)
    }

    @Test func confidence_twoApprovals_lowConfidence() {
        let memory = MerchantMemory(
            merchantCanonical: "starbucks",
            subcategory: nil,
            countApproved: 2,
            countCorrected: 0,
            lastApprovedAt: Date(),
            aliases: []
        )
        // baseConfidence = 2/5 = 0.4, correctionRate = 0, confidence = 0.4
        #expect(memory.confidence == 0.4)
    }

    @Test func confidence_withCorrections_reduced() {
        let memory = MerchantMemory(
            merchantCanonical: "starbucks",
            subcategory: nil,
            countApproved: 4,
            countCorrected: 1,
            lastApprovedAt: Date(),
            aliases: []
        )
        // baseConfidence = 4/5 = 0.8, correctionRate = 1/5 = 0.2, confidence = 0.8 * 0.8 = 0.64
        #expect(abs(memory.confidence - 0.64) < 0.0001)
    }

    // MARK: - decideSuggestion thresholds

    @MainActor @Test func decideSuggestion_highApproval_lowCorrection_auto() {
        let result = MerchantMemoryService.decideSuggestion(countApproved: 5, correctionRate: 0.05)
        #expect(result == .autoAssign)
    }

    @MainActor @Test func decideSuggestion_highApproval_highCorrection_suggest() {
        let result = MerchantMemoryService.decideSuggestion(countApproved: 5, correctionRate: 0.2)
        #expect(result == .suggest)
    }

    @MainActor @Test func decideSuggestion_medApproval_lowCorrection_suggest() {
        let result = MerchantMemoryService.decideSuggestion(countApproved: 3, correctionRate: 0.1)
        #expect(result == .suggest)
    }

    @MainActor @Test func decideSuggestion_medApproval_highCorrection_none() {
        let result = MerchantMemoryService.decideSuggestion(countApproved: 3, correctionRate: 0.5)
        #expect(result == .none)
    }

    @MainActor @Test func decideSuggestion_lowApproval_none() {
        let result = MerchantMemoryService.decideSuggestion(countApproved: 1, correctionRate: 0.0)
        #expect(result == .none)
    }
}
