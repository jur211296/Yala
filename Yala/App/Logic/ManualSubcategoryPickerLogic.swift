//
//  ManualSubcategoryPickerLogic.swift
//  Yala
//
//  Qué subcategorías puede elegir una persona a mano al apuntar un movimiento.
//

import Foundation

/// Una sola regla para todo lo que ofrece una subcategoría al apuntar a mano: la rejilla de la hoja
/// «Subcategoría», su fila «Recientes» y el atajo «!» de la descripción.
///
/// Se ofrecen solo las visibles, de una categoría visible, que no sean de sistema y que casen con el tipo
/// (gasto o ingreso; una transferencia no lleva subcategoría). Las de sistema —«Ajustes de saldo»,
/// «Transferencia entre cuentas» y las del puente de grupos— solo las asigna la app.
///
/// Por qué existe: hasta 2.2 la rejilla aplicaba este filtro pero «Recientes» y el atajo «!» no. Al
/// terminar el onboarding, el saldo inicial (subcategoría «Ajustes de saldo») salía como PRIMERA
/// sugerencia de «Recientes» en el primer gasto de una persona nueva, y el atajo «!» podía proponer
/// «Transferencia entre cuentas» para un gasto. Auditoría UX 2.2, lote 2, B6.
enum ManualSubcategoryPickerLogic {

    /// Los datos que decide la regla, sin SwiftData, para poder probarla.
    struct Candidate: Equatable {
        let isVisible: Bool
        let isAnySystem: Bool
        let categoryIsVisible: Bool
        let categoryIsSystem: Bool
        let categoryIsIncome: Bool
    }

    static func isPickable(_ candidate: Candidate, for transactionType: TransactionType) -> Bool {
        guard candidate.isVisible, !candidate.isAnySystem else { return false }
        guard candidate.categoryIsVisible, !candidate.categoryIsSystem else { return false }
        switch transactionType {
        case .expense: return !candidate.categoryIsIncome
        case .income: return candidate.categoryIsIncome
        case .transfer: return false
        }
    }

    static func isPickable(_ subcategory: Subcategory, for transactionType: TransactionType) -> Bool {
        let category = subcategory.safeCategory
        return isPickable(
            Candidate(
                isVisible: subcategory.isVisible,
                isAnySystem: subcategory.isAnySystem,
                categoryIsVisible: category.isVisible,
                categoryIsSystem: category.isSystem,
                categoryIsIncome: category.isIncome
            ),
            for: transactionType
        )
    }
}
