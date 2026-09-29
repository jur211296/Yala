//
//  RootTabLayoutLogic.swift
//  Yala
//
//  Qué pestañas enseña la raíz y en qué orden, según el espacio de la ventana (ADR «Yala se adapta por
//  espacio, no por dispositivo»).
//
//  **Las pestañas que no tocan se QUITAN de la `TabView`, no se ocultan con `.hidden(_:)`.** Medido el
//  2026-09-29: con una pestaña oculta seleccionada, UIKit aborta la app (`-[_UITabModel _setSelectedItem:…]`,
//  NSInternalInconsistency). Y la selección apunta a una pestaña que no se ve más a menudo de lo que parece:
//  Panel en la shell de solo grupos, Buscar durante los 50 ms de una pestaña temporal, Más al ensanchar la
//  ventana. Quitada, la `TabView` lo tolera, que es como funcionaba antes de esta fase.
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

    /// Las páginas que monta la `TabView`, en orden.
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
