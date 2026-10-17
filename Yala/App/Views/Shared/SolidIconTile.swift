//
//  SolidIconTile.swift
//  Yala
//
//  La ficha de icono de las pantallas de vuelta a Yala (UX 2.2 · lote 6): un cuadrado redondeado relleno de un
//  color SÓLIDO con el glifo en blanco encima. Es la forma de las fichas de la referencia Kargul que Jürgen
//  aprobó para el lote 1, y la usan el consentimiento de la nube, «Encontramos tus datos» y el aviso tardío
//  de iCloud.
//
//  Sin degradado y sin halo (criterios UX/UI permanentes de Jürgen, 2026-10-13): lo que jerarquiza es el
//  relleno, no un efecto. Los colores son los rellenos del onboarding, que llevan el blanco con contraste AA.
//

import SwiftUI

struct SolidIconTile: View {
    let systemName: String
    let fill: Color
    var size: CGFloat = 40

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(fill)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    // A11Y-DM: blanco fijo sobre relleno sólido oscuro (AA en claro y en oscuro).
                    .foregroundStyle(.white)
            )
            .accessibilityHidden(true)
    }
}

/// Los rellenos de las fichas, uno por tipo de dato. Índigo, rosa y turquesa son los del onboarding
/// (`UIHelpers`); el ámbar es el de los presupuestos (#B45309, 5,0:1 con blanco) y el violeta el de los
/// grupos (#6D28D9, 7,1:1).
enum SolidIconTilePalette {
    static let transactions = Color.selectedIndigoFill
    static let accounts = Color.emphasisPinkFill
    static let categories = Color.incomeAmount
    static let budgets = Color(hex: "B45309")
    static let groups = Color(hex: "6D28D9")
}
