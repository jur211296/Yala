//
//  BankNoticeDraftService.swift
//  Yala
//
//  Convierte en borradores de la Bandeja los avisos del banco que dejó la acción de Atajos en `BankNoticePendingStore`.
//  Molde de `ApplePayDraftService`: gate de quiescencia del import, consume-after-save y, si el `save()` falla, revierte
//  solo sus inserts y deja la cola para el siguiente pase. Lo llama solo `InboundCaptureDrain`.
//
//  - Movimiento: borrador por confirmar con el importe con signo, la cuenta por divisa (la última usada para un `$` o un
//    aviso sin moneda, como Apple Pay) y la subcategoría que recuerde el comercio.
//  - «No entendimos este aviso»: borrador sin importe con el texto del aviso como descripción, para completarlo.
//  - Origen: `.automation` con el banco en la evidencia (`BankNoticeBank.brandName`); la Bandeja lo enseña como «Aviso de
//    BCP». Un caso propio en `DraftSourceType` lo leería como `.voice` un build anterior que reciba el borrador por iCloud.
//
//  La cuenta (2026-11-20, `CuentaSolaAlLeer`): los últimos cuatro dígitos del aviso contra los del «Número de cuenta»
//  de cada cuenta y el nombre del banco contra el nombre de las cuentas, sin conexión. Si no deciden, la regla de siempre.
//

import Foundation
import SwiftData

@MainActor
enum BankNoticeDraftService {

    /// Lo que cabe del texto del aviso como descripción de un borrador que no se entendió.
    nonisolated static let notUnderstoodNoteLimit = 140

    @discardableResult
    static func processPending(
        context: ModelContext,
        pendingStoreDefaults: UserDefaults? = BankNoticePendingStore.appGroupDefaults,
        importQuiescent: Bool? = nil
    ) -> Int {
        guard importQuiescent ?? iCloudSyncService.shared.isImportQuiescent else {
            SaveBreadcrumb.deferred("BankNoticeDraftService.processPending", "import not quiescent")
            return 0
        }
        let pending = BankNoticePendingStore.peekAll(defaults: pendingStoreDefaults)
        guard !pending.isEmpty else { return 0 }

        let realAccounts: [Account]
        do {
            realAccounts = try context.fetch(
                FetchDescriptor<Account>(predicate: #Predicate<Account> { $0.isSystemAccount == false })
            )
        } catch {
            #if DEBUG
            print("BankNoticeDraftService: Error fetching accounts: \(error)")
            #endif
            return 0
        }

        var createdDrafts: [InboxDraft] = []
        var materializedKeys: [String] = []
        var droppedKeys: [String] = []

        for (key, entry) in pending {
            guard let draft = makeDraft(for: entry, accounts: realAccounts, context: context) else {
                droppedKeys.append(key)
                continue
            }
            context.insert(draft)
            createdDrafts.append(draft)
            materializedKeys.append(key)
        }

        if !droppedKeys.isEmpty {
            BankNoticePendingStore.remove(keys: droppedKeys, defaults: pendingStoreDefaults)
        }
        guard !createdDrafts.isEmpty else { return 0 }

        do {
            SaveBreadcrumb.willSave("BankNoticeDraftService.processPending")
            try context.save()
            SaveBreadcrumb.didSave("BankNoticeDraftService.processPending")
        } catch {
            #if DEBUG
            print("BankNoticeDraftService: Error saving drafts: \(error)")
            #endif
            createdDrafts.forEach { context.delete($0) }
            return 0
        }
        BankNoticePendingStore.remove(keys: materializedKeys, defaults: pendingStoreDefaults)
        return createdDrafts.count
    }

    /// El borrador de un aviso, o `nil` si no deja ninguno (no era un movimiento).
    static func makeDraft(for entry: BankNoticePendingEntry, accounts: [Account], context: ModelContext) -> InboxDraft? {
        let evidence = (entry.bank ?? .other).brandName
        let date = Date(timeIntervalSince1970: entry.receivedAt)
        switch entry.reading {
        case .notAMovement:
            return nil
        case .notUnderstood:
            return InboxDraft(
                note: notUnderstoodNote(entry.rawText),
                amount: nil,
                date: date,
                sourceType: .automation,
                rawText: entry.rawText,
                evidence: evidence,
                confidenceDate: 1.0,
                needsUserInput: DraftBuilder.computeNeedsUserInput(hasAmount: false, hasAccount: false, hasSubcategory: false)
            )
        case .movement(let movement, let ruleID):
            let (currency, cardAccount) = ApplePayDraftService.resolveCurrency(
                parsedCurrency: movement.currencyCode,
                ambiguousSymbol: movement.ambiguousSymbol,
                lastUsedShortcutID: LastUsedAccountStore.read(),
                in: accounts
            )
            let account = accountFromNotice(bank: entry.bank, last4: movement.cardLast4, currency: currency, in: accounts)
                ?? defaultAccount(for: entry.bank, currency: currency, in: accounts)
                ?? ApplePayDraftService.matchedAccount(currency: currency, cardAccount: cardAccount, in: accounts)
            let counterparty = movement.counterparty ?? ""
            var subcategory: Subcategory?
            var subcategoryConfidence: Double?
            if !counterparty.isEmpty {
                switch MerchantMemoryService(modelContext: context).suggest(for: counterparty, isExpense: movement.isExpense) {
                case .autoAssign(let sub):
                    subcategory = sub
                    subcategoryConfidence = 0.95
                case .suggest(let sub):
                    subcategory = sub
                    subcategoryConfidence = 0.8
                case .none:
                    // Sin recuerdo, el banco de comercios del teléfono: «TAMBO+ MIRAFLORES» es un supermercado. El aviso no
                    // pasa por la IA; solo cuentan las categorías del banco que no dejan duda (`VisionMerchantKind.fromCatalog`).
                    if let known = MerchantKindSubcategory.subcategory(
                        kind: nil, merchant: counterparty, isExpense: movement.isExpense,
                        in: MerchantKindSubcategory.fetchVisible(context: context)) {
                        subcategory = known
                        subcategoryConfidence = 0.6
                    }
                }
            }
            let magnitude = NSDecimalNumber(decimal: movement.amount).doubleValue
            return InboxDraft(
                note: counterparty,
                amount: movement.isExpense ? -abs(magnitude) : abs(magnitude),
                date: date,
                account: account,
                subcategory: subcategory,
                sourceType: .automation,
                rawText: entry.rawText,
                evidence: evidence,
                // Una regla da la cifra exacta; el modelo del iPhone, una cifra que está en el aviso pero que hay que mirar.
                confidenceAmount: ruleID == nil ? 0.8 : 1.0,
                confidenceDate: 1.0,
                confidenceMerchant: counterparty.isEmpty ? nil : (ruleID == nil ? 0.6 : 1.0),
                confidenceSubcategory: subcategoryConfidence,
                needsUserInput: DraftBuilder.computeNeedsUserInput(
                    hasAmount: true, hasAccount: account != nil, hasSubcategory: subcategory != nil)
            )
        }
    }

    /// La cuenta que dicen los últimos 4 del aviso o el nombre de su banco (`CuentaSolaAlLeer`), o `nil` si no deciden.
    static func accountFromNotice(bank: BankNoticeBank?, last4: String?, currency: String?, in accounts: [Account]) -> Account? {
        let mention = bank.flatMap { $0 == .other ? nil : $0.brandName }
        guard mention != nil || last4 != nil else { return nil }
        let choice = DraftBuilder.chooseAccount(mention: mention, last4: last4, currency: currency, in: accounts)
        return choice.resultado.cuentaPuesta == nil ? nil : choice.account
    }

    /// La «Cuenta por defecto» que la persona eligió para ese banco (B2), si sigue viva, sin archivar y en la moneda del
    /// aviso (o el aviso no dice moneda). Va después de los últimos 4 y el nombre del banco: lo que dice el aviso manda.
    static func defaultAccount(
        for bank: BankNoticeBank?, currency: String?, in accounts: [Account],
        defaults: UserDefaults? = BankNoticeActivityStore.appGroupDefaults
    ) -> Account? {
        guard let bank, let id = BankNoticeActivityStore.settings(for: bank, defaults: defaults).defaultAccountShortcutID,
              let account = accounts.first(where: { $0.shortcutID == id && !$0.isArchived }) else { return nil }
        guard let currency else { return account }
        return account.currencyCode.uppercased() == currency.uppercased() ? account : nil
    }

    /// La descripción de un borrador que no se entendió: el aviso en una línea, recortado.
    nonisolated static func notUnderstoodNote(_ rawText: String) -> String {
        let line = BankNoticeParser.normalized(rawText)
        guard line.count > notUnderstoodNoteLimit else { return line }
        return String(line.prefix(notUnderstoodNoteLimit - 1)) + "…"
    }
}
