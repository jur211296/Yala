//
//  IntentSignalBreadcrumb.swift
//  Yala
//
//  Rastro de diagnóstico para el flujo "un App Intent background guardó → la app refresca
//  al volver a foreground". El bug (Inbox vacío / datos en 0 en warm launch tras una
//  automatización de Apple Pay) SOLO reproduce en device real con Apple Pay real, así que
//  no hay forma de verlo en el simulador ni en un test: los breadcrumbs en Console.app son
//  la única ventana a la secuencia real de eventos en el device del owner (vía TestFlight).
//
//  Logging INTENCIONALMENTE fuera de `#if DEBUG` (excepción consciente, igual que
//  `SaveBreadcrumb` / `SplitSync*`): sin PII (solo nombres de sitio, bools, segundos y
//  códigos de error). Filtro en Console.app: subsystem `com.yala`, category `IntentSignal`.
//
//  A diferencia de `SaveBreadcrumb` (que es `@MainActor` porque lee `iCloudSyncService`),
//  este es `nonisolated` puro (Logger es thread-safe) para poder llamarse desde el proceso
//  del intent, que no corre en el main actor de la app.
//
//  Ver `Bugs/applepay-shortcut-ios27-warm-launch-datos-vacios`.
//

import Foundation
import OSLog

enum IntentSignalBreadcrumb {
    // `nonisolated` (Logger es Sendable) para poder loguear desde el proceso del intent, que
    // no corre en el main actor. Sin esto, el default de aislamiento del módulo trata el
    // `static let` como main-actor y las funciones nonisolated no podrían referenciarlo.
    nonisolated private static let logger = Logger(subsystem: "com.yala", category: "IntentSignal")

    /// Un intent background acaba de marcar la señal tras su `save()`.
    nonisolated static func set(_ intent: String) {
        logger.notice("SIGNAL SET \(intent, privacy: .public)")
    }

    /// Resultado de crear el `ModelContainer` del intent. `cloudKit=false` confirma que usa
    /// el container local-only (`.none`). `errorCode` != nil delata un fallo de creación
    /// (canario del 134410 si alguna vez reaparece el 2º mirror `.private`).
    nonisolated static func intentContainerCreated(cloudKit: Bool, errorCode: Int?) {
        if let errorCode {
            logger.notice("CONTAINER \(cloudKit ? "cloudKit" : "local", privacy: .public) — error=\(errorCode, privacy: .public)")
        } else {
            logger.notice("CONTAINER \(cloudKit ? "cloudKit" : "local", privacy: .public) — ok")
        }
    }

    /// La app chequeó la señal al volver a foreground / en bootstrap. Se loguea SIEMPRE
    /// (también `found=false`): la ausencia de señal es tan diagnóstica como su presencia.
    nonisolated static func checked(site: String, found: Bool, ageSeconds: Double?) {
        if let ageSeconds {
            logger.notice("SIGNAL CHECK \(site, privacy: .public) — found=\(found, privacy: .public) age=\(ageSeconds, format: .fixed(precision: 1), privacy: .public)s")
        } else {
            logger.notice("SIGNAL CHECK \(site, privacy: .public) — found=\(found, privacy: .public)")
        }
    }

    /// El re-fire diferido aplicó cambios pendientes (el merge de la history aterrizó).
    nonisolated static func refireApplied(elapsed: Double) {
        logger.notice("REFIRE applied — elapsed=\(elapsed, format: .fixed(precision: 1), privacy: .public)s")
    }

    /// El re-fire llegó al tope de la ventana sin aplicar ningún pending (el observer no
    /// re-disparó dentro de la ventana). No fuerza reload — el refresh inmediato ya cubrió el
    /// caso merged; un merge posterior lo aplica la próxima navegación.
    nonisolated static func refireTimedOut() {
        logger.notice("REFIRE timed-out")
    }

    /// Entrada a `bootstrap()`. `alreadyInitialized=true` = el guard cortará (proceso ya
    /// bootstrapeado); `false` = primer bootstrap real de este proceso.
    nonisolated static func bootstrapEntered(alreadyInitialized: Bool) {
        logger.notice("BOOTSTRAP enter — alreadyInitialized=\(alreadyInitialized, privacy: .public)")
    }

    /// El observer de `.NSPersistentStoreRemoteChange` quedó registrado (paso 13 del bootstrap).
    /// Si un `SIGNAL SET` aparece ANTES de esta línea, confirma el hueco (observer no armado).
    nonisolated static func observerRegistered() {
        logger.notice("OBSERVER remote-change registered")
    }

    /// El observer de remote-change disparó (el coordinator de la app procesó history).
    nonisolated static func remoteChangeFired(edge: String) {
        logger.notice("REMOTE-CHANGE fired — edge=\(edge, privacy: .public)")
    }

    /// Resultado del chequeo inicial de datos en `ContentView`. `hasExistingData=false` tras
    /// un `found=true` = el mainContext no mergeó (la ventana de reconciliación no cerró).
    nonisolated static func initialSyncChecked(hasExistingData: Bool) {
        logger.notice("INITIAL-SYNC — hasExistingData=\(hasExistingData, privacy: .public)")
    }
}
