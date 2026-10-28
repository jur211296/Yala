//
//  RecordsFiltersView.swift
//  Yala
//
//  Replica of ExportFiltersStepView design for Records
//

import SwiftData
import SwiftUI

struct RecordsFiltersView<VM: Filterable & Observable>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var filtersViewModel = RecordsFiltersViewModel()

    // MARK: - ViewModel Binding

    @Bindable var recordsViewModel: VM

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
    // Lo de «Ocultar». Convive con lo de «Mostrar solo» de arriba (opción B, 2026-10-25): las dos listas se aplican a la
    // vez y un mismo valor no puede estar en las dos.
    @State private var localExcludedAccounts: Set<PersistentIdentifier> = []
    @State private var localExcludedCategories: Set<PersistentIdentifier> = []
    @State private var localExcludedSubcategories: Set<PersistentIdentifier> = []
    @State private var localExcludedTags: Set<PersistentIdentifier> = []
    @State private var localExcludedNeeds: Set<SubcategoryNeed> = []
    @State private var localExcludedCurrencies: Set<CurrencyCode> = []
    /// La pestaña a la vista: qué lista escribe un toque. Cambiarla ya no vacía nada (antes «Mostrar solo» y «Ocultar»
    /// eran un modo global y los mismos valores significaban una cosa u otra).
    @State private var isEditingHidden: Bool = false
    @State private var hasSnapshotted = false
    /// Lo que había en categorías al abrir, antes de expandirlo a subcategorías para la hoja. Si al aplicar la lista de
    /// subcategorías sigue siendo la expansión de entonces, se devuelve la forma original: «Sin Comida» sigue siendo
    /// «Sin Comida» (con sus movimientos sin subcategoría) y no N cápsulas «Sin <subcategoría>».
    @State private var categoryExpansion: CategoryExpansion?

    private struct CategoryExpansion {
        let includedCategories: Set<PersistentIdentifier>
        let includedSubcategories: Set<PersistentIdentifier>
        let expandedIncluded: Set<PersistentIdentifier>
        let excludedCategories: Set<PersistentIdentifier>
        let excludedSubcategories: Set<PersistentIdentifier>
        let expandedExcluded: Set<PersistentIdentifier>
    }

    // MARK: - Preguntas antes de perder lo elegido (UX 2.2 · L8-16)

    /// Lo que había al abrir la hoja (tras expandir categorías a subcategorías). La X y el gesto de cerrar preguntan
    /// solo si lo elegido difiere de esto.
    @State private var originalDraft: RecordsFiltersDraft?
    @State private var showDiscardAlert = false

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
            .alert(L10n.UXL8C.Filters.discardTitle, isPresented: $showDiscardAlert) {
                Button(L10n.UXL8C.Filters.keepChoosing, role: .cancel) {}
                Button(L10n.UXL8C.Filters.discard, role: .destructive) { dismiss() }
            } message: {
                Text(L10n.UXL8C.Filters.discardMessage)
            }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        NavigationStack {
            ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        // Mostrar solo / Ocultar (UX 2.2 · L3-5): el selector invertía todo sin decir cómo. Los
                        // segmentos van cortos para que quepan en un iPhone pequeño y en alemán; la frase de debajo
                        // dice qué hace el que está puesto.
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Picker("", selection: $isEditingHidden) {
                                Text(L10n.Filters.includeMode).tag(false)
                                Text(L10n.Filters.excludeMode).tag(true)
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("filters_include_exclude_picker")

                            Text(isEditingHidden ? L10n.Filters.excludeModeExplanation : L10n.Filters.includeModeExplanation)
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("filters_mode_explanation")

                            Text(L10n.SegmentFilter.combineHint)
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("filters_combine_hint")

                            // En «Ocultar» no está la fila Tipo, a propósito: ocultar los gastos es lo mismo que ver
                            // solo los ingresos, y eso se elige en «Mostrar solo» (L8-16).
                            if isEditingHidden && !sessionState.isExpensesOnlyMode {
                                Text(L10n.UXL8C.Filters.typeLivesInShowOnly)
                                    .font(DS.Typography.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("filters_type_hint")
                            }
                        }

                        SectionBox(title: L10n.Filters.filterOptions) {
                            VStack(spacing: DS.Spacing.none) {
                                accountsContent
                                // Transaction natures (Income/Expense) - hidden in expenses-only mode and exclude mode
                                if !sessionState.isExpensesOnlyMode && !isEditingHidden {
                                    Divider().padding(.leading, DS.Spacing.lg)
                                    transactionNaturesContent
                                }
                                Divider().padding(.leading, DS.Spacing.lg)
                                categoriesContent
                                // Sin etiquetas la fila no lleva a nada (UX 2.2 · L3-5): no se pinta.
                                if !filtersViewModel.activeTags.isEmpty {
                                    Divider().padding(.leading, DS.Spacing.lg)
                                    tagsContent
                                }
                                Divider().padding(.leading, DS.Spacing.lg)
                                needsContent
                                Divider().padding(.leading, DS.Spacing.lg)
                                currencyContent
                                // El monto necesita UNA moneda. Lleva su título, y sin moneda única dice qué hacer: la
                                // sección de moneda está justo encima (L8-16; antes no salía, L3-5).
                                if !filtersViewModel.currenciesWithTransactions.isEmpty {
                                    Divider().padding(.leading, DS.Spacing.lg)
                                    amountSection
                                }
                                Divider().padding(.leading, DS.Spacing.lg)
                                noteContent
                            }
                        }

                        // Reset filters button
                        Button {
                            dsWithAnimation(reduceMotion) {
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
                    .dismissKeyboardOnTap()
                }
                .scrollDismissesKeyboard(.interactively)
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Filters.title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                filtersViewModel.setContext(modelContext)
                if !hasSnapshotted {
                    snapshotFromViewModel()
                    expandCategoryFiltersToSubcategories()
                    originalDraft = currentDraft
                    hasSnapshotted = true
                }
            }
            // Arrastrar la hoja hacia abajo con cambios pregunta lo mismo que la X.
            .onSheetDismissAttempt(isActive: hasChanges) { showDiscardAlert = true }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        requestClose()
                    }
                    .accessibilityIdentifier("filters_close_button")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Action.apply) {
                        // Sin cambios no se escribe nada: abrir y aplicar no puede alterar el filtro.
                        if hasChanges { commitToViewModel() }
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(.thOnAccent)
                    .accessibilityIdentifier("filters_apply_button")
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
            items: filtersViewModel.filterAccounts(selected: localSelectedAccounts.union(localExcludedAccounts)),
            showEmptyPlaceholder: false,
            parenthesizesStatus: false
        ) { account in
            accountChip(account)
        }
    }

    private func accountChip(_ account: Account) -> some View {
        let isSelected = editAccounts.contains(account.persistentModelID)

        return Button {
            if isSelected {
                editAccounts.remove(account.persistentModelID)
            } else {
                editAccounts.insert(account.persistentModelID)
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
                .overlay { otherListMark(otherAccounts.contains(account.persistentModelID)) }
        }
        .buttonStyle(.plain)
    }

    private var selectedAccountsText: String {
        filtersViewModel.selectedAccountsText(selectedAccounts: editAccounts, isExcludeMode: isEditingHidden)
    }

    private var categoriesContent: some View {
        Button {
            showCategoriesSheet = true
        } label: {
            HStack(spacing: DS.Spacing.none) {
                FilterSectionHeader(
                    icon: "tag",
                    title: L10n.Filters.categories,
                    status: selectedCategoriesText,
                    parenthesizesStatus: false
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
        let original = (
            localSelectedCategories, localSelectedSubcategories, localExcludedCategories, localExcludedSubcategories
        )
        // Lo oculto, primero: «Ocultar Comida» desde la tarta se ve en la hoja como sus subcategorías ocultas.
        localExcludedSubcategories = expanded(categories: localExcludedCategories, into: localExcludedSubcategories)
        localExcludedCategories.removeAll()
        // Y lo visto solo, sin lo oculto: «Solo Comida» + «Sin Restaurantes» no puede meter Restaurantes en las dos
        // listas.
        localSelectedSubcategories = expanded(categories: localSelectedCategories, into: localSelectedSubcategories)
            .subtracting(localExcludedSubcategories)
        localSelectedCategories.removeAll()
        categoryExpansion = CategoryExpansion(
            includedCategories: original.0, includedSubcategories: original.1,
            expandedIncluded: localSelectedSubcategories,
            excludedCategories: original.2, excludedSubcategories: original.3,
            expandedExcluded: localExcludedSubcategories
        )
    }

    private func expanded(
        categories: Set<PersistentIdentifier>,
        into subcategories: Set<PersistentIdentifier>
    ) -> Set<PersistentIdentifier> {
        var result = subcategories
        for categoryID in categories {
            let subcategoriesOfCategory = filtersViewModel.allSubcategories
                .filter { sub in
                    guard let category = sub.category else { return false }
                    return category.persistentModelID == categoryID && sub.isVisible
                }
                .map { $0.persistentModelID }

            let alreadyHasSpecificSelection = subcategoriesOfCategory.contains { subcategories.contains($0) }

            if !alreadyHasSpecificSelection {
                result.formUnion(subcategoriesOfCategory)
            }
        }
        return result
    }

    private var selectedCategoriesText: String {
        filtersViewModel.selectedCategoriesText(selectedSubcategories: editSubcategories, isExcludeMode: isEditingHidden)
    }

    private var tagsContent: some View {
        FilterChipsSection(
            icon: "number",
            title: L10n.Settings.tags,
            status: selectedTagsText,
            items: filtersViewModel.activeTags,
            showEmptyPlaceholder: true,
            parenthesizesStatus: false
        ) { tag in
            tagChip(tag)
        }
    }

    private func tagChip(_ tag: Tag) -> some View {
        let isSelected = editTags.contains(tag.persistentModelID)

        return Button {
            if isSelected {
                editTags.remove(tag.persistentModelID)
            } else {
                editTags.insert(tag.persistentModelID)
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Circle()
                    .fill(isSelected ? Color.white : Color(hex: tag.colorHex))
                    .frame(width: DS.Chip.dotSize, height: DS.Chip.dotSize)

                Text(tag.name)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(isSelected ? theme.onAccent : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? theme.accent : Color(.tertiarySystemFill))
            )
            .overlay { otherListMark(otherTags.contains(tag.persistentModelID)) }
        }
        .buttonStyle(.plain)
    }

    private var selectedTagsText: String {
        filtersViewModel.selectedTagsText(selectedTags: editTags, isExcludeMode: isEditingHidden)
    }

    // MARK: - Transaction Natures Content (Income/Expense)

    private var transactionNaturesContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            FilterSectionHeader(
                icon: "arrow.up.arrow.down",
                title: L10n.Filters.type,
                status: selectedTransactionNaturesText,
                parenthesizesStatus: false
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
        let all = RecordsFiltersSection.types.emptyStatus(isExcludeMode: false)
        if localSelectedTransactionNatures.isEmpty {
            return all
        }
        if localSelectedTransactionNatures.count == TransactionNature.allCases.count {
            return all
        }
        return localSelectedTransactionNatures.first?.displayName ?? all
    }

    // MARK: - Needs Content

    private var needsContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header
            FilterSectionHeader(
                icon: "chart.bar.fill",
                title: L10n.Filters.need,
                status: selectedNeedsText,
                parenthesizesStatus: false
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
        let isSelected = editNeeds.contains(need)

        return Button {
            if isSelected {
                editNeeds.remove(need)
            } else {
                editNeeds.insert(need)
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Text(need.displayName)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(isSelected ? theme.onAccent : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? theme.accent : Color(.tertiarySystemFill))
            )
            .overlay { otherListMark(otherNeeds.contains(need)) }
        }
        .buttonStyle(.plain)
    }

    private var selectedNeedsText: String {
        if editNeeds.isEmpty {
            return RecordsFiltersSection.needs.emptyStatus(isExcludeMode: isEditingHidden)
        }
        return "\(editNeeds.count)"
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
                    status: selectedCurrenciesText,
                    parenthesizesStatus: false
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
        let isSelected = editCurrencies.contains(currency)

        return Button {
            if isSelected {
                editCurrencies.remove(currency)
            } else {
                editCurrencies.insert(currency)
            }
        } label: {
            Text(currency.rawValue)
                .font(DS.Typography.subheadline)
                .foregroundStyle(isSelected ? theme.onAccent : .primary)
                .lineLimit(1)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? theme.accent : Color(.tertiarySystemFill))
                )
                .overlay { otherListMark(otherCurrencies.contains(currency)) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("filters_currency_chip_\(currency.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedCurrenciesText: String {
        guard !filtersViewModel.currenciesWithTransactions.isEmpty else { return "" }

        if editCurrencies.isEmpty {
            return RecordsFiltersSection.currencies.emptyStatus(isExcludeMode: isEditingHidden)
        }
        if !isEditingHidden &&
           editCurrencies.count == filtersViewModel.currenciesWithTransactions.count {
            return RecordsFiltersSection.currencies.emptyStatus(isExcludeMode: false)
        }
        return "\(editCurrencies.count)/\(filtersViewModel.currenciesWithTransactions.count)"
    }

    /// Monto, con su título. Con una sola moneda, el selector; con varias y ninguna elegida, qué hacer.
    private var amountSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "banknote")
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .frame(width: DS.FormRow.iconWidth)
                    .accessibilityHidden(true)

                Text(L10n.UXL8C.Filters.amountTitle)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.md)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("filters_amount_title")

            if amountCurrencyCode != nil {
                AmountFilterView(
                    condition: $localAmountCondition,
                    currencyCode: amountCurrencyCode
                )
            } else {
                // En «Ocultar» lo que se marca es lo que desaparece: pedir «elige una sola» diría lo contrario.
                Text(isEditingHidden
                     ? L10n.UXL8C.Filters.amountNeedsOneVisibleCurrency
                     : L10n.UXL8C.Filters.amountNeedsOneCurrency)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, DS.Spacing.formIndent)
                    .padding(.trailing, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.sm)
                    .padding(.bottom, DS.Spacing.md)
                    .accessibilityIdentifier("filters_amount_needs_one_currency")
            }
        }
    }

    /// La moneda del filtro de monto: la única que queda a la vista. Nunca una oculta.
    private var amountCurrencyCode: CurrencyCode? {
        RecordsAmountFilterCurrencyLogic.currency(
            included: localSelectedCurrencies,
            excluded: localExcludedCurrencies,
            available: filtersViewModel.currenciesWithTransactions
        )
    }

    private var noteContent: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "note.text")
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
                .frame(width: DS.FormRow.iconWidth)

            TextField(L10n.Filters.noteContains, text: $localSearchText)
                .accessibilityIdentifier("filters_note_field")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Accounts Sheet

    private var accountsSheetView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    SectionBox(title: "") {
                        VStack(spacing: DS.Spacing.none) {
                            ForEach(Array(filtersViewModel.filterAccounts(selected: localSelectedAccounts.union(localExcludedAccounts)).enumerated()), id: \.element.id) { index, account in
                                if index > 0 {
                                    SubsectionDivider()
                                }

                                Button {
                                    if editAccounts.contains(account.persistentModelID) {
                                        editAccounts.remove(account.persistentModelID)
                                    } else {
                                        editAccounts.insert(account.persistentModelID)
                                    }
                                } label: {
                                    HStack {
                                        Text(account.name)
                                            .font(DS.Typography.body)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if editAccounts.contains(account.persistentModelID) {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(theme.accentText)
                                                .font(DS.Typography.headline)
                                                .accessibilityHidden(true)
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
            .yalaScreenBackground(.subtle)
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
            selectedSubcategories: Binding(get: { editSubcategories }, set: { editSubcategories = $0 }),
            otherListSubcategories: isEditingHidden ? localSelectedSubcategories : localExcludedSubcategories,
            otherListMarkColor: isEditingHidden ? theme.accent : DS.Semantic.errorForeground
        )
    }

    private func subcategories(for category: Category) -> [Subcategory] {
        filtersViewModel.subcategories(for: category)
    }

    private func subcategorySelectionSummary(for category: Category) -> String {
        filtersViewModel.subcategorySelectionSummary(for: category, selectedSubcategories: editSubcategories)
    }

    // MARK: - Tags Sheet

    private var tagsSheetView: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    SectionBox(title: "") {
                        VStack(spacing: DS.Spacing.none) {
                            ForEach(Array(filtersViewModel.activeTags.enumerated()), id: \.element.id) { index, tag in
                                if index > 0 {
                                    SubsectionDivider()
                                }

                                Button {
                                    if editTags.contains(tag.persistentModelID) {
                                        editTags.remove(tag.persistentModelID)
                                    } else {
                                        editTags.insert(tag.persistentModelID)
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

                                        if editTags.contains(tag.persistentModelID) {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(theme.accentText)
                                                .font(DS.Typography.headline)
                                                .accessibilityHidden(true)
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
            .yalaScreenBackground(.subtle)
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

    // MARK: - La lista de la pestaña a la vista

    // Un toque escribe en la lista de la pestaña («Mostrar solo» o «Ocultar») y quita el valor de la otra: un mismo
    // valor no puede estar en las dos. Lo mismo que hace `SessionState` al aplicar (`overlaps`).

    private var editAccounts: Set<PersistentIdentifier> {
        get { isEditingHidden ? localExcludedAccounts : localSelectedAccounts }
        nonmutating set {
            if isEditingHidden {
                localExcludedAccounts = newValue
                localSelectedAccounts.subtract(newValue)
            } else {
                localSelectedAccounts = newValue
                localExcludedAccounts.subtract(newValue)
            }
        }
    }
    private var otherAccounts: Set<PersistentIdentifier> {
        isEditingHidden ? localSelectedAccounts : localExcludedAccounts
    }

    private var editSubcategories: Set<PersistentIdentifier> {
        get { isEditingHidden ? localExcludedSubcategories : localSelectedSubcategories }
        nonmutating set {
            if isEditingHidden {
                localExcludedSubcategories = newValue
                localSelectedSubcategories.subtract(newValue)
            } else {
                localSelectedSubcategories = newValue
                localExcludedSubcategories.subtract(newValue)
            }
        }
    }

    private var editTags: Set<PersistentIdentifier> {
        get { isEditingHidden ? localExcludedTags : localSelectedTags }
        nonmutating set {
            if isEditingHidden {
                localExcludedTags = newValue
                localSelectedTags.subtract(newValue)
            } else {
                localSelectedTags = newValue
                localExcludedTags.subtract(newValue)
            }
        }
    }
    private var otherTags: Set<PersistentIdentifier> {
        isEditingHidden ? localSelectedTags : localExcludedTags
    }

    private var editNeeds: Set<SubcategoryNeed> {
        get { isEditingHidden ? localExcludedNeeds : localSelectedNeeds }
        nonmutating set {
            if isEditingHidden {
                localExcludedNeeds = newValue
                localSelectedNeeds.subtract(newValue)
            } else {
                localSelectedNeeds = newValue
                localExcludedNeeds.subtract(newValue)
            }
        }
    }
    private var otherNeeds: Set<SubcategoryNeed> {
        isEditingHidden ? localSelectedNeeds : localExcludedNeeds
    }

    private var editCurrencies: Set<CurrencyCode> {
        get { isEditingHidden ? localExcludedCurrencies : localSelectedCurrencies }
        nonmutating set {
            if isEditingHidden {
                localExcludedCurrencies = newValue
                localSelectedCurrencies.subtract(newValue)
            } else {
                localSelectedCurrencies = newValue
                localExcludedCurrencies.subtract(newValue)
            }
        }
    }
    private var otherCurrencies: Set<CurrencyCode> {
        isEditingHidden ? localSelectedCurrencies : localExcludedCurrencies
    }

    /// Un valor que está en la OTRA lista se ve igual con su contorno: rojo si está oculto (mirando «Mostrar solo»),
    /// lila si se ve solo (mirando «Ocultar»). Tocarlo lo pasa a la lista de la pestaña.
    @ViewBuilder
    private func otherListMark(_ isInOtherList: Bool) -> some View {
        if isInOtherList {
            Capsule()
                .strokeBorder(isEditingHidden ? theme.accent : DS.Semantic.errorForeground, lineWidth: 1.5)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Snapshot / Commit

    private func snapshotFromViewModel() {
        // Las líneas de una tarjeta elegida no se ofrecen: entran solas al elegirla. El borrador local guarda solo la tarjeta,
        // y así quitarla al confirmar quita también sus líneas (entrega 3).
        localSelectedAccounts = SessionState.shared.shownAccountSelection(recordsViewModel.selectedAccounts)
        localSelectedCategories = recordsViewModel.selectedCategories
        localSelectedSubcategories = recordsViewModel.selectedSubcategories
        localSelectedTags = recordsViewModel.selectedTags
        localSelectedNeeds = recordsViewModel.selectedNeeds
        localSelectedTransactionNatures = recordsViewModel.selectedTransactionNatures
        localSelectedCurrencies = recordsViewModel.selectedCurrencies
        localAmountCondition = recordsViewModel.amountCondition
        localSearchText = recordsViewModel.searchText
        localExcludedAccounts = SessionState.shared.shownAccountSelection(recordsViewModel.excludedAccounts)
        localExcludedCategories = recordsViewModel.excludedCategories
        localExcludedSubcategories = recordsViewModel.excludedSubcategories
        localExcludedTags = recordsViewModel.excludedTags
        localExcludedNeeds = recordsViewModel.excludedNeeds
        localExcludedCurrencies = recordsViewModel.excludedCurrencies
        // Se abre en «Ocultar» solo si no hay nada en «Mostrar solo» y sí algo oculto: así se ve lo que hay.
        isEditingHidden = !hasIncludedEntities && hasExcludedEntities
    }

    private var hasIncludedEntities: Bool {
        !localSelectedAccounts.isEmpty || !localSelectedCategories.isEmpty || !localSelectedSubcategories.isEmpty
            || !localSelectedTags.isEmpty || !localSelectedNeeds.isEmpty || !localSelectedCurrencies.isEmpty
    }

    private var hasExcludedEntities: Bool {
        !localExcludedAccounts.isEmpty || !localExcludedCategories.isEmpty || !localExcludedSubcategories.isEmpty
            || !localExcludedTags.isEmpty || !localExcludedNeeds.isEmpty || !localExcludedCurrencies.isEmpty
    }

    private func commitToViewModel() {
        // Las subcategorías que no se tocaron vuelven a su forma de categoría (ver `categoryExpansion`).
        var includedCategories = localSelectedCategories
        var includedSubcategories = localSelectedSubcategories
        var excludedCategories = localExcludedCategories
        var excludedSubcategories = localExcludedSubcategories
        if let expansion = categoryExpansion {
            if includedSubcategories == expansion.expandedIncluded {
                includedCategories = expansion.includedCategories
                includedSubcategories = expansion.includedSubcategories
            }
            if excludedSubcategories == expansion.expandedExcluded {
                excludedCategories = expansion.excludedCategories
                excludedSubcategories = expansion.excludedSubcategories
            }
        }
        // En bloque: la hoja entrega las dos listas ya disjuntas, y así `SessionState` no recorta una con el valor
        // intermedio de la otra.
        SessionState.shared.performBatchFilterUpdate {
            recordsViewModel.selectedAccounts = localSelectedAccounts
            recordsViewModel.selectedCategories = includedCategories
            recordsViewModel.selectedSubcategories = includedSubcategories
            recordsViewModel.selectedTags = localSelectedTags
            recordsViewModel.selectedNeeds = localSelectedNeeds
            recordsViewModel.selectedTransactionNatures = localSelectedTransactionNatures
            recordsViewModel.selectedCurrencies = localSelectedCurrencies
            recordsViewModel.excludedAccounts = localExcludedAccounts
            recordsViewModel.excludedCategories = excludedCategories
            recordsViewModel.excludedSubcategories = excludedSubcategories
            recordsViewModel.excludedTags = localExcludedTags
            recordsViewModel.excludedNeeds = localExcludedNeeds
            recordsViewModel.excludedCurrencies = localExcludedCurrencies
            // Sin una moneda a la vista la hoja dice que el monto no se puede usar: tampoco se aplica (review del lote
            // 12.5: seguía filtrando cada registro en su propia moneda). Con ella, el monto se guarda con su moneda, y
            // `SessionState` lo vacía si deja de ser la única a la vista por otro camino.
            SessionState.shared.applyAmountFilter(
                amountCurrencyCode == nil ? .any : localAmountCondition, in: amountCurrencyCode
            )
            recordsViewModel.searchText = localSearchText
        }
    }

    // MARK: - Draft (UX 2.2 · L8-16)

    private var currentDraft: RecordsFiltersDraft {
        RecordsFiltersDraft(
            accounts: localSelectedAccounts,
            categories: localSelectedCategories,
            subcategories: localSelectedSubcategories,
            tags: localSelectedTags,
            needs: localSelectedNeeds,
            transactionNatures: localSelectedTransactionNatures,
            currencies: localSelectedCurrencies,
            amountCondition: localAmountCondition,
            noteText: localSearchText,
            excludedAccounts: localExcludedAccounts,
            excludedCategories: localExcludedCategories,
            excludedSubcategories: localExcludedSubcategories,
            excludedTags: localExcludedTags,
            excludedNeeds: localExcludedNeeds,
            excludedCurrencies: localExcludedCurrencies
        )
    }

    private var hasChanges: Bool {
        RecordsFiltersDraftLogic.hasChanges(current: currentDraft, original: originalDraft)
    }

    /// La X: con cambios pregunta «¿Descartar los filtros?»; sin ellos, cierra.
    private func requestClose() {
        if hasChanges {
            showDiscardAlert = true
        } else {
            dismiss()
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
        localExcludedAccounts.removeAll()
        localExcludedCategories.removeAll()
        localExcludedSubcategories.removeAll()
        localExcludedTags.removeAll()
        localExcludedNeeds.removeAll()
        localExcludedCurrencies.removeAll()
        isEditingHidden = false
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
                selection: Binding(get: { editCurrencies }, set: { editCurrencies = $0 }),
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
