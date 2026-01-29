//
//  TopSubcategoriesWidgetViewModel.swift
//  Yala
//
//  ViewModel for TopSubcategoriesWidget - handles category loading.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class TopSubcategoriesWidgetViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var allCategories: [Category] = []

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadCategories()
    }

    // MARK: - Data Loading

    func loadCategories() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\Category.name)])
        do {
            allCategories = try context.fetch(descriptor)
        } catch {
            print("TopSubcategoriesWidgetViewModel: Error loading categories: \(error)")
            allCategories = []
        }
    }

    // MARK: - Helpers

    func category(withID id: PersistentIdentifier?) -> Category? {
        guard let id = id else { return nil }
        return allCategories.first { $0.persistentModelID == id }
    }

    func categoryName(forID id: PersistentIdentifier?) -> String {
        if let id = id, let category = category(withID: id) {
            return category.name
        }
        return L10n.Common.all
    }
}
