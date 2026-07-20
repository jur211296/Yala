//
//  GroupsSignOutBannerMarker.swift
//  Yala
//
//  Marker one-shot del banner de re-entrada del tab Grupos (D2, §3.3.3). Tras un "Cerrar sesión de
//  grupos" (`.groupsOnlySignOut`), al reabrir la app el empty state H-7 ("tus grupos están en tu
//  cuenta") lleva un banner one-shot ("Cerraste tu sesión de grupos…"). El marker se ARMA en
//  `CloudSessionSignOut.finalizeGroupsOnlyClose` (in-session, sobrevive el exit(0)+relaunch por vivir
//  en UserDefaults), se QUEMA en el `onAppear` del banner real (regla de one-shots del repo — jamás en
//  el productor ni en el drain) y se DESARMA si el usuario re-firma sesión de grupos (belt: un banner
//  "cerraste tu sesión" es stale tras re-firmar).
//
//  DEVICE-GLOBAL (como el resto de `cloudSync.*`): el sweep de sign-out no lo toca. Persiste inerte
//  hasta que el banner se muestra una vez; solo surge cuando el empty state H-7 está activo (flag ON +
//  sin sesión), así que un marker colgado es inofensivo. Flag OFF ⇒ jamás se arma (byte-idéntico).
//

import Foundation

nonisolated enum GroupsSignOutBannerMarker {

    static let key = "cloudSync.groupsSignOut.pendingReentryBanner"

    /// Arma el banner (al finalizar el cierre solo-grupos, in-session antes del relaunch).
    static func markPending(_ defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key)
    }

    /// `true` si hay un banner de re-entrada pendiente de mostrar.
    static func isPending(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }

    /// Quema el marker (en el `onAppear` del banner real) o lo desarma (al re-firmar sesión).
    static func clear(_ defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
