//
//  ShellModeLogic.swift
//  Yala
//
//  Derivador ÚNICO del modo EFECTIVO de la shell (tab bar + visibilidad de secciones personales).
//
//  **Desde el 2026-09-13 la shell tiene UNA sola fuente: el eje 1 del ADR 2026-09-09 «Sesiones — dos
//  ejes» (`PrivateSessionMark`).** Antes eran dos flags —«por dónde entró esta persona» y «qué
//  eligió usar»— y ninguno de los dos decía lo que la shell
//  necesita saber. Preguntarlo en dos sitios distintos es como una vista acababa pintando pestañas que
//  otra escondía; la pregunta real siempre fue la misma: **¿esta persona tiene vida personal en este
//  teléfono?** Si no la tiene, Yala es Grupos y nada más.
//
//  IMPORTANTE: esto alimenta SOLO los gates de SHELL/visibilidad (tab bar, dashboard de «Más», sección
//  «Organización» de Ajustes). Los gates de datos —si el bridge corre, qué se borra al cerrar sesión—
//  leen el eje directamente y no pasan por aquí.
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
    /// `.groupsFocused` cuando no hay sesión privada en este dispositivo; `.full` en caso contrario.
    ///
    /// **Una sesión nacida en la nube tiene vida personal y por eso sale `.full`**: la marca la
    /// enciende el onboarding personal, que toda alta completa recorre — sea privada o en la nube. Las
    /// cuatro celdas del ADR §2 se reparten así sin ningún término más.
    static func effective(hasPrivateSession: Bool) -> ShellMode {
        hasPrivateSession ? .full : .groupsFocused
    }
}
