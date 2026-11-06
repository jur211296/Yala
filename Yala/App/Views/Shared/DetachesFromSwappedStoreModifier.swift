//
//  DetachesFromSwappedStoreModifier.swift
//  Yala
//
//  Card 7e60: una presentación del árbol viejo (la hoja de Ajustes) sobrevive al cambio de almacén en caliente hasta
//  que UIKit termina de cerrarla, y en ese rato su contenido vuelve a aparecer y lee su `modelContext`, que es del
//  almacén soltado. Ver `SwappedStoreContentLogic`.
//

import SwiftUI

/// Deja de pintar el contenido en cuanto el almacén con el que se montó ya no es el montado: sin vista, ni `onAppear`
/// ni `.task` ni `body` llegan a tocar un `modelContext` muerto. Lo que se ve en ese rato es el fondo de la hoja, que
/// UIKit está retirando.
private struct DetachesFromSwappedStoreModifier: ViewModifier {
    /// La generación del almacén cuando este contenido apareció por primera vez.
    @State private var mountedGeneration = PersonalContainerHost.shared.generation

    func body(content: Content) -> some View {
        let host = PersonalContainerHost.shared
        if SwappedStoreContentLogic.isStale(
            mountedGeneration: mountedGeneration,
            currentGeneration: host.generation,
            hostHasContainer: host.container != nil) {
            Color.clear
                .accessibilityHidden(true)
        } else {
            content
        }
    }
}

extension View {
    /// Para el contenido de una presentación desde la que se puede cambiar el almacén en caliente (cerrar sesión o
    /// borrar la cuenta en la nube): ver `DetachesFromSwappedStoreModifier`.
    func detachesFromSwappedStore() -> some View {
        modifier(DetachesFromSwappedStoreModifier())
    }
}
