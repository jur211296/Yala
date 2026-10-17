//
//  RecordsTabView.swift
//  Yala
//
//  Records tab content — hero summary + panel-style filter bar + lista.
//
//  El title del módulo (`.navigationTitle` "Estadísticas" en `DetailContainerView` /
//  "Registros" en `RecordsStandaloneView`) vive en el host — esta view solo
//  renderiza el contenido scrolleable.
//

import SwiftData
import SwiftUI

// MARK: - Records Tab View

struct RecordsTabView: View {
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppPreferences.self) private var appPreferences
    /// «Quitar repetidos» (L8-11) borra desde aquí, que lo montan Registros y Estadísticas › Registros.
    @Environment(\.modelContext) private var modelContext

    @ScaledMetric(relativeTo: .largeTitle) private var summaryVerticalPadding: CGFloat = 12

    @Bindable var viewModel: RecordsViewModel
    let accounts: [Account]
    let categories: [Category]
    let tags: [Tag]
    let subcategories: [Subcategory]
    let transactionDateRange: (start: Date, end: Date)
    let defaultCurrencyCode: String
    var onFilterChange: () -> Void

    @State private var showCustomPeriodPicker: Bool = false
    /// El `ScrollView` tiene poco alto (iPhone girado): la cabecera va en banda (`SummaryHeaderStack`).
    @State private var isShortContainer = false
    @State private var recordsViewMode: RecordsViewMode = .list
    @State private var selectedCalendarDay: Date?
    @State private var calendarMonth: Date = .now
    @Namespace private var viewModeNamespace

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                // L8-11: en modo duplicados el resumen del período («Neto del período · Sigue así») no dice nada de
                // lo que se busca; lo sustituye el encabezado del modo, con el período para poder ampliar la búsqueda.
                if viewModel.duplicateModeActive {
                    DuplicateModeHeader(
                        tally: viewModel.duplicateTally,
                        // Con un día elegido en el calendario, solo los grupos que se ven (revisión del lote 8).
                        onRemove: { viewModel.requestDuplicateRemoval(limitedToDay: keyboardDay) },
                        onDeactivate: { viewModel.exitDuplicateMode() }
                    ) {
                        periodSelector
                    }
                } else {
                    heroSummary
                }

                filterBarPanel

                if viewModel.groupedRecords.isEmpty {
                    emptyStateContent
                } else {
                    viewModeHeader

                    if recordsViewMode == .calendar {
                        RecordsCalendarView(
                            groups: viewModel.groupedRecords,
                            period: viewModel.period,
                            customDateRange: sessionState.customDateRange,
                            currencyCode: defaultCurrencyCode,
                            adjustment: viewModel.statsAdjustment,
                            selectedDay: $selectedCalendarDay,
                            calendarMonth: $calendarMonth
                        )
                        .padding(.horizontal, DS.Spacing.lg)

                        calendarDaySummary
                    }

                    recordsListContent
                }
            }
            .padding(.top, DS.Spacing.sm)
        }
        .measuresShortContainer($isShortContainer)
        .scrollViewGlassEdges()
        // El nombre del grupo en las filas que vienen de un gasto de grupo (L8-5).
        .providesGroupNames()
        .sheet(isPresented: $showCustomPeriodPicker) {
            CustomPeriodPickerSheet(
                minDate: transactionDateRange.start,
                maxDate: transactionDateRange.end,
                currentRange: sessionState.customDateRange
            )
        }
        .onChange(of: sessionState.customDateRange) {
            onFilterChange()
        }
        .onChange(of: viewModel.period) {
            resetCalendarState()
        }
        .onChange(of: viewModel.filteredCount) {
            clampCalendarMonthIfNeeded()
        }
        .onAppear {
            syncCalendarMonth()
        }
        .onChange(of: keyboardDay, initial: true) { _, day in viewModel.keyboardDayFilter = day }
        .alert(
            duplicateRemovalTitle,
            isPresented: $viewModel.isConfirmingDuplicateRemoval
        ) {
            // Los textos de los botones van literales (swiftui-ds.md); lo que cambia es qué botones hay, como en la
            // confirmación del borrado en lote.
            if viewModel.duplicateRemovalPlan.toDelete.isEmpty {
                Button(L10n.Common.understood, role: .cancel) {}
            } else {
                Button(L10n.Action.cancel, role: .cancel) {}
                    .accessibilityIdentifier("records_duplicates_remove_cancel")
                // La lista se recarga sola: el borrado sube `dataVersion` y el host recarga desde el store.
                Button(L10n.UXL8B.Duplicates.removeConfirm, role: .destructive) {
                    viewModel.confirmDuplicateRemoval(context: modelContext)
                }
                .accessibilityIdentifier("records_duplicates_remove_confirm")
            }
        } message: {
            Text(duplicateRemovalMessage)
        }
    }

    // MARK: - Quitar repetidos (L8-11)

    private var duplicateRemovalTitle: String {
        let plan = viewModel.duplicateRemovalPlan
        guard !plan.toDelete.isEmpty else { return L10n.Records.groupRecordsOnlyTitle }
        return L10n.UXL8B.Duplicates.removeTitle(plan.toDelete.count)
    }

    /// «Se queda uno de cada grupo. No se puede deshacer.» Si algún repetido viene de Grupos, se dice cuántos se
    /// quedan; si todos los repetidos vienen de ahí, no hay nada que borrar y se explica por qué.
    private var duplicateRemovalMessage: String {
        let plan = viewModel.duplicateRemovalPlan
        guard !plan.toDelete.isEmpty else { return L10n.Records.groupRecordsDeleteFromGroup }
        var parts = [L10n.UXL8B.Duplicates.keepOnePerGroup]
        // Con criterios flojos «Quitar repetidos» puede abarcar cientos: se dice en qué coinciden (revisión del lote 8).
        let fields = viewModel.duplicateCriteria.activeFields
        if fields.count < 4, let list = duplicateFieldList(fields) {
            parts.append(L10n.UXL8.duplicatesMatchedOn(list))
        }
        if plan.keptGroupRecords > 0 {
            parts.append(L10n.UXL8B.Duplicates.keptShared(plan.keptGroupRecords))
        }
        parts.append(L10n.Common.cannotUndo)
        return parts.joined(separator: " ")
    }

    // MARK: - Resumen del día elegido (L8-10)

    /// «Gastaste S/ 2,300 · Entró S/ 354», arriba de la lista del día elegido. Mismo cálculo que las barras y el
    /// hero (`DailySpendingCalculator.dayTotals`), así que los días suman lo que dice el resumen del período.
    @ViewBuilder
    private var calendarDaySummary: some View {
        if let day = selectedCalendarDay,
           let group = viewModel.groupedRecords.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
            let totals = DailySpendingCalculator.dayTotals(
                records: group.records, adjustment: viewModel.statsAdjustment, currencyCode: defaultCurrencyCode)
            let parts = RecordsCalendarDaySummaryLogic.parts(totals)
            if !parts.isEmpty {
                // En fila «Gastaste … · Entró …»; con texto grande o en un SE, una línea por lado.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                            if index > 0 {
                                Text(verbatim: "·")
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                            daySummaryText(part)
                        }
                        Spacer(minLength: 0)
                    }
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                            daySummaryText(part)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(DS.Typography.subheadlineEmphasized)
                .padding(.top, DS.Spacing.xs)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("records_calendar_day_summary")
            }
        }
    }

    /// Solo lo que entró lleva color (colorea la excepción): el tono oscurecido, que sí vale para texto.
    private func daySummaryText(_ part: RecordsCalendarDaySummaryLogic.Part) -> some View {
        switch part {
        case .spent(let amount):
            return Text(L10n.UXL8B.daySpent(appPreferences.currency(amount, currencyCode: defaultCurrencyCode)))
                .foregroundStyle(Color.amountTint(isIncome: false))
                .fixedSize(horizontal: false, vertical: true)
        case .income(let amount):
            return Text(L10n.UXL8B.dayIncome(appPreferences.currency(amount, currencyCode: defaultCurrencyCode)))
                .foregroundStyle(Color.amountTint(isIncome: true))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// El día al que ↑↓ se limitan: el elegido en la vista calendario (`displayedGroups`), o ninguno.
    private var keyboardDay: Date? {
        recordsViewMode == .calendar ? selectedCalendarDay : nil
    }

    // MARK: - Filter Bar (panel style)

    private var filterBarPanel: some View {
        FilterControlBar(
            periodSelector: EmptyView(),                    // period vive inline en heroSummary
            viewModel: viewModel,
            accounts: accounts,
            categories: categories,
            allSubcategories: subcategories,
            tags: tags,
            animationValue: viewModel.period,
            transactionTypeFilter: viewModel.transactionTypeFilter,
            onClearTransactionType: { viewModel.transactionTypeFilter = .all },
            onFilterChange: onFilterChange,
            panelStyle: true,
            inlinePeriodSelector: false
        )
    }

    // MARK: - Period Selector (inline en la fila "Saldo · ...")

    private var periodSelector: some View {
        TrendsPeriodMenu(
            selectedPeriod: viewModel.period,
            customDateRange: sessionState.customDateRange,
            onSelect: { period in
                withTransaction(Transaction(animation: nil)) {
                    viewModel.period = period
                    sessionState.selectedPeriod = period
                }
            },
            onCustomTapped: {
                showCustomPeriodPicker = true
            }
        )
        .equatable()
    }

    // MARK: - Hero Summary

    private var heroSummary: some View {
        let hasRecords = viewModel.filteredCount > 0

        let showsFigure = !sessionState.isExpensesOnlyMode && hasRecords

        // El hero del Panel (`HeroHeader`): rótulo y período arriba, cifra y detalle debajo, a la izquierda.
        // Con poco alto (iPhone girado) va en banda: cifra y rótulo | período, entradas y salidas y recuento.
        return SummaryHeaderStack(isShort: isShortContainer, verticalPadding: summaryVerticalPadding) {
            periodSelector
        } caption: {
            // Qué es la cifra. Con un chip de naturaleza activo el otro lado es
            // 0 y `recordsSummary.balance` deja de ser un neto, así que el
            // rótulo sigue al filtro. (El hero no se pinta en solo-gastos, de
            // modo que las naturalezas efectivas son las seleccionadas.)
            if showsFigure {
                HeroHeaderLabel(text: StatsHeroCaptionLogic.records(
                    natures: viewModel.selectedTransactionNatures
                ).text)
                    .accessibilityIdentifier("stats_hero_caption")
            }
        } figure: {
            if showsFigure {
                AmountText(
                    value: recordsSummary.balance,
                    currencyCode: defaultCurrencyCode,
                    font: DS.Typography.panelHeroAmount, secondaryFont: DS.Typography.panelHeroAmountSecondary,
                    isEstimate: recordsSummary.balanceIsApproximate
                )
                .accessibilityIdentifier("records_summary_balance")
            }
        } detail: {
            incomeExpenseChips

            if let subtitle = RecordsMotivationalLogic.subtitle(forCount: viewModel.filteredCount) {
                Text(localizedMotivational(subtitle))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }

    private func localizedMotivational(_ subtitle: RecordsHeroSubtitle) -> String {
        switch subtitle {
        case .one: return L10n.Stats.Records.motivationalOne
        case .many(let n): return L10n.Stats.Records.motivationalMany(n)
        }
    }

    // MARK: - Income / Expense Chips (tap-to-filter)

    private var incomeExpenseChips: some View {
        let isIncomeFiltered = viewModel.selectedTransactionNatures == [.income]
        let isExpenseFiltered = viewModel.selectedTransactionNatures == [.expense]
        let hasNeedFilter = isIncomeFiltered || isExpenseFiltered

        // A tamaños de accesibilidad los dos importes van uno bajo otro (`AdaptiveRowStack`): en fila no
        // cabían y se cortaban por el medio («S/1,…10»).
        return AdaptiveRowStack(stackedAlignment: .center, spacing: DS.Spacing.md, stackedSpacing: DS.Spacing.xs) {
            if !sessionState.isExpensesOnlyMode {
                Button {
                    dsWithAnimation(reduceMotion) {
                        if isIncomeFiltered {
                            viewModel.selectedTransactionNatures.removeAll()
                        } else {
                            viewModel.selectedTransactionNatures = [.income]
                        }
                        onFilterChange()
                    }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.up.right")
                            .font(DS.Typography.labelSmall)
                            .foregroundStyle(Color.incomeGraph)
                            .accessibilityHidden(true)
                        AmountText(
                            value: recordsSummary.income,
                            currencyCode: defaultCurrencyCode,
                            font: DS.Typography.subheadline, secondaryFont: DS.Typography.captionSmall,
                            tint: .secondary,
                            isEstimate: recordsSummary.incomeIsApproximate
                        )
                        .accessibilityIdentifier("records_summary_income")
                    }
                    .opacity(hasNeedFilter && !isIncomeFiltered ? 0.3 : 1.0)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Accessibility.metricIncome)
                // El `accessibilityLabel` del Button TAPA la etiqueta que `AmountText` se pone a sí
                // mismo, así que sin este `accessibilityValue` VoiceOver no lee el número —ni el
                // «≈»— en un control que existe para enseñarlo.
                .accessibilityValue(appPreferences.currency(
                    recordsSummary.income, currencyCode: defaultCurrencyCode,
                    isEstimate: recordsSummary.incomeIsApproximate
                ))
            }

            Button {
                dsWithAnimation(reduceMotion) {
                    if isExpenseFiltered {
                        if !sessionState.isExpensesOnlyMode {
                            viewModel.selectedTransactionNatures.removeAll()
                        }
                    } else {
                        viewModel.selectedTransactionNatures = [.expense]
                    }
                    onFilterChange()
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "arrow.down.right")
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(Color.expenseGraph)
                        .accessibilityHidden(true)
                    AmountText(
                        value: recordsSummary.expense,
                        currencyCode: defaultCurrencyCode,
                        font: DS.Typography.subheadline, secondaryFont: DS.Typography.captionSmall,
                        tint: .secondary,
                        isEstimate: recordsSummary.expenseIsApproximate
                    )
                    .accessibilityIdentifier("records_summary_expense")
                }
                .opacity(hasNeedFilter && !isExpenseFiltered ? 0.3 : 1.0)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Accessibility.metricExpense)
            .accessibilityValue(appPreferences.currency(
                recordsSummary.expense, currencyCode: defaultCurrencyCode,
                isEstimate: recordsSummary.expenseIsApproximate
            ))
        }
    }

    private var recordsSummary: RecordsViewModel.RecordsSummary {
        viewModel.recordsSummary
    }

    // MARK: - Records List Content

    /// Grupos a mostrar: todos, o solo el día seleccionado en modo calendario.
    private var displayedGroups: [(date: Date, records: [TransactionItem])] {
        guard recordsViewMode == .calendar, let day = selectedCalendarDay else {
            return viewModel.groupedRecords
        }
        return viewModel.groupedRecords.filter {
            Calendar.current.isDate($0.date, inSameDayAs: day)
        }
    }

    @ViewBuilder
    private var recordsListContent: some View {
        let groups = displayedGroups
        if viewModel.duplicateModeActive {
            duplicateGroupsContent
        } else if groups.isEmpty {
            dayEmptyState
        } else {
            LazyVStack(spacing: DS.Spacing.sm, pinnedViews: [.sectionHeaders]) {
                ForEach(groups, id: \.date) { group in
                    Section {
                        ForEach(group.records, id: \.persistentModelID) { record in
                            RecordRowView(
                                record: record,
                                currencyCode: defaultCurrencyCode,
                                isSelectionMode: viewModel.isSelectionMode,
                                isSelected: viewModel.selectedRecordIDs.contains(
                                    record.persistentModelID),
                                onTap: {
                                    viewModel.showRecordDetail(record)
                                },
                                onToggleSelection: {
                                    viewModel.toggleSelection(record.persistentModelID)
                                }
                            )
                            .modifier(RecordRowContextMenu(record: record, viewModel: viewModel))
                        }
                    } header: {
                        RecordDateSectionView(date: group.date)
                    }
                }
            }
            .padding(.top, DS.Spacing.sm)
            // Las dos páginas que montan esta lista (Registros y Estadísticas › Registros) le ponen encima Yala IA y
            // «+»: al final del scroll, la última fila sube por encima de los dos. Dos aunque Yala IA esté oculto —
            // sobrar 68 pt al final no se ve; quedarse corto tapa el importe.
            .padding(.bottom, DS.Button.fabStackClearance(buttons: 2))
        }
    }

    // MARK: - Modo duplicados: un grupo por sección (L8-11)

    /// Los grupos que se enseñan: todos, o en la vista calendario con un día elegido, los que tienen algún registro de
    /// ese día (el grupo entero, para que se vea con qué casa).
    private var displayedDuplicateGroups: [[TransactionItem]] {
        guard recordsViewMode == .calendar, let day = selectedCalendarDay else { return viewModel.duplicateGroups }
        return viewModel.duplicateGroups.filter { group in
            group.contains { Calendar.current.isDate($0.date, inSameDayAs: day) }
        }
    }

    @ViewBuilder
    private var duplicateGroupsContent: some View {
        let groups = displayedDuplicateGroups
        if groups.isEmpty {
            duplicatesEmptyState
        } else {
            LazyVStack(spacing: DS.Spacing.sm, pinnedViews: [.sectionHeaders]) {
                ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                    Section {
                        ForEach(group, id: \.persistentModelID) { record in
                            RecordRowView(
                                record: record,
                                currencyCode: defaultCurrencyCode,
                                isSelectionMode: viewModel.isSelectionMode,
                                isSelected: viewModel.selectedRecordIDs.contains(record.persistentModelID),
                                onTap: { viewModel.showRecordDetail(record) },
                                onToggleSelection: { viewModel.toggleSelection(record.persistentModelID) }
                            )
                            .modifier(RecordRowContextMenu(record: record, viewModel: viewModel))
                        }
                    } header: {
                        DuplicateGroupHeader(records: group)
                    }
                }
            }
            .padding(.top, DS.Spacing.sm)
            .padding(.bottom, DS.Button.fabStackClearance(buttons: 2))
        }
    }

    /// «No encontramos registros repetidos» y qué se miró, según los criterios de «Coincidir por».
    private var duplicatesEmptyState: some View {
        YalaEmptyState(
            icon: "doc.on.doc",
            title: L10n.UXL8B.Duplicates.emptyTitle,
            message: duplicatesEmptyMessage,
            actionTitle: nil,
            action: nil
        )
        .accessibilityIdentifier("records_duplicates_empty")
    }

    private var duplicatesEmptyMessage: String {
        let fields = viewModel.duplicateCriteria.activeFields
        guard !fields.isEmpty, let list = duplicateFieldList(fields) else { return L10n.UXL8B.Duplicates.emptyNoCriteria }
        return L10n.UXL8B.Duplicates.emptyLooksAt(list)
    }

    /// «monto, nota, subcategoría y fecha», en el idioma de Yala.
    private func duplicateFieldList(_ fields: [RecordsDuplicateLogic.Criteria.Field]) -> String? {
        guard !fields.isEmpty else { return nil }
        let names = fields.map { field -> String in
            switch field {
            case .amount: return L10n.UXL8B.Duplicates.fieldAmount
            case .note: return L10n.UXL8B.Duplicates.fieldNote
            case .subcategory: return L10n.UXL8B.Duplicates.fieldSubcategory
            case .date: return L10n.UXL8B.Duplicates.fieldDate
            }
        }
        let formatter = ListFormatter()
        formatter.locale = AppLocale.current
        return formatter.string(from: names) ?? names.joined(separator: ", ")
    }

    /// Mini empty-state cuando el día seleccionado en el calendario no tiene registros.
    private var dayEmptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(DS.Typography.largeTitle)
                .foregroundStyle(.secondary.opacity(0.5))
                .accessibilityHidden(true)
            Text(L10n.Records.noRecordsThisDay)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.xxxl)
        .yalaSafeBottomPadding()
    }

    // MARK: - View Mode Header (toggle Lista / Calendario)

    /// Solo el selector Lista / Calendario, a la derecha. El rótulo «Registros» que iba a su izquierda repetía el
    /// título de la pantalla (o el chip de Estadísticas) y se quitó (auditoría UX 2.2, L8-1).
    private var viewModeHeader: some View {
        HStack {
            Spacer()
            viewModeSelector
        }
        // El margen lateral lo da el contentMargins del ScrollView (scrollViewGlassEdges,
        // DS.Spacing.lg). NO añadir padding horizontal propio aquí o se duplica (32pt) y el
        // header queda más adentro que la lista y que las secciones de Tendencias/Distribución.
        .accessibilityElement(children: .contain)
    }

    private var viewModeSelector: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(RecordsViewMode.allCases) { mode in
                viewModeButton(for: mode)
            }
        }
    }

    private func viewModeButton(for mode: RecordsViewMode) -> some View {
        let isSelected = recordsViewMode == mode
        return Button {
            dsWithAnimation(reduceMotion) {
                recordsViewMode = mode
                if mode == .list {
                    selectedCalendarDay = nil
                } else {
                    clampCalendarMonthIfNeeded()
                }
            }
        } label: {
            Image(systemName: mode.iconName)
                .font(DS.Typography.labelSmall)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : theme.secondaryText)
                .frame(width: 32, height: 32)
                .background {
                    if isSelected {
                        Circle()
                            .fill(theme.accent)
                            .matchedGeometryEffect(id: "recordsViewMode", in: viewModeNamespace)
                    } else {
                        Circle()
                            .fill(.thSecondaryText.opacity(0.08))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.accessibilityLabel)
        .accessibilityIdentifier("records_view_mode_\(mode.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Calendar State

    /// Pone el mes visible (modo paginado) en el mes más reciente con datos.
    private func syncCalendarMonth() {
        guard let maxDate = viewModel.groupedRecords.map(\.date).max() else { return }
        calendarMonth = Calendar.current.startOfDay(for: maxDate)
    }

    /// Si tras cambiar filtros el mes visible quedó fuera del rango de datos, lo reencuadra.
    private func clampCalendarMonthIfNeeded() {
        let dates = viewModel.groupedRecords.map(\.date)
        guard let minDate = dates.min(), let maxDate = dates.max() else { return }
        let cal = Calendar.current
        if calendarMonth < cal.startOfDay(for: minDate) || calendarMonth > maxDate {
            calendarMonth = cal.startOfDay(for: maxDate)
        }
    }

    /// Al cambiar de periodo: limpia el día seleccionado y reencuadra el mes.
    private func resetCalendarState() {
        selectedCalendarDay = nil
        syncCalendarMonth()
    }

    // MARK: - Empty State Content

    @ViewBuilder
    private var emptyStateContent: some View {
        if viewModel.duplicateModeActive {
            // Modo duplicados sin resultados: el encabezado de arriba sigue visible para desactivar.
            duplicatesEmptyState
        } else {
            YalaEmptyState(
                icon: "list.bullet.rectangle",
                title: L10n.Records.noRecords,
                message: viewModel.hasActiveFilters
                    ? L10n.Statistics.noRecordsFiltered
                    : L10n.Statistics.noRecordsDescription,
                actionTitle: viewModel.hasActiveFilters ? L10n.Filters.clearFilters : nil,
                action: viewModel.hasActiveFilters ? {
                    viewModel.clearFilters()
                    onFilterChange()
                } : nil
            )
        }
    }
}

// MARK: - Duplicate Mode Header

/// Encabezado del modo «Identificar duplicados» (L8-11): sustituye al resumen del período mientras el modo está
/// activo. Dice cuántos posibles duplicados hay y en cuántos grupos, ofrece «Quitar repetidos» y deja salir del modo.
/// Lleva el selector de período porque la búsqueda mira dentro de él.
private struct DuplicateModeHeader<Period: View>: View {
    let tally: RecordsDuplicateLogic.Tally
    let onRemove: () -> Void
    let onDeactivate: () -> Void
    @ViewBuilder let period: () -> Period

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .center, spacing: DS.Spacing.sm) {
                period()
                Spacer(minLength: DS.Spacing.sm)
                Button(action: onDeactivate) {
                    Label(L10n.Records.Duplicates.deactivate, systemImage: "xmark.circle.fill")
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.thPrimaryText)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("records_duplicates_deactivate")
            }

            Label {
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "doc.on.doc")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("records_duplicates_header")

            if tally.groups > 0 {
                YalaSecondaryButton(L10n.UXL8B.Duplicates.remove, icon: "trash", destructive: true, action: onRemove)
                    .accessibilityIdentifier("records_duplicates_remove")
            }
        }
        .padding(DS.Spacing.lg)
        .solidCard(radius: DS.Radius.lg)
        // Sin padding horizontal externo: el margen lo da el contentMargins del ScrollView
        // (16pt), igual que las filas de la lista. Añadirlo aquí duplicaría el margen (32pt).
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        guard tally.groups > 0 else { return L10n.Records.Duplicates.bannerTitle }
        return L10n.UXL8B.Duplicates.header(duplicates: tally.duplicates, groups: tally.groups)
    }
}

// MARK: - Duplicate Group Header

/// Cabecera de cada grupo de duplicados: cuántos casan, cuál se queda al quitar repetidos y, si comparten día, cuál.
private struct DuplicateGroupHeader: View {
    private static var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
        return formatter
    }

    let records: [TransactionItem]

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            Text("\(L10n.UXL8B.Duplicates.groupSize(records.count)) · \(L10n.UXL8B.Duplicates.keepsFirst)")
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: DS.Spacing.sm)
            if let sharedDay {
                Text(Self.dayFormatter.string(from: sharedDay))
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// El día, si todos los del grupo son del mismo (con «Fecha» fuera de los criterios pueden no serlo).
    private var sharedDay: Date? {
        guard let first = records.first?.date else { return nil }
        let calendar = Calendar.current
        return records.allSatisfy { calendar.isDate($0.date, inSameDayAs: first) } ? first : nil
    }
}
