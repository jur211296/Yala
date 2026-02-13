import SwiftUI

/// Header de sección reutilizable con título y acción opcional
/// Uso: Encabezados de listas, secciones de settings, widgets
struct YalaSectionHeader: View {
    let title: String
    let subtitle: String?
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        _ title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.labelSmall)
                    }
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(Color.electricIndigo)
                }
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Compact Variant

/// Header compacto para secciones menores
struct YalaSectionHeaderCompact: View {
    let title: String
    let count: Int?

    init(_ title: String, count: Int? = nil) {
        self.title = title
        self.count = count
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(title.uppercased())
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)

            if let count {
                Text("\(count)")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(Color.secondary.opacity(DS.Opacity.subtle))
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 30) { // DS: intentional non-token value
        // Standard header
        YalaSectionHeader("Categorías", actionTitle: "Ver todas") { }

        // With subtitle
        YalaSectionHeader(
            "Últimos registros",
            subtitle: "Mostrando 5 más recientes",
            actionTitle: "Ver todos"
        ) { }

        // Without action
        YalaSectionHeader("Configuración")

        Divider()

        // Compact headers
        YalaSectionHeaderCompact("Activas", count: 12)
        YalaSectionHeaderCompact("Archivadas")
    }
    .padding()
    .background(Color.yalaBackground)
}
