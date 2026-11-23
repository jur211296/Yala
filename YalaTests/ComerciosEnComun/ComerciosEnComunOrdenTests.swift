//
//  ComerciosEnComunOrdenTests.swift
//  YalaTests
//
//  «Comercios en común» (2.3, 2026-11-22): el orden memoria › lista común y la línea de «Esto leí».
//  Una suite por fichero: `makeTestContext()` se comparte por fichero (regla de testing.md).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - El orden de las sugerencias

@MainActor
@Suite("Comercios en común — orden: memoria › lista común", .serialized)
struct ComerciosEnComunOrdenTests {

    private func listaCon(_ e: ComerciosEscenario, _ items: [String: String]) async {
        e.transporte.listaRespuesta = .nueva(version: "v", items: items)
        await e.comunes.bajarListaSiToca()
    }

    private func remember(_ merchant: String, as sub: Subcategory, approved: Int, corrected: Int = 0, in context: ModelContext) {
        context.insert(MerchantMemory(
            merchantCanonical: MerchantCanonicalizer.canonicalize(merchant), subcategory: sub,
            countApproved: approved, countCorrected: corrected, lastApprovedAt: Date(), aliases: [merchant]))
    }

    @Test func sinMemoria_laListaComunPropone_nuncaPoneSola() async throws {
        let e = try ComerciosEscenario.make()
        await listaCon(e, ["TAMBO": "supermarket"])
        let service = MerchantMemoryService(modelContext: e.context, comunes: e.comunes)
        guard case .suggest(let sub) = service.suggest(for: "IZI*TAMBO+ AV LARCO 1153", isExpense: true) else {
            Issue.record("La lista común tenía que proponer.")
            return
        }
        #expect(sub === e.super_)
        // Un ingreso no recibe una sugerencia de gasto.
        #expect({ if case .none = service.suggest(for: "Tambo", isExpense: false) { true } else { false } }())
    }

    @Test func memoriaDeUnaVez_ganaALaListaComun() async throws {
        let e = try ComerciosEscenario.make()
        await listaCon(e, ["TAMBO": "supermarket"])
        remember("Tambo", as: e.antojo, approved: 0, corrected: 1, in: e.context)
        try e.context.save()
        let service = MerchantMemoryService(modelContext: e.context, comunes: e.comunes)
        guard case .suggest(let sub) = service.suggest(for: "Tambo", isExpense: true) else {
            Issue.record("Tu corrección tenía que mandar desde la primera vez.")
            return
        }
        #expect(sub === e.antojo)
    }

    @Test func memoriaDeUnaVez_sinListaComun_siguiendoComoAntes() async throws {
        let e = try ComerciosEscenario.make()
        remember("Tambo", as: e.antojo, approved: 1, in: e.context)
        try e.context.save()
        let service = MerchantMemoryService(modelContext: e.context, comunes: e.comunes)
        #expect({ if case .none = service.suggest(for: "Tambo") { true } else { false } }(),
                "Sin lista común, la memoria por debajo del umbral sigue sin proponer.")
    }

    @Test func memoriaFuerte_siguePoniendoSola() async throws {
        let e = try ComerciosEscenario.make()
        await listaCon(e, ["TAMBO": "pharmacy"])
        remember("Tambo", as: e.super_, approved: 6, in: e.context)
        try e.context.save()
        let service = MerchantMemoryService(modelContext: e.context, comunes: e.comunes)
        guard case .autoAssign(let sub) = service.suggest(for: "Tambo") else {
            Issue.record("La memoria fuerte manda.")
            return
        }
        #expect(sub === e.super_)
    }

    @Test func updateMemory_conOrigen_aporta_sinOrigen_no() throws {
        let e = try ComerciosEscenario.make()
        let service = MerchantMemoryService(modelContext: e.context, comunes: e.comunes)
        service.updateMemory(merchantRaw: "Mifarma", subcategory: e.farmacia, wasCorrection: false)
        #expect(e.comunes.estado.cola.isEmpty)
        service.updateMemory(merchantRaw: "Mifarma", subcategory: e.farmacia, wasCorrection: false, source: .applePay)
        #expect(e.comunes.estado.cola == [ComercioAporte(merchant: "MIFARMA", kind: "pharmacy")])
    }

    @Test func laLineaDeEstoLei_soloSinMemoria() async throws {
        let e = try ComerciosEscenario.make()
        await listaCon(e, ["TAMBO": "supermarket"])
        let linea = { ComerciosEnComunLinea.comercio(
            note: "TAMBO+", subcategory: e.super_, isExpense: true, subcategories: e.visibles, context: e.context,
            comunes: e.comunes) }
        #expect(linea() == "Tambo+")
        // Con otra categoría elegida, no sale.
        #expect(ComerciosEnComunLinea.comercio(note: "TAMBO+", subcategory: e.antojo, isExpense: true,
                                               subcategories: e.visibles, context: e.context, comunes: e.comunes) == nil)
        // Con memoria de ese comercio, tampoco.
        remember("Tambo+", as: e.super_, approved: 1, in: e.context)
        try e.context.save()
        #expect(linea() == nil)
    }
}

