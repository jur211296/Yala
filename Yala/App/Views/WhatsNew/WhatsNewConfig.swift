//
//  WhatsNewConfig.swift
//  Yala
//
//  Configuración de features por versión.
//  Para cada release, agregar un case al switch y un array estático.
//

import SwiftUI

enum WhatsNewConfig {

    /// Retorna features para la versión, o nil si no hay novedades (ej: hotfix).
    /// Compara solo major.minor — "1.2.1" se evalúa como "1.2".
    static func features(for version: String) -> [WhatsNewFeature]? {
        let majorMinor = extractMajorMinor(version)
        switch majorMinor {
        case "1.1":
            return version1_1
        case "1.2":
            return version1_2
        case "2.0":
            return version2_0
        default:
            return nil
        }
    }

    // MARK: - Version 1.1

    // A11Y-DM: paleta decorativa por feature del carrusel (colores de sistema, adaptan a Dark Mode)
    private static let version1_1: [WhatsNewFeature] = [
        WhatsNewFeature(
            icon: "chart.bar.doc.horizontal.fill",
            iconColor: .purple,
            title: L10n.WhatsNew.v11ResumenTitle,
            description: L10n.WhatsNew.v11ResumenDescription
        ),
        WhatsNewFeature(
            icon: "chart.pie.fill",
            iconColor: .blue,
            title: L10n.WhatsNew.v11BudgetDetailTitle,
            description: L10n.WhatsNew.v11BudgetDetailDescription
        ),
        WhatsNewFeature(
            icon: "line.3.horizontal.decrease.circle.fill",
            iconColor: .orange,
            title: L10n.WhatsNew.v11ExcludeTitle,
            description: L10n.WhatsNew.v11ExcludeDescription
        ),
    ]

    // MARK: - Version 1.2

    // A11Y-DM: paleta decorativa por feature del carrusel (colores de sistema, adaptan a Dark Mode)
    private static let version1_2: [WhatsNewFeature] = [
        WhatsNewFeature(
            icon: "chart.line.uptrend.xyaxis",
            iconColor: .blue,
            title: L10n.WhatsNew.v12CashFlowTitle,
            description: L10n.WhatsNew.v12CashFlowDescription
        ),
        WhatsNewFeature(
            icon: "tablecells",
            iconColor: .orange,
            title: L10n.WhatsNew.v12ComparativeTitle,
            description: L10n.WhatsNew.v12ComparativeDescription
        ),
        WhatsNewFeature(
            icon: "paintpalette.fill",
            iconColor: .purple,
            title: L10n.WhatsNew.v12ThemesTitle,
            description: L10n.WhatsNew.v12ThemesDescription
        ),
        WhatsNewFeature(
            icon: "calendar.badge.clock",
            iconColor: .teal,
            title: L10n.WhatsNew.v12ScheduledTitle,
            description: L10n.WhatsNew.v12ScheduledDescription
        ),
        WhatsNewFeature(
            icon: "gift.fill",
            iconColor: .green,
            title: L10n.WhatsNew.v12MoreForYouTitle,
            description: L10n.WhatsNew.v12MoreForYouDescription
        ),
    ]

    // MARK: - Version 2.0

    // A11Y-DM: paleta decorativa por feature del carrusel (colores de sistema, adaptan a Dark Mode)
    private static let version2_0: [WhatsNewFeature] = [
        WhatsNewFeature(
            icon: "person.2.fill",
            iconColor: .green,
            title: L10n.WhatsNew.v20GroupsTitle,
            description: L10n.WhatsNew.v20GroupsDescription
        ),
        WhatsNewFeature(
            icon: "sparkles",
            iconColor: .indigo,
            title: L10n.WhatsNew.v20AITitle,
            description: L10n.WhatsNew.v20AIDescription
        ),
        WhatsNewFeature(
            icon: "paintbrush.fill",
            iconColor: .pink,
            title: L10n.WhatsNew.v20RedesignTitle,
            description: L10n.WhatsNew.v20RedesignDescription
        ),
    ]

    // MARK: - Helpers

    /// Extracts "major.minor" from a version string, e.g. "1.2.1" → "1.2"
    private static func extractMajorMinor(_ version: String) -> String {
        let parts = version.split(separator: ".")
        guard parts.count >= 2 else { return version }
        return "\(parts[0]).\(parts[1])"
    }
}
