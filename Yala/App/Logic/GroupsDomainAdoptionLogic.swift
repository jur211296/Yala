//
//  GroupsDomainAdoptionLogic.swift
//  Yala
//
//  Pure decision logic del gate de ADOPCIÓN del dominio Grupos: ¿este dispositivo, que declaró
//  «aquí empieza un usuario nuevo», deja que el bridge materialice gastos de grupo en el corpus
//  personal?
//
//  **Antes fue `GroupsBetaGateLogic` y era SSOT de DOS preguntas** —si se VE Grupos y si el bridge
//  escribe en un dispositivo SELLADO—. La primera murió en 2.1 con el código beta «1050» (decisión
//  del owner: Grupos abierto para todos), y de aquel gate no queda ni la pantalla, ni el modifier de
//  ingreso del código, ni sus 6 keys de l10n. **La segunda sigue viva y es la razón de este fichero.**
//  Si vuelves buscando dónde se decide si el tab se ve: ya no se decide en ningún sitio, se ve
//  siempre.
//
//  La key de `UserDefaults` conserva su string histórico `"groupsBetaUnlocked"`
//  (`AppPreferences.Keys.groupsBetaUnlocked`): renombrarla obligaría a migrar el parque sin ganar
//  nada. Quien la ESCRIBE hoy es `GroupsDomainAdoptionMarker` (entrada al tab), el alta solo-grupos
//  y la entrada por invitación — todos actos de adopción deliberados.
//
//  Extraído como pure-logic para tests sin SwiftData ni UI (sin flake R8 conocido
//  por `makeTestContext()`). Patrón análogo a `GroupsOnboardingLogic`.
//

import Foundation

enum GroupsDomainAdoptionLogic {

    /// ¿El usuario actual de ESTE dispositivo ADOPTÓ el dominio Grupos con un acto deliberado?
    ///
    /// Dos términos, y los dos hacen falta: la adopción per-device
    /// (`AppPreferences.Keys.groupsBetaUnlocked`, escrita al entrar al tab, al aceptar una
    /// invitación o en el alta solo-grupos) y el modo solo-grupos vivo
    /// (`SessionState.isGroupInviteMode`, que ES una adopción: este dispositivo se dio de alta
    /// PARA grupos). Quitar el segundo cerraría el bridge al invitado normal, que es la mayoría.
    ///
    /// **No es un gate de visibilidad.** Solo lo consume `isBridgeAllowed`; colapsarlo a `true`
    /// deja `sealedForFreshStart` sin efecto observable y abre los 5 guards de
    /// `GroupTransactionBridge.isDomainOpenForBridge` a la vez.
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
    /// **Por qué un SELLO y no un gate general.** Exigir el dominio adoptado SIEMPRE habría
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
