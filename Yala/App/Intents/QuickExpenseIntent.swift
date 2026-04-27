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

// MARK: - Quick Entry Intent

/// Atajo "Nuevo registro": abre la app con la pantalla de Nueva Transacción.
/// Reusa el mismo deep-link que el HomeScreen widget Yala — la UI del sheet
/// gestiona los defaults (cuenta, tipo, etc.) igual que cuando se abre desde el FAB.
struct QuickExpenseIntent: AppIntent {

    static var title: LocalizedStringResource = "shortcut.quickExpense.title"
    static var description = IntentDescription("shortcut.quickExpense.description")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        TelemetryService.track(.intentInvoked, parameters: ["intent_type": "quickExpense"])
        if let url = WidgetURLHelper.url(for: "new-transaction") {
            await UIApplication.shared.open(url)
        }
        TelemetryService.track(.intentSuccess, parameters: ["intent_type": "quickExpense", "outcome": "app_opened"])
        return .result()
    }
}

// MARK: - Voice Entry Intent

struct VoiceEntryIntent: AppIntent {

    static var title: LocalizedStringResource = "shortcut.voiceEntry.title"
    static var description = IntentDescription("shortcut.voiceEntry.description")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        TelemetryService.track(.intentInvoked, parameters: ["intent_type": "voiceEntry"])
        if let url = WidgetURLHelper.url(for: "voice-entry") {
            await UIApplication.shared.open(url)
        }
        TelemetryService.track(.intentSuccess, parameters: ["intent_type": "voiceEntry", "outcome": "app_opened"])
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
        TelemetryService.track(.intentInvoked, parameters: ["intent_type": "imageEntry"])
        if let url = WidgetURLHelper.url(for: "image-entry") {
            await UIApplication.shared.open(url)
        }
        TelemetryService.track(.intentSuccess, parameters: ["intent_type": "imageEntry", "outcome": "app_opened"])
        return .result()
    }
}

// MARK: - Apple Pay Transaction Intent

struct ApplePayTransactionIntent: AppIntent {

    static var title: LocalizedStringResource = "shortcut.applePay.title"
    static var description = IntentDescription("shortcut.applePay.description")

    static var openAppWhenRun: Bool = false

    // MARK: - Parameter Summary (shows configurable fields in Shortcuts)

    static var parameterSummary: some ParameterSummary {
        Summary("Record an expense of \(\.$amount) at \(\.$merchant)")
    }

    init() {}

    // MARK: - Parameters
    // Solo `amount` lleva inputConnectionBehavior — iOS auto-conecta el primer
    // String? con ese trait al primer output del trigger Wallet. Aplicarlo a
    // varios parameters hace que el matching falle silenciosamente, así que
    // `merchant` se conecta manualmente desde el editor de Atajos.

    @Parameter(
        title: "shortcut.applePay.param.amount",
        description: "shortcut.applePay.param.amount.description",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var amount: String?

    @Parameter(
        title: "shortcut.applePay.param.merchant",
        description: "shortcut.applePay.param.merchant.description"
    )
    var merchant: String?

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        TelemetryService.track(.intentInvoked, parameters: ["intent_type": "applePay"])

        guard let amountString = amount else {
            TelemetryService.track(.intentFailed, parameters: ["intent_type": "applePay", "error": "no_amount"])
            return .result(dialog: "shortcut.applePay.error.noAmount", view: EmptyView())
        }

        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: SwiftDataConfiguration.personalSchema,
                configurations: SwiftDataConfiguration.personalConfiguration
            )
        } catch {
            #if DEBUG
            print("ApplePayTransactionIntent: Error creating ModelContainer: \(error)")
            #endif
            return .result(dialog: "shortcut.error.database", view: EmptyView())
        }

        let context = container.mainContext

        guard let parsedResult = parseAmountAndCurrency(from: amountString, context: context) else {
            TelemetryService.track(.intentFailed, parameters: ["intent_type": "applePay", "error": "no_amount"])
            return .result(dialog: "shortcut.applePay.error.noAmount", view: EmptyView())
        }

        let finalAmount = parsedResult.amount
        let detectedCurrency = parsedResult.currency
        let finalNote = merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let effectiveDate = Date.now

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
            return .result(dialog: "shortcut.error.noAccount", view: EmptyView())
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

        // Confidence routing: autoAssign (≥5 aprobs, ≤10% error) → 0.95; suggest → 0.8.
        var matchedSubcategory: Subcategory?
        var subcategoryConfidence: Double?
        if !finalNote.isEmpty {
            let merchantService = MerchantMemoryService(modelContext: context)
            let suggestion = merchantService.suggest(for: finalNote)

            switch suggestion {
            case .autoAssign(let sub):
                matchedSubcategory = sub
                subcategoryConfidence = 0.95
                needsUserInput.removeAll { $0 == "subcategory" }
            case .suggest(let sub):
                matchedSubcategory = sub
                subcategoryConfidence = 0.8
            case .none:
                break
            }
        }

        // Create InboxDraft (Apple Pay siempre crea draft → user revisa en Inbox)
        let draft = InboxDraft(
            note: finalNote,
            amount: -abs(finalAmount), // Apple Pay is always expense (negative)
            date: effectiveDate,
            account: matchedAccount,
            subcategory: matchedSubcategory,
            sourceType: .applePay,
            rawText: amount, // Store original amount string for reference
            evidence: finalNote.isEmpty ? nil : finalNote,
            confidenceAmount: 1.0,
            confidenceDate: 1.0,
            confidenceMerchant: finalNote.isEmpty ? nil : 1.0,
            confidenceSubcategory: subcategoryConfidence,
            needsUserInput: needsUserInput
        )

        context.insert(draft)

        do {
            try context.save()
        } catch {
            return .result(dialog: "shortcut.error.save", view: EmptyView())
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

        // Snippet con badge "Borrador" — el user revisa/aprueba en Inbox.
        let formattedAmount = formatIntentCurrency(amount: finalAmount, currencyCode: detectedCurrency ?? "USD")
        let noteDisplay = finalNote.isEmpty ? "Apple Pay" : finalNote
        let snippet = TransactionSnippetView(
            amount: finalAmount,
            currencyCode: detectedCurrency ?? "USD",
            accountName: matchedAccount?.name ?? "—",
            subcategoryName: matchedSubcategory?.name ?? noteDisplay,
            subcategoryIcon: matchedSubcategory?.safeCategory.iconName ?? "creditcard",
            date: effectiveDate,
            isExpense: true,
            isDraft: true
        )
        TelemetryService.track(.intentSuccess, parameters: ["intent_type": "applePay", "outcome": "draft_created"])
        return .result(
            dialog: "shortcut.applePay.success \(formattedAmount) \(noteDisplay)",
            view: snippet
        )
    }

    // MARK: - Helpers

    /// Parses amount and currency from Wallet text format
    /// Examples: "$32.04" -> (32.04, "USD"), "S/ 25.90" -> (25.90, "PEN"), "€25,50" -> (25.50, "EUR")
    /// Símbolos ambiguos (`$` para USD/ARS/CLP/MXN, `kr` para NOK/SEK/DKK) se resuelven
    /// con la currency del lastUsedAccount cuando existe; sin él, fallback al símbolo default.
    @MainActor
    private func parseAmountAndCurrency(from text: String, context: ModelContext) -> (amount: Double, currency: String?)? {
        // Symbols ordered by priority (más específicos primero — "MX$" antes de "$")
        let prefixedSymbols: [(symbol: String, code: String)] = [
            ("MX$", "MXN"), ("COP$", "COP"), ("R$", "BRL"),
            ("A$", "AUD"), ("C$", "CAD"), ("NZ$", "NZD"), ("HK$", "HKD"),
            ("S/.", "PEN"), ("S/", "PEN"),
            ("€", "EUR"), ("£", "GBP"), ("¥", "JPY"),
            ("Fr", "CHF"), ("₣", "CHF"),
            ("kr", "NOK"),  // Ambiguo (NOK/SEK/DKK) — resolver por account
            ("$", "USD")     // Ambiguo (USD/ARS/CLP/MXN/etc) — resolver por account
        ]

        var detectedCurrency: String?
        var detectedSymbol: String?

        for entry in prefixedSymbols {
            if text.contains(entry.symbol) {
                detectedCurrency = entry.code
                detectedSymbol = entry.symbol
                break
            }
        }

        // Trailing currency code: "25.00 ARS" → ARS (override de símbolo ambiguo).
        let words = text.components(separatedBy: .whitespaces)
        if let lastWord = words.last,
           lastWord.count == 3,
           lastWord.uppercased() == lastWord {
            detectedCurrency = lastWord
            detectedSymbol = nil
        }

        // Ambiguous symbols ($ y kr): override con currency del lastUsedAccount si existe.
        if detectedSymbol == "$" || detectedSymbol == "kr" {
            if let lastUsedID = LastUsedAccountStore.read(),
               let accountCurrency = Self.currencyOfAccount(shortcutID: lastUsedID, context: context) {
                detectedCurrency = accountCurrency
            }
        }

        // Extract numeric value
        var cleaned = text.replacingOccurrences(of: "[^\\d.,\\-]", with: "", options: .regularExpression)

        // Handle European format (comma as decimal separator)
        if cleaned.contains(",") {
            if !cleaned.contains(".") {
                // Only comma: 25,50 -> 25.50
                cleaned = cleaned.replacing(",", with: ".")
            } else if let commaIndex = cleaned.lastIndex(of: ","),
                      let dotIndex = cleaned.lastIndex(of: "."),
                      commaIndex > dotIndex {
                // Comma after dot: 1.234,56 -> 1234.56
                cleaned = cleaned.replacing(".", with: "")
                cleaned = cleaned.replacing(",", with: ".")
            } else {
                // Dot after comma: 1,234.56 -> 1234.56 (US format with thousands separator)
                cleaned = cleaned.replacing(",", with: "")
            }
        }

        guard let amount = Double(cleaned) else {
            return nil
        }

        return (amount, detectedCurrency)
    }

    /// Lookup de currencyCode por shortcutID. Usado para desambiguar `$` y `kr`.
    @MainActor
    fileprivate static func currencyOfAccount(shortcutID: String, context: ModelContext) -> String? {
        guard UUID(uuidString: shortcutID) != nil else { return nil }
        let descriptor = FetchDescriptor<Account>()
        do {
            let all = try context.fetch(descriptor)
            return all.first { $0.shortcutID.uuidString == shortcutID }?.currencyCode
        } catch {
            return nil
        }
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
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        TelemetryService.track(.intentInvoked, parameters: ["intent_type": "siriNatural"])
        // Step 1: Get text (request if not provided via Siri phrase)
        let finalText: String
        if let existingText = text, !existingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finalText = existingText.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let requested = try await $text.requestValue("shortcut.siriNatural.dialog.askText")
            guard !requested.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .result(dialog: "shortcut.siriNatural.error.noText", view: EmptyView())
            }
            finalText = requested.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Step 2: Pro gate — LLM parsing requires Pro subscription
        let isProUser = UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)?.bool(forKey: AppPreferences.Keys.isProUser) ?? false

        guard isProUser else {
            TelemetryService.track(.intentFailed, parameters: ["intent_type": "siriNatural", "error": "pro_required"])
            return .result(dialog: "shortcut.siriNatural.error.proRequired", view: EmptyView())
        }

        // Step 3: Create ModelContainer
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: SwiftDataConfiguration.personalSchema,
                configurations: SwiftDataConfiguration.personalConfiguration
            )
        } catch {
            #if DEBUG
            print("SiriNaturalEntryIntent: Error creating ModelContainer: \(error)")
            #endif
            return .result(dialog: "shortcut.error.database", view: EmptyView())
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
            return .result(dialog: "shortcut.error.noAccount", view: EmptyView())
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

        // Pre-flight quality gate: descarta transactions sin amount.
        // Si TODAS fallan → error explicativo (mejor que crear drafts basura).
        let validParsed = parsedTransactions.filter { $0.amount != nil }
        guard !validParsed.isEmpty else {
            TelemetryService.track(.intentFailed, parameters: ["intent_type": "siriNatural", "error": "parsing_failed"])
            return .result(dialog: "shortcut.siriNatural.error.parsingFailedHelp", view: EmptyView())
        }
        // Si parcial: trabajamos con las válidas (informamos en speak-back final).
        let partialFailures = parsedTransactions.count - validParsed.count
        let workingParsed = validParsed

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

        for parsed in workingParsed {
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

            // Respeta expensesOnlyMode: si activo, fuerza isExpense=true ignorando
            // lo que el LLM haya inferido (consistente con QuickExpense + ApplePay).
            let expensesOnlyMode = UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)?.bool(forKey: AppPreferences.Keys.expensesOnlyMode) ?? false
            let isExpense = expensesOnlyMode ? true : parsed.isExpense

            let signedAmount: Double?
            if let amount = parsed.amount {
                let absValue = abs(NSDecimalNumber(decimal: amount).doubleValue)
                signedAmount = isExpense ? -absValue : absValue
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
            return .result(dialog: "shortcut.siriNatural.error.parsingFailed", view: EmptyView())
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
            return .result(dialog: "shortcut.error.save", view: EmptyView())
        }

        // Step 11: Send notification
        let firstDraft = uniqueDrafts.first
        let firstNote = firstDraft?.note ?? finalText
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

        // Speak-back TTS-friendly + snippet visual del primer draft.
        let dialogText: String
        if isOfflineFallback {
            dialogText = String(localized: "shortcut.siriNatural.success.offline \(firstNote)")
        } else if partialFailures > 0 {
            dialogText = String(localized: "shortcut.siriNatural.success.partial \(uniqueDrafts.count) \(parsedTransactions.count)")
        } else if uniqueDrafts.count == 1 {
            dialogText = String(localized: "shortcut.siriNatural.success.single \(firstNote)")
        } else {
            dialogText = String(localized: "shortcut.siriNatural.success.multiple \(uniqueDrafts.count)")
        }

        let snippet = TransactionSnippetView(
            amount: abs(firstDraft?.amount ?? 0),
            currencyCode: firstDraft?.account?.currencyCode ?? "USD",
            accountName: firstDraft?.account?.name ?? "—",
            subcategoryName: firstDraft?.subcategory?.name ?? firstNote,
            subcategoryIcon: firstDraft?.subcategory?.safeCategory.iconName ?? "text.bubble",
            date: firstDraft?.date ?? Date.now,
            isExpense: (firstDraft?.amount ?? 0) < 0,
            isDraft: true
        )
        let outcome = isOfflineFallback ? "draft_offline" : (partialFailures > 0 ? "draft_partial" : "draft_created")
        TelemetryService.track(.intentSuccess, parameters: ["intent_type": "siriNatural", "outcome": outcome])
        return .result(dialog: IntentDialog(stringLiteral: dialogText), view: snippet)
    }
}

// MARK: - Last Used Account Store (F5)

/// Memoria per-device (App Group) de la última cuenta usada al registrar una transacción.
/// Permite a QuickExpenseIntent saltarse la pregunta de cuenta cuando el atajo no la fija.
/// NO se sincroniza vía iCloud KV — la "última cuenta usada" es contextual al device.
enum LastUsedAccountStore {
    /// Lee el UUID-string de la última cuenta usada (o nil si no existe).
    nonisolated static func read() -> String? {
        UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)?
            .string(forKey: AppPreferences.Keys.lastUsedAccountID)
    }

    /// Persiste el UUID-string de la cuenta. No-op si el valor ya está escrito (evita flush inútil de UserDefaults).
    nonisolated static func write(_ shortcutID: String) {
        guard read() != shortcutID else { return }
        UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)?
            .set(shortcutID, forKey: AppPreferences.Keys.lastUsedAccountID)
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
