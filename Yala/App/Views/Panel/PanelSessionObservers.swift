//
//  PanelSessionObservers.swift
//  Yala
//
//  SessionState onChange observers extracted from PanelView.
//

import SwiftData
import SwiftUI

struct PanelSessionObservers: ViewModifier {
    let viewModel: PanelViewModel
    let sessionState: SessionState

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedPeriod) {
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.selectedAccountIDs) {
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.selectedCategoryIDs) {
                if !sessionState.isExcludeMode && !sessionState.selectedCategoryIDs.isEmpty {
                    let selectedCats = viewModel.categories.filter {
                        sessionState.selectedCategoryIDs.contains($0.persistentModelID)
                    }
                    if !selectedCats.isEmpty {
                        if selectedCats.allSatisfy({ !$0.isIncome }) {
                            sessionState.selectedTransactionNatures = [.expense]
                        } else if selectedCats.allSatisfy({ $0.isIncome }) {
                            sessionState.selectedTransactionNatures = [.income]
                        }
                    }
                }
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.selectedNeeds) {
                if !sessionState.isExcludeMode && !sessionState.selectedNeeds.isEmpty {
                    sessionState.selectedTransactionNatures = [.expense]
                }
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.selectedSubcategoryIDs) {
                if !sessionState.isExcludeMode && !sessionState.selectedSubcategoryIDs.isEmpty {
                    let selectedSubs = viewModel.allSubcategories.filter {
                        sessionState.selectedSubcategoryIDs.contains($0.persistentModelID)
                    }
                    if !selectedSubs.isEmpty {
                        if selectedSubs.allSatisfy({ !$0.safeCategory.isIncome }) {
                            sessionState.selectedTransactionNatures = [.expense]
                        } else if selectedSubs.allSatisfy({ $0.safeCategory.isIncome }) {
                            sessionState.selectedTransactionNatures = [.income]
                        }
                    }
                }
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.selectedTags) {
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.selectedCurrencies) {
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.selectedTransactionNatures) {
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.amountCondition) {
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.searchText) {
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.isExcludeMode) {
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.selectedTrendMetric) {
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.customDateRange) {
                viewModel.recalculateData()
            }
    }
}
