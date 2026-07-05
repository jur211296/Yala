//
//  SiriDraftService.swift
//  Yala
//
//  Materializa los dictados de Siri encolados por el intent (`SiriPendingStore`) como `InboxDraft`s,
//  DESDE LA APP (único dueño del store CloudKit). Reemplaza el patrón viejo en que el intent creaba
//  su propio `ModelContainer` y guardaba los drafts él mismo — ese 2º container dejaba una ventana
//  de reconciliación que vaciaba la UI hasta un cold launch.
//
//  El intent ya hizo el parseo LLM (red); aquí solo resolvemos cuenta/subcategoría contra el store
//  (SwiftData). NO dedupeamos (igual que ApplePay: "nunca perder un gasto capturado" — ver el bloque
//  del bucle). Gate de quiescencia idéntico a `ApplePayDraftService` /
//  `ScheduledPaymentDraftService` (evita el `_assertionFailure`/SIGTRAP al hacer `save()` durante el
//  import de CloudKit). Consume-after-save: la cola (App Group) solo se limpia tras un `save()` OK.
//
//  Ver `Bugs/applepay-shortcut-ios27-warm-launch-datos-vacios`.
//

import Foundation
import SwiftData

@MainActor
struct SiriDraftService {

    /// Convierte la cola de dictados de Siri pendientes en `InboxDraft`s. Devuelve cuántos creó.
    /// Se llama en `bootstrap()`, en `handleBecameActive()` y en el trailing-edge del observer de
    /// remote-change; es idempotente (consume-after-save) y barato si la cola está vacía.
    @discardableResult
    static func processPending(context: ModelContext) -> Int {
        // Gate de quiescencia (idéntico a ApplePayDraftService): crea InboxDrafts + `save()` del store
        // personal; diferir durante el import del restore de iCloud evita el `_assertionFailure`/
        // SIGTRAP interno de SwiftData. NO consumimos la cola si el gate no pasa (los dictados
        // persisten y se reintentan en el próximo arranque / trailing-edge).
        guard iCloudSyncService.shared.isImportQuiescent else {
            SaveBreadcrumb.deferred("SiriDraftService.processPending", "import not quiescent")
            return 0
        }

        // peek (NO consume): un fetch/save fallido o un crash antes del save deja la cola intacta →
        // se reintenta. Solo borramos las keys tras un `save()` exitoso (consume-after-save).
        let pending = SiriPendingStore.peekAll()
        guard !pending.isEmpty else { return 0 }

        // Fetches del lote (una vez para todos los dictados): cuentas reales (excluye las de sistema:
        // solo el bridge las asigna), subcategorías visibles y drafts pendientes para dedup.
        let realAccounts: [Account]
        do {
            realAccounts = try context.fetch(
                FetchDescriptor<Account>(predicate: #Predicate<Account> { $0.isSystemAccount == false })
            )
        } catch {
            #if DEBUG
            print("SiriDraftService: Error fetching accounts: \(error)")
            #endif
            return 0   // NO consumimos (peek no borró) → se reintenta, sin perder dictados.
        }

        let visibleSubcategories: [Subcategory]
        do {
            visibleSubcategories = try context.fetch(
                FetchDescriptor<Subcategory>(predicate: #Predicate<Subcategory> { $0.isVisible == true })
            )
        } catch {
            #if DEBUG
            print("SiriDraftService: Error fetching subcategories: \(error)")
            #endif
            visibleSubcategories = []
        }

        let expensesOnlyMode = UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)?
            .bool(forKey: AppPreferences.Keys.expensesOnlyMode) ?? false

        // Construir los drafts por dictado. Un dictado sin ninguna transacción con `amount` se
        // descarta (drop la key sin materializar nada). NO dedupeamos: igual que ApplePay, cada
        // dictado válido produce su(s) borrador(es) — filosofía "nunca perder un gasto capturado".
        // (El dedup contra pendientes colapsaba silenciosamente dos gastos idénticos reales del
        // mismo día; un reproceso tras crash crea un duplicado recuperable, nunca una pérdida.)
        var materializedKeys: [String] = []
        var droppedKeys: [String] = []
        var accepted: [InboxDraft] = []

        for (key, entry) in pending {
            let fallbackDate = Date(timeIntervalSince1970: entry.savedAt)
            let candidates = entry.transactions.compactMap { parsed in
                buildDraft(
                    from: parsed,
                    rawText: entry.rawText,
                    fallbackDate: fallbackDate,
                    realAccounts: realAccounts,
                    visibleSubcategories: visibleSubcategories,
                    expensesOnlyMode: expensesOnlyMode,
                    context: context
                )
            }
            guard !candidates.isEmpty else {
                droppedKeys.append(key)
                continue
            }
            accepted.append(contentsOf: candidates)
            materializedKeys.append(key)
        }

        // Los descartados (sin transacción válida) se borran aunque no haya nada que guardar.
        if !droppedKeys.isEmpty {
            SiriPendingStore.remove(keys: droppedKeys)
            TelemetryService.track(.siriPayloadDropped, parameters: ["count": String(droppedKeys.count)])
        }

        // Nada válido que insertar (todos los dictados sin transacción parseable): salir.
        guard !accepted.isEmpty else { return 0 }

        for draft in accepted { context.insert(draft) }

        do {
            SaveBreadcrumb.willSave("SiriDraftService.processPending")
            try context.save()
            SaveBreadcrumb.didSave("SiriDraftService.processPending")
        } catch {
            #if DEBUG
            print("SiriDraftService: Error saving drafts: \(error)")
            #endif
            // Save falló: revertir SOLO nuestros inserts (sin rollback global) y NO borrar las keys →
            // se reintentan. Sin pérdida ni duplicado.
            accepted.forEach { context.delete($0) }
            return 0
        }

        // Save OK → borrar las keys materializadas. Residual documentado: un crash entre este save y
        // el remove reprocesaría el dictado, pero el dedup del próximo pase lo absorbe.
        SiriPendingStore.remove(keys: materializedKeys)
        TelemetryService.track(.siriPayloadMaterialized, parameters: ["count": String(accepted.count)])
        return accepted.count
    }

    // MARK: - Helpers

    /// Mapea un `ParsedTransaction` a un `InboxDraft` resolviendo cuenta/subcategoría contra el store.
    /// `nil` solo si la transacción no tiene `amount` (el intent ya filtró, pero es defensivo).
    /// `internal` (no `private`) para testear la materialización sin el gate de quiescencia del
    /// singleton `iCloudSyncService` (que hace `processPending` no-aislable, igual que
    /// `ScheduledPaymentDraftService.processDuePayments`).
    static func buildDraft(
        from parsed: ParsedTransaction,
        rawText: String,
        fallbackDate: Date,
        realAccounts: [Account],
        visibleSubcategories: [Subcategory],
        expensesOnlyMode: Bool,
        context: ModelContext
    ) -> InboxDraft? {
        guard let amount = parsed.amount else { return nil }

        // Cuenta por divisa (único match entre cuentas reales; nil si 0 ó 2+ → user elige al aprobar).
        let matchedAccount: Account? = parsed.currencyHint.flatMap {
            DraftBuilder.findAccount(byCurrency: $0, in: realAccounts)
        }

        // Subcategoría por hint del LLM; fallback a MerchantMemory (aprendizaje por merchant/nota).
        var matchedSubcategory: Subcategory?
        if let hint = parsed.subcategoryHint, !hint.isEmpty {
            matchedSubcategory = DraftBuilder.matchSubcategoryByHint(
                hint: hint,
                isExpense: parsed.isExpense,
                in: visibleSubcategories
            )
        }
        if matchedSubcategory == nil && !parsed.note.isEmpty {
            matchedSubcategory = DraftBuilder.suggestSubcategory(merchant: parsed.note, context: context)
        }

        // Respeta expensesOnlyMode: si activo, fuerza gasto ignorando lo que infirió el LLM
        // (consistente con el intent viejo + QuickExpense + ApplePay).
        let isExpense = expensesOnlyMode ? true : parsed.isExpense
        let absValue = abs(NSDecimalNumber(decimal: amount).doubleValue)
        let signedAmount = isExpense ? -absValue : absValue

        let needsUserInput = DraftBuilder.computeNeedsUserInput(
            hasAmount: true,
            hasAccount: matchedAccount != nil,
            hasSubcategory: matchedSubcategory != nil
        )

        return InboxDraft(
            note: parsed.note,
            amount: signedAmount,
            // Fecha del parseo si el LLM la infirió; si no, la del dictado (`savedAt`) — un gasto
            // dictado sin fecha ocurrió ~ahora. Espeja a ApplePay (siempre estampa fecha) y cumple
            // el contrato de `SiriPendingEntry.savedAt`. Sin esto el draft queda sin fecha.
            date: parsed.date ?? fallbackDate,
            account: matchedAccount,
            subcategory: matchedSubcategory,
            sourceType: .siri,
            rawText: rawText,
            evidence: parsed.note.isEmpty ? nil : parsed.note,
            confidenceAmount: parsed.confidence.amount,
            confidenceDate: parsed.confidence.date,
            confidenceMerchant: parsed.confidence.merchant,
            confidenceSubcategory: parsed.confidence.subcategory,
            needsUserInput: needsUserInput
        )
    }
}
