//
//  TagsSettingsListViewModel.swift
//  Yala
//
//  ViewModel for TagsSettingsListView - handles tag list state and reordering.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class TagsSettingsListViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var tags: [Tag] = []

    // MARK: - UI State

    var isPresentingCreateTag = false
    var tagToEdit: Tag?
    var isEditMode = false

    // MARK: - Sort Order (synced from AppPreferences via View)

    var tagsSortOrderNames: [String] = [] {
        didSet {
            tagSortIndexCache = nil
        }
    }

    // MARK: - Computed Properties

    private var tagSortIndexCache: [String: Int]?

    private var tagSortIndex: [String: Int] {
        if let cache = tagSortIndexCache {
            return cache
        }
        let index = Dictionary(tagsSortOrderNames.enumerated().map { ($1, $0) },
                               uniquingKeysWith: { first, _ in first })
        tagSortIndexCache = index
        return index
    }

    var orderedActiveTags: [Tag] {
        let active = tags.filter { $0.isActive }
        let indexByName = tagSortIndex

        return active.sorted { a, b in
            let ia = indexByName[a.name]
            let ib = indexByName[b.name]

            switch (ia, ib) {
            case (let x?, let y?):
                return x < y
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }
    }

    var inactiveTags: [Tag] {
        tags.filter { !$0.isActive }
    }

    var isEmpty: Bool {
        tags.isEmpty
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
            print("TagsSettingsListViewModel: Error loading tags: \(error)")
            #endif
            tags = []
        }
    }

    // MARK: - Reorder Logic

    func moveTag(from source: IndexSet, to destination: Int) -> [String] {
        var currentOrder = orderedActiveTags.map { $0.name }
        currentOrder.move(fromOffsets: source, toOffset: destination)
        tagsSortOrderNames = currentOrder
        return currentOrder
    }
}
