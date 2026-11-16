//
//  DetachesFromSwappedStoreModifier.swift
//  Yala
//
//  Card 7e60: una presentación del árbol viejo (la hoja de Ajustes) sobrevive al cambio de almacén en caliente hasta
//  que UIKit termina de cerrarla, y en ese rato su contenido vuelve a aparecer y lee su `modelContext`, que es del
//  almacén soltado. Ver `SwappedStoreContentLogic`.
//

import SwiftUI

extension EnvironmentValues {
    /// La generación del almacén con la que se montó el árbol de la ventana (`YalaApp.windowContent`). `nil` fuera de
    /// ese árbol (previews). Viaja por el entorno y no en un `@State` del contenido a propósito: el contenido de una hoja
    /// puede rehacerse sin cerrarla, y un `@State` rehecho tras el cambio guardaría la generación NUEVA con el
    /// `modelContext` viejo (review adversarial del lote). La hoja hereda el entorno del árbol que la presentó, y ese
    /// árbol ya no existe: conserva la suya.
    @Entry var mountedStoreGeneration: Int? = nil
}

/// Deja de pintar el contenido en cuanto el almacén con el que se montó ya no es el montado: sin vista, ni `onAppear`
/// ni `.task` ni `body` llegan a tocar un `modelContext` muerto. Lo que se ve en ese rato es el fondo de la hoja, que
/// UIKit está retirando.
private struct DetachesFromSwappedStoreModifier: ViewModifier {
    @Environment(\.mountedStoreGeneration) private var mountedGeneration

    func body(content: Content) -> some View {
        let host = PersonalContainerHost.shared
        if let mountedGeneration, SwappedStoreContentLogic.isStale(
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
