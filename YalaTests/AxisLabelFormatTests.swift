//
//  AxisLabelFormatTests.swift
//  YalaTests
//
//  Etiquetas del eje Y de las gráficas del Panel (auditoría UX 2.2, lote 3, B3): con un eje
//  estrecho, redondear a miles enteros pintaba «2K 2K 2K».
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct AxisLabelFormatTests {

    /// El saldo de una cuenta nueva de S/ 1.800: las marcas del eje no pueden salir iguales.
    @Test func ejeEstrecho_marcasDistintas() {
        let domain = 1_710.0...1_890.0
        let labels = [1_750.0, 1_800.0, 1_850.0].map { YalaFormatter.axisK($0, domain: domain) }
        #expect(labels == ["1.75K", "1.8K", "1.85K"])
        #expect(Set(labels).count == labels.count)
    }

    /// Un eje de barras de 0 a 1.800: 1.500 no puede leerse «2K».
    @Test func ejeDeCeroAMil_mediosMiles() {
        let domain = 0.0...1_890.0
        #expect(YalaFormatter.axisK(1_500, domain: domain) == "1.5K")
        #expect(YalaFormatter.axisK(1_000, domain: domain) == "1K")
        #expect(YalaFormatter.axisK(500, domain: domain) == "500")
        #expect(YalaFormatter.axisK(0, domain: domain) == "0")
    }

    /// Ejes anchos: igual que antes, miles enteros.
    @Test func ejeAncho_milesEnteros() {
        let domain = 90_000.0...100_000.0
        #expect(YalaFormatter.axisK(94_000, domain: domain) == "94K")
        #expect(YalaFormatter.axisK(98_000, domain: domain) == "98K")
    }

    @Test func negativos_conSigno() {
        let domain = -2_000.0...2_000.0
        #expect(YalaFormatter.axisK(-1_500, domain: domain) == "-1.5K")
    }

    @Test func ejeMenorQueMil_decimalesSoloSiHacenFalta() {
        #expect(YalaFormatter.axisK(10.5, domain: 10.0...11.0) == "10.5")
        #expect(YalaFormatter.axisK(400, domain: 0.0...800.0) == "400")
    }

    /// Un dominio degenerado (todos los puntos iguales) no puede romper el formato.
    @Test func dominioPlano_noRompe() {
        #expect(YalaFormatter.axisK(1_800, domain: 1_800.0...1_800.0) == "2K")
    }
}
