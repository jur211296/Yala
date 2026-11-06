//
//  SwappedStoreContentLogic.swift
//  Yala
//
//  Card 7e60 (QA en el iPhone 14, 2026-11-05): cerrar sesión en la nube cerraba Yala ~10 s después de confirmar. El cierre
//  cambia el almacén en caliente (`PersonalContainerSwap`): el árbol viejo se desmonta, pero la hoja de Ajustes que lo
//  lanzó es una presentación de UIKit y sigue viva hasta que termina de cerrarse. Al terminar, su `onAppear` volvía a
//  correr y `ProfileViewModel` hacía `fetchCount` con el `modelContext` del almacén ya soltado: SwiftData aborta
//  (`swift_weakLoadStrong`, EXC_BREAKPOINT), sin nada que atrapar.
//

import SwiftData

/// ¿El contenido que se montó con un almacén sigue perteneciendo al almacén montado ahora?
enum SwappedStoreContentLogic {

    /// `true` si el contenido ya no puede tocar su `modelContext`: el host no tiene almacén (la ventana del cambio en
    /// caliente) o tiene OTRO (la generación subió: cambio consumado, o repuesto tras un aborto).
    static func isStale(mountedGeneration: Int, currentGeneration: Int, hostHasContainer: Bool) -> Bool {
        !hostHasContainer || mountedGeneration != currentGeneration
    }
}

/// El `modelContext` de un ViewModel atado a la generación del almacén con la que se le dio.
///
/// Card 7e60, tercer cierre (iPhone 14, 2026-11-06): tras el cambio en caliente, el `onDismiss` de la hoja de Ajustes del
/// Panel viejo llamaba a `reloadAndRecalculate()` sobre su `PanelViewModel`, y su recarga hacía `fetch` con el contexto
/// del almacén soltado (`swift_weakLoadStrong`, EXC_BREAKPOINT). Un `onDismiss` corre aunque su vista ya no esté
/// montada, así que el corte va en el ViewModel, que es quien guarda el contexto: venga de donde venga la llamada, un
/// contexto de otro almacén se lee como `nil` y la recarga no hace nada.
@MainActor
struct BoundStoreContext {

    private var context: ModelContext?
    /// `nil` si se ató sin almacén montado en el host (los tests con contenedor propio): nada que comparar.
    private var generation: Int?

    mutating func bind(_ context: ModelContext) {
        self.context = context
        let host = PersonalContainerHost.shared
        generation = host.container != nil ? host.generation : nil
    }

    /// `true` si el contexto atado es de un almacén que ya no es el montado.
    var isDetached: Bool {
        guard context != nil, let generation else { return false }
        let host = PersonalContainerHost.shared
        return SwappedStoreContentLogic.isStale(
            mountedGeneration: generation,
            currentGeneration: host.generation,
            hostHasContainer: host.container != nil)
    }

    /// El contexto atado, o `nil` si su almacén ya no es el montado.
    var liveContext: ModelContext? {
        isDetached ? nil : context
    }
}
