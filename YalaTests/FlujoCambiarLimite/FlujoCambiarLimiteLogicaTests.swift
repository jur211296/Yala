//
//  FlujoCambiarLimiteLogicaTests.swift
//  YalaTests
//
//  S4 del replanteo del flujo de caja: qué meses cambia cada alcance de «Cambiar límite», qué se escribe y cómo se lee
//  el monto. Lógica pura, sin contexto.
//

import Foundation
import Testing

@testable import Yala

@Suite("Flujo de caja · cambiar límite · lógica")
struct FlujoCambiarLimiteLogicaTests {

    typealias L = FlujoCambiarLimiteLogica

    /// Oct (pasado) · Nov (elegido) · Dic · Ene (con ajuste propio) · Feb.
    private let meses: [L.Mes] = [
        .init(monthKey: "2026-10", limite: 800, tieneAjustePropio: false, esPasado: true),
        .init(monthKey: "2026-11", limite: 900, tieneAjustePropio: false, esPasado: false),
        .init(monthKey: "2026-12", limite: 900, tieneAjustePropio: false, esPasado: false),
        .init(monthKey: "2027-01", limite: 1500, tieneAjustePropio: true, esPasado: false),
        .init(monthKey: "2027-02", limite: 900, tieneAjustePropio: false, esPasado: false),
    ]

    private func cambian(_ alcance: L.Alcance, desde elegido: String = "2026-11") -> [String] {
        L.filas(meses: meses, alcance: alcance, elegido: elegido, monto: 1000).filter(\.cambia).map(\.monthKey)
    }

    @Test func porDefecto_esDesdeEsteMes() {
        #expect(L.Alcance.porDefecto == .desdeEsteMes, "P3 de Jürgen")
    }

    @Test func soloEsteMes_cambiaUnoSolo() {
        #expect(cambian(.soloEsteMes) == ["2026-11"])
    }

    @Test func desdeEsteMes_noTocaLosAnteriores_niLosQueTienenAjustePropio() {
        #expect(cambian(.desdeEsteMes) == ["2026-11", "2026-12", "2027-02"])
        let enero = L.filas(meses: meses, alcance: .desdeEsteMes, elegido: "2026-11", monto: 1000)
            .first { $0.monthKey == "2027-01" }
        #expect(enero?.conservaAjuste == true)
        #expect(enero?.despues == 1500)
        #expect(L.conservanAjuste(meses: meses, elegido: "2026-11") == ["2027-01"])
    }

    @Test func desdeUnMesConAjustePropio_loCambiaATambienEse() {
        #expect(cambian(.desdeEsteMes, desde: "2027-01") == ["2027-01", "2027-02"])
    }

    @Test func todos_cambiaTambienElPasadoYLosAjustes() {
        #expect(cambian(.todos) == meses.map(\.monthKey))
    }

    @Test func unMesPasado_sePuedeElegir() {
        #expect(cambian(.soloEsteMes, desde: "2026-10") == ["2026-10"])
        #expect(cambian(.desdeEsteMes, desde: "2026-10") == ["2026-10", "2026-11", "2026-12", "2027-02"])
    }

    @Test func sinMontoValido_lasFilasRepitenElAntes() {
        let filas = L.filas(meses: meses, alcance: .todos, elegido: "2026-11", monto: nil)
        #expect(filas.allSatisfy { $0.antes == $0.despues })
        let negativo = L.filas(meses: meses, alcance: .todos, elegido: "2026-11", monto: -5)
        #expect(negativo.allSatisfy { $0.antes == $0.despues })
    }

    @Test func cero_esValido_negativoNo() {
        #expect(L.esMontoValido(0))
        #expect(!L.esMontoValido(-1))
        #expect(!L.esMontoValido(.infinity))
        #expect(L.filas(meses: meses, alcance: .soloEsteMes, elegido: "2026-11", monto: 0)
            .first { $0.monthKey == "2026-11" }?.despues == 0)
    }

    @Test func montoEscrito() {
        let us = Locale(identifier: "en_US")
        let pe = Locale(identifier: "es_ES")
        #expect(L.montoEscrito("", locale: us) == nil, "vacío no es 0")
        #expect(L.montoEscrito("  ", locale: us) == nil)
        #expect(L.montoEscrito("0", locale: us) == 0)
        #expect(L.montoEscrito("1,234.5", locale: us) == 1234.5)
        #expect(L.montoEscrito("1.234,5", locale: pe) == 1234.5)
        #expect(L.montoEscrito("-5", locale: us) == nil)
        #expect(L.montoEscrito("abc", locale: us) == nil)
    }

    // MARK: - Escritura

    @Test func escritura_soloEsteMes_esUnAjusteDeEseMes_yNoTocaLosCambios() {
        let previos: [CashFlowAmountChangeLogic.Change] = [.init(monthKey: "2026-09", amount: 700)]
        let e = L.escritura(alcance: .soloEsteMes, elegido: "2026-11", monto: 0, cambiosActuales: previos)
        #expect(e.ajusteDeUnMes == "2026-11")
        #expect(e.retirarAjustes == .mes("2026-11"))
        #expect(e.cambiosDesde == previos)
        #expect(e.montoFijo == nil)
    }

    @Test func escritura_desdeEsteMes_guardaElCambio_yRetiraLosPosteriores() {
        let previos: [CashFlowAmountChangeLogic.Change] = [
            .init(monthKey: "2026-09", amount: 700), .init(monthKey: "2027-01", amount: 1200),
        ]
        let e = L.escritura(alcance: .desdeEsteMes, elegido: "2026-11", monto: 1000, cambiosActuales: previos)
        #expect(e.ajusteDeUnMes == nil)
        #expect(e.retirarAjustes == .mes("2026-11"))
        #expect(e.cambiosDesde == [.init(monthKey: "2026-09", amount: 700), .init(monthKey: "2026-11", amount: 1000)])
        #expect(e.montoFijo == nil)
    }

    @Test func escritura_todos_esMontoFijo_sinCambiosNiAjustes() {
        let previos: [CashFlowAmountChangeLogic.Change] = [.init(monthKey: "2026-09", amount: 700)]
        let e = L.escritura(alcance: .todos, elegido: "2026-11", monto: 1000, cambiosActuales: previos)
        #expect(e.ajusteDeUnMes == nil)
        #expect(e.retirarAjustes == .todos)
        #expect(e.cambiosDesde.isEmpty)
        #expect(e.montoFijo == 1000)
    }

    @Test func escritura_todos_enUnPagoPlanificado_conservaElMetodo() {
        let e = L.escritura(
            alcance: .todos, elegido: "2026-11", monto: 50, cambiosActuales: [.init(monthKey: "2026-12", amount: 9)],
            conservaMetodo: true, primerMes: "2026-08")
        #expect(e.montoFijo == nil, "a monto fijo, el motor deja de darle a la línea los cobros de su pago")
        #expect(e.retirarAjustes == .todos)
        #expect(e.cambiosDesde == [.init(monthKey: "2026-08", amount: 50)], "desde el primer mes del plan")
    }

    @Test func mismoMonto_aCentimos() {
        #expect(L.mismoMonto(123.456, 123.46))
        #expect(!L.mismoMonto(123.45, 123.46))
    }
}
