//
//  ListDetailOverlayLogic.swift
//  Yala
//
//  Cuándo la columna de lista de un `NavigationSplitView` está TAPANDO el detalle. Pasa cuando las dos no caben
//  lado a lado (medido: iPad mini en vertical, 744 pt, con la lista a 375): el split la superpone sobre el detalle
//  en vez de repartir el ancho. Al abrir un registro o un presupuesto desde ahí, la superposición se retira para que
//  se vea lo abierto — es lo que hacen Mail y Notas.
//

import CoreGraphics

enum ListDetailOverlayLogic {
    /// `true` si la lista está a la vista y el detalle ocupa el split entero: la lista flota encima.
    /// Lado a lado, el detalle mide el split MENOS la lista; con la lista retirada también mide el split entero,
    /// pero entonces `listIsShown` es `false` y no hay nada que retirar.
    static func listCoversDetail(splitWidth: CGFloat, detailWidth: CGFloat, listIsShown: Bool) -> Bool {
        guard listIsShown, splitWidth > 0, detailWidth > 0 else { return false }
        return detailWidth >= splitWidth - 1
    }
}
