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

    // MARK: - ViewModels

    @State private var dataViewModel = DetailContainerViewModel()
    @State private var recordsViewModel = RecordsViewModel()

    // MARK: - UI State

    @State private var showDeleteConfirmation = false
    @State private var showBulkEditSheet = false
    @State private var isPresentingSettings = false
    @State private var recalculateTask: Task<Void, Never>?
    @State private var pendingReload = false

    // MARK: - FAB State

    @State private var showFABMenu = false
    @State private var showVoiceRecording = false
    @State private var showImageSelection = false
    @State private var showUpgradeForVoice = false
    @State private var showUpgradeForImage = false

    // MARK: - Pro Feature Gates

    private var isVoiceLocked: Bool {
        !FeatureGateService.shared.canAccess(.voiceInput)
    }

    private var isImageLocked: Bool {
        !FeatureGateService.shared.canAccess(.imageInput)
    }

    // MARK: - AppStorage

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.pen.rawValue
    @AppStorage("voiceInputEnabled") private var voiceInputEnabled: Bool = false
    @AppStorage("imageInputEnabled") private var imageInputEnabled: Bool = false
    @AppStorage("aiDataConsentAccepted") private var aiDataConsentAccepted: Bool = false
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
                isPresentingSettings: $isPresentingSettings,
                modelContext: modelContext,
                recalculateData: recalculateData,
                reloadAndRecalculate: reloadAndRecalculate
            ))
            .modifier(RecordsStandaloneObservers(
                sessionState: sessionState,
                dataViewModel: dataViewModel,
                showFABMenu: $showFABMenu,
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
                    defaultCurrencyCode: defaultCurrencyCode,
                    onFilterChange: { recalculateData() }
                )

                // FAB (only when not in selection mode)
                if !recordsViewModel.isSelectionMode {
                    newRecordFAB
                }

                // Selection action bar (with animation)
                if recordsViewModel.isSelectionMode && !recordsViewModel.selectedRecordIDs.isEmpty {
                    selectionActionBar
                }
            }
            .animation(.spring(response: DS.Animation.springResponse, dampingFraction: DS.Animation.springDamping), value: recordsViewModel.isSelectionMode)
            .animation(.spring(response: DS.Animation.springResponse, dampingFraction: DS.Animation.springDamping), value: recordsViewModel.selectedRecordIDs.isEmpty)
            .navigationTitle(L10n.Tab.records)
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
                            .frame(width: 8, height: 8)
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
    private var newRecordFAB: some View {
        let fabBackground = canUseVoiceInput ? theme.accent : DS.Semantic.disabledForeground.opacity(0.5)

        if canUseVoiceInput {
            VStack {
                Spacer()
                HStack {
                    Spacer()
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
                                        showUpgradeForVoice = true
                                    } else if !aiDataConsentAccepted {
                                        pendingAIInput = .voice
                                        showAIConsentAlert = true
                                    } else {
                                        if !voiceInputEnabled { voiceInputEnabled = true }
                                        showVoiceRecording = true
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
                                        showUpgradeForImage = true
                                    } else if !aiDataConsentAccepted {
                                        pendingAIInput = .image
                                        showAIConsentAlert = true
                                    } else {
                                        if !imageInputEnabled { imageInputEnabled = true }
                                        showImageSelection = true
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
                                    recordsViewModel.showNewTransaction = true
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
                                .foregroundStyle(.white)
                                .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                                .background(showFABMenu ? DS.Semantic.disabledForeground : fabBackground)
                                .clipShape(Circle())
                                .rotationEffect(.degrees(showFABMenu ? 90 : 0))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(showFABMenu ? L10n.Accessibility.closeMenu : L10n.Accessibility.newRecord)
                        .glassEffect(.regular.interactive())
                        .dsFloatingShadow()
                    }
                    .padding(.trailing, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.xxl)
                }
            }
        } else {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    // Simple FAB (no accounts/subcategories — disabled)
                    Button {
                        // No-op: disabled state
                    } label: {
                        Image(systemName: "plus")
                            .font(DS.Typography.title)
                            .foregroundStyle(.white)
                            .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                            .background(fabBackground)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Accessibility.newRecord)
                    .glassEffect(.regular.interactive())
                    .dsFloatingShadow()
                    .padding(.trailing, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.xxl)
                    .disabled(true)
                    .accessibilityHint(L10n.Accessibility.createAccountFirst)
                }
            }
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

    /// Synchronous full reload — used only for the initial onAppear.
    private func performRecalculation() {
        dataViewModel.loadData()
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
    @Bindable var recordsViewModel: RecordsViewModel
    @Binding var showDeleteConfirmation: Bool
    @Binding var showBulkEditSheet: Bool
    @Binding var showVoiceRecording: Bool
    @Binding var showImageSelection: Bool
    @Binding var showUpgradeForVoice: Bool
    @Binding var showUpgradeForImage: Bool
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
    @Binding var showFABMenu: Bool
    let recalculateData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedMainTab) { _, newTab in
                if showFABMenu { showFABMenu = false }
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
    @Binding var showFABMenu: Bool
    let recalculateData: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(RecordsNavObserver(
                sessionState: sessionState,
                showFABMenu: $showFABMenu,
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
    @Binding var showFABMenu: Bool
    let recalculateData: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(RecordsStandaloneObservers1(
                sessionState: sessionState,
                showFABMenu: $showFABMenu,
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
