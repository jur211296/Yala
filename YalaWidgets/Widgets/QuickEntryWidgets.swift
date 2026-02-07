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

    @Parameter(title: "widget.theme.type", default: .system)
    var theme: WidgetThemeOption
}

// MARK: - Timeline Entry

struct QuickEntryEntry: TimelineEntry {
    let date: Date
    let theme: WidgetThemeOption

    static var placeholder: QuickEntryEntry {
        QuickEntryEntry(date: Date(), theme: .system)
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
        return QuickEntryEntry(date: Date(), theme: configuration.theme)
    }

    func timeline(for configuration: QuickEntryWidgetIntent, in context: Context) async -> Timeline<QuickEntryEntry> {
        let entry = QuickEntryEntry(date: Date(), theme: configuration.theme)
        // These widgets don't need frequent updates
        let nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
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
                    .frame(width: WDS.QuickEntry.circleSize, height: WDS.QuickEntry.circleSize)

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: WDS.Icon.xl))
                    .foregroundColor(WidgetColors.electricIndigo)
                    .widgetAccentable()
            }

            Text("widget.ui.newRecord", bundle: .main)
                .font(WDS.Typography.label)
                .foregroundStyle(.primary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(WDS.Spacing.xs)
        .widgetURL(WidgetURLHelper.url(for: "new-transaction"))
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
                .containerBackground(for: .widget) {
                    if entry.theme == .system {
                        ContainerRelativeShape().fill(.tertiary)
                    } else {
                        WidgetColors.yalaCard
                    }
                }
        }
        .configurationDisplayName("widget.gallery.quickManual")
        .description("widget.gallery.quickManual.desc")
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
                    .fill(WidgetColors.hotPink.opacity(0.15))
                    .frame(width: WDS.QuickEntry.circleSize, height: WDS.QuickEntry.circleSize)

                Image(systemName: "mic.fill")
                    .font(.system(size: WDS.Icon.xl))
                    .foregroundColor(WidgetColors.hotPink)
                    .widgetAccentable()
            }

            Text("widget.ui.voiceRecord", bundle: .main)
                .font(WDS.Typography.label)
                .foregroundStyle(.primary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(WDS.Spacing.xs)
        .widgetURL(WidgetURLHelper.url(for: "voice-entry"))
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
                .containerBackground(for: .widget) {
                    if entry.theme == .system {
                        ContainerRelativeShape().fill(.tertiary)
                    } else {
                        WidgetColors.yalaCard
                    }
                }
        }
        .configurationDisplayName("widget.gallery.quickVoice")
        .description("widget.gallery.quickVoice.desc")
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
                    .fill(WidgetColors.yalaTeal.opacity(0.15))
                    .frame(width: WDS.QuickEntry.circleSize, height: WDS.QuickEntry.circleSize)

                Image(systemName: "camera.fill")
                    .font(.system(size: WDS.Icon.xl))
                    .foregroundColor(WidgetColors.yalaTeal)
                    .widgetAccentable()
            }

            Text("widget.ui.scanReceipt", bundle: .main)
                .font(WDS.Typography.label)
                .foregroundStyle(.primary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(WDS.Spacing.xs)
        .widgetURL(WidgetURLHelper.url(for: "image-entry"))
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
                .containerBackground(for: .widget) {
                    if entry.theme == .system {
                        ContainerRelativeShape().fill(.tertiary)
                    } else {
                        WidgetColors.yalaCard
                    }
                }
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
    QuickEntryEntry(date: Date(), theme: .system)
}

#Preview("Voice Entry", as: .systemSmall) {
    QuickVoiceEntryWidget()
} timeline: {
    QuickEntryEntry(date: Date(), theme: .system)
}

#Preview("Image Entry", as: .systemSmall) {
    QuickImageEntryWidget()
} timeline: {
    QuickEntryEntry(date: Date(), theme: .system)
}
