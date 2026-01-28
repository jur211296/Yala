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

@available(iOS 16.0, *)
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

@available(iOS 16.0, *)
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
        // Step 1: Get transaction type (expense or income)
        let finalType = try await getTransactionType()
        let isIncome = (finalType == .income)

        // Step 2: Get amount (always positive)
        let finalAmount = try await getAmount()

        // Step 3: Get note (optional, can be empty)
        let finalNote = try await getNote()

        // Step 4: Get account
        let accountEntity = try await getAccount()

        // Step 5: Get subcategory (filtered by type)
        let subcategoryName: String
        let subcategoryCategoryName: String

        if isIncome {
            let incomeEntity = try await getIncomeSubcategory()
            subcategoryName = incomeEntity.name
            subcategoryCategoryName = incomeEntity.categoryName
        } else {
            let expenseEntity = try await getExpenseSubcategory()
            subcategoryName = expenseEntity.name
            subcategoryCategoryName = expenseEntity.categoryName
        }

        // Step 6: Get tag name (optional text field)
        let finalTagName = try await getTagName()

        // Create ModelContainer
        let schema = Schema([
            Category.self,
            Subcategory.self,
            Tag.self,
            Account.self,
            TransactionItem.self,
            Budget.self,
            ExchangeRate.self,
            FavoritePayment.self,
            ScheduledPayment.self,
            InboxDraft.self,
            MerchantMemory.self,
        ])

        let configuration = ModelConfiguration("YalaModel")

        guard let container = try? ModelContainer(for: schema, configurations: configuration) else {
            return .result(dialog: "shortcut.error.database")
        }

        let context = container.mainContext

        // Resolve account
        guard let resolvedAccount = fetchAccount(name: accountEntity.name, context: context) else {
            return .result(dialog: "shortcut.error.noAccount")
        }

        // Resolve subcategory
        guard let resolvedSubcategory = fetchSubcategory(name: subcategoryName, categoryName: subcategoryCategoryName, context: context) else {
            return .result(dialog: "shortcut.error.noSubcategory")
        }

        // Resolve tag (optional - search by name if provided)
        var resolvedTag: Tag?
        if let name = finalTagName, !name.isEmpty {
            resolvedTag = fetchTag(name: name, context: context)
        }

        // Get exchange rate info
        let preferredCurrency = UserDefaults.standard.string(forKey: "preferredCurrency") ?? "PEN"
        let transactionCurrency = resolvedAccount.currencyCode

        var exchangeRate = 1.0
        var amountInPreferred = finalAmount
        var isProvisional = false

        if transactionCurrency != preferredCurrency {
            let converter = CurrencyConverter.shared
            let convertedDecimal = converter.convert(
                Decimal(finalAmount),
                from: transactionCurrency,
                to: preferredCurrency,
                on: Date(),
                context: context
            )
            amountInPreferred = NSDecimalNumber(decimal: convertedDecimal).doubleValue

            if finalAmount > 0 {
                exchangeRate = amountInPreferred / finalAmount
            }

            isProvisional = !converter.hasExactRate(for: Date(), context: context)
        }

        // Create transaction
        let transaction = TransactionItem(
            date: Date(),
            amount: finalAmount,
            currencyCode: transactionCurrency,
            note: finalNote,
            category: resolvedSubcategory.category,
            subcategory: resolvedSubcategory,
            account: resolvedAccount,
            tags: resolvedTag.map { [$0] } ?? [],
            exchangeRate: exchangeRate,
            amountInPreferredCurrency: amountInPreferred,
            preferredCurrencyCode: preferredCurrency,
            isExchangeRateProvisional: isProvisional
        )

        context.insert(transaction)

        do {
            try context.save()
        } catch {
            return .result(dialog: "shortcut.error.save")
        }

        // Format success message with all details
        let formattedAmount = formatCurrency(amount: finalAmount, currencyCode: transactionCurrency)
        let noteText = (finalNote?.isEmpty == false) ? finalNote! : "-"
        let subcategoryText = resolvedSubcategory.name
        let tagText = resolvedTag?.name ?? String(localized: "shortcut.result.noTag")

        let successMessage = String(localized: "shortcut.success.expenseDetail \(resolvedAccount.name) \(formattedAmount) \(noteText) \(subcategoryText) \(tagText)")

        return .result(dialog: IntentDialog(stringLiteral: successMessage))
    }

    // MARK: - Parameter Resolution

    private func getTransactionType() async throws -> TransactionTypeAppEnum {
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
        return try? context.fetch(descriptor).first
    }

    private func fetchSubcategory(name: String, categoryName: String, context: ModelContext) -> Subcategory? {
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.name == name }
        )
        guard let subcategories = try? context.fetch(descriptor) else { return nil }
        return subcategories.first { $0.category.name == categoryName }
    }

    private func fetchTag(name: String, context: ModelContext) -> Tag? {
        let descriptor = FetchDescriptor<Tag>()
        guard let tags = try? context.fetch(descriptor) else { return nil }

        // Case-insensitive and diacritic-insensitive matching
        let normalizedInput = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        return tags.first { tag in
            let normalizedTagName = tag.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return normalizedTagName == normalizedInput
        }
    }

    private func formatCurrency(amount: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currencyCode) \(amount)"
    }
}

// MARK: - Intent Errors

@available(iOS 16.0, *)
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

@available(iOS 16.0, *)
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

@available(iOS 16.0, *)
struct AccountQuery: EntityQuery {

    @MainActor
    func entities(for identifiers: [String]) async throws -> [AccountAppEntity] {
        let allEntities = try await suggestedEntities()
        return allEntities.filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [AccountAppEntity] {
        let schema = Schema([
            Category.self, Subcategory.self, Tag.self, Account.self,
            TransactionItem.self, Budget.self, ExchangeRate.self,
            FavoritePayment.self, ScheduledPayment.self, InboxDraft.self, MerchantMemory.self
        ])
        let configuration = ModelConfiguration("YalaModel")

        guard let container = try? ModelContainer(for: schema, configurations: configuration) else {
            return []
        }

        let context = container.mainContext
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\Account.name)]
        )

        guard let accounts = try? context.fetch(descriptor) else { return [] }

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

@available(iOS 16.0, *)
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

@available(iOS 16.0, *)
struct ExpenseSubcategoryQuery: EntityQuery {

    @MainActor
    func entities(for identifiers: [String]) async throws -> [ExpenseSubcategoryAppEntity] {
        let allEntities = try await suggestedEntities()
        return allEntities.filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [ExpenseSubcategoryAppEntity] {
        let schema = Schema([
            Category.self, Subcategory.self, Tag.self, Account.self,
            TransactionItem.self, Budget.self, ExchangeRate.self,
            FavoritePayment.self, ScheduledPayment.self, InboxDraft.self, MerchantMemory.self
        ])
        let configuration = ModelConfiguration("YalaModel")

        guard let container = try? ModelContainer(for: schema, configurations: configuration) else {
            return []
        }

        let context = container.mainContext
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.isVisible },
            sortBy: [SortDescriptor(\Subcategory.name)]
        )

        guard let subcategories = try? context.fetch(descriptor) else { return [] }

        // Filter ONLY expense subcategories (isIncome = false)
        // Sort by category A-Z, then subcategory A-Z
        return subcategories
            .filter { $0.category.isIncome == false }
            .sorted { first, second in
                if first.category.name != second.category.name {
                    return first.category.name < second.category.name
                }
                return first.name < second.name
            }
            .map { subcategory in
                ExpenseSubcategoryAppEntity(
                    id: "\(subcategory.category.name):\(subcategory.name)",
                    name: subcategory.name,
                    categoryName: subcategory.category.name
                )
            }
    }
}

// MARK: - Income Subcategory App Entity (isIncome = true)

@available(iOS 16.0, *)
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

@available(iOS 16.0, *)
struct IncomeSubcategoryQuery: EntityQuery {

    @MainActor
    func entities(for identifiers: [String]) async throws -> [IncomeSubcategoryAppEntity] {
        let allEntities = try await suggestedEntities()
        return allEntities.filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [IncomeSubcategoryAppEntity] {
        let schema = Schema([
            Category.self, Subcategory.self, Tag.self, Account.self,
            TransactionItem.self, Budget.self, ExchangeRate.self,
            FavoritePayment.self, ScheduledPayment.self, InboxDraft.self, MerchantMemory.self
        ])
        let configuration = ModelConfiguration("YalaModel")

        guard let container = try? ModelContainer(for: schema, configurations: configuration) else {
            return []
        }

        let context = container.mainContext
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.isVisible },
            sortBy: [SortDescriptor(\Subcategory.name)]
        )

        guard let subcategories = try? context.fetch(descriptor) else { return [] }

        // Filter ONLY income subcategories (isIncome = true)
        // Sort by category A-Z, then subcategory A-Z
        return subcategories
            .filter { $0.category.isIncome == true }
            .sorted { first, second in
                if first.category.name != second.category.name {
                    return first.category.name < second.category.name
                }
                return first.name < second.name
            }
            .map { subcategory in
                IncomeSubcategoryAppEntity(
                    id: "\(subcategory.category.name):\(subcategory.name)",
                    name: subcategory.name,
                    categoryName: subcategory.category.name
                )
            }
    }
}

// MARK: - Voice Entry Intent

@available(iOS 16.0, *)
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

        // Open the app with voice-entry URL
        if let url = URL(string: "yala://voice-entry") {
            await UIApplication.shared.open(url)
        }

        return .result()
    }
}

// MARK: - Image Entry Intent

@available(iOS 16.0, *)
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

        // Open the app with image-entry URL
        if let url = URL(string: "yala://image-entry") {
            await UIApplication.shared.open(url)
        }

        return .result()
    }
}

// MARK: - Voice/Image Intent Errors

@available(iOS 16.0, *)
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
