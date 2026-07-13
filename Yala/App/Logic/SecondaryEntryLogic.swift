//
//  SecondaryEntryLogic.swift
//  Yala
//
//  Secuencia de escrituras de la ENTRADA a sesión secundaria (M1 Inc 6). El ORDEN es
//  kill-safety y está testeado — cada paso deja un estado recuperable:
//   1) claim (`.routeReturningUser`, keyed por userID) — ANTES del descriptor: si el descriptor
//      quedara sin claim, el guard P6 del runtime bloquearía la hidratación post-boot; un claim
//      huérfano SIN descriptor es inerte (el claim-store sobrevive sign-outs por diseño).
//   2) descriptor (`SecondarySessionStore.activate`) — el COMMIT POINT: kill antes = no pasó
//      nada (la invitada re-tapea); kill después = el boot monta el secundario igual.
//   3) flags de onboarding — la ventana 2→3 la sana el healing de
//      `performSecondaryEntryTasksIfNeeded` (Inc 2).
//
//  JAMÁS aquí: `startAdoptWithExistingSession`/`runAdoptFlow` (escribirían el PAR global
//  `.cloud`+`mirrorOffArmed` del dueño y correrían orphan-reconcile sobre SU store montado),
//  `signOut()` de la sesión SIWA (el runtime la necesita post-relaunch), ni purgas (las hace
//  el boot — única fuente kill-safe).
//

import Foundation

nonisolated enum SecondaryEntryLogic {

    /// Ejecuta los 3 pasos EN ORDEN. Closures inyectables (el test asserta la secuencia).
    static func begin(
        userID: String,
        recordClaim: (String) -> Void,
        activateDescriptor: (String) -> Void,
        markOnboardingFlags: () -> Void
    ) {
        recordClaim(userID)
        activateDescriptor(userID)
        markOnboardingFlags()
    }
}
