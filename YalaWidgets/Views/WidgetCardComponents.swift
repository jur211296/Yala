//
//  WidgetCardComponents.swift
//  YalaWidgets
//
//  Las piezas del rediseño 2.2 de los widgets (auditoría `docs/widgets/AUDITORIA-WIDGETS-2-2.md`): cabecera con
//  insignia sólida, cifra grande, píldora de variación, gráfica de línea sin ejes, barra con ritmo y pie de frescura.
//  Todo con `WidgetDS` y `WidgetColors`, y pensado para los cuatro modos en que se ve un widget:
//
//  - claro y oscuro: la tarjeta de la app (`WidgetColors.cardBackground`);
//  - StandBy: el sistema quita la tarjeta y pinta sobre negro, así que nada depende del fondo para leerse;
//  - tintado y transparente (`widgetRenderingMode == .accented`): el sistema pinta todo en blanco conservando la
//    opacidad y tiñe lo marcado con `widgetAccentable()`. Un relleno opaco con un icono blanco encima se vuelve un
//    círculo blanco sin icono, así que en ese modo la insignia pasa a ser translúcida.
//
//  Movimiento: las cifras cambian con `numericText` y nada se mueve con Reducir movimiento (`WidgetMotion`).
//

import Charts
import SwiftUI
import WidgetKit

// MARK: - Movimiento

/// La transición de contenido de una cifra: numérica, o ninguna con Reducir movimiento.
struct WidgetNumericTransition: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Double

    func body(content: Content) -> some View {
        if reduceMotion {
            content.contentTransition(.identity)
        } else {
            content.contentTransition(.numericText(value: value))
        }
    }
}

/// Lo mismo para una cifra ya escrita como texto («79,4K»), sin el valor que la animación usa para saber si sube o baja.
struct WidgetNumericTextTransition: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.contentTransition(reduceMotion ? .identity : .numericText())
    }
}

extension View {
    /// Al cambiar la entrada, la cifra rueda hasta la nueva (salvo con Reducir movimiento).
    func widgetNumericTransition(_ value: Double) -> some View {
        modifier(WidgetNumericTransition(value: value))
    }

    /// Igual, para una cifra que ya viene en texto.
    func widgetNumericTransition() -> some View {
        modifier(WidgetNumericTextTransition())
    }
}

// MARK: - Insignia

/// Círculo sólido con el icono en blanco: las fichas de la app (filas de presupuesto del Panel, referencia Kargul). En
/// tintado, translúcido con el icono a la vista.
struct WidgetBadge: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let systemImage: String
    let color: Color
    var size: CGFloat = WidgetDS.Icon.badgeSmall

    var body: some View {
        ZStack {
            Circle()
                .fill(renderingMode == .fullColor ? color : Color.primary.opacity(WidgetDS.Opacity.subtle))
            Image(systemName: systemImage)
                .font(.system(size: size * 0.5, weight: .semibold)) // A11Y-DT: el glifo escala con su insignia, de tamaño fijo
                .foregroundStyle(renderingMode == .fullColor ? Color.white : Color.primary)
                .accessibilityHidden(true)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Cabecera

/// Insignia + título, y a la derecha lo que la acompañe (el período, un botón). La misma jerarquía que la cabecera de
/// los widgets del Panel: título `subheadline` semibold, detalle en `caption` gris.
struct WidgetCardHeader<Trailing: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: WidgetDS.Spacing.sm) {
            WidgetBadge(systemImage: systemImage, color: tint)
            Text(title)
                .font(WidgetDS.Typography.subheadlineEmphasized)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: WidgetDS.Spacing.xs)
            trailing
        }
    }
}

extension WidgetCardHeader where Trailing == EmptyView {
    init(title: String, systemImage: String, tint: Color) {
        self.init(title: title, systemImage: systemImage, tint: tint) { EmptyView() }
    }
}

/// El detalle gris de la cabecera («Este mes»).
struct WidgetHeaderDetail: View {
    let text: String

    var body: some View {
        Text(text)
            .font(WidgetDS.Typography.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

// MARK: - Cifra grande

/// La cifra protagonista: la del hero del Panel (36 semibold, símbolo y decimales a 17 en gris), con la marca «≈» y la
/// transición numérica. Es lo único que se tiñe en tintado.
struct WidgetHeroAmount: View {
    let value: Double
    let currencyCode: String
    let displayFormat: String
    var isEstimate: Bool = false
    var tint: WidgetAmountText.Tint = .primary
    /// «+» delante de una cifra positiva: el neto de Entradas y salidas.
    var forceSign: Bool = false

    var body: some View {
        WidgetAmountText(
            value: value,
            currencyCode: currencyCode,
            displayFormat: displayFormat,
            font: WidgetDS.Typography.panelHeroAmount,
            secondaryFont: WidgetDS.Typography.panelHeroAmountSecondary,
            tint: tint,
            forceSign: forceSign,
            isEstimate: isEstimate,
            fractionDigits: 0
        )
        .widgetNumericTransition(value)
        .widgetAccentable()
    }
}

// MARK: - Píldora de variación

/// Lo que dice la píldora: bueno (índigo), malo (rosa) o neutro (gris). Los colores de la app para una variación
/// (`VariationChip`): en un gasto, subir es rosa y bajar índigo; en un saldo, al revés.
enum WidgetTone {
    case good, bad, neutral

    var textColor: Color {
        switch self {
        case .good: return WidgetColors.accentText
        case .bad: return WidgetColors.alertText
        case .neutral: return .secondary
        }
    }

    var fillColor: Color {
        switch self {
        case .good: return WidgetColors.electricIndigo
        case .bad: return WidgetColors.hotPink
        case .neutral: return .primary
        }
    }
}

/// Cápsula con relleno tenue del tono y el texto en su color legible. Sin degradados ni brillos.
struct WidgetPill: View {
    let text: String
    var systemImage: String? = nil
    let tone: WidgetTone

    var body: some View {
        HStack(spacing: WidgetDS.Spacing.xxs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(WidgetDS.Typography.badgeLabel)
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(WidgetDS.Typography.badgeLabel)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(tone.textColor)
        .padding(.horizontal, WidgetDS.Spacing.sm)
        .padding(.vertical, WidgetDS.Spacing.xxs)
        .background(Capsule().fill(tone.fillColor.opacity(WidgetDS.Opacity.subtle)))
    }
}

// MARK: - Barra con ritmo

/// Barra de progreso de la app (carril tenue, relleno sólido) con una muesca opcional: cuánto del período ya pasó.
/// Si el relleno va por delante de la muesca, se está gastando más rápido de lo que pasa el tiempo.
struct WidgetMeterBar: View {
    /// 0…1 (lo que pase de 1 llena la barra).
    let fraction: Double
    let color: Color
    /// 0…1, o `nil` sin ritmo (presupuesto único).
    var pace: Double? = nil
    var height: CGFloat = WidgetDS.Sizing.progressBarHeight

    var body: some View {
        Capsule()
            .fill(WidgetColors.track)
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(color)
                        .frame(width: max(height, geo.size.width * min(max(fraction, 0), 1)))
                        .widgetAccentable()
                }
            }
            .overlay(alignment: .leading) {
                if let pace {
                    GeometryReader { geo in
                        Capsule()
                            .fill(Color.primary)
                            .frame(width: WidgetDS.Spacing.xxs, height: height + WidgetDS.Spacing.xs)
                            .offset(x: geo.size.width * min(max(pace, 0), 1) - WidgetDS.Spacing.xxs / 2,
                                    y: -WidgetDS.Spacing.xxs)
                    }
                    .accessibilityHidden(true)
                }
            }
    }
}

// MARK: - Enlace sin tinte

/// Una zona del widget que abre otra pantalla que la del widget entero. Un `Link` pinta su contenido con el tinte (azul)
/// y los estilos jerárquicos de dentro (`.secondary`, `.tertiary`) se derivan de ese tinte: así salían azules los nombres
/// y los títulos del Resumen del mes (auditoría 2.2). Fijar `Color.primary` (no el `.primary` jerárquico, que también
/// deriva) devuelve el gris de la app a todo lo de dentro.
struct WidgetPlainLink<Content: View>: View {
    let destination: URL
    @ViewBuilder var content: Content

    var body: some View {
        Link(destination: destination) {
            content.foregroundStyle(Color.primary)
        }
    }
}

// MARK: - Donut

/// Una porción del donut: su color y lo que vale.
struct WidgetDonutSlice: Identifiable {
    let id: String
    let value: Double
    let color: Color
}

/// Aro de porciones sólidas con lo que se le ponga en el centro (el total). Sin burbujas ni rótulos: los nombres, los
/// importes y los porcentajes van en la leyenda de al lado. En tintado no se tiñe (lo teñido es la cifra).
struct WidgetDonut<Center: View>: View {
    let slices: [WidgetDonutSlice]
    @ViewBuilder var center: Center

    var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("valor", max(slice.value, 0)),
                innerRadius: .ratio(WidgetDS.Chart.donutInnerRatio),
                angularInset: WidgetDS.Chart.donutAngularInset
            )
            .foregroundStyle(slice.color)
        }
        .chartLegend(.hidden)
        .chartBackground { _ in center }
        .accessibilityHidden(true)
    }
}

// MARK: - Frescura

/// «Actualizado ayer» / «Actualizado el 29 oct.»: solo cuando la foto de la app no es de hoy. El widget no calcula nada
/// por su cuenta; si la app no se abre ni refresca en segundo plano, las cifras son las de ese día.
struct WidgetFreshnessNote: View {
    let lastUpdated: Date?
    let now: Date

    var body: some View {
        if let text = Self.text(lastUpdated: lastUpdated, now: now) {
            Text(text)
                .font(WidgetDS.Typography.captionSmall)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    static func text(lastUpdated: Date?, now: Date, calendar: Calendar = .current) -> String? {
        guard let lastUpdated, !calendar.isDate(lastUpdated, inSameDayAs: now) else { return nil }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)),
           calendar.isDate(lastUpdated, inSameDayAs: yesterday) {
            return String(localized: "widget.freshness.yesterday", bundle: .main)
        }
        let day = lastUpdated.formatted(.dateTime.day().month(.abbreviated))
        return String(format: String(localized: "widget.freshness.onDate", bundle: .main), day)
    }
}

// MARK: - Fechas en texto

enum WidgetDateText {
    /// «setiembre», «September», «wrzesień»: el mes solo, como va dentro de una frase («vs. setiembre»). La forma de
    /// fecha («MMMM») lo deja en minúscula en español, francés, italiano o portugués, donde la suelta y
    /// `formatted(.dateTime.month(.wide))` lo capitalizan. El polaco declina la forma de fecha («września»), así que
    /// ahí va la suelta.
    static func monthName(_ date: Date, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = locale.language.languageCode?.identifier == "pl" ? "LLLL" : "MMMM"
        return formatter.string(from: date)
    }

    /// «2025».
    static func year(_ date: Date) -> String {
        date.formatted(.dateTime.year())
    }

    /// Cuándo vence un pago: «Vencido · 28 oct.», «Hoy», «Mañana», «En 3 días» o la fecha. Lo comparten la fila de Pagos
    /// planificados y el de la pantalla bloqueada.
    static func due(_ date: Date, isOverdue: Bool, now: Date, calendar: Calendar = .current) -> String {
        let day = date.formatted(.dateTime.day().month(.abbreviated))
        switch WidgetInsightsLogic.dueLabel(due: date, isOverdue: isOverdue, now: now, calendar: calendar) {
        case .overdue: return String(localized: "widget.ui.overdue", bundle: .main) + " · " + day
        case .today: return String(localized: "widget.ui.today", bundle: .main)
        case .tomorrow: return String(localized: "widget.ui.tomorrow", bundle: .main)
        case .inDays(let days): return String(format: String(localized: "widget.payments.inDays", bundle: .main), days)
        case .date: return day
        }
    }
}

// MARK: - Refresco

enum WidgetRefresh {
    /// La política común: a la medianoche siguiente o en cuatro horas, lo que llegue antes. A medianoche cambian «Hoy»
    /// y «Mañana», el mes y el ritmo de los presupuestos; los datos nuevos llegan antes, cuando la app guarda algo
    /// (`WidgetDataCache.updateCache` recarga todos los widgets).
    static func nextDate(after now: Date, calendar: Calendar = .current) -> Date {
        let fourHours = calendar.date(byAdding: .hour, value: 4, to: now) ?? now.addingTimeInterval(4 * 3600)
        guard let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return fourHours
        }
        return min(midnight, fourHours)
    }

    /// Una entrada ahora y otra igual a medianoche. Lo que depende del día («Hoy», «Mañana», «En 3 días», «Ayer»)
    /// cambia a su hora aunque WidgetKit retrase la recarga: la recarga pedida es una petición, la entrada fechada no.
    static func dayAwareTimeline<Entry: TimelineEntry>(
        _ entry: Entry, calendar: Calendar = .current, redated: (Date) -> Entry
    ) -> Timeline<Entry> {
        let policy = TimelineReloadPolicy.after(nextDate(after: entry.date, calendar: calendar))
        guard let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: entry.date)) else {
            return Timeline(entries: [entry], policy: policy)
        }
        return Timeline(entries: [entry, redated(midnight)], policy: policy)
    }
}
