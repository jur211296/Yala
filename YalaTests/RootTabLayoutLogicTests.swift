//
//  RootTabLayoutLogicTests.swift
//  YalaTests
//
//  La raíz decide su forma por el ancho de la VENTANA: barra lateral con todas las páginas en regular,
//  la barra de pestañas de siempre en compact. El orden de las pestañas es el mismo en los dos tamaños,
//  para que redimensionar no reordene ni desmonte nada.
//

import Testing

@testable import Yala

struct RootTabLayoutLogicTests {
    private typealias Logic = RootTabLayoutLogic

    // MARK: - layout

    @Test func regularWindow_usesSidebar() {
        #expect(Logic.layout(isRegularWidth: true, reduceToGroupsOnly: false) == .sidebar)
    }

    @Test func compactWindow_usesTabBar() {
        #expect(Logic.layout(isRegularWidth: false, reduceToGroupsOnly: false) == .tabBar)
    }

    /// Solo grupos: aunque la ventana sea ancha, la raíz sigue siendo la de hoy (Grupos + Más con la
    /// activación). Una barra lateral con todas las páginas enseñaría destinos que `selectMainTab` rechaza.
    @Test func groupsOnlyShell_keepsTabBar_evenInRegularWidth() {
        #expect(Logic.layout(isRegularWidth: true, reduceToGroupsOnly: true) == .tabBar)
    }

    // MARK: - orderedTabs

    @Test func orderedTabs_keepsUserOrderFirst_thenTheRest() {
        let ordered = Logic.orderedTabs(activeTabs: [.panel, .records, .statistics])
        #expect(ordered == [.panel, .records, .statistics, .planning, .reports, .groups])
    }

    @Test func orderedTabs_containsEveryPageOnce() {
        let ordered = Logic.orderedTabs(activeTabs: [.panel, .planning])
        #expect(Set(ordered) == Set(ConfigurableTab.allCases))
        #expect(ordered.count == ConfigurableTab.allCases.count)
    }

    // MARK: - shownTabs

    private let everyPage = RootTabLayoutLogic.orderedTabs(activeTabs: [.panel, .statistics, .planning])

    @Test func sidebar_showsEveryPage() {
        let shown = Logic.shownTabs(
            layout: .sidebar, orderedTabs: everyPage, tabBarTabs: [.panel], selected: .panel, reduceToGroupsOnly: false)
        #expect(shown == everyPage)
    }

    /// iPhone: la seleccionada ya está en la barra (la pone `selectMainTab`), así que sale lo de siempre.
    @Test func tabBar_withSelectedInside_isExactlyTheTabBarTabs() {
        let tabBarTabs: [ConfigurableTab] = [.panel, .statistics, .planning]
        for selected in [AppTab.panel, .statistics, .planning, .more, .search] {
            let shown = Logic.shownTabs(
                layout: .tabBar, orderedTabs: everyPage, tabBarTabs: tabBarTabs, selected: selected,
                reduceToGroupsOnly: false)
            #expect(shown == tabBarTabs)
        }
    }

    /// Estrechar la ventana con Registros abierto (no está en la configuración): sigue montada, al final.
    @Test func tabBar_keepsTheSelectedPageMounted() {
        let shown = Logic.shownTabs(
            layout: .tabBar, orderedTabs: everyPage, tabBarTabs: [.panel, .statistics, .planning], selected: .records,
            reduceToGroupsOnly: false)
        #expect(shown == [.panel, .statistics, .planning, .records])
    }

    /// Solo grupos: la selección puede quedarse en Panel, y Panel NO aparece.
    @Test func groupsOnlyShell_neverAddsTheSelectedPage() {
        let shown = Logic.shownTabs(
            layout: .tabBar, orderedTabs: everyPage, tabBarTabs: [.groups], selected: .panel, reduceToGroupsOnly: true)
        #expect(shown == [.groups])
    }

    // MARK: - mountedTabs / hiddenTabs (ticket ipad-narrowing-the-window-on-groups-crashes-the-app)

    /// Las seis páginas se montan en los dos tamaños y en el MISMO orden: una pestaña añadida al ensanchar no tiene
    /// controlador hasta que se visita, y al estrechar UIKit la mete en la barra y se cierra la app.
    @Test func mountedTabs_areEveryPage_inTheSameOrder_forAnyTabBarTabs() {
        for tabBarTabs: [ConfigurableTab] in [[.panel], [.panel, .statistics, .planning], [.panel, .statistics, .planning, .groups]] {
            let mounted = Logic.mountedTabs(orderedTabs: everyPage, tabBarTabs: tabBarTabs, reduceToGroupsOnly: false)
            #expect(mounted == everyPage)
        }
    }

    /// Solo grupos: se QUITAN las demás, no se ocultan. Ahí la selección puede quedarse en Panel, y una pestaña
    /// oculta y seleccionada tumba la app.
    @Test func mountedTabs_inGroupsOnlyShell_areOnlyTheTabBarTabs() {
        let mounted = Logic.mountedTabs(orderedTabs: everyPage, tabBarTabs: [.groups], reduceToGroupsOnly: true)
        #expect(mounted == [.groups])
    }

    /// En la barra de pestañas se ocultan las montadas que no se enseñan; la seleccionada nunca, aunque no esté en
    /// la configuración.
    @Test func hiddenTabs_inTabBar_areTheMountedOnesNotShown_neverTheSelected() {
        let tabBarTabs: [ConfigurableTab] = [.panel, .statistics, .planning]
        for selected in [AppTab.panel, .statistics, .planning, .records, .reports, .groups, .more, .search] {
            let shown = Logic.shownTabs(
                layout: .tabBar, orderedTabs: everyPage, tabBarTabs: tabBarTabs, selected: selected,
                reduceToGroupsOnly: false)
            let mounted = Logic.mountedTabs(orderedTabs: everyPage, tabBarTabs: tabBarTabs, reduceToGroupsOnly: false)
            let hidden = Logic.hiddenTabs(mounted: mounted, shown: shown)
            #expect(Set(hidden).isDisjoint(with: shown))
            #expect(Set(hidden).union(shown) == Set(mounted))
            if let page = selected.asConfigurable { #expect(!hidden.contains(page)) }
        }
    }

    /// Con Grupos seleccionado en una ventana estrecha: a la vista las tres de la configuración y Grupos; ocultas
    /// Registros y Reportes. Es el caso del ticket.
    @Test func hiddenTabs_narrowWindowWithGroups_hidesRecordsAndReports() {
        let shown = Logic.shownTabs(
            layout: .tabBar, orderedTabs: everyPage, tabBarTabs: [.panel, .statistics, .planning], selected: .groups,
            reduceToGroupsOnly: false)
        #expect(shown == [.panel, .statistics, .planning, .groups])
        #expect(Logic.hiddenTabs(mounted: everyPage, shown: shown) == [.records, .reports])
    }

    @Test func hiddenTabs_inSidebar_areNone() {
        let shown = Logic.shownTabs(
            layout: .sidebar, orderedTabs: everyPage, tabBarTabs: [.panel], selected: .panel, reduceToGroupsOnly: false)
        #expect(Logic.hiddenTabs(mounted: everyPage, shown: shown).isEmpty)
    }

    /// Solo grupos: nada oculto (lo que no toca ya no está montado).
    @Test func hiddenTabs_inGroupsOnlyShell_areNone() {
        let mounted = Logic.mountedTabs(orderedTabs: everyPage, tabBarTabs: [.groups], reduceToGroupsOnly: true)
        let shown = Logic.shownTabs(
            layout: .tabBar, orderedTabs: everyPage, tabBarTabs: [.groups], selected: .panel, reduceToGroupsOnly: true)
        #expect(Logic.hiddenTabs(mounted: mounted, shown: shown).isEmpty)
    }

    // MARK: - More / Search

    @Test func moreTab_onlyInTabBar() {
        #expect(Logic.showsMoreTab(layout: .tabBar))
        #expect(!Logic.showsMoreTab(layout: .sidebar))
    }

    /// El tope de cinco elementos de la barra del iPhone: con cuatro páginas (tres + la temporal), Buscar
    /// se retira. Los dos vecinos del umbral.
    @Test func searchTab_inTabBar_followsTheFiveItemLimit() {
        #expect(Logic.showsSearchTab(layout: .tabBar, tabBarTabCount: 3))
        #expect(!Logic.showsSearchTab(layout: .tabBar, tabBarTabCount: 4))
    }

    @Test func searchTab_inSidebar_alwaysShown() {
        #expect(Logic.showsSearchTab(layout: .sidebar, tabBarTabCount: 4))
    }
}
