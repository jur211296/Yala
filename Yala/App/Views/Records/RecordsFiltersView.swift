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
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme

    @State private var filtersViewModel = RecordsFiltersViewModel()

    // MARK: - ViewModel Binding

    @Bindable var recordsViewModel: RecordsViewModel

    // MARK: - Sheet Presentation State

    @State private var showAccountsSheet = false
    @State private var showCategoriesSheet = false
    @State private var showTagsSheet = false
    @State private var showCurrencySheet = false

    // MARK: - Local Filter State (deferred — commit on Apply)

    @State private var localSelectedAccounts: Set<PersistentIdentifier> = []
    @State private var localSelectedCategories: Set<PersistentIdentifier> = []
    @State private var localSelectedSubcategories: Set<PersistentIdentifier> = []
    @State private var localSelectedTags: Set<PersistentIdentifier> = []
    @State private var localSelectedNeeds: Set<SubcategoryNeed> = []
    @State private var localSelectedTransactionNatures: Set<TransactionNature> = []
    @State private var localSelectedCurrencies: Set<CurrencyCode> = []
    @State private var localAmountCondition: AmountFilterCondition = .any
    @State private var localSearchText: String = ""
    @State private var localIsExcludeMode: Bool = false
    @State private var hasSnapshotted = false

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
                        // Include/Exclude mode selector
                        Picker("", selection: $localIsExcludeMode) {
                            Text(L10n.Filters.includeMode).tag(false)
                            Text(L10n.Filters.excludeMode).tag(true)
                        }
                        .pickerStyle(.segmented)

                        SectionBox(title: L10n.Filters.filterOptions) {
                            VStack(spacing: DS.Spacing.none) {
                                accountsContent
                                // Transaction natures (Income/Expense) - hidden in expenses-only mode and exclude mode
                                if !sessionState.isExpensesOnlyMode && !localIsExcludeMode {
                                    Divider().padding(.leading, DS.Spacing.lg)
                                    transactionNaturesContent
                                }
                                Divider().padding(.leading, DS.Spacing.lg)
                                categoriesContent
                                Divider().padding(.leading, DS.Spacing.lg)
                                tagsContent
                                Divider().padding(.leading, DS.Spacing.lg)
                                needsContent
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
                                clearLocalFilters()
                            }
                        } label: {
                            Text(L10n.Filters.clearFilters)
                                .font(DS.Typography.headline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS.FormRow.paddingV)
                                .background(.thCard)
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
                if !hasSnapshotted {
                    snapshotFromViewModel()
                    expandCategoryFiltersToSubcategories()
                    hasSnapshotted = true
                }
            }
            .onChange(of: localIsExcludeMode) { oldValue, newValue in
                guard oldValue != newValue else { return }
                localSelectedAccounts.removeAll()
                localSelectedCategories.removeAll()
                localSelectedSubcategories.removeAll()
                localSelectedNeeds.removeAll()
                localSelectedTags.removeAll()
                localSelectedCurrencies.removeAll()
                if sessionState.isExpensesOnlyMode {
                    localSelectedTransactionNatures = [.expense]
                } else {
                    localSelectedTransactionNatures.removeAll()
                }
                localAmountCondition = .any
                localSearchText = ""
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Action.apply) {
                        commitToViewModel()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    // MARK: - Filter Content Rows
    // Note: Period selection is handled by the control bar, not this filters sheet

    private var accountsContent: some View {
        FilterChipsSection(
            icon: "creditcard",
            title: L10n.Settings.accounts,
            status: selectedAccountsText,
            items: filtersViewModel.activeAccounts,
            showEmptyPlaceholder: false
        ) { account in
            accountChip(account)
        }
    }

    private func accountChip(_ account: Account) -> some View {
        let isSelected = localSelectedAccounts.contains(account.persistentModelID)

        return Button {
            if isSelected {
                localSelectedAccounts.remove(account.persistentModelID)
            } else {
                localSelectedAccounts.insert(account.persistentModelID)
            }
        } label: {
            Text(account.name)
                .font(DS.Typography.subheadline)
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

    private var selectedAccountsText: String {
        filtersViewModel.selectedAccountsText(selectedAccounts: localSelectedAccounts, isExcludeMode: localIsExcludeMode)
    }

    private var categoriesContent: some View {
        Button {
            showCategoriesSheet = true
        } label: {
            HStack(spacing: DS.Spacing.none) {
                FilterSectionHeader(
                    icon: "tag",
                    title: L10n.Filters.categories,
                    status: selectedCategoriesText
                )

                Spacer()

                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Expands category-level filters (from pie chart taps) into their visible subcategories
    /// so the filters sheet correctly reflects the active filter state.
    /// If specific subcategories are already selected for a category, keeps those instead of expanding.
    private func expandCategoryFiltersToSubcategories() {
        let selectedCats = localSelectedCategories
        guard !selectedCats.isEmpty else { return }

        let existingSubcategoryIDs = localSelectedSubcategories

        for categoryID in selectedCats {
            let subcategoriesOfCategory = filtersViewModel.allSubcategories
                .filter { sub in
                    guard let category = sub.category else { return false }
                    return category.persistentModelID == categoryID && sub.isVisible
                }
                .map { $0.persistentModelID }

            let alreadyHasSpecificSelection = subcategoriesOfCategory.contains { existingSubcategoryIDs.contains($0) }

            if !alreadyHasSpecificSelection {
                localSelectedSubcategories.formUnion(subcategoriesOfCategory)
            }
        }

        localSelectedCategories.removeAll()
    }

    private var selectedCategoriesText: String {
        filtersViewModel.selectedCategoriesText(selectedSubcategories: localSelectedSubcategories, isExcludeMode: localIsExcludeMode)
    }

    private var tagsContent: some View {
        FilterChipsSection(
            icon: "number",
            title: L10n.Settings.tags,
            status: selectedTagsText,
            items: filtersViewModel.activeTags,
            showEmptyPlaceholder: true
        ) { tag in
            tagChip(tag)
        }
    }

    private func tagChip(_ tag: Tag) -> some View {
        let isSelected = localSelectedTags.contains(tag.persistentModelID)

        return Button {
            if isSelected {
                localSelectedTags.remove(tag.persistentModelID)
            } else {
                localSelectedTags.insert(tag.persistentModelID)
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Circle()
                    .fill(isSelected ? Color.white : Color(hex: tag.colorHex))
                    .frame(width: DS.Chip.dotSize, height: DS.Chip.dotSize)

                Text(tag.name)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? theme.accent : Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedTagsText: String {
        filtersViewModel.selectedTagsText(selectedTags: localSelectedTags, isExcludeMode: localIsExcludeMode)
    }

    // MARK: - Transaction Natures Content (Income/Expense)

    private var transactionNaturesContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            FilterSectionHeader(
                icon: "arrow.up.arrow.down",
                title: L10n.Filters.type,
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
            .padding(.leading, DS.Spacing.lg + DS.FormRow.iconWidth + DS.Spacing.md)
            .padding(.trailing, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
        }
    }

    private func transactionNatureChip(_ nature: TransactionNature) -> some View {
        let isSelected = localSelectedTransactionNatures.contains(nature)

        return Button {
            if isSelected {
                localSelectedTransactionNatures.remove(nature)
            } else {
                localSelectedTransactionNatures.insert(nature)
            }
        } label: {
            Text(nature.displayName)
                .font(DS.Typography.subheadline)
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
        if localSelectedTransactionNatures.isEmpty {
            return L10n.Filters.all
        }
        if localSelectedTransactionNatures.count == TransactionNature.allCases.count {
            return L10n.Filters.all
        }
        return localSelectedTransactionNatures.first?.displayName ?? L10n.Filters.all
    }

    // MARK: - Needs Content

    private var needsContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            FilterSectionHeader(
                icon: "chart.bar.fill",
                title: L10n.Filters.need,
                status: selectedNeedsText
            )
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.md)

            // Chips
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(SubcategoryNeed.allCases, id: \.self) { need in
                    needChip(need)
                }
            }
            .padding(.leading, DS.Spacing.lg + DS.FormRow.iconWidth + DS.Spacing.md)
            .padding(.trailing, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
        }
    }

    private func needChip(_ need: SubcategoryNeed) -> some View {
        let isSelected = localSelectedNeeds.contains(need)

        return Button {
            if isSelected {
                localSelectedNeeds.remove(need)
            } else {
                localSelectedNeeds.insert(need)
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Text(need.displayName)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? theme.accent : Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedNeedsText: String {
        if localSelectedNeeds.isEmpty {
            return localIsExcludeMode ? L10n.Filters.nothingExcluded : L10n.Filters.allNeeds
        }
        return "\(localSelectedNeeds.count)"
    }

    @ViewBuilder
    private var currencyContent: some View {
        // Hide section if no transactions with currencies
        if !filtersViewModel.currenciesWithTransactions.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Header
                FilterSectionHeader(
                    icon: "arrow.triangle.2.circlepath",
                    title: L10n.Filters.currency,
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
                .padding(.leading, DS.Spacing.lg + DS.FormRow.iconWidth + DS.Spacing.md)
                .padding(.trailing, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)
            }
        }
    }

    private func currencyChip(_ currency: CurrencyCode) -> some View {
        let isSelected = localSelectedCurrencies.contains(currency)

        return Button {
            if isSelected {
                localSelectedCurrencies.remove(currency)
            } else {
                localSelectedCurrencies.insert(currency)
            }
        } label: {
            Text(currency.rawValue)
                .font(DS.Typography.subheadline)
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? theme.accent : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }

    private var selectedCurrenciesText: String {
        guard !filtersViewModel.currenciesWithTransactions.isEmpty else { return "" }

        if localSelectedCurrencies.isEmpty {
            return localIsExcludeMode ? L10n.Filters.nothingExcluded : L10n.Filters.all
        }
        if !localIsExcludeMode &&
           localSelectedCurrencies.count == filtersViewModel.currenciesWithTransactions.count {
            return L10n.Filters.all
        }
        return "\(localSelectedCurrencies.count)/\(filtersViewModel.currenciesWithTransactions.count)"
    }

    private var amountContent: some View {
        AmountFilterView(
            condition: $localAmountCondition,
            currencyCode: localSelectedCurrencies.count == 1
                ? localSelectedCurrencies.first : nil
        )
    }

    private var noteContent: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "note.text")
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
                .frame(width: DS.FormRow.iconWidth)

            TextField(L10n.Filters.noteContains, text: $localSearchText)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Accounts Sheet

    private var accountsSheetView: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        SectionBox(title: "") {
                            VStack(spacing: DS.Spacing.none) {
                                ForEach(Array(filtersViewModel.activeAccounts.enumerated()), id: \.element.id) { index, account in
                                    if index > 0 {
                                        SubsectionDivider()
                                    }

                                    Button {
                                        if localSelectedAccounts.contains(account.persistentModelID) {
                                            localSelectedAccounts.remove(account.persistentModelID)
                                        } else {
                                            localSelectedAccounts.insert(account.persistentModelID)
                                        }
                                    } label: {
                                        HStack {
                                            Text(account.name)
                                                .font(DS.Typography.body)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            if localSelectedAccounts.contains(account.persistentModelID) {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(theme.accent)
                                                    .font(DS.Typography.headline)
                                            }
                                        }
                                        .padding(.horizontal, DS.FormRow.paddingH)
                                        .padding(.vertical, DS.FormRow.paddingV)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                }
            }
            .navigationTitle(L10n.Filters.selectAccounts)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
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
            selectedSubcategories: $localSelectedSubcategories
        )
    }

    private func subcategories(for category: Category) -> [Subcategory] {
        filtersViewModel.subcategories(for: category)
    }

    private func subcategorySelectionSummary(for category: Category) -> String {
        filtersViewModel.subcategorySelectionSummary(for: category, selectedSubcategories: localSelectedSubcategories)
    }

    // MARK: - Tags Sheet

    private var tagsSheetView: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        SectionBox(title: "") {
                            VStack(spacing: DS.Spacing.none) {
                                ForEach(Array(filtersViewModel.activeTags.enumerated()), id: \.element.id) { index, tag in
                                    if index > 0 {
                                        SubsectionDivider()
                                    }

                                    Button {
                                        if localSelectedTags.contains(tag.persistentModelID) {
                                            localSelectedTags.remove(tag.persistentModelID)
                                        } else {
                                            localSelectedTags.insert(tag.persistentModelID)
                                        }
                                    } label: {
                                        HStack(spacing: DS.Spacing.md) {
                                            Circle()
                                                .fill(Color(hex: tag.colorHex))
                                                .frame(width: 10, height: 10)

                                            Text(tag.name)
                                                .font(DS.Typography.body)
                                                .foregroundStyle(.primary)

                                            Spacer()

                                            if localSelectedTags.contains(tag.persistentModelID) {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(theme.accent)
                                                    .font(DS.Typography.headline)
                                            }
                                        }
                                        .padding(.horizontal, DS.FormRow.paddingH)
                                        .padding(.vertical, DS.FormRow.paddingV)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                }
            }
            .navigationTitle(L10n.Filters.selectTags)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                        showTagsSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Snapshot / Commit

    private func snapshotFromViewModel() {
        localSelectedAccounts = recordsViewModel.selectedAccounts
        localSelectedCategories = recordsViewModel.selectedCategories
        localSelectedSubcategories = recordsViewModel.selectedSubcategories
        localSelectedTags = recordsViewModel.selectedTags
        localSelectedNeeds = recordsViewModel.selectedNeeds
        localSelectedTransactionNatures = recordsViewModel.selectedTransactionNatures
        localSelectedCurrencies = recordsViewModel.selectedCurrencies
        localAmountCondition = recordsViewModel.amountCondition
        localSearchText = recordsViewModel.searchText
        localIsExcludeMode = recordsViewModel.isExcludeMode
    }

    private func commitToViewModel() {
        // Set isExcludeMode FIRST — its didSet in SessionState clears selections,
        // then set filter values inside a batch to prevent resetExcludeModeIfNeeded
        // from resetting exclude mode during intermediate empty states.
        recordsViewModel.isExcludeMode = localIsExcludeMode
        SessionState.shared.performBatchFilterUpdate {
            recordsViewModel.selectedAccounts = localSelectedAccounts
            recordsViewModel.selectedCategories = localSelectedCategories
            recordsViewModel.selectedSubcategories = localSelectedSubcategories
            recordsViewModel.selectedTags = localSelectedTags
            recordsViewModel.selectedNeeds = localSelectedNeeds
            recordsViewModel.selectedTransactionNatures = localSelectedTransactionNatures
            recordsViewModel.selectedCurrencies = localSelectedCurrencies
            recordsViewModel.amountCondition = localAmountCondition
            recordsViewModel.searchText = localSearchText
        }
    }

    private func clearLocalFilters() {
        localSelectedAccounts.removeAll()
        localSelectedCategories.removeAll()
        localSelectedSubcategories.removeAll()
        localSelectedNeeds.removeAll()
        if sessionState.isExpensesOnlyMode {
            localSelectedTransactionNatures = [.expense]
        } else {
            localSelectedTransactionNatures.removeAll()
        }
        localSelectedTags.removeAll()
        localIsExcludeMode = false
        localAmountCondition = .any
        localSelectedCurrencies = []
        localSearchText = ""
    }

    // MARK: - Currency Sheet

    private var currencySheetView: some View {
        NavigationStack {
            MultiSelectionList(
                title: L10n.Filters.selectCurrencies,
                items: filtersViewModel.currenciesWithTransactions,
                selection: $localSelectedCurrencies,
                label: { $0.rawValue }
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                        showCurrencySheet = false
                    }
                }
            }
        }
    }
}
