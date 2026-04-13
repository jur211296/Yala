//
//  PanelDataObservers.swift
//  Yala
//
//  Data-related onChange observers extracted from PanelView.
//

import SwiftUI

struct PanelDataObservers: ViewModifier {
    let viewModel: PanelViewModel
    let sessionState: SessionState
    @Binding var showFABMenu: Bool

    func body(content: Content) -> some View {
        content
            .modifier(PanelDataCountObservers(viewModel: viewModel, sessionState: sessionState, showFABMenu: $showFABMenu))
            .modifier(PanelDataFilterObservers(viewModel: viewModel, sessionState: sessionState))
    }
}

struct PanelDataCountObservers: ViewModifier {
    let viewModel: PanelViewModel
    let sessionState: SessionState
    @Binding var showFABMenu: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedMainTab) { _, _ in
                if showFABMenu { showFABMenu = false }
            }
            .onChange(of: viewModel.accounts.count) { _, _ in
                viewModel.recalculateData()
            }
            .onChange(of: viewModel.transactions.count) { _, _ in
                viewModel.recalculateData()
            }
            .onChange(of: viewModel.budgets.count) { _, _ in
                viewModel.recalculateData()
            }
            .onChange(of: viewModel.allSubcategories.count) { _, _ in
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.needsBudgetsWidgetRefresh) { _, needsRefresh in
                if needsRefresh {
                    viewModel.recalculateData()
                    sessionState.needsBudgetsWidgetRefresh = false
                }
            }
            .onChange(of: sessionState.formattingVersion) { _, _ in
                viewModel.recalculateData()
            }
    }
}

struct PanelDataFilterObservers: ViewModifier {
    let viewModel: PanelViewModel
    let sessionState: SessionState

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.dataVersion) { _, _ in
                viewModel.reloadAndRecalculate()
            }
            .onChange(of: viewModel.trendType) { _, _ in
                viewModel.syncToSessionState(sessionState)
                viewModel.recalculateData()
            }
            .onChange(of: viewModel.selectedCategoryID) {
                viewModel.recalculateData()
            }
            .onChange(of: viewModel.focusedDate) {
                viewModel.recalculateData()
            }
            .onChange(of: viewModel.selectedNeed) {
                viewModel.recalculateData()
            }
            .onChange(of: viewModel.subcategoriesWidgetFilter) {
                viewModel.recalculateData()
            }
    }
}
