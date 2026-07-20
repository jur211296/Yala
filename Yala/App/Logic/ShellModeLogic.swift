//
//  ShellModeLogic.swift
//  Yala
//
//  Derivador ÚNICO del modo EFECTIVO de la shell (tab bar + visibilidad de secciones
//  personales) a partir de `OnboardingMode` + `UsageFocus`. Pure-logic, testeado con tabla.
//
//  IMPORTANTE: alimenta SOLO los gates de SHELL/visibilidad (tab bar, dashboard de «Más»,
//  sección «Organización» de Ajustes). Los gates de BEHAVIOR/BRIDGE (bridge de gastos de
//  grupo, routing de restore, segmento de telemetría) DEBEN seguir leyendo
//  `isGroupInviteMode` — un usuario `.groupsOnly` TIENE store personal (a diferencia de un
//  group-invite legado) y su semántica de datos no cambia.
//

import Foundation

/// El modo efectivo de la SHELL.
nonisolated enum ShellMode: Equatable {
    /// App completa (tab bar configurable, dashboard y organización visibles).
    case full
    /// Shell reducida a la pestaña Grupos (+ Más + Buscar).
    case groupsFocused
}

nonisolated enum ShellModeLogic {
    /// `.groupsFocused` cuando el usuario llegó por invitación (`onboardingMode == .groupInvite`)
    /// O eligió «Solo mis grupos» (`usageFocus == .groupsOnly`); `.full` en caso contrario.
    ///
    /// Byte-idéntico a `onboardingMode == .groupInvite` (== `isGroupInviteMode`) cuando
    /// `usageFocus == .full` (default) — así los gates de shell no cambian para usuarios
    /// existentes hasta que D1 setee `.groupsOnly`.
    static func effective(onboardingMode: OnboardingMode, usageFocus: UsageFocus) -> ShellMode {
        (onboardingMode == .groupInvite || usageFocus == .groupsOnly) ? .groupsFocused : .full
    }
}
