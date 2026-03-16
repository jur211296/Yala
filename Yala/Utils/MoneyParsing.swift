//
//  MoneyParsing.swift
//  Yala
//
//  Utilidades para parsear montos monetarios desde texto a Decimal,
//  manejando símbolos de moneda, separadores y signos.
//

import Foundation

/// Parsea un monto monetario desde un String a Decimal.
/// - Reglas principales:
///   - Elimina símbolos de moneda comunes (S/, $, €, etc.).
///   - Soporta signo negativo como:
///     - Prefijo: "-123.45"
///     - Sufijo: "123.45-"
///     - Paréntesis: "(123.45)" → negativo
///   - Soporta formatos con punto o coma:
///     - "1,234.56"
///     - "1.234,56"
///     - "1234.56"
///     - "1234,56"
///   - Si el formato es inválido devuelve nil.
func parseDecimal(from raw: String) -> Decimal? {
    // 1. Normalizamos espacios
    var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Si está vacío no hay monto
    if text.isEmpty {
        return nil
    }
    
    // 2. Detectar negativo por paréntesis
    var isNegative = false
    
    if text.hasPrefix("("), text.hasSuffix(")") {
        isNegative = true
        text.removeFirst()
        text.removeLast()
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // 3. Detectar guiones como signo
    if text.hasPrefix("-") {
        isNegative.toggle()
        text.removeFirst()
    }
    
    if text.hasSuffix("-") {
        isNegative.toggle()
        text.removeLast()
    }
    
    // 4. Eliminar símbolos de moneda y otros caracteres no numéricos
    // Permitimos solo dígitos, punto, coma
    let allowedCharacters = CharacterSet(charactersIn: "0123456789.,")
    let filteredScalars = text.unicodeScalars.filter { allowedCharacters.contains($0) }
    var numericPart = String(String.UnicodeScalarView(filteredScalars))
    
    // Quitamos espacios intermedios
    numericPart = numericPart.replacing(" ", with: "")
    
    // Si después de filtrar no queda nada, es inválido
    if numericPart.isEmpty {
        return nil
    }
    
    // 5. Determinar separadores de miles y decimal
    let dotIndex = numericPart.lastIndex(of: ".")
    let commaIndex = numericPart.lastIndex(of: ",")
    
    var decimalSeparator: Character? = nil
    
    if let dot = dotIndex, let comma = commaIndex {
        // Hay punto y coma, tomamos el último que aparezca como separador decimal
        decimalSeparator = dot > comma ? "." : ","
    } else if dotIndex != nil {
        decimalSeparator = "."
    } else if commaIndex != nil {
        decimalSeparator = ","
    }
    
    // 6. Construir una cadena normalizada con "." como separador decimal
    var normalized = ""
    if let decimalSeparator = decimalSeparator {
        // Separador decimal identificado
        // Eliminamos todos los separadores que no sean el decimal
        let thousandsSeparators: [Character] = decimalSeparator == "." ? [","] : ["."]
        
        for char in numericPart {
            if thousandsSeparators.contains(char) {
                // Ignorar como separador de miles
                continue
            } else if char == decimalSeparator {
                normalized.append(".")
            } else {
                normalized.append(char)
            }
        }
    } else {
        // No hay separador decimal, solo dígitos y quizá separadores de miles inconsistentes
        // Eliminamos puntos y comas por seguridad
        normalized = numericPart.replacing(".", with: "")
        normalized = normalized.replacing(",", with: "")
    }
    
    // 7. Crear Decimal a partir de la cadena normalizada
    guard var decimal = Decimal(string: normalized) else {
        return nil
    }
    
    // 8. Aplicar signo
    if isNegative && decimal != 0 {
        decimal *= -1
    }
    
    return decimal
}
