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

    // MARK: - Data Queries

    @Query(sort: \Account.name) private var allAccounts: [Account]
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(sort: \Subcategory.sortOrder) private var allSubcategories: [Subcategory]

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

    // Nota
    @State private var noteContains: String = ""

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
        // Resolve subcategory objects from PersistentIdentifiers
        let selectedSubcategoryObjects = allSubcategories.filter {
            selectedSubcategories.contains($0.persistentModelID)
        }

        // Derive categories from the selected subcategories
        let finalCategories = Set(selectedSubcategoryObjects.compactMap { $0.category })

        let selectedTagObjects = allTags.filter { selectedTags.contains($0.persistentModelID) }

        let selectedTagNames: [String]
        if !allTags.isEmpty && selectedTagObjects.count == allTags.count {
            // Interpretar "todas seleccionadas" como "sin filtro por etiquetas"
            selectedTagNames = []
        } else {
            selectedTagNames = selectedTagObjects.map { $0.name }
        }

        // Convert DetailPeriod to date interval
        let dateInterval = selectedPeriod.dateInterval()

        return ExportFilters(
            selectedAccounts: allAccounts.filter {
                selectedAccounts.contains($0.persistentModelID)
            },
            selectedCategories: Array(finalCategories),
            selectedSubcategories: selectedSubcategoryObjects,
            selectedTagNames: selectedTagNames,
            selectedCurrencies: Array(selectedCurrencies),
            amountCondition: amountCondition,
            dateFrom: dateInterval.start,
            dateTo: dateInterval.end,
            noteContains: noteContains.isEmpty ? nil : noteContains
        )
    }

    // MARK: - Body

    var body: some View {
        mainContent
            .sheet(isPresented: $showCategoriesSheet) {
                categoriesSheetView
            }
            .sheet(isPresented: $showPeriodPicker) {
                ExportPeriodPickerSheet(
                    selectedPeriod: selectedPeriod,
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
                        SectionBox(title: L10n.Filters.filterOptions) {
                            VStack(spacing: 0) {
                                periodRow
                                Divider().padding(.leading, 16)
                                accountsContent
                                Divider().padding(.leading, 16)
                                categoriesContent
                                Divider().padding(.leading, 16)
                                tagsContent
                                Divider().padding(.leading, 16)
                                naturesContent
                                Divider().padding(.leading, 16)
                                currencyContent
                                Divider().padding(.leading, 16)
                                amountContent
                                Divider().padding(.leading, 16)
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
                    YalaToolbarButton(systemName: "xmark") {
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
                }
            }
        }
    }

    // MARK: - Sheets

    private var categoriesSheetView: some View {
        CategorySelectorSheet(
            categories: allCategories,
            subcategories: allSubcategories,
            selectedSubcategories: $selectedSubcategories
        )
        .onAppear {
            // Initialize with all selected if empty
            if selectedSubcategories.isEmpty {
                let visibleSubs = allSubcategories.filter { $0.isVisible }
                selectedSubcategories = Set(visibleSubs.map { $0.persistentModelID })
            }
        }
    }

    // MARK: - Sections

    private var selectedAccountsText: String {
        if selectedAccounts.isEmpty {
            return L10n.Filters.noneSelected
        }
        if selectedAccounts.count == allAccounts.count {
            return L10n.Filters.allAccounts
        }
        return L10n.Filters.selectedCount(selectedAccounts.count)
    }

    private func syncAccountsSelection() {
        if !hasInitializedAccounts && !allAccounts.isEmpty {
            selectedAccounts = Set(allAccounts.map { $0.persistentModelID })
            hasInitializedAccounts = true
        }
    }

    private var selectedCategoriesText: String {
        let visibleSubs = allSubcategories.filter { $0.isVisible }

        // Empty = all selected
        if selectedSubcategories.isEmpty {
            return L10n.Filters.allCategories
        }

        // All visible subcategories selected
        if selectedSubcategories.count == visibleSubs.count {
            return L10n.Filters.allCategories
        }

        // Partial selection
        return L10n.Filters.subcategoriesSelectedCount(selectedSubcategories.count)
    }

    private var selectedTagsText: String {
        if allTags.isEmpty {
            return L10n.Filters.noTags
        }
        if selectedTags.isEmpty || selectedTags.count == allTags.count {
            return L10n.Filters.allTags
        }
        return L10n.Filters.selectedCount(selectedTags.count)
    }

    private func syncTagsSelection() {
        if selectedTags.isEmpty && !allTags.isEmpty {
            selectedTags = Set(allTags.map { $0.persistentModelID })
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
            items: allAccounts,
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
                let selected = allAccounts.filter { newAccountIDs.contains($0.persistentModelID) }
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

    private var categoriesContent: some View {
        Button {
            showCategoriesSheet = true
        } label: {
            HStack(spacing: 0) {
                FilterSectionHeader(
                    icon: "tag",
                    title: L10n.Settings.categories,
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

    private func subcategories(for category: Category) -> [Subcategory] {
        allSubcategories.filter { sub in
            sub.category == category && sub.isVisible
        }
    }

    private var tagsContent: some View {
        FilterChipsSection(
            icon: "number",
            title: L10n.Settings.tags,
            status: selectedTagsText,
            items: allTags,
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
            .padding(.leading, 52)
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

    private var availableCurrencies: [CurrencyCode] {
        if selectedAccounts.isEmpty {
            return CurrencyCode.allCases
        }
        let selected = allAccounts.filter { selectedAccounts.contains($0.persistentModelID) }
        let accountCurrencies = Set(
            selected.map { CurrencyCode(rawValue: $0.currencyCode) ?? .pen })
        return CurrencyCode.allCases.filter { accountCurrencies.contains($0) }
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
        if selectedNatures.isEmpty { return L10n.Filters.allNatures }
        return "\(selectedNatures.count)"
    }

    private var amountContent: some View {
        AmountFilterView(
            condition: $amountCondition,
            currencyCode: selectedCurrencies.count == 1 ? selectedCurrencies.first : nil
        )
    }

    private var periodSubtitle: String {
        let interval = selectedPeriod.dateInterval()

        let calendar = Calendar.current
        let displayEnd = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM yyyy"

        return "\(formatter.string(from: interval.start)) - \(formatter.string(from: displayEnd))"
    }

    // MARK: - Period Row (inside SectionBox)

    private var periodRow: some View {
        Button {
            showPeriodPicker = true
        } label: {
            HStack {
                Image(systemName: "calendar")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(width: 24)

                Text(L10n.Export.period)
                    .font(.body)
                    .foregroundStyle(Color.yalaPrimaryText)

                Spacer()

                Text(selectedPeriod.displayName)
                    .font(.body)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
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
                .font(.body)
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
    let onSelect: (DetailPeriod) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(DetailPeriod.allCases) { period in
                            periodRow(for: period)
                        }
                    }
                    .background(Color.yalaCard)
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
                    YalaToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }
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
                    .font(.body)
                    .foregroundStyle(Color.yalaPrimaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.brandPrimary)
                        .font(.body.weight(.semibold))
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if period != DetailPeriod.allCases.last {
            Divider()
                .padding(.leading, 16)
        }
    }
}
