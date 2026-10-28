//
//  ExportRecordsView.swift
//  Yala
//
//  «Llévate tus registros» — exportar en UNA pantalla (decisiones de Jürgen sobre el lote 20 de la auditoría UX 2.2,
//  2026-10-18; variante L20-1-A). Sustituye al asistente de tres pasos (filtros → columnas → resumen), que empezaba por
//  «Incluir/Excluir» y terminaba preguntando «CSV» o «Excel». Aquí, de arriba abajo:
//
//  - el período en fichas («Todo» elegido),
//  - el formato en dos tarjetas (Excel, recomendado; Texto (CSV)),
//  - «Más opciones», plegado: todo lo que el asistente tenía (cuentas, categorías, etiquetas, necesidad, moneda, monto,
//    nota, Mostrar solo/Ocultar, columnas e «Incluir mis grupos»). Plegado, su subtítulo enumera los filtros que
//    recortan algo (L20-2: «todos los filtros activos a la vista», también la nota y «Ocultar»),
//  - y abajo la cifra: «Saldrán N registros · del X a hoy» (o «Ninguno con estos filtros» en rojo) y el botón
//    «Exportar N registros», apagado si no sale ninguno.
//
//  Al compartir: cancelar no enseña nada; compartir dice dónde quedó el archivo (L20-3). Desde «Vaciar datos», el botón
//  del aviso es «Seguir con el vaciado» y vuelve a la hoja de alcance.
//

import SwiftData
import SwiftUI

struct ExportRecordsView: View {

    /// Desde dónde se abre: cambia el botón del aviso tras compartir (L20-3).
    enum Origin: Equatable { case settings, wipe }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme

    let origin: Origin
    /// Desde Vaciar: «Seguir con el vaciado». Quien presenta cierra esta hoja y reabre la de alcance.
    let onContinueWipe: (() -> Void)?

    @State private var viewModel = ExportFiltersStepViewModel()
    @State private var shareResult: ExportShareResult

    // MARK: - Lo que se ve siempre

    @State private var periodChoice: ExportRecordsLogic.PeriodChoice = .all
    @State private var customDateRange: DateInterval?
    @State private var format: ExportFormat = .xlsx
    @State private var showsMoreOptions = false

    // MARK: - Más opciones (lo del asistente de siempre)

    @State private var selectedAccounts: Set<PersistentIdentifier> = []
    @State private var hasInitializedAccounts = false
    @State private var selectedSubcategories: Set<PersistentIdentifier> = []
    @State private var selectedTags: Set<PersistentIdentifier> = []
    @State private var selectedNeeds: Set<SubcategoryNeed> = Set(SubcategoryNeed.allCases)
    @State private var selectedCurrencies: Set<CurrencyCode> = Set(CurrencyCode.allCases)
    @State private var amountCondition: AmountFilterCondition = .any
    @State private var noteContains: String = ""
    @State private var isExcludeMode: Bool = false
    @State private var exportColumns: ExportColumns = .default
    @State private var hasAccountCards = false
    @State private var includeGroups = false
    @State private var hasExportableGroups = false

    @State private var showCategoriesSheet = false
    @State private var showCustomPicker = false

    // MARK: - La cifra y la exportación

    /// `nil` mientras cuenta.
    @State private var matchingCount: Int?
    /// Si contar falla no se bloquea la exportación: el botón queda en «Exportar» y el servicio dirá lo que pase.
    @State private var countFailed = false
    @State private var isExporting = false
    @State private var exportError: (any Error)?
    @State private var showErrorAlert = false
    @State private var exportedFile: ExportedFile?
    @State private var groupsExportFailed = false

    init(origin: Origin = .settings, onContinueWipe: (() -> Void)? = nil) {
        self.origin = origin
        self.onContinueWipe = onContinueWipe
        _shareResult = State(initialValue: ExportShareResult())
    }

    // MARK: - Filtros

    private var exportFilters: ExportFilters {
        var filters = viewModel.buildExportFilters(
            selectedAccounts: selectedAccounts,
            selectedSubcategories: selectedSubcategories,
            selectedTags: selectedTags,
            selectedCurrencies: selectedCurrencies,
            amountCondition: effectiveAmountCondition,
            selectedPeriod: periodChoice.detailPeriod,
            customDateRange: customDateRange,
            noteContains: noteContains,
            isExcludeMode: isExcludeMode
        )
        // Todas elegidas = sin filtro de necesidad.
        filters.selectedNeeds = selectedNeeds.count == SubcategoryNeed.allCases.count
            ? [] : SubcategoryNeed.allCases.filter { selectedNeeds.contains($0) }
        return filters
    }

    private var isAmountValid: Bool {
        if case .between(let min, let max) = effectiveAmountCondition { return min <= max }
        return true
    }

    /// La moneda del monto (`ExportRecordsLogic.amountCurrency`): nunca una oculta. En «Ocultar» las disponibles son las
    /// de las cuentas que se exportan, no las de las marcadas (que se ocultan).
    private var amountCurrencyCode: CurrencyCode? {
        ExportRecordsLogic.amountCurrency(
            marked: selectedCurrencies,
            available: isExcludeMode ? viewModel.currenciesLeftInView(hiding: selectedAccounts) : availableCurrencies,
            isExcludeMode: isExcludeMode
        )
    }

    private var effectiveAmountCondition: AmountFilterCondition {
        ExportRecordsLogic.effectiveAmount(amountCondition, currency: amountCurrencyCode)
    }

    private var canExport: Bool {
        guard !isExporting else { return false }
        if countFailed {
            return !selectedAccounts.isEmpty && isAmountValid && exportColumns.hasAtLeastOneActiveColumn
        }
        return ExportRecordsLogic.canExport(
            count: matchingCount, hasAccountSelected: !selectedAccounts.isEmpty,
            amountIsValid: isAmountValid, hasColumns: exportColumns.hasAtLeastOneActiveColumn)
    }

    private var activeFilters: [ExportRecordsLogic.ActiveFilter] {
        let offered = viewModel.offeredAccounts
        let marked = offered.filter { selectedAccounts.contains($0.persistentModelID) }.count
        let allCurrencies = availableCurrencies
        let chosenCurrencies = allCurrencies.filter { selectedCurrencies.contains($0) }.map(\.rawValue)
        return ExportRecordsLogic.activeFilters(
            markedAccounts: marked, offeredAccounts: offered.count,
            selectedSubcategories: selectedSubcategories.count,
            visibleSubcategories: viewModel.allSubcategories.filter(\.isVisible).count,
            selectedTags: selectedTags.count, allTags: viewModel.allTags.count,
            selectedNeeds: selectedNeeds.count, allNeeds: SubcategoryNeed.allCases.count,
            selectedCurrencies: chosenCurrencies, availableCurrencies: allCurrencies.count,
            amountIsActive: effectiveAmountCondition.isActive,
            note: noteContains,
            isExcludeMode: isExcludeMode)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    headerSection
                    periodCard
                    formatCard
                    moreOptionsCard
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.lg)
                .dismissKeyboardOnTap()
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { bottomBar }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Export.exportBtn)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                }
            }
        }
        .onAppear { prepare() }
        .task(id: exportFilters) { await recount() }
        .modifier(ExportRecordsPresentations(
            showCategoriesSheet: $showCategoriesSheet,
            showCustomPicker: $showCustomPicker,
            exportedFile: $exportedFile,
            customDateRange: $customDateRange,
            categoriesSheet: AnyView(categoriesSheetView),
            onCustomRangeApplied: { periodChoice = .dates },
            shareResult: shareResult))
        .alert(L10n.Export.exportError, isPresented: $showErrorAlert, presenting: exportError) { _ in
            Button(L10n.Common.ok, role: .cancel) {}
        } message: { error in
            Text((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
        .modifier(ExportDoneAlerts(
            shareResult: shareResult, origin: origin,
            message: groupsExportFailed ? L10n.Export.groupsExportFailedNote : nil,
            onBackToSettings: { dismiss() },
            onContinueWipe: { continueWipe() }))
    }

    // MARK: - Arriba

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.UXL20D.exportTitle)
                .font(DS.Typography.title2)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
            Text(L10n.UXL20D.exportSubtitle)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var periodCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.Export.period)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
            // En una fila, como la variante elegida; con texto grande, en varias.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DS.Spacing.xs) { periodChips }
                FlowLayout(spacing: DS.Spacing.sm) { periodChips }
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(radius: DS.Radius.xl)
    }

    @ViewBuilder
    private var periodChips: some View {
        ForEach(ExportRecordsLogic.PeriodChoice.allCases, id: \.self) { choice in
            periodChip(choice)
        }
    }

    private func periodTitle(_ choice: ExportRecordsLogic.PeriodChoice) -> String {
        switch choice {
        case .all: return L10n.UXL20D.periodAll
        case .thisYear: return L10n.Period.thisYear
        case .thisMonth: return L10n.Period.thisMonth
        case .dates: return L10n.UXL20D.periodDates
        }
    }

    private func periodChip(_ choice: ExportRecordsLogic.PeriodChoice) -> some View {
        let isSelected = periodChoice == choice
        return Button {
            if choice == .dates {
                showCustomPicker = true
            } else {
                periodChoice = choice
            }
        } label: {
            Text(periodTitle(choice))
                .font(DS.Typography.subheadlineEmphasized)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isSelected ? theme.onAccent : Color.primary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background {
                    if isSelected {
                        Capsule().fill(theme.accent)
                    } else {
                        Capsule().fill(Color.clear).glassEffect(.regular, in: Capsule())
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("export_period_\(choice.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var formatCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.Export.format)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                formatTile(.xlsx, icon: "tablecells.fill", title: L10n.UXL20D.formatExcel,
                           caption: L10n.UXL20D.formatRecommended)
                formatTile(.csv, icon: "doc.text", title: L10n.UXL20D.formatCSV,
                           caption: L10n.UXL20D.formatCSVHint)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(radius: DS.Radius.xl)
    }

    private func formatTile(_ value: ExportFormat, icon: String, title: String, caption: String) -> some View {
        let isSelected = format == value
        return Button {
            format = value
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .font(DS.Typography.title3)
                    .accessibilityHidden(true)
                Text(title)
                    .font(DS.Typography.bodyBold)
                    .fixedSize(horizontal: false, vertical: true)
                Text(caption)
                    .font(DS.Typography.caption)
                    .foregroundStyle(isSelected ? theme.onAccent : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? theme.onAccent : Color.primary)
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.accent)
                } else {
                    RoundedRectangle(cornerRadius: DS.Radius.lg).fill(Color.clear)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("export_format_\(value.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Más opciones

    /// Plegado dice qué recorta (L20-2); sin filtros, lo que hay dentro.
    private var moreOptionsSubtitle: String {
        let active = activeFilters
        guard !active.isEmpty else { return L10n.UXL20D.moreOptionsHint }
        return active.map { Self.text(for: $0) }.joined(separator: " · ")
    }

    static func text(for filter: ExportRecordsLogic.ActiveFilter) -> String {
        switch filter {
        case .accounts(let n): return L10n.UXL20D.activeAccounts(n)
        case .categories(let n): return L10n.UXL20D.activeCategories(n)
        case .tags(let n): return L10n.UXL20D.activeTags(n)
        case .needs(let n): return L10n.UXL20D.activeNeeds(n)
        case .currencies(let codes): return L10n.UXL20D.activeCurrencies(codes.joined(separator: ", "))
        case .amount: return L10n.UXL20D.activeAmount
        case .note(let text): return L10n.UXL20D.activeNote(text)
        case .hidingSelected: return L10n.UXL20D.activeHiding
        }
    }

    private var moreOptionsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            Button {
                withAnimation(.snappy) { showsMoreOptions.toggle() }
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "slider.horizontal.3")
                        .font(DS.Typography.headline)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(L10n.UXL20D.moreOptions)
                            .font(DS.Typography.bodyBold)
                            .foregroundStyle(.primary)
                        Text(moreOptionsSubtitle)
                            .font(DS.Typography.caption)
                            .foregroundStyle(activeFilters.isEmpty ? Color.secondary : Color.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("export_more_options_summary")
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showsMoreOptions ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .padding(DS.Spacing.lg)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("export_more_options")
            .accessibilityValue(showsMoreOptions ? L10n.UXL20D.expanded : L10n.UXL20D.collapsed)

            if showsMoreOptions {
                Divider()
                moreOptionsContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(radius: DS.Radius.xl)
    }

    private var moreOptionsContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            Picker(L10n.UXL20D.modeLabel, selection: $isExcludeMode) {
                Text(L10n.Filters.includeMode).tag(false)
                Text(L10n.Filters.excludeMode).tag(true)
            }
            .pickerStyle(.segmented)
            .padding(DS.Spacing.lg)
            .accessibilityIdentifier("export_mode_picker")

            Divider().padding(.leading, DS.Spacing.lg)
            accountsContent
            Divider().padding(.leading, DS.Spacing.lg)
            categoriesContent
            Divider().padding(.leading, DS.Spacing.lg)
            tagsContent
            Divider().padding(.leading, DS.Spacing.lg)
            needsContent
            Divider().padding(.leading, DS.Spacing.lg)
            currencyContent
            Divider().padding(.leading, DS.Spacing.lg)
            AmountFilterView(
                condition: $amountCondition,
                currencyCode: amountCurrencyCode,
                // En «Ocultar» lo marcado es lo que desaparece: «elige una sola» diría lo contrario.
                noCurrencyMessage: isExcludeMode ? L10n.UXL8C.Filters.amountNeedsOneVisibleCurrency : nil
            )
            Divider().padding(.leading, DS.Spacing.lg)
            noteContent
            Divider()
            columnsContent
            if hasExportableGroups {
                Divider()
                groupsToggle
            }
        }
    }

    // MARK: - Filtros (los del asistente de siempre)

    private var categoriesSheetView: some View {
        CategorySelectorSheet(
            categories: viewModel.allCategories,
            subcategories: viewModel.allSubcategories,
            selectedSubcategories: $selectedSubcategories
        )
        .onAppear {
            if selectedSubcategories.isEmpty {
                let visibleSubs = viewModel.allSubcategories.filter { $0.isVisible }
                selectedSubcategories = Set(visibleSubs.map { $0.persistentModelID })
            }
        }
    }

    private var accountsContent: some View {
        FilterChipsSection(
            icon: "creditcard",
            title: L10n.Settings.accounts,
            status: viewModel.selectedAccountsText(selectedAccounts: selectedAccounts),
            items: viewModel.offeredAccounts,
            showEmptyPlaceholder: false
        ) { account in
            accountChip(account)
        }
        .onChange(of: selectedAccounts) { _, newAccountIDs in
            // Las monedas de todo lo que se exporta: elegir la tarjeta ofrece las de todas sus líneas.
            selectedCurrencies = Set(viewModel.availableCurrencies(selectedAccounts: newAccountIDs))
        }
    }

    private func accountChip(_ account: Account) -> some View {
        let isSelected = selectedAccounts.contains(account.persistentModelID)
        return Button {
            selectedAccounts = viewModel.toggling(account, in: selectedAccounts)
        } label: {
            Text(account.name)
                .font(DS.Typography.subheadline)
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    Capsule().fill(isSelected ? Color(hex: account.colorHex) : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("export_account_chip_\(account.name)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var categoriesContent: some View {
        Button {
            showCategoriesSheet = true
        } label: {
            HStack(spacing: DS.Spacing.none) {
                FilterSectionHeader(
                    icon: "tag",
                    title: L10n.Settings.categories,
                    status: viewModel.selectedCategoriesText(selectedSubcategories: selectedSubcategories)
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
        .accessibilityIdentifier("export_categories_row")
    }

    private var tagsContent: some View {
        FilterChipsSection(
            icon: "number",
            title: L10n.Settings.tags,
            status: viewModel.selectedTagsText(selectedTags: selectedTags),
            items: viewModel.allTags,
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
                    .foregroundStyle(isSelected ? theme.onAccent : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(Capsule().fill(isSelected ? theme.accent : Color(.tertiarySystemFill)))
        }
        .buttonStyle(.plain)
    }

    private var availableCurrencies: [CurrencyCode] {
        viewModel.availableCurrencies(selectedAccounts: selectedAccounts)
    }

    private var selectedCurrenciesText: String {
        let chosen = availableCurrencies.filter { selectedCurrencies.contains($0) }
        if chosen.count == availableCurrencies.count { return L10n.Filters.allCurrencies }
        return chosen.map(\.rawValue).joined(separator: ", ")
    }

    private var currencyContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            FilterSectionHeader(
                icon: "arrow.triangle.2.circlepath",
                title: L10n.Settings.currency,
                status: selectedCurrenciesText
            )
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.md)

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
                .foregroundStyle(isSelected ? theme.onAccent : .primary)
                .lineLimit(1)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(Capsule().fill(isSelected ? theme.accent : Color(.tertiarySystemFill)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("export_currency_chip_\(currency.rawValue)")
    }

    private var selectedNeedsText: String {
        if selectedNeeds.count == SubcategoryNeed.allCases.count { return L10n.Filters.allNeeds }
        return L10n.Filters.selectedCount(selectedNeeds.count)
    }

    private var needsContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            FilterSectionHeader(icon: "chart.bar.fill", title: L10n.Need.label, status: selectedNeedsText)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)

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
            Text(need.displayName)
                .font(DS.Typography.subheadline)
                .foregroundStyle(isSelected ? theme.onAccent : .primary)
                .lineLimit(1)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(Capsule().fill(isSelected ? theme.accent : Color(.tertiarySystemFill)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("export_need_chip_\(need.rawValue)")
    }

    private var noteContent: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "note.text")
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
                .frame(width: 24)
            TextField(L10n.Filters.noteContains, text: $noteContains)
                .accessibilityIdentifier("export_note_field")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Columnas e «Incluir mis grupos»

    private var columnsContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            Text(L10n.Export.columns)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .accessibilityAddTraits(.isHeader)
            ForEach(ExportColumns.offeredOrder(hasAccountCards: hasAccountCards)) { column in
                columnToggle(column)
            }
        }
    }

    private func columnToggle(_ column: ExportColumn) -> some View {
        Toggle(isOn: $exportColumns[isActive: column]) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(column.displayName)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.primary)
                Text(column.description)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, DS.Spacing.sm)
        }
        .toggleStyle(.switch)
        .padding(.horizontal, DS.Spacing.lg)
        .accessibilityIdentifier("export_column_\(column.rawValue)")
    }

    private var groupsToggle: some View {
        Toggle(isOn: $includeGroups) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Export.includeGroups)
                    .font(DS.Typography.bodyBold)
                    .foregroundStyle(.primary)
                Text(L10n.Export.includeGroupsDescription)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, DS.Spacing.md)
        }
        .toggleStyle(.switch)
        .padding(.horizontal, DS.Spacing.lg)
        .accessibilityIdentifier("export_include_groups")
    }

    // MARK: - Abajo: la cifra y el botón

    private static let rangeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    private var rangeText: String {
        let interval = exportFilters.effectiveDateInterval()
        let formatter = Self.rangeFormatter
        formatter.locale = AppLocale.current
        let from = formatter.string(from: interval.start)
        if ExportRecordsLogic.endsToday(interval, now: .now, calendar: .current) {
            return L10n.UXL20D.rangeToToday(from)
        }
        return L10n.UXL20D.range(from, formatter.string(from: interval.end))
    }

    @ViewBuilder
    private var countLineView: some View {
        switch ExportRecordsLogic.countLine(for: countFailed ? nil : matchingCount) {
        case .counting:
            if !countFailed {
                ProgressView().controlSize(.small)
            }
        case .none:
            Text(L10n.UXL20D.noneWithFilters)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(DS.Semantic.errorForeground)
        case .some(let count):
            Text("\(L10n.UXL20D.willExport(count)) · \(rangeText)")
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var buttonTitle: String {
        guard !countFailed, let count = matchingCount, count > 0 else { return L10n.Export.exportBtn }
        return L10n.UXL20D.exportCount(count)
    }

    private var bottomBar: some View {
        VStack(spacing: DS.Spacing.sm) {
            countLineView
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("export_count_line")
            YalaPrimaryButton(buttonTitle, icon: "square.and.arrow.up", isDisabled: !canExport && !isExporting,
                              isLoading: isExporting,
                              disabledHint: matchingCount == 0
                                  ? L10n.UXL20D.noneWithFilters : L10n.Accessibility.completeRequiredFilters) {
                performExport()
            }
            .accessibilityIdentifier("export_button")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.sm)
        .background(.bar)
    }

    // MARK: - Acciones

    private func prepare() {
        viewModel.setContext(modelContext)
        guard !hasInitializedAccounts, !viewModel.allAccounts.isEmpty else { return }
        hasInitializedAccounts = true
        selectedAccounts = viewModel.initialAccountSelection
        if selectedTags.isEmpty { selectedTags = Set(viewModel.allTags.map(\.persistentModelID)) }
        hasExportableGroups = GroupsExportBuilder.hasExportableGroups(in: modelContext)
        // Tarjeta con varias divisas (entrega 4): la columna se ofrece, y sale activada, si lo que se exporta la tiene.
        hasAccountCards = AccountCardIndex(
            accounts: viewModel.exportedAccounts(selectedAccounts: selectedAccounts)).hasCards
        if hasAccountCards { exportColumns.activate(.card) }
    }

    private func recount() async {
        let filters = exportFilters
        // La cifra anterior se queda mientras cuenta: vaciarla en cada toque hacía parpadear la línea y el botón.
        // Deja pasar la tecla siguiente antes de contar: la nota cuenta una vez por pausa, no por letra.
        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else { return }
        do {
            matchingCount = try TransactionsExportService.matchingCount(using: filters, in: modelContext)
            countFailed = false
        } catch {
            #if DEBUG
            print("ExportRecordsView: Error: no se pudo contar: \(error)")
            #endif
            countFailed = true
        }
    }

    private func performExport() {
        isExporting = true
        let filters = exportFilters
        let columns = exportColumns
        let format = format
        let withGroups = hasExportableGroups && includeGroups
        Task {
            // Que el indicador se vea aunque el archivo salga en un instante.
            try? await Task.sleep(for: .seconds(0.3))
            do {
                let result = try TransactionsExportService.export(
                    format: format, using: filters, columns: columns, in: modelContext, scheduleTagBackfill: true)
                // G5-D2: con «Incluir mis grupos», un CSV aparte junto al personal. Su fallo no tumba el personal.
                var urls: [URL] = [result.fileURL]
                var groupsFailed = false
                if withGroups {
                    do {
                        if let groupsURL = try GroupsExportBuilder.exportGroupsCSV(in: modelContext) {
                            urls.append(groupsURL)
                        }
                    } catch {
                        groupsFailed = true
                        #if DEBUG
                        print("ExportRecordsView: CSV de grupos falló (se comparte solo el personal): \(error)")
                        #endif
                    }
                }
                isExporting = false
                groupsExportFailed = groupsFailed
                exportedFile = ExportedFile(urls: urls)
            } catch {
                isExporting = false
                exportError = error
                showErrorAlert = true
            }
        }
    }

    private func continueWipe() {
        if let onContinueWipe {
            onContinueWipe()
        } else {
            dismiss()
        }
    }
}

// MARK: - Presentaciones

/// Las hojas de la pantalla, aparte del `body` para que el compilador del CI (Xcode 26.6) no se ahogue con la cadena
/// (`swiftui-ds.md`: como mucho tres modificadores por `ViewModifier`).
private struct ExportRecordsPresentations: ViewModifier {
    @Binding var showCategoriesSheet: Bool
    @Binding var showCustomPicker: Bool
    @Binding var exportedFile: ExportedFile?
    @Binding var customDateRange: DateInterval?
    let categoriesSheet: AnyView
    let onCustomRangeApplied: () -> Void
    let shareResult: ExportShareResult

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showCategoriesSheet) { categoriesSheet }
            .sheet(isPresented: $showCustomPicker) {
                ExportCustomPeriodPickerSheet(customDateRange: $customDateRange, onApply: onCustomRangeApplied)
            }
            .sheet(item: $exportedFile, onDismiss: { shareResult.sheetDidClose() }) { file in
                ShareSheet(activityItems: file.urls, onFinish: { completed, activity in
                    shareResult.record(completed: completed, activityType: activity)
                })
                .yalaSheetDetents([.medium, .large])
            }
    }
}

/// El aviso tras compartir (L20-3). Dos alertas con su botón LITERAL, una por origen: el texto de un botón de `.alert`
/// no puede depender de estado (`swiftui-ds.md`). Solo una de las dos puede encenderse en cada pantalla.
private struct ExportDoneAlerts: ViewModifier {
    @Bindable var shareResult: ExportShareResult
    let origin: ExportRecordsView.Origin
    let message: String?
    let onBackToSettings: () -> Void
    let onContinueWipe: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if origin == .wipe {
            content.alert(ExportShareResult.title(for: shareResult.shownOutcome),
                          isPresented: $shareResult.isShowingAlert) {
                Button(L10n.UXL20D.continueWipe) { onContinueWipe() }
            } message: {
                if let message { Text(message) }
            }
        } else {
            content.alert(ExportShareResult.title(for: shareResult.shownOutcome),
                          isPresented: $shareResult.isShowingAlert) {
                Button(L10n.Export.backToSettings) { onBackToSettings() }
            } message: {
                if let message { Text(message) }
            }
        }
    }
}

// MARK: - Fechas elegidas a mano («Fechas…»)

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

        // El rango elegido antes, o los últimos 30 días.
        if let range = customDateRange.wrappedValue {
            _startDate = State(initialValue: range.start)
            _endDate = State(initialValue: range.end)
        } else {
            let now = Date.now
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
                    .accessibilityIdentifier("export_dates_save")
                }
            }
        }
        .yalaSheetDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func applyRange() {
        let calendar = Calendar.current
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        customDateRange = DateInterval(start: calendar.startOfDay(for: startDate), end: endOfDay)
        dismiss()
        onApply()
    }
}
