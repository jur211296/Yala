//
//  FavoriteChipsRow.swift
//  Yala
//
//  El icono y el color de un favorito. Hasta la hoja B1 (2026-11-20) este fichero llevaba también la fila de favoritos
//  con nombre y monto (UX 2.2 · L2-13); la sustituye `IconFavoritesRow` (`NuevoRegistroB1Pieces.swift`), de solo icono.
//

import SwiftUI

/// Icono y color de un favorito: los de su categoría; los de transferencia, los de transferencia (L2-14).
struct FavoriteChipStyle {
    let iconName: String
    let color: Color

    init(favorite: FavoritePayment) {
        if favorite.type == .transfer {
            iconName = "arrow.left.arrow.right"
            color = TransactionType.transfer.color
            return
        }
        iconName = favorite.subcategory?.iconName
            ?? favorite.subcategory?.category?.iconName
            ?? "star.fill"
        let colorHex = favorite.subcategory?.category?.colorHex
            ?? favorite.subcategory?.colorHex
            ?? AppConstants.defaultColorHex
        color = Color(hex: colorHex)
    }
}
