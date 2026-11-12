//
//  StatisticsFocusScroll.swift
//  Yala
//
//  UX 2.2 · L15-3 (opción B, Jürgen 2026-10-18): cada widget abre la pantalla que amplía lo que enseña. El de «Entradas
//  y salidas» abre Tendencias con esa tarjeta a la vista, y los de subcategorías abren Distribución con las
//  subcategorías, no la pestaña tal como estaba.
//

import SwiftUI

/// Atiende la parte de una pestaña de Estadísticas que pidió un enlace (`SceneNavigation.pendingStatisticsFocus`): si es
/// la suya, la consume y corre `perform` una vuelta del main actor después (en el primer `onAppear` el contenido aún no
/// está colocado y un salto del scroll se pierde).
struct StatisticsFocusHandler: ViewModifier {
    let focus: StatisticsDeepLink.Focus
    let perform: @MainActor () -> Void

    @Environment(SceneNavigation.self) private var navigation

    func body(content: Content) -> some View {
        content
            .onAppear { performIfRequested() }
            .onChange(of: navigation.pendingStatisticsFocus) { _, _ in performIfRequested() }
    }

    private func performIfRequested() {
        guard navigation.pendingStatisticsFocus == focus else { return }
        navigation.pendingStatisticsFocus = nil
        Task { @MainActor in perform() }
    }
}

/// Deja a la vista la parte pedida: va en el `ScrollView`, dentro de su `ScrollViewReader`; la parte lleva `.id(focus)`.
struct StatisticsFocusScroll: ViewModifier {
    let focus: StatisticsDeepLink.Focus
    let proxy: ScrollViewProxy

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.modifier(StatisticsFocusHandler(focus: focus) {
            dsWithAnimation(reduceMotion) { proxy.scrollTo(focus, anchor: .top) }
        })
    }
}
