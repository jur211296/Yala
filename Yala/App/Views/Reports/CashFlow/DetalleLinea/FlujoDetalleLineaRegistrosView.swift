//
//  FlujoDetalleLineaRegistrosView.swift
//  Yala
//
//  «Registros de noviembre» del detalle de una línea del flujo de caja (S3 del replanteo): todos los registros que el
//  motor da a la línea en el mes, por día y con lo que suma cada día, con la fila de Registros (se puede tocar) y
//  «Ver en Registros» a la derecha del título. Un día de mañana en adelante dice «Programado».
//

import SwiftData
import SwiftUI

struct FlujoDetalleLineaRegistrosView: View {
    let dias: [FlujoDetalleLineaLogica.Dia]
    let mesNombre: String
    let currencyCode: String
    /// `nil`: la línea no tiene categoría que filtrar (no sale «Ver en Registros»).
    let onVerEnRegistros: (() -> Void)?
    let onAbrir: (TransactionItem) -> Void

    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    titulo
                    Spacer(minLength: DS.Spacing.sm)
                    verEnRegistros
                }
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    titulo
                    verEnRegistros
                }
            }

            if dias.isEmpty {
                Text(L10n.FlujoDetalleLinea.sinRegistros(mes: mesNombre))
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("cashflow_line_records_empty")
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    ForEach(dias) { dia in
                        diaView(dia)
                    }
                }
            }
        }
    }

    private var titulo: some View {
        Text(L10n.FlujoDetalleLinea.registrosTitulo(mes: mesNombre))
            .font(DS.Typography.headline)
            .foregroundStyle(.primary)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var verEnRegistros: some View {
        if let onVerEnRegistros {
            Button(action: onVerEnRegistros) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(L10n.FlujoDetalleLinea.verEnRegistros)
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.labelSmall)
                        .accessibilityHidden(true)
                }
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thAccentText)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("cashflow_line_see_in_records")
        }
    }

    private func diaView(_ dia: FlujoDetalleLineaLogica.Dia) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text(dia.fecha.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                if dia.esProgramado {
                    Text("· " + L10n.FlujoDetalleLinea.programadoDia)
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: DS.Spacing.sm)
                Text(appPreferences.currency(dia.total, currencyCode: currencyCode))
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("cashflow_line_records_day")

            VStack(spacing: DS.Spacing.sm) {
                ForEach(dia.registros, id: \.transaction.persistentModelID) { registro in
                    RecordRowView(
                        record: registro.transaction,
                        currencyCode: currencyCode,
                        isSelectionMode: false,
                        isSelected: false,
                        onTap: { onAbrir(registro.transaction) },
                        onToggleSelection: {}
                    )
                }
            }
        }
    }
}
