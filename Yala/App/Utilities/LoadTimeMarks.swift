//
//  LoadTimeMarks.swift
//  Yala
//
//  Marcas de «tiempo hasta contenido útil» por pantalla. Solo en DEBUG: en Release todo es no-op.
//

import Foundation
import os

/// Mide cuánto tarda cada pantalla en enseñar sus datos.
///
/// Un intervalo empieza al elegir la pestaña (`begin`) —o al arrancar el proceso, para el arranque en frío— y acaba
/// donde la vista asigna el estado que pinta los datos (`ready`). Cada intervalo sale dos veces: como signpost
/// (`Instruments` → os_signpost, subsistema `app.yala.perf`) y como línea de log con los milisegundos
/// (`log show --predicate 'subsystem == "app.yala.perf"'`), que es lo que lee `LoadTimesUITests`.
///
/// `ready` sin un `begin` pendiente no hace nada: una pestaña ya cargada que vuelve a aparecer no se cuenta. Y `ready`
/// cierra el intervalo en la vuelta SIGUIENTE del main run loop, no en el acto: así el intervalo incluye el render que
/// provoca el estado recién asignado (el `body` que pinta los datos), que es parte de lo que la persona espera.
/// Un intervalo de más de 60 s se descarta: es una pestaña que se eligió y nunca llegó a «listo» por esta vía.
enum LoadTimeMarks {

    enum Screen: String, CaseIterable {
        case coldLaunch = "arranque"
        case panel
        case records = "registros"
        case statistics = "estadisticas"
        case planning = "planificacion"
        case groups = "grupos"
        case cashFlow = "flujo"
        case inbox = "bandeja"
        case settings = "ajustes"
        case settingsAccounts = "ajustes-cuentas"
        case widgetCache = "widgets"
    }

    /// La pantalla que mide elegir `tab`. Informes no tiene marca propia: se mide su Flujo de caja, al elegir el chip.
    static func screen(for tab: AppTab) -> Screen? {
        switch tab {
        case .records: return .records
        case .statistics: return .statistics
        case .planning: return .planning
        case .groups: return .groups
        // El Panel se mide desde su `onAppear` (y en frío, desde el arranque): al volver a una pestaña ya calculada no
        // recalcula, y un `begin` aquí quedaría pendiente hasta el siguiente cálculo, que no es «cargar».
        case .panel, .reports, .more, .search: return nil
        }
    }

    #if DEBUG
    private static let signposter = OSSignposter(subsystem: "app.yala.perf", category: "carga")
    private static let logger = Logger(subsystem: "app.yala.perf", category: "carga")
    private static var pending: [Screen: (start: UInt64, state: OSSignpostIntervalState)] = [:]

    /// Instante de arranque del proceso, en el reloj de `DispatchTime` (nanosegundos desde el arranque del sistema).
    /// Sale de `sysctl(KERN_PROC_PID)`: el reloj de pared de `p_starttime` menos lo que ya lleva vivo el proceso.
    private static func processStartUptimeNanos() -> UInt64? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0 else { return nil }
        let start = info.kp_proc.p_starttime
        let startWall = Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000
        let elapsed = Date().timeIntervalSince1970 - startWall
        let now = DispatchTime.now().uptimeNanoseconds
        let elapsedNanos = UInt64(max(0, elapsed) * 1_000_000_000)
        return now > elapsedNanos ? now - elapsedNanos : nil
    }
    #endif

    /// Empieza el intervalo de `screen`. Si ya había uno pendiente, lo reinicia.
    static func begin(_ screen: Screen) {
        #if DEBUG
        if let old = pending[screen] {
            signposter.endInterval("carga", old.state, "\(screen.rawValue, privacy: .public) reiniciado")
        }
        let state = signposter.beginInterval("carga", id: signposter.makeSignpostID(), "\(screen.rawValue, privacy: .public)")
        let start = screen == .coldLaunch
            ? (processStartUptimeNanos() ?? DispatchTime.now().uptimeNanoseconds)
            : DispatchTime.now().uptimeNanoseconds
        pending[screen] = (start, state)
        #endif
    }

    /// Cierra el intervalo pendiente de `screen` y escribe sus milisegundos.
    static func ready(_ screen: Screen) {
        #if DEBUG
        guard let entry = pending.removeValue(forKey: screen) else { return }
        DispatchQueue.main.async {
            let ms = Double(DispatchTime.now().uptimeNanoseconds - entry.start) / 1_000_000
            signposter.endInterval("carga", entry.state, "\(screen.rawValue, privacy: .public)")
            guard ms < 60_000 else { return }
            logger.notice("PERF \(screen.rawValue, privacy: .public) \(ms, format: .fixed(precision: 1), privacy: .public) ms")
        }
        #endif
    }

    /// Mide un bloque síncrono (p. ej. escribir la caché de los widgets) y escribe sus milisegundos. Sin `begin`/`ready`:
    /// el bloque es todo el trabajo.
    @discardableResult
    static func measure<T>(_ screen: Screen, _ body: () throws -> T) rethrows -> T {
        #if DEBUG
        let state = signposter.beginInterval("carga", id: signposter.makeSignpostID(), "\(screen.rawValue, privacy: .public)")
        let start = DispatchTime.now().uptimeNanoseconds
        defer {
            let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            signposter.endInterval("carga", state, "\(screen.rawValue, privacy: .public)")
            logger.notice("PERF \(screen.rawValue, privacy: .public) \(ms, format: .fixed(precision: 1), privacy: .public) ms")
        }
        #endif
        return try body()
    }
}
