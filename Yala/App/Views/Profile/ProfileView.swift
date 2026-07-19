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

    // H4: cierre de sesión universal (privada y nube). El coordinador es @Observable;
    // los alerts se materializan en @State propio vía onChange (regla toolbar-muerta:
    // jamás un binding de presentación con setter no-op). El cover terminal de relaunch
    // tiene DUEÑO ÚNICO en el root (SignOutRelaunchNetModifier, ContentView) — presentar
    // también desde este sheet creaba una carrera de anchors ante la misma fase y UIKit
    // tumbaba AMBAS cadenas (bug device 2026-07-14). Ante `.awaitingRelaunch` este sheet
    // solo se CIERRA; el root verifica presentación efectiva y reintenta.
    private var signOutCoordinator: CloudSessionSignOut { CloudSessionSignOut.shared }
    @State private var showCloudSignOutConfirm = false
    @State private var showSignOutBlockedAlert = false
    // H-2026-07-18-6: el bloqueo TRANSITORIO del sign-out solo-grupos usa un alert distinto
    // ("un momento más") — el permanente conserva el alert de conexión de siempre.
    @State private var showSignOutPendingAlert = false

    private func syncSignOutUI(from phase: CloudSessionSignOut.Phase) {
        switch phase {
        case .blocked(_, let reason):
            switch reason {
            case .transient: showSignOutPendingAlert = true
            case .permanent: showSignOutBlockedAlert = true
            }
        case .awaitingRelaunch: dismiss()
        case .idle, .working: break
        }
    }

    /// Copy del confirmationDialog de cierre de sesión — misma precedencia que `path()`
    /// (secundaria → nube → solo-grupos → privado), vía `CloudSignOutFlowLogic`.
    private var signOutConfirmMessage: String {
        let path = CloudSignOutFlowLogic.path(
            for: CloudSyncFlags.storageMode,
            secondarySessionActive: SecondarySessionStore.isActive(),
            hasLiveSession: CloudAuthService.shared.hasSession,
            groupsBackendEnabled: CloudSyncFlags.groupsBackendEnabled)
        switch CloudSignOutFlowLogic.confirmMessage(for: path) {
        case .icloud: return L10n.Settings.signOutConfirmMessageICloud
        case .cloud: return L10n.Settings.signOutConfirmMessageCloud
        case .secondary: return L10n.Settings.signOutConfirmMessageSecondary
        case .groupsOnly: return L10n.Settings.signOutConfirmMessageGroupsOnly
        }
    }

    // G5-D1b: eliminar cuenta (DARK — fila visible solo con sesión backend viva). Doble confirmación:
    // el primer diálogo explica la matriz por modo, el segundo es el irreversible. Misma disciplina de
    // presentación que el cierre de sesión (bindings reales + onChange; el cover terminal lo dueña el root
    // vía CloudSessionSignOut.phase — el cierre local del borrado entra en esa misma fase viva).
    private var deletionService: AccountDeletionService { AccountDeletionService.shared }
    @State private var showDeleteAccountConfirm = false
    @State private var showDeleteAccountFinal = false
    @State private var showDeleteAccountError = false

    /// Copy del PRIMER diálogo — explica qué se borra y dónde según el modo (misma decisión que
    /// `AccountDeletionService`: `.cloud` vs solo-grupos).
    private var deleteAccountConfirmMessage: String {
        let base = CloudSyncFlags.storageMode == .cloud
            ? L10n.Settings.deleteAccountConfirmMessageCloud
            : L10n.Settings.deleteAccountConfirmMessageGroupsOnly
        // Fase 1 (§3.3.4): desvío cruzado hacia "Vaciar mis datos" — patrón anti-error de destino.
        return base + "\n\n" + L10n.Settings.deleteAccountCrossReferHint
    }

    private func syncDeletionUI(from phase: AccountDeletionService.Phase) {
        switch phase {
        case .failed: showDeleteAccountError = true
        case .awaitingRelaunch: dismiss()  // belt: el root ya cerró vía CloudSessionSignOut.phase
        case .idle, .working: break
        }
    }

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
            // H4: cierre de sesión — confirmación destructiva con copy honesto por modo.
            .confirmationDialog(
                L10n.Settings.signOutConfirmTitle,
                isPresented: $showCloudSignOutConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Settings.signOutConfirmAction, role: .destructive) {
                    Task { await CloudSessionSignOut.shared.signOut(context: modelContext) }
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                // El copy honesto sigue la MISMA precedencia que `path()`: secundaria → nube →
                // solo-grupos → privado (extraído a `CloudSignOutFlowLogic.confirmMessage`).
                Text(signOutConfirmMessage)
            }
            .alert(L10n.Settings.signOutBlockedTitle, isPresented: $showSignOutBlockedAlert) {
                Button(L10n.Common.ok, role: .cancel) {
                    CloudSessionSignOut.shared.acknowledgeBlocked()
                }
            } message: {
                Text(L10n.Settings.signOutBlockedMessage)
            }
            // H-2026-07-18-6: bloqueo TRANSITORIO (solo-grupos, tras agotar el retry interno) —
            // copy que invita a esperar, no a revisar la conexión. Solo un bool se pone a la vez
            // (rutas mutuamente excluyentes en `syncSignOutUI`).
            .alert(L10n.Settings.signOutPendingTitle, isPresented: $showSignOutPendingAlert) {
                Button(L10n.Common.ok, role: .cancel) {
                    CloudSessionSignOut.shared.acknowledgeBlocked()
                }
            } message: {
                Text(L10n.Settings.signOutPendingMessage)
            }
            .onChange(of: signOutCoordinator.phase) { _, newPhase in
                syncSignOutUI(from: newPhase)
            }
            // Recuperación de estados huérfanos: si el sheet se cerró mientras el coordinator
            // trabajaba, al reabrir Ajustes se re-presenta el alert `.blocked` (SEGURO — nada
            // armado, solo informar); con `.awaitingRelaunch` el sheet se cierra solo para
            // despejar el anchor del cover terminal del root (dueño único).
            .onAppear { syncSignOutUI(from: signOutCoordinator.phase) }
            // G5-D1b: eliminar cuenta — DOBLE confirmación. Diálogo 1 (matriz por modo) → alerta 2
            // (irreversible) → borrado. Diálogo (step 1) y alerta (step 2) usan contenedores de
            // presentación DISTINTOS ⇒ el segundo presenta tras cerrarse el primero sin carrera same-anchor.
            .confirmationDialog(
                L10n.Settings.deleteAccountConfirmTitle,
                isPresented: $showDeleteAccountConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Settings.deleteAccountContinue, role: .destructive) {
                    showDeleteAccountFinal = true
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(deleteAccountConfirmMessage)
            }
            .alert(L10n.Settings.deleteAccountFinalTitle, isPresented: $showDeleteAccountFinal) {
                Button(L10n.Settings.deleteAccountFinalAction, role: .destructive) {
                    Task { await AccountDeletionService.shared.deleteAccount(context: modelContext) }
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Settings.deleteAccountFinalMessage)
            }
            .alert(L10n.Settings.deleteAccountErrorTitle, isPresented: $showDeleteAccountError) {
                Button(L10n.Settings.deleteAccountRetry) {
                    Task { await AccountDeletionService.shared.deleteAccount(context: modelContext) }
                }
                Button(L10n.Common.cancel, role: .cancel) {
                    AccountDeletionService.shared.acknowledgeFailure()
                }
            } message: {
                Text(L10n.Settings.deleteAccountErrorMessage)
            }
            .onChange(of: deletionService.phase) { _, newPhase in
                syncDeletionUI(from: newPhase)
            }
            .onAppear { syncDeletionUI(from: deletionService.phase) }
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
                case .storageMode:
                    StorageSettingsView()
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
                // G5-B: fila informativa "Cuenta de grupos" — SOLO en sesión solo-grupos (backend viva,
                // personal `.icloud`, flag ON, no secundaria). Reconoce que hay una sesión de grupos
                // activa en el device. Texto genérico: `CloudAuthService` no expone email/nombre
                // públicamente (no se añade accessor). NO mueve las filas existentes (va primero; su
                // divisor la separa de la fila iCloud, que se muestra con la misma condición `!= .cloud`).
                if CloudSyncFlags.groupsBackendEnabled
                    && CloudAuthService.shared.hasSession
                    && CloudSyncFlags.storageMode != .cloud
                    && !SecondarySessionStore.isActive() {
                    groupsAccountRow
                    SubsectionDivider()
                }

                // La fila "iCloud" se oculta en Modo Nube (`.cloud`): `iCloudSyncSettingsView` mentiría
                // (el store personal ya no lo espeja el mirror). La vista completa bifurcada por modo es
                // I12; aquí basta ocultarla (R12 mínimo).
                if CloudSyncFlags.storageMode != .cloud {
                    profileRow(
                        icon: "icloud.fill",
                        title: L10n.iCloud.title,
                        iconColor: .blue,
                        destination: .iCloudSync
                    )
                }

                // Modo Nube (I14): fila "Almacenamiento" — solo si el backend está configurado
                // (staging/DEV; prod placeholder no muestra nada). M1: oculta en sesión SECUNDARIA —
                // la pantalla describe/opera la migración del DUEÑO (la invitada ni la ve).
                // DIFERIDOS #34: el flag remoto gatea solo la ENTRADA — un usuario "engaged"
                // (`.cloud` persistido o migración/reversa en vuelo/fallida) conserva la fila
                // SIEMPRE (gestión + resume + REVERSA, el escape ante incidente).
                if StorageRowGateLogic.isVisible(
                    isConfigured: CloudBackendConfig.isConfigured,
                    isSecondaryActive: SecondarySessionStore.isActive(),
                    remoteEnabled: CloudRemoteFlags.cloudModeEnabled,
                    isEngaged: StorageModePersistence.read() == .cloud
                        || (CloudMigrationController.shared?.uiState ?? .idle) != .idle
                ) {
                    if CloudSyncFlags.storageMode != .cloud { SubsectionDivider() }
                    profileRow(
                        icon: "externaldrive.badge.icloud",
                        title: L10n.Storage.title,
                        iconColor: .indigo,
                        destination: .storageMode
                    )
                    .accessibilityIdentifier("storage_settings_row")
                }

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
                            subtitle: L10n.Settings.exportDataSubtitle,
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
                    // Fase 1 (§3.2): "arrow.counterclockwise" (volver al estado inicial);
                    // "trash" queda reservado a "Eliminar mi cuenta". `.red` es color de
                    // sistema (adapta a Dark Mode) → sin marcador A11Y-DM.
                    settingsRowContent(
                        icon: "arrow.counterclockwise", title: L10n.Settings.wipeData,
                        subtitle: L10n.Settings.wipeDataSubtitle, iconColor: .red)
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
                    .accessibilityIdentifier("profile_security_faceid")
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
                // H4: cerrar sesión — SIEMPRE al final (privada y nube; oculta solo en
                // modo group-invite, como el resto de filas personales).
                if CloudSignOutFlowLogic.shouldShowRow(isGroupInviteMode: isGroupInviteMode) {
                    SubsectionDivider()
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            showCloudSignOutConfirm = true
                        } label: {
                            settingsRowContent(
                                icon: "rectangle.portrait.and.arrow.right",
                                title: L10n.Settings.signOut,
                                subtitle: L10n.Settings.signOutSubtitle,
                                iconColor: .red,
                                showSpinner: signOutCoordinator.phase == .working)
                        }
                        .buttonStyle(.plain)
                        .disabled(signOutCoordinator.phase == .working)
                        .accessibilityIdentifier("profile_security_signout")

                        // H-2026-07-18-6: caption honesto mientras el sign-out solo-grupos ESPERA a
                        // que se asienten writes internos (retry interno) — el bloqueo típico es
                        // transitorio y antes obligaba a tocar "Cerrar sesión" varias veces.
                        if signOutCoordinator.phase == .working && signOutCoordinator.waitingForPending {
                            Text(L10n.Settings.signOutWorking)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, DS.Spacing.lg)
                                .padding(.bottom, DS.FormRow.paddingV)
                                .accessibilityIdentifier("profile_signout_working_caption")
                        }
                    }
                }
                // G5-D1b: eliminar cuenta — tras "Cerrar sesión", solo con sesión backend viva y fuera de
                // secundaria (RESIDUAL v1) / group-invite. DARK hoy (hasSession imposible en prod).
                if AccountDeletionRowLogic.shouldShow(
                    hasSession: CloudAuthService.shared.hasSession,
                    secondaryActive: SecondarySessionStore.isActive(),
                    isGroupInviteMode: isGroupInviteMode) {
                    SubsectionDivider()
                    Button {
                        showDeleteAccountConfirm = true
                    } label: {
                        settingsRowContent(
                            icon: "trash",
                            title: L10n.Settings.deleteAccount,
                            subtitle: L10n.Settings.deleteAccountSubtitle,
                            iconColor: .red)
                    }
                    .buttonStyle(.plain)
                    // Deshabilitada si CUALQUIER coordinador trabaja (borrado o cierre de sesión) —
                    // acciones mutuamente excluyentes que comparten la fase terminal de relaunch.
                    .disabled(deletionService.phase == .working || signOutCoordinator.phase == .working)
                    .accessibilityIdentifier("profile_security_delete_account")
                }
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
    /// G5-B: fila informativa (no navegable) que reconoce una sesión de grupos activa. Sin chevron
    /// (no navega) y con subtítulo genérico — el coordinador de sign-out cierra esa sesión.
    private var groupsAccountRow: some View {
        HStack(spacing: DS.Spacing.md) {
            if effectiveColorfulIcons {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(DS.Typography.subheadline).fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.indigo))
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .frame(width: 28)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.Settings.groupsAccountRowTitle)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                Text(L10n.Settings.groupsAccountRowSubtitle)
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile_groups_account_row")
    }

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
        subtitle: String? = nil,
        iconColor: Color = .gray,
        textColor: Color = .primary,
        showSpinner: Bool = false
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

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.body)
                    .foregroundStyle(textColor)

                if let subtitle {
                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            // H-2026-07-18-6: spinner inline en la fila mientras el cierre de sesión trabaja
            // (reemplaza el chevron — el resto de filas conservan el chevron por default false).
            if showSpinner {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "chevron.right")
                    .font(DS.Typography.labelSmall.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
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
