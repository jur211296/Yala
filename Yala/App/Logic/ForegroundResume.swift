//
//  ForegroundResume.swift
//  Yala
//
//  Soltar el freno de recálculo al volver a primer plano, aunque iOS avise de la escena antes que de la app.
//
//  Las pantallas con freno (Panel, Registros, Estadísticas, Grupos, detalle de grupo, Informes) lo ponen en `.inactive` /
//  `.background` y lo sueltan en `.active`. Hasta el 2026-11-04 la vuelta empezaba con
//  `guard UIApplication.shared.applicationState == .active else { return }`: si `scenePhase` llegaba a `.active` con la
//  app todavía sin activar —con varias ventanas `scenePhase` es el de la ventana y `applicationState` el del proceso—, el
//  `return` se saltaba también el soltar, y la pantalla ignoraba todo cambio hasta la siguiente transición de fase. Nadie
//  lo vio pasar (card `tablero-al-volver-a-yala-una-pantalla-podria-que-n34p`, ticket
//  `scene-phase-active-guard-may-leave-the-brake-paused`).
//
//  Ahora, si la app aún no está activa, la vuelta ESPERA a `didBecomeActive` en vez de perderse. El caso normal no
//  cambia: con la app activa corre en el acto, como antes.
//
//  **Es también la medida.** Cada espera deja una línea en Console.app (subsistema `com.yala`, categoría
//  `ForegroundResume`, fuera de `#if DEBUG` y sin datos de la persona, como `IntentSignalBreadcrumb`):
//  `DEFERRED <pantalla>` cuando iOS avisó de la escena con la app sin activar, y `RESUMED <pantalla>` cuando la espera
//  terminó. Sin ninguna `DEFERRED` en un uso normal, la hipótesis del ticket no ocurre en ese aparato.
//

import Foundation
import OSLog
import UIKit

@MainActor
enum ForegroundResume {

    nonisolated private static let logger = Logger(subsystem: "com.yala", category: "ForegroundResume")

    /// Qué hacer con la vuelta a `.active`, dado si la app ya está activa.
    enum Decision: Equatable {
        case now
        case waitForActivation
    }

    nonisolated static func decide(applicationIsActive: Bool) -> Decision {
        applicationIsActive ? .now : .waitForActivation
    }

    #if DEBUG
    /// Esperas que hubo en este proceso. Solo para medir (tests y traza).
    private(set) static var deferredCount = 0
    #endif

    /// Corre `resume` ahora si la app está activa; si no, en cuanto lo esté. `site` nombra la pantalla en el rastro.
    static func whenApplicationActive(
        _ site: String,
        isApplicationActive: (() -> Bool)? = nil,
        center: NotificationCenter = .default,
        _ resume: @escaping @MainActor () -> Void
    ) {
        // El valor real se lee aquí dentro, en el main actor: como argumento por defecto se evaluaría fuera.
        let isActive = isApplicationActive?() ?? (UIApplication.shared.applicationState == .active)
        switch decide(applicationIsActive: isActive) {
        case .now:
            resume()
        case .waitForActivation:
            #if DEBUG
            deferredCount += 1
            print("ForegroundResume: \(site) — escena activa con la app sin activar; espero a didBecomeActive")
            #endif
            logger.notice("DEFERRED \(site, privacy: .public)")
            let box = ObserverBox()
            box.token = center.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    guard let token = box.token else { return }
                    center.removeObserver(token)
                    box.token = nil
                    logger.notice("RESUMED \(site, privacy: .public)")
                    resume()
                }
            }
        }
    }

    /// El observador se quita a sí mismo al primer aviso: una espera, una vuelta.
    private final class ObserverBox: @unchecked Sendable {
        var token: NSObjectProtocol?
    }
}
