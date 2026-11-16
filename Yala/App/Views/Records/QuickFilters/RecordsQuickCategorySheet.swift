//
//  RecordsQuickCategorySheet.swift
//  Yala
//
//  La hoja de «Categoría ▾» en Registros (Jürgen, 15-nov): se elige como en el primer presupuesto del onboarding. Arriba,
//  la rejilla de categorías (`TutorialSelectableTile`, tal cual): tocar una la elige entera o la quita. Debajo, las
//  subcategorías de lo elegido en círculos, para quitar las que no se quieran ver (el paso 2 de ese flujo). Se aplica
//  al cerrar («Listo» o deslizando), de una vez, como «Más filtros»: aplicado a cada toque, el Panel deducía «Gasto» de
//  la primera categoría y lo dejaba puesto al sumar una de ingresos. Lo marcado lo guarda quien presenta la hoja; cómo
//  se escribe en la sesión, `RecordsQuickCategorySelectionLogic`.
//

import SwiftData
import SwiftUI

struct RecordsQuickCategorySheet: View {
    let categories: [Category]
    let subcategories: [Subcategory]
    /// Lo marcado, como conjunto de subcategorías (`RecordsQuickCategorySelectionLogic.expanded`).
    @Binding var expanded: Set<PersistentIdentifier>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.usesLargeSheets) private var usesLargeSheets
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedDetent: PresentationDetent = .medium

    private let sizing = SelectorSheetSizing.mediumFirst
    private typealias Entry = RecordsQuickCategorySelectionLogic.Entry<PersistentIdentifier, PersistentIdentifier>
    private typealias Logic = RecordsQuickCategorySelectionLogic

    /// Las categorías que se ofrecen: las que tienen alguna subcategoría visible, como la hoja de «Más filtros».
    private var offered: [(category: Category, subs: [Subcategory])] {
        categories.compactMap { category in
            let subs = subcategories.filter { $0.category == category && $0.isVisible }
            return subs.isEmpty ? nil : (category, subs)
        }
    }

    private func entry(_ category: Category, _ subs: [Subcategory]) -> Entry {
        Entry(id: category.persistentModelID, subcategories: subs.map(\.persistentModelID))
    }

    var body: some View {
        let expanded = expanded
        let chosen = offered.filter { Logic.isChosen(entry($0.category, $0.subs), in: expanded) }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: DS.Spacing.sm),
                            count: TutorialGridColumns.count(3, dynamicTypeSize: dynamicTypeSize)
                        ),
                        spacing: DS.Spacing.sm
                    ) {
                        ForEach(offered, id: \.category.persistentModelID) { item in
                            let itemEntry = entry(item.category, item.subs)
                            TutorialSelectableTile(
                                icon: item.category.iconName ?? "tag.fill",
                                color: Color(hex: item.category.colorHex),
                                title: item.category.name,
                                isOn: Logic.isChosen(itemEntry, in: expanded),
                                id: "records_quick_category_tile"
                            ) {
                                write(Logic.togglingCategory(itemEntry, in: expanded))
                            }
                        }
                    }

                    if !chosen.isEmpty {
                        Text(L10n.RecordsQuickFilters23.subcategoriesHint)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(chosen, id: \.category.persistentModelID) { item in
                            subcategoryGroup(item.category, item.subs, expanded: expanded)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.lg)
            }
            .yalaScreenBackground(sizing.background(
                selectedDetent: selectedDetent,
                usesLargeSheets: usesLargeSheets,
                dynamicTypeSize: dynamicTypeSize
            ))
            .navigationTitle(L10n.RecordsQuickFilters23.category)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !expanded.isEmpty {
                        Button(L10n.Filters.allCategories) {
                            DS.Haptic.selection()
                            write([])
                        }
                        .accessibilityIdentifier("records_quick_category_all")
                    }
                }
            }
            .safeAreaBar(edge: .bottom) {
                YalaPrimaryButton(L10n.Action.done) { dismiss() }
                    .accessibilityIdentifier("records_quick_category_done")
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.sm)
            }
        }
        .selectorSheetSizing(sizing, selectedDetent: $selectedDetent)
    }

    // MARK: - Subcategorías de lo elegido (el paso 2 del primer presupuesto)

    private func subcategoryGroup(
        _ category: Category, _ subs: [Subcategory], expanded: Set<PersistentIdentifier>
    ) -> some View {
        let color = Color(hex: category.colorHex)
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Label {
                Text(category.name).font(DS.Typography.subheadline.weight(.semibold))
            } icon: {
                Circle().fill(color).frame(width: 10, height: 10)
            }
            .accessibilityAddTraits(.isHeader)
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: DS.Spacing.xs),
                    count: TutorialGridColumns.count(4, dynamicTypeSize: dynamicTypeSize)
                ),
                spacing: DS.Spacing.sm
            ) {
                ForEach(subs, id: \.persistentModelID) { sub in
                    RecordsQuickSubcategoryCircle(
                        subcategory: sub,
                        color: color,
                        isOn: expanded.contains(sub.persistentModelID)
                    ) {
                        write(Logic.togglingSubcategory(sub.persistentModelID, in: expanded))
                    }
                }
            }
        }
    }

    private func write(_ newExpanded: Set<PersistentIdentifier>) {
        expanded = newExpanded
    }
}

/// Un círculo de subcategoría: el del paso 2 del primer presupuesto (`FirstBudgetFlowView.subcategoryCircle`, que es
/// privado allí), con el mismo dibujo. Marcado: relleno del color de la categoría y ✓.
private struct RecordsQuickSubcategoryCircle: View {
    let subcategory: Subcategory
    let color: Color
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button {
            DS.Haptic.selection()
            action()
        } label: {
            VStack(spacing: DS.Spacing.xxs) {
                Image(systemName: subcategory.iconName ?? "circle.fill")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(isOn ? Color.white : color)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(isOn ? color : color.opacity(0.15)))
                    .overlay(alignment: .topTrailing) {
                        if isOn {
                            Image(systemName: "checkmark.circle.fill")
                                .font(DS.Typography.caption)
                                .foregroundStyle(.white, color)
                                .offset(x: 4, y: -4)
                        }
                    }
                    .accessibilityHidden(true)
                Text(subcategory.name)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(isOn ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("records_quick_subcategory")
    }
}
