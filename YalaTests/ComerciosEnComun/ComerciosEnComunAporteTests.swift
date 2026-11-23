//
//  ComerciosEnComunAporteTests.swift
//  YalaTests
//
//  «Comercios en común» (2.3, 2026-11-22): qué se aporta y qué no.
//  Una suite por fichero: `makeTestContext()` se comparte por fichero (regla de testing.md).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Qué se aporta

@MainActor
@Suite("Comercios en común — qué se aporta", .serialized)
struct ComerciosEnComunAporteTests {

    @Test func soloLoCapturado() {
        for source: DraftSourceType in [.voice, .siri, .receiptPhoto, .screenshotList, .screenshotSingle, .emailAlert,
                                        .applePay, .automation] {
            #expect(ComerciosEnComunTipo.sourceContributes(source), "\(source)")
        }
        for source: DraftSourceType in [.manual, .scheduledPayment, .subscription, .groupExpense, .groupSettlement,
                                        .groupScheduledExpense, .aiConnector] {
            #expect(!ComerciosEnComunTipo.sourceContributes(source), "\(source)")
        }
    }

    @Test func encolaComercioYTipo_yNadaMas() throws {
        let e = try ComerciosEscenario.make()
        e.comunes.registrarAporte(merchantRaw: "IZI*TAMBO+ AV LARCO 1153", subcategory: e.super_, source: .applePay,
                                  visibles: e.visibles)
        #expect(e.comunes.estado.cola == [ComercioAporte(merchant: "TAMBO", kind: "supermarket")])
        // Lo que viaja: dos campos, sin más.
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(e.comunes.estado.cola[0])) as? [String: Any]
        #expect(Set(json?.keys ?? [:].keys) == ["merchant", "kind"])
    }

    @Test func noSeRepite() throws {
        let e = try ComerciosEscenario.make()
        for _ in 0..<3 {
            e.comunes.registrarAporte(merchantRaw: "Tambo", subcategory: e.super_, source: .voice, visibles: e.visibles)
        }
        #expect(e.comunes.estado.cola.count == 1)
    }

    @Test func noAporta_categoriaPropia_alquiler_ingreso_niManual() throws {
        let e = try ComerciosEscenario.make()
        e.comunes.registrarAporte(merchantRaw: "Chifa Don Lucho", subcategory: e.antojo, source: .voice, visibles: e.visibles)
        e.comunes.registrarAporte(merchantRaw: "Inmobiliaria Sol", subcategory: e.alquiler, source: .voice, visibles: e.visibles)
        e.comunes.registrarAporte(merchantRaw: "Empresa SAC", subcategory: e.sueldo, source: .voice, visibles: e.visibles)
        e.comunes.registrarAporte(merchantRaw: "Tambo", subcategory: e.super_, source: .manual, visibles: e.visibles)
        #expect(e.comunes.estado.cola.isEmpty)
        // Control: el mismo gasto capturado sí aporta.
        e.comunes.registrarAporte(merchantRaw: "Tambo", subcategory: e.super_, source: .voice, visibles: e.visibles)
        #expect(e.comunes.estado.cola.count == 1)
    }

    @Test func apagarAportar_vaciaLaCola_yNoEncolaMas() throws {
        let e = try ComerciosEscenario.make()
        e.comunes.registrarAporte(merchantRaw: "Tambo", subcategory: e.super_, source: .voice, visibles: e.visibles)
        e.comunes.aporta = false
        #expect(e.comunes.estado.cola.isEmpty)
        e.comunes.registrarAporte(merchantRaw: "Mifarma", subcategory: e.farmacia, source: .voice, visibles: e.visibles)
        #expect(e.comunes.estado.cola.isEmpty)
    }
}

