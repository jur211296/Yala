//
//  RecordsStandaloneView.swift
//  Yala
//
//  Standalone Records view accessible from "More" tab.
//  Provides full Records functionality with FAB, selection mode, and filter sync.
//

import SwiftData
import SwiftUI

// MARK: - Records Standalone View

/// Standalone view for Records, accessible from "More" tab or as a promoted main tab.
/// Mirrors DetailContainerView functionality but only shows Records content.
struct RecordsStandaloneView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    // MARK: - ViewModels

    @State private var dataViewModel = DetailContainerViewModel()
    @State private var recordsViewModel = RecordsViewModel()

    // MARK: - UI State

    @State private var showDeleteConfirmation = false
    @State private var showBulkEditSheet = false
    @State private var isPresentingSettings = false
    @State private var recalculateTask: Task<Void, Never>?
    @State private var pendingReload = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var isInBackground = false

    // MARK: - FAB State

    @State private var showVoiceRecording = false
    @State private var showImageSelection = false
    @State private var showUpgradeForVoice = false
    @State private var showUpgradeForImage = false

    // MARK: - Chat Assistant
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

    @State private var showAIConsentAlert = false
    @State private var pendingAIInput: PendingAIInput = .voice

    /// Check if voice input can be used (requires accounts and subcategories)
    private var canUseVoiceInput: Bool {
        dataViewModel.canUseVoiceInput
    }

    // MARK: - Body

    var body: some View {
        mainContent
            .modifier(RecordsStandaloneSheets(
                recordsViewModel: recordsViewModel,
                showDeleteConfirmation: $showDeleteConfirmation,
                showBulkEditSheet: $showBulkEditSheet,
                showVoiceRecording: $showVoiceRecording,
                showImageSelection: $showImageSelection,
                showUpgradeForVoice: $showUpgradeForVoice,
                showUpgradeForImage: $showUpgradeForImage,
                showChatSheet: $showChatSheet,
                showUpgradeForChat: $showUpgradeForChat,
                showChatConsentAlert: $showChatConsentAlert,
                showYalaAIOnboarding: $showYalaAIOnboarding,
                pendingOpenChatAfterOnboarding: $pendingOpenChatAfterOnboarding,
                isPresentingSettings: $isPresentingSettings,
                modelContext: modelContext,
                recalculateData: recalculateData,
                reloadAndRecalculate: reloadAndRecalculate
            ))
            .modifier(RecordsStandaloneObservers(
                sessionState: sessionState,
                dataViewModel: dataViewModel,
                recalculateData: recalculateData
            ))
            .appliesPendingRemoteChanges(sessionState)
            .onAppear {
                dataViewModel.setContext(modelContext)
                performRecalculation()
            }
            .onDisappear { recalculateTask?.cancel() }
            .onChange(of: sessionState.dataVersion) { _, _ in
                reloadAndRecalculate()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background, .inactive:
                    isInBackground = true
                    recalculateTask?.cancel()
                case .active:
                    guard UIApplication.shared.applicationState == .active else { return }
                    guard isInBackground else { return }
                    isInBackground = false
                    reloadAndRecalculate()
                @unknown default:
                    break
                }
            }
            .aiConsentAlert(isPresented: $showAIConsentAlert, pendingInput: $pendingAIInput) { input in
                switch input {
                case .voice: showVoiceRecording = true
                case .image: showImageSelection = true
                }
            }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

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

                // FAB (only when not in selection mode)
                if !recordsViewModel.isSelectionMode {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            FABStackView(
                                canUseVoiceInput: canUseVoiceInput,
                                isVoiceLocked: isVoiceLocked,
                                isImageLocked: isImageLocked,
                                isChatLocked: !FeatureGateService.shared.canAccess(.chatAssistant),
                                chatConsentAccepted: appPreferences.aiChatConsentAccepted,
                                chatFABVisible: appPreferences.chatFABVisible,
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
                                onUpgradeChat: { showUpgradeForChat = true },
                                onChatConsentNeeded: { showChatConsentAlert = true }
                            )
                        }
                    }
                }

                // Selection action bar (with animation)
                if recordsViewModel.isSelectionMode && !recordsViewModel.selectedRecordIDs.isEmpty {
                    selectionActionBar
                }
            }
            .animation(.spring(response: DS.Animation.springResponse, dampingFraction: DS.Animation.springDamping), value: recordsViewModel.isSelectionMode)
            .animation(.spring(response: DS.Animation.springResponse, dampingFraction: DS.Animation.springDamping), value: recordsViewModel.selectedRecordIDs.isEmpty)
            .navigationTitle(L10n.Records.title)
            .toolbar {
                if recordsViewModel.isSelectionMode {
                    selectionModeToolbar
                } else {
                    normalModeToolbar
                }
            }
            .navigationBarBackButtonHidden(recordsViewModel.isSelectionMode)
        }
    }

    // MARK: - Normal Mode Toolbar

    @ToolbarContentBuilder
    private var normalModeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: DS.Spacing.md) {
                // Selection button
                Button {
                    recordsViewModel.enterSelectionMode()
                } label: {
                    Image(systemName: "checklist")
                        .font(DS.Typography.body.weight(.medium))
                        .foregroundStyle(.thToolbarIcon)
                }
                .accessibilityLabel(L10n.Action.select)

                // Filters button
                Button {
                    recordsViewModel.showFiltersSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(DS.Typography.body.weight(.medium))
                        .foregroundStyle(.thToolbarIcon)
                }
                .accessibilityLabel(L10n.Filters.title)
                .overlay(alignment: .topTrailing) {
                    if recordsViewModel.activeFilterCount > 0 {
                        Circle()
                            .fill(Color.hotPink)
                            .frame(width: DS.Chip.dotSize, height: DS.Chip.dotSize)
                            .offset(x: 2, y: -2)
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

    // MARK: - New Record FAB

    @ViewBuilder

    // MARK: - Selection Action Bar

    private var selectionActionBar: some View {
        VStack {
            Spacer()

            HStack(spacing: DS.Spacing.xl) {
                // Delete button
                Button(role: .destructive) {
                    DS.Haptic.warning()
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(DS.Typography.title)
                        .foregroundStyle(DS.Semantic.errorForeground)
                        .frame(width: DS.Button.actionSize, height: DS.Button.actionSize)
                }
                .accessibilityLabel(L10n.Action.delete)
                .buttonStyle(.plain)

                Spacer()

                // Selection count
                Text("\(recordsViewModel.selectedRecordIDs.count) \(L10n.Common.selected)")
                    .font(DS.Typography.headline)
                    .contentTransition(.numericText())

                Spacer()

                // Edit button
                Button {
                    DS.Haptic.selection()
                    handleEditAction()
                } label: {
                    Image(systemName: "pencil")
                        .font(DS.Typography.title)
                        .foregroundStyle(theme.accent)
                        .frame(width: DS.Button.actionSize, height: DS.Button.actionSize)
                }
                .accessibilityLabel(L10n.Action.edit)
                .buttonStyle(.plain)
            }
            .padding(.vertical, DS.Spacing.sm)
            .padding(.horizontal, DS.Spacing.lg)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
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

    private func scheduleRecalculation(reload: Bool) {
        if reload { pendingReload = true }
        guard !isInBackground else { return }
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

    private func performCalculation() {
        recordsViewModel.applyFilters(
            transactions: dataViewModel.allTransactions,
            accounts: dataViewModel.accounts,
            categories: dataViewModel.categories,
            tags: dataViewModel.tags
        )
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

// MARK: - Sheets Modifier

private struct RecordsStandaloneSheets: ViewModifier {
    @Environment(AppPreferences.self) private var appPreferences
    @Bindable var recordsViewModel: RecordsViewModel
    @Binding var showDeleteConfirmation: Bool
    @Binding var showBulkEditSheet: Bool
    @Binding var showVoiceRecording: Bool
    @Binding var showImageSelection: Bool
    @Binding var showUpgradeForVoice: Bool
    @Binding var showUpgradeForImage: Bool
    @Binding var showChatSheet: Bool
    @Binding var showUpgradeForChat: Bool
    @Binding var showChatConsentAlert: Bool
    @Binding var showYalaAIOnboarding: Bool
    @Binding var pendingOpenChatAfterOnboarding: Bool
    @Binding var isPresentingSettings: Bool
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
                    .onDisappear { reloadAndRecalculate() }
            }
            .sheet(isPresented: $showVoiceRecording) {
                VoiceRecordingView()
            }
            .sheet(isPresented: $showImageSelection) {
                ImageSelectionView()
            }
            .sheet(isPresented: $showUpgradeForVoice) {
                UpgradePromptSheet(feature: .voiceInput, context: .proFeature)
            }
            .sheet(isPresented: $showUpgradeForImage) {
                UpgradePromptSheet(feature: .imageInput, context: .proFeature)
            }
            .sheet(isPresented: $showChatSheet) {
                ChatSheetView()
            }
            .yalaAIOnboardingSheet(
                isPresented: $showYalaAIOnboarding,
                pendingOpenChat: $pendingOpenChatAfterOnboarding,
                showChatSheet: $showChatSheet,
                launcher: .records,
                onPersistFlag: { appPreferences.hasShownYalaAIOnboarding = true }
            )
            .sheet(isPresented: $showUpgradeForChat) {
                UpgradePromptSheet(feature: .chatAssistant, context: .proFeature)
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
                    NewTransactionView(transactionToEdit: transaction)
                        .presentationDetents([.large])
                        .onDisappear {
                            recordsViewModel.editingTransaction = nil
                            reloadAndRecalculate()
                        }
                }
            }
            .confirmationDialog(
                L10n.Records.deleteConfirmTitle(recordsViewModel.selectedRecordIDs.count),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.Action.delete, role: .destructive) {
                    recordsViewModel.deleteSelected(context: modelContext)
                    reloadAndRecalculate()
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Common.cannotUndo)
            }
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

// MARK: - Observers Modifiers

/// Session state navigation observer
private struct RecordsNavObserver: ViewModifier {
    let sessionState: SessionState
    let recalculateData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedMainTab) { _, newTab in
                if newTab == .records { recalculateData() }
            }
    }
}

/// Session state filter observers - Part 1a
private struct RecordsSessionObservers1a: ViewModifier {
    let sessionState: SessionState
    let recalculateData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedAccountIDs) { _, _ in recalculateData() }
            .onChange(of: sessionState.selectedCategoryIDs) { _, _ in recalculateData() }
            .onChange(of: sessionState.selectedSubcategoryIDs) { _, _ in recalculateData() }
    }
}

/// Session state filter observers - Part 1b
private struct RecordsSessionObservers1b: ViewModifier {
    let sessionState: SessionState
    let recalculateData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedTags) { _, _ in recalculateData() }
            .onChange(of: sessionState.selectedPeriod) { _, _ in recalculateData() }
    }
}

/// Session state filter observers - Part 2a
private struct RecordsSessionObservers2a: ViewModifier {
    let sessionState: SessionState
    let recalculateData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedNeeds) { _, _ in recalculateData() }
            .onChange(of: sessionState.selectedTransactionNatures) { _, _ in recalculateData() }
            .onChange(of: sessionState.selectedCurrencies) { _, _ in recalculateData() }
    }
}

/// Session state filter observers - Part 2b
private struct RecordsSessionObservers2b: ViewModifier {
    let sessionState: SessionState
    let dataViewModel: DetailContainerViewModel
    let recalculateData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.amountCondition) { _, _ in recalculateData() }
            .onChange(of: sessionState.searchText) { _, _ in recalculateData() }
            .onChange(of: sessionState.isExcludeMode) { _, _ in recalculateData() }
            .onChange(of: sessionState.customDateRange) { _, _ in recalculateData() }
            .onChange(of: dataViewModel.allTransactions) { recalculateData() }
    }
}

/// Combined observers modifier - Part 1
private struct RecordsStandaloneObservers1: ViewModifier {
    let sessionState: SessionState
    let recalculateData: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(RecordsNavObserver(
                sessionState: sessionState,
                recalculateData: recalculateData
            ))
            .modifier(RecordsSessionObservers1a(
                sessionState: sessionState,
                recalculateData: recalculateData
            ))
            .modifier(RecordsSessionObservers1b(
                sessionState: sessionState,
                recalculateData: recalculateData
            ))
    }
}

/// Combined observers modifier - Part 2
private struct RecordsStandaloneObservers2: ViewModifier {
    let sessionState: SessionState
    let dataViewModel: DetailContainerViewModel
    let recalculateData: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(RecordsSessionObservers2a(
                sessionState: sessionState,
                recalculateData: recalculateData
            ))
            .modifier(RecordsSessionObservers2b(
                sessionState: sessionState,
                dataViewModel: dataViewModel,
                recalculateData: recalculateData
            ))
    }
}

/// Main combined observers modifier
private struct RecordsStandaloneObservers: ViewModifier {
    let sessionState: SessionState
    let dataViewModel: DetailContainerViewModel
    let recalculateData: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(RecordsStandaloneObservers1(
                sessionState: sessionState,
                recalculateData: recalculateData
            ))
            .modifier(RecordsStandaloneObservers2(
                sessionState: sessionState,
                dataViewModel: dataViewModel,
                recalculateData: recalculateData
            ))
    }
}

// MARK: - Preview

#Preview {
    RecordsStandaloneView()
        .environment(SessionState.shared)
}
