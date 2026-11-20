//
//  OfertaProBeneficiosCard.swift
//  Yala
//
//  La tarjeta de la oferta Pro de Primeros pasos (opción A de Jürgen, 20-nov-2026): cuatro bloques que cubren las ocho
//  puertas Pro y, como última fila, «Ver todos los beneficios ›». Va justa en el iPhone SE: las filas llevan 6 pt de
//  aire vertical (medido en la maqueta: el plan mensual acaba en 600 pt y el botón fijo empieza en 605). Si se agranda
//  algo, se vuelve a medir allí.
//

import SwiftUI

struct OfertaProBeneficiosCard: View {
    let onSeeAll: () -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let counts = OfertaProBeneficiosLogic.counts()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(OfertaProBeneficiosLogic.Block.allCases.enumerated()), id: \.element) { index, block in
                blockRow(block)
                    .padding(.vertical, DS.Spacing.xs + DS.Spacing.xxs)
                if index < OfertaProBeneficiosLogic.Block.allCases.count - 1 {
                    Divider().padding(.leading, dynamicTypeSize.isAccessibilitySize ? 0 : 44)
                }
            }
            Divider()
            seeAllLink
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("setup_offer_features")
    }

    /// Icono en ficha de color, título y detalle. A tamaños de accesibilidad el icono va encima: a la izquierda le quita
    /// ancho al texto (medido en la maqueta a AX3).
    @ViewBuilder
    private func blockRow(_ block: OfertaProBeneficiosLogic.Block) -> some View {
        let detail = block.detail(counts)
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    OfertaProIconTile(block: block)
                    blockText(block.title, detail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: DS.Spacing.md) {
                    OfertaProIconTile(block: block)
                    blockText(block.title, detail)
                    Spacer(minLength: 0)
                }
            }
        }
        // Cada bloque se lee como un elemento: «Anota sin teclear. Dictando, o con una foto, captura o PDF».
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(block.title). \(detail)")
        .accessibilityIdentifier("setup_offer_block_\(block)")
    }

    private func blockText(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(title)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.thPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var seeAllLink: some View {
        Button(action: onSeeAll) {
            HStack(spacing: DS.Spacing.xs) {
                Text(OfertaProBeneficiosText.seeAll)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .font(DS.Typography.subheadlineEmphasized)
            .foregroundStyle(theme.accentText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("setup_offer_see_all")
    }
}

/// La ficha de color de cada bloque.
private struct OfertaProIconTile: View {
    let block: OfertaProBeneficiosLogic.Block

    @ScaledMetric(relativeTo: .subheadline) private var side: CGFloat = 32 // A11Y-DT: @ScaledMetric

    // A11Y-DM: paleta decorativa por función, la de `ProIncludedGrid` (rellenos con un glifo blanco, sin texto encima)
    private var color: Color {
        switch block {
        case .capture: .hotPink
        case .ai: .electricIndigo
        case .limits: .blue
        case .style: .orange
        }
    }

    var body: some View {
        Image(systemName: block.icon)
            .font(DS.Typography.caption.weight(.semibold))
            .foregroundStyle(.white)
            // Techo de 56 pt: a AX5 la ficha llegaba a ~90 y empujaba el texto (medido en el 17 Pro).
            .frame(width: min(side, 56), height: min(side, 56))
            .background(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous).fill(color))
            .accessibilityHidden(true)
    }
}
