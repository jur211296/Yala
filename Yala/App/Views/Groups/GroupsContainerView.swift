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

                if viewModel.activeGroups.isEmpty {
                    YalaEmptyState.noGroups {
                        viewModel.showCreateGroup = true
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
