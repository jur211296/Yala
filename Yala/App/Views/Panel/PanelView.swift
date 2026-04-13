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

    /// Check if voice input is locked (Pro feature)
    private var isVoiceLocked: Bool {
        !FeatureGateService.shared.canAccess(.voiceInput)
    }

    /// Check if image input is locked (Pro feature)
    private var isImageLocked: Bool {
        !FeatureGateService.shared.canAccess(.imageInput)
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
                prefillAccountID: viewModel.selectedAccountID,
                prefillCategoryID: viewModel.selectedCategoryID,
                customDateRange: sessionState.customDateRange,
                viewModel: viewModel
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

                        PanelAccountsSection(
                            viewModel: viewModel,
                            sessionState: sessionState,
                            accountsSortOrderNames: accountsSortOrderNamesRaw.split(separator: "|").map(String.init),
                            accountFormSheet: $accountFormSheet,
                            showUpgradeForAccounts: $showUpgradeForAccounts
                        )

                        PanelFilterAndWidgetsSection(
                            viewModel: viewModel,
                            sessionState: sessionState,
                            defaultCurrencyCodeRaw: defaultCurrencyCodeRaw,
                            showVariations: showVariations,
                            showWidgetPreferences: $showWidgetPreferences,
                            showCustomPeriodPicker: $showCustomPeriodPicker,
                            showBudgetFavoritesSettings: $showBudgetFavoritesSettings
                        )
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
        let fabBackground = viewModel.canUseVoiceInput ? theme.accent : DS.Semantic.disabledForeground.opacity(0.5)

        if viewModel.canUseVoiceInput {
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

    /// Pull-to-refresh: sync preferences + reload data
    private func refreshData() async {
        PreferenceSyncService.shared.bootstrap()
        viewModel.reloadAndRecalculate()
        try? await Task.sleep(for: .milliseconds(300))
        DS.Haptic.light()
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

}
