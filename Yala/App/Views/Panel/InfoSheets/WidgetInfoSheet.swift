//
//  WidgetInfoSheet.swift
//  Yala
//
//  Sheet pedagógica para widgets del Panel. El draft de tamaño se aplica al
//  ViewModel SOLO si el usuario confirma con el check del toolbar; cerrar
//  con X o gesto descarta el draft sin persistir.
//

import SwiftUI

struct WidgetInfoSheet<Preview: View>: View {
    let kind: WidgetInfoKind
    let viewModel: PanelViewModel
    @ViewBuilder let previewContent: (WidgetSize) -> Preview

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    @State private var draftSize: WidgetSize = .small
    @State private var initialSize: WidgetSize = .small
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
            .navigationTitle(kind.title)
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
                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(
                        systemName: "checkmark",
                        label: L10n.Action.done
                    ) {
                        persistDraftToViewModel()
                        dismiss()
                    }
                    .disabled(draftSize == initialSize)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            // Capturar el tamaño actual del VM en el primer mount; los cambios
            // subsecuentes del segmented mutan `draftSize` localmente y solo se
            // persisten al VM si el usuario confirma con el botón check.
            if !didLoadInitialSize {
                let current = viewModel.widgetSize(widgetType)
                draftSize = current
                initialSize = current
                didLoadInitialSize = true
            }
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
    /// `.allowsHitTesting(false)` aplicado aquí centraliza el invariante
    /// "preview no acepta gestos" — sin esto, taps en burbujas/filas/segmentos
    /// del preview filtrarían el Panel real por debajo. Los call-sites en
    /// `PanelWidgetSection` no necesitan repetirlo.
    /// El alto se calibra por kind via `WidgetInfoKind.previewBoxHeight` para
    /// que pies/tops large no se aprieten dentro del frame.
    @ViewBuilder
    private var previewBox: some View {
        let isSmall = draftSize == .small
        let smallWidth = max(0, contentWidth * 0.5)
        ZStack {
            previewContent(draftSize)
                .environment(\.isWidgetPreviewMode, true)
                .environment(appPreferences)
                .frame(width: isSmall && smallWidth > 0 ? smallWidth : nil)
                .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity)
        .frame(height: kind.previewBoxHeight)
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

    private func persistDraftToViewModel() {
        guard didLoadInitialSize else { return }
        viewModel.setWidgetSize(widgetType, size: draftSize)
    }
}
