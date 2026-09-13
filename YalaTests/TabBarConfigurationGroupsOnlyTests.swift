//
//  TabBarConfigurationGroupsOnlyTests.swift
//  YalaTests
//
//  `TabBarConfiguration.forMode` con el eje 1: `reduceToGroupsOnly` lo pasa el caller como
//  `effectiveShellMode == .groupsFocused`, o sea «no hay sesión privada en este teléfono». Sucede a
//  `TabBarConfigurationSecondaryTests`, que medía lo mismo más el filtro de la sesión de visita —
//  retirada el 2026-09-13.
//

import Foundation
import Testing

@testable import Yala

@Suite("TabBarConfiguration · la tab bar de una sesión solo-grupos")
struct TabBarConfigurationGroupsOnlyTests {

    @Test func reduceToGroupsOnly_forcesGroupsOnly() {
        // Quien no tiene vida personal aquí ve solo Grupos, diga lo que diga su config guardada.
        let stored = TabBarConfiguration(activeTabs: [.panel, .statistics, .planning])
        let config = TabBarConfiguration.forMode(stored: stored, reduceToGroupsOnly: true)
        #expect(config.activeTabs == [.groups])
    }

    @Test func reduceToGroupsOnly_false_keepsStored() {
        // Byte-idéntico: con sesión privada, la config custom manda.
        let stored = TabBarConfiguration(activeTabs: [.panel, .statistics, .planning])
        let config = TabBarConfiguration.forMode(stored: stored, reduceToGroupsOnly: false)
        #expect(config.activeTabs == [.panel, .statistics, .planning])
    }

    /// **La tab bar NO mira el canal de Grupos, y eso es una decisión con fecha** (2026-09-13). Hubo un
    /// filtro que quitaba la pestaña con el canal apagado; su sujeto era la sesión de visita, donde el
    /// motor estaba atado al Apple ID del dueño. Traducido al eje 1 se volvía contra el dueño de su
    /// propio teléfono: bajar el kill-switch de Grupos —o perder el snapshot de remote-config, que cae a
    /// fail-closed— le dejaba la app sin ninguna pantalla de contenido.
    ///
    /// Este caso es el que lo impide: la config de una sesión solo-grupos NO depende de ningún flag de
    /// canal, así que ningún incidente puede vaciarle la barra.
    @Test func laTabBarNoDependeDelCanalDeGrupos() {
        let config = TabBarConfiguration.forMode(stored: .default, reduceToGroupsOnly: true)
        #expect(config.activeTabs == [.groups], """
            la tab bar de una sesión solo-grupos volvió a depender de algo que no es el eje. Con el canal
            apagado, esta persona se queda sin una sola superficie de contenido.
            """)
    }
}
