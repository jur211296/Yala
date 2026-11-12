//
//  RecordsQuickFilterBar.swift
//  Yala
//
//  Revisión 2.3, decisión 15 (F2, 9-nov). Filtrar Registros por cuenta y categoría pedía 7 toques dentro de «···» y
//  «Aplicar». Encima de la lista, una fila fija: Cuenta ▾ · Categoría ▾ · Fecha ▾ · Más filtros. Cada chip se aplica al
//  tocar y dice lo elegido; la hoja completa queda en «Más filtros» para lo demás. Los filtros siguen siendo de la sesión:
//  escriben en `SessionState` como la hoja, y por eso los ven también el Panel y Estadísticas.
//

import SwiftData
import SwiftUI

struct RecordsQuickFilterBar: View {
    @Bindable var viewModel: RecordsViewModel
    let accounts: [Account]
    let categories: [Category]
    let subcategories: [Subcategory]
    let onCustomPeriod: () -> Void
    let onFilterChange: () -> Void

    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme
    @State private var showsCategoryPicker = false

    var body: some View {
        // Los cuatro caben en una fila de iPhone a tamaño normal; con texto grande (o un SE) pasan a dos, sin cortarse.
        FilterBandLayout(spacing: DS.Spacing.xs) {
            accountChip
            categoryChip
            dateChip
            moreChip
        }
        .sheet(isPresented: $showsCategoryPicker) {
            RecordsQuickCategorySheet(
                categories: categories,
                subcategories: subcategories,
                selectedCategories: viewModel.selectedCategories,
                selectedSubcategories: viewModel.selectedSubcategories,
                onChoose: chooseCategory
            )
        }
    }

    // MARK: - Cuenta ▾

    /// Las cuentas que se ofrecen: las de la hoja (sin archivadas, cada tarjeta una vez, sin sus líneas).
    private var offeredAccounts: [Account] {
        let roles = AccountLineLogic.resolve(accounts.map { AccountLineNode($0) })
        return accounts.filter { !$0.isArchived && !(roles[$0.shortcutID]?.isLine ?? false) }
    }

    private var shownAccountSelection: Set<PersistentIdentifier> {
        sessionState.shownAccountSelection(viewModel.selectedAccounts)
    }

    private var accountLabel: RecordsQuickChipLabel {
        let shown = shownAccountSelection
        return .accounts(selectedNames: accounts.filter { shown.contains($0.persistentModelID) }.map(\.name))
    }

    private var accountChip: some View {
        Menu {
            Button {
                chooseAccount(nil)
            } label: {
                selectableLabel(L10n.Filters.allAccounts, isSelected: viewModel.selectedAccounts.isEmpty)
            }
            Divider()
            ForEach(offeredAccounts, id: \.persistentModelID) { account in
                Button {
                    chooseAccount(account.persistentModelID)
                } label: {
                    selectableLabel(
                        account.name,
                        isSelected: shownAccountSelection == [account.persistentModelID]
                    )
                }
            }
        } label: {
            chipLabel(
                placeholder: L10n.RecordsQuickFilters23.account,
                label: accountLabel,
                many: L10n.RecordsQuickFilters23.accountsCount
            )
        }
        .accessibilityLabel(L10n.RecordsQuickFilters23.account)
        .accessibilityValue(accessibilityValue(accountLabel, many: L10n.RecordsQuickFilters23.accountsCount))
        .accessibilityIdentifier("records_quick_account")
    }

    /// Un toque, una cuenta: reemplaza lo que hubiera. Lo múltiple sigue en «Más filtros».
    private func chooseAccount(_ id: PersistentIdentifier?) {
        DS.Haptic.selection()
        viewModel.selectedAccounts = id.map { [$0] } ?? []
        onFilterChange()
    }

    // MARK: - Categoría ▾

    private var categoryLabel: RecordsQuickChipLabel {
        let wholeCategories = categories
            .filter { viewModel.selectedCategories.contains($0.persistentModelID) }
            .map(\.name)
        let entries = categories.map { category in
            CategoryFilterSummaryLogic.CategoryEntry(
                name: category.name,
                subcategories: subcategories
                    .filter { $0.category == category && $0.isVisible }
                    .map { (id: $0.persistentModelID, name: $0.name) }
            )
        }
        let fromSubcategories = CategoryFilterSummaryLogic.names(
            selected: viewModel.selectedSubcategories, categories: entries
        )
        return .categories(names: wholeCategories + fromSubcategories)
    }

    private var categoryChip: some View {
        Button {
            showsCategoryPicker = true
        } label: {
            chipLabel(placeholder: L10n.RecordsQuickFilters23.category, label: categoryLabel, many: { _ in "" })
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.RecordsQuickFilters23.category)
        .accessibilityValue(accessibilityValue(categoryLabel, many: { _ in "" }))
        .accessibilityIdentifier("records_quick_category")
    }

    /// Elegir en la hoja reemplaza la categoría: una categoría entera, una subcategoría o «Todas».
    private func chooseCategory(_ choice: RecordsQuickCategorySheet.Choice) {
        DS.Haptic.selection()
        switch choice {
        case .all:
            viewModel.selectedCategories = []
            viewModel.selectedSubcategories = []
        case .category(let id):
            viewModel.selectedSubcategories = []
            viewModel.selectedCategories = [id]
        case .subcategory(let id):
            viewModel.selectedCategories = []
            viewModel.selectedSubcategories = [id]
        }
        onFilterChange()
    }

    // MARK: - Fecha ▾

    /// «Todo el tiempo» es lo de siempre en Registros: el chip dice «Fecha». Con otro período, su nombre.
    private var dateLabel: RecordsQuickChipLabel {
        let period = sessionState.selectedPeriod
        if period == .allTime { return .placeholder }
        if period == .custom, let range = sessionState.customDateRange {
            return .one(PeriodStepLogic.customTitle(range))
        }
        return .one(period.displayName)
    }

    private var dateChip: some View {
        Menu {
            ForEach(DetailPeriod.allCases.filter { $0 != .custom }) { period in
                Button {
                    DS.Haptic.selection()
                    sessionState.choosePeriod(period)
                    onFilterChange()
                } label: {
                    selectableLabel(period.displayName, isSelected: sessionState.selectedPeriod == period)
                }
            }
            Divider()
            Button {
                onCustomPeriod()
            } label: {
                selectableLabel(L10n.Period.custom, isSelected: sessionState.selectedPeriod == .custom)
            }
        } label: {
            chipLabel(placeholder: L10n.RecordsQuickFilters23.date, label: dateLabel, many: { _ in "" })
        }
        .accessibilityLabel(L10n.RecordsQuickFilters23.date)
        .accessibilityValue(accessibilityValue(dateLabel, many: { _ in "" }))
        .accessibilityIdentifier("records_quick_date")
    }

    // MARK: - Más filtros

    private var moreChip: some View {
        Button {
            viewModel.showFiltersSheet = true
        } label: {
            Text(L10n.RecordsQuickFilters23.more)
                .font(DS.Typography.subheadline)
                .lineLimit(1)
            .foregroundStyle(.primary)
            .padding(.horizontal, DS.Spacing.sm)
            .frame(minHeight: FilterChipView.closeHitSize)
            .glassEffect(.regular.interactive(), in: .capsule)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("records_quick_more")
    }

    // MARK: - Piezas

    /// El chip: su nombre sin nada elegido y lo elegido, relleno con el acento, cuando lo hay. 44 pt de alto.
    private func chipLabel(
        placeholder: String,
        label: RecordsQuickChipLabel,
        many: (Int) -> String
    ) -> some View {
        let text: String
        switch label {
        case .placeholder: text = placeholder
        case .one(let name): text = name
        case .many(let count): text = many(count)
        }
        return HStack(spacing: DS.Spacing.xs) {
            Text(text)
                .font(DS.Typography.subheadline)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(DS.Typography.captionSmall.weight(.semibold))
                .accessibilityHidden(true)
        }
        .foregroundStyle(label.isActive ? theme.onAccent : Color.primary)
        .padding(.horizontal, DS.Spacing.sm)
        .frame(minHeight: FilterChipView.closeHitSize)
        .background {
            if label.isActive {
                Capsule().fill(theme.accent)
            }
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .contentShape(Capsule())
    }

    private func accessibilityValue(_ label: RecordsQuickChipLabel, many: (Int) -> String) -> String {
        switch label {
        case .placeholder: return ""
        case .one(let name): return name
        case .many(let count): return many(count)
        }
    }

    @ViewBuilder
    private func selectableLabel(_ title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}

// MARK: - Hoja de «Categoría ▾»

/// La lista de categorías con su buscador: tocar una fila aplica y cierra. Una categoría entera, una subcategoría o
/// «Todas las categorías».
struct RecordsQuickCategorySheet: View {
    enum Choice: Equatable {
        case all
        case category(PersistentIdentifier)
        case subcategory(PersistentIdentifier)
    }

    let categories: [Category]
    let subcategories: [Subcategory]
    let selectedCategories: Set<PersistentIdentifier>
    let selectedSubcategories: Set<PersistentIdentifier>
    let onChoose: (Choice) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @State private var query = ""

    private func visibleSubcategories(of category: Category) -> [Subcategory] {
        subcategories.filter { $0.category == category && $0.isVisible }
    }

    private var isSearching: Bool { !CategorySearchLogic.normalized(query).isEmpty }

    var body: some View {
        NavigationStack {
            List {
                if !isSearching {
                    row(
                        title: L10n.Filters.allCategories, caption: nil,
                        isSelected: selectedCategories.isEmpty && selectedSubcategories.isEmpty,
                        choice: .all
                    )
                }
                ForEach(categories, id: \.persistentModelID) { category in
                    let subs = visibleSubcategories(of: category)
                    let categoryMatches = CategorySearchLogic.matches(category.name, query: query)
                    let matchingSubs = subs.filter { CategorySearchLogic.matches($0.name, query: query) }
                    if !subs.isEmpty && (categoryMatches || !matchingSubs.isEmpty) {
                        Section {
                            if categoryMatches {
                                row(
                                    title: category.name, caption: L10n.RecordsQuickFilters23.wholeCategory,
                                    isSelected: selectedCategories == [category.persistentModelID]
                                        || (!subs.isEmpty && Set(subs.map(\.persistentModelID)) == selectedSubcategories),
                                    choice: .category(category.persistentModelID)
                                )
                            }
                            ForEach(isSearching ? matchingSubs : subs, id: \.persistentModelID) { sub in
                                row(
                                    title: sub.name, caption: isSearching ? category.name : nil,
                                    isSelected: selectedSubcategories == [sub.persistentModelID],
                                    choice: .subcategory(sub.persistentModelID),
                                    indented: !isSearching
                                )
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .overlay {
                if isSearching && noResults {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: L10n.RecordsQuickFilters23.searchPrompt
            )
            .autocorrectionDisabled()
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.RecordsQuickFilters23.category)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var noResults: Bool {
        !categories.contains { category in
            let subs = visibleSubcategories(of: category)
            return !subs.isEmpty && (CategorySearchLogic.matches(category.name, query: query)
                || subs.contains { CategorySearchLogic.matches($0.name, query: query) })
        }
    }

    private func row(
        title: String, caption: String?, isSelected: Bool, choice: Choice, indented: Bool = false
    ) -> some View {
        Button {
            onChoose(choice)
            dismiss()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                    if let caption {
                        Text(caption)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, indented ? DS.Spacing.lg : DS.Spacing.none)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.accentText)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(caption ?? "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("records_quick_category_row")
    }
}
