//
//  ExchangeRate.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import Foundation
import SwiftData

// MARK: - ExchangeRate

@Model
final class ExchangeRate {
    // CloudKit: defaults required
    var dateKey: String = ""
    var base: String = "USD"
    var rates: Data = Data()
    /// Unix timestamp from the API response (when the rate was recorded)
    var timestamp: Date?

    // MARK: - Sync Identity (Modo Nube, I2)
    /// Identidad estable de sync. Opcional sin default (gotcha de UUID colapsado — ver
    /// `TransactionItem.syncID`). Poblado por `SyncIdentityService`.
    @Attribute(.preserveValueOnDeletion) var syncID: UUID?

    init(
        dateKey: String,
        base: String,
        rates: Data,
        timestamp: Date? = nil
    ) {
        self.dateKey = dateKey
        self.base = base
        self.rates = rates
        self.timestamp = timestamp
    }

    convenience init(
        dateKey: String,
        base: String,
        ratesDictionary: [String: Double],
        timestamp: Date? = nil
    ) throws {
        let data = try JSONEncoder().encode(ratesDictionary)
        self.init(dateKey: dateKey, base: base, rates: data, timestamp: timestamp)
    }

    /// Decodifica el blob `rates` tolerando sus DOS caras válidas: doubles nativos (escrituras
    /// locales/API) y STRINGS decimales escala-8 — una fila que hizo round-trip por el canal nube vuelve
    /// con strings porque el canon c1 proyecta todo número anidado de un blob como STRING JSON
    /// (`Canonc1Codec.canonicalizeBlobValue`) y el apply re-serializa el wire verbatim
    /// (`EntityApplyMap.exchangeRate` → `WireValueDecoder.jsonData`). NUNCA volver al decode estricto
    /// `[String: Double]` (pierde TODAS las tasas de la fecha, bug device 2026-07-18) ni "arreglarlo"
    /// normalizando strings→Double en el apply: ambas caras proyectan la MISMA emisión canónica (los
    /// strings pasan verbatim, los doubles se formatean a escala-8 — invariante pinneado en
    /// `Canonc1CodecTests`), así que leer tolerante no toca el Merkle; re-escribir el blob en el apply
    /// sí arriesga el roundtrip parse/format (divergencia clase-FX).
    func decodedRates() -> [String: Double] {
        guard !rates.isEmpty else { return [:] }
        do {
            guard let dict = try JSONSerialization.jsonObject(with: rates) as? [String: Any] else {
                #if DEBUG
                print("ExchangeRate: rates de \(dateKey) no es un objeto JSON")
                #endif
                return [:]
            }
            var result: [String: Double] = [:]
            result.reserveCapacity(dict.count)
            for (code, value) in dict {
                if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
                    result[code] = number.doubleValue
                } else if let string = value as? String, let parsed = Double(string), parsed.isFinite {
                    result[code] = parsed
                }
                // Otro tipo (bool/null/anidado) → se omite SOLO esa key; el resto de tasas sobrevive
                // (el decode estricto tumbaba la fecha entera al primer tropiezo).
            }
            return result
        } catch {
            #if DEBUG
            print("ExchangeRate: Error decoding rates for \(dateKey): \(error)")
            #endif
            return [:]
        }
    }
}
