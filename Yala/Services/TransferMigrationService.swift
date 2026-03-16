//
//  TransferMigrationService.swift
//  Yala
//
//  One-time migration to move positive transfers from Otros to Ingresos category.
//  This ensures incoming transfers appear correctly when filtering by income.
//

import Foundation
import SwiftData

/// Service to migrate existing positive transfers from Otros/Transferencia to Ingresos/Transferencia
@MainActor struct TransferMigrationService {

    /// Key to track if migration has been performed
    private static let migrationCompletedKey = "TransferMigrationV1Completed"

    /// Migrates positive transfers from Otros to Ingresos category if not already done.
    /// Should be called once at app startup (e.g., in PanelView.onAppear).
    static func migratePositiveTransfersIfNeeded(in context: ModelContext) {
        // Check if migration already completed
        guard !UserDefaults.standard.bool(forKey: migrationCompletedKey) else {
            return
        }

        #if DEBUG
        print("[TransferMigration] Starting migration of positive transfers...")
        #endif

        // Find the Income category and its transfer subcategory
        let incomeCategoryName = "Ingresos"
        let transferSubcategoryNames = Subcategory.transferNames

        // Fetch Ingresos/Transferencia entre cuentas subcategory
        guard let incomeTransferSubcategory = findOrCreateIncomeTransferSubcategory(
            in: context,
            categoryName: incomeCategoryName,
            subcategoryNames: transferSubcategoryNames
        ) else {
            #if DEBUG
            print("[TransferMigration] Could not find or create income transfer subcategory")
            #endif
            return
        }

        // Fetch all positive transfers currently in Otros
        let otrosCategoryName = "Otros"
        do {
            var descriptor = FetchDescriptor<TransactionItem>()
            descriptor.predicate = #Predicate<TransactionItem> { $0.balanceAdjustmentType == "transfer" && $0.amount > 0 }
            let transferTransactions = try context.fetch(descriptor)

            var migratedCount = 0
            for transaction in transferTransactions {
                // Check if this is a positive transfer in Otros
                guard transaction.category?.name == otrosCategoryName,
                      transferSubcategoryNames.contains(transaction.subcategory?.name ?? "")
                else { continue }

                // Migrate to Ingresos/Transferencia entre cuentas
                transaction.category = incomeTransferSubcategory.category
                transaction.subcategory = incomeTransferSubcategory
                migratedCount += 1
            }

            if migratedCount > 0 {
                try context.save()
                #if DEBUG
                print("[TransferMigration] Migrated \(migratedCount) positive transfer(s) to Ingresos")
                #endif
            } else {
                #if DEBUG
                print("[TransferMigration] No positive transfers needed migration")
                #endif
            }

            // Mark migration as completed
            UserDefaults.standard.set(true, forKey: migrationCompletedKey)

        } catch {
            #if DEBUG
            print("[TransferMigration] Error during migration: \(error)")
            #endif
        }
    }

    /// Finds or creates the Ingresos/Transferencia entre cuentas subcategory
    private static func findOrCreateIncomeTransferSubcategory(
        in context: ModelContext,
        categoryName: String,
        subcategoryNames: Set<String>
    ) -> Subcategory? {
        // Try to find existing subcategory
        let descriptor = FetchDescriptor<Subcategory>()
        let allSubcategories: [Subcategory]
        do {
            allSubcategories = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("[TransferMigration] Error fetching subcategories: \(error)")
            #endif
            return nil
        }

        for subcategory in allSubcategories {
            if subcategory.safeCategory.name == categoryName,
               subcategoryNames.contains(subcategory.name) {
                return subcategory
            }
        }

        // If not found, try to create it
        let catDescriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.name == categoryName }
        )
        let fetchedCategoryResults: [Category]
        do {
            fetchedCategoryResults = try context.fetch(catDescriptor)
        } catch {
            #if DEBUG
            print("[TransferMigration] Error fetching income category: \(error)")
            #endif
            return nil
        }
        guard let incomeCategory = fetchedCategoryResults.first else {
            return nil
        }

        // Create the subcategory
        let subcategory = Subcategory(
            name: "Transferencia entre cuentas",
            colorHex: nil,
            natureRawValue: SubcategoryNeed.unclassified.rawValue,
            iconName: "arrow.left.arrow.right",
            category: incomeCategory
        )
        context.insert(subcategory)

        do {
            try context.save()
        } catch {
            #if DEBUG
            print("[TransferMigration] Warning: Could not save new subcategory: \(error)")
            #endif
        }

        return subcategory
    }
}
