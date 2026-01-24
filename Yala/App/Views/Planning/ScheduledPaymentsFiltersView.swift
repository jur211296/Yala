//
//  ScheduledPaymentsFiltersView.swift
//  Yala
//
//  Filters sheet for scheduled payments
//

import SwiftData
import SwiftUI

struct ScheduledPaymentsFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ScheduledPaymentsViewModel

    let accounts: [Account]
    let categories: [Category]
    let tags: [Tag]

    @State private var showCategoriesSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    SectionBox(title: NSLocalizedString("filters.title", comment: "")) {
                        VStack(spacing: 0) {
                            accountsContent
                            Divider().padding(.leading, 16)
                            transactionTypesContent
                            Divider().padding(.leading, 16)
                            categoriesContent
                            Divider().padding(.leading, 16)
                            tagsContent
                        }
                    }
                }
                .padding(.vertical, DS.Spacing.lg)
                .padding(.horizontal, DS.Spacing.lg)
            }
            .background(PanelBackgroundView())
            .navigationTitle(NSLocalizedString("filters.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("action.close", comment: "")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.hasActiveFilters {
                        Button(NSLocalizedString("filters.clear", comment: "")) {
                            viewModel.clearFilters()
                        }
                        .foregroundStyle(Color.hotPink)
                    }
                }
            }
            .sheet(isPresented: $showCategoriesSheet) {
                categoriesSheetView
            }
        }
    }

    // MARK: - Accounts Content

    private var accountsContent: some View {
        FilterChipsSection(
            icon: "creditcard",
            title: NSLocalizedString("settings.accounts", comment: ""),
            status: selectedAccountsText,
            items: activeAccounts,
            showEmptyPlaceholder: false
        ) { account in
            accountChip(account)
        }
    }

    private func accountChip(_ account: Account) -> some View {
        let isSelected = viewModel.selectedAccounts.contains(account.persistentModelID)

        return Button {
            if isSelected {
                viewModel.selectedAccounts.remove(account.persistentModelID)
            } else {
                viewModel.selectedAccounts.insert(account.persistentModelID)
            }
        } label: {
            Text(account.name)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? Color(hex: account.colorHex) : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }

    private var selectedAccountsText: String {
        if viewModel.selectedAccounts.isEmpty {
            return NSLocalizedString("filters.all", comment: "")
        }
        return "\(viewModel.selectedAccounts.count)/\(activeAccounts.count)"
    }

    // MARK: - Transaction Types Content

    private var transactionTypesContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            FilterSectionHeader(
                icon: "arrow.left.arrow.right",
                title: NSLocalizedString("filters.transaction.type", comment: ""),
                status: selectedTransactionTypesText
            )
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.md)

            FlowLayout(spacing: DS.Spacing.sm) {
                transactionTypeChip("expense", label: NSLocalizedString("transaction.type.expense", comment: ""))
                transactionTypeChip("income", label: NSLocalizedString("transaction.type.income", comment: ""))
            }
            .padding(.leading, 52)
            .padding(.trailing, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
        }
    }

    private func transactionTypeChip(_ type: String, label: String) -> some View {
        let isSelected = viewModel.selectedTransactionNatures.contains(type)

        return Button {
            if isSelected {
                viewModel.selectedTransactionNatures.remove(type)
            } else {
                viewModel.selectedTransactionNatures.insert(type)
            }
        } label: {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.electricIndigo : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }

    private var selectedTransactionTypesText: String {
        if viewModel.selectedTransactionNatures.isEmpty {
            return NSLocalizedString("filters.all", comment: "")
        }
        return "\(viewModel.selectedTransactionNatures.count)"
    }

    // MARK: - Categories Content

    private var categoriesContent: some View {
        Button {
            showCategoriesSheet = true
        } label: {
            HStack(spacing: 0) {
                FilterSectionHeader(
                    icon: "tag",
                    title: NSLocalizedString("categories.title", comment: ""),
                    status: selectedCategoriesText
                )

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var selectedCategoriesText: String {
        if viewModel.selectedSubcategories.isEmpty && viewModel.selectedCategories.isEmpty {
            return NSLocalizedString("filters.all", comment: "")
        }
        let count = viewModel.selectedSubcategories.count + viewModel.selectedCategories.count
        return "\(count)"
    }

    // MARK: - Tags Content

    private var tagsContent: some View {
        FilterChipsSection(
            icon: "number",
            title: NSLocalizedString("settings.tags", comment: ""),
            status: selectedTagsText,
            items: activeTags,
            showEmptyPlaceholder: true
        ) { tag in
            tagChip(tag)
        }
    }

    private func tagChip(_ tag: Tag) -> some View {
        let isSelected = viewModel.selectedTags.contains(tag.persistentModelID)

        return Button {
            if isSelected {
                viewModel.selectedTags.remove(tag.persistentModelID)
            } else {
                viewModel.selectedTags.insert(tag.persistentModelID)
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: tag.iconName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white : Color(hex: tag.colorHex))

                Text(tag.name)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: tag.colorHex) : Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedTagsText: String {
        if viewModel.selectedTags.isEmpty {
            return NSLocalizedString("filters.all", comment: "")
        }
        return "\(viewModel.selectedTags.count)/\(activeTags.count)"
    }

    // MARK: - Categories Sheet

    private var categoriesSheetView: some View {
        CategorySelectorSheet(
            categories: categories,
            subcategories: categories.flatMap { $0.subcategories },
            selectedSubcategories: $viewModel.selectedSubcategories
        )
    }

    // MARK: - Computed Properties

    private var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }

    private var activeTags: [Tag] {
        tags.filter { $0.isActive }
    }
}
