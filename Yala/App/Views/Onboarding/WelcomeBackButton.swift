//
//  WelcomeBackButton.swift
//  Yala
//
//  «Volver» reusado por las pantallas del flow Welcome — descarta la pantalla actual sin alterar
//  flags persistentes y vuelve a la anterior.
//
//  **El botón atrás del sistema, como en el resto de la app** (Jürgen, 2026-10-25): el chevron en su círculo de
//  cristal, en la barra de navegación. Antes era una píldora «‹ Volver» dibujada encima (rasgo 7 de la referencia
//  del 15-sep, `WelcomeForm.swift`) porque un chevron blanco suelto sobre el degradado no se leía como botón; el
//  círculo de cristal sí se lee. Y al ser un botón de barra, en el iPhone Duo cerrado pasa solo a la barra
//  vertical, con la hora, en vez de ocupar arriba el alto de una fila.
//

import SwiftUI

extension View {
    /// `nil` no pinta botón, pero la barra sigue ahí: el titular arranca a la misma altura en todas las
    /// pantallas del recorrido, tengan o no vuelta atrás.
    func welcomeBackButton(tint: Color, action: (() -> Void)?) -> some View {
        modifier(WelcomeBackButton(tint: tint, action: action))
    }
}

/// Una pila de navegación propia por pantalla: el Welcome cambia de paso sustituyendo la vista (no hay pila
/// común que empujar), y ninguna de las que lo llevan está dentro de otra.
private struct WelcomeBackButton: ViewModifier {
    let tint: Color
    let action: (() -> Void)?

    func body(content: Content) -> some View {
        NavigationStack {
            content
                .toolbar {
                    if let action {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                DS.Haptic.selection()
                                action()
                            } label: {
                                Label(L10n.Welcome.Invite.back, systemImage: "chevron.backward")
                                    .foregroundStyle(tint)
                            }
                            .accessibilityIdentifier("welcome_back_button")
                        }
                    }
                }
        }
    }
}
