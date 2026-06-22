//
//  SaveBreadcrumb.swift
//  Yala
//
//  Rastro de diagnóstico para los `ModelContext.save()` que pueden correr durante el
//  import de iCloud (restore). Un `save()` sobre el coordinator del store personal
//  mientras NSPersistentCloudKitContainer importa dispara un `_assertionFailure` interno
//  de SwiftData (SIGTRAP, no atrapable por do/catch). Como ese crash SOLO reproduce en
//  CloudKit **Production** (device restaurado) y no tenemos dSYM para simbolicar los `.ips`,
//  sembramos un breadcrumb ANTES de cada `save()` candidato: el último `SAVE <site>` en
//  Console.app nombra el sitio exacto si algo crashea.
//
//  Logging INTENCIONALMENTE fuera de `#if DEBUG` (excepción consciente, igual que `SplitSync*`):
//  verificable solo vía TestFlight Release en Console.app; sin PII (solo bools/strings de sitio).
//

import Foundation
import OSLog

/// Breadcrumbs para los `save()` del store personal vulnerables a la ventana de import.
/// Confinado a `@MainActor` porque lee `iCloudSyncService.shared` (singleton main-actor) y
/// todos los call sites manipulan `ModelContext` en el main actor.
@MainActor
enum SaveBreadcrumb {
    private static let logger = Logger(subsystem: "com.yala", category: "SaveGate")

    /// Llamar JUSTO antes de un `context.save()`. Si la app crashea en ese save, esta es la
    /// última línea que aparece en Console.app → identifica el sitio sin necesidad del dSYM.
    static func willSave(_ site: String) {
        let status = iCloudSyncService.shared.status
        logger.notice("SAVE \(site, privacy: .public) — importing=\(status.isImporting, privacy: .public) syncing=\(status.isSyncing, privacy: .public) firstImport=\(iCloudSyncService.shared.hasCompletedFirstImport, privacy: .public)")
    }

    /// Llamar tras un `save()` exitoso — confirma que el sitio NO crasheó.
    static func didSave(_ site: String) {
        logger.notice("SAVED \(site, privacy: .public)")
    }

    /// Llamar cuando un save se difiere por el gate de quiescencia (no se ejecutó este turno).
    static func deferred(_ site: String, _ reason: String) {
        logger.notice("DEFER \(site, privacy: .public) — \(reason, privacy: .public)")
    }
}
