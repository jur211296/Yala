//
//  CuentaSolaAlLeerPeticion.swift
//  Yala
//
//  Lo que la petición de la foto o del chat lleva de las cuentas para que la IA proponga una (segunda capa, decisión A + B
//  de Jürgen, 20-nov-2026). Solo el NOMBRE, la clase y la moneda de cada cuenta elegible y, si toca, sus reglas de captura
//  como texto. Nunca saldos ni números de cuenta: este tipo no tiene sitio para ellos, a propósito.
//
//  Qué viaja lo decide `Envio` (parte 2, decisiones de Jürgen del 21-nov):
//  - Foto: con la cuenta en la nube, nombres y reglas. En iCloud privado, también, pero solo con el permiso de voz y foto
//    aceptado en su versión que lo dice (`AIConsentRevision.processing`); con el anterior, nada (la foto sale como antes).
//  - Chat: nombres siempre (el permiso de Yala IA ya los promete) y reglas solo con la cuenta en la nube.
//

import Foundation

nonisolated enum CuentaSolaAlLeerPeticion {

    struct Cuenta: Equatable, Sendable {
        let name: String
        let kind: PaymentMethodAccountLogic.AccountKind
        let currencyCode: String
        /// Las reglas de captura de la cuenta, ya escritas como texto para la IA (vacío si no viajan).
        let rules: [String]

        init(name: String, kind: PaymentMethodAccountLogic.AccountKind, currencyCode: String, rules: [String] = []) {
            self.name = name
            self.kind = kind
            self.currencyCode = currencyCode
            self.rules = rules
        }
    }

    /// Qué sale del teléfono.
    enum Envio: Equatable, Sendable {
        case nada
        case nombres
        case nombresYReglas

        /// La foto: nube o permiso vigente → nombres y reglas; si no, nada.
        static func foto(isCloud: Bool, hasCurrentProcessingConsent: Bool) -> Envio {
            isCloud || hasCurrentProcessingConsent ? .nombresYReglas : .nada
        }

        /// El chat: nombres siempre; reglas, en la nube.
        static func chat(isCloud: Bool) -> Envio { isCloud ? .nombresYReglas : .nombres }
    }

    /// Tope de cuentas en la lista: más no ayuda a elegir y cada una se paga en tokens.
    static let maxCuentas = 40
    /// Tope de reglas por cuenta en la petición.
    static let maxReglas = 10

    /// Las cuentas que viajan según `envio`.
    static func cuentas(from candidates: [CuentaSolaAlLeer.Cuenta], envio: Envio) -> [Cuenta] {
        guard envio != .nada else { return [] }
        return candidates.prefix(maxCuentas).map { candidate in
            let rules = envio == .nombresYReglas ? candidate.rules.prefix(maxReglas).compactMap(reglaTexto) : []
            return Cuenta(name: candidate.name, kind: candidate.kind, currencyCode: candidate.currencyCode, rules: rules)
        }
    }

    /// Una regla como la lee la IA: «text contains "zip"», «merchant is "Uber"», «Apple Pay card "Interbank Visa"».
    static func reglaTexto(_ rule: AccountCaptureRule) -> String? {
        let value = AccountCaptureRule.cleaned(rule.value).replacingOccurrences(of: "\"", with: "'")
        guard !value.isEmpty else { return nil }
        switch rule.kind {
        case .applePayCard: return "Apple Pay card \"\(value)\""
        case .merchant: return "merchant is \"\(value)\""
        case .text: return rule.mode == .together ? "text contains \"\(value)\" (exact phrase)" : "text contains \"\(value)\""
        }
    }

    /// El bloque que se añade al mensaje de la foto o del chat, o `nil` sin cuentas.
    static func texto(_ cuentas: [Cuenta]) -> String? {
        let lines = cuentas.compactMap { cuenta -> String? in
            let name = cuenta.name.components(separatedBy: .newlines).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let base = "- \(name) | \(kindLabel(cuenta.kind)) | \(cuenta.currencyCode)"
            guard !cuenta.rules.isEmpty else { return base }
            return base + " | rules: " + cuenta.rules.joined(separator: "; ")
        }
        guard !lines.isEmpty else { return nil }
        let hasRules = cuentas.contains { !$0.rules.isEmpty }
        var header = ["The user's accounts (name | kind | currency). For \"account\", copy one name exactly or use null:"]
        if hasRules {
            header = ["The user's accounts (name | kind | currency | rules). A matching rule decides the account. For "
                + "\"account\", copy one name exactly or use null:"]
        }
        return (header + lines).joined(separator: "\n")
    }

    private static func kindLabel(_ kind: PaymentMethodAccountLogic.AccountKind) -> String {
        switch kind {
        case .cash: return "cash"
        case .creditCard: return "credit card"
        case .bank: return "bank account"
        case .other: return "other"
        }
    }
}
