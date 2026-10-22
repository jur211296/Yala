//
//  RootTabLayoutLogic.swift
//  Yala
//
//  Qué pestañas enseña la raíz y en qué orden, según el espacio de la ventana (ADR «Yala se adapta por
//  espacio, no por dispositivo»).
//
//  **Las seis páginas se montan desde el primer arranque; la barra de pestañas OCULTA las que no tocan, nunca la
//  seleccionada** (`mountedTabs`, `hiddenTabs`). Las dos mitades están medidas el 2026-09-29 y tiran en sentidos
//  opuestos: una pestaña añadida al ensanchar la ventana no tiene controlador hasta que se visita y tumba la app al
//  estrecharla (ver `mountedTabs`); una pestaña oculta y SELECCIONADA también la tumba
//  (`-[_UITabModel _setSelectedItem:…]`, NSInternalInconsistency). Por eso `shownTabs` incluye siempre la
//  seleccionada, y lo que la selección puede señalar sin verse —Panel en la shell de solo grupos, Buscar durante los
//  50 ms de una pestaña temporal, Más al ensanchar— se QUITA en vez de ocultarse.
//
//  Para que redimensionar no desmonte lo abierto, la página SELECCIONADA sigue en la barra de pestañas aunque
//  no esté en la configuración, y el orden es el mismo en los dos tamaños (misma identidad por pestaña).
//

import Foundation

enum RootTabLayoutLogic {
    /// Forma de la raíz.
    enum Layout: Equatable {
        /// Barra de pestañas de siempre: la configuración del usuario, la pestaña temporal, Más y Buscar.
        case tabBar
        /// Ventana de ancho regular: barra lateral con todas las páginas y Buscar; sin Más.
        case sidebar
    }

    /// `isRegularWidth` es el size class horizontal de la ventana. La shell de solo grupos se queda con la
    /// barra de pestañas en cualquier ancho: ahí solo Grupos es alcanzable y Más lleva la activación.
    static func layout(isRegularWidth: Bool, reduceToGroupsOnly: Bool) -> Layout {
        isRegularWidth && !reduceToGroupsOnly ? .sidebar : .tabBar
    }

    /// Todas las páginas, primero en el orden del usuario y luego el resto en el orden del catálogo. Es el
    /// MISMO orden en los dos tamaños, para que redimensionar no reordene (ni desmonte) nada.
    static func orderedTabs(activeTabs: [ConfigurableTab]) -> [ConfigurableTab] {
        activeTabs + ConfigurableTab.allCases.filter { !activeTabs.contains($0) }
    }

    /// Las páginas que se VEN, en orden (las demás montadas van ocultas: `hiddenTabs`).
    ///
    /// - Barra lateral: todas (`orderedTabs`).
    /// - Barra de pestañas: las de antes de esta fase (`tabBarTabs`: configuración + temporal) y, si la página
    ///   seleccionada no está entre ellas, también esa. En un iPhone la seleccionada ya está siempre (la pone
    ///   `selectMainTab` como temporal), así que no cambia nada; al ESTRECHAR la ventana de un iPad con Registros
    ///   abierto —que no está en la configuración por defecto— es lo que evita desmontarlo con el registro dentro.
    ///   No en la shell de solo grupos: ahí solo Grupos es alcanzable y la selección puede quedarse en Panel.
    static func shownTabs(
        layout: Layout,
        orderedTabs: [ConfigurableTab],
        tabBarTabs: [ConfigurableTab],
        selected: AppTab,
        reduceToGroupsOnly: Bool
    ) -> [ConfigurableTab] {
        if layout == .sidebar { return orderedTabs }
        guard !reduceToGroupsOnly,
              let selectedPage = selected.asConfigurable,
              !tabBarTabs.contains(selectedPage)
        else { return tabBarTabs }
        return tabBarTabs + [selectedPage]
    }

    /// Las páginas que la `TabView` MONTA, en orden: las seis, en los dos tamaños, salvo en la shell de solo grupos.
    ///
    /// **Montadas desde el primer arranque, no añadidas al ensanchar.** Medido el 2026-09-29 (iPad Pro 13, iOS 27.0):
    /// al estrechar la ventana, UIKit reconstruye la barra con las pestañas que tenía en la lateral y mete el ítem de
    /// cada una de las cuatro primeras. Una pestaña que SwiftUI añadió con la barra lateral ya puesta no tiene
    /// controlador —ni ítem— hasta que se visita, y ese `nil` tumba la app
    /// (`-[UITabBarController _tabs_rebuildTabBarItemsAnimated:]`, `insertObject:atIndex:: object cannot be nil`).
    /// Las que ya estaban en el primer montaje sí lo tienen. Por eso la barra de pestañas OCULTA las que no tocan
    /// (`hiddenTabs`) en vez de quitarlas.
    ///
    /// En la shell de solo grupos se siguen quitando: ahí la selección puede quedarse en Panel, y una pestaña oculta
    /// y seleccionada también tumba la app (`-[_UITabModel _setSelectedItem:…]`, fase 1).
    static func mountedTabs(
        orderedTabs: [ConfigurableTab],
        tabBarTabs: [ConfigurableTab],
        reduceToGroupsOnly: Bool
    ) -> [ConfigurableTab] {
        reduceToGroupsOnly ? tabBarTabs : orderedTabs
    }

    /// Las páginas montadas que la barra de pestañas no enseña: las que no están en `shownTabs`. Nunca la
    /// seleccionada —`shownTabs` la incluye siempre—, porque una pestaña oculta y seleccionada tumba la app.
    /// En la lateral, ninguna.
    static func hiddenTabs(mounted: [ConfigurableTab], shown: [ConfigurableTab]) -> [ConfigurableTab] {
        mounted.filter { !shown.contains($0) }
    }

    /// Más solo existe en la barra de pestañas: en la lateral, todo lo que ofrecía ya está a la vista.
    static func showsMoreTab(layout: Layout) -> Bool {
        layout == .tabBar
    }

    /// Buscar: en la barra de pestañas se retira cuando la pestaña temporal llevaría la barra a seis
    /// elementos (el iPhone pinta cinco y el resto cae al «Más» nativo). En la lateral no hay tope.
    static func showsSearchTab(layout: Layout, tabBarTabCount: Int) -> Bool {
        layout == .sidebar || tabBarTabCount <= 3
    }
}
