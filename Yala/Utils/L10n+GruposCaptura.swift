//
//  L10n+GruposCaptura.swift
//  Yala
//
//  Textos de Voz, Foto y Yala IA dentro de un grupo, hechos como los de personal (encargo «Grupos: voz, foto y Yala IA
//  idénticos a personal», 2026-11-16). Solo lo que es del grupo: lo demás usa los textos de personal tal cual. En su
//  propio fichero, como los de cada lote, para no pisar `L10n.swift` con otras sesiones.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func lgc(_ key: String) -> String {
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
    enum GruposCaptura {
        // Foto: título y subtítulo de la hoja, como «Registrar con foto o archivo» de personal
        static var photoTitle: String { lgc("gruposCaptura.photo.title") }
        static var photoSubtitle: String { lgc("gruposCaptura.photo.subtitle") }
        // Foto: el paso mientras se lee, como «Buscando el importe» de personal
        static var readingStep: String { lgc("gruposCaptura.photo.readingStep") }
        // Volver a grabar u otra foto con el reparto a la vista: lo que se pierde
        static var discardSplitMessage: String { lgc("gruposCaptura.discard.message") }
        // Yala IA: saludo, caja de texto, respuesta y botón de ajustar
        static var chatGreeting: String { lgc("gruposCaptura.chat.greeting") }
        static var chatPlaceholder: String { lgc("gruposCaptura.chat.placeholder") }
        static var chatReply: String { lgc("gruposCaptura.chat.reply") }
        static var chatAdjust: String { lgc("gruposCaptura.chat.adjust") }
    }
}
