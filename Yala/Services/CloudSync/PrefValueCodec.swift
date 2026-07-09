//
//  PrefValueCodec.swift
//  Yala
//
//  Codec canónico value TEXT ↔ tipo Swift para las preferencias sincronizadas (Modo Nube, I13).
//  La tabla `user_preferences` del backend es `value TEXT` (opaca) → el TIPO lo conoce el cliente por
//  la key (`PrefSyncKey.kind`). Esta pieza es la ÚNICA fuente de la codificación: la usan el `PrefsOutbox`
//  (encode al encolar) Y el merge del pull (decode). Una asimetría encode/decode corrompería prefs
//  cross-device en silencio → round-trip tests por tipo (`PrefValueCodecTests`).
//
//  Encodings:
//    - Bool → "true" / "false"
//    - Int  → decimal (`String(Int)`)
//    - String → verbatim
//
//  `nonisolated`: valor puro que cruza contextos (el outbox codifica fuera del main actor, el merge lo
//  consume desde `@MainActor`); bajo `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` debe serlo o el
//  compilador lo aislaría al main.
//

import Foundation

// MARK: - PrefValue

/// Valor tipado de una preferencia. El `PrefValueCodec` lo serializa a/desde el TEXT del backend.
nonisolated enum PrefValue: Equatable {
    case string(String)
    case bool(Bool)
    case int(Int)

    /// El `String` subyacente si es `.string` (nil en otro caso). Usado por el merge para comparar/escribir.
    var stringValue: String? {
        if case let .string(s) = self { return s }
        return nil
    }

    /// El `Bool` subyacente si es `.bool` (nil en otro caso).
    var boolValue: Bool? {
        if case let .bool(b) = self { return b }
        return nil
    }

    /// El `Int` subyacente si es `.int` (nil en otro caso).
    var intValue: Int? {
        if case let .int(i) = self { return i }
        return nil
    }
}

// MARK: - PrefKind

/// El tipo de una key sincronizada (discrimina la codificación TEXT). Lo declara `PrefSyncKey.kind`.
nonisolated enum PrefKind: String {
    case string
    case bool
    case int
}

// MARK: - PrefValueCodec

/// Codec TEXT ↔ `PrefValue`. Determinista, sin dependencia de locale (Int en decimal ASCII).
nonisolated enum PrefValueCodec {

    /// Serializa un `PrefValue` al TEXT canónico que viaja al backend / se persiste en el outbox.
    static func encode(_ value: PrefValue) -> String {
        switch value {
        case .string(let s): return s
        case .bool(let b): return b ? "true" : "false"
        case .int(let i): return String(i)
        }
    }

    /// Reconstruye el `PrefValue` a partir del TEXT y el `kind` de la key. Tolerante a basura:
    ///   - bool: cualquier cosa distinta de "true" (exacto) → `false` (paridad con la interpretación
    ///     de `NSUbiquitousKeyValueStore.bool`, donde solo el valor puesto explícitamente cuenta).
    ///   - int: no-parseable → `0` (paridad con `UserDefaults.integer` para keys ausentes/basura).
    static func decode(_ text: String, as kind: PrefKind) -> PrefValue {
        switch kind {
        case .string: return .string(text)
        case .bool: return .bool(text == "true")
        case .int: return .int(Int(text) ?? 0)
        }
    }
}
