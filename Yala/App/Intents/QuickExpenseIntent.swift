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

        // Step 3: Leer el contexto cacheado por la app (subcategorías para el LLM + divisa + cuentas).
        // El intent NO abre SwiftData: un 2º `ModelContainer` sobre el store de la app dejaba una
        // ventana de reconciliación que vaciaba la UI hasta un cold launch. En su lugar hace SOLO el
        // parseo LLM (red) y encola el resultado; la app materializa los drafts al abrir
        // (`SiriDraftService`). Ver `Bugs/applepay-shortcut-ios27-warm-launch-datos-vacios`.
        let cachedContext = SiriIntentContextCache.read()

        // Guard de cuenta: bloqueamos SOLO si la caché EXISTE y confirma 0 cuentas reales. Si es nil
        // (primer uso, app nunca abierta post-instalación) NO bloqueamos — encolamos igual y la app
        // crea el draft con "account" en needsUserInput (evita el falso "no hay cuentas" por caché
        // ausente/stale).
        if let cachedContext, !cachedContext.hasRealAccount {
            TelemetryService.track(.intentFailed, parameters: ["intent_type": "siriNatural", "error": "no_account"])
            return .result(dialog: "shortcut.error.noAccount", view: EmptyView())
        }

        // Step 4: Parse with LLM (con offline fallback). Las subcategorías salen de la caché.
        var parsedTransactions: [ParsedTransaction] = []
        var isOfflineFallback = false
        do {
            parsedTransactions = try await TranscriptionParserService.shared.parseMultiple(
                text: finalText,
                expenseSubcategories: cachedContext?.expenseSubcategories ?? [],
                incomeSubcategories: cachedContext?.incomeSubcategories ?? []
            )
        } catch {
            #if DEBUG
            print("SiriNaturalEntryIntent: LLM parsing failed: \(error)")
            #endif
            // Offline fallback: AmountParser para extracción básica del monto.
            isOfflineFallback = true
            if let parsed = AmountParser.parse(finalText) {
                parsedTransactions = [ParsedTransaction(
                    amount: parsed.amount,
                    date: nil,
                    note: finalText,
                    isExpense: true,
                    subcategoryHint: nil,
                    tagHints: [],
                    currencyHint: nil,
                    confidence: ParsedTransaction.TransactionConfidence(
                        amount: parsed.confidence, date: 0.0, merchant: 0.0, subcategory: 0.0, tags: 0.0
                    )
                )]
            }
        }

        // Pre-flight quality gate: descarta transactions sin amount. Si TODAS fallan → error.
        let validParsed = parsedTransactions.filter { $0.amount != nil }
        guard !validParsed.isEmpty else {
            TelemetryService.track(.intentFailed, parameters: ["intent_type": "siriNatural", "error": "parsing_failed"])
            return .result(dialog: "shortcut.siriNatural.error.parsingFailedHelp", view: EmptyView())
        }
        let partialFailures = parsedTransactions.count - validParsed.count

        // Step 5: Encolar el lote para que la app lo materialice como borrador(es) al abrir. El
        // conteo del dialog usa `validParsed.count`: la app crea un borrador por transacción válida
        // (sin dedup, igual que ApplePay), así que el conteo hablado coincide con lo que llega a la
        // Bandeja (salvo un reproceso raro tras crash, que duplicaría — recuperable).
        SiriPendingStore.append(SiriPendingEntry(
            rawText: finalText,
            transactions: validParsed,
            savedAt: Date.now.timeIntervalSince1970
        ))
        IntentSignalBreadcrumb.set("siriNatural")

        // Step 6: Notificación local (la app refresca la Bandeja al abrir).
        let firstParsed = validParsed.first
        let firstNote = (firstParsed?.note).flatMap { $0.isEmpty ? nil : $0 } ?? finalText
        let notifBody = isOfflineFallback
            ? String(localized: "shortcut.siriNatural.notification.bodyOffline")
            : String(localized: "shortcut.siriNatural.notification.body \(firstNote)")
        await NotificationService.shared.sendNotification(
            title: String(localized: "shortcut.siriNatural.notification.title"),
            body: notifBody,
            deepLink: "inbox"
        )

        // Step 7: Speak-back + snippet visual del primer movimiento (datos del PARSEO — cuenta/
        // subcategoría canónicas las resuelve la app; aquí placeholder/hint).
        let dialogText: String
        if isOfflineFallback {
            dialogText = String(localized: "shortcut.siriNatural.success.offline \(firstNote)")
        } else if partialFailures > 0 {
            dialogText = L10n.Shortcut.successPartial(validParsed.count, parsedTransactions.count)
        } else if validParsed.count == 1 {
            dialogText = String(localized: "shortcut.siriNatural.success.single \(firstNote)")
        } else {
            dialogText = String(localized: "shortcut.siriNatural.success.multiple \(validParsed.count)")
        }

        let expensesOnlyMode = UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)?.bool(forKey: AppPreferences.Keys.expensesOnlyMode) ?? false
        let snippetIsExpense = expensesOnlyMode ? true : (firstParsed?.isExpense ?? true)
        let snippetAmount = firstParsed?.amount.map { abs(NSDecimalNumber(decimal: $0).doubleValue) } ?? 0
        let snippet = TransactionSnippetView(
            amount: snippetAmount,
            currencyCode: firstParsed?.currencyHint ?? cachedContext?.defaultCurrency ?? "USD",
            accountName: "—",
            subcategoryName: firstParsed?.subcategoryHint ?? firstNote,
            subcategoryIcon: "text.bubble",
            date: firstParsed?.date ?? Date.now,
            isExpense: snippetIsExpense,
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
