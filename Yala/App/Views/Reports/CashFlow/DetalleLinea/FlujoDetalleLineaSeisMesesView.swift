//
//  FlujoDetalleLineaSeisMesesView.swift
//  Yala
//
//  «Últimos 6 meses» del detalle de una línea del flujo de caja (S3 del replanteo): una barra por mes con lo real y una
//  marca con el límite de ese mes. La barra va en rosa si el mes se pasó del límite (en un ingreso, si no llegó). VoiceOver
//  lee la conclusión («En 4 de 6 meses…») y cada mes con su cifra (`swiftui-ds.md` · decisión 26 de 2.3).
//
//  19-nov-2026 (Jürgen: «tener tooltip útil las barras… poder apretar un mes y que abajo… cambie a los registros de ese
//  mes»): mantener presionada una barra (o pasar el puntero en iPad y Mac) enseña su mes, lo gastado, el límite, la
//  diferencia y si se dejó fuera por aislado; tocarla elige ese mes para la lista de abajo y la marca; tocarla otra vez,
//  o el mes que se ve, vuelve. Los meses aislados del límite van en gris. Los gestos van en `chartOverlay`, que sí
//  propaga el entorno (`swiftui-ds.md`), y por columnas: un toque o una pulsación larga no le quitan el arrastre al
//  scroll de la hoja.
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
    /// El mes elegido para la lista de abajo; `nil` = el que se ve.
    @Binding var mesElegido: String?

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.yalaTheme) private var theme
    /// La barra con el tooltip abierto (pulsación larga o puntero).
    @State private var tooltip: String?

    /// El mes marcado en la gráfica: el elegido o, sin elegir, el que se ve.
    private var mesMarcado: String { mesElegido ?? mesActivo }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.FlujoDetalleLinea.seisMesesTitulo)
                .font(DS.Typography.headline)
                .accessibilityAddTraits(.isHeader)

            Chart {
                ForEach(meses) { mes in
                    if mesElegido == mes.monthKey {
                        // La columna elegida, de fondo.
                        RectangleMark(
                            x: .value("mes", mes.monthKey),
                            yStart: .value("base", 0),
                            yEnd: .value("tope", techo),
                            width: .ratio(0.95)
                        )
                        .foregroundStyle(theme.accentText.opacity(0.12))
                        .cornerRadius(DS.Radius.sm)
                    }
                    BarMark(
                        x: .value("mes", mes.monthKey),
                        y: .value("real", max(0, mes.real)),
                        width: .ratio(0.55)
                    )
                    .foregroundStyle(color(de: mes))
                    .opacity(mes.monthKey == mesMarcado ? 1 : 0.55)
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
                                .fontWeight(key == mesMarcado ? .semibold : .regular)
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
            .chartYScale(domain: 0...techo)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    if let plotFrame = proxy.plotFrame {
                        let plot = geo[plotFrame]
                        columnas(ancho: plot.width, alto: plot.height)
                            .frame(width: plot.width, height: plot.height)
                            .offset(x: plot.minX, y: plot.minY)
                        if let key = tooltip, let mes = meses.first(where: { $0.monthKey == key }),
                           let i = meses.firstIndex(where: { $0.monthKey == key }) {
                            tooltipView(mes)
                                .fixedSize()
                                .modifier(TooltipPosition(
                                    centroX: plot.minX + plot.width * (CGFloat(i) + 0.5) / CGFloat(meses.count),
                                    anchoTotal: geo.size.width
                                ))
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
            .frame(height: 140)
            // Abierto con una pulsación larga, se cierra solo a los 4 s (con el puntero, al salir de la barra).
            .task(id: tooltip) { await cerrarTooltipLuego() }
            // Seis etiquetas de mes en el ancho de un iPhone: con texto de accesibilidad se pisaban. La gráfica no
            // crece; lo que se lee en grande es el resumen de debajo (y VoiceOver lee cada mes).
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.FlujoDetalleLinea.seisMesesTitulo)
            .accessibilityValue(resumenHablado)
            // VoiceOver elige el mes de la lista con las acciones (la gráfica es un solo elemento).
            .accessibilityActions {
                ForEach(meses) { mes in
                    Button(nombreLargo(mes.mes)) { elegir(mes.monthKey) }
                }
            }
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
                if meses.contains(where: \.esAislado) {
                    leyenda(color: colorAislado, ancho: 10, alto: 10, texto: L10n.FlujoDetalleLinea.otrosAislado)
                }
                Spacer(minLength: 0)
            }
            .accessibilityHidden(true)

            Text(resumen)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
            Text(L10n.FlujoDetalleLinea.tooltipAyuda)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Gestos por columna

    /// Una columna por mes sobre el área de la gráfica: tocar elige el mes de la lista; mantener (o el puntero) abre el
    /// tooltip. Sin `DragGesture`: el scroll de la hoja sigue siendo del dedo.
    private func columnas(ancho: CGFloat, alto: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(meses) { mes in
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        tooltip = nil
                        elegir(mes.monthKey)
                    }
                    .onLongPressGesture(minimumDuration: 0.35) {
                        DS.Haptic.selection()
                        tooltip = mes.monthKey
                    }
                    .onHover { dentro in
                        if dentro { tooltip = mes.monthKey } else if tooltip == mes.monthKey { tooltip = nil }
                    }
                    .accessibilityHidden(true)
            }
        }
    }

    private func cerrarTooltipLuego() async {
        guard let abierto = tooltip else { return }
        do {
            try await Task.sleep(for: .seconds(4))
        } catch {
            return
        }
        if tooltip == abierto { tooltip = nil }
    }

    /// Tocar un mes lo elige; tocar el elegido, o el que se ve, vuelve al que se ve.
    private func elegir(_ key: String) {
        DS.Haptic.selection()
        mesElegido = (key == mesElegido || key == mesActivo) ? nil : key
    }

    private func tooltipView(_ mes: FlujoDetalleLineaLogica.MesHistoria) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(nombreLargo(mes.mes))
                .font(DS.Typography.label.weight(.semibold))
            Text("\(L10n.FlujoDetalleLinea.seisMesesReal(esIngreso: esIngreso)): \(appPreferences.currency(mes.real, currencyCode: currencyCode))")
            Text("\(L10n.FlujoDetalleLinea.seisMesesLimite(esIngreso: esIngreso)): \(appPreferences.currency(mes.limite, currencyCode: currencyCode))")
            if abs(mes.diferencia) > 0.005 {
                Text(L10n.FlujoDetalleLinea.diferencia(
                    appPreferences.currency(abs(mes.diferencia), currencyCode: currencyCode), esMas: mes.diferencia > 0
                ))
                .foregroundStyle(cumple(mes) ? Color.secondary : DS.Semantic.errorForeground)
            }
            if mes.esAislado {
                Text(L10n.FlujoDetalleLinea.tooltipAislado)
                    .foregroundStyle(.secondary)
            }
        }
        .font(DS.Typography.captionSmall)
        .monospacedDigit()
        .padding(DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(theme.card)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
        )
        .accessibilityIdentifier("cashflow_line_history_tooltip")
    }

    /// El tope del eje: lo más alto entre lo real y el límite, con un poco de aire para la columna elegida.
    private var techo: Double {
        max(meses.map { max($0.real, $0.limite) }.max() ?? 0, 1) * 1.08
    }

    private var colorAislado: Color { Color.secondary.opacity(0.6) }

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
        // Un mes que se dejó fuera del límite por aislado: gris, no se juzga contra ese límite.
        if mes.esAislado { return colorAislado }
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

// MARK: - Dónde va el tooltip

/// Centrado sobre su columna, arriba de la gráfica, sin salirse por los lados.
private struct TooltipPosition: ViewModifier {
    let centroX: CGFloat
    let anchoTotal: CGFloat
    @State private var ancho: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { ancho = $0 }
            .offset(x: min(max(centroX - ancho / 2, 0), max(anchoTotal - ancho, 0)), y: 0)
    }
}
