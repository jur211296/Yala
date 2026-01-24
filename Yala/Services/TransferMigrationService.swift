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
struct TransferMigrationService {

    /// Key to track if migration has been performed
    private static let migrationCompletedKey = "TransferMigrationV1Completed"

    /// Migrates positive transfers from Otros to Ingresos category if not already done.
    /// Should be called once at app startup (e.g., in PanelView.onAppear).
    static func migratePositiveTransfersIfNeeded(in context: ModelContext) {
        // Check if migration already completed
        guard !UserDefaults.standard.bool(forKey: migrationCompletedKey) else {
            return
        }

        print("[TransferMigration] Starting migration of positive transfers...")

        // Find the Income category and its transfer subcategory
        let incomeCategoryName = "Ingresos"
        let transferSubcategoryNames = Subcategory.systemSubcategoryNames.filter {
            $0 != "Ajustes de saldo"
        }

        // Fetch Ingresos/Transferencia entre cuentas subcategory
        guard let incomeTransferSubcategory = findOrCreateIncomeTransferSubcategory(
            in: context,
            categoryName: incomeCategoryName,
            subcategoryNames: transferSubcategoryNames
        ) else {
            print("[TransferMigration] Could not find or create income transfer subcategory")
            return
        }

        // Fetch all positive transfers currently in Otros
        let otrosCategoryName = "Otros"
        do {
            let descriptor = FetchDescriptor<TransactionItem>()
            let allTransactions = try context.fetch(descriptor)

            var migratedCount = 0
            for transaction in allTransactions {
                // Check if this is a positive transfer in Otros
                guard transaction.balanceAdjustmentType == "transfer",
                      transaction.amount > 0,
                      transaction.category?.name == otrosCategoryName,
                      transferSubcategoryNames.contains(transaction.subcategory?.name ?? "")
                else { continue }

                // Migrate to Ingresos/Transferencia entre cuentas
                transaction.category = incomeTransferSubcategory.category
                transaction.subcategory = incomeTransferSubcategory
                migratedCount += 1
            }

            if migratedCount > 0 {
                try context.save()
                print("[TransferMigration] Migrated \(migratedCount) positive transfer(s) to Ingresos")
            } else {
                print("[TransferMigration] No positive transfers needed migration")
            }

            // Mark migration as completed
            UserDefaults.standard.set(true, forKey: migrationCompletedKey)

        } catch {
            print("[TransferMigration] Error during migration: \(error)")
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
        guard let allSubcategories = try? context.fetch(descriptor) else { return nil }

        for subcategory in allSubcategories {
            if subcategory.category.name == categoryName,
               subcategoryNames.contains(subcategory.name) {
                return subcategory
            }
        }

        // If not found, try to create it
        let catDescriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.name == categoryName }
        )
        guard let incomeCategory = try? context.fetch(catDescriptor).first else {
            return nil
        }

        // Create the subcategory
        let subcategory = Subcategory(
            name: "Transferencia entre cuentas",
            colorHex: nil,
            natureRawValue: SubcategoryNature.unclassified.rawValue,
            iconName: "arrow.left.arrow.right",
            category: incomeCategory
        )
        context.insert(subcategory)

        do {
            try context.save()
        } catch {
            print("[TransferMigration] Warning: Could not save new subcategory: \(error)")
        }

        return subcategory
    }
}
