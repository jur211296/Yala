//
//  FavoritesVisibility.swift
//  Yala
//
//  Qué favoritos se ofrecen. Lo comparten la lista de Favoritos y la fila de chips del formulario (UX 2.2 · L2-13).
//

import Foundation

enum FavoritesVisibility {
    /// En modo «Solo gastos» no salen los de ingreso, como siempre, ni los de transferencia (L2-14): ese modo no tiene
    /// transferencias, y usarlo cambiaría el formulario a un tipo que no ofrece.
    ///
    /// Con `type`, solo los de ese tipo: la fila del formulario enseña los del tipo elegido (decisión 69 de la revisión
    /// 2.3). Antes, en «Ingreso» salían «Café» y las transferencias, y tocarlos cambiaba el tipo. Sin `type` (Ajustes,
    /// «Ver todos»), todos.
    static func shown(
        _ favorites: [FavoritePayment], isExpensesOnlyMode: Bool, type: TransactionType? = nil
    ) -> [FavoritePayment] {
        favorites.filter { favorite in
            if isExpensesOnlyMode && favorite.type != .expense { return false }
            if let type, favorite.type != type { return false }
            return true
        }
    }
}
