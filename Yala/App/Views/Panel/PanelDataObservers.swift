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
        // Sin observadores de `accounts/transactions/budgets/allSubcategories.count` (retirados el 2026-10-30, encargo
        // `eficiencia-carga-por-vista`): esos arrays solo los escribe `PanelViewModel.loadData()`, y su único llamador
        // es `scheduleRecalculation`, que calcula justo después en el mismo turno. Cada cambio de conteo pedía otro
        // cálculo completo 150 ms más tarde sobre los mismos datos: en cada arranque en frío, uno de más tras el primer
        // contenido. Si alguien escribe esos arrays por otro camino, que recalcule él.
        content
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

/// La app pasa a activa → el Panel repite lo que el freno de recálculo descartó antes (`applicationDidBecomeActive`).
/// En el arranque en frío del iPad la carga se pedía con la app aún sin activar y el Panel se quedaba en el esqueleto
/// (barrido final 2.2, 2026-11-05). Va aparte: `PanelDataObservers` ya lleva tres modificadores.
struct PanelActivationObserver: ViewModifier {
    let viewModel: PanelViewModel

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                viewModel.applicationDidBecomeActive()
            }
    }
}
