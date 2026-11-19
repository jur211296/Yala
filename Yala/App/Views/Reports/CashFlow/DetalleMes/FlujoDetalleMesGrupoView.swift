//
//  FlujoDetalleMesGrupoView.swift
//  Yala
//
//  Una categoría del plan como agrupador (ajuste obligatorio de Jürgen del 18-nov-2026): la cabecera dice la categoría y
//  lo que suma en el mes, y se pliega; dentro van sus líneas, una por subcategoría (la fila base). Una línea por
//  categoría que venga de antes enseña debajo su desglose por subcategoría, de solo lectura, para no perder ese detalle;
//  y lo anotado en la categoría sin subcategoría va como fila propia, para que el grupo sume lo que enseña.
//

import SwiftUI

struct FlujoDetalleMesGrupoView<Fila: View>: View {
    let grupo: FlujoDetalleMesLogica.Grupo
    let iconName: String?
    let colorHex: String?
    let currencyCode: String
    let isCollapsed: Bool
    let onToggle: () -> Void
    @ViewBuilder let fila: (CashFlowLineResult) -> Fila

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            cabecera
            if !isCollapsed {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    ForEach(grupo.lineas, id: \.lineID) { linea in
                        fila(linea)
                        desglose(linea)
                    }
                    if let sinSub = grupo.sinSubcategoria {
                        filaSimple(L10n.Report.noSubcategory, value: sinSub, identifier: "cashflow_group_unassigned")
                            .padding(.horizontal, DS.Spacing.lg)
                    }
                }
                .padding(.leading, DS.Spacing.md)
            }
        }
    }

    private var cabecera: some View {
        Button(action: onToggle) {
            HStack(spacing: DS.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(colorHex.map { Color(hex: $0) } ?? Color.secondary.opacity(0.2))
                        .frame(width: 28, height: 28)
                    Image(systemName: iconName ?? "folder")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(colorHex == nil ? Color.secondary : Color.white)
                }
                .accessibilityHidden(true)
                Text(grupo.nombre)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer(minLength: DS.Spacing.sm)
                AmountText(
                    value: grupo.total,
                    currencyCode: currencyCode,
                    font: DS.Typography.subheadlineEmphasized.monospacedDigit()
                )
                Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                    .font(DS.Typography.captionSmall.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, DS.Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityValue(isCollapsed ? L10n.UXL20D.collapsed : L10n.UXL20D.expanded)
        .accessibilityHint(L10n.FlujoDetalleMes.lineas(grupo.lineas.count))
        .accessibilityIdentifier("cashflow_group_header")
    }

    /// Lo real de cada subcategoría de una línea por categoría (la línea ya dice su total).
    @ViewBuilder
    private func desglose(_ linea: CashFlowLineResult) -> some View {
        if let partes = linea.subcategoryBreakdown, partes.count > 1 {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                ForEach(Array(partes.enumerated()), id: \.offset) { _, parte in
                    filaSimple(parte.subcategoryName, value: parte.realAmount ?? parte.plannedAmount,
                               identifier: "cashflow_line_subcategory")
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
    }

    private func filaSimple(_ label: String, value: Double, identifier: String) -> some View {
        AdaptiveRowStack(spacing: DS.Spacing.sm, stackedSpacing: DS.Spacing.xxs) {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } trailing: {
            AmountText(
                value: value,
                currencyCode: currencyCode,
                font: DS.Typography.caption.monospacedDigit(),
                tint: .secondary
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
