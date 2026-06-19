//
//  WelcomeFlowLayout.swift
//  Yala
//
//  Constantes y cálculos de layout compartidos entre Hero y Chooser para
//  garantizar que el logo aparezca a la misma altura visual en ambas
//  pantallas — independiente del tamaño de pantalla (iPhone SE, Pro, Pro Max,
//  iPad). Sin GeometryReader compartido, el cálculo lo hace cada view con su
//  propio `GeometryProxy`, pero usando esta función SSOT para el valor.
//

import SwiftUI

enum WelcomeFlowLayout {
    /// Proporción de la altura disponible reservada como espacio mínimo entre
    /// safe area top y el logo. Calibrado para que el logo quede visualmente
    /// centrado entre top y el contenido principal en iPhones modernos.
    private static let logoTopProportion: CGFloat = 0.10

    /// Mínimo absoluto en pantallas pequeñas (iPhone SE) — evita que el logo
    /// quede demasiado pegado al notch en pantallas con poca altura.
    private static let logoTopFloor: CGFloat = 60

    /// Espacio mínimo entre safe area top y logo, proporcional a la altura
    /// disponible. Usado idénticamente en Hero y Chooser → ambos logos
    /// aparecen al mismo y desde safe area, sin importar el contenido debajo
    /// ni el tamaño de pantalla.
    static func logoTopSpacing(in geo: GeometryProxy) -> CGFloat {
        max(logoTopFloor, geo.size.height * logoTopProportion)
    }
}

/// Wrapper compartido por Hero y Chooser que encapsula el background gradient
/// indigo→negro, el `GeometryReader` root, y el cálculo del `logoTopSpacing`.
/// El content recibe el spacing como parámetro y lo aplica al primer Spacer
/// para que el logo aparezca al mismo y en ambas pantallas.
struct WelcomeFlowScreen<Content: View>: View {
    @ViewBuilder let content: (_ logoTopSpacing: CGFloat) -> Content

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: DS.Gradients.heroIndigoBlack,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                content(WelcomeFlowLayout.logoTopSpacing(in: geo))
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}
