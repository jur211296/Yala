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
        // case "1.3": return version1_3
        default:
            return nil
        }
    }

    // MARK: - Version 1.1

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

    private static let version1_2: [WhatsNewFeature] = [
        WhatsNewFeature(
            icon: "hand.point.up.left.fill",
            iconColor: .blue,
            title: L10n.WhatsNew.v12CoachMarksTitle,
            description: L10n.WhatsNew.v12CoachMarksDescription
        ),
        WhatsNewFeature(
            icon: "bell.badge.fill",
            iconColor: .orange,
            title: L10n.WhatsNew.v12NotificationsTitle,
            description: L10n.WhatsNew.v12NotificationsDescription
        ),
        WhatsNewFeature(
            icon: "sparkles",
            iconColor: .purple,
            title: L10n.WhatsNew.v12InsightsTitle,
            description: L10n.WhatsNew.v12InsightsDescription
        ),
        WhatsNewFeature(
            icon: "person.2.fill",
            iconColor: .green,
            title: L10n.WhatsNew.v12SharedBalancesTitle,
            description: L10n.WhatsNew.v12SharedBalancesDescription
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
