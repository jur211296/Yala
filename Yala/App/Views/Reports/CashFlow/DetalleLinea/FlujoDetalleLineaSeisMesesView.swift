//
//  FlujoDetalleLineaSeisMesesView.swift
//  Yala
//
//  «Últimos 6 meses» del detalle de una línea del flujo de caja (S3 del replanteo): una barra por mes con lo real y una
//  marca con el límite de ese mes. La barra va en rosa si el mes se pasó del límite (en un ingreso, si no llegó). VoiceOver
//  lee la conclusión («En 4 de 6 meses…») y cada mes con su cifra (`swiftui-ds.md` · decisión 26 de 2.3).
//

import Accessibility
import Charts
import SwiftUI

struct FlujoDetalleLineaSeisMesesView: View {
    let meses: [FlujoDetalleLineaLogica.MesHistoria]
    let esIngreso: Bool
    let currencyCode: String
    /// El mes que se ve en el detalle, resaltado.
    let mesActivo: String

    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.FlujoDetalleLinea.seisMesesTitulo)
                .font(DS.Typography.headline)
                .accessibilityAddTraits(.isHeader)

            Chart {
                ForEach(meses) { mes in
                    BarMark(
                        x: .value("mes", mes.monthKey),
                        y: .value("real", max(0, mes.real)),
                        width: .ratio(0.55)
                    )
                    .foregroundStyle(color(de: mes))
                    .opacity(mes.monthKey == mesActivo ? 1 : 0.55)
                    .cornerRadius(DS.Radius.xs)

                    // El límite de cada mes: una raya sobre la columna.
                    RectangleMark(
                        x: .value("mes", mes.monthKey),
                        y: .value("límite", mes.limite),
                        width: .ratio(0.8),
                        height: 2
                    )
                    .foregroundStyle(Color.secondary)
                }
            }
            .chartXAxis {
                AxisMarks(values: meses.map(\.monthKey)) { value in
                    AxisValueLabel {
                        if let key = value.as(String.self) {
                            Text(etiqueta(key))
                                .font(DS.Typography.captionSmall)
                                .fontWeight(key == mesActivo ? .semibold : .regular)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(YalaFormatter.amountCompactTable(value: amount))
                                .font(DS.Typography.captionSmall)
                        }
                    }
                }
            }
            .frame(height: 140)
            // Seis etiquetas de mes en el ancho de un iPhone: con texto de accesibilidad se pisaban. La gráfica no
            // crece; lo que se lee en grande es el resumen de debajo (y VoiceOver lee cada mes).
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.FlujoDetalleLinea.seisMesesTitulo)
            .accessibilityValue(resumenHablado)
            .accessibilityChartDescriptor(FlujoDetalleLineaSeisMesesDescriptor(
                titulo: L10n.FlujoDetalleLinea.seisMesesTitulo,
                resumen: resumen,
                meses: meses.map { ($0.monthKey, etiqueta($0.monthKey), $0.real, $0.limite) },
                serieReal: L10n.FlujoDetalleLinea.seisMesesReal(esIngreso: esIngreso),
                serieLimite: L10n.FlujoDetalleLinea.seisMesesLimite(esIngreso: esIngreso)
            ))
            .accessibilityIdentifier("cashflow_line_history_chart")

            HStack(spacing: DS.Spacing.lg) {
                leyenda(color: .electricIndigo, ancho: 10, alto: 10, texto: L10n.FlujoDetalleLinea.seisMesesReal(esIngreso: esIngreso))
                leyenda(color: .secondary, ancho: 14, alto: 2, texto: L10n.FlujoDetalleLinea.seisMesesLimite(esIngreso: esIngreso))
                Spacer(minLength: 0)
            }
            .accessibilityHidden(true)

            Text(resumen)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
    }

    private func leyenda(color: Color, ancho: CGFloat, alto: CGFloat, texto: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: ancho, height: alto)
            Text(texto)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
        }
    }

    /// Un mes cumple si gastó el límite o menos (en un ingreso, si recibió lo esperado o más).
    private func cumple(_ mes: FlujoDetalleLineaLogica.MesHistoria) -> Bool {
        esIngreso ? mes.real >= mes.limite - 0.005 : mes.real <= mes.limite + 0.005
    }

    private func color(de mes: FlujoDetalleLineaLogica.MesHistoria) -> Color {
        // El mes en curso todavía no ha cerrado: en un ingreso, no haber llegado aún no es un aviso.
        if esIngreso && mes.esActual { return .electricIndigo }
        return cumple(mes) ? .electricIndigo : .hotPink
    }

    private var cerrados: [FlujoDetalleLineaLogica.MesHistoria] {
        meses.filter { !$0.esActual }
    }

    private var resumen: String {
        let base = cerrados.isEmpty ? meses : cerrados
        return L10n.FlujoDetalleLinea.seisMesesResumen(
            dentro: base.filter(cumple).count, de: base.count, esIngreso: esIngreso
        )
    }

    private var resumenHablado: String {
        let porMes = meses.map { mes in
            L10n.FlujoDetalleLinea.seisMesesMes(
                nombreLargo(mes.mes),
                real: appPreferences.currency(mes.real, currencyCode: currencyCode),
                limite: appPreferences.currency(mes.limite, currencyCode: currencyCode)
            )
        }
        return ([resumen] + porMes).joined(separator: ". ")
    }

    private func etiqueta(_ key: String) -> String {
        guard let date = CashFlowDetailLineRow.monthDate(key) else { return key }
        return date.formatted(.dateTime.month(.abbreviated))
    }

    private func nombreLargo(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }
}

// MARK: - Descriptor de la gráfica

private struct FlujoDetalleLineaSeisMesesDescriptor: AXChartDescriptorRepresentable {
    let titulo: String
    let resumen: String
    let meses: [(key: String, etiqueta: String, real: Double, limite: Double)]
    let serieReal: String
    let serieLimite: String

    func makeChartDescriptor() -> AXChartDescriptor {
        let maximo = max(meses.map(\.real).max() ?? 0, meses.map(\.limite).max() ?? 0) * 1.1 + 1
        let xAxis = AXCategoricalDataAxisDescriptor(title: "", categoryOrder: meses.map(\.etiqueta))
        let yAxis = AXNumericDataAxisDescriptor(title: "", range: 0...maximo, gridlinePositions: []) { value in
            YalaFormatter.amountCompactTable(value: value)
        }
        let real = AXDataSeriesDescriptor(
            name: serieReal, isContinuous: false,
            dataPoints: meses.map { .init(x: $0.etiqueta, y: $0.real) }
        )
        let limite = AXDataSeriesDescriptor(
            name: serieLimite, isContinuous: false,
            dataPoints: meses.map { .init(x: $0.etiqueta, y: $0.limite) }
        )
        return AXChartDescriptor(
            title: titulo, summary: resumen, xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: [real, limite]
        )
    }
}
