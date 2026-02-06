//
//  SaveAsRecurringViewModel.swift
//  Yala
//
//  ViewModel for SaveAsRecurringSheet - handles tag loading.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class SaveAsRecurringViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var allTags: [Tag] = []

    // MARK: - Computed Properties

    var activeTags: [Tag] {
        allTags.filter { $0.isActive }
    }

    func selectedTagObjects(from selectedIDs: Set<PersistentIdentifier>) -> [Tag] {
        activeTags.filter { selectedIDs.contains($0.persistentModelID) }
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadTags()
    }

    // MARK: - Data Loading

    func loadTags() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\Tag.name)])
        do {
            allTags = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("SaveAsRecurringViewModel: Error loading tags: \(error)")
            #endif
            allTags = []
        }
    }
}
