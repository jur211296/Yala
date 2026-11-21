//
//  CuentaSolaAlLeerPeticionTests.swift
//  YalaTests
//
//  Lo que la petición de la foto lleva de las cuentas (capa B, decisión de Jürgen del 20-nov) y cómo se lee la respuesta.
//  El criterio del encargo: en la petición viajan los nombres de las cuentas con su clase y su moneda, y NUNCA saldos,
//  números de cuenta ni últimos 4. Se comprueba sobre el cuerpo JSON de la petición que sale, no sobre el tipo.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct CuentaSolaAlLeerPeticionTests {

    private let candidatas = [
        CuentaSolaAlLeer.Cuenta(
            id: UUID(), name: "Zip Visa", kind: .creditCard, currencyCode: "PEN", accountNumber: "4557 8800 1234 9031"),
        CuentaSolaAlLeer.Cuenta(id: UUID(), name: "Efectivo", kind: .cash, currencyCode: "USD", accountNumber: "998877"),
    ]

    private func body(accounts: [CuentaSolaAlLeerPeticion.Cuenta]) throws -> String {
        let query = ImageVisionService().makeQuery(
            imageData: Data([0xFF, 0xD8, 0xFF]), currency: .unknown, accounts: accounts, today: "Friday, 2026-11-20")
        return try #require(String(data: JSONEncoder().encode(query), encoding: .utf8))
    }

    @Test("En la nube viajan nombre, clase y moneda; nunca el número de cuenta ni sus últimos 4")
    func nubeLlevaNombresSinNumeros() throws {
        let cuentas = CuentaSolaAlLeerPeticion.cuentas(from: candidatas, isCloud: true)
        let json = try body(accounts: cuentas)
        #expect(json.contains("Zip Visa"))
        #expect(json.contains("credit card"))
        #expect(json.contains("PEN"))
        #expect(json.contains("Efectivo"))
        // Ni el número entero ni sus últimos 4 (el prompt trae su propio ejemplo enmascarado, «••4417»).
        #expect(!json.contains("9031"))
        #expect(!json.contains("4557"))
        #expect(!json.contains("998877"))
    }

    @Test("En iCloud privado no viaja ninguna cuenta: la petición es la de siempre")
    func privadoNoLlevaCuentas() throws {
        let cuentas = CuentaSolaAlLeerPeticion.cuentas(from: candidatas, isCloud: false)
        #expect(cuentas.isEmpty)
        #expect(CuentaSolaAlLeerPeticion.texto(cuentas) == nil)
        let json = try body(accounts: cuentas)
        #expect(!json.contains("Zip Visa"))
        #expect(!json.contains("The user's accounts"))
    }

    @Test("La lista se corta en el tope y un nombre con saltos de línea va en una sola")
    func topeYSaltos() {
        let muchas = (0..<60).map {
            CuentaSolaAlLeer.Cuenta(id: UUID(), name: "Cuenta \($0)", kind: .bank, currencyCode: "PEN", accountNumber: nil)
        }
        #expect(CuentaSolaAlLeerPeticion.cuentas(from: muchas, isCloud: true).count == CuentaSolaAlLeerPeticion.maxCuentas)
        let texto = CuentaSolaAlLeerPeticion.texto([.init(name: "Zip\nVisa", kind: .creditCard, currencyCode: "PEN")])
        #expect(texto?.contains("- Zip Visa | credit card | PEN") == true)
    }

    @Test("El prompt de la foto pide los dos campos nuevos y su ejemplo no enseña un medio de pago inventado")
    func promptPideLosCampos() {
        let prompt = ImageVisionService().systemPrompt(currency: .unknown)
        #expect(prompt.contains("- Payment:"))
        #expect(prompt.contains("- Account:"))
        #expect(prompt.contains("\"payment\": null, \"account\": null"))
    }

    // MARK: - La respuesta

    @Test("Con los campos, se leen; sin ellos (gateway viejo), nil como antes")
    func decodificaConYSinCampos() throws {
        let con = #"{"amount":-25.9,"date":"2026-11-20","merchant":"Tambo","note":null,"currency":"PEN","payment":"Zip Visa ••4417","account":"Zip Visa"}"#
        let sin = #"{"amount":-25.9,"date":"2026-11-20","merchant":"Tambo","note":null,"currency":"PEN"}"#
        let a = try JSONDecoder().decode(VisionTransaction.self, from: Data(con.utf8))
        let b = try JSONDecoder().decode(VisionTransaction.self, from: Data(sin.utf8))
        #expect(a.payment == "Zip Visa ••4417")
        #expect(a.account == "Zip Visa")
        #expect(a.amount == -25.9)
        #expect(b.payment == nil)
        #expect(b.account == nil)
        #expect(b.merchant == "Tambo")
    }

    @Test("Un medio de pago que no es texto no tumba la lectura del movimiento")
    func campoRaroNoTumba() throws {
        let raro = #"{"amount":-10,"date":null,"merchant":"X","note":null,"currency":null,"payment":4417,"account":["a"]}"#
        let t = try JSONDecoder().decode(VisionTransaction.self, from: Data(raro.utf8))
        #expect(t.amount == -10)
        #expect(t.payment == nil)
        #expect(t.account == nil)
    }
}
