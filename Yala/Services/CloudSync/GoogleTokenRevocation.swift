//
//  GoogleTokenRevocation.swift
//  Yala
//
//  Revocación del grant OAuth de Google al ELIMINAR la cuenta (sesión 3 del brief congelado
//  BRIEF-GOOGLE-SIGNIN-V1, decisión owner #4) — espejo estructural de `SIWATokenRevocation` (paso 4a).
//  Guideline 5.1.1(v) formalmente solo exige el revoke de SIWA; Google entra por la frase "credentials
//  or tokens off of the device" + simetría ante App Review. A diferencia de SIWA no hay canje ni Worker:
//  el SDK GoogleSignIn custodia sus propios tokens y `GIDSignIn.disconnect()` revoca el grant COMPLETO
//  (y firma out) en un solo paso — el par custodiado (`GoogleUserPairStore`, sesión 1) solo aporta el
//  MATCH, no el token.
//
//  MATCH DOBLE (§0 del plan — endurece el molde B1, que matchea solo por appleUserID):
//    (1) `pair.sub == currentSub` — el par es de ESTA cuenta Supabase (la que se está borrando). Cierra
//        el hazard cross-cuenta M1: un par residual del DUEÑO bajo la secundaria jamás revoca al dueño.
//    (2) `sdkUserID == pair.googleUserID` — la sesión del SDK es DEL MISMO humano que el par. Cierra el
//        hazard que el sub NO cubre: tras un sign-out de A, el `signIn` del SDK de B puede TRIUNFAR con
//        el exchange de Supabase FALLIDO (el catch re-lanza sin deshacer la sesión SDK) ⇒ sesión SDK =
//        B, par = A. Si A borra su cuenta después, `disconnect()` sin este match revocaría el grant de B.
//  Cualquier mismatch ⇒ no-op SIN disconnect y SIN limpiar el par.
//
//  Contrato best-effort INTACTO (molde B1): jamás lanza ni bloquea el borrado. El par NO se limpia en
//  skip/fallo (retry posible vía `.failed(.localClose)` del borrado — mismo matiz que SIWA); solo el
//  disconnect exitoso lo limpia. Ciclo de vida del par: sobrevive el sign-out normal y la frontera M1
//  (credencial del PROVIDER, no de la sesión — verificado 2026-07-16: ni `CloudSessionSignOut` ni
//  `SecondarySessionBoundaryPurge` tocan `GoogleUserPairStore`/`com.yala.cloudauth`); re-sign-in lo
//  sobreescribe (clear-before-write). Residual documentado (D1 del plan de sesión 1): post-reinstalación
//  no hay sesión SDK restaurable ⇒ skip `no-sdk-session` — el grant queda vivo pero el token es inerte.
//

import Foundation
import GoogleSignIn

@MainActor
enum GoogleTokenRevocation {

    /// Tope del revoke best-effort (offline → se abandona sin limpiar el par; un retry del borrado —
    /// idempotente — lo reintenta; en el peor caso el grant queda vivo con token inerte, jamás filtrado).
    static let revokeTimeout: Duration = .seconds(4)

    /// Dependencias inyectables (molde `SIWATokenRevocation.Dependencies` — tests sin singleton).
    struct Dependencies {
        var readPair: @MainActor () -> GoogleUserPairStore.Pair?
        /// `sub` de la sesión Supabase VIGENTE (match #1). En el paso 4b del borrado la sesión sigue
        /// viva (el JWT no muere con el HARD DELETE — verificación stateless).
        var currentSub: @MainActor () -> String?
        /// `userID` del usuario del SDK: `currentUser`, o el restaurado si `hasPreviousSignIn()` — el
        /// restore refresca tokens si expiraron (VA A RED, por eso corre DENTRO del tope de 4s).
        var sdkUserID: @MainActor () async -> String?
        /// `disconnect()` del SDK (revoca el grant OAuth completo y firma out) → `true` solo si no lanzó.
        var disconnect: @MainActor () async -> Bool
        var clearPair: @MainActor () -> Void

        nonisolated static let live = Dependencies(
            readPair: { GoogleUserPairStore().read() },
            currentSub: { CloudAuthService.shared.currentUserID },
            sdkUserID: {
                if let userID = GIDSignIn.sharedInstance.currentUser?.userID {
                    return userID
                }
                guard GIDSignIn.sharedInstance.hasPreviousSignIn() else { return nil }
                do {
                    // Restaura (y deja como `currentUser`, sobre el que opera `disconnect()`) la sesión
                    // SDK persistida. Firma verificada contra GIDSignIn.h 9.2.0.
                    return try await GIDSignIn.sharedInstance.restorePreviousSignIn().userID
                } catch {
                    // Traducción EXPLÍCITA fallo→nil del contrato best-effort (no un silenciamiento):
                    // sin sesión restaurable el flujo hace skip documentado (`no-sdk-session`).
                    #if DEBUG
                    print("GoogleTokenRevocation: restorePreviousSignIn falló: \(error)")
                    #endif
                    return nil
                }
            },
            disconnect: {
                do {
                    try await GIDSignIn.sharedInstance.disconnect()
                    return true
                } catch {
                    #if DEBUG
                    print("GoogleTokenRevocation: disconnect falló: \(error)")
                    #endif
                    return false
                }
            },
            clearPair: { GoogleUserPairStore().clear() }
        )
    }

    /// Revoca el grant OAuth de Google si aplica (paso 4b del borrado, tras el 4a de SIWA). Best-effort
    /// por diseño — JAMÁS lanza ni bloquea el borrado de cuenta hacia el caller.
    static func revokeIfNeeded() async {
        await revokeIfNeeded(deps: .live)
    }

    /// Cuerpo testeable con deps inyectadas.
    static func revokeIfNeeded(deps: Dependencies) async {
        guard let pair = deps.readPair() else {
            // Sin par custodiado: sesión previa al capture, capture saltado (googlePairCaptureSkipped)
            // o cuenta que jamás firmó con Google (el caso masivo — el 4b tiene skip natural).
            CloudSyncBreadcrumb.googleRevokeSkipped(reason: "no-pair")
            return
        }

        // Match #1 (§0): el par debe ser de ESTA cuenta Supabase. Par de OTRA cuenta (p.ej. residuo del
        // dueño bajo la secundaria M1) → no-op SIN disconnect y SIN limpiar (sigue válido para su dueño).
        guard let currentSub = deps.currentSub(), currentSub == pair.sub else {
            CloudSyncBreadcrumb.googleRevokeSkipped(reason: "stale-pair")
            return
        }

        // Carrera (sdkUserID [posible restore con red] + disconnect) vs timeout 4s — molde EXACTO de
        // `SIWATokenRevocation.revokeIfNeeded`. AJUSTE A2 del /review-plan: el enum distingue skip ≠
        // fallo — un skip es estado legítimo (sin canario, sin limpiar); solo `.failed` (disconnect
        // rechazado o timeout) dispara el canario.
        let result: RevokeRace = await withTaskGroup(of: RevokeRace.self) { group in
            group.addTask { @MainActor in
                guard let sdkUserID = await deps.sdkUserID() else { return .skippedNoSDKSession }
                // Match #2 (§0): la sesión SDK debe ser DEL MISMO humano que el par — JAMÁS disconnect
                // sobre la sesión de otro (revocaría SU grant, no el de la cuenta que se borra).
                guard sdkUserID == pair.googleUserID else { return .skippedStaleSDKSession }
                // AJUSTE A3: si el disconnect falla tras un restore EXITOSO, la sesión SDK restaurada
                // (de la cuenta ya borrada) no queda huérfana — la barre el paso 4c del borrado (cierre
                // local → `CloudAuthService.signOut()` → `GIDSignIn.signOut()` local).
                return await deps.disconnect() ? .disconnected : .failed
            }
            group.addTask {
                try? await Task.sleep(for: revokeTimeout)
                return .failed
            }
            let first = await group.next() ?? .failed
            group.cancelAll()
            return first
        }

        switch result {
        case .disconnected:
            // Éxito → el par muere con la cuenta (NO limpiar en fallo: queda custodiado para un retry).
            deps.clearPair()
            CloudSyncBreadcrumb.googleDisconnected()
        case .skippedNoSDKSession:
            // Post-reinstalación / SDK sin sesión persistida: grant vivo pero token inerte (residual
            // documentado). Estado legítimo — sin canario, sin limpiar.
            CloudSyncBreadcrumb.googleRevokeSkipped(reason: "no-sdk-session")
        case .skippedStaleSDKSession:
            CloudSyncBreadcrumb.googleRevokeSkipped(reason: "stale-sdk-session")
        case .failed:
            // Rechazo del SDK o timeout — colapsados en un solo reason (la carrera no los distingue;
            // paridad con SIWA, que colapsa ambos en `revoke`).
            CloudSyncBreadcrumb.googleRevokeFailed(reason: "disconnect")
            TelemetryService.googleRevokeFailed(reason: "disconnect")
        }
    }

    /// Resultado interno de la carrera (AJUSTE A2): skip ≠ fallo — los skips son estados legítimos que
    /// JAMÁS disparan el canario; `.failed` = disconnect rechazado o timeout.
    private enum RevokeRace: Sendable {
        case skippedNoSDKSession
        case skippedStaleSDKSession
        case disconnected
        case failed  // disconnect rechazado / timeout
    }
}
