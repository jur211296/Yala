//
//  QuickEntryWidgets.swift
//  YalaWidgets
//
//  Quick action widgets for entering transactions.
//  Three Small widgets: Manual, Voice, and Image entry.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration Intent

struct QuickEntryWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "widget.intent.quickEntry.title" }
    static var description: IntentDescription { "widget.intent.quickEntry.desc" }

}

// MARK: - Timeline Entry

struct QuickEntryEntry: TimelineEntry {
    let date: Date

    static var placeholder: QuickEntryEntry {
        QuickEntryEntry(date: Date())
    }
}

// MARK: - Common Provider

struct QuickEntryProvider: AppIntentTimelineProvider {
    typealias Entry = QuickEntryEntry
    typealias Intent = QuickEntryWidgetIntent

    func placeholder(in context: Context) -> QuickEntryEntry {
        .placeholder
    }

    func snapshot(for configuration: QuickEntryWidgetIntent, in context: Context) async -> QuickEntryEntry {
        if context.isPreview {
            return .placeholder
        }
        return QuickEntryEntry(date: Date())
    }

    func timeline(for configuration: QuickEntryWidgetIntent, in context: Context) async -> Timeline<QuickEntryEntry> {
        let entry = QuickEntryEntry(date: Date())
        // These widgets don't need frequent updates
        let nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
}

// MARK: - Azulejo

/// Una acción de entrada rápida: el destino, su icono, su texto y su relleno. Los rellenos son los sólidos de la app
/// que llevan blanco encima con contraste AA (índigo profundo, rosa profundo, turquesa profundo).
enum QuickEntryAction: CaseIterable {
    case manual, voice, image

    var path: String {
        switch self {
        case .manual: return "new-transaction"
        case .voice: return "voice-entry"
        case .image: return "image-entry"
        }
    }

    var systemImage: String {
        switch self {
        case .manual: return "plus"
        case .voice: return "mic.fill"
        case .image: return "camera.fill"
        }
    }

    var fill: Color {
        switch self {
        case .manual: return WidgetColors.indigoFill
        case .voice: return WidgetColors.pinkFill
        case .image: return WidgetColors.tealFill
        }
    }

    /// El texto del azulejo pequeño (el nombre del widget en la galería).
    var title: String {
        switch self {
        case .manual: return String(localized: "widget.ui.newRecord", bundle: .main)
        case .voice: return String(localized: "widget.ui.voiceRecord", bundle: .main)
        case .image: return String(localized: "widget.ui.scanReceipt", bundle: .main)
        }
    }

    /// El texto corto del botón en el tamaño mediano.
    var shortTitle: String {
        switch self {
        case .manual: return String(localized: "widget.quick.manual", bundle: .main)
        case .voice: return String(localized: "widget.quick.voice", bundle: .main)
        case .image: return String(localized: "widget.quick.photo", bundle: .main)
        }
    }
}

/// El azulejo pequeño: el relleno es el fondo del widget (`containerBackground`) y encima, en blanco, el icono en su
/// círculo y el texto. En StandBy y en tintado el sistema quita el relleno, y el contenido sigue leyéndose porque es
/// del primario.
struct QuickEntryTileView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    let action: QuickEntryAction

    /// Sin el relleno (StandBy, tintado) el blanco fijo desaparecería sobre un fondo claro: se pasa al primario.
    private var onFill: Color { renderingMode == .fullColor && showsBackground ? .white : .primary }

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.none) {
            Image(systemName: action.systemImage)
                .font(WidgetDS.Typography.headline)
                .foregroundStyle(onFill)
                .frame(width: WidgetDS.Icon.badgeLarge, height: WidgetDS.Icon.badgeLarge)
                .background(Circle().fill(onFill.opacity(WidgetDS.Opacity.subtle)))
                .widgetAccentable()

            Spacer(minLength: WidgetDS.Spacing.sm)

            Text(action.title)
                .font(WidgetDS.Typography.headline)
                .foregroundStyle(onFill)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetURLHelper.url(for: action.path))
    }
}

/// El mediano de «Nuevo registro»: las tres maneras de registrar en un solo widget, cada una con su enlace.
struct QuickEntryRowView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.md) {
            WidgetCardHeader(
                title: String(localized: "widget.quick.title", bundle: .main),
                systemImage: "square.and.pencil",
                tint: WidgetColors.electricIndigo
            )
            HStack(spacing: WidgetDS.Spacing.sm) {
                ForEach(QuickEntryAction.allCases, id: \.self) { action in
                    QuickEntryButton(action: action)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetURLHelper.url(for: QuickEntryAction.manual.path))
    }
}

/// Un botón del mediano: relleno sólido con icono y texto en blanco; en tintado, translúcido.
private struct QuickEntryButton: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let action: QuickEntryAction

    private var solid: Bool { renderingMode == .fullColor }

    var body: some View {
        Link(destination: MonthSummaryLinks.url(action.path)) {
            VStack(spacing: WidgetDS.Spacing.xs) {
                Image(systemName: action.systemImage)
                    .font(WidgetDS.Typography.headline)
                Text(action.shortTitle)
                    .font(WidgetDS.Typography.labelSmall)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(solid ? Color.white : Color.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: WidgetDS.Radius.md, style: .continuous)
                    .fill(solid ? action.fill : Color.primary.opacity(WidgetDS.Opacity.subtle))
            )
        }
        .accessibilityLabel(Text(action.title))
    }
}

// MARK: - Manual Entry Widget

struct QuickManualEntryWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .systemMedium {
            QuickEntryRowView()
        } else {
            QuickEntryTileView(action: .manual)
        }
    }
}

struct QuickManualEntryWidget: Widget {
    let kind: String = "QuickManualEntryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: QuickEntryWidgetIntent.self,
            provider: QuickEntryProvider()
        ) { entry in
            QuickManualEntryWidgetView()
                .modifier(QuickEntryBackground(action: .manual))
        }
        .configurationDisplayName("widget.gallery.quickManual")
        .description("widget.gallery.quickManual.desc")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

/// El fondo: el relleno sólido en el pequeño y la tarjeta de siempre en el mediano (que lleva sus botones de color).
private struct QuickEntryBackground: ViewModifier {
    @Environment(\.widgetFamily) private var family
    let action: QuickEntryAction

    func body(content: Content) -> some View {
        content.containerBackground(family == .systemMedium ? WidgetColors.cardBackground : action.fill, for: .widget)
    }
}

// MARK: - Voice Entry Widget

struct QuickVoiceEntryWidgetView: View {
    var body: some View {
        QuickEntryTileView(action: .voice)
    }
}

struct QuickVoiceEntryWidget: Widget {
    let kind: String = "QuickVoiceEntryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: QuickEntryWidgetIntent.self,
            provider: QuickEntryProvider()
        ) { entry in
            QuickVoiceEntryWidgetView()
                .modifier(QuickEntryBackground(action: .voice))
        }
        .configurationDisplayName("widget.gallery.quickVoice")
        .description("widget.gallery.quickVoice.desc")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Image Entry Widget

struct QuickImageEntryWidgetView: View {
    var body: some View {
        QuickEntryTileView(action: .image)
    }
}

struct QuickImageEntryWidget: Widget {
    let kind: String = "QuickImageEntryWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: QuickEntryWidgetIntent.self,
            provider: QuickEntryProvider()
        ) { entry in
            QuickImageEntryWidgetView()
                .modifier(QuickEntryBackground(action: .image))
        }
        .configurationDisplayName("widget.gallery.quickImage")
        .description("widget.gallery.quickImage.desc")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Previews

#Preview("Manual Entry", as: .systemSmall) {
    QuickManualEntryWidget()
} timeline: {
    QuickEntryEntry(date: Date())
}

#Preview("Voice Entry", as: .systemSmall) {
    QuickVoiceEntryWidget()
} timeline: {
    QuickEntryEntry(date: Date())
}

#Preview("Image Entry", as: .systemSmall) {
    QuickImageEntryWidget()
} timeline: {
    QuickEntryEntry(date: Date())
}

#Preview("Three actions", as: .systemMedium) {
    QuickManualEntryWidget()
} timeline: {
    QuickEntryEntry(date: Date())
}
