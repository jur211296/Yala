//
//  TopPrimaryAction.swift
//  Yala
//
//  El patrón del Panel, para todas las páginas principales (card kzhe, Jürgen 2026-10-24): la acción principal
//  («Nuevo …») es un botón ARRIBA, bajo la cabecera, y el botón flotante solo sale cuando el scroll se lleva ese
//  botón. Arriba el flotante sobra —la acción está a la vista y tapaba cifras—; abajo hace falta, para no subir del
//  todo a crear algo.
//
//  El Panel decide por el desplazamiento (umbrales 180/150 en `PanelView`) porque su fila de acciones está siempre
//  a la misma altura. Aquí cada página tiene la cabecera de un alto distinto (con o sin hero, con avisos), así que
//  decide el propio botón: `revealsFloatingActionWhenScrolledAway` mira si sigue a la vista dentro de su scroll.
//

import SwiftUI

/// La píldora de la acción principal: la misma que «Nuevo registro» en la fila del Panel (`PanelQuickActionsRow`),
/// relleno del acento con el texto encima. Con `isPrimary: false`, la de tarjeta de las acciones secundarias.
struct TopPrimaryActionPill: View {
    let title: String
    let systemImage: String
    var isPrimary: Bool = true
    let accessibilityIdentifier: String
    let action: () -> Void

    @Environment(\.yalaTheme) private var theme

    /// 44 pt, el mínimo táctil de las HIG; con texto grande crece (`minHeight`).
    private static let pillHeight: CGFloat = 44

    var body: some View {
        Button {
            DS.Haptic.selection()
            action()
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: systemImage)
                    .font(DS.Typography.label)
                    .accessibilityHidden(true)
                Text(title)
                    .font(DS.Typography.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isPrimary ? AnyShapeStyle(theme.onAccent) : AnyShapeStyle(Color.primary))
            .padding(.horizontal, DS.Spacing.lg)
            .frame(minHeight: Self.pillHeight)
            .background {
                if isPrimary {
                    Capsule().fill(theme.accent)
                } else {
                    Capsule().fill(theme.card)
                }
            }
            // Dentro del label y tras el padding (regla de filas clicables de `swiftui-ds.md`).
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .shadow(
            color: DS.Shadow.small.color,
            radius: DS.Shadow.small.radius,
            x: DS.Shadow.small.x,
            y: DS.Shadow.small.y
        )
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

/// Qué hace el flotante según la visibilidad del botón de arriba. Puro, para fijarlo en un test.
enum TopPrimaryActionRevealLogic {
    /// Fracción del botón que tiene que seguir a la vista para que cuente como visible. Con medio botón fuera ya
    /// no se lee como «la acción está aquí», y el flotante entra.
    static let visibilityThreshold: Double = 0.5

    /// El flotante sale cuando el botón de arriba ya no se ve, y solo entonces: con los dos a la vez la acción
    /// principal saldría dos veces en la misma pantalla.
    static func showsFloating(topActionVisible: Bool) -> Bool {
        !topActionVisible
    }
}

extension View {
    /// Se cuelga del botón de arriba. Escribe en `showsFloating` si el flotante tiene que salir: `true` cuando el
    /// scroll se lleva el botón, `false` cuando vuelve. Fuera de un scroll no se llama nunca y el flotante no sale,
    /// que es lo correcto: el botón está siempre a la vista.
    func revealsFloatingActionWhenScrolledAway(_ showsFloating: Binding<Bool>) -> some View {
        modifier(TopPrimaryActionRevealModifier(showsFloating: showsFloating))
    }
}

private struct TopPrimaryActionRevealModifier: ViewModifier {
    @Binding var showsFloating: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .onScrollVisibilityChange(threshold: TopPrimaryActionRevealLogic.visibilityThreshold) { visible in
                let shows = TopPrimaryActionRevealLogic.showsFloating(topActionVisible: visible)
                guard shows != showsFloating else { return }
                dsWithAnimation(reduceMotion) { showsFloating = shows }
            }
            // Sin reinicio en `onAppear` a propósito: las páginas de pestaña siguen montadas y conservan el scroll, así
            // que al volver con el botón fuera de vista el flotante tiene que seguir ahí.
    }
}
