//
//  ApplePayDraftService.swift
//  Yala
//
//  Materializa los gastos de Apple Pay encolados por el intent (`ApplePayPendingStore`) como
//  `InboxDraft`s, DESDE LA APP (único dueño del store CloudKit). Reemplaza el patrón viejo en
//  que el intent creaba su propio `ModelContainer` y guardaba el draft él mismo — ese 2º
//  container dejaba una ventana de reconciliación que vaciaba la UI hasta un cold launch.
//
//  Gate de quiescencia idéntico a `ScheduledPaymentDraftService.processDuePayments` (evita el
//  `_assertionFailure`/SIGTRAP al hacer `save()` durante el import de CloudKit). El error-path SÍ
//  difiere de ese servicio: aquí la fuente (App Group) se consume, así que revertimos inserts y
//  dejamos la cola intacta para reintentar (consume-after-save), sin depender de un dedup por-id.
//
//  Ver `Bugs/applepay-shortcut-ios27-warm-launch-datos-vacios`.
//

import Foundation
import SwiftData

@MainActor
struct ApplePayDraftService {

    /// Convierte la cola de gastos de Apple Pay pendientes en `InboxDraft`s. Devuelve cuántos creó.
    /// Se llama en `bootstrap()`, en `handleBecameActive()` y en el trailing-edge del observer de
    /// remote-change; es idempotente (consume-after-save) y barato si la cola está vacía.
    /// `pendingStoreDefaults`: App Group real por default (intent/app); inyectable en tests
    /// para aislar la cola y evitar contaminación cross-test del App Group compartido.
    /// `importQuiescent`: por default lee el singleton `iCloudSyncService.shared` (producción);
    /// inyectable en tests para no depender del singleton global — que otras suites concurrentes
    /// (iCloudSyncServiceTests) mutan a no-quiescente → `return 0` → falso rojo cross-suite.
    @discardableResult
    static func processPending(
        context: ModelContext,
        pendingStoreDefaults: UserDefaults? = ApplePayPendingStore.appGroupDefaults,
        importQuiescent: Bool? = nil
    ) -> Int {
        // Gate de quiescencia (idéntico a ScheduledPaymentDraftService): crea InboxDrafts + `save()`
        // del store personal; diferir durante el import del restore de iCloud evita el
        // `_assertionFailure`/SIGTRAP interno de SwiftData. NO consumimos la cola si el gate no pasa
        // (los pagos persisten y se reintentan en el próximo arranque / trailing-edge).
        // nil (producción/intent) → lee el singleton main-actor; los tests inyectan `true` para no
        // depender de `iCloudSyncService.shared`, que otras suites concurrentes mutan a no-quiescente.
        guard importQuiescent ?? iCloudSyncService.shared.isImportQuiescent else {
            SaveBreadcrumb.deferred("ApplePayDraftService.processPending", "import not quiescent")
            return 0
        }

        // peek (NO consume): un fetch/save fallido o un crash antes del save deja la cola intacta →
        // se reintenta. Solo borramos las keys tras un `save()` exitoso (consume-after-save).
        let pending = ApplePayPendingStore.peekAll(defaults: pendingStoreDefaults)
        guard !pending.isEmpty else { return 0 }

        // Cuentas reales (excluye las de sistema: solo el bridge las asigna). Un solo fetch para
        // resolver divisa ambigua Y matchear cuenta.
        let realAccounts: [Account]
        do {
            realAccounts = try context.fetch(
                FetchDescriptor<Account>(predicate: #Predicate<Account> { $0.isSystemAccount == false })
            )
        } catch {
            #if DEBUG
            print("ApplePayDraftService: Error fetching accounts: \(error)")
            #endif
            // NO consumimos (peek no borró) → se reintenta en el próximo pase, sin perder pagos.
            return 0
        }

        var createdDrafts: [InboxDraft] = []
        var materializedKeys: [String] = []
        var droppedKeys: [String] = []

        for (key, payload) in pending {
            // Descartar montos no parseables o cero (un pago real nunca es 0; ej. auth/hold).
            guard let parsed = ApplePayAmountParser.parse(payload.rawAmount), parsed.amount != 0 else {
                #if DEBUG
                print("ApplePayDraftService: unparseable/zero amount, dropping payload")
                #endif
                droppedKeys.append(key)
                continue
            }

            // Resolver divisa ambigua ($/kr) por la última cuenta usada (App Group + cuentas reales).
            // Tarjeta con varias divisas (entrega 3, decisión D7): si la última cuenta usada es de una tarjeta cuya divisa
            // NO se escribe con ese símbolo, y la tarjeta tiene UNA cuenta que sí (`$` → su línea en dólares), el pago va a
            // esa cuenta. Antes, con la tarjeta en soles, un pago en `$` quedaba en soles (§2.13 del análisis). Con la
            // tarjeta en pesos (MXN, ARS, CLP…), `$` son pesos y manda la regla de siempre (review del 2026-10-18).
            let (currency, cardAccount) = resolveCurrency(
                parsedCurrency: parsed.currency,
                ambiguousSymbol: parsed.ambiguousSymbol,
                lastUsedShortcutID: LastUsedAccountStore.read(),
                in: realAccounts
            )

            // Cuenta por divisa (único match entre cuentas reales; nil si 0 ó 2+ → user elige). La de la tarjeta, si la hay.
            let matchedAccount = Self.matchedAccount(currency: currency, cardAccount: cardAccount, in: realAccounts)

            // Subcategoría por merchant (MerchantMemory) — preserva el routing de confianza del
            // intent viejo (autoAssign → 0.95, suggest → 0.8).
            let merchant = payload.merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            var matchedSubcategory: Subcategory?
            var subcategoryConfidence: Double?
            if !merchant.isEmpty {
                switch MerchantMemoryService(modelContext: context).suggest(for: merchant) {
                case .autoAssign(let sub):
                    matchedSubcategory = sub
                    subcategoryConfidence = 0.95
                case .suggest(let sub):
                    matchedSubcategory = sub
                    subcategoryConfidence = 0.8
                case .none:
                    break
                }
            }

            // D3: si no hay cuenta (0 cuentas o divisa no matcheable), el borrador se crea igual con
            // `account = nil` y "account" en needsUserInput; el usuario la asigna al aprobar.
            let needsUserInput = DraftBuilder.computeNeedsUserInput(
                hasAmount: true,
                hasAccount: matchedAccount != nil,
                hasSubcategory: matchedSubcategory != nil
            )

            let draft = InboxDraft(
                note: merchant,
                amount: -abs(parsed.amount),   // Apple Pay siempre es gasto (negativo)
                date: Date(timeIntervalSince1970: payload.savedAt),
                account: matchedAccount,
                subcategory: matchedSubcategory,
                sourceType: .applePay,
                rawText: payload.rawAmount,
                evidence: merchant.isEmpty ? nil : merchant,
                confidenceAmount: 1.0,
                confidenceDate: 1.0,
                confidenceMerchant: merchant.isEmpty ? nil : 1.0,
                confidenceSubcategory: subcategoryConfidence,
                needsUserInput: needsUserInput
            )
            context.insert(draft)
            createdDrafts.append(draft)
            materializedKeys.append(key)
        }

        // Los descartados (corruptos/cero) se borran aunque no haya nada que guardar (no reintentar).
        if !droppedKeys.isEmpty {
            ApplePayPendingStore.remove(keys: droppedKeys, defaults: pendingStoreDefaults)
        }

        guard !createdDrafts.isEmpty else { return 0 }

        do {
            SaveBreadcrumb.willSave("ApplePayDraftService.processPending")
            try context.save()
            SaveBreadcrumb.didSave("ApplePayDraftService.processPending")
        } catch {
            #if DEBUG
            print("ApplePayDraftService: Error saving drafts: \(error)")
            #endif
            // Save falló: revertir SOLO nuestros inserts (sin rollback global, que borraría otros
            // cambios pendientes) y NO borrar las keys → se reintentan. Sin pérdida ni duplicado.
            createdDrafts.forEach { context.delete($0) }
            return 0
        }

        // Save OK → borrar las keys materializadas. Residual documentado: un crash entre este save
        // y el remove reprocesaría los pagos → borrador duplicado (recuperable), nunca pérdida.
        ApplePayPendingStore.remove(keys: materializedKeys, defaults: pendingStoreDefaults)
        return createdDrafts.count
    }

    // MARK: - Moneda

    /// La moneda del borrador y, si va a una tarjeta con varias divisas, la cuenta de esa tarjeta. Un código o un símbolo
    /// inequívoco mandan; con `$`/`kr`, la de la última cuenta usada (o su línea que se escribe con ese símbolo); y sin
    /// ningún símbolo, también la de la última cuenta usada (auditoría UX 2.2, L15-8: hasta entonces el borrador quedaba
    /// sin moneda ni cuenta, y la notificación hablaba en dólares).
    static func resolveCurrency(
        parsedCurrency: String?,
        ambiguousSymbol: String?,
        lastUsedShortcutID: String?,
        in accounts: [Account]
    ) -> (currency: String?, cardAccount: Account?) {
        guard let lastUsedID = lastUsedShortcutID else { return (parsedCurrency, nil) }
        guard let symbol = ambiguousSymbol else {
            return (parsedCurrency ?? currencyOfAccount(shortcutID: lastUsedID, in: accounts), nil)
        }
        if let member = cardMember(lastUsedShortcutID: lastUsedID, ambiguousSymbol: symbol, in: accounts) {
            return (member.currencyCode, member)
        }
        return (currencyOfAccount(shortcutID: lastUsedID, in: accounts) ?? parsedCurrency, nil)
    }

    /// La cuenta a la que va el borrador: la de la tarjeta, o la ÚNICA cuenta en esa moneda (con 0 o 2+, la elige quien
    /// aprueba). Mientras no tenga cuenta, la Bandeja lo enseña en la moneda por defecto.
    static func matchedAccount(currency: String?, cardAccount: Account?, in accounts: [Account]) -> Account? {
        cardAccount ?? currency.flatMap { DraftBuilder.findAccount(byCurrency: $0, in: accounts) }
    }

    /// La pista que lee la notificación del atajo (`ApplePayCurrencyHint`, L15-8): la moneda en que la Bandeja va a
    /// enseñar el borrador —la de su cuenta— con la MISMA regla, sin símbolo y con `$` y `kr`. Sin cuenta, nada: la
    /// notificación cae a la moneda por defecto, como la Bandeja.
    static func currencyHint(lastUsedShortcutID: String?, accounts: [Account]) -> ApplePayCurrencyHint {
        func shownCurrency(parsedCurrency: String?, symbol: String?) -> String? {
            let (currency, card) = resolveCurrency(
                parsedCurrency: parsedCurrency, ambiguousSymbol: symbol, lastUsedShortcutID: lastUsedShortcutID, in: accounts)
            return matchedAccount(currency: currency, cardAccount: card, in: accounts)?.currencyCode
        }
        var bySymbol: [String: String] = [:]
        for symbol in ["$", "kr"] {
            // La moneda que el parseo le da al símbolo cuando nada la refina (USD, NOK).
            let symbolDefault = ApplePayAmountParser.parse("\(symbol)1")?.currency
            bySymbol[symbol] = shownCurrency(parsedCurrency: symbolDefault, symbol: symbol)
        }
        return ApplePayCurrencyHint(
            lastUsedAccountID: lastUsedShortcutID,
            noSymbolCurrency: shownCurrency(parsedCurrency: nil, symbol: nil),
            currencyBySymbol: bySymbol)
    }

    /// Reescribe la pista con las cuentas de ahora. La llaman el arranque, la vuelta a primer plano y el guardado de un
    /// movimiento (que es quien cambia la última cuenta usada). Un fetch que falla deja la pista que había. Cambiar la
    /// moneda de una cuenta, borrarla o fundirla no la reescribe: la deja vieja hasta el siguiente primer plano, y la
    /// notificación de ese rato puede decir la moneda de antes (residual aceptado).
    static func refreshCurrencyHint(context: ModelContext) {
        do {
            let accounts = try context.fetch(
                FetchDescriptor<Account>(predicate: #Predicate<Account> { $0.isSystemAccount == false })
            )
            ApplePayCurrencyHint.write(currencyHint(lastUsedShortcutID: LastUsedAccountStore.read(), accounts: accounts))
        } catch {
            #if DEBUG
            print("ApplePayDraftService: Error refreshing currency hint: \(error)")
            #endif
        }
    }

    // MARK: - Helpers

    /// La cuenta de la tarjeta de la última cuenta usada que se escribe con `ambiguousSymbol`, si es la ÚNICA de la tarjeta
    /// y la última cuenta usada no se escribe ella misma con ese símbolo (`AccountCardLogic.route` hacia esa divisa). En
    /// cualquier otro caso `nil`, y la regla de siempre (la divisa de la última cuenta usada) decide: una cuenta sin líneas,
    /// una tarjeta en pesos con `$`, o dos líneas que se escriben igual.
    static func cardMember(lastUsedShortcutID: String, ambiguousSymbol: String, in accounts: [Account]) -> Account? {
        guard let lastUsed = UUID(uuidString: lastUsedShortcutID),
              let lastUsedAccount = accounts.first(where: { $0.shortcutID == lastUsed }) else { return nil }
        func writesWithSymbol(_ code: String) -> Bool {
            CurrencyCode(rawValue: code.uppercased())?.symbol == ambiguousSymbol
        }
        guard !writesWithSymbol(lastUsedAccount.currencyCode) else { return nil }
        let nodes = accounts.map { AccountLineNode($0) }
        let candidates = AccountCardLogic.liveMembers(of: lastUsed, nodes: nodes).filter { writesWithSymbol($0.currencyCode) }
        guard candidates.count == 1, let target = candidates.first,
              let route = AccountCardLogic.route(chosenID: lastUsed, currencyCode: target.currencyCode, nodes: nodes),
              !route.isFallback else { return nil }
        return accounts.first { $0.shortcutID == route.accountID }
    }

    /// Lookup de currencyCode por shortcutID contra una lista ya fetcheada (resuelve `$`/`kr`).
    private static func currencyOfAccount(shortcutID: String, in accounts: [Account]) -> String? {
        guard UUID(uuidString: shortcutID) != nil else { return nil }
        return accounts.first { $0.shortcutID.uuidString == shortcutID }?.currencyCode
    }
}
