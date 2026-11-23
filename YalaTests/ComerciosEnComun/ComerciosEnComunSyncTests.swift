//
//  ComerciosEnComunSyncTests.swift
//  YalaTests
//
//  «Comercios en común» (2.3, 2026-11-22): el aviso, el lote semanal y la lista diaria.
//  Una suite por fichero: `makeTestContext()` se comparte por fichero (regla de testing.md).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Envío y descarga

@MainActor
@Suite("Comercios en común — envío semanal y lista diaria", .serialized)
struct ComerciosEnComunSyncTests {

    @Test func avisoAntesDelPrimerEnvio_unaVez_yElLoteEsperaUnaSemana() async throws {
        var e = try ComerciosEscenario.make()
        var avisos = 0
        var ahora = e.ahora
        e.comunes.now = { ahora }
        e.comunes.mostrarAviso = { _ in avisos += 1 }
        e.comunes.registrarAporte(merchantRaw: "Tambo", subcategory: e.super_, source: .voice, visibles: e.visibles)

        await e.comunes.sincronizarSiToca()
        #expect(avisos == 1)
        #expect(e.transporte.lotes.isEmpty, "El lote espera una semana desde que entró lo primero.")

        ahora = ahora.addingTimeInterval(6 * 86_400)
        await e.comunes.sincronizarSiToca()
        #expect(e.transporte.lotes.isEmpty)

        ahora = ahora.addingTimeInterval(86_400)
        await e.comunes.sincronizarSiToca()
        #expect(avisos == 1, "El aviso sale una sola vez.")
        #expect(e.transporte.lotes == [[ComercioAporte(merchant: "TAMBO", kind: "supermarket")]])
        #expect(e.comunes.estado.cola.isEmpty)
        e.ahora = ahora
    }

    @Test func sinAviso_noSeEnviaNada() async throws {
        let e = try ComerciosEscenario.make()
        e.comunes.now = { e.ahora.addingTimeInterval(30 * 86_400) }
        e.comunes.registrarAporte(merchantRaw: "Tambo", subcategory: e.super_, source: .voice, visibles: e.visibles)
        await e.comunes.enviarSiToca()
        #expect(e.transporte.lotes.isEmpty)
    }

    @Test func noAportarDesdeElAviso_apagaYVacia() async throws {
        let e = try ComerciosEscenario.make()
        var accion: (@MainActor () -> Void)?
        e.comunes.mostrarAviso = { accion = $0 }
        e.comunes.registrarAporte(merchantRaw: "Tambo", subcategory: e.super_, source: .voice, visibles: e.visibles)
        e.comunes.mostrarAvisoSiToca()
        accion?()
        #expect(!e.comunes.aporta)
        #expect(e.comunes.estado.cola.isEmpty)
    }

    @Test func telefonoNuevo_conservaLaCola() async throws {
        let e = try ComerciosEscenario.make()
        var ahora = e.ahora
        e.comunes.now = { ahora }
        e.comunes.mostrarAviso = { _ in }
        e.transporte.envioRespuesta = .telefonoNuevo
        e.comunes.registrarAporte(merchantRaw: "Tambo", subcategory: e.super_, source: .voice, visibles: e.visibles)
        e.comunes.mostrarAvisoSiToca()
        ahora = ahora.addingTimeInterval(8 * 86_400)
        await e.comunes.enviarSiToca()
        #expect(e.transporte.lotes.count == 1)
        #expect(e.comunes.estado.cola.count == 1)
        // Se reintenta la semana siguiente, no al instante.
        await e.comunes.enviarSiToca()
        #expect(e.transporte.lotes.count == 1)
    }

    @Test func unFalloDeRed_noPierdeNada() async throws {
        let e = try ComerciosEscenario.make()
        var ahora = e.ahora
        e.comunes.now = { ahora }
        e.comunes.mostrarAviso = { _ in }
        e.transporte.falla = true
        e.comunes.registrarAporte(merchantRaw: "Tambo", subcategory: e.super_, source: .voice, visibles: e.visibles)
        e.comunes.mostrarAvisoSiToca()
        ahora = ahora.addingTimeInterval(8 * 86_400)
        await e.comunes.enviarSiToca()
        #expect(e.comunes.estado.cola.count == 1)
    }

    @Test func elLoteNoPasaDe30() async throws {
        let e = try ComerciosEscenario.make()
        var ahora = e.ahora
        e.comunes.now = { ahora }
        e.comunes.mostrarAviso = { _ in }
        for i in 0..<35 {
            e.comunes.registrarAporte(merchantRaw: "Tienda X\(Character(UnicodeScalar(UInt8(65 + i % 26))))\(Character(UnicodeScalar(UInt8(65 + i / 26))))",
                                      subcategory: e.super_, source: .voice, visibles: e.visibles)
        }
        #expect(e.comunes.estado.cola.count == 35)
        e.comunes.mostrarAvisoSiToca()
        ahora = ahora.addingTimeInterval(8 * 86_400)
        await e.comunes.enviarSiToca()
        #expect(e.transporte.lotes.first?.count == 30)
        #expect(e.comunes.estado.cola.count == 5)
    }

    @Test func laListaSeBajaUnaVezAlDia_conSuVersion() async throws {
        let e = try ComerciosEscenario.make()
        var ahora = e.ahora
        e.comunes.now = { ahora }
        e.transporte.listaRespuesta = .nueva(version: "v1", items: ["TAMBO": "supermarket"])
        await e.comunes.bajarListaSiToca()
        #expect(e.comunes.tipo(paraComercio: "Tambo+") == .supermarket)
        await e.comunes.bajarListaSiToca()
        #expect(e.transporte.versionesPedidas == [nil])
        ahora = ahora.addingTimeInterval(86_401)
        e.transporte.listaRespuesta = .sinCambios
        await e.comunes.bajarListaSiToca()
        #expect(e.transporte.versionesPedidas == [nil, "v1"])
        #expect(e.comunes.tipo(paraComercio: "Tambo+") == .supermarket)
    }
}

