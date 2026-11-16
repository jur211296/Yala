//
//  UITestDemoSubcategoryLogic.swift
//  Yala
//
//  Seam de XCUITest y de capturas (`-uitest-voice-result`, `-uitest-image-result`): qué subcategoría lleva el taxi de las
//  demos de voz y de foto. El perfil `two` lo ponía en Restaurantes, la subcategoría de la comida.
//

import Foundation

#if DEBUG
enum UITestDemoSubcategoryLogic {
    /// La subcategoría del taxi: la de taxis y apps de transporte si está entre los gastos sembrados; si no, `fallback`.
    static func taxiSubcategory(
        among expenseNames: [String],
        rideshareName: String = L10n.Subcategory.rideshare,
        fallback: String?
    ) -> String? {
        expenseNames.contains(rideshareName) ? rideshareName : fallback
    }
}
#endif
