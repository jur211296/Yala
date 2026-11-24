//
//  SelectorCuentaMonedaTests.swift
//  YalaTests
//
//  El selector de cuenta de un gasto o ingreso enseña solo las cuentas de la moneda del monto (pedido de Jürgen del
//  23-nov-2026, pruebas de 2.3 en el iPhone). Desde Nuevo registro y desde un borrador de la Bandeja; en la Bandeja abre
//  además a media altura, como en Nuevo registro. Las transferencias y el gasto de grupo siguen como estaban.
//
//  Lo que se fija aquí: qué cuentas salen (`AccountSelectorCurrencyScope`), que cambiar la moneda junto al monto lleve a
//  una cuenta de esa moneda que el selector enseña (`AmountCurrencyMenuLogic.target`) y el cableado de las dos pantallas,
//  leído del código porque las vistas no se montan aquí.
//

import Foundation
import Testing
@testable import Yala

@Suite("Selector de cuenta por moneda del monto")
struct SelectorCuentaMonedaTests {

    private struct Cuenta: Equatable {
        let id: String
        let moneda: String
    }

    private let cuentas = [
        Cuenta(id: "BCP Crédito PEN", moneda: "PEN"),
        Cuenta(id: "BCP Crédito USD", moneda: "USD"),
        Cuenta(id: "BCP Débito PEN", moneda: "PEN"),
        Cuenta(id: "BCP Débito USD", moneda: "USD"),
    ]

    private func mostradas(_ moneda: String?) -> AccountSelectorCurrencyScope.Shown<Cuenta> {
        AccountSelectorCurrencyScope.shown(cuentas, currencyCode: moneda, currencyOf: \.moneda)
    }

    // MARK: - Qué cuentas salen

    @Test func conSoles_soloLasCuentasEnSoles() {
        let shown = mostradas("PEN")
        #expect(shown.accounts.map(\.id) == ["BCP Crédito PEN", "BCP Débito PEN"])
        #expect(!shown.isFallback)
    }

    @Test func conDolares_soloLasCuentasEnDolares() {
        let shown = mostradas("USD")
        #expect(shown.accounts.map(\.id) == ["BCP Crédito USD", "BCP Débito USD"])
        #expect(!shown.isFallback)
    }

    @Test func laMonedaNoDistingueMayusculas() {
        #expect(mostradas("usd").accounts.map(\.id) == ["BCP Crédito USD", "BCP Débito USD"])
    }

    @Test func sinMoneda_todasLasCuentas() {
        let shown = mostradas(nil)
        #expect(shown.accounts == cuentas)
        #expect(!shown.isFallback)
    }

    /// Una moneda sin cuentas (un borrador en la moneda principal sin cuentas en ella, o un registro que se edita en una
    /// moneda que ya no tiene cuenta): la hoja no queda vacía, enseña todas y lo dice.
    @Test func monedaSinCuentas_ensenaTodasYLoDice() {
        let shown = mostradas("EUR")
        #expect(shown.accounts == cuentas)
        #expect(shown.isFallback)
    }

    /// Sin ninguna cuenta no hay nada que enseñar: el vacío de siempre, no el aviso de la moneda.
    @Test func sinCuentas_noEsRespaldo() {
        let shown = AccountSelectorCurrencyScope.shown([Cuenta](), currencyCode: "PEN", currencyOf: \.moneda)
        #expect(shown.accounts.isEmpty)
        #expect(!shown.isFallback)
    }

    // MARK: - Cambiar la moneda junto al monto

    private var menu: [AmountCurrencyAccount<String>] {
        cuentas.map { AmountCurrencyAccount(id: $0.id, currencyCode: $0.moneda) }
    }

    /// Con una cuenta en soles elegida, pasar a dólares lleva a la primera cuenta en dólares, y esa cuenta es una de las
    /// que enseña el selector con la moneda nueva.
    @Test func pasarADolares_llevaAUnaCuentaQueElSelectorEnsena() throws {
        let destino = try #require(AmountCurrencyMenuLogic.target(for: "USD", selected: "BCP Débito PEN", accounts: menu))
        #expect(destino == "BCP Crédito USD")
        #expect(mostradas("USD").accounts.map(\.id).contains(destino))
    }

    /// Con la cuenta ya en esa moneda, cambiar no la mueve.
    @Test func mismaMoneda_conservaLaCuenta() {
        #expect(AmountCurrencyMenuLogic.target(for: "PEN", selected: "BCP Débito PEN", accounts: menu) == "BCP Débito PEN")
    }

    /// Sin cuenta elegida (un borrador sin cuenta), elegir una moneda pone la primera cuenta en ella.
    @Test func sinCuenta_eligeLaPrimeraDeEsaMoneda() {
        #expect(AmountCurrencyMenuLogic.target(for: "USD", selected: nil, accounts: menu) == "BCP Crédito USD")
    }

    /// Una tarjeta con línea en dólares: elegir dólares lleva a su línea, no a otra cuenta.
    @Test func tarjetaConLinea_vaASuLinea() {
        let conLinea = [
            AmountCurrencyAccount(id: "Visa", currencyCode: "PEN", cardMembers: ["Visa", "Visa · USD"]),
            AmountCurrencyAccount(id: "Visa · USD", currencyCode: "USD", cardMembers: ["Visa", "Visa · USD"]),
            AmountCurrencyAccount(id: "Ahorros USD", currencyCode: "USD"),
        ]
        #expect(AmountCurrencyMenuLogic.target(for: "USD", selected: "Visa", accounts: conLinea) == "Visa · USD")
    }

    /// La cápsula solo ofrece monedas con cuentas: no se puede elegir una que deje el selector vacío.
    @Test func laCapsulaSoloOfreceMonedasConCuentas() {
        let opciones = AmountCurrencyMenuLogic.options(accounts: menu, current: "PEN").map(\.currencyCode)
        #expect(opciones == ["PEN", "USD"])
    }

    // MARK: - Cableado

    private static var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func code(_ relative: String) throws -> String {
        let source = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
        return source.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") }
            .joined(separator: " ")
    }

    /// El tramo de código desde `marker` hasta que se cierra el paréntesis que abre.
    private static func call(after marker: String, in code: String) throws -> String {
        let start = try #require(code.range(of: marker), "no está \(marker)")
        var depth = 0
        var end = code.endIndex
        for index in code[start.lowerBound...].indices {
            let char = code[index]
            if char == "(" { depth += 1 }
            if char == ")" {
                depth -= 1
                if depth == 0 {
                    end = code.index(after: index)
                    break
                }
            }
        }
        return String(code[start.lowerBound..<end])
    }

    @Test func nuevoRegistro_filtraPorLaMonedaDelMonto() throws {
        let code = try Self.code("Yala/App/Views/Transactions/NewTransactionView.swift")
        let gasto = try Self.call(after: "AccountSelectorSheet( selectedAccount: $viewModel.selectedAccount", in: code)
        #expect(gasto.contains("currencyScope: isBridgedCasoA ? nil : viewModel.amountCurrencyCode"))
        // Las transferencias eligen origen y destino en cualquier moneda.
        let origen = try Self.call(after: "AccountSelectorSheet( selectedAccount: $viewModel.sourceAccount", in: code)
        let destino = try Self.call(after: "AccountSelectorSheet( selectedAccount: $viewModel.destinationAccount", in: code)
        #expect(!origen.contains("currencyScope"))
        #expect(!destino.contains("currencyScope"))
        // Sin cuenta elegida la cápsula también abre: si no, con el filtro no habría forma de llegar a otra moneda.
        let capsula = try #require(code.range(of: "private var currencyCapsuleOptions: [AmountCurrencyOption] {"))
        let cuerpo = String(code[capsula.upperBound...].prefix(200))
        #expect(!cuerpo.contains("selectedAccount != nil"))
    }

    @Test func bandeja_filtraPorLaMonedaYAbreAMediaAltura() throws {
        let code = try Self.code("Yala/App/Views/Inbox/InboxDraftEditSheet.swift")
        let hoja = try Self.call(after: "AccountSelectorSheet(", in: code)
        #expect(hoja.contains("currencyScope: displayCurrencyCode"))
        #expect(hoja.contains("sizing: .mediumFirst"))
        // La cápsula del monto ofrece todas las monedas con cuenta, como en Nuevo registro: si no, filtrar dejaría el
        // borrador atrapado en la moneda de su cuenta.
        #expect(code.contains("AmountCurrencyMenuLogic.options("))
        #expect(code.contains("AmountCurrencyMenuLogic.target("))
    }

    /// El aviso de respaldo vive en la tabla de Nuevo registro (cuyo test exige la clave en los 16 idiomas) y lleva el
    /// hueco de la moneda.
    @Test func elAvisoDeRespaldoLlevaLaMoneda() throws {
        #expect(NuevoRegistroB1Text.allKeys.contains("accountSelector.noneInCurrency"))
        let url = Self.root.appendingPathComponent("Yala/Resources/es-419.lproj/NuevoRegistroB1.strings")
        let table = try #require(NSDictionary(contentsOf: url) as? [String: String])
        #expect(table["nr.accountSelector.noneInCurrency"] == "No tienes cuentas en %@. Estas son todas tus cuentas.")
    }
}
