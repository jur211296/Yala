//
//  PrimerosPasosPulidoText.swift
//  Yala
//
//  Los textos nuevos del pulido de Primeros pasos (encargo del 2026-11-20), en su propia tabla
//  (`PrimerosPasosPulido.strings`), leídos con el idioma de la app como `PagoLogoPropioText`.
//

import Foundation

enum PrimerosPasosPulidoText {
    static let table = "PrimerosPasosPulido"

    static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
        let sentinel = "__YALA_MISSING__"
        let fullKey = "primerosPasosPulido.\(key)"
        var value = resolution.bundle.localizedString(forKey: fullKey, value: sentinel, table: table)
        if value == sentinel, let parent = resolution.parentBundle {
            value = parent.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        if value == sentinel {
            value = Bundle.main.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        return value == sentinel ? fullKey : value
    }

    /// Paso 3, primera pregunta: la salida sin crear nada (sustituye a «Omitir este paso» de la intro).
    static var budgetNoneOption: String { string("budget.noneOption") }
    /// Paso 4, primera pregunta: la salida sin crear nada.
    static var paymentNoneOption: String { string("payment.noneOption") }
    /// Paso 4, título de la primera pregunta (sustituye a «¿Qué pagas cada cierto tiempo?»).
    static var paymentKindQuestion: String { string("payment.kindQuestion") }
    /// Paso 4, debajo del título: los pagos fijos que Yala propone sola tras tres cobros (Pagos que se repiten, S1).
    static var paymentKindAutoDetect: String { string("payment.kindAutoDetect") }
    /// Paso 3, al terminar: cuántos presupuestos caben en el plan gratis.
    static func budgetDoneFreeLimit(_ limit: Int) -> String {
        String(format: string("budget.doneFreeLimit"), locale: LanguageManager.resolved.locale, limit)
    }
    /// Paso 3, al terminar: empezar otro ahí mismo.
    static var budgetCreateAnother: String { string("budget.createAnother") }
    /// Paso 4, al terminar: los pagos planificados no tienen tope en el plan gratis (`ProFeature` no los cuenta).
    static var paymentDoneFree: String { string("payment.doneFree") }
}
