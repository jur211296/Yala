//
//  QuickExpenseIntent.swift
//  Yala
//
//  App Intent for quickly recording transactions via Shortcuts/Siri.
//

import AppIntents
import Foundation
import SwiftData
import SwiftUI

// MARK: - Transaction Type Enum

enum TransactionTypeAppEnum: String, AppEnum {
    case expense = "expense"
    case income = "income"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "shortcut.entity.transactionType"

    static var caseDisplayRepresentations: [TransactionTypeAppEnum: DisplayRepresentation] = [
        .expense: DisplayRepresentation(title: "shortcut.type.expense"),
        .income: DisplayRepresentation(title: "shortcut.type.income")
    ]
}

// MARK: - Quick Entry Intent

struct QuickExpenseIntent: AppIntent {

    static var title: LocalizedStringResource = "shortcut.quickExpense.title"
    static var description = IntentDescription("shortcut.quickExpense.description")

    static var openAppWhenRun: Bool = false

    // MARK: - Parameters

    @Parameter(
        title: "shortcut.param.type",
        description: "shortcut.param.type.description",
        requestValueDialog: "shortcut.dialog.askType"
    )
    var transactionType: TransactionTypeAppEnum?

    @Parameter(
        title: "shortcut.param.amount",
        description: "shortcut.param.amount.description",
        requestValueDialog: "shortcut.dialog.askAmount"
    )
    var amount: Double?

    @Parameter(
        title: "shortcut.param.note",
        description: "shortcut.param.note.description",
        requestValueDialog: "shortcut.dialog.askNote"
    )
    var note: String?

    @Parameter(
        title: "shortcut.param.account",
        description: "shortcut.param.account.description",
        requestValueDialog: "shortcut.dialog.askAccount"
    )
    var account: AccountAppEntity?

    @Parameter(
        title: "shortcut.param.subcategory",
        description: "shortcut.param.subcategory.description",
        requestValueDialog: "shortcut.dialog.askSubcategory"
    )
    var expenseSubcategory: ExpenseSubcategoryAppEntity?

    @Parameter(
        title: "shortcut.param.subcategory",
        description: "shortcut.param.subcategory.description",
        requestValueDialog: "shortcut.dialog.askSubcategory"
    )
    var incomeSubcategory: IncomeSubcategoryAppEntity?

    @Parameter(
        title: "shortcut.param.tag",
        description: "shortcut.param.tag.description",
        requestValueDialog: "shortcut.dialog.askTag"
    )
    var tagName: String?

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Gather all user input
        let input = try await resolveInput()

        // Setup database
        guard let context = setupModelContext() else {
            return .result(dialog: "shortcut.error.database")
        }

        // Resolve entities from database
        guard let resolvedAccount = fetchAccount(name: input.accountName, context: context) else {
            return .result(dialog: "shortcut.error.noAccount")
        }
        guard let resolvedSubcategory = fetchSubcategory(name: input.subcategoryName, categoryName: input.subcategoryCategoryName, context: context) else {
            return .result(dialog: "shortcut.error.noSubcategory")
        }
        var resolvedTag: Tag?
        if let name = input.tagName, !name.isEmpty {
            resolvedTag = fetchTag(name: name, context: context)
        }

        // Create and save transaction
        let result = createTransaction(
            amount: input.amount,
            note: input.note,
            account: resolvedAccount,
            subcategory: resolvedSubcategory,
            tag: resolvedTag,
            context: context
        )

        guard let transaction = result.transaction else {
            return .result(dialog: "shortcut.error.save")
        }

        // Format success message
        let formattedAmount = formatIntentCurrency(amount: input.amount, currencyCode: transaction.currencyCode)
        let noteText = (input.note?.isEmpty == false) ? (input.note ?? "-") : "-"
        let tagText = resolvedTag?.name ?? String(localized: "shortcut.result.noTag")
        let successMessage = String(localized: "shortcut.success.expenseDetail \(resolvedAccount.name) \(formattedAmount) \(noteText) \(resolvedSubcategory.name) \(tagText)")

        return .result(dialog: IntentDialog(stringLiteral: successMessage))
    }

    // MARK: - Input Resolution

    private struct ResolvedInput {
        let amount: Double
        let note: String?
        let accountName: String
        let subcategoryName: String
        let subcategoryCategoryName: String
        let tagName: String?
    }

    private func resolveInput() async throws -> ResolvedInput {
        let finalType = try await getTransactionType()
        let isIncome = (finalType == .income)
        let finalAmount = try await getAmount()
        let finalNote = try await getNote()
        let accountEntity = try await getAccount()

        let subcategoryName: String
        let subcategoryCategoryName: String
        if isIncome {
            let entity = try await getIncomeSubcategory()
            subcategoryName = entity.name
            subcategoryCategoryName = entity.categoryName
        } else {
            let entity = try await getExpenseSubcategory()
            subcategoryName = entity.name
            subcategoryCategoryName = entity.categoryName
        }

        let finalTagName = try await getTagName()

        return ResolvedInput(
            amount: finalAmount,
            note: finalNote,
            accountName: accountEntity.name,
            subcategoryName: subcategoryName,
            subcategoryCategoryName: subcategoryCategoryName,
            tagName: finalTagName
        )
    }

    // MARK: - Model Container

    @MainActor
    private func setupModelContext() -> ModelContext? {
        do {
            let container = try ModelContainer(
                for: SwiftDataConfiguration.schema,
                configurations: SwiftDataConfiguration.configuration
            )
            return container.mainContext
        } catch {
            #if DEBUG
            print("QuickExpenseIntent: Error creating ModelContainer: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Transaction Creation

    private struct TransactionResult {
        let transaction: TransactionItem?
    }

    @MainActor
    private func createTransaction(
        amount: Double,
        note: String?,
        account: Account,
        subcategory: Subcategory,
        tag: Tag?,
        context: ModelContext
    ) -> TransactionResult {
        let preferredCurrency = CurrencyDefaults.currentPreferred
        let transactionCurrency = account.currencyCode

        var exchangeRate = 1.0
        var amountInPreferred = amount
        var isProvisional = false

        if transactionCurrency != preferredCurrency {
            let converter = CurrencyConverter.shared
            let convertedDecimal = converter.convert(
                Decimal(amount),
                from: transactionCurrency,
                to: preferredCurrency,
                on: Date.now,
                context: context
            )
            amountInPreferred = NSDecimalNumber(decimal: convertedDecimal).doubleValue
            if amount > 0 {
                exchangeRate = amountInPreferred / amount
            }
            isProvisional = !converter.hasExactRate(for: Date.now, context: context)
        }

        let transaction = TransactionItem(
            date: Date.now,
            amount: amount,
            currencyCode: transactionCurrency,
            note: note,
            category: subcategory.safeCategory,
            subcategory: subcategory,
            account: account,
            tags: tag.map { [$0] } ?? [],
            exchangeRate: exchangeRate,
            amountInPreferredCurrency: amountInPreferred,
            preferredCurrencyCode: preferredCurrency,
            isExchangeRateProvisional: isProvisional
        )

        context.insert(transaction)

        do {
            try context.save()
            WidgetDataCache.updateCache(context: context)
            SessionState.shared.incrementDataVersion()
            return TransactionResult(transaction: transaction)
        } catch {
            return TransactionResult(transaction: nil)
        }
    }

    // MARK: - Parameter Resolution

    private func getTransactionType() async throws -> TransactionTypeAppEnum {
        // In expenses-only mode, always use expense
        let appGroupID = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String
            ?? "group.com.jurgenschmidt.yala"
        if UserDefaults(suiteName: appGroupID)?.bool(forKey: "expensesOnlyMode") == true {
            return .expense
        }
        if let existingType = transactionType {
            return existingType
        }
        let requestedType: TransactionTypeAppEnum = try await $transactionType.requestValue("shortcut.dialog.askType")
        return requestedType
    }

    private func getAmount() async throws -> Double {
        if let existingAmount = amount, existingAmount > 0 {
            return existingAmount
        }
        let requestedAmount: Double = try await $amount.requestValue("shortcut.dialog.askAmount")
        return abs(requestedAmount)
    }

    private func getNote() async throws -> String? {
        if let existingNote = note {
            return existingNote
        }
        let requestedNote = try await $note.requestValue("shortcut.dialog.askNote")
        return requestedNote
    }

    private func getAccount() async throws -> AccountAppEntity {
        if let existingAccount = account {
            return existingAccount
        }
        let requestedAccount: AccountAppEntity = try await $account.requestValue("shortcut.dialog.askAccount")
        return requestedAccount
    }

    private func getExpenseSubcategory() async throws -> ExpenseSubcategoryAppEntity {
        if let existing = expenseSubcategory {
            return existing
        }
        let requested: ExpenseSubcategoryAppEntity = try await $expenseSubcategory.requestValue("shortcut.dialog.askSubcategory")
        return requested
    }

    private func getIncomeSubcategory() async throws -> IncomeSubcategoryAppEntity {
        if let existing = incomeSubcategory {
            return existing
        }
        let requested: IncomeSubcategoryAppEntity = try await $incomeSubcategory.requestValue("shortcut.dialog.askSubcategory")
        return requested
    }

    private func getTagName() async throws -> String? {
        if let existingTagName = tagName {
            return existingTagName
        }
        let requestedTagName = try await $tagName.requestValue("shortcut.dialog.askTag")
        return requestedTagName
    }

    // MARK: - Helpers

    private func fetchAccount(name: String, context: ModelContext) -> Account? {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.name == name }
        )
        do {
            return try context.fetch(descriptor).first
        } catch {
            #if DEBUG
            print("QuickExpenseIntent: Error fetching account '\(name)': \(error)")
            #endif
            return nil
        }
    }

    private func fetchSubcategory(name: String, categoryName: String, context: ModelContext) -> Subcategory? {
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.name == name }
        )
        let subcategories: [Subcategory]
        do {
            subcategories = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("QuickExpenseIntent: Error fetching subcategory '\(name)': \(error)")
            #endif
            return nil
        }
        return subcategories.first { $0.safeCategory.name == categoryName }
    }

    private func fetchTag(name: String, context: ModelContext) -> Tag? {
        let descriptor = FetchDescriptor<Tag>()
        let tags: [Tag]
        do {
            tags = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("QuickExpenseIntent: Error fetching tags: \(error)")
            #endif
            return nil
        }

        // Case-insensitive and diacritic-insensitive matching
        let normalizedInput = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        return tags.first { tag in
            let normalizedTagName = tag.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return normalizedTagName == normalizedInput
        }
    }

}

// MARK: - Intent Errors

enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case noAccount
    case noSubcategory

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noAccount:
            return "shortcut.error.noAccount"
        case .noSubcategory:
            return "shortcut.error.noSubcategory"
        }
    }
}

// MARK: - Account App Entity

struct AccountAppEntity: AppEntity {

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "shortcut.entity.account"
    static var defaultQuery = AccountQuery()

    var id: String
    var name: String
    var currencyCode: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name) (\(currencyCode))")
    }
}

struct AccountQuery: EntityQuery {

    @MainActor
    func entities(for identifiers: [String]) async throws -> [AccountAppEntity] {
        let allEntities = try await suggestedEntities()
        return allEntities.filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [AccountAppEntity] {
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: SwiftDataConfiguration.schema,
                configurations: SwiftDataConfiguration.configuration
            )
        } catch {
            #if DEBUG
            print("AccountQuery: Error creating ModelContainer: \(error)")
            #endif
            return []
        }

        let context = container.mainContext
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\Account.name)]
        )

        let accounts: [Account]
        do {
            accounts = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("AccountQuery: Error fetching accounts: \(error)")
            #endif
            return []
        }

        return accounts.map { account in
            AccountAppEntity(
                id: account.name,
                name: account.name,
                currencyCode: account.currencyCode
            )
        }
    }
}

// MARK: - Expense Subcategory App Entity (isIncome = false)

struct ExpenseSubcategoryAppEntity: AppEntity {

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "shortcut.entity.subcategory"
    static var defaultQuery = ExpenseSubcategoryQuery()

    var id: String
    var name: String
    var categoryName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(categoryName) > \(name)")
    }
}

struct ExpenseSubcategoryQuery: EntityQuery {

    @MainActor
    func entities(for identifiers: [String]) async throws -> [ExpenseSubcategoryAppEntity] {
        let allEntities = try await suggestedEntities()
        return allEntities.filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [ExpenseSubcategoryAppEntity] {
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: SwiftDataConfiguration.schema,
                configurations: SwiftDataConfiguration.configuration
            )
        } catch {
            #if DEBUG
            print("ExpenseSubcategoryQuery: Error creating ModelContainer: \(error)")
            #endif
            return []
        }

        let context = container.mainContext
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.isVisible },
            sortBy: [SortDescriptor(\Subcategory.name)]
        )

        let subcategories: [Subcategory]
        do {
            subcategories = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ExpenseSubcategoryQuery: Error fetching subcategories: \(error)")
            #endif
            return []
        }

        // Filter ONLY expense subcategories (isIncome = false)
        // Sort by category A-Z, then subcategory A-Z
        return subcategories
            .filter { $0.safeCategory.isIncome == false }
            .sorted { first, second in
                if first.safeCategory.name != second.safeCategory.name {
                    return first.safeCategory.name < second.safeCategory.name
                }
                return first.name < second.name
            }
            .map { subcategory in
                ExpenseSubcategoryAppEntity(
                    id: "\(subcategory.safeCategory.name):\(subcategory.name)",
                    name: subcategory.name,
                    categoryName: subcategory.safeCategory.name
                )
            }
    }
}

// MARK: - Income Subcategory App Entity (isIncome = true)

struct IncomeSubcategoryAppEntity: AppEntity {

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "shortcut.entity.subcategory"
    static var defaultQuery = IncomeSubcategoryQuery()

    var id: String
    var name: String
    var categoryName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(categoryName) > \(name)")
    }
}

struct IncomeSubcategoryQuery: EntityQuery {

    @MainActor
    func entities(for identifiers: [String]) async throws -> [IncomeSubcategoryAppEntity] {
        let allEntities = try await suggestedEntities()
        return allEntities.filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [IncomeSubcategoryAppEntity] {
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: SwiftDataConfiguration.schema,
                configurations: SwiftDataConfiguration.configuration
            )
        } catch {
            #if DEBUG
            print("IncomeSubcategoryQuery: Error creating ModelContainer: \(error)")
            #endif
            return []
        }

        let context = container.mainContext
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.isVisible },
            sortBy: [SortDescriptor(\Subcategory.name)]
        )

        let subcategories: [Subcategory]
        do {
            subcategories = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("IncomeSubcategoryQuery: Error fetching subcategories: \(error)")
            #endif
            return []
        }

        // Filter ONLY income subcategories (isIncome = true)
        // Sort by category A-Z, then subcategory A-Z
        return subcategories
            .filter { $0.safeCategory.isIncome == true }
            .sorted { first, second in
                if first.safeCategory.name != second.safeCategory.name {
                    return first.safeCategory.name < second.safeCategory.name
                }
                return first.name < second.name
            }
            .map { subcategory in
                IncomeSubcategoryAppEntity(
                    id: "\(subcategory.safeCategory.name):\(subcategory.name)",
                    name: subcategory.name,
                    categoryName: subcategory.safeCategory.name
                )
            }
    }
}

// MARK: - Voice Entry Intent

struct VoiceEntryIntent: AppIntent {

    static var title: LocalizedStringResource = "shortcut.voiceEntry.title"
    static var description = IntentDescription("shortcut.voiceEntry.description")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let isEnabled = UserDefaults.standard.bool(forKey: "voiceInputEnabled")

        guard isEnabled else {
            throw VoiceImageIntentError.voiceNotEnabled
        }

        // Open the app with voice-entry URL (dynamic scheme for Yala vs Yala Dev)
        let urlScheme = Bundle.main.object(forInfoDictionaryKey: "URL_SCHEME") as? String ?? "yala"
        if let url = URL(string: "\(urlScheme)://voice-entry") {
            await UIApplication.shared.open(url)
        }

        return .result()
    }
}

// MARK: - Image Entry Intent

struct ImageEntryIntent: AppIntent {

    static var title: LocalizedStringResource = "shortcut.imageEntry.title"
    static var description = IntentDescription("shortcut.imageEntry.description")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let isEnabled = UserDefaults.standard.bool(forKey: "imageInputEnabled")

        guard isEnabled else {
            throw VoiceImageIntentError.imageNotEnabled
        }

        // Open the app with image-entry URL (dynamic scheme for Yala vs Yala Dev)
        let urlScheme = Bundle.main.object(forInfoDictionaryKey: "URL_SCHEME") as? String ?? "yala"
        if let url = URL(string: "\(urlScheme)://image-entry") {
            await UIApplication.shared.open(url)
        }

        return .result()
    }
}

// MARK: - Voice/Image Intent Errors

enum VoiceImageIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case voiceNotEnabled
    case imageNotEnabled

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .voiceNotEnabled:
            return "shortcut.error.voiceNotEnabled"
        case .imageNotEnabled:
            return "shortcut.error.imageNotEnabled"
        }
    }
}

// MARK: - Apple Pay Transaction Intent

struct ApplePayTransactionIntent: AppIntent {

    static var title: LocalizedStringResource = "shortcut.applePay.title"
    static var description = IntentDescription("shortcut.applePay.description")

    static var openAppWhenRun: Bool = false

    // MARK: - Parameter Summary (shows configurable fields in Shortcuts)

    static var parameterSummary: some ParameterSummary {
        Summary("shortcut.applePay.summaryTitle") {
            \.$amount
            \.$name
            \.$merchant
        }
    }

    init() {}

    init(amount: String?, merchant: String?, name: String? = nil) {
        self.amount = amount
        self.merchant = merchant
        self.name = name
    }

    // MARK: - Parameters
    // Parameters match Wallet Transaction output fields
    // Using inputConnectionBehavior to allow connection to Wallet transaction outputs

    @Parameter(
        title: "shortcut.applePay.param.amount",
        description: "shortcut.applePay.param.amount.description",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var amount: String?

    @Parameter(
        title: "shortcut.applePay.param.merchant",
        description: "shortcut.applePay.param.merchant.description",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var merchant: String?

    @Parameter(
        title: "shortcut.applePay.param.name",
        description: "shortcut.applePay.param.name.description",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var name: String?

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Parse amount and currency from Wallet text (e.g., "$32.04", "S/ 25.90")
        guard let amountString = amount,
              let parsedResult = parseAmountAndCurrency(from: amountString) else {
            return .result(dialog: "shortcut.applePay.error.noAmount")
        }

        let finalAmount = parsedResult.amount
        let detectedCurrency = parsedResult.currency

        // Use "name" if available (cleaner), otherwise "merchant"
        let finalNote: String
        if let nameValue = name, !nameValue.trimmingCharacters(in: .whitespaces).isEmpty {
            finalNote = nameValue
        } else if let merchantValue = merchant, !merchantValue.trimmingCharacters(in: .whitespaces).isEmpty {
            finalNote = merchantValue
        } else {
            finalNote = ""
        }

        // Use current date (when automation runs)
        let effectiveDate = Date.now

        // Create ModelContainer
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: SwiftDataConfiguration.schema,
                configurations: SwiftDataConfiguration.configuration
            )
        } catch {
            #if DEBUG
            print("ApplePayTransactionIntent: Error creating ModelContainer: \(error)")
            #endif
            return .result(dialog: "shortcut.error.database")
        }

        let context = container.mainContext

        // Guard: no accounts configured yet
        let accountCount: Int
        do {
            accountCount = try context.fetchCount(FetchDescriptor<Account>())
        } catch {
            #if DEBUG
            print("QuickExpenseIntent: Error fetching account count: \(error)")
            #endif
            accountCount = 0
        }
        guard accountCount > 0 else {
            return .result(dialog: "shortcut.error.noAccount")
        }

        // Try to find account by detected currency (if unique match)
        var matchedAccount: Account?
        var needsUserInput: [String] = ["subcategory"]

        if let currency = detectedCurrency {
            matchedAccount = findIntentAccount(byCurrency: currency, context: context)
        }

        if matchedAccount == nil {
            needsUserInput.insert("account", at: 0)
        }

        // Try to auto-categorize using MerchantMemory
        var matchedSubcategory: Subcategory?
        if !finalNote.isEmpty {
            let merchantService = MerchantMemoryService(modelContext: context)
            let suggestion = merchantService.suggest(for: finalNote)

            switch suggestion {
            case .autoAssign(let sub):
                // High confidence - auto-assign
                matchedSubcategory = sub
                needsUserInput.removeAll { $0 == "subcategory" }
            case .suggest(let sub):
                // Medium confidence - suggest but still needs confirmation
                matchedSubcategory = sub
                // Keep subcategory in needsUserInput so user confirms
            case .none:
                break
            }
        }

        // Create InboxDraft
        let draft = InboxDraft(
            note: finalNote,
            amount: -abs(finalAmount), // Apple Pay is always expense (negative)
            date: effectiveDate,
            account: matchedAccount,
            subcategory: matchedSubcategory,
            sourceType: .applePay,
            rawText: amount, // Store original amount string for reference
            evidence: finalNote.isEmpty ? nil : finalNote,
            confidenceAmount: 1.0, // Amount from Apple Pay is always accurate
            confidenceDate: 1.0, // Date is when automation runs
            confidenceMerchant: finalNote.isEmpty ? nil : 1.0,
            confidenceSubcategory: matchedSubcategory != nil ? 0.8 : nil,
            needsUserInput: needsUserInput
        )

        context.insert(draft)

        do {
            try context.save()
        } catch {
            return .result(dialog: "shortcut.error.save")
        }

        // Send push notification for automatic record (Apple Pay is always expense)
        let notifAmount = YalaFormatter.currency(value: finalAmount, currencyCode: detectedCurrency ?? "USD", forceFullPrecision: true)
        let noteText = finalNote.isEmpty ? "" : " — \(finalNote)"
        let notifBody = L10n.Shortcut.Notification.body(L10n.Shortcut.Notification.expense, notifAmount, noteText)
        await NotificationService.shared.sendNotification(
            title: L10n.Shortcut.Notification.title,
            body: notifBody,
            deepLink: "inbox"
        )

        // Format success message
        let formattedAmount = formatIntentCurrency(amount: finalAmount, currencyCode: detectedCurrency ?? "USD")
        let noteDisplay = finalNote.isEmpty ? "Apple Pay" : finalNote
        return .result(dialog: "shortcut.applePay.success \(formattedAmount) \(noteDisplay)")
    }

    // MARK: - Helpers

    /// Parses amount and currency from Wallet text format
    /// Examples: "$32.04" -> (32.04, "USD"), "S/ 25.90" -> (25.90, "PEN"), "€25,50" -> (25.50, "EUR")
    private func parseAmountAndCurrency(from text: String) -> (amount: Double, currency: String?)? {
        // Currency symbol to code mapping
        let currencyMap: [String: String] = [
            "$": "USD",
            "€": "EUR",
            "£": "GBP",
            "¥": "JPY",
            "S/": "PEN",
            "S/.": "PEN",
            "R$": "BRL",
            "MX$": "MXN",
            "COP$": "COP",
            "COP": "COP",
        ]

        var detectedCurrency: String?

        // Try to detect currency from symbol
        for (symbol, code) in currencyMap {
            if text.contains(symbol) {
                detectedCurrency = code
                break
            }
        }

        // Also check for currency code at end (e.g., "25.00 USD")
        let words = text.components(separatedBy: .whitespaces)
        if let lastWord = words.last,
           lastWord.count == 3,
           lastWord.uppercased() == lastWord {
            detectedCurrency = lastWord
        }

        // Extract numeric value
        var cleaned = text.replacingOccurrences(of: "[^\\d.,\\-]", with: "", options: .regularExpression)

        // Handle European format (comma as decimal separator)
        if cleaned.contains(",") {
            if !cleaned.contains(".") {
                // Only comma: 25,50 -> 25.50
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            } else if let commaIndex = cleaned.lastIndex(of: ","),
                      let dotIndex = cleaned.lastIndex(of: "."),
                      commaIndex > dotIndex {
                // Comma after dot: 1.234,56 -> 1234.56
                cleaned = cleaned.replacingOccurrences(of: ".", with: "")
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
            } else {
                // Dot after comma: 1,234.56 -> 1234.56 (US format with thousands separator)
                cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            }
        }

        guard let amount = Double(cleaned) else {
            return nil
        }

        return (amount, detectedCurrency)
    }

}

// MARK: - Automation Entry Intent

/// Data structure for parsing JSON from external automations
private struct AutomationTransactionData: Codable {
    let amount: Double
    let currency: String
    let merchant: String?
    let date: String? // ISO format: YYYY-MM-DD
}

struct AutomationEntryIntent: AppIntent {

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    static var title: LocalizedStringResource = "shortcut.automation.title"
    static var description = IntentDescription("shortcut.automation.description")

    static var openAppWhenRun: Bool = false

    // MARK: - Parameter Summary

    static var parameterSummary: some ParameterSummary {
        Summary("shortcut.automation.summaryTitle") {
            \.$transactionJSON
        }
    }

    // MARK: - Parameters

    @Parameter(
        title: "shortcut.automation.param.json",
        description: "shortcut.automation.param.json.description",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var transactionJSON: String?

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Validate JSON parameter
        guard let jsonString = transactionJSON, !jsonString.isEmpty else {
            return .result(dialog: "shortcut.automation.error.noJSON")
        }

        // Parse JSON
        guard let jsonData = jsonString.data(using: .utf8) else {
            return .result(dialog: IntentDialog(stringLiteral:
                String(localized: "shortcut.automation.error.invalidJSON") + " (encoding error)"))
        }

        let transaction: AutomationTransactionData
        do {
            transaction = try JSONDecoder().decode(AutomationTransactionData.self, from: jsonData)
        } catch let decodingError as DecodingError {
            let errorDetail: String
            switch decodingError {
            case .keyNotFound(let key, _):
                errorDetail = "Missing: \(key.stringValue)"
            case .typeMismatch(_, let context):
                errorDetail = "Type error: \(context.codingPath.last?.stringValue ?? "?")"
            case .valueNotFound(_, let context):
                errorDetail = "Null: \(context.codingPath.last?.stringValue ?? "?")"
            case .dataCorrupted(let context):
                errorDetail = context.debugDescription
            @unknown default:
                errorDetail = decodingError.localizedDescription
            }
            return .result(dialog: IntentDialog(stringLiteral:
                String(localized: "shortcut.automation.error.invalidJSON") + " (\(errorDetail))"))
        } catch {
            return .result(dialog: IntentDialog(stringLiteral:
                String(localized: "shortcut.automation.error.invalidJSON") + " (\(error.localizedDescription))"))
        }

        // Validate amount
        guard transaction.amount > 0 else {
            return .result(dialog: "shortcut.automation.error.noAmount")
        }

        // Normalize currency to uppercase
        let normalizedCurrency = transaction.currency.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedCurrency.isEmpty else {
            return .result(dialog: "shortcut.automation.error.noCurrency")
        }

        // Parse date if provided (ISO format: YYYY-MM-DD)
        var effectiveDate = Date.now
        if let dateString = transaction.date, !dateString.isEmpty {
            if let parsed = Self.isoDateFormatter.date(from: dateString) {
                effectiveDate = parsed
            }
        }

        // Use merchant as note
        let finalNote = transaction.merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Create ModelContainer
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: SwiftDataConfiguration.schema,
                configurations: SwiftDataConfiguration.configuration
            )
        } catch {
            #if DEBUG
            print("AutomationEntryIntent: Error creating ModelContainer: \(error)")
            #endif
            return .result(dialog: "shortcut.error.database")
        }

        let context = container.mainContext

        // Guard: no accounts configured yet
        let accountCount: Int
        do {
            accountCount = try context.fetchCount(FetchDescriptor<Account>())
        } catch {
            #if DEBUG
            print("QuickExpenseIntent: Error fetching account count: \(error)")
            #endif
            accountCount = 0
        }
        guard accountCount > 0 else {
            return .result(dialog: "shortcut.error.noAccount")
        }

        // Try to find account by currency (only if unique match)
        var matchedAccount: Account?
        var needsUserInput: [String] = ["subcategory"]

        matchedAccount = findIntentAccount(byCurrency: normalizedCurrency, context: context)

        if matchedAccount == nil {
            needsUserInput.insert("account", at: 0)
        }

        // Try to auto-categorize using MerchantMemory
        var matchedSubcategory: Subcategory?
        if !finalNote.isEmpty {
            let merchantService = MerchantMemoryService(modelContext: context)
            let suggestion = merchantService.suggest(for: finalNote)

            switch suggestion {
            case .autoAssign(let sub):
                // High confidence - auto-assign
                matchedSubcategory = sub
                needsUserInput.removeAll { $0 == "subcategory" }
            case .suggest(let sub):
                // Medium confidence - suggest but still needs confirmation
                matchedSubcategory = sub
                // Keep subcategory in needsUserInput so user confirms
            case .none:
                break
            }
        }

        // Create InboxDraft (always expense = negative amount)
        let draft = InboxDraft(
            note: finalNote,
            amount: -abs(transaction.amount),
            date: effectiveDate,
            account: matchedAccount,
            subcategory: matchedSubcategory,
            sourceType: .automation,
            rawText: jsonString,
            evidence: finalNote.isEmpty ? nil : finalNote,
            confidenceAmount: 1.0,
            confidenceDate: transaction.date != nil ? 1.0 : 0.5,
            confidenceMerchant: finalNote.isEmpty ? nil : 1.0,
            confidenceSubcategory: matchedSubcategory != nil ? 0.8 : nil,
            needsUserInput: needsUserInput
        )

        context.insert(draft)

        do {
            try context.save()
        } catch {
            return .result(dialog: "shortcut.error.save")
        }

        // Send push notification for automatic record (guard above ensures amount > 0, always expense)
        let automNotifAmount = YalaFormatter.currency(value: transaction.amount, currencyCode: normalizedCurrency, forceFullPrecision: true)
        let automNoteText = finalNote.isEmpty ? "" : " — \(finalNote)"
        let automNotifBody = L10n.Shortcut.Notification.body(L10n.Shortcut.Notification.expense, automNotifAmount, automNoteText)
        await NotificationService.shared.sendNotification(
            title: L10n.Shortcut.Notification.title,
            body: automNotifBody,
            deepLink: "inbox"
        )

        // Format success message
        let formattedAmount = formatIntentCurrency(amount: transaction.amount, currencyCode: normalizedCurrency)
        let noteDisplay = finalNote.isEmpty ? String(localized: "shortcut.automation.defaultNote") : finalNote
        return .result(dialog: "shortcut.automation.success \(formattedAmount) \(noteDisplay)")
    }

}

// MARK: - Siri Natural Language Entry Intent

struct SiriNaturalEntryIntent: AppIntent {

    static var title: LocalizedStringResource = "shortcut.siriNatural.title"
    static var description = IntentDescription("shortcut.siriNatural.description")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "shortcut.siriNatural.param.text",
               requestValueDialog: "shortcut.siriNatural.dialog.askText")
    var text: String?

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Step 1: Get text (request if not provided via Siri phrase)
        let finalText: String
        if let existingText = text, !existingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finalText = existingText.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let requested = try await $text.requestValue("shortcut.siriNatural.dialog.askText")
            guard !requested.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .result(dialog: "shortcut.siriNatural.error.noText")
            }
            finalText = requested.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Step 2: Pro gate — LLM parsing requires Pro subscription
        let isProUser = UserDefaults(suiteName: SharedContainerService.appGroupIdentifier)?.bool(forKey: "isProUser") ?? false

        guard isProUser else {
            return .result(dialog: "shortcut.siriNatural.error.proRequired")
        }

        // Step 3: Create ModelContainer
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: SwiftDataConfiguration.schema,
                configurations: SwiftDataConfiguration.configuration
            )
        } catch {
            #if DEBUG
            print("SiriNaturalEntryIntent: Error creating ModelContainer: \(error)")
            #endif
            return .result(dialog: "shortcut.error.database")
        }

        let context = container.mainContext

        // Step 4: Guard — at least 1 account configured
        let accountCount: Int
        do {
            accountCount = try context.fetchCount(FetchDescriptor<Account>())
        } catch {
            #if DEBUG
            print("SiriNaturalEntryIntent: Error fetching account count: \(error)")
            #endif
            accountCount = 0
        }
        guard accountCount > 0 else {
            return .result(dialog: "shortcut.error.noAccount")
        }

        // Step 5: Fetch subcategory lists for LLM context
        let subcategoryDescriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.isVisible },
            sortBy: [SortDescriptor(\Subcategory.name)]
        )
        let allSubcategories: [Subcategory]
        do {
            allSubcategories = try context.fetch(subcategoryDescriptor)
        } catch {
            #if DEBUG
            print("SiriNaturalEntryIntent: Error fetching subcategories: \(error)")
            #endif
            allSubcategories = []
        }

        let expenseSubcategories = allSubcategories
            .filter { !$0.safeCategory.isIncome }
            .map { $0.name }
        let incomeSubcategories = allSubcategories
            .filter { $0.safeCategory.isIncome }
            .map { $0.name }

        // Step 6: Parse with LLM (with offline fallback)
        var parsedTransactions: [ParsedTransaction] = []
        var isOfflineFallback = false

        do {
            parsedTransactions = try await TranscriptionParserService.shared.parseMultiple(
                text: finalText,
                expenseSubcategories: expenseSubcategories,
                incomeSubcategories: incomeSubcategories
            )
        } catch {
            #if DEBUG
            print("SiriNaturalEntryIntent: LLM parsing failed: \(error)")
            #endif

            // Offline fallback: try AmountParser for basic amount extraction
            isOfflineFallback = true
            if let parsed = AmountParser.parse(finalText) {
                let fallbackTransaction = ParsedTransaction(
                    amount: parsed.amount,
                    date: nil,
                    note: finalText,
                    isExpense: true,
                    subcategoryHint: nil,
                    tagHints: [],
                    currencyHint: nil,
                    confidence: ParsedTransaction.TransactionConfidence(
                        amount: parsed.confidence,
                        date: 0.0,
                        merchant: 0.0,
                        subcategory: 0.0,
                        tags: 0.0
                    )
                )
                parsedTransactions = [fallbackTransaction]
            }
        }

        // Guard: at least one parsed result
        guard !parsedTransactions.isEmpty else {
            return .result(dialog: "shortcut.siriNatural.error.parsingFailed")
        }

        // Step 7: Fetch existing pending drafts for deduplication
        let pendingDescriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate { $0.statusRaw == "pending" }
        )
        let existingDrafts: [InboxDraft]
        do {
            existingDrafts = try context.fetch(pendingDescriptor)
        } catch {
            #if DEBUG
            print("SiriNaturalEntryIntent: Error fetching pending drafts: \(error)")
            #endif
            existingDrafts = []
        }

        // Step 8: Create InboxDrafts from parsed transactions
        let merchantService = MerchantMemoryService(modelContext: context)
        var newDrafts: [InboxDraft] = []

        for parsed in parsedTransactions {
            var needsUserInput: [String] = []

            // Match account by currency hint
            var matchedAccount: Account?
            if let currencyHint = parsed.currencyHint {
                matchedAccount = findIntentAccount(byCurrency: currencyHint, context: context)
            }
            if matchedAccount == nil {
                needsUserInput.append("account")
            }

            // Match subcategory by hint
            var matchedSubcategory: Subcategory?
            if let subcategoryHint = parsed.subcategoryHint {
                matchedSubcategory = allSubcategories.first { sub in
                    sub.name.localizedCaseInsensitiveCompare(subcategoryHint) == .orderedSame
                }
            }

            // Fallback: MerchantMemory auto-categorization
            if matchedSubcategory == nil && !parsed.note.isEmpty {
                let suggestion = merchantService.suggest(for: parsed.note)
                switch suggestion {
                case .autoAssign(let sub):
                    matchedSubcategory = sub
                case .suggest(let sub):
                    matchedSubcategory = sub
                case .none:
                    break
                }
            }

            if matchedSubcategory == nil {
                needsUserInput.append("subcategory")
            }

            // Calculate signed amount
            let signedAmount: Double?
            if let amount = parsed.amount {
                let absValue = abs(NSDecimalNumber(decimal: amount).doubleValue)
                signedAmount = parsed.isExpense ? -absValue : absValue
            } else {
                signedAmount = nil
                needsUserInput.append("amount")
            }

            let draft = InboxDraft(
                note: parsed.note,
                amount: signedAmount,
                date: parsed.date,
                account: matchedAccount,
                subcategory: matchedSubcategory,
                sourceType: .siri,
                rawText: finalText,
                evidence: parsed.note.isEmpty ? nil : parsed.note,
                confidenceAmount: parsed.confidence.amount,
                confidenceDate: parsed.confidence.date,
                confidenceMerchant: parsed.confidence.merchant,
                confidenceSubcategory: parsed.confidence.subcategory,
                needsUserInput: needsUserInput
            )

            newDrafts.append(draft)
        }

        // Step 9: Deduplicate against existing pending drafts
        let uniqueDrafts = DraftDeduplicationService.deduplicate(
            newDrafts: newDrafts,
            existingDrafts: existingDrafts
        )

        guard !uniqueDrafts.isEmpty else {
            return .result(dialog: "shortcut.siriNatural.error.parsingFailed")
        }

        // Step 10: Insert and save
        for draft in uniqueDrafts {
            context.insert(draft)
        }

        do {
            try context.save()
        } catch {
            #if DEBUG
            print("SiriNaturalEntryIntent: Error saving drafts: \(error)")
            #endif
            return .result(dialog: "shortcut.error.save")
        }

        // Step 11: Send notification
        let firstNote = uniqueDrafts.first?.note ?? finalText
        let notifTitle = String(localized: "shortcut.siriNatural.notification.title")
        let notifBody: String
        if isOfflineFallback {
            notifBody = String(localized: "shortcut.siriNatural.notification.bodyOffline")
        } else {
            notifBody = String(localized: "shortcut.siriNatural.notification.body \(firstNote)")
        }
        await NotificationService.shared.sendNotification(
            title: notifTitle,
            body: notifBody,
            deepLink: "inbox"
        )

        // Step 12: Return confirmation dialog
        if isOfflineFallback {
            return .result(dialog: IntentDialog(stringLiteral:
                String(localized: "shortcut.siriNatural.success.offline \(firstNote)")))
        } else if uniqueDrafts.count == 1 {
            return .result(dialog: IntentDialog(stringLiteral:
                String(localized: "shortcut.siriNatural.success.single \(firstNote)")))
        } else {
            return .result(dialog: IntentDialog(stringLiteral:
                String(localized: "shortcut.siriNatural.success.multiple \(uniqueDrafts.count)")))
        }
    }
}

// MARK: - Shared Intent Helpers

private let intentCurrencyFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.maximumFractionDigits = 2
    return f
}()

private func formatIntentCurrency(amount: Double, currencyCode: String) -> String {
    intentCurrencyFormatter.currencyCode = currencyCode
    return intentCurrencyFormatter.string(from: NSNumber(value: amount)) ?? "\(currencyCode) \(amount)"
}

@MainActor
private func findIntentAccount(byCurrency currencyCode: String, context: ModelContext) -> Account? {
    let normalizedCode = currencyCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

    let descriptor = FetchDescriptor<Account>(
        predicate: #Predicate<Account> { account in
            account.isArchived == false
        }
    )

    let accounts: [Account]
    do {
        accounts = try context.fetch(descriptor)
    } catch {
        #if DEBUG
        print("findIntentAccount: Error fetching accounts: \(error)")
        #endif
        return nil
    }

    let matches = accounts.filter { $0.currencyCode.uppercased() == normalizedCode }
    return matches.count == 1 ? matches.first : nil
}
