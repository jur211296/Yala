//
//  HLC.swift
//  Yala
//
//  Hybrid Logical Clock (HLC) del Modo Nube, incremento I1. Un HLC combina el reloj físico de pared
//  con un contador lógico para producir timestamps con ORDEN TOTAL y causalidad, resistentes al skew
//  de reloj entre dispositivos. Es el árbitro del LWW (last-writer-wins) del sync por campo.
//
//  Referencias: algoritmo clásico de Kulkarni et al. ("Logical Physical Clocks", 2014) y la
//  implementación `timestamp.ts` de Actual Budget. Formato de string canónico c1 (46 chars):
//      <T-CANON:24>-<counterHex:4>-<nodeID:16>
//  p.ej. "2021-01-01T00:00:00.000Z-0000-00000000000000aa".
//
//  Todo el tipo es `nonisolated`: bajo `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, un valor puro
//  que cruza contextos (sync corre fuera del main actor) DEBE serlo o el compilador lo aísla al main.
//

import Foundation

// MARK: - Errores

/// Errores del avance del reloj HLC (send/receive). Ambos casos son condiciones que hacen INSEGURO
/// emitir un timestamp: preferimos fallar tipado antes que producir un HLC corrupto o mentir sobre el
/// tiempo.
nonisolated enum ClockDriftError: Error, Equatable {
    /// El contador lógico superaría 0xFFFF (16 bits) en el mismo ms físico. 0xFFFF es válido; 0x10000 no.
    case counterOverflow
    /// El reloj lógico resultante se adelanta al reloj de pared más que el máximo tolerado (5 min).
    case driftExceeded(driftMillis: Int64)
}

/// Errores del parsing estricto de una string HLC c1.
nonisolated enum HLCParsingError: Error, Equatable {
    /// Longitud distinta de 46 chars.
    case invalidLength(Int)
    /// Formato inválido (guion mal puesto, hex en mayúscula/no-hex, etc.) con motivo.
    case invalidFormat(String)
}

// MARK: - NodeID

/// Identidad de nodo de 128 bits truncada a los ÚLTIMOS 16 hex (64 bits), lowercase. Rompe empates
/// cuando (physicalMs, counter) coinciden entre dos dispositivos → garantiza orden total.
/// La persistencia (Keychain) NO es parte de I1.
nonisolated struct NodeID: Hashable, Sendable, Codable, CustomStringConvertible {

    /// Exactamente 16 chars hex lowercase.
    let value: String

    /// Construye desde una string ya validada (16 hex lowercase). Falla si no cumple.
    init(validating raw: String) throws {
        guard raw.count == 16 else {
            throw HLCParsingError.invalidFormat("nodeID de \(raw.count) chars ≠ 16")
        }
        guard NodeID.isLowercaseHex(raw) else {
            throw HLCParsingError.invalidFormat("nodeID no es hex lowercase: \(raw)")
        }
        self.value = raw
    }

    /// Genera un nodeID nuevo: 128 bits aleatorios, se toman los ÚLTIMOS 16 hex.
    static func generate() -> NodeID {
        var generator = SystemRandomNumberGenerator()
        // 128 bits = dos palabras de 64.
        let high = UInt64.random(in: UInt64.min...UInt64.max, using: &generator)
        let low = UInt64.random(in: UInt64.min...UInt64.max, using: &generator)
        let fullHex = String(format: "%016lx%016lx", high, low)  // 32 hex
        let last16 = String(fullHex.suffix(16))
        // `last16` es hex lowercase de 16 chars por construcción; el init validante es defensivo.
        do {
            return try NodeID(validating: last16)
        } catch {
            // Inalcanzable: %016lx siempre produce 16 hex lowercase. Fallback duro sin trap.
            return NodeID(unchecked: String(repeating: "0", count: 16))
        }
    }

    /// Init interno sin validación, solo para el fallback inalcanzable de `generate()`.
    private init(unchecked raw: String) {
        self.value = raw
    }

    var description: String { value }

    private static func isLowercaseHex(_ s: String) -> Bool {
        for scalar in s.unicodeScalars {
            let v = scalar.value
            let isDigit = v >= 48 && v <= 57          // 0-9
            let isLowerAF = v >= 97 && v <= 102       // a-f
            if !(isDigit || isLowerAF) { return false }
        }
        return true
    }

    // MARK: Codable (single-value string)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        try self.init(validating: raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - HLC

/// Un timestamp HLC inmutable. Orden total ESTRUCTURADO por (physicalMs, counter, nodeID) — NUNCA por
/// comparación de la string completa. `Codable` como string c1 single-value.
nonisolated struct HLC: Comparable, Hashable, Sendable, Codable, CustomStringConvertible {

    /// ms desde el epoch Unix (componente físico).
    let physicalMs: Int64
    /// Contador lógico, 0...0xFFFF.
    let counter: UInt16
    /// Identidad de nodo emisor.
    let nodeID: NodeID

    /// Construye un HLC validando que `physicalMs` mapee a un año canónico (0001..9999). Cualquier HLC
    /// que exista cumple ese invariante → `description` puede formatear sin volver a validar.
    /// - Throws: `CanonicalTimeError.yearOutOfRange`.
    init(physicalMs: Int64, counter: UInt16, nodeID: NodeID) throws {
        _ = try CanonicalTime.canonicalIsoMillis(physicalMs)  // valida rango de año
        self.physicalMs = physicalMs
        self.counter = counter
        self.nodeID = nodeID
    }

    /// String canónica c1 de 46 chars. `physicalMs` está validado por construcción → unchecked es seguro.
    var description: String {
        let isoMillis = CanonicalTime.canonicalIsoMillisUnchecked(physicalMs)
        let counterHex = String(format: "%04x", counter)
        return "\(isoMillis)-\(counterHex)-\(nodeID.value)"
    }

    /// Invariante verificable: el prefijo de 24 chars de la string es exactamente el timestamp canónico.
    var canonicalTimestampPrefix: String {
        String(description.prefix(24))
    }

    // MARK: Comparable — orden total ESTRUCTURADO (campo a campo), nunca sobre la string entera.

    static func < (lhs: HLC, rhs: HLC) -> Bool {
        if lhs.physicalMs != rhs.physicalMs { return lhs.physicalMs < rhs.physicalMs }
        if lhs.counter != rhs.counter { return lhs.counter < rhs.counter }
        // nodeID: ancho fijo (16) lowercase hex → comparar como string es un orden total válido.
        return lhs.nodeID.value < rhs.nodeID.value
    }

    // MARK: Codable (single-value string c1, parsing estricto)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = try HLC.parse(raw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    /// Parsea una string c1 de 46 chars ESTRICTAMENTE: `<iso:24>-<counterHex:4>-<nodeID:16>`.
    /// Rechaza longitudes distintas de 46, guiones fuera de sitio, hex en mayúscula o malformado, y
    /// timestamps no canónicos.
    /// - Throws: `HLCParsingError` o `CanonicalTimeError`.
    static func parse(_ string: String) throws -> HLC {
        let scalars = Array(string.unicodeScalars)
        guard scalars.count == 46 else {
            throw HLCParsingError.invalidLength(scalars.count)
        }
        // Guiones separadores en posición fija: 24 y 29.
        let dash = Unicode.Scalar(45)  // '-'
        guard scalars[24] == dash else {
            throw HLCParsingError.invalidFormat("se esperaba '-' en la posición 24")
        }
        guard scalars[29] == dash else {
            throw HLCParsingError.invalidFormat("se esperaba '-' en la posición 29")
        }

        let isoPart = String(String.UnicodeScalarView(scalars[0..<24]))
        let counterPart = String(String.UnicodeScalarView(scalars[25..<29]))
        let nodePart = String(String.UnicodeScalarView(scalars[30..<46]))

        let physicalMs = try CanonicalTime.parseCanonicalIsoMillis(isoPart)
        let counter = try parseCounterHex(counterPart)
        let nodeID = try NodeID(validating: nodePart)

        return try HLC(physicalMs: physicalMs, counter: counter, nodeID: nodeID)
    }

    /// Parsea 4 hex lowercase → UInt16. Rechaza mayúsculas y no-hex.
    private static func parseCounterHex(_ part: String) throws -> UInt16 {
        let scalars = Array(part.unicodeScalars)
        guard scalars.count == 4 else {
            throw HLCParsingError.invalidFormat("counterHex de \(scalars.count) chars ≠ 4")
        }
        var result: UInt32 = 0
        for scalar in scalars {
            let v = scalar.value
            let digit: UInt32
            if v >= 48 && v <= 57 {          // 0-9
                digit = v - 48
            } else if v >= 97 && v <= 102 {  // a-f (lowercase-only)
                digit = v - 97 + 10
            } else {
                throw HLCParsingError.invalidFormat("counterHex no es hex lowercase: \(part)")
            }
            result = result * 16 + digit
        }
        return UInt16(result)  // result <= 0xFFFF por construcción (4 hex)
    }
}

// MARK: - HLCClock

/// Reloj HLC con estado mutable. Genera timestamps monótonos (`send`) e integra timestamps remotos
/// (`receive`) preservando causalidad. `now:` se inyecta (patrón canónico del repo) — nunca lee
/// `Date()` internamente. Struct con `mutating` (valor con estado explícito, sin isolation implícita).
nonisolated struct HLCClock {

    /// Máximo skew tolerado entre el reloj lógico y el de pared: 5 minutos.
    static let maxDriftMillis: Int64 = 5 * 60 * 1_000

    /// Identidad de este nodo. Estampa todo timestamp emitido.
    let nodeID: NodeID

    /// Último timestamp conocido por el reloj (nil = aún no emitió/recibió nada).
    private(set) var latest: HLC?

    init(nodeID: NodeID, latest: HLC? = nil) {
        self.nodeID = nodeID
        self.latest = latest
    }

    /// Componente físico previo, o `Int64.min` si no hay `latest` (nunca gana el `max`).
    private var latestPhysical: Int64 { latest?.physicalMs ?? Int64.min }
    private var latestCounter: Int { latest.map { Int($0.counter) } ?? 0 }

    /// Emite un timestamp para un evento LOCAL. `l' = max(l, pt)`; mismo ms → counter+1; el reloj de
    /// pared avanza → counter=0; el reloj de pared retrocede → `l` manda y counter+1.
    /// - Throws: `ClockDriftError.counterOverflow`, `.driftExceeded`, o `CanonicalTimeError`.
    mutating func send(now: Date = .now) throws -> HLC {
        let wallMs = CanonicalTime.physicalMillis(from: now)
        let oldPhysical = latestPhysical

        let newPhysical = max(oldPhysical, wallMs)
        let newCounter: Int
        if newPhysical == oldPhysical {
            // El reloj de pared no superó al lógico (mismo ms o regresión) → avanza el contador.
            newCounter = latestCounter + 1
        } else {
            // El reloj de pared avanzó a un ms nuevo → contador a cero.
            newCounter = 0
        }

        let result = try makeTimestamp(physicalMs: newPhysical, counter: newCounter, wallMs: wallMs)
        latest = result
        return result
    }

    /// Integra un timestamp REMOTO recibido. `l' = max(l, l_m, pt)` con las reglas de contador de
    /// Kulkarni. El resultado se estampa con el nodeID LOCAL (representa nuestra recepción del evento).
    /// - Throws: `ClockDriftError.counterOverflow`, `.driftExceeded`, o `CanonicalTimeError`.
    mutating func receive(remote: HLC, now: Date = .now) throws -> HLC {
        let wallMs = CanonicalTime.physicalMillis(from: now)
        let oldPhysical = latestPhysical
        let oldCounter = latestCounter
        let msgPhysical = remote.physicalMs
        let msgCounter = Int(remote.counter)

        let newPhysical = max(oldPhysical, msgPhysical, wallMs)
        let newCounter: Int
        if newPhysical == oldPhysical && newPhysical == msgPhysical {
            newCounter = max(oldCounter, msgCounter) + 1
        } else if newPhysical == oldPhysical {
            newCounter = oldCounter + 1
        } else if newPhysical == msgPhysical {
            newCounter = msgCounter + 1
        } else {
            newCounter = 0
        }

        let result = try makeTimestamp(physicalMs: newPhysical, counter: newCounter, wallMs: wallMs)
        latest = result
        return result
    }

    /// Valida drift y overflow, y construye el HLC con el nodeID local. NO muta `latest` (lo hace el
    /// llamador solo si no lanza).
    private func makeTimestamp(physicalMs: Int64, counter: Int, wallMs: Int64) throws -> HLC {
        // Drift: el reloj lógico resultante no debe adelantarse al de pared más que el máximo.
        let drift = physicalMs - wallMs
        if drift > HLCClock.maxDriftMillis {
            throw ClockDriftError.driftExceeded(driftMillis: drift)
        }
        // Overflow del contador de 16 bits.
        guard counter <= Int(UInt16.max) else {
            throw ClockDriftError.counterOverflow
        }
        return try HLC(physicalMs: physicalMs, counter: UInt16(counter), nodeID: nodeID)
    }
}
