//
//  L10n+DisenoTarjeta.swift
//  Yala
//
//  Tarjetas de cuenta personalizables del Panel (2026-11-16): el editor de diseño y lo que VoiceOver lee de la tarjeta.
//  En su propio fichero, como los lotes de 2.2 y 2.3.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su
/// fichero.
private func disenoTarjetaString(_ key: String) -> String {
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
    enum DisenoTarjeta {
        /// Título de la hoja y acción del menú contextual de la tarjeta.
        static var title: String { disenoTarjetaString("cardDesign.title") }
        static var open: String { disenoTarjetaString("cardDesign.open") }
        /// VoiceOver del botón de paleta: «Diseñar la tarjeta de Viajes».
        static func openFor(_ accountName: String) -> String {
            String(format: disenoTarjetaString("cardDesign.openFor"), accountName)
        }
        static var save: String { disenoTarjetaString("cardDesign.save") }
        static var cancel: String { disenoTarjetaString("cardDesign.cancel") }
        static var reset: String { disenoTarjetaString("cardDesign.reset") }

        /// VoiceOver de la tarjeta: «terminada en 1256».
        static func endingIn(_ digits: String) -> String {
            String(format: disenoTarjetaString("cardDesign.endingIn"), digits)
        }

        enum Section {
            static var templates: String { disenoTarjetaString("cardDesign.section.templates") }
            static var color: String { disenoTarjetaString("cardDesign.section.color") }
            static var pattern: String { disenoTarjetaString("cardDesign.section.pattern") }
            static var icon: String { disenoTarjetaString("cardDesign.section.icon") }
            static var details: String { disenoTarjetaString("cardDesign.section.details") }
        }

        enum Swatch {
            static var template: String { disenoTarjetaString("cardDesign.color.template") }
            static var account: String { disenoTarjetaString("cardDesign.color.account") }
            static var custom: String { disenoTarjetaString("cardDesign.color.custom") }
            /// VoiceOver de una muestra de color: «Color 3».
            static func numbered(_ number: Int) -> String {
                String(format: disenoTarjetaString("cardDesign.color.swatch"), number)
            }
        }

        enum Icon {
            static var account: String { disenoTarjetaString("cardDesign.icon.account") }
            /// VoiceOver de un ícono de la lista: «Ícono 3».
            static func numbered(_ number: Int) -> String {
                String(format: disenoTarjetaString("cardDesign.icon.choice"), number)
            }
        }

        static var chip: String { disenoTarjetaString("cardDesign.chip") }

        enum LastFour {
            static var title: String { disenoTarjetaString("cardDesign.lastFour.title") }
            static var prompt: String { disenoTarjetaString("cardDesign.lastFour.prompt") }
            static var footer: String { disenoTarjetaString("cardDesign.lastFour.footer") }
        }

        static func category(_ category: CardTemplateCategory) -> String {
            disenoTarjetaString("cardDesign.category.\(category.rawValue)")
        }

        static func template(_ id: String) -> String {
            disenoTarjetaString("cardDesign.template.\(id)")
        }

        static func pattern(_ pattern: CardPattern) -> String {
            disenoTarjetaString("cardDesign.pattern.\(pattern.rawValue)")
        }
    }
}
