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

    /// **La pila de navegación que comparten los pasos de un recorrido que cambia de pantalla fundiendo** (card feer,
    /// 2026-10-28). Con una pila por pantalla, cada cambio de paso quitaba y ponía una pila de UIKit: la que salía
    /// desaparecía de golpe, sin fundirse, y la que entraba podía crecer desde la esquina enseñando su fondo negro
    /// (vídeo de Jürgen del 27-oct). Montada una vez por encima de los pasos, la pila no se mueve: los pasos cambian
    /// dentro como vistas normales, y cada uno solo aporta su «‹» a la barra.
    func welcomeNavigationHost() -> some View {
        modifier(WelcomeNavigationHost())
    }
}

extension EnvironmentValues {
    /// Lo enciende `welcomeNavigationHost()`: las pantallas de debajo ya están dentro de la pila del recorrido.
    @Entry var isInsideWelcomeNavigationHost = false
}

private struct WelcomeNavigationHost: ViewModifier {
    func body(content: Content) -> some View {
        NavigationStack {
            content
                .environment(\.isInsideWelcomeNavigationHost, true)
        }
    }
}

/// Fuera de `welcomeNavigationHost()` la pantalla monta su propia pila (la activación de Yala completo desde Grupos,
/// que intercala pantallas con pila propia y no puede alojarlas dentro de otra). Dentro, solo pone su botón.
private struct WelcomeBackButton: ViewModifier {
    let tint: Color
    let action: (() -> Void)?
    @Environment(\.isInsideWelcomeNavigationHost) private var isInsideHost

    func body(content: Content) -> some View {
        if isInsideHost {
            withBackButton(content)
        } else {
            NavigationStack {
                withBackButton(content)
            }
        }
    }

    private func withBackButton(_ content: Content) -> some View {
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
