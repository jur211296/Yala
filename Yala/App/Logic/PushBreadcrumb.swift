//
//  PushBreadcrumb.swift
//  Yala
//
//  Rastro de diagnóstico del push remoto propio (spike G0 Grupos→backend, semilla de G8).
//  El guion device del spike filtra en Console.app por `subsystem:com.yala category:Push`
//  y mide entrega/latencia del silent push del gateway con estos tokens grep-ables:
//  `PUSH TOKEN_OK` · `PUSH TOKEN_FAIL` · `PUSH RECEIVED kind=<cloudkit|yala(...)|unknown>`.
//
//  Logging INTENCIONALMENTE fuera de `#if DEBUG` (excepción consciente, igual que
//  `SaveBreadcrumb`/`SplitSync*`): la entrega real de APNs solo se observa en device
//  (TestFlight/Xcode) vía Console.app. Sin PII — el device token NUNCA se loggea completo
//  en Release (solo prefijo de 8 chars); el token completo solo bajo `#if DEBUG`.
//

import Foundation
import OSLog

enum PushBreadcrumb {
    private static let logger = Logger(subsystem: "com.yala", category: "Push")

    /// Clasificación del payload recibido en `didReceiveRemoteNotification`.
    enum ReceivedKind {
        case cloudKit // payload de CloudKit (CKSyncEngine lo procesa por su canal interno)
        case yala(kind: String?) // payload propio del gateway (key top-level "yala")
        case unknown
    }

    static func tokenRegistered(_ token: String) {
        logger.notice("PUSH TOKEN_OK prefix=\(String(token.prefix(8)), privacy: .public) len=\(token.count, privacy: .public)")
        #if DEBUG
        // Copiable desde la consola de Xcode para el curl del spike (solo DEBUG).
        logger.notice("PUSH TOKEN_FULL \(token, privacy: .public)")
        #endif
    }

    static func tokenFailed(_ error: Error) {
        logger.notice("PUSH TOKEN_FAIL \(String(describing: error), privacy: .public)")
    }

    static func received(kind: ReceivedKind) {
        logger.notice("PUSH RECEIVED kind=\(label(for: kind), privacy: .public)")
    }

    private static func label(for kind: ReceivedKind) -> String {
        switch kind {
        case .cloudKit: return "cloudkit"
        case .yala(let kind): return "yala(\(kind ?? "-"))"
        case .unknown: return "unknown"
        }
    }
}
