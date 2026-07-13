//
//  CrossAccountEntryGuardLogic.swift
//  Yala
//
//  Pure-logic del guard cross-cuenta en el sign-in de nube desde el Welcome
//  (decisión owner 2026-07-12, degradación F0-C autorizada).
//
//  Un Apple ID DISTINTO al dueño del corpus local JAMÁS debe adoptar sobre esos
//  datos: el orphan-reconcile del adopt corre ANTES del relaunch y pushearía las
//  filas del dueño a la cuenta entrante (mezcla cross-cuenta — la clase de
//  incidente que `runtimeBlockedByUnclaimedIdentity` existe para impedir).
//  v1 BLOQUEA ese camino (aun con limpieza, el remount mirror-ON re-importaría el
//  iCloud del dueño). La solución real son las sesiones invitadas aisladas (M1/I7c)
//  — spike documentado en el vault.
//
//  La MISMA cuenta re-entra libre: su claim persistido (CloudClaimActionStore,
//  keyed por userID, sobrevive el sign-out a propósito) es la prueba de que el
//  corpus local le pertenece.
//

import Foundation

nonisolated enum CrossAccountEntryGuardLogic {

    enum Decision: Equatable {
        /// Device limpio o misma cuenta → continuar al adopt.
        case proceed
        /// Datos locales de otra identidad → BLOQUEADO en v1. El caller debe hacer
        /// `signOut()` antes de volver al chooser (no dejar sesión SIWA colgada).
        case blockedForeignData
    }

    /// - Parameters:
    ///   - hasLocalData: hay corpus personal en el device (transacciones/cuentas).
    ///   - sameAccountClaimExists: el claim-store tiene registro para el userID que
    ///     acaba de firmar (⇒ este corpus ya fue reclamado por ESTA cuenta).
    static func decide(hasLocalData: Bool, sameAccountClaimExists: Bool) -> Decision {
        guard hasLocalData else { return .proceed }
        return sameAccountClaimExists ? .proceed : .blockedForeignData
    }
}
