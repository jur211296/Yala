//
//  DescriptionAutocomplete.swift
//  Yala
//
//  Created by Neto - Autocomplete suggestions for description field.
//

import SwiftData
import SwiftUI

// MARK: - Mention Type

/// Types of mentions supported in the description field
enum MentionType: Equatable {
    case tag  // #
    case subcategory  // !
    case account  // @

    var triggerCharacter: Character {
        switch self {
        case .tag: return "#"
        case .subcategory: return "!"
        case .account: return "@"
        }
    }

    var iconName: String {
        switch self {
        case .tag: return "number"
        case .subcategory: return "tag"
        case .account: return "creditcard"
        }
    }
}

// MARK: - Mention State

/// Tracks the current mention being typed
struct MentionState: Equatable {
    let type: MentionType
    let query: String  // Text after the trigger character
    let triggerIndex: String.Index  // Position of trigger in text

    static func detect(in text: String) -> MentionState? {
        // Find the last trigger character that's not already "closed"
        // We look for #, !, or @ and check if we're still typing after it

        guard !text.isEmpty else { return nil }

        // Find the last whitespace or start of string
        var searchStartIndex = text.startIndex
        if let lastSpace = text.lastIndex(of: " ") {
            searchStartIndex = text.index(after: lastSpace)
        }
        if let lastNewline = text.lastIndex(of: "\n"), lastNewline > searchStartIndex {
            searchStartIndex = text.index(after: lastNewline)
        }

        // Check if the word starts with a trigger character
        guard searchStartIndex < text.endIndex else { return nil }

        let currentWord = String(text[searchStartIndex...])
        guard !currentWord.isEmpty else { return nil }

        let firstChar = currentWord.first!

        let mentionType: MentionType?
        switch firstChar {
        case "#": mentionType = .tag
        case "!": mentionType = .subcategory
        case "@": mentionType = .account
        default: mentionType = nil
        }

        guard let type = mentionType else { return nil }

        // Get the query (text after the trigger)
        let query = String(currentWord.dropFirst())

        return MentionState(
            type: type,
            query: query,
            triggerIndex: searchStartIndex
        )
    }
}

// MARK: - Autocomplete Suggestion Item

/// A unified suggestion item for any mention type
struct AutocompleteSuggestion: Identifiable {
    let id: String
    let name: String
    let colorHex: String
    let type: MentionType

    // Original objects for selection
    var tag: Tag?
    var subcategory: Subcategory?
    var account: Account?
}

// MARK: - Autocomplete Suggestions View

struct AutocompleteSuggestionsView: View {
    let suggestions: [AutocompleteSuggestion]
    let onSelect: (AutocompleteSuggestion) -> Void

    var body: some View {
        if !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(suggestions) { suggestion in
                        Button {
                            onSelect(suggestion)
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Circle()
                                    .fill(Color(hex: suggestion.colorHex))
                                    .frame(width: 8, height: 8)

                                Text(suggestion.name)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(
                                Capsule()
                                    .fill(Color.yalaCard)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        Color(hex: suggestion.colorHex).opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
            }
            .frame(height: 44)
        }
    }
}

// MARK: - Autocomplete Helper

/// Helper to generate suggestions based on mention state
struct AutocompleteHelper {

    /// Get tag suggestions sorted by recent usage
    static func getTagSuggestions(
        query: String,
        allTags: [Tag],
        recentTransactions: [TransactionItem]
    ) -> [AutocompleteSuggestion] {
        // Get active tags
        let activeTags = allTags.filter { $0.isActive }

        // Sort by recent usage
        var tagUsage: [PersistentIdentifier: Date] = [:]
        for transaction in recentTransactions.prefix(100) {
            for tag in transaction.tags {
                if tagUsage[tag.persistentModelID] == nil {
                    tagUsage[tag.persistentModelID] = transaction.date
                }
            }
        }

        let sortedTags = activeTags.sorted { a, b in
            let dateA = tagUsage[a.persistentModelID] ?? .distantPast
            let dateB = tagUsage[b.persistentModelID] ?? .distantPast
            return dateA > dateB
        }

        // Filter by query if not empty
        let filtered: [Tag]
        if query.isEmpty {
            filtered = Array(sortedTags.prefix(8))
        } else {
            filtered = sortedTags.filter {
                $0.name.localizedCaseInsensitiveContains(query)
            }.prefix(8).map { $0 }
        }

        return filtered.map { tag in
            AutocompleteSuggestion(
                id: "tag-\(tag.persistentModelID.hashValue)",
                name: tag.name,
                colorHex: tag.colorHex,
                type: .tag,
                tag: tag
            )
        }
    }

    /// Get subcategory suggestions - searches ALL subcategories, prioritizing recently used
    static func getSubcategorySuggestions(
        query: String,
        allSubcategories: [Subcategory],
        recentTransactions: [TransactionItem],
        transactionType: TransactionType
    ) -> [AutocompleteSuggestion] {
        // Build usage map from recent transactions for sorting priority
        var subcategoryUsage: [PersistentIdentifier: Date] = [:]

        for transaction in recentTransactions.prefix(100) {
            guard let subcategory = transaction.subcategory else { continue }
            if subcategoryUsage[subcategory.persistentModelID] == nil {
                subcategoryUsage[subcategory.persistentModelID] = transaction.date
            }
        }

        // Filter subcategories by transaction type using the category relationship
        let filteredSubcategories = allSubcategories.filter { subcategory in
            let category = subcategory.category
            switch transactionType {
            case .expense: return !category.isIncome
            case .income: return category.isIncome
            case .transfer: return false
            }
        }

        // Filter by query if not empty
        let filtered: [Subcategory]
        if query.isEmpty {
            // When no query, show ONLY recently used subcategories (max 5)
            filtered =
                filteredSubcategories
                .filter { subcategoryUsage[$0.persistentModelID] != nil }
                .sorted { a, b in
                    let dateA = subcategoryUsage[a.persistentModelID] ?? .distantPast
                    let dateB = subcategoryUsage[b.persistentModelID] ?? .distantPast
                    return dateA > dateB
                }
        } else {
            // When query exists, search ALL subcategories (including unused), prioritizing recently used
            filtered =
                filteredSubcategories
                .filter { $0.name.localizedCaseInsensitiveContains(query) }
                .sorted { a, b in
                    let dateA = subcategoryUsage[a.persistentModelID] ?? .distantPast
                    let dateB = subcategoryUsage[b.persistentModelID] ?? .distantPast
                    if dateA != dateB {
                        return dateA > dateB  // Recently used first
                    }
                    return a.name < b.name  // Then alphabetically
                }
        }

        return filtered.prefix(8).map { subcategory in
            let colorHex = subcategory.colorHex ?? subcategory.category.colorHex
            return AutocompleteSuggestion(
                id: "subcat-\(subcategory.persistentModelID.hashValue)",
                name: subcategory.name,
                colorHex: colorHex,
                type: .subcategory,
                subcategory: subcategory
            )
        }
    }

    /// Get account suggestions sorted by recent usage
    static func getAccountSuggestions(
        query: String,
        allAccounts: [Account],
        recentTransactions: [TransactionItem]
    ) -> [AutocompleteSuggestion] {
        // Get active accounts
        let activeAccounts = allAccounts.filter { !$0.isArchived }

        // Sort by recent usage
        var accountUsage: [PersistentIdentifier: Date] = [:]
        for transaction in recentTransactions.prefix(100) {
            guard let account = transaction.account else { continue }
            if accountUsage[account.persistentModelID] == nil {
                accountUsage[account.persistentModelID] = transaction.date
            }
        }

        let sortedAccounts = activeAccounts.sorted { a, b in
            let dateA = accountUsage[a.persistentModelID] ?? .distantPast
            let dateB = accountUsage[b.persistentModelID] ?? .distantPast
            return dateA > dateB
        }

        // Filter by query if not empty
        let filtered: [Account]
        if query.isEmpty {
            filtered = Array(sortedAccounts.prefix(8))
        } else {
            filtered = sortedAccounts.filter {
                $0.name.localizedCaseInsensitiveContains(query)
            }.prefix(8).map { $0 }
        }

        return filtered.map { account in
            AutocompleteSuggestion(
                id: "account-\(account.persistentModelID.hashValue)",
                name: account.name,
                colorHex: account.colorHex,
                type: .account,
                account: account
            )
        }
    }
}
