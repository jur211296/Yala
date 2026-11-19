//
//  ImageEntryAutoClose.swift
//  Yala
//
//  Cuándo la hoja de foto se cierra sola tras guardar (encargo «X nativa en la hoja de foto», 2026-11-17): al guardarse
//  el último pendiente con todos guardados, la hoja enseña «Guardado» con su háptica un instante y se va, sin pedir
//  «Listo». Si queda algo por hacer en la hoja —un registro sin guardar (también uno desmarcado, que se queda en la
//  Bandeja), un guardado que falló, fotos que no se leyeron o páginas que no entraron—, se queda abierta con su aviso.
//

import Foundation

enum ImageEntryAutoCloseLogic {
    /// Lo que la hoja tiene a la vista justo después de un guardado.
    struct State: Equatable {
        /// Cuántos registros enseña «Esto leí» y cuántos de ellos quedaron guardados.
        var draftCount: Int
        var savedCount: Int
        var saveFailed: Bool
        /// Fotos que no se leyeron (el aviso con Reintentar o Yala Pro).
        var failedPhotos: Int
        /// Páginas de un PDF o fotos compartidas que no entraron por el tope de la tanda.
        var leftOut: Int
    }

    static func closesAfterSaving(_ state: State) -> Bool {
        state.draftCount > 0
            && state.savedCount == state.draftCount
            && !state.saveFailed
            && state.failedPhotos == 0
            && state.leftOut == 0
    }

    /// Lo que dura la confirmación antes de cerrarse: el título pasa a «Guardado» y la fila enseña su check.
    static let confirmationDelay: Duration = .milliseconds(600)

    /// `-uitest-image-autoclose-seconds <s>`: un XCUITest que lee la hoja ya guardada antes de que se vaya la alarga. No
    /// decide si se cierra, solo cuándo.
    static var delay: Duration {
        #if DEBUG
        if UITestHooks.isActive,
           let raw = UITestHooks.parseValue(after: "-uitest-image-autoclose-seconds", from: ProcessInfo.processInfo.arguments),
           let seconds = Double(raw), seconds > 0 {
            return .milliseconds(Int(seconds * 1000))
        }
        #endif
        return confirmationDelay
    }
}
