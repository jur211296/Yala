//
//  YalaScreenBackgroundPreview.swift
//  Yala
//
//  Previews para el modifier `.yalaScreenBackground(_:ignoredEdges:)`.
//  Visualiza las 3 variantes × selección de themes representativos.
//

import SwiftUI

#if DEBUG

private struct DemoCard: View {
    let label: String

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text(label)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.thPrimaryText)
            Text("Sample content")
                .font(DS.Typography.caption)
                .foregroundStyle(.thSecondaryText)
        }
        .padding(DS.Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(.thCard)
        }
    }
}

private struct VariantDemo: View {
    let variant: YalaBackgroundVariant
    let label: String

    var body: some View {
        DemoCard(label: label)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .yalaScreenBackground(variant)
    }
}

#Preview("Variants — Liquid Glass") {
    VStack(spacing: 0) {
        VariantDemo(variant: .panel, label: ".panel")
        VariantDemo(variant: .subtle, label: ".subtle")
        VariantDemo(variant: .transparent, label: ".transparent")
    }
    .environment(\.yalaTheme, .liquidGlass)
}

#Preview("Variants — Light") {
    VStack(spacing: 0) {
        VariantDemo(variant: .panel, label: ".panel")
        VariantDemo(variant: .subtle, label: ".subtle")
        VariantDemo(variant: .transparent, label: ".transparent")
    }
    .environment(\.yalaTheme, .light)
}

#Preview("Variants — Translucent Rosa") {
    VStack(spacing: 0) {
        VariantDemo(variant: .panel, label: ".panel")
        VariantDemo(variant: .subtle, label: ".subtle")
        VariantDemo(variant: .transparent, label: ".transparent")
    }
    .environment(\.yalaTheme, .translucentRosa)
}

#Preview("Variants — Dark") {
    VStack(spacing: 0) {
        VariantDemo(variant: .panel, label: ".panel")
        VariantDemo(variant: .subtle, label: ".subtle")
        VariantDemo(variant: .transparent, label: ".transparent")
    }
    .environment(\.yalaTheme, .dark)
}

/// Sanity: variante `.panel` con `ignoredEdges: [.top]` debería respetar
/// el inset bottom de un FAB stack hipotético.
#Preview("Edge cases — ignoredEdges") {
    DemoCard(label: "ignoredEdges: [.top]")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            Text("Bottom safe area inset (FAB simulado)")
                .font(DS.Typography.caption)
                .padding(DS.Spacing.md)
                .frame(maxWidth: .infinity)
                .background(.thCard)
        }
        .yalaScreenBackground(.panel, ignoredEdges: [.top])
        .environment(\.yalaTheme, .liquidGlass)
}

#endif
