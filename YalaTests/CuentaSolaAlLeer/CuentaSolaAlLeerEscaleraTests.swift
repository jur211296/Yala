//
//  CuentaSolaAlLeerEscaleraTests.swift
//  YalaTests
//
//  La escalera común de la cuenta sola al leer una captura (`CuentaSolaAlLeer`, parte 1 del ticket
//  `2026-11-20-captura-cuenta-automatica-y-reglas`) y su segunda capa, la IA (decisión A + B de Jürgen). Lógica pura, sin
//  SwiftData: la suite con contexto va aparte (`CuentaSolaAlLeerDraftTests`).
//

import Foundation
import Testing

@testable import Yala

struct CuentaSolaAlLeerEscaleraTests {

    private typealias Logic = CuentaSolaAlLeer

    private func cuenta(
        _ name: String, _ kind: PaymentMethodAccountLogic.AccountKind = .bank, currency: String = "PEN",
        number: String? = nil
    ) -> Logic.Cuenta {
        Logic.Cuenta(id: UUID(), name: name, kind: kind, currencyCode: currency, accountNumber: number)
    }

    // La semilla `ficha`: tres cuentas en soles y una en dólares.
    private let principal = Logic.Cuenta(
        id: UUID(), name: "Cuenta Principal", kind: .bank, currencyCode: "PEN", accountNumber: nil)
    private let efectivo = Logic.Cuenta(id: UUID(), name: "Efectivo", kind: .cash, currencyCode: "PEN", accountNumber: nil)
    private let tarjeta = Logic.Cuenta(
        id: UUID(), name: "Tarjeta de crédito", kind: .creditCard, currencyCode: "PEN", accountNumber: nil)
    private let ahorros = Logic.Cuenta(id: UUID(), name: "Ahorros USD", kind: .bank, currencyCode: "USD", accountNumber: nil)
    private var ficha: [Logic.Cuenta] { [principal, efectivo, tarjeta, ahorros] }

    // MARK: - Pasos de la escalera

    @Test("«Tarjeta de crédito» en la imagen elige esa cuenta por su nombre")
    func nombreEntero() {
        #expect(Logic.leer(mention: "Tarjeta de crédito", last4: nil, among: ficha) == .elegida(tarjeta.id, .nombre))
    }

    @Test("«Zip» → Zip; «Zip Visa ••4417» → Zip Visa (el nombre más largo escrito entero gana)")
    func zipYZipVisa() {
        let zip = cuenta("Zip", .creditCard)
        let zipVisa = cuenta("Zip Visa", .creditCard)
        #expect(Logic.leer(mention: "Zip", last4: nil, among: [zip, zipVisa]) == .elegida(zip.id, .nombre))
        #expect(Logic.leer(mention: "Zip Visa ••4417", last4: nil, among: [zip, zipVisa]) == .elegida(zipVisa.id, .nombre))
    }

    @Test("«Visa» con «BCP Visa» e «Interbank Visa» no elige: las dos coinciden")
    func dosCoinciden() {
        let bcp = cuenta("BCP Visa", .creditCard)
        let ibk = cuenta("Interbank Visa", .creditCard)
        #expect(Logic.leer(mention: "Visa", last4: nil, among: [bcp, ibk, efectivo]) == .varias([bcp.id, ibk.id]))
    }

    @Test("Dos nombres igual de largos escritos enteros: no elige")
    func empateDeLongitud() {
        let a = cuenta("BCP Soles")
        let b = cuenta("BBVA Soles")
        let c = cuenta("BCP Dolar")
        #expect(Logic.leer(mention: "BCP Soles y BCP Dolar", last4: nil, among: [a, b, c]) == .varias([a.id, c.id]))
    }

    @Test("«****4417» elige la cuenta cuyo número acaba en 4417 aunque el nombre no salga")
    func ultimos4() {
        let zipVisa = cuenta("Zip Visa", .creditCard, number: "4557-8800-1234-4417")
        let otra = cuenta("Interbank", .creditCard, number: "1111")
        #expect(Logic.leer(mention: "Visa ****4417", last4: nil, among: [otra, zipVisa]) == .elegida(zipVisa.id, .last4))
        // Los del aviso llegan aparte.
        #expect(Logic.leer(mention: nil, last4: "4417", among: [otra, zipVisa]) == .elegida(zipVisa.id, .last4))
        // «terminada en», en palabras.
        #expect(Logic.leer(mention: "tarjeta terminada en 4417", last4: nil, among: [otra, zipVisa]) == .elegida(zipVisa.id, .last4))
    }

    @Test("Los últimos 4 mandan sobre el nombre")
    func ultimos4AntesQueNombre() {
        let zip = cuenta("Zip", .creditCard)
        let zipVisa = cuenta("Zip Visa", .creditCard, number: "··4417")
        #expect(Logic.leer(mention: "Zip ••4417", last4: nil, among: [zip, zipVisa]) == .elegida(zipVisa.id, .last4))
    }

    @Test("Dos cuentas que acaban en los mismos 4 dígitos: no elige y las dos coinciden")
    func ultimos4Repetidos() {
        let a = cuenta("Visa", .creditCard, number: "9999 4417")
        let b = cuenta("Master", .creditCard, number: "4417")
        #expect(Logic.leer(mention: "••4417", last4: nil, among: [a, b]) == .varias([a.id, b.id]))
    }

    @Test("Un número de cuenta con menos de 4 dígitos no casa con nada")
    func numeroCorto() {
        #expect(Logic.last4(ofAccountNumber: "417") == nil)
        #expect(Logic.last4(ofAccountNumber: "ES12 3456 7890 4417") == "4417")
        #expect(Logic.last4(ofAccountNumber: nil) == nil)
    }

    @Test("Palabras del nombre: «yape» → «Yape BCP»; las cifras sueltas no cuentan")
    func palabras() {
        let yape = cuenta("Yape BCP")
        #expect(Logic.leer(mention: "yape", last4: nil, among: [yape, efectivo]) == .elegida(yape.id, .palabras))
        #expect(Logic.leer(mention: "Yape 4417", last4: nil, among: [yape, efectivo]) == .elegida(yape.id, .palabras))
    }

    @Test("Clase: «efectivo» va a la única cuenta de efectivo aunque no se llame así")
    func clase() {
        let billetera = cuenta("Billetera", .cash)
        #expect(Logic.leer(mention: "efectivo", last4: nil, among: [billetera, principal]) == .elegida(billetera.id, .clase))
    }

    @Test("Sin medio de pago o con uno que no casa con nada, no elige (sigue la moneda)")
    func ninguna() {
        #expect(Logic.leer(mention: nil, last4: nil, among: ficha) == .ninguna)
        #expect(Logic.leer(mention: "  ", last4: nil, among: ficha) == .ninguna)
        #expect(Logic.leer(mention: "Tunki", last4: nil, among: ficha) == .ninguna)
    }

    // MARK: - Segunda capa: la IA

    @Test("La cuenta de la IA vale si existe y sus palabras están en el medio de pago")
    func cuentaDeIAValida() {
        let ibk = cuenta("Interbank Visa", .creditCard)
        let bcp = cuenta("BCP Visa", .creditCard)
        #expect(Logic.cuentaDeIA("interbank visa", payment: "Visa ••4417", among: [ibk, bcp]) == ibk.id)
    }

    @Test("Un nombre que la IA inventa se ignora")
    func cuentaDeIAInventada() {
        #expect(Logic.cuentaDeIA("Scotiabank Oro", payment: "Visa Oro", among: ficha) == nil)
    }

    @Test("Una cuenta real cuyas palabras no están en lo leído se ignora")
    func cuentaDeIASinRastro() {
        #expect(Logic.cuentaDeIA("Efectivo", payment: "Tarjeta de crédito", among: ficha) == nil)
        #expect(Logic.cuentaDeIA("Efectivo", payment: nil, among: ficha) == nil)
    }

    @Test("Teléfono e IA coinciden → sola, con estrella")
    func coinciden() {
        let lectura = Logic.leer(mention: "Tarjeta de crédito", last4: nil, among: ficha)
        #expect(Logic.combinar(lectura, iaAccountID: tarjeta.id) == .sola(tarjeta.id, .nombre))
    }

    @Test("Solo la IA propone una cuenta que existe → sugerida")
    func soloIA() {
        let bcp = cuenta("BCP Visa", .creditCard)
        let ibk = cuenta("Interbank Visa", .creditCard)
        let accounts = [bcp, ibk]
        let lectura = Logic.leer(mention: "Visa", last4: nil, among: accounts)
        let ia = Logic.cuentaDeIA("Interbank Visa", payment: "Visa", among: accounts)
        #expect(Logic.combinar(lectura, iaAccountID: ia) == .sugerida(ibk.id))
        #expect(Logic.combinar(.ninguna, iaAccountID: ibk.id) == .sugerida(ibk.id))
    }

    @Test("La IA propone un nombre que no existe → se ignora y manda el teléfono")
    func iaInventaYManda() {
        let ia = Logic.cuentaDeIA("Diners Club", payment: "Tarjeta de crédito", among: ficha)
        let lectura = Logic.leer(mention: "Tarjeta de crédito", last4: nil, among: ficha)
        #expect(ia == nil)
        #expect(Logic.combinar(lectura, iaAccountID: ia) == .sola(tarjeta.id, .nombre))
    }

    @Test("Teléfono e IA discrepan → no elige y enseña las dos")
    func discrepan() {
        let payment = "Tarjeta de crédito · Cuenta Principal"
        let lectura = Logic.leer(mention: payment, last4: nil, among: ficha)
        let ia = Logic.cuentaDeIA("Cuenta Principal", payment: payment, among: ficha)
        let resultado = Logic.combinar(lectura, iaAccountID: ia)
        #expect(resultado == .choque(telefono: tarjeta.id, ia: principal.id))
        #expect(resultado.cuentaPuesta == nil)
    }

    @Test("Sin IA (Apple Pay, avisos, correo) la escalera decide sola")
    func sinIA() {
        #expect(Logic.combinar(.elegida(tarjeta.id, .last4), iaAccountID: nil) == .sola(tarjeta.id, .last4))
        #expect(Logic.combinar(.varias([tarjeta.id, principal.id]), iaAccountID: nil) == .varias([tarjeta.id, principal.id]))
        #expect(Logic.combinar(.ninguna, iaAccountID: nil) == .ninguna)
    }

    // MARK: - Lo que se enseña

    @Test("El chip deja la estrella si la persona cambia la cuenta, y «Elige cuenta» si elige una")
    func chip() {
        #expect(Logic.chip(for: .sola(tarjeta.id, .nombre), currentAccountID: tarjeta.id) == .elegida(.nombre))
        #expect(Logic.chip(for: .sola(tarjeta.id, .nombre), currentAccountID: efectivo.id) == .normal)
        #expect(Logic.chip(for: .sugerida(tarjeta.id), currentAccountID: tarjeta.id) == .sugerida)
        #expect(Logic.chip(for: .varias([tarjeta.id, principal.id]), currentAccountID: nil) == .elige(coinciden: 2))
        #expect(Logic.chip(for: .varias([tarjeta.id, principal.id]), currentAccountID: tarjeta.id) == .normal)
        #expect(Logic.chip(for: .choque(telefono: tarjeta.id, ia: principal.id), currentAccountID: nil) == .elige(coinciden: 2))
        #expect(Logic.chip(for: nil, currentAccountID: nil) == .normal)
    }

    @Test("La línea de «por qué» sale tres veces y luego no")
    func porqueTresVeces() {
        #expect((0..<5).map { Logic.muestraPorque(vecesMostrada: $0) } == [true, true, true, false, false])
    }

    @Test("«Coinciden con «Visa»» cita el medio de pago sin los dígitos")
    func palabraCitada() {
        #expect(Logic.palabraCitada("Visa ••4417") == "Visa")
        #expect(Logic.palabraCitada("••4417") == nil)
        #expect(Logic.palabraCitada(nil) == nil)
    }

    @Test("La elección guarda los últimos 4 que leyó, para «termina en 4417»")
    func eleccionGuardaDigitos() {
        let eleccion = Logic.Eleccion(resultado: .sola(tarjeta.id, .last4), mention: "Visa ****4417", last4: nil)
        #expect(eleccion.last4 == "4417")
    }
}
