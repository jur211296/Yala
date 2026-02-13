//
//  ImportIntroViewModel.swift
//  Yala
//
//  ViewModel for ImportIntroSheet - handles subcategory loading for template generation.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class ImportIntroViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var allSubcategories: [Subcategory] = []

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
    }

    // MARK: - Data Loading

    func loadData() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<Subcategory>(sortBy: [SortDescriptor(\Subcategory.sortOrder)])
        do {
            allSubcategories = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ImportIntroViewModel: Error loading subcategories: \(error)")
            #endif
            allSubcategories = []
        }
    }
}
