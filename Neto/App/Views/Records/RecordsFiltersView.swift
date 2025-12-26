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

    // MARK: - Categories State

    @State private var expandedCategories: Set<Category> = []

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
                    VStack(spacing: 24) {
                        dateSection

                        SectionBox(title: "Opciones de filtrado") {
                            VStack(spacing: 0) {
                                accountsContent
                                Divider().padding(.leading, 16)
                                categoriesContent
                                Divider().padding(.leading, 16)
                                tagsContent
                                Divider().padding(.leading, 16)
                                currencyContent
                                Divider().padding(.leading, 16)
                                amountContent
                                Divider().padding(.leading, 16)
                                noteContent
                            }
                        }
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SheetTopButton(systemName: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Aplicar") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Date Section

    @State private var selectedPeriodCategory: PeriodCategory = .current

    private var dateSection: some View {
        SectionBox(title: "Seleccione el período") {
            VStack(alignment: .leading, spacing: 16) {
                // Category Picker: Dropdown menu style
                Menu {
                    ForEach(PeriodCategory.allCases) { category in
                        Button(category.displayName) {
                            selectedPeriodCategory = category
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedPeriodCategory.displayName)
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.horizontal, 16)

                // Show options based on selected category
                switch selectedPeriodCategory {
                case .current:
                    currentPeriodPicker
                case .rolling:
                    rollingPeriodPicker
                case .custom:
                    customDatePickers
                }
            }
            .padding(.bottom, 12)
        }
        .onChange(of: selectedPeriodCategory) { _, newCategory in
            // When changing category, set a default period for that category
            switch newCategory {
            case .current:
                if viewModel.period.category != .current {
                    viewModel.period = .thisMonth
                }
            case .rolling:
                if viewModel.period.category != .rolling {
                    viewModel.period = .last30Days
                }
            case .custom:
                viewModel.period = .custom
            }
        }
        .onAppear {
            // Sync category from viewModel.period
            selectedPeriodCategory = viewModel.period.category
        }
    }

    private var currentPeriodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Segmented control for current periods
            Picker("Periodo", selection: $viewModel.period) {
                ForEach(RecordsPeriod.currentPeriods) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            // Show date range subtitle
            if let subtitle = periodSubtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }
        }
    }

    private var rollingPeriodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Segmented control for rolling periods
            Picker("Periodo", selection: $viewModel.period) {
                ForEach(RecordsPeriod.rollingPeriods) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            // Show date range subtitle
            if let subtitle = periodSubtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            }
        }
    }

    private var customDatePickers: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Desde")
                    .foregroundStyle(.secondary)
                Spacer()
                DatePicker("", selection: $viewModel.customStartDate, displayedComponents: .date)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)

            HStack {
                Text("Hasta")
                    .foregroundStyle(.secondary)
                Spacer()
                DatePicker("", selection: $viewModel.customEndDate, displayedComponents: .date)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
        }
    }

    private var periodSubtitle: String? {
        guard viewModel.period != .custom else { return nil }
        guard let interval = viewModel.period.dateInterval() else { return nil }

        let calendar = Calendar.current
        let displayEnd = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d MMM yyyy"

        return "\(formatter.string(from: interval.start)) - \(formatter.string(from: displayEnd))"
    }

    // MARK: - Filter Content Rows

    private var accountsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with icon
            HStack(spacing: 12) {
                Image(systemName: "creditcard")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(width: 24)

                Text("Cuentas")
                    .font(.body)
                    .foregroundStyle(.primary)

                Text("(\(selectedAccountsText))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Chips - aligned after icon (16 padding + 24 icon + 12 spacing = 52)
            FlowLayout(spacing: 8) {
                ForEach(activeAccounts) { account in
                    accountChip(account)
                }
            }
            .padding(.leading, 52)
            .padding(.trailing, 16)
            .padding(.bottom, 12)
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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
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
            return "Sin filtro"
        }
        if viewModel.selectedAccounts.count == activeAccounts.count {
            return "Todas"
        }
        return "\(viewModel.selectedAccounts.count)/\(activeAccounts.count)"
    }

    private var categoriesContent: some View {
        FilterSelectionRow(
            title: "Categorías",
            subtitle: selectedCategoriesText,
            icon: "tag"
        )
        .onTapGesture {
            showCategoriesSheet = true
        }
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
            return "Sin filtro"
        }

        // Count unique categories from selected subcategories
        let selectedSubs = allSubcategories.filter {
            viewModel.selectedSubcategories.contains($0.persistentModelID)
        }
        let uniqueCategories = Set(selectedSubs.compactMap { $0.category })
        let catCount = uniqueCategories.count

        return "\(catCount) categorías, \(subCount) subcategorías"
    }

    private var tagsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with icon
            HStack(spacing: 12) {
                Image(systemName: "number")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(width: 24)

                Text("Etiquetas")
                    .font(.body)
                    .foregroundStyle(.primary)

                Text("(\(selectedTagsText))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Chips - aligned after icon
            if !activeTags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(activeTags) { tag in
                        tagChip(tag)
                    }
                }
                .padding(.leading, 52)
                .padding(.trailing, 16)
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            syncTagsSelection()
        }
        .opacity(allTags.isEmpty ? 0.5 : 1.0)
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
            HStack(spacing: 6) {
                Circle()
                    .fill(isSelected ? Color.white : Color(hex: tag.colorHex))
                    .frame(width: 8, height: 8)

                Text(tag.name)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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
        if allTags.isEmpty {
            return "Sin etiquetas"
        }
        if viewModel.selectedTags.isEmpty {
            return "Sin filtro"
        }
        if viewModel.selectedTags.count == activeTags.count {
            return "Todas"
        }
        return "\(viewModel.selectedTags.count)/\(activeTags.count)"
    }

    private var currencyContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with icon
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(width: 24)

                Text("Moneda")
                    .font(.body)
                    .foregroundStyle(.primary)

                Text("(\(selectedCurrenciesText))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Chips - aligned after icon
            FlowLayout(spacing: 8) {
                ForEach(CurrencyCode.allCases) { currency in
                    currencyChip(currency)
                }
            }
            .padding(.leading, 52)
            .padding(.trailing, 16)
            .padding(.bottom, 12)
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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
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
            return "Sin filtro"
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
        HStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: 24)

            TextField("Nota contiene...", text: $viewModel.searchText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
            .navigationTitle("Seleccionar cuentas")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SheetTopButton(systemName: "chevron.left") {
                        showAccountsSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Categories Sheet

    private var categoriesSheetView: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: 24) {
                        SectionBox(title: "Seleccionar categorías") {
                            VStack(spacing: 0) {
                                // Select All / Deselect All button
                                Button {
                                    if isEverythingSelected {
                                        clearAllCategoriesAndSubcategories()
                                    } else {
                                        selectAllCategoriesAndSubcategories()
                                    }
                                } label: {
                                    HStack {
                                        Text(
                                            isEverythingSelected
                                                ? "Deseleccionar todo" : "Seleccionar todo"
                                        )
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)

                                        Spacer()

                                        Image(
                                            systemName: isEverythingSelected
                                                ? "checkmark.circle.fill"
                                                : "circle"
                                        )
                                        .foregroundStyle(
                                            isEverythingSelected
                                                ? Color.brandPrimary
                                                : Color.netoSecondaryText.opacity(0.4)
                                        )
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                }
                                .buttonStyle(.plain)

                                SubsectionDivider()

                                ForEach(Array(allCategories.enumerated()), id: \.element.id) {
                                    index, category in
                                    VStack(spacing: 0) {
                                        categoryHeaderRow(category)

                                        if expandedCategories.contains(category) {
                                            let subs = subcategories(for: category)
                                            ForEach(Array(subs.enumerated()), id: \.element.id) {
                                                _, subcategory in
                                                SubsectionDivider()
                                                subcategoryRow(subcategory, category: category)
                                            }
                                        }
                                    }

                                    if index < allCategories.count - 1 {
                                        SubsectionDivider()
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Seleccionar categorías")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SheetTopButton(systemName: "chevron.left") {
                        showCategoriesSheet = false
                    }
                }
            }
        }
    }

    private func categoryHeaderRow(_ category: Category) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(colorForHex(category.colorHex))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "tag")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text(subcategorySelectionSummary(for: category))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Category selection toggle
            Button {
                toggleCategory(category)
            } label: {
                let state = selectionState(for: category)
                Image(systemName: selectionIconName(for: state))
                    .foregroundStyle(
                        state == .none
                            ? Color.netoSecondaryText.opacity(0.4)
                            : Color.brandPrimary
                    )
            }
            .buttonStyle(.plain)

            // Expand/collapse button
            Button {
                if expandedCategories.contains(category) {
                    expandedCategories.remove(category)
                } else {
                    expandedCategories.insert(category)
                }
            } label: {
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(expandedCategories.contains(category) ? 0 : -90))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            if expandedCategories.contains(category) {
                expandedCategories.remove(category)
            } else {
                expandedCategories.insert(category)
            }
        }
    }

    private func subcategoryRow(_ subcategory: Subcategory, category: Category) -> some View {
        Button {
            if viewModel.selectedSubcategories.contains(subcategory.persistentModelID) {
                viewModel.selectedSubcategories.remove(subcategory.persistentModelID)
            } else {
                viewModel.selectedSubcategories.insert(subcategory.persistentModelID)
            }
        } label: {
            HStack(spacing: 12) {
                let subColor = colorForHex(subcategory.colorHex ?? category.colorHex)
                Circle()
                    .fill(subColor)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "tag")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    )

                Text(subcategory.name)
                    .foregroundStyle(.primary)
                    .font(.body)

                Spacer()

                let isSelected = viewModel.selectedSubcategories.contains(
                    subcategory.persistentModelID)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(
                        isSelected ? Color.brandPrimary : Color.netoSecondaryText.opacity(0.4)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .padding(.leading, 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            return "Sin subcategorías"
        }

        if selectedCount == 0 {
            return "Ninguna seleccionada"
        }

        if selectedCount == total {
            return "Todas las subcategorías"
        }

        return "\(selectedCount) de \(total) subcategorías"
    }

    // MARK: - Category Selection Helpers

    private enum CategorySelectionState {
        case none
        case partial
        case all
    }

    private var isEverythingSelected: Bool {
        let allVisibleSubs = allSubcategories.filter { $0.isVisible }
        return viewModel.selectedSubcategories.count == allVisibleSubs.count
            && !allVisibleSubs.isEmpty
    }

    private func selectAllCategoriesAndSubcategories() {
        let visibleSubs = allSubcategories.filter { $0.isVisible }
        viewModel.selectedSubcategories = Set(visibleSubs.map { $0.persistentModelID })
    }

    private func clearAllCategoriesAndSubcategories() {
        viewModel.selectedSubcategories.removeAll()
    }

    private func toggleCategory(_ category: Category) {
        let subs = subcategories(for: category)
        let selectedSubs = subs.filter {
            viewModel.selectedSubcategories.contains($0.persistentModelID)
        }

        if selectedSubs.count == subs.count {
            // All selected -> deselect all
            subs.forEach { viewModel.selectedSubcategories.remove($0.persistentModelID) }
        } else {
            // Some or none selected -> select all
            subs.forEach { viewModel.selectedSubcategories.insert($0.persistentModelID) }
        }
    }

    private func selectionState(for category: Category) -> CategorySelectionState {
        let subs = subcategories(for: category)
        if subs.isEmpty { return .none }

        let selectedCount = subs.filter {
            viewModel.selectedSubcategories.contains($0.persistentModelID)
        }.count

        if selectedCount == 0 {
            return .none
        } else if selectedCount == subs.count {
            return .all
        } else {
            return .partial
        }
    }

    private func selectionIconName(for state: CategorySelectionState) -> String {
        switch state {
        case .none: return "circle"
        case .partial: return "minus.circle.fill"
        case .all: return "checkmark.circle.fill"
        }
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
            .navigationTitle("Seleccionar etiquetas")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SheetTopButton(systemName: "chevron.left") {
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
                title: "Seleccionar monedas",
                items: CurrencyCode.allCases,
                selection: $viewModel.selectedCurrencies,
                label: { $0.rawValue }
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SheetTopButton(systemName: "chevron.left") {
                        showCurrencySheet = false
                    }
                }
            }
        }
    }
}
