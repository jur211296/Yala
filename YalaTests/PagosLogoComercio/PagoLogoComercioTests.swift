//
//  PagoLogoComercioTests.swift
//  YalaTests
//
//  Pagos planificados: el logo del comercio con un criterio para la lista, la línea de tiempo y el calendario
//  (decisión de Jürgen del 2026-11-18). Fija dos cosas: que la pieza común decide lo mismo que el banco y recuerda el
//  casado (sin coste al desplazar), y que las tres vistas pasan por ella, también la fila con letra grande.
//

import Foundation
import Testing

@testable import Yala

@Suite("Pagos planificados · logo del comercio: la pieza común", .serialized)
@MainActor
struct PagoLogoComercioTests {

    @Test("Decide lo mismo que el banco: logo elegido, quitado, automático y sin casar")
    func decideLoMismoQueElBanco() {
        PagoLogoComercio._testReset()
        defer { PagoLogoComercio._testReset() }
        let casos: [(String?, String)] = [
            (nil, "Netflix"), (nil, "Recibo Luz del Sur"), (nil, "Pago Claro"), (nil, "Alquiler"),
            (nil, "Almuerzo con Ana"), (SubscriptionBrandCatalog.noneID, "Netflix"), ("spotify", "Mi música"),
            ("id-que-ya-no-existe", "Spotify"), (nil, ""),
        ]
        for (guardado, nombre) in casos {
            let esperado = PaymentLogoResolver.resolve(storedID: guardado, name: nombre)
            #expect(PagoLogoComercio.logo(logoGuardado: guardado, nombre: nombre) == esperado, "\(guardado ?? "nil") · \(nombre)")
        }
        // Control del escenario: hay casos con logo y sin él.
        #expect(PagoLogoComercio.logo(logoGuardado: nil, nombre: "Netflix") != nil)
        #expect(PagoLogoComercio.logo(logoGuardado: nil, nombre: "Alquiler") == nil)
        #expect(PagoLogoComercio.logo(logoGuardado: SubscriptionBrandCatalog.noneID, nombre: "Netflix") == nil)
    }

    @Test("Recuerda el casado: repintar no vuelve a recorrer el banco, ni cuando no casa")
    func recuerdaElCasado() {
        PagoLogoComercio._testReset()
        defer { PagoLogoComercio._testReset() }
        for _ in 0..<50 {
            _ = PagoLogoComercio.logo(logoGuardado: nil, nombre: "Netflix")
            _ = PagoLogoComercio.logo(logoGuardado: nil, nombre: "Alquiler")
        }
        #expect(PagoLogoComercio.casadosReales == 2)
    }

    @Test("Renombrar el pago o elegir otro logo cambia la clave: no se queda con el logo viejo")
    func renombrarCambiaElLogo() {
        PagoLogoComercio._testReset()
        defer { PagoLogoComercio._testReset() }
        let antes = PagoLogoComercio.logo(logoGuardado: nil, nombre: "Netflix")
        let renombrado = PagoLogoComercio.logo(logoGuardado: nil, nombre: "Spotify")
        let quitado = PagoLogoComercio.logo(logoGuardado: SubscriptionBrandCatalog.noneID, nombre: "Spotify")
        #expect(antes?.id != renombrado?.id)
        #expect(renombrado != nil)
        #expect(quitado == nil)
    }

    @Test("El recuerdo tiene techo: pasado, empieza de cero y sigue contestando bien")
    func techo() {
        PagoLogoComercio._testReset()
        defer { PagoLogoComercio._testReset() }
        for indice in 0..<(PagoLogoComercio.techo + 5) {
            _ = PagoLogoComercio.logo(logoGuardado: nil, nombre: "Pago \(indice)")
        }
        #expect(PagoLogoComercio.casadosReales == PagoLogoComercio.techo + 5)
        // Tras vaciarse, «Pago 0» se vuelve a casar una vez y luego se recuerda.
        _ = PagoLogoComercio.logo(logoGuardado: nil, nombre: "Pago 0")
        _ = PagoLogoComercio.logo(logoGuardado: nil, nombre: "Pago 0")
        #expect(PagoLogoComercio.casadosReales == PagoLogoComercio.techo + 6)
        #expect(PagoLogoComercio.logo(logoGuardado: nil, nombre: "Netflix") != nil)
    }
}

@Suite("Pagos planificados · logo del comercio: cableado de las tres vistas (source-scan)")
struct PagoLogoComercioCableadoTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Sin comentarios, para que documentar el invariante no lo cumpla.
    private static func codeOnly(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let range = line.range(of: "//") else { return line }
                return line[..<range.lowerBound]
            }
            .joined(separator: "\n")
    }

    private static func count(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private static let lista = "Yala/App/Views/Planning/ScheduledPaymentsListView.swift"
    private static let fila = "Yala/App/Views/Planning/ScheduledPaymentRowView.swift"

    @Test("Ninguna de las tres vistas casa por su cuenta: todas preguntan a la pieza común")
    func ningunaCasaPorSuCuenta() throws {
        for path in [Self.lista, Self.fila] {
            let code = Self.codeOnly(try Self.source(path))
            #expect(!code.contains(".paymentLogo"), "\(path) vuelve a casar sin recordar")
            #expect(!code.contains("PaymentLogoResolver"), "\(path) vuelve a casar sin recordar")
        }
    }

    @Test("Lista, línea de tiempo y calendario pintan con la pieza común")
    func lasTresVistasUsanLaPieza() throws {
        let lista = Self.codeOnly(try Self.source(Self.lista))
        // Línea de tiempo: el distintivo en sus dos formas (tamaño normal y letra grande) sale de una función que usa la pieza.
        #expect(Self.count("timelineBrandBadge(summary)", in: lista) == 2)
        #expect(lista.contains("PagoLogoDistintivo(logo: PagoLogoComercio.logo(for: summary.payment), diameter: DS.Icon.badgeSmall)"))
        // Calendario: la marca lee el mismo logo. Desde el 24-nov-2026 toda marca es logo o icono, así que el límite por
        // celda ya no depende del logo (`calendarMarkLimit`, fijado en `YalaTests/PagosPlanificadosChipsVista/`).
        #expect(Self.count("PagoLogoComercio.logo(for: $0.payment)", in: lista) == 0)
        #expect(lista.contains("if let logo = PagoLogoComercio.logo(for: summary.payment)"))
    }

    @Test("La fila enseña el logo también con letra grande: las dos formas pintan el mismo distintivo")
    func laFilaConLetraGrandeTambien() throws {
        let fila = Self.codeOnly(try Self.source(Self.fila))
        // El distintivo se define una vez y lo usan las dos ramas (letra normal y de accesibilidad).
        #expect(Self.count("distintivo", in: fila) == 3, "una definición y dos usos")
        #expect(fila.contains("PagoLogoDistintivo(logo: PagoLogoComercio.logo(for: summary.payment))"))
        // El icono de la subcategoría solo queda como respaldo del distintivo (definición + un uso).
        #expect(Self.count("paymentIcon", in: fila) == 2)
    }
}
