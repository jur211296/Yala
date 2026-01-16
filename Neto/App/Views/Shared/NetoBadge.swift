import SwiftUI

/// Badge/chip unificado para etiquetas, estados y contadores
/// Uso: Tags, status indicators, counts, nature chips
struct NetoBadge: View {
    let text: String
    let icon: String?
    let color: Color
    let style: BadgeStyle

    enum BadgeStyle {
        case filled      // Fondo sólido, texto claro
        case soft        // Fondo suave, texto del color
        case outline     // Solo borde, sin fondo
    }

    init(
        _ text: String,
        icon: String? = nil,
        color: Color = .electricIndigo,
        style: BadgeStyle = .soft
    ) {
        self.text = text
        self.icon = icon
        self.color = color
        self.style = style
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(DS.Typography.labelTiny)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .foregroundStyle(foregroundColor)
        .background(backgroundColor)
        .clipShape(Capsule())
        .overlay(borderOverlay)
    }

    private var foregroundColor: Color {
        switch style {
        case .filled:
            return .white
        case .soft, .outline:
            return color
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .filled:
            return color
        case .soft:
            return color.opacity(0.15)
        case .outline:
            return .clear
        }
    }

    @ViewBuilder
    private var borderOverlay: some View {
        switch style {
        case .outline:
            Capsule()
                .stroke(color.opacity(0.5), lineWidth: 1)
        default:
            EmptyView()
        }
    }
}

// MARK: - Counter Badge

/// Badge numérico para contadores
struct NetoCountBadge: View {
    let count: Int
    let maxDisplay: Int

    init(_ count: Int, max: Int = 99) {
        self.count = count
        self.maxDisplay = max
    }

    var body: some View {
        Text(count > maxDisplay ? "\(maxDisplay)+" : "\(count)")
            .font(DS.Typography.labelTiny)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .foregroundStyle(.white)
            .background(Color.electricIndigo)
            .clipShape(Capsule())
    }
}

// MARK: - Status Badge

/// Badge de estado con colores semánticos
struct NetoStatusBadge: View {
    let status: Status
    let text: String?

    enum Status {
        case success, warning, error, info, neutral

        var color: Color {
            switch self {
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            case .info: return .blue
            case .neutral: return .gray
            }
        }

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            case .neutral: return "circle.fill"
            }
        }
    }

    init(_ status: Status, text: String? = nil) {
        self.status = status
        self.text = text
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: status.icon)
                .font(.system(size: 10))

            if let text {
                Text(text)
                    .font(DS.Typography.labelTiny)
            }
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(status.color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Tag Badge (for transaction tags)

/// Badge específico para tags de transacciones
struct NetoTagBadge: View {
    let name: String
    let colorHex: String
    let icon: String?

    init(name: String, colorHex: String, icon: String? = nil) {
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
            }
            Text(name)
                .font(DS.Typography.labelTiny)
        }
        .padding(.horizontal, DS.Chip.paddingH)
        .padding(.vertical, DS.Chip.paddingV)
        .foregroundStyle(Color.tagChipColor)
        .background(Color(hex: colorHex).opacity(0.2))
        .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: DS.Spacing.xl) {
        // Standard badges
        HStack {
            NetoBadge("Nuevo", style: .filled)
            NetoBadge("Pendiente", style: .soft)
            NetoBadge("Archivado", style: .outline)
        }

        // With icons
        HStack {
            NetoBadge("Esencial", icon: "star.fill", color: .orange, style: .soft)
            NetoBadge("Opcional", icon: "sparkles", color: .purple, style: .soft)
        }

        Divider()

        // Counter badges
        HStack {
            Text("Notificaciones")
            Spacer()
            NetoCountBadge(5)
        }
        .padding(.horizontal)

        HStack {
            Text("Mensajes")
            Spacer()
            NetoCountBadge(150)
        }
        .padding(.horizontal)

        Divider()

        // Status badges
        HStack {
            NetoStatusBadge(.success, text: "Completado")
            NetoStatusBadge(.warning, text: "Pendiente")
            NetoStatusBadge(.error)
        }

        Divider()

        // Tag badges
        HStack {
            NetoTagBadge(name: "Viajes", colorHex: "#FF6B6B", icon: "airplane")
            NetoTagBadge(name: "Comida", colorHex: "#4ECDC4")
            NetoTagBadge(name: "Trabajo", colorHex: "#45B7D1", icon: "briefcase")
        }
    }
    .padding()
    .background(Color.netoBackground)
}
