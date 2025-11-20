//
//  CurrencyUtils.swift
//  Finaria
//
//  Utilidades para normalizar códigos de moneda
//  y convertir montos usando PEN como pivote.
//

import Foundation

/// Normaliza un código de moneda “sucio” a un código estándar de 3 letras.
/// Ejemplos:
/// - "S/", "s/.", "SOL", "soles" → "PEN"
/// - "$", "US$", "usd" → "USD"
/// - "€", "eur" → "EUR"
/// Si no se reconoce, devuelve la versión uppercased recortada a 3 letras cuando aplica.
func normalizeCurrencyCode(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        return "PEN"
    }
    
    let upper = trimmed.uppercased()
    
    switch upper {
    // Sol peruano
    case "PEN", "SOL", "SOLES", "S/", "S/.", "S/. ":
        return "PEN"
        
    // Dólar estadounidense
    case "USD", "US$", "US DOLLAR", "$", "$USD", "USD$":
        return "USD"
        
    // Euro
    case "EUR", "€", "EURO":
        return "EUR"
        
    default:
        // Intento de normalización genérica: tomar solo letras y quedarnos con 3
        let letters = upper.filter { $0.isLetter }
        if letters.count == 3 {
            return String(letters)
        } else if letters.count > 3 {
            let start = letters.startIndex
            let end = letters.index(start, offsetBy: 3)
            return String(letters[start..<end])
        } else {
            // Fallback a PEN para seguridad
            return "PEN"
        }
    }
}

/// Devuelve la tasa de conversión de una moneda a PEN.
/// - Importante: para FIN-21 las tasas son fijas:
///   - 1 PEN = 1.0
///   - 1 USD = 3.54 PEN
///   - 1 EUR = 3.89 PEN
func rateToPEN(_ rawCode: String) -> Decimal {
    let code = normalizeCurrencyCode(rawCode)
    
    switch code {
    case "PEN":
        return 1.0
    case "USD":
        return 3.54
    case "EUR":
        return 3.89
    default:
        // Moneda desconocida, asumimos 1 a 1 con PEN
        return 1.0
    }
}

/// Convierte un monto entre dos monedas usando PEN como pivote.
/// - Si from y to son iguales, se devuelve el monto original.
/// - Si from, to o la tasa no son válidos, se mantiene el valor original.
func convert(_ amount: Decimal, from rawFrom: String, to rawTo: String) -> Decimal {
    let fromCode = normalizeCurrencyCode(rawFrom)
    let toCode = normalizeCurrencyCode(rawTo)
    
    // Si es la misma moneda, no hay nada que hacer
    if fromCode == toCode {
        return amount
    }
    
    // Cantidad en PEN
    let fromRate = rateToPEN(fromCode)
    if fromRate == 0 {
        return amount
    }
    
    let amountInPEN = amount * fromRate
    
    // Si el destino es PEN, devolvemos directamente
    if toCode == "PEN" {
        return amountInPEN
    }
    
    // Convertir de PEN a la moneda objetivo
    let toRate = rateToPEN(toCode)
    if toRate == 0 {
        return amount
    }
    
    return amountInPEN / toRate
}
