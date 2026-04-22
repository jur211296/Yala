//
//  HeroMonthView.swift
//  Yala
//
//  Hero del Panel (PP2-01). Sin card y edge-to-edge — aprovecha todo el
//  ancho del Panel. Tres secciones verticales: fila superior con el
//  saludo a tamaño `title`, el Pro badge y el `TrendsPeriodMenu`
//  alineados a la misma altura (mismo padding/font que el selector);
//  KPI protagonista (aiSubtitle LLM cuando está disponible, fallback
//  rule-based con cifras concretas en markdown bold) en `subheadline`;
//  upsellCTA opcional para usuarios Free o Pro sin consent IA.
//
//  Amounts use `YalaFormatter.currency(...)`, which respects the user's
//  profile preferences for decimal places and symbol vs. code.
//

import SwiftUI

struct HeroMonthView: View {
    let data: HeroMonthData
    let currencyCode: String
    let selectedPeriod: DetailPeriod
    let customDateRange: DateInterval?
    let onSelectPeriod: (DetailPeriod) -> Void
    let onCustomPeriodTapped: () -> Void

    /// Mensaje IA ya resuelto (cache hit o API success). Nil ⇒ fallback
    /// rule-based inmediato, sin spinner ni flash-blank.
    var aiSubtitle: String? = nil
    var showProBadge: Bool = false
    var showUpsellCTA: Bool = false
    var onUpsellTap: () -> Void = {}

    /// `YalaFormatter.currency` reads `decimalPlaces` and
    /// `currencyDisplayFormat` straight from `UserDefaults`, which leaves
    /// SwiftUI blind to changes. Reading the @Observable props inside *this*
    /// view's body registers them as dependencies so the hero rebuilds the
    /// instant the user tweaks Profile → Personalización.
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        // Touch the formatter-related prefs so this view re-evaluates when
        // they change. Keep `let _ = …` form — a plain `_ = …` returns
        // `Void` and breaks `@ViewBuilder`.
        let _ = appPreferences.decimalPlaces
        let _ = appPreferences.currencyDisplayFormat

        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            topRow
            kpi
            if showUpsellCTA { upsellCTA }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(voiceoverLabel)
    }

    // MARK: - Top row (chip + pro badge + period selector inline)

    private var topRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            chip
            Spacer(minLength: DS.Spacing.sm)
            if showProBadge { proBadge }
            TrendsPeriodMenu(
                selectedPeriod: selectedPeriod,
                customDateRange: customDateRange,
                onSelect: onSelectPeriod,
                onCustomTapped: onCustomPeriodTapped
            )
        }
    }

    private var chip: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "sparkles")
                .font(DS.Typography.title)
                .foregroundStyle(DS.Semantic.favoriteIcon)
            Text(chipText)
                .font(DS.Typography.title)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    /// Mismo font (`labelSmall`), mismo padding (`md` horizontal / `sm`
    /// vertical) y mismo `glassEffect + Capsule` que `PeriodSelectorLabel`,
    /// así el badge queda a la misma altura y pegado al selector.
    private var proBadge: some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: "sparkles")
                .font(DS.Typography.labelSmall)
            Text(L10n.Panel.Hero.proBadge)
                .font(DS.Typography.labelSmall)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .glassEffect(.regular, in: Capsule())
        .accessibilityLabel(L10n.Panel.Hero.proBadge)
    }

    // MARK: - KPI (protagonista)

    /// `subheadline` (ligeramente más grande que body) + `AttributedString
    /// (markdown:)` para que los `**montos**` en los templates rule-based
    /// se rendereen en bold. El aiSubtitle LLM puede venir sin markdown y
    /// se renderiza normal.
    private var kpi: some View {
        Text(kpiAttributedText)
            .font(DS.Typography.subheadline)
            .foregroundStyle(.primary)
            .minimumScaleFactor(0.85)
            .lineLimit(6)
            .fixedSize(horizontal: false, vertical: true)
            .animation(.easeInOut(duration: 0.3), value: aiSubtitle)
    }

    /// Parsea markdown (`**bold**`) si aplica; cae al string plano cuando
    /// el parser no puede (aiSubtitle ya viene sin markdown en producción).
    private var kpiAttributedText: AttributedString {
        let raw = kpiText
        if let parsed = try? AttributedString(markdown: raw) {
            return parsed
        }
        return AttributedString(raw)
    }

    // MARK: - Upsell CTA

    /// Visible cuando no hay aiSubtitle y el user aún puede "desbloquearlo"
    /// (Free → upgrade sheet; Pro sin consent → alert que activa el consent).
    /// La decisión de destino vive en `PanelHeroSection`.
    private var upsellCTA: some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            TelemetryService.trackOnce(.panelHeroCTAImpression, key: Self.telemetryKey)
        }
    }

    private static let telemetryKey = "panelHero"

    // MARK: - Copy

    private var chipText: String {
        let userName = appPreferences.userName
        if data.state == .monthStart {
            return L10n.Panel.Hero.chipMonthStart(userName: userName, month: monthLabel)
        }
        return L10n.Panel.Hero.chipDefault(userName: userName)
    }

    /// SSOT del KPI: LLM cuando disponible, fallback rule-based con cifras
    /// concretas (income, spent, available, days) y montos en bold markdown.
    private var kpiText: String {
        if let aiSubtitle, !aiSubtitle.isEmpty { return aiSubtitle }
        let income = formattedAmount(data.income)
        let spent = formattedAmount(data.expense)
        let available = formattedAmount(data.available)
        switch data.state {
        case .monthStart:
            return L10n.Panel.Hero.kpiMonthStart(income: income, daysRemaining: data.daysRemaining)
        case .onTrack:
            return L10n.Panel.Hero.kpiOnTrack(
                income: income, spent: spent, available: available, daysRemaining: data.daysRemaining
            )
        case .neutral:
            return L10n.Panel.Hero.kpiNeutral(
                income: income, spent: spent, available: available, daysRemaining: data.daysRemaining
            )
        case .tight:
            return L10n.Panel.Hero.kpiTight(
                spent: spent, available: available, daysRemaining: data.daysRemaining
            )
        case .overBudget:
            return L10n.Panel.Hero.kpiOverBudget(spent: spent, income: income)
        }
    }

    /// Locale-aware full month name, capitalised per locale. Cached so we
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

    // MARK: - Formatting

    private func formattedAmount(_ value: Double) -> String {
        YalaFormatter.currency(value: value, currencyCode: currencyCode)
    }

    private var voiceoverLabel: String {
        var parts: [String] = []
        if showProBadge { parts.append(L10n.Panel.Hero.proBadge) }
        parts.append(chipText)
        // Removemos el markdown para VoiceOver
        parts.append(kpiText.replacing("**", with: ""))
        if showUpsellCTA { parts.append(L10n.Panel.Hero.upsellCTA) }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Preview

#Preview("Hero states") {
    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
        HeroMonthView(
            data: HeroMonthData(
                state: .monthStart, income: 0, expense: 0,
                daysRemaining: 28, daysElapsed: 2
            ),
            currencyCode: "PEN",
            selectedPeriod: .thisMonth,
            customDateRange: nil,
            onSelectPeriod: { _ in },
            onCustomPeriodTapped: {}
        )
        HeroMonthView(
            data: HeroMonthData(
                state: .onTrack, income: 11356, expense: 6019,
                daysRemaining: 20, daysElapsed: 10
            ),
            currencyCode: "PEN",
            selectedPeriod: .thisMonth,
            customDateRange: nil,
            onSelectPeriod: { _ in },
            onCustomPeriodTapped: {}
        )
        // Pro + cache hit → aiSubtitle es el KPI protagonista
        HeroMonthView(
            data: HeroMonthData(
                state: .neutral, income: 4500, expense: 1500,
                daysRemaining: 20, daysElapsed: 10
            ),
            currencyCode: "PEN",
            selectedPeriod: .thisMonth,
            customDateRange: nil,
            onSelectPeriod: { _ in },
            onCustomPeriodTapped: {},
            aiSubtitle: "Abril te está yendo bien, Jur. Llevas un ritmo tranquilo — sigue así.",
            showProBadge: true
        )
        // Free — upsellCTA visible
        HeroMonthView(
            data: HeroMonthData(
                state: .neutral, income: 4500, expense: 1500,
                daysRemaining: 20, daysElapsed: 10
            ),
            currencyCode: "PEN",
            selectedPeriod: .thisMonth,
            customDateRange: nil,
            onSelectPeriod: { _ in },
            onCustomPeriodTapped: {},
            showUpsellCTA: true
        )
    }
    .padding(.vertical)
    .environment(AppPreferences(defaults: .standard))
}
