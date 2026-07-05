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
        Summary("Record from Apple Pay the fields amount: \(\.$amount) and merchant: \(\.$merchant)")
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
    func perform() async throws -> some IntentResult {
        TelemetryService.track(.intentInvoked, parameters: ["intent_type": "applePay"])

        guard let amountString = amount else {
            TelemetryService.track(.intentFailed, parameters: ["intent_type": "applePay", "error": "no_amount"])
            await notifyFailure()
            return .result()
        }

        // El intent NO toca SwiftData: encola el pago CRUDO en App Group y la app crea el
        // `InboxDraft` al abrir (`ApplePayDraftService`). Abrir un 2º `ModelContainer` aquí dejaba
        // una ventana de reconciliación que vaciaba la UI hasta un cold launch. Ver
        // `Bugs/applepay-shortcut-ios27-warm-launch-datos-vacios`.

        // Parseo PURO (sin base de datos) solo para formatear la notificación. La divisa ambigua
        // ($/kr) la resuelve la app al materializar; aquí, fallback razonable por símbolo.
        // Monto no parseable o cero (ej. auth/hold de $0) → no es un gasto real: avisar y no encolar.
        guard let parsed = ApplePayAmountParser.parse(amountString), parsed.amount != 0 else {
            TelemetryService.track(.intentFailed, parameters: ["intent_type": "applePay", "error": "no_amount"])
            await notifyFailure()
            return .result()
        }

        let merchantText = merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Encolar el gasto para que la app lo materialice como borrador al abrir.
        ApplePayPendingStore.append(
            ApplePayPendingExpense(
                rawAmount: amountString,
                merchant: merchantText.isEmpty ? nil : merchantText,
                savedAt: Date.now.timeIntervalSince1970
            )
        )
        IntentSignalBreadcrumb.set("applePay")

        let notifCurrency = parsed.currency ?? "USD"
        let notifAmount = YalaFormatterStatic.currency(value: abs(parsed.amount), currencyCode: notifCurrency, forceFullPrecision: true)
        let noteText = merchantText.isEmpty ? "" : " — \(merchantText)"
        let notifBody = L10n.Shortcut.Notification.body(L10n.Shortcut.Notification.expense, notifAmount, noteText)

        // Sin ProvidesDialog/ShowsSnippetView: la automation Wallet corre con la pantalla
        // bloqueada, donde iOS no puede presentar UI → reportaría "no se pudo ejecutar el
        // atajo". El único feedback es la notificación local (sí llega bloqueada). Se envía con
        // `await` (no Task.detached): sendNotification solo consulta permisos +
        // notificationCenter.add() (~ms), muy por debajo del budget, y await garantiza el envío
        // antes de que el proceso del intent termine.
        await NotificationService.shared.sendNotification(
            title: L10n.Shortcut.Notification.title,
            body: notifBody,
            deepLink: "inbox"
        )

        TelemetryService.track(.intentSuccess, parameters: ["intent_type": "applePay", "outcome": "draft_queued"])
        return .result()
    }

    // MARK: - Helpers

    /// Notificación de fallo. Sin dialog ni throw: la automation Wallet corre con la
    /// pantalla bloqueada y cualquier UI haría que iOS reporte "no se pudo ejecutar el
    /// atajo". La notif local sí llega bloqueada, así el usuario sabe que su pago no se
    /// registró. `deepLink: nil` porque en los paths de fallo no hay draft que abrir.
    @MainActor
    private func notifyFailure() async {
        await NotificationService.shared.sendNotification(
            title: L10n.Shortcut.Notification.errorTitle,
            body: L10n.Shortcut.Notification.errorBody,
            deepLink: nil
        )
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
            // `.none` (local-only): igual que ApplePay, evita el 2º mirror CloudKit sobre el
            // store de la app (error 134410 in-process). La app exporta el write vía history.
            container = try ModelContainer(
                for: SwiftDataConfiguration.personalSchema,
                configurations: SwiftDataConfiguration.personalLocalWriteConfiguration
            )
            IntentSignalBreadcrumb.intentContainerCreated(cloudKit: false, errorCode: nil)
        } catch {
            #if DEBUG
            print("SiriNaturalEntryIntent: Error creating ModelContainer: \(error)")
            #endif
            IntentSignalBreadcrumb.intentContainerCreated(cloudKit: false, errorCode: (error as NSError).code)
            return .result(dialog: "shortcut.error.database", view: EmptyView())
        }

        let context = container.mainContext

        // Step 4: Guard — at least 1 real account configured (system accounts excluded — only the bridge assigns them)
        let accountCount: Int
        do {
            accountCount = try context.fetchCount(
                FetchDescriptor<Account>(predicate: #Predicate<Account> { $0.isSystemAccount == false })
            )
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

        // Señal cross-launch (igual que ApplePay): la app refresca al volver a foreground.
        PendingIntentSaveSignal.mark()
        IntentSignalBreadcrumb.set("siriNatural")

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
            dialogText = L10n.Shortcut.successPartial(uniqueDrafts.count, parsedTransactions.count)
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
            account.isArchived == false && account.isSystemAccount == false
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
