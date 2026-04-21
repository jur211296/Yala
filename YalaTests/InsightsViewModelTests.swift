//
//  InsightsViewModelTests.swift
//  YalaTests
//
//  Unit tests for InsightsViewModel state management.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// Serialized because the equality-guard tests mutate `SessionState.shared.dataVersion`
// (a singleton); parallel execution produces flaky results when tests interleave reads.
@Suite(.serialized)
struct InsightsViewModelTests {

    // MARK: - Initial State

    @MainActor @Test func initialState_insightDataNil() {
        let vm = InsightsViewModel()
        #expect(vm.insightData == nil)
    }

    @MainActor @Test func initialState_aiInsightsNil() {
        let vm = InsightsViewModel()
        #expect(vm.aiInsights == nil)
    }

    @MainActor @Test func initialState_isLoadingAIFalse() {
        let vm = InsightsViewModel()
        #expect(vm.isLoadingAI == false)
    }

    @MainActor @Test func initialState_aiErrorNil() {
        let vm = InsightsViewModel()
        #expect(vm.aiError == nil)
    }

    @MainActor @Test func currentTone_isCurrent() {
        let vm = InsightsViewModel()
        #expect(vm.currentTone == .current)
    }

    @MainActor @Test func currentFocus_isCurrent() {
        let vm = InsightsViewModel()
        #expect(vm.currentFocus == .current)
    }

    // MARK: - AI Activated State

    @MainActor @Test func initialState_aiActivatedFalse() {
        let vm = InsightsViewModel()
        #expect(vm.aiActivated == false)
    }

    @MainActor @Test func resetAIState_clearsAllAIState() {
        let vm = InsightsViewModel()
        // Simulate some AI state being set (via internal mutation during triggerAIGeneration)
        // After reset, all AI state should be cleared
        vm.resetAIState()
        #expect(vm.aiInsights == nil)
        #expect(vm.aiActivated == false)
        #expect(vm.isLoadingAI == false)
        #expect(vm.aiError == nil)
    }

    // MARK: - Equality Guard

    // Empty input arrays avoid instantiating a ModelContainer: Swift Testing doesn't
    // set XCTestConfigurationFilePath, so `SwiftDataConfiguration.isRunningTests` is
    // false and `context.insert` attempts to open the real CloudKit container.

    @MainActor @Test func equalityGuard_sameInputs_skipsRecalculation() {
        let vm = InsightsViewModel()

        vm.calculateInsightsData(
            transactions: [], accounts: [], categories: [],
            budgets: [], scheduledPayments: [],
            period: .thisMonth, criteria: .empty, currencyCode: "PEN",
            customRange: nil, comparisonMode: .month
        )
        let firstSig = vm.lastInputsSignature
        #expect(firstSig != 0)

        // Same inputs → signature unchanged → cache-hit (no recalculation).
        vm.calculateInsightsData(
            transactions: [], accounts: [], categories: [],
            budgets: [], scheduledPayments: [],
            period: .thisMonth, criteria: .empty, currencyCode: "PEN",
            customRange: nil, comparisonMode: .month
        )
        #expect(vm.lastInputsSignature == firstSig)
    }

    @MainActor @Test func equalityGuard_dataVersionBump_recalculates() {
        let vm = InsightsViewModel()
        let initialDataVersion = SessionState.shared.dataVersion
        defer { SessionState.shared.dataVersion = initialDataVersion }

        vm.calculateInsightsData(
            transactions: [], accounts: [], categories: [],
            budgets: [], scheduledPayments: [],
            period: .thisMonth, criteria: .empty, currencyCode: "PEN",
            customRange: nil, comparisonMode: .month
        )
        let firstSig = vm.lastInputsSignature

        // dataVersion bump simulates CRUD/CloudKit change → must invalidate cache.
        SessionState.shared.dataVersion += 1
        vm.calculateInsightsData(
            transactions: [], accounts: [], categories: [],
            budgets: [], scheduledPayments: [],
            period: .thisMonth, criteria: .empty, currencyCode: "PEN",
            customRange: nil, comparisonMode: .month
        )
        #expect(vm.lastInputsSignature != firstSig)
    }

    @MainActor @Test func invalidateCache_forcesRecalcOnNextCall() {
        let vm = InsightsViewModel()

        vm.calculateInsightsData(
            transactions: [], accounts: [], categories: [],
            budgets: [], scheduledPayments: [],
            period: .thisMonth, criteria: .empty, currencyCode: "PEN",
            customRange: nil, comparisonMode: .month
        )
        #expect(vm.lastInputsSignature != 0)

        vm.invalidateCache()
        #expect(vm.lastInputsSignature == 0)

        vm.calculateInsightsData(
            transactions: [], accounts: [], categories: [],
            budgets: [], scheduledPayments: [],
            period: .thisMonth, criteria: .empty, currencyCode: "PEN",
            customRange: nil, comparisonMode: .month
        )
        #expect(vm.lastInputsSignature != 0)
    }
}
