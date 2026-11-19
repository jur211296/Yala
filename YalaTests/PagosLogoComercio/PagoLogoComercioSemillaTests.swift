//
//  PagoLogoComercioSemillaTests.swift
//  YalaTests
//
//  El casado del logo medido sobre la semilla `realista` (encargo del 2026-11-18): qué pagos planificados enseñan logo
//  y cuáles se quedan con su icono, en el idioma de la semilla y en los dieciséis de la app. Y, como control de falsos
//  positivos, las descripciones de los movimientos de esa semilla: textos más libres que el nombre de un pago.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

#if DEBUG

@Suite("Pagos planificados · logo del comercio medido sobre la semilla realista", .serialized)
@MainActor
struct PagoLogoComercioSemillaTests {

    /// Lo que la semilla `realista` siembra como pagos planificados, con el logo que deben enseñar (`nil` = su icono).
    /// Netflix, Spotify e iCloud+ son comercios; gimnasio, alquiler, teléfono, internet y seguro, en genérico, no.
    private static let esperado: [String: String?] = [
        "Netflix": "netflix", "Spotify": "spotify", "iCloud+": "icloud",
    ]

    @Test("Pagos de la semilla: casan los comercios y los genéricos se quedan con su icono")
    func pagosDeLaSemilla() async throws {
        PagoLogoComercio._testReset()
        defer { PagoLogoComercio._testReset() }
        let sentinelKey = CategorySeedSentinel.currentKey
        let previousSentinel = UserDefaults.standard.object(forKey: sentinelKey)
        UserDefaults.standard.removeObject(forKey: sentinelKey)
        defer { UserDefaults.standard.set(previousSentinel, forKey: sentinelKey) }

        let context = try makeTestContext()
        await DevSeedService().seed(in: context, profile: .realista)
        let pagos = try context.fetch(FetchDescriptor<ScheduledPayment>())
        #expect(pagos.count >= 8, "la semilla sembró \(pagos.count) pagos")

        var conLogo: [String] = []
        var sinLogo: [String] = []
        for pago in pagos {
            let logo = PagoLogoComercio.logo(for: pago)
            if let esperadoID = Self.esperado[pago.name] {
                #expect(logo?.id == esperadoID, "\(pago.name) → \(logo?.id ?? "sin logo")")
            } else {
                #expect(logo == nil, "\(pago.name) casó con \(logo?.id ?? "")")
            }
            if let logo { conLogo.append("\(pago.name)→\(logo.id)") } else { sinLogo.append(pago.name) }
        }
        print("PagoLogoComercio: medición semilla realista · con logo \(conLogo.count)/\(pagos.count): \(conLogo.sorted()) · sin logo: \(sinLogo.sorted())")

        // Control de falsos positivos: las descripciones de los movimientos de la semilla.
        let movimientos = try context.fetch(FetchDescriptor<TransactionItem>())
        let notas = Set(movimientos.compactMap(\.note).filter { !$0.isEmpty })
        var casadas: [String] = []
        for nota in notas.sorted() {
            if let logo = PagoLogoComercio.logo(logoGuardado: nil, nombre: nota) { casadas.append("\(nota)→\(logo.id)") }
        }
        print("PagoLogoComercio: medición descripciones de movimientos · \(notas.count) distintas, casan \(casadas.count): \(casadas)")
        #expect(!notas.isEmpty, "la semilla no trajo descripciones: el control no mide nada")
    }

    @Test("Los nombres genéricos de la semilla no casan en ninguno de los dieciséis idiomas")
    func genericosEnLosDieciseisIdiomas() throws {
        PagoLogoComercio._testReset()
        defer { PagoLogoComercio._testReset() }
        let claves = ["devseed.spGym", "devseed.spRent", "devseed.spPhone", "devseed.spInsurance", "devseed.spInternet"]
        let carpetas = Bundle.main.paths(forResourcesOfType: "lproj", inDirectory: nil).filter { !$0.hasSuffix("Base.lproj") }
        #expect(carpetas.count >= 16, "solo \(carpetas.count) idiomas en el bundle")
        var casados: [String] = []
        for carpeta in carpetas {
            guard let bundle = Bundle(path: carpeta) else { continue }
            for clave in claves {
                let nombre = bundle.localizedString(forKey: clave, value: nil, table: nil)
                #expect(nombre != clave, "\(carpeta): falta \(clave)")
                if let logo = PagoLogoComercio.logo(logoGuardado: nil, nombre: nombre) {
                    casados.append("\((carpeta as NSString).lastPathComponent) \(nombre)→\(logo.id)")
                }
            }
        }
        #expect(casados.isEmpty, "\(casados)")
    }
}

#endif
