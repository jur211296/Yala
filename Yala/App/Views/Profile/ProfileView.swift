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
    @State private var userProfileImageData: Data?
    @AppStorage("userProfileIcon") private var userProfileIcon: String = ""
    @AppStorage("voiceInputEnabled") private var voiceInputEnabled: Bool = false
    @AppStorage("voiceLanguage") private var voiceLanguageRaw: String = VoiceLanguage.system.rawValue
    @AppStorage("imageInputEnabled") private var imageInputEnabled: Bool = false
    @AppStorage("aiDataConsentAccepted") private var aiDataConsentAccepted: Bool = false
    @State private var showAIConsentAlert: Bool = false
    @State private var pendingConsentForVoice: Bool = true

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
    @State private var showSupportSheet = false

    private var isProUser: Bool {
        FeatureGateService.shared.isProUser
    }

    private var isVoiceLocked: Bool {
        !FeatureGateService.shared.canAccess(.voiceInput)
    }

    private var isImageLocked: Bool {
        !FeatureGateService.shared.canAccess(.imageInput)
    }

    enum ProfileSheet: Identifiable {
        case personalDetails
        case importIntro
        case exportWizard

        var id: Int {
            hashValue
        }
    }

    // Destinations for NavigationStack
    enum ProfileDestination: Hashable {
        case accounts
        case categories
        case tags
        case themes
        case personalization
        case currency
        case appIcon
        case notifications
        case favorites
        case budgetsFavorites
        case planned
        case userDataReset
        case biometricSecurity
        case subscription
        case tips
        case faq
        case iCloudSync
        case siriShortcuts
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        // Header
                        profileHeader

                        // Sections
                        organizacionSection
                        preferenciasSection
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
            .alert(L10n.AIConsent.title, isPresented: $showAIConsentAlert) {
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
                Text(L10n.AIConsent.message)
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
                    SubscriptionView()
                case .tips:
                    TutorialsListView()
                case .faq:
                    FAQView()
                case .notifications:
                    NotificationsSettingsView()
                case .favorites:
                    FavoritesListView(mode: .manage)
                case .budgetsFavorites:
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
                ProfileImageStorage.migrateFromUserDefaultsIfNeeded()
                userProfileImageData = ProfileImageStorage.load()
            }
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

                    if let imageData = userProfileImageData,
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
    }

    // MARK: - Pro Badge with Cyan Spark

    /// Custom Pro badge with cyan spark so it stands out against the gold background
    private var proBadgeWithCyanSpark: some View {
        HStack(spacing: DS.Spacing.xs) {
            // Cyan spark (instead of gold)
            YalaSparkShape()
                .fill(Color.cyan)
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
                SubsectionDivider()
                profileRow(
                    icon: "tag.fill", title: L10n.Settings.categories, iconColor: .orange,
                    destination: .categories)
                SubsectionDivider()
                profileRow(
                    icon: "number", title: L10n.Settings.tags, iconColor: .purple,
                    destination: .tags)
                SubsectionDivider()
                profileRow(
                    icon: "chart.pie.fill", title: L10n.Settings.budgetsFavorites,
                    iconColor: .mint,
                    destination: .budgetsFavorites)
                SubsectionDivider()
                profileRow(
                    icon: "calendar.badge.clock", title: L10n.Settings.plannedPayments,
                    iconColor: .cyan,
                    destination: .planned
                )
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
                SubsectionDivider()
                profileRow(
                    icon: "paintpalette.fill", title: L10n.Settings.theme, iconColor: .pink,
                    destination: .themes)
                SubsectionDivider()
                voiceInputRow
                SubsectionDivider()
                imageInputRow

                if voiceInputEnabled || imageInputEnabled {
                    Text(L10n.AIConsent.inlineHint)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
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
                    if colorfulIcons {
                        Image(systemName: "waveform.badge.mic")
                            .font(DS.Typography.subheadline).fontWeight(.medium)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.hotPink)
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
                                        DispatchQueue.main.async {
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
                if colorfulIcons {
                    Image(systemName: "photo.on.rectangle")
                        .font(DS.Typography.subheadline).fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.teal)
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

    private var ayudaSection: some View {
        SectionBox(title: L10n.Settings.help) {
            VStack(spacing: DS.Spacing.none) {
                profileRow(
                    icon: "book.fill", title: L10n.Settings.tutorials,
                    iconColor: .electricIndigo, destination: .tips)
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
            if colorfulIcons {
                // iOS-style colored icon with rounded square background
                Image(systemName: icon)
                    .font(DS.Typography.subheadline).fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(iconColor)
                    )
            } else {
                // Plain icon without background
                Image(systemName: icon)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .frame(width: 28)
            }

            Text(title)
                .font(DS.Typography.body)
                .foregroundStyle(textColor)

            Spacer()

            Image(systemName: "chevron.right")
                .font(DS.Typography.labelSmall.weight(.medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
        .contentShape(Rectangle())
    }

}

#Preview {
    ProfileView()
}
