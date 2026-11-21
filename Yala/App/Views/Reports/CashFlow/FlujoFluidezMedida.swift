//
//  FlujoFluidezMedida.swift
//  Yala
//
//  Cuánto cuesta en el hilo principal cada cálculo de Reportes (Flujo de caja y Comparativa). Solo en DEBUG: en Release
//  todo es un paso directo. Sale como signpost (`Instruments` → os_signpost, subsistema `app.yala.perf`, categoría
//  `fluidez`) y como línea de log con los milisegundos (`log show --predicate 'subsystem == "app.yala.perf"'`), que es lo
//  que lee la medición antes y después del encargo de fluidez del 20-nov-2026.
//

import Foundation
import os

enum FlujoFluidezMedida {

    /// El cálculo que se mide. El nombre es el que sale en el log («PERF fluidez flujo.recalcular 41.2 ms»).
    enum Trabajo: String {
        case flujoRecalcular = "flujo.recalcular"
        case comparativaCalcular = "comparativa.calcular"
    }

    #if DEBUG
    private static let signposter = OSSignposter(subsystem: "app.yala.perf", category: "fluidez")
    private static let logger = Logger(subsystem: "app.yala.perf", category: "fluidez")
    #endif

    /// Mide un bloque síncrono del hilo principal y escribe sus milisegundos.
    @MainActor
    @discardableResult
    static func medir<T>(_ trabajo: Trabajo, _ cuerpo: () throws -> T) rethrows -> T {
        #if DEBUG
        let nombre = trabajo.rawValue
        let state = signposter.beginInterval("fluidez", id: signposter.makeSignpostID(), "\(nombre, privacy: .public)")
        let inicio = DispatchTime.now().uptimeNanoseconds
        defer {
            let ms = Double(DispatchTime.now().uptimeNanoseconds - inicio) / 1_000_000
            signposter.endInterval("fluidez", state, "\(nombre, privacy: .public)")
            logger.notice("PERF fluidez \(nombre, privacy: .public) \(ms, format: .fixed(precision: 1), privacy: .public) ms")
        }
        #endif
        return try cuerpo()
    }
}
