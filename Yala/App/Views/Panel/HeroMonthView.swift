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

    /// Mensaje IA ya resuelto (cache hit o API success). Nil ⇒ fallback
    /// rule-based inmediato, sin spinner ni flash-blank.
    var aiSubtitle: String? = nil
    var showProBadge: Bool = false
    var showUpsellCTA: Bool = false
    var onUpsellTap: () -> Void = {}

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

    /// Distingue el tema "light" (card blanca pura) del resto. En light el
    /// 6% primary de los pills lee como gris sucio sobre la card blanca;
    /// glass es la salida. En temas con card teñida/oscura ese 6% se ve
    /// limpio, así que se conserva.
    @Environment(\.yalaTheme) private var theme

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
            if showUpsellCTA { upsellCTA }
            pills
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(padding: DS.Card.padding)
        // Edit button + badge Pro en un único overlay topTrailing — evita
        // chocar con el saludo del chip en topLeading.
        .overlay(alignment: .topTrailing) {
            HStack(spacing: DS.Spacing.xs) {
                if showProBadge { proBadge }
                editButton
            }
            .padding(DS.Card.padding)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(voiceoverLabel)
    }

    // MARK: - Pro badge

    private var proBadge: some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: "sparkles")
                .font(DS.Typography.captionSmall)
            Text(L10n.Panel.Hero.proBadge)
                .font(DS.Typography.captionSmall)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .glassEffect(.regular, in: Capsule())
        .accessibilityLabel(L10n.Panel.Hero.proBadge)
    }

    // MARK: - Upsell CTA (Free)

    /// Chip con el gradient `proBadge` (yellow→orange) en el sparkle —
    /// misma paleta Pro que `ProBadge`/`FABStackView`/`MilestoneUpgradeSheet`
    /// para reforzar que el CTA lleva a upgrade. Texto `.primary` para
    /// legibilidad.
    private var upsellCTA: some View {
        HStack {
            Button(action: onUpsellTap) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "sparkle")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(
                            LinearGradient(
                                colors: DS.Gradients.proBadge,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(L10n.Panel.Hero.upsellCTA)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .glassEffect(.regular.interactive(), in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .onAppear {
            TelemetryService.trackOnce(.panelHeroCTAImpression, key: Self.telemetryKey)
        }
    }

    private static let telemetryKey = "panelHero"

    // MARK: - Edit button

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
            // Evita el flash rule-based → IA cuando el VM resuelve el
            // mensaje tras ~1s.
            .animation(.easeInOut(duration: 0.3), value: aiSubtitle)
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
        .modifier(HeroPillBackgroundModifier(useGlass: theme.baseColorScheme == .light))
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

    /// Si `aiSubtitle` viene cargado (Pro + consent + cache hit o API
    /// success), lo usamos. Si no, el `switch` rule-based es el fallback
    /// — Free, Pro sin consent, offline o error de API.
    private var subtextText: String {
        if let aiSubtitle, !aiSubtitle.isEmpty { return aiSubtitle }
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
        var parts: [String] = []
        if showProBadge { parts.append(L10n.Panel.Hero.proBadge) }
        parts.append(chipText)
        parts.append(kpiText)
        parts.append(subtextText)
        if showUpsellCTA { parts.append(L10n.Panel.Hero.upsellCTA) }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Pill background modifier

/// Pill background tuned per-theme. El tema "light" tiene la card en
/// blanco puro; ahí `Color.primary.opacity(0.06)` lee como gris sucio, y
/// Liquid Glass resuelve la separación visual sin ensuciar. En temas con
/// card teñida/oscura ese mismo 6% se ve limpio — mantener el look
/// original evita que Glass introduzca un brillo fuera de lugar.
private struct HeroPillBackgroundModifier: ViewModifier {
    let useGlass: Bool

    func body(content: Content) -> some View {
        if useGlass {
            content.glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
            )
        } else {
            content.background(
                Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
            )
        }
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

        // Pro + cache hit (badge visible)
        HeroMonthView(
            data: HeroMonthData(
                state: .onTrack, income: 4500, expense: 900,
                daysRemaining: 20, daysElapsed: 10
            ),
            currencyCode: "PEN",
            activeKPIs: Array(HeroKPI.defaultOrder.prefix(3)),
            onEditTapped: {},
            aiSubtitle: "Abril te está yendo bien, Jur. Llevas un ritmo tranquilo — sigue así.",
            showProBadge: true,
            showUpsellCTA: false,
            onUpsellTap: {}
        )

        // Free + CTA upsell
        HeroMonthView(
            data: HeroMonthData(
                state: .neutral, income: 4500, expense: 1500,
                daysRemaining: 20, daysElapsed: 10
            ),
            currencyCode: "PEN",
            activeKPIs: Array(HeroKPI.defaultOrder.prefix(3)),
            onEditTapped: {},
            aiSubtitle: nil,
            showProBadge: false,
            showUpsellCTA: true,
            onUpsellTap: {}
        )
    }
    .padding()
    .environment(AppPreferences(defaults: .standard))
}
