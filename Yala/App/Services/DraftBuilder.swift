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
//  - suggestSubcategory(merchant:context:)    — vía MerchantMemoryService.
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

    // MARK: - suggestSubcategory

    /// Consulta `MerchantMemoryService` con el `merchant` (nota cruda) y devuelve
    /// la subcategoría sugerida o `nil` si no hay datos suficientes.
    static func suggestSubcategory(merchant: String, context: ModelContext) -> Subcategory? {
        let trimmed = merchant.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let service = MerchantMemoryService(modelContext: context)
        switch service.suggest(for: trimmed) {
        case .suggest(let sub), .autoAssign(let sub):
            return sub
        case .none:
            return nil
        }
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

        let filtered = subcategories.filter { sub in
            let category = sub.safeCategory
            return isExpense ? !category.isIncome : category.isIncome
        }

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
            subcategory = suggestSubcategory(merchant: parsed.note, context: context)
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
