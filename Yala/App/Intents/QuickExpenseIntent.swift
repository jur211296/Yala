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
        if let url = WidgetURLHelper.url(for: "new-transaction") {
            await UIApplication.shared.open(url)
        }
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
        if let url = WidgetURLHelper.url(for: "voice-entry") {
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
        if let url = WidgetURLHelper.url(for: "image-entry") {
            await UIApplication.shared.open(url)
        }
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
        guard let amountString = amount else {
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

        // «Pago de S/ 25,90 en Tambo por revisar · Tócalo para aprobarlo.» (auditoría UX 2.2, lote 15, L15-8): es un
        // borrador por aprobar, no un registro. La moneda es la que pondrá el borrador (`ApplePayCurrencyHint`): sin
        // símbolo, la de la última cuenta usada; antes caía a dólares y contradecía a la Bandeja.
        let notifCurrency = ApplePayCurrencyHint.notificationCurrency(
            parsedCurrency: parsed.currency,
            ambiguousSymbol: parsed.ambiguousSymbol,
            hint: ApplePayCurrencyHint.read(),
            lastUsedAccountID: LastUsedAccountStore.read(),
            defaultCurrency: SiriIntentContextCache.read()?.defaultCurrency
        )
        let notifAmount = YalaFormatterStatic.currency(value: abs(parsed.amount), currencyCode: notifCurrency, forceFullPrecision: true)
        let notifTitle = L10n.Shortcut.Notification.applePayTitle(amount: notifAmount, merchant: merchantText)

        // Sin ProvidesDialog/ShowsSnippetView: la automation Wallet corre con la pantalla
        // bloqueada, donde iOS no puede presentar UI → reportaría "no se pudo ejecutar el
        // atajo". El único feedback es la notificación local (sí llega bloqueada). Se envía con
        // `await` (no Task.detached): sendNotification solo consulta permisos +
        // notificationCenter.add() (~ms), muy por debajo del budget, y await garantiza el envío
        // antes de que el proceso del intent termine.
        await NotificationService.shared.sendNotification(
            title: notifTitle,
            body: L10n.Shortcut.Notification.applePayBody,
            deepLink: "inbox"
        )

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

    /// En segundo plano siempre, salvo sin Pro: entonces abre Yala en la hoja de Pro (`continueInForeground`).
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

    @Parameter(title: "shortcut.siriNatural.param.text",
               requestValueDialog: "shortcut.siriNatural.dialog.askText")
    var text: String?

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        // Step 1: ¿Pro? Se mira ANTES de pedir el texto: sin Pro, dictarlo para tirarlo era perderlo. Sin Pro, Siri lo
        // dice y abre Yala en la hoja de Pro de la voz (auditoría UX 2.2, lote 15, L15-6, opción B). Si el modelo del
        // iPhone está encendido y disponible, el usuario gratis anota igual leyendo el texto en el teléfono
        // (`SiriOnDeviceEntry`, apagado hasta que Jürgen decida).
        let isProUser = UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)?.bool(forKey: AppPreferences.Keys.isProUser) ?? false
        let route = SiriEntryRoute.decide(
            isPro: isProUser,
            onDeviceEnabled: SiriOnDeviceEntry.isEnabled,
            onDeviceAvailable: SiriOnDeviceEntry.isEnabled && SiriOnDeviceEntry.isAvailable
        )
        if route == .upgrade {
            return .result(dialog: await openProSheet(), view: EmptyView())
        }

        // Step 2: Get text (request if not provided via Siri phrase)
        let finalText: String
        if let existingText = text, !existingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finalText = existingText.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let requested = try await $text.requestValue(IntentSpeech.dialog("shortcut.siriNatural.dialog.askText"))
            guard !requested.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .result(dialog: IntentSpeech.dialog("shortcut.siriNatural.error.noText"), view: EmptyView())
            }
            finalText = requested.trimmingCharacters(in: .whitespacesAndNewlines)
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
            return .result(dialog: IntentSpeech.dialog("shortcut.error.noAccount"), view: EmptyView())
        }

        // Step 4: Parse with LLM (con offline fallback). Las subcategorías salen de la caché. Sin el consentimiento de
        // IA el texto no sale del teléfono: solo la lectura local del monto (auditoría UX 2.2, lote 15).
        // En el teléfono (`.onDevice`) el texto no sale de él, así que no hace falta ese consentimiento.
        let aiConsentAccepted = UserDefaults.standard.bool(forKey: AppPreferences.Keys.aiDataConsentAccepted)
        let (parsedTransactions, isOfflineFallback) = await Self.parseTransactions(
            finalText,
            consentAccepted: route == .onDevice || aiConsentAccepted
        ) { text in
            if route == .onDevice {
                return try await SiriOnDeviceEntry.parse(
                    text,
                    expenseSubcategories: cachedContext?.expenseSubcategories ?? [],
                    incomeSubcategories: cachedContext?.incomeSubcategories ?? []
                )
            }
            return try await TranscriptionParserService.shared.parseMultiple(
                text: text,
                expenseSubcategories: cachedContext?.expenseSubcategories ?? [],
                incomeSubcategories: cachedContext?.incomeSubcategories ?? [],
                currency: cachedContext?.parserCurrency ?? .unknown
            )
        }

        // Pre-flight quality gate: descarta transactions sin amount. Si TODAS fallan → error.
        let validParsed = parsedTransactions.filter { $0.amount != nil }
        guard !validParsed.isEmpty else {
            return .result(dialog: IntentSpeech.dialog("shortcut.siriNatural.error.parsingFailedHelp"), view: EmptyView())
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
        // «(sin conexión)» solo es verdad si se intentó leer en el servidor y falló; sin consentimiento no se intentó.
        let notifBody = isOfflineFallback && aiConsentAccepted && route == .server
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
        return .result(dialog: IntentSpeech.resolved(dialogText), view: snippet)
    }

    /// Sin Pro: Siri dice «Activa Yala Pro…» y Yala se abre en la hoja de Pro de la voz (el atajo `voice-entry`, que sin
    /// Pro presenta esa hoja; con Pro —si el App Group iba atrasado—, la grabación de voz). Si la persona no deja abrir
    /// Yala, Siri se queda en el aviso, como antes.
    @MainActor
    private func openProSheet() async -> IntentDialog {
        let dialog = IntentSpeech.dialog("shortcut.siriNatural.error.proRequired")
        do {
            // Sin diálogo propio: el aviso va en el resultado, y pasarlo también aquí podía decirse dos veces.
            try await continueInForeground(nil, alwaysConfirm: false)
        } catch {
            #if DEBUG
            print("SiriNaturalEntryIntent: no se abrió Yala para la hoja de Pro: \(error)")
            #endif
            return dialog
        }
        if let url = WidgetURLHelper.url(for: "voice-entry") {
            await UIApplication.shared.open(url)
        }
        return dialog
    }

    /// Lee el texto dictado. Con el consentimiento de IA lo manda a `remote` (el LLM, a través del servidor) y, si
    /// falla, cae a la lectura local del monto. **Sin el consentimiento, `remote` no se llama**: el texto no sale del
    /// teléfono y queda la lectura local, como sin conexión. Hasta el lote 15 de la auditoría UX 2.2 el atajo mandaba
    /// el texto a OpenAI aunque la persona no hubiera aceptado el aviso de «Procesamiento de voz e imágenes»: la voz y
    /// la foto de la app lo piden siempre (`AppBootstrapper.executeAction`) y este atajo no lo miraba.
    @MainActor
    static func parseTransactions(
        _ text: String,
        consentAccepted: Bool,
        remote: (String) async throws -> [ParsedTransaction]
    ) async -> (transactions: [ParsedTransaction], isOfflineFallback: Bool) {
        if consentAccepted {
            do {
                return (try await remote(text), false)
            } catch {
                #if DEBUG
                print("SiriNaturalEntryIntent: LLM parsing failed: \(error)")
                #endif
            }
        }
        // Lectura local: AmountParser para extracción básica del monto.
        guard let parsed = AmountParser.parse(text) else { return ([], true) }
        return ([ParsedTransaction(
            amount: parsed.amount,
            date: nil,
            note: text,
            isExpense: true,
            subcategoryHint: nil,
            tagHints: [],
            currencyHint: nil,
            confidence: ParsedTransaction.TransactionConfidence(
                amount: parsed.confidence, date: 0.0, merchant: 0.0, subcategory: 0.0, tags: 0.0
            )
        )], true)
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
