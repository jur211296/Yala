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
    /// `.groupsFocused` cuando no hay sesión privada en este dispositivo, **o** cuando la hay y la persona eligió
    /// «Solo grupos» en «Cómo usas Yala»; `.full` en el resto.
    ///
    /// **Una sesión nacida en la nube tiene vida personal y por eso sale `.full`**: la marca la
    /// enciende el onboarding personal, que toda alta completa recorre — sea privada o en la nube. Las
    /// cuatro celdas del ADR §2 se reparten así sin ningún término más.
    ///
    /// **El segundo término es solo de VISTA** (card p0iu, 2026-10-26): `GroupsOnlyViewMark` reduce la shell sin
    /// apagar la sesión privada, así que los gates de DATOS —que leen el eje directamente— no cambian. Sin término por
    /// defecto a propósito: un llamador nuevo que lo olvidara pintaría la app completa a quien eligió solo grupos.
    static func effective(hasPrivateSession: Bool, prefersGroupsOnlyView: Bool) -> ShellMode {
        guard hasPrivateSession else { return .groupsFocused }
        return prefersGroupsOnlyView ? .groupsFocused : .full
    }
}
