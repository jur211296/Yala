//
//  SubcategoryTransferSheet.swift
//  Yala
//
//  Sheet para transferir transacciones antes de eliminar una subcategoría.
//

import SwiftData
import SwiftUI

/// Sheet que ofrece opciones para manejar transacciones antes de eliminar una subcategoría
struct SubcategoryTransferSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = SubcategoryTransferViewModel()

    let subcategoryToDelete: Subcategory
    let onComplete: () -> Void

    @State private var showingPicker: Bool = false
    @State private var showingDeleteConfirmation: Bool = false

    /// Calculated transaction count for this subcategory
    private var transactionCount: Int {
        viewModel.transactionCount(for: subcategoryToDelete)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        // Header con información
                        headerSection

                        // Opciones de acción
                        actionsSection
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                }
            }
            .navigationTitle(L10n.Subcategory.transferTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPicker) {
                destinationPickerSheet
            }
            .confirmationDialog(
                L10n.Subcategory.deleteTransactionsConfirmTitle,
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.Subcategory.deleteTransactionsConfirm, role: .destructive) {
                    deleteAllTransactions()
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Subcategory.deleteTransactionsConfirmMessage(transactionCount))
            }
        }

        .onAppear {
            viewModel.setContext(modelContext)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Icono de advertencia
            ZStack {
                Circle()
                    .fill(DS.Semantic.warningBackground)
                    .frame(width: 70, height: 70)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(DS.Typography.amountLarge)
                    .foregroundStyle(DS.Semantic.warningForeground)
                    .accessibilityHidden(true)
            }

            // Mensaje
            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Subcategory.transferHeader)
                    .font(DS.Typography.headline)
                    .multilineTextAlignment(.center)

                Text(L10n.Subcategory.transferDescription(transactionCount, subcategoryToDelete.name))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: DS.Spacing.md) {
            // Opción 1: Transferir a subcategoría específica
            actionButton(
                icon: "arrow.right.circle.fill",
                title: L10n.Subcategory.transferToSpecific,
                description: L10n.Subcategory.transferToSpecificDesc,
                color: .blue
            ) {
                showingPicker = true
            }

            // Opción 2: Mover a "Sin asignar"
            actionButton(
                icon: "tray.fill",
                title: L10n.Subcategory.transferToUnassigned,
                description: L10n.Subcategory.transferToUnassignedDesc,
                color: .purple
            ) {
                transferToUnassigned()
            }

            // Opción 3: Eliminar transacciones
            actionButton(
                icon: "trash.fill",
                title: L10n.Subcategory.deleteTransactions,
                description: L10n.Subcategory.deleteTransactionsDesc,
                color: DS.Semantic.errorForeground
            ) {
                showingDeleteConfirmation = true
            }
        }
    }

    private func actionButton(
        icon: String,
        title: String,
        description: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            SectionBox(title: "") {
                HStack(spacing: DS.Spacing.lg) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: DS.Button.actionSize, height: DS.Button.actionSize)

                        Image(systemName: icon)
                            .font(DS.Typography.title)
                            .foregroundStyle(color)
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(title)
                            .font(DS.Typography.bodyBold)
                            .foregroundStyle(.primary)

                        Text(description)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding()
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Destination Picker Sheet

    private var destinationPickerSheet: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        ForEach(viewModel.availableDestinations(excluding: subcategoryToDelete), id: \.category.persistentModelID) { group in
                            SectionBox(title: group.category.name) {
                                VStack(spacing: DS.Spacing.none) {
                                    ForEach(
                                        Array(group.subcategories.enumerated()),
                                        id: \.element.persistentModelID
                                    ) { index, subcategory in
                                        Button {
                                            transferTransactions(to: subcategory)
                                        } label: {
                                            HStack(spacing: DS.Spacing.md) {
                                                Circle()
                                                    .fill(
                                                        Color(
                                                            hex: subcategory.colorHex
                                                                ?? group.category.colorHex)
                                                    )
                                                    .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)
                                                    .overlay(
                                                        Image(
                                                            systemName: subcategory.iconName
                                                                ?? "tag.fill"
                                                        )
                                                        .font(DS.Typography.subheadline)
                                                        .foregroundStyle(.white)
                                                    )

                                                Text(subcategory.name)
                                                    .foregroundStyle(.primary)

                                                Spacer()
                                            }
                                            .padding()
                                        }
                                        .buttonStyle(.plain)

                                        if index < group.subcategories.count - 1 {
                                            SubsectionDivider()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xl)
                }
            }
            .navigationTitle(L10n.Subcategory.selectDestination)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        showingPicker = false
                    }
                }
            }
        }

    }

    // MARK: - Transfer Logic

    /// Transfers all transactions to the specified subcategory
    private func transferTransactions(to destination: Subcategory) {
        do {
            try viewModel.transferTransactions(from: subcategoryToDelete, to: destination)
            showingPicker = false
            dismiss()
            onComplete()
        } catch {
            #if DEBUG
            print("Transfer: Error transferring transactions: \(error)")
            #endif
        }
    }

    /// Transfers all transactions to the "Unassigned" subcategory in "Others" category
    private func transferToUnassigned() {
        guard let unassignedSubcategory = viewModel.getOrCreateUnassignedSubcategory(for: subcategoryToDelete) else {
            #if DEBUG
            print("Transfer: Could not get or create unassigned subcategory")
            #endif
            return
        }

        transferTransactions(to: unassignedSubcategory)
    }

    /// Deletes all transactions associated with the subcategory
    private func deleteAllTransactions() {
        do {
            try viewModel.deleteTransactions(for: subcategoryToDelete)
            dismiss()
            onComplete()
        } catch {
            #if DEBUG
            print("Transfer: Error deleting transactions: \(error)")
            #endif
        }
    }
}
