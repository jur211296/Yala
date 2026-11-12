//
//  FirstAccountCreator.swift
//  Yala
//
//  Y23-07: guarda lo que se contestó en el paso 1 con las mismas piezas que el formulario de cuenta. La principal en la
//  primera moneda, con su saldo inicial (`InitialBalanceService`), y una línea por cada otra moneda
//  (`AccountLineService.addLine`, `parentAccountID`) con el suyo: la cuenta queda con sus monedas ANTES de verse, no
//  como hoy, que se ofrecen después de guardar. En tarjeta, los días y el recordatorio van en la principal; el aviso lo
//  programa `CreditCardReminderScheduler` al subir `dataVersion`, como al guardar el formulario.
//

import Foundation
import SwiftData

@MainActor
enum FirstAccountCreator {

    enum CreateError: Error {
        case incomplete
        case missingBalanceSubcategory
    }

    /// Crea la cuenta. Devuelve la principal.
    @discardableResult
    static func create(_ draft: FirstAccountDraft, suggestedName: String, in context: ModelContext) throws -> Account {
        guard let kind = draft.kind, let mainCurrency = draft.currencies.first else { throw CreateError.incomplete }
        let currencies = FirstAccountFlowLogic.normalizedCurrencies(draft.currencies)
        let type = kind.accountType

        let account = Account(
            name: FirstAccountFlowLogic.finalName(typed: draft.name, suggested: suggestedName),
            currencyCode: normalizeCurrencyCode(mainCurrency),
            colorHex: kind.colorHex,
            iconName: iconName(for: type),
            type: type.rawValue,
            adjustmentMode: AdjustmentMode.changeInitialBalance.rawValue
        )
        if kind.isCard {
            let lead = FirstAccountFlowLogic.storedReminder(
                lead: draft.reminderLead, paymentDay: draft.paymentDay, statementDay: draft.statementDay)
            account.creditCardStatementDay = draft.statementDay?.day
            // Sin día de pago se queda el de siempre del modelo (1) y sin recordatorio: no hay qué recordar.
            if let paymentDay = draft.paymentDay?.day { account.creditCardPaymentDay = paymentDay }
            account.creditCardPaymentReminder = lead != nil
            account.creditCardReminderDaysBefore = lead ?? 0
        }
        context.insert(account)

        let needsBalanceRow = currencies.contains { (draft.balances[$0] ?? 0) != 0 }
        var opening: TransactionItem?
        if needsBalanceRow {
            guard let subcategory = InitialBalanceService.ensureBalanceAdjustmentSubcategoryExists(context: context) else {
                context.delete(account)
                throw CreateError.missingBalanceSubcategory
            }
            if let mainBalance = draft.balances[currencies[0]], mainBalance != 0 {
                opening = InitialBalanceService.setInitialBalance(
                    amount: mainBalance, for: account, subcategory: subcategory, allTransactions: [], context: context)
            }
        }
        do {
            try context.save()
        } catch {
            // Se deshace solo lo propio, como `AccountLineService.addLine`: un `rollback()` del contexto compartido se
            // llevaría cambios de otras pantallas, y dejado en el contexto lo guardaría el siguiente guardado.
            if let opening { context.delete(opening) }
            context.delete(account)
            throw error
        }

        // Las otras monedas, como líneas de esta cuenta. Cada una se guarda sola (`addLine` guarda y deshace lo suyo si
        // falla): una que falle no se lleva la cuenta, que ya existe.
        for code in currencies.dropFirst() {
            let balance = draft.balances[code] ?? 0
            do {
                try AccountLineService.addLine(
                    currencyCode: code, to: account, initialBalance: balance == 0 ? nil : balance, in: context)
            } catch {
                #if DEBUG
                print("FirstAccountCreator: Error: adding the \(code) line: \(error)")
                #endif
            }
        }

        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
        SetupChecklistManager.shared.markCompleted(.firstAccount)
        return account
    }
}
