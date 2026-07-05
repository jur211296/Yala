//
//  DraftToGroupExpenseTemplateLogic.swift
//  Yala
//
//  Pure-logic: construye el `GroupExpensePrefillTemplate` para convertir un draft
//  personal de gasto en un gasto compartido de grupo. Extraído para tests sin
//  SwiftData (llamar con `accountPrefill: nil` — el resto son valores planos).
//

import Foundation

enum DraftToGroupExpenseTemplateLogic {
    /// Construye la plantilla de prellenado a partir de un draft personal de gasto.
    ///
    /// El pagador NO se toca: queda fijado a "yo" (Caso A) en `GroupExpenseViewModel.init`.
    /// El split arranca en `.equal` con todos los miembros activos preseleccionados; el
    /// usuario puede reeditar todo en el form antes de guardar.
    ///
    /// - Parameters:
    ///   - amount: monto CON SIGNO del draft (negativo = gasto). Se normaliza a `abs`
    ///     porque `createExpense`/el template esperan un total positivo.
    ///   - cachedCurrencyCode: moneda cacheada del draft (`nil` → cae a la del grupo).
    ///   - note: descripción del draft.
    ///   - activeMemberIDs: miembros activos del grupo elegido (todos preseleccionados).
    ///   - groupCurrencyCode: moneda nativa del grupo (fallback de moneda).
    ///   - accountPrefill: cuenta personal del pagador (Caso A). `nil` en tests.
    static func buildTemplate(
        amount: Double,
        cachedCurrencyCode: String?,
        note: String,
        activeMemberIDs: [UUID],
        groupCurrencyCode: String,
        accountPrefill: Account? = nil
    ) -> GroupExpensePrefillTemplate {
        GroupExpensePrefillTemplate(
            totalAmount: abs(amount),
            currencyCode: cachedCurrencyCode ?? groupCurrencyCode,
            splitType: .equal,
            participantIDs: activeMemberIDs,
            values: [:],
            description: note,
            accountPrefill: accountPrefill
        )
    }
}
