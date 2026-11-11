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
        /// Rótulo de la cifra al final del período, bajo la gráfica: dice de qué es y hasta cuándo (decisión 30 de 2.3).
        /// `%@` = día y mes («30 de noviembre»).
        static func closingBalance(_ day: String) -> String { String(format: lpf("trend.projected.closing.balance"), day) }
        static func closingExpense(_ day: String) -> String { String(format: lpf("trend.projected.closing.expense"), day) }
        static func closingIncome(_ day: String) -> String { String(format: lpf("trend.projected.closing.income"), day) }

        /// La cuenta de «Al 30 tendrías» en el mes en curso del flujo de caja: lo que falta entrar y salir hasta fin de mes.
        static var leftToComeIn: String { lpf("cashflow.monthEnd.leftIn") }
        static var leftToGoOut: String { lpf("cashflow.monthEnd.leftOut") }

        /// El enlace bajo la cifra al plan de flujo de caja: armarlo si no hay plan, verlo si lo hay.
        static var linkSetup: String { lpf("trend.projected.link.setup") }
        static var linkPlan: String { lpf("trend.projected.link.plan") }
        /// En la pantalla de armar el plan: para qué sirve también el plan.
        static var setupNote: String { lpf("trend.projected.setupNote") }

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

extension L10n.CashFlowPlan {
    /// Lo que falta de una línea en el mes en curso: es una estimación, y se dice con la misma palabra que el resto de lo
    /// estimado del flujo de caja (decisión 31 de 2.3).
    static var estimateLeft: String { lpf("cashFlowPlan.estimateLeft") }
}
