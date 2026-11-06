//
//  L10n+ProjectedFlow.swift
//  Yala
//
//  Textos de «Ver proyectado» en Tendencias y el Panel (card «Flujo proyectado en Tendencias y Panel», 2026-11-06).
//  En su propio fichero, como los de cada lote, para no pisar `L10n.swift` con otras sesiones.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func lpf(_ key: String) -> String {
    let resolution = LanguageManager.resolved
    let sentinel = "__YALA_MISSING__"
    let variantValue = NSLocalizedString(key, bundle: resolution.bundle, value: sentinel, comment: "")
    if variantValue != sentinel { return variantValue }
    if let parent = resolution.parentBundle {
        let parentValue = NSLocalizedString(key, bundle: parent, value: sentinel, comment: "")
        if parentValue != sentinel { return parentValue }
    }
    let mainValue = NSLocalizedString(key, bundle: .main, value: sentinel, comment: "")
    if mainValue != sentinel { return mainValue }
    return key
}

extension L10n {
    enum ProjectedFlow {
        /// La píldora de la tarjeta de tendencia.
        static var toggle: String { lpf("trend.projected.toggle") }
        /// Rótulo de la cifra al final del período, bajo la gráfica.
        static var closing: String { lpf("trend.projected.closing") }

        /// De dónde sale la estimación de lo no planificado.
        static func source(_ source: ProjectedFlowCalculator.Source) -> String {
            switch source {
            case .plan: return lpf("trend.projected.source.plan")
            case .rhythm: return lpf("trend.projected.source.rhythm")
            case .scheduledOnly: return lpf("trend.projected.source.scheduled")
            }
        }
    }
}
