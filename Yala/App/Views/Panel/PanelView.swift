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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SessionState.self) private var sessionState
    @Environment(ExchangeRateService.self) private var exchangeRateService
    @Environment(CurrencyConverter.self) private var currencyConverter

    @State private var viewModel = PanelViewModel()



    @State private var isPresentingSettings = false

    /// Sheet presentation state for account form
    @State private var accountFormSheet: AccountFormSheet?

/// Widget Preferences Sheet
    @State private var showWidgetPreferences = false

    /// New Transaction Sheet
    @State private var showNewTransaction = false

    /// Subscription sheet from banners
    @State private var showSubscriptionFromBanner = false
    @State private var subscriptionBannerSource = "direct"

    /// Periodic banner visibility
    @State private var showPeriodicBanner = false

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

    /// Coach mark: Pro tour (Phase 2)
    @State private var showProFabTour = false
    @State private var proFabTourIndex = 0

    /// Setup Checklist state
    @State private var practiceCleanupItem: PracticeCleanupItem?
    @State private var isVoiceSetupTrial = false
    @State private var isImageSetupTrial = false
    @State private var setupTrialExampleImages: [UIImage]? = nil

    /// Upgrade prompt sheets for gated features
    @State private var showUpgradeForVoice = false
    @State private var showUpgradeForImage = false
    @State private var showUpgradeForAccounts = false

    /// Check if accounts limit is reached (Pro feature)
    private var isAccountsLimitReached: Bool {
        let activeCount = viewModel.accounts.count(where: { !$0.isArchived })
        return !FeatureGateService.shared.canCreate(.accounts, currentCount: activeCount)
    }

    /// Check if Statistics tab is visible
    private var isStatisticsVisible: Bool {
        TabBarConfiguration.fromJSON(tabConfigJSON).activeTabs.contains(.statistics)
    }

    /// Check if voice input can be used (requires accounts and subcategories)
    private var canUseVoiceInput: Bool {
        let hasActiveAccounts = viewModel.accounts.contains { !$0.isArchived }
        let hasVisibleSubcategories = viewModel.allSubcategories.contains { $0.isVisible }
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

    // MARK: - Practice Cleanup

    private func consumePendingPracticeCleanup() {
        let mgr = SetupChecklistManager.shared
        if let pending = mgr.pendingPracticeCleanup {
            practiceCleanupItem = pending
            mgr.pendingPracticeCleanup = nil
        }
    }

    private func deletePracticeItem(_ item: PracticeCleanupItem) {
        do {
            for pid in item.allPersistentIDs {
                switch item.kind {
                case .transaction: try deletePracticeModel(TransactionItem.self, id: pid)
                case .draft: try deletePracticeModel(InboxDraft.self, id: pid)
                case .budget: try deletePracticeModel(Budget.self, id: pid)
                case .scheduledPayment: try deletePracticeModel(ScheduledPayment.self, id: pid)
                }
            }
            try modelContext.save()
        } catch {
            #if DEBUG
            print("SetupChecklist: Error deleting practice item: \(error)")
            #endif
        }
    }

    private func deletePracticeModel<T: PersistentModel>(_ type: T.Type, id: PersistentIdentifier) throws {
        let all = try modelContext.fetch(FetchDescriptor<T>())
        guard let match = all.first(where: { $0.persistentModelID == id }) else {
            #if DEBUG
            print("SetupChecklist: Practice \(T.self) not found — ID mismatch")
            #endif
            return
        }
        modelContext.delete(match)
    }

    // MARK: - Setup Checklist Navigation

    private func handleSetupStep(_ step: SetupStepID) {
        switch step {
        case .firstExpense:
            showNewTransaction = true
        case .firstBudget:
            sessionState.shouldAutoOpenBudgetEditor = true
            sessionState.navigateToBudgets()
        case .scheduledPayment:
            sessionState.shouldAutoOpenScheduledEditor = true
            sessionState.navigateToScheduledPayments()
        case .exploreSettings:
            // Opens Profile which will trigger the Settings tour
            isPresentingSettings = true
            SetupChecklistManager.shared.markCompleted(.exploreSettings)
        case .discoverFeatures:
            if FeatureGateService.shared.isProUser {
                // Pro users: just mark as completed
                SetupChecklistManager.shared.markCompleted(.discoverFeatures)
            } else {
                // Free users: show subscription/trial sheet
                subscriptionBannerSource = "setupChecklist"
                showSubscriptionFromBanner = true
                SetupChecklistManager.shared.markCompleted(.discoverFeatures)
            }
        case .tryVoiceInput:
            FeatureGateService.shared.enableSetupTrial(for: .voiceInput)
            isVoiceSetupTrial = true
            if !voiceInputEnabled { voiceInputEnabled = true }
            showVoiceRecording = true
        case .tryImageInput:
            FeatureGateService.shared.enableSetupTrial(for: .imageInput)
            isImageSetupTrial = true
            if !imageInputEnabled { imageInputEnabled = true }
            setupTrialExampleImages = loadExampleImages()
            showImageSelection = true
        }
    }

    private func loadExampleImages() -> [UIImage]? {
        let supportedLangs: Set<String> = ["de", "en", "es", "fr", "it", "pt"]
        let lang = Bundle.main.preferredLocalizations.first ?? "en"
        let suffix = supportedLangs.contains(lang) ? lang : "en"
        let images = [
            "ExampleImages/example-receipt-\(suffix)",
            "ExampleImages/example-bank-alert-\(suffix)",
            "ExampleImages/example-transaction-list-\(suffix)"
        ].compactMap { UIImage(named: $0) }
        return images.isEmpty ? nil : images
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
                if viewModel.pendingDrafts.count > 0 {
                    Text("\(min(viewModel.pendingDrafts.count, 99))")
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
            viewModel.allSubcategories.first(where: { $0.persistentModelID == subcategoryID })?.name
        }
    }

    var body: some View {
        NavigationStack {
            mainContent
                .yalaSkeleton(!viewModel.isReady)
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
                SetupChecklistManager.shared.expandAfterTour()
                ProTourManager.shared.triggerIfEligible()
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
        .coachMarkOverlay(
            steps: ProTourSteps.panelSteps,
            isPresented: $showProFabTour,
            currentIndex: $proFabTourIndex,
            scrollProxy: panelScrollProxy,
            onComplete: {
                ProTourManager.shared.advancePhase()
            }
        )
        .task(id: ProTourManager.shared.currentPhase) {
            guard !ProTourManager.shared.hasCompleted,
                  ProTourManager.shared.currentPhase == .panel else { return }
            do { try await Task.sleep(for: .seconds(0.8)) } catch { return }
            guard ProTourManager.shared.currentPhase == .panel,
                  !showPanelTour, !showInteractivityTour,
                  !showProFabTour else { return }
            showProFabTour = true
        }
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
                practiceCleanupItem: $practiceCleanupItem,
                isVoiceSetupTrial: $isVoiceSetupTrial,
                isImageSetupTrial: $isImageSetupTrial,
                setupTrialExampleImages: $setupTrialExampleImages,
                deletePracticeItem: deletePracticeItem,
                existingAccountNames: existingAccountNames,
                prefillAccountID: viewModel.selectedAccountID,
                prefillCategoryID: viewModel.selectedCategoryID,
                prefillSubcategoryName: prefillSubcategoryName,
                transactionDateRange: transactionDateRange,
                customDateRange: sessionState.customDateRange,
                viewModel: viewModel,
                navigateToStatistics: navigateToStatistics
            )
        )
        .sheet(isPresented: $showSubscriptionFromBanner) {
            NavigationStack {
                SubscriptionView(source: subscriptionBannerSource)
            }
        }
        .appliesPendingRemoteChanges(sessionState)
        .onAppear {
            viewModel.widgetConfig.columns = DS.Adaptive.columns(sizeClass)
            viewModel.setContext(
                modelContext,
                exchangeRateService: exchangeRateService,
                currencyConverter: currencyConverter,
                defaultCurrencyCode: defaultCurrencyCodeRaw,
                sessionState: sessionState
            )
            Task { TransferMigrationService.migratePositiveTransfersIfNeeded(in: modelContext) }
            viewModel.syncFromSessionState(sessionState)
            let newOrder = viewModel.ensureAccountsSortOrderConsistency(
                accounts: viewModel.accounts,
                currentOrderRaw: accountsSortOrderNamesRaw
            )
            if newOrder != accountsSortOrderNamesRaw {
                accountsSortOrderNamesRaw = newOrder
            }
            viewModel.reloadAndRecalculate()
        }
        .onDisappear {
            viewModel.cancelRecalculation()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                viewModel.setBackground(true)
            case .active:
                guard UIApplication.shared.applicationState == .active else { return }
                viewModel.setBackground(false)
                viewModel.reloadAndRecalculate()
            @unknown default:
                break
            }
        }
        .onChange(of: sizeClass) { _, newValue in
            viewModel.widgetConfig.columns = DS.Adaptive.columns(newValue)
        }
        .onChange(of: defaultCurrencyCodeRaw) { _, newValue in
            viewModel.updateDefaultCurrencyCode(newValue)
            viewModel.recalculateData()
        }
        .task {
            // Wait for post-onboarding flow (trial sheet) to complete
            while !sessionState.isReadyForTours {
                do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            }
            if !hasSeenPanelTour {
                // Start collapsed — expands after tour completes
                do { try await Task.sleep(for: .seconds(0.6)) } catch { return }
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
        .onChange(of: viewModel.transactions.count) { _, _ in
            triggerInteractivityTourIfEligible()
        }
        .modifier(
            PanelDataObservers(
                viewModel: viewModel,
                sessionState: sessionState,
                showFABMenu: $showFABMenu
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
                viewModel: viewModel,
                sessionState: sessionState
            )
        )
    }

    private var mainContent: some View {
        ZStack {
            PanelBackgroundView()

            ScrollViewReader { scrollProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        if showSiriTip, viewModel.transactions.count >= 5 {
                            SiriTipCard(isVisible: $showSiriTip)
                        }

                        // Update available banner (all users)
                        if AppUpdateService.shared.shouldShowBanner,
                           let updateVersion = AppUpdateService.shared.latestVersion {
                            UpdateAvailableBanner(
                                version: updateVersion,
                                appStoreURL: AppUpdateService.shared.appStoreURL,
                                onDismiss: { AppUpdateService.shared.dismissBanner() }
                            )
                        }

                        // Trial / periodic upgrade banner
                        if StoreKitManager.shared.isInTrial {
                            TrialBanner(
                                daysRemaining: StoreKitManager.shared.trialDaysRemaining
                            ) {
                                TelemetryService.track(.proUpsellTapped, parameters: TelemetryService.upsellParameters(source: "trialBanner"))
                                subscriptionBannerSource = "trialBanner"
                                showSubscriptionFromBanner = true
                            }
                            .onAppear {
                                var params = TelemetryService.upsellParameters(source: "trialBanner")
                                params["daysRemaining"] = String(StoreKitManager.shared.trialDaysRemaining)
                                TelemetryService.trackOnce(.proUpsellShown, key: "trialBanner", parameters: params)
                                if StoreKitManager.shared.isTrialExpiringSoon {
                                    TelemetryService.trackOnce(.trialExpiring, key: "trialExpiring", parameters: params)
                                }
                            }
                        } else if !FeatureGateService.shared.isProUser && showPeriodicBanner {
                            ProUpgradeBanner(
                                onUpgrade: {
                                    TelemetryService.track(.proUpsellTapped, parameters: TelemetryService.upsellParameters(source: "periodicBanner"))
                                    subscriptionBannerSource = "periodicBanner"
                                    showSubscriptionFromBanner = true
                                },
                                onDismiss: {
                                    TelemetryService.track(.proUpsellDismissed, parameters: TelemetryService.upsellParameters(source: "periodicBanner"))
                                    ProUpsellService.shared.recordDismissed()
                                    showPeriodicBanner = false
                                }
                            )
                            .onAppear {
                                TelemetryService.trackOnce(.proUpsellShown, key: "periodicBanner", parameters: TelemetryService.upsellParameters(source: "periodicBanner"))
                                ProUpsellService.shared.recordShown(source: "periodicBanner")
                            }
                        }

                        // Setup Checklist (persistent for new users)
                        SetupChecklistCard(
                            manager: SetupChecklistManager.shared,
                            onStepTapped: { step in handleSetupStep(step) }
                        )
                        .coachMarkAnchor("setupChecklist")

                        // Contextual guide for panel (first visit)
                        ContextualGuideBanner.panel()
                            .coachMarkAnchor("contextualGuide")

                        accountsSection
                        totalBalanceSection
                    }
                    .padding(.horizontal, DS.Adaptive.horizontalPadding(sizeClass))
                    .padding(.top, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.xxxl)
                }
                .refreshable {
                    await refreshData()
                }
                .onAppear {
                    panelScrollProxy = scrollProxy
                    showPeriodicBanner = ProUpsellService.shared.shouldShowPeriodicBanner()

                    // Setup checklist: auto-detect completed steps & manage collapse state
                    let mgr = SetupChecklistManager.shared
                    mgr.autoDetect(
                        transactionCount: viewModel.transactions.count,
                        budgetCount: viewModel.budgets.count,
                        scheduledCount: viewModel.scheduledPayments.count
                    )

                    // Keep collapsed until panel tour completes (avoids flash)
                    if !hasSeenPanelTour {
                        mgr.collapseForTour()
                    } else {
                        mgr.checkReExpand()
                    }

                    consumePendingPracticeCleanup()
                }
                .onChange(of: SetupChecklistManager.shared.pendingPracticeCleanup?.id) { _, newID in
                    guard newID != nil else { return }
                    consumePendingPracticeCleanup()
                }
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
                        .foregroundStyle(Color.contrastingText(for: theme.accent))
                        .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                        .background(showFABMenu ? DS.Semantic.disabledForeground : fabBackground)
                        .clipShape(Circle())
                        .rotationEffect(.degrees(showFABMenu ? 90 : 0))
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive())
                .dsFloatingShadow()
                .accessibilityLabel(showFABMenu ? L10n.Accessibility.closeMenu : L10n.Accessibility.newRecord)
                .accessibilityIdentifier("fab_new_transaction")
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
                    .foregroundStyle(Color.contrastingText(for: theme.accent))
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

            if viewModel.accounts.isEmpty {
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
                        from: viewModel.accounts,
                        sortOrderNames: accountsSortOrderNamesRaw.split(separator: "|").map(String.init)
                    ),
                    transactions: viewModel.transactions,
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
                ].count(where: { $0 })

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
                                let account = viewModel.accounts.first(where: {
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
                            let selectedSubsByID = viewModel.allSubcategories.filter {
                                viewModel.selectedSubcategoryIDs.contains($0.persistentModelID)
                            }
                            let isAllSubsSelected =
                                !selectedSubsByID.isEmpty
                                && selectedSubsByID.count == viewModel.allSubcategories.count

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
                                if let tag = viewModel.tags.first(where: { $0.persistentModelID == tagID }) {
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
            // Note: VStack (not Lazy) — LazyVStack caused crashes on tab switch because it
            // destroys off-screen widgets, then recreates them on return while performRecalculation
            // runs synchronously, overwhelming the main thread.
            VStack(spacing: DS.Spacing.lg) {
                ForEach(viewModel.layoutRows.dropFirst()) { row in
                    widgetRow(for: row)
                }
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
        viewModel.reloadAndRecalculate()
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
        let uniqueDays = Set(viewModel.transactions.map { Calendar.current.startOfDay(for: $0.date) }).count
        guard uniqueDays >= 2 else { return }
        Task {
            try? await Task.sleep(for: .seconds(1.0))
            if !showInteractivityTour {
                showInteractivityTour = true
            }
        }
    }

    // MARK: - Widget Helpers

    @ViewBuilder
    private func widgetView(for config: WidgetConfig) -> some View {
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCodeRaw) ?? .pen
        PanelWidgetRouter(
            config: config,
            viewModel: viewModel,
            sessionState: sessionState,
            currencyCode: preferredCurrency.rawValue,
            showVariations: showVariations,
            reduceMotion: reduceMotion,
            onNavigate: navigateToStatistics,
            onEditBudgetFavorites: { showBudgetFavoritesSettings = true }
        )
    }

    // MARK: - Helpers

    private func existingAccountNames(editingAccount: Account?) -> [String] {
        guard let editingAccount = editingAccount else {
            return viewModel.accounts.map { $0.name }
        }
        return
            viewModel.accounts
            .filter { $0.persistentModelID != editingAccount.persistentModelID }
            .map { $0.name }
    }

    /// Date range of all transactions (for custom period picker limits)
    private var transactionDateRange: (start: Date, end: Date) {
        let dates = viewModel.transactions.map(\.date)
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

/// Encapsulates data-related onChange observers to reduce body complexity.
/// Uses viewModel reference (O(1) comparison) instead of SwiftData arrays.
private struct PanelDataObservers: ViewModifier {
    let viewModel: PanelViewModel
    let sessionState: SessionState
    @Binding var showFABMenu: Bool

    func body(content: Content) -> some View {
        content
            .modifier(PanelDataCountObservers(viewModel: viewModel, sessionState: sessionState, showFABMenu: $showFABMenu))
            .modifier(PanelDataFilterObservers(viewModel: viewModel, sessionState: sessionState))
    }
}

/// Split 1: Count-based and session observers
private struct PanelDataCountObservers: ViewModifier {
    let viewModel: PanelViewModel
    let sessionState: SessionState
    @Binding var showFABMenu: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedMainTab) { _, _ in
                if showFABMenu { showFABMenu = false }
            }
            .onChange(of: viewModel.accounts.count) { _, _ in
                viewModel.recalculateData()
            }
            .onChange(of: viewModel.transactions.count) { _, _ in
                viewModel.recalculateData()
            }
            .onChange(of: viewModel.budgets.count) { _, _ in
                viewModel.recalculateData()
            }
            .onChange(of: viewModel.allSubcategories.count) { _, _ in
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.needsBudgetsWidgetRefresh) { _, needsRefresh in
                if needsRefresh {
                    viewModel.recalculateData()
                    sessionState.needsBudgetsWidgetRefresh = false
                }
            }
            .onChange(of: sessionState.formattingVersion) { _, _ in
                viewModel.recalculateData()
            }
    }
}

/// Split 2: Data version and ViewModel-local filter observers
private struct PanelDataFilterObservers: ViewModifier {
    let viewModel: PanelViewModel
    let sessionState: SessionState

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.dataVersion) { _, _ in
                viewModel.reloadAndRecalculate()
            }
            .onChange(of: viewModel.trendType) { _, _ in
                viewModel.syncToSessionState(sessionState)
                viewModel.recalculateData()
            }
            .onChange(of: viewModel.selectedCategoryID) {
                viewModel.recalculateData()
            }
            .onChange(of: viewModel.focusedDate) {
                viewModel.recalculateData()
            }
            .onChange(of: viewModel.selectedNeed) {
                viewModel.recalculateData()
            }
            .onChange(of: viewModel.subcategoriesWidgetFilter) {
                viewModel.recalculateData()
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
    @Binding var practiceCleanupItem: PracticeCleanupItem?
    @Binding var isVoiceSetupTrial: Bool
    @Binding var isImageSetupTrial: Bool
    @Binding var setupTrialExampleImages: [UIImage]?
    @State private var showPracticeAlert = false

    /// Deferred practice data — stored during callback, consumed in onDismiss.
    private struct DeferredPractice {
        let id: PersistentIdentifier
        let name: String
        let kind: PracticeItemKind
        let additionalIDs: [PersistentIdentifier]
    }
    @State private var deferredVoicePractice: DeferredPractice?
    @State private var deferredImagePractice: DeferredPractice?
    let deletePracticeItem: (PracticeCleanupItem) -> Void

    let existingAccountNames: (Account?) -> [String]
    let prefillAccountID: PersistentIdentifier?
    let prefillCategoryID: PersistentIdentifier?
    let prefillSubcategoryName: String?
    let transactionDateRange: (start: Date, end: Date)
    let customDateRange: DateInterval?
    let viewModel: PanelViewModel
    let navigateToStatistics: (DetailViewTab) -> Void

    func body(content: Content) -> some View {
        content
            .sheet(item: $accountFormSheet) { sheet in
                AccountFormView(
                    existingNames: existingAccountNames(sheet.account),
                    accountToEdit: sheet.account
                )
                .onDisappear {
                    viewModel.reloadAndRecalculate()
                }
            }
            .sheet(isPresented: $isPresentingSettings, onDismiss: {
                viewModel.reloadAndRecalculate()
            }) {
                ProfileView(initialDestination: SessionState.shared.pendingProfileDestination)
            }
            .sheet(isPresented: $showWidgetPreferences, onDismiss: {
                viewModel.endWidgetPreferencesEditing()
                viewModel.reloadAndRecalculate()
            }) {
                WidgetPreferencesView(viewModel: viewModel)
                    .presentationDragIndicator(.visible)
                    .onAppear {
                        viewModel.beginWidgetPreferencesEditing()
                    }
            }
            .sheet(isPresented: $showNewTransaction, onDismiss: {
                viewModel.reloadAndRecalculate()
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
                    },
                    onSetupTrialCompleted: isVoiceSetupTrial ? { itemID, itemName, kind in
                        deferredVoicePractice = DeferredPractice(
                            id: itemID, name: itemName, kind: kind, additionalIDs: []
                        )
                    } : nil,
                    onSetupTrialSkipped: isVoiceSetupTrial ? {
                        SetupChecklistManager.shared.markCompleted(.tryVoiceInput)
                    } : nil
                )
            }
            .sheet(isPresented: $showImageSelection, onDismiss: {
                handleImageSelectionDismiss()
            }) {
                ImageSelectionView(
                    onSavedToInbox: {
                        navigateToInboxAfterImage = true
                    },
                    exampleImages: setupTrialExampleImages,
                    onSetupTrialCompleted: isImageSetupTrial ? { itemID, itemName, kind, additionalIDs in
                        deferredImagePractice = DeferredPractice(
                            id: itemID, name: itemName, kind: kind, additionalIDs: additionalIDs
                        )
                    } : nil,
                    onSetupTrialSkipped: isImageSetupTrial ? {
                        SetupChecklistManager.shared.markCompleted(.tryImageInput)
                    } : nil
                )
            }
            .sheet(isPresented: $showCustomPeriodPicker) {
                CustomPeriodPickerSheet(
                    minDate: transactionDateRange.start,
                    maxDate: transactionDateRange.end,
                    currentRange: customDateRange
                )
            }
            .sheet(isPresented: $showBudgetFavoritesSettings, onDismiss: {
                viewModel.reloadAndRecalculate()
            }) {
                NavigationStack {
                    BudgetsFavoritesSettingsView()
                }
            }
            .sheet(isPresented: $showInbox, onDismiss: {
                viewModel.reloadAndRecalculate()
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
            .onChange(of: practiceCleanupItem?.id) { _, newValue in
                showPracticeAlert = newValue != nil
            }
            .alert(
                L10n.SetupChecklist.practiceTitle(practiceCleanupItem?.localizedItemType ?? ""),
                isPresented: $showPracticeAlert
            ) {
                Button(L10n.SetupChecklist.practiceKeep, role: .cancel) {
                    practiceCleanupItem = nil
                }
                Button(L10n.SetupChecklist.practiceDelete, role: .destructive) {
                    if let item = practiceCleanupItem {
                        deletePracticeItem(item)
                    }
                    practiceCleanupItem = nil
                    viewModel.reloadAndRecalculate()
                }
            } message: {
                Text(L10n.SetupChecklist.practiceMessage)
            }
    }

    private func handleVoiceRecordingDismiss() {
        if isVoiceSetupTrial {
            isVoiceSetupTrial = false
            FeatureGateService.shared.disableSetupTrial(for: .voiceInput)
        }
        if navigateToInboxAfterVoice {
            navigateToInboxAfterVoice = false
            showInbox = true
        }
        if switchToImageAfterVoice {
            switchToImageAfterVoice = false
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                showImageSelection = true
            }
        }

        // Consume deferred practice cleanup — must happen after sheet fully dismisses
        // so the alert can present without being blocked by the sheet.
        if let deferred = deferredVoicePractice {
            deferredVoicePractice = nil
            SetupChecklistManager.shared.markCompleted(
                .tryVoiceInput,
                practiceItem: PracticeCleanupItem(
                    stepID: .tryVoiceInput,
                    itemName: deferred.name,
                    persistentID: deferred.id,
                    kind: deferred.kind
                )
            )
        }

        viewModel.reloadAndRecalculate()
    }

    private func handleImageSelectionDismiss() {
        if isImageSetupTrial {
            isImageSetupTrial = false
            setupTrialExampleImages = nil
            FeatureGateService.shared.disableSetupTrial(for: .imageInput)
        }
        if navigateToInboxAfterImage {
            navigateToInboxAfterImage = false
            showInbox = true
        }

        // Consume deferred practice cleanup
        if let deferred = deferredImagePractice {
            deferredImagePractice = nil
            SetupChecklistManager.shared.markCompleted(
                .tryImageInput,
                practiceItem: PracticeCleanupItem(
                    stepID: .tryImageInput,
                    itemName: deferred.name,
                    persistentID: deferred.id,
                    kind: deferred.kind,
                    additionalIDs: deferred.additionalIDs
                )
            )
        }

        viewModel.reloadAndRecalculate()

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
    let viewModel: PanelViewModel
    let sessionState: SessionState

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedPeriod) {
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.selectedAccountIDs) {
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.selectedCategoryIDs) {
                if !sessionState.isExcludeMode && !sessionState.selectedCategoryIDs.isEmpty {
                    let selectedCats = viewModel.categories.filter {
                        sessionState.selectedCategoryIDs.contains($0.persistentModelID)
                    }
                    if !selectedCats.isEmpty {
                        if selectedCats.allSatisfy({ !$0.isIncome }) {
                            sessionState.selectedTransactionNatures = [.expense]
                        } else if selectedCats.allSatisfy({ $0.isIncome }) {
                            sessionState.selectedTransactionNatures = [.income]
                        }
                    }
                }
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.selectedNeeds) {
                if !sessionState.isExcludeMode && !sessionState.selectedNeeds.isEmpty {
                    sessionState.selectedTransactionNatures = [.expense]
                }
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.selectedSubcategoryIDs) {
                if !sessionState.isExcludeMode && !sessionState.selectedSubcategoryIDs.isEmpty {
                    let selectedSubs = viewModel.allSubcategories.filter {
                        sessionState.selectedSubcategoryIDs.contains($0.persistentModelID)
                    }
                    if !selectedSubs.isEmpty {
                        if selectedSubs.allSatisfy({ !$0.safeCategory.isIncome }) {
                            sessionState.selectedTransactionNatures = [.expense]
                        } else if selectedSubs.allSatisfy({ $0.safeCategory.isIncome }) {
                            sessionState.selectedTransactionNatures = [.income]
                        }
                    }
                }
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.selectedTags) {
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.selectedCurrencies) {
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.selectedTransactionNatures) {
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.amountCondition) {
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.searchText) {
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.isExcludeMode) {
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.selectedTrendMetric) {
                viewModel.recalculateData()
            }
            .onChange(of: sessionState.customDateRange) {
                viewModel.recalculateData()
            }
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
