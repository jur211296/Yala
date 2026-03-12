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

            for duplicate in duplicates {
                // Re-parent subcategories
                for sub in duplicate.subcategories ?? [] {
                    // Try to find matching subcategory in keeper by iconName
                    let matchInKeeper = (keeper.subcategories ?? []).first { $0.iconName == sub.iconName }

                    if let match = matchInKeeper {
                        // Re-parent transactions from duplicate sub to keeper's matching sub
                        for tx in sub.transactions ?? [] {
                            tx.subcategory = match
                        }
                        // Clean up and delete duplicate subcategory
                        sub.category = nil
                        context.delete(sub)
                    } else {
                        // No match in keeper — re-parent subcategory to keeper
                        sub.category = keeper
                    }
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
}
