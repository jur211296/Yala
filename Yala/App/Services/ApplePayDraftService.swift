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
    @discardableResult
    static func processPending(context: ModelContext) -> Int {
        // Gate de quiescencia (idéntico a ScheduledPaymentDraftService): crea InboxDrafts + `save()`
        // del store personal; diferir durante el import del restore de iCloud evita el
        // `_assertionFailure`/SIGTRAP interno de SwiftData. NO consumimos la cola si el gate no pasa
        // (los pagos persisten y se reintentan en el próximo arranque / trailing-edge).
        guard iCloudSyncService.shared.isImportQuiescent else {
            SaveBreadcrumb.deferred("ApplePayDraftService.processPending", "import not quiescent")
            return 0
        }

        // peek (NO consume): un fetch/save fallido o un crash antes del save deja la cola intacta →
        // se reintenta. Solo borramos las keys tras un `save()` exitoso (consume-after-save).
        let pending = ApplePayPendingStore.peekAll()
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
            var currency = parsed.currency
            if parsed.ambiguousSymbol != nil,
               let lastUsedID = LastUsedAccountStore.read(),
               let resolved = currencyOfAccount(shortcutID: lastUsedID, in: realAccounts) {
                currency = resolved
            }

            // Cuenta por divisa (único match entre cuentas reales; nil si 0 ó 2+ → user elige).
            let matchedAccount: Account? = currency.flatMap {
                DraftBuilder.findAccount(byCurrency: $0, in: realAccounts)
            }

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
            ApplePayPendingStore.remove(keys: droppedKeys)
            TelemetryService.track(.applePayPayloadDropped, parameters: ["count": String(droppedKeys.count)])
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
        ApplePayPendingStore.remove(keys: materializedKeys)
        TelemetryService.track(.applePayPayloadMaterialized, parameters: ["count": String(createdDrafts.count)])
        return createdDrafts.count
    }

    // MARK: - Helpers

    /// Lookup de currencyCode por shortcutID contra una lista ya fetcheada (resuelve `$`/`kr`).
    private static func currencyOfAccount(shortcutID: String, in accounts: [Account]) -> String? {
        guard UUID(uuidString: shortcutID) != nil else { return nil }
        return accounts.first { $0.shortcutID.uuidString == shortcutID }?.currencyCode
    }
}
