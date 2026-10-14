//
//  OnboardingAccountNameLogic.swift
//  Yala
//
//  El nombre que el onboarding le propone a la primera cuenta (UX 2.2 · L1UI-8).
//

import Foundation

/// Qué nombre sugiere el paso «Nombre y divisa» según lo que la persona eligió antes.
///
/// - «Cada cuenta por separado» (`.fullControl`): el tipo y la divisa, «Ahorros Soles».
/// - «Todo junto en una sola cuenta» (`.dayToDay`): «Mi dinero Soles». Hasta el 2026-10-13 recibía «Gastos Soles», y
///   quien acaba de decir que ahí va todo su dinero entendía que solo eran gastos (L1UI-8, decisión de Jürgen).
/// - «Solo anotar mis gastos» (`.expensesOnly`): «Gastos Soles», que ahí sí es lo que hay.
///
/// Recibe las piezas ya localizadas para que el test no dependa del idioma del simulador.
nonisolated enum OnboardingAccountNameLogic {
    static func suggestedName(
        mode: OnboardingUsageMode,
        accountTypeName: String,
        currencyName: String,
        allTogetherFormat: String,
        expensesWord: String
    ) -> String {
        switch mode {
        case .fullControl:
            return "\(accountTypeName) \(currencyName)"
        case .dayToDay:
            return String(format: allTogetherFormat, currencyName)
        case .expensesOnly:
            return "\(expensesWord) \(currencyName)"
        }
    }
}
