//
//  L10n+ResumenIAHora.swift
//  Yala
//
//  La marca del resumen con IA de Estadísticas escrito con cifras que ya no son las de ahora: «Escrito con tus datos
//  de las 18:05 · Actualizar» (ticket `stats-ai-summary-shows-figures-from-before-the-latest-records`, opción B de
//  Jürgen del 2026-11-17). En su propio fichero, como los lotes de 2.3.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su
/// fichero.
private func resumenIAHoraString(_ key: String) -> String {
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
    enum ResumenIAHora {
        /// «Escrito con tus datos de las 18:05». La hora llega ya formateada (`time(_:)`).
        static func writtenAt(_ time: String) -> String {
            String(format: resumenIAHoraString("insights.aiStale.writtenAt"), locale: AppLocale.current, time)
        }

        static var refresh: String { resumenIAHoraString("insights.aiStale.refresh") }

        /// Lo que dice VoiceOver del botón: qué hace, no solo su nombre.
        static var refreshHint: String { resumenIAHoraString("insights.aiStale.refreshHint") }

        /// «Actualizar» con el techo del día gastado.
        static var dailyCapReached: String { resumenIAHoraString("insights.aiStale.dailyCap") }

        /// La hora en el formato de la persona: 12 o 24 horas según su ajuste del iPhone (`hourCycle` de `region`), en
        /// el idioma de la app (`language`: «p. m.», «PM», «午後»…).
        static func time(_ date: Foundation.Date, language: Locale = AppLocale.current, region: Locale = .current) -> String {
            let pattern = DateFormatter.dateFormat(fromTemplate: "jmm", options: 0, locale: region) ?? "HH:mm"
            let formatter = DateFormatter()
            formatter.locale = language
            formatter.dateFormat = pattern
            return formatter.string(from: date)
        }
    }
}
