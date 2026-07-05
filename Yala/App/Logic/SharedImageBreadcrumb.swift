//
//  SharedImageBreadcrumb.swift
//  Yala
//
//  Rastro de diagnóstico para el flujo "compartir imagen al share sheet → registro por
//  imagen con IA". El bug de cold launch (la sheet nunca aparecía) era invisible: el intent
//  se descartaba en silencio, sin log en producción. Estos breadcrumbs en Console.app son la
//  ventana a la secuencia real de eventos en el device del owner (vía TestFlight), igual que
//  `IntentSignalBreadcrumb` para Apple Pay.
//
//  Logging INTENCIONALMENTE fuera de `#if DEBUG` (excepción consciente, igual que
//  `IntentSignalBreadcrumb` / `SaveBreadcrumb` / `SplitSync*`): sin PII (solo nombres de
//  sitio y bools). Filtro en Console.app: subsystem `com.yala`, category `SharedImage`.
//
//  Ver `Bugs/qa_cold-launch-share-image-no-registro`.
//

import Foundation
import OSLog

enum SharedImageBreadcrumb {
    nonisolated private static let logger = Logger(subsystem: "com.yala", category: "SharedImage")

    /// La app chequeó `PendingImages/` en una ventana ready (bootstrap post-init o
    /// `becameActive`). Se loguea SIEMPRE: `found=false` es tan diagnóstico como `found=true`.
    /// `willReEmit=false` con `found=true` delata que el gate de readiness bloqueó el re-emit
    /// (init/onboarding/lock) — el intent se reintentará en la próxima ventana.
    nonisolated static func checked(site: String, found: Bool, willReEmit: Bool) {
        logger.notice("SHARED-IMAGE CHECK \(site, privacy: .public) — found=\(found, privacy: .public) reEmit=\(willReEmit, privacy: .public)")
    }
}
