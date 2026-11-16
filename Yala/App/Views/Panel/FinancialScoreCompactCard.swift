//
//  FinancialScoreCompactCard.swift
//  Yala
//
//  La nota de salud en «Tus finanzas» del Panel, en una fila baja (lote 1 de la nota de salud, 11-nov-2026): la nota,
//  un mensaje breve con un paso concreto y, si la hay, la línea de lo que la nota no ve. Tocarla abre la hoja con el
//  desglose. Estadísticas › Resumen sigue con la tarjeta completa (`FinancialScoreView`).
//

import SwiftUI

struct FinancialScoreCompactCard: View {
    let score: FinancialScore
    let sessionState: SessionState
    var hasBudgets: Bool = false

    // A11Y-DT: el anillo crece con el tamaño del texto, como el de la tarjeta completa.
    @ScaledMetric(relativeTo: .title2) private var ringSize: CGFloat = 46

    @State private var showsDetail = false

    var body: some View {
        Button {
            showsDetail = true
        } label: {
            HStack(alignment: .center, spacing: DS.Spacing.md) {
                ring

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.Panel.Health.cardTitle)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.primary)
                    Text(FinancialScoreCopy.cardMessage(for: score, isExpensesOnlyMode: sessionState.isExpensesOnlyMode))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("health_compact_message")
                    if let unseen = FinancialScoreCopy.unseenLine(
                        for: score, isExpensesOnlyMode: sessionState.isExpensesOnlyMode
                    ) {
                        Text(unseen)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("health_unseen")
                    }
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .solidCard(padding: DS.Spacing.lg, radius: DS.Panel.widgetRadius)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("panel_health_compact")
        .sheet(isPresented: $showsDetail) {
            FinancialScoreDetailSheet(
                kind: .total,
                score: score.total,
                onPrimaryCTA: nil,
                breakdown: score,
                hasBudgets: hasBudgets
            )
        }
    }

    private var ring: some View {
        ZStack {
            ScoreRingView(
                progress: (score.total.map { Double($0) / 100.0 }) ?? 0,
                size: ringSize,
                lineWidth: ringSize * 0.11,
                foreground: ringForeground
            )
            Text(score.total.map { "\($0)" } ?? L10n.Panel.Health.emptyBadge)
                .font(DS.Typography.headline)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(score.total == nil ? DS.Semantic.disabledForeground : Color.primary)
                .padding(.horizontal, ringSize * 0.12)
        }
        .frame(width: ringSize, height: ringSize)
        .accessibilityLabel(ringAccessibilityLabel)
    }

    /// Relleno sólido del mismo tono que la tarjeta completa (índigo arriba, rosa abajo): nada de rojo de alarma.
    private var ringForeground: AnyShapeStyle {
        guard let total = score.total else {
            return AnyShapeStyle(DS.Semantic.disabledForeground.opacity(0.4))
        }
        return AnyShapeStyle(FinancialScoreTint.color(for: total))
    }

    private var ringAccessibilityLabel: String {
        guard let total = score.total else { return L10n.Panel.Health.noData }
        return L10n.Panel.Health.scoreVoiceover(score: total)
    }
}
