//
//  SetupDemoMockSelectorSheet.swift
//  Yala
//
//  Sub-view shared para Setup Checklist demos standalone. Replica el chrome de
//  AccountSelectorSheet (lista) y SubcategorySelectorSheet (LazyVGrid 4 cols)
//  con script interno de highlight + auto-select + auto-dismiss. SwiftUI puro
//  sin SwiftData.
//
//  El enum `SetupDemoMockSheet` cubre los 3 tipos de selector que el demo de
//  firstExpense usa (account, subcategory, tags). El enum `SubcategoryContext`
//  controla la categoría mock cuando type == .subcategory (Step 2 usa `.food`,
//  Step 4 `scheduledPayment` usa `.subscriptions`).
//

import SwiftUI

// MARK: - Mock sheet types

enum SetupDemoMockSheet: String, Identifiable, CaseIterable {
    case account
    case subcategory
    case tags

    var id: String { rawValue }

    var accentColor: Color {
        switch self {
        case .account: return Color.electricIndigo
        case .subcategory: return Color.essentialNeed
        case .tags: return Color.priorityNeed
        }
    }

    var chipIcon: String {
        switch self {
        case .account: return "creditcard"
        case .subcategory: return "tag"
        case .tags: return "number"
        }
    }

    var sheetIcon: String {
        switch self {
        case .account: return "creditcard.fill"
        case .subcategory: return "tag.fill"
        case .tags: return "number"
        }
    }

    var chipPlaceholder: String {
        switch self {
        case .account: return L10n.Transaction.account
        case .subcategory: return L10n.Transaction.subcategory
        case .tags: return L10n.Transaction.tags
        }
    }

    /// Opciones mock — la 2da siempre es el target highlighted al final.
    /// Para `.subcategory`, las options vienen de `SubcategoryContext` (el grid
    /// usa contexto + icons específicos), no de aquí.
    func options(targetValue: String) -> [String] {
        switch self {
        case .account: return ["Efectivo", targetValue, "Tarjeta"]
        case .subcategory: return []
        case .tags: return ["trabajo", targetValue, "fin de semana"]
        }
    }

    var usesGridLayout: Bool { self == .subcategory }
}

// MARK: - Subcategory context (controla grid mock cuando type == .subcategory)

enum SubcategoryContext {
    case food          // Step 2 — firstExpense
    case subscriptions // Step 4 — scheduledPayment

    var headerLabel: String {
        switch self {
        case .food: return L10n.SetupChecklist.Demo.firstExpenseSubcategoryExample
        case .subscriptions: return L10n.SetupChecklist.Demo.scheduledPaymentSubcategoryHeader
        }
    }

    /// 4 options para LazyVGrid — la 2da es el target.
    func options(targetValue: String) -> [String] {
        switch self {
        case .food:
            return ["Restaurante", targetValue, "Supermercado", "Café"]
        case .subscriptions:
            return ["Internet", targetValue, "Gimnasio", "Streaming"]
        }
    }

    func icon(for index: Int) -> String {
        switch self {
        case .food:
            switch index {
            case 0: return "fork.knife"
            case 1: return "carrot.fill"
            case 2: return "cart.fill"
            case 3: return "cup.and.saucer.fill"
            default: return "tag.fill"
            }
        case .subscriptions:
            switch index {
            case 0: return "wifi"
            case 1: return "tv.fill"
            case 2: return "dumbbell.fill"
            case 3: return "play.rectangle.fill"
            default: return "tag.fill"
            }
        }
    }
}

// MARK: - Mock Selector Sheet

struct SetupDemoMockSelectorSheet: View {

    enum Stage {
        case idle
        case highlighting
        case selected
    }

    let type: SetupDemoMockSheet
    let targetValue: String
    let categoryContext: SubcategoryContext
    let reduceMotion: Bool
    let onSelected: () -> Void

    init(
        type: SetupDemoMockSheet,
        targetValue: String,
        categoryContext: SubcategoryContext = .food,
        reduceMotion: Bool,
        onSelected: @escaping () -> Void
    ) {
        self.type = type
        self.targetValue = targetValue
        self.categoryContext = categoryContext
        self.reduceMotion = reduceMotion
        self.onSelected = onSelected
    }

    @Environment(\.dismiss) private var dismiss
    @State private var stage: Stage = .idle
    @State private var script: Task<Void, Never>?

    private var options: [String] {
        type == .subcategory
            ? categoryContext.options(targetValue: targetValue)
            : type.options(targetValue: targetValue)
    }
    private var targetIndex: Int { 1 }

    private var gridColumns: [GridItem] {
        let count = min(options.count, 4)
        return Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.md), count: count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    if type.usesGridLayout {
                        gridContent
                    } else {
                        listContent
                    }
                }
            }
            .navigationTitle(type.chipPlaceholder)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        script?.cancel()
                        dismiss()
                    }
                }
            }
        }
        .task { startInternalScript() }
        .onDisappear { script?.cancel() }
    }

    // MARK: - List layout (account, tags)

    private var listContent: some View {
        VStack(spacing: DS.Spacing.none) {
            ForEach(0..<options.count, id: \.self) { index in
                mockListRow(index: index)
                if index < options.count - 1 {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 0.5)
                        .padding(.leading, DS.Spacing.xxxl)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(.thCard)
        )
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.xxl)
    }

    private func mockListRow(index: Int) -> some View {
        let isTarget = index == targetIndex
        let isHighlighted = stage != .idle && isTarget
        let isSelected = stage == .selected && isTarget
        return HStack(spacing: DS.Spacing.md) {
            Circle()
                .fill(type.accentColor.opacity(isTarget ? 1.0 : 0.6))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: type.sheetIcon)
                        .font(DS.Typography.label.weight(.semibold))
                        .foregroundStyle(.white)
                )

            Text(options[index])
                .font(DS.Typography.body)
                .foregroundStyle(.primary)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(DS.Typography.headline)
                    .foregroundStyle(type.accentColor)
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(
            isHighlighted ? type.accentColor.opacity(0.10) : Color.clear
        )
        .scaleEffect(isHighlighted ? 1.02 : 1.0)
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: stage)
    }

    // MARK: - Grid layout (subcategory — replica SubcategorySelectorSheet)

    private var gridContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.sm) {
                    Circle()
                        .fill(type.accentColor)
                        .frame(width: 10, height: 10)
                    Text(categoryContext.headerLabel)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, DS.Spacing.xs)

                LazyVGrid(columns: gridColumns, spacing: DS.Spacing.md) {
                    ForEach(0..<options.count, id: \.self) { index in
                        mockGridItem(index: index)
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.xxl)
    }

    private func mockGridItem(index: Int) -> some View {
        let isTarget = index == targetIndex
        let isHighlighted = stage != .idle && isTarget
        let isSelected = stage == .selected && isTarget
        let active = isHighlighted || isSelected
        return VStack(spacing: DS.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(type.accentColor.opacity(active ? 1.0 : 0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: categoryContext.icon(for: index))
                    .font(DS.Typography.label.weight(.bold))
                    .foregroundStyle(active ? .white : type.accentColor)

                if isSelected {
                    Circle()
                        .stroke(type.accentColor, lineWidth: 2)
                        .frame(width: 54, height: 54)
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }
            }

            Text(options[index])
                .font(DS.Typography.captionSmall)
                .foregroundStyle(active ? type.accentColor : .primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 28)
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: stage)
    }

    @MainActor
    private func startInternalScript() {
        script?.cancel()
        script = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }

            stage = .highlighting
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }

            stage = .selected
            onSelected()
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }

            dismiss()
        }
    }
}
