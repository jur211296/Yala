//
//  FullModeActivationLogic.swift
//  Yala
//
//  Pure-logic helpers for `FullModeActivationView` — extraídos del view para
//  permitir tests sin SwiftData ni UI. Cada helper es referencialmente
//  transparente: misma input → misma output.
//

import Foundation

enum FullModeActivationLogic {

    /// Construye el `ICloudAccountSummary` que activa los skips correctos del
    /// `OnboardingView` cuando un user `.groupInvite` activa Yala completo:
    /// - skip `.name` (ya tenemos `userName`)
    /// - skip `.currencyName` (ya tenemos moneda del grupo o de defaults)
    /// - skip `.categories` si el user ya las sembró vía Approach J
    /// - NO skip account steps (`accountsCount: 0`) — user crea cuenta proper.
    static func buildSummary(
        userName: String?,
        groupCurrency: String?,
        defaultCurrency: String?,
        userCategoriesCount: Int
    ) -> ICloudAccountSummary {
        ICloudAccountSummary(
            userName: userName,
            accountsCount: 0,
            transactionsCount: 0,
            budgetsCount: 0,
            groupsCount: 0,
            primaryCurrencyCode: groupCurrency ?? defaultCurrency,
            categoriesCount: userCategoriesCount
        )
    }

    /// Decide si una cuenta `Account` residual del legacy de QA debe borrarse.
    /// Solo borra cuentas tipo `.general` no-sistema sin transacciones —
    /// paranoid safeguard que respeta cualquier dato real del user.
    static func shouldDeleteResidualGeneralAccount(
        type: String,
        isSystemAccount: Bool,
        hasTransactions: Bool
    ) -> Bool {
        type == AccountType.general.rawValue
            && !isSystemAccount
            && !hasTransactions
    }
}
