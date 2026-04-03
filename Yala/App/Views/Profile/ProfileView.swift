//
//  ProfileView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import AVFoundation
import Photos
import StoreKit
import SwiftData
import SwiftUI

//  Created by Yala Refactoring.
//

/// Main profile screen acting as the Configuration Control Center
struct ProfileView: View {
    /// Optional destination to navigate to on appear (used by setup checklist).
    var initialDestination: ProfileDestination?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.yalaTheme) private var theme

    @ScaledMetric(relativeTo: .largeTitle) private var avatarIconSize: CGFloat = 40 // A11Y-DT: @ScaledMetric

    @State private var viewModel = ProfileViewModel()

    @AppStorage("userName") private var userName: String = "Usuario"
    @AppStorage("colorfulIcons") private var colorfulIcons: Bool = true
    private var effectiveColorfulIcons: Bool {
        theme.forcesMonochromeIcons ? false : colorfulIcons
    }
    private var profileStorage: ProfileImageStorage { .shared }
    @AppStorage("userProfileIcon") private var userProfileIcon: String = ""
    @AppStorage("voiceInputEnabled") private var voiceInputEnabled: Bool = false
    @AppStorage("voiceLanguage") private var voiceLanguageRaw: String = VoiceLanguage.system.rawValue
    @AppStorage("imageInputEnabled") private var imageInputEnabled: Bool = false
    @AppStorage("aiDataConsentAccepted") private var aiDataConsentAccepted: Bool = false
    @AppStorage("aiInsightsConsentAccepted") private var aiInsightsConsentAccepted: Bool = false
    @AppStorage(InsightTone.storageKey) private var insightsToneRaw: String = InsightTone.normal.rawValue
    @AppStorage(InsightFocus.storageKey) private var insightsFocusRaw: String = InsightFocus.balanced.rawValue
    @State private var showAIConsentAlert: Bool = false
    @State private var showInsightsConsentAlert: Bool = false
    @State private var showChatConsentAlert: Bool = false
    @State private var pendingConsentForVoice: Bool = true
    @AppStorage("aiChatConsentAccepted") private var aiChatConsentAccepted: Bool = false
    @AppStorage("chatAssistantEnabled") private var chatAssistantEnabled: Bool = false

    // Navigation & Sheets
    @State private var navigationPath = NavigationPath()
    @State private var activeSheet: ProfileSheet?

    // Import result - shown as alert after ImportIntroSheet dismisses
    @State private var importResult: ImportResult?
    @State private var showImportResult: Bool = false

    // Permission denied alert
    @State private var showPermissionDeniedAlert: Bool = false
    @State private var permissionDeniedType: String = ""

    // Subscription state
    @State private var showUpgradeForVoice = false
    @State private var showUpgradeForImage = false
    @State private var showUpgradeForInsights = false
    @State private var showUpgradeForChat = false
    @State private var showSupportSheet = false

    // Coach mark: Settings tour
    @AppStorage("hasSeenSettingsTour") private var hasSeenSettingsTour = false
    @State private var showSettingsTour = false
    @State private var settingsTourIndex = 0
    @State private var settingsScrollProxy: ScrollViewProxy?

    // Coach mark: Pro tour (Phase 1)
    @State private var showProTour = false
    @State private var proTourIndex = 0

    #if DEBUG
    @State private var seedService = DevSeedService()
    @State private var showSeedConfirmation = false
    @State private var showSeedProgress = false
    #endif

    private var isProUser: Bool {
        FeatureGateService.shared.isProUser
    }

    private var isVoiceLocked: Bool {
        !FeatureGateService.shared.canAccess(.voiceInput)
    }

    private var isImageLocked: Bool {
        !FeatureGateService.shared.canAccess(.imageInput)
    }

    private var isSmartInsightsLocked: Bool {
        !FeatureGateService.shared.canAccess(.smartInsightsAI)
    }

    private var isChatLocked: Bool {
        !FeatureGateService.shared.canAccess(.chatAssistant)
    }

    private var selectedTone: InsightTone {
        InsightTone(rawValue: insightsToneRaw) ?? .normal
    }

    private var selectedFocus: InsightFocus {
        InsightFocus(rawValue: insightsFocusRaw) ?? .balanced
    }

    enum ProfileSheet: Identifiable {
        case personalDetails
        case importIntro
        case exportWizard

        var id: Int {
            hashValue
        }
    }

    // ProfileDestination extracted to Yala/App/Models/ProfileDestination.swift

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                PanelBackgroundView()

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: DS.Spacing.xxl) {
                            // Header
                            profileHeader

                            // Sections
                            organizacionSection
                            preferenciasSection
                            aiFeaturesSection
                            datosSection
                            seguridadSection
                            ayudaSection
                            legalSection

                            // Version info
                            Text(L10n.Settings.versionInfo)
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.tertiary)
                                .padding(.top, DS.Spacing.sm)
                        }
                        .padding(.vertical, DS.Spacing.xxl)
                    }
                    .scrollDisabled(false)
                    .onAppear { settingsScrollProxy = scrollProxy }
                }
            }
            .navigationTitle(L10n.Profile.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .sheet(item: $activeSheet) { item in
                switch item {
                case .personalDetails:
                    PersonalDetailsView()
                case .importIntro:
                    ImportIntroSheet(
                        accounts: viewModel.accounts,
                        categories: viewModel.categories,
                        onImportCompleted: { result in
                            // Store result and show alert after sheet animation completes
                            activeSheet = nil
                            importResult = result
                            // Small delay to ensure sheet is fully dismissed
                            Task {
                                try? await Task.sleep(for: .milliseconds(200))
                                showImportResult = true
                            }
                        }
                    )
                case .exportWizard:
                    ExportFiltersStepView()
                }
            }
            .alert(
                importResult?.isSuccess == true
                    ? L10n.Profile.importSuccess : L10n.Profile.importError,
                isPresented: $showImportResult,
                presenting: importResult
            ) { _ in
                Button(L10n.Common.ok, role: .cancel) {}
            } message: { result in
                Text(result.message)
            }
            .alert(
                permissionDeniedType,
                isPresented: $showPermissionDeniedAlert
            ) {
                Button(L10n.Voice.openSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                if permissionDeniedType == L10n.Settings.voiceInputEnabled {
                    Text(L10n.Voice.errorMicPermission)
                } else {
                    Text(L10n.Image.errorPhotoPermission)
                }
            }
            .alert(L10n.AIConsent.processingTitle, isPresented: $showAIConsentAlert) {
                Button(L10n.AIConsent.accept) {
                    aiDataConsentAccepted = true
                    if pendingConsentForVoice {
                        voiceInputEnabled = true
                    } else {
                        imageInputEnabled = true
                    }
                }
                Button(L10n.AIConsent.privacyPolicy) {
                    openURL(AppConstants.privacyURL)
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                Text(L10n.AIConsent.processingMessage)
            }
            .alert(L10n.AIConsent.insightsTitle, isPresented: $showInsightsConsentAlert) {
                Button(L10n.AIConsent.accept) {
                    aiInsightsConsentAccepted = true
                }
                Button(L10n.AIConsent.privacyPolicy) {
                    openURL(AppConstants.privacyURL)
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                Text(L10n.AIConsent.insightsMessage)
            }
            .onAppear {
                // Auto-navigate to destination from setup checklist
                if let dest = initialDestination ?? SessionState.shared.pendingProfileDestination {
                    SessionState.shared.pendingProfileDestination = nil
                    navigationPath.append(dest)
                }
            }
            .navigationDestination(for: ProfileDestination.self) { destination in
                switch destination {
                case .accounts:
                    AccountsSettingsListView()
                case .categories:
                    CategoriesSettingsListView()
                case .tags:
                    TagsSettingsListView()
                case .themes:
                    ThemeSettingsView {
                        dismiss()
                    }
                case .personalization:
                    PersonalizationSettingsView()
                case .currency:
                    CurrencySettingsView()
                case .appIcon:
                    AppIconSettingsView()
                case .biometricSecurity:
                    BiometricSecurityView()
                case .subscription:
                    SubscriptionView(source: "profile")
                case .tips:
                    TutorialsListView()
                case .faq:
                    FAQView()
                case .notifications:
                    NotificationsSettingsView()
                case .favorites:
                    FavoritesListView(mode: .manage)
                case .budgets:
                    BudgetsFavoritesSettingsView()
                case .planned:
                    ScheduledPaymentsSettingsView()
                case .userDataReset:
                    UserDataResetView(onUserDataWiped: {
                        dismiss()
                    })
                case .iCloudSync:
                    iCloudSyncSettingsView()
                case .siriShortcuts:
                    SiriShortcutsView()
                }
            }
            .onAppear {
                viewModel.setContext(modelContext)
                profileStorage.migrateFromUserDefaultsIfNeeded()
            }
        }
        .coachMarkOverlay(
            steps: SettingsTourSteps.steps,
            isPresented: $showSettingsTour,
            currentIndex: $settingsTourIndex,
            scrollProxy: settingsScrollProxy,
            onComplete: { hasSeenSettingsTour = true }
        )
        .coachMarkOverlay(
            steps: ProTourSteps.profileSteps,
            isPresented: $showProTour,
            currentIndex: $proTourIndex,
            scrollProxy: settingsScrollProxy,
            onComplete: {
                ProTourManager.shared.advancePhase()
            }
        )
        .task {
            if !hasSeenSettingsTour {
                do { try await Task.sleep(for: .seconds(0.8)) } catch { return }
                if !hasSeenSettingsTour {
                    showSettingsTour = true
                }
            }
        }
        .task(id: hasSeenSettingsTour) {
            guard hasSeenSettingsTour else { return }
            // Re-check eligibility (covers race: subscribed before tours completed)
            ProTourManager.shared.triggerIfEligible()
            guard ProTourManager.shared.currentPhase == .profile else { return }
            do { try await Task.sleep(for: .seconds(0.8)) } catch { return }
            guard ProTourManager.shared.currentPhase == .profile,
                  !showSettingsTour else { return }
            showProTour = true
        }
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: DS.Spacing.md) {
            // Avatar - tappable to edit profile
            Button {
                activeSheet = .personalDetails
            } label: {
                ZStack {
                    // Pro users get golden gradient ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: isProUser
                                    ? DS.Gradients.proBadge
                                    : [theme.accent, theme.accent.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 100, height: 100)

                    if let imageData = profileStorage.imageData,
                        let uiImage = UIImage(data: imageData)
                    {
                        // User photo
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 90, height: 90)
                            .clipShape(Circle())
                    } else {
                        // Custom icon or default
                        Circle()
                            .fill(theme.accent.opacity(0.1))
                            .frame(width: 90, height: 90)

                        Image(systemName: userProfileIcon.isEmpty ? "person.fill" : userProfileIcon)
                            .font(.system(size: avatarIconSize))
                            .foregroundStyle(theme.accent)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    }

                    // Spark badge for Pro users
                    if isProUser {
                        ZStack {
                            Circle()
                                .fill(.thCard)
                            YalaSpark(size: .medium, animated: true)
                        }
                        .frame(width: 28, height: 28)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        .offset(x: 38, y: -38)
                    }
                }
            }
            .buttonStyle(.plain)

            // Name
            Text(userName)
                .font(DS.Typography.title)
                .foregroundStyle(.primary)

            // Pro badge with cyan spark (only here, so it stands out)
            if isProUser {
                proBadgeWithCyanSpark
            }

            Button(L10n.Profile.edit) {
                activeSheet = .personalDetails
            }
            .font(DS.Typography.label)
            .foregroundStyle(.primary)

        }
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, isProUser ? DS.Spacing.lg : 0)
        .background(
            Group {
                if isProUser {
                    LinearGradient(
                        colors: [Color.yellow.opacity(0.03), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        )
        .sheet(isPresented: $showUpgradeForVoice) {
            UpgradePromptSheet(feature: .voiceInput, context: .proFeature)
        }
        .sheet(isPresented: $showUpgradeForImage) {
            UpgradePromptSheet(feature: .imageInput, context: .proFeature)
        }
        .sheet(isPresented: $showUpgradeForInsights) {
            UpgradePromptSheet(feature: .smartInsightsAI, context: .proFeature)
        }
        .sheet(isPresented: $showUpgradeForChat) {
            UpgradePromptSheet(feature: .chatAssistant, context: .proFeature)
        }
    }

    // MARK: - Pro Badge with Cyan Spark

    /// Custom Pro badge with cyan spark so it stands out against the gold background
    private var proBadgeWithCyanSpark: some View {
        HStack(spacing: DS.Spacing.xs) {
            // Cyan spark (instead of gold)
            YalaSparkShape()
                .fill(Color.cyan) // DS-OK: decorative section accent
                .frame(width: 12, height: 12)

            Text("PRO")
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(
            LinearGradient(
                colors: DS.Gradients.proBadge,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Capsule())
    }

    // MARK: - Sections

    private var organizacionSection: some View {
        SectionBox(title: L10n.Settings.organization) {
            VStack(spacing: DS.Spacing.none) {
                profileRow(
                    icon: "creditcard.fill", title: L10n.Settings.accounts, iconColor: DS.Semantic.successForeground,
                    destination: .accounts)
                    .accessibilityIdentifier("profile_accounts")
                    .coachMarkAnchor("settingsAccounts")
                SubsectionDivider()
                profileRow(
                    icon: "tag.fill", title: L10n.Settings.categories, iconColor: .orange,
                    destination: .categories)
                    .accessibilityIdentifier("profile_categories")
                    .coachMarkAnchor("settingsCategories")
                SubsectionDivider()
                profileRow(
                    icon: "number", title: L10n.Settings.tags, iconColor: .purple,
                    destination: .tags)
                    .accessibilityIdentifier("profile_tags")
                    .coachMarkAnchor("settingsTags")
                SubsectionDivider()
                profileRow(
                    icon: "chart.pie.fill", title: L10n.Settings.budgets,
                    iconColor: .mint,
                    destination: .budgets)
                    .coachMarkAnchor("settingsBudgets")
                SubsectionDivider()
                profileRow(
                    icon: "calendar.badge.clock", title: L10n.Settings.plannedPayments,
                    iconColor: .cyan,
                    destination: .planned
                )
                .coachMarkAnchor("settingsPlanned")
                SubsectionDivider()
                profileRow(
                    icon: "star.fill", title: L10n.Settings.favorites, iconColor: .yellow,
                    destination: .favorites)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var preferenciasSection: some View {
        SectionBox(title: L10n.Settings.preferences) {
            VStack(spacing: DS.Spacing.none) {
                profileRow(
                    icon: "slider.horizontal.3", title: L10n.Settings.personalization,
                    iconColor: .indigo, destination: .personalization)
                .coachMarkAnchor("settingsPersonalization")
                SubsectionDivider()
                profileRow(
                    icon: "bell.fill", title: L10n.Settings.notifications, iconColor: .red,
                    destination: .notifications)
                SubsectionDivider()
                profileRow(
                    icon: "dollarsign.circle.fill", title: L10n.Settings.currencyAndExchange,
                    iconColor: DS.Semantic.successForeground, destination: .currency
                )
                SubsectionDivider()
                profileRow(
                    icon: "app.fill", title: L10n.Settings.appIcon,
                    iconColor: .blue, destination: .appIcon)
                .coachMarkAnchor("settingsAppIcon")
                SubsectionDivider()
                profileRow(
                    icon: "paintpalette.fill", title: L10n.Settings.theme, iconColor: .pink,
                    destination: .themes)
                .coachMarkAnchor("settingsTheme")
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var aiFeaturesSection: some View {
        SectionBox(title: L10n.Settings.aiFeatures) {
            VStack(spacing: DS.Spacing.none) {
                voiceInputRow
                    .coachMarkAnchor("proVoiceInput")
                SubsectionDivider()
                imageInputRow
                    .coachMarkAnchor("proImageInput")
                SubsectionDivider()
                chatAssistantRow
                    .coachMarkAnchor("proChatAssistant")
                SubsectionDivider()
                smartInsightsToggleRow
                    .coachMarkAnchor("proSmartInsights")

                let hasProcessing = aiDataConsentAccepted && (voiceInputEnabled || imageInputEnabled)
                let hasInsights = aiInsightsConsentAccepted
                let hasChat = aiChatConsentAccepted && chatAssistantEnabled
                let activeCount = [hasProcessing, hasInsights, hasChat].count(where: { $0 })
                if activeCount > 0 {
                    Text(activeCount >= 2 ? L10n.AIConsent.inlineHintMultiple
                         : hasProcessing ? L10n.AIConsent.inlineHintProcessing
                         : hasInsights ? L10n.AIConsent.inlineHintInsights
                         : L10n.AIConsent.inlineHintChat)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var chatAssistantRow: some View {
        Button {
            if isChatLocked { showUpgradeForChat = true }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                if effectiveColorfulIcons {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .font(DS.Typography.subheadline).fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.electricIndigo))
                        .opacity(isChatLocked ? 0.5 : 1)
                } else {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                        .frame(width: 28)
                        .opacity(isChatLocked ? 0.5 : 1)
                }

                Text(L10n.Settings.chatAssistant)
                    .font(DS.Typography.body)
                    .foregroundStyle(isChatLocked ? .secondary : .primary)

                if isChatLocked { ProBadge(size: .small) }

                Spacer()

                if isChatLocked {
                    Image(systemName: "lock.fill")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                } else {
                    Toggle(L10n.Settings.chatAssistant, isOn: $chatAssistantEnabled)
                        .labelsHidden()
                        .onChange(of: chatAssistantEnabled) { _, isEnabled in
                            guard isEnabled, !aiChatConsentAccepted else { return }
                            chatAssistantEnabled = false
                            showChatConsentAlert = true
                        }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .alert(L10n.AIConsent.chatTitle, isPresented: $showChatConsentAlert) {
            Button(L10n.AIConsent.accept) {
                aiChatConsentAccepted = true
                chatAssistantEnabled = true
            }
            Button(L10n.AIConsent.privacyPolicy) {
                UIApplication.shared.open(AppConstants.privacyURL)
            }
            Button(L10n.Action.cancel, role: .cancel) {}
        } message: {
            Text(L10n.AIConsent.chatMessage)
        }
    }

    private var smartInsightsToggleRow: some View {
        VStack(spacing: DS.Spacing.none) {
            // Toggle row
            Button {
                if isSmartInsightsLocked {
                    showUpgradeForInsights = true
                }
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    if effectiveColorfulIcons {
                        Image(systemName: "sparkles")
                            .font(DS.Typography.subheadline).fontWeight(.medium)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.purple) // DS-OK: decorative section accent
                            )
                            .opacity(isSmartInsightsLocked ? 0.5 : 1)
                    } else {
                        Image(systemName: "sparkles")
                            .font(DS.Typography.body)
                            .foregroundStyle(.primary)
                            .frame(width: 28)
                            .opacity(isSmartInsightsLocked ? 0.5 : 1)
                    }

                    Text(L10n.Insights.aiToggle)
                        .font(DS.Typography.body)
                        .foregroundStyle(isSmartInsightsLocked ? .secondary : .primary)

                    if isSmartInsightsLocked {
                        ProBadge(size: .small)
                    }

                    Spacer()

                    if isSmartInsightsLocked {
                        Image(systemName: "lock.fill")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    } else {
                        Toggle(L10n.Insights.aiToggle, isOn: Binding(
                            get: { aiInsightsConsentAccepted },
                            set: { newValue in
                                if newValue && !aiInsightsConsentAccepted {
                                    showInsightsConsentAlert = true
                                } else {
                                    aiInsightsConsentAccepted = newValue
                                }
                            }
                        ))
                            .labelsHidden()
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.FormRow.paddingV)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Tone selector (only visible when enabled and not locked)
            if aiInsightsConsentAccepted && !isSmartInsightsLocked {
                HStack(spacing: DS.Spacing.md) {
                    Color.clear
                        .frame(width: 28, height: 28)

                    Text(L10n.Insights.toneLabel)
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Menu {
                        ForEach(InsightTone.allCases) { tone in
                            Button {
                                insightsToneRaw = tone.rawValue
                                PreferenceSyncService.shared.set(string: tone.rawValue, forKey: InsightTone.storageKey)
                                InsightsLLMService.shared.invalidateCache()
                            } label: {
                                HStack {
                                    Text(tone.displayName)
                                    if insightsToneRaw == tone.rawValue {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Text(selectedTone.displayName)
                                .font(DS.Typography.body)
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(DS.Typography.captionSmall.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.FormRow.paddingV)

                // Focus selector
                HStack(spacing: DS.Spacing.md) {
                    Color.clear
                        .frame(width: 28, height: 28)

                    Text(L10n.Insights.focusLabel)
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Menu {
                        ForEach(InsightFocus.allCases) { focus in
                            Button {
                                insightsFocusRaw = focus.rawValue
                                PreferenceSyncService.shared.set(string: focus.rawValue, forKey: InsightFocus.storageKey)
                                InsightsLLMService.shared.invalidateCache()
                            } label: {
                                HStack {
                                    Text(focus.displayName)
                                    if insightsFocusRaw == focus.rawValue {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Text(selectedFocus.displayName)
                                .font(DS.Typography.body)
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(DS.Typography.captionSmall.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.FormRow.paddingV)
            }
        }
    }

    private var voiceInputRow: some View {
        VStack(spacing: DS.Spacing.none) {
            // Toggle row
            Button {
                if isVoiceLocked {
                    showUpgradeForVoice = true
                }
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    if effectiveColorfulIcons {
                        Image(systemName: "waveform.badge.mic")
                            .font(DS.Typography.subheadline).fontWeight(.medium)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.hotPink) // DS-OK: decorative section accent
                            )
                            .opacity(isVoiceLocked ? 0.5 : 1)
                    } else {
                        Image(systemName: "waveform.badge.mic")
                            .font(DS.Typography.body)
                            .foregroundStyle(.primary)
                            .frame(width: 28)
                            .opacity(isVoiceLocked ? 0.5 : 1)
                    }

                    Text(L10n.Settings.voiceInputEnabled)
                        .font(DS.Typography.body)
                        .foregroundStyle(isVoiceLocked ? .secondary : .primary)

                    if isVoiceLocked {
                        ProBadge(size: .small)
                    }

                    Spacer()

                    if isVoiceLocked {
                        Image(systemName: "lock.fill")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    } else {
                        Toggle(L10n.Settings.voiceInputEnabled, isOn: $voiceInputEnabled)
                            .labelsHidden()

                            .onChange(of: voiceInputEnabled) { _, isEnabled in
                                guard isEnabled else { return }
                                if !aiDataConsentAccepted {
                                    voiceInputEnabled = false
                                    pendingConsentForVoice = true
                                    showAIConsentAlert = true
                                    return
                                }
                                let status = AVAudioApplication.shared.recordPermission
                                if status == .undetermined {
                                    AVAudioApplication.requestRecordPermission { granted in
                                        Task { @MainActor in
                                            if !granted {
                                                voiceInputEnabled = false
                                                permissionDeniedType = L10n.Settings.voiceInputEnabled
                                                showPermissionDeniedAlert = true
                                            }
                                        }
                                    }
                                } else if status == .denied {
                                    voiceInputEnabled = false
                                    permissionDeniedType = L10n.Settings.voiceInputEnabled
                                    showPermissionDeniedAlert = true
                                }
                            }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.FormRow.paddingV)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Language selector (only visible when enabled and not locked)
            if voiceInputEnabled && !isVoiceLocked {
                HStack(spacing: DS.Spacing.md) {
                    // Empty space to align with icon
                    Color.clear
                        .frame(width: 28, height: 28)

                    Text(L10n.Settings.voiceLanguage)
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Menu {
                        ForEach(VoiceLanguage.allCases) { language in
                            Button {
                                voiceLanguageRaw = language.rawValue
                                PreferenceSyncService.shared.set(string: language.rawValue, forKey: "voiceLanguage")
                            } label: {
                                HStack {
                                    Text(language.displayName)
                                    if voiceLanguageRaw == language.rawValue {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Text(VoiceLanguage(rawValue: voiceLanguageRaw)?.displayName ?? L10n.VoiceLanguage.system)
                                .font(DS.Typography.body)
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(DS.Typography.captionSmall.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.FormRow.paddingV)
            }
        }
    }

    private var imageInputRow: some View {
        Button {
            if isImageLocked {
                showUpgradeForImage = true
            }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                if effectiveColorfulIcons {
                    Image(systemName: "photo.on.rectangle")
                        .font(DS.Typography.subheadline).fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.teal) // DS-OK: decorative section accent
                        )
                        .opacity(isImageLocked ? 0.5 : 1)
                } else {
                    Image(systemName: "photo.on.rectangle")
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                        .frame(width: 28)
                        .opacity(isImageLocked ? 0.5 : 1)
                }

                Text(L10n.Settings.imageInputEnabled)
                    .font(DS.Typography.body)
                    .foregroundStyle(isImageLocked ? .secondary : .primary)

                if isImageLocked {
                    ProBadge(size: .small)
                }

                Spacer()

                if isImageLocked {
                    Image(systemName: "lock.fill")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                } else {
                    Toggle(L10n.Settings.imageInputEnabled, isOn: $imageInputEnabled)
                        .labelsHidden()

                        .onChange(of: imageInputEnabled) { _, isEnabled in
                            guard isEnabled else { return }
                            if !aiDataConsentAccepted {
                                imageInputEnabled = false
                                pendingConsentForVoice = false
                                showAIConsentAlert = true
                                return
                            }
                            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                            if status == .notDetermined {
                                PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in }
                            } else if status == .denied || status == .restricted {
                                imageInputEnabled = false
                                permissionDeniedType = L10n.Settings.imageInputEnabled
                                showPermissionDeniedAlert = true
                            }
                        }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var datosSection: some View {
        SectionBox(title: L10n.Settings.data) {
            VStack(spacing: DS.Spacing.none) {
                profileRow(
                    icon: "icloud.fill",
                    title: L10n.iCloud.title,
                    iconColor: .blue,
                    destination: .iCloudSync
                )

                SubsectionDivider()

                Button {
                    activeSheet = .importIntro
                } label: {
                    settingsRowContent(
                        icon: "tray.and.arrow.down.fill", title: L10n.Settings.importData,
                        iconColor: .blue)
                }
                .buttonStyle(.plain)

                SubsectionDivider()

                Button {
                    activeSheet = .exportWizard
                } label: {
                    settingsRowContent(
                        icon: "square.and.arrow.up.fill", title: L10n.Settings.exportData,
                        iconColor: .mint
                    )
                    .opacity(!viewModel.hasTransactions ? 0.5 : 1.0)
                }
                .accessibilityHint(!viewModel.hasTransactions ? L10n.Accessibility.noTransactionsToExport : "")
                .disabled(!viewModel.hasTransactions)
                .buttonStyle(.plain)
                .coachMarkAnchor("proExportExtended")

                SubsectionDivider()

                NavigationLink(value: ProfileDestination.userDataReset) {
                    settingsRowContent(
                        icon: "trash.fill", title: L10n.Settings.wipeData, iconColor: .red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var seguridadSection: some View {
        SectionBox(title: L10n.Settings.security) {
            VStack(spacing: DS.Spacing.none) {
                profileRow(
                    icon: BiometricAuthService.shared.biometricType.icon,
                    title: BiometricAuthService.shared.biometricType.displayName,
                    iconColor: DS.Semantic.successForeground,
                    destination: .biometricSecurity)
                SubsectionDivider()
                profileRow(
                    icon: "mic.badge.plus", title: String(localized: "settings.siriShortcuts"),
                    iconColor: .blue, destination: .siriShortcuts)
                SubsectionDivider()
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    settingsRowContent(
                        icon: "lock.shield.fill", title: L10n.Settings.permissions,
                        iconColor: .blue)
                }
                .buttonStyle(.plain)
                SubsectionDivider()
                profileRow(
                    icon: "creditcard.fill", title: L10n.Settings.subscriptions,
                    iconColor: .purple, destination: .subscription)
                #if DEBUG
                if Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true {
                    SubsectionDivider()
                    devProToggleRow
                    SubsectionDivider()
                    devSeedDataRow
                }
                #endif
                SubsectionDivider()
                Button {
                    requestReview()
                } label: {
                    settingsRowContent(
                        icon: "star.bubble.fill", title: L10n.Settings.rateApp,
                        iconColor: .yellow)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    #if DEBUG
    private var devProToggleRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "sparkles")
                .font(DS.Typography.subheadline).fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange) // DS-OK: decorative section accent
                )

            Text("Simular Pro")
                .font(DS.Typography.body)
                .foregroundStyle(.primary)

            Spacer()

            Toggle("", isOn: Binding(
                get: { StoreKitManager.shared.devForceProTier },
                set: { _ in StoreKitManager.shared.toggleDevProTier() }
            ))
            .labelsHidden()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    private var devSeedDataRow: some View {
        Button {
            if seedService.hasSeeded {
                showSeedConfirmation = true
            } else {
                Task { await seedService.seed(in: modelContext) }
            }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: seedService.hasSeeded ? "arrow.clockwise" : "square.and.arrow.down.fill")
                    .font(DS.Typography.subheadline).fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(seedService.hasSeeded ? Color.orange : Color.teal)
                    )

                Text(seedService.hasSeeded ? "Recargar datos de prueba" : "Cargar datos de prueba")
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
        }
        .buttonStyle(.plain)
        .alert("¿Recargar datos de prueba?", isPresented: $showSeedConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Recargar", role: .destructive) {
                Task { await seedService.reset(in: modelContext) }
            }
        } message: {
            Text("Se eliminarán todos los datos existentes y se cargarán datos de prueba nuevos.")
        }
        .sheet(isPresented: $showSeedProgress) {
            devSeedProgressSheet
        }
        .onChange(of: seedService.isSeeding) { _, newValue in
            showSeedProgress = newValue
        }
    }

    private var devSeedProgressSheet: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            Image(systemName: "cylinder.split.1x2.fill")
                .font(.system(size: 48)) // A11Y-DT: debug-only seed progress view
                .foregroundStyle(DS.Semantic.imageAccent)

            Text("Generando datos de prueba")
                .font(DS.Typography.headline)

            VStack(spacing: DS.Spacing.sm) {
                ProgressView(value: seedService.progress)
                    .tint(DS.Semantic.imageAccent)

                Text(seedService.stepLabel)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DS.Spacing.xxxl)

            Text("\(Int(seedService.progress * 100))%")
                .font(DS.Typography.headline)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer()
        }
        .interactiveDismissDisabled()
        .presentationDetents([.medium])
    }
    #endif

    private var ayudaSection: some View {
        SectionBox(title: L10n.Settings.help) {
            VStack(spacing: DS.Spacing.none) {
                profileRow(
                    icon: "book.fill", title: L10n.Settings.tutorials,
                    iconColor: .electricIndigo, destination: .tips)
                .coachMarkAnchor("settingsTutorials")
                SubsectionDivider()
                profileRow(
                    icon: "questionmark.circle.fill", title: L10n.Settings.faq,
                    iconColor: .orange, destination: .faq)
                SubsectionDivider()
                Button {
                    showSupportSheet = true
                } label: {
                    settingsRowContent(
                        icon: "envelope.fill", title: L10n.Settings.contact,
                        iconColor: .teal)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showSupportSheet) {
                    SupportFormSheet()
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var legalSection: some View {
        SectionBox(title: L10n.Settings.legal) {
            VStack(spacing: DS.Spacing.none) {
                Button {
                    openURL(AppConstants.privacyURL)
                } label: {
                    settingsRowContent(
                        icon: "hand.raised.fill", title: L10n.Settings.privacy,
                        iconColor: .gray)
                }
                .buttonStyle(.plain)
                SubsectionDivider()
                Button {
                    openURL(AppConstants.termsURL)
                } label: {
                    settingsRowContent(
                        icon: "doc.text.fill", title: L10n.Settings.terms,
                        iconColor: .gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }


    // MARK: - Reference Builder

    @ViewBuilder
    private func profileRow(
        icon: String,
        title: String,
        iconColor: Color = .gray,
        destination: ProfileDestination
    ) -> some View {
        NavigationLink(value: destination) {
            settingsRowContent(icon: icon, title: title, iconColor: iconColor)
        }
        .buttonStyle(.plain)
    }

    private func settingsRowContent(
        icon: String,
        title: String,
        iconColor: Color = .gray,
        textColor: Color = .primary
    ) -> some View {
        HStack(spacing: DS.Spacing.md) {
            // Conditionally show colored or plain icons based on setting
            if effectiveColorfulIcons {
                // iOS-style colored icon with rounded square background
                Image(systemName: icon)
                    .font(DS.Typography.subheadline).fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(iconColor)
                    )
                    .accessibilityHidden(true)
            } else {
                // Plain icon without background
                Image(systemName: icon)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .frame(width: 28)
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(DS.Typography.body)
                .foregroundStyle(textColor)

            Spacer()

            Image(systemName: "chevron.right")
                .font(DS.Typography.labelSmall.weight(.medium))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
        .contentShape(Rectangle())
    }

}

#Preview {
    ProfileView()
}
