//
//  AccountFormViewModelTests.swift
//  YalaTests
//
//  Unit tests for AccountFormViewModel validation logic.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized)
struct AccountFormViewModelTests {

    // MARK: - isNameValid

    @MainActor @Test func isNameValid_empty_false() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.name = ""
        #expect(vm.isNameValid == false)
    }

    @MainActor @Test func isNameValid_whitespace_false() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.name = "   "
        #expect(vm.isNameValid == false)
    }

    @MainActor @Test func isNameValid_withText_true() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.name = "Mi Cuenta"
        #expect(vm.isNameValid == true)
    }

    // MARK: - isNameUnique

    @MainActor @Test func isNameUnique_noExisting_true() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.name = "Nueva"
        #expect(vm.isNameUnique == true)
    }

    @MainActor @Test func isNameUnique_duplicate_false() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: ["Banco"])
        vm.name = "Banco"
        #expect(vm.isNameUnique == false)
    }

    @MainActor @Test func isNameUnique_caseInsensitive_false() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: ["Banco"])
        vm.name = "banco"
        #expect(vm.isNameUnique == false)
    }

    @MainActor @Test func isNameUnique_editingSameName_true() {
        let account = Account(name: "Banco", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard.fill", type: "bank")
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: ["Banco"])
        vm.name = "Banco"
        #expect(vm.isNameUnique == true)
    }

    // MARK: - isCurrencyValid

    @MainActor @Test func isCurrencyValid_validCurrency_true() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.selectedCurrency = .pen
        #expect(vm.isCurrencyValid == true)
    }

    // MARK: - isBalanceValid

    @MainActor @Test func isBalanceValid_newAccount_emptyText_false() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.balanceText = ""
        #expect(vm.isBalanceValid == false)
    }

    @MainActor @Test func isBalanceValid_newAccount_validText_true() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.balanceText = "100.50"
        #expect(vm.isBalanceValid == true)
    }

    // MARK: - canSave

    @MainActor @Test func canSave_allValid_true() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.name = "Cuenta Nueva"
        vm.selectedCurrency = .pen
        vm.balanceText = "0"
        #expect(vm.canSave == true)
    }

    @MainActor @Test func canSave_emptyName_false() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.name = ""
        vm.balanceText = "100"
        #expect(vm.canSave == false)
    }

    // MARK: - parsedBalanceAmount

    @MainActor @Test func parsedBalanceAmount_positive() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.isPositive = true
        vm.balanceText = "500"
        #expect(vm.parsedBalanceAmount == 500)
    }

    @MainActor @Test func parsedBalanceAmount_negative() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.isPositive = false
        vm.balanceText = "500"
        #expect(vm.parsedBalanceAmount == -500)
    }

    // MARK: - needsAdjustment

    @MainActor @Test func needsAdjustment_newAccount_noBalance_false() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.balanceText = ""
        #expect(vm.needsAdjustment == false)
    }

    // MARK: - Balance Adjustment Scenarios (BUG-13)

    // 2a: byEntry sin input → sin ajuste
    @MainActor @Test func needsAdjustment_editByEntry_noInput_false() {
        let account = Account(name: "Test", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard.fill", type: "bank")
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        #expect(vm.selectedAdjustmentMode == .byEntry)
        #expect(vm.balanceText.isEmpty)
        #expect(vm.parsedBalanceAmount == nil)
        #expect(vm.needsAdjustment == false)
    }

    // 2b: byEntry con input → necesita ajuste
    @MainActor @Test func needsAdjustment_editByEntry_withInput_true() {
        let account = Account(name: "Test", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard.fill", type: "bank")
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        vm.balanceText = "500"
        vm.isPositive = true
        // currentBalance is 0 (no transactions), target is 500 → adjustment needed
        #expect(vm.needsAdjustment == true)
        #expect(vm.adjustmentAmount == 500)
    }

    // 2c: changeInitialBalance sin modificar → sin ajuste
    @MainActor @Test func needsAdjustment_editChangeInitial_noModification_false() {
        let account = Account(name: "Test", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard.fill", type: "bank")
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        vm.selectedAdjustmentMode = .changeInitialBalance
        vm.adjustmentModeChanged()
        // Pre-filled with existingInitialBalance (0.00) → no change → no adjustment
        #expect(vm.needsAdjustment == false)
    }

    // 2d: changeInitialBalance con modificación → necesita ajuste
    @MainActor @Test func needsAdjustment_editChangeInitial_withModification_true() {
        let account = Account(name: "Test", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard.fill", type: "bank")
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        vm.selectedAdjustmentMode = .changeInitialBalance
        vm.adjustmentModeChanged()
        // Modify to a different value
        vm.balanceText = "1000"
        vm.isPositive = true
        // existingInitialBalance is 0, new is 1000 → adjustment needed
        #expect(vm.needsAdjustment == true)
    }

    // MARK: - Credit Card Fields

    @MainActor @Test func creditCard_defaultValues() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        #expect(vm.creditCardPaymentReminder == false)
        #expect(vm.creditCardPaymentDay == 1)
    }

    @MainActor @Test func creditCard_loadsFromAccount() {
        let account = Account(name: "Visa", currencyCode: "USD", colorHex: "#FF0080", iconName: "creditcard.fill", type: "Tarjeta de crédito")
        account.creditCardPaymentReminder = true
        account.creditCardPaymentDay = 15
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        #expect(vm.creditCardPaymentReminder == true)
        #expect(vm.creditCardPaymentDay == 15)
        #expect(vm.selectedType == .creditCard)
    }

    // MARK: - Día de corte y aviso (card nmtk)

    @MainActor @Test func creditCard_statementDayAndLead_loadFromAccount_andOutOfRangeValuesReadAsUnset() {
        let account = Account(name: "Visa", currencyCode: "PEN", colorHex: "#FF0080", iconName: "creditcard.fill",
                              type: AccountType.creditCard.rawValue)
        account.creditCardStatementDay = 15
        account.creditCardReminderDaysBefore = 3
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        #expect(vm.creditCardStatementDay == 15)
        #expect(vm.creditCardReminderDaysBefore == 3)

        account.creditCardStatementDay = 31
        account.creditCardReminderDaysBefore = 2
        let odd = AccountFormViewModel(accountToEdit: account, existingNames: [])
        #expect(odd.creditCardStatementDay == nil)
        #expect(odd.creditCardReminderDaysBefore == 0)
    }

    /// Sin día de corte el aviso solo puede ser el mismo día: el selector ofrece solo esa opción y lo que se guarda es 0
    /// aunque quedara elegido otro valor de antes.
    @MainActor @Test func creditCard_withoutStatementDay_leadIsSameDay() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.creditCardStatementDay = 15
        vm.creditCardReminderDaysBefore = 5
        #expect(vm.creditCardReminderLeadOptions == [0, 1, 3, 5])
        #expect(vm.effectiveCreditCardReminderDaysBefore == 5)
        vm.creditCardStatementDay = nil
        #expect(vm.creditCardReminderLeadOptions == [0])
        #expect(vm.effectiveCreditCardReminderDaysBefore == 0)
    }

    @MainActor @Test func creditCard_nextReminderDay_isThreeDaysBeforeThePayment() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Lima"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 10)))
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.creditCardPaymentReminder = true
        vm.creditCardStatementDay = 15
        vm.creditCardPaymentDay = 5
        vm.creditCardReminderDaysBefore = 3
        #expect(vm.nextCreditCardReminderDay(now: now, calendar: calendar)
                == calendar.date(from: DateComponents(year: 2026, month: 11, day: 2)))
        vm.creditCardPaymentReminder = false
        #expect(vm.nextCreditCardReminderDay(now: now, calendar: calendar) == nil)
    }

    /// Guardar la tarjeta escribe los dos campos; cambiarla a otro tipo los limpia.
    @MainActor @Test func creditCard_savesStatementDayAndLead_andAnotherTypeClearsThem() throws {
        let context = try makeTestContext()
        let account = Account(name: "Visa", currencyCode: "PEN", colorHex: "#FF0080", iconName: "creditcard.fill",
                              type: AccountType.creditCard.rawValue)
        context.insert(account)
        try context.save()
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        vm.creditCardStatementDay = 20
        vm.creditCardPaymentDay = 10
        vm.creditCardReminderDaysBefore = 5
        #expect(vm.saveAccount(context: context))
        #expect(account.creditCardStatementDay == 20)
        #expect(account.creditCardPaymentDay == 10)
        #expect(account.creditCardReminderDaysBefore == 5)

        let other = AccountFormViewModel(accountToEdit: account, existingNames: [])
        other.selectedType = .checking
        #expect(other.saveAccount(context: context))
        #expect(account.creditCardStatementDay == nil)
        #expect(account.creditCardReminderDaysBefore == 0)
    }

    // Cambio de modo: byEntry → changeInitialBalance pre-llena, changeInitialBalance → byEntry limpia
    @MainActor @Test func adjustmentModeChanged_switchModes_correctState() {
        let account = Account(name: "Test", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard.fill", type: "bank")
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        #expect(vm.balanceText.isEmpty) // byEntry default: empty

        vm.selectedAdjustmentMode = .changeInitialBalance
        vm.adjustmentModeChanged()
        #expect(vm.balanceText == "0.00") // pre-filled

        vm.selectedAdjustmentMode = .byEntry
        vm.adjustmentModeChanged()
        #expect(vm.balanceText.isEmpty) // cleared
        #expect(vm.isPositive == true)
    }

    // MARK: - Archivar excluye de estadísticas (archived-accounts-still-count-in-the-panel-total)

    private func makeAccount(excluded: Bool = false, archived: Bool = false) -> Account {
        Account(name: "Ahorros", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard.fill",
                type: "bank", excludeFromStatistics: excluded, isArchived: archived)
    }

    @MainActor @Test func archiving_turnsOnExclude_andShowsNotice() {
        let vm = AccountFormViewModel(accountToEdit: makeAccount(), existingNames: [])
        vm.isArchived = true
        vm.setArchived(true)
        #expect(vm.excludeFromStatistics == true)
        #expect(vm.showsArchiveExclusionNotice == true)
    }

    @MainActor @Test func archiving_alreadyExcluded_noNotice() {
        let vm = AccountFormViewModel(accountToEdit: makeAccount(excluded: true), existingNames: [])
        vm.setArchived(true)
        #expect(vm.excludeFromStatistics == true)
        #expect(vm.showsArchiveExclusionNotice == false)
    }

    @MainActor @Test func unarchivingInSameEdit_undoesOnlyTheAutoExclude() {
        let vm = AccountFormViewModel(accountToEdit: makeAccount(), existingNames: [])
        vm.setArchived(true)
        vm.setArchived(false)
        #expect(vm.isArchived == false)
        #expect(vm.excludeFromStatistics == false)
        #expect(vm.showsArchiveExclusionNotice == false)
    }

    @MainActor @Test func unarchiving_whenExcludedByUser_keepsExclude() {
        let vm = AccountFormViewModel(accountToEdit: makeAccount(excluded: true), existingNames: [])
        vm.setArchived(true)
        vm.setArchived(false)
        #expect(vm.excludeFromStatistics == true)
    }

    @MainActor @Test func unarchiving_savedArchivedAccount_doesNotReinclude() {
        // Archivada y excluida en una edición anterior: desarchivar ahora no toca el toggle.
        let vm = AccountFormViewModel(accountToEdit: makeAccount(excluded: true, archived: true), existingNames: [])
        #expect(vm.isArchived == true)
        vm.setArchived(false)
        #expect(vm.excludeFromStatistics == true)
    }

    @MainActor @Test func reincludingByHand_hidesNotice_andStaysIncluded() {
        // El toggle de excluir sigue mandando: el usuario puede volver a incluir la archivada.
        let vm = AccountFormViewModel(accountToEdit: makeAccount(), existingNames: [])
        vm.setArchived(true)
        vm.excludeFromStatistics = false
        vm.excludeChanged(to: false)
        #expect(vm.isArchived == true)
        #expect(vm.excludeFromStatistics == false)
        #expect(vm.showsArchiveExclusionNotice == false)
    }

    @MainActor @Test func loadingArchivedAccount_doesNotTouchExclude() {
        let vm = AccountFormViewModel(accountToEdit: makeAccount(archived: true), existingNames: [])
        #expect(vm.isArchived == true)
        #expect(vm.excludeFromStatistics == false)
        #expect(vm.showsArchiveExclusionNotice == false)
    }

    @MainActor @Test func reExcludingByHand_thenUnarchiving_keepsUsersExclude() {
        // Archivar → re-incluir a mano → volver a excluir a mano → desarchivar: lo último que
        // eligió el usuario es excluir, y desarchivar no se lo puede apagar.
        let vm = AccountFormViewModel(accountToEdit: makeAccount(), existingNames: [])
        vm.setArchived(true)
        vm.excludeFromStatistics = false
        vm.excludeChanged(to: false)
        vm.excludeFromStatistics = true
        vm.excludeChanged(to: true)
        #expect(vm.showsArchiveExclusionNotice == false)
        vm.setArchived(false)
        #expect(vm.excludeFromStatistics == true)
    }
}
