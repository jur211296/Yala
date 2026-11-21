//
//  OfertaProTodosLosBeneficiosPage.swift
//  Yala
//
//  «Qué incluye Yala Pro» (opción A de Jürgen, 20-nov-2026): la página que «Ver todos los beneficios ›» empuja dentro
//  de la hoja de la oferta. Gratis | Pro por grupos y el pie de lo que sigue gratis. No es `SubscriptionView`: aquel es
//  el paywall de Ajustes y apilaría dos pagos. La página no tiene plan propio: el botón de abajo es el de la oferta
//  (`bottomBar`), que compra el plan elegido allí, y «‹» vuelve con ese plan intacto.
//

import SwiftUI

struct OfertaProTodosLosBeneficiosPage<BottomBar: View>: View {
    /// El «Empezar mi mes gratis» de la oferta. Se construye en el `body` de la página para que repinte con la compra.
    @ViewBuilder let bottomBar: () -> BottomBar

    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private typealias P = OfertaProBeneficiosText.Page

    private let groups = OfertaProBeneficiosLogic.groups()

    /// Ancho de las columnas Gratis y Pro (las de la maqueta): caben «Sin límite» y sus traducciones en dos líneas.
    @ScaledMetric(relativeTo: .footnote) private var freeColumn: CGFloat = 64 // A11Y-DT: @ScaledMetric
    @ScaledMetric(relativeTo: .footnote) private var proColumn: CGFloat = 76 // A11Y-DT: @ScaledMetric

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if !dynamicTypeSize.isAccessibilitySize {
                    columnHeader
                }
                ForEach(groups) { group in
                    groupView(group)
                }
                Text(P.footer)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("setup_offer_all_benefits_footer")
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.sm)
            .padding(.bottom, DS.Spacing.xxl)
            .readableColumn()
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityIdentifier("setup_offer_all_benefits")
        .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) {
            bottomBar()
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)
        }
        .navigationTitle(P.title)
        .navigationBarTitleDisplayMode(.inline)
        .yalaScreenBackground(.subtle)
    }

    /// «Gratis · Pro» encima de las columnas. VoiceOver no lo lee: cada fila ya dice las dos.
    private var columnHeader: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Text(P.free)
                .frame(width: freeColumn)
            Text(P.pro)
                .foregroundStyle(theme.accentText)
                .frame(width: proColumn)
        }
        .font(DS.Typography.labelSmall)
        .foregroundStyle(.secondary)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.bottom, -DS.Spacing.sm)
        .accessibilityHidden(true)
    }

    private func groupView(_ group: OfertaProBeneficiosLogic.BenefitGroup) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(group.title)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.secondary)
                .padding(.leading, DS.Spacing.md)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
                    rowView(row)
                        .padding(.vertical, DS.Spacing.md)
                        .padding(.horizontal, DS.Spacing.md)
                        // La fila se lee entera: «Cuentas: gratis 4, Pro sin límite».
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(OfertaProBeneficiosLogic.spokenRow(row))
                        .accessibilityIdentifier("setup_offer_all_benefits_row_\(row.id)")
                    if index < group.rows.count - 1 {
                        Divider().padding(.leading, DS.Spacing.md)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
        }
    }

    /// A tamaños de accesibilidad las columnas no caben: el título arriba y «Gratis …  ·  Pro …» debajo.
    @ViewBuilder
    private func rowView(_ row: OfertaProBeneficiosLogic.Row) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(row.title)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: DS.Spacing.sm) {
                    Text(P.free).font(DS.Typography.labelSmall).foregroundStyle(.secondary)
                    mark(row.free, pro: false)
                }
                HStack(spacing: DS.Spacing.sm) {
                    Text(P.pro).font(DS.Typography.labelSmall).foregroundStyle(theme.accentText)
                    mark(row.pro, pro: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 0) {
                Text(row.title)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: DS.Spacing.sm)
                mark(row.free, pro: false).frame(width: freeColumn)
                mark(row.pro, pro: true).frame(width: proColumn)
            }
        }
    }

    @ViewBuilder
    private func mark(_ mark: OfertaProBeneficiosLogic.Mark, pro: Bool) -> some View {
        switch mark {
        case .included:
            Image(systemName: "checkmark.circle.fill")
                .font(DS.Typography.subheadline)
                .foregroundStyle(pro ? AnyShapeStyle(theme.accentText) : AnyShapeStyle(.secondary))
        case .notIncluded:
            Image(systemName: "minus")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.tertiary)
        case .count, .unlimited:
            Text(mark.spoken)
                .font(pro ? DS.Typography.labelSmall.weight(.semibold) : DS.Typography.labelSmall)
                .foregroundStyle(pro ? AnyShapeStyle(theme.accentText) : AnyShapeStyle(.secondary))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
