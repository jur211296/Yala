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
                refreshRecordsData: refreshRecordsData
            ))
            .modifier(RecordsStandaloneObservers(
                sessionState: sessionState,
                recordsViewModel: recordsViewModel,
                dataViewModel: dataViewModel,
                showFABMenu: $showFABMenu,
                refreshRecordsData: refreshRecordsData
            ))
            .onAppear {
                dataViewModel.setContext(modelContext)
                refreshRecordsData()
            }
            .onChange(of: sessionState.dataVersion) { _, _ in
                refreshRecordsData()
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
                    onFilterChange: { refreshRecordsData() }
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
        let hasMultipleInputs = voiceInputEnabled || imageInputEnabled

        if hasMultipleInputs && canUseVoiceInput {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    // Custom FAB with popup menu above
                    VStack(alignment: .trailing, spacing: DS.Spacing.md) {
                        // Menu options (shown when expanded)
                        if showFABMenu {
                            VStack(spacing: DS.Spacing.sm) {
                                // Voice option (if enabled)
                                if voiceInputEnabled {
                                    fabMenuButton(
                                        icon: "waveform",
                                        text: L10n.Panel.fabVoice,
                                        color: .hotPink,
                                        isLocked: isVoiceLocked
                                    ) {
                                        dsWithAnimation(reduceMotion) {
                                            showFABMenu = false
                                        }
                                        if isVoiceLocked {
                                            showUpgradeForVoice = true
                                        } else {
                                            showVoiceRecording = true
                                        }
                                    }
                                }

                                // Image option (if enabled)
                                if imageInputEnabled {
                                    fabMenuButton(
                                        icon: "photo",
                                        text: L10n.Panel.fabImage,
                                        color: .teal,
                                        isLocked: isImageLocked
                                    ) {
                                        dsWithAnimation(reduceMotion) {
                                            showFABMenu = false
                                        }
                                        if isImageLocked {
                                            showUpgradeForImage = true
                                        } else {
                                            showImageSelection = true
                                        }
                                    }
                                }

                                // Manual option (always shown)
                                fabMenuButton(
                                    icon: "square.and.pencil",
                                    text: L10n.Panel.fabManual,
                                    color: .electricIndigo
                                ) {
                                    dsWithAnimation(reduceMotion) {
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
                            dsWithAnimation(reduceMotion) {
                                showFABMenu.toggle()
                            }
                        } label: {
                            Image(systemName: showFABMenu ? "xmark" : "plus")
                                .font(DS.Typography.title.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                                .background(showFABMenu ? DS.Semantic.disabledForeground : fabBackground)
                                .clipShape(Circle())
                                .rotationEffect(.degrees(showFABMenu ? 90 : 0))
                        }
                        .buttonStyle(.plain)
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
                    // Simple FAB (no special inputs enabled)
                    Button {
                        if canUseVoiceInput {
                            recordsViewModel.showNewTransaction = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(DS.Typography.title.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                            .background(fabBackground)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive())
                    .dsFloatingShadow()
                    .padding(.trailing, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.xxl)
                    .disabled(!canUseVoiceInput)
                    .accessibilityHint(!canUseVoiceInput ? "Crea al menos una cuenta y una categoría" : "")
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
                    .font(DS.Typography.body.weight(.semibold))
                    .frame(width: DS.Button.fabMenuIconSize)

                Text(text)
                    .font(DS.Typography.headline)

                if isLocked {
                    ProBadge(size: .small)
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .frame(width: DS.Button.fabMenuWidth)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(isLocked ? Color.gray : color)
            .clipShape(Capsule())
            .shadow(color: (isLocked ? Color.gray : color).opacity(0.3), radius: 8, x: 0, y: 4)
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
                        .foregroundStyle(.red)
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

    private func refreshRecordsData() {
        dataViewModel.loadData()
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
    let refreshRecordsData: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $recordsViewModel.showFiltersSheet) {
                RecordsFiltersView(recordsViewModel: recordsViewModel)
                    .onDisappear { refreshRecordsData() }
            }
            .sheet(isPresented: $recordsViewModel.showNewTransaction) {
                NewTransactionView()
                    .onDisappear { refreshRecordsData() }
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
                        .onDisappear {
                            recordsViewModel.editingTransaction = nil
                            refreshRecordsData()
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
                    refreshRecordsData()
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Common.cannotUndo)
            }
            .sheet(isPresented: $showBulkEditSheet) {
                BulkEditSheet(
                    viewModel: recordsViewModel,
                    selectedCount: recordsViewModel.selectedRecordIDs.count,
                    onComplete: refreshRecordsData
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
    let refreshRecordsData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedMainTab) { _, newTab in
                if showFABMenu { showFABMenu = false }
                if newTab == .records { refreshRecordsData() }
            }
    }
}

/// Session state filter observers - Part 1a
private struct RecordsSessionObservers1a: ViewModifier {
    let sessionState: SessionState
    let refreshRecordsData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedAccountIDs) { _, _ in refreshRecordsData() }
            .onChange(of: sessionState.selectedCategoryIDs) { _, _ in refreshRecordsData() }
            .onChange(of: sessionState.selectedSubcategoryIDs) { _, _ in refreshRecordsData() }
    }
}

/// Session state filter observers - Part 1b
private struct RecordsSessionObservers1b: ViewModifier {
    let sessionState: SessionState
    let refreshRecordsData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedTags) { _, _ in refreshRecordsData() }
            .onChange(of: sessionState.selectedPeriod) { _, _ in refreshRecordsData() }
    }
}

/// Session state filter observers - Part 2a
private struct RecordsSessionObservers2a: ViewModifier {
    let sessionState: SessionState
    let refreshRecordsData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedNatures) { _, _ in refreshRecordsData() }
            .onChange(of: sessionState.selectedTransactionNatures) { _, _ in refreshRecordsData() }
            .onChange(of: sessionState.selectedCurrencies) { _, _ in refreshRecordsData() }
    }
}

/// Session state filter observers - Part 2b
private struct RecordsSessionObservers2b: ViewModifier {
    let sessionState: SessionState
    let dataViewModel: DetailContainerViewModel
    let refreshRecordsData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.amountCondition) { _, _ in refreshRecordsData() }
            .onChange(of: sessionState.searchText) { _, _ in refreshRecordsData() }
            .onChange(of: sessionState.customDateRange) { _, _ in refreshRecordsData() }
            .onChange(of: dataViewModel.allTransactions) { refreshRecordsData() }
    }
}

/// ViewModel filter observers - Part 1
private struct RecordsViewModelObservers1: ViewModifier {
    @Bindable var recordsViewModel: RecordsViewModel
    let refreshRecordsData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: recordsViewModel.period) { _, _ in refreshRecordsData() }
            .onChange(of: recordsViewModel.selectedAccounts) { _, _ in refreshRecordsData() }
            .onChange(of: recordsViewModel.selectedCategories) { _, _ in refreshRecordsData() }
            .onChange(of: recordsViewModel.selectedSubcategories) { _, _ in refreshRecordsData() }
            .onChange(of: recordsViewModel.selectedTags) { _, _ in refreshRecordsData() }
    }
}

/// ViewModel filter observers - Part 2
private struct RecordsViewModelObservers2: ViewModifier {
    @Bindable var recordsViewModel: RecordsViewModel
    let refreshRecordsData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: recordsViewModel.selectedNatures) { _, _ in refreshRecordsData() }
            .onChange(of: recordsViewModel.selectedTransactionNatures) { _, _ in refreshRecordsData() }
            .onChange(of: recordsViewModel.selectedCurrencies) { _, _ in refreshRecordsData() }
            .onChange(of: recordsViewModel.amountCondition) { _, _ in refreshRecordsData() }
            .onChange(of: recordsViewModel.searchText) { _, _ in refreshRecordsData() }
    }
}

/// Combined observers modifier - Part 1
private struct RecordsStandaloneObservers1: ViewModifier {
    let sessionState: SessionState
    @Binding var showFABMenu: Bool
    let refreshRecordsData: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(RecordsNavObserver(
                sessionState: sessionState,
                showFABMenu: $showFABMenu,
                refreshRecordsData: refreshRecordsData
            ))
            .modifier(RecordsSessionObservers1a(
                sessionState: sessionState,
                refreshRecordsData: refreshRecordsData
            ))
            .modifier(RecordsSessionObservers1b(
                sessionState: sessionState,
                refreshRecordsData: refreshRecordsData
            ))
    }
}

/// Combined observers modifier - Part 2
private struct RecordsStandaloneObservers2: ViewModifier {
    let sessionState: SessionState
    let dataViewModel: DetailContainerViewModel
    let refreshRecordsData: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(RecordsSessionObservers2a(
                sessionState: sessionState,
                refreshRecordsData: refreshRecordsData
            ))
            .modifier(RecordsSessionObservers2b(
                sessionState: sessionState,
                dataViewModel: dataViewModel,
                refreshRecordsData: refreshRecordsData
            ))
    }
}

/// Combined observers modifier - Part 3 (ViewModel)
private struct RecordsStandaloneObservers3: ViewModifier {
    @Bindable var recordsViewModel: RecordsViewModel
    let refreshRecordsData: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(RecordsViewModelObservers1(
                recordsViewModel: recordsViewModel,
                refreshRecordsData: refreshRecordsData
            ))
            .modifier(RecordsViewModelObservers2(
                recordsViewModel: recordsViewModel,
                refreshRecordsData: refreshRecordsData
            ))
    }
}

/// Main combined observers modifier
private struct RecordsStandaloneObservers: ViewModifier {
    let sessionState: SessionState
    @Bindable var recordsViewModel: RecordsViewModel
    let dataViewModel: DetailContainerViewModel
    @Binding var showFABMenu: Bool
    let refreshRecordsData: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(RecordsStandaloneObservers1(
                sessionState: sessionState,
                showFABMenu: $showFABMenu,
                refreshRecordsData: refreshRecordsData
            ))
            .modifier(RecordsStandaloneObservers2(
                sessionState: sessionState,
                dataViewModel: dataViewModel,
                refreshRecordsData: refreshRecordsData
            ))
            .modifier(RecordsStandaloneObservers3(
                recordsViewModel: recordsViewModel,
                refreshRecordsData: refreshRecordsData
            ))
    }
}

// MARK: - Preview

#Preview {
    RecordsStandaloneView()
        .environment(SessionState.shared)
}
