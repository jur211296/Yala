//
//  FavoritesListView.swift
//  Neto
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

    @Query(sort: \FavoritePayment.displayOrder, order: .forward)
    private var favorites: [FavoritePayment]

    let mode: FavoritesListMode
    var onSelect: ((FavoritePayment) -> Void)?

    @State private var showEditor = false
    @State private var favoriteToEdit: FavoritePayment?

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
            if favorites.isEmpty {
                emptyState
            } else {
                favoritesList
            }
        }
        .background(PanelBackgroundView())
        .navigationTitle(L10n.Favorites.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Leading button only for select mode (sheet)
            if mode == .select {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }
            }

            // Toolbar trailing buttons
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    // Edit/Done button
                    if mode == .manage && !favorites.isEmpty {
                        if editMode?.wrappedValue.isEditing == true {
                            NetoSaveButton(action: {
                                editMode?.wrappedValue = .inactive
                            })
                        } else {
                            Button {
                                editMode?.wrappedValue = .active
                            } label: {
                                Text(L10n.Action.edit)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Color.primary)
                            }
                            .frame(height: 32)
                        }
                    }

                    // Add button (hide in edit mode)
                    if !(editMode?.wrappedValue.isEditing == true) {
                        NetoToolbarButton(systemName: "plus") {
                            favoriteToEdit = nil
                            showEditor = true
                        }
                    }
                }
            }
        }
        .sheet(
            isPresented: $showEditor,
            onDismiss: {
                // Reset favoriteToEdit when sheet closes
                favoriteToEdit = nil
            }
        ) {
            if let favorite = favoriteToEdit {
                FavoriteEditorView(favorite: favorite)
            } else {
                FavoriteEditorView(favorite: nil)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.electricIndigo.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "star.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.electricIndigo, Color.hotPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text(L10n.Favorites.noFavorites)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(L10n.Favorites.createTemplate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Favorites List (Native List with swipe-to-delete and reorder)

    private var favoritesList: some View {
        List {
            ForEach(favorites, id: \.persistentModelID) { favorite in
                FavoriteRowView(favorite: favorite) {
                    handleFavoriteTap(favorite)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onDelete(perform: deleteFavorites)
            .onMove(perform: moveFavorites)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Actions

    private func handleFavoriteTap(_ favorite: FavoritePayment) {
        switch mode {
        case .manage:
            // Open for editing
            favoriteToEdit = favorite
            showEditor = true
        case .select:
            // Return selection to caller
            onSelect?(favorite)
            dismiss()
        }
    }

    private func deleteFavorites(at offsets: IndexSet) {
        for index in offsets {
            let favorite = favorites[index]
            modelContext.delete(favorite)
        }
        try? modelContext.save()
    }

    private func moveFavorites(from source: IndexSet, to destination: Int) {
        var orderedFavorites = favorites
        orderedFavorites.move(fromOffsets: source, toOffset: destination)

        // Update display order
        for (index, favorite) in orderedFavorites.enumerated() {
            favorite.displayOrder = index
        }

        try? modelContext.save()
    }
}

#Preview {
    FavoritesListView(mode: .manage)
}
