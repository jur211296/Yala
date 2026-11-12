//
//  AmountFilterTextLogic.swift
//  Yala
//
//  El campo de monto del filtro (Registros › Filtros y Exportar). Revisión 2.3, decisión 74 (9-nov): el marcador
//  sigue el formato de la persona —sus decimales y el separador de su región, el mismo que ponen los importes de la
//  app y el teclado decimal—, no un «0.00» fijo. Y lo escrito se lee con ese mismo separador: un marcador que dice
//  «0,00» y un «12,50» que filtraba por 12 (`Decimal(string:)` solo entiende el punto) se contradecían.
//

import Foundation

enum AmountFilterTextLogic {

    /// El cero con los decimales que la persona eligió en Personalización (`decimalPlaces`) y el separador de su
    /// región: «0.00», «0,00» o «0».
    static func placeholder(decimals: Int, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: 0) ?? "0"
    }

    /// Lo escrito, como número. Acepta el separador decimal de la región y también el punto (lo pegado de fuera);
    /// `nil` si no es un número.
    static func amount(from text: String, locale: Locale = .current) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let separator = locale.decimalSeparator ?? "."
        let normalized = separator == "." ? trimmed : trimmed.replacingOccurrences(of: separator, with: ".")
        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// El texto con que el campo vuelve a enseñar un monto ya aplicado: con el separador de la región y sin
    /// separador de miles, como lo habría escrito la persona.
    static func text(for amount: Decimal, locale: Locale = .current) -> String {
        let plain = NSDecimalNumber(decimal: amount).stringValue
        let separator = locale.decimalSeparator ?? "."
        return separator == "." ? plain : plain.replacingOccurrences(of: ".", with: separator)
    }
}
