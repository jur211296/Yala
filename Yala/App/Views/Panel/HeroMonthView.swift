//
//  HeroMonthView.swift
//  Yala
//
//  Panel 2.0 "Hero del mes" (P20-04). Sits at the top of the Panel scroll and
//  replaces the old static "Panel de Jür" title with a warm, state-driven
//  greeting that tells the user where they stand for the current month.
//
//  Visual shape — **loose, no card, no gradient background**:
//    • Chip line: SF Symbol (sparkles / eyes / figure.strengthtraining)
//      tinted by the month's state + "Hola, <name>" greeting, optional
//      contextual suffix.
//    • Large KPI line with the empathetic message.
//    • Secondary one-liner with the concrete numbers.
//    • Three pills underneath: Income · Spent · Days remaining.
//
//  The state is the ONLY visual cue of Panel 2.0 palette (purple/pink/blue/
//  cyan) — it lives inside the chip icon tint. Everything else uses
//  semantic foreground colors so the hero blends with the Panel background
//  in light + dark mode.
//
//  Amounts use `YalaFormatter.currency(...)`, which respects the user's
//  profile preferences for decimal places and symbol vs. code.
//

import SwiftUI

struct HeroMonthView: View {
    let data: HeroMonthData
    let currencyCode: String
    let activeKPIs: [HeroKPI]
    let onEditTapped: () -> Void

    /// `YalaFormatter.currency` reads `decimalPlaces` and
    /// `currencyDisplayFormat` straight from `UserDefaults`, which leaves
    /// SwiftUI blind to changes. Reading the @Observable props inside *this*
    /// view's body (see `body` below) registers them as dependencies so the
    /// hero rebuilds the instant the user tweaks Profile → Personalización.
    /// We observe here (the leaf) rather than at `PanelHeroSection` because
    /// SwiftUI does Equatable-diffing on the child's inputs and would
    /// otherwise skip the rebuild. Also the source of truth for `userName`
    /// (used in chip greetings).
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        // Touch the formatter-related prefs so this view re-evaluates when
        // they change. Keep `let _ = …` form — a plain `_ = …` returns
        // `Void` and breaks `@ViewBuilder`.
        let _ = appPreferences.decimalPlaces
        let _ = appPreferences.currencyDisplayFormat

        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            chip
            kpi
            subtext
            pills
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(padding: DS.Card.padding)
        // Edit button floats OUTSIDE the solidCard padding — the card modifier
        // already handles its own inner padding, so anchoring the overlay to
        // the card's top-trailing edge avoids having to subtract anything.
        // Pattern matches `AccountCardView`: glass-circle with a sliders icon.
        .overlay(alignment: .topTrailing) { editButton }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(voiceoverLabel)
    }

    // MARK: - Edit button (P20-04b)

    /// Anchored to `.topTrailing` of the card with padding symmetric to the
    /// chip line inside the card: the chip sits at `DS.Card.padding` from
    /// top-leading, so the button sits at `DS.Card.padding` from top-trailing.
    /// Bumped from `labelTiny` / `xs` to `body` / `sm` for a more comfortable
    /// tap target and visual weight.
    private var editButton: some View {
        Button(action: onEditTapped) {
            Image(systemName: "slider.horizontal.3")
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
                .padding(DS.Spacing.sm)
                .glassEffect(.regular.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
        .padding(DS.Card.padding)
        .accessibilityLabel(L10n.Panel.Hero.KpiPrefs.editButton)
    }

    // MARK: - Chip

    @ViewBuilder
    private var chip: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: chipIcon)
                .font(DS.Typography.label)
                .foregroundStyle(stateTint)
            Text(chipText)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - KPI & subtext

    private var kpi: some View {
        Text(kpiText)
            .font(DS.Typography.largeTitle)
            .foregroundStyle(.primary)
            .minimumScaleFactor(0.5)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var subtext: some View {
        Text(subtextText)
            .font(DS.Typography.body)
            .foregroundStyle(.secondary)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Pills

    @ViewBuilder
    private var pills: some View {
        if !activeKPIs.isEmpty {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(activeKPIs, id: \.self) { kpi in
                    pill(for: kpi)
                }
            }
            .padding(.top, DS.Spacing.xs)
        }
    }

    /// Renders a pill for a given KPI, pulling its value from `data` (the
    /// calculator packages all 6 via stored + computed vars). `daysLeft` is
    /// the only non-currency value — everything else goes through
    /// `YalaFormatter.currency` and therefore respects Profile →
    /// Personalización.
    private func pill(for kpi: HeroKPI) -> some View {
        let value: String = {
            switch kpi {
            case .income:        return formattedAmount(data.income)
            case .spent:         return formattedAmount(data.expense)
            case .daysLeft:      return "\(data.daysRemaining)"
            case .available:     return formattedAmount(data.available)
            case .dailyAverage:  return formattedAmount(data.dailyAverage)
            case .projection:    return formattedAmount(data.projection)
            }
        }()
        return pill(label: kpi.pillLabel, value: value)
    }

    private func pill(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(label)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(DS.Typography.amountSmall)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            Color.primary.opacity(0.06),
            in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
        )
    }

    // MARK: - State → color accent

    /// Single surviving trace of the Panel 2.0 palette — tints the chip icon.
    /// Each state picks the leading color of its former gradient.
    private var stateTint: Color {
        switch data.state {
        case .monthStart:  return .cyan
        case .onTrack:     return .indigo
        case .neutral:     return .purple
        case .tight:       return .hotPink
        // Brand voice: `overBudget` does NOT escalate visually. Same tint as
        // neutral so we say "let's keep going", not "you failed".
        case .overBudget:  return .purple
        }
    }

    private var chipIcon: String {
        switch data.state {
        case .monthStart, .onTrack, .neutral: return "sparkles"
        case .tight:                          return "eyes"
        case .overBudget:                     return "figure.strengthtraining.traditional"
        }
    }

    // MARK: - State → copy

    private var chipText: String {
        let userName = appPreferences.userName
        switch data.state {
        case .monthStart:  return L10n.Panel.Hero.chipMonthStart(userName: userName, month: monthLabel)
        case .onTrack:     return L10n.Panel.Hero.chipOnTrack(userName: userName)
        case .neutral:     return L10n.Panel.Hero.chipNeutral(userName: userName)
        case .tight:       return L10n.Panel.Hero.chipTight(userName: userName)
        case .overBudget:  return L10n.Panel.Hero.chipOverBudget(userName: userName)
        }
    }

    /// Locale-aware full month name, capitalised per locale
    /// ("abril" → "Abril" in ES/PT/IT/FR, "April" in EN/DE). Cached so we
    /// don't re-instantiate `DateFormatter` on every render of the Panel.
    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "MMMM"
        return f
    }()

    private var monthLabel: String {
        Self.monthFormatter.string(from: .now).localizedCapitalized
    }

    private var kpiText: String {
        switch data.state {
        case .monthStart:  return L10n.Panel.Hero.kpiMonthStart
        case .onTrack:     return L10n.Panel.Hero.kpiOnTrack
        case .neutral:     return L10n.Panel.Hero.kpiNeutral
        case .tight:       return L10n.Panel.Hero.kpiTight
        case .overBudget:  return L10n.Panel.Hero.kpiOverBudget
        }
    }

    /// Contextual one-liner below the KPI. **This is the insertion point
    /// for P20-05 (Hero IA, Pro)**: the IA service will replace this string
    /// with a cached (24h) LLM message for Pro users, and fall back to this
    /// rule-based version when the cache is empty or the user is Free.
    /// Keep the 5 rule-based copies as a stable fallback contract.
    private var subtextText: String {
        switch data.state {
        case .monthStart:
            return L10n.Panel.Hero.subtextMonthStart(daysRemaining: data.daysRemaining)
        case .onTrack:
            return L10n.Panel.Hero.subtextOnTrack(
                spent: formattedAmount(data.expense),
                daysRemaining: data.daysRemaining
            )
        case .neutral:
            return L10n.Panel.Hero.subtextNeutral(
                spent: formattedAmount(data.expense),
                available: formattedAmount(max(0, data.income - data.expense))
            )
        case .tight:
            return L10n.Panel.Hero.subtextTight
        case .overBudget:
            return L10n.Panel.Hero.subtextOverBudget
        }
    }

    // MARK: - Formatting

    /// Uses the shared `YalaFormatter.currency` helper so income/expense
    /// follow the user's preferences for decimal places and symbol vs. code
    /// (Profile → Personalización).
    private func formattedAmount(_ value: Double) -> String {
        YalaFormatter.currency(value: value, currencyCode: currencyCode)
    }

    private var voiceoverLabel: String {
        "\(chipText). \(kpiText). \(subtextText)"
    }
}

// MARK: - Preview

#Preview("States") {
    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
        HeroMonthView(
            data: HeroMonthData(
                state: .monthStart, income: 0, expense: 0,
                daysRemaining: 28, daysElapsed: 2
            ),
            currencyCode: "PEN",
            activeKPIs: Array(HeroKPI.defaultOrder.prefix(3)),
            onEditTapped: {}
        )
        HeroMonthView(
            data: HeroMonthData(
                state: .onTrack, income: 4500, expense: 900,
                daysRemaining: 20, daysElapsed: 10
            ),
            currencyCode: "PEN",
            activeKPIs: Array(HeroKPI.defaultOrder.prefix(3)),
            onEditTapped: {}
        )
        HeroMonthView(
            data: HeroMonthData(
                state: .neutral, income: 4500, expense: 1500,
                daysRemaining: 20, daysElapsed: 10
            ),
            currencyCode: "PEN",
            activeKPIs: Array(HeroKPI.defaultOrder.prefix(3)),
            onEditTapped: {}
        )
        HeroMonthView(
            data: HeroMonthData(
                state: .tight, income: 4500, expense: 3700,
                daysRemaining: 6, daysElapsed: 24
            ),
            currencyCode: "PEN",
            activeKPIs: Array(HeroKPI.defaultOrder.prefix(3)),
            onEditTapped: {}
        )
        HeroMonthView(
            data: HeroMonthData(
                state: .overBudget, income: 4500, expense: 4800,
                daysRemaining: 3, daysElapsed: 27
            ),
            currencyCode: "PEN",
            activeKPIs: Array(HeroKPI.defaultOrder.prefix(3)),
            onEditTapped: {}
        )
    }
    .padding()
    .environment(AppPreferences(defaults: .standard))
}
