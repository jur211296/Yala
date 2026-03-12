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
}
