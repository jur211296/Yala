//
//  MarcasRecalculoPanel.swift
//  Yala
//
//  Lote 4 de eficiencia (26-nov-2026). Marcas del recálculo del Panel: un intervalo `os_signpost`
//  «Panel.performCalculation» por cálculo y uno por etapa, para leerlos con Instruments (Time Profiler + os_signpost) en el
//  iPhone, y en DEBUG un resumen por consola con lo que costó cada etapa y el tramo más largo sin ceder el hilo.
//
//  El tramo más largo es la cifra que importa: mientras dura, la app no atiende toques ni el paso a segundo plano. Con
//  16.004 movimientos en el iPhone 14 el cálculo entero era un solo tramo de ~7 s (`docs/qa/rendimiento-iphone14-2026-11-26/`).
//

import Foundation
import os

@MainActor
final class MarcasRecalculoPanel {

    nonisolated static let signposter = OSSignposter(subsystem: "com.yala", category: "PanelRecalculo")

    private let reloj = ContinuousClock()
    private let inicio: ContinuousClock.Instant
    private let estado: OSSignpostIntervalState
    private var etapaAbierta: (nombre: StaticString, inicio: ContinuousClock.Instant, estado: OSSignpostIntervalState)?
    private(set) var etapas: [(nombre: String, duracion: Duration)] = []

    init() {
        inicio = reloj.now
        estado = Self.signposter.beginInterval("Panel.performCalculation")
    }

    /// Abre la etapa `nombre` y cierra la anterior, si había.
    func etapa(_ nombre: StaticString) {
        cerrarEtapa()
        etapaAbierta = (nombre, reloj.now, Self.signposter.beginInterval(nombre))
    }

    private func cerrarEtapa() {
        guard let abierta = etapaAbierta else { return }
        Self.signposter.endInterval(abierta.nombre, abierta.estado)
        etapas.append(("\(abierta.nombre)", reloj.now - abierta.inicio))
        etapaAbierta = nil
    }

    /// Cierra el cálculo. `cesion` aporta el tramo más largo sin ceder el hilo y cuántas veces cedió.
    func terminar(completado: Bool, cesion: CesionDelHilo?) {
        cerrarEtapa()
        Self.signposter.endInterval("Panel.performCalculation", estado)
        #if DEBUG
        let total = reloj.now - inicio
        let detalle = etapas.map { "\($0.nombre) \(Self.ms($0.duracion))" }.joined(separator: " · ")
        let tramo = cesion.map { " · tramo máx \(Self.ms($0.tramoMasLargo)) · cesiones \($0.cesiones)" } ?? ""
        print("PERF panel-calculo \(completado ? "completo" : "cortado") total \(Self.ms(total))\(tramo) · \(detalle)")
        #endif
    }

    nonisolated static func ms(_ duracion: Duration) -> String {
        let c = duracion.components
        let milis = Double(c.seconds) * 1_000 + Double(c.attoseconds) / 1e15
        return String(format: "%.0f ms", milis)
    }
}
