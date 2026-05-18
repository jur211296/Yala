//
//  CategoryDeduplicationService.swift
//  Yala
//
//  Merges duplicate seed categories that can arise when iCloud sync delivers
//  categories while the local device also runs seedCategoriesIfNeeded().
//

import Foundation
import SwiftData

@MainActor
enum CategoryDeduplicationService {

    /// Returns the stable identity key for a category (iconName + colorHex + isIncome).
    static func identityKey(for category: Category) -> String {
        "\(category.iconName ?? "nil")|\(category.colorHex)|\(category.isIncome)"
    }

    /// Deduplicates seed categories by stable identity (iconName + colorHex + isIncome).
    /// Keeps the category with the most transactions and re-parents orphaned data.
    /// - Returns: number of duplicate categories removed.
    @discardableResult
    static func deduplicateSeedCategories(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate<Category> { $0.isDefaultSeed == true }
        )

        let seedCategories: [Category]
        do {
            seedCategories = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("CategoryDedup: Error fetching seed categories: \(error)")
            #endif
            return 0
        }

        // Group by stable identity: iconName + colorHex + isIncome
        let grouped = Dictionary(grouping: seedCategories) { identityKey(for: $0) }

        var removedCount = 0

        for (_, group) in grouped where group.count > 1 {
            // Keep the one with most transactions
            let sorted = group.sorted { ($0.transactions?.count ?? 0) > ($1.transactions?.count ?? 0) }
            let keeper = sorted[0]
            let duplicates = sorted.dropFirst()
            let keeperSeedSubs = (keeper.subcategories ?? []).filter { $0.isDefaultSeed }

            for duplicate in duplicates {
                for sub in (duplicate.subcategories ?? []) where sub.isDefaultSeed {
                    if let match = keeperSeedSubs.first(where: { $0.iconName == sub.iconName }) {
                        reparentInverseRelationships(from: sub, to: match)
                        sub.category = nil
                        context.delete(sub)
                    } else {
                        sub.category = keeper
                    }
                }

                // Custom subs nunca se mergean con seed: el match por iconName es coincidencia
                // visual, no equivalencia semántica. Se re-parentean al keeper preservando identidad.
                for sub in (duplicate.subcategories ?? []) where !sub.isDefaultSeed {
                    sub.category = keeper
                }

                // Re-parent category-level transactions
                for tx in duplicate.transactions ?? [] {
                    tx.category = keeper
                }

                // Re-parent budgets
                for budget in duplicate.budgets ?? [] {
                    budget.category = keeper
                }

                context.delete(duplicate)
                removedCount += 1
            }
        }

        if removedCount > 0 {
            do {
                try context.save()
                #if DEBUG
                print("CategoryDedup: Removed \(removedCount) duplicate seed categories")
                #endif
            } catch {
                #if DEBUG
                print("CategoryDedup: Error saving after dedup: \(error)")
                #endif
            }
        }

        return removedCount
    }

    /// Re-parent TODAS las relaciones inversas de `sub` a `match` antes de borrar `sub`.
    /// Sin esto el deleteRule .nullify vacía silenciosamente Budget.subcategories y deja
    /// huérfanos a payments/drafts/memories/cashFlowLines.
    private static func reparentInverseRelationships(from sub: Subcategory, to match: Subcategory) {
        for tx in sub.transactions ?? [] { tx.subcategory = match }
        for fav in sub.favoritePayments ?? [] { fav.subcategory = match }
        for sched in sub.scheduledPayments ?? [] { sched.subcategory = match }
        for draft in sub.inboxDrafts ?? [] { draft.subcategory = match }
        for memory in sub.merchantMemories ?? [] { memory.subcategory = match }
        for line in sub.cashFlowLines ?? [] { line.subcategory = match }
        // M2M Budget.subcategories: idempotency check evita doble append cuando dos subs
        // duplicadas comparten match en el mismo budget.
        for budget in sub.budgets ?? [] {
            guard (budget.subcategories ?? []).allSatisfy({ $0.persistentModelID != match.persistentModelID }) else { continue }
            if budget.subcategories == nil { budget.subcategories = [] }
            budget.subcategories?.append(match)
        }
    }
}
