//
//  VariationDisplayConfig.swift
//  Yala
//
//  Configuración compartida para los widgets que pintan comparación entre
//  el periodo actual y el anterior. El Panel usa `.panelCompact` para
//  reducir ruido textual; Stats usa `.full` por default.
//

import Foundation

struct VariationDisplayConfig: Equatable {
    /// Chip pequeño de variación dentro del layout `.small` del widget.
    var showsSmallVariation: Bool
    /// Etiqueta `vs $X` junto al KPI principal.
    var showsPreviousAmountLabel: Bool
    /// Texto del periodo comparado (ej: "vs mes pasado").
    var showsComparisonPeriodLabel: Bool

    static let full = Self(
        showsSmallVariation: true,
        showsPreviousAmountLabel: true,
        showsComparisonPeriodLabel: true
    )

    static let panelCompact = Self(
        showsSmallVariation: false,
        showsPreviousAmountLabel: false,
        showsComparisonPeriodLabel: false
    )
}
