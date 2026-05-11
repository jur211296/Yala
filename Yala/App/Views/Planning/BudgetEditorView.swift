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
    @Environment(\.yalaTheme) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var scaledAmountSize: CGFloat = 28 // A11Y-DT: @ScaledMetric
    @Environment(SessionState.self) private var sessionState
    @Environment(EntityDeletionService.self) private var deletionService

    @State private var viewModel = BudgetEditorViewModel()

    @Environment(AppPreferences.self) private var appPreferences

    let budget: Budget?
    let mode: ViewMode
    let onStartReal: (() -> Void)?

    // Demo state
    @State private var demoTask: Task<Void, Never>?
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        budget: Budget?,
        mode: ViewMode = .interactive,
        onStartReal: (() -> Void)? = nil
    ) {
        self.budget = budget
        self.mode = mode
        self.onStartReal = onStartReal
    }

    // Error state
    @State private var showSaveError = false

    // Basic Info
    @State private var name: String = ""
    @State private var limitAmount: String = ""
    @State private var currencyCode: String = ""

    // Period
    @State private var selectedPeriodType: BudgetPeriodType = .monthly
    @State private var startDate: Date = Date.now
    @State private var endDate: Date = Date.now

    // Active status
    @State private var isActive: Bool = true

    // Alert notifications
    @State private var alertEnabled: Bool = false
    @State private var selectedThresholds: Set<Int> = []

    // Filters - Using PersistentIdentifier for consistency with RecordsFiltersView
    @State private var selectedAccounts: Set<PersistentIdentifier> = []
    @State private var selectedSubcategories: Set<PersistentIdentifier> = []
    @State private var selectedTags: Set<PersistentIdentifier> = []
    @State private var selectedNeeds: Set<SubcategoryNeed> = []
    @State private var includeSharedExpenses: Bool = true

    // Sheet states
    @State private var showCategoriesSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showCustomThreshold = false
    @State private var customThresholdText: String = ""

    // Focus state
    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isAmountFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Contextual guide for new users creating first budget
                    if budget == nil {
                        ContextualGuideBanner.budgetEditor()
                    }

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

                    // Filters Section with always-visible info banner
                    budgetFilterBanner
                    filtersSection

                    // Shared expenses toggle
                    sharedExpensesToggle

                    // Delete Button (only for existing budgets)
                    if budget != nil {
                        deleteSection
                    }
                }
                .padding(.vertical, DS.Spacing.xxl)
                .dismissKeyboardOnTap()
            }
            .scrollViewGlassEdges()
            .scrollDismissesKeyboard(.interactively)
            .background(PanelBackgroundView())
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
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
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
                    Task {
                        try? await Task.sleep(for: .milliseconds(500))
                        isNameFieldFocused = true
                    }
                }
            }
            .onChange(of: selectedAccounts) { _, newAccounts in
                updateCurrencyFromAccounts(newAccounts)
            }
            .onChange(of: viewModel.showSaveError) { _, new in if new { showSaveError = true } }
            .alert(
                L10n.Common.error,
                isPresented: $showSaveError,
                actions: {
                    Button(L10n.Common.understood, role: .cancel) { viewModel.dismissSaveError() }
                },
                message: {
                    Text(L10n.Common.saveError)
                }
            )
            .disabled(mode.isDemo)
            .overlay(alignment: .top) {
                if mode.isDemo {
                    DemoBanner(onStartReal: { onStartReal?() })
                }
            }
            .task {
                if mode.isDemo { startDemoScript() }
            }
            .onDisappear {
                demoTask?.cancel()
                demoTask = nil
            }
        }
    }

    // MARK: - Demo Script

    @MainActor
    private func startDemoScript() {
        demoTask?.cancel()
        if voiceOverEnabled {
            applyFinalDemoState()
            return
        }
        demoTask = Task { @MainActor in
            let nameExample = L10n.SetupChecklist.Demo.budgetNameExample
            let useAnimations = !reduceMotion

            while !Task.isCancelled {
                resetDemoState(animated: false)
                try? await Task.sleep(for: .milliseconds(500))

                // typing name
                for (idx, _) in nameExample.enumerated() {
                    guard !Task.isCancelled else { return }
                    let endIdx = nameExample.index(nameExample.startIndex, offsetBy: idx + 1)
                    name = String(nameExample[..<endIdx])
                    try? await Task.sleep(for: .milliseconds(useAnimations ? 90 : 0))
                }
                try? await Task.sleep(for: .milliseconds(400))

                // monto 500
                if useAnimations {
                    withAnimation(.smooth(duration: 0.3)) { limitAmount = "500" }
                } else {
                    limitAmount = "500"
                }
                try? await Task.sleep(for: .milliseconds(600))

                // period cycling: weekly → monthly → yearly → monthly final
                let periods: [BudgetPeriodType] = [.weekly, .monthly, .yearly, .monthly]
                for period in periods {
                    guard !Task.isCancelled else { return }
                    if useAnimations {
                        withAnimation(.smooth(duration: 0.3)) { selectedPeriodType = period }
                    } else {
                        selectedPeriodType = period
                    }
                    try? await Task.sleep(for: .milliseconds(500))
                }

                // alerts highlight
                if useAnimations {
                    withAnimation(.smooth(duration: 0.3)) {
                        alertEnabled = true
                        selectedThresholds = [80]
                    }
                } else {
                    alertEnabled = true
                    selectedThresholds = [80]
                }
                try? await Task.sleep(for: .milliseconds(1500))

                // hold + fade
                try? await Task.sleep(for: .milliseconds(1500))
                guard !Task.isCancelled else { return }
            }
        }
    }

    @MainActor
    private func applyFinalDemoState() {
        name = L10n.SetupChecklist.Demo.budgetNameExample
        limitAmount = "500"
        selectedPeriodType = .monthly
        alertEnabled = true
        selectedThresholds = [80]
    }

    @MainActor
    private func resetDemoState(animated: Bool) {
        if animated {
            withAnimation(.smooth(duration: 0.3)) {
                name = ""
                limitAmount = ""
                selectedPeriodType = .monthly
                alertEnabled = false
                selectedThresholds = []
            }
        } else {
            name = ""
            limitAmount = ""
            selectedPeriodType = .monthly
            alertEnabled = false
            selectedThresholds = []
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
                        .accessibilityHidden(true)
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
                            .focused($isAmountFieldFocused)
                            .onChange(of: isAmountFieldFocused) { _, isFocused in
                                if isFocused && (limitAmount == "0" || limitAmount == "0.00" || limitAmount == "0,00") {
                                    limitAmount = ""
                                }
                                if !isFocused && !limitAmount.isEmpty {
                                    let amount = AmountInputHelper.parseDecimal(limitAmount)
                                    limitAmount = AmountInputHelper.formatWithGrouping(amount)
                                }
                            }
                            .onChange(of: limitAmount) { _, newValue in
                                let filtered = AmountInputHelper.filterAmountInput(newValue)
                                if filtered != newValue {
                                    limitAmount = filtered
                                }
                            }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Period Section

    private var periodSection: some View {
        SectionBox(title: NSLocalizedString("budgets.editor.period.type", comment: "")) {
            Picker(NSLocalizedString("budgets.editor.period.type", comment: ""), selection: $selectedPeriodType) {
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
                        .accessibilityHidden(true)

                    Text(NSLocalizedString("budgets.editor.start.date", comment: ""))
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    DateFieldButton(
                        date: $startDate,
                        title: NSLocalizedString("budgets.editor.start.date", comment: "")
                    )
                }
                .padding()

                SubsectionDivider()

                // End Date
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "calendar")
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                        .accessibilityHidden(true)

                    Text(NSLocalizedString("budgets.editor.end.date", comment: ""))
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    DateFieldButton(
                        date: $endDate,
                        minDate: startDate,
                        title: NSLocalizedString("budgets.editor.end.date", comment: "")
                    )
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

    }

    // MARK: - Shared Expenses Toggle

    private var sharedExpensesToggle: some View {
        Toggle(isOn: $includeSharedExpenses) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Budgets.includeSharedExpenses)
                    .font(DS.Typography.body)
                Text(L10n.Budgets.includeSharedExpensesHint)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }
        }
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
                            .accessibilityHidden(true)
                        Text(L10n.Budgets.alertsEnable)
                    }
                }

                .padding()

                // Hint when global notifications are disabled
                if !appPreferences.budgetAlertsEnabled {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "info.circle")
                            .font(DS.Typography.caption)
                            .accessibilityHidden(true)
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
                            ForEach(allThresholds, id: \.self) { threshold in
                                thresholdChip(threshold)
                            }

                            // Custom threshold toggle
                            Button {
                                showCustomThreshold.toggle()
                                if !showCustomThreshold {
                                    customThresholdText = ""
                                }
                            } label: {
                                HStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: "plus")
                                        .font(DS.Typography.captionSmall)
                                    Text(NSLocalizedString("budgets.alerts.custom", comment: ""))
                                        .font(DS.Typography.subheadline)
                                }
                                .foregroundStyle(showCustomThreshold ? .white : .primary)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.sm)
                                .background(
                                    Capsule()
                                        .fill(showCustomThreshold ? theme.accent : Color.clear)
                                )
                                .glassEffect(showCustomThreshold ? .clear : .regular.interactive(), in: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, DS.Spacing.lg)

                        // Custom threshold input
                        if showCustomThreshold {
                            HStack(spacing: DS.Spacing.sm) {
                                TextField("1–100", text: $customThresholdText)
                                    .keyboardType(.numberPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)

                                Text("%")
                                    .font(DS.Typography.subheadline)
                                    .foregroundStyle(.secondary)

                                Button {
                                    if let value = Int(customThresholdText),
                                       value >= 1, value <= 100 {
                                        selectedThresholds.insert(value)
                                        customThresholdText = ""
                                        showCustomThreshold = false
                                    }
                                } label: {
                                    Text(NSLocalizedString("budgets.alerts.addThreshold", comment: ""))
                                        .font(DS.Typography.subheadline)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, DS.Spacing.md)
                                        .padding(.vertical, DS.Spacing.sm)
                                        .background(
                                            Capsule()
                                                .fill(theme.accent)
                                        )
                                }
                                .buttonStyle(.plain)
                                .disabled(!isValidCustomThreshold)
                                .accessibilityHint(!isValidCustomThreshold ? L10n.Accessibility.invalidThreshold : "")
                            }
                            .padding(.horizontal, DS.Spacing.lg)
                        }
                    }
                    .padding(.bottom, DS.Spacing.md)
                }
            }
        }
    }

    private var allThresholds: [Int] {
        Set([50, 75, 90, 100]).union(selectedThresholds).sorted()
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
                        .fill(isSelected ? theme.accent : Color.clear)
                )
                .glassEffect(isSelected ? .clear : .regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filters Section

    private var budgetFilterBanner: some View {
        let summary = viewModel.filterSummaryText(
            selectedAccounts: selectedAccounts,
            selectedSubcategories: selectedSubcategories,
            selectedTags: selectedTags,
            selectedNeeds: selectedNeeds
        )
        return ContextualGuideBanner.budgetFilterInfo(
            message: summary ?? L10n.ContextualGuide.BudgetFilter.allExpenses
        )
    }

    private var filtersSection: some View {
        SectionBox(title: NSLocalizedString("budgets.editor.filters", comment: "")) {
            VStack(spacing: DS.Spacing.none) {
                accountsContent
                Divider().padding(.leading, DS.Spacing.lg)
                categoriesContent
                Divider().padding(.leading, DS.Spacing.lg)
                tagsContent
                Divider().padding(.leading, DS.Spacing.lg)
                needsContent
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
                    .fill(isSelected ? theme.accent : Color(.tertiarySystemFill))
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

    private var needsContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            FilterSectionHeader(
                icon: "chart.bar.fill",
                title: NSLocalizedString("need.title", comment: ""),
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
            .padding(.leading, DS.Spacing.formIndent)
            .padding(.trailing, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
        }
    }

    private func needChip(_ need: SubcategoryNeed) -> some View {
        let isSelected = selectedNeeds.contains(need)

        return Button {
            if isSelected {
                selectedNeeds.remove(need)
            } else {
                selectedNeeds.insert(need)
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
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
        if selectedNeeds.isEmpty {
            return NSLocalizedString("filters.all", comment: "")
        }
        return "\(selectedNeeds.count)"
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
                    .fill(DS.Semantic.errorBackgroundSubtle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(DS.Semantic.errorBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(DS.Semantic.errorForeground)
        .padding(.top, DS.Spacing.lg)
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
        let parsedAmount = AmountInputHelper.parseDecimal(limitAmount)
        guard !name.isEmpty, !limitAmount.isEmpty, parsedAmount > 0 else {
            return false
        }
        // For unique budgets, validate date range
        if selectedPeriodType == .unique && startDate >= endDate {
            return false
        }
        return true
    }

    private var isValidCustomThreshold: Bool {
        guard let value = Int(customThresholdText) else { return false }
        return value >= 1 && value <= 100
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
            currencyCode = appPreferences.defaultCurrencyCode.rawValue
        }
    }

    private func loadBudgetData() {
        // Initialize currency code
        currencyCode = appPreferences.defaultCurrencyCode.rawValue

        guard let budget = budget else { return }

        name = budget.name
        currencyCode = budget.currencyCode
        limitAmount = AmountInputHelper.formatWithGrouping(budget.limitAmount)
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
            let needStrings = naturesString.components(separatedBy: ",")
            selectedNeeds = Set(needStrings.compactMap { SubcategoryNeed(rawValue: $0) })
        }

        // Load shared expenses setting
        includeSharedExpenses = budget.includeSharedExpenses

        // Load alert settings
        alertEnabled = budget.alertEnabled
        if let thresholdsString = budget.alertThresholds {
            selectedThresholds = Set(
                thresholdsString.split(separator: ",").compactMap { Int($0) }
            )
        }
    }

    private func saveBudget() {
        guard mode == .interactive else { return }
        let amount = AmountInputHelper.parseDecimal(limitAmount)
        guard amount > 0 else { return }

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
            selectedNeeds: selectedNeeds,
            alertEnabled: alertEnabled,
            alertThresholds: selectedThresholds,
            includeSharedExpenses: includeSharedExpenses
        )

        if let savedID = saved {
            sessionState.needsBudgetsWidgetRefresh = true
            if budget == nil, SetupChecklistManager.shared.stepCompleted[.firstBudget] != true {
                SetupChecklistManager.shared.markCompleted(
                    .firstBudget,
                    practiceItem: PracticeCleanupItem(
                        stepID: .firstBudget,
                        itemName: name,
                        persistentID: savedID
                    )
                )
            } else {
                SetupChecklistManager.shared.markCompleted(.firstBudget)
            }
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
