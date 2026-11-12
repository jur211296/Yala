//
//  CategoryMoveRecordsSheet.swift
//  Yala
//
//  Una categoría con registros no se puede borrar tal cual: o se oculta, o sus registros pasan a otra y
//  después se elimina (auditoría UX 2.2, lote 7, L7-10).
//

import SwiftData
import SwiftUI

// MARK: - El aviso con las dos salidas

/// «No se puede eliminar» con dos salidas: «Ocultarla» (deja de aparecer al registrar y el historial se queda) y
/// «Mover sus registros…». Antes solo decía que había que vaciarla subcategoría por subcategoría.
struct CategoryCannotDeleteAlert: ViewModifier {
    @Binding var isPresented: Bool
    let recordCount: Int
    let onHide: () -> Void
    let onMove: () -> Void

    func body(content: Content) -> some View {
        content.alert(L10n.Category.cannotDeleteTitle, isPresented: $isPresented) {
            Button(L10n.UXL7.Categories.hideAction) { onHide() }
            Button(L10n.UXL7.Categories.moveRecordsAction) { onMove() }
            Button(L10n.Action.cancel, role: .cancel) {}
        } message: {
            Text(L10n.UXL7.Categories.cannotDeleteChoiceMessage(recordCount))
        }
    }
}

// MARK: - A dónde van

struct CategoryMoveRecordsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(EntityDeletionService.self) private var deletionService

    let category: Category
    /// Ya se movió todo y la categoría está eliminada.
    let onMoved: () -> Void

    @State private var destinations: [CategoryRecordsMoveService.Destination] = []
    @State private var chosen: Subcategory?
    @State private var chosenCount: Int = 0
    @State private var showConfirmation = false
    @State private var showFailure = false
    /// El nombre se lee al abrir: tras eliminarla, la categoría ya no se puede leer.
    @State private var categoryName: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text(L10n.UXL7.Categories.moveSubtitle(categoryName))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DS.Spacing.xs)

                    if destinations.isEmpty {
                        Text(L10n.UXL7.Categories.moveNoDestinations)
                            .font(DS.Typography.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.xxl)
                    }

                    ForEach(destinations) { destination in
                        SectionBox(title: destination.category.name) {
                            VStack(spacing: DS.Spacing.none) {
                                ForEach(Array(destination.subcategories.enumerated()), id: \.element.persistentModelID) {
                                    index, subcategory in
                                    if index > 0 { SubsectionDivider() }
                                    destinationRow(subcategory, in: destination.category)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.UXL7.Categories.moveTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .alert(L10n.UXL7.Categories.moveConfirmTitle(categoryName), isPresented: $showConfirmation) {
                Button(L10n.UXL7.Categories.moveConfirmAction, role: .destructive) { performMove() }
                Button(L10n.Action.cancel, role: .cancel) { chosen = nil }
            } message: {
                Text(confirmationMessage)
            }
            .alert(L10n.Common.error, isPresented: $showFailure) {
                Button(L10n.Common.understood, role: .cancel) {}
            } message: {
                Text(L10n.UXL7.Categories.moveFailed)
            }
        }
        .onAppear(perform: load)
    }

    private var confirmationMessage: String {
        guard let chosen, let parent = chosen.category else { return "" }
        return L10n.UXL7.Categories.moveConfirmMessage(
            categoryName, "\(parent.name) › \(chosen.name)", L10n.UXL7.recordsCount(chosenCount))
    }

    private func destinationRow(_ subcategory: Subcategory, in parent: Category) -> some View {
        Button {
            choose(subcategory)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Circle()
                    .fill(Color(hex: subcategory.colorHex ?? parent.colorHex))
                    .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)
                    .overlay(
                        Image(systemName: subcategory.iconName ?? parent.iconName ?? "tag.fill")
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.white)
                    )
                    .accessibilityHidden(true)
                Text(subcategory.name)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("category_move_destination_\(subcategory.name)")
    }

    private func load() {
        categoryName = category.name
        do {
            let subcategories = try modelContext.fetch(FetchDescriptor<Subcategory>())
            destinations = CategoryRecordsMoveService.destinations(for: category, among: subcategories)
        } catch {
            #if DEBUG
            print("CategoryMoveRecordsSheet: Error loading subcategories: \(error)")
            #endif
            destinations = []
        }
    }

    /// El recuento de la confirmación se lee al elegir el destino, no al abrir la hoja.
    private func choose(_ subcategory: Subcategory) {
        do {
            chosenCount = try CategoryRecordsMoveService.recordCount(of: category, context: modelContext)
            chosen = subcategory
            showConfirmation = true
        } catch {
            #if DEBUG
            print("CategoryMoveRecordsSheet: Error counting records: \(error)")
            #endif
            showFailure = true
        }
    }

    private func performMove() {
        guard let destination = chosen else { return }
        do {
            try CategoryRecordsMoveService.moveAllAndDelete(
                from: category, to: destination, context: modelContext, deletionService: deletionService)
            dismiss()
            onMoved()
        } catch {
            #if DEBUG
            print("CategoryMoveRecordsSheet: Error moving records: \(error)")
            #endif
            showFailure = true
        }
    }
}
