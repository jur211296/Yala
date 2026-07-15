//
//  PushTokenSignOutSeam.swift
//  Yala
//
//  Seam G8 (APNs de grupos) — punto de extensión NO-OP del cierre de sesión. Cuando G8 aterrice
//  el push del canal de Grupos, este seam borrará/desregistrará el push token del device en el
//  sign-out (para que la cuenta saliente deje de recibir notificaciones de grupos en este device).
//
//  HOY es un no-op deliberado: se invoca desde TODOS los paths de `CloudSessionSignOut` que ya
//  cortan el canal de Grupos (`teardownForSignOut`), de modo que cuando G8 rellene el cuerpo, el
//  cableado del cierre ya está en su sitio (cero cambios en el coordinador). Idempotente y seguro
//  con el flag OFF.
//

import Foundation

@MainActor
enum PushTokenSignOutSeam {

    /// G8 lo rellena: desregistra/borra el push token del canal de Grupos para la sesión saliente.
    /// HOY no-op — invocado junto a `GroupsSyncClient.teardownForSignOut()` en cada path de sign-out.
    static func clearForSignOut() {
        // G8: borrar el push token del device del backend de grupos (RPC de desregistro) para
        // que la cuenta saliente no siga recibiendo notificaciones en este device.
    }
}
