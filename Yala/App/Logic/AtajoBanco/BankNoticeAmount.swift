//
//  BankNoticeAmount.swift
//  Yala
//
//  Lee un importe tal como lo escribe un aviso del banco en Perú: «S/ 12.50», «S/.1,234.50», «S/ 45,90», «US$ 12.00»,
//  «USD 12», «$ 9.99». Pura, para los tests.
//
//  El separador decimal se decide por la forma, no por el idioma del teléfono: el último `.` o `,` seguido de uno o dos
//  dígitos al final es el decimal; cualquier otro separa miles. «1,234» son mil doscientos treinta y cuatro; «45,90»,
//  cuarenta y cinco con noventa.
//

import Foundation

nonisolated enum BankNoticeAmount {

    /// La moneda de un símbolo o código. `nil` en `code` y el símbolo en `ambiguous` si no se sabe (`$`).
    static func currency(of token: String) -> (code: String?, ambiguous: String?) {
        let normalized = token.uppercased().replacingOccurrences(of: " ", with: "")
        switch normalized {
        case "S/", "S/.", "PEN", "S./": return ("PEN", nil)
        case "US$", "USD", "U$S", "$US": return ("USD", nil)
        case "$": return (nil, "$")
        default: return (nil, nil)
        }
    }

    /// El importe de un texto de dígitos con separadores, en positivo. `nil` si no es un número o es cero.
    static func decimal(from raw: String) -> Decimal? {
        let digitsAndSeparators = raw.filter { $0.isNumber || $0 == "." || $0 == "," }
        guard !digitsAndSeparators.isEmpty, digitsAndSeparators.contains(where: \.isNumber) else { return nil }
        var integerPart = digitsAndSeparators
        var fractionPart = ""
        if let lastSeparator = digitsAndSeparators.lastIndex(where: { $0 == "." || $0 == "," }) {
            let after = digitsAndSeparators[digitsAndSeparators.index(after: lastSeparator)...]
            if (1...2).contains(after.count), after.allSatisfy(\.isNumber) {
                integerPart = String(digitsAndSeparators[..<lastSeparator])
                fractionPart = String(after)
            }
        }
        let integerDigits = integerPart.filter(\.isNumber)
        guard !integerDigits.isEmpty || !fractionPart.isEmpty else { return nil }
        let literal = (integerDigits.isEmpty ? "0" : integerDigits) + (fractionPart.isEmpty ? "" : "." + fractionPart)
        guard let value = Decimal(string: literal, locale: Locale(identifier: "en_US_POSIX")), value > 0 else { return nil }
        return value
    }

    /// Los importes que aparecen escritos en el texto, para comprobar lo que devuelve el modelo del iPhone: un importe
    /// que no está en el aviso no se acepta.
    static func amountsWritten(in text: String) -> Set<Decimal> {
        var found = Set<Decimal>()
        let pattern = #"\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?"#
        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern)
        } catch {
            #if DEBUG
            print("BankNoticeAmount: Error: \(error)")
            #endif
            return found
        }
        let range = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: range) {
            guard let swiftRange = Range(match.range, in: text), let value = decimal(from: String(text[swiftRange])) else {
                continue
            }
            found.insert(value)
        }
        return found
    }
}
