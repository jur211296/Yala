//
//  HeroHeader.swift
//  Yala
//
//  La maqueta del hero de Yala: la del Panel (`HeroMonthView`), compartida con las cuatro pestañas de Estadísticas
//  y, por `RecordsTabView`, con la página Registros. Antes cada una tenía la suya —centrada, con el período encima y
//  el rótulo debajo de la cifra— y el usuario que pasaba del Panel a Estadísticas tenía que volver a orientarse
//  (ticket `distribution-subviews-miss-the-new-panel-hero`, decisión de Jürgen del 2026-10-03).
//
//  Tres piezas, con un solo eje de lectura a la izquierda:
//  - `label`: qué es la cifra («Disponible», «Saldo de cuentas», «Neto del período»…), arriba a la izquierda.
//  - `period`: la píldora del período, a su derecha. A tamaños de accesibilidad baja debajo (`AdaptiveRowStack`).
//  - `content`: la cifra y lo que la acompaña (entradas y salidas, recuento), alineados a la izquierda.
//
//  Solo maqueta: cada pantalla sigue eligiendo su número y su rótulo. Con poco alto (iPhone girado) Resumen y
//  Registros no lo usan: `SummaryHeaderStack` los pone en banda.
//

import SwiftUI

struct HeroHeader<Label: View, Period: View, Content: View>: View {
    /// El aire entre la fila del rótulo y la cifra. El Panel lo achica (2026-11-16: el rótulo quedaba lejos de su
    /// cifra); Estadísticas y Registros siguen con el de siempre.
    var labelToContentSpacing: CGFloat = DS.Spacing.md
    @ViewBuilder var label: Label
    @ViewBuilder var period: Period
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: labelToContentSpacing) {
            AdaptiveRowStack(spacing: DS.Spacing.xs, stackedSpacing: DS.Spacing.sm) {
                label
            } trailing: {
                period
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DS.Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// El margen vertical del hero en Estadísticas: arriba y abajo `value` (un `@ScaledMetric` de cada pestaña), salvo
/// debajo de una barra de chips de navegación (`navigationChipsInset`), donde arriba no suma nada y el hero queda a la
/// misma distancia de los chips que el contenido de Planificación o del detalle de grupo (`NavigationChipsBar.swift`).
/// Registros reutiliza la misma pestaña sin chips encima y conserva el margen de siempre.
private struct HeroVerticalPadding: ViewModifier {
    let value: CGFloat
    @Environment(\.sitsBelowNavigationChips) private var sitsBelowNavigationChips

    func body(content: Content) -> some View {
        content
            .padding(.top, sitsBelowNavigationChips ? DS.Spacing.none : value)
            .padding(.bottom, value)
    }
}

extension View {
    func heroVerticalPadding(_ value: CGFloat) -> some View {
        modifier(HeroVerticalPadding(value: value))
    }
}

/// El rótulo del hero: lo que dice qué es la cifra. Mismo estilo en el Panel y en Estadísticas.
struct HeroHeaderLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(DS.Typography.subheadline)
            .foregroundStyle(.secondary)
            // Dos líneas y no una: en Estadísticas el rótulo es más largo que «Disponible» y en algunos idiomas no
            // cabe junto a la píldora. Cortarlo escondería justo lo que dice qué es el número.
            .lineLimit(2)
    }
}

/// La variación bajo la cifra del hero en modo «Solo gastos»: el chip del gasto y «vs período anterior», la misma
/// línea que pinta el hero del Panel (`HeroMonthView`). Las pestañas de Estadísticas la usan para que su cabecera
/// sea la del Panel (decisión A de Jürgen del 2026-10-26, auditoría «Solo gastos»).
///
/// Sin variación (primer período, «Todo el tiempo») o con las variaciones apagadas no pinta nada: el texto solo,
/// sin chip, quedaría huérfano. Por eso se comprueba `showVariations` aquí y no se confía en que el chip se oculte.
struct ExpensesOnlyHeroVariation: View {
    let variation: Double?
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        if appPreferences.showVariations, let variation {
            HStack(spacing: DS.Spacing.xs) {
                VariationChip(variation: variation, size: .small, isExpenseContext: true)
                Text(L10n.Statistics.vsPreviousPeriod)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("stats_hero_expense_variation")
        }
    }
}

// MARK: - El hero claro (2026-11-16)
//
// Las piezas que el Panel estrenó con «Tu saldo hoy» y su «?» (`HeroMonthView`), para Estadísticas, Registros y el Flujo
// de caja: el rótulo con su «?» y los rótulos en chico de ingresos y gastos. El Panel sigue con las suyas: se dejó como
// está para no cambiar lo que Jürgen ya aprobó.

/// El hero claro: rótulo (con su «?») y período arriba, la cifra PEGADA al rótulo y el detalle debajo.
///
/// Con `HeroHeader`, la fila de arriba medía lo que la columna más alta, y en Estadísticas esa es la del período (flechas,
/// píldora y debajo los días: ~55 pt). El rótulo quedaba centrado en esa altura y la cifra empezaba debajo de todo: el
/// «hueco antes del valor» que Jürgen señaló (16-nov). Aquí el rótulo se alinea con el texto de la píldora y la cifra
/// empieza justo debajo del rótulo, con el aire del Panel; si la cifra no cabe al lado del período, baja bajo él. El
/// detalle va siempre debajo de los dos. A tamaños de accesibilidad el período baja bajo el rótulo, como en el Panel.
struct HeroClaroHeader<Label: View, Period: View, Figure: View, Detail: View>: View {
    @ViewBuilder var label: Label
    @ViewBuilder var period: Period
    @ViewBuilder var figure: Figure
    @ViewBuilder var detail: Detail
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HeroClaroRows(stacksPeriod: dynamicTypeSize.isAccessibilitySize) {
            HStack(alignment: .center, spacing: DS.Spacing.xs) { label }
            VStack(alignment: .trailing, spacing: DS.Spacing.none) { period }
            VStack(alignment: .leading, spacing: DS.Spacing.sm) { figure }
            VStack(alignment: .leading, spacing: DS.Spacing.sm) { detail }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// La maqueta de `HeroClaroHeader`, con cuatro huecos fijos: rótulo, período, cifra y detalle. Un `Layout` y no pilas,
/// porque decide la posición de la cifra midiendo si cabe al lado del período.
struct HeroClaroRows: Layout {
    /// Texto de accesibilidad: el período baja bajo el rótulo (en fila no caben en un SE).
    var stacksPeriod: Bool

    /// Rótulo → cifra: lo mismo que el Panel (`xs` entre filas + `xs` de margen de la cifra).
    static var labelToFigure: CGFloat { DS.Spacing.xs * 2 }
    private static var labelToPeriod: CGFloat { DS.Spacing.sm }
    private static var figureToPeriod: CGFloat { DS.Spacing.md }
    private static var figureToDetail: CGFloat { DS.Spacing.sm }
    private static var bottomMargin: CGFloat { DS.Spacing.xs }
    /// Sin texto en el período (flechas solas), se alinea el rótulo con el centro de la primera fila de la píldora.
    private static var pillRowHeight: CGFloat { 36 }

    struct Frames: Equatable {
        var label: CGRect = .zero
        var period: CGRect = .zero
        var figure: CGRect = .zero
        var detail: CGRect = .zero
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? idealWidth(subviews)
        return CGSize(width: width, height: frames(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 4 else { return }
        let f = frames(width: bounds.width, subviews: subviews)
        for (subview, frame) in zip(subviews, [f.label, f.period, f.figure, f.detail]) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private func idealWidth(_ subviews: Subviews) -> CGFloat {
        subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
    }

    private func frames(width: CGFloat, subviews: Subviews) -> Frames {
        guard subviews.count == 4 else { return Frames() }
        let label = subviews[0], period = subviews[1], figure = subviews[2], detail = subviews[3]
        var f = Frames()

        let periodIdeal = period.sizeThatFits(.unspecified)
        let periodWidth = min(periodIdeal.width, width)
        let periodSize = periodWidth > 0
            ? period.sizeThatFits(ProposedViewSize(width: periodWidth, height: nil)) : .zero
        let hasPeriod = periodSize.width > 0 && periodSize.height > 0
        let besideLabel = width - (hasPeriod ? periodSize.width + Self.labelToPeriod : 0)
        let inRow = !hasPeriod || (!stacksPeriod && besideLabel >= min(label.sizeThatFits(.unspecified).width, 120))

        if inRow {
            let labelSize = label.sizeThatFits(ProposedViewSize(width: max(besideLabel, 0), height: nil))
            // El rótulo se alinea con el texto de la píldora; si el período no da línea base, con su primera fila.
            let labelBaseline = label.dimensions(in: ProposedViewSize(labelSize))[VerticalAlignment.firstTextBaseline]
            var periodBaseline = period.dimensions(in: ProposedViewSize(periodSize))[VerticalAlignment.firstTextBaseline]
            if !hasPeriod || periodBaseline >= periodSize.height - 0.5 {
                periodBaseline = min(periodSize.height, Self.pillRowHeight) / 2 + labelBaseline - labelSize.height / 2
            }
            let labelY = max(0, periodBaseline - labelBaseline)
            let periodY = hasPeriod ? max(0, labelBaseline - periodBaseline) : 0
            f.label = CGRect(origin: CGPoint(x: 0, y: labelY), size: labelSize)
            f.period = hasPeriod
                ? CGRect(origin: CGPoint(x: width - periodSize.width, y: periodY), size: periodSize) : .zero

            let figureIdeal = figure.sizeThatFits(ProposedViewSize(width: width, height: nil))
            let fitsBeside = !hasPeriod || figureIdeal.width <= width - periodSize.width - Self.figureToPeriod
            let figureY = fitsBeside
                ? f.label.maxY + Self.labelToFigure
                : max(f.label.maxY + Self.labelToFigure, f.period.maxY + DS.Spacing.xs)
            f.figure = CGRect(origin: CGPoint(x: 0, y: figureY), size: figureIdeal)
        } else {
            let labelSize = label.sizeThatFits(ProposedViewSize(width: width, height: nil))
            f.label = CGRect(origin: .zero, size: labelSize)
            f.period = CGRect(origin: CGPoint(x: 0, y: f.label.maxY + Self.labelToPeriod), size: periodSize)
            let figureSize = figure.sizeThatFits(ProposedViewSize(width: width, height: nil))
            f.figure = CGRect(origin: CGPoint(x: 0, y: f.period.maxY + Self.labelToFigure), size: figureSize)
        }

        let top = max(f.figure.maxY, f.period.maxY, f.label.maxY)
        let detailSize = detail.sizeThatFits(ProposedViewSize(width: width, height: nil))
        if detailSize.height > 0 {
            let gap = f.figure.height > 0 ? Self.figureToDetail : Self.labelToFigure
            f.detail = CGRect(origin: CGPoint(x: 0, y: top + gap), size: CGSize(width: width, height: detailSize.height))
            f.height = f.detail.maxY + Self.bottomMargin
        } else {
            f.detail = CGRect(origin: CGPoint(x: 0, y: top), size: CGSize(width: width, height: 0))
            f.height = top + Self.bottomMargin
        }
        return f
    }
}

/// El «?» junto al rótulo del hero: el mismo círculo de vidrio que el del Panel y que la ayuda de los widgets, y como
/// ellos solo con «Mostrar ayudas» encendido. No presenta nada: avisa a quien lo monta, que es quien cuelga la hoja.
struct HeroInfoButton: View {
    let identifier: String
    let action: () -> Void
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        if HeroClaroLogic.showsHelp(showHints: appPreferences.showWidgetHints, showsFigure: true) {
            Button {
                DS.Haptic.light()
                action()
            } label: {
                WidgetHelpCircleLabel()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.HeroClaro.infoButton)
            .accessibilityIdentifier(identifier)
        }
    }
}
