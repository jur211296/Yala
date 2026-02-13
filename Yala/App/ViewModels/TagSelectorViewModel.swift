//
//  TagSelectorViewModel.swift
//  Yala
//
//  ViewModel for TagSelectorSheet - handles tag list loading.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class TagSelectorViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var tags: [Tag] = []

    // MARK: - UI State

    var showNewTagSheet = false
    var tagCountBeforeSheet = 0

    // MARK: - Computed Properties

    var activeTags: [Tag] {
        tags.filter { $0.isActive }
    }

    var isEmpty: Bool {
        activeTags.isEmpty
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
            tags = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("TagSelectorViewModel: Error loading tags: \(error)")
            #endif
            tags = []
        }
    }

    // MARK: - Actions

    func prepareForNewTag() {
        tagCountBeforeSheet = activeTags.count
        showNewTagSheet = true
    }

    func closeNewTagSheet() {
        showNewTagSheet = false
        loadTags()
    }
}
