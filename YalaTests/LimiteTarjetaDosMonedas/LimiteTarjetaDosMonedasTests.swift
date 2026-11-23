//
//  LimiteTarjetaDosMonedasTests.swift
//  YalaTests
//
//  El uso de línea de una tarjeta con dos monedas (decisión de Jürgen del 22-nov-2026): lo usado se mide en la divisa
//  del límite y lo de la otra se convierte. Sin tipo de cambio, no hay línea. Y la nota que lo dice, en los 16 idiomas.
//

import Foundation
import Testing
@testable import Yala

@Suite("Límite de tarjeta · uso de línea con dos monedas")
struct LimiteTarjetaDosMonedasTests {

    typealias L = HojaCuentaTarjetaLogica

    /// 1 USD = 3,75 PEN; cualquier otra pareja, sin tipo de cambio.
    private static func convertir(_ monto: Double, _ desde: String) -> Double? {
        desde == "USD" ? monto * 3.75 : nil
    }

    private static func linea(_ facturado: Double, _ porFacturar: Double, _ divisa: String) -> L.LineaEnDivisa {
        L.LineaEnDivisa(facturado: facturado, porFacturar: porFacturar, divisa: divisa)
    }

    @Test func dosMonedas_conCambio_sumaEnLaDivisaDelLimite() throws {
        // 1.000 S/ + 200 USD × 3,75 = 1.750 S/ de 5.000 → 35 %.
        let r = try #require(L.usoDeLinea(lineas: [Self.linea(600, 400, "PEN"), Self.linea(150, 50, "USD")],
                                          limite: 5_000, divisaLimite: "PEN", convertir: Self.convertir))
        #expect(r.uso.usado == 1_750)
        #expect(r.uso.fraccionUsada == 0.35)
        #expect(r.uso.disponible == 3_250)
        #expect(r.divisasConvertidas == ["USD"])
    }

    @Test func dosMonedas_sinCambio_noHayLinea() {
        #expect(L.usoDeLinea(lineas: [Self.linea(600, 0, "PEN"), Self.linea(100, 0, "EUR")],
                             limite: 5_000, divisaLimite: "PEN", convertir: Self.convertir) == nil)
    }

    @Test func saldoAFavor_enUnaMoneda_cuentaComoCero_yNoDescuenta() throws {
        // -300 USD a favor no rebajan los 1.000 S/: son dos deudas. Y no se convierte nada, así que no hay nota.
        let r = try #require(L.usoDeLinea(lineas: [Self.linea(1_000, 0, "PEN"), Self.linea(-300, 0, "USD")],
                                          limite: 4_000, divisaLimite: "PEN", convertir: Self.convertir))
        #expect(r.uso.usado == 1_000)
        #expect(r.divisasConvertidas.isEmpty)
    }

    @Test func saldoAFavor_enLaOtra_sinCambio_noImporta() throws {
        // Nada que convertir en EUR (saldo a favor): no hace falta tipo de cambio para esa pareja.
        let r = try #require(L.usoDeLinea(lineas: [Self.linea(500, 0, "PEN"), Self.linea(-20, 0, "EUR")],
                                          limite: 1_000, divisaLimite: "PEN", convertir: Self.convertir))
        #expect(r.uso.fraccionUsada == 0.5)
    }

    @Test func pasarseDelLimite_conLoConvertido_seDiceTalCual() throws {
        // 900 S/ + 100 USD × 3,75 = 1.275 S/ de 1.000 → 127,5 % y nada disponible.
        let r = try #require(L.usoDeLinea(lineas: [Self.linea(900, 0, "PEN"), Self.linea(0, 100, "USD")],
                                          limite: 1_000, divisaLimite: "PEN", convertir: Self.convertir))
        #expect(r.uso.fraccionUsada == 1.275)
        #expect(r.uso.disponible == 0)
    }

    @Test func limiteEnDolares_convierteLosSoles() throws {
        let r = try #require(L.usoDeLinea(lineas: [Self.linea(375, 0, "PEN"), Self.linea(100, 0, "USD")],
                                          limite: 1_000, divisaLimite: "USD") { monto, desde in
            desde == "PEN" ? monto / 3.75 : nil
        })
        #expect(r.uso.usado == 200)
        #expect(r.divisasConvertidas == ["PEN"])
    }

    @Test func sinLimite_nada() {
        for limite in [nil, 0, -10, Double.infinity] as [Double?] {
            #expect(L.usoDeLinea(lineas: [Self.linea(1, 1, "PEN"), Self.linea(1, 1, "USD")],
                                 limite: limite, divisaLimite: "PEN", convertir: Self.convertir) == nil)
        }
    }

    @Test func unaSolaDivisa_igualQueAntes_sinNota() throws {
        let r = try #require(L.usoDeLinea(lineas: [Self.linea(1_000, 247.5, "PEN")], limite: 8_000,
                                          divisaLimite: "PEN") { _, _ in Issue.record("No convierte."); return nil })
        #expect(r.uso == L.usoDeLinea(lineas: [(1_000, 247.5)], limite: 8_000))
        #expect(r.divisasConvertidas.isEmpty)
    }
}

@MainActor
@Suite("Límite de tarjeta · nota de conversión en los 16 idiomas")
struct LimiteTarjetaDosMonedasTextosTests {

    private static func table(_ locale: String) throws -> [String: String] {
        let url = HojaCuentaTarjetaTextosTests.repoRoot()
            .appending(path: "Yala/Resources/\(locale).lproj/LimiteTarjeta.strings")
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        return try #require(plist as? [String: String])
    }

    @Test(arguments: HojaCuentaTarjetaTextosTests.locales)
    func cadaIdioma_tieneLaNota_conUnHueco(_ locale: String) throws {
        let nota = try #require(try Self.table(locale)["limiteTarjeta.lineUsage.converted"], "\(locale) sin la nota.")
        #expect(nota.components(separatedBy: "%@").count == 2, "\(locale): la nota lleva un solo hueco.")
    }

    @Test func espanolNeutro_sinVosotros() throws {
        for locale in ["es", "es-419", "es-ES"] {
            let nota = try #require(try Self.table(locale)["limiteTarjeta.lineUsage.converted"])
            #expect(nota == "Aprox.: incluye lo que debes en %@, al último tipo de cambio.")
        }
    }

    @Test func elCodigo_encuentraLaClave() {
        #expect(!L10n.LimiteTarjeta.notaConversion(divisas: "USD").hasPrefix("limiteTarjeta."))
        #expect(L10n.LimiteTarjeta.notaConversion(divisas: "USD").contains("USD"))
    }
}
