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

/// ¿El contenido que se montó con un almacén sigue perteneciendo al almacén montado ahora?
enum SwappedStoreContentLogic {

    /// `true` si el contenido ya no puede tocar su `modelContext`: el host no tiene almacén (la ventana del cambio en
    /// caliente) o tiene OTRO (la generación subió: cambio consumado, o repuesto tras un aborto).
    static func isStale(mountedGeneration: Int, currentGeneration: Int, hostHasContainer: Bool) -> Bool {
        !hostHasContainer || mountedGeneration != currentGeneration
    }
}
