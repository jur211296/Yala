//
//  RecordsMonthSeparator.swift
//  Yala
//
//  Revisión 2.3, decisión 17 (T2, 9-nov): el separador de mes de la lista de Registros. Va fijo arriba mientras se
//  desplaza («Octubre 2026 · 182 registros · S/ -6,420») y, al tocarlo, un menú con los meses lleva directo al
//  elegido: hasta un gasto de hace tres semanas eran nueve deslizamientos.
//
//  Decisión 79: es lo único fijo de la lista, así que lleva banda opaca y nada se lee debajo. Las cabeceras de día van
//  con el scroll desde 2.2 (no se montan sobre las filas).
//

import SwiftUI

struct RecordsMonthSeparator: View {
    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Una entrada del menú: el mes y su resumen («182 registros · S/ -6,420»).
    struct Option: Identifiable {
        let id: Date
        let title: String
        let summary: String
    }

    let title: String
    let summary: String
    let monthKey: String
    let options: [Option]
    let onSelect: (Date) -> Void

    var body: some View {
        Menu {
            Section(L10n.RecordsMonthJump23.goToAnotherMonth) {
                ForEach(options) { option in
                    Button {
                        onSelect(option.id)
                    } label: {
                        Text(option.title)
                        Text(option.summary)
                    }
                }
            }
        } label: {
            label
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(title), \(summary)"))
        .accessibilityHint(L10n.RecordsMonthJump23.goToAnotherMonth)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(Text(verbatim: monthKey))
        .accessibilityIdentifier("records_month_separator")
    }

    private var label: some View {
        // En una línea a tamaño normal; con texto de accesibilidad el resumen baja bajo el mes y nada se corta.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xxs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DS.Spacing.xs))
        return HStack(alignment: .center, spacing: DS.Spacing.sm) {
            layout {
                Text(title)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
                Text(summary)
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Image(systemName: "chevron.down")
                .font(DS.Typography.labelSmall.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Banda opaca (decisión 79): fija arriba, las filas pasan por debajo sin leerse a través.
        .background(theme.background)
        .contentShape(Rectangle())
        // De borde a borde: la lista lleva el margen de `scrollViewGlassEdges` y la banda lo cubre, con el texto
        // alineado con las cabeceras de día.
        .padding(.horizontal, -DS.Spacing.lg)
    }
}
