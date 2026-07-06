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

    @Environment(AppPreferences.self) private var appPreferences
    private var effectiveColorfulIcons: Bool {
        theme.forcesMonochromeIcons ? false : appPreferences.colorfulIcons
    }
    private var profileStorage: ProfileImageStorage { .shared }

    // Navigation & Sheets
    @State private var navigationPath = NavigationPath()
    @State private var activeSheet: ProfileSheet?

    // Import result - shown as alert after ImportIntroSheet dismisses
    @State private var importResult: ImportResult?
    @State private var showImportResult: Bool = false

    // Permission denied alert

    // Subscription state
    @State private var showUpgradeForVoice = false
    @State private var showUpgradeForImage = false
    @State private var showUpgradeForInsights = false
    @State private var showUpgradeForChat = false
    @State private var showSupportSheet = false

    // Coach mark: Settings tour
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

    /// GC-08: en modo solo-grupos el perfil se reduce a lo esencial de grupos +
    /// opciones universales; se ocultan las filas de finanzas personales.
    private var isGroupInviteMode: Bool {
        SessionState.shared.isGroupInviteMode
    }

    /// En solo-grupos no se muestra cromo Pro (no hay venta de Pro en ese modo).
    private var showsProBadge: Bool {
        isProUser && !isGroupInviteMode
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
            ScrollViewReader { scrollProxy in
                ScrollView {
                        VStack(spacing: DS.Spacing.xxl) {
                            // Header
                            profileHeader

                            // Sections
                            // Organización gestiona finanzas personales (cuentas, categorías,
                            // presupuestos…): se omite por completo en modo solo-grupos.
                            if !isGroupInviteMode {
                                organizacionSection
                            }
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
                    .scrollDisabled(false)
                    .onAppear { settingsScrollProxy = scrollProxy }
            }
            .navigationTitle(L10n.Profile.title)
            .navigationBarTitleDisplayMode(.inline)
            .yalaScreenBackground(.subtle)
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
                            let countBucket: String
                            switch result.count {
                            case 0: countBucket = "0"
                            case 1...10: countBucket = "1-10"
                            case 11...100: countBucket = "11-100"
                            default: countBucket = "100+"
                            }
                            TelemetryService.track(.dataImported, parameters: [
                                "exito": String(result.isSuccess),
                                "cantidad_bucket": countBucket,
                            ])
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
            .onAppear {
                // Auto-navigate to destination passed by caller (e.g. sync settings sheet).
                if let dest = initialDestination {
                    navigationPath.append(dest)
                }
            }
            // .routerConsumer(.profile) removed in F7 — was dead code (drained
            // .profileNavigate intent but never produced one, and consumed without
            // acting). Profile navigation flows through ContentView.handleMainTabIntent
            // for tab routing instead.
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
                case .faceIDProtectionGuide:
                    FaceIDProtectionGuideView()
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
                case .aiPrivacy:
                    AIPrivacySettingsView()
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
            onComplete: { appPreferences.hasSeenSettingsTour = true }
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
            // El coach mark monta un overlay-spotlight que intercepta taps; en uitest
            // bloquearía la navegación de Settings. Suprimido como el resto de overlays
            // de primer uso (F1c). También en solo-grupos: varios anclajes apuntan a
            // filas (Cuentas, Categorías…) ocultas en ese modo.
            guard !UITestHooks.isActive, !isGroupInviteMode else { return }
            if !appPreferences.hasSeenSettingsTour {
                do { try await Task.sleep(for: .seconds(0.8)) } catch { return }
                if !appPreferences.hasSeenSettingsTour {
                    showSettingsTour = true
                }
            }
        }
        .task(id: appPreferences.hasSeenSettingsTour) {
            guard !UITestHooks.isActive, !isGroupInviteMode else { return }
            guard appPreferences.hasSeenSettingsTour else { return }
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
                                colors: showsProBadge
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

                        Image(systemName: appPreferences.userProfileIcon.isEmpty ? "person.fill" : appPreferences.userProfileIcon)
                            .font(.system(size: avatarIconSize))
                            .foregroundStyle(theme.accent)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    }

                    // Spark badge for Pro users
                    if showsProBadge {
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
            .accessibilityLabel(L10n.Accessibility.profile)

            // Name
            Text(appPreferences.userName)
                .font(DS.Typography.title)
                .foregroundStyle(.primary)

            // Pro badge with cyan spark (only here, so it stands out)
            if showsProBadge {
                proBadgeWithCyanSpark
            }

            Button(L10n.Profile.edit) {
                activeSheet = .personalDetails
            }
            .font(DS.Typography.label)
            .foregroundStyle(.primary)

        }
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, showsProBadge ? DS.Spacing.lg : 0)
        .background(
            Group {
                if showsProBadge {
                    LinearGradient(
                        // A11Y-DM: tinte dorado Pro sutil decorativo (casi invisible, adapta a Dark Mode)
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
                .accessibilityIdentifier("profile_planned")
                .coachMarkAnchor("settingsPlanned")
                SubsectionDivider()
                profileRow(
                    icon: "star.fill", title: L10n.Settings.favorites, iconColor: .yellow,
                    destination: .favorites)
                    .accessibilityIdentifier("profile_favorites")
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var preferenciasSection: some View {
        SectionBox(title: L10n.Settings.preferences) {
            VStack(spacing: DS.Spacing.none) {
                // Personalización (formato, calendario, modo solo-gastos…) es de
                // finanzas personales: oculta en solo-grupos.
                if !isGroupInviteMode {
                    profileRow(
                        icon: "slider.horizontal.3", title: L10n.Settings.personalization,
                        iconColor: .indigo, destination: .personalization)
                    .accessibilityIdentifier("profile_personalization")
                    .coachMarkAnchor("settingsPersonalization")
                    SubsectionDivider()
                }
                // Notificaciones: universal (los grupos generan avisos).
                profileRow(
                    icon: "bell.fill", title: L10n.Settings.notifications, iconColor: .red,
                    destination: .notifications)
                .accessibilityIdentifier("profile_notifications")
                // Divisa/tasas e Icono de app: ocultos en solo-grupos (formato queda en
                // defaults: 2 decimales + símbolo de la moneda del grupo).
                if !isGroupInviteMode {
                    SubsectionDivider()
                    profileRow(
                        icon: "dollarsign.circle.fill", title: L10n.Settings.currencyAndExchange,
                        iconColor: DS.Semantic.successForeground, destination: .currency
                    )
                    .accessibilityIdentifier("profile_currency")
                    SubsectionDivider()
                    profileRow(
                        icon: "app.fill", title: L10n.Settings.appIcon,
                        iconColor: .blue, destination: .appIcon)
                    .coachMarkAnchor("settingsAppIcon")
                }
                SubsectionDivider()
                profileRow(
                    icon: "paintpalette.fill", title: L10n.Settings.theme, iconColor: .pink,
                    destination: .themes)
                .coachMarkAnchor("settingsTheme")
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
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

                // Importar/exportar operan sobre transacciones personales: ocultos en
                // solo-grupos (solo existen movimientos virtuales de grupo).
                if !isGroupInviteMode {
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
                }

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
                    icon: "faceid",
                    title: L10n.Settings.faceIDProtection,
                    iconColor: DS.Semantic.successForeground,
                    destination: .faceIDProtectionGuide)
                // Atajos de Siri: registran gastos personales — fuera de alcance en solo-grupos.
                if !isGroupInviteMode {
                    SubsectionDivider()
                    profileRow(
                        icon: "mic.badge.plus", title: String(localized: "settings.siriShortcuts"),
                        iconColor: .blue, destination: .siriShortcuts)
                }
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
                // Privacidad IA (chat) y Suscripción Pro: ligadas a finanzas personales.
                // En solo-grupos el upgrade fluye por "Activar Yala completo".
                if !isGroupInviteMode {
                    SubsectionDivider()
                    profileRow(
                        icon: "hand.raised.fill", title: L10n.Settings.aiPrivacy,
                        iconColor: .indigo, destination: .aiPrivacy)
                    SubsectionDivider()
                    profileRow(
                        icon: "creditcard.fill", title: L10n.Settings.subscriptions,
                        iconColor: .purple, destination: .subscription)
                }
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
                // Tutoriales: el catálogo es de finanzas personales (no hay tutorial de
                // grupos) → oculto en solo-grupos.
                if !isGroupInviteMode {
                    profileRow(
                        icon: "book.fill", title: L10n.Settings.tutorials,
                        iconColor: .electricIndigo, destination: .tips)
                    .coachMarkAnchor("settingsTutorials")
                    SubsectionDivider()
                }
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
        .previewAppPreferences()
}
