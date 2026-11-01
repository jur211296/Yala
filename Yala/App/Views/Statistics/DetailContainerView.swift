//
//  DetailContainerView.swift
//  Yala
//
//  Unified container for Trends, Categories, and Records with shared navigation.
//  Located in Statistics as it's the primary drill-down view from the Statistics tab.
//

import SwiftData
import SwiftUI

// MARK: - Detail Container View

/// Unified container view providing chip-based navigation between Trends, Categories, and Records.
/// Uses extracted TrendsTabView and CategoriesTabView components for their respective content.
struct DetailContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState
    @Environment(SceneNavigation.self) private var navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    /// Size class de la ventana: en ancha el chip Registros abre el registro en un panel al lado de la lista.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - ViewModels

    /// La pantalla tiene poco alto: Yala IA y «+» en fila (UX 2.2 · L15-14).
    @State private var fabShortContainer = false
    /// Yala IA y «+» flotantes solo cuando el scroll se lleva la fila de acciones del hero (card kzhe, el patrón del
    /// Panel). Lo escribe la fila de cada subpestaña (`StatsQuickActionsSlot`).
    @State private var showFloatingActions = false

    @State private var dataViewModel = DetailContainerViewModel()
    @State private var recordsViewModel: RecordsViewModel
    @State private var trendsViewModel: StatisticsViewModel
    @State private var insightsViewModel = InsightsViewModel()

    // MARK: - Navigation State

    /// Las pestañas montadas y la que se ve. Chip y página cambian juntos (`StagedTabPages`, card pjum): la nueva se
    /// monta invisible debajo y, ya montada, la fila y la página cambian en el mismo movimiento.
    @State private var pages = StagedTabSelection<DetailViewTab>(.records)
    private var selectedTab: DetailViewTab { pages.shown }

    // MARK: - UI State

    @State private var showDeleteConfirmation = false
    @State private var showBulkEditSheet = false
    @State private var isPresentingSettings = false
    /// La salida de lo que falta para registrar, pedida por la fila del hero o por el flotante (card 7jfp).
    @State private var missingStepExit: MissingStepExit?
    @State private var recalculateTask: Task<Void, Never>?
    @State private var pendingReload = false
    @State private var isInBackground = false
    /// La pasada de cálculo de las cuatro pestañas (y la firma de la Salud Financiera, que vive con ella).
    @State private var recalculation = StatisticsRecalculation()
    /// Ancho del chip Registros: decide si lista y registro abierto caben lado a lado.
    @State private var recordsWidth: CGFloat = 0
    private let isFromSearch: Bool  // Skip session sync when coming from global search

    @Environment(AppPreferences.self) private var appPreferences

    @State private var showAIConsentAlert = false
    @State private var pendingAIInput: PendingAIInput = .voice

    /// Voice recording sheet
    @State private var showVoiceRecording = false

    /// Image selection sheet
    @State private var showImageSelection = false

    /// Upgrade prompt sheets for Pro features
    @State private var showUpgradeForVoice = false
    @State private var showUpgradeForImage = false

    /// Chat Assistant
    @State private var showChatSheet = false
    @State private var showUpgradeForChat = false
    @State private var showChatConsentAlert = false
    @State private var showYalaAIOnboarding = false
    @State private var pendingOpenChatAfterOnboarding = false

    // MARK: - Pro Feature Gates

    private var isVoiceLocked: Bool {
        !FeatureGateService.shared.canAccess(.voiceInput)
    }

    private var isImageLocked: Bool {
        !FeatureGateService.shared.canAccess(.imageInput)
    }

    /// Check if voice input can be used (requires accounts and subcategories)
    private var canUseVoiceInput: Bool {
        dataViewModel.canUseVoiceInput
    }

    // MARK: - Acciones de arriba (card kzhe)

    /// Lo que la fila del hero de cada subpestaña necesita. Mismos gates que el botón flotante, decididos aquí: la
    /// fila solo pinta y llama.
    private var statsQuickActions: StatsQuickActions {
        StatsQuickActions(
            canCreateRecords: canUseVoiceInput,
            missingStep: dataViewModel.visibleMissingStep,
            onCreateFirstAccount: { missingStepExit = .createAccount },
            onCreateCategories: { createCategories() },
            isVoiceLocked: isVoiceLocked,
            isImageLocked: isImageLocked,
            isChatLocked: !FeatureGateService.shared.canAccess(.chatAssistant),
            isChatVisible: appPreferences.chatFABVisible,
            onManualTap: { recordsViewModel.showNewTransaction = true },
            onVoiceTap: { startAIEntry(.voice) },
            onImageTap: { startAIEntry(.image) },
            onChatTap: { startChat() },
            showsFloating: $showFloatingActions
        )
    }

    /// Lo que falta para registrar, desde el flotante: la misma salida que la fila (card 7jfp).
    private func resolveMissingStep() {
        switch dataViewModel.quickActionsState {
        case .needsAccount: missingStepExit = .createAccount
        case .needsCategories: createCategories()
        case .ready: break
        }
    }

    /// «Crear categorías»: crea las de siempre, o abre Ajustes › Categorías si ya hay propias (como el Panel).
    private func createCategories() {
        switch dataViewModel.createCategoriesAction() {
        case .seedDefaults: DS.Haptic.success()
        case .openCategoriesSettings: missingStepExit = .categoriesSettings
        }
    }

    /// Voz y foto desde la fila: Pro → permiso de IA → la entrada. El mismo orden que `FABStackView` y que
    /// `PanelView.startAIEntry`; el permiso lo pide el `aiConsentAlert` de esta vista.
    private func startAIEntry(_ input: PendingAIInput) {
        switch input {
        case .voice where isVoiceLocked:
            showUpgradeForVoice = true
            return
        case .image where isImageLocked:
            showUpgradeForImage = true
            return
        default:
            break
        }
        guard appPreferences.aiDataConsentAccepted else {
            pendingAIInput = input
            showAIConsentAlert = true
            return
        }
        switch input {
        case .voice: showVoiceRecording = true
        case .image: showImageSelection = true
        }
    }

    /// Yala IA: Pro → presentación, permiso o chat (`YalaAIOnboardingLogic`), como el flotante.
    private func startChat() {
        guard FeatureGateService.shared.canAccess(.chatAssistant) else {
            showUpgradeForChat = true
            return
        }
        switch YalaAIOnboardingLogic.nextScreen(
            consentAccepted: appPreferences.aiChatConsentAccepted,
            onboardingShown: appPreferences.hasShownYalaAIOnboarding
        ) {
        case .onboarding: showYalaAIOnboarding = true
        case .chat:       showChatSheet = true
        case .consent:    showChatConsentAlert = true
        }
    }

    // MARK: - Initialization

    init(context: RecordsFilterContext = .empty, initialTab: DetailViewTab = .insights) {
        self.isFromSearch = context.isFromSearch
        var cleanContext = context
        // Only reset period and filters when NOT coming from search
        // When from search, respect the passed period (.allTime) and searchText
        if !context.isFromSearch {
            cleanContext.period = .thisMonth
            cleanContext.accountID = nil
            cleanContext.categoryID = nil
            cleanContext.need = nil
        }
        _recordsViewModel = State(initialValue: RecordsViewModel(context: cleanContext))

        let initialMetric: TrendMetric = SessionState.shared.isExpensesOnlyMode ? .expense : .balance
        let trendsContext = StatisticsContext(
            initialMetric: initialMetric,
            period: .thisMonth,
            accountID: nil,
            categoryID: nil,
            subcategoryName: nil,
            need: nil,
            dateInterval: nil
        )
        _trendsViewModel = State(initialValue: StatisticsViewModel(context: trendsContext))
        _pages = State(initialValue: StagedTabSelection(initialTab))
    }

    // MARK: - Body

    var body: some View {
        mainContent
            .prefersToolbarItemsInVerticalBar()
            .toolbar {
                if recordsViewModel.isSelectionMode {
                    selectionModeToolbar
                } else {
                    normalModeToolbar
                }
            }
            .navigationBarBackButtonHidden(recordsViewModel.isSelectionMode)
            .tint(.primary)
            .modifier(
                DetailContainerSheets(
                    recordsViewModel: recordsViewModel,
                    trendsViewModel: trendsViewModel,
                    showDeleteConfirmation: $showDeleteConfirmation,
                    showBulkEditSheet: $showBulkEditSheet,
                    isPresentingSettings: $isPresentingSettings,
                    showVoiceRecording: $showVoiceRecording,
                    showImageSelection: $showImageSelection,
                    showUpgradeForVoice: $showUpgradeForVoice,
                    showUpgradeForImage: $showUpgradeForImage,
                    showChatSheet: $showChatSheet,
                    showUpgradeForChat: $showUpgradeForChat,
                    showChatConsentAlert: $showChatConsentAlert,
                    showYalaAIOnboarding: $showYalaAIOnboarding,
                    pendingOpenChatAfterOnboarding: $pendingOpenChatAfterOnboarding,
                    showAIConsentAlert: $showAIConsentAlert,
                    pendingAIInput: $pendingAIInput,
                    modelContext: modelContext,
                    recalculateData: recalculateData,
                    reloadAndRecalculate: reloadAndRecalculate
                )
            )
            // «Editar» del aviso tras guardar abre el registro con la hoja de editar de Estadísticas (UX 2.2 · L2-5).
            .environment(\.savedRecordEditorOpener, recordsViewModel.savedRecordEditorOpener)
            .appliesPendingRemoteChanges(sessionState)
            // Menú contextual de las filas de Registros: confirmación de borrado y selector de categoría.
            .modifier(RecordRowActionsPresenter(viewModel: recordsViewModel))
            .onAppear {
                dataViewModel.setContext(modelContext)
                performRecalculation()
            }
            .onDisappear {
                recalculateTask?.cancel()
                recordsViewModel.exitDuplicateMode()   // modo efímero
            }
            .onChange(of: scenePhase) { _, newPhase in
                UITestHooks.shared.traceLifecycle("fase \(newPhase)")
                switch newPhase {
                case .background, .inactive:
                    isInBackground = true
                    recalculateTask?.cancel()
                case .active:
                    guard UIApplication.shared.applicationState == .active else { return }
                    isInBackground = false
                    reloadAndRecalculate()
                @unknown default:
                    break
                }
            }
            .task {
                if selectedTab != navigation.selectedDetailTab {
                    pages.jump(to: navigation.selectedDetailTab)
                }
            }
            .onChange(of: navigation.selectedDetailTab) { _, newValue in
                if selectedTab != newValue { pages.jump(to: newValue) }
            }
            .onChange(of: selectedTab) { _, newTab in
                // Cada subpestaña monta su scroll desde arriba, con su fila a la vista.
                showFloatingActions = false
                if newTab != .records {
                    recordsViewModel.exitDuplicateMode()   // modo efímero: se apaga al salir del tab Registros
                }
                if navigation.selectedDetailTab != newTab {
                    navigation.selectedDetailTab = newTab
                }
                // .categories también consume insightData.periodSummary (gate >=5 tx
                // del Distribution Insight Card) — disparar recalculation también ahí.
                if newTab == .insights || newTab == .categories {
                    scheduleRecalculation(reload: false)
                }
            }
            .onChange(of: navigation.selectedMainTab) { _, newTab in
                // Sync filters when navigating to Statistics tab (view may already be mounted)
                if newTab == .statistics && !isFromSearch {
                    recalculateData()
                }
            }
            // Sin `onChange(of: dataViewModel.allTransactions)` (retirado el 2026-10-30, encargo
            // `eficiencia-carga-por-vista`): el array solo cambia en `setContext` (el `onAppear`, que calcula justo
            // después) y en `scheduleRecalculation` (que también). Pedía otro cálculo 150 ms después sobre los mismos
            // datos y comparaba el histórico entero en cada repintado.
            .onChange(of: sessionState.dataVersion) { _, _ in
                reloadAndRecalculate()
            }
            .onChange(of: sessionState.comparisonMode) { recalculateData() }
            .onChange(of: appPreferences.insightsTone) { recalculateData() }
            .onChange(of: appPreferences.insightsFocus) { recalculateData() }
            // Toggles globales de grupos (sheet del tab Grupos). Refrescan in-place
            // sin esperar a cambiar de período: includeGroupTransactionsInStats afecta
            // insightData + Financial Score + Tendencias/Distribución;
            // includeGroupTransactionsInFeed afecta la sub-pestaña Registros. También
            // cubre cambios que llegan vía sync cross-device con la vista ya montada.
            .onChange(of: appPreferences.includeGroupTransactionsInStats) { recalculateData() }
            .onChange(of: appPreferences.includeGroupTransactionsInFeed) { recalculateData() }
            .modifier(
                DetailContainerObservers(
                    sessionState: sessionState,
                    trendsViewModel: trendsViewModel,
                    recordsViewModel: recordsViewModel,
                    categories: dataViewModel.categories,
                    subcategories: dataViewModel.allSubcategories,
                    recalculateData: recalculateData
                ))
            .aiConsentAlert(isPresented: $showAIConsentAlert, pendingInput: $pendingAIInput) { input in
                switch input {
                case .voice: showVoiceRecording = true
                case .image: showImageSelection = true
                }
            }
            .modifier(StatsRecordsPaneObservers(
                recordsViewModel: recordsViewModel,
                horizontalSizeClass: horizontalSizeClass,
                recordsTabIsShown: selectedTab == .records,
                allTransactions: dataViewModel.allTransactions))
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack {
            VStack(spacing: DS.Spacing.none) {
                // Contextual guide for current statistics tab
                statisticsGuide
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.xs)

                tabContent
                    .environment(\.statsQuickActions, statsQuickActions)
            }
            .navigationChipsInset {
                navigationChipsBar
            }

            // Yala IA y «+» en las cuatro pestañas, no solo en Registros: en el Panel «Nuevo registro» está siempre a
            // mano (la fila del hero o, al bajar, estos mismos flotantes), y Estadísticas lleva ya su hero
            // (`HeroHeader`). Decisión del 2026-10-03, ticket `distribution-subviews-miss-the-new-panel-hero`.
            // Desde la card kzhe, solo cuando el scroll se lleva la fila de acciones del hero: arriba la acción ya está a
            // la vista y los flotantes tapaban la primera tarjeta.
            if showFloatingActions && !recordsViewModel.isSelectionMode && !recordPaneCoversList {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FABStackView(
                            canUseVoiceInput: canUseVoiceInput,
                            isVoiceLocked: isVoiceLocked,
                            isImageLocked: isImageLocked,
                            isChatLocked: !FeatureGateService.shared.canAccess(.chatAssistant),
                            chatFABVisible: appPreferences.chatFABVisible,
                            isShortContainer: fabShortContainer,
                            missingStep: dataViewModel.visibleMissingStep,
                            onResolveMissingStep: { resolveMissingStep() },
                            onVoiceTap: { showVoiceRecording = true },
                            onImageTap: { showImageSelection = true },
                            onManualTap: { recordsViewModel.showNewTransaction = true },
                            onUpgradeVoice: { showUpgradeForVoice = true },
                            onUpgradeImage: { showUpgradeForImage = true },
                            onChatTap: {
                                switch YalaAIOnboardingLogic.nextScreen(
                                    consentAccepted: appPreferences.aiChatConsentAccepted,
                                    onboardingShown: appPreferences.hasShownYalaAIOnboarding
                                ) {
                                case .onboarding: showYalaAIOnboarding = true
                                case .chat:       showChatSheet = true
                                case .consent:    showChatConsentAlert = true
                                }
                            },
                            onUpgradeChat: { showUpgradeForChat = true }
                        )
                    }
                }
                // Con poco alto, los dos botones van en fila (UX 2.2 · L15-14).
                .measuresShortContainer($fabShortContainer)
                // Con el registro abierto al lado, los flotantes van sobre la lista, como en la página Registros.
                .frame(width: recordsListWidth)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Modo selección: qué hacer y, con algo elegido, Eliminar y Editar (L8-12).
            if recordsViewModel.isSelectionMode {
                RecordsSelectionBar(
                    selectedCount: recordsViewModel.selectedRecordIDs.count,
                    onDelete: {
                        recordsViewModel.prepareBulkDelete(context: modelContext)
                        showDeleteConfirmation = true
                    },
                    onEdit: handleEditAction
                )
                .frame(width: recordsListWidth)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .yalaScreenBackground()
        .missingStepExitSheet(
            $missingStepExit,
            existingAccountNames: { dataViewModel.accounts.map(\.name) },
            onDismiss: { reloadAndRecalculate() }
        )
    }

    @ViewBuilder
    private var statisticsGuide: some View {
        switch selectedTab {
        case .insights:
            ContextualGuideBanner.insights()
        case .trends:
            ContextualGuideBanner.trends()
        case .categories:
            ContextualGuideBanner.categories()
        case .records:
            ContextualGuideBanner.records()
        }
    }

    private var tabContent: some View {
        StagedTabPages(selection: $pages) { tab in
            page(for: tab)
        }
    }

    @ViewBuilder
    private func page(for tab: DetailViewTab) -> some View {
        switch tab {
        case .insights:
            InsightsTabView(
                accounts: dataViewModel.accounts,
                categories: dataViewModel.categories,
                allSubcategories: dataViewModel.allSubcategories,
                tags: dataViewModel.tags,
                allTransactions: dataViewModel.allTransactions,
                budgets: dataViewModel.budgets,
                scheduledPayments: dataViewModel.scheduledPayments,
                defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue,
                viewModel: insightsViewModel,
                trendsViewModel: trendsViewModel
            )
            .accessibilityIdentifier("stats_tab_insights")
        case .trends:
            TrendsTabView(
                accounts: dataViewModel.accounts,
                categories: dataViewModel.categories,
                allSubcategories: dataViewModel.allSubcategories,
                tags: dataViewModel.tags,
                allTransactions: dataViewModel.allTransactions,
                dataGeneration: dataViewModel.dataGeneration,
                trendsViewModel: trendsViewModel,
                insightsViewModel: insightsViewModel,
                defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue
            )
            .accessibilityIdentifier("stats_tab_trends")
        case .categories:
            CategoriesTabView(
                accounts: dataViewModel.accounts,
                categories: dataViewModel.categories,
                allSubcategories: dataViewModel.allSubcategories,
                tags: dataViewModel.tags,
                allTransactions: dataViewModel.allTransactions,
                dataGeneration: dataViewModel.dataGeneration,
                viewModel: trendsViewModel,
                insightsViewModel: insightsViewModel,
                defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue
            )
            // Tocar un segmento pregunta «Ver solo / Ocultar» (propuesta A, 2026-10-25).
            .segmentFilterChoiceHost()
            .accessibilityIdentifier("stats_tab_categories")
        case .records:
            recordsContent
        }
    }

    // MARK: - Registros: lista y registro abierto

    /// Ventana ancha: tocar un registro lo abre en un panel, no en hoja (`RecordsViewModel.opensDetailInColumn`,
    /// el molde de la página Registros). Sin `NavigationSplitView`: este chip vive dentro de la pila de Estadísticas.
    private var recordsOpensInPane: Bool { horizontalSizeClass == .regular }

    /// Anchos de la lista, los de `ListDetailSplit`: más ancha con texto de accesibilidad.
    private var recordsListWidths: DS.Adaptive.ListColumnWidths {
        DS.Adaptive.listColumnWidths(isAccessibilityText: dynamicTypeSize.isAccessibilitySize)
    }

    /// Lista y panel caben lado a lado: dos anchos de iPhone, la misma regla que `ListDetailSplit`.
    private var recordsSideBySide: Bool {
        recordsOpensInPane && recordsWidth >= 2 * recordsListWidths.min
    }

    /// Sin sitio para los dos, el registro abierto tapa la lista; su X la devuelve.
    private var recordPaneCoversList: Bool {
        selectedTab == .records && recordsOpensInPane && !recordsSideBySide && openPaneRecord != nil
    }

    /// Ancho de la lista cuando va al lado del panel; `nil` (todo) si no.
    private var recordsListWidth: CGFloat? {
        selectedTab == .records && recordsSideBySide ? recordsListWidths.ideal : nil
    }

    /// El registro abierto, resuelto contra lo cargado (nunca `model(for:)`, que fabrica un objeto aunque ya no
    /// exista).
    private var openPaneRecord: TransactionItem? {
        guard let id = recordsViewModel.openRecordID else { return nil }
        // Lo que espera su borrado con «Deshacer» ya no se enseña (UX 2.2 · L15-13).
        return dataViewModel.allTransactions.first {
            $0.persistentModelID == id && !RecordPendingDeletion.shared.hides(id, transferPairID: $0.transferPairID)
        }
    }

    /// Los mismos hijos en todos los tamaños —la lista siempre la primera— para que redimensionar no la
    /// reconstruya: lado a lado un `HStack`; sin sitio, un `ZStack` donde el panel tapa la lista; en compacta, la
    /// lista sola (la hoja de siempre).
    private var recordsContent: some View {
        let sideBySide = recordsSideBySide
        let layout = sideBySide ? AnyLayout(HStackLayout(spacing: DS.Spacing.none)) : AnyLayout(ZStackLayout())
        return layout {
            RecordsTabView(
                viewModel: recordsViewModel,
                accounts: dataViewModel.accounts,
                categories: dataViewModel.categories,
                tags: dataViewModel.tags,
                subcategories: dataViewModel.allSubcategories,
                transactionDateRange: dataViewModel.computeTransactionDateRange(),
                defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue,
                onFilterChange: { recalculateData() }
            )
            .frame(width: sideBySide ? recordsListWidths.ideal : nil)
            .overlay(alignment: .trailing) {
                if sideBySide { Divider() }
            }
            .accessibilityIdentifier("stats_tab_records")

            if recordsOpensInPane, sideBySide || openPaneRecord != nil {
                recordPane
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { recordsWidth = $0 }
    }

    @ViewBuilder
    private var recordPane: some View {
        if let record = openPaneRecord {
            TransactionDetailSheet(
                transaction: record,
                presentation: .pane,
                onEdit: { recordsViewModel.editOpenRecord(record) },
                onClose: { recordsViewModel.openRecordID = nil },
                onDuplicate: { recordsViewModel.duplicateRecord(record) },
                onDelete: { recordsViewModel.deleteOpenRecord(
                    record, context: modelContext,
                    undoName: RecordDeleteConfirmationText.undoName(for: record, preferences: appPreferences)) },
                deleteIsUndoable: true
            )
            .id(record.persistentModelID)
        } else {
            ContentUnavailableView(L10n.Records.detailPlaceholder, systemImage: ConfigurableTab.records.iconName)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("stats_records_detail_placeholder")
        }
    }

    // MARK: - Navigation Chips Bar

    private var navigationChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(DetailViewTab.allCases) { tab in
                    navigationChipButton(for: tab)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
        .fadesTowardVerticalBar()
        // Al pulsar, el cristal interactivo del chip se hincha por encima de su cápsula; sin esto el scroll lo recortaba
        // en recto arriba y abajo (QA de Jürgen, 2026-10-27). Cabe en el aire de `navigationChipsInset`. Grupos ya lo lleva.
        .scrollClipDisabled()
        // La cápsula cambia de ancho con la página, en el mismo movimiento. Implícita: un `withAnimation` no anima
        // dentro de una pestaña.
        .animation(reduceMotion ? nil : StagedTabSelection<DetailViewTab>.animation, value: selectedTab)
    }

    private func navigationChipButton(for tab: DetailViewTab) -> some View {
        // Cuatro chips con icono y solo el elegido con su nombre (UX 2.2 · L11-1, decisión de Jürgen del
        // 2026-10-15). Con los cuatro nombres, «Distribución» salía cortada y «Registros» quedaba entera fuera de
        // la pantalla de un iPhone 17 Pro, sin nada que dijera que la fila se desliza.
        NavigationChipButton(
            title: tab.title, icon: tab.icon, isSelected: selectedTab == tab, animatesSwitch: true
        ) {
            StagedTabSelection.select(tab, in: $pages, reduceMotion: reduceMotion)
        }
        .accessibilityIdentifier("detail_chip_\(tab.rawValue.lowercased())")
    }

    // MARK: - Normal Mode Toolbar

    @ToolbarContentBuilder
    private var normalModeToolbar: some ToolbarContent {
        // Tab Registros: «Seleccionar» a la vista, no solo dentro de «···» (L8-12).
        if selectedTab == .records {
            ToolbarItem(placement: .topBarTrailing) {
                RecordsSelectToolbarButton(viewModel: recordsViewModel)
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }

        ToolbarItem(placement: .topBarTrailing) {
            if selectedTab == .records {
                // Tab Registros: menú (···) con Seleccionar + Filtrar + Identificar duplicados.
                RecordsOverflowMenu(viewModel: recordsViewModel)
                    .accessibilityIdentifier("records_overflow_menu")
            } else {
                // Tendencias / Categorías / Insights: solo botón Filtrar (→ trendsViewModel).
                Button {
                    trendsViewModel.showFiltersSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(DS.Typography.body).fontWeight(.medium)
                        .foregroundStyle(.thToolbarIcon)
                }
                .accessibilityLabel(L10n.Accessibility.filters)
                .accessibilityIdentifier("filters_toolbar_button")
                .overlay(alignment: .topTrailing) {
                    if trendsViewModel.userFilterCount(isExpensesOnlyMode: sessionState.isExpensesOnlyMode) > 0 {
                        Circle()
                            .fill(Color.hotPink)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                            .accessibilityHidden(true)
                    }
                }
            }
        }

        // iOS 26 spacer creates separate glass groups
        ToolbarSpacer(.fixed, placement: .topBarTrailing)

        ProfileToolbarItem {
            isPresentingSettings = true
        }
    }

    // MARK: - Selection Mode Toolbar

    @ToolbarContentBuilder
    private var selectionModeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(L10n.Common.cancel) {
                recordsViewModel.exitSelectionMode()
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            let allSelected = recordsViewModel.selectedRecordIDs.count ==
                recordsViewModel.groupedRecords.flatMap(\.records).count
            Button(allSelected ? L10n.Export.deselectAll : L10n.Export.selectAll) {
                if allSelected {
                    recordsViewModel.deselectAll()
                } else {
                    recordsViewModel.selectAll()
                }
            }
        }
    }

    // MARK: - Actions

    /// Filter changes — recalculate from cache, NO DB fetch
    private func recalculateData() {
        scheduleRecalculation(reload: false)
    }

    /// Data mutations (dataVersion, sheet dismiss) — reload DB + recalculate
    private func reloadAndRecalculate() {
        scheduleRecalculation(reload: true)
    }

    /// Debounced recalculation (150ms). `pendingReload` ensures a reload request isn't lost
    /// if a subsequent calculate-only call arrives within the debounce window.
    /// Background guard: skip scheduling while scenePhase is background/inactive — pendingReload
    /// is preserved so the next foreground reloadAndRecalculate picks it up. The
    /// `applicationState` check mirrors PanelView and prevents work during snapshot time.
    private func scheduleRecalculation(reload: Bool) {
        if reload { pendingReload = true }
        guard !isInBackground, UIApplication.shared.applicationState == .active else { return }
        recalculateTask?.cancel()
        recalculateTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            guard !Task.isCancelled else { return }
            if pendingReload {
                dataViewModel.loadData()
                pendingReload = false
            }
            performCalculation()
        }
    }

    /// Initial onAppear calculation. `setContext` already fetched if the context was new,
    /// so this only runs the synchronous calc pass. Subsequent reloads go through
    /// `reloadAndRecalculate` (dataVersion / scene foreground).
    private func performRecalculation() {
        performCalculation()
    }

    /// Runs all calculations from cached ViewModel data (no SwiftData fetch).
    private func performCalculation() {
        recalculation.run(
            StatisticsRecalculation.Inputs(
                transactions: dataViewModel.allTransactions,
                accounts: dataViewModel.accounts,
                categories: dataViewModel.categories,
                tags: dataViewModel.tags,
                budgets: dataViewModel.budgets,
                scheduledPayments: dataViewModel.scheduledPayments,
                period: sessionState.selectedPeriod,
                customRange: sessionState.customDateRange,
                comparisonMode: sessionState.comparisonMode,
                currencyCode: appPreferences.defaultCurrencyCode.rawValue,
                dataVersion: sessionState.dataVersion,
                includeGroupTransactionsInStats: appPreferences.includeGroupTransactionsInStats
            ),
            records: recordsViewModel,
            trends: trendsViewModel,
            insights: insightsViewModel,
            context: modelContext
        )
        LoadTimeMarks.ready(.statistics)
    }

    private func handleEditAction() {
        let flatTransactions = recordsViewModel.groupedRecords.flatMap { $0.records }
        let action = recordsViewModel.editSelectedRecords(transactions: flatTransactions)

        switch action {
        case .none:
            break
        case .single(let record):
            recordsViewModel.editingTransaction = record
            recordsViewModel.showEditTransaction = true
            recordsViewModel.exitSelectionMode()
        case .multiple:
            showBulkEditSheet = true
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DetailContainerView()
    }
    .environment(SceneNavigation())
    .previewAppPreferences()
}

// MARK: - View Helpers

// MARK: - ViewModifiers to break up expression complexity

/// Encapsulates sheet presentations to reduce body complexity
private struct DetailContainerSheets: ViewModifier {
    @Environment(AppPreferences.self) private var appPreferences
    @Bindable var recordsViewModel: RecordsViewModel
    @Bindable var trendsViewModel: StatisticsViewModel
    @Binding var showDeleteConfirmation: Bool
    @Binding var showBulkEditSheet: Bool
    @Binding var isPresentingSettings: Bool
    @Binding var showVoiceRecording: Bool
    @Binding var showImageSelection: Bool
    @Binding var showUpgradeForVoice: Bool
    @Binding var showUpgradeForImage: Bool
    @Binding var showChatSheet: Bool
    @Binding var showUpgradeForChat: Bool
    @Binding var showChatConsentAlert: Bool
    @Binding var showYalaAIOnboarding: Bool
    @Binding var pendingOpenChatAfterOnboarding: Bool
    /// Para pedir el consentimiento de datos al abrir voz o foto tras comprar Pro (UX 2.2 · L17-9).
    @Binding var showAIConsentAlert: Bool
    @Binding var pendingAIInput: PendingAIInput
    let modelContext: ModelContext
    let recalculateData: () -> Void
    let reloadAndRecalculate: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $recordsViewModel.showFiltersSheet) {
                RecordsFiltersView(recordsViewModel: recordsViewModel)
                    .onDisappear { recalculateData() }
            }
            .sheet(isPresented: $recordsViewModel.showNewTransaction) {
                NewTransactionView()
                    .presentationDetents([.large])
                    .onDisappear {
                        UITestHooks.shared.traceLifecycle("formulario fuera abierto=\(recordsViewModel.showNewTransaction)")
                        reloadAndRecalculate()
                    }
            }
            .sheet(isPresented: $showVoiceRecording) {
                VoiceRecordingView()
            }
            .sheet(isPresented: $showImageSelection) {
                ImageSelectionView()
            }
            // Si se compra Pro en la hoja, al cerrarse se abre lo que se quería (UX 2.2 · L17-9).
            .proUpgradeSheet(isPresented: $showUpgradeForVoice, feature: .voiceInput, context: .proFeature) {
                openAIEntryAfterUnlock(.voice)
            }
            .proUpgradeSheet(isPresented: $showUpgradeForImage, feature: .imageInput, context: .proFeature) {
                openAIEntryAfterUnlock(.image)
            }
            // Yala IA: columna al lado en ventana ancha, la hoja de siempre en compacta.
            .yalaAIChat(isPresented: $showChatSheet, insideNavigationStack: true)
            .yalaAIOnboardingSheet(
                isPresented: $showYalaAIOnboarding,
                pendingOpenChat: $pendingOpenChatAfterOnboarding,
                showChatSheet: $showChatSheet,
                launcher: .stats,
                onPersistFlag: { appPreferences.hasShownYalaAIOnboarding = true }
            )
            .proUpgradeSheet(isPresented: $showUpgradeForChat, feature: .chatAssistant, context: .proFeature) {
                openChatAfterUnlock()
            }
            .chatConsentAlert(isPresented: $showChatConsentAlert) {
                switch YalaAIOnboardingLogic.nextScreen(
                    consentAccepted: true,
                    onboardingShown: appPreferences.hasShownYalaAIOnboarding
                ) {
                case .onboarding: showYalaAIOnboarding = true
                case .chat:       showChatSheet = true
                case .consent:    break
                }
            }
            .sheet(isPresented: $recordsViewModel.showEditTransaction) {
                if let transaction = recordsViewModel.editingTransaction {
                    NewTransactionView(
                        transactionToEdit: transaction,
                        startsAsDuplicate: recordsViewModel.editorStartsAsDuplicate)
                        .presentationDetents([.large])
                        .onDisappear {
                            recordsViewModel.editingTransaction = nil
                            recordsViewModel.editorStartsAsDuplicate = false
                            reloadAndRecalculate()
                        }
                }
            }
            .sheet(
                isPresented: $recordsViewModel.showTransactionDetail,
                onDismiss: {
                    // Reemplazo de sheet: si se pidió editar, presenta el editor
                    // (conserva la TX); si no, cierre normal (limpia + recalcula).
                    if recordsViewModel.consumePendingEditAfterDetail() {
                        recordsViewModel.showEditTransaction = true
                    } else {
                        // Eliminar desde el detalle: con la hoja ya cerrada (L8-4).
                        _ = recordsViewModel.consumePendingDeleteAfterDetail(context: modelContext)
                        recordsViewModel.editingTransaction = nil
                        reloadAndRecalculate()
                    }
                }
            ) {
                if let transaction = recordsViewModel.editingTransaction {
                    TransactionDetailSheet(
                        transaction: transaction,
                        onEdit: { recordsViewModel.requestEditFromDetail() },
                        onDuplicate: { recordsViewModel.requestDuplicateFromDetail() },
                        onDelete: { recordsViewModel.requestDeleteFromDetail(
                            transaction,
                            undoName: RecordDeleteConfirmationText.undoName(for: transaction, preferences: appPreferences)) },
                        deleteIsUndoable: true
                    )
                }
            }
            .sheet(isPresented: $trendsViewModel.showFiltersSheet) {
                RecordsFiltersView(recordsViewModel: recordsViewModel)
                    .onDisappear { recalculateData() }
            }
            // Alerta centrada y con el registro nombrado, como el resto de borrados (L8-7).
            .modifier(RecordsBulkDeleteAlert(
                isPresented: $showDeleteConfirmation,
                viewModel: recordsViewModel
            ) {
                recordsViewModel.deleteSelected(context: modelContext)
                reloadAndRecalculate()
            })
            .sheet(isPresented: $showBulkEditSheet) {
                BulkEditSheet(
                    viewModel: recordsViewModel,
                    selectedCount: recordsViewModel.selectedRecordIDs.count,
                    onComplete: reloadAndRecalculate
                )
            }
            .sheet(isPresented: $isPresentingSettings) {
                ProfileView()
            }
    }
}

/// Encapsulates onChange observers to reduce body complexity
private struct DetailContainerObservers: ViewModifier {
    let sessionState: SessionState
    @Bindable var trendsViewModel: StatisticsViewModel
    @Bindable var recordsViewModel: RecordsViewModel
    let categories: [Category]
    let subcategories: [Subcategory]
    let recalculateData: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(SessionStateObservers(
                sessionState: sessionState,
                categories: categories,
                subcategories: subcategories,
                recalculateData: recalculateData
            ))
            // isAggregatedView is local to StatisticsViewModel (not a SessionState proxy)
            .onChange(of: trendsViewModel.isAggregatedView) { _, _ in recalculateData() }
            // "Identificar duplicados": recompute al togglear modo/criterios.
            .onChange(of: recordsViewModel.duplicateModeActive) { _, _ in
                recalculateData()
            }
            .onChange(of: recordsViewModel.duplicateCriteria) { _, _ in
                recalculateData()
            }
    }
}

/// SessionState onChange observers — split to reduce type-checker complexity.
private struct SessionStateObservers: ViewModifier {
    let sessionState: SessionState
    let categories: [Category]
    let subcategories: [Subcategory]
    let recalculateData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedPeriod) { recalculateData() }
            .onChange(of: sessionState.selectedAccountIDs) { recalculateData() }
            .onChange(of: sessionState.selectedCategoryIDs) {
                if !sessionState.selectedCategoryIDs.isEmpty {
                    let selectedCats = categories.filter {
                        sessionState.selectedCategoryIDs.contains($0.persistentModelID)
                    }
                    if !selectedCats.isEmpty && selectedCats.allSatisfy({ !$0.isIncome }) {
                        sessionState.selectedTransactionNatures = [.expense]
                    }
                }
                recalculateData()
            }
            .onChange(of: sessionState.selectedNeeds) {
                if !sessionState.selectedNeeds.isEmpty {
                    sessionState.selectedTransactionNatures = [.expense]
                }
                recalculateData()
            }
            .onChange(of: sessionState.selectedSubcategoryIDs) {
                if !sessionState.selectedSubcategoryIDs.isEmpty {
                    let selectedSubs = subcategories.filter {
                        sessionState.selectedSubcategoryIDs.contains($0.persistentModelID)
                    }
                    if !selectedSubs.isEmpty && selectedSubs.allSatisfy({ !$0.safeCategory.isIncome }) {
                        sessionState.selectedTransactionNatures = [.expense]
                    }
                }
                recalculateData()
            }
            .onChange(of: sessionState.selectedTags) { recalculateData() }
            .onChange(of: sessionState.selectedCurrencies) { recalculateData() }
            .onChange(of: sessionState.selectedTransactionNatures) { recalculateData() }
            .onChange(of: sessionState.amountCondition) { recalculateData() }
            .onChange(of: sessionState.searchText) { recalculateData() }
            .onChange(of: sessionState.excludedFilterSets) { recalculateData() }
            .onChange(of: sessionState.selectedTrendMetric) { recalculateData() }
            .onChange(of: sessionState.customDateRange) { recalculateData() }
    }
}

/// El panel del registro abierto en Estadísticas › Registros (ventana ancha): qué abre un toque, qué pasa al
/// estrechar con uno abierto y cuándo se cierra. En un modificador aparte por lo mismo que los otros observadores de
/// esta vista: el compilador de CI no tipa a tiempo una cadena larga de `onChange` con cierres.
private struct StatsRecordsPaneObservers: ViewModifier {
    let recordsViewModel: RecordsViewModel
    let horizontalSizeClass: UserInterfaceSizeClass?
    /// El chip Registros está a la vista. Con otro chip delante, estrechar cierra lo abierto sin sacar una hoja
    /// encima del Resumen o de Tendencias.
    let recordsTabIsShown: Bool
    let allTransactions: [TransactionItem]

    func body(content: Content) -> some View {
        content
            .onChange(of: horizontalSizeClass, initial: true) { _, newClass in sizeClassChanged(newClass) }
            .onChange(of: allTransactions) { closeIfTheRecordIsGone() }
    }

    /// En ancha el toque abre el panel; en compacta, la hoja. Si la ventana se estrecha con un registro abierto en
    /// el panel, pasa a la hoja: el mismo registro sigue a la vista.
    private func sizeClassChanged(_ newClass: UserInterfaceSizeClass?) {
        recordsViewModel.opensDetailInColumn = newClass == .regular
        guard newClass != .regular, let id = recordsViewModel.openRecordID else { return }
        recordsViewModel.openRecordID = nil
        guard recordsTabIsShown,
              let record = allTransactions.first(where: { $0.persistentModelID == id }) else { return }
        recordsViewModel.editingTransaction = record
        recordsViewModel.showTransactionDetail = true
    }

    /// Registro abierto que ya no existe (borrado desde el editor u otro dispositivo): el panel vuelve al vacío.
    private func closeIfTheRecordIsGone() {
        guard let id = recordsViewModel.openRecordID else { return }
        guard !allTransactions.contains(where: { $0.persistentModelID == id }) else { return }
        #if DEBUG
        print("DetailContainerView: el registro abierto ya no está, se cierra el panel")
        #endif
        recordsViewModel.openRecordID = nil
    }
}

// MARK: - Tras comprar Pro (UX 2.2 · L17-9)

extension DetailContainerSheets {
    /// El mismo camino que tocar Voz o Foto siendo Pro, con su consentimiento de datos si aún no se dio.
    fileprivate func openAIEntryAfterUnlock(_ input: PendingAIInput) {
        guard appPreferences.aiDataConsentAccepted else {
            pendingAIInput = input
            showAIConsentAlert = true
            return
        }
        switch input {
        case .voice: showVoiceRecording = true
        case .image: showImageSelection = true
        }
    }

    /// El mismo camino que tocar Yala IA siendo Pro.
    fileprivate func openChatAfterUnlock() {
        switch YalaAIOnboardingLogic.nextScreen(
            consentAccepted: appPreferences.aiChatConsentAccepted,
            onboardingShown: appPreferences.hasShownYalaAIOnboarding
        ) {
        case .onboarding: showYalaAIOnboarding = true
        case .chat: showChatSheet = true
        case .consent: showChatConsentAlert = true
        }
    }
}
