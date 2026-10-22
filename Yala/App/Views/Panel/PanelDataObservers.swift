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

    func body(content: Content) -> some View {
        content
            .modifier(PanelDataCountObservers(viewModel: viewModel, sessionState: sessionState))
            .modifier(PanelDataFilterObservers(viewModel: viewModel, sessionState: sessionState))
            .modifier(PanelExchangeRateObserver(viewModel: viewModel))
    }
}

/// Tasas nuevas en disco → el Panel recalcula. Sin esto el saldo seguía convertido a la tasa vieja y el
/// «≈» encendido hasta el siguiente toque (ticket `panel-no-recalcula-al-llegar-tasas-nuevas`). Va en su
/// propio modificador: los otros dos ya llevan seis cada uno y el compilador del CI tipa peor.
struct PanelExchangeRateObserver: ViewModifier {
    let viewModel: PanelViewModel

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .yalaExchangeRatesUpdated)) { _ in
                viewModel.exchangeRatesDidUpdate()
            }
    }
}

struct PanelDataCountObservers: ViewModifier {
    let viewModel: PanelViewModel
    let sessionState: SessionState

    func body(content: Content) -> some View {
        content
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
