//
//  FinancialScoreView.swift
//  Yala
//

import SwiftUI

struct FinancialScoreView: View {
    let score: FinancialScore
    let sessionState: SessionState
    /// Subtítulo opcional bajo el título de la card. Se usa en Resumen para
    /// dejar claro que el score siempre refleja el mes en curso, aún cuando
    /// el selector de periodo de la pestaña esté en otro rango. Panel no lo
    /// necesita porque allí no hay selector encima de la card.
    var subtitle: String? = nil

    /// Oculta el header interno (título + subtítulo + botón help) para que el
    /// callsite pueda dibujar el título fuera de la card (consistente con el
    /// resto de section headers en Insights / Stats).
    var hideHeader: Bool = false

    // A11Y-DT: ring diameter scales with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var mainRingSize: CGFloat = 88

    @State private var presentedSheet: FinancialScoreDetailKind? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            if !hideHeader { header }
            bodyContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .solidCard(padding: DS.Spacing.xl, radius: DS.Panel.widgetRadius)
        .sheet(item: $presentedSheet) { kind in
            FinancialScoreDetailSheet(
                kind: kind,
                score: score(for: kind),
                onPrimaryCTA: primaryCTA(for: kind)
            )
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack(alignment: .center, spacing: DS.Spacing.sm) {
                Text(L10n.Panel.Health.cardTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Button {
                    presentedSheet = .total
                } label: {
                    Image(systemName: "questionmark")
                        .font(DS.Typography.captionSmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.primary)
                        .frame(width: DS.Panel.widgetAccessorySize, height: DS.Panel.widgetAccessorySize)
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Panel.Health.totalSheetTitle)

                Spacer()
            }

            if let subtitle {
                Text(subtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Body

    @ViewBuilder
    private var bodyContent: some View {
        HStack(alignment: .center, spacing: DS.Spacing.xl) {
            mainRingButton
            subScoreStack
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var mainRingButton: some View {
        Button {
            presentedSheet = .total
        } label: {
            ZStack {
                ScoreRingView(
                    progress: (score.total.map { Double($0) / 100.0 }) ?? 0,
                    size: mainRingSize,
                    lineWidth: mainRingSize * 0.1,
                    foreground: mainRingForeground
                )
                Text(score.total.map { "\($0)" } ?? L10n.Panel.Health.emptyBadge)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(score.total == nil ? DS.Semantic.disabledForeground : Color.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mainRingAccessibilityLabel)
    }

    @ViewBuilder
    private var subScoreStack: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SubScoreBarRow(
                value: score.budget,
                label: L10n.Panel.Health.subScoreBudget
            ) { presentedSheet = .budget }

            SubScoreBarRow(
                value: score.activity,
                label: L10n.Panel.Health.subScoreActivity
            ) { presentedSheet = .activity }

            SubScoreBarRow(
                value: score.bills,
                label: L10n.Panel.Health.subScoreBills
            ) { presentedSheet = .bills }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func score(for kind: FinancialScoreDetailKind) -> Int? {
        switch kind {
        case .total:    return score.total
        case .budget:   return score.budget
        case .activity: return score.activity
        case .bills:    return score.bills
        }
    }

    private func primaryCTA(for kind: FinancialScoreDetailKind) -> (() -> Void)? {
        switch kind {
        case .total:
            return nil
        case .budget:
            return { sessionState.navigateToBudgets() }
        case .activity:
            return { sessionState.navigateToRecordsStandalone() }
        case .bills:
            return { sessionState.navigateToScheduledPayments() }
        }
    }

    private var mainRingForeground: AnyShapeStyle {
        guard let total = score.total else {
            return AnyShapeStyle(DS.Semantic.disabledForeground.opacity(0.4))
        }
        return AnyShapeStyle(LinearGradient(
            colors: panoramaGradientColors(score: total),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ))
    }

    private var mainRingAccessibilityLabel: String {
        let title = L10n.Panel.Health.totalSheetTitle
        if let total = score.total {
            return "\(title), \(L10n.Panel.Health.scoreVoiceover(score: total))"
        }
        return "\(title), \(L10n.Panel.Health.noData)"
    }
}

// MARK: - SubScoreBarRow

private struct SubScoreBarRow: View {
    let value: Int?
    let label: String
    let onTap: () -> Void

    @State private var barWidth: CGFloat = 0

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(label)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: DS.Spacing.sm) {
                    barTrack

                    Text(value.map { "\($0)" } ?? L10n.Panel.Health.emptyBadge)
                        .font(DS.Typography.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(
                            value == nil ? DS.Semantic.disabledForeground : Color.primary
                        )
                        .frame(minWidth: 32, alignment: .trailing)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: Bar

    private var barTrack: some View {
        Capsule()
            .fill(Color.primary.opacity(0.05))
            .frame(height: 8)
            .overlay(alignment: .leading) {
                if let value {
                    Capsule()
                        .fill(LinearGradient(
                            colors: panoramaGradientColors(score: value),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: fillWidth(for: value), height: 8)
                }
            }
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { barWidth = $0 }
            .frame(maxWidth: .infinity)
    }

    private func fillWidth(for value: Int) -> CGFloat {
        let clamped = CGFloat(max(0, min(value, 100)))
        return max(8, barWidth * clamped / 100)
    }

    // MARK: A11y

    private var accessibilityLabel: String {
        if let value {
            return "\(label), \(L10n.Panel.Health.scoreVoiceover(score: value))"
        }
        return "\(label), \(L10n.Panel.Health.noData)"
    }
}

// MARK: - Shared gradient

/// End-color pivots on 50–100: 100 → indigo, 75 → 50/50 mix, ≤50 → pink.
/// The composite score rarely dips below 50 thanks to its soft floor.
private func panoramaGradientColors(score: Int) -> [Color] {
    let clamped = max(50, min(100, score))
    let t = Double(100 - clamped) / 50
    let endColor = Color.indigo.mix(with: .pink, by: t)
    return [.indigo, endColor]
}
