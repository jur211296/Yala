//
//  WireValueDecoder.swift
//  Yala
//
//  Decodificación PURA del valor de wire de UNA columna del pull (Modo Nube, incremento I8f-1). Es el
//  inverso del `Canonc1Codec.encode` para el camino de bajada: el JSON crudo que devuelve PostgREST
//  (`select=*`) → el tipo Swift que el `@Model` espera (`EntityApplyMap`). `nonisolated` + `Sendable`:
//  no toca el actor ni SwiftData (recibe/produce escalares), así queda testeable con vectores literales.
//
//  Contrato de wire (§d.6 + notas DIFERIDOS): el pull NO castea a `::text`, así que los valores llegan
//  con la forma NATIVA de PostgREST y el decoder DEBE tolerar las dos caras de cada tipo:
//   - **money/rate**: STRING decimal (`"12.5000"`) O número JSON (`12.5`) — `wireDouble` acepta ambos.
//   - **timestamptz**: texto ISO de PostgREST — puede traer `+00:00` en vez de `Z` y microsegundos →
//     `millisFromISO` normaliza (aritmética entera, FLOOR sub-ms, nunca `DateFormatter`/locale; D-2c).
//   - **uuid[]**: array JSON o `null` (ambos = "sin filtro" — NULL ≡ `'{}'`, DIFERIDOS #25).
//   - **boolean**: bool JSON. **int**: número JSON. **text**: string. **jsonb** (`rates`): objeto JSON.
//

import Foundation

// MARK: - WireValue

/// Árbol JSON tipado de un valor de wire. La distinción `bool` vs `number` (que `JSONSerialization`
/// colapsa a `NSNumber`) se preserva decodificando con `JSONDecoder` (prueba `Bool` antes que numérico).
/// `Equatable` para los tests; `Sendable`/`nonisolated` para cruzar sin actor.
nonisolated enum WireValue: Sendable, Equatable, Decodable, Encodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([WireValue])
    case object([String: WireValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            // Bool ANTES que numérico: `decode(Bool)` solo casa `true`/`false` (un número JSON lanza
            // typeMismatch), y `decode(Double)` sobre `true` también lanza → sin ambigüedad.
            self = .bool(b)
        } else if let d = try? container.decode(Double.self) {
            self = .number(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let arr = try? container.decode([WireValue].self) {
            self = .array(arr)
        } else if let obj = try? container.decode([String: WireValue].self) {
            self = .object(obj)
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "WireValue no reconocido")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .number(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .array(let a): try container.encode(a)
        case .object(let o): try container.encode(o)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - WireValueDecoder (accessores tipados + parse de tiempo)

/// Helpers puros para leer un `WireValue` como el tipo Swift esperado. Toda ausencia/incompatibilidad →
/// `nil` (el applier decide si eso significa "no tocar" o "poner a NULL" según la columna, §d.1).
nonisolated enum WireValueDecoder {

    /// `Double` de una columna money/rate: acepta STRING decimal (`"12.5000"`) o número JSON (`12.5`).
    /// `null`/otro → `nil`.
    static func double(_ value: WireValue) -> Double? {
        switch value {
        case .number(let d): return d
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    /// `Int` de una columna entera (`sort_order`/…): número JSON (truncado) o string decimal. `null` → `nil`.
    static func int(_ value: WireValue) -> Int? {
        switch value {
        case .number(let d): return Int(d)
        case .string(let s): return Int(s) ?? Double(s).map(Int.init)
        default: return nil
        }
    }

    /// `Bool` tri-estado de una columna booleana. Solo `.bool` → valor; el resto → `nil` ("no aplicar").
    static func bool(_ value: WireValue) -> Bool? {
        if case .bool(let b) = value { return b }
        return nil
    }

    /// `String` de una columna de texto. `null`/otro → `nil`.
    static func string(_ value: WireValue) -> String? {
        if case .string(let s) = value { return s }
        return nil
    }

    /// `UUID` de una columna FK/`uuid`. `null`/malformada → `nil`.
    static func uuid(_ value: WireValue) -> UUID? {
        guard case .string(let s) = value else { return nil }
        return UUID(uuidString: s)
    }

    /// `[UUID]` de una columna `uuid[]`. `null` → `nil` ("sin filtro"); array → los UUIDs válidos
    /// (tokens malformados se descartan). Un array vacío → `[]` (distinto de `nil`, aunque para las M2M
    /// mirror el applier los trata igual: sin filtro).
    static func uuidArray(_ value: WireValue) -> [UUID]? {
        switch value {
        case .null: return nil
        case .array(let items):
            return items.compactMap { item -> UUID? in
                if case .string(let s) = item { return UUID(uuidString: s) }
                return nil
            }
        default: return nil
        }
    }

    /// `[String]` de una columna `text[]` (llega como array JSON de strings). `null`/otro → `nil`.
    static func stringArray(_ value: WireValue) -> [String]? {
        switch value {
        case .array(let items):
            return items.compactMap { if case .string(let s) = $0 { return s } else { return nil } }
        default: return nil
        }
    }

    /// `Date` de una columna `timestamptz` (texto ISO de PostgREST). `null`/malformada → `nil`.
    static func date(_ value: WireValue) -> Date? {
        guard case .string(let s) = value, let ms = millisFromISO(s) else { return nil }
        return Date(timeIntervalSince1970: Double(ms) / 1000.0)
    }

    /// `Data` (JSON re-serializado) de una columna `jsonb` (`rates`). Objeto → sus bytes canónicos
    /// (keys ordenadas). `null`/otro → `nil`.
    static func jsonData(_ value: WireValue) -> Data? {
        switch value {
        case .null: return nil
        case .object, .array:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            do {
                return try encoder.encode(value)
            } catch {
                #if DEBUG
                print("WireValueDecoder.jsonData: encode falló (columna jsonb no aplicada): \(error)")
                #endif
                return nil
            }
        default: return nil
        }
    }

    // MARK: - Parse inverso ISO → ms Unix (D-2c)

    /// Convierte un timestamp ISO-8601 a ms Unix, aritmética ENTERA (inverso de `canonicalIsoMillis`).
    /// Tolerante a las variantes de PostgREST: `YYYY-MM-DDTHH:mm:ss[.f+][Z|±HH:MM|±HHMM|±HH]` (y `' '`
    /// como separador de fecha/hora). Sub-ms se TRUNCAN (FLOOR para instantes ≥ epoch). Reusa
    /// `CanonicalTime.daysFromCivil` (mismo algoritmo civil que el formateo canónico) → round-trippea
    /// `ms → canonicalIsoMillis → millisFromISO`. NUNCA `DateFormatter`/`TimeZone` (sensibles a locale).
    static func millisFromISO(_ string: String) -> Int64? {
        let s = Array(string.unicodeScalars)
        guard s.count >= 19 else { return nil }

        func digits(_ start: Int, _ count: Int) -> Int64? {
            var r: Int64 = 0
            for i in 0..<count {
                let v = s[start + i].value
                guard v >= 48 && v <= 57 else { return nil }
                r = r * 10 + Int64(v - 48)
            }
            return r
        }

        // Separadores de posición fija. El char 10 puede ser 'T' o ' ' (PostgREST usa 'T' por header
        // Accept, pero somos tolerantes).
        let sepDate = s[10]
        guard s[4] == "-", s[7] == "-",
              sepDate == Unicode.Scalar(84) /* T */ || sepDate == Unicode.Scalar(32) /* space */,
              s[13] == ":", s[16] == ":" else { return nil }

        guard let year = digits(0, 4), let month = digits(5, 2), let day = digits(8, 2),
              let hour = digits(11, 2), let minute = digits(14, 2), let second = digits(17, 2) else {
            return nil
        }
        guard year >= 1, month >= 1, month <= 12, day >= 1, day <= 31,
              hour <= 23, minute <= 59, second <= 59 else { return nil }

        var idx = 19
        var millis: Int64 = 0

        // Fracción de segundo opcional: tomar los 3 primeros dígitos (FLOOR sub-ms), pad con ceros.
        if idx < s.count && s[idx] == Unicode.Scalar(46) /* . */ {
            idx += 1
            var frac: [Int64] = []
            while idx < s.count {
                let v = s[idx].value
                if v >= 48 && v <= 57 { frac.append(Int64(v - 48)); idx += 1 } else { break }
            }
            guard !frac.isEmpty else { return nil }  // '.' sin dígitos = malformado
            for k in 0..<3 { millis = millis * 10 + (k < frac.count ? frac[k] : 0) }
        }

        // Zona horaria opcional: Z | ±HH[:MM] | ±HHMM | ±HH. Ausente → UTC (0).
        var offsetMinutes: Int64 = 0
        if idx < s.count {
            let c = s[idx]
            if c == Unicode.Scalar(90) /* Z */ || c == Unicode.Scalar(122) /* z */ {
                idx += 1
            } else if c == Unicode.Scalar(43) /* + */ || c == Unicode.Scalar(45) /* - */ {
                let sign: Int64 = (c == Unicode.Scalar(45)) ? -1 : 1
                idx += 1
                guard idx + 1 < s.count, let oh = digits(idx, 2) else { return nil }
                idx += 2
                var om: Int64 = 0
                if idx < s.count && s[idx] == Unicode.Scalar(58) /* : */ { idx += 1 }
                if idx + 1 < s.count, let m = digits(idx, 2) { om = m }
                offsetMinutes = sign * (oh * 60 + om)
            }
            // Cualquier cola no reconocida se ignora (tolerancia defensiva).
        }

        let days = CanonicalTime.daysFromCivil(year: year, month: month, day: day)
        let localMs = (days * 86_400 + hour * 3_600 + minute * 60 + second) * 1_000 + millis
        return localMs - offsetMinutes * 60 * 1_000
    }
}
