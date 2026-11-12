//
//  FinancialScoreDetailSheet.swift
//  Yala
//
//  Medium-detent sheet presented when the user taps any ring in the Panel 2.0
//  "Salud Financiera" card. Hero ring + headline + explanation + optional
//  navigation CTA (nil for the total — the user is already on the Panel).
//
//  Uses the app's canonical sheet chrome: NavigationStack + inline title +
//  `YalaToolbarButton` in `.topBarLeading` for close. No `.presentationBackground`
//  override — iOS 26 supplies the native glass background by default.
//

import SwiftUI

enum FinancialScoreDetailKind: String, Identifiable {
    case total
    case budget
    case activity
    case bills

    var id: String { rawValue }

    /// Color identity of each sub-score. `.total` has no fixed tint — it renders a score-driven solid tone
    /// (`FinancialScoreTint`, sin degradado desde UX 2.2 · L3-14).
    var tint: Color? {
        switch self {
        case .total:    return nil
        case .budget:   return .purple
        case .activity: return .indigo
        case .bills:    return .blue
        }
    }
}

struct FinancialScoreDetailSheet: View {
    let kind: FinancialScoreDetailKind
    /// Raw score (0–100) or `nil` for N/A / placeholder state.
    let score: Int?
    /// Called after the sheet dismisses. `nil` hides the CTA (used by `.total`).
    var onPrimaryCTA: (() -> Void)? = nil
    /// Las tres partes, para enseñar de dónde sale la nota total (UX 2.2 · L3-14). Solo la usa `.total`.
    var breakdown: FinancialScore? = nil
    /// Hay presupuestos: sin nota de presupuestos, la hoja dice que empiezan a contar el mes que viene (UX 2.2 · L3-13).
    var hasBudgets: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionState.self) private var sessionState

    @State private var selectedDetent: PresentationDetent = .medium

    // A11Y-DT: hero ring and central number scale with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 120
    @ScaledMetric(relativeTo: .largeTitle) private var centerFontSize: CGFloat = 36

    private var isLargeDetent: Bool { selectedDetent == .large }

    var body: some View {
        NavigationStack {
            // Medium usa el glass nativo del sheet iOS; large monta el gradient
            // temático para llenar la pantalla (paridad con BalanceLiveAnchorEducationSheet).
            ZStack {
                content
            }
            .yalaScreenBackground(isLargeDetent ? .subtle : .transparent)
            .navigationTitle(title)
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
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }

    // Hero + texts live inside a ScrollView so long translations never
    // truncate nor push the CTA out of sight; the CTA stays pinned below.
    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    heroRing
                        .padding(.top, DS.Spacing.lg)

                    VStack(spacing: DS.Spacing.md) {
                        headlineBlock
                        explanationBlock
                    }

                    if kind == .total, let breakdown {
                        breakdownBlock(breakdown)
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.lg)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)

            ctaBlock
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var heroRing: some View {
        let progress: Double = score.map { Double($0) / 100.0 } ?? 0
        let isEmpty = score == nil

        ZStack {
            ScoreRingView(
                progress: progress,
                size: ringSize,
                lineWidth: ringSize * 0.1,
                foreground: ringForeground
            )
            Text(centerLabel)
                .font(.system(size: centerFontSize, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(isEmpty ? DS.Semantic.disabledForeground : Color.primary)
        }
    }

    @ViewBuilder
    private var headlineBlock: some View {
        Text(headline)
            .font(DS.Typography.headline)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var explanationBlock: some View {
        Text(explanation)
            .font(DS.Typography.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var ctaBlock: some View {
        if let ctaLabel, let onPrimaryCTA {
            YalaPrimaryButton(ctaLabel, icon: "arrow.forward") {
                dismiss()
                // Let the sheet finish its dismiss animation before pushing the
                // destination — prevents the tab bar from snapping mid-transition.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(250))
                    onPrimaryCTA()
                }
            }
        }
    }

    // MARK: - Ring styling (matches the Panel card)

    private var ringForeground: AnyShapeStyle {
        if score == nil {
            return AnyShapeStyle(DS.Semantic.disabledForeground.opacity(0.4))
        }
        if let tint = kind.tint {
            return AnyShapeStyle(tint)
        }
        return AnyShapeStyle(FinancialScoreTint.color(for: score ?? 100))
    }

    // MARK: - De dónde sale la nota (UX 2.2 · L3-14)

    /// Las tres partes con su peso y su nota, y una frase de qué mejorar. Antes la hoja decía que «pesan distinto» sin
    /// decir cuánto, y Ritmo y Compromisos no se explicaban.
    private func breakdownBlock(_ breakdown: FinancialScore) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(spacing: DS.Spacing.sm) {
                partRow(
                    title: L10n.Panel.Health.subScoreBudget,
                    detail: L10n.Panel.Health.partBudget,
                    weight: FinancialScoreCalculator.weightBudget,
                    value: breakdown.budget
                )
                Divider()
                partRow(
                    title: L10n.Panel.Health.subScoreActivity,
                    detail: L10n.Panel.Health.partActivity,
                    weight: FinancialScoreCalculator.weightRhythm,
                    value: breakdown.activity
                )
                Divider()
                partRow(
                    title: L10n.Panel.Health.subScoreBills,
                    detail: L10n.Panel.Health.partBills,
                    weight: FinancialScoreCalculator.weightCommitments,
                    value: breakdown.bills
                )
            }
            .padding(DS.Spacing.md)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))

            if let improvement = improvementLine(breakdown) {
                Text(improvement)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("health_improvement_tip")
            }

            Text(L10n.Panel.Health.floorNote(FinancialScoreCalculator.totalFloor))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("health_breakdown")
    }

    private func partRow(title: String, detail: String, weight: Double, value: Int?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Panel.Health.partTitle(title, weight: Int((weight * 100).rounded())))
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DS.Spacing.sm)
            Text(value.map { "\($0)" } ?? L10n.Panel.Health.partNotCounting)
                .font(value == nil ? DS.Typography.caption : DS.Typography.headline)
                .monospacedDigit()
                .foregroundStyle(value == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    /// Sin ninguna parte con nota no hay nada que decir: «lo que ya cuenta va bien» sería falso.
    private func improvementLine(_ breakdown: FinancialScore) -> String? {
        guard breakdown.budget != nil || breakdown.activity != nil || breakdown.bills != nil else { return nil }
        switch FinancialScoreCalculator.weakestPart(of: breakdown) {
        case .budget: return L10n.Panel.Health.improveBudget
        case .activity: return L10n.Panel.Health.improveActivity
        case .bills: return L10n.Panel.Health.improveBills
        case .total, nil: return L10n.Panel.Health.improveNothing
        }
    }

    // MARK: - Derived copy

    private var title: String {
        switch kind {
        case .total:    return L10n.Panel.Health.totalSheetTitle
        case .budget:   return L10n.Panel.Health.budgetSheetTitle
        case .activity: return L10n.Panel.Health.activitySheetTitle
        case .bills:    return L10n.Panel.Health.billsSheetTitle
        }
    }

    private var explanation: String {
        switch kind {
        case .total:    return L10n.Panel.Health.totalSheetExplanation
        case .budget:   return L10n.Panel.Health.budgetSheetExplanation
        case .activity: return L10n.Panel.Health.activitySheetExplanation
        case .bills:
            // En Solo Gastos no hay ingresos: la explicación normal promete
            // "% de tus ingresos" (no medible). Variante de solo-cobertura.
            return sessionState.isExpensesOnlyMode
                ? L10n.Panel.Health.billsSheetExplanationExpensesOnly
                : L10n.Panel.Health.billsSheetExplanation
        }
    }

    private var headline: String {
        switch kind {
        case .total:
            guard let score else { return L10n.Panel.Health.totalHeadlineEmpty }
            if score >= 90 { return L10n.Panel.Health.totalHeadlineHigh }
            if score >= 70 { return L10n.Panel.Health.totalHeadlineMid }
            return L10n.Panel.Health.totalHeadlineLow
        case .budget:
            guard let score else {
                return hasBudgets ? L10n.Panel.Health.budgetHeadlineStartsNextMonth : L10n.Panel.Health.budgetHeadlineEmpty
            }
            if score >= 90 { return L10n.Panel.Health.budgetHeadlineHigh }
            if score >= 70 { return L10n.Panel.Health.budgetHeadlineMid }
            return L10n.Panel.Health.budgetHeadlineLow
        case .activity:
            guard let score else { return L10n.Panel.Health.activityHeadlineEmpty }
            if score >= 90 { return L10n.Panel.Health.activityHeadlineHigh }
            if score >= 70 { return L10n.Panel.Health.activityHeadlineMid }
            return L10n.Panel.Health.activityHeadlineLow
        case .bills:
            guard let score else { return L10n.Panel.Health.billsHeadlineEmpty }
            if score >= 90 { return L10n.Panel.Health.billsHeadlineHigh }
            if score >= 70 { return L10n.Panel.Health.billsHeadlineMid }
            return L10n.Panel.Health.billsHeadlineLow
        }
    }

    private var ctaLabel: String? {
        switch kind {
        case .total: return nil
        case .budget:
            return score == nil && !hasBudgets
                ? L10n.Panel.Health.budgetCTACreate
                : L10n.Panel.Health.budgetCTAView
        case .activity:
            return score == nil
                ? L10n.Panel.Health.activityCTACreate
                : L10n.Panel.Health.activityCTAView
        case .bills:
            return score == nil
                ? L10n.Panel.Health.billsCTACreate
                : L10n.Panel.Health.billsCTAView
        }
    }

    private var centerLabel: String {
        guard let score else { return L10n.Panel.Health.emptyBadge }
        return "\(score)"
    }
}

#if DEBUG
#Preview("Budget — high") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            FinancialScoreDetailSheet(kind: .budget, score: 92, onPrimaryCTA: {})
                .environment(SessionState.shared)
        }
}
#Preview("Activity — empty") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            FinancialScoreDetailSheet(kind: .activity, score: nil, onPrimaryCTA: {})
                .environment(SessionState.shared)
        }
}
#Preview("Total — mid") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            FinancialScoreDetailSheet(kind: .total, score: 78)
                .environment(SessionState.shared)
        }
}
#endif
