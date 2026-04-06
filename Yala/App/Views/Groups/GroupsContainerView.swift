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

    // MARK: - State

    @State private var viewModel = GroupsViewModel()
    @State private var isPresentingSettings = false

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

                            // Group cards
                            ForEach(viewModel.filteredGroups, id: \.id) { group in
                                GroupCardView(
                                    group: group,
                                    memberCount: viewModel.memberCount(for: group),
                                    balance: viewModel.currentUserBalance(for: group)
                                ) {
                                    viewModel.openDetail(for: group)
                                }
                            }

                            // Archived groups
                            if !viewModel.archivedGroups.isEmpty {
                                archivedGroupsSection
                            }
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.sm)
                        .padding(.bottom, DS.Spacing.safeBottom)
                    }
                    .searchable(
                        text: $viewModel.searchText,
                        placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: L10n.Common.search
                    )
                }

                // FAB — new group
                if !viewModel.activeGroups.isEmpty {
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
            .onAppear {
                viewModel.setContext(modelContext)
            }
            .onChange(of: sessionState.dataVersion) {
                viewModel.loadData()
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
                         : "\(L10n.Groups.Settings.showArchived) (\(viewModel.archivedGroups.count))")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if viewModel.showArchived {
                ForEach(viewModel.archivedGroups, id: \.id) { group in
                    GroupCardView(
                        group: group,
                        memberCount: viewModel.memberCount(for: group),
                        balance: viewModel.currentUserBalance(for: group)
                    ) {
                        viewModel.openDetail(for: group)
                    }
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
                        .background(theme.accent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Groups.newGroup)
                .glassEffect(.regular.interactive())
                .dsFloatingShadow()
            }
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
        }
    }
}
