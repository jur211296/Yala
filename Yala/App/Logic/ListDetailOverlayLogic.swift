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

    /// `true` si, con algo abierto en el detalle, el split es demasiado estrecho para lista y detalle legibles a la
    /// vez, y la lista debe apartarse (queda a un toque en el botón de la barra). Pasa al abrir Yala IA al lado
    /// (iPad Pro 13 en vertical: 1024 − 375 de chat = 649 pt de split, que el split repartía en 415 de lista y ~230
    /// de registro abierto, medido 2026-09-29), y en cualquier ventana ancha por debajo de dos anchos de iPhone.
    ///
    /// - `minimumColumnWidth`: por debajo, una columna deja de leerse (el ancho del iPhone más estrecho).
    /// - Solo en ventana ancha: plegado (compacta) el split enseña una columna y esto no aplica.
    /// - Con el detalle vacío («Elige un…») la lista se queda: apartarla dejaría la pantalla sin salida.
    static func listYieldsToDetail(
        splitWidth: CGFloat,
        minimumColumnWidth: CGFloat,
        isRegularWidth: Bool,
        detailIsEmpty: Bool
    ) -> Bool {
        guard isRegularWidth, !detailIsEmpty, splitWidth > 0 else { return false }
        return splitWidth < minimumColumnWidth * 2
    }
}
