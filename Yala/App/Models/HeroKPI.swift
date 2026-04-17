//
//  HeroKPI.swift
//  Yala
//
//  Enumera las métricas disponibles para los pills del Hero del mes (Panel 2.0).
//  El usuario las reordena y activa/desactiva desde `HeroKPIPreferencesSheet`;
//  `HeroMonthView` renderiza sólo los primeros 3 activos (cap aplicado en el VM).
//
//  Paralelo conceptual a `PanelSectionKind`: String-backed, `CaseIterable`,
//  `Hashable`, `Identifiable`. Vive en `Models/` (no en `Calculators/`) para
//  mantener a `HeroMonthCalculator` como pure compute sin conocer presentación.
//

import Foundation

enum HeroKPI: String, CaseIterable, Hashable, Identifiable {
    case income
    case spent
    case daysLeft
    case available
    case dailyAverage
    case projection

    var id: String { rawValue }

    /// SF Symbol shown next to the KPI name in the preferences sheet.
    var iconName: String {
        switch self {
        case .income:        return "arrow.down.circle"
        case .spent:         return "arrow.up.circle"
        case .daysLeft:      return "calendar"
        case .available:     return "wallet.pass"
        case .dailyAverage:  return "chart.bar"
        case .projection:    return "chart.line.uptrend.xyaxis"
        }
    }

    /// Full name shown in the preferences sheet (list rows).
    var displayName: String {
        switch self {
        case .income:        return L10n.Panel.Hero.KpiPrefs.nameIncome
        case .spent:         return L10n.Panel.Hero.KpiPrefs.nameSpent
        case .daysLeft:      return L10n.Panel.Hero.KpiPrefs.nameDaysLeft
        case .available:     return L10n.Panel.Hero.KpiPrefs.nameAvailable
        case .dailyAverage:  return L10n.Panel.Hero.KpiPrefs.nameDailyAverage
        case .projection:    return L10n.Panel.Hero.KpiPrefs.nameProjection
        }
    }

    /// Short label shown on the hero pill (tight space, 1 line).
    var pillLabel: String {
        switch self {
        case .income:        return L10n.Panel.Hero.pillIncome
        case .spent:         return L10n.Panel.Hero.pillSpent
        case .daysLeft:      return L10n.Panel.Hero.pillDaysLeft
        case .available:     return L10n.Panel.Hero.KpiPrefs.pillAvailable
        case .dailyAverage:  return L10n.Panel.Hero.KpiPrefs.pillDailyAverage
        case .projection:    return L10n.Panel.Hero.KpiPrefs.pillProjection
        }
    }

    /// Default visible-first order used when the user has never customised
    /// their hero. `PanelViewModel.orderedHeroKPIs()` gates on the
    /// `panelHeroKPIsCustomized` flag to decide between this default and the
    /// stored order. Self-heal: any KPI missing from stored order is appended
    /// at the tail of the resolved list (so KPIs added in future versions
    /// surface automatically, still hidden per `defaultHidden`).
    static let defaultOrder: [HeroKPI] = [
        .income, .spent, .daysLeft,
        .available, .dailyAverage, .projection
    ]

    /// KPIs hidden by default for new users — they live in the ordered list
    /// but don't render until the user toggles them on.
    static let defaultHidden: [HeroKPI] = [.available, .dailyAverage, .projection]
}
