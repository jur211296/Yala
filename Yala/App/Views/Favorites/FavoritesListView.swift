//
//  FavoritesListView.swift
//  Yala
//
//  List view for favorite payment templates.
//  Accessed from ProfileView (manage mode) or NewTransactionView star button (select mode).
//

import SwiftData
import SwiftUI

// MARK: - List Mode

enum FavoritesListMode {
    /// Manage favorites: add, edit, delete, reorder (from ProfileView - pushed)
    case manage
    /// Select a favorite to pre-fill a transaction (from NewTransactionView - sheet)
    case select
}

// MARK: - Favorites List View

struct FavoritesListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode

    @State private var viewModel = FavoritesListViewModel()

    let mode: FavoritesListMode
    var onSelect: ((FavoritePayment) -> Void)?

    init(mode: FavoritesListMode = .manage, onSelect: ((FavoritePayment) -> Void)? = nil) {
        self.mode = mode
        self.onSelect = onSelect
    }

    var body: some View {
        // For manage mode (pushed from ProfileView), don't wrap in NavigationStack
        // For select mode (presented as sheet), wrap in NavigationStack
        if mode == .select {
            NavigationStack {
                content
            }
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if viewModel.isEmpty {
                emptyState
            } else {
                favoritesList
            }
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.Favorites.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Leading button only for select mode (sheet)
            if mode == .select {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }

            // Toolbar trailing buttons
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: DS.Spacing.lg) {
                    // Edit/Done button
                    if mode == .manage && !viewModel.isEmpty {
                        if editMode?.wrappedValue.isEditing == true {
                            YalaSaveButton(action: {
                                editMode?.wrappedValue = .inactive
                            })
                        } else {
                            Button {
                                editMode?.wrappedValue = .active
                            } label: {
                                Text(L10n.Action.edit)
                                    .font(DS.Typography.headline)
                                    .foregroundStyle(Color.primary)
                            }
                            .frame(height: 32)
                        }
                    }

                    // Add button (hide in edit mode)
                    if !(editMode?.wrappedValue.isEditing == true) {
                        YalaToolbarButton(systemName: "plus", label: L10n.Action.add) {
                            viewModel.openEditor(for: nil)
                        }
                        .accessibilityIdentifier("favorites_add_button")
                    }
                }
            }
        }
        .sheet(
            isPresented: $viewModel.showEditor,
            onDismiss: {
                viewModel.closeEditor()
            }
        ) {
            if let favorite = viewModel.favoriteToEdit {
                FavoriteEditorView(favorite: favorite)
            } else {
                FavoriteEditorView(favorite: nil)
            }
        }
        .alert(
            L10n.Common.error,
            isPresented: $viewModel.showSaveError,
            actions: {
                Button(L10n.Common.understood, role: .cancel) {}
            },
            message: {
                Text(L10n.Common.saveError)
            }
        )
        .onAppear {
            viewModel.setContext(modelContext)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()
            YalaEmptyState.noFavorites()
            Spacer()
        }
    }

    // MARK: - Favorites List (Native List with swipe-to-delete and reorder)

    private var favoritesList: some View {
        List {
            ForEach(viewModel.displayedFavorites, id: \.persistentModelID) { favorite in
                FavoriteRowView(favorite: favorite) {
                    handleFavoriteTap(favorite)
                }
                .accessibilityIdentifier("favorites_row_\(favorite.name)")
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onDelete(perform: viewModel.deleteFavorites)
            .onMove(perform: viewModel.moveFavorites)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top) {
            if mode == .manage {
                ContextualGuideBanner.favoritesManage()
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.sm)
            }
        }
    }

    // MARK: - Actions

    private func handleFavoriteTap(_ favorite: FavoritePayment) {
        switch mode {
        case .manage:
            viewModel.openEditor(for: favorite)
        case .select:
            onSelect?(favorite)
            dismiss()
        }
    }
}

#Preview {
    FavoritesListView(mode: .manage)
}
