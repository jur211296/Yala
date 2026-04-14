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
    @Binding var showFABMenu: Bool

    /// Periodic banner visibility
    @State private var showPeriodicBanner = false

    /// Nudge banner visibility (dormant/sporadic users)
    @State private var showNudgeBanner = false

    @AppStorage("userName") private var userName: String = "Usuario"
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCodeRaw: String = CurrencyCode.pen.rawValue
    @AppStorage("showVariations") private var showVariations: Bool = true
    @AppStorage("accountsSortOrderNames") private var accountsSortOrderNamesRaw: String = ""
    @AppStorage(TabBarConfiguration.storageKey) private var tabConfigJSON: String = TabBarConfiguration.default.toJSON()
    @AppStorage("voiceInputEnabled") private var voiceInputEnabled: Bool = false
    @AppStorage("imageInputEnabled") private var imageInputEnabled: Bool = false
    @AppStorage("aiDataConsentAccepted") private var aiDataConsentAccepted: Bool = false
    @AppStorage("showSiriTip") private var showSiriTip: Bool = true

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
            if !voiceInputEnabled { voiceInputEnabled = true }
            sheets.showVoiceRecording = true
        case .tryImageInput:
            FeatureGateService.shared.enableSetupTrial(for: .imageInput)
            sheets.isImageSetupTrial = true
            if !imageInputEnabled { imageInputEnabled = true }
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
                .navigationTitle(L10n.Panel.title(userName))
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
                            accountsSortOrderNames: accountsSortOrderNamesRaw.split(separator: "|").map(String.init),
                            accountFormSheet: $sheets.accountFormSheet,
                            showUpgradeForAccounts: $sheets.showUpgradeForAccounts
                        )

                        PanelFilterAndWidgetsSection(
                            viewModel: viewModel,
                            sessionState: sessionState,
                            defaultCurrencyCodeRaw: defaultCurrencyCodeRaw,
                            showVariations: showVariations,
                            showWidgetPreferences: $sheets.showWidgetPreferences,
                            showCustomPeriodPicker: $sheets.showCustomPeriodPicker,
                            showBudgetFavoritesSettings: $sheets.showBudgetFavoritesSettings
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
                                sheets.showUpgradeForVoice = true
                            } else if !aiDataConsentAccepted {
                                sheets.pendingAIInput = .voice
                                sheets.showAIConsentAlert = true
                            } else {
                                if !voiceInputEnabled { voiceInputEnabled = true }
                                sheets.showVoiceRecording = true
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
                                sheets.showUpgradeForImage = true
                            } else if !aiDataConsentAccepted {
                                sheets.pendingAIInput = .image
                                sheets.showAIConsentAlert = true
                            } else {
                                if !imageInputEnabled { imageInputEnabled = true }
                                sheets.showImageSelection = true
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
                            sheets.showNewTransaction = true
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

}
