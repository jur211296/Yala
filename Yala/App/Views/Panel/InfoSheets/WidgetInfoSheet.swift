//
//  WidgetInfoSheet.swift
//  Yala
//
//  Sheet pedagógica para widgets del Panel. El draft de tamaño se persiste
//  al ViewModel al cerrar (botón xmark o gesto de dismiss).
//

import SwiftUI

/// Alto fijo del previewBox — calibrado al alto del widget más alto del kind.
/// Las 3 sizes ocupan el mismo espacio para evitar salto visual al cambiar
/// el segmented; small queda centrado verticalmente dentro del frame.
private let previewBoxHeight: CGFloat = 280

struct WidgetInfoSheet<Preview: View>: View {
    let kind: WidgetInfoKind
    let viewModel: PanelViewModel
    @ViewBuilder let previewContent: (WidgetSize) -> Preview

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    @State private var draftSize: WidgetSize = .small
    @State private var didLoadInitialSize = false
    @State private var contentWidth: CGFloat = 0

    private var content: WidgetInfoContent { .content(for: kind) }
    private var widgetType: WidgetType { kind.widgetType }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    sizeSegmented
                    previewBox
                    chipsRow
                    sectionsBlock
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.lg)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width in
                    contentWidth = width
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(.thBackground)
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

    /// Small se renderiza al ~50% del ancho disponible para emular la
    /// apariencia half-pair del grid del Panel; medium/large ocupan ancho
    /// completo.
    @ViewBuilder
    private var previewBox: some View {
        let isSmall = draftSize == .small
        let smallWidth = max(0, contentWidth * 0.5)
        ZStack {
            previewContent(draftSize)
                .environment(\.isWidgetPreviewMode, true)
                .environment(appPreferences)
                .frame(width: isSmall && smallWidth > 0 ? smallWidth : nil)
        }
        .frame(maxWidth: .infinity)
        .frame(height: previewBoxHeight)
    }

    @ViewBuilder
    private var chipsRow: some View {
        FlowLayout(spacing: DS.Spacing.sm) {
            ForEach(content.chips(draftSize)) { chip in
                WidgetInfoChipView(chip: chip)
            }
        }
    }

    @ViewBuilder
    private var sectionsBlock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            ForEach(content.sections(draftSize)) { section in
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(section.question)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(section.answer)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func sizeLabel(_ size: WidgetSize) -> String {
        switch size {
        case .small:  return L10n.Panel.WidgetSize.small
        case .medium: return L10n.Panel.WidgetSize.medium
        case .large:  return L10n.Panel.WidgetSize.large
        }
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
