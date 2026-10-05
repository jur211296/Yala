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
    static func findAccount(byCurrency currencyCode: String, in accounts: [Account]) -> Account? {
        let normalizedCode = currencyCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCode.isEmpty else { return nil }

        let matches = accounts
            .filter { !$0.isArchived }
            .filter { $0.currencyCode.uppercased() == normalizedCode }
        return matches.count == 1 ? matches.first : nil
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
    static func build(
        parsed: ParsedTransaction,
        defaultCurrency: String,
        context: ModelContext
    ) -> ChatTransactionDraft {
        let currency = parsed.currencyHint?.uppercased() ?? defaultCurrency.uppercased()
        let account = findAccount(byCurrency: currency, context: context)

        // 1) Match por subcategoryHint del LLM (replica el comportamiento de voice input).
        //    El LLM recibe la lista de subcategorías del user y devuelve el nombre exacto.
        // 2) Fallback a MerchantMemory (aprendizaje histórico de "Wong" → Supermercados).
        var subcategory: Subcategory?
        if let hint = parsed.subcategoryHint, !hint.isEmpty {
            subcategory = matchSubcategoryByHint(hint: hint, isExpense: parsed.isExpense, context: context)
        }
        if subcategory == nil {
            subcategory = suggestSubcategory(
                merchant: parsed.note,
                isExpense: parsed.isExpense,
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
            isExpense: parsed.isExpense,
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
