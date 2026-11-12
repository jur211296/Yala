//
//  Account.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import Foundation
import SwiftData

// MARK: - Account

@Model
final class Account {
    // CloudKit: defaults required
    var name: String = ""
    var currencyCode: String = "USD"
    var colorHex: String = "#6366F1"
    var iconName: String = "creditcard"

    var type: String = "checking"
    var accountNumber: String?
    var adjustmentMode: String = "manual"
    var excludeFromStatistics: Bool = false
    var isArchived: Bool = false

    /// True para cuentas sistema auto-creadas por el bridge de grupos (`Grupos PEN`, etc.).
    /// CloudKit: must have default value. No editable, no eliminable, excluida de pickers manuales.
    var isSystemAccount: Bool = false

    /// Stable identifier for App Intents (Siri/Shortcuts). Unaffected by `name` renames.
    /// CloudKit: must have default value, no `@Attribute(.unique)`. Migration: legacy entities
    /// receive a UUID at first save via AppBootstrapper.persistAppEntityShortcutIDsIfNeeded.
    /// I12: identidad de sync del Modo Nube (`sync_id_source = Account.shortcutID`).
    /// `.preserveValueOnDeletion` para que el history tombstone conserve el `shortcutID` (metadata de
    /// History; NO es un campo CloudKit nuevo → sin deploy .ckdb).
    @Attribute(.preserveValueOnDeletion) var shortcutID: UUID = UUID()

    // Credit card specific
    var creditCardPaymentReminder: Bool = false
    var creditCardPaymentDay: Int = 1
    /// Día de corte de la tarjeta (1…28): separa lo FACTURADO de lo POR FACTURAR y da el importe del aviso
    /// (`CreditCardStatementLogic`, card nmtk). `nil` = sin día de corte, como toda tarjeta de antes de 2.2: la ficha se
    /// queda sin estado de cuenta y el aviso solo puede ser el mismo día, sin importe.
    /// CloudKit: campo nuevo `CD_creditCardStatementDay` (los cuatro `.ckdb`), desplegado a Production antes de que un
    /// build lo escriba. Modo Nube: `accounts.credit_card_statement_day`, `since: 5`.
    var creditCardStatementDay: Int?
    /// Cuántos días antes del pago avisar: 0 (el mismo día), 1, 3 o 5 (`CreditCardStatementLogic.reminderLeadOptions`).
    /// Sin día de corte se lee como 0. CloudKit: `CD_creditCardReminderDaysBefore`. Modo Nube:
    /// `accounts.credit_card_reminder_days_before`, `since: 5`.
    var creditCardReminderDaysBefore: Int = 0

    /// Tarjeta con varias divisas: si esta cuenta es una LÍNEA en otra divisa, el `shortcutID` de la cuenta
    /// principal de la tarjeta. `nil` = cuenta normal o principal. UUID crudo y no relación, a propósito: una
    /// línea que llega antes que su principal conserva el enlace (no hay `SyncDanglingRef` que lo guarde).
    /// Qué es cada cuenta lo decide SOLO `AccountLineLogic.resolve`: un enlace inválido o huérfano se lee como
    /// cuenta suelta. NUNCA `isSystemAccount` para esto: el bridge de Grupos tomaría la línea por pata virtual.
    /// CloudKit: campo nuevo `CD_parentAccountID` (los cuatro `.ckdb`), desplegado a Production antes de que
    /// un build lo escriba. Modo Nube: columna `accounts.parent_account_id`, `since: 2` en el manifest.
    var parentAccountID: UUID?

    /// Relación inversa con budgets (muchos-a-muchos) - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var budgets: [Budget]?

    /// Inverse relationship: transactions linked to this account - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var transactions: [TransactionItem]?

    /// Inverse relationship: favorite payments linked to this account - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var favoritePayments: [FavoritePayment]?

    /// Inverse relationship: favoritos de transferencia que llevan dinero A esta cuenta (UX 2.2 · L2-14) - CloudKit:
    /// must be optional. Es una a-muchos, así que no es un campo de CloudKit: el campo es `CD_destinationAccount` del favorito.
    @Relationship(deleteRule: .nullify)
    var destinationFavoritePayments: [FavoritePayment]?

    /// Inverse relationship: scheduled payments linked to this account - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var scheduledPayments: [ScheduledPayment]?

    /// Inverse relationship: inbox drafts linked to this account - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var inboxDrafts: [InboxDraft]?

    init(
        name: String,
        currencyCode: String,
        colorHex: String,
        iconName: String,
        type: String,
        accountNumber: String? = nil,
        adjustmentMode: String = "Ajustar por registro",
        excludeFromStatistics: Bool = false,
        isArchived: Bool = false,
        isSystemAccount: Bool = false
    ) {
        self.name = name
        self.currencyCode = currencyCode
        self.colorHex = colorHex
        self.iconName = iconName
        self.type = type
        self.accountNumber = accountNumber
        self.adjustmentMode = adjustmentMode
        self.excludeFromStatistics = excludeFromStatistics
        self.isArchived = isArchived
        self.isSystemAccount = isSystemAccount
    }
}

// MARK: - Free-limit billing

extension Account {
    /// Cuenta de USUARIO que consume el límite Free de cuentas.
    /// Las cuentas de sistema del bridge de grupos (`isSystemAccount`) NO cuentan:
    /// el usuario no las creó y no puede eliminarlas. Las archivadas tampoco.
    /// SSOT del predicado — el bug 2026-07-22 (3 call-sites divergidos) es la prueba
    /// de que repetirlo a mano diverge. NUNCA re-implementar el filtro inline.
    ///
    /// Las LÍNEAS de una tarjeta con varias divisas tampoco cuentan (decisión de Jürgen del 2026-10-10): la
    /// tarjeta cuenta una vez, por su principal. Una cuenta sola no sabe si su principal existe, así que aquí
    /// basta con declarar el enlace; la lista (`billableUserAccounts`) vuelve a contar la línea que no resuelve
    /// como tal (huérfana, inválida, duplicada), porque esa se ve como cuenta suelta.
    var isBillableUserAccount: Bool { !isArchived && !isSystemAccount && parentAccountID == nil }
}

extension Array where Element == Account {
    /// Cuentas que consumen el límite Free (ver `isBillableUserAccount`). Una cuenta con enlace cuenta si
    /// `AccountLineLogic` no la reconoce como línea entre las cuentas de ESTA lista: falla cerrado.
    var billableUserAccounts: [Account] {
        let roles = AccountLineLogic.resolve(map { AccountLineNode($0) })
        return filter { account in
            if account.isBillableUserAccount { return true }
            guard !account.isArchived, !account.isSystemAccount, account.parentAccountID != nil else { return false }
            return !(roles[account.shortcutID]?.isLine ?? false)
        }
    }

    /// Qué es cada cuenta de esta lista (`AccountLineLogic.resolve`). Para que una principal archivada cuente, la
    /// lista tiene que traer TODAS las cuentas, archivadas incluidas.
    var lineRoles: [UUID: AccountLineRole] {
        AccountLineLogic.resolve(map { AccountLineNode($0) })
    }

    /// Estas cuentas agrupadas en tarjetas, en su orden (`AccountCardLogic.cards`). `roles` sale de `lineRoles` sobre
    /// todas las cuentas, no solo sobre las que se enseñan.
    func accountCards(roles: [UUID: AccountLineRole]) -> [AccountCard<Account>] {
        AccountCardLogic.cards(self, roles: roles, id: \.shortcutID, currencyCode: \.currencyCode)
    }
}
