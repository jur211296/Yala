//
//  NavigationChipsBar.swift
//  Yala
//
//  La barra de chips de navegación bajo el título grande (Estadísticas, Planificación, detalle de grupo) y el aire
//  que la separa del primer contenido.
//
//  La medida es la del Panel: allí el contenido empieza `DS.Spacing.lg` por debajo de la barra de navegación, y a la
//  vista quedan ~26 pt entre los botones de arriba y la píldora del período. Bajo los chips, la barra pone
//  `DS.Spacing.sm` y el contenido otros `DS.Spacing.sm` de margen de su scroll: ~24 pt a la vista, medido el
//  2026-10-10 en Planificación, Reportes y el detalle de grupo. Estadísticas sumaba además el margen superior del
//  hero (12 pt que crecían con el texto grande) y se iba a 36; por eso el hero lo omite cuando hay chips encima
//  (`heroVerticalPadding(_:)`, en `HeroHeader.swift`). Ticket de tablero `hay-un-vacio-sobrante-entre-los-chips-y`.
//

import SwiftUI

extension EnvironmentValues {
    /// El contenido está debajo de una barra de chips de navegación: el aire hasta el primer contenido ya lo ponen
    /// la barra y el scroll, y el hero no suma el suyo.
    @Entry var sitsBelowNavigationChips: Bool = false
}

extension View {
    /// Monta `bar` como barra de chips de navegación encima del contenido, con su margen vertical de siempre.
    func navigationChipsInset<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        environment(\.sitsBelowNavigationChips, true)
            .safeAreaInset(edge: .top) {
                bar()
                    .padding(.vertical, DS.Spacing.sm)
            }
    }
}
