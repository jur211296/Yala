//
//  RelaunchNetLogic.swift
//  Yala
//
//  Decisión pura de las redes de relaunch terminal (fix carrera de anchors 2026-07-14).
//
//  Contexto: los covers terminales de relaunch (sign-out `.cloud`/secundario M1 y ventana
//  de ENTRADA secundaria) presentaban desde DOS anchors ante el mismo observable — UIKit
//  no presenta dos veces y la reconciliación puede tumbar AMBAS cadenas dejando el flag en
//  `true` sin onDismiss (red muerta, app usable con el wipe de boot armado). El fix hace al
//  root DUEÑO ÚNICO de la presentación y VERIFICA presentación efectiva: solo el `onAppear`
//  del contenido real prueba que UIKit presentó; si no llegó, la red reintenta (toggle
//  false→true) según `verdict`. `exit(0)` en background es la red final (decisión owner UX).
//

import SwiftUI

enum RelaunchNetLogic {

    // MARK: - Verify loop (verificación de presentación efectiva)

    enum Verdict: Equatable {
        /// La condición de relaunch ya no está armada — nada que presentar.
        case standDown
        /// El `onAppear` del contenido real disparó — el cover está presentado de verdad.
        case satisfied
        /// El cover no apareció y quedan intentos — re-presentar (toggle false→true).
        case retry
        /// Cap de intentos agotado — algo tapa el anchor perpetuamente. El blocker vivo
        /// de la matriz sigue conteniendo el router y el exit-on-background es la red final.
        case exhausted
    }

    /// Primer chequeo tras armar: cubre la animación de dismiss de la sheet de Profile
    /// (~0.35s) y la de presentación del cover — jamás se toggla un cover a medio animar.
    static let initialVerifyDelay: Duration = .milliseconds(800)
    /// Cadencia entre reintentos (> duración de la animación de presentación ~0.35s).
    static let retryInterval: Duration = .seconds(1)
    /// El toggle false→true necesita un runloop turn — en la misma transaction SwiftUI
    /// coalesce a no-op y jamás re-presentaría.
    static let toggleGap: Duration = .milliseconds(50)
    /// Cap por CICLO (~9s), no de por vida: volver a foreground arma un ciclo fresco.
    static let maxAttempts = 8

    static func verdict(armed: Bool, coverDidAppear: Bool, attempt: Int) -> Verdict {
        guard armed else { return .standDown }
        // El cover vivo gana SIEMPRE, incluso con attempt > cap (jamás togglar un cover real).
        guard !coverDidAppear else { return .satisfied }
        return attempt < maxAttempts ? .retry : .exhausted
    }

    // MARK: - Exit-on-background (decisión owner 2026-07-14)

    /// `true` = terminar el proceso (`exit(0)`): la app pasó a background con un relaunch
    /// terminal pendiente — el próximo launch corre el cleanup pre-mount y aterriza donde
    /// corresponde, sin pedirle al usuario que mate la app. Solo `.background` (jamás
    /// `.inactive`: app switcher/notification center no deben matar el proceso).
    static func shouldExitOnBackground(
        scenePhase: ScenePhase,
        signOutPhase: CloudSessionSignOut.Phase,
        secondaryEntryArmedUnmounted: Bool
    ) -> Bool {
        scenePhase == .background
            && (signOutPhase == .awaitingRelaunch || secondaryEntryArmedUnmounted)
    }
}
