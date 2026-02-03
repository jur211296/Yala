//
//  QuickEntryWidgets.swift
//  YalaWidgets
//
//  Quick action widgets for entering transactions.
//  Three Small widgets: Manual, Voice, and Image entry.
//

import WidgetKit
import SwiftUI

// MARK: - Common Entry

struct QuickEntryEntry: TimelineEntry {
    let date: Date
}

// MARK: - Common Provider

struct QuickEntryProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickEntryEntry {
        QuickEntryEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickEntryEntry) -> Void) {
        completion(QuickEntryEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickEntryEntry>) -> Void) {
        let entry = QuickEntryEntry(date: Date())
        // These widgets don't need frequent updates
        let nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Manual Entry Widget

struct QuickManualEntryWidgetView: View {
    var body: some View {
        VStack(spacing: WDS.Spacing.md) {
            Spacer()

            ZStack {
                Circle()
                    .fill(WidgetColors.electricIndigo.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: WDS.Icon.xl))
                    .foregroundColor(WidgetColors.electricIndigo)
            }

            Text("Nuevo registro")
                .font(WDS.Typography.label)
                .foregroundStyle(.primary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(WDS.Spacing.xs)
        .widgetURL(URL(string: "yala://new-transaction"))
    }
}

struct QuickManualEntryWidget: Widget {
    let kind: String = "QuickManualEntryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: QuickEntryProvider()
        ) { _ in
            QuickManualEntryWidgetView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Nuevo registro")
        .description("Registra un gasto o ingreso manualmente")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Voice Entry Widget

struct QuickVoiceEntryWidgetView: View {
    var body: some View {
        VStack(spacing: WDS.Spacing.md) {
            Spacer()

            ZStack {
                Circle()
                    .fill(WidgetColors.yalaTeal.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: "mic.fill")
                    .font(.system(size: WDS.Icon.xl))
                    .foregroundColor(WidgetColors.yalaTeal)
            }

            Text("Registro por voz")
                .font(WDS.Typography.label)
                .foregroundStyle(.primary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(WDS.Spacing.xs)
        .widgetURL(URL(string: "yala://voice-entry"))
    }
}

struct QuickVoiceEntryWidget: Widget {
    let kind: String = "QuickVoiceEntryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: QuickEntryProvider()
        ) { _ in
            QuickVoiceEntryWidgetView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Registro por voz")
        .description("Dicta tu gasto o ingreso")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Image Entry Widget

struct QuickImageEntryWidgetView: View {
    var body: some View {
        VStack(spacing: WDS.Spacing.md) {
            Spacer()

            ZStack {
                Circle()
                    .fill(WidgetColors.hotPink.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: "camera.fill")
                    .font(.system(size: WDS.Icon.xl))
                    .foregroundColor(WidgetColors.hotPink)
            }

            Text("Escanear recibo")
                .font(WDS.Typography.label)
                .foregroundStyle(.primary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(WDS.Spacing.xs)
        .widgetURL(URL(string: "yala://image-entry"))
    }
}

struct QuickImageEntryWidget: Widget {
    let kind: String = "QuickImageEntryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: QuickEntryProvider()
        ) { _ in
            QuickImageEntryWidgetView()
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Escanear recibo")
        .description("Registra desde una foto o recibo")
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
