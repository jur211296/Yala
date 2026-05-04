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

    /// Controla si el título del navigation bar es visible. Solo aparece tras
    /// hacer scroll lo suficiente para que el saludo del hero desaparezca,
    /// evitando duplicar identidad ("Panel de X" arriba + "Hola, X" en hero).
    @State private var showInlineTitle = false

    /// Umbrales con histéresis para el título en el toolbar. El título
    /// aparece apenas el usuario scrollea por encima del `show`, y solo
    /// desaparece al volver al borde superior — evita oscilación con
    /// scroll inertial cerca del límite.
    private static let inlineTitleShowAt: CGFloat = 8
    private static let inlineTitleHideAt: CGFloat = 0

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
            AppRouter.shared.enqueue(.navigate(.budgets))
            AppRouter.shared.enqueue(.autoOpenBudgetEditor)
        case .scheduledPayment:
            AppRouter.shared.enqueue(.navigate(.scheduledPayments))
            AppRouter.shared.enqueue(.autoOpenScheduledEditor)
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
            if appPreferences.aiDataConsentAccepted {
                sheets.showVoiceRecording = true
            } else {
                sheets.pendingAIInput = .voice
                sheets.showAIConsentAlert = true
            }
        case .tryImageInput:
            FeatureGateService.shared.enableSetupTrial(for: .imageInput)
            sheets.isImageSetupTrial = true
            sheets.setupTrialExampleImages = loadExampleImages()
            if appPreferences.aiDataConsentAccepted {
                sheets.showImageSelection = true
            } else {
                sheets.pendingAIInput = .image
                sheets.showAIConsentAlert = true
            }
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
            AppRouter.shared.enqueue(.presentFullModeActivation)
        case .openGroupDetail:
            SessionState.shared.navigateToGroups()
        case .openPanel, .dismiss:
            break
        }
    }

    // MARK: - Toolbar Buttons

    private var sectionsConfigButton: some View {
        Button {
            DS.Haptic.light()
            sheets.showSectionsConfig = true
        } label: {
            Image(systemName: "square.grid.2x2")
                .font(DS.Typography.body).fontWeight(.medium)
                .foregroundStyle(.thToolbarIcon)
        }
        .accessibilityLabel(L10n.Accessibility.sectionsConfig)
        .accessibilityIdentifier("panel_sections_config")
    }

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
                // Title aparece solo tras scrollear (ver `showInlineTitle`),
                // evitando duplicación con el saludo del hero al inicio.
                .navigationTitle(showInlineTitle ? L10n.Panel.title(appPreferences.userName) : "")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        inboxToolbarButton
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        sectionsConfigButton
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
            // Inject AppPreferences BEFORE setContext so the first performCalculation
            // sees per-widget visibility state (P20-03 guards).
            viewModel.setAppPreferences(appPreferences)
            viewModel.setContext(
                modelContext,
                exchangeRateService: exchangeRateService,
                currencyConverter: currencyConverter,
                defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue,
                sessionState: sessionState
            )
            // Seed BEFORE the first calculation so hidden sections don't do
            // work on app launch.
            viewModel.hiddenSections = Self.parseHiddenSections(appPreferences.panelSectionsHidden)
            Task { TransferMigrationService.migratePositiveTransfersIfNeeded(in: modelContext) }
            viewModel.syncFromSessionState(sessionState)
            reconcileAccountsSortOrder()
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
        .onChange(of: appPreferences.defaultCurrencyCode) { _, newValue in
            viewModel.updateDefaultCurrencyCode(newValue.rawValue)
            viewModel.recalculateData()
        }
        .onChange(of: appPreferences.panelSectionsHidden) { oldValue, newValue in
            let next = Self.parseHiddenSections(newValue)
            guard viewModel.hiddenSections != next else { return }
            let previous = viewModel.hiddenSections
            viewModel.hiddenSections = next
            // Only recompute when a section became visible — hiding alone
            // doesn't need fresh data (cached values simply stop rendering).
            if !next.isSuperset(of: previous) {
                viewModel.recalculateData()
            }
        }
        .onChange(of: viewModel.accounts.count) { _, _ in
            reconcileAccountsSortOrder()
        }
        // Regenera mensaje IA al togglear feature o cambiar estado Pro.
        .onChange(of: appPreferences.aiInsightsConsentAccepted) { _, _ in
            viewModel.retriggerHeroAI()
        }
        .onChange(of: StoreKitManager.shared.isProUser) { _, _ in
            viewModel.retriggerHeroAI()
        }
    }

    /// Drops unknown raw values so a legacy/future preference string doesn't
    /// pollute the typed set.
    private static func parseHiddenSections(_ raw: [String]) -> Set<PanelSectionKind> {
        Set(raw.compactMap(PanelSectionKind.init(rawValue:)))
    }

    /// Sincroniza `appPreferences.accountsSortOrderNames` con las cuentas activas:
    /// agrega nombres nuevos al final y remueve los de cuentas eliminadas/archivadas.
    /// El guard evita writes no-op (que dispararían didSet + observer async redundante).
    private func reconcileAccountsSortOrder() {
        let currentOrder = appPreferences.accountsSortOrderNames
        let newOrder = viewModel.ensureAccountsSortOrderConsistency(
            accounts: viewModel.accounts,
            currentOrder: currentOrder
        )
        if newOrder != currentOrder {
            appPreferences.accountsSortOrderNames = newOrder
        }
    }

    private var mainContent: some View {
        ZStack {
            PanelBackgroundView()

            ScrollViewReader { scrollProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        // Gated on `heroWidget.data != nil` inside the section
                        // itself so the skeleton doesn't flash an empty card
                        // before the first `performCalculation()` lands.
                        PanelHeroSection(
                            viewModel: viewModel,
                            sessionState: sessionState,
                            showCustomPeriodPicker: $sheets.showCustomPeriodPicker
                        )

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

                        // Thematic sections wrapper renders: Tu panorama
                        // (accounts + health), then the filter bar (period + chips),
                        // then each thematic section. Auto-hide uses
                        // `viewModel.hasAnyVisibleWidget(in:)`.
                        PanelFilterAndWidgetsSection(
                            viewModel: viewModel,
                            sessionState: sessionState,
                            defaultCurrencyCodeRaw: appPreferences.defaultCurrencyCode.rawValue,
                            showVariations: appPreferences.showVariations,
                            accountsSortOrderNames: appPreferences.accountsSortOrderNames,
                            sectionPrefsPresentation: $sheets.sectionPrefsPresentation,
                            showBudgetFavoritesSettings: $sheets.showBudgetFavoritesSettings,
                            accountFormSheet: $sheets.accountFormSheet,
                            showUpgradeForAccounts: $sheets.showUpgradeForAccounts,
                            showCustomPeriodPicker: $sheets.showCustomPeriodPicker
                        )
                    }
                    .padding(.top, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.xxxl)
                }
                .scrollViewGlassEdges(horizontalMargin: DS.Adaptive.horizontalPadding(sizeClass))
                .onScrollGeometryChange(for: CGFloat.self) { geom in
                    geom.contentOffset.y
                } action: { _, offsetY in
                    let shouldShow = showInlineTitle
                        ? offsetY > Self.inlineTitleHideAt
                        : offsetY >= Self.inlineTitleShowAt
                    guard showInlineTitle != shouldShow else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showInlineTitle = shouldShow
                    }
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
