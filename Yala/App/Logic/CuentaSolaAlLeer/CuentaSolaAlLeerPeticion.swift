//
//  CuentaSolaAlLeerPeticion.swift
//  Yala
//
//  Lo que la petición de la foto lleva de las cuentas para que la IA proponga una (segunda capa, decisión A + B de
//  Jürgen, 20-nov-2026). Solo el NOMBRE, la clase y la moneda de cada cuenta elegible. Nunca saldos, números de cuenta,
//  últimos 4 ni reglas: este tipo no tiene sitio para ellos, a propósito.
//
//  Solo con la cuenta en la nube (`CloudSyncFlags.storageMode == .cloud`): en iCloud privado el permiso de foto promete
//  que solo viaja la foto, así que ahí la lista va vacía y la petición sale como antes. Extenderlo al modo privado
//  necesita versionar ese permiso (decisión de Jürgen).
//

import Foundation

nonisolated enum CuentaSolaAlLeerPeticion {

    struct Cuenta: Equatable, Sendable {
        let name: String
        let kind: PaymentMethodAccountLogic.AccountKind
        let currencyCode: String
    }

    /// Tope de cuentas en la lista: más no ayuda a elegir y cada una se paga en tokens.
    static let maxCuentas = 40

    /// Las cuentas que viajan, o ninguna si la cuenta no está en la nube.
    static func cuentas(from candidates: [CuentaSolaAlLeer.Cuenta], isCloud: Bool) -> [Cuenta] {
        guard isCloud else { return [] }
        return candidates.prefix(maxCuentas).map { Cuenta(name: $0.name, kind: $0.kind, currencyCode: $0.currencyCode) }
    }

    /// El bloque que se añade al mensaje de la foto, o `nil` sin cuentas.
    static func texto(_ cuentas: [Cuenta]) -> String? {
        let lines = cuentas.compactMap { cuenta -> String? in
            let name = cuenta.name.components(separatedBy: .newlines).joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return "- \(name) | \(kindLabel(cuenta.kind)) | \(cuenta.currencyCode)"
        }
        guard !lines.isEmpty else { return nil }
        return (["The user's accounts (name | kind | currency). For \"account\", copy one name exactly or use null:"] + lines)
            .joined(separator: "\n")
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
