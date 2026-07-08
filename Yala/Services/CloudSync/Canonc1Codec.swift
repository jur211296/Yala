//
//  Canonc1Codec.swift
//  Yala
//
//  Codec canónico c1 del cable de Modo Nube (incremento I8a). Proyecta un `[String: CanonValue]`
//  (columna Postgres snake_case → valor tipado) al STRING canónico c1 EXACTO — el mismo byte a byte
//  que producirán los 4 codecs (Swift cliente-autor · TS web · Kotlin Android · re-serializador del
//  Worker). Es la base del leaf del Merkle: un byte de divergencia rompe la verificación cross-plataforma.
//  `canon_version="c1"` es INMUTABLE (§d.7, bloque S2): una regla NUNCA se muta; un canon nuevo = `c2`
//  paralelo. Pure-logic, `nonisolated`, sin dependencias de plataforma (Calendar/DateFormatter/Locale).
//
//  REGLAS POR-TIPO (§d.1 + §d.7 bloque S2, sub-decisiones O1–O10):
//  - Objeto JSON de UN nivel; keys = columna Postgres snake_case, ordenadas por BYTES UTF-8 ascendentes
//    (no scalars Unicode, no collation). JCS-restringido: sin espacios, UTF-8 sin BOM, sin trailing newline.
//  - Dinero/tasa (`Double`→NUMERIC): decimal string escala-FIJA (dinero=4, tasa=8) HALF_EVEN desde el
//    binario EXACTO del Double, notación plana, `-0.0`→`"0.0000"`, va como STRING JSON. NaN/±Inf → THROW
//    (`.nonFiniteNumber`); |dinero|≥10¹⁴ o |tasa|≥10¹⁰ → THROW (`.numericOutOfRange`).
//  - Fecha (`Date`→TIMESTAMPTZ): `canonicalIsoMillis(physicalMillis(from:))` de `CanonicalTime` (I1, reutilizado).
//  - `local_day`: `YYYY-MM-DD` = los 10 primeros chars de esa misma T-CANON.
//  - UUID/FK: 36 chars lowercase. `UUID[]`: array lowercase ordenado por bytes UTF-8, dedup; vacío → OMITIR key.
//  - `Bool?`: `true`/`false`/`null` literal. NULL explícito (`.null`/`.bool(nil)`) → `key:null`; ausencia → sin key.
//  - Blob Data-JSON: parsea y re-canonicaliza recursivamente (keys por bytes UTF-8; números anidados = regla
//    de tasa escala-8 como STRING JSON; ver `canonicalizeBlobValue`).
//  - Columnas server-authored NUNCA son keys (llegar → THROW `.serverAuthoredKey`).
//
//  MÉTODO HALF_EVEN (decisión de implementación, resuelve un conflicto task↔spec):
//  el redondeo NO usa `Decimal(Double)`/`NSDecimalNumberHandler(.bankers)`. Verificado empíricamente que
//  `Decimal(Double)` es INEXACTO e inconsistente (`Decimal(19.99)`=19.98999999999999488 truncado a ~20
//  dígitos, `Decimal(0.1)`=0.1 acortado) → divergiría de `BigDecimal(double)` (Java, exacto-desde-binario)
//  y rompería el Merkle. `.bankers` SÍ es HALF_EVEN pero redondea sobre el STRING decimal, no el binario
//  (p.ej. `.bankers` de "0.00005" a escala 4 = 0.0000, mientras el DOUBLE 0.00005 = 0.0000500…01 > ½ →
//  0.0001). La spec (§d.7) prohíbe `Decimal(Double)` y exige la "ruta big-decimal exacto-desde-binario":
//  aquí se descompone el Double en (mantisa entera M, exponente binario E) — valor = M·2^E EXACTO — y se
//  redondea la razón M·10^S / 2^-E con aritmética entera/`BigUInt`. Reproduce los ejemplos de la propia
//  spec (`0.12345`→`0.1235` arriba, `0.12355`→`0.1235` par).
//

import Foundation

/// Errores tipados del codec c1. El CONSUMIDOR (I8c/`CloudSyncEngine`) mapea a los canarios de telemetría:
/// `.nonFiniteNumber` → `cloudSyncNonFiniteRejected`; `.numericOutOfRange` → `cloudSyncNumericOutOfRange`.
/// (El codec es pure-logic `nonisolated`; no dispara telemetría por sí mismo — ver patrón `AttestSyncGate`.)
/// El fuera-de-rango del AÑO de una fecha propaga `CanonicalTimeError.yearOutOfRange` (I1, reutilizado).
nonisolated enum Canonc1Error: Error, Equatable {
    /// Un `Double` de dinero/tasa era NaN o ±Inf. Canario del consumidor: `cloudSyncNonFiniteRejected`.
    case nonFiniteNumber
    /// |dinero|≥10¹⁴ o |tasa|≥10¹⁰ (fuera del rango exacto <2⁵³). Canario: `cloudSyncNumericOutOfRange`.
    case numericOutOfRange(scale: Int)
    /// Una columna server-authored (`updated_at`/`server_seq`/`hlc`/`deleted_hlc`/`schema_version`/`user_id`)
    /// llegó como key del mapa. Defensa: nunca deben viajar en `fields`.
    case serverAuthoredKey(String)
    /// Un blob `.dataJSON` no era JSON válido (o contenía un tipo no serializable).
    case malformedBlobJSON(String)
}

/// Codec canónico c1. `nonisolated` puro: sin estado, sin actor, determinista.
nonisolated enum Canonc1Codec {

    // MARK: - Constantes de regla

    /// Escala decimal fija del dinero (§d.7 O1).
    static let moneyScale = 4
    /// Escala decimal fija de la tasa (§d.7 O4).
    static let rateScale = 8

    /// Columnas server-authored + identidad-de-servidor que NUNCA son leaves del Canal 1 (§d.7). Si alguna
    /// llega como key del `fields`, es un bug del emisor → THROW en vez de contaminar el hash.
    static let serverAuthoredKeys: Set<String> = [
        "updated_at", "server_seq", "hlc", "deleted_hlc", "schema_version", "user_id",
    ]

    // MARK: - Entrada pública

    /// Serializa un mapa columna→valor al string canónico c1 EXACTO.
    /// - Parameter fields: columna Postgres snake_case → `CanonValue`. Solo columnas TOCADAS (PATCH parcial).
    /// - Returns: objeto JSON de un nivel, JCS-restringido, keys ordenadas por bytes UTF-8.
    /// - Throws: `Canonc1Error` (número no-finito / fuera de rango / key server-authored / blob malformado)
    ///           o `CanonicalTimeError.yearOutOfRange` (año de fecha fuera de 0001..9999).
    static func encode(_ fields: [String: CanonValue]) throws -> String {
        // Defensa: ninguna columna server-authored puede viajar como leaf.
        for key in fields.keys where serverAuthoredKeys.contains(key) {
            throw Canonc1Error.serverAuthoredKey(key)
        }

        // Orden canónico de keys por BYTES UTF-8 ascendentes (no scalars, no collation).
        let sortedKeys = fields.keys.sorted(by: utf8BytesLess)

        var entries: [String] = []
        entries.reserveCapacity(sortedKeys.count)
        for key in sortedKeys {
            // `encodeValue` devuelve `nil` SOLO para el caso "OMITIR la key" (`.uuidArray` vacío).
            guard let valueString = try encodeValue(fields[key]!) else { continue }
            entries.append(encodeJSONString(key) + ":" + valueString)
        }
        return "{" + entries.joined(separator: ",") + "}"
    }

    // MARK: - Encoder por valor

    /// Serializa un `CanonValue` a su fragmento JSON canónico, o `nil` si la key debe OMITIRSE.
    static func encodeValue(_ value: CanonValue) throws -> String? {
        switch value {
        case .money(let d):
            return encodeJSONString(try decimalFixed(d, scale: moneyScale))
        case .rate(let d):
            return encodeJSONString(try decimalFixed(d, scale: rateScale))
        case .timestamp(let date):
            let ms = CanonicalTime.physicalMillis(from: date)
            return encodeJSONString(try CanonicalTime.canonicalIsoMillis(ms))
        case .localDay(let date):
            // El día civil = los 10 primeros chars (`YYYY-MM-DD`) de la MISMA T-CANON. La Date llega
            // posicionada por I8c a medianoche UTC desde los componentes del picker (la regla de derivación
            // {picker_components}→local_day vive en I8c; aquí solo se formatea determinísticamente).
            let ms = CanonicalTime.physicalMillis(from: date)
            let canonical = try CanonicalTime.canonicalIsoMillis(ms)
            return encodeJSONString(String(canonical.prefix(10)))
        case .uuid(let id):
            return encodeJSONString(id.uuidString.lowercased())
        case .uuidArray(let ids):
            if ids.isEmpty { return nil }  // vacío → OMITIR la key entera (sin-filtro ≠ null ≠ [])
            let lowered = ids.map { $0.uuidString.lowercased() }
            // Ordena por bytes UTF-8 ascendentes y deduplica (adyacentes tras ordenar).
            let sorted = lowered.sorted(by: utf8BytesLess)
            var deduped: [String] = []
            deduped.reserveCapacity(sorted.count)
            for s in sorted where deduped.last != s { deduped.append(s) }
            return "[" + deduped.map(encodeJSONString).joined(separator: ",") + "]"
        case .string(let s):
            return encodeJSONString(s)
        case .bool(let b):
            switch b {
            case .some(true): return "true"
            case .some(false): return "false"
            case .none: return "null"
            }
        case .int(let n):
            return String(n)
        case .dataJSON(let data):
            return try canonicalizeBlob(data)
        case .null:
            return "null"
        }
    }

    // MARK: - Números: HALF_EVEN escala-fija desde el binario EXACTO del Double

    /// Decimal string de escala fija `S` con redondeo HALF_EVEN sobre el VALOR BINARIO EXACTO del Double.
    /// Notación plana, exactamente `S` decimales, `-0.0`→`"0.0000"`, sin ceros a la izquierda.
    /// - Throws: `.nonFiniteNumber` (NaN/±Inf), `.numericOutOfRange` (|v|≥10¹⁴ dinero / ≥10¹⁰ tasa).
    static func decimalFixed(_ x: Double, scale S: Int) throws -> String {
        guard x.isFinite else { throw Canonc1Error.nonFiniteNumber }
        // Límite congelado (owner 2026-07-05): dinero |v|<10¹⁴, tasa |v|<10¹⁰ (mantiene todo <2⁵³ = exacto).
        let limit = (S == moneyScale) ? 1e14 : 1e10
        guard x.magnitude < limit else { throw Canonc1Error.numericOutOfRange(scale: S) }

        let negative = x.sign == .minus
        let magnitude = x.magnitude

        // Descompone el Double en (M, E) tal que magnitude = M · 2^E EXACTO (M entero de ≤53 bits).
        // bits IEEE-754 binary64: [signo:1][exponente:11][fracción:52].
        let bits = magnitude.bitPattern
        let exponentBits = Int((bits >> 52) & 0x7FF)
        let fractionBits = bits & 0x000F_FFFF_FFFF_FFFF
        let mantissa: UInt64
        let exponent: Int
        if exponentBits == 0 {
            // Subnormal (o cero): sin bit implícito; el exponente sesgado mínimo es 1 → E = 1 - 1023 - 52.
            mantissa = fractionBits
            exponent = -1074
        } else {
            // Normal: bit implícito 1.frac; valor = (2⁵² | frac) · 2^(exp - 1023 - 52).
            mantissa = fractionBits | (1 << 52)
            exponent = exponentBits - 1075
        }

        // q = round_half_even(magnitude · 10^S) como entero. Cabe en UInt64 para todo v en rango
        // (v·10^S < 10¹⁸ < 2⁶³). El intermedio N = M · 10^S puede exceder 64 bits → BigUInt.
        let pow10: UInt64 = (S == moneyScale) ? 10_000 : 100_000_000
        let scaled = BigUInt(mantissa).multiplied(by: pow10)

        let q: UInt64
        if exponent >= 0 {
            // magnitude·10^S = scaled · 2^E (entero exacto). Inalcanzable para v en rango (E≥0 ⇒ |v|≥2⁵² >
            // 10¹⁴), pero defensivo.
            q = scaled.lowUInt64(shiftedLeftBy: exponent)
        } else {
            // magnitude·10^S = scaled / 2^k. Redondeo HALF_EVEN entero: mira el bit "mitad" (k-1) y si hay
            // cualquier bit por debajo.
            let k = -exponent
            var quotient = scaled.lowUInt64(shiftedRightBy: k)
            let halfBit = scaled.bit(k - 1)
            let anyBelowHalf = scaled.anyBitSetBelow(k - 1)
            if halfBit {
                if anyBelowHalf {
                    quotient += 1                    // resto > mitad → arriba
                } else if quotient % 2 == 1 {
                    quotient += 1                    // resto == mitad exacta → al PAR
                }
            }                                        // resto < mitad → se queda
            q = quotient
        }

        let integerPart = q / pow10
        let fractionPart = q % pow10
        var fractionString = String(fractionPart)
        if fractionString.count < S {
            fractionString = String(repeating: "0", count: S - fractionString.count) + fractionString
        }
        // Signo solo si el resultado redondeado es no-cero (−0.0 y colas negativas → sin signo).
        let sign = (negative && q != 0) ? "-" : ""
        return sign + String(integerPart) + "." + fractionString
    }

    // MARK: - Blobs Data-JSON (recursivo)

    /// Re-canonicaliza un blob `Data`-JSON (nunca los bytes crudos ni base64): keys por bytes UTF-8, números
    /// anidados = regla de TASA (escala 8) como STRING JSON, strings con escape RFC-8785, arrays en orden.
    /// v1: el único blob del manifest con números es `rates` (tasas de cambio) → tratar TODO número anidado
    /// como tasa escala-8 es correcto y determinista. Un blob futuro con enteros semánticos o dinero
    /// (escala 4) necesitaría su propia regla (documentado — límite consciente de v1).
    static func canonicalizeBlob(_ data: Data) throws -> String {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw Canonc1Error.malformedBlobJSON("JSON inválido: \(error)")
        }
        return try canonicalizeBlobValue(object)
    }

    /// Canonicaliza un valor ya parseado de un blob (recursivo).
    static func canonicalizeBlobValue(_ value: Any) throws -> String {
        if value is NSNull { return "null" }
        if let number = value as? NSNumber {
            // `NSNumber` colapsa Bool y número: distinguir el booleano por su CFTypeID.
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            // Todo número anidado se canonicaliza con la regla de TASA (escala 8) como STRING JSON.
            // Caveat: `doubleValue` de un entero JSON grande puede perder precisión; las tasas de v1
            // son pequeñas, no ocurre en la práctica (residual documentado).
            return encodeJSONString(try decimalFixed(number.doubleValue, scale: rateScale))
        }
        if let string = value as? String {
            return encodeJSONString(string)
        }
        if let array = value as? [Any] {
            // Arrays: ORDEN preservado (dato ordenado). El sort/dedup es SOLO de `.uuidArray` (columnas).
            return "[" + (try array.map(canonicalizeBlobValue).joined(separator: ",")) + "]"
        }
        if let dict = value as? [String: Any] {
            let sortedKeys = dict.keys.sorted(by: utf8BytesLess)
            let parts = try sortedKeys.map { key -> String in
                encodeJSONString(key) + ":" + (try canonicalizeBlobValue(dict[key]!))
            }
            return "{" + parts.joined(separator: ",") + "}"
        }
        throw Canonc1Error.malformedBlobJSON("tipo JSON no soportado: \(type(of: value))")
    }

    // MARK: - Strings: escape mínimo RFC-8785 (JCS)

    /// Serializa una string como literal JSON con escape MÍNIMO RFC-8785 (§d.7): `"`→`\"`, `\`→`\\`,
    /// C0 con formas cortas (`\b\t\n\f\r`), resto de controles <0x20 como `\u00xx` (hex LOWERCASE);
    /// `/` NO se escapa; no-ASCII (≥0x80) va como UTF-8 crudo, JAMÁS `\uXXXX` ni surrogate pairs.
    static func encodeJSONString(_ s: String) -> String {
        var out = "\""
        out.reserveCapacity(s.utf8.count + 2)
        for scalar in s.unicodeScalars {
            switch scalar.value {
            case 0x22: out += "\\\""   // "
            case 0x5C: out += "\\\\"   // \
            case 0x08: out += "\\b"
            case 0x09: out += "\\t"
            case 0x0A: out += "\\n"
            case 0x0C: out += "\\f"
            case 0x0D: out += "\\r"
            default:
                if scalar.value < 0x20 {
                    out += "\\u" + hex4Lowercase(scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)  // ASCII imprimible o UTF-8 crudo (incl. no-ASCII)
                }
            }
        }
        out += "\""
        return out
    }

    /// 4 dígitos hex LOWERCASE zero-padded (para `\u00xx` de controles C0).
    private static func hex4Lowercase(_ v: UInt32) -> String {
        let digits = "0123456789abcdef"
        let chars = Array(digits)
        var result = ""
        for shift in stride(from: 12, through: 0, by: -4) {
            let nibble = Int((v >> UInt32(shift)) & 0xF)
            result.append(chars[nibble])
        }
        return result
    }

    // MARK: - Orden por bytes UTF-8

    /// Orden estricto ascendente por los BYTES UTF-8 de la string (no scalars Unicode, no collation).
    /// El prefijo común decide; a igual prefijo, la más corta va antes.
    static func utf8BytesLess(_ a: String, _ b: String) -> Bool {
        let x = Array(a.utf8)
        let y = Array(b.utf8)
        var i = 0
        while i < x.count && i < y.count {
            if x[i] != y[i] { return x[i] < y[i] }
            i += 1
        }
        return x.count < y.count
    }
}

// MARK: - BigUInt mínimo (limbs UInt32 little-endian)

/// Entero sin signo de precisión arbitraria, mínimo para la ruta HALF_EVEN exacta-desde-binario.
/// Solo las operaciones que el codec necesita: construir desde `UInt64`, multiplicar por `UInt64`,
/// test de bit, y extraer los 64 bits bajos de un desplazamiento. `nonisolated` puro.
nonisolated struct BigUInt: Equatable {
    /// Limbs de 32 bits, little-endian (índice 0 = menos significativo). Nunca vacío.
    private var limbs: [UInt32]

    init(_ value: UInt64) {
        limbs = [UInt32(value & 0xFFFF_FFFF), UInt32(value >> 32)]
        normalize()
    }

    private init(limbs: [UInt32]) {
        self.limbs = limbs.isEmpty ? [0] : limbs
        normalize()
    }

    /// Quita limbs altos en cero (deja al menos uno).
    private mutating func normalize() {
        while limbs.count > 1 && limbs.last == 0 { limbs.removeLast() }
    }

    /// `self * value` exacto.
    func multiplied(by value: UInt64) -> BigUInt {
        let vLow = value & 0xFFFF_FFFF
        let vHigh = value >> 32
        var out = [UInt64](repeating: 0, count: limbs.count + 2)
        for (i, limb) in limbs.enumerated() {
            let l = UInt64(limb)
            var carry: UInt64 = 0
            let p0 = l * vLow + out[i] + carry
            out[i] = p0 & 0xFFFF_FFFF
            carry = p0 >> 32
            let p1 = l * vHigh + out[i + 1] + carry
            out[i + 1] = p1 & 0xFFFF_FFFF
            carry = p1 >> 32
            var j = i + 2
            while carry > 0 {
                let sum = out[j] + carry
                out[j] = sum & 0xFFFF_FFFF
                carry = sum >> 32
                j += 1
            }
        }
        return BigUInt(limbs: out.map { UInt32($0 & 0xFFFF_FFFF) })
    }

    /// Bit `i` (0 = menos significativo). `false` fuera de rango o `i < 0`.
    func bit(_ i: Int) -> Bool {
        if i < 0 { return false }
        let word = i / 32
        let offset = i % 32
        if word >= limbs.count { return false }
        return (limbs[word] >> offset) & 1 == 1
    }

    /// ¿Hay ALGÚN bit en 1 en las posiciones `0..<i`? (para el desempate HALF_EVEN "resto > mitad").
    func anyBitSetBelow(_ i: Int) -> Bool {
        if i <= 0 { return false }
        let fullWords = i / 32
        for w in 0..<min(fullWords, limbs.count) where limbs[w] != 0 { return true }
        if fullWords < limbs.count {
            let remainingBits = i % 32
            if remainingBits > 0 {
                let mask: UInt32 = (1 << UInt32(remainingBits)) - 1
                if limbs[fullWords] & mask != 0 { return true }
            }
        }
        return false
    }

    /// Los 64 bits bajos de `self >> n`. Correcto cuando el cociente cabe en 64 bits (garantizado en rango).
    func lowUInt64(shiftedRightBy n: Int) -> UInt64 {
        var result: UInt64 = 0
        for b in 0..<64 where bit(n + b) { result |= (UInt64(1) << UInt64(b)) }
        return result
    }

    /// Los 64 bits bajos de `self << n`. Solo para el caso defensivo `exponent >= 0` (inalcanzable en rango).
    func lowUInt64(shiftedLeftBy n: Int) -> UInt64 {
        var result: UInt64 = 0
        for b in 0..<64 {
            let source = b - n
            if source >= 0 && bit(source) { result |= (UInt64(1) << UInt64(b)) }
        }
        return result
    }
}
