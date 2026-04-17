//
//  FinancialScoreView.swift
//  Yala
//
//  Panel 2.0 "Salud Financiera" card. Lives inside a `.solidCard()` like every
//  other Panel widget. Tap the big ring → opens the `.total` sheet. Tap a
//  mini-ring → opens the matching sheet whose CTA navigates to Budgets,
//  Records, or Scheduled Payments. Placeholder "—" states still open the
//  sheet; the CTA just switches to "Create my first …".
//

import SwiftUI

struct FinancialScoreView: View {
    let score: FinancialScore
    let viewModel: PanelViewModel
    let sessionState: SessionState

    // A11Y-DT: ring diameters scale with Dynamic Type. Hardcoded defaults are
    // the baseline at default text size.
    @ScaledMetric(relativeTo: .largeTitle) private var mainRingSize: CGFloat = 110
    @ScaledMetric(relativeTo: .body) private var miniRingSize: CGFloat = 44

    @State private var presentedSheet: FinancialScoreDetailKind? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            header
            bodyContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .solidCard(padding: DS.Spacing.xl)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voiceoverLabel)
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
        HStack(alignment: .center, spacing: DS.Spacing.sm) {
            Text(L10n.Panel.Health.cardTitle)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Button {
                presentedSheet = .total
            } label: {
                Image(systemName: "info.circle")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Panel.Health.totalSheetTitle)

            Spacer()
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
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(score.total == nil ? DS.Semantic.disabledForeground : Color.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var subScoreStack: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            subScoreRow(kind: .budget,   value: score.budget,   label: L10n.Panel.Health.subScoreBudget)
            subScoreRow(kind: .activity, value: score.activity, label: L10n.Panel.Health.subScoreActivity)
            subScoreRow(kind: .bills,    value: score.bills,    label: L10n.Panel.Health.subScoreBills)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func subScoreRow(
        kind: FinancialScoreDetailKind,
        value: Int?,
        label: String
    ) -> some View {
        Button {
            presentedSheet = kind
        } label: {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    ScoreRingView(
                        progress: value.map { Double($0) / 100.0 } ?? 0,
                        size: miniRingSize,
                        lineWidth: miniRingSize * 0.14,
                        foreground: value == nil
                            ? AnyShapeStyle(DS.Semantic.disabledForeground.opacity(0.35))
                            : AnyShapeStyle(kind.tint ?? .indigo)
                    )
                    Text(value.map { "\($0)" } ?? L10n.Panel.Health.emptyBadge)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(value == nil ? DS.Semantic.disabledForeground : Color.primary)
                }
                Text(label)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        if score.total == nil {
            return AnyShapeStyle(DS.Semantic.disabledForeground.opacity(0.4))
        }
        return AnyShapeStyle(LinearGradient(
            colors: DS.Gradients.heroFor(score: score.total),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ))
    }

    private var voiceoverLabel: String {
        let dash = L10n.Panel.Health.emptyBadge
        return L10n.Panel.Health.voiceoverSummary(
            total: score.total.map { "\($0)" } ?? dash,
            budget: score.budget.map { "\($0)" } ?? dash,
            activity: score.activity.map { "\($0)" } ?? dash,
            bills: score.bills.map { "\($0)" } ?? dash
        )
    }
}
