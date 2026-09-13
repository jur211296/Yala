//
//  RestoreBreadcrumb.swift
//  Yala
//
//  Rastro de diagnóstico del flujo Welcome → Restore (pantalla de progreso,
//  destino post-restore, wipe-gate). El bug que motivó el
//  rediseño solo reproduce en CloudKit **Production** (device restaurado), donde no
//  hay dSYM ni reproducción en simulador → Console.app sobre TestFlight Release es
//  la única ventana. Logging INTENCIONALMENTE fuera de `#if DEBUG` (excepción
//  consciente, igual que `SaveBreadcrumb`/`SplitSync*`); sin PII (solo bools/strings
//  de fase/ruta, nunca nombres ni montos).
//

import Foundation
import OSLog

@MainActor
enum RestoreBreadcrumb {
    private static let logger = Logger(subsystem: "com.yala", category: "RestoreFlow")

    /// Restore asentado: `completed` = quiescencia alcanzada; `partial` = timeout
    /// (se procede con datos parciales, seguimos sincronizando en background).
    static func settled(phase: String) {
        logger.notice("SETTLED phase=\(phase, privacy: .public)")
    }

    /// Destino post-restore decidido por `RestoreRouter`.
    static func destination(_ dest: String) {
        logger.notice("DEST \(dest, privacy: .public)")
    }

    /// Respeto al wipe: se mostró el estado `.wiped` (no se ofreció restaurar
    /// porque el último acto del usuario fue un wipe).
    static func wiped() {
        logger.notice("WIPED — restore no ofrecido (último acto fue wipe)")
    }

    /// La búsqueda terminó vacía y el faro dice que este Apple ID SÍ tiene cuenta nube: lo que falta
    /// no son los datos, es la nube (kill-switch remoto puesto). Vale la pena en el log porque
    /// distingue, sobre un mismo recorrido «no encontré nada», los dos desenlaces opuestos — y el
    /// término que los separa se conmuta desde el backend, así que el device no tiene otra forma de
    /// contar por qué enseñó lo que enseñó.
    static func cloudPaused() {
        logger.notice("CLOUD-PAUSED — sin datos en iCloud, faro linked y kill remoto puesto")
    }
}
