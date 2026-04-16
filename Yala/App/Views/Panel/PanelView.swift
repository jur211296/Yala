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

    let viewModel: PanelViewModel
    @Binding var sheets: PanelSheetState

    /// Periodic banner visibility
    @State private var showPeriodicBanner = false

    /// Nudge banner visibility (dormant/sporadic users)
    @State private var showNudgeBanner = false

    @Environment(AppPreferences.self) private var appPreferences

    /// Coach mark: Pro tour (Phase 2)
    @State private var showProFabTour = false
    @State private var proFabTourIndex = 0

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
            sheets.practiceCleanupItem = pending
            mgr.pendingPracticeCleanup = nil
        }
    }

    // MARK: - Setup Checklist Navigation

    private func handleSetupStep(_ step: SetupStepID) {
        switch step {
        case .firstExpense:
            sheets.showNewTransaction = true
        case .firstBudget:
            sessionState.shouldAutoOpenBudgetEditor = true
            sessionState.navigateToBudgets()
        case .scheduledPayment:
            sessionState.shouldAutoOpenScheduledEditor = true
            sessionState.navigateToScheduledPayments()
        case .exploreSettings:
            sheets.isPresentingSettings = true
            SetupChecklistManager.shared.markCompleted(.exploreSettings)
        case .discoverFeatures:
            if FeatureGateService.shared.isProUser {
                SetupChecklistManager.shared.markCompleted(.discoverFeatures)
            } else {
                sheets.subscriptionBannerSource = "setupChecklist"
                sheets.showSubscriptionFromBanner = true
                SetupChecklistManager.shared.markCompleted(.discoverFeatures)
            }
        case .tryVoiceInput:
            FeatureGateService.shared.enableSetupTrial(for: .voiceInput)
            sheets.isVoiceSetupTrial = true
            if !appPreferences.voiceInputEnabled { appPreferences.voiceInputEnabled = true }
            sheets.showVoiceRecording = true
        case .tryImageInput:
            FeatureGateService.shared.enableSetupTrial(for: .imageInput)
            sheets.isImageSetupTrial = true
            if !appPreferences.imageInputEnabled { appPreferences.imageInputEnabled = true }
            sheets.setupTrialExampleImages = loadExampleImages()
            sheets.showImageSelection = true
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

    // MARK: - Nudge CTA Routing

    private func handleNudgeAction(_ nudge: NudgeType) {
        switch nudge.actionType {
        case .activateFullMode:
            SessionState.shared.shouldOpenFullModeActivation = true
        case .openGroupDetail:
            SessionState.shared.navigateToGroups()
        case .openPanel, .dismiss:
            break
        }
    }

    // MARK: - Toolbar Buttons

    private var inboxToolbarButton: some View {
        Button {
            sheets.showInbox = true
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
                .navigationTitle(L10n.Panel.title(appPreferences.userName))
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        inboxToolbarButton
                    }
                    ProfileToolbarItem {
                        sheets.isPresentingSettings = true
                    }
                }
        }
        .coachMarkOverlay(
            steps: ProTourSteps.panelSteps,
            isPresented: $showProFabTour,
            currentIndex: $proFabTourIndex,
            onComplete: {
                ProTourManager.shared.advancePhase()
            }
        )
        .task(id: ProTourManager.shared.currentPhase) {
            guard !ProTourManager.shared.hasCompleted,
                  ProTourManager.shared.currentPhase == .panel else { return }
            do { try await Task.sleep(for: .seconds(0.8)) } catch { return }
            guard ProTourManager.shared.currentPhase == .panel,
                  !showProFabTour else { return }
            showProFabTour = true
        }
        .appliesPendingRemoteChanges(sessionState)
        .onAppear {
            viewModel.widgetConfig.columns = DS.Adaptive.columns(sizeClass)
            viewModel.setContext(
                modelContext,
                exchangeRateService: exchangeRateService,
                currencyConverter: currencyConverter,
                defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue,
                sessionState: sessionState
            )
            Task { TransferMigrationService.migratePositiveTransfersIfNeeded(in: modelContext) }
            viewModel.syncFromSessionState(sessionState)
            let currentOrderRaw = appPreferences.accountsSortOrderNames.joined(separator: "|")
            let newOrder = viewModel.ensureAccountsSortOrderConsistency(
                accounts: viewModel.accounts,
                currentOrderRaw: currentOrderRaw
            )
            if newOrder != currentOrderRaw {
                appPreferences.accountsSortOrderNames = newOrder.split(separator: "|").map(String.init)
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
        .onChange(of: appPreferences.defaultCurrencyCode) { _, newValue in
            viewModel.updateDefaultCurrencyCode(newValue.rawValue)
            viewModel.recalculateData()
        }
    }

    private var mainContent: some View {
        ZStack {
            PanelBackgroundView()

            ScrollViewReader { scrollProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        if appPreferences.showSiriTip, viewModel.transactions.count >= 5 {
                            SiriTipCard(isVisible: Binding(
                                get: { appPreferences.showSiriTip },
                                set: { appPreferences.showSiriTip = $0 }
                            ))
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
                                sheets.subscriptionBannerSource = "trialBanner"
                                sheets.showSubscriptionFromBanner = true
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
                                    sheets.subscriptionBannerSource = "periodicBanner"
                                    sheets.showSubscriptionFromBanner = true
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

                        // Nudge banner (dormant/sporadic users — only if no Pro upsell showing)
                        if let nudge = NudgeService.shared.currentNudge, showNudgeBanner {
                            GroupNudgeBanner(
                                nudge: nudge,
                                message: NudgeService.shared.currentNudgeMessage ?? "",
                                onAction: {
                                    NudgeService.shared.recordInteracted(nudge)
                                    withAnimation(.easeOut(duration: 0.25)) { showNudgeBanner = false }
                                    handleNudgeAction(nudge)
                                },
                                onDismiss: {
                                    NudgeService.shared.recordDismissed(nudge)
                                    withAnimation(.easeOut(duration: 0.25)) { showNudgeBanner = false }
                                },
                                onAutoDismiss: {
                                    NudgeService.shared.recordDismissed(nudge, autoDismissed: true)
                                    withAnimation(.easeOut(duration: 0.25)) { showNudgeBanner = false }
                                }
                            )
                        }

                        // Setup Checklist (persistent for new users)
                        SetupChecklistCard(
                            manager: SetupChecklistManager.shared,
                            onStepTapped: { step in handleSetupStep(step) }
                        )

                        // Contextual guide for panel (first visit)
                        ContextualGuideBanner.panel()

                        PanelAccountsSection(
                            viewModel: viewModel,
                            sessionState: sessionState,
                            accountsSortOrderNames: appPreferences.accountsSortOrderNames,
                            accountFormSheet: $sheets.accountFormSheet,
                            showUpgradeForAccounts: $sheets.showUpgradeForAccounts
                        )

                        PanelFilterAndWidgetsSection(
                            viewModel: viewModel,
                            sessionState: sessionState,
                            defaultCurrencyCodeRaw: appPreferences.defaultCurrencyCode.rawValue,
                            showVariations: appPreferences.showVariations,
                            showWidgetPreferences: $sheets.showWidgetPreferences,
                            showCustomPeriodPicker: $sheets.showCustomPeriodPicker,
                            showBudgetFavoritesSettings: $sheets.showBudgetFavoritesSettings
                        )
                    }
                    .padding(.top, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.xxxl)
                }
                .scrollViewGlassEdges(horizontalMargin: DS.Adaptive.horizontalPadding(sizeClass))
                .refreshable {
                    await refreshData()
                }
                .onAppear {
                    showPeriodicBanner = ProUpsellService.shared.shouldShowPeriodicBanner()

                    // Evaluate nudge only if no Pro upsell showing
                    if !showPeriodicBanner {
                        NudgeService.shared.evaluate()
                        showNudgeBanner = NudgeService.shared.currentNudge != nil
                    }

                    // Setup checklist: auto-detect completed steps & manage collapse state
                    let mgr = SetupChecklistManager.shared
                    mgr.autoDetect(
                        transactionCount: viewModel.transactions.count,
                        budgetCount: viewModel.budgets.count,
                        scheduledCount: viewModel.scheduledPayments.count
                    )
                    mgr.checkReExpand()

                    consumePendingPracticeCleanup()
                }
                .onChange(of: SetupChecklistManager.shared.pendingPracticeCleanup?.id) { _, newID in
                    guard newID != nil else { return }
                    consumePendingPracticeCleanup()
                }
            }

            // Botón flotante de nuevo registro + Chat FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FABStackView(
                        canUseVoiceInput: viewModel.canUseVoiceInput,
                        isVoiceLocked: isVoiceLocked,
                        isImageLocked: isImageLocked,
                        isChatLocked: !FeatureGateService.shared.canAccess(.chatAssistant),
                        chatConsentAccepted: appPreferences.aiChatConsentAccepted,
                        chatEnabled: appPreferences.chatAssistantEnabled,
                        chatFABVisible: appPreferences.chatFABVisible,
                        onVoiceTap: { sheets.showVoiceRecording = true },
                        onImageTap: { sheets.showImageSelection = true },
                        onManualTap: { sheets.showNewTransaction = true },
                        onUpgradeVoice: { sheets.showUpgradeForVoice = true },
                        onUpgradeImage: { sheets.showUpgradeForImage = true },
                        onChatTap: { sheets.showChatSheet = true },
                        onUpgradeChat: { sheets.showUpgradeForChat = true },
                        onChatConsentNeeded: { sheets.showChatConsentAlert = true }
                    )
                }
            }
        }
    }

    /// Pull-to-refresh: sync preferences + reload data
    private func refreshData() async {
        PreferenceSyncService.shared.bootstrap()
        viewModel.reloadAndRecalculate()
        try? await Task.sleep(for: .milliseconds(300))
        DS.Haptic.light()
    }

}
