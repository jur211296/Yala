//
//  PushTokenSignOutSeam.swift
//  Yala
//
//  Seam G8 (APNs de grupos) — desregistro del push token del device en el cierre de sesión, para que la
//  cuenta saliente deje de recibir notificaciones de grupos en este device. Se invoca desde TODOS los paths
//  de `CloudSessionSignOut` que ya cortan el canal de Grupos (`teardownForSignOut`), ANTES de `signOut()`
//  (JWT vivo en el punto de invocación).
//
//  Gateado DURO por `CloudSyncFlags.groupsBackendEnabled` (byte-identidad flag-OFF): los paths `.cloud` son
//  alcanzables con el flag OFF y sesión viva, y sin el gate el seam pasaría de no-op a una llamada de red
//  (divergencia observable). Best-effort con TIMEOUT ACOTADO (offline, el default de URLSession ~60s
//  congelaría el diálogo de sign-out, que corre con `phase == .working` ANTES del signOut). JAMÁS lanza,
//  JAMÁS bloquea más allá del timeout.
//

import Foundation

@MainActor
enum PushTokenSignOutSeam {

    /// Tope del desregistro best-effort. Offline → se abandona al vencer (el server limpia igual en
    /// delete-account vía `groups_forget_user`; un token huérfano solo produce pushes que no-opean).
    static let unregisterTimeout: Duration = .seconds(4)

    // MARK: - Seams inyectables (defecto = cableado de producción; los override los usan los tests)

    static var client: PushTokenRegistrationClient = PushTokenRegistrationClient()
    static var hasSession: @MainActor () -> Bool = { CloudAuthService.shared.hasSession }
    /// El token capturado sobrevive al sign-out (sirve para re-registro con la próxima cuenta) — NO se borra.
    static var storedToken: @MainActor () -> String? = { PushTokenRegistrar.shared.storedToken }

    // MARK: - API

    /// Desregistra el push token de la sesión saliente (best-effort, timeout-acotado). No-op sin flag /
    /// sesión / token.
    static func clearForSignOut() async {
        guard CloudSyncFlags.groupsBackendEnabled, hasSession(),
              let token = storedToken(), !token.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                do {
                    try await client.unregister(deviceToken: token)
                } catch {
                    // Best-effort: offline / cancelado por el timeout / rechazo → log y seguir.
                    #if DEBUG
                    print("PushTokenSignOutSeam: unregister falló (best-effort, se abandona): \(error)")
                    #endif
                }
            }
            group.addTask {
                try? await Task.sleep(for: unregisterTimeout)
            }
            // El primero en terminar (el unregister o el timeout) libera; cancelamos el otro.
            await group.next()
            group.cancelAll()
        }
    }
}
