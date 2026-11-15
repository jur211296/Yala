//
//  L10n+VozFotoAvisos23.swift
//  Yala
//
//  Textos de la decisión 81 de la revisión 2.3 (Nuevo registro: «Volver a grabar» y «Otra foto» preguntan antes de
//  descartar lo entendido). En su propio fichero, como los de cada lote, para no pisar `L10n.swift` con otras sesiones.
//  El botón destructivo reusa «Descartar» de `L10n.Alert`, el mismo de «¿Descartar este registro?».
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func vfa(_ key: String) -> String {
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
    enum EntryDiscard {
        /// «¿Descartar lo que entendí?»: «Volver a grabar» con registros de la voz sin guardar.
        static var voiceTitle: String { vfa("entryDiscard.voice.title") }
        /// Qué pasa si se descarta: lo no guardado se borra y no queda en la Bandeja.
        static var voiceMessage: String { vfa("entryDiscard.voice.message") }
        /// «¿Descartar lo que leí?»: «Otra foto» con registros de la foto sin guardar.
        static var photoTitle: String { vfa("entryDiscard.photo.title") }
        /// Qué pasa si se descarta: lo no guardado se borra y no queda en la Bandeja.
        static var photoMessage: String { vfa("entryDiscard.photo.message") }
        /// La salida segura: cierra la pregunta y deja lo entendido como estaba.
        static var keepReviewing: String { vfa("entryDiscard.keepReviewing") }
    }
}
