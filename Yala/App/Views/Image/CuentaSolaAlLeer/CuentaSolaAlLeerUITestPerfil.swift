//
//  CuentaSolaAlLeerUITestPerfil.swift
//  Yala
//
//  Perfiles de `-uitest-image-result` para la cuenta elegida sola al leer una foto. Devuelven SOLO lo que diría la IA
//  (medio de pago y, con la capa B, la cuenta que cree): la cuenta la elige la escalera de producción
//  (`VisionDraftFactory` → `DraftBuilder.chooseAccount`). No pasan por `UITestDemoAccountLogic`, que rellena la cuenta a
//  mano: con él la prueba saldría verde sin la escalera.
//
//  - `cuenta-sola`: el medio de pago es el nombre de la tarjeta de crédito de la semilla → «✦» y la línea de «por qué».
//  - `cuenta-sola-varias`: «Visa» con dos cuentas que lo llevan (las crea el perfil) → «Elige cuenta · 2 coinciden».
//  - `cuenta-sola-sugerida`: lo mismo y la IA propone una de las dos → «sugerida».
//  - `cuenta-sola-choque`: la imagen nombra la tarjeta y la IA otra cuenta escrita en el mismo medio de pago → choque.
//  - Parte 2 (reglas, 2026-11-21), con las cuentas «Zip» y «Zip Visa» que crea el perfil y el medio de pago «Zip»:
//    `cuenta-sola-zip` sin reglas (elige «Zip» por nombre); `cuenta-sola-regla` con la regla «zip» en «Zip Visa» (va a
//    «Zip Visa» aunque exista «Zip»); `cuenta-sola-reglas-choque` con «zip» en las dos (no elige).
//

#if DEBUG
import Foundation
import SwiftData

@MainActor
enum CuentaSolaAlLeerUITestPerfil {

    static func handles(_ perfil: String) -> Bool { perfil.hasPrefix("cuenta-sola") }

    /// Las dos cuentas que llevan «Visa». Nombres de marca: iguales en todos los idiomas.
    static let visaNames = ["BCP Visa", "Interbank Visa"]
    /// Las dos cuentas de los perfiles de reglas.
    static let zipNames = ["Zip", "Zip Visa"]

    /// Lo que la IA devolvería para el perfil: el medio de pago y la cuenta que cree.
    static func lectura(_ perfil: String, context: ModelContext) -> (payment: String?, account: String?) {
        let accounts = DraftBuilder.fetchActiveAccounts(context: context).filter { !$0.isSystemAccount }
        let credit = accounts.first { $0.type == AccountType.creditCard.rawValue }?.name
        let checking = accounts.first { $0.type == AccountType.checking.rawValue }?.name
        switch perfil {
        case "cuenta-sola-varias":
            ensureVisaAccounts(context: context, existing: accounts)
            return ("Visa", nil)
        case "cuenta-sola-sugerida":
            ensureVisaAccounts(context: context, existing: accounts)
            return ("Visa", visaNames[1])
        case "cuenta-sola-zip":
            ensureAccounts(zipNames, context: context, existing: accounts, rules: [:])
            return ("Zip", nil)
        case "cuenta-sola-regla":
            ensureAccounts(zipNames, context: context, existing: accounts, rules: ["Zip Visa": "zip"])
            return ("Zip", nil)
        case "cuenta-sola-reglas-choque":
            ensureAccounts(zipNames, context: context, existing: accounts, rules: ["Zip": "zip", "Zip Visa": "zip"])
            return ("Zip", nil)
        case "cuenta-sola-choque":
            // Con los dos nombres escritos, el teléfono elige el más largo; la IA dice el otro.
            let both = [credit, checking].compactMap { $0 }
            let shorter = both.min { $0.count < $1.count }
            return (both.joined(separator: " · "), shorter)
        default:
            return (credit, nil)
        }
    }

    /// Crea las dos cuentas «Visa» en la divisa principal de la semilla si no están.
    private static func ensureVisaAccounts(context: ModelContext, existing: [Account]) {
        ensureAccounts(visaNames, context: context, existing: existing, rules: [:])
    }

    /// Crea las cuentas que faltan (tarjetas de crédito en la divisa principal de la semilla) y les pone una regla «El
    /// texto dice» con el valor de `rules`.
    private static func ensureAccounts(
        _ names: [String], context: ModelContext, existing: [Account], rules: [String: String]
    ) {
        let currency = existing.first { $0.type == AccountType.checking.rawValue }?.currencyCode ?? "PEN"
        for name in names {
            let account = existing.first(where: { $0.name == name }) ?? {
                let made = Account(
                    name: name, currencyCode: currency, colorHex: "#1F3A93", iconName: "creditcard.fill",
                    type: AccountType.creditCard.rawValue)
                context.insert(made)
                return made
            }()
            if let value = rules[name] {
                CuentaSolaReglasStore.setRules([AccountCaptureRule(kind: .text, value: value)], on: account)
            }
        }
        do {
            try context.save()
        } catch {
            print("CuentaSolaAlLeerUITestPerfil: Error: \(error)")
        }
    }

    /// `-uitest-capture-rule "Cuenta|kind|valor"` (kind: `text`, `merchant` o `applePay`): una regla en esa cuenta.
    static func applyCaptureRuleArgument(context: ModelContext, arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard let index = arguments.firstIndex(of: "-uitest-capture-rule"), index + 1 < arguments.count else { return }
        let parts = arguments[index + 1].components(separatedBy: "|")
        guard parts.count == 3, let kind = AccountCaptureRule.Kind(rawValue: parts[1]) else { return }
        let accounts = DraftBuilder.fetchActiveAccounts(context: context)
        guard let account = accounts.first(where: { $0.name == parts[0] }) else { return }
        CuentaSolaReglasStore.setRules([AccountCaptureRule(kind: kind, value: parts[2])], on: account)
        do {
            try context.save()
        } catch {
            print("CuentaSolaAlLeerUITestPerfil: Error: \(error)")
        }
    }
}
#endif
