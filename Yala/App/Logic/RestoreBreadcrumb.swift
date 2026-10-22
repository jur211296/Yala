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
    ///
    /// `settlement` parte ese `partial` en los dos que importan, y sin él el log no los distingue: el
    /// tope se agota igual para el histórico que tarda que para quien no tiene nada. Es el término que
    /// decide si la pantalla puede negar los datos, así que es el que hay que poder leer desde
    /// Console.app sobre un TestFlight Release, donde el bug reproduce y el debugger no llega.
    static func settled(phase: String, settlement: RestoreImportSettlement) {
        logger.notice("SETTLED phase=\(phase, privacy: .public) import=\(String(describing: settlement), privacy: .public)")
    }

    /// El tope se agotó con un import de CloudKit en marcha: hay datos bajando y la pantalla NO los
    /// niega. Distingue en el log el desenlace que hasta el 2026-09-20 se confundía con el `.notFound`
    /// legítimo — mismo recorrido en pantalla, hecho contrario.
    static func importIncomplete() {
        logger.notice("IMPORT-INCOMPLETE — tope agotado con import observado: los datos siguen llegando")
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

    /// La búsqueda terminó vacía y NO hemos podido preguntarle al servidor: sin snapshot de
    /// remote-config no se sabe si la nube está abierta, así que no se afirma nada sobre los datos.
    /// En el log distingue este desenlace del `.notFound` legítimo, que en pantalla se parecen y en
    /// hechos no: el que falta aquí es la red, no los datos. Sin ese rastro, el único recorrido que
    /// los separa —reinstalar sin red— no deja huella de por qué enseñó lo que enseñó.
    static func cloudUnverified() {
        logger.notice("CLOUD-UNVERIFIED — sin datos en iCloud y sin snapshot de config (nadie contestó)")
    }
}
