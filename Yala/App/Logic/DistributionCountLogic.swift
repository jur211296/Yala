//
//  DistributionCountLogic.swift
//  Yala
//
//  Cuántas categorías y subcategorías hay en un desglose, contado igual para la vista y para VoiceOver (lote 07 de
//  mejoras necesarias 2.3). La cabecera de Distribución decía «8 categorías» y la tarta le decía a VoiceOver «7»: la
//  cabecera contaba las categorías con importe cero y dejaba fuera «Sin categoría», y la tarta contaba sus trozos, con
//  «Sin categoría» y «Otros» dentro.
//
//  Cuenta lo que se ve como categoría: una categoría (o subcategoría) de verdad con importe en el período. «Sin
//  categoría» y «Sin subcategoría» no son una categoría, «Otros» agrupa varias y una de importe cero no tiene trozo.
//

import Foundation

enum DistributionCountLogic {

    /// Categorías reales con importe en el período.
    static func categoryCount(_ items: [CategorySpendingSummary]) -> Int {
        items.filter { !$0.isUncategorized && hasAmount($0.amount) }.count
    }

    /// Subcategorías reales con importe en el período. La fila «Sin subcategoría» de una categoría (sin `subcategory`)
    /// y la de «Sin categoría» no cuentan.
    static func subcategoryCount(_ items: [SubcategorySpendingSummary]) -> Int {
        items.filter { $0.subcategory != nil && hasAmount($0.amount) }.count
    }

    private static func hasAmount(_ amount: Double) -> Bool {
        amount.isFinite && amount > 0
    }
}
