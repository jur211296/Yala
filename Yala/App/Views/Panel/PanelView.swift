//
//  PanelView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI
import UIKit

// MARK: - Panel (pantalla de inicio)

struct PanelView: View {

    init() {
        // Eliminamos el fondo gris por defecto del TabView en modo página
        let pageViewBackground = UIView.appearance(
            whenContainedInInstancesOf: [UIPageViewController.self]
        )
        pageViewBackground.backgroundColor = .clear

        let scrollViewBackground = UIScrollView.appearance(
            whenContainedInInstancesOf: [UIPageViewController.self]
        )
        scrollViewBackground.backgroundColor = .clear
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState

    @State private var viewModel = PanelViewModel()

    // Convenience accessors for data from ViewModel
    private var accounts: [Account] { viewModel.accounts }
    private var tags: [Tag] { viewModel.tags }
    private var categories: [Category] { viewModel.categories }
    private var allSubcategories: [Subcategory] { viewModel.allSubcategories }
    private var transactions: [TransactionItem] { viewModel.transactions }
    private var budgets: [Budget] { viewModel.budgets }
    private var scheduledPayments: [ScheduledPayment] { viewModel.scheduledPayments }
    private var pendingDrafts: [InboxDraft] { viewModel.pendingDrafts }

    @State private var isPresentingSettings = false

    /// Sheet presentation state for account form
    @State private var accountFormSheet: AccountFormSheet?

    /// Trend Detail View State (To be removed/minimized as navigation is gone)
    @State private var trendDetailType: TrendType = .balance

    /// Widget Preferences Sheet
    @State private var showWidgetPreferences = false

    /// New Transaction Sheet
    @State private var showNewTransaction = false

    /// Budget Favorites Settings Sheet
    @State private var showBudgetFavoritesSettings = false

    /// Inbox View Sheet
    @State private var showInbox = false

    /// Task for debouncing data recalculations
    @State private var calculationTask: Task<Void, Never>?

    /// Custom period picker sheet
    @State private var showCustomPeriodPicker = false

    @AppStorage("userName") private var userName: String = "Usuario"
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCodeRaw: String = CurrencyCode.pen
        .rawValue
    @AppStorage("accountsSortOrderNames") private var accountsSortOrderNamesRaw: String = ""
    @AppStorage(TabBarConfiguration.storageKey) private var tabConfigJSON: String = TabBarConfiguration.default.toJSON()
    @AppStorage("voiceInputEnabled") private var voiceInputEnabled: Bool = false
    @AppStorage("imageInputEnabled") private var imageInputEnabled: Bool = false

    /// Voice recording sheet
    @State private var showVoiceRecording = false
    @State private var navigateToInboxAfterVoice = false
    @State private var switchToImageAfterVoice = false

    /// Image selection sheet
    @State private var showImageSelection = false
    @State private var navigateToInboxAfterImage = false

    /// FAB menu expanded state
    @State private var showFABMenu = false

    /// Check if Statistics tab is visible
    private var isStatisticsVisible: Bool {
        TabBarConfiguration.fromJSON(tabConfigJSON).activeTabs.contains(.statistics)
    }

    /// Check if voice input can be used (requires accounts and subcategories)
    private var canUseVoiceInput: Bool {
        let hasActiveAccounts = accounts.contains { !$0.isArchived }
        let hasVisibleSubcategories = allSubcategories.contains { $0.isVisible }
        return hasActiveAccounts && hasVisibleSubcategories
    }

    /// Navigate to Statistics detail, setting temporary tab if needed
    private func navigateToStatistics(_ detailTab: DetailViewTab) {
        if !isStatisticsVisible {
            // Set Statistics as temporary tab (like selecting from "More")
            sessionState.temporaryTab = .statistics
        }
        sessionState.navigateToDetail(detailTab)
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle(L10n.Panel.title(userName))
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showInbox = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "tray.full")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color.electricIndigo)

                                // Badge with count
                                if pendingDrafts.count > 0 {
                                    Text("\(min(pendingDrafts.count, 99))")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(
                                            Capsule()
                                                .fill(Color.hotPink)
                                        )
                                        .offset(x: 8, y: -6)
                                }
                            }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            isPresentingSettings = true
                        } label: {
                            Image(systemName: "person.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.electricIndigo)
                        }
                    }
                }
                .sheet(item: $accountFormSheet) { sheet in
                    AccountFormView(
                        existingNames: existingAccountNames(editingAccount: sheet.account),
                        accountToEdit: sheet.account
                    )
                    .onDisappear {
                        // Force recalculation when account form closes
                        // (initial balance changes may not trigger @Query immediately)
                        recalculateData()
                    }
                }
                .sheet(isPresented: $isPresentingSettings, onDismiss: {
                    recalculateData()
                }) {
                    ProfileView()
                }
                .sheet(isPresented: $showWidgetPreferences) {
                    WidgetPreferencesView(viewModel: viewModel)
                        .presentationDragIndicator(.visible)
                }
                .sheet(isPresented: $showNewTransaction, onDismiss: {
                    recalculateData()
                }) {
                    // Convert selected subcategory ID back to name for prefill
                    let prefillSubcategoryName: String? = viewModel.selectedSubcategoryIDs.first.flatMap { subcategoryID in
                        allSubcategories.first(where: { $0.persistentModelID == subcategoryID })?.name
                    }
                    NewTransactionView(
                        prefillAccountID: viewModel.selectedAccountID,
                        prefillCategoryID: viewModel.selectedCategoryID,
                        prefillSubcategoryName: prefillSubcategoryName
                    )
                }
                .sheet(isPresented: $showVoiceRecording, onDismiss: {
                    if navigateToInboxAfterVoice {
                        navigateToInboxAfterVoice = false
                        showInbox = true
                    }
                    if switchToImageAfterVoice {
                        switchToImageAfterVoice = false
                        // Small delay to allow sheet dismiss animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showImageSelection = true
                        }
                    }
                    recalculateData()
                }) {
                    VoiceRecordingView(
                        onSavedToInbox: {
                            navigateToInboxAfterVoice = true
                        },
                        onSwitchToImage: {
                            switchToImageAfterVoice = true
                        }
                    )
                }
                .sheet(isPresented: $showImageSelection, onDismiss: {
                    if navigateToInboxAfterImage {
                        navigateToInboxAfterImage = false
                        showInbox = true
                    }
                    recalculateData()
                }) {
                    ImageSelectionView(onSavedToInbox: {
                        navigateToInboxAfterImage = true
                    })
                }
                .sheet(isPresented: $showCustomPeriodPicker) {
                    CustomPeriodPickerSheet(
                        minDate: transactionDateRange.start,
                        maxDate: transactionDateRange.end,
                        currentRange: sessionState.customDateRange
                    )
                }
                .sheet(isPresented: $showBudgetFavoritesSettings, onDismiss: {
                    recalculateData()
                }) {
                    NavigationStack {
                        BudgetsFavoritesSettingsView()
                    }
                }
                .sheet(isPresented: $showInbox, onDismiss: {
                    recalculateData()
                }) {
                    InboxView(onNavigateToRecords: {
                        navigateToStatistics(.records)
                    })
                }
        }
        .onAppear {
            viewModel.setContext(modelContext)

            // Note: seedCategoriesIfNeeded removed - now handled by OnboardingView step 5
            TransferMigrationService.migratePositiveTransfersIfNeeded(in: modelContext)

            // Sync all filters from SessionState -> ViewModel
            viewModel.syncFromSessionState(sessionState)

            // Ensure consistency
            let newOrder = viewModel.ensureAccountsSortOrderConsistency(
                accounts: accounts,
                currentOrderRaw: accountsSortOrderNamesRaw
            )
            if newOrder != accountsSortOrderNamesRaw {
                accountsSortOrderNamesRaw = newOrder
            }

            // Initial Trend Calculation (async to avoid blocking UI)
            recalculateData()
        }
        .onChange(of: sessionState.selectedMainTab) { _, _ in
            // Close FAB menu when navigating away from Panel
            if showFABMenu {
                showFABMenu = false
            }
        }
        .onChange(of: accounts) {
            let newOrder = viewModel.ensureAccountsSortOrderConsistency(
                accounts: accounts,
                currentOrderRaw: accountsSortOrderNamesRaw
            )
            if newOrder != accountsSortOrderNamesRaw {
                accountsSortOrderNamesRaw = newOrder
            }
        }
        // Note: Filter onChange handlers removed - filters are now SSOT computed properties
        // that read/write directly to SessionState. PanelSessionObservers handles recalculation.
        .onChange(of: transactions) {
            // Recalculate when transactions change
            recalculateData()
        }
        .onChange(of: budgets) {
            // Recalculate when budgets change (favorites toggled, reordered, etc.)
            recalculateData()
        }
        .onChange(of: allSubcategories) {
            // Recalculate when subcategories change (nature edited, etc.)
            recalculateData()
        }
        .onChange(of: sessionState.needsBudgetsWidgetRefresh) { _, needsRefresh in
            // Recalculate when favorites are modified from any view (Profile, Planning, etc.)
            if needsRefresh {
                recalculateData()
                sessionState.needsBudgetsWidgetRefresh = false
            }
        }
        .onChange(of: defaultCurrencyCodeRaw) {
            // Recalculate when preferred currency changes
            recalculateData()
        }
        .onChange(of: sessionState.formattingVersion) {
            // Force recalculation when formatting settings change (rounded amounts, etc.)
            recalculateData()
        }
        .onChange(of: sessionState.shouldShowInbox) { _, shouldShow in
            // Open Inbox when triggered by Share Extension
            if shouldShow {
                showInbox = true
                sessionState.shouldShowInbox = false
            }
        }
        .onChange(of: sessionState.hasPendingSharedImage) { _, hasPending in
            // Open ImageSelectionView when shared image is pending
            if hasPending && sessionState.pendingSharedImageURL != nil {
                showImageSelection = true
            }
        }
        .onChange(of: sessionState.shouldShowVoiceEntry) { _, shouldShow in
            // Open VoiceRecordingSheet when triggered by App Shortcut
            if shouldShow {
                showVoiceRecording = true
                sessionState.shouldShowVoiceEntry = false
            }
        }
        .onChange(of: sessionState.shouldShowImageEntry) { _, shouldShow in
            // Open ImageSelectionView when triggered by App Shortcut
            if shouldShow {
                showImageSelection = true
                sessionState.shouldShowImageEntry = false
            }
        }
        .onChange(of: viewModel.trendType) {
            // Sync trend type to SessionState when it changes
            viewModel.syncToSessionState(sessionState)
            recalculateData()
        }
        .modifier(
            PanelSessionObservers(
                sessionState: sessionState,
                categories: categories,
                subcategories: allSubcategories,
                recalculateData: recalculateData
            )
        )
    }

    private var mainContent: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    accountsSection
                    totalBalanceSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xxxl)
                // Force complete re-render when formatting settings change
                .id(sessionState.formattingVersion)
            }

            // Botón flotante de nuevo registro
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    newRecordFAB
                }
            }
        }
    }

    // MARK: - New Record FAB

    @ViewBuilder
    private var newRecordFAB: some View {
        let fabBackground = canUseVoiceInput ? Color.electricIndigo : Color.gray.opacity(0.5)
        let hasMultipleInputs = (voiceInputEnabled && imageInputEnabled) ||
                                (voiceInputEnabled && !imageInputEnabled) ||
                                (!voiceInputEnabled && imageInputEnabled)

        if hasMultipleInputs && canUseVoiceInput {
            // Custom FAB with popup menu above
            VStack(alignment: .trailing, spacing: DS.Spacing.md) {
                // Menu options (shown when expanded)
                if showFABMenu {
                    VStack(spacing: DS.Spacing.sm) {
                        // Voice option (if enabled)
                        if voiceInputEnabled {
                            fabMenuButton(
                                icon: "waveform",
                                text: L10n.Panel.fabVoice,
                                color: .electricIndigo
                            ) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    showFABMenu = false
                                }
                                showVoiceRecording = true
                            }
                        }

                        // Image option (if enabled)
                        if imageInputEnabled {
                            fabMenuButton(
                                icon: "photo",
                                text: L10n.Panel.fabImage,
                                color: .teal
                            ) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    showFABMenu = false
                                }
                                showImageSelection = true
                            }
                        }

                        // Manual option (always shown)
                        fabMenuButton(
                            icon: "square.and.pencil",
                            text: L10n.Panel.fabManual,
                            color: .hotPink
                        ) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                showFABMenu = false
                            }
                            showNewTransaction = true
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity),
                        removal: .scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity)
                    ))
                }

                // FAB button
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        showFABMenu.toggle()
                    }
                } label: {
                    Image(systemName: showFABMenu ? "xmark" : "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(showFABMenu ? Color.gray : fabBackground)
                        .clipShape(Circle())
                        .rotationEffect(.degrees(showFABMenu ? 90 : 0))
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive())
                .shadow(color: Color.black.opacity(0.20), radius: 20, x: 0, y: 10)
            }
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
        } else {
            // Simple FAB (no special inputs enabled)
            Button {
                if canUseVoiceInput {
                    showNewTransaction = true
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(fabBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive())
            .shadow(color: Color.black.opacity(0.20), radius: 20, x: 0, y: 10)
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
            .disabled(!canUseVoiceInput)
        }
    }

    private func fabMenuButton(icon: String, text: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 24)

                Text(text)
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .frame(width: 140)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(color)
            .clipShape(Capsule())
            .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .phaseAnimator([false, true]) { content, phase in
            content
                .scaleEffect(phase ? 1.03 : 1.0)
        } animation: { _ in
            .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
        }
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text(L10n.Panel.accounts)
                .font(.title2.weight(.semibold))

            AccountsCarouselView(
                viewModel: viewModel,
                orderedAccounts: viewModel.orderedActiveAccounts(
                    from: accounts,
                    sortOrderNames: accountsSortOrderNamesRaw.split(separator: "|").map(String.init)
                ),
                transactions: transactions,
                onAddAccount: {
                    accountFormSheet = AccountFormSheet(account: nil)
                },
                onEditAccount: { account in
                    accountFormSheet = AccountFormSheet(account: account)
                }
            )
        }
    }

    private var totalBalanceSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {

            // Unified Period Selector & Filters Row
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                TrendsPeriodMenu(
                    selectedPeriod: sessionState.selectedPeriod,
                    customDateRange: sessionState.customDateRange,
                    onSelect: { period in
                        sessionState.selectedPeriod = period
                    },
                    onCustomTapped: {
                        showCustomPeriodPicker = true
                    }
                )

                // Filter chips (Scrollable to the right)
                let hasAccountFilter = viewModel.selectedAccountID != nil
                let hasDateFilter = viewModel.focusedDate != nil
                let hasCategoryFilter = viewModel.selectedCategoryID != nil
                let hasNatureFilter = viewModel.selectedNature != nil
                let hasSubcategoryFilter = !viewModel.selectedSubcategoryIDs.isEmpty
                let hasTagFilter = !viewModel.selectedTags.isEmpty
                let hasCurrencyFilter = !viewModel.selectedCurrencies.isEmpty
                let hasAmountFilter = viewModel.amountCondition.isActive
                let hasNoteFilter = !viewModel.searchText.isEmpty
                let hasTransactionNatureFilter = sessionState.selectedTransactionNatures.count == 1

                let activeFilterCount = [
                    hasAccountFilter, hasDateFilter, hasCategoryFilter,
                    hasNatureFilter, hasSubcategoryFilter, hasTagFilter,
                    hasCurrencyFilter, hasAmountFilter, hasNoteFilter,
                    hasTransactionNatureFilter,
                ].filter { $0 }.count

                if activeFilterCount > 0 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.sm) {
                            // Account Chip
                            if let selectedID = viewModel.selectedAccountID,
                                let account = accounts.first(where: {
                                    $0.persistentModelID == selectedID
                                })
                            {
                                FilterChipView(
                                    accountName: account.name,
                                    onClear: { viewModel.selectedAccountID = nil }
                                )
                            }

                            // Date Chip
                            if let focusedDate = viewModel.focusedDate {
                                FilterChipView(
                                    text: "Fecha: \(formattedDate(focusedDate))",
                                    onClear: {
                                        withAnimation {
                                            viewModel.focusedDate = nil
                                        }
                                    }
                                )
                            }

                            // Category Chip - show when category is directly selected OR when subcategories are selected
                            let selectedSubsByID = allSubcategories.filter {
                                viewModel.selectedSubcategoryIDs.contains($0.persistentModelID)
                            }
                            let isAllSubsSelected =
                                !selectedSubsByID.isEmpty
                                && selectedSubsByID.count == allSubcategories.count

                            // Show category chip if:
                            // 1. A category is directly selected (from pie chart), OR
                            // 2. Subcategories are selected (shows parent category)
                            if let categoryID = viewModel.selectedCategoryID,
                               let category = viewModel.topSpendingCategories.first(where: { $0.category.persistentModelID == categoryID })?.category {
                                // Direct category selection (from pie chart)
                                FilterChipView(
                                    categoryName: category.name,
                                    iconName: category.iconName,
                                    colorHex: category.colorHex,
                                    count: 1,
                                    onClear: {
                                        viewModel.selectedCategoryID = nil
                                        viewModel.selectedSubcategoryIDs.removeAll()
                                        sessionState.selectedCategoryIDs.removeAll()
                                        sessionState.selectedSubcategoryIDs.removeAll()
                                    }
                                )
                            } else if !isAllSubsSelected && !selectedSubsByID.isEmpty {
                                // Subcategory selection - show parent category
                                let parentCategories = Set(
                                    selectedSubsByID.compactMap { $0.category })
                                if let firstCategory = parentCategories.first {
                                    FilterChipView(
                                        categoryName: firstCategory.name,
                                        iconName: firstCategory.iconName,
                                        colorHex: firstCategory.colorHex,
                                        count: parentCategories.count,
                                        onClear: {
                                            viewModel.selectedCategoryID = nil
                                            viewModel.selectedSubcategoryIDs.removeAll()
                                            sessionState.selectedCategoryIDs.removeAll()
                                            sessionState.selectedSubcategoryIDs.removeAll()
                                        }
                                    )
                                }
                            }

                            // Subcategory Chip (aggregated from selected subcategory IDs)
                            if !isAllSubsSelected && !selectedSubsByID.isEmpty {
                                if let firstSub = selectedSubsByID.first {
                                    let color =
                                        (firstSub.colorHex?.isEmpty == false
                                            ? firstSub.colorHex : nil)
                                        ?? firstSub.category.colorHex
                                    FilterChipView(
                                        subcategoryName: firstSub.name,
                                        iconName: firstSub.iconName,
                                        colorHex: color,
                                        count: selectedSubsByID.count,
                                        onClear: {
                                            viewModel.selectedSubcategoryIDs.removeAll()
                                            sessionState.selectedSubcategoryIDs.removeAll()
                                        }
                                    )
                                }
                            }

                            // Nature Chip (Subcategory Nature: essential/priority/optional)
                            if let nature = viewModel.selectedNature {
                                FilterChipView(
                                    nature: nature,
                                    onClear: {
                                        withAnimation { viewModel.selectedNature = nil }
                                    }
                                )
                            }

                            // Transaction Nature Chip (Income/Expense)
                            if sessionState.selectedTransactionNatures.count == 1,
                               let transactionNature = sessionState.selectedTransactionNatures.first {
                                FilterChipView(
                                    transactionNature: transactionNature,
                                    onClear: {
                                        withAnimation {
                                            sessionState.selectedTransactionNatures.removeAll()
                                        }
                                    }
                                )
                            }

                            // Tag Chips
                            ForEach(Array(viewModel.selectedTags), id: \.self) { tagID in
                                if let tag = tags.first(where: { $0.persistentModelID == tagID }) {
                                    FilterChipView(
                                        tagName: tag.name,
                                        iconName: tag.iconName,
                                        colorHex: tag.colorHex,
                                        onClear: {
                                            withAnimation {
                                                viewModel.selectedTags.remove(tagID)
                                                viewModel.syncToSessionState(sessionState)
                                            }
                                        }
                                    )
                                }
                            }

                            // Currency Chips
                            ForEach(Array(viewModel.selectedCurrencies), id: \.self) { currency in
                                FilterChipView(
                                    currencyCode: currency.rawValue,
                                    onClear: {
                                        withAnimation {
                                            viewModel.selectedCurrencies.remove(currency)
                                            viewModel.syncToSessionState(sessionState)
                                        }
                                    }
                                )
                            }

                            // Amount Chip
                            if viewModel.amountCondition.isActive {
                                FilterChipView(
                                    amountText: viewModel.amountCondition.displayText,
                                    onClear: {
                                        withAnimation {
                                            viewModel.amountCondition = .any
                                            viewModel.syncToSessionState(sessionState)
                                        }
                                    }
                                )
                            }

                            // Note/Search Chip
                            if !viewModel.searchText.isEmpty {
                                FilterChipView(
                                    noteText: viewModel.searchText,
                                    onClear: {
                                        withAnimation {
                                            viewModel.searchText = ""
                                            viewModel.syncToSessionState(sessionState)
                                        }
                                    }
                                )
                            }

                            // Clear All Button
                            if activeFilterCount > 1 {
                                Button {
                                    withAnimation {
                                        clearAllPanelFilters()
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    Spacer()
                }
            }
            .padding(.bottom, DS.Spacing.sm)

            HStack {
                Text(L10n.Panel.widgets)
                    .font(.title2.weight(.semibold))

                Spacer()

                Button {
                    showWidgetPreferences = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.primary)
                }
            }
            .padding(.trailing, 4)

            // Custom Grid Layout (VStack of Rows)
            VStack(spacing: DS.Spacing.lg) {
                ForEach(viewModel.layoutRows) { row in
                    switch row.type {
                    case .fullWidth(let config):
                        widgetView(for: config)
                            .clipped()  // Prevent content overflow
                    case .halfWidthPair(let left, let right):
                        HStack(spacing: DS.Spacing.lg) {
                            widgetView(for: left)
                                .frame(maxWidth: .infinity)
                                .clipped()  // Prevent content overflow

                            if let right = right {
                                widgetView(for: right)
                                    .frame(maxWidth: .infinity)
                                    .clipped()  // Prevent content overflow
                            } else {
                                // Spacer for empty slot
                                Color.clear
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }

            EmptyView()
                .onChange(of: viewModel.selectedCategoryID) {
                    recalculateData()
                }
                .onChange(of: viewModel.focusedDate) {
                    recalculateData()
                }
                .onChange(of: viewModel.selectedNature) {
                    recalculateData()
                }
        }

    }

    private func formattedAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    /// Recalculate trend data with smooth animation
    private func recalculateData() {
        // Reload fresh data from SwiftData first
        viewModel.loadData()

        // Direct synchronous call for instant response
        withAnimation(.easeOut(duration: 0.15)) {
            viewModel.calculateTrendData(
                accounts: accounts,
                transactions: transactions,
                defaultCurrencyCode: defaultCurrencyCodeRaw,
                context: modelContext,
                sessionState: sessionState
            )

            // Calculate budgets widget data
            viewModel.calculateBudgetsWidget(
                budgets: budgets,
                transactions: transactions,
                defaultCurrencyCode: defaultCurrencyCodeRaw
            )
        }
    }

    // MARK: - Widget Helpers

    @ViewBuilder
    private func widgetView(for config: WidgetConfig) -> some View {
        // Render actual widget directly - calculations are fast enough now
        actualWidgetView(for: config)
    }

    @ViewBuilder
    private func skeletonView(for config: WidgetConfig) -> some View {
        switch config.type {
        case .trend:
            TrendWidgetSkeleton()
        case .cashFlow:
            CashFlowSkeleton()
        case .latestRecords:
            LatestRecordsSkeleton()
        case .categoriesPie:
            CategoriesPieSkeleton()
        default:
            WidgetSkeleton(height: config.size == .large ? 300 : 200)
        }
    }

    @ViewBuilder
    private func actualWidgetView(for config: WidgetConfig) -> some View {
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCodeRaw) ?? .pen
        let balance = viewModel.displayedBalanceInDefaultCurrency(
            accounts: accounts,
            transactions: transactions,
            defaultCurrencyCode: defaultCurrencyCodeRaw,
            context: modelContext
        )

        // All widgets below have 'onShowMore' or 'onViewDetail' removed (or passed as nil) to remove chevrons

        if config.type == .trend {
            TrendWidget(
                viewModel: viewModel,
                sessionState: sessionState,
                currencyCode: preferredCurrency.rawValue,
                currentBalance: balance
            )
            .onChange(of: viewModel.subcategoriesWidgetFilter) { _, _ in
                recalculateData()
            }
            .onChange(of: viewModel.selectedSubcategoryIDs) { _, _ in
                recalculateData()
            }
            .onChange(of: viewModel.trendType) { _, _ in
                recalculateData()
            }
        } else if config.type == .topSpending {
            TopCategoriesWidget(
                categories: viewModel.topSpendingCategories,
                currencyCode: preferredCurrency.rawValue,
                selectedCategoryID: viewModel.selectedCategoryID,
                onSelectCategory: { id in
                    withAnimation {
                        viewModel.toggleCategoryFilter(id)
                    }
                },
                onShowMore: { navigateToStatistics(.categories) },
                size: mapWidgetSize(config.size),
                period: viewModel.selectedPeriod,
                previousTotalAmount: viewModel.previousCategoriesTotalAmount,
                showVariationHeader: viewModel.selectedPeriod != .allTime
            )
        } else if config.type == .topSubcategories {
            TopSubcategoriesWidget(
                subcategories: viewModel.topSubcategories,
                currencyCode: preferredCurrency.rawValue,
                globalCategoryFilterID: viewModel.selectedCategoryID,
                localCategoryFilterID: $viewModel.subcategoriesWidgetFilter,
                onSelectSubcategory: { subcategoryID in
                    withAnimation {
                        viewModel.toggleSubcategoryFilter(
                            subcategoryID,
                            transactions: transactions,
                            accounts: accounts,
                            defaultCurrencyCode: preferredCurrency.rawValue,
                            context: modelContext,
                            sessionState: sessionState
                        )
                    }
                },
                selectedSubcategoryIDs: viewModel.selectedSubcategoryIDs,
                onShowMore: { navigateToStatistics(.categories) },
                size: mapWidgetSize(config.size),
                period: viewModel.selectedPeriod,
                previousTotalAmount: viewModel.previousSubcategoriesTotalAmount,
                showVariationHeader: viewModel.selectedPeriod != .allTime
            )
        } else if config.type == .categoriesPie {
            CategoriesPieWidget(
                categories: viewModel.topSpendingCategories,
                currencyCode: preferredCurrency.rawValue,
                selectedCategoryID: viewModel.selectedCategoryID,
                onSelectCategory: { id in
                    withAnimation {
                        viewModel.toggleCategoryFilter(id)
                    }
                },
                onShowDetail: { navigateToStatistics(.categories) },
                size: config.size,
                period: viewModel.selectedPeriod,
                previousTotalAmount: viewModel.previousCategoriesTotalAmount,
                showVariationHeader: true
            )
        } else if config.type == .subcategoriesPie {
            SubcategoriesPieWidget(
                subcategories: viewModel.topSubcategories,
                currencyCode: preferredCurrency.rawValue,
                selectedCategoryID: viewModel.selectedCategoryID,
                selectedSubcategoryIDs: viewModel.selectedSubcategoryIDs,
                onSelectSubcategory: { subcategoryID in
                    withAnimation {
                        viewModel.toggleSubcategoryFilter(
                            subcategoryID,
                            transactions: transactions,
                            accounts: accounts,
                            defaultCurrencyCode: preferredCurrency.rawValue,
                            context: modelContext,
                            sessionState: sessionState
                        )
                    }
                },
                onShowDetail: { navigateToStatistics(.categories) },
                size: config.size,
                period: viewModel.selectedPeriod,
                previousTotalAmount: viewModel.previousSubcategoriesTotalAmount,
                showVariationHeader: true
            )
        } else if config.type == .cashFlow {
            if let summary = viewModel.cashFlowSummary {
                CashFlowWidget(
                    summary: summary,
                    size: config.size,
                    period: viewModel.selectedPeriod.rawValue,
                    grouping: viewModel.cashFlowGrouping,
                    interval: viewModel.currentInterval,
                    onShowDetail: { navigateToStatistics(.trends) },
                    displayMode: viewModel.trendType,
                    selectedTransactionNatures: viewModel.selectedTransactionNatures
                )
            } else {
                EmptyView()
            }
        } else if config.type == .latestRecords {
            RecentRecordsWidget(
                records: viewModel.latestRecords,
                currencyCode: preferredCurrency.rawValue,
                onShowMore: { navigateToStatistics(.records) }
            )
        } else if config.type == .expensesByNature {
            NatureTrendWidget(
                trendPoints: viewModel.natureTrendPoints,
                selectedNature: viewModel.selectedNature,
                currencyCode: preferredCurrency.rawValue,
                size: mapWidgetSize(config.size),
                grouping: viewModel.natureGrouping,
                interval: viewModel.currentInterval,
                onSelectNature: { nature in
                    withAnimation {
                        viewModel.toggleNatureFilter(nature)
                    }
                },
                onShowDetail: { navigateToStatistics(.categories) },
                period: viewModel.selectedPeriod,
                previousTotalAmount: viewModel.previousNatureTotalAmount,
                previousAmountByNature: viewModel.previousNatureAmounts,
                showVariationHeader: viewModel.selectedPeriod != .allTime,
                isIncomeMode: viewModel.selectedTransactionNatures == [.income]
            )
        } else if config.type == .exchangeRate {
            ExchangeRateWidget(
                data: viewModel.exchangeRateWidgetData,
                preferredCurrency: preferredCurrency.rawValue,
                selectedCurrencies: $viewModel.selectedComparisonCurrencies,
                grouping: viewModel.exchangeRateGrouping,
                onShowDetail: nil  // REMOVED CHEVRON
            )
        } else if config.type == .budgets {
            BudgetsWidget(
                budgets: viewModel.topBudgetSummaries,
                currencyCode: preferredCurrency.rawValue,
                hasBudgetsButNoFavorites: viewModel.hasBudgetsButNoFavorites,
                selectedBudgetID: sessionState.selectedBudgetID,
                onSelectBudget: { budget in
                    sessionState.applyBudgetFilters(budget)
                },
                onShowMore: { sessionState.navigateToBudgets() },
                onEditFavorites: { showBudgetFavoritesSettings = true },
                size: mapBudgetsWidgetSize(config.size)
            )
        } else if config.type == .scheduledPayments {
            ScheduledPaymentsWidget(
                payments: scheduledPayments,
                currencyCode: preferredCurrency.rawValue,
                period: viewModel.selectedPeriod,
                customDateRange: sessionState.customDateRange,
                mode: config.scheduledPaymentsMode,
                filter: $viewModel.scheduledPaymentsWidgetFilter,
                onShowMore: { sessionState.navigateToScheduledPayments() }
            )
        }
    }

    private func mapWidgetSize(_ size: WidgetSize) -> TopCategoriesWidget.CardSize {
        switch size {
        case .medium: return .medium
        case .large: return .large
        }
    }

    private func mapBudgetsWidgetSize(_ size: WidgetSize) -> BudgetsWidget.CardSize {
        switch size {
        case .medium: return .medium
        case .large: return .large
        }
    }

    // MARK: - Helpers

    private func existingAccountNames(editingAccount: Account?) -> [String] {
        guard let editingAccount = editingAccount else {
            return accounts.map { $0.name }
        }
        return
            accounts
            .filter { $0.persistentModelID != editingAccount.persistentModelID }
            .map { $0.name }
    }

    /// Date range of all transactions (for custom period picker limits)
    private var transactionDateRange: (start: Date, end: Date) {
        let dates = transactions.map(\.date)
        let start = dates.min() ?? Date()
        let end = dates.max() ?? Date()
        return (start, end)
    }

    /// Clear all Panel filters and sync to SessionState
    private func clearAllPanelFilters() {
        viewModel.selectedAccountID = nil
        viewModel.focusedDate = nil
        viewModel.selectedCategoryID = nil
        viewModel.selectedSubcategoryIDs.removeAll()
        viewModel.selectedNature = nil
        viewModel.selectedTags.removeAll()
        viewModel.selectedCurrencies.removeAll()
        viewModel.amountCondition = .any
        viewModel.searchText = ""
        sessionState.selectedTransactionNatures.removeAll()
        viewModel.syncToSessionState(sessionState)
    }
}

// MARK: - Sheet Wrapper

/// Wrapper to enable `.sheet(item:)` pattern for both new and edit account forms.
struct AccountFormSheet: Identifiable {
    let id = UUID()
    let account: Account?
}

// MARK: - Panel Observers

/// Encapsulates SessionState onChange observers to reduce body complexity and avoid type-checker limits
/// Note: With SSOT refactor, syncFromSessionState is no longer needed - filters are computed properties
/// that read/write directly to SessionState.shared. Only recalculateData is needed.
private struct PanelSessionObservers: ViewModifier {
    let sessionState: SessionState
    let categories: [Category]
    let subcategories: [Subcategory]
    let recalculateData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedPeriod) {
                recalculateData()
            }
            .onChange(of: sessionState.selectedAccountIDs) {
                recalculateData()
            }
            .onChange(of: sessionState.selectedCategoryIDs) {
                // Auto-create expense chip only if ALL selected categories are expense (not income)
                if !sessionState.selectedCategoryIDs.isEmpty {
                    let selectedCats = categories.filter {
                        sessionState.selectedCategoryIDs.contains($0.persistentModelID)
                    }
                    // Only set expense if we found matching categories AND all are expense categories
                    if !selectedCats.isEmpty && selectedCats.allSatisfy({ !$0.isIncome }) {
                        sessionState.selectedTransactionNatures = [.expense]
                    }
                }
                recalculateData()
            }
            .onChange(of: sessionState.selectedNatures) {
                // Auto-create expense chip when nature filter applied (natures are expense-only)
                if !sessionState.selectedNatures.isEmpty {
                    sessionState.selectedTransactionNatures = [.expense]
                }
                recalculateData()
            }
            .onChange(of: sessionState.selectedSubcategoryIDs) {
                // Auto-create expense chip only if ALL selected subcategories are from expense categories
                if !sessionState.selectedSubcategoryIDs.isEmpty {
                    let selectedSubs = subcategories.filter {
                        sessionState.selectedSubcategoryIDs.contains($0.persistentModelID)
                    }
                    // Only set expense if we found matching subcategories AND all are from expense categories
                    if !selectedSubs.isEmpty && selectedSubs.allSatisfy({ !$0.category.isIncome }) {
                        sessionState.selectedTransactionNatures = [.expense]
                    }
                }
                recalculateData()
            }
            .onChange(of: sessionState.selectedTags) {
                recalculateData()
            }
            .onChange(of: sessionState.selectedCurrencies) {
                recalculateData()
            }
            .onChange(of: sessionState.selectedTransactionNatures) {
                recalculateData()
            }
            .onChange(of: sessionState.amountCondition) {
                recalculateData()
            }
            .onChange(of: sessionState.searchText) {
                recalculateData()
            }
            .onChange(of: sessionState.selectedTrendMetric) {
                recalculateData()
            }
            .onChange(of: sessionState.customDateRange) {
                recalculateData()
            }
    }
}
