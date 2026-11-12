//
//  TransactionAccountPrefillLogic.swift
//  Yala
//
//  Qué cuenta trae puesta el formulario de un registro nuevo (UX 2.2 · L2-1, decidido por Jürgen el 21-oct, y la
//  mitad del formulario de la card uipg). Lógica pura: no toca SwiftData ni `UserDefaults`, para fijarla con tests.
//

import Foundation

/// La regla de la cuenta precargada, en este orden:
///
/// 1. El filtro de cuentas incluye UNA cuenta («Solo X») → esa.
/// 2. La última cuenta usada (`LastUsedAccountStore`), si sigue activa y el filtro no la deja fuera: con varias
///    filtradas, solo si está entre ellas; y nunca si es una de las ocultas.
/// 3. Solo hay una cuenta → esa.
/// 4. Vacía.
///
/// **Nunca una excluida ni una al azar.** Antes el Panel pasaba `selectedAccountIDs.first`, que con dos filtradas
/// devolvía una cualquiera y en modo excluir la que se acababa de excluir (ticket
/// `panel-lee-el-filtro-de-cuentas-en-singular-fuera-del-saldo`).
///
/// El filtro es el de `SessionState` (global: Panel, Registros y Estadísticas lo comparten), así que la regla vale
/// abra el formulario la pantalla que lo abra.
nonisolated enum TransactionAccountPrefillLogic {

    /// Una cuenta tal como la ve la regla.
    struct Candidate<ID: Hashable>: Equatable {
        let id: ID
        /// `Account.shortcutID` en texto: lo que guarda `LastUsedAccountStore`.
        let shortcutID: String
        /// Sin archivar y no es una cuenta sistema de Grupos: se puede elegir en el formulario.
        let isActive: Bool
        /// Una línea de una tarjeta con varias divisas. No cuenta como «otra cuenta» al contar cuántas hay.
        let isLine: Bool
    }

    /// El filtro de cuentas tal como lo tiene `SessionState`.
    struct Filter<ID: Hashable> {
        /// Las INCLUIDAS, conjunto entero (la tarjeta con sus líneas): para saber si una cuenta está dentro.
        let accountIDs: Set<ID>
        /// Las incluidas tal como se pintan (cada tarjeta una vez): para saber si el filtro es de UNA cuenta.
        let shownAccountIDs: Set<ID>
        /// Las ocultas («Sin X»). Conviven con las incluidas desde el 2026-10-25.
        let excludedAccountIDs: Set<ID>

        static var none: Filter { Filter(accountIDs: [], shownAccountIDs: [], excludedAccountIDs: []) }
    }

    /// La cuenta de un gasto o un ingreso nuevo (y el origen de una transferencia).
    static func account<ID: Hashable>(
        candidates: [Candidate<ID>],
        filter: Filter<ID>,
        lastUsedShortcutID: String?
    ) -> ID? {
        let allowed = candidates.filter { $0.isActive && passes($0.id, filter: filter) }

        // (1) Filtro de una cuenta.
        if filter.shownAccountIDs.count == 1, let only = filter.shownAccountIDs.first,
           allowed.contains(where: { $0.id == only }) {
            return only
        }

        // (2) La última usada, si el filtro no la deja fuera.
        if let last = lastUsedShortcutID, let match = allowed.first(where: { $0.shortcutID == last }) {
            return match.id
        }

        // (3) La única cuenta. Se cuentan las cuentas que se eligen (sin las líneas de una tarjeta), y se exige que el
        // filtro no la excluya: si la única está excluida, vacía.
        let choosable = candidates.filter { $0.isActive && !$0.isLine }
        if choosable.count == 1, let only = choosable.first, allowed.contains(where: { $0.id == only.id }) {
            return only.id
        }

        // (4) Vacía.
        return nil
    }

    /// El destino de una transferencia: vacío, salvo que haya exactamente dos cuentas; entonces, la que no es el origen.
    /// Solo ocultarla lo impide (nunca una oculta): con el Panel filtrado por el origen, la otra cuenta queda
    /// fuera del filtro y es justo adonde se pasa el dinero.
    static func transferDestination<ID: Hashable>(
        candidates: [Candidate<ID>],
        filter: Filter<ID>,
        source: ID?
    ) -> ID? {
        let choosable = candidates.filter { $0.isActive && !$0.isLine }
        guard choosable.count == 2, let source,
              choosable.contains(where: { $0.id == source }),
              let other = choosable.first(where: { $0.id != source }),
              !filter.excludedAccountIDs.contains(other.id) else { return nil }
        return other.id
    }

    /// ¿El filtro deja dentro esta cuenta? Si hay incluidas, tiene que estar entre ellas; y nunca entre las ocultas.
    static func passes<ID: Hashable>(_ id: ID, filter: Filter<ID>) -> Bool {
        if !filter.accountIDs.isEmpty, !filter.accountIDs.contains(id) { return false }
        return !filter.excludedAccountIDs.contains(id)
    }
}
