//
//  Budget.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import Foundation
import SwiftData

// MARK: - Budget

@Model
final class Budget {
    // Stable identifier for tracking (e.g., alert notifications)
    var id: UUID = UUID()

    // Legacy properties (kept for backwards compatibility) - CloudKit: defaults required
    var currencyCode: String = "USD"
    var limitAmount: Double = 0
    @Relationship(deleteRule: .nullify, inverse: \Category.budgets)
    var category: Category?

    // New properties for enhanced budget system - CloudKit: defaults required
    var name: String = ""
    var periodType: String = "monthly"  // "weekly", "monthly", "yearly", "unique"
    var startDate: Date?    // For unique budgets
    var endDate: Date?      // For unique budgets
    var currentPeriodStart: Date?  // LEGACY: unused, kept for CloudKit compat with older versions

    // Many-to-many relationships - CloudKit: must be optional
    // LEGACY: kept only for cascade .nullify when a related entity is deleted.
    // DO NOT read from these for filtering/display logic. Read via resolvedXIDs() helpers.
    // Writers MUST use setFilters(...) to keep both sides (M2M + CSV) in sync.
    @Relationship(deleteRule: .nullify, inverse: \Account.budgets)
    var accounts: [Account]?

    @Relationship(deleteRule: .nullify, inverse: \Subcategory.budgets)
    var subcategories: [Subcategory]?

    @Relationship(deleteRule: .nullify, inverse: \Tag.budgets)
    var tags: [Tag]?
    var natures: String?    // Comma-separated nature values (e.g., "essential,priority")

    // CSV mirror of M2M relations — SSOT for read (eager, travels in the Budget record).
    // Solves CloudKit lazy hydration race where M2M can appear nil/[] post cold start.
    var subcategoryIDs: String?   // CSV of Subcategory.shortcutID UUIDs
    var accountIDs: String?       // CSV of Account.shortcutID UUIDs
    var tagIDs: String?           // CSV of Tag.id UUIDs
    var isActive: Bool = true
    var createdAt: Date = Date.now
    var isFavorite: Bool = false
    var favoriteOrder: Int = 0

    // Alert notifications
    var alertEnabled: Bool = false
    var alertThresholds: String? = nil  // CSV: "50,75,100"

    // Shared expenses
    var includeSharedExpenses: Bool = true

    init(
        id: UUID = UUID(),
        currencyCode: String,
        limitAmount: Double,
        category: Category? = nil,
        name: String = "",
        periodType: String = "monthly",
        startDate: Date? = nil,
        endDate: Date? = nil,
        currentPeriodStart: Date? = nil,
        accounts: [Account] = [],
        subcategories: [Subcategory] = [],
        tags: [Tag] = [],
        natures: String? = nil,
        isActive: Bool = true,
        createdAt: Date = Date.now,
        isFavorite: Bool = false,
        favoriteOrder: Int = 0,
        alertEnabled: Bool = false,
        alertThresholds: String? = nil,
        includeSharedExpenses: Bool = true,
        subcategoryIDs: String? = nil,
        accountIDs: String? = nil,
        tagIDs: String? = nil
    ) {
        self.id = id
        self.currencyCode = currencyCode
        self.limitAmount = limitAmount
        self.category = category
        self.name = name
        self.periodType = periodType
        self.startDate = startDate
        self.endDate = endDate
        self.currentPeriodStart = currentPeriodStart
        self.accounts = accounts
        self.subcategories = subcategories
        self.tags = tags
        self.natures = natures
        self.isActive = isActive
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.favoriteOrder = favoriteOrder
        self.alertEnabled = alertEnabled
        self.alertThresholds = alertThresholds
        self.includeSharedExpenses = includeSharedExpenses
        // Auto-mirror: si caller no pasó CSV explícito, derivar desde M2M arrays
        // para garantizar SSOT al construir. Si el explicit param es no-nil, respeta
        // lo que el caller indicó (incluso `""` o un valor distinto del M2M).
        self.subcategoryIDs = subcategoryIDs ?? CSVMirrorCodec.encode(subcategories.map(\.shortcutID))
        self.accountIDs = accountIDs ?? CSVMirrorCodec.encode(accounts.map(\.shortcutID))
        self.tagIDs = tagIDs ?? CSVMirrorCodec.encode(tags.map(\.id))
    }

    // MARK: - Display Properties

    /// Returns the icon and color for this budget based on its subcategories.
    /// Legacy fallback that reads M2M directly — used by previews/tests sin context.
    /// Prefer `Budget.computeDisplayProperties(for:in:)` for runtime callers — that
    /// helper reads the CSV mirror first (eager, no CloudKit lazy race).
    var displayProperties: (icon: String, color: String) {
        let subs = subcategories ?? []
        return Self.resolveDisplayProperties(from: subs)
    }

    /// Resolves icon/color from the CSV mirror (SSOT) with a fetch by `shortcutID`.
    /// Falls back to M2M when the CSV is nil (legacy budgets pre-deploy).
    @MainActor
    static func computeDisplayProperties(
        for budget: Budget,
        in context: ModelContext
    ) -> (icon: String, color: String) {
        if let ids = budget.resolvedSubcategoryIDs(scheduleBackfill: true), !ids.isEmpty {
            let descriptor = FetchDescriptor<Subcategory>(predicate: #Predicate { ids.contains($0.shortcutID) })
            let subs = (try? context.fetch(descriptor)) ?? []
            if !subs.isEmpty {
                return resolveDisplayProperties(from: subs)
            }
        }
        // Fallback to M2M (legacy path or no filter)
        return resolveDisplayProperties(from: budget.subcategories ?? [])
    }

    /// Pure helper that computes (icon, color) from a list of subcategories.
    /// Same logic as the legacy `displayProperties` — shared between paths.
    static func resolveDisplayProperties(from subs: [Subcategory]) -> (icon: String, color: String) {
        guard !subs.isEmpty else {
            return ("chart.pie.fill", AppConstants.defaultColorHex)
        }

        if subs.count == 1, let sub = subs.first {
            let icon = sub.iconName ?? sub.safeCategory.iconName ?? "tag.fill"
            let color = sub.colorHex ?? sub.safeCategory.colorHex
            return (icon, color)
        }

        let uniqueCategories = Set(subs.map { $0.safeCategory.persistentModelID })
        if uniqueCategories.count == 1, let first = subs.first {
            let icon = first.safeCategory.iconName ?? "tag.fill"
            let color = first.colorHex ?? first.safeCategory.colorHex
            return (icon, color)
        }

        return ("chart.pie.fill", AppConstants.defaultColorHex)
    }
}
