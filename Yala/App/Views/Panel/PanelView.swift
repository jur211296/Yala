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

    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SessionState.self) private var sessionState
    @Environment(ExchangeRateService.self) private var exchangeRateService
    @Environment(CurrencyConverter.self) private var currencyConverter

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

/// Widget Preferences Sheet
    @State private var showWidgetPreferences = false

    /// New Transaction Sheet
    @State private var showNewTransaction = false

    /// Budget Favorites Settings Sheet
    @State private var showBudgetFavoritesSettings = false

    /// Inbox View Sheet
    @State private var showInbox = false

/// Custom period picker sheet
    @State private var showCustomPeriodPicker = false

    @AppStorage("userName") private var userName: String = "Usuario"
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCodeRaw: String = CurrencyCode.pen.rawValue
    @AppStorage("showVariations") private var showVariations: Bool = true
    @AppStorage("accountsSortOrderNames") private var accountsSortOrderNamesRaw: String = ""
    @AppStorage(TabBarConfiguration.storageKey) private var tabConfigJSON: String = TabBarConfiguration.default.toJSON()
    @AppStorage("voiceInputEnabled") private var voiceInputEnabled: Bool = false
    @AppStorage("imageInputEnabled") private var imageInputEnabled: Bool = false
    @AppStorage("aiDataConsentAccepted") private var aiDataConsentAccepted: Bool = false
    @State private var showAIConsentAlert = false
    @State private var pendingAIInput: PendingAIInput = .voice
    @AppStorage("showSiriTip") private var showSiriTip: Bool = true
    @AppStorage("panelShowAIInsight") private var showAIInsight: Bool = false
    @AppStorage(InsightTone.storageKey) private var toneSetting: String = InsightTone.normal.rawValue
    @AppStorage(InsightFocus.storageKey) private var focusSetting: String = InsightFocus.balanced.rawValue

    /// Contextual AI insight state
    @State private var contextualInsight: String?
    @State private var isLoadingInsight = false
    @State private var contextualInsightDismissed = false

    /// Voice recording sheet
    @State private var showVoiceRecording = false
    @State private var navigateToInboxAfterVoice = false
    @State private var switchToImageAfterVoice = false

    /// Image selection sheet
    @State private var showImageSelection = false
    @State private var navigateToInboxAfterImage = false

    /// FAB menu expanded state
    @State private var showFABMenu = false

    /// Coach mark: Panel tour (A1-A4)
    @AppStorage("hasSeenPanelTour") private var hasSeenPanelTour = false
    @State private var showPanelTour = false
    @State private var panelTourIndex = 0

    /// Coach mark: Interactivity tour (C1-C2)
    @AppStorage("hasSeenInteractivityTour") private var hasSeenInteractivityTour = false
    @State private var showInteractivityTour = false
    @State private var interactivityTourIndex = 0
    @State private var panelScrollProxy: ScrollViewProxy?

    /// Upgrade prompt sheets for gated features
    @State private var showUpgradeForVoice = false
    @State private var showUpgradeForImage = false
    @State private var showUpgradeForAccounts = false

    /// Check if accounts limit is reached (Pro feature)
    private var isAccountsLimitReached: Bool {
        let activeCount = accounts.filter { !$0.isArchived }.count
        return !FeatureGateService.shared.canCreate(.accounts, currentCount: activeCount)
    }

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

    /// Check if voice input is locked (Pro feature)
    private var isVoiceLocked: Bool {
        !FeatureGateService.shared.canAccess(.voiceInput)
    }

    /// Check if image input is locked (Pro feature)
    private var isImageLocked: Bool {
        !FeatureGateService.shared.canAccess(.imageInput)
    }

    /// Navigate to Statistics detail, setting temporary tab if needed
    private func navigateToStatistics(_ detailTab: DetailViewTab) {
        if !isStatisticsVisible {
            // Set Statistics as temporary tab (like selecting from "More")
            sessionState.temporaryTab = .statistics
        }
        sessionState.navigateToDetail(detailTab)
    }

    // MARK: - Toolbar Buttons

    private var inboxToolbarButton: some View {
        Button {
            showInbox = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "tray.fill")
                    .font(DS.Typography.body).fontWeight(.medium)
                    .foregroundStyle(.thToolbarIcon)

                // Badge with count
                if pendingDrafts.count > 0 {
                    Text("\(min(pendingDrafts.count, 99))")
                        .font(DS.Typography.captionSmall).fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(
                            Capsule()
                                .fill(Color.hotPink)
                        )
                        .offset(x: DS.Spacing.sm, y: -(DS.Spacing.xs + 2))
                }
            }
        }
        .accessibilityLabel(L10n.Accessibility.inbox)
    }


    /// Prefill subcategory name for NewTransactionView
    private var prefillSubcategoryName: String? {
        viewModel.selectedSubcategoryIDs.first.flatMap { subcategoryID in
            allSubcategories.first(where: { $0.persistentModelID == subcategoryID })?.name
        }
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle(L10n.Panel.title(userName))
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        inboxToolbarButton
                    }
                    ProfileToolbarItem {
                        isPresentingSettings = true
                    }
                }
        }
        .coachMarkOverlay(
            steps: PanelTourSteps.steps(isProUser: FeatureGateService.shared.isProUser),
            isPresented: $showPanelTour,
            currentIndex: $panelTourIndex,
            scrollProxy: panelScrollProxy,
            onComplete: {
                hasSeenPanelTour = true
            }
        )
        .coachMarkOverlay(
            steps: InteractivityTourSteps.steps,
            isPresented: $showInteractivityTour,
            currentIndex: $interactivityTourIndex,
            scrollProxy: panelScrollProxy,
            onComplete: {
                hasSeenInteractivityTour = true
            }
        )
        .modifier(
            PanelSheetsModifier(
                accountFormSheet: $accountFormSheet,
                isPresentingSettings: $isPresentingSettings,
                showWidgetPreferences: $showWidgetPreferences,
                showNewTransaction: $showNewTransaction,
                showVoiceRecording: $showVoiceRecording,
                showImageSelection: $showImageSelection,
                showCustomPeriodPicker: $showCustomPeriodPicker,
                showBudgetFavoritesSettings: $showBudgetFavoritesSettings,
                showInbox: $showInbox,
                showUpgradeForVoice: $showUpgradeForVoice,
                showUpgradeForImage: $showUpgradeForImage,
                showUpgradeForAccounts: $showUpgradeForAccounts,
                navigateToInboxAfterVoice: $navigateToInboxAfterVoice,
                switchToImageAfterVoice: $switchToImageAfterVoice,
                navigateToInboxAfterImage: $navigateToInboxAfterImage,
                showAIConsentAlert: $showAIConsentAlert,
                pendingAIInput: $pendingAIInput,
                existingAccountNames: existingAccountNames,
                prefillAccountID: viewModel.selectedAccountID,
                prefillCategoryID: viewModel.selectedCategoryID,
                prefillSubcategoryName: prefillSubcategoryName,
                transactionDateRange: transactionDateRange,
                customDateRange: sessionState.customDateRange,
                viewModel: viewModel,
                navigateToStatistics: navigateToStatistics,
                recalculateData: recalculateData
            )
        )
        .onAppear {
            viewModel.widgetConfig.columns = DS.Adaptive.columns(sizeClass)
            viewModel.setContext(
                modelContext,
                exchangeRateService: exchangeRateService,
                currencyConverter: currencyConverter
            )
            TransferMigrationService.migratePositiveTransfersIfNeeded(in: modelContext)
            viewModel.syncFromSessionState(sessionState)
            let newOrder = viewModel.ensureAccountsSortOrderConsistency(
                accounts: accounts,
                currentOrderRaw: accountsSortOrderNamesRaw
            )
            if newOrder != accountsSortOrderNamesRaw {
                accountsSortOrderNamesRaw = newOrder
            }
            recalculateData()
        }
        .onChange(of: sizeClass) { _, newValue in
            viewModel.widgetConfig.columns = DS.Adaptive.columns(newValue)
        }
        .task {
            // Wait for post-onboarding flow (trial sheet) to complete
            while !sessionState.isReadyForTours {
                try? await Task.sleep(for: .milliseconds(200))
            }
            if !hasSeenPanelTour {
                try? await Task.sleep(for: .seconds(0.6))
                if !hasSeenPanelTour {
                    showPanelTour = true
                }
            }
        }
        .onChange(of: showPanelTour) { _, isShowing in
            if !isShowing && hasSeenPanelTour {
                triggerInteractivityTourIfEligible()
            }
        }
        .onChange(of: transactions.count) { _, _ in
            triggerInteractivityTourIfEligible()
        }
        .modifier(
            PanelDataObservers(
                accounts: accounts,
                transactions: transactions,
                budgets: budgets,
                allSubcategories: allSubcategories,
                sessionState: sessionState,
                viewModel: viewModel,
                showFABMenu: $showFABMenu,
                accountsSortOrderNamesRaw: $accountsSortOrderNamesRaw,
                defaultCurrencyCodeRaw: $defaultCurrencyCodeRaw,
                recalculateData: recalculateData
            )
        )
        .modifier(
            PanelSheetTriggers(
                sessionState: sessionState,
                showInbox: $showInbox,
                showImageSelection: $showImageSelection,
                showVoiceRecording: $showVoiceRecording,
                showNewTransaction: $showNewTransaction,
                showUpgradeForVoice: $showUpgradeForVoice,
                showUpgradeForImage: $showUpgradeForImage
            )
        )
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

            ScrollViewReader { scrollProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        if showSiriTip {
                            SiriTipCard(isVisible: $showSiriTip)
                        }

                        accountsSection
                        contextualInsightSection
                        totalBalanceSection
                    }
                    .padding(.horizontal, DS.Adaptive.horizontalPadding(sizeClass))
                    .padding(.top, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.xxxl)
                    // Force complete re-render when formatting settings change
                    .id(sessionState.formattingVersion)
                    .task(id: insightTaskKey) {
                        await loadContextualInsight()
                    }
                }
                .refreshable {
                    await refreshData()
                }
                .onAppear { panelScrollProxy = scrollProxy }
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
        let fabBackground = canUseVoiceInput ? theme.accent : DS.Semantic.disabledForeground.opacity(0.5)

        if canUseVoiceInput {
            // Custom FAB with popup menu above (always 3 options)
            VStack(alignment: .trailing, spacing: DS.Spacing.md) {
                // Menu options (shown when expanded)
                if showFABMenu {
                    VStack(spacing: DS.Spacing.sm) {
                        // Voice option
                        fabMenuButton(
                            icon: "waveform",
                            text: L10n.Panel.fabVoice,
                            color: .hotPink,
                            isLocked: isVoiceLocked
                        ) {
                            dsWithAnimation(reduceMotion, .spring(response: 0.25, dampingFraction: 0.8)) {
                                showFABMenu = false
                            }
                            if isVoiceLocked {
                                showUpgradeForVoice = true
                            } else if !aiDataConsentAccepted {
                                pendingAIInput = .voice
                                showAIConsentAlert = true
                            } else {
                                if !voiceInputEnabled { voiceInputEnabled = true }
                                showVoiceRecording = true
                            }
                        }

                        // Image option
                        fabMenuButton(
                            icon: "photo",
                            text: L10n.Panel.fabImage,
                            color: .teal,
                            isLocked: isImageLocked
                        ) {
                            dsWithAnimation(reduceMotion, .spring(response: 0.25, dampingFraction: 0.8)) {
                                showFABMenu = false
                            }
                            if isImageLocked {
                                showUpgradeForImage = true
                            } else if !aiDataConsentAccepted {
                                pendingAIInput = .image
                                showAIConsentAlert = true
                            } else {
                                if !imageInputEnabled { imageInputEnabled = true }
                                showImageSelection = true
                            }
                        }

                        // Manual option (always shown)
                        fabMenuButton(
                            icon: "square.and.pencil",
                            text: L10n.Panel.fabManual,
                            color: .electricIndigo
                        ) {
                            dsWithAnimation(reduceMotion, .spring(response: 0.25, dampingFraction: 0.8)) {
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
                    DS.Haptic.medium()
                    dsWithAnimation(reduceMotion, .spring(response: 0.25, dampingFraction: 0.8)) {
                        showFABMenu.toggle()
                    }
                } label: {
                    Image(systemName: showFABMenu ? "xmark" : "plus")
                        .font(DS.Typography.title)
                        .foregroundStyle(.white)
                        .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                        .background(showFABMenu ? DS.Semantic.disabledForeground : fabBackground)
                        .clipShape(Circle())
                        .rotationEffect(.degrees(showFABMenu ? 90 : 0))
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive())
                .dsFloatingShadow()
                .accessibilityLabel(showFABMenu ? L10n.Accessibility.closeMenu : L10n.Accessibility.newRecord)
                .coachMarkAnchor("fab")
            }
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
        } else {
            // Simple FAB (no accounts/subcategories — disabled)
            Button {
                // No-op: disabled state
            } label: {
                Image(systemName: "plus")
                    .font(DS.Typography.title)
                    .foregroundStyle(.white)
                    .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                    .background(fabBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive())
            .dsFloatingShadow()
            .coachMarkAnchor("fab")
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
            .disabled(true)
            .accessibilityLabel(L10n.Accessibility.newRecord)
            .accessibilityHint(L10n.Accessibility.createAccountFirst)
        }
    }

    private func fabMenuButton(
        icon: String,
        text: String,
        color: Color,
        isLocked: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            DS.Haptic.selection()
            action()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(DS.Typography.headline)
                    .frame(width: DS.Button.fabMenuIconSize)

                Text(text)
                    .font(DS.Typography.headline)

                Spacer(minLength: 0)

                if isLocked {
                    ProBadge(size: .small)
                }
            }
            .foregroundStyle(.white)
            .frame(width: DS.Button.fabMenuWidth)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(isLocked ? DS.Semantic.disabledForeground : color)
            .clipShape(Capsule())
            .shadow(color: (isLocked ? DS.Semantic.disabledForeground : color).opacity(0.3), radius: DS.Shadow.medium.radius, x: 0, y: DS.Shadow.medium.y)
        }
        .buttonStyle(.plain)
        .phaseAnimator(reduceMotion ? [false] : [false, true]) { content, phase in
            content
                .scaleEffect(phase ? 1.03 : 1.0)
        } animation: { _ in
            .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
        }
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text(L10n.Panel.accounts)
                .font(DS.Typography.title)

            if accounts.isEmpty {
                YalaEmptyState.noAccounts {
                    if isAccountsLimitReached {
                        showUpgradeForAccounts = true
                    } else {
                        accountFormSheet = AccountFormSheet(account: nil)
                    }
                }
            } else {
                AccountsCarouselView(
                    viewModel: viewModel,
                    orderedAccounts: viewModel.orderedActiveAccounts(
                        from: accounts,
                        sortOrderNames: accountsSortOrderNamesRaw.split(separator: "|").map(String.init)
                    ),
                    transactions: transactions,
                    isExpensesOnlyMode: sessionState.isExpensesOnlyMode,
                    onAddAccount: {
                        if isAccountsLimitReached {
                            showUpgradeForAccounts = true
                        } else {
                            accountFormSheet = AccountFormSheet(account: nil)
                        }
                    },
                    onEditAccount: { account in
                        accountFormSheet = AccountFormSheet(account: account)
                    }
                )
                .coachMarkAnchor("accounts")
                .coachMarkAnchor("filterAccount")
            }
        }
    }

    // MARK: - Contextual AI Insight

    /// Stable task key that triggers re-computation when period or filters change.
    /// Must be deterministic (no Hasher — its seed changes per launch).
    private var insightTaskKey: String {
        let account = viewModel.selectedAccountID.map { "\($0)" } ?? "all"
        let cats = SessionState.shared.selectedCategoryIDs.map { "\($0)" }.sorted().joined(separator: ",")
        let subs = viewModel.selectedSubcategoryIDs.map { "\($0)" }.sorted().joined(separator: ",")
        return "\(viewModel.selectedPeriod.rawValue)_\(account)_\(cats)_\(subs)_\(toneSetting)_\(focusSetting)"
    }

    @ViewBuilder
    private var contextualInsightSection: some View {
        let isPro = FeatureGateService.shared.canAccess(.smartInsightsAI)
        let hasConsent = UserDefaults.standard.bool(forKey: "aiInsightsConsentAccepted")
        let shouldShow = isPro && hasConsent && showAIInsight && !contextualInsightDismissed && transactions.count >= 5

        if shouldShow && isLoadingInsight {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "sparkles")
                    .foregroundStyle(theme.accent)
                    .symbolEffect(.pulse)
                    .accessibilityHidden(true)
                Text(L10n.Insights.analyzingData)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .transition(.asymmetric(
                insertion: .scale(scale: 0.95).combined(with: .opacity),
                removal: .scale(scale: 0.95).combined(with: .opacity)
            ))
        } else if shouldShow, let insight = contextualInsight {
            ContextualInsightCard(
                text: insight,
                onDismiss: {
                    dsWithAnimation(reduceMotion) {
                        contextualInsightDismissed = true
                    }
                }
            )
            .transition(.asymmetric(
                insertion: .scale(scale: 0.95).combined(with: .opacity),
                removal: .scale(scale: 0.95).combined(with: .opacity)
            ))
        }
    }

    private func loadContextualInsight() async {
        // Reset dismiss state when task key changes (period/filter change)
        contextualInsightDismissed = false
        contextualInsight = nil

        let isPro = FeatureGateService.shared.canAccess(.smartInsightsAI)
        let hasConsent = UserDefaults.standard.bool(forKey: "aiInsightsConsentAccepted")
        let isOnline = NetworkMonitor.shared.isConnected

        guard isPro, hasConsent, isOnline, transactions.count >= 5 else {
            return
        }

        // Debounce: wait 10s after last filter change before calling LLM
        do {
            try await Task.sleep(for: .seconds(10))
        } catch {
            return // Task cancelled — filters changed again, skip LLM call
        }

        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCodeRaw) ?? .pen
        let txnCount = transactions.count
        let tone = InsightTone.current
        let focus = InsightFocus.current
        let country = Locale.current.region?.identifier ?? ""
        let currencyFormat = UserDefaults.standard.string(forKey: "currencyDisplayFormat") ?? "code"
        let cacheKey = "panel_\(insightTaskKey)_\(txnCount)_\(country)_\(currencyFormat)"

        // Calculate InsightData
        let criteria = viewModel.buildFilterCriteria(dateInterval: viewModel.panelDateInterval)
        let data = InsightsCalculator.calculate(
            transactions: transactions,
            accounts: accounts,
            categories: categories,
            budgets: budgets,
            scheduledPayments: scheduledPayments,
            period: viewModel.selectedPeriod,
            criteria: criteria,
            currencyCode: preferredCurrency.rawValue,
            customRange: viewModel.customDateRange
        )

        // Build lightweight aggregated dict (subset — no filter context, no year-over-year)
        var aggregated: [String: Any] = [
            "currency": preferredCurrency.rawValue,
            "currency_display": YalaFormatter.currencyIdentifier(for: preferredCurrency.rawValue),
            "locale": Locale.current.language.languageCode?.identifier ?? "es",
            "country": Locale.current.region?.identifier ?? "",
            "total_expense": Int(data.periodSummary.totalExpense),
            "total_income": Int(data.periodSummary.totalIncome),
            "spending_total_variation": data.periodSummary.expenseVariation.map { "\(Int($0))%" } ?? "N/A",
            "income_variation": data.periodSummary.incomeVariation.map { "\(Int($0))%" } ?? "N/A",
            "daily_avg_variation": data.periodSummary.dailyAverageVariation.map { "\(Int($0))%" } ?? "N/A",
            "count": data.periodSummary.transactionCount,
            "daily_avg": Int(data.quickStats.dailyAverage)
        ]

        // Top 3 categories with amounts (reduced vs full insights top 5)
        if !data.quickStats.topCategories.isEmpty {
            aggregated["top_categories"] = data.quickStats.topCategories.prefix(3).map {
                ["name": $0.category.name, "amount": Int($0.amount), "pct": Int($0.percentage)] as [String: Any]
            }
        }

        // Top subcategory
        if let topSub = data.quickStats.topSubcategory {
            let subName = topSub.subcategory?.name ?? topSub.subcategoryName
            let totalExpense = data.periodSummary.totalExpense
            let pctOfTotal = totalExpense > 0 ? Int((topSub.amount / totalExpense) * 100) : 0
            aggregated["top_subcategory"] = ["name": subName, "amount": Int(topSub.amount), "pct_of_total": pctOfTotal] as [String: Any]
        }

        // Highest expense
        if let highest = data.quickStats.highestExpense {
            aggregated["highest_expense"] = ["amount": Int(highest.amount), "description": highest.note] as [String: Any]
        }

        // Subscriptions (Netflix, Spotify, etc.)
        if data.commitments.activeSubscriptionsCount > 0 {
            aggregated["subscriptions"] = ["count": data.commitments.activeSubscriptionsCount, "monthly_total": Int(data.commitments.activeSubscriptionsMonthly)] as [String: Any]
        }

        // Recurring payments (rent, utilities, payroll, etc.)
        if data.commitments.activeRecurringCount > 0 {
            aggregated["recurring_payments"] = ["count": data.commitments.activeRecurringCount, "monthly_total": Int(data.commitments.activeRecurringMonthly)] as [String: Any]
        }

        let needDist = data.needDistribution
        if needDist.total > 0 {
            aggregated["need_split"] = [
                "essential": ["pct": Int(needDist.essentialPercent), "amount": Int(needDist.essential)] as [String: Any],
                "priority": ["pct": Int(needDist.priorityPercent), "amount": Int(needDist.priority)] as [String: Any],
                "optional": ["pct": Int(needDist.optionalPercent), "amount": Int(needDist.optional)] as [String: Any]
            ]
        }

        if !data.commitments.budgetsAtRisk.isEmpty {
            aggregated["budgets_at_risk"] = data.commitments.budgetsAtRisk.map {
                ["name": $0.name, "spent": Int($0.spent), "limit": Int($0.limit), "usage_pct": Int($0.usagePercent)] as [String: Any]
            }
        }

        // Loading state only covers the async LLM call
        isLoadingInsight = true
        defer { isLoadingInsight = false }

        do {
            let result = try await InsightsLLMService.shared.generateContextualInsight(
                aggregatedData: aggregated,
                cacheKey: cacheKey,
                tone: tone,
                focus: focus
            )

            guard !Task.isCancelled else { return }
            contextualInsight = result
        } catch {
            #if DEBUG
            print("PanelView: Contextual insight error: \(error)")
            #endif
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
                let hasNeedFilter = viewModel.selectedNeed != nil
                let hasSubcategoryFilter = !viewModel.selectedSubcategoryIDs.isEmpty
                let hasTagFilter = !viewModel.selectedTags.isEmpty
                let hasCurrencyFilter = !viewModel.selectedCurrencies.isEmpty
                let hasAmountFilter = viewModel.amountCondition.isActive
                let hasNoteFilter = !viewModel.searchText.isEmpty
                let hasTransactionNatureFilter = sessionState.selectedTransactionNatures.count == 1

                let activeFilterCount = [
                    hasAccountFilter, hasDateFilter, hasCategoryFilter,
                    hasNeedFilter, hasSubcategoryFilter, hasTagFilter,
                    hasCurrencyFilter, hasAmountFilter, hasNoteFilter,
                    hasTransactionNatureFilter,
                ].filter { $0 }.count

                if activeFilterCount > 0 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.sm) {
                            // Exclude mode badge
                            if viewModel.isExcludeMode {
                                HStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: "minus.circle.fill")
                                        .font(DS.Typography.chipIconOnly)
                                        .foregroundStyle(DS.Semantic.errorForeground)
                                        .accessibilityHidden(true)
                                    Text(L10n.Filters.excludeMode)
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(DS.Semantic.errorForeground)
                                }
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(DS.Semantic.errorBackgroundSubtle, in: Capsule())
                            }

                            // Account Chip
                            if let selectedID = viewModel.selectedAccountID,
                                let account = accounts.first(where: {
                                    $0.persistentModelID == selectedID
                                })
                            {
                                FilterChipView(
                                    accountName: account.name,
                                    onClear: { viewModel.selectedAccountID = nil }
                                ).excludeMode(viewModel.isExcludeMode)
                            }

                            // Date Chip
                            if let focusedDate = viewModel.focusedDate {
                                FilterChipView(
                                    text: L10n.Filters.datePrefix(formattedDate(focusedDate)),
                                    onClear: {
                                        dsWithAnimation(reduceMotion) {
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
                                ).excludeMode(viewModel.isExcludeMode)
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
                                    ).excludeMode(viewModel.isExcludeMode)
                                }
                            }

                            // Subcategory Chip (aggregated from selected subcategory IDs)
                            if !isAllSubsSelected && !selectedSubsByID.isEmpty {
                                if let firstSub = selectedSubsByID.first {
                                    let color =
                                        (firstSub.colorHex?.isEmpty == false
                                            ? firstSub.colorHex : nil)
                                        ?? firstSub.safeCategory.colorHex
                                    FilterChipView(
                                        subcategoryName: firstSub.name,
                                        iconName: firstSub.iconName,
                                        colorHex: color,
                                        count: selectedSubsByID.count,
                                        onClear: {
                                            viewModel.selectedSubcategoryIDs.removeAll()
                                            sessionState.selectedSubcategoryIDs.removeAll()
                                        }
                                    ).excludeMode(viewModel.isExcludeMode)
                                }
                            }

                            // Nature Chip (Subcategory Nature: essential/priority/optional)
                            if let need = viewModel.selectedNeed {
                                FilterChipView(
                                    need: need,
                                    onClear: {
                                        dsWithAnimation(reduceMotion) { viewModel.selectedNeed = nil }
                                    }
                                ).excludeMode(viewModel.isExcludeMode)
                            }

                            // Transaction Nature Chip (Income/Expense)
                            if sessionState.selectedTransactionNatures.count == 1,
                               let transactionNature = sessionState.selectedTransactionNatures.first {
                                FilterChipView(
                                    transactionNature: transactionNature,
                                    onClear: {
                                        dsWithAnimation(reduceMotion) {
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
                                            dsWithAnimation(reduceMotion) {
                                                viewModel.selectedTags.remove(tagID)
                                                viewModel.syncToSessionState(sessionState)
                                            }
                                        }
                                    ).excludeMode(viewModel.isExcludeMode)
                                }
                            }

                            // Currency Chips
                            ForEach(Array(viewModel.selectedCurrencies), id: \.self) { currency in
                                FilterChipView(
                                    currencyCode: currency.rawValue,
                                    onClear: {
                                        dsWithAnimation(reduceMotion) {
                                            viewModel.selectedCurrencies.remove(currency)
                                            viewModel.syncToSessionState(sessionState)
                                        }
                                    }
                                ).excludeMode(viewModel.isExcludeMode)
                            }

                            // Amount Chip
                            if viewModel.amountCondition.isActive {
                                FilterChipView(
                                    amountText: viewModel.amountCondition.displayText,
                                    onClear: {
                                        dsWithAnimation(reduceMotion) {
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
                                        dsWithAnimation(reduceMotion) {
                                            viewModel.searchText = ""
                                            viewModel.syncToSessionState(sessionState)
                                        }
                                    }
                                )
                            }

                            // Clear All Button
                            if activeFilterCount > 1 {
                                Button {
                                    dsWithAnimation(reduceMotion) {
                                        clearAllPanelFilters()
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityLabel(L10n.Accessibility.clearFilters)
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    Spacer()
                }
            }
            .padding(.bottom, DS.Spacing.sm)

            // Widgets section header + first widget — spotlight anchor for tour
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                HStack {
                    Text(L10n.Panel.widgets)
                        .font(DS.Typography.title)

                    Spacer()

                    Button {
                        showWidgetPreferences = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(DS.Typography.body).fontWeight(.medium)
                            .foregroundStyle(Color.primary)
                    }
                    .accessibilityLabel(L10n.Accessibility.widgetPreferences)
                    .coachMarkAnchor("widgetPreferences")
                }
                .padding(.trailing, DS.Spacing.xxs)

                // First widget row (included in "widgets" spotlight)
                if let firstRow = viewModel.layoutRows.first {
                    widgetRow(for: firstRow)
                }
            }
            .coachMarkAnchor("widgets")
            .coachMarkAnchor("interactiveWidgets")

            // Remaining widget rows
            VStack(spacing: DS.Spacing.lg) {
                ForEach(viewModel.layoutRows.dropFirst()) { row in
                    widgetRow(for: row)
                }
            }

            EmptyView()
                .onChange(of: viewModel.selectedCategoryID) {
                    recalculateData()
                }
                .onChange(of: viewModel.focusedDate) {
                    recalculateData()
                }
                .onChange(of: viewModel.selectedNeed) {
                    recalculateData()
                }
        }

    }

    private static let chipDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "d MMM"
        return f
    }()

    private func formattedDate(_ date: Date) -> String {
        Self.chipDateFormatter.string(from: date)
    }

    /// Pull-to-refresh: sync preferences + reload data
    private func refreshData() async {
        PreferenceSyncService.shared.bootstrap()
        recalculateData()
        try? await Task.sleep(for: .milliseconds(300))
        DS.Haptic.light()
    }

    /// Renders a single widget layout row (full-width or half-width pair)
    @ViewBuilder
    private func widgetRow(for row: WidgetConfigManager.WidgetRow) -> some View {
        switch row.type {
        case .fullWidth(let config):
            widgetView(for: config)
                .clipped()
        case .halfWidthPair(let left, let right):
            HStack(alignment: .top, spacing: DS.Spacing.lg) {
                widgetView(for: left)
                    .frame(maxWidth: .infinity)
                    .clipped()

                if let right = right {
                    widgetView(for: right)
                        .frame(maxWidth: .infinity)
                        .clipped()
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// Check and trigger interactivity tour if conditions are met
    private func triggerInteractivityTourIfEligible() {
        guard hasSeenPanelTour, !hasSeenInteractivityTour, !showPanelTour, !showInteractivityTour else { return }
        let uniqueDays = Set(transactions.map { Calendar.current.startOfDay(for: $0.date) }).count
        guard uniqueDays >= 2 else { return }
        Task {
            try? await Task.sleep(for: .seconds(1.0))
            if !showInteractivityTour {
                showInteractivityTour = true
            }
        }
    }

    /// Recalculate trend data with smooth animation
    private func recalculateData() {
        // Reload fresh data from SwiftData first
        viewModel.loadData()

        // Direct synchronous call for instant response
        dsWithAnimation(reduceMotion, .easeOut(duration: 0.15)) {
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
    private func actualWidgetView(for config: WidgetConfig) -> some View {
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCodeRaw) ?? .pen
        let balance = viewModel.displayedBalanceInDefaultCurrency(
            accounts: accounts,
            transactions: transactions,
            defaultCurrencyCode: defaultCurrencyCodeRaw
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
                isExcludeMode: viewModel.isExcludeMode,
                onSelectCategory: { id in
                    dsWithAnimation(reduceMotion) {
                        viewModel.toggleCategoryFilter(id)
                    }
                },
                onShowMore: { navigateToStatistics(.categories) },
                size: mapWidgetSize(config.size),
                period: viewModel.selectedPeriod,
                previousTotalAmount: viewModel.previousCategoriesTotalAmount,
                showVariationHeader: showVariations && viewModel.selectedPeriod != .allTime
            )
        } else if config.type == .topSubcategories {
            TopSubcategoriesWidget(
                subcategories: viewModel.topSubcategories,
                currencyCode: preferredCurrency.rawValue,
                globalCategoryFilterID: viewModel.selectedCategoryID,
                localCategoryFilterID: $viewModel.subcategoriesWidgetFilter,
                onSelectSubcategory: { subcategoryID in
                    dsWithAnimation(reduceMotion) {
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
                isExcludeMode: viewModel.isExcludeMode,
                onShowMore: { navigateToStatistics(.categories) },
                size: mapWidgetSize(config.size),
                period: viewModel.selectedPeriod,
                previousTotalAmount: viewModel.previousSubcategoriesTotalAmount,
                showVariationHeader: showVariations && viewModel.selectedPeriod != .allTime
            )
        } else if config.type == .categoriesPie {
            CategoriesPieWidget(
                categories: viewModel.topSpendingCategories,
                currencyCode: preferredCurrency.rawValue,
                selectedCategoryIDs: viewModel.selectedCategoryID.map { Set([$0]) } ?? [],
                onSelectCategory: { id in
                    dsWithAnimation(reduceMotion) {
                        viewModel.toggleCategoryFilter(id)
                    }
                },
                onShowDetail: { navigateToStatistics(.categories) },
                isExcludeMode: viewModel.isExcludeMode,
                size: config.size,
                period: viewModel.selectedPeriod,
                previousTotalAmount: viewModel.previousCategoriesTotalAmount,
                showVariationHeader: showVariations && viewModel.selectedPeriod != .allTime
            )
        } else if config.type == .subcategoriesPie {
            SubcategoriesPieWidget(
                subcategories: viewModel.topSubcategories,
                currencyCode: preferredCurrency.rawValue,
                selectedCategoryID: viewModel.selectedCategoryID,
                selectedSubcategoryIDs: viewModel.selectedSubcategoryIDs,
                onSelectSubcategory: { subcategoryID in
                    dsWithAnimation(reduceMotion) {
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
                isExcludeMode: viewModel.isExcludeMode,
                size: config.size,
                period: viewModel.selectedPeriod,
                previousTotalAmount: viewModel.previousSubcategoriesTotalAmount,
                showVariationHeader: showVariations && viewModel.selectedPeriod != .allTime
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
                    selectedTransactionNatures: viewModel.selectedTransactionNatures,
                    isExpensesOnlyMode: sessionState.isExpensesOnlyMode
                )
            } else {
                YalaEmptyState(
                    icon: "chart.bar.fill",
                    title: L10n.Empty.noData,
                    message: L10n.Statistics.noRecordsDescription
                )
                .frame(height: 200)
            }
        } else if config.type == .latestRecords {
            RecentRecordsWidget(
                records: viewModel.latestRecords,
                currencyCode: preferredCurrency.rawValue,
                onShowMore: { navigateToStatistics(.records) }
            )
        } else if config.type == .expensesByNeed {
            NeedTrendWidget(
                trendPoints: viewModel.needTrendPoints,
                selectedNeed: viewModel.selectedNeed,
                currencyCode: preferredCurrency.rawValue,
                size: mapWidgetSize(config.size),
                grouping: viewModel.needGrouping,
                interval: viewModel.currentInterval,
                onSelectNeed: { need in
                    dsWithAnimation(reduceMotion) {
                        viewModel.toggleNeedFilter(need)
                    }
                },
                onShowDetail: { navigateToStatistics(.categories) },
                period: viewModel.selectedPeriod,
                previousTotalAmount: viewModel.previousNeedTotalAmount,
                previousAmountByNeed: viewModel.previousNeedAmounts,
                showVariationHeader: showVariations && viewModel.selectedPeriod != .allTime,
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
            let selectedBudget = sessionState.selectedBudgetID.flatMap { selectedID in
                viewModel.topBudgetSummaries.first { $0.budget.persistentModelID == selectedID }?.budget
            }
            let displayCurrency = selectedBudget?.currencyCode ?? preferredCurrency.rawValue

            BudgetsWidget(
                budgets: viewModel.topBudgetSummaries,
                currencyCode: displayCurrency,
                hasBudgetsButNoFavorites: viewModel.hasBudgetsButNoFavorites,
                selectedBudgetID: sessionState.selectedBudgetID,
                isExcludeMode: viewModel.isExcludeMode,
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
        let start = dates.min() ?? Date.now
        let end = dates.max() ?? Date.now
        return (start, end)
    }

    /// Clear all Panel filters and sync to SessionState
    private func clearAllPanelFilters() {
        viewModel.selectedAccountID = nil
        viewModel.focusedDate = nil
        viewModel.selectedCategoryID = nil
        viewModel.selectedSubcategoryIDs.removeAll()
        viewModel.subcategoriesWidgetFilter = nil
        viewModel.selectedNeed = nil
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

// MARK: - Panel Data Observers Modifier

/// Encapsulates data-related onChange observers to reduce body complexity
private struct PanelDataObservers: ViewModifier {
    let accounts: [Account]
    let transactions: [TransactionItem]
    let budgets: [Budget]
    let allSubcategories: [Subcategory]
    let sessionState: SessionState
    let viewModel: PanelViewModel
    @Binding var showFABMenu: Bool
    @Binding var accountsSortOrderNamesRaw: String
    @Binding var defaultCurrencyCodeRaw: String
    let recalculateData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedMainTab) { _, _ in
                if showFABMenu {
                    showFABMenu = false
                }
            }
            .onChange(of: accounts) { _, _ in
                let newOrder = viewModel.ensureAccountsSortOrderConsistency(
                    accounts: accounts,
                    currentOrderRaw: accountsSortOrderNamesRaw
                )
                if newOrder != accountsSortOrderNamesRaw {
                    accountsSortOrderNamesRaw = newOrder
                }
            }
            .onChange(of: transactions) { _, _ in
                recalculateData()
            }
            .onChange(of: budgets) { _, _ in
                recalculateData()
            }
            .onChange(of: allSubcategories) { _, _ in
                recalculateData()
            }
            .onChange(of: sessionState.needsBudgetsWidgetRefresh) { _, needsRefresh in
                if needsRefresh {
                    recalculateData()
                    sessionState.needsBudgetsWidgetRefresh = false
                }
            }
            .onChange(of: defaultCurrencyCodeRaw) { _, _ in
                recalculateData()
            }
            .onChange(of: sessionState.formattingVersion) { _, _ in
                recalculateData()
            }
            .onChange(of: sessionState.dataVersion) { _, _ in
                recalculateData()
            }
            .onChange(of: viewModel.trendType) { _, _ in
                viewModel.syncToSessionState(sessionState)
                recalculateData()
            }
    }
}

// MARK: - Panel Sheet Triggers Modifier

/// Encapsulates onChange observers that trigger sheet presentations
private struct PanelSheetTriggers: ViewModifier {
    let sessionState: SessionState
    @Binding var showInbox: Bool
    @Binding var showImageSelection: Bool
    @Binding var showVoiceRecording: Bool
    @Binding var showNewTransaction: Bool
    @Binding var showUpgradeForVoice: Bool
    @Binding var showUpgradeForImage: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.shouldShowInbox) { _, shouldShow in
                if shouldShow {
                    showInbox = true
                    sessionState.shouldShowInbox = false
                }
            }
            .onChange(of: sessionState.shouldShowSharedImage) { _, shouldShow in
                if shouldShow {
                    showImageSelection = true
                    sessionState.shouldShowSharedImage = false
                }
            }
            .onChange(of: sessionState.shouldShowVoiceEntry) { _, shouldShow in
                if shouldShow {
                    showVoiceRecording = true
                    sessionState.shouldShowVoiceEntry = false
                }
            }
            .onChange(of: sessionState.shouldShowImageEntry) { _, shouldShow in
                if shouldShow {
                    showImageSelection = true
                    sessionState.shouldShowImageEntry = false
                }
            }
            .onChange(of: sessionState.shouldShowNewTransaction) { _, shouldShow in
                if shouldShow {
                    showNewTransaction = true
                    sessionState.shouldShowNewTransaction = false
                }
            }
            .onChange(of: sessionState.shouldShowUpgradeForVoice) { _, shouldShow in
                if shouldShow {
                    showUpgradeForVoice = true
                    sessionState.shouldShowUpgradeForVoice = false
                }
            }
            .onChange(of: sessionState.shouldShowUpgradeForImage) { _, shouldShow in
                if shouldShow {
                    showUpgradeForImage = true
                    sessionState.shouldShowUpgradeForImage = false
                }
            }
    }
}

// MARK: - Panel Sheets Modifier

/// Encapsulates sheet presentations to reduce body complexity and avoid type-checker limits
private struct PanelSheetsModifier: ViewModifier {
    @Binding var accountFormSheet: AccountFormSheet?
    @Binding var isPresentingSettings: Bool
    @Binding var showWidgetPreferences: Bool
    @Binding var showNewTransaction: Bool
    @Binding var showVoiceRecording: Bool
    @Binding var showImageSelection: Bool
    @Binding var showCustomPeriodPicker: Bool
    @Binding var showBudgetFavoritesSettings: Bool
    @Binding var showInbox: Bool
    @Binding var showUpgradeForVoice: Bool
    @Binding var showUpgradeForImage: Bool
    @Binding var showUpgradeForAccounts: Bool
    @Binding var navigateToInboxAfterVoice: Bool
    @Binding var switchToImageAfterVoice: Bool
    @Binding var navigateToInboxAfterImage: Bool
    @Binding var showAIConsentAlert: Bool
    @Binding var pendingAIInput: PendingAIInput

    let existingAccountNames: (Account?) -> [String]
    let prefillAccountID: PersistentIdentifier?
    let prefillCategoryID: PersistentIdentifier?
    let prefillSubcategoryName: String?
    let transactionDateRange: (start: Date, end: Date)
    let customDateRange: DateInterval?
    let viewModel: PanelViewModel
    let navigateToStatistics: (DetailViewTab) -> Void
    let recalculateData: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(item: $accountFormSheet) { sheet in
                AccountFormView(
                    existingNames: existingAccountNames(sheet.account),
                    accountToEdit: sheet.account
                )
                .onDisappear {
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
                NewTransactionView(
                    prefillAccountID: prefillAccountID,
                    prefillCategoryID: prefillCategoryID,
                    prefillSubcategoryName: prefillSubcategoryName
                )
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showVoiceRecording, onDismiss: {
                handleVoiceRecordingDismiss()
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
                handleImageSelectionDismiss()
            }) {
                ImageSelectionView(onSavedToInbox: {
                    navigateToInboxAfterImage = true
                })
            }
            .sheet(isPresented: $showCustomPeriodPicker) {
                CustomPeriodPickerSheet(
                    minDate: transactionDateRange.start,
                    maxDate: transactionDateRange.end,
                    currentRange: customDateRange
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
            .sheet(isPresented: $showUpgradeForVoice) {
                UpgradePromptSheet(feature: .voiceInput, context: .proFeature)
            }
            .sheet(isPresented: $showUpgradeForImage) {
                UpgradePromptSheet(feature: .imageInput, context: .proFeature)
            }
            .sheet(isPresented: $showUpgradeForAccounts) {
                UpgradePromptSheet(feature: .accounts, context: .limitReached)
            }
            .aiConsentAlert(isPresented: $showAIConsentAlert, pendingInput: $pendingAIInput) { input in
                switch input {
                case .voice: showVoiceRecording = true
                case .image: showImageSelection = true
                }
            }
    }

    private func handleVoiceRecordingDismiss() {
        if navigateToInboxAfterVoice {
            navigateToInboxAfterVoice = false
            showInbox = true
        }
        if switchToImageAfterVoice {
            switchToImageAfterVoice = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showImageSelection = true
            }
        }
        recalculateData()
    }

    private func handleImageSelectionDismiss() {
        if navigateToInboxAfterImage {
            navigateToInboxAfterImage = false
            showInbox = true
        }
        recalculateData()

        // If there's a deferred panel action (e.g., Control Center "new-transaction"
        // that arrived while shared image was showing), resolve it now
        AppBootstrapper.shared.showDeferredActionsIfNeeded()
    }
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
                // Skip in exclude mode — selecting a category to exclude doesn't imply expense-only
                if !sessionState.isExcludeMode && !sessionState.selectedCategoryIDs.isEmpty {
                    let selectedCats = categories.filter {
                        sessionState.selectedCategoryIDs.contains($0.persistentModelID)
                    }
                    // Only set expense/income if we found matching categories AND all share the same type
                    if !selectedCats.isEmpty {
                        if selectedCats.allSatisfy({ !$0.isIncome }) {
                            sessionState.selectedTransactionNatures = [.expense]
                        } else if selectedCats.allSatisfy({ $0.isIncome }) {
                            sessionState.selectedTransactionNatures = [.income]
                        }
                    }
                }
                recalculateData()
            }
            .onChange(of: sessionState.selectedNeeds) {
                // Auto-create expense chip when nature filter applied (natures are expense-only)
                // Skip in exclude mode
                if !sessionState.isExcludeMode && !sessionState.selectedNeeds.isEmpty {
                    sessionState.selectedTransactionNatures = [.expense]
                }
                recalculateData()
            }
            .onChange(of: sessionState.selectedSubcategoryIDs) {
                // Auto-create expense chip only if ALL selected subcategories are from expense categories
                // Skip in exclude mode
                if !sessionState.isExcludeMode && !sessionState.selectedSubcategoryIDs.isEmpty {
                    let selectedSubs = subcategories.filter {
                        sessionState.selectedSubcategoryIDs.contains($0.persistentModelID)
                    }
                    // Only set expense/income if we found matching subcategories AND all share the same type
                    if !selectedSubs.isEmpty {
                        if selectedSubs.allSatisfy({ !$0.safeCategory.isIncome }) {
                            sessionState.selectedTransactionNatures = [.expense]
                        } else if selectedSubs.allSatisfy({ $0.safeCategory.isIncome }) {
                            sessionState.selectedTransactionNatures = [.income]
                        }
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
            .onChange(of: sessionState.isExcludeMode) {
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

// MARK: - Contextual Insight Card

private struct ContextualInsightCard: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "sparkles")
                .font(DS.Typography.title)
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)

            Text(markdownAttributed(text))
                .font(DS.Typography.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Panel.dismissInsight)
        }
        .padding(DS.Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    private func markdownAttributed(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }
}

// MARK: - Siri Tip Card

private struct SiriTipCard: View {
    @Binding var isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "mic.badge.plus")
                .font(DS.Typography.title)
                .foregroundStyle(.tint)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Tips.Siri.title)
                    .font(DS.Typography.headline)

                Text(L10n.Tips.Siri.detail)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                dsWithAnimation(reduceMotion) {
                    isVisible = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Tips.Siri.close)
        }
        .padding(DS.Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        ))
    }
}
