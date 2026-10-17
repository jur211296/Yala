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
    @Environment(SceneNavigation.self) private var navigation
    @Environment(ExchangeRateService.self) private var exchangeRateService
    @Environment(CurrencyConverter.self) private var currencyConverter

    let viewModel: PanelViewModel
    @Binding var sheets: PanelSheetState

    /// **El veredicto de App Attest de ESTE teléfono.** Es lo único del aviso que no se puede leer reactivamente:
    /// sale de `UserDefaults` y depende del reloj. Lo mantiene al día `cloudAttestVerdictWatcher`; las otras dos
    /// condiciones las lee `CloudAttestNotice.isShowing` vivas, en el body (ticket
    /// `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data`).
    @State private var attestVerdictIsTerminal = false
    /// Solo para el punto del botón de filtros: lee los filtros de `SessionState`, no guarda nada.
    @State private var panelFilters = PanelSessionFilters()

    /// Periodic banner visibility
    @State private var showPeriodicBanner = false

    /// Nudge banner visibility (dormant/sporadic users)
    @State private var showNudgeBanner = false
    /// El aviso que se está enseñando de la cola (UX 2.2 · L3-8). `nil` = el primero.
    @State private var selectedNotice: PanelNotice?
    /// La misma clave que lee `ContextualGuideBanner.panel()`: el Panel necesita saber si la guía sigue puesta para
    /// contarla en «1 de N».
    @AppStorage("guide.panel.dismissed") private var panelGuideDismissed = false

    @Environment(AppPreferences.self) private var appPreferences

    /// Coach mark: Pro tour (Phase 2)
    @State private var showProFabTour = false
    @State private var proFabTourIndex = 0
    @State private var showTodayFXCoachMark = false
    @State private var todayFXCoachMarkIndex = 0

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

    /// Los botones flotantes sólo aparecen cuando el scroll se lleva la fila de
    /// acciones del hero (`PanelQuickActionsRow`). Arriba sobran —las acciones
    /// están a la vista, y ahí es donde tapaban cifras—; a partir de media
    /// pantalla hacen falta, porque este Panel son cuatro pantallas de scroll y
    /// subir del todo para registrar un gasto se paga todos los días.
    ///
    /// Mismos dos umbrales con histéresis que el título de la barra, y por el
    /// mismo motivo: con un solo umbral, el scroll inercial cerca del límite
    /// hace parpadear el botón.
    @State private var showFloatingActions = false
    private static let floatingActionsShowAt: CGFloat = 180
    private static let floatingActionsHideAt: CGFloat = 150

    /// Check if voice input is locked (Pro feature)
    private var isVoiceLocked: Bool {
        !FeatureGateService.shared.canAccess(.voiceInput)
    }

    /// Check if image input is locked (Pro feature)
    private var isImageLocked: Bool {
        !FeatureGateService.shared.canAccess(.imageInput)
    }

    /// Gate del coach mark "Today FX": primera vez en multi-currency con la
    /// métrica balance cubriendo hoy. Bloqueado mientras el Pro Tour esté
    /// activo para evitar overlays simultáneos. Vive en PanelView para que
    /// el spotlight no se clipe al frame del card de Tendencias.
    private var shouldShowTodayFXCoachMark: Bool {
        guard !UITestHooks.isActive else { return false }
        guard viewModel.dataTrendType == .balance else { return false }
        guard viewModel.trendLiveAnchor != nil else { return false }
        guard (viewModel.trendLiveAnchorBreakdown?.count ?? 0) > 1 else { return false }
        guard !appPreferences.hasSeenTodayFXCoachMark else { return false }
        let proTourActive = ProTourManager.shared.triggered
            && !ProTourManager.shared.hasCompleted
        return !proTourActive
    }

    // MARK: - Setup Checklist Navigation

    private func handleSetupStep(_ step: SetupStepID) {
        switch step {
        case .firstExpense:
            sheets.showNewTransaction = true
        case .firstBudget:
            RouterEntryGate.shared.submit(.navigate(.budgets))
            RouterEntryGate.shared.submit(.autoOpenBudgetEditor)
        case .scheduledPayment:
            RouterEntryGate.shared.submit(.navigate(.scheduledPayments))
            RouterEntryGate.shared.submit(.autoOpenScheduledEditor)
        case .exploreSettings:
            sheets.isPresentingSettings = true
            SetupChecklistManager.shared.markCompleted(.exploreSettings)
        case .discoverFeatures:
            let checklist = SetupChecklistManager.shared
            // Si este paso termina «Primeros pasos», lo que sale es la oferta de prueba que pide el cierre de la
            // lista (UX 2.2 · L1-12, `TrialOfferMomentLogic`): abrir además el paywall general serían dos muros
            // seguidos.
            if !FeatureGateService.shared.isProUser && !checklist.wouldCompleteAll(by: .discoverFeatures) {
                sheets.subscriptionBannerSource = "setupChecklist"
                sheets.showSubscriptionFromBanner = true
            }
            checklist.markCompleted(.discoverFeatures)
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
        let lang = LanguageManager.baseLanguageCode(of: Bundle.main.preferredLocalizations.first ?? "en")
        let suffix = supportedLangs.contains(lang) ? lang : "en"
        let images = [
            "ExampleImages/example-receipt-\(suffix)",
            "ExampleImages/example-bank-alert-\(suffix)",
            "ExampleImages/example-transaction-list-\(suffix)"
        ].compactMap { UIImage(named: $0) }
        return images.isEmpty ? nil : images
    }

    // MARK: - Entrada de registros (fila de acciones y FAB comparten decisión)

    /// Voz e imagen: gate Pro → consentimiento de datos → acción. `PanelView` es
    /// el ÚNICO dueño de esta decisión a propósito. `FABStackView` monta su
    /// propia `.aiConsentAlert` para su menú; si la fila de acciones montara
    /// otra, serían dos anchors ante el mismo estado —regla 4 de presentaciones—
    /// así que la fila sólo llama aquí y la alerta sigue siendo la de
    /// `PanelSheetsModifier`. Mismo reparto que ya usaba `handleSetupStep`.
    private func startAIEntry(_ input: PendingAIInput) {
        switch input {
        case .voice where isVoiceLocked:
            sheets.showUpgradeForVoice = true
            return
        case .image where isImageLocked:
            sheets.showUpgradeForImage = true
            return
        default:
            break
        }
        guard appPreferences.aiDataConsentAccepted else {
            sheets.pendingAIInput = input
            sheets.showAIConsentAlert = true
            return
        }
        switch input {
        case .voice: sheets.showVoiceRecording = true
        case .image: sheets.showImageSelection = true
        }
    }

    /// Chat: gate Pro → onboarding/consentimiento → chat. Reusa el pure-logic
    /// `YalaAIOnboardingLogic` en vez de reordenar los tres casos a mano.
    private func startChat() {
        guard FeatureGateService.shared.canAccess(.chatAssistant) else {
            sheets.showUpgradeForChat = true
            return
        }
        switch YalaAIOnboardingLogic.nextScreen(
            consentAccepted: appPreferences.aiChatConsentAccepted,
            onboardingShown: appPreferences.hasShownYalaAIOnboarding
        ) {
        case .onboarding: sheets.showYalaAIOnboarding = true
        case .chat:       sheets.showChatSheet = true
        case .consent:    sheets.showChatConsentAlert = true
        }
    }

    // MARK: - Nudge CTA Routing

    private func handleNudgeAction(_ nudge: NudgeType) {
        switch nudge.actionType {
        case .activateFullMode:
            RouterEntryGate.shared.submit(.presentFullModeActivation)
        case .openGroupDetail:
            navigation.navigateToGroups()
        case .openPanel, .dismiss:
            break
        }
    }

    // MARK: - Toolbar Buttons

    /// Filtros del Panel: la misma hoja que Estadísticas e Informes, con todas las cuentas que quieras a la vez. El
    /// punto dice que el usuario filtró algo (`hasUserFilters`).
    private var filtersToolbarButton: some View {
        Button {
            sheets.showFilters = true
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(DS.Typography.body).fontWeight(.medium)
                .foregroundStyle(.thToolbarIcon)
        }
        .filterBadge(isActive: panelFilters.hasUserFilters)
        .accessibilityLabel(L10n.Accessibility.filters)
        .accessibilityIdentifier("panel_filters_button")
    }

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
        .accessibilityIdentifier("panel_inbox_button")
    }


    var body: some View {
        NavigationStack {
            mainContent
                // Mantiene al día el veredicto del attest (los tres momentos, en el propio modifier). El
                // decisivo es el aviso del store: el 401 llega con el Panel delante.
                .cloudAttestVerdictWatcher($attestVerdictIsTerminal)
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
                        filtersToolbarButton
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
            // «Omitir guía» salta el tour Pro ENTERO, no solo esta fase: antes avanzaba a la siguiente y el tour
            // volvía a salir en el Panel o en Estadísticas (auditoría UX 2.2 · lote 5 · B7).
            onSkip: { ProTourManager.shared.skipTour() },
            onComplete: {
                ProTourManager.shared.advancePhase()
            }
        )
        .task(id: ProTourManager.shared.currentPhase) {
            guard !UITestHooks.isActive else { return }
            guard !ProTourManager.shared.hasCompleted,
                  ProTourManager.shared.currentPhase == .panel else { return }
            do { try await Task.sleep(for: .seconds(0.8)) } catch { return }
            guard ProTourManager.shared.currentPhase == .panel,
                  !showProFabTour else { return }
            showProFabTour = true
        }
        .coachMarkOverlay(
            steps: ProTourSteps.todayFXSteps,
            isPresented: $showTodayFXCoachMark,
            currentIndex: $todayFXCoachMarkIndex,
            onComplete: { appPreferences.hasSeenTodayFXCoachMark = true }
        )
        .task(id: shouldShowTodayFXCoachMark) {
            guard shouldShowTodayFXCoachMark, !showTodayFXCoachMark else { return }
            do { try await Task.sleep(for: .seconds(1.5)) } catch { return }
            guard !Task.isCancelled, shouldShowTodayFXCoachMark else { return }
            withAnimation { showTodayFXCoachMark = true }
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
            viewModel.hiddenSections = Self.parseHiddenSections(appPreferences.resolvedSectionsHidden)
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
        .onChange(of: appPreferences.includeGroupsInPanelTotal) { _, _ in
            // El toggle vive en un sheet del tab Grupos, desacoplado del Panel.
            // Recalcular al volver para reflejar inclusión/exclusión de grupos
            // en el saldo total agregado.
            viewModel.recalculateData()
        }
        .onChange(of: appPreferences.includeGroupTransactionsInStats) { _, _ in
            // Mismo sheet del tab Grupos: el Financial Score (calculateHealthWidget)
            // incluye/excluye TX bridgeadas según esta preferencia. Recalcular
            // in-place para que "Salud Financiera" no quede stale al volver o vía
            // sync cross-device con el Panel ya montado.
            viewModel.recalculateData()
        }
        // Observa el valor RESUELTO, no la lista cruda: así el disparo cubre los dos
        // eventos que cambian lo que se ve —que se escriba la lista, y que el
        // centinela de siembra se encienda—. Con la lista cruda, un usuario cuya
        // configuración remota resulte ser «ninguna sección oculta» no dispararía
        // nada (el `didSet` corta al comparar `[]` con `[]`) y se quedaría viendo el
        // curado hasta reiniciar la app.
        .onChange(of: appPreferences.resolvedSectionsHidden) { oldValue, newValue in
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
        .modifier(PanelKeyboardRequestObserver(sessionState: sessionState, open: openFromKeyboard))
    }

    /// ⌘K y ⌘, (iPad con teclado): Yala IA por su camino de siempre (Pro → presentación → consentimiento) y Ajustes
    /// con la misma hoja que el botón de perfil.
    private func openFromKeyboard(_ request: KeyboardPanelRequest) {
        switch request {
        case .yalaAI: startChat()
        case .settings: sheets.isPresentingSettings = true
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

    /// «Tus finanzas» (cuentas y salud) se pinta si alguna de sus dos secciones está a la vista. Misma regla que
    /// las secciones temáticas de `PanelFilterAndWidgetsSection`.
    private var panoramaVisibility: (accounts: Bool, health: Bool) {
        let visible = { (kind: PanelSectionKind) in
            viewModel.isSectionVisible(kind) && viewModel.hasAnyVisibleWidget(in: kind)
        }
        return (visible(.accounts), visible(.health))
    }

    // MARK: - Avisos (UX 2.2 · L3-8)

    /// Cada aviso con la MISMA condición con la que se pintaba suelto.
    private var noticeFlags: PanelNoticeQueueLogic.Flags {
        var flags = PanelNoticeQueueLogic.Flags()
        flags.panelGuide = !UITestHooks.isActive && !panelGuideDismissed
        flags.setupChecklist = !UITestHooks.isActive && SetupChecklistManager.shared.shouldShow
        flags.updateAvailable = AppUpdateService.shared.shouldShowBanner && AppUpdateService.shared.latestVersion != nil
        flags.proOffer = StoreKitManager.shared.isInTrial
            || (!FeatureGateService.shared.isProUser && showPeriodicBanner)
        flags.nudge = !UITestHooks.isActive && NudgeService.shared.currentNudge != nil && showNudgeBanner
        flags.siriTip = !UITestHooks.isActive && appPreferences.showSiriTip && viewModel.transactions.count >= 5
        return flags
    }

    @ViewBuilder
    private func noticeView(_ notice: PanelNotice) -> some View {
        switch notice {
        case .panelGuide:
            ContextualGuideBanner.panel()
        case .setupChecklist:
            SetupChecklistCard(
                manager: SetupChecklistManager.shared,
                onStepTapped: { step in handleSetupStep(step) }
            )
        case .updateAvailable:
            if let updateVersion = AppUpdateService.shared.latestVersion {
                UpdateAvailableBanner(
                    version: updateVersion,
                    appStoreURL: AppUpdateService.shared.appStoreURL,
                    onDismiss: { AppUpdateService.shared.dismissBanner() }
                )
            }
        case .proOffer:
            if StoreKitManager.shared.isInTrial {
                TrialBanner(
                    daysRemaining: StoreKitManager.shared.trialDaysRemaining
                ) {
                    sheets.subscriptionBannerSource = "trialBanner"
                    sheets.showSubscriptionFromBanner = true
                }
            } else {
                ProUpgradeBanner(
                    onUpgrade: {
                        sheets.subscriptionBannerSource = "periodicBanner"
                        sheets.showSubscriptionFromBanner = true
                    },
                    onDismiss: {
                        ProUpsellService.shared.recordDismissed()
                        showPeriodicBanner = false
                    }
                )
                .onAppear {
                    ProUpsellService.shared.recordShown(source: "periodicBanner")
                }
            }
        case .nudge:
            if let nudge = NudgeService.shared.currentNudge {
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
        case .siriTip:
            SiriTipCard(isVisible: Binding(
                get: { appPreferences.showSiriTip },
                set: { appPreferences.showSiriTip = $0 }
            ))
        }
    }

    /// La cabecera del Panel. En compacta, la pila de siempre. En ancha, una banda de dos columnas —saldo y acciones
    /// a la izquierda, «Tus finanzas» a la derecha— con los avisos debajo: en horizontal la cabecera se comía un tercio
    /// de la pantalla (ticket `ipad-and-duo-panel-and-statistics-use-the-width`). Los mismos hijos en los dos casos,
    /// así redimensionar no cambia su identidad.
    private var headerLayout: AnyLayout {
        DS.Adaptive.isWideScreen(sizeClass)
            ? AnyLayout(HeaderBandLayout(spacing: DS.Spacing.lg))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.lg))
    }

    private var mainContent: some View {
        let panorama = panoramaVisibility
        let panoramaVisible = panorama.accounts || panorama.health
        return ZStack {
            PanelBackgroundView()

            ScrollViewReader { scrollProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    headerLayout {
                        // **Antes del hero, y el PRIMERO de la pila de banners.** Es el único aviso del Panel que no
                        // ofrece nada —los demás son novedades y ofertas— y dice que lo que la persona apunta aquí no
                        // está llegando a su cuenta. Hasta este ticket eso solo se leía al intentar cerrar sesión.
                        //
                        // Va DENTRO del scroll, no en un `safeAreaInset` como su hermano de Grupos: aquella pestaña no
                        // tiene pila de banners y ésta sí, y el inset roba altura permanente. Sin `UITestHooks.isActive`
                        // a propósito —al revés que el nudge y el checklist—: es el aviso que los XCUI vienen a medir.
                        if CloudAttestNotice.isShowing(verdictIsTerminal: attestVerdictIsTerminal) {
                            CloudAttestNoticeBanner(accessibilityID: "panel_attest_terminal_banner")
                                .padding(DS.Spacing.md)
                                .glassEffect(.regular)
                        }

                        // Gated on `heroWidget.data != nil` inside the section
                        // itself so the skeleton doesn't flash an empty card
                        // before the first `performCalculation()` lands.
                        PanelHeroSection(
                            viewModel: viewModel,
                            sessionState: sessionState,
                            showCustomPeriodPicker: $sheets.showCustomPeriodPicker
                        )
                        .headerBandColumn(.leading)

                        PanelQuickActionsRow(
                            canCreateRecords: viewModel.canUseVoiceInput,
                            hasAccounts: viewModel.accounts.contains { !$0.isArchived },
                            onCreateFirstAccount: { sheets.accountFormSheet = AccountFormSheet(account: nil) },
                            isVoiceLocked: isVoiceLocked,
                            isImageLocked: isImageLocked,
                            isChatLocked: !FeatureGateService.shared.canAccess(.chatAssistant),
                            isChatVisible: appPreferences.chatFABVisible,
                            onManualTap: { sheets.showNewTransaction = true },
                            onVoiceTap: { startAIEntry(.voice) },
                            onImageTap: { startAIEntry(.image) },
                            onChatTap: { startChat() }
                        )
                        .headerBandColumn(.leading)

                        // Movimientos sin cuenta: el primero de los avisos tras la cabecera. No ofrece nada: dice que hay
                        // dinero fuera del saldo y de los gastos, y lleva a la única salida (darles una cuenta).
                        OrphanedRecordsNotice(count: viewModel.orphanedRecordCount) {
                            sheets.showOrphanedRecords = true
                        }

                        // Los avisos, de uno en uno con «1 de N» (UX 2.2 · L3-8): apilados empujaban las cuentas a dos
                        // pantallas. El orden lo decide `PanelNoticeQueueLogic`; cada aviso conserva su condición.
                        PanelNoticeCarousel(
                            notices: PanelNoticeQueueLogic.visible(noticeFlags),
                            selected: $selectedNotice
                        ) { notice in
                            noticeView(notice)
                        }

                        // Ganancia/pérdida cambiaria del saldo que el Panel suma. La condición vive
                        // DENTRO de la card, no aquí: con el `if` fuera, cruzar el umbral mientras
                        // el usuario lee el detalle destruía la hoja abierta, y leer la propiedad
                        // aquí invalidaba este body entero en cada gasto.
                        FXPnLCard(viewModel: viewModel)

                        // «Tus finanzas» (cuentas + salud). En compacta va aquí, tras los avisos, como siempre; en
                        // ancha, `HeaderBandLayout` la sube a la columna derecha de la cabecera.
                        if panoramaVisible {
                            PanelPanoramaSection(
                                viewModel: viewModel,
                                sessionState: sessionState,
                                accountsSortOrderNames: appPreferences.accountsSortOrderNames,
                                accountsVisible: panorama.accounts,
                                healthVisible: panorama.health,
                                accountFormSheet: $sheets.accountFormSheet,
                                accountDetail: $sheets.accountDetail,
                                showUpgradeForAccounts: $sheets.showUpgradeForAccounts
                            )
                            .headerBandColumn(.trailing)
                        }

                        // The filter bar (period + chips), then each thematic section. Auto-hide uses
                        // `viewModel.hasAnyVisibleWidget(in:)`. Entre «Tus finanzas» y la barra de filtros van los
                        // 32 pt que había entre sections cuando «Tus finanzas» vivía dentro de este bloque.
                        PanelFilterAndWidgetsSection(
                            viewModel: viewModel,
                            sessionState: sessionState,
                            defaultCurrencyCodeRaw: appPreferences.defaultCurrencyCode.rawValue,
                            showVariations: appPreferences.showVariations,
                            sectionPrefsPresentation: $sheets.sectionPrefsPresentation,
                            showBudgetFavoritesSettings: $sheets.showBudgetFavoritesSettings,
                            showCustomPeriodPicker: $sheets.showCustomPeriodPicker
                        )
                        .padding(.top, panoramaVisible ? DS.Spacing.xxl - DS.Spacing.lg : 0)
                    }
                    .padding(.top, DS.Spacing.lg)
                    // Tocar un registro de «Últimos registros» abre su detalle (UX 2.2 · L3-12).
                    .environment(\.openPanelRecord, OpenPanelRecordAction { record in
                        sheets.recordDetail = PanelRecordPresentation(record: record)
                    })
                    // Al final del scroll están a la vista Yala IA y «+» (`showFloatingActions`): el último widget
                    // sube por encima de los dos.
                    .padding(.bottom, DS.Button.fabStackClearance(buttons: 2))
                }
                .scrollViewGlassEdges(horizontalMargin: DS.Adaptive.horizontalPadding(sizeClass))
                .onScrollGeometryChange(for: CGFloat.self) { geom in
                    geom.contentOffset.y
                } action: { _, offsetY in
                    let shouldShowTitle = showInlineTitle
                        ? offsetY > Self.inlineTitleHideAt
                        : offsetY >= Self.inlineTitleShowAt
                    if showInlineTitle != shouldShowTitle {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showInlineTitle = shouldShowTitle
                        }
                    }

                    // Los flotantes entran cuando la fila de acciones sale por
                    // arriba, y se van cuando vuelve. Dos umbrales, no uno.
                    let shouldShowFABs = showFloatingActions
                        ? offsetY > Self.floatingActionsHideAt
                        : offsetY >= Self.floatingActionsShowAt
                    if showFloatingActions != shouldShowFABs {
                        dsWithAnimation(reduceMotion) {
                            showFloatingActions = shouldShowFABs
                        }
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
                        // Sin el «Saldo inicial» ni los ajustes: no los apuntó la persona (`countsAsUserRecord`).
                        transactionCount: viewModel.transactions.count(where: {
                            SetupChecklistManager.countsAsUserRecord(balanceAdjustmentType: $0.balanceAdjustmentType)
                        }),
                        budgetCount: viewModel.budgets.count,
                        scheduledCount: viewModel.scheduledPayments.count
                    )
                    mgr.checkReExpand()
                    // «¿Era de prueba?» lo enciende `PanelShell` detrás del candado del Panel (`drainPanelIfActive`).
                }
            }

            // Botón flotante de nuevo registro + Chat FAB. Sólo mientras la
            // fila de acciones del hero NO esté a la vista (ver
            // `showFloatingActions`): con las dos a la vez, la acción principal
            // saldría dos veces en la misma pantalla.
            // `|| showProFabTour`: los dos pasos del tour de Pro (`ProTourSteps
            // .panelSteps`, ids "fab" y "proChatFab") señalan estos botones, y el
            // tour arranca con el Panel ARRIBA DEL TODO —donde ahora están
            // ocultos—, así que sin esto el coach mark apuntaría a una vista que
            // no existe. Mientras el tour corre, se muestran aunque el scroll
            // diga que no.
            if showFloatingActions || showProFabTour {
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
                            // Misma decisión que la fila de acciones del hero, en
                            // un solo sitio: `FABStackView` ya gatea el Pro antes
                            // de llamar aquí y `startChat()` lo vuelve a comprobar
                            // sin efecto, para que la fila pueda usar el helper.
                            onChatTap: { startChat() },
                            onUpgradeChat: { sheets.showUpgradeForChat = true },
                            onChatConsentNeeded: { sheets.showChatConsentAlert = true }
                        )
                    }
                }
                .transition(.opacity)
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

/// Consume la petición de un atajo (`SceneNavigation.pendingKeyboardPanelRequest`) cuando el Panel está delante. Se
/// mira también al cambiar de pestaña: si el Panel no estaba en la barra, `selectMainTab` lo elige 50 ms después.
private struct PanelKeyboardRequestObserver: ViewModifier {
    let sessionState: SessionState
    @Environment(SceneNavigation.self) private var navigation
    let open: (KeyboardPanelRequest) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: navigation.pendingKeyboardPanelRequest) { _, _ in consumeIfFront() }
            .onChange(of: navigation.selectedMainTab) { _, _ in consumeIfFront() }
    }

    private func consumeIfFront() {
        guard navigation.selectedMainTab == .panel, let request = navigation.pendingKeyboardPanelRequest else { return }
        navigation.pendingKeyboardPanelRequest = nil
        open(request)
    }
}
