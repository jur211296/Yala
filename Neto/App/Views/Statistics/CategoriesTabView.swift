//
//  CategoriesTabView.swift
//  Neto
//
//  Categories tab content with carousel for Categories and Subcategories pie charts.
//

import Charts
import SwiftData
import SwiftUI

/// Categories tab content view.
/// Displays category and subcategory spending breakdown with carousel and filters.
struct CategoriesTabView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState

    // MARK: - Data Queries

    @Query(sort: \Account.name, order: .forward) private var accounts: [Account]
    @Query(sort: \Category.name, order: .forward) private var categories: [Category]
    @Query(sort: \Subcategory.name, order: .forward) private var allSubcategories: [Subcategory]
    @Query(sort: \Tag.name, order: .forward) private var tags: [Tag]
    @Query(sort: \TransactionItem.date, order: .reverse) private var allTransactions:
        [TransactionItem]

    // MARK: - External Dependencies

    @Bindable var viewModel: StatisticsViewModel
    let defaultCurrencyCode: String
    let onNavigateToRecords: () -> Void

    // MARK: - State

    @State private var categorySpending: [CategorySpendingSummary] = []
    @State private var subcategorySpending: [SubcategorySpendingSummary] = []
    @State private var tagSpending: [TagSpendingSummary] = []
    @State private var natureTrendPoints: [NatureTrendPoint] = []
    @State private var selectedCategoryID: PersistentIdentifier?
    @State private var selectedSubcategoryID: PersistentIdentifier?
    @State private var selectedNature: SubcategoryNature?
    @State private var carouselIndex: Int? = 0
    @State private var listViewType: ListViewType = .categories
    @State private var isListExpanded: Bool = false
    @State private var isSubcategoriesAutomatic: Bool = false  // Track if switch was automatic
    @State private var showCustomPeriodPicker: Bool = false  // Custom period picker sheet
    @State private var isSyncingFilters: Bool = false  // Anti-loop flag for sync functions
    @Namespace private var listSelectorNamespace

    // MARK: - List View Type

    enum ListViewType: String, CaseIterable, Identifiable {
        case categories
        case subcategories

        var id: String { rawValue }

        var title: String {
            switch self {
            case .categories: return L10n.ListViewType.categories
            case .subcategories: return L10n.ListViewType.subcategories
            }
        }

        var iconName: String {
            switch self {
            case .categories: return "square.grid.2x2.fill"
            case .subcategories: return "list.bullet.indent"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                controlBar
                chartsCarousel
                natureWidget
                categoriesListSection
                recentRecordsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .onAppear {
            calculateData()
        }
        .onChange(of: viewModel.detailPeriod) {
            calculateData()
        }
        .onChange(of: viewModel.selectedAccounts) {
            calculateData()
        }
        .onChange(of: viewModel.selectedCategories) {
            calculateData()
            syncCategoryFilterToSelection()
        }
        .onChange(of: viewModel.selectedSubcategories) {
            calculateData()
            syncSubcategoryFilterToSelection()
        }
        .onChange(of: viewModel.selectedTags) {
            calculateData()
        }
        .onChange(of: viewModel.selectedNatures) {
            calculateData()
            syncNatureFilterToSelection()
        }
        .onChange(of: selectedCategoryID) {
            syncSelectionToCategoryFilter()
            calculateData()
        }
        .onChange(of: selectedSubcategoryID) {
            syncSelectionToSubcategoryFilter()
            calculateData()
        }
        .onChange(of: selectedNature) {
            syncSelectionToNatureFilter()
            calculateData()
        }
        .onChange(of: sessionState.customDateRange) {
            // Sync custom date range and recalculate
            viewModel.syncCustomRangeFromSessionState(sessionState)
            calculateData()
        }
        .sheet(isPresented: $showCustomPeriodPicker) {
            CustomPeriodPickerSheet(
                minDate: transactionDateRange.start,
                maxDate: transactionDateRange.end,
                currentRange: sessionState.customDateRange
            )
        }
    }

    /// Date range of all transactions (for custom period picker limits)
    private var transactionDateRange: (start: Date, end: Date) {
        let sortedDates = allTransactions.map(\.date).sorted()
        let start = sortedDates.first ?? Date()
        let end = sortedDates.last ?? Date()
        return (start, end)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 12) {
            periodSelector

            if hasActiveFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Account chips (with icon)
                        ForEach(selectedAccountChips, id: \.id) { chip in
                            FilterChipView(
                                accountName: chip.name,
                                count: chip.count,
                                onClear: {
                                    viewModel.selectedAccounts.removeAll()
                                }
                            )
                        }

                        // Category chip (aggregated - one chip max)
                        if let catChip = aggregatedCategoryChip(
                            selectedSubcategories: viewModel.selectedSubcategories,
                            allSubcategories: allSubcategories
                        ) {
                            FilterChipView(
                                categoryName: catChip.name,
                                iconName: catChip.iconName,
                                colorHex: catChip.colorHex,
                                count: catChip.count,
                                onClear: {
                                    viewModel.selectedCategories.removeAll()
                                    viewModel.selectedSubcategories.removeAll()
                                    selectedCategoryID = nil
                                }
                            )
                        }

                        // Subcategory chip (aggregated - one chip max)
                        if let subChip = aggregatedSubcategoryChip(
                            selectedSubcategories: viewModel.selectedSubcategories,
                            allSubcategories: allSubcategories
                        ) {
                            FilterChipView(
                                subcategoryName: subChip.name,
                                iconName: subChip.iconName,
                                colorHex: subChip.colorHex,
                                count: subChip.count,
                                onClear: {
                                    viewModel.selectedSubcategories.removeAll()
                                    selectedSubcategoryID = nil
                                }
                            )
                        }

                        // Tag chips (individual with color dots)
                        ForEach(selectedTagChips, id: \.id) { chip in
                            FilterChipView(
                                tagName: chip.name,
                                colorHex: chip.colorHex,
                                onClear: {
                                    viewModel.selectedTags.remove(chip.tagID)
                                }
                            )
                        }

                        // Nature chips (individual with color dots)
                        ForEach(Array(viewModel.selectedNatures), id: \.rawValue) { nature in
                            FilterChipView(
                                nature: nature,
                                onClear: {
                                    viewModel.selectedNatures.remove(nature)
                                }
                            )
                        }

                        // Currency chips
                        ForEach(Array(viewModel.selectedCurrencies), id: \.self) { currency in
                            FilterChipView(
                                currencyCode: currency.rawValue,
                                onClear: {
                                    viewModel.selectedCurrencies.remove(currency)
                                    sessionState.selectedCurrencies.remove(currency)
                                }
                            )
                        }

                        // Amount chip
                        if viewModel.amountCondition.isActive {
                            FilterChipView(
                                amountText: viewModel.amountCondition.displayText,
                                onClear: {
                                    viewModel.amountCondition = .any
                                    sessionState.amountCondition = .any
                                }
                            )
                        }

                        // Search/Note chip
                        if !viewModel.searchText.isEmpty {
                            FilterChipView(
                                noteText: viewModel.searchText,
                                onClear: {
                                    viewModel.searchText = ""
                                    sessionState.searchText = ""
                                }
                            )
                        }

                        // Clear all button
                        if activeFilterCount > 1 {
                            Button {
                                withAnimation {
                                    clearAllFilters()
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .animation(nil, value: viewModel.detailPeriod)
    }

    private var periodSelector: some View {
        TrendsPeriodMenu(
            selectedPeriod: viewModel.detailPeriod,
            customDateRange: sessionState.customDateRange,
            onSelect: { period in
                sessionState.selectedPeriod = period
            },
            onCustomTapped: {
                showCustomPeriodPicker = true
            }
        )
        .equatable()
    }

    // MARK: - Charts Carousel

    private var chartsCarousel: some View {
        VStack(spacing: DS.Spacing.sm) {
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let spacing: CGFloat = DS.Spacing.md
                let cardWidth = totalWidth

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: spacing) {
                        // Categories Chart
                        categoryChartCard
                            .frame(width: cardWidth)

                        // Subcategories Chart
                        subcategoryChartCard
                            .frame(width: cardWidth)

                        // Tags Chart
                        tagChartCard
                            .frame(width: cardWidth)
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $carouselIndex)
                .frame(width: totalWidth)
            }
            .frame(height: 340)

            // Page indicator
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { page in
                    Circle()
                        .fill(
                            page == (carouselIndex ?? 0)
                                ? Color.netoPrimaryText.opacity(0.3)
                                : Color.netoSecondaryText.opacity(0.2)
                        )
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Category Chart Card

    private var categoryChartCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if categorySpending.isEmpty {
                emptyState(
                    icon: "chart.pie",
                    title: L10n.Statistics.noCategoryData,
                    subtitle: L10n.Statistics.noExpensesInPeriod
                )
                .frame(height: 320)
            } else {
                CategoriesPieWidget(
                    categories: categorySpending,
                    currencyCode: defaultCurrencyCode,
                    selectedCategoryID: selectedCategoryID,
                    onSelectCategory: { categoryID in
                        if selectedCategoryID == categoryID {
                            selectedCategoryID = nil
                        } else {
                            selectedCategoryID = categoryID
                        }
                    },
                    size: .large
                )
            }
        }
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
    }

    // MARK: - Subcategory Chart Card

    private var subcategoryChartCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if subcategorySpending.isEmpty {
                emptyState(
                    icon: "chart.pie",
                    title: L10n.Statistics.noSubcategoryData,
                    subtitle: L10n.Statistics.noExpensesInPeriod
                )
                .frame(height: 320)
            } else {
                SubcategoriesPieWidget(
                    subcategories: subcategorySpending,
                    currencyCode: defaultCurrencyCode,
                    selectedCategoryID: selectedCategoryID,
                    selectedSubcategoryIDs: selectedSubcategoryID.map { Set([$0]) } ?? [],
                    onSelectSubcategory: { subcategoryID in
                        if selectedSubcategoryID == subcategoryID {
                            selectedSubcategoryID = nil
                        } else {
                            selectedSubcategoryID = subcategoryID
                        }
                    },
                    size: .large
                )
            }
        }
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
    }

    // MARK: - Tag Chart Card

    private var tagChartCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if tagSpending.isEmpty {
                emptyState(
                    icon: "tag",
                    title: L10n.Empty.noTags,
                    subtitle: L10n.Statistics.noExpensesInPeriod
                )
                .frame(height: 320)
            } else {
                TagsPieWidget(
                    tags: tagSpending,
                    currencyCode: defaultCurrencyCode,
                    selectedTagID: nil,
                    onSelectTag: { _ in },
                    size: .large
                )
            }
        }
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
    }

    // MARK: - Nature Widget

    private var natureWidget: some View {
        NatureTrendWidget(
            trendPoints: natureTrendPoints,
            selectedNature: selectedNature,
            currencyCode: defaultCurrencyCode,
            size: .large,
            grouping: natureGrouping,
            interval: viewModel.panelDateInterval,
            onSelectNature: { nature in
                if selectedNature == nature {
                    selectedNature = nil
                } else {
                    selectedNature = nature
                }
            },
            onShowDetail: nil
        )
    }

    /// Determine grouping for nature widget based on selected period
    /// Matches PanelViewModel logic for consistent bar chart grouping
    private var natureGrouping: TrendGrouping {
        switch viewModel.detailPeriod {
        case .thisWeek, .last7Days:
            return .day  // Daily bars for week
        case .thisMonth, .lastMonth, .last30Days:
            return .day  // Daily bars for month
        case .thisYear, .lastYear, .allTime, .custom:
            return .month  // Monthly bars for year/all-time/custom
        }
    }

    // MARK: - Categories List Section

    private var categoriesListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with title and selector
            HStack(alignment: .center) {
                Text(
                    listViewType == .categories
                        ? L10n.Statistics.topCategories : L10n.Statistics.topSubcategories
                )
                .font(.headline)
                .foregroundStyle(.primary)

                Spacer()

                listViewSelector
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)

            // Content based on selected view type
            if listViewType == .categories {
                if categorySpending.isEmpty {
                    emptyState(
                        icon: "chart.bar.xaxis",
                        title: L10n.Empty.noCategories,
                        subtitle: L10n.Statistics.noDataToShow
                    )
                    .frame(height: 200)
                } else {
                    AllCategoriesListContent(
                        categories: categorySpending,
                        currencyCode: defaultCurrencyCode,
                        selectedCategoryID: selectedCategoryID,
                        isExpanded: isListExpanded,
                        onToggleExpanded: { isListExpanded.toggle() },
                        onSelectCategory: { categoryID in
                            if selectedCategoryID == categoryID {
                                selectedCategoryID = nil
                            } else {
                                selectedCategoryID = categoryID
                            }
                        }
                    )
                }
            } else {
                if subcategorySpending.isEmpty {
                    emptyState(
                        icon: "list.bullet.indent",
                        title: L10n.Empty.noSubcategories,
                        subtitle: L10n.Statistics.noDataToShow
                    )
                    .frame(height: 200)
                } else {
                    AllSubcategoriesListContent(
                        subcategories: subcategorySpending,
                        currencyCode: defaultCurrencyCode,
                        selectedCategoryID: selectedCategoryID,
                        selectedSubcategoryID: selectedSubcategoryID,
                        isExpanded: isListExpanded,
                        onToggleExpanded: { isListExpanded.toggle() },
                        onSelectSubcategory: { subcategoryID in
                            if selectedSubcategoryID == subcategoryID {
                                selectedSubcategoryID = nil
                            } else {
                                selectedSubcategoryID = subcategoryID
                            }
                        }
                    )
                }
            }
        }
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
    }

    private var listViewSelector: some View {
        HStack(spacing: 0) {
            ForEach(ListViewType.allCases) { viewType in
                listViewButton(for: viewType)
            }
        }
        .padding(3)
        .background(Color.netoSecondaryText.opacity(0.08))
        .clipShape(Capsule())
    }

    private func listViewButton(for viewType: ListViewType) -> some View {
        let isSelected = listViewType == viewType
        let isLocked = shouldLockToSubcategories

        return Button {
            // Only allow change if not locked to subcategories
            // OR if trying to switch to subcategories (always allowed)
            guard !isLocked || viewType == .subcategories else { return }

            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                setListViewManually(viewType)
            }
        } label: {
            Image(systemName: viewType.iconName)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : Color.netoSecondaryText)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(Color.electricIndigo)
                                .matchedGeometryEffect(
                                    id: "listSelector", in: listSelectorNamespace)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .opacity((isLocked && viewType == .categories) ? 0.4 : 1.0)  // Dim locked button
        .disabled(isLocked && viewType == .categories)  // Disable locked button
    }

    // MARK: - List View Auto-switching Logic

    /// Determines if list view should be locked to subcategories
    private var shouldLockToSubcategories: Bool {
        !viewModel.selectedCategories.isEmpty
    }

    /// Enforce list view lock logic based on current category filter
    private func enforceListViewLock() {
        if shouldLockToSubcategories {
            // Lock to subcategories when category filter is applied (automatic)
            if listViewType != .subcategories {
                listViewType = .subcategories
                isSubcategoriesAutomatic = true
            }
        } else {
            // When category filter is cleared, reset to categories ONLY if switch was automatic
            if listViewType == .subcategories && isSubcategoriesAutomatic {
                listViewType = .categories
                isSubcategoriesAutomatic = false
            }
        }
    }

    /// Called when user manually selects a list view type
    private func setListViewManually(_ type: ListViewType) {
        listViewType = type
        // Mark as manual selection (not automatic)
        isSubcategoriesAutomatic = false
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.Card.padding)
    }

    // MARK: - Data Calculation

    private func calculateData() {
        let interval = viewModel.panelDateInterval

        // Build filter criteria
        let criteria = FilterCriteria(
            selectedAccounts: viewModel.selectedAccounts,
            selectedCategories: viewModel.selectedCategories,
            selectedSubcategories: viewModel.selectedSubcategories,
            selectedTags: viewModel.selectedTags,
            selectedNatures: viewModel.selectedNatures,
            selectedCurrencies: viewModel.selectedCurrencies,
            transactionTypeFilter: .all,
            amountCondition: viewModel.amountCondition,
            searchText: viewModel.searchText,
            dateInterval: interval
        )

        // Filter transactions
        let filtered = FilterService.filterForTrends(
            transactions: allTransactions,
            accounts: accounts,
            criteria: criteria
        )

        // Calculate category spending
        categorySpending = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: filtered,
            interval: interval,
            currencyCode: defaultCurrencyCode,
            context: modelContext
        )

        // Calculate subcategory spending (show ALL subcategories, filter applied via opacity in UI)
        subcategorySpending = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: filtered,
            interval: interval,
            currencyCode: defaultCurrencyCode,
            categoryFilter: nil,  // Don't filter here, show all with opacity
            context: modelContext
        )

        // Calculate tag spending
        tagSpending = calculateTagSpending(
            transactions: filtered,
            interval: interval,
            currencyCode: defaultCurrencyCode
        )

        // Calculate nature trend data with correct grouping based on period
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCode) ?? .pen
        natureTrendPoints = NatureTrendHelper.calculateTrend(
            transactions: filtered,
            grouping: natureGrouping,
            interval: interval,
            preferredCurrency: preferredCurrency,
            context: modelContext
        )

        // Apply list view lock logic after data calculation
        enforceListViewLock()
    }

    // MARK: - Filter Synchronization

    /// Sync chart selection to ViewModel filters (chart -> top filters)
    private func syncSelectionToCategoryFilter() {
        guard !isSyncingFilters else { return }
        isSyncingFilters = true
        defer { isSyncingFilters = false }

        if let categoryID = selectedCategoryID {
            // Add to ViewModel's selected categories if not already there
            if !viewModel.selectedCategories.contains(categoryID) {
                viewModel.selectedCategories.insert(categoryID)
            }
            // Clear subcategory selection when category changes
            selectedSubcategoryID = nil
            viewModel.selectedSubcategories.removeAll()
        } else {
            // If deselected, remove from ViewModel
            // But only if it was the only one selected
            if viewModel.selectedCategories.count == 1 {
                viewModel.selectedCategories.removeAll()
            }
        }
    }

    private func syncSelectionToSubcategoryFilter() {
        guard !isSyncingFilters else { return }
        isSyncingFilters = true
        defer { isSyncingFilters = false }

        if let subcategoryID = selectedSubcategoryID {
            // Find the subcategory by persistentID
            if let subcategory = subcategorySpending.first(where: { $0.persistentID == subcategoryID })?
                .subcategory
            {
                if !viewModel.selectedSubcategories.contains(subcategory.persistentModelID) {
                    viewModel.selectedSubcategories.insert(subcategory.persistentModelID)
                }
                // Also ensure parent category is selected
                let parentCategory = subcategory.category
                if !viewModel.selectedCategories.contains(parentCategory.persistentModelID) {
                    viewModel.selectedCategories.insert(parentCategory.persistentModelID)
                }
                selectedCategoryID = parentCategory.persistentModelID
            }
        } else {
            // If deselected subcategory, remove from ViewModel
            if viewModel.selectedSubcategories.count == 1 {
                viewModel.selectedSubcategories.removeAll()
            }
        }
    }

    /// Sync ViewModel filters to chart selection (top filters -> chart)
    private func syncCategoryFilterToSelection() {
        guard !isSyncingFilters else { return }
        isSyncingFilters = true
        defer { isSyncingFilters = false }

        if viewModel.selectedCategories.count == 1 {
            selectedCategoryID = viewModel.selectedCategories.first
        } else if viewModel.selectedCategories.isEmpty {
            selectedCategoryID = nil
        }
    }

    private func syncSubcategoryFilterToSelection() {
        guard !isSyncingFilters else { return }
        isSyncingFilters = true
        defer { isSyncingFilters = false }

        if viewModel.selectedSubcategories.count == 1 {
            // Find the subcategory name from the ID
            if let subcategoryID = viewModel.selectedSubcategories.first,
                let subcategory = subcategorySpending.first(where: {
                    $0.subcategory?.persistentModelID == subcategoryID
                })
            {
                selectedSubcategoryID = subcategory.persistentID
            }
        } else if viewModel.selectedSubcategories.isEmpty {
            selectedSubcategoryID = nil
        }
    }

    private func syncSelectionToNatureFilter() {
        guard !isSyncingFilters else { return }
        isSyncingFilters = true
        defer { isSyncingFilters = false }

        if let nature = selectedNature {
            // Add to ViewModel's selected natures if not already there
            if !viewModel.selectedNatures.contains(nature) {
                viewModel.selectedNatures.insert(nature)
            }
        } else {
            // If deselected, remove from ViewModel
            if viewModel.selectedNatures.count == 1 {
                viewModel.selectedNatures.removeAll()
            }
        }
    }

    private func syncNatureFilterToSelection() {
        guard !isSyncingFilters else { return }
        isSyncingFilters = true
        defer { isSyncingFilters = false }

        if viewModel.selectedNatures.count == 1 {
            selectedNature = viewModel.selectedNatures.first
        } else if viewModel.selectedNatures.isEmpty {
            selectedNature = nil
        }
    }

    // MARK: - Recent Records Section

    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Statistics.latestRecords)
                .font(.headline)
                .foregroundStyle(Color.netoPrimaryText)

            if viewModel.recentRecords.isEmpty {
                emptyRecordsState
            } else {
                ForEach(viewModel.recentRecords.prefix(5), id: \.persistentModelID) { record in
                    CompactRecordRow(record: record, currencyCode: defaultCurrencyCode)
                }
            }

            Button {
                onNavigateToRecords()
            } label: {
                HStack {
                    Spacer()
                    Text(L10n.Action.viewAll)
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption)
                    Spacer()
                }
                .padding(.vertical, 12)
                .foregroundStyle(Color.electricIndigo)
                .background(Color.electricIndigo.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Card.padding)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
    }

    private var emptyRecordsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(L10n.Statistics.noRecords)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func clearAllFilters() {
        viewModel.clearFilters()
        selectedCategoryID = nil
        selectedSubcategoryID = nil
        selectedNature = nil
    }

    // MARK: - Chip Data Structures

    private struct CategoryChip: Identifiable {
        let id = UUID()
        let categoryID: PersistentIdentifier
    }

    private struct SubcategoryChip: Identifiable {
        let id: String
        let name: String
        let iconName: String?
        let colorHex: String?
        let subcategoryID: PersistentIdentifier?
    }

    private var selectedCategoryChips: [CategoryChip] {
        var chips: [CategoryChip] = []

        // From ViewModel
        for categoryID in viewModel.selectedCategories {
            chips.append(CategoryChip(categoryID: categoryID))
        }

        // From local selection (if not already in ViewModel)
        if let localCategoryID = selectedCategoryID,
            !viewModel.selectedCategories.contains(localCategoryID)
        {
            chips.append(CategoryChip(categoryID: localCategoryID))
        }

        return chips
    }

    private var selectedSubcategoryChips: [SubcategoryChip] {
        var chips: [SubcategoryChip] = []

        // From ViewModel - use allSubcategories Query to find details
        for subcategoryID in viewModel.selectedSubcategories {
            if let subcategory = allSubcategories.first(where: {
                $0.persistentModelID == subcategoryID
            }) {
                let categoryColor = subcategory.category.colorHex
                chips.append(
                    SubcategoryChip(
                        id: subcategory.name,
                        name: subcategory.name,
                        iconName: subcategory.iconName,
                        colorHex: (subcategory.colorHex?.isEmpty == false
                            ? subcategory.colorHex : nil) ?? categoryColor,
                        subcategoryID: subcategoryID
                    ))
            }
        }

        // From local selection (if not already added via ViewModel)
        if let localSubcategoryID = selectedSubcategoryID,
            !viewModel.selectedSubcategories.contains(localSubcategoryID),
            let summary = subcategorySpending.first(where: { $0.persistentID == localSubcategoryID })
        {
            chips.append(
                SubcategoryChip(
                    id: summary.id,
                    name: summary.subcategoryName,
                    iconName: summary.subcategory?.iconName,
                    colorHex: summary.colorHex,
                    subcategoryID: summary.subcategory?.persistentModelID
                ))
        }

        return chips
    }

    // MARK: - Tag Chip Data

    private struct TagChip: Identifiable {
        let id: PersistentIdentifier
        let tagID: PersistentIdentifier
        let name: String
        let colorHex: String?
    }

    private var selectedTagChips: [TagChip] {
        tags.filter { viewModel.selectedTags.contains($0.persistentModelID) }
            .map {
                TagChip(
                    id: $0.persistentModelID, tagID: $0.persistentModelID, name: $0.name,
                    colorHex: $0.colorHex)
            }
    }

    // MARK: - Filter Helpers

    private var hasActiveFilters: Bool {
        viewModel.hasActiveFilters || selectedCategoryID != nil || selectedSubcategoryID != nil
    }

    private var activeFilterCount: Int {
        var count = 0
        if !viewModel.selectedAccounts.isEmpty { count += 1 }
        if !viewModel.selectedCategories.isEmpty || selectedCategoryID != nil { count += 1 }
        if !viewModel.selectedSubcategories.isEmpty || selectedSubcategoryID != nil { count += 1 }
        if !viewModel.selectedTags.isEmpty { count += 1 }
        if !viewModel.selectedNatures.isEmpty { count += 1 }
        return count
    }

    // MARK: - Chip Helpers

    private struct AccountChip: Identifiable {
        let id = UUID()
        let name: String
        let count: Int
    }

    private var selectedAccountChips: [AccountChip] {
        guard !viewModel.selectedAccounts.isEmpty else { return [] }
        let selectedAccountsList =
            accounts
            .filter { viewModel.selectedAccounts.contains($0.persistentModelID) }
        guard !selectedAccountsList.isEmpty else { return [] }

        // Return a single chip with the first account name and total count
        if let firstName = selectedAccountsList.first?.name {
            return [AccountChip(name: firstName, count: selectedAccountsList.count)]
        }
        return []
    }

    private var tagsChipText: String? {
        guard !viewModel.selectedTags.isEmpty else { return nil }
        let names = tags.filter { viewModel.selectedTags.contains($0.persistentModelID) }.map {
            $0.name
        }
        guard !names.isEmpty else { return nil }
        return names.count == 1 ? names.first : "\(names.first ?? "") +\(names.count - 1)"
    }

    private var naturesChipText: String? {
        guard !viewModel.selectedNatures.isEmpty else { return nil }
        let names = viewModel.selectedNatures.map { $0.displayName }
        return names.count == 1 ? names.first : "\(names.first ?? "") +\(names.count - 1)"
    }

    // MARK: - Tag Spending Calculator

    private func calculateTagSpending(
        transactions: [TransactionItem],
        interval: DateInterval,
        currencyCode: String
    ) -> [TagSpendingSummary] {
        let expenseTransactions = transactions.filter { transaction in
            guard let category = transaction.category, !category.isIncome else { return false }
            guard !transaction.tags.isEmpty else { return false }
            return interval.contains(transaction.date)
        }

        var tagTotals: [PersistentIdentifier: Double] = [:]
        var tagMap: [PersistentIdentifier: Tag] = [:]

        for transaction in expenseTransactions {
            let absAmount = abs(transaction.amountInPreferredCurrency)
            for tag in transaction.tags {
                let tagID = tag.persistentModelID
                tagTotals[tagID, default: 0] += absAmount
                tagMap[tagID] = tag
            }
        }

        let totalExpense = tagTotals.values.reduce(0, +)
        let sortedTags = tagTotals.sorted { $0.value > $1.value }

        return sortedTags.compactMap { (id, amount) -> TagSpendingSummary? in
            guard let tag = tagMap[id] else { return nil }
            let percentage = totalExpense > 0 ? (amount / totalExpense) * 100 : 0
            return TagSpendingSummary(tag: tag, amount: amount, percentage: percentage)
        }
    }
}

// MARK: - All Categories List Content

/// Widget that displays all categories (not limited) in a list format
private struct AllCategoriesListContent: View {
    let categories: [CategorySpendingSummary]
    let currencyCode: String
    var selectedCategoryID: PersistentIdentifier?
    var isExpanded: Bool
    var onToggleExpanded: (() -> Void)?
    var onSelectCategory: ((PersistentIdentifier) -> Void)?

    private var displayedCategories: [CategorySpendingSummary] {
        isExpanded ? categories : Array(categories.prefix(10))
    }

    private var showExpandButton: Bool {
        categories.count > 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let maxAmount = categories.first?.amount {
                ForEach(displayedCategories) { summary in
                    let isSelected = selectedCategoryID == summary.category.persistentModelID
                    let isAnySelected = selectedCategoryID != nil
                    let shouldDim = isAnySelected && !isSelected

                    CategoryRowView(
                        summary: summary,
                        maxAmount: maxAmount,
                        currencyCode: currencyCode
                    )
                    .opacity(shouldDim ? 0.3 : 1.0)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelectCategory?(summary.category.persistentModelID)
                    }
                }

                if showExpandButton {
                    Button {
                        onToggleExpanded?()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isExpanded ? L10n.Action.viewLess : L10n.Action.viewAll)
                                .font(.subheadline.weight(.semibold))
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .foregroundStyle(Color.electricIndigo)
                        .background(Color.electricIndigo.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - All Subcategories List Content

/// Widget that displays all subcategories (not limited) in a list format
private struct AllSubcategoriesListContent: View {
    let subcategories: [SubcategorySpendingSummary]
    let currencyCode: String
    var selectedCategoryID: PersistentIdentifier?
    var selectedSubcategoryID: PersistentIdentifier?
    var isExpanded: Bool
    var onToggleExpanded: (() -> Void)?
    var onSelectSubcategory: ((PersistentIdentifier) -> Void)?

    private var displayedSubcategories: [SubcategorySpendingSummary] {
        isExpanded ? subcategories : Array(subcategories.prefix(10))
    }

    private var showExpandButton: Bool {
        subcategories.count > 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let maxAmount = subcategories.first?.amount {
                ForEach(displayedSubcategories) { summary in
                    let isSelected = selectedSubcategoryID == summary.persistentID
                    let isAnySelected = selectedSubcategoryID != nil

                    // Check if this subcategory belongs to the selected category
                    let belongsToSelectedCategory =
                        selectedCategoryID == nil
                        || summary.category?.persistentModelID == selectedCategoryID

                    // Dim if:
                    // 1. There's a subcategory selected and this isn't it, OR
                    // 2. There's a category selected and this subcategory doesn't belong to it
                    let shouldDim = (isAnySelected && !isSelected) || !belongsToSelectedCategory

                    SubcategoryRowView(
                        summary: summary,
                        maxAmount: maxAmount,
                        currencyCode: currencyCode
                    )
                    .opacity(shouldDim ? 0.3 : 1.0)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let persistentID = summary.persistentID {
                            onSelectSubcategory?(persistentID)
                        }
                    }
                }

                if showExpandButton {
                    Button {
                        onToggleExpanded?()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isExpanded ? L10n.Action.viewLess : L10n.Action.viewAll)
                                .font(.subheadline.weight(.semibold))
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .foregroundStyle(Color.electricIndigo)
                        .background(Color.electricIndigo.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - Category Row Component

private struct CategoryRowView: View {
    let summary: CategorySpendingSummary
    let maxAmount: Double
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            // Icon Circle
            ZStack {
                Circle()
                    .fill(Color(hex: summary.category.colorHex))
                    .frame(width: 40, height: 40)

                Image(systemName: summary.category.iconName ?? "tag.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Name and Amount
                HStack {
                    Text(summary.category.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(NetoFormatter.currency(value: summary.amount, currencyCode: currencyCode))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                }

                // Bar and Percentage
                VStack(alignment: .leading, spacing: 4) {
                    // Percentage Text
                    Text("\(formattedPercentage(summary.percentage)) \(L10n.Statistics.ofExpense)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    // Bar
                    GeometryReader { geo in
                        let width =
                            maxAmount > 0 ? (summary.amount / maxAmount) * geo.size.width : 0

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 6)

                            Capsule()
                                .fill(Color(hex: summary.category.colorHex))
                                .frame(width: width, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
    }

    private func formattedPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }
}

// MARK: - Subcategory Row Component

private struct SubcategoryRowView: View {
    let summary: SubcategorySpendingSummary
    let maxAmount: Double
    let currencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            // Icon Circle
            ZStack {
                Circle()
                    .fill(Color(hex: summary.colorHex ?? "#6366F1"))
                    .frame(width: 40, height: 40)

                if let subcategory = summary.subcategory {
                    Image(systemName: subcategory.iconName ?? "list.bullet.indent")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "list.bullet.indent")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                // Name and Amount
                HStack {
                    Text(summary.subcategoryName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(NetoFormatter.currency(value: summary.amount, currencyCode: currencyCode))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                }

                // Bar and Percentage
                VStack(alignment: .leading, spacing: 4) {
                    // Percentage Text
                    Text("\(formattedPercentage(summary.percentageOfTotal)) \(L10n.Statistics.ofExpense)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    // Bar
                    GeometryReader { geo in
                        let width =
                            maxAmount > 0 ? (summary.amount / maxAmount) * geo.size.width : 0

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 6)

                            Capsule()
                                .fill(Color(hex: summary.colorHex ?? "#6366F1"))
                                .frame(width: width, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
    }

    private func formattedPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }
}
