//
//  GroupsContainerView.swift
//  Yala
//
//  Vista principal del tab Grupos — lista de grupos compartidos.
//

import SwiftUI
import SwiftData

struct GroupsContainerView: View {

    // MARK: - Environment

    @Environment(SessionState.self) private var sessionState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(\.openURL) private var openURL

    // MARK: - State

    @State private var viewModel = GroupsViewModel()
    @State private var isPresentingSettings = false
    @Environment(AppPreferences.self) private var appPreferences
    @State private var showNotificationPrompt = false
    @State private var showPermissionDeniedAlert = false
    @State private var showNudgeBanner = false
    @State private var showGroupsOnboarding = false
    /// Drives el alert "¿Salir del grupo?" cuando un current user `.rejected`
    /// toca su card. Single-modal global vs N alerts montados por card.
    @State private var rejectedGroupPendingLeave: SplitGroup?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                if viewModel.activeGroups.isEmpty && viewModel.archivedGroups.isEmpty {
                    YalaEmptyState.noGroups {
                        viewModel.showCreateGroup = true
                    }
                } else if viewModel.activeGroups.isEmpty {
                    // Only archived groups exist
                    VStack(spacing: DS.Spacing.xl) {
                        YalaEmptyState.noGroups {
                            viewModel.showCreateGroup = true
                        }
                        archivedGroupsSection
                            .padding(.horizontal, DS.Spacing.lg)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: DS.Spacing.lg) {
                            // Global summary
                            if let summary = viewModel.globalSummary {
                                GroupSummaryHeader(summary: summary)
                            }

                            // Nudge banner
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

                            // Group cards
                            ForEach(viewModel.filteredGroups, id: \.id) { group in
                                groupCardRow(group: group)
                            }

                            // Archived groups
                            if !viewModel.archivedGroups.isEmpty {
                                archivedGroupsSection
                            }
                        }
                        .padding(.top, DS.Spacing.sm)
                        .padding(.bottom, DS.Spacing.safeBottom)
                    }
                    .scrollViewGlassEdges()
                    .searchable(
                        text: $viewModel.searchText,
                        placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: L10n.Common.search
                    )
                }

                // FAB — new group
                if !viewModel.activeGroups.isEmpty || !viewModel.archivedGroups.isEmpty {
                    newGroupFAB
                }
            }
            .navigationTitle(L10n.Groups.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ProfileToolbarItem {
                    isPresentingSettings = true
                }
            }
            .sheet(isPresented: $isPresentingSettings) {
                ProfileView()
            }
            .sheet(isPresented: $viewModel.showCreateGroup, onDismiss: {
                viewModel.loadData()
            }) {
                GroupFormView(group: nil)
            }
            .fullScreenCover(isPresented: $viewModel.showGroupDetail, onDismiss: {
                viewModel.loadData()
            }) {
                if let group = viewModel.selectedGroup {
                    GroupDetailView(group: group)
                }
            }
            .refreshable { viewModel.loadData() }
            .appliesPendingRemoteChanges(sessionState)
            .onAppear {
                viewModel.setContext(modelContext)
                evaluateNudge()
                evaluateGroupsOnboarding()
            }
            .groupsOnboardingSheet(
                isPresented: $showGroupsOnboarding,
                onPersistFlag: {
                    seedSystemGroupCategoriesIfNeeded(in: modelContext)
                    appPreferences.hasShownGroupsOnboarding = true
                }
            )
            .onDisappear {
                showNudgeBanner = false
            }
            .onChange(of: sessionState.dataVersion) {
                viewModel.loadData()
            }
            .onChange(of: viewModel.activeGroups.count) { _, newCount in
                if !appPreferences.hasSeenGroupsNotificationPrompt && newCount > 0 {
                    showNotificationPrompt = true
                }
            }
            // Deep link: open a specific group detail once the group list is available.
            .onChange(of: sessionState.pendingGroupID, initial: true) { _, _ in
                openPendingGroupIfAvailable()
            }
            .onChange(of: viewModel.groups.count, initial: true) { _, _ in
                openPendingGroupIfAvailable()
            }
            .alert(L10n.Groups.Notifications.promptTitle, isPresented: $showNotificationPrompt) {
                Button(L10n.Groups.Notifications.promptEnable) {
                    appPreferences.hasSeenGroupsNotificationPrompt = true
                    activateGroupsNotification()
                }
                Button(L10n.Action.cancel, role: .cancel) {
                    appPreferences.hasSeenGroupsNotificationPrompt = true
                }
            } message: {
                Text(L10n.Groups.Notifications.promptMessage)
            }
            .alert(L10n.Notifications.permissionRequired, isPresented: $showPermissionDeniedAlert) {
                Button(L10n.Notifications.openSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Notifications.permissionMessage)
            }
            .alert(
                L10n.Groups.Card.leaveGroupAlertTitle,
                isPresented: Binding(
                    get: { rejectedGroupPendingLeave != nil },
                    set: { if !$0 { rejectedGroupPendingLeave = nil } }
                )
            ) {
                Button(L10n.Groups.Settings.leaveGroup, role: .destructive) {
                    if let group = rejectedGroupPendingLeave {
                        Task { @MainActor in
                            do {
                                try await GroupService.shared.leaveGroup(group)
                                viewModel.loadData()
                            } catch {
                                #if DEBUG
                                print("GroupsContainerView: leaveGroup failed: \(error)")
                                #endif
                            }
                            rejectedGroupPendingLeave = nil
                        }
                    }
                }
                Button(L10n.Action.cancel, role: .cancel) {
                    rejectedGroupPendingLeave = nil
                }
            } message: {
                Text(L10n.Groups.Card.leaveGroupAlertBody)
            }
        }
    }

    // MARK: - Helpers

    private func groupCardRow(group: SplitGroup) -> some View {
        GroupCardView(
            group: group,
            memberCount: viewModel.memberCount(for: group),
            pendingCount: viewModel.pendingMemberCount(for: group),
            debts: viewModel.currentUserDebts(for: group),
            displayMode: GroupCardDisplayLogic.displayMode(
                memberStatus: viewModel.currentMemberStatus(for: group)
            ),
            action: { viewModel.openDetail(for: group) },
            onRejectedTap: { rejectedGroupPendingLeave = group }
        )
    }

    private func evaluateNudge() {
        NudgeService.shared.evaluate()
        if NudgeService.shared.currentNudge != nil {
            withAnimation(.easeOut(duration: 0.3)) {
                showNudgeBanner = true
            }
        }
    }

    private func evaluateGroupsOnboarding() {
        let shouldShow = GroupsOnboardingLogic.shouldShow(
            hasShownOnboarding: appPreferences.hasShownGroupsOnboarding,
            onboardingMode: sessionState.onboardingMode,
            hasPendingGroupDeeplink: sessionState.pendingGroupID != nil
        )
        if shouldShow {
            showGroupsOnboarding = true
        }
    }

    private func openPendingGroupIfAvailable() {
        guard let groupID = sessionState.pendingGroupID,
              let uuid = UUID(uuidString: groupID),
              let group = viewModel.activeGroups.first(where: { $0.id == uuid })
        else { return }

        sessionState.pendingGroupID = nil
        viewModel.openDetail(for: group)
    }

    private func handleNudgeAction(_ nudge: NudgeType) {
        switch nudge.actionType {
        case .activateFullMode:
            AppRouter.shared.enqueue(.presentFullModeActivation)
        case .openPanel:
            sessionState.selectMainTab(.panel)
        case .openGroupDetail:
            if let group = viewModel.activeGroups.first {
                viewModel.openDetail(for: group)
            }
        case .dismiss:
            break
        }
    }

    private func activateGroupsNotification() {
        // typeRaw matches NotificationType.groups
        let descriptor = FetchDescriptor<NotificationItem>(
            predicate: #Predicate { $0.typeRaw == "groups" }
        )
        do {
            if let item = try modelContext.fetch(descriptor).first {
                item.isActive = true
                try modelContext.save()
            }
        } catch {
            #if DEBUG
            print("GroupsContainerView: Error activating groups notification: \(error)")
            #endif
        }

        Task { @MainActor in
            let status = await NotificationService.shared.checkPermissionStatus()
            switch status {
            case .notDetermined:
                _ = await NotificationService.shared.requestPermission()
            case .denied:
                showPermissionDeniedAlert = true
            default:
                break
            }
        }
    }

    // MARK: - Archived Groups

    private var archivedGroupsSection: some View {
        VStack(spacing: DS.Spacing.md) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.showArchived.toggle()
                }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: viewModel.showArchived ? "chevron.down" : "chevron.right")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                    Text(viewModel.showArchived
                         ? L10n.Groups.Settings.hideArchived
                         : L10n.Groups.Settings.showArchivedCount(viewModel.archivedGroups.count))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if viewModel.showArchived {
                ForEach(viewModel.archivedGroups, id: \.id) { group in
                    groupCardRow(group: group)
                        .opacity(0.6)
                }
            }
        }
    }

    // MARK: - FAB

    private var newGroupFAB: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    viewModel.showCreateGroup = true
                } label: {
                    Image(systemName: "plus")
                        .font(DS.Typography.title)
                        .foregroundStyle(.white)
                        .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                        .glassEffect(
                            .regular.interactive().tint(theme.accent.opacity(0.6)),
                            in: Circle()
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .dsFloatingShadow()
                .accessibilityLabel(L10n.Groups.newGroup)
            }
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
        }
    }
}
