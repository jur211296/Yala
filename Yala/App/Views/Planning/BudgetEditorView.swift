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
    @ScaledMetric(relativeTo: .largeTitle) private var scaledAmountSize: CGFloat = 28
    @Environment(SessionState.self) private var sessionState
    @Environment(EntityDeletionService.self) private var deletionService

    @State private var viewModel = BudgetEditorViewModel()

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.pen.rawValue
    @AppStorage("budgetAlertsEnabled") private var budgetAlertsGloballyEnabled: Bool = false

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

    // Alert notifications
    @State private var alertEnabled: Bool = false
    @State private var selectedThresholds: Set<Int> = []

    // Filters - Using PersistentIdentifier for consistency with RecordsFiltersView
    @State private var selectedAccounts: Set<PersistentIdentifier> = []
    @State private var selectedSubcategories: Set<PersistentIdentifier> = []
    @State private var selectedTags: Set<PersistentIdentifier> = []
    @State private var selectedNatures: Set<SubcategoryNature> = []

    // Sheet states
    @State private var showCategoriesSheet = false
    @State private var showDeleteConfirmation = false

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

                    // Alert Notifications Section
                    alertsSection

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
                    YalaToolbarButton(systemName: "xmark", label: "Cerrar") {
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
                viewModel.setContext(modelContext, deletionService: deletionService)
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
                isPresented: Binding(
                    get: { viewModel.showSaveError },
                    set: { _ in viewModel.dismissSaveError() }
                ),
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
            VStack(spacing: DS.Spacing.none) {
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
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $limitAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: scaledAmountSize, weight: .bold))
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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
            VStack(spacing: DS.Spacing.none) {
                // Start Date
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "calendar")
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    Text(NSLocalizedString("budgets.editor.start.date", comment: ""))
                        .font(DS.Typography.body)
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
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    Text(NSLocalizedString("budgets.editor.end.date", comment: ""))
                        .font(DS.Typography.body)
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
                .font(DS.Typography.body)
        }
        .tint(Color.brandPrimary)
    }

    // MARK: - Alerts Section

    private var alertsSection: some View {
        SectionBox(title: L10n.Budgets.alertsTitle) {
            VStack(spacing: DS.Spacing.none) {
                // Toggle
                Toggle(isOn: $alertEnabled) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundStyle(.secondary)
                        Text(L10n.Budgets.alertsEnable)
                    }
                }
                .tint(Color.brandPrimary)
                .padding()

                // Hint when global notifications are disabled
                if !budgetAlertsGloballyEnabled {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "info.circle")
                            .font(DS.Typography.caption)
                        Text(L10n.Budgets.alertsGlobalDisabledHint)
                            .font(DS.Typography.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.md)
                }

                if alertEnabled {
                    SubsectionDivider()

                    // Threshold chips
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(L10n.Budgets.alertsThresholds)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.top, DS.Spacing.sm)

                        FlowLayout(spacing: DS.Spacing.sm) {
                            ForEach([50, 75, 90, 100], id: \.self) { threshold in
                                thresholdChip(threshold)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.bottom, DS.Spacing.md)
                    }
                }
            }
        }
    }

    private func thresholdChip(_ threshold: Int) -> some View {
        let isSelected = selectedThresholds.contains(threshold)

        return Button {
            if isSelected {
                selectedThresholds.remove(threshold)
            } else {
                selectedThresholds.insert(threshold)
            }
        } label: {
            Text("\(threshold)%")
                .font(DS.Typography.subheadline)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.brandPrimary : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filters Section

    private var filtersSection: some View {
        SectionBox(title: NSLocalizedString("budgets.editor.filters", comment: "")) {
            VStack(spacing: DS.Spacing.none) {
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
            items: viewModel.activeAccounts,
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
        if selectedAccounts.isEmpty {
            return NSLocalizedString("filters.all", comment: "")
        }
        if selectedAccounts.count == viewModel.activeAccounts.count {
            return NSLocalizedString("filters.all", comment: "")
        }
        return "\(selectedAccounts.count)/\(viewModel.activeAccounts.count)"
    }

    // MARK: - Categories Content

    private var categoriesContent: some View {
        Button {
            showCategoriesSheet = true
        } label: {
            HStack(spacing: DS.Spacing.none) {
                FilterSectionHeader(
                    icon: "tag",
                    title: NSLocalizedString("subcategories.title", comment: ""),
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

    private var selectedCategoriesText: String {
        viewModel.selectedCategoriesText(selectedSubcategories: selectedSubcategories)
    }

    // MARK: - Tags Content

    private var tagsContent: some View {
        FilterChipsSection(
            icon: "number",
            title: NSLocalizedString("settings.tags", comment: ""),
            status: selectedTagsText,
            items: viewModel.activeTags,
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
                    .font(DS.Typography.subheadline)
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
        if selectedTags.count == viewModel.activeTags.count {
            return NSLocalizedString("filters.all", comment: "")
        }
        return "\(selectedTags.count)/\(viewModel.activeTags.count)"
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
                    .font(DS.Typography.subheadline)
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
                    .font(DS.Typography.bodyBold)
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
            categories: viewModel.categories,
            subcategories: viewModel.allSubcategories,
            selectedSubcategories: $selectedSubcategories
        )
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
           let account = viewModel.activeAccounts.first(where: { $0.persistentModelID == accountId }) {
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
        selectedAccounts = Set((budget.accounts ?? []).map { $0.persistentModelID })
        selectedSubcategories = Set((budget.subcategories ?? []).map { $0.persistentModelID })
        selectedTags = Set((budget.tags ?? []).map { $0.persistentModelID })

        // Parse natures string
        if let naturesString = budget.natures {
            let natureStrings = naturesString.components(separatedBy: ",")
            selectedNatures = Set(natureStrings.compactMap { SubcategoryNature(rawValue: $0) })
        }

        // Load alert settings
        alertEnabled = budget.alertEnabled
        if let thresholdsString = budget.alertThresholds {
            selectedThresholds = Set(
                thresholdsString.split(separator: ",").compactMap { Int($0) }
            )
        }
    }

    private func saveBudget() {
        guard let amount = Double(limitAmount) else { return }

        let saved = viewModel.saveBudget(
            existing: budget,
            name: name,
            limitAmount: amount,
            currencyCode: currencyCode,
            periodType: selectedPeriodType,
            startDate: startDate,
            endDate: endDate,
            isActive: isActive,
            selectedAccounts: selectedAccounts,
            selectedSubcategories: selectedSubcategories,
            selectedTags: selectedTags,
            selectedNatures: selectedNatures,
            alertEnabled: alertEnabled,
            alertThresholds: selectedThresholds
        )

        if saved {
            dismiss()
        }
    }

    private func deleteBudget() {
        guard let budget = budget else { return }

        if viewModel.deleteBudget(budget) {
            // Trigger widget refresh
            sessionState.needsBudgetsWidgetRefresh = true
            dismiss()
        }
    }
}
