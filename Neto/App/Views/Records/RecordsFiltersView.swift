//
//  RecordsFiltersView.swift
//  Neto
//
//  Replica of ExportFiltersStepView design for Records
//

import SwiftData
import SwiftUI

struct RecordsFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - Data Queries

    @Query(sort: \Account.name) private var allAccounts: [Account]
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(sort: \Subcategory.sortOrder) private var allSubcategories: [Subcategory]

    // MARK: - ViewModel Binding

    @Bindable var viewModel: RecordsViewModel

    // MARK: - Sheet Presentation State

    @State private var showAccountsSheet = false
    @State private var showCategoriesSheet = false
    @State private var showTagsSheet = false
    @State private var showCurrencySheet = false

    // MARK: - Initialization Flags

    @State private var hasInitializedAccounts = false
    @State private var hasInitializedTags = false
    @State private var hasInitializedCurrencies = false
    @State private var hasInitializedCategories = false

    // MARK: - Computed Properties

    private var activeAccounts: [Account] {
        allAccounts.filter { !$0.isArchived }
    }

    private var activeTags: [Tag] {
        allTags.filter { $0.isActive }
    }

    // MARK: - Body

    var body: some View {
        mainContent
            .sheet(isPresented: $showAccountsSheet) {
                accountsSheetView
            }
            .sheet(isPresented: $showCategoriesSheet) {
                categoriesSheetView
            }
            .sheet(isPresented: $showTagsSheet) {
                tagsSheetView
            }
            .sheet(isPresented: $showCurrencySheet) {
                currencySheetView
            }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        SectionBox(title: L10n.Filters.filterOptions) {
                            VStack(spacing: 0) {
                                accountsContent
                                Divider().padding(.leading, DS.Spacing.lg)
                                transactionNaturesContent
                                Divider().padding(.leading, DS.Spacing.lg)
                                categoriesContent
                                Divider().padding(.leading, DS.Spacing.lg)
                                tagsContent
                                Divider().padding(.leading, DS.Spacing.lg)
                                naturesContent
                                Divider().padding(.leading, DS.Spacing.lg)
                                currencyContent
                                Divider().padding(.leading, DS.Spacing.lg)
                                amountContent
                                Divider().padding(.leading, DS.Spacing.lg)
                                noteContent
                            }
                        }

                        // Reset filters button
                        Button {
                            withAnimation {
                                viewModel.clearFilters()
                            }
                        } label: {
                            Text(L10n.Filters.clearFilters)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.electricIndigo)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS.FormRow.paddingV)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, DS.Spacing.xxl)
                    .padding(.horizontal, DS.Spacing.lg)
                }
            }
            .navigationTitle(L10n.Filters.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Aplicar") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brandPrimary)
                }
            }
        }
    }

    // MARK: - Filter Content Rows
    // Note: Period selection is handled by the control bar, not this filters sheet

    private var accountsContent: some View {
        FilterChipsSection(
            icon: "creditcard",
            title: "Cuentas",
            status: selectedAccountsText,
            items: activeAccounts,
            showEmptyPlaceholder: false
        ) { account in
            accountChip(account)
        }
        .onAppear {
            syncAccountsSelection()
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
                        .fill(
                            isSelected ? Color(hex: account.colorHex) : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }

    private func syncAccountsSelection() {
        // Empty selection = no filter (show all)
        // Only set the flag to avoid re-initialization
        hasInitializedAccounts = true
    }

    private var selectedAccountsText: String {
        if viewModel.selectedAccounts.isEmpty {
            return "Todas"
        }
        if viewModel.selectedAccounts.count == activeAccounts.count {
            return "Todas"
        }
        return "\(viewModel.selectedAccounts.count)/\(activeAccounts.count)"
    }

    private var categoriesContent: some View {
        Button {
            showCategoriesSheet = true
        } label: {
            HStack(spacing: 0) {
                FilterSectionHeader(
                    icon: "tag",
                    title: "Categorías",
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
        .onAppear {
            syncCategoriesSelection()
        }
    }

    private func syncCategoriesSelection() {
        // Empty selection = no filter (show all)
        hasInitializedCategories = true
    }

    private var selectedCategoriesText: String {
        let subCount = viewModel.selectedSubcategories.count

        if subCount == 0 {
            return "Todas"
        }

        // All selected = no filter (equivalent to "Todas")
        let allIDs = Set(allSubcategories.map { $0.persistentModelID })
        if viewModel.selectedSubcategories == allIDs {
            return "Todas"
        }

        // Count unique categories from selected subcategories
        let selectedSubs = allSubcategories.filter {
            viewModel.selectedSubcategories.contains($0.persistentModelID)
        }
        if selectedSubs.isEmpty {
            return "Todas"
        }

        if let firstSub = selectedSubs.first {
            let remainingCount = selectedSubs.count - 1
            if remainingCount > 0 {
                return "\(firstSub.name) +\(remainingCount)"
            } else {
                return firstSub.name
            }
        }

        return "Todas"
    }

    private var tagsContent: some View {
        FilterChipsSection(
            icon: "number",
            title: "Etiquetas",
            status: selectedTagsText,
            items: activeTags,
            showEmptyPlaceholder: true
        ) { tag in
            tagChip(tag)
        }
        .onAppear {
            syncTagsSelection()
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
            HStack(spacing: DS.Spacing.sm) {
                Circle()
                    .fill(isSelected ? Color.white : Color(hex: tag.colorHex))
                    .frame(width: 8, height: 8)

                Text(tag.name)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? Color.brandPrimary : Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }

    private func syncTagsSelection() {
        // Empty selection = no filter (show all)
        hasInitializedTags = true
    }

    private var selectedTagsText: String {
        if viewModel.selectedTags.isEmpty {
            return "Todas"
        }
        if viewModel.selectedTags.count == activeTags.count {
            return "Todas"
        }
        return "\(viewModel.selectedTags.count)/\(activeTags.count)"
    }

    // MARK: - Transaction Natures Content (Income/Expense)

    private var transactionNaturesContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            FilterSectionHeader(
                icon: "arrow.up.arrow.down",
                title: "Tipo",
                status: selectedTransactionNaturesText
            )
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.md)

            // Chips
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(TransactionNature.allCases, id: \.self) { nature in
                    transactionNatureChip(nature)
                }
            }
            .padding(.leading, 52)
            .padding(.trailing, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
        }
    }

    private func transactionNatureChip(_ nature: TransactionNature) -> some View {
        let isSelected = viewModel.selectedTransactionNatures.contains(nature)

        return Button {
            if isSelected {
                viewModel.selectedTransactionNatures.remove(nature)
            } else {
                viewModel.selectedTransactionNatures.insert(nature)
            }
        } label: {
            Text(nature.displayName)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? nature.color : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }

    private var selectedTransactionNaturesText: String {
        if viewModel.selectedTransactionNatures.isEmpty { return "Todos" }
        if viewModel.selectedTransactionNatures.count == TransactionNature.allCases.count {
            return "Todos"
        }
        return viewModel.selectedTransactionNatures.first?.displayName ?? "Todos"
    }

    // MARK: - Natures Content

    private var naturesContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            FilterSectionHeader(
                icon: "leaf.fill",
                title: "Naturaleza",
                status: selectedNaturesText
            )
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.md)

            // Chips
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(SubcategoryNature.allCases, id: \.self) { nature in
                    natureChip(nature)
                }
            }
            .padding(.leading, 52)
            .padding(.trailing, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
        }
    }

    private func natureChip(_ nature: SubcategoryNature) -> some View {
        let isSelected = viewModel.selectedNatures.contains(nature)

        return Button {
            if isSelected {
                viewModel.selectedNatures.remove(nature)
            } else {
                viewModel.selectedNatures.insert(nature)
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Text(nature.displayName)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? Color.brandPrimary : Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedNaturesText: String {
        if viewModel.selectedNatures.isEmpty { return "Todas" }
        return "\(viewModel.selectedNatures.count)"
    }

    private var currencyContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            FilterSectionHeader(
                icon: "arrow.triangle.2.circlepath",
                title: "Moneda",
                status: selectedCurrenciesText
            )
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.md)

            // Chips - aligned after icon
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(CurrencyCode.allCases) { currency in
                    currencyChip(currency)
                }
            }
            .padding(.leading, 52)
            .padding(.trailing, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
        }
        .onAppear {
            syncCurrenciesSelection()
        }
    }

    private func currencyChip(_ currency: CurrencyCode) -> some View {
        let isSelected = viewModel.selectedCurrencies.contains(currency)

        return Button {
            if isSelected {
                viewModel.selectedCurrencies.remove(currency)
            } else {
                viewModel.selectedCurrencies.insert(currency)
            }
        } label: {
            Text(currency.rawValue)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.brandPrimary : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }

    private func syncCurrenciesSelection() {
        // Empty selection = no filter (show all)
        hasInitializedCurrencies = true
    }

    private var selectedCurrenciesText: String {
        if viewModel.selectedCurrencies.isEmpty {
            return "Todas"
        }
        if viewModel.selectedCurrencies.count == CurrencyCode.allCases.count {
            return "Todas"
        }
        return "\(viewModel.selectedCurrencies.count)/\(CurrencyCode.allCases.count)"
    }

    private var amountContent: some View {
        AmountFilterView(
            condition: $viewModel.amountCondition,
            currencyCode: viewModel.selectedCurrencies.count == 1
                ? viewModel.selectedCurrencies.first : nil
        )
    }

    private var noteContent: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "note.text")
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: 24)

            TextField(L10n.Filters.noteContains, text: $viewModel.searchText)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Accounts Sheet

    private var accountsSheetView: some View {
        NavigationStack {
            List {
                ForEach(activeAccounts) { account in
                    Button {
                        if viewModel.selectedAccounts.contains(account.persistentModelID) {
                            viewModel.selectedAccounts.remove(account.persistentModelID)
                        } else {
                            viewModel.selectedAccounts.insert(account.persistentModelID)
                        }
                    } label: {
                        HStack {
                            Text(account.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if viewModel.selectedAccounts.contains(account.persistentModelID) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.brandPrimary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle(L10n.Filters.selectAccounts)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "chevron.left") {
                        showAccountsSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Categories Sheet

    private var categoriesSheetView: some View {
        CategorySelectorSheet(
            categories: allCategories,
            subcategories: allSubcategories,
            selectedSubcategories: $viewModel.selectedSubcategories
        )
    }

    private func subcategories(for category: Category) -> [Subcategory] {
        allSubcategories.filter { sub in
            sub.category == category && sub.isVisible
        }
    }

    private func subcategorySelectionSummary(for category: Category) -> String {
        let subs = subcategories(for: category)
        let total = subs.count
        let selectedCount = subs.filter {
            viewModel.selectedSubcategories.contains($0.persistentModelID)
        }.count

        if total == 0 {
            return L10n.Filters.noSubcategories
        }

        if selectedCount == 0 {
            return L10n.Filters.noneSelected
        }

        if selectedCount == total {
            return L10n.Filters.allSubcategories
        }

        return "\(selectedCount) / \(total)"
    }

    // MARK: - Tags Sheet

    private var tagsSheetView: some View {
        NavigationStack {
            List {
                ForEach(allTags.filter { $0.isActive }) { tag in
                    Button {
                        if viewModel.selectedTags.contains(tag.persistentModelID) {
                            viewModel.selectedTags.remove(tag.persistentModelID)
                        } else {
                            viewModel.selectedTags.insert(tag.persistentModelID)
                        }
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(hex: tag.colorHex))
                                .frame(width: 10, height: 10)

                            Text(tag.name)
                                .foregroundStyle(.primary)

                            Spacer()

                            if viewModel.selectedTags.contains(tag.persistentModelID) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.brandPrimary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle(L10n.Filters.selectTags)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "chevron.left") {
                        showTagsSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Currency Sheet

    private var currencySheetView: some View {
        NavigationStack {
            MultiSelectionList(
                title: L10n.Filters.selectCurrencies,
                items: CurrencyCode.allCases,
                selection: $viewModel.selectedCurrencies,
                label: { $0.rawValue }
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "chevron.left") {
                        showCurrencySheet = false
                    }
                }
            }
        }
    }
}
