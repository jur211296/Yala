//
//  UsageTabTracking.swift
//  Yala
//
//  Telemetría propia: «usó esta función» para las páginas de la barra (Panel, Estadísticas, Presupuestos, Pagos
//  programados, Grupos). Lee la página que SE VE (`RootTabLayoutLogic.displayedTab`, no la selección: en la shell de
//  solo grupos la selección se queda en Panel) y el chip de Planificación. El «uno al día» lo pone `MetricsService`.
//  Tres observadores y cierres de una línea: es el tope que el compilador del CI tipa a tiempo (regla de swiftui-ds).
//

import SwiftUI

private struct UsageTabTrackingModifier: ViewModifier {
    let displayed: AppTab
    let planning: PlanningTab

    func body(content: Content) -> some View {
        content
            .onAppear { record() }
            .onChange(of: displayed) { _, _ in record() }
            .onChange(of: planning) { _, _ in record() }
    }

    private func record() {
        guard let feature = MetricsUseTabLogic.feature(displayed: displayed, planning: planning) else { return }
        MetricsService.used(feature)
    }
}

extension View {
    func tracksUsedTab(_ displayed: AppTab, planning: PlanningTab) -> some View {
        modifier(UsageTabTrackingModifier(displayed: displayed, planning: planning))
    }
}
