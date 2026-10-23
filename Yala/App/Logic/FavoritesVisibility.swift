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
    static func shown(_ favorites: [FavoritePayment], isExpensesOnlyMode: Bool) -> [FavoritePayment] {
        guard isExpensesOnlyMode else { return favorites }
        return favorites.filter { $0.type == .expense }
    }
}
