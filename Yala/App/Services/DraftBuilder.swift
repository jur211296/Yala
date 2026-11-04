//
//  DraftBuilder.swift
//  Yala
//
//  Helpers compartidos por VisionDraftFactory (image input → InboxDraft) y
//  ChatAssistantService (chat → ChatTransactionDraft) para mapear texto/visión
//  parseado a una propuesta de transacción con account/subcategory inferidos.
//
//  API granular para que cada caller arme su propio modelo final:
//  - findAccount(byCurrency:context:)         — match por divisa, exacto o nil.
//  - suggestSubcategory(merchant:isExpense:context:) — vía MerchantMemoryService,
//                                                descartando lo que contradiga el tipo.
//  - computeNeedsUserInput(...)               — campos críticos sin inferencia.
//  - build(parsed:defaultCurrency:context:)   — compone los anteriores en un
//                                                ChatTransactionDraft (caller chat).
//

import Foundation
import SwiftData

@MainActor
struct DraftBuilder {

    // MARK: - findAccount

    /// Pure-logic match contra una lista ya fetcheada. Filtra archivadas internamente
    /// por si el caller no lo hizo. 1 match exacto → devuelve la cuenta; 0 ó 2+ → nil.
    ///
    /// La usan TODAS las capturas que eligen cuenta por la divisa dictada (chat, voz, imagen, Siri, Apple Pay). Una línea de
    /// una tarjeta con varias divisas es una cuenta más de su divisa: con la tarjeta en soles y su línea en dólares como única
    /// cuenta en USD, un importe en USD va a la línea (entrega 3). Las cuentas de sistema de Grupos no son elegibles: solo
    /// las asigna el bridge (A0-Bridge), como en Siri y Apple Pay, que ya las quitaban antes de llamar.
    static func findAccount(byCurrency currencyCode: String, in accounts: [Account]) -> Account? {
        let normalizedCode = currencyCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCode.isEmpty else { return nil }

        let matches = accounts
            .filter { !$0.isArchived && !$0.isSystemAccount }
            .filter { $0.currencyCode.uppercased() == normalizedCode }
        return matches.count == 1 ? matches.first : nil
    }

    /// Las cuentas sin archivar. Si el fetch falla, ninguna (y el borrador pide la cuenta).
    static func fetchActiveAccounts(context: ModelContext) -> [Account] {
        do {
            return try context.fetch(FetchDescriptor<Account>(predicate: #Predicate<Account> { account in account.isArchived == false }))
        } catch {
            #if DEBUG
            print("DraftBuilder: Error fetching accounts: \(error)")
            #endif
            return []
        }
    }

    /// Convenience: fetch desde el context y delega al overload puro.
    /// Devuelve `nil` si el fetch falla o no hay match único.
    static func findAccount(byCurrency currencyCode: String, context: ModelContext) -> Account? {
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
            print("DraftBuilder: Error fetching accounts by currency: \(error)")
            #endif
            return nil
        }

        return findAccount(byCurrency: currencyCode, in: accounts)
    }

    // MARK: - findAccount por medio de pago

    /// Las cuentas entre las que se busca el medio de pago: sin archivar, sin las de sistema de Grupos y sin las líneas de
    /// una tarjeta con varias divisas (se nombra la tarjeta; la divisa elige la línea en `findAccount(paymentMention:)`).
    static func paymentCandidates(in accounts: [Account]) -> [PaymentMethodAccountLogic.Candidate] {
        let roles = AccountLineLogic.resolve(accounts.map { AccountLineNode($0) })
        return accounts
            .filter { !$0.isArchived && !$0.isSystemAccount && !(roles[$0.shortcutID]?.isLine ?? false) }
            .map { PaymentMethodAccountLogic.Candidate(id: $0.shortcutID, name: $0.name, kind: paymentKind(of: $0)) }
    }

    private static func paymentKind(of account: Account) -> PaymentMethodAccountLogic.AccountKind {
        switch AccountType(rawValue: account.type) {
        case .cash: return .cash
        case .creditCard: return .creditCard
        case .checking, .savings: return .bank
        case .general, nil: return .other
        }
    }

    /// La cuenta que el usuario nombró como medio de pago («25 almuerzo yape» → su cuenta Yape), o `nil`.
    ///
    /// Sin divisa dicha, la cuenta nombrada vale tal cual (y su divisa pasa a ser la del borrador). Con divisa dicha, la
    /// tarjeta con varias divisas va a su línea en esa divisa (`AccountCardLogic.route`); si la cuenta no tiene esa divisa,
    /// `nil`: no se fuerza una cuenta en otra divisa y quien llama vuelve a la regla de siempre, por divisa.
    static func findAccount(paymentMention mention: String?, dictatedCurrency: String?, in accounts: [Account]) -> Account? {
        guard let mention else { return nil }
        let live = accounts.filter { !$0.isArchived && !$0.isSystemAccount }
        guard let chosenID = PaymentMethodAccountLogic.account(for: mention, among: paymentCandidates(in: live)),
              let chosen = live.first(where: { $0.shortcutID == chosenID }) else { return nil }
        let dictated = dictatedCurrency?.uppercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !dictated.isEmpty else { return chosen }
        guard let route = AccountCardLogic.route(chosenID: chosenID, currencyCode: dictated, nodes: live.map { AccountLineNode($0) }),
              !route.isFallback else { return nil }
        return live.first { $0.shortcutID == route.accountID }
    }

    // MARK: - matchesNature

    /// `true` si la naturaleza de la subcategoría concuerda con el tipo del borrador.
    ///
    /// **Cuando el tipo y la categoría discrepan manda el tipo (`isExpense`), y la subcategoría se
    /// descarta** (decisión del ticket `chat-draft-sign-can-contradict-its-subcategory`). No es una
    /// preferencia nueva: es lo que ya hacían los otros cuatro puntos del borrador del chat, medidos
    /// el 2026-09-08 en este árbol —el selector de la card filtra por `draft.isExpense` (desde el 2026-10-04,
    /// `SubcategorySelectorSheet` con `transactionType` vía `ChatDraftFieldSheet`), `ChatAssistantViewModel.updateDraft`
    /// rechaza contra él la subcategoría que el usuario elige a mano, `matchSubcategoryByHint` filtra
    /// por él, y `saveDraft` firma el monto con él—. El único que no lo respetaba era el fallback por
    /// comercio, y su sugerencia es lo MENOS parecido a una intención: no sale de lo que el usuario
    /// acaba de dictar, sino del recuerdo estadístico de otros dictados con ese mismo comercio.
    ///
    /// Ojo con lo que decide `safeCategory` en el borde: una subcategoría **sin** categoría —relación
    /// `nil`, que CloudKit puede entregar mientras el record va en vuelo— devuelve un placeholder con
    /// `isIncome: false`, así que cuenta como de gasto. Se mantiene ese criterio a propósito: es el
    /// que ya aplican el menú del card y `updateDraft`, y hacer aquí una excepción los desalinearía.
    static func matchesNature(_ subcategory: Subcategory, isExpense: Bool) -> Bool {
        subcategory.safeCategory.isIncome != isExpense
    }

    // MARK: - suggestSubcategory

    /// Consulta `MerchantMemoryService` con el `merchant` (nota cruda) y devuelve
    /// la subcategoría sugerida, o `nil` si no hay datos suficientes **o si la que
    /// recuerda contradice el tipo del borrador** (ver `matchesNature`).
    ///
    /// `MerchantMemoryService` guarda `merchant → subcategoría` y no sabe nada de naturaleza, de modo
    /// que un comercio aprendido sobre ingresos puede devolver una subcategoría de ingreso para un
    /// texto que el parser resolvió como gasto —«por defecto asume gasto», dice su prompt—. Al
    /// descartarla, el borrador nace sin subcategoría y `computeNeedsUserInput` lo marca: el card pide
    /// elegirla y bloquea Guardar. Es el mismo estado que cuando no hay memoria de ese comercio, que
    /// es el caso común.
    ///
    /// Sin este filtro la combinación cruzada se persistía —monto firmado por `isExpense` y
    /// `category` tomada de la subcategoría— y `TransactionClassificationLogic` la lee como un
    /// reembolso: **resta** del bucket de ingresos en Registros y Estadísticas mientras el widget de
    /// inicio, que solo mira el signo, la suma.
    static func suggestSubcategory(merchant: String, isExpense: Bool, context: ModelContext) -> Subcategory? {
        let trimmed = merchant.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let service = MerchantMemoryService(modelContext: context)
        let remembered: Subcategory
        switch service.suggest(for: trimmed) {
        case .suggest(let sub), .autoAssign(let sub):
            remembered = sub
        case .none:
            return nil
        }

        return matchesNature(remembered, isExpense: isExpense) ? remembered : nil
    }

    // MARK: - matchSubcategoryByHint

    /// Matchea el `subcategoryHint` del LLM (nombre exacto sugerido) contra las
    /// subcategorías visibles del user. Estrategia (replica voice input):
    /// 1. Exact match (case + accent insensitive). Único → match. Múltiple → nil (ambigua).
    /// 2. Partial match (subcat contiene hint). Único → match.
    /// 3. Reverse match (hint contiene subcat). Único → match.
    /// 4. Filtra por tipo (expense vs income) coincidente con la categoría.
    static func matchSubcategoryByHint(
        hint: String,
        isExpense: Bool,
        in subcategories: [Subcategory]
    ) -> Subcategory? {
        let normalizedHint = normalizeForMatching(hint)
        guard !normalizedHint.isEmpty else { return nil }

        let filtered = subcategories.filter { matchesNature($0, isExpense: isExpense) }

        // 1. Exact match
        let exactMatches = filtered.filter { normalizeForMatching($0.name) == normalizedHint }
        if exactMatches.count == 1 { return exactMatches.first }
        if exactMatches.count > 1 { return nil }

        // 2. Partial match (subcat name contains hint)
        let partialMatches = filtered.filter { normalizeForMatching($0.name).contains(normalizedHint) }
        if partialMatches.count == 1 { return partialMatches.first }
        if partialMatches.count > 1 { return nil }

        // 3. Reverse match (hint contains subcat name)
        let reverseMatches = filtered.filter { normalizedHint.contains(normalizeForMatching($0.name)) }
        if reverseMatches.count == 1 { return reverseMatches.first }

        return nil
    }

    /// Convenience: fetch subcategorías visibles del context y delega.
    static func matchSubcategoryByHint(
        hint: String,
        isExpense: Bool,
        context: ModelContext
    ) -> Subcategory? {
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate<Subcategory> { $0.isVisible == true }
        )
        let subs = (try? context.fetch(descriptor)) ?? []
        return matchSubcategoryByHint(hint: hint, isExpense: isExpense, in: subs)
    }

    private static func normalizeForMatching(_ text: String) -> String {
        text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
    }

    // MARK: - fetchVisibleSubcategoryNames

    /// Fetch nombres de subcategorías visibles particionados por tipo (gasto/ingreso).
    /// Útil para alimentar el `expenseSubcategories`/`incomeSubcategories` del parser LLM.
    /// Compartido entre voice input y chat (ambos llaman `TranscriptionParserService.parseMultiple`).
    static func fetchVisibleSubcategoryNames(context: ModelContext) -> (expense: [String], income: [String]) {
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate<Subcategory> { $0.isVisible == true }
        )
        let subs: [Subcategory]
        do {
            subs = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("DraftBuilder.fetchVisibleSubcategoryNames: \(error)")
            #endif
            return ([], [])
        }
        let expense = subs.filter { !$0.safeCategory.isIncome }.map { $0.name }
        let income = subs.filter { $0.safeCategory.isIncome }.map { $0.name }
        return (expense, income)
    }

    // MARK: - computeNeedsUserInput

    /// Calcula los campos críticos sin valor inferido. El caller usa esto para
    /// destacar filas en la UI ("Selecciona cuenta", "Selecciona subcategoría").
    static func computeNeedsUserInput(
        hasAmount: Bool,
        hasAccount: Bool,
        hasSubcategory: Bool
    ) -> [String] {
        var fields: [String] = []
        if !hasAccount { fields.append("account") }
        if !hasSubcategory { fields.append("subcategory") }
        if !hasAmount { fields.append("amount") }
        return fields
    }

    // MARK: - build (chat-specific)

    /// Compone un `ChatTransactionDraft` a partir de un `ParsedTransaction` (output
    /// de `TranscriptionParserService`) usando los helpers anteriores.
    /// Currency: prioriza `parsed.currencyHint`; si no hay, usa `defaultCurrency`.
    /// Date: prioriza `parsed.date`; si no hay, usa `Date.now`.
    /// Tags: matchea `parsed.tagHints` por nombre (case-insensitive) contra los Tags
    /// existentes del user. Tags no encontrados se ignoran (v1).
    /// `expensesOnlyMode`: con el modo «solo gastos», el borrador nace como gasto aunque el modelo lea un ingreso, como en
    /// Siri, el Atajo y Apple Pay (`SiriDraftService`). Ticket `chat-ignores-expenses-only-mode`.
    /// `sourceText` y `batchCount`: la frase del usuario y cuántos movimientos salieron de ella, para el medio de pago
    /// (`PaymentMethodAccountLogic.mention`). Sin frase no se busca: queda la regla por divisa.
    static func build(
        parsed: ParsedTransaction,
        defaultCurrency: String,
        context: ModelContext,
        expensesOnlyMode: Bool = false,
        sourceText: String = "",
        batchCount: Int = 1
    ) -> ChatTransactionDraft {
        let isExpense = expensesOnlyMode ? true : parsed.isExpense
        let mention = PaymentMethodAccountLogic.mention(
            hint: parsed.paymentHint, hintAnswered: parsed.paymentHintAnswered, sourceText: sourceText, batchCount: batchCount)
        let paymentAccount = mention.flatMap { mention in
            findAccount(paymentMention: mention, dictatedCurrency: parsed.currencyHint, in: fetchActiveAccounts(context: context))
        }
        let currency = parsed.currencyHint?.uppercased() ?? paymentAccount?.currencyCode.uppercased() ?? defaultCurrency.uppercased()
        let account = paymentAccount ?? findAccount(byCurrency: currency, context: context)

        // 1) Match por subcategoryHint del LLM (replica el comportamiento de voice input).
        //    El LLM recibe la lista de subcategorías del user y devuelve el nombre exacto.
        // 2) Fallback a MerchantMemory (aprendizaje histórico de "Wong" → Supermercados).
        var subcategory: Subcategory?
        if let hint = parsed.subcategoryHint, !hint.isEmpty {
            subcategory = matchSubcategoryByHint(hint: hint, isExpense: isExpense, context: context)
        }
        if subcategory == nil {
            subcategory = suggestSubcategory(
                merchant: parsed.note,
                isExpense: isExpense,
                context: context
            )
        }

        let tagIDs = matchTags(hints: parsed.tagHints, context: context)
        let needs = computeNeedsUserInput(
            hasAmount: parsed.amount != nil,
            hasAccount: account != nil,
            hasSubcategory: subcategory != nil
        )

        return ChatTransactionDraft(
            amount: parsed.amount,
            currencyCode: currency,
            isExpense: isExpense,
            note: parsed.note,
            date: parsed.date ?? Date.now,
            accountID: account?.persistentModelID,
            subcategoryID: subcategory?.persistentModelID,
            tagIDs: tagIDs,
            needsUserInput: needs
        )
    }

    // MARK: - matchTags

    /// Matchea tag hints (nombres del LLM) contra Tags existentes del user.
    /// Case-insensitive + trim. Tags no encontrados se ignoran (v1: el user puede
    /// agregarlos manualmente vía Edit → NewTransactionView).
    static func matchTags(hints: [String], context: ModelContext) -> [PersistentIdentifier] {
        let trimmed = hints.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return [] }

        let allTags: [Tag]
        do {
            allTags = try context.fetch(FetchDescriptor<Tag>())
        } catch {
            return []
        }

        return allTags
            .filter { trimmed.contains($0.name.lowercased()) }
            .map { $0.persistentModelID }
    }
}
