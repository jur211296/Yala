//
//  GroupsBetaGateLogic.swift
//  Yala
//
//  Pure decision logic para el gate de código beta del tab Grupos. Grupos se
//  libera en producción de forma controlada (validación de la v2.0.1): nadie
//  entra sin el código beta, salvo quien llega por enlace de invitación.
//
//  Gate TEMPORAL — se removerá al estabilizar la 2.0.1.
//
//  Extraído como pure-logic para tests sin SwiftData ni UI (sin flake R8 conocido
//  por `makeTestContext()`). Patrón análogo a `GroupsOnboardingLogic`.
//

import Foundation

enum GroupsBetaGateLogic {

    /// Código beta numérico que desbloquea el acceso a Grupos.
    static let betaCode = "1050"

    /// `true` si el texto ingresado coincide con el código beta. Trim defensivo:
    /// `.numberPad` no garantiza solo-dígitos (teclados de terceros, pegado).
    static func isValidCode(_ input: String) -> Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines) == betaCode
    }

    /// Decide si mostrar el gate de bloqueo en lugar del contenido de Grupos.
    /// - Parameters:
    ///   - isUnlocked: `AppPreferences.Keys.groupsBetaUnlocked` (per-device). Una vez
    ///     `true` (código correcto o invitación aceptada), el gate no se muestra más.
    ///   - isGroupInviteMode: `SessionState.isGroupInviteMode`. Los invitados por enlace
    ///     entran sin código (exentos del gate).
    static func shouldShowGate(isUnlocked: Bool, isGroupInviteMode: Bool) -> Bool {
        !isDomainOpen(isUnlocked: isUnlocked, isGroupInviteMode: isGroupInviteMode)
    }

    /// ¿El dominio Grupos está ABIERTO para el usuario actual de ESTE dispositivo?
    ///
    /// Mismo predicado que `shouldShowGate`, invertido — SSOT deliberada: la puerta que decide
    /// si se VE Grupos es la misma que decide si un dispositivo SELLADO deja que el bridge
    /// materialice gastos de grupo en el corpus personal (ver `isBridgeAllowed`).
    static func isDomainOpen(isUnlocked: Bool, isGroupInviteMode: Bool) -> Bool {
        isUnlocked || isGroupInviteMode
    }

    /// ¿Puede el bridge materializar gastos de grupo en el corpus PERSONAL de este dispositivo?
    ///
    /// **El problema** (handover de dispositivo, hallazgos `E2-04`/`NEW-E2-01` de la auditoría de
    /// Modo Nube): los grupos viven en el iCloud del Apple ID, no en la cuenta Yala. Un usuario B
    /// que empieza de cero en el dispositivo de A —MISMO Apple ID— es indistinguible de A para
    /// TODA señal de identidad de CloudKit (`userRecordID`, `SplitMember.cloudKitUserRecordID`,
    /// `isCurrentUser`, que `refreshCurrentUserFlags` incluso re-afirma). La única señal
    /// disponible es de intención, no de identidad: quién declaró el relevo y quién adoptó Grupos
    /// después.
    ///
    /// **Por qué un SELLO y no un gate general.** Exigir el dominio abierto SIEMPRE habría
    /// bloqueado el bridge de todo usuario que aún no abrió Grupos —el estado por DEFECTO— con un
    /// falso negativo silencioso: el bug se convierte en «mis gastos de grupo no aparecen» y nadie
    /// sabe por qué. Así que el default es PERMITIR: solo el dispositivo que pasó por «empiezo de
    /// cero» (`DataWipeService.wipeLocalGroupsDomain` escribe
    /// `AppPreferences.Keys.groupsDomainSealedForFreshStart`) queda cerrado, hasta que su nuevo
    /// dueño adopte Grupos con un acto deliberado. Un dispositivo sin sello se comporta
    /// exactamente igual que antes de este fix.
    ///
    /// Con el sello puesto y la puerta cerrada, el corpus de grupos que el motor re-descargue de
    /// iCloud queda INERTE para la vida personal: nada de Panel, Inbox, presupuestos, reportes ni
    /// widgets.
    static func isBridgeAllowed(
        sealedForFreshStart: Bool, isUnlocked: Bool, isGroupInviteMode: Bool
    ) -> Bool {
        guard sealedForFreshStart else { return true }
        return isDomainOpen(isUnlocked: isUnlocked, isGroupInviteMode: isGroupInviteMode)
    }
}
