//
//  AppLanguageRowLogic.swift
//  Yala
//
//  UX 2.2 · L16-5 (opción B de Jürgen, 2026-10-23, «híbrido»). La fila «Idioma de la app» de Personalización sale
//  siempre. Adónde lleva depende de lo que iOS ofrece:
//
//  - Con más de un idioma en el iPhone (General › Idioma y región), la página de Yala en los Ajustes de iOS enseña
//    «Idioma»: se va allí, porque ese camino traduce también Buscar y las fechas de las gráficas.
//  - Con uno solo, iOS no enseña nada (medido el 2026-10-22 en el simulador): se abre el selector de Yala.
//  - Con un idioma elegido en el selector de Yala (`LanguageManager.overrideLanguage`), el selector de Yala manda sobre
//    el de iOS (`LanguageManager.resolved`), así que cambiarlo en iOS no haría nada: también el selector de Yala.
//

import Foundation

enum AppLanguageRowLogic {

    enum Route: Equatable {
        /// La página de Yala en los Ajustes de iOS, donde está «Idioma».
        case iOSSettings
        /// El selector de idioma propio de Yala.
        case yalaPicker
    }

    static func route(overrideLanguage: String?, preferredLanguages: [String]) -> Route {
        guard overrideLanguage == nil else { return .yalaPicker }
        return preferredLanguages.count > 1 ? .iOSSettings : .yalaPicker
    }

    /// El idioma que marca el selector de Yala al abrirse: el elegido en Yala o, si no hay, el del iPhone resuelto con la
    /// misma cadena que la bienvenida (`SupportedLocale.bestMatch`: exacto → región → idioma base → inglés). Nunca un
    /// alias (`es`, `pt`), que el selector no enseña.
    static func currentCode(overrideLanguage: String?, preferredLanguages: [String], region: String?) -> String {
        if let overrideLanguage { return overrideLanguage }
        return SupportedLocale.bestMatch(forPreferredLanguages: preferredLanguages, region: region).code
    }
}
