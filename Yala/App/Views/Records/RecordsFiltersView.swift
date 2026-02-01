//
//  RecordsFiltersView.swift
//  Yala
//
//  Replica of ExportFiltersStepView design for Records
//

import SwiftData
import SwiftUI

struct RecordsFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var filtersViewModel = RecordsFiltersViewModel()

    // MARK: - ViewModel Binding

    @Bindable var recordsViewModel: RecordsViewModel

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
                                recordsViewModel.clearFilters()
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
            .onAppear {
                filtersViewModel.setContext(modelContext)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark") {
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
            items: filtersViewModel.activeAccounts,
            showEmptyPlaceholder: false
        ) { account in
            accountChip(account)
        }
        .onAppear {
            syncAccountsSelection()
        }
    }

    private func accountChip(_ account: Account) -> some View {
        let isSelected = recordsViewModel.selectedAccounts.contains(account.persistentModelID)

        return Button {
            if isSelected {
                recordsViewModel.selectedAccounts.remove(account.persistentModelID)
            } else {
                recordsViewModel.selectedAccounts.insert(account.persistentModelID)
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
        filtersViewModel.selectedAccountsText(selectedAccounts: recordsViewModel.selectedAccounts)
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
        filtersViewModel.selectedCategoriesText(selectedSubcategories: recordsViewModel.selectedSubcategories)
    }

    private var tagsContent: some View {
        FilterChipsSection(
            icon: "number",
            title: "Etiquetas",
            status: selectedTagsText,
            items: filtersViewModel.activeTags,
            showEmptyPlaceholder: true
        ) { tag in
            tagChip(tag)
        }
        .onAppear {
            syncTagsSelection()
        }
    }

    private func tagChip(_ tag: Tag) -> some View {
        let isSelected = recordsViewModel.selectedTags.contains(tag.persistentModelID)

        return Button {
            if isSelected {
                recordsViewModel.selectedTags.remove(tag.persistentModelID)
            } else {
                recordsViewModel.selectedTags.insert(tag.persistentModelID)
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
        filtersViewModel.selectedTagsText(selectedTags: recordsViewModel.selectedTags)
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
        let isSelected = recordsViewModel.selectedTransactionNatures.contains(nature)

        return Button {
            if isSelected {
                recordsViewModel.selectedTransactionNatures.remove(nature)
            } else {
                recordsViewModel.selectedTransactionNatures.insert(nature)
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
        if recordsViewModel.selectedTransactionNatures.isEmpty { return "Todos" }
        if recordsViewModel.selectedTransactionNatures.count == TransactionNature.allCases.count {
            return "Todos"
        }
        return recordsViewModel.selectedTransactionNatures.first?.displayName ?? "Todos"
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
        let isSelected = recordsViewModel.selectedNatures.contains(nature)

        return Button {
            if isSelected {
                recordsViewModel.selectedNatures.remove(nature)
            } else {
                recordsViewModel.selectedNatures.insert(nature)
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
        if recordsViewModel.selectedNatures.isEmpty { return "Todas" }
        return "\(recordsViewModel.selectedNatures.count)"
    }

    @ViewBuilder
    private var currencyContent: some View {
        // Hide section if no transactions with currencies
        if !filtersViewModel.currenciesWithTransactions.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Header
                FilterSectionHeader(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Moneda",
                    status: selectedCurrenciesText
                )
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)

                // Chips - only currencies with transactions
                FlowLayout(spacing: DS.Spacing.sm) {
                    ForEach(filtersViewModel.currenciesWithTransactions) { currency in
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
    }

    private func currencyChip(_ currency: CurrencyCode) -> some View {
        let isSelected = recordsViewModel.selectedCurrencies.contains(currency)

        return Button {
            if isSelected {
                recordsViewModel.selectedCurrencies.remove(currency)
            } else {
                recordsViewModel.selectedCurrencies.insert(currency)
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
        // If no currencies with transactions, don't show anything
        guard !filtersViewModel.currenciesWithTransactions.isEmpty else { return "" }

        if recordsViewModel.selectedCurrencies.isEmpty ||
           recordsViewModel.selectedCurrencies.count == filtersViewModel.currenciesWithTransactions.count {
            return L10n.Filters.all
        }
        return "\(recordsViewModel.selectedCurrencies.count)/\(filtersViewModel.currenciesWithTransactions.count)"
    }

    private var amountContent: some View {
        AmountFilterView(
            condition: $recordsViewModel.amountCondition,
            currencyCode: recordsViewModel.selectedCurrencies.count == 1
                ? recordsViewModel.selectedCurrencies.first : nil
        )
    }

    private var noteContent: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "note.text")
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: 24)

            TextField(L10n.Filters.noteContains, text: $recordsViewModel.searchText)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Accounts Sheet

    private var accountsSheetView: some View {
        NavigationStack {
            List {
                ForEach(filtersViewModel.activeAccounts) { account in
                    Button {
                        if recordsViewModel.selectedAccounts.contains(account.persistentModelID) {
                            recordsViewModel.selectedAccounts.remove(account.persistentModelID)
                        } else {
                            recordsViewModel.selectedAccounts.insert(account.persistentModelID)
                        }
                    } label: {
                        HStack {
                            Text(account.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if recordsViewModel.selectedAccounts.contains(account.persistentModelID) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.brandPrimary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.yalaCard)
            .navigationTitle(L10n.Filters.selectAccounts)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "chevron.left") {
                        showAccountsSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Categories Sheet

    private var categoriesSheetView: some View {
        CategorySelectorSheet(
            categories: filtersViewModel.allCategories,
            subcategories: filtersViewModel.allSubcategories,
            selectedSubcategories: $recordsViewModel.selectedSubcategories
        )
    }

    private func subcategories(for category: Category) -> [Subcategory] {
        filtersViewModel.subcategories(for: category)
    }

    private func subcategorySelectionSummary(for category: Category) -> String {
        filtersViewModel.subcategorySelectionSummary(for: category, selectedSubcategories: recordsViewModel.selectedSubcategories)
    }

    // MARK: - Tags Sheet

    private var tagsSheetView: some View {
        NavigationStack {
            List {
                ForEach(filtersViewModel.activeTags) { tag in
                    Button {
                        if recordsViewModel.selectedTags.contains(tag.persistentModelID) {
                            recordsViewModel.selectedTags.remove(tag.persistentModelID)
                        } else {
                            recordsViewModel.selectedTags.insert(tag.persistentModelID)
                        }
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(hex: tag.colorHex))
                                .frame(width: 10, height: 10)

                            Text(tag.name)
                                .foregroundStyle(.primary)

                            Spacer()

                            if recordsViewModel.selectedTags.contains(tag.persistentModelID) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.brandPrimary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.yalaCard)
            .navigationTitle(L10n.Filters.selectTags)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "chevron.left") {
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
                items: filtersViewModel.currenciesWithTransactions,
                selection: $recordsViewModel.selectedCurrencies,
                label: { $0.rawValue }
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "chevron.left") {
                        showCurrencySheet = false
                    }
                }
            }
        }
    }
}
