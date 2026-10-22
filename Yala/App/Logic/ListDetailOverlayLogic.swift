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
    /// - `minimumColumnWidth`: por debajo, una columna deja de leerse (el ancho del iPhone más estrecho; más con texto
    ///   de accesibilidad, `DS.Adaptive.listColumnWidths`).
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

    /// `true` si, con texto de accesibilidad, la ventana es ancha pero no caben dos columnas que lo lean: la página
    /// se pliega a la pila de compacto (la lista sola; lo abierto, encima). Pasa en el Pro Max girado (832 pt contra
    /// 2 × 440): una columna que lea AX5 no cabe AL LADO del detalle y el split la superpone, tapando «Elige un…»
    /// (medido 2026-10-01). Y en el iPad mini (744 en vertical; 853 en horizontal, junto a la barra lateral). Con texto
    /// de siempre nunca: ahí la columna del iPhone cabe.
    ///
    /// - `pageWidth`: el ancho de la página tal como lo mide ella. Ya viene SIN los márgenes seguros (la isla del
    ///   iPhone girado, la barra lateral del iPad), aunque el proxy los siga reportando: restarlos los cuenta dos
    ///   veces (medido: 1096 de página en el iPad Pro 13 girado, con 280 de margen reportado).
    /// - `minimumColumnWidth`: el mínimo AX de la columna de lista (`DS.Adaptive.listColumnWidths`).
    static func foldsForAccessibilityText(
        pageWidth: CGFloat,
        minimumColumnWidth: CGFloat,
        isAccessibilityText: Bool,
        isRegularWidth: Bool
    ) -> Bool {
        guard isAccessibilityText, isRegularWidth, pageWidth > 0 else { return false }
        return pageWidth < minimumColumnWidth * 2
    }
}
