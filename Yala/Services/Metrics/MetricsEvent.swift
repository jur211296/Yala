//
//  MetricsEvent.swift
//  Yala
//
//  Wire model de la telemetría propia (POST /metrics del gateway, 2026-07-17 —
//  sustituye TelemetryDeck). Tres eventos y nada más: ping (activos/día),
//  register (altas/día) y canary (diagnósticos operativos del gate de Modo Nube).
//  Contrato completo en qa/cloud/README § "Telemetría propia POST /metrics".
//

import Foundation

/// Un evento del wire v1. `e` ∈ {ping, register, canary}; `n` nombre (slug estable),
/// `d` detalle ≤128 chars, `x` valor numérico (default server-side: 1).
/// DTO Codable cross-persistencia (spool en UserDefaults) → `nonisolated` (regla del repo
/// bajo SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor).
nonisolated struct MetricsEvent: Codable, Equatable {
    var e: String
    var n: String?
    var d: String?
    var x: Double?

    static func ping() -> MetricsEvent { MetricsEvent(e: "ping") }

    static func register(kind: String, detail: String) -> MetricsEvent {
        MetricsEvent(e: "register", n: kind, d: detail)
    }

    static func canary(name: String, detail: String?, value: Double) -> MetricsEvent {
        MetricsEvent(e: "canary", n: name, d: detail, x: value == 1 ? nil : value)
    }
}

/// Body del `POST /metrics`. `install` = hash SHA-256 truncado del bucketSeed local
/// (anónimo, no reversible); `app` = CFBundleShortVersionString.
nonisolated struct MetricsRequestBody: Codable {
    var v: Int
    var install: String
    var app: String?
    var events: [MetricsEvent]
}

// MARK: - Contextos de canarios (mudados de TelemetryService — sus wrappers los consumen)

enum DuplicateDetectionContext: String {
    case bootCleanup = "boot-cleanup"
    case runtimeFetch = "runtime-fetch"
    case syncApply = "sync-apply"
    case uniquingFallback = "uniquing-fallback"
}

enum TransferReconcileContext: String {
    case bootReconcile = "boot.transferReconcile"
    case bootCollision = "boot.transferCollision"
}
