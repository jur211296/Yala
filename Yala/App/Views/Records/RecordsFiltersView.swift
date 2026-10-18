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
    @State private var localIsExcludeMode: Bool = false
    @State private var hasSnapshotted = false

    // MARK: - Preguntas antes de perder lo elegido (UX 2.2 · L8-16)

    /// Lo que había al abrir la hoja (tras expandir categorías a subcategorías). La X y el gesto de cerrar preguntan
    /// solo si lo elegido difiere de esto.
    @State private var originalDraft: RecordsFiltersDraft?
    @State private var showDiscardAlert = false
    /// El segmento pinta esto, no `localIsExcludeMode`: cambiarlo con algo marcado pregunta antes de vaciar, y si la
    /// persona cancela el segmento vuelve a su sitio sin haber borrado nada.
    @State private var requestedExcludeMode = false
    @State private var pendingExcludeMode: Bool?
    @State private var showModeSwitchAlert = false

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
            .alert(modeSwitchTitle, isPresented: $showModeSwitchAlert) {
                Button(L10n.Action.cancel, role: .cancel) { cancelModeSwitch() }
                Button(L10n.UXL8C.Filters.switchConfirm, role: .destructive) { confirmModeSwitch() }
            } message: {
                Text(L10n.UXL8C.Filters.switchMessage)
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
                            Picker("", selection: $requestedExcludeMode) {
                                Text(L10n.Filters.includeMode).tag(false)
                                Text(L10n.Filters.excludeMode).tag(true)
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("filters_include_exclude_picker")

                            Text(localIsExcludeMode ? L10n.Filters.excludeModeExplanation : L10n.Filters.includeModeExplanation)
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("filters_mode_explanation")

                            // En «Ocultar» no está la fila Tipo, a propósito: ocultar los gastos es lo mismo que ver
                            // solo los ingresos, y eso se elige en «Mostrar solo» (L8-16).
                            if localIsExcludeMode && !sessionState.isExpensesOnlyMode {
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
                                if !sessionState.isExpensesOnlyMode && !localIsExcludeMode {
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
            .onChange(of: requestedExcludeMode) { _, newValue in handleModeRequest(newValue) }
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
                        commitToViewModel()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
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
            items: filtersViewModel.filterAccounts(selected: localSelectedAccounts),
            showEmptyPlaceholder: false,
            parenthesizesStatus: false
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
            showEmptyPlaceholder: true,
            parenthesizesStatus: false
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
            return RecordsFiltersSection.needs.emptyStatus(isExcludeMode: localIsExcludeMode)
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
        .accessibilityIdentifier("filters_currency_chip_\(currency.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedCurrenciesText: String {
        guard !filtersViewModel.currenciesWithTransactions.isEmpty else { return "" }

        if localSelectedCurrencies.isEmpty {
            return RecordsFiltersSection.currencies.emptyStatus(isExcludeMode: localIsExcludeMode)
        }
        if !localIsExcludeMode &&
           localSelectedCurrencies.count == filtersViewModel.currenciesWithTransactions.count {
            return RecordsFiltersSection.currencies.emptyStatus(isExcludeMode: false)
        }
        return "\(localSelectedCurrencies.count)/\(filtersViewModel.currenciesWithTransactions.count)"
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
                Text(L10n.UXL8C.Filters.amountNeedsOneCurrency)
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

    /// La moneda del filtro de monto: la elegida si hay una sola, o la única que tienen los registros. Con varias
    /// monedas y ninguna elegida no hay monto que comparar.
    private var amountCurrencyCode: CurrencyCode? {
        if localSelectedCurrencies.count == 1 { return localSelectedCurrencies.first }
        guard localSelectedCurrencies.isEmpty, filtersViewModel.currenciesWithTransactions.count == 1 else { return nil }
        return filtersViewModel.currenciesWithTransactions.first
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
                            ForEach(Array(filtersViewModel.filterAccounts(selected: localSelectedAccounts).enumerated()), id: \.element.id) { index, account in
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
        localIsExcludeMode = recordsViewModel.isExcludeMode
        requestedExcludeMode = recordsViewModel.isExcludeMode
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
            isExcludeMode: localIsExcludeMode
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

    private var modeSwitchTitle: String {
        (pendingExcludeMode ?? !localIsExcludeMode)
            ? L10n.UXL8C.Filters.switchToExcludeTitle
            : L10n.UXL8C.Filters.switchToIncludeTitle
    }

    /// El segmento pidió otro modo. Sin nada que se pierda, cambia; con algo marcado, el segmento vuelve a su sitio
    /// y pregunta. La vuelta del segmento entra otra vez aquí con el modo de siempre y no hace nada.
    private func handleModeRequest(_ requested: Bool) {
        guard requested != localIsExcludeMode else { return }
        if RecordsFiltersDraftLogic.modeSwitchWouldClear(currentDraft, isExpensesOnlyMode: sessionState.isExpensesOnlyMode) {
            pendingExcludeMode = requested
            requestedExcludeMode = localIsExcludeMode
            showModeSwitchAlert = true
        } else {
            applyModeSwitch(to: requested)
        }
    }

    private func confirmModeSwitch() {
        guard let target = pendingExcludeMode else { return }
        pendingExcludeMode = nil
        applyModeSwitch(to: target)
    }

    private func cancelModeSwitch() {
        pendingExcludeMode = nil
    }

    /// Cambiar de modo vacía lo elegido: los mismos IDs significan «solo estos» o «todos menos estos».
    /// Antes lo hacía un `onChange` del modo, que también corría al rehidratar la hoja en «Ocultar».
    private func applyModeSwitch(to excludeMode: Bool) {
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
        localIsExcludeMode = excludeMode
        requestedExcludeMode = excludeMode
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
        requestedExcludeMode = false
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
