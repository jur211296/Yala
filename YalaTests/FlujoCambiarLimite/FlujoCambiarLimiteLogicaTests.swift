//
//  FlujoCambiarLimiteLogicaTests.swift
//  YalaTests
//
//  S4 del replanteo del flujo de caja: qué se escribe con cada alcance y cómo se lee el monto. La hoja «Cambiar límite»
//  se retiró el 19-nov-2026; esta lógica la usa «Cálculo del monto» al guardar un monto fijo. Lógica pura, sin contexto.
//

import Foundation
import Testing

@testable import Yala

@Suite("Flujo de caja · cambiar límite · lógica")
struct FlujoCambiarLimiteLogicaTests {

    typealias L = FlujoCambiarLimiteLogica

    @Test func porDefecto_esDesdeEsteMes() {
        #expect(L.Alcance.porDefecto == .desdeEsteMes, "P3 de Jürgen")
    }

    @Test func cero_esValido_negativoNo() {
        #expect(L.esMontoValido(0))
        #expect(!L.esMontoValido(-1))
        #expect(!L.esMontoValido(.infinity))
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
}
