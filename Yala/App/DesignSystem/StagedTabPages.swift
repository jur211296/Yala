//
//  StagedTabPages.swift
//  Yala
//
//  Las páginas de una fila de chips de navegación (detalle de grupo, Estadísticas), montadas para que el chip y la
//  página cambien a la vez (card pjum, 2026-10-31).
//
//  Antes (card yc6k) la fila se animaba primero y la página se montaba al terminar. Jürgen lo vio en el iPhone:
//  «primero cambia el chip y un segundo después la página cambia de golpe». Ahora, en dos tiempos al revés:
//  1. La página nueva se monta DEBAJO de la que se ve, invisible (`staged`). Montarla bloquea el hilo principal
//     (Estadísticas, 0,12–0,27 s en el iPhone), y ese bloqueo cae con la pantalla quieta: se sigue viendo la de antes.
//  2. Cuando ya está montada (su `onAppear`, una vuelta del main actor después), la página cambia y la fila empieza a
//     animarse en el mismo fotograma. Como la página ya está pintada, ningún bloqueo se come la animación de la fila.
//
//  **La página no se funde, y no por falta de ganas** (medido en vídeo el 2026-10-31, iOS 27.0): el título grande vive
//  dentro del scroll de la página, así que un fundido de la página funde también el título, y mientras la vieja sigue
//  montada la nueva no lo recibe: «Viaje a Cusco» desaparecía ~0,3 s. Por eso la vieja se desmonta en el mismo
//  instante en que se enseña la nueva, como un control segmentado del sistema.
//
//  La animación de la fila es implícita (`.animation(_:value:)` en la fila): `ContentView` apaga las de toda
//  transacción que cruza la `TabView` (regla «Animar dentro de una pestaña» de `swiftui-ds.md`).
//

import SwiftUI

/// Qué páginas hay montadas y cuál se ve. Valor puro: lo prueba `StagedTabSelectionTests`.
struct StagedTabSelection<Tab: Hashable>: Equatable {
    /// La que se ve y la que pinta el chip elegido.
    private(set) var shown: Tab
    /// La que se está montando debajo, invisible, a la espera de aparecer.
    private(set) var staged: Tab?

    init(_ tab: Tab) { shown = tab }

    /// Las montadas, en orden estable: la que se ve y, si hay, la que llega.
    var mounted: [Tab] {
        guard let staged, staged != shown else { return [shown] }
        return [shown, staged]
    }

    /// Pide `tab`. Devuelve `true` si hay que montarla debajo y esperar a que aparezca; `false` si ya se ve (y
    /// entonces se olvida la que estuviera llegando: un toque en la de siempre la cancela).
    mutating func request(_ tab: Tab) -> Bool {
        guard tab != shown else {
            staged = nil
            return false
        }
        staged = tab
        return true
    }

    /// Enseña `tab` si es la que se esperaba (un toque posterior puede haberla sustituido).
    mutating func reveal(_ tab: Tab) -> Bool {
        guard staged == tab, tab != shown else { return false }
        shown = tab
        staged = nil
        return true
    }

    /// Cambio directo (Reducir movimiento).
    mutating func jump(to tab: Tab) {
        shown = tab
        staged = nil
    }
}

extension StagedTabSelection {
    /// La animación de la fila de chips al cambiar de página.
    static var animation: Animation { NavigationChipButton.switchAnimation }

    /// Pide `tab`. Lo llama el toque en el chip y cualquier cambio de página que venga de fuera de la fila (tocar el
    /// saldo, «Ver los saldos»).
    @MainActor
    static func select(_ tab: Tab, in selection: Binding<Self>, reduceMotion: Bool) {
        var quiet = Transaction()
        quiet.disablesAnimations = true
        guard !reduceMotion else {
            withTransaction(quiet) { selection.wrappedValue.jump(to: tab) }
            return
        }
        var next = selection.wrappedValue
        guard next.request(tab) else {
            withTransaction(quiet) { selection.wrappedValue = next }
            return
        }
        withTransaction(quiet) { selection.wrappedValue = next }
        // Red por si el `onAppear` no vuelve a llegar: con toques rápidos (B, A, B en la misma pasada) la página B
        // puede seguir montada de antes, sin aparecer otra vez, y el chip se quedaría sin responder. No corre durante
        // el montaje (el hilo principal está ocupado), así que llega con la página ya pintada; si el `onAppear` ya la
        // enseñó, no hace nada.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.revealFallbackDelay) {
            reveal(tab, in: selection)
        }
    }

    /// Lo que espera la red de `select` antes de enseñar la página aunque su `onAppear` no haya llegado.
    static var revealFallbackDelay: TimeInterval { 0.5 }

    /// La página montada debajo ya apareció. Se enseña una vuelta del main actor después del `onAppear`, para que su
    /// montaje ya esté pintado y su bloqueo no se coma la animación de la fila.
    @MainActor
    static func stagedPageAppeared(_ tab: Tab, in selection: Binding<Self>) {
        DispatchQueue.main.async { reveal(tab, in: selection) }
    }

    @MainActor
    private static func reveal(_ tab: Tab, in selection: Binding<Self>) {
        var next = selection.wrappedValue
        guard next.reveal(tab) else { return }
        selection.wrappedValue = next
    }
}

/// Monta las páginas de `selection` una encima de otra: solo la elegida se ve, se toca y se lee.
struct StagedTabPages<Tab: Hashable, Page: View>: View {
    @Binding var selection: StagedTabSelection<Tab>
    @ViewBuilder let page: (Tab) -> Page

    var body: some View {
        ZStack {
            ForEach(selection.mounted, id: \.self) { tab in
                let isShown = tab == selection.shown
                page(tab)
                    .opacity(isShown ? 1 : 0)
                    .allowsHitTesting(isShown)
                    .accessibilityHidden(!isShown)
                    .zIndex(isShown ? 1 : 0)
                    .onAppear {
                        if tab == selection.staged {
                            StagedTabSelection.stagedPageAppeared(tab, in: $selection)
                        }
                    }
            }
        }
    }
}
