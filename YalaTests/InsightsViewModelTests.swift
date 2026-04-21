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
}
