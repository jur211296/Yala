//
//  MarcasFotoWidgets.swift
//  Yala
//
//  Lote 7 de eficiencia (27-nov-2026). Marcas de la foto de los widgets por etapas: un intervalo `os_signpost`
//  «Widgets.foto» por foto (subsystem `com.yala`, categoría `FotoWidgets`), para leerlo con Instruments en el iPhone, y en
//  DEBUG una línea por consola con su duración en reloj, los tramos y el más largo sin ceder el hilo. Es la cifra que
//  mide el lote: con 16.004 movimientos la foto dejaba bloques de hasta 1,3 s en el arranque.
//

import Foundation
import os

@MainActor
enum MarcasFotoWidgets {

    nonisolated static let signposter = OSSignposter(subsystem: "com.yala", category: "FotoWidgets")

    private static var abierta: (inicio: ContinuousClock.Instant, estado: OSSignpostIntervalState)?

    /// Empieza una foto por etapas.
    static func empezar() {
        // Una foto tirada a medias (un guardado, el paso a segundo plano) no llega a `tramos`: se cierra aquí.
        if let anterior = abierta { signposter.endInterval("Widgets.foto", anterior.estado) }
        abierta = (ContinuousClock.now, signposter.beginInterval("Widgets.foto"))
    }

    /// Termina la foto: cuántos tramos y el más largo sin ceder.
    static func tramos(_ tramos: Int, masLargo: Duration) {
        guard let abierta else { return }
        signposter.endInterval("Widgets.foto", abierta.estado)
        self.abierta = nil
        #if DEBUG
        let total = ContinuousClock.now - abierta.inicio
        print("PERF widgets-foto total \(MarcasRecalculoPanel.ms(total)) · tramos \(tramos) · tramo máx \(MarcasRecalculoPanel.ms(masLargo))")
        #endif
    }
}
