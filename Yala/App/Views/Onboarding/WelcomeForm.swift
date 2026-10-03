//
//  WelcomeForm.swift
//  Yala
//
//  La forma de las pantallas de ENTRADA del Welcome, sacada de la referencia del 15-sep
//  (`docs/design/referencias/2026-09-15-onboarding-login-referencia.jpg`): titular en serif y una
//  línea que dice las formas de entrar, sin logo; todo lo que se elige vive en UNA tarjeta de borde
//  fino y sin sombra; fuera de ella solo queda la pregunta de pie.
//
//  **De la referencia se trae la jerarquía y el contenedor, no la superficie.** El fondo sigue siendo
//  el degradado índigo→negro fijo del Welcome y la tarjeta es la misma `welcomeFlowCard` de siempre:
//  el Welcome «se ve igual siempre» es decisión de Jürgen (`WelcomeFlowStyle`), y el contraste
//  fondo/tarjeta es identidad de Yala. Por eso los pesos de botón están invertidos respecto a la
//  captura —lleno es blanco, no negro—: lo que se copia es el orden de importancia, no el color.
//
//  Lo usan los cuatro choosers (Chooser, «Ya tengo una cuenta», «Es mi primera vez», «Vengo por un
//  grupo») y el intro de `WelcomeCloudSignInView`. El Hero se queda con su logo: es la portada.
//

import SwiftUI

// MARK: - Layout

enum WelcomeFormLayout {
    /// Hueco sobre el titular: el de la píldora «Volver» (`welcomeBackButton`) más aire, para que el
    /// titular no quede debajo de ella aunque la pantalla no tenga botón de volver — así todas las
    /// pantallas del recorrido arrancan el titular a la misma altura.
    ///
    /// Fijo porque la píldora no crece más allá de `xxxLarge` (`welcomeBackButton`): con texto de
    /// accesibilidad montaba encima del titular (medido en el iPhone 17 Pro a AX5, ~80 pt).
    static let topInset: CGFloat = DS.Spacing.sm + DS.Button.actionSize + DS.Spacing.lg
    /// Ancho máximo de la columna en ventanas anchas (iPad, Stage Manager): una tarjeta de formulario
    /// estirada a 1 000 pt deja los botones como barras.
    static let maxWidth: CGFloat = 560
    /// Alto de los botones de la tarjeta: el mismo de los botones de marca de Apple y Google, que el
    /// caller ya fija a 50 pt. Tres alturas distintas en una tarjeta romperían el ritmo.
    static let buttonHeight: CGFloat = 50
}

// MARK: - Pantalla

/// Fondo del Welcome + columna con scroll: titular serif, subtítulo y el contenido (la tarjeta y,
/// si la hay, la pregunta de pie). El scroll no es decoración: con Dynamic Type grande el titular y
/// la tarjeta no caben en un iPhone SE, y las pantallas de antes, con `Spacer`s, recortaban.
struct WelcomeFormScreen<Content: View>: View {
    let title: String
    let subtitle: String?
    /// Identificador del SUBTÍTULO, para las pantallas cuyo XCUITest distingue variantes de copy sin leer
    /// texto localizado (el origen del faro en `WelcomeCloudSignInView`).
    var subtitleIdentifier: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: DS.Gradients.heroIndigoBlack,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                    header
                    content()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, WelcomeFormLayout.topInset)
                .padding(.bottom, DS.Spacing.xxl)
                .frame(maxWidth: WelcomeFormLayout.maxWidth)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title)
                .font(DS.Typography.welcomeHeadline)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let subtitle {
                if let subtitleIdentifier {
                    subtitleText(subtitle).accessibilityIdentifier(subtitleIdentifier)
                } else {
                    subtitleText(subtitle)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func subtitleText(_ text: String) -> some View {
        Text(text)
            .font(DS.Typography.body)
            .foregroundStyle(.white.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Tarjeta

extension View {
    /// La tarjeta del formulario: relleno interior + `welcomeFlowCard` (borde fino, sin sombra).
    func welcomeFormCard() -> some View {
        self
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .welcomeFlowCard(radius: DS.Radius.xl)
    }
}

/// Etiqueta ENCIMA de lo que se elige (rasgo 3 de la referencia): dice qué es cada bloque de la
/// tarjeta, en vez de esconderlo en el botón.
struct WelcomeFormLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(DS.Typography.subheadline)
            .foregroundStyle(.white.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// El «o» que separa dos caminos dentro de la tarjeta. Oculto a VoiceOver: los botones ya se leen
/// como alternativas, y «o» suelto entre dos botones no añade nada al oído.
struct WelcomeFormSeparator: View {
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            line
            Text(L10n.Welcome.Form.or)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.6))
            line
        }
        .accessibilityHidden(true)
    }

    private var line: some View {
        Rectangle()
            .fill(WelcomeFlowStyle.cardStroke)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

/// Línea fina entre dos filas de una tarjeta de opciones. Arranca donde arranca el texto de la fila,
/// no en el borde: el icono queda como columna propia, como en una lista agrupada de iOS.
struct WelcomeOptionDivider: View {
    var leadingInset: CGFloat = DS.Spacing.lg + WelcomeOptionRowMetrics.iconSize + DS.Spacing.md

    var body: some View {
        Rectangle()
            .fill(WelcomeFlowStyle.cardStroke)
            .frame(height: 1)
            .padding(.leading, leadingInset)
            .accessibilityHidden(true)
    }
}

enum WelcomeOptionRowMetrics {
    /// El círculo del icono de cada fila de opciones. Es el de las cards de antes.
    static let iconSize: CGFloat = 48
}

// MARK: - Botones

/// Botón de la tarjeta, con el PESO como parámetro y no el color (rasgo 4 de la referencia).
///
/// Dos pesos y no tres: el tercero de la captura —gris pasivo hasta que hay datos— es el «Entrar» de
/// un formulario con campos, y el Welcome de Yala no tiene campos que rellenar. Se añadirá cuando
/// exista una pantalla que lo use; uno sin caller es una promesa que nadie prueba.
struct WelcomeFormButton: View {
    enum Weight {
        /// El camino que la pantalla propone. Blanco lleno: sobre el degradado oscuro, es el negro de
        /// la referencia.
        case filled
        /// La salida que no pide cuenta de Yala. Solo borde.
        case outline
    }

    enum Icon {
        case system(String)
        /// Imagen del catálogo que NO se recolorea (el logo G de Google exige sus colores de marca).
        case asset(String)
    }

    let title: String
    var icon: Icon? = nil
    let weight: Weight
    let action: () -> Void

    var body: some View {
        Button {
            DS.Haptic.selection()
            action()
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                iconView
                Text(title)
                    .font(DS.Typography.headline)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: WelcomeFormLayout.buttonHeight)
            .background(background)
            .overlay(border)
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .font(DS.Typography.headline)
                .accessibilityHidden(true)
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFit()
                // A11Y-DT: logo de marca a tamaño fijo, como en `GoogleSignInButton`; el texto de al lado sí escala.
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
        case nil:
            EmptyView()
        }
    }

    // A11Y-DM: colores fijos por diseño — el fondo del Welcome es oscuro constante (`WelcomeFlowStyle`).
    private var foreground: Color {
        switch weight {
        case .filled: .black
        case .outline: .white
        }
    }

    @ViewBuilder
    private var background: some View {
        switch weight {
        case .filled:
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(.white)
        case .outline:
            Color.clear
        }
    }

    @ViewBuilder
    private var border: some View {
        switch weight {
        case .filled:
            EmptyView()
        case .outline:
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(.white.opacity(0.35), lineWidth: 1)
        }
    }
}
