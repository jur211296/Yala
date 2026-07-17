//
//  GoogleSignInButton.swift
//  Yala
//
//  Botón "Continuar con Google" (Google Sign-In sesión 2, decisión owner #2: componente
//  custom compartido — el SDK no ofrece un botón SwiftUI a la altura del de Apple). Sigue
//  las brand guidelines de Google (colores/stroke EXACTOS por variante, logo G multicolor
//  JAMÁS recoloreado/template) con prominencia pareja al `ASAuthorizationAppleIDButton`
//  a 50pt — el caller fija `.frame(height: 50)` como con el botón Apple.
//
//  Variantes: `.light` (Welcome, pareja del Apple `.white` sobre el hero oscuro) y `.dark`
//  (GroupsSignIn en dark mode, pareja del Apple black/white del sheet `.subtle`).
//  Los botones Apple duplicados existentes NO se refactorizan (fuera de alcance).
//

import SwiftUI

struct GoogleSignInButton: View {

    enum Variant {
        case light
        case dark
    }

    let variant: Variant
    let action: () -> Void

    // Colores de las brand guidelines de Google — inalterables por contrato de marca.
    // A11Y-DM: fondo/stroke/texto hardcodeados por variante (el caller elige la variante
    // según el scheme; los valores en sí no adaptan — es el contrato visual de Google).
    private var background: Color {
        switch variant {
        case .light: Color(red: 1, green: 1, blue: 1)                          // #FFFFFF
        case .dark: Color(red: 0x13 / 255, green: 0x13 / 255, blue: 0x14 / 255) // #131314
        }
    }

    private var stroke: Color {
        switch variant {
        case .light: Color(red: 0x74 / 255, green: 0x77 / 255, blue: 0x75 / 255) // #747775
        case .dark: Color(red: 0x8E / 255, green: 0x91 / 255, blue: 0x8F / 255)  // #8E918F
        }
    }

    private var textColor: Color {
        switch variant {
        case .light: Color(red: 0x1F / 255, green: 0x1F / 255, blue: 0x1F / 255) // #1F1F1F
        case .dark: Color(red: 0xE3 / 255, green: 0xE3 / 255, blue: 0xE3 / 255)  // #E3E3E3
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image("GoogleG")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)  // brand guideline: el logo JAMÁS se recolorea
                    .accessibilityHidden(true)
                Text(L10n.Auth.googleButton)
                    // A11Y-DT: paridad visual con ASAuthorizationAppleIDButton a 50pt (UIKit,
                    // tampoco escala). Desviación consciente de Roboto: no se bundlea una fuente
                    // por un botón — system .medium con prominencia equivalente.
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(textColor)
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Light variant") {
    VStack {
        GoogleSignInButton(variant: .light) {}
            .frame(height: 50)
            .padding(.horizontal, DS.Spacing.xl)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}

#Preview("Dark variant") {
    VStack {
        GoogleSignInButton(variant: .dark) {}
            .frame(height: 50)
            .padding(.horizontal, DS.Spacing.xl)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(white: 0.1))
    .preferredColorScheme(.dark)
}
