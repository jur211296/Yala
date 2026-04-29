//
//  WidgetInfoSheet.swift
//  Yala
//
//  Sheet pedagógica interactiva para widgets del Panel. Muestra una preview
//  reactiva de la gráfica (con sample data o real), chips descriptores,
//  segmented S/M/L (que muta `@State` local y aplica al VM al cerrar) y
//  explicación brand-voice que varía según el tamaño seleccionado.
//
//  Patrón derivado de `FinancialScoreDetailSheet`: NavigationStack + xmark
//  toolbar + large detent + ScrollView con secciones apiladas.
//

import SwiftUI

struct WidgetInfoSheet<Preview: View>: View {
    let kind: WidgetInfoKind
    let viewModel: PanelViewModel
    @ViewBuilder let previewContent: (WidgetSize) -> Preview

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    @State private var draftSize: WidgetSize = .small
    @State private var didLoadInitialSize = false

    private var content: WidgetInfoContent { .content(for: kind) }
    private var widgetType: WidgetType { kind.widgetType }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    previewBox
                    chipsRow
                    sizeSegmented
                    explanationBlock
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
                        applyDraftAndDismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            // Solo capturar el tamaño actual del VM en el primer mount; los
            // cambios subsecuentes del segmented mutan `draftSize` localmente
            // y se persisten en el VM al cerrar la sheet.
            if !didLoadInitialSize {
                draftSize = viewModel.widgetSize(widgetType)
                didLoadInitialSize = true
            }
        }
        .onDisappear {
            // Safety net: si la sheet se dismissa por gesto/swipe (no botón),
            // igual aplicamos el draft al VM real. Idempotente — si ya se aplicó
            // vía `applyDraftAndDismiss`, el guard de `setWidgetSize` lo no-opa.
            persistDraftToViewModel()
        }
    }

    @ViewBuilder
    private var previewBox: some View {
        previewContent(draftSize)
            .environment(\.isWidgetPreviewMode, true)
            .environment(appPreferences)
            .frame(maxWidth: .infinity)
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
        Text(explanationFor(draftSize))
            .font(DS.Typography.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var sizeSegmented: some View {
        let supported = widgetType.supportedSizes
        if supported.count > 1 {
            Picker(selection: $draftSize) {
                ForEach(supported, id: \.self) { size in
                    Text(sizeLabel(size)).tag(size)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
        }
    }

    private func sizeLabel(_ size: WidgetSize) -> String {
        switch size {
        case .small:  return L10n.Panel.WidgetSize.small
        case .medium: return L10n.Panel.WidgetSize.medium
        case .large:  return L10n.Panel.WidgetSize.large
        }
    }

    /// Resuelve la explicación pedagógica para el tamaño actual. Cada tamaño
    /// tiene un layout distinto (small = compacto KPI; medium/large = chart
    /// completo con interacciones), por eso la copy varía.
    private func explanationFor(_ size: WidgetSize) -> String {
        content.explanation(size)
    }

    private func applyDraftAndDismiss() {
        persistDraftToViewModel()
        dismiss()
    }

    private func persistDraftToViewModel() {
        guard didLoadInitialSize else { return }
        viewModel.setWidgetSize(widgetType, size: draftSize)
    }
}
