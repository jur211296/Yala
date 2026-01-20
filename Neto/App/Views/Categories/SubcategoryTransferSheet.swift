//
//  SubcategoryTransferSheet.swift
//  Neto
//
//  Sheet para transferir transacciones antes de eliminar una subcategoría.
//

import SwiftData
import SwiftUI

/// Sheet que ofrece opciones para manejar transacciones antes de eliminar una subcategoría
struct SubcategoryTransferSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Subcategory.sortOrder, order: .forward) private var allSubcategories:
        [Subcategory]
    @Query(sort: \Category.sortOrder, order: .forward) private var allCategories: [Category]

    let subcategoryToDelete: Subcategory
    let onComplete: () -> Void

    @State private var showingPicker: Bool = false
    @State private var showingDeleteConfirmation: Bool = false

    /// Calculated transaction count for this subcategory
    private var transactionCount: Int {
        let subcategoryID = subcategoryToDelete.persistentModelID
        do {
            let descriptor = FetchDescriptor<TransactionItem>()
            let allTransactions = try modelContext.fetch(descriptor)
            return allTransactions.filter { $0.subcategory?.persistentModelID == subcategoryID }.count
        } catch {
            print("Transfer: Error counting transactions in sheet: \(error)")
            return 0
        }
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
                    NetoToolbarButton(systemName: "xmark") {
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
        .tint(Color.electricIndigo)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Icono de advertencia
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 70, height: 70)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
            }

            // Mensaje
            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Subcategory.transferHeader)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(L10n.Subcategory.transferDescription(transactionCount, subcategoryToDelete.name))
                    .font(.subheadline)
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
                color: .red
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
                            .frame(width: 44, height: 44)

                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundStyle(color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote)
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
                        ForEach(availableDestinations, id: \.category.persistentModelID) { group in
                            SectionBox(title: group.category.name) {
                                VStack(spacing: 0) {
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
                                                    .frame(width: 32, height: 32)
                                                    .overlay(
                                                        Image(
                                                            systemName: subcategory.iconName
                                                                ?? "tag.fill"
                                                        )
                                                        .font(.subheadline)
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
                    NetoToolbarButton(systemName: "xmark") {
                        showingPicker = false
                    }
                }
            }
        }
        .tint(Color.electricIndigo)
    }

    // MARK: - Transfer Logic

    /// Transfers all transactions to the specified subcategory
    private func transferTransactions(to destination: Subcategory) {
        let sourceID = subcategoryToDelete.persistentModelID

        do {
            let descriptor = FetchDescriptor<TransactionItem>()
            let allTransactions = try modelContext.fetch(descriptor)
            let transactionsToTransfer = allTransactions.filter {
                $0.subcategory?.persistentModelID == sourceID
            }

            for transaction in transactionsToTransfer {
                transaction.subcategory = destination
                transaction.category = destination.category
            }

            try modelContext.save()
            modelContext.processPendingChanges()
            showingPicker = false
            dismiss()
            onComplete()
        } catch {
            print("Transfer: Error transferring transactions: \(error)")
        }
    }

    /// Transfers all transactions to the "Unassigned" subcategory in "Others" category
    private func transferToUnassigned() {
        guard let unassignedSubcategory = getOrCreateUnassignedSubcategory() else {
            print("Transfer: Could not get or create unassigned subcategory")
            return
        }

        transferTransactions(to: unassignedSubcategory)
    }

    /// Deletes all transactions associated with the subcategory
    private func deleteAllTransactions() {
        let sourceID = subcategoryToDelete.persistentModelID

        do {
            let descriptor = FetchDescriptor<TransactionItem>()
            let allTransactions = try modelContext.fetch(descriptor)
            let transactionsToDelete = allTransactions.filter {
                $0.subcategory?.persistentModelID == sourceID
            }

            for transaction in transactionsToDelete {
                modelContext.delete(transaction)
            }

            try modelContext.save()
            modelContext.processPendingChanges()
            dismiss()
            onComplete()
        } catch {
            print("Transfer: Error deleting transactions: \(error)")
        }
    }

    /// Gets or creates the "Unassigned" subcategory in the "Others" category
    private func getOrCreateUnassignedSubcategory() -> Subcategory? {
        let isIncome = subcategoryToDelete.category.isIncome
        let othersName = L10n.Category.others
        let unassignedName = L10n.Subcategory.unassigned

        // Find or create "Others" category
        var othersCategory: Category? = allCategories.first {
            $0.name == othersName && $0.isIncome == isIncome
        }

        if othersCategory == nil {
            // Create "Others" category
            let maxSortOrder = allCategories.map { $0.sortOrder }.max() ?? -1
            let newCategory = Category(
                name: othersName,
                colorHex: "#8E8E93",  // Gray color
                isIncome: isIncome,
                isDefaultSeed: false,
                isVisible: true,
                sortOrder: maxSortOrder + 1,
                iconName: "questionmark.folder"
            )
            modelContext.insert(newCategory)
            othersCategory = newCategory
        }

        guard let category = othersCategory else { return nil }

        // Find or create "Unassigned" subcategory
        var unassignedSubcategory: Subcategory? = allSubcategories.first {
            $0.name == unassignedName && $0.category.persistentModelID == category.persistentModelID
        }

        if unassignedSubcategory == nil {
            // Create "Unassigned" subcategory
            let maxSortOrder = category.subcategories.map { $0.sortOrder }.max() ?? -1
            let newSubcategory = Subcategory(
                name: unassignedName,
                colorHex: category.colorHex,
                isDefaultSeed: false,
                isVisible: true,
                sortOrder: maxSortOrder + 1,
                natureRawValue: SubcategoryNature.unclassified.rawValue,
                iconName: "questionmark",
                category: category
            )
            modelContext.insert(newSubcategory)
            unassignedSubcategory = newSubcategory
        }

        // Save to ensure IDs are generated
        do {
            try modelContext.save()
        } catch {
            print("Transfer: Error saving unassigned subcategory: \(error)")
            return nil
        }

        return unassignedSubcategory
    }

    // MARK: - Available Destinations

    /// Subcategorías disponibles agrupadas por categoría (excluyendo la que se va a eliminar)
    private var availableDestinations: [(category: Category, subcategories: [Subcategory])] {
        let parentCategory = subcategoryToDelete.category

        // Filtrar subcategorías visibles, excluyendo la que se elimina
        let filtered = allSubcategories.filter { subcategory in
            guard subcategory.isVisible else { return false }
            guard subcategory.persistentModelID != subcategoryToDelete.persistentModelID else {
                return false
            }
            // Solo mostrar subcategorías del mismo tipo (ingreso/gasto)
            return subcategory.category.isIncome == parentCategory.isIncome
        }

        // Agrupar por categoría
        let grouped = Dictionary(grouping: filtered) { $0.category }

        return
            grouped
            .sorted { $0.key.sortOrder < $1.key.sortOrder }
            .map {
                (category: $0.key, subcategories: $0.value.sorted { $0.sortOrder < $1.sortOrder })
            }
    }
}
