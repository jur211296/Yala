//
//  CashFlowRealEstimateBarLogic.swift
//  Yala
//
//  Cuánto de la barra de una línea del plan es real y cuánto estimado (decisión 31 de la revisión 2.3). La pinta
//  `CashFlowRealEstimateBar`.
//

import Foundation

enum CashFlowRealEstimateBarLogic {

    /// Qué parte de la barra es real y qué parte estimada, en fracciones del ancho (0…1, suman como mucho 1).
    struct Segments: Equatable {
        let real: Double
        let estimate: Double
    }

    /// Solo en el mes en curso y con algo planeado: un mes cerrado ya no tiene nada estimado, y uno que viene es todo
    /// estimado (lo dice su etiqueta). Una línea superada no lleva parte estimada: la pinta la barra de siempre, en rosa.
    static func segments(real: Double, planned: Double, isCurrentMonth: Bool) -> Segments? {
        guard isCurrentMonth, planned > 0, real < planned else { return nil }
        let realShare = min(max(real / planned, 0), 1)
        return Segments(real: realShare, estimate: 1 - realShare)
    }
}
