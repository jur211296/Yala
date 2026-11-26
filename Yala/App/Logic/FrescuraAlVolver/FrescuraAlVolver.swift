//
//  FrescuraAlVolver.swift
//  Yala
//
//  ¿Cambió algo mientras la pantalla no estaba delante? Para las pantallas que no tienen firma propia de carga
//  (Registros, Grupos y el detalle de grupo; el Panel, Estadísticas e Informes usan la suya). Lote 1 de eficiencia.
//
//  La firma se toma al IRSE (la primera fase no activa: `.inactive` o `.background`) y se compara al volver. Cambió si
//  hubo un guardado de SwiftData en el proceso (`StoreSaveCounter`, de cualquier contexto y de los dos almacenes: también
//  las páginas que baja la nube de Grupos sin subir `dataVersion`), si subió `dataVersion` (lo que baja CloudKit se aplica
//  así al volver) o si cambió el día. Además obliga el trabajo que el freno cortó o descartó con la app fuera, y lo que el
//  contexto tenga sin guardar. Sin firma tomada (la app volvió sin haberse ido por esta pantalla), recarga: es el lado
//  seguro.
//

import Foundation

/// Lo que tenía el mundo en un instante: lo que puede cambiar lo que pinta una pantalla sin que ella lo oiga.
struct FirmaAlVolver: Equatable {
    let dataVersion: Int
    let storeSaves: Int
    let day: Date

    static func tomar(dataVersion: Int, storeSaves: Int, now: Date, calendar: Calendar) -> FirmaAlVolver {
        FirmaAlVolver(dataVersion: dataVersion, storeSaves: storeSaves, day: calendar.startOfDay(for: now))
    }
}

/// El estado de una pantalla entre irse y volver. Vive en un `@State` de la pantalla.
struct FrescuraAlVolver: Equatable {

    /// La firma de cuando la app dejó de estar activa. `nil` con la app delante.
    private(set) var firmaAlIrse: FirmaAlVolver?
    /// Volvió con la página oculta: la próxima aparición comprueba antes de pintar.
    private(set) var pendienteAlAparecer = false

    /// La app dejó de estar activa. Solo cuenta la primera fase: `.inactive` → `.background` no mueve la firma.
    mutating func alIrse(_ firma: FirmaAlVolver) {
        if firmaAlIrse == nil { firmaAlIrse = firma }
    }

    /// La app volvió con la página a la vista: ¿recargar? Consume la firma.
    mutating func alVolverVisible(ahora: FirmaAlVolver, trabajoSinTerminar: Bool, cambiosSinGuardar: Bool) -> Bool {
        defer { firmaAlIrse = nil }
        return Self.hayQueRecargar(
            alIrse: firmaAlIrse, ahora: ahora, trabajoSinTerminar: trabajoSinTerminar, cambiosSinGuardar: cambiosSinGuardar)
    }

    /// La app volvió con la página oculta: no calcula, y la próxima aparición compara contra la firma de cuando se fue.
    mutating func alVolverOculta() {
        pendienteAlAparecer = true
    }

    /// La página apareció. `nil` si no había nada pendiente de una vuelta (la pantalla hace lo de siempre); si lo había,
    /// si hay que recargar. Consume el pendiente y la firma.
    mutating func alAparecer(ahora: FirmaAlVolver, trabajoSinTerminar: Bool, cambiosSinGuardar: Bool) -> Bool? {
        guard pendienteAlAparecer else { return nil }
        pendienteAlAparecer = false
        defer { firmaAlIrse = nil }
        return Self.hayQueRecargar(
            alIrse: firmaAlIrse, ahora: ahora, trabajoSinTerminar: trabajoSinTerminar, cambiosSinGuardar: cambiosSinGuardar)
    }

    static func hayQueRecargar(
        alIrse: FirmaAlVolver?,
        ahora: FirmaAlVolver,
        trabajoSinTerminar: Bool,
        cambiosSinGuardar: Bool
    ) -> Bool {
        guard let alIrse else { return true }
        return trabajoSinTerminar || cambiosSinGuardar || alIrse != ahora
    }
}
