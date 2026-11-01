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

/// El chip de una barra de navegación: icono, nombre y cápsula de acento si está elegido. Lo comparten Estadísticas,
/// Planificación, Reportes y el detalle de grupo (lienzo «Una sola Yala», 2026-10-26); antes cada pantalla tenía su copia.
///
/// `showsTitleWhenUnselected`: con `false`, el nombre solo en el elegido (Estadísticas y Grupos, decisiones L11-1 y
/// L12-1: con todos los nombres el último se cortaba). Con `true`, en todos (Planificación y Reportes, donde caben).
///
/// El chip pinta `isSelected` tal cual: si cambia dentro de una transacción animada, la cápsula cambia de ancho y los
/// vecinos se recolocan en el mismo movimiento. Para que eso se vea, la pantalla monta sus páginas con
/// `StagedTabPages` y pone `animatesSwitch` (Estadísticas y el detalle de grupo); sin ellos (Planificación y Reportes,
/// cuyos chips no cambian de ancho) el cambio llega sin animación, como siempre.
struct NavigationChipButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var showsTitleWhenUnselected = false
    /// `true` si la pantalla anima la fila ella misma (`StagedTabPages` + `.animation(_:value:)` en la fila). Con
    /// `false`, el toque llega con las animaciones apagadas; y apagadas así, ninguna transacción anidada las enciende
    /// (medido en el simulador, iOS 27.0).
    var animatesSwitch = false
    let action: () -> Void

    @Environment(\.yalaTheme) private var theme

    private var showsTitle: Bool { isSelected || showsTitleWhenUnselected }

    /// El nombre entra fundido cuando la cápsula ya ha empezado a abrir sitio, y se va en el acto: con un fundido de
    /// salida asomaba un resto del nombre al borde de la cápsula mientras esta se cerraba (medido en el simulador).
    private static let titleTransition: AnyTransition = .asymmetric(
        insertion: .opacity.animation(.easeOut(duration: DS.Animation.fast).delay(0.08)),
        removal: .identity
    )

    var body: some View {
        Button {
            // Háptico de selección al cambiar de chip, en las cuatro filas (card pjum). Tocar el que ya está, nada.
            if !isSelected { DS.Haptic.selection() }
            if animatesSwitch {
                action()
            } else {
                // Sin animación: el título grande de la pantalla parpadeaba al cambiar de chip.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { action() }
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(DS.Typography.subheadline)
                    .accessibilityHidden(true)
                if showsTitle {
                    Text(title)
                        .font(DS.Typography.label)
                        .lineLimit(1)
                        .transition(Self.titleTransition)
                }
            }
            .padding(.horizontal, showsTitle ? DS.Spacing.lg : DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .frame(minWidth: 44)
            .foregroundStyle(isSelected ? theme.onAccent : .primary)
            .background(Capsule().fill(isSelected ? theme.accent : Color.clear))
            // Lo que se va (el nombre que sale) se recorta a la cápsula mientras esta se estrecha.
            .clipShape(.capsule)
            .glassEffect(isSelected ? .clear : .regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        // El nombre se lee aunque el chip enseñe solo el icono.
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension NavigationChipButton {
    static let switchAnimation: Animation = DS.Animation.selection
}
