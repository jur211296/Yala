//
//  PeriodSelectorLabel.swift
//  Yala
//
//  Shared period selector label component.
//

import SwiftUI

/// Cómo cambia el título de la píldora cuando cambia el período. Sin valor (Panel, Informes, Grupos) no se anima, como
/// siempre: el título salta al nuevo.
///
/// Con valor (Estadísticas), la píldora anima su ancho y el título viejo y el nuevo no se cruzan: el viejo se quita y
/// el nuevo entra en el hueco del título, que lo recorta. Antes, la cápsula saltaba al ancho nuevo en un fotograma y se
/// montaba sobre la flecha recién pulsada; con una animación sin más, los dos títulos se fundían uno encima del otro
/// («Este mes» sobre «Mes pasado», vídeo de Jürgen del 2026-10-27, y medido en el simulador).
enum PeriodTitleMotion: Equatable {
    /// El nuevo entra desde ese borde: las flechas ‹ ›.
    case push(from: Edge)
    /// El nuevo aparece cuando el viejo ya se ha ido: una elección del menú.
    case fade

    /// El título viejo se va en el acto, sin fundido, en los dos casos. Con un fundido —aunque fuera corto— se quedaba
    /// encima del nuevo mientras duraba la animación: el solape que vio Jürgen («Este mes» sobre «Mes pasado», medido
    /// en el simulador). Y una salida con sentido no vale: SwiftUI saca la vista vieja con la transición que tenía en su
    /// último fotograma, así que saldría con el sentido del cambio ANTERIOR (tras ‹ ‹, el primer › la sacaría hacia la
    /// derecha mientras el nuevo entra por ella).
    private static let removal: AnyTransition = .identity

    /// Quitar el viejo y encender el nuevo justo después, sin que coincidan. Lo usa también la línea de días.
    static let sequentialFade: AnyTransition = .asymmetric(
        insertion: .opacity.animation(.easeOut(duration: DS.Animation.fast).delay(0.1)),
        removal: removal
    )

    var transition: AnyTransition {
        switch self {
        case .push(let edge): .asymmetric(insertion: .move(edge: edge).combined(with: .opacity), removal: Self.removal)
        case .fade: Self.sequentialFade
        }
    }
}

/// Period selector dropdown label used in control bars.
/// Sin `titleMotion`, la animación queda apagada para que el título no se recorte durante el cambio de período.
struct PeriodSelectorLabel: View {
    let title: String
    /// `nil`: sin icono (la cápsula de divisa de Estadísticas del grupo, que va al lado de la del período).
    var icon: String? = "calendar"
    /// `nil`: el título cambia sin animación. Ver `PeriodTitleMotion`.
    var titleMotion: PeriodTitleMotion? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(DS.Typography.labelSmall)
                    .accessibilityHidden(true)
            }
            titleView
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .foregroundStyle(.thPrimaryText)
        .glassEffect(.regular.interactive(), in: .capsule)
        // Ensure entire capsule is tappable
        .contentShape(Capsule())
        // CRITICAL: Prevent truncation even if parent animates/constrains width
        // Salvo a tamaños de accesibilidad: ahí «Todo el tiempo» ya no cabe en el ancho de un iPhone SE, y con el
        // ancho fijo la píldora ensanchaba la columna entera del Panel y de Registros, que se salía por los dos
        // bordes (medido el 2026-09-28). Sin ese tope horizontal, el título pasa a dos líneas dentro de la píldora.
        .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
        // CRITICAL: Disable animation to prevent clipping during period changes (salvo con título animado: ahí el
        // título que entra se mide por su propio texto, no por el ancho que la cápsula tiene a mitad de animación).
        .transaction { if titleMotion == nil { $0.animation = nil } }
    }

    @ViewBuilder
    private var titleView: some View {
        if let titleMotion {
            // Un título por valor: el cambio es una vista que sale y otra que entra, no un mismo texto que se funde.
            // Como el viejo sale en el acto, no ensancha la píldora mientras se va. La caja recorta: el que entra
            // deslizándose aparece en el hueco del título, sin pasar por encima del icono.
            ZStack {
                titleText
                    .id(title)
                    .transition(titleMotion.transition)
            }
            .clipped()
        } else {
            titleText
        }
    }

    private var titleText: some View {
        Text(title)
            .font(DS.Typography.labelSmall)
            .multilineTextAlignment(.center)
    }
}

#Preview {
    VStack(spacing: DS.Spacing.lg) {
        PeriodSelectorLabel(title: "Este mes")
        PeriodSelectorLabel(title: "Últimos 30 días")
    }
    .padding()
    .background(.thCard)
}
