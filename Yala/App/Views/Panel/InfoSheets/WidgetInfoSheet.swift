//
//  WidgetInfoSheet.swift
//  Yala
//
//  Sheet pedagógica interactiva para widgets del Panel. Muestra una preview
//  reactiva de la gráfica (con sample data o real), chips descriptores,
//  explicación brand-voice, segmented S/M/L sincronizado con la preferencia
//  real, y CTA "Añadir al Panel" cuando el widget está oculto.
//
//  Patrón derivado de `FinancialScoreDetailSheet`: NavigationStack + xmark
//  toolbar + medium/large detents + ScrollView con secciones apiladas.
//

import SwiftUI

struct WidgetInfoSheet<Preview: View>: View {
    let kind: WidgetInfoKind
    let viewModel: PanelViewModel
    @ViewBuilder let previewContent: (WidgetSize) -> Preview

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    @State private var selectedSize: WidgetSize = .small

    private var content: WidgetInfoContent { .content(for: kind) }
    private var widgetType: WidgetType { kind.widgetType }
    private var isAdded: Bool { viewModel.isWidgetVisible(widgetType) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    previewBox
                    chipsRow
                    explanationBlock
                    sizeSegmented
                    if !isAdded { addToPanelCTA }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle(content.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(
                        systemName: "xmark",
                        label: L10n.Accessibility.close
                    ) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { selectedSize = viewModel.widgetSize(widgetType) }
        .onChange(of: selectedSize) { _, new in
            viewModel.setWidgetSize(widgetType, size: new)
        }
    }

    @ViewBuilder
    private var previewBox: some View {
        previewContent(selectedSize)
            .environment(\.isWidgetPreviewMode, true)
            .environment(appPreferences)
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(.regularMaterial)
            )
    }

    @ViewBuilder
    private var chipsRow: some View {
        FlowLayout(spacing: DS.Spacing.sm) {
            ForEach(content.chips) { chip in
                WidgetInfoChipView(chip: chip)
            }
        }
    }

    @ViewBuilder
    private var explanationBlock: some View {
        Text(content.explanation)
            .font(DS.Typography.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var sizeSegmented: some View {
        let supported = widgetType.supportedSizes
        if supported.count > 1 {
            Picker(selection: $selectedSize) {
                ForEach(supported, id: \.self) { size in
                    Text(sizeLabel(size)).tag(size)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var addToPanelCTA: some View {
        YalaPrimaryButton(L10n.Panel.WidgetInfo.addToPanel, icon: "plus") {
            viewModel.addWidgetToPanel(widgetType)
            dismiss()
        }
    }

    private func sizeLabel(_ size: WidgetSize) -> String {
        switch size {
        case .small:  return L10n.Panel.WidgetSize.small
        case .medium: return L10n.Panel.WidgetSize.medium
        case .large:  return L10n.Panel.WidgetSize.large
        }
    }
}
