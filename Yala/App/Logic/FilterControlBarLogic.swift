//
//  FilterControlBarLogic.swift
//  Yala
//
//  Pure-logic helpers para FilterControlBar. Decide gating del PanelSection
//  (panel style) y visibilidad del periodSelector inline (legacy).
//
//  TODO(stats-polish-epic): este helper queda obsoleto cuando las 4 tabs
//  Stats migren al panel style. Ver Backlog/stats-polish-panel-alignment.md
//  sección "Cleanup post-épico".
//

import Foundation

enum FilterControlBarLogic {
    /// En panel style la barra se renderiza solo cuando hay chips activos
    /// (alineado con `PanelFilterControlBar`). En legacy la barra siempre
    /// se monta para exponer el periodSelector inline aunque no haya chips.
    static func shouldRenderPanelSection(panelStyle: Bool, activeFilterCount: Int) -> Bool {
        panelStyle && activeFilterCount > 0
    }

    /// El periodSelector inline aplica solo en legacy. En panel style vive
    /// en el hero, no en el control bar.
    static func shouldShowInlinePeriodSelector(panelStyle: Bool) -> Bool {
        !panelStyle
    }
}
