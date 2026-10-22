//
//  OpenInNewWindowButton.swift
//  Yala
//
//  «Abrir en una ventana nueva» para los menús contextuales de grupo y registro (fase 4 del carril adaptativo).
//

import SwiftUI

/// Abre `route` en una ventana nueva de Yala. **Solo aparece donde el sistema deja abrir otra ventana**
/// (`supportsMultipleWindows`): en el iPhone no, y en el iPhone Duo cerrado tampoco, que es lo que pide Apple.
///
/// Si ya hay una ventana con ese mismo destino, el sistema la trae al frente en vez de abrir otra
/// (`WindowGroup(for:)`). SwiftUI no informa de un fallo al pedir la escena: lo que pase entonces lo decide el sistema
/// y esta ventana sigue como estaba.
struct OpenInNewWindowButton: View {
    let route: WindowRoute

    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if supportsMultipleWindows {
            Button(L10n.Window.openInNewWindow, systemImage: "macwindow.badge.plus") {
                openWindow(value: route)
            }
        }
    }
}
