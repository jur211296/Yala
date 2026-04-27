//
//  NewTransactionViewModel.swift
//  Yala
//
//  Created by Yala - New Transaction Form.
//

import Foundation
import SwiftData
import SwiftUI
import UserNotifications
import WidgetKit

// MARK: - New Transaction ViewModel

/// ViewModel para el formulario de nuevo registro de transacción
@MainActor
@Observable
final class NewTransactionViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Loaded Data

    private(set) var accounts: [Account] = []
    private(set) var categories: [Category] = []
    private(set) var tags: [Tag] = []
    private(set) var subcategories: [Subcategory] = []
    private(set) var transactions: [TransactionItem] = []

    // MARK: - Form State

    /// Tipo de transacción seleccionado
    var transactionType: TransactionType = .expense

    /// Monto como string para el teclado numérico
    var amountString: String = "0.00" {
        didSet {
            // Update destination amount if we have a valid transfer context
            if needsExchangeRate {
                updateDestinationAmount()
            }
        }
    }

    /// Cuenta seleccionada (obligatoria para gasto/ingreso)
    var selectedAccount: Account?

    /// Cuenta origen (solo para transferencias)
    var sourceAccount: Account?

    /// Cuenta destino (solo para transferencias)
    var destinationAccount: Account?

    /// Subcategoría seleccionada (obligatoria)
    var selectedSubcategory: Subcategory?

    /// Naturaleza seleccionada (nil = usar la de subcategoría)
    var selectedNeed: SubcategoryNeed?

    /// Fecha de la transacción
    var transactionDate: Date = Date.now

    /// Etiquetas seleccionadas
    var selectedTags: [Tag] = []

    /// Nota libre
    var note: String = ""

    /// Código de divisa para el registro
    var currencyCode: String = CurrencyDefaults.defaultCode

    // MARK: - Transfer Exchange Rate

    /// Tipo de cambio para transferencias entre divisas
    var exchangeRate: Double = 1.0

    /// Monto en divisa destino (calculado o editado manualmente)
    var destinationAmount: Double = 0.0

    /// Indica si el tipo de cambio fue editado manualmente
    var isExchangeRateManual: Bool = false

    // MARK: - Sheet States

    var showAccountSelector: Bool = false
    var showSourceAccountSelector: Bool = false
    var showDestinationAccountSelector: Bool = false
    var showSubcategorySelector: Bool = false
    var showTagSelector: Bool = false
    var showFavoritesSheet: Bool = false
    var showDatePicker: Bool = false
    var showNeedSelector: Bool = false

    // Quick actions sheets
    var showDeleteConfirmation: Bool = false
    var showSaveAsFavoriteSheet: Bool = false
    var showSaveAsRecurringSheet: Bool = false
    var showSplitCalculator: Bool = false

    // Notification primer
    var showNotificationPrimer: Bool = false

    // MARK: - Validation State

    var showValidationErrors: Bool = false
    var showFutureDateAlert: Bool = false
    var isSaving: Bool = false
    var saveError: String?

    // MARK: - Computed Properties

    /// Monto como Double
    var amount: Double {
        AmountInputHelper.parseDecimal(amountString)
    }

    /// Monto formateado para display
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "0.00"
    }

    /// Color del monto según el tipo de transacción
    var amountColor: Color {
        transactionType.color
    }

    /// Indica si es una transferencia
    var isTransfer: Bool {
        transactionType == .transfer
    }

    /// Indica si las divisas son diferentes (requiere tipo de cambio)
    var needsExchangeRate: Bool {
        guard isTransfer,
            let source = sourceAccount,
            let dest = destinationAccount
        else {
            return false
        }
        return source.currencyCode != dest.currencyCode
    }

    /// Cuenta efectiva para mostrar (según tipo de transacción)
    var effectiveAccount: Account? {
        isTransfer ? sourceAccount : selectedAccount
    }

    /// Código de divisa efectivo
    var effectiveCurrencyCode: String {
        if let account = effectiveAccount {
            return account.currencyCode
        }
        return currencyCode
    }

    // MARK: - Context Setup

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
    }

    func loadData() {
        guard let context = modelContext else { return }

        // Load accounts
        let accountsDescriptor = FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\.name)]
        )
        do {
            accounts = try context.fetch(accountsDescriptor)
        } catch {
            #if DEBUG
            print("NewTransactionViewModel: Error loading accounts: \(error)")
            #endif
        }

        // Load categories
        let categoriesDescriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        do {
            categories = try context.fetch(categoriesDescriptor)
        } catch {
            #if DEBUG
            print("NewTransactionViewModel: Error loading categories: \(error)")
            #endif
        }

        // Load tags
        let tagsDescriptor = FetchDescriptor<Tag>(
            sortBy: [SortDescriptor(\.name)]
        )
        do {
            tags = try context.fetch(tagsDescriptor)
        } catch {
            #if DEBUG
            print("NewTransactionViewModel: Error loading tags: \(error)")
            #endif
        }

        // Load visible subcategories
        let subcategoriesDescriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate<Subcategory> { $0.isVisible },
            sortBy: [SortDescriptor(\.name)]
        )
        do {
            subcategories = try context.fetch(subcategoriesDescriptor)
        } catch {
            #if DEBUG
            print("NewTransactionViewModel: Error loading subcategories: \(error)")
            #endif
        }

        // Load transactions (for recent suggestions)
        var transactionsDescriptor = FetchDescriptor<TransactionItem>(
            sortBy: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)]
        )
        transactionsDescriptor.fetchLimit = 100
        do {
            transactions = try context.fetch(transactionsDescriptor)
        } catch {
            #if DEBUG
            print("NewTransactionViewModel: Error loading transactions: \(error)")
            #endif
        }
    }

    // MARK: - Validation

    var isAmountValid: Bool {
        amount > 0 && amount <= 999_999_999
    }

    var isAccountValid: Bool {
        if isTransfer {
            return sourceAccount != nil && destinationAccount != nil
        }
        return selectedAccount != nil
    }

    var isTransferAccountsValid: Bool {
        guard isTransfer else { return true }
        guard let source = sourceAccount, let dest = destinationAccount else {
            return false
        }
        return source.persistentModelID != dest.persistentModelID
    }

    /// Prepara el estado para una transferencia, seleccionando cuentas por defecto si es necesario
    func prepareForTransfer(allAccounts: [Account]) {
        // Only use non-archived accounts for auto-selection
        let eligible = allAccounts.filter { !$0.isArchived }

        // Ensure source account is set (use selected if available)
        if sourceAccount == nil {
            sourceAccount = selectedAccount
        }

        // If still nil, try to pick first eligible account
        if sourceAccount == nil {
            sourceAccount = eligible.first
        }

        // Auto-select destination if nil
        if destinationAccount == nil, let source = sourceAccount {
            // Pick first eligible account that is not source
            destinationAccount = eligible.first {
                $0.persistentModelID != source.persistentModelID
            }
        }
    }

    var isSubcategoryValid: Bool {
        // Para transferencias, subcategoría es opcional
        if isTransfer {
            return true
        }
        return selectedSubcategory != nil
    }

    var canSave: Bool {
        isAmountValid && isAccountValid && isTransferAccountsValid && isSubcategoryValid
    }

    // MARK: - Field Validation States

    var amountValidation: FieldValidationState {
        if !showValidationErrors { return .empty }
        return isAmountValid ? .valid : .invalid(message: L10n.Validation.enterAmountGreaterThanZero)
    }

    var accountValidation: FieldValidationState {
        if isTransfer {
            // Same-account error shows immediately (no showValidationErrors gate)
            if sourceAccount != nil, destinationAccount != nil, !isTransferAccountsValid {
                return .invalid(message: L10n.Validation.accountsMustBeDifferent)
            }
            if !showValidationErrors { return .empty }
            if sourceAccount == nil {
                return .invalid(message: L10n.Validation.selectSourceAccount)
            }
            if destinationAccount == nil {
                return .invalid(message: L10n.Validation.selectDestinationAccount)
            }
            return .valid
        }
        if !showValidationErrors { return .empty }
        return selectedAccount != nil ? .valid : .invalid(message: L10n.Validation.selectAccount)
    }

    var subcategoryValidation: FieldValidationState {
        if !showValidationErrors { return .empty }
        if isTransfer { return .valid }
        return selectedSubcategory != nil
            ? .valid : .invalid(message: L10n.Validation.selectSubcategory)
    }

    // MARK: - Prefill

    /// Pre-rellena el formulario desde contexto externo
    func prefill(
        accountID: PersistentIdentifier?,
        categoryID: PersistentIdentifier?,
        subcategoryName: String?,
        accounts: [Account],
        subcategories: [Subcategory]
    ) {
        // Pre-rellenar cuenta
        if let accountID = accountID,
            let account = accounts.first(where: { $0.persistentModelID == accountID })
        {
            selectedAccount = account
            sourceAccount = account
            currencyCode = account.currencyCode
        }

        // Pre-rellenar subcategoría
        if let subcategoryName = subcategoryName,
            let subcategory = subcategories.first(where: { $0.name == subcategoryName })
        {
            selectedSubcategory = subcategory
            // Ajustar tipo según la categoría
            if subcategory.safeCategory.isIncome {
                transactionType = .income
            } else {
                transactionType = .expense
            }
        }
    }

    // MARK: - Numeric Keypad

    /// Añade un dígito al monto
    func appendDigit(_ digit: String) {
        if amountString == "0" && digit != "." {
            amountString = digit
        } else if digit == "." {
            if !amountString.contains(".") {
                amountString += digit
            }
        } else {
            // Limitar decimales a 2
            if let dotIndex = amountString.firstIndex(of: ".") {
                let decimalPart = amountString[amountString.index(after: dotIndex)...]
                if decimalPart.count >= 2 {
                    return
                }
            }
            amountString += digit
        }
        updateDestinationAmount()
    }

    /// Borra el último dígito
    func deleteLastDigit() {
        if amountString.count > 1 {
            amountString.removeLast()
        } else {
            amountString = "0"
        }
        updateDestinationAmount()
    }

    /// Limpia el monto
    func clearAmount() {
        amountString = "0"
        updateDestinationAmount()
    }

    // MARK: - Exchange Rate

    /// Actualiza el monto destino basado en el tipo de cambio
    func updateDestinationAmount() {
        if needsExchangeRate {
            destinationAmount = amount * exchangeRate
        }
    }

    /// Actualiza el tipo de cambio cuando se edita el monto destino
    func updateExchangeRateFromDestination() {
        guard amount > 0 else { return }
        exchangeRate = destinationAmount / amount
        isExchangeRateManual = true
    }

    /// Carga el tipo de cambio del servicio (solo para transfers entre cuentas de diferente divisa)
    func loadExchangeRate(context: ModelContext) async {
        // Only load exchange rate for transfers between accounts with different currencies
        // For regular transactions, the rate is set during prefill and should not be reset here
        guard needsExchangeRate,
            let source = sourceAccount,
            let dest = destinationAccount
        else {
            // Don't reset exchangeRate here - it may have been set during prefill for display purposes
            return
        }

        // Ensure we have rates for the transaction date
        let dateInterval = DateInterval(start: transactionDate, duration: 0)

        // If date is today, fetch latest rates specifically (timeseries might lag)
        if Calendar.current.isDateInToday(transactionDate) {
            await ExchangeRateService.shared.updateTodayIfNeeded(context: context)
        }

        await ExchangeRateService.shared.ensureRates(for: dateInterval, context: context)

        if let rate = CurrencyConverter.shared.getDisplayRate(
            from: source.currencyCode,
            to: dest.currencyCode,
            date: transactionDate,
            context: context
        ) {
            exchangeRate = rate
            isExchangeRateManual = false
            updateDestinationAmount()
        }
    }

    // MARK: - Editing State

    /// Transaction being edited (if any)
    var editingTransaction: TransactionItem?

    /// Transfer pair being edited (outflow, inflow)
    var editingTransferPair: (out: TransactionItem, in: TransactionItem)?

    // ... (rest of the class)

    // MARK: - Save

    /// Guarda la transacción en el contexto
    /// - Returns: The created or updated transactions (useful for tracking IDs)
    /// Fast validation (no I/O) — safe to call before optimistic UI
    func preValidate() -> Bool {
        showValidationErrors = true
        if Calendar.current.compare(transactionDate, to: Date.now, toGranularity: .day) == .orderedDescending {
            showFutureDateAlert = true
            return false
        }
        return canSave
    }

    func save(context: ModelContext) -> [TransactionItem]? {
        guard preValidate() else { return nil }

        // Capture before save — editingTransaction gets set during saveNormalTransaction
        let isNewTransaction = editingTransaction == nil && editingTransferPair == nil

        isSaving = true

        do {
            var result: [TransactionItem] = []
            if isTransfer {
                let (outTx, inTx) = try saveTransfer(context: context)
                editingTransferPair = (outTx, inTx)
                result = [outTx, inTx]
            } else {
                let tx = try saveNormalTransaction(context: context)
                editingTransaction = tx
                result = [tx]
            }
            try context.save()
            SessionState.shared.incrementDataVersion()

            // F5: memorizar última cuenta usada (per-device, para QuickExpenseIntent fallback)
            if let savedAccount = result.first?.account {
                LastUsedAccountStore.write(savedAccount.shortcutID.uuidString)
            }

            // Update widget cache deferred — don't block save UI
            Task {
                WidgetDataCache.updateCache(context: context)
            }

            // Track new transaction count for notification primer
            if isNewTransaction {
                let count = UserDefaults.standard.integer(forKey: "transactionsSavedCount") + 1
                UserDefaults.standard.set(count, forKey: "transactionsSavedCount")

                // Check if we should prompt for App Store review
                if ReviewPromptService.shouldPrompt(transactionCount: count) {
                    AppRouter.shared.enqueue(.requestAppStoreReview)
                }

                // Check milestone upgrade for Free users
                if !FeatureGateService.shared.isProUser,
                   ProUpsellService.shared.shouldShowMilestone(transactionCount: count),
                   let milestone = ProUpsellService.shared.nextMilestone(for: count) {
                    AppRouter.shared.enqueue(.presentMilestoneUpgrade(milestone))
                    ProUpsellService.shared.markMilestoneShown(milestone)
                }
            }

            // Analytics
            TelemetryService.track(.transactionSaved, parameters: [
                "type": transactionType.rawValue,
                "isNew": String(isNewTransaction),
            ])

            isSaving = false
            return result
        } catch {
            #if DEBUG
            print("Error saving transaction: \(error)")
            #endif
            saveError = L10n.Common.saveError
            isSaving = false
            return nil
        }
    }

    private func saveNormalTransaction(context: ModelContext) throws -> TransactionItem {
        guard let account = selectedAccount,
            let subcategory = selectedSubcategory
        else {
            throw TransactionSaveError.missingRequiredFields
        }

        let finalAmount = transactionType.isNegative ? -amount : amount
        let preferredCode = CurrencyDefaults.currentPreferred

        let amountInPreferred = CurrencyConverter.shared.convert(
            Decimal(finalAmount),
            from: account.currencyCode,
            to: preferredCode,
            on: transactionDate,
            context: context
        )

        let effectiveRate: Double
        if abs(finalAmount) > 0.0001 {
            effectiveRate = (amountInPreferred as NSDecimalNumber).doubleValue / finalAmount
        } else {
            effectiveRate = 1.0
        }

        let transaction: TransactionItem
        if let existing = editingTransaction {
            transaction = existing
            transaction.date = transactionDate
            transaction.amount = finalAmount
            transaction.currencyCode = account.currencyCode
            transaction.note = note.isEmpty ? nil : note
            transaction.category = subcategory.safeCategory
            transaction.subcategory = subcategory
            transaction.account = account
            transaction.tags = selectedTags
            transaction.exchangeRate = abs(effectiveRate)
            transaction.amountInPreferredCurrency =
                (amountInPreferred as NSDecimalNumber).doubleValue
            transaction.preferredCurrencyCode = preferredCode
            // Save need override if different from subcategory's need
            transaction.needOverride = selectedNeed?.rawValue
        } else {
            transaction = TransactionItem(
                date: transactionDate,
                amount: finalAmount,
                currencyCode: account.currencyCode,
                note: note.isEmpty ? nil : note,
                category: subcategory.category,
                subcategory: subcategory,
                account: account,
                tags: selectedTags,
                exchangeRate: abs(effectiveRate),
                amountInPreferredCurrency: (amountInPreferred as NSDecimalNumber).doubleValue,
                preferredCurrencyCode: preferredCode
            )
            // Save need override for new transactions
            transaction.needOverride = selectedNeed?.rawValue
            context.insert(transaction)
        }

        // Persist split data (same for both edit and new)
        applySplitData(to: transaction)

        return transaction
    }

    private func saveTransfer(context: ModelContext) throws -> (TransactionItem, TransactionItem) {
        guard let source = sourceAccount,
            let dest = destinationAccount
        else {
            throw TransactionSaveError.missingRequiredFields
        }

        let outflowSubcategory = try ensureTransferCategory(context: context)
        let inflowSubcategory = try ensureIncomeTransferCategory(context: context)
        let preferredCode = CurrencyDefaults.currentPreferred

        // --- OUTFLOW (Source) ---
        let outAmount = -amount
        let outAmountInPreferred = CurrencyConverter.shared.convert(
            Decimal(outAmount),
            from: source.currencyCode,
            to: preferredCode,
            on: transactionDate,
            context: context
        )
        let outRate =
            abs(outAmount) > 0.0001
            ? (outAmountInPreferred as NSDecimalNumber).doubleValue / outAmount : 1.0

        // --- INFLOW (Dest) ---
        let inAmount = needsExchangeRate ? destinationAmount : amount
        let inAmountInPreferred = CurrencyConverter.shared.convert(
            Decimal(inAmount),
            from: dest.currencyCode,
            to: preferredCode,
            on: transactionDate,
            context: context
        )
        let inRate =
            abs(inAmount) > 0.0001
            ? (inAmountInPreferred as NSDecimalNumber).doubleValue / inAmount : 1.0

        // Retrieve or Create
        let outTransaction: TransactionItem
        let inTransaction: TransactionItem

        if let pair = editingTransferPair {
            outTransaction = pair.out
            inTransaction = pair.in

            // Update Out (Otros/Transferencia entre cuentas)
            outTransaction.date = transactionDate
            outTransaction.amount = outAmount
            outTransaction.currencyCode = source.currencyCode
            outTransaction.note = note.isEmpty ? L10n.Transfer.transferTo(dest.name) : note
            outTransaction.category = outflowSubcategory.safeCategory
            outTransaction.subcategory = outflowSubcategory
            outTransaction.account = source
            outTransaction.tags = selectedTags
            outTransaction.exchangeRate = abs(outRate)
            outTransaction.amountInPreferredCurrency =
                (outAmountInPreferred as NSDecimalNumber).doubleValue
            outTransaction.preferredCurrencyCode = preferredCode
            outTransaction.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer

            // Update In (Ingresos/Transferencia entre cuentas)
            inTransaction.date = transactionDate
            inTransaction.amount = inAmount
            inTransaction.currencyCode = dest.currencyCode
            inTransaction.note = note.isEmpty ? L10n.Transfer.transferFrom(source.name) : note
            inTransaction.category = inflowSubcategory.safeCategory
            inTransaction.subcategory = inflowSubcategory
            inTransaction.account = dest
            inTransaction.tags = selectedTags
            inTransaction.exchangeRate = abs(inRate)
            inTransaction.amountInPreferredCurrency =
                (inAmountInPreferred as NSDecimalNumber).doubleValue
            inTransaction.preferredCurrencyCode = preferredCode
            inTransaction.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer

        } else {
            // Create Out (Otros/Transferencia entre cuentas)
            outTransaction = TransactionItem(
                date: transactionDate,
                amount: outAmount,
                currencyCode: source.currencyCode,
                note: note.isEmpty ? L10n.Transfer.transferTo(dest.name) : note,
                category: outflowSubcategory.safeCategory,
                subcategory: outflowSubcategory,
                account: source,
                tags: selectedTags,
                exchangeRate: abs(outRate),
                amountInPreferredCurrency: (outAmountInPreferred as NSDecimalNumber).doubleValue,
                preferredCurrencyCode: preferredCode
            )
            outTransaction.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer

            // Create In (Ingresos/Transferencia entre cuentas)
            inTransaction = TransactionItem(
                date: transactionDate,
                amount: inAmount,
                currencyCode: dest.currencyCode,
                note: note.isEmpty ? L10n.Transfer.transferFrom(source.name) : note,
                category: inflowSubcategory.safeCategory,
                subcategory: inflowSubcategory,
                account: dest,
                tags: selectedTags,
                exchangeRate: abs(inRate),
                amountInPreferredCurrency: (inAmountInPreferred as NSDecimalNumber).doubleValue,
                preferredCurrencyCode: preferredCode
            )
            inTransaction.balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer

            context.insert(outTransaction)
            context.insert(inTransaction)
        }

        // Link both sides with a shared transfer pair ID
        let pairID = UUID().uuidString
        outTransaction.transferPairID = pairID
        inTransaction.transferPairID = pairID

        return (outTransaction, inTransaction)
    }

    private func ensureTransferCategory(context: ModelContext) throws -> Subcategory {
        // Use first expense category with localized subcategory name
        let subcategoryName = L10n.Transfer.categoryName

        // Check if transfer subcategory already exists in any expense category
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.name == subcategoryName && $0.category?.isIncome == false }
        )

        let fetchedSubcategories: [Subcategory]
        do {
            fetchedSubcategories = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("[NewTransactionViewModel] Error fetching transfer subcategory: \(error)")
            #endif
            fetchedSubcategories = []
        }
        if let existing = fetchedSubcategories.first {
            return existing
        }

        // Find first expense category
        let catDescriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.isIncome == false },
            sortBy: [SortDescriptor(\.sortOrder)]
        )

        let fetchedExpenseCategories: [Category]
        do {
            fetchedExpenseCategories = try context.fetch(catDescriptor)
        } catch {
            #if DEBUG
            print("[NewTransactionViewModel] Error fetching expense categories: \(error)")
            #endif
            fetchedExpenseCategories = []
        }

        let category: Category
        if let existingCat = fetchedExpenseCategories.first {
            category = existingCat
        } else {
            // Fallback: create expense category if somehow missing
            category = Category(
                name: "Otros",
                colorHex: "#64748B",
                isIncome: false
            )
            context.insert(category)
        }

        // Create subcategory within "Otros"
        let subcategory = Subcategory(
            name: subcategoryName,
            colorHex: nil,
            natureRawValue: SubcategoryNeed.unclassified.rawValue,
            iconName: "arrow.left.arrow.right",
            category: category
        )
        context.insert(subcategory)

        return subcategory
    }

    /// Ensures the income transfer subcategory exists for incoming transfers
    private func ensureIncomeTransferCategory(context: ModelContext) throws -> Subcategory {
        let subcategoryName = L10n.Transfer.categoryName

        // Check if transfer subcategory already exists in any income category
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.name == subcategoryName && $0.category?.isIncome == true }
        )

        let fetchedIncomeSubcategories: [Subcategory]
        do {
            fetchedIncomeSubcategories = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("[NewTransactionViewModel] Error fetching income transfer subcategory: \(error)")
            #endif
            fetchedIncomeSubcategories = []
        }
        if let existing = fetchedIncomeSubcategories.first {
            return existing
        }

        // Find first income category
        let catDescriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.isIncome == true },
            sortBy: [SortDescriptor(\.sortOrder)]
        )

        let fetchedIncomeCategories: [Category]
        do {
            fetchedIncomeCategories = try context.fetch(catDescriptor)
        } catch {
            #if DEBUG
            print("[NewTransactionViewModel] Error fetching income categories: \(error)")
            #endif
            fetchedIncomeCategories = []
        }

        let category: Category
        if let existingCat = fetchedIncomeCategories.first {
            category = existingCat
        } else {
            // Fallback: create income category if somehow missing
            category = Category(
                name: "Ingresos",
                colorHex: "#14B8A6",
                isIncome: true
            )
            context.insert(category)
        }

        // Create subcategory within "Ingresos"
        let subcategory = Subcategory(
            name: subcategoryName,
            colorHex: nil,
            natureRawValue: SubcategoryNeed.unclassified.rawValue,
            iconName: "arrow.left.arrow.right",
            category: category
        )
        context.insert(subcategory)

        return subcategory
    }

    // MARK: - Notification Primer

    func checkNotificationPrimer() async {
        let count = UserDefaults.standard.integer(forKey: "transactionsSavedCount")
        guard count >= 3, !UserDefaults.standard.bool(forKey: "hasSeenNotificationPrimer") else { return }
        let status = await NotificationService.shared.checkPermissionStatus()
        UserDefaults.standard.set(true, forKey: "hasSeenNotificationPrimer")
        if status == .notDetermined {
            showNotificationPrimer = true
        }
    }

    // MARK: - Split Calculator State

    /// Split state (transient, loaded from/saved to TransactionItem)
    var splitTotalAmount: Double?
    var splitType: SplitType?
    var splitMyValue: Double?
    var splitDivisor: Double?
    var isSplitStale: Bool = false

    var hasSplitData: Bool {
        splitTotalAmount != nil && splitType != nil
    }

    var splitDescription: String? {
        guard let type = splitType, let total = splitTotalAmount else { return nil }
        let formattedTotal = YalaFormatter.number(value: total, forceFullPrecision: true)
        switch type {
        case .percentage:
            if let pct = splitMyValue {
                let pctStr = pct == pct.rounded() ? String(Int(pct)) : String(format: "%.1f", pct)
                return L10n.Split.descPercentage(pctStr, formattedTotal)
            }
        case .equal:
            if let people = splitMyValue {
                return L10n.Split.descEqual(Int(people))
            }
        case .shares:
            if let my = splitMyValue, let totalShares = splitDivisor {
                return L10n.Split.descShares(Int(my), Int(totalShares))
            }
        case .exact:
            if let exact = splitMyValue {
                return L10n.Split.descExact(YalaFormatter.number(value: exact, forceFullPrecision: true))
            }
        }
        return nil
    }

    func applySplitResult(amount: Double, splitType: SplitType, totalAmount: Double, myValue: Double, divisor: Double?) {
        self.splitTotalAmount = totalAmount
        self.splitType = splitType
        self.splitMyValue = myValue
        self.splitDivisor = divisor
        self.isSplitStale = false
        // Update amount string — programmatic, not manual edit
        self.amountString = AmountInputHelper.formatWithGrouping(amount)

        // Save last used preferences
        UserDefaults.standard.set(splitType.rawValue, forKey: "lastSplitType")
        if splitType == .percentage {
            UserDefaults.standard.set(myValue, forKey: "lastSplitPercentage")
        }
    }

    private func applySplitData(to transaction: TransactionItem) {
        transaction.splitTotalAmount = splitTotalAmount
        transaction.splitType = splitType?.rawValue
        transaction.splitMyValue = splitMyValue
        transaction.splitDivisor = splitDivisor
    }

    func clearSplitData() {
        splitTotalAmount = nil
        splitType = nil
        splitMyValue = nil
        splitDivisor = nil
        isSplitStale = false
    }

    // MARK: - Reset

    /// Resetea el formulario a valores iniciales
    func reset() {
        transactionType = .expense
        amountString = "0"
        selectedAccount = nil
        sourceAccount = nil
        destinationAccount = nil
        selectedSubcategory = nil
        transactionDate = Date.now
        selectedTags = []
        note = ""
        exchangeRate = 1.0
        destinationAmount = 0.0
        isExchangeRateManual = false
        showValidationErrors = false
        isSaving = false
        clearSplitData()
    }
}

// MARK: - Errors

enum TransactionSaveError: Error {
    case missingRequiredFields
    case saveFailed
}
