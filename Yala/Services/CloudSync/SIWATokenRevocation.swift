//
//  SIWATokenRevocation.swift
//  Yala
//
//  SEAM (no-op) de revocación del token de Sign in with Apple al ELIMINAR la cuenta (G5-D1b).
//
//  PENDIENTE-OWNER (GATE DE FLAGS): Apple App Store Review Guideline 5.1.1(v) exige que, al ofrecer
//  "eliminar cuenta" a un usuario que se autenticó con Sign in with Apple, la app REVOQUE los tokens vía
//  el endpoint de revocación de Apple (`https://appleid.apple.com/auth/revoke`). Eso requiere firmar un
//  `client_secret` JWT server-side con la key SIWA (.p8) — la carga/gestión del .p8 y el endpoint de
//  revocación son DECISIÓN Y CARGA DEL OWNER (misma key que la memoria `reference_siwa_key_yala`). Hasta
//  entonces este seam es un no-op consciente: el flujo de borrado NO depende de él para su correctitud
//  (los datos y la identidad de perfil mueren igual vía `delete_personal_account`), pero DEBE aterrizar
//  antes de encender el flag de cuenta en producción para cumplir 5.1.1(v).
//

import Foundation

@MainActor
enum SIWATokenRevocation {

    /// Revoca el token de SIWA si aplica. HOY: no-op (ver el header). Best-effort por diseño — jamás
    /// bloquea ni falla el borrado de cuenta (la revocación es un requisito de review, no de correctitud
    /// del wipe). Cuando el owner cablee la revocación real, este método NO debe lanzar hacia el caller.
    static func revokeIfNeeded() async {
        // no-op — PENDIENTE-OWNER 5.1.1(v). Ver el header del archivo.
    }
}
