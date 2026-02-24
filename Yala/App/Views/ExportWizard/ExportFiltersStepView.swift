//
//  ExportFiltersStepView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI

struct ExportFiltersStepView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme

    @State private var viewModel = ExportFiltersStepViewModel()

    // MARK: - Local State

    // Cuentas
    @State private var selectedAccounts: Set<PersistentIdentifier> = []
    @State private var hasInitializedAccounts = false

    // Categorías y Subcategorías
    @State private var selectedSubcategories: Set<PersistentIdentifier> = []

    // Etiquetas
    @State private var selectedTags: Set<PersistentIdentifier> = []

    // Naturaleza
    @State private var selectedNatures: Set<SubcategoryNature> = Set(SubcategoryNature.allCases)

    // Moneda
    @State private var selectedCurrencies: Set<CurrencyCode> = Set(CurrencyCode.allCases)

    // Monto
    @State private var amountCondition: AmountFilterCondition = .any

    // Periodo
    @State private var selectedPeriod: DetailPeriod = .last30Days
    @State private var customDateRange: DateInterval?

    // Nota
    @State private var noteContains: String = ""

    // Modo incluir/excluir
    @State private var isExcludeMode: Bool = false

    // MARK: - Sheet Presentation State
    @State private var showCategoriesSheet = false
    @State private var showPeriodPicker = false

    // MARK: - Computed Properties

    private var isAccountSelectionValid: Bool {
        !selectedAccounts.isEmpty
    }

    private var isValid: Bool {
        if !isAccountSelectionValid {
            return false
        }

        // Validar rango de montos
        if case .between(let min, let max) = amountCondition {
            return min <= max
        }

        return true
    }

    private var exportFilters: ExportFilters {
        viewModel.buildExportFilters(
            selectedAccounts: selectedAccounts,
            selectedSubcategories: selectedSubcategories,
            selectedTags: selectedTags,
            selectedCurrencies: selectedCurrencies,
            amountCondition: amountCondition,
            selectedPeriod: selectedPeriod,
            customDateRange: customDateRange,
            noteContains: noteContains,
            isExcludeMode: isExcludeMode
        )
    }

    // MARK: - Body

    var body: some View {
        mainContent
            .onAppear {
                viewModel.setContext(modelContext)
            }
            .sheet(isPresented: $showCategoriesSheet) {
                categoriesSheetView
            }
            .sheet(isPresented: $showPeriodPicker) {
                ExportPeriodPickerSheet(
                    selectedPeriod: selectedPeriod,
                    customDateRange: $customDateRange,
                    onSelect: { period in
                        selectedPeriod = period
                        showPeriodPicker = false
                    }
                )
                .presentationDetents([.large])
            }
    }

    private var mainContent: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        Picker("", selection: $isExcludeMode) {
                            Text(L10n.Filters.includeMode).tag(false)
                            Text(L10n.Filters.excludeMode).tag(true)
                        }
                        .pickerStyle(.segmented)

                        SectionBox(title: L10n.Filters.filterOptions) {
                            VStack(spacing: DS.Spacing.none) {
                                periodRow
                                Divider().padding(.leading, DS.Spacing.lg)
                                accountsContent
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
                    }
                    .padding(.vertical, DS.Spacing.xxl)
                    .padding(.horizontal, DS.Spacing.lg)
                }
            }
            .navigationTitle(L10n.Export.exportData)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ExportColumnsStepView(
                            exportFilters: exportFilters,
                            onFinish: { dismiss() }
                        )
                    } label: {
                        Text(L10n.Common.next)
                    }
                    .disabled(!isValid)
                    .accessibilityHint(!isValid ? "Completa los filtros requeridos" : "")
                }
            }
        }
    }

    // MARK: - Sheets

    private var categoriesSheetView: some View {
        CategorySelectorSheet(
            categories: viewModel.allCategories,
            subcategories: viewModel.allSubcategories,
            selectedSubcategories: $selectedSubcategories
        )
        .onAppear {
            // Initialize with all selected if empty
            if selectedSubcategories.isEmpty {
                let visibleSubs = viewModel.allSubcategories.filter { $0.isVisible }
                selectedSubcategories = Set(visibleSubs.map { $0.persistentModelID })
            }
        }
    }

    // MARK: - Sections

    private var selectedAccountsText: String {
        viewModel.selectedAccountsText(selectedAccounts: selectedAccounts)
    }

    private func syncAccountsSelection() {
        if !hasInitializedAccounts && !viewModel.allAccounts.isEmpty {
            selectedAccounts = Set(viewModel.allAccounts.map { $0.persistentModelID })
            hasInitializedAccounts = true
        }
    }

    private var selectedCategoriesText: String {
        viewModel.selectedCategoriesText(selectedSubcategories: selectedSubcategories)
    }

    private var selectedTagsText: String {
        viewModel.selectedTagsText(selectedTags: selectedTags)
    }

    private func syncTagsSelection() {
        if selectedTags.isEmpty && !viewModel.allTags.isEmpty {
            selectedTags = Set(viewModel.allTags.map { $0.persistentModelID })
        }
    }

    private var selectedCurrenciesText: String {
        if selectedCurrencies.count == availableCurrencies.count {
            return L10n.Filters.allCurrencies
        }
        return selectedCurrencies.map { $0.rawValue }.joined(separator: ", ")
    }

    private var accountsContent: some View {
        FilterChipsSection(
            icon: "creditcard",
            title: L10n.Settings.accounts,
            status: selectedAccountsText,
            items: viewModel.allAccounts,
            showEmptyPlaceholder: false
        ) { account in
            accountChip(account)
        }
        .onAppear {
            syncAccountsSelection()
        }
        .onChange(of: selectedAccounts) { _, newAccountIDs in
            if newAccountIDs.isEmpty {
                selectedCurrencies = Set(CurrencyCode.allCases)
            } else {
                let selected = viewModel.allAccounts.filter { newAccountIDs.contains($0.persistentModelID) }
                let available = Set(
                    selected.map { CurrencyCode(rawValue: $0.currencyCode) ?? .pen })
                selectedCurrencies = available
            }
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

    private var categoriesContent: some View {
        Button {
            showCategoriesSheet = true
        } label: {
            HStack(spacing: DS.Spacing.none) {
                FilterSectionHeader(
                    icon: "tag",
                    title: L10n.Settings.categories,
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

    private func subcategories(for category: Category) -> [Subcategory] {
        viewModel.subcategories(for: category)
    }

    private var tagsContent: some View {
        FilterChipsSection(
            icon: "number",
            title: L10n.Settings.tags,
            status: selectedTagsText,
            items: viewModel.allTags,
            showEmptyPlaceholder: true
        ) { tag in
            tagChip(tag)
        }
        .onAppear {
            syncTagsSelection()
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

    private var currencyContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            FilterSectionHeader(
                icon: "arrow.triangle.2.circlepath",
                title: L10n.Settings.currency,
                status: selectedCurrenciesText
            )
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.md)

            // Chips
            FlowLayout(spacing: DS.Spacing.sm) {
                ForEach(availableCurrencies) { currency in
                    currencyChip(currency)
                }
            }
            .padding(.leading, DS.Spacing.formIndent)
            .padding(.trailing, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
        }
    }

    private func currencyChip(_ currency: CurrencyCode) -> some View {
        let isSelected = selectedCurrencies.contains(currency)

        return Button {
            if isSelected {
                selectedCurrencies.remove(currency)
            } else {
                selectedCurrencies.insert(currency)
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

    private var availableCurrencies: [CurrencyCode] {
        viewModel.availableCurrencies(selectedAccounts: selectedAccounts)
    }

    // MARK: - Natures Content

    private var naturesContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            FilterSectionHeader(
                icon: "leaf.fill",
                title: L10n.Nature.label,
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
            .padding(.leading, DS.Spacing.formIndent)
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
                    .fill(isSelected ? theme.accent : Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedNaturesText: String {
        if selectedNatures.isEmpty { return L10n.Filters.allNatures }
        return "\(selectedNatures.count)"
    }

    private var amountContent: some View {
        AmountFilterView(
            condition: $amountCondition,
            currencyCode: selectedCurrencies.count == 1 ? selectedCurrencies.first : nil
        )
    }

    // MARK: - Static Formatters

    private static let periodLongFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    private static let periodShortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yy"
        f.locale = AppLocale.current
        return f
    }()

    private var periodSubtitle: String {
        let interval = selectedPeriod.dateInterval()

        let calendar = Calendar.current
        let displayEnd = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end

        return "\(Self.periodLongFormatter.string(from: interval.start)) - \(Self.periodLongFormatter.string(from: displayEnd))"
    }

    // MARK: - Period Row (inside SectionBox)

    private var periodDisplayText: String {
        if selectedPeriod == .custom, let range = customDateRange {
            return "\(Self.periodShortFormatter.string(from: range.start)) - \(Self.periodShortFormatter.string(from: range.end))"
        }
        return selectedPeriod.displayName
    }

    private var periodRow: some View {
        Button {
            showPeriodPicker = true
        } label: {
            HStack {
                Image(systemName: "calendar")
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .frame(width: 24)

                Text(L10n.Export.period)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)

                Spacer()

                Text(periodDisplayText)
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var noteContent: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "note.text")
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
                .frame(width: 24)

            TextField(L10n.Filters.noteContains, text: $noteContains)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }
}

// MARK: - Period Picker Sheet

private struct ExportPeriodPickerSheet: View {
    let selectedPeriod: DetailPeriod
    @Binding var customDateRange: DateInterval?
    let onSelect: (DetailPeriod) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @State private var showCustomPicker = false

    /// Periods to show (exclude .custom, handled separately)
    private var standardPeriods: [DetailPeriod] {
        DetailPeriod.allCases.filter { $0 != .custom }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.none) {
                        // Standard periods
                        ForEach(standardPeriods) { period in
                            periodRow(for: period)
                            Divider().padding(.leading, DS.Spacing.lg)
                        }

                        // Custom period section
                        customPeriodRow
                    }
                    .background(.thCard)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.lg)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                    .padding()
                }
            }
            .navigationTitle(L10n.Export.period)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCustomPicker) {
                ExportCustomPeriodPickerSheet(
                    customDateRange: $customDateRange,
                    onApply: {
                        onSelect(.custom)
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func periodRow(for period: DetailPeriod) -> some View {
        let isSelected = selectedPeriod == period

        Button {
            onSelect(period)
        } label: {
            HStack {
                Text(period.displayName)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.accent)
                        .font(DS.Typography.headline)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var customPeriodRow: some View {
        Button {
            showCustomPicker = true
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.Period.custom)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thPrimaryText)

                    if let range = customDateRange {
                        Text(formattedRange(range))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if selectedPeriod == .custom {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.accent)
                        .font(DS.Typography.headline)
                }

                Image(systemName: "chevron.right")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static let periodShortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yy"
        f.locale = AppLocale.current
        return f
    }()

    private func formattedRange(_ range: DateInterval) -> String {
        "\(Self.periodShortFormatter.string(from: range.start)) - \(Self.periodShortFormatter.string(from: range.end))"
    }
}

// MARK: - Custom Period Picker Sheet

private struct ExportCustomPeriodPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Binding var customDateRange: DateInterval?
    let onApply: () -> Void

    @State private var startDate: Date
    @State private var endDate: Date

    init(customDateRange: Binding<DateInterval?>, onApply: @escaping () -> Void) {
        self._customDateRange = customDateRange
        self.onApply = onApply

        // Initialize with current range or default to last 30 days
        if let range = customDateRange.wrappedValue {
            _startDate = State(initialValue: range.start)
            _endDate = State(initialValue: range.end)
        } else {
            let now = Date()
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now
            _startDate = State(initialValue: thirtyDaysAgo)
            _endDate = State(initialValue: now)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker(
                        L10n.Period.startDate,
                        selection: $startDate,
                        in: ...endDate,
                        displayedComponents: .date
                    )
                    .listRowBackground(theme.card)

                    DatePicker(
                        L10n.Period.endDate,
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: .date
                    )
                    .listRowBackground(theme.card)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(.thCard)
            .navigationTitle(L10n.Period.custom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    YalaSaveButton {
                        applyRange()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func applyRange() {
        let calendar = Calendar.current
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        let range = DateInterval(start: calendar.startOfDay(for: startDate), end: endOfDay)

        customDateRange = range
        dismiss()
        onApply()
    }
}
