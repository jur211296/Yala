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
