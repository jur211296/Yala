//
//  BudgetEditorView.swift
//  Yala
//
//  Budget editor sheet for creating and editing budgets
//

import SwiftData
import SwiftUI

struct BudgetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState
    @Environment(EntityDeletionService.self) private var deletionService

    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Account.name) private var allAccounts: [Account]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(sort: \Subcategory.sortOrder) private var allSubcategories: [Subcategory]

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.pen.rawValue

    let budget: Budget?

    // Basic Info
    @State private var name: String = ""
    @State private var limitAmount: String = ""
    @State private var currencyCode: String = ""

    // Period
    @State private var selectedPeriodType: BudgetPeriodType = .monthly
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()

    // Active status
    @State private var isActive: Bool = true

    // Filters - Using PersistentIdentifier for consistency with RecordsFiltersView
    @State private var selectedAccounts: Set<PersistentIdentifier> = []
    @State private var selectedSubcategories: Set<PersistentIdentifier> = []
    @State private var selectedTags: Set<PersistentIdentifier> = []
    @State private var selectedNatures: Set<SubcategoryNature> = []

    // Sheet states
    @State private var showCategoriesSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showSaveError = false

    // Focus state
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Basic Information Section
                    basicInfoSection

                    // Period Section
                    periodSection

                    // Date Range (only for unique budgets)
                    if selectedPeriodType == .unique {
                        dateRangeSection
                    }

                    // Active Toggle
                    activeToggle

                    // Filters Section
                    filtersSection

                    // Delete Button (only for existing budgets)
                    if budget != nil {
                        deleteSection
                    }
                }
                .padding(.vertical, DS.Spacing.xxl)
                .padding(.horizontal, DS.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(
                PanelBackgroundView()
                    .dismissKeyboardOnTap()
            )
            .alert(
                NSLocalizedString("budgets.delete.confirm.title", comment: ""),
                isPresented: $showDeleteConfirmation
            ) {
                Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("action.delete", comment: ""), role: .destructive) {
                    deleteBudget()
                }
            } message: {
                Text(NSLocalizedString("budgets.delete.confirm.message", comment: ""))
            }
            .navigationTitle(
                budget == nil
                    ? NSLocalizedString("budgets.new", comment: "")
                    : NSLocalizedString("budgets.edit", comment: "")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: saveBudget, isDisabled: !canSave)
                }
            }
            .sheet(isPresented: $showCategoriesSheet) {
                categoriesSheetView
            }
            .onChange(of: showCategoriesSheet) { _, isPresenting in
                if isPresenting { dismissKeyboard() }
            }
            .onAppear {
                loadBudgetData()
                // Auto-focus name field for new budgets
                if budget == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isNameFieldFocused = true
                    }
                }
            }
            .onChange(of: selectedAccounts) { _, newAccounts in
                updateCurrencyFromAccounts(newAccounts)
            }
            .alert(
                L10n.Common.error,
                isPresented: $showSaveError,
                actions: {
                    Button(L10n.Common.understood, role: .cancel) {}
                },
                message: {
                    Text(L10n.Common.saveError)
                }
            )
        }
    }

    // MARK: - Basic Information Section

    private var basicInfoSection: some View {
        SectionBox(title: NSLocalizedString("budgets.editor.basic.info", comment: "")) {
            VStack(spacing: 0) {
                // Name Field
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "textformat")
                        .foregroundStyle(.secondary)
                    TextField(
                        NSLocalizedString("budgets.editor.name.placeholder", comment: ""),
                        text: $name
                    )
                    .textContentType(.name)
                    .focused($isNameFieldFocused)
                }
                .padding()

                SubsectionDivider()

                // Amount Field (Large and prominent like AccountFormView)
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                        Text(currencyCode)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $limitAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 28, weight: .bold))
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Period Section

    private var periodSection: some View {
        SectionBox(title: NSLocalizedString("budgets.editor.period.type", comment: "")) {
            Picker("", selection: $selectedPeriodType) {
                Text(NSLocalizedString("budgets.period.weekly", comment: "")).tag(BudgetPeriodType.weekly)
                Text(NSLocalizedString("budgets.period.monthly", comment: "")).tag(BudgetPeriodType.monthly)
                Text(NSLocalizedString("budgets.period.yearly", comment: "")).tag(BudgetPeriodType.yearly)
                Text(NSLocalizedString("budgets.period.unique", comment: "")).tag(BudgetPeriodType.unique)
            }
            .pickerStyle(.segmented)
            .padding()
        }
    }

    // MARK: - Date Range Section

    private var dateRangeSection: some View {
        SectionBox(title: NSLocalizedString("budgets.editor.date.range", comment: "")) {
            VStack(spacing: 0) {
                // Start Date
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "calendar")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    Text(NSLocalizedString("budgets.editor.start.date", comment: ""))
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    DatePicker(
                        "",
                        selection: $startDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
                .padding()

                SubsectionDivider()

                // End Date
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "calendar")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    Text(NSLocalizedString("budgets.editor.end.date", comment: ""))
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    DatePicker(
                        "",
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
                .padding()
            }
        }
    }

    // MARK: - Active Toggle

    private var activeToggle: some View {
        Toggle(isOn: $isActive) {
            Text(NSLocalizedString("common.active", comment: ""))
                .font(.body)
        }
        .tint(Color.brandPrimary)
    }

    // MARK: - Filters Section

    private var filtersSection: some View {
        SectionBox(title: NSLocalizedString("budgets.editor.filters", comment: "")) {
            VStack(spacing: 0) {
                accountsContent
                Divider().padding(.leading, 16)
                categoriesContent
                Divider().padding(.leading, 16)
                tagsContent
                Divider().padding(.leading, 16)
                naturesContent
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
        let isSelected = selectedAccounts.contains(account.persistentModelID)

        return Button {
            if isSelected {
                selectedAccounts.remove(account.persistentModelID)
            } else {
                selectedAccounts.insert(account.persistentModelID)
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

    private var selectedAccountsText: String {
        if selectedAccounts.isEmpty {
            return NSLocalizedString("filters.all", comment: "")
        }
        if selectedAccounts.count == activeAccounts.count {
            return NSLocalizedString("filters.all", comment: "")
        }
        return "\(selectedAccounts.count)/\(activeAccounts.count)"
    }

    // MARK: - Categories Content

    private var categoriesContent: some View {
        Button {
            showCategoriesSheet = true
        } label: {
            HStack(spacing: 0) {
                FilterSectionHeader(
                    icon: "tag",
                    title: NSLocalizedString("subcategories.title", comment: ""),
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
        let subCount = selectedSubcategories.count

        if subCount == 0 {
            return NSLocalizedString("filters.all", comment: "")
        }

        // Get selected subcategories
        let selectedSubs = allSubcategories.filter {
            selectedSubcategories.contains($0.persistentModelID)
        }
        if selectedSubs.isEmpty {
            return NSLocalizedString("filters.all", comment: "")
        }

        if let firstSub = selectedSubs.first {
            let remainingCount = selectedSubs.count - 1
            if remainingCount > 0 {
                return "\(firstSub.name) +\(remainingCount)"
            } else {
                return firstSub.name
            }
        }

        return NSLocalizedString("filters.all", comment: "")
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
        let isSelected = selectedTags.contains(tag.persistentModelID)

        return Button {
            if isSelected {
                selectedTags.remove(tag.persistentModelID)
            } else {
                selectedTags.insert(tag.persistentModelID)
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
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

    private var selectedTagsText: String {
        if selectedTags.isEmpty {
            return NSLocalizedString("filters.all", comment: "")
        }
        if selectedTags.count == activeTags.count {
            return NSLocalizedString("filters.all", comment: "")
        }
        return "\(selectedTags.count)/\(activeTags.count)"
    }

    // MARK: - Natures Content

    private var naturesContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            FilterSectionHeader(
                icon: "leaf.fill",
                title: NSLocalizedString("nature.title", comment: ""),
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
        let isSelected = selectedNatures.contains(nature)

        return Button {
            if isSelected {
                selectedNatures.remove(nature)
            } else {
                selectedNatures.insert(nature)
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
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
        if selectedNatures.isEmpty {
            return NSLocalizedString("filters.all", comment: "")
        }
        return "\(selectedNatures.count)"
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            HStack {
                Spacer()
                Text(NSLocalizedString("budgets.delete", comment: ""))
                    .font(.body.weight(.medium))
                Spacer()
            }
            .padding(.vertical, DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.red.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.red)
        .padding(.top, 16)
    }

    // MARK: - Categories Sheet

    private var categoriesSheetView: some View {
        CategorySelectorSheet(
            categories: categories,
            subcategories: allSubcategories,
            selectedSubcategories: $selectedSubcategories
        )
    }

    // MARK: - Computed Properties

    private var activeAccounts: [Account] {
        allAccounts.filter { !$0.isArchived }
    }

    private var activeTags: [Tag] {
        allTags.filter { $0.isActive }
    }

    // MARK: - Validation

    private var canSave: Bool {
        !name.isEmpty && !limitAmount.isEmpty && Double(limitAmount) != nil
    }

    // MARK: - Data Management

    /// Update currency based on selected accounts
    /// - If exactly 1 account is selected, use its currency
    /// - Otherwise, use the default/preferred currency
    private func updateCurrencyFromAccounts(_ accountIds: Set<PersistentIdentifier>) {
        if accountIds.count == 1,
           let accountId = accountIds.first,
           let account = activeAccounts.first(where: { $0.persistentModelID == accountId }) {
            currencyCode = account.currencyCode
        } else {
            currencyCode = defaultCurrencyCode
        }
    }

    private func loadBudgetData() {
        // Initialize currency code
        currencyCode = defaultCurrencyCode

        guard let budget = budget else { return }

        name = budget.name
        currencyCode = budget.currencyCode
        limitAmount = String(format: "%.2f", budget.limitAmount)
        selectedPeriodType = BudgetPeriodType(rawValue: budget.periodType) ?? .monthly
        isActive = budget.isActive

        if let start = budget.startDate {
            startDate = start
        }
        if let end = budget.endDate {
            endDate = end
        }

        // Convert arrays to sets of PersistentIdentifiers
        selectedAccounts = Set(budget.accounts.map { $0.persistentModelID })
        selectedSubcategories = Set(budget.subcategories.map { $0.persistentModelID })
        selectedTags = Set(budget.tags.map { $0.persistentModelID })

        // Parse natures string
        if let naturesString = budget.natures {
            let natureStrings = naturesString.components(separatedBy: ",")
            selectedNatures = Set(natureStrings.compactMap { SubcategoryNature(rawValue: $0) })
        }
    }

    private func saveBudget() {
        guard let amount = Double(limitAmount) else { return }

        // Convert PersistentIdentifiers back to model objects
        let accountsArray = activeAccounts.filter { selectedAccounts.contains($0.persistentModelID) }
        let subcategoriesArray = allSubcategories.filter { selectedSubcategories.contains($0.persistentModelID) }
        let tagsArray = activeTags.filter { selectedTags.contains($0.persistentModelID) }
        let naturesString = selectedNatures.isEmpty ? nil : selectedNatures.map { $0.rawValue }.joined(separator: ",")

        if let existingBudget = budget {
            // Update existing budget
            existingBudget.name = name
            existingBudget.limitAmount = amount
            existingBudget.currencyCode = currencyCode
            existingBudget.periodType = selectedPeriodType.rawValue
            existingBudget.isActive = isActive
            existingBudget.startDate = selectedPeriodType == .unique ? startDate : nil
            existingBudget.endDate = selectedPeriodType == .unique ? endDate : nil
            existingBudget.accounts = accountsArray
            existingBudget.subcategories = subcategoriesArray
            existingBudget.tags = tagsArray
            existingBudget.natures = naturesString
        } else {
            // Create new budget
            let newBudget = Budget(
                currencyCode: currencyCode,
                limitAmount: amount,
                name: name,
                periodType: selectedPeriodType.rawValue,
                startDate: selectedPeriodType == .unique ? startDate : nil,
                endDate: selectedPeriodType == .unique ? endDate : nil,
                accounts: accountsArray,
                subcategories: subcategoriesArray,
                tags: tagsArray,
                natures: naturesString,
                isActive: isActive
            )

            modelContext.insert(newBudget)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            showSaveError = true
        }
    }

    private func deleteBudget() {
        guard let budget = budget else { return }
        deletionService.setContext(modelContext)
        do {
            try deletionService.deleteBudget(budget)
            // Trigger widget refresh
            sessionState.needsBudgetsWidgetRefresh = true
            dismiss()
        } catch {
            showSaveError = true
        }
    }
}
