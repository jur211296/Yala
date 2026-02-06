//
//  BulkEditViewModel.swift
//  Yala
//
//  ViewModel for BulkEditSheet - handles tag loading.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class BulkEditViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var allTags: [Tag] = []

    // MARK: - Computed Properties

    var activeTags: [Tag] {
        allTags.filter { $0.isActive }
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
    }

    // MARK: - Data Loading

    func loadData() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\Tag.name)])
        do {
            allTags = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("BulkEditViewModel: Error loading tags: \(error)")
            #endif
            allTags = []
        }
    }
}
