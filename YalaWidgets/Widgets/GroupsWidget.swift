//
//  GroupsWidget.swift
//  YalaWidgets
//
//  «Grupos» (2.2, S35f3): cuánto debes y cuánto te deben, como arriba de la lista de Grupos, y los grupos con su saldo.
//  Mediano: el resumen y dos grupos. Grande: el resumen, cinco grupos y la frescura de la foto.
//
//  Las cifras las calcula la app con las funciones de la lista (`WidgetGroupsSnapshotBuilder`); el widget solo decide el
//  orden de las filas (`WidgetInsightsLogic.orderedGroupRows`: primero lo que debes) y cómo se escriben. Los colores son
//  los de la lista (`groupOweText` / `groupOwedText`), y la flecha de cada lado dice lo mismo sin depender del color.
//
//  Toque: el widget abre Grupos; cada fila, su grupo (`groups/<id>`, con las puertas de siempre). Sin grupos, invita a
//  crear uno y abre la pestaña, que guía la sesión y el consentimiento.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct GroupsWidgetEntry: TimelineEntry {
    var date: Date
    /// Los grupos que calculó la app. `nil` con una foto anterior a 2.2 (no los trae).
    let groups: WidgetGroupsSummary?
    let currencyDisplayFormat: String
    let isPlaceholder: Bool
    /// Cuándo escribió la app la foto.
    var lastUpdated: Date? = nil

    static var placeholder: GroupsWidgetEntry {
        GroupsWidgetEntry(
            date: Date(),
            groups: WidgetGroupsSummary(
                iOwe: [WidgetGroupAmount(currencyCode: "PEN", amount: 86.5)],
                owedToMe: [WidgetGroupAmount(currencyCode: "PEN", amount: 240)],
                activeGroupCount: 3,
                groups: [
                    WidgetGroupBalance(id: "1", name: "Viaje a Cusco", iconName: "airplane", colorHex: "#8B5CF6",
                                       iOwe: [], owedToMe: [WidgetGroupAmount(currencyCode: "PEN", amount: 240)]),
                    WidgetGroupBalance(id: "2", name: "Depa", iconName: "house.fill", colorHex: "#00C2CB",
                                       iOwe: [WidgetGroupAmount(currencyCode: "PEN", amount: 86.5)], owedToMe: []),
                    WidgetGroupBalance(id: "3", name: "Fútbol de los jueves", iconName: "soccerball", colorHex: "#F59E0B",
                                       iOwe: [], owedToMe: [])
                ]
            ),
            currencyDisplayFormat: "symbol",
            isPlaceholder: true
        )
    }
}

// MARK: - Timeline Provider

struct GroupsWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GroupsWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (GroupsWidgetEntry) -> Void) {
        completion(context.isPreview ? .placeholder : createEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GroupsWidgetEntry>) -> Void) {
        let entry = createEntry()
        // Los saldos llegan cuando la app reescribe la foto; la recarga periódica solo mueve la frescura.
        completion(Timeline(entries: [entry], policy: .after(WidgetRefresh.nextDate(after: entry.date))))
    }

    /// Cuántas filas caben por tamaño.
    static func rowLimit(for family: WidgetFamily) -> Int {
        family == .systemLarge ? 5 : 2
    }

    func createEntry() -> GroupsWidgetEntry {
        GroupsWidgetEntry(
            date: Date(),
            groups: WidgetDataService.getGroups(),
            currencyDisplayFormat: WidgetDataService.getCurrencyDisplayFormat(),
            isPlaceholder: false,
            lastUpdated: WidgetDataService.getLastUpdated()
        )
    }
}

// MARK: - Widget View

struct GroupsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GroupsWidgetEntry

    private var isLarge: Bool { family == .systemLarge }

    var body: some View {
        // El mediano va justo de alto (cabecera, resumen y dos filas): separación `xs`, o la segunda fila se corta en un
        // iPhone pequeño (lo cazó la review).
        VStack(alignment: .leading, spacing: isLarge ? WidgetDS.Spacing.md : WidgetDS.Spacing.xs) {
            WidgetCardHeader(
                title: String(localized: "widget.gallery.groups", bundle: .main),
                systemImage: "person.2.fill",
                tint: WidgetColors.electricIndigo
            )

            if let groups = entry.groups {
                if groups.activeGroupCount == 0 && !groups.hasArchivedDebt {
                    Spacer(minLength: 0)
                    WidgetCreateFirstView(icon: "person.badge.plus", message: "widget.empty.noGroupsYet")
                    Spacer(minLength: 0)
                } else if groups.activeGroupCount == 0 {
                    // Solo archivados con algo pendiente: como la lista, la deuda que sigue viva y nada más.
                    Spacer(minLength: 0)
                    GroupsArchivedDebtLines(groups: groups, displayFormat: entry.currencyDisplayFormat,
                                            font: WidgetDS.Typography.subheadline)
                    Spacer(minLength: 0)
                } else {
                    GroupsSummaryRow(groups: groups, displayFormat: entry.currencyDisplayFormat, isLarge: isLarge)
                    // La línea de archivados cabe en el grande; en el mediano, solo si no hay filas que enseñar.
                    if isLarge || groups.groups.isEmpty {
                        GroupsArchivedDebtLines(groups: groups, displayFormat: entry.currencyDisplayFormat,
                                                font: WidgetDS.Typography.captionSmall)
                    }
                    rows(groups)
                }
            } else {
                Spacer(minLength: 0)
                Text("widget.empty.openYalaGroups", bundle: .main)
                    .font(WidgetDS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(WidgetURLHelper.url(for: "groups"))
    }

    private func rows(_ groups: WidgetGroupsSummary) -> some View {
        let shown = WidgetInsightsLogic.orderedGroupRows(
            groups.groups, limit: GroupsWidgetProvider.rowLimit(for: family), side: \.side)
        // Separación fija y arriba: con dos grupos, repartir el alto del grande dejaba cada fila sola en su tercio.
        return VStack(alignment: .leading, spacing: isLarge ? WidgetDS.Spacing.md : WidgetDS.Spacing.xs) {
            ForEach(shown, id: \.id) { group in
                WidgetPlainLink(destination: MonthSummaryLinks.url("groups/\(group.id)")) {
                    GroupBalanceRowView(group: group, displayFormat: entry.currencyDisplayFormat)
                }
            }
            if isLarge {
                Spacer(minLength: WidgetDS.Spacing.none)
                WidgetFreshnessNote(lastUpdated: entry.lastUpdated, now: entry.date)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Resumen

/// «↗ Debes» y «↙ Te deben», lado a lado, con sus divisas unidas por « + » como arriba de la lista de Grupos (el global
/// no se netea: se debe a personas distintas). Sin nada pendiente, «¡Están al día!». Lo único que se tiñe.
struct GroupsSummaryRow: View {
    let groups: WidgetGroupsSummary
    let displayFormat: String
    var isLarge = false

    var body: some View {
        if groups.iOwe.isEmpty && groups.owedToMe.isEmpty {
            Text("widget.groups.allSettled", bundle: .main)
                .font(WidgetDS.Typography.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .widgetAccentable()
        } else {
            HStack(alignment: .top, spacing: WidgetDS.Spacing.md) {
                if !groups.iOwe.isEmpty {
                    side(label: "widget.groups.iOwe", systemImage: "arrow.up.right",
                         amounts: groups.iOwe, color: WidgetColors.groupOweText)
                }
                if !groups.owedToMe.isEmpty {
                    side(label: "widget.groups.owedToMe", systemImage: "arrow.down.left",
                         amounts: groups.owedToMe, color: WidgetColors.groupOwedText)
                }
            }
        }
    }

    private func side(
        label: LocalizedStringResource, systemImage: String, amounts: [WidgetGroupAmount], color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: WidgetDS.Spacing.none) {
            Label {
                Text(label)
            } icon: {
                Image(systemName: systemImage)
            }
            .font(WidgetDS.Typography.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            Text(GroupsWidgetText.amounts(amounts, displayFormat: displayFormat))
                .font(isLarge ? WidgetDS.Typography.title3 : WidgetDS.Typography.headline)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Archivados

/// «+ S/ 190.00 que te deben en grupos archivados», como debajo del total de la lista (L19-9): archivar no salda nada.
/// Sin nada pendiente en los archivados no pinta nada.
struct GroupsArchivedDebtLines: View {
    let groups: WidgetGroupsSummary
    let displayFormat: String
    let font: Font

    var body: some View {
        let owed = groups.archivedOwedToMe ?? []
        let owe = groups.archivedIOwe ?? []
        if !owed.isEmpty || !owe.isEmpty {
            VStack(alignment: .leading, spacing: WidgetDS.Spacing.none) {
                if !owed.isEmpty {
                    Text(String(format: String(localized: "widget.groups.archivedOwedLine", bundle: .main),
                                GroupsWidgetText.amounts(owed, displayFormat: displayFormat)))
                }
                if !owe.isEmpty {
                    Text(String(format: String(localized: "widget.groups.archivedOweLine", bundle: .main),
                                GroupsWidgetText.amounts(owe, displayFormat: displayFormat)))
                }
            }
            .font(font)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .accessibilityElement(children: .combine)
        }
    }
}

extension WidgetGroupsSummary {
    var hasArchivedDebt: Bool {
        !(archivedOwedToMe ?? []).isEmpty || !(archivedIOwe ?? []).isEmpty
    }
}

// MARK: - Fila de grupo

/// Un grupo: su insignia (icono y color del grupo), el nombre y, a la derecha, lo que debes o te deben en él con la flecha
/// de su lado, o «Al día».
struct GroupBalanceRowView: View {
    let group: WidgetGroupBalance
    let displayFormat: String

    var body: some View {
        HStack(spacing: WidgetDS.Spacing.sm) {
            WidgetBadge(systemImage: group.iconName, color: WidgetColors.fill(hex: group.colorHex))

            Text(group.name)
                .font(WidgetDS.Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: WidgetDS.Spacing.xs)

            trailing
        }
        .accessibilityElement(children: .combine)
    }

    /// Lo que debes y, si en otra divisa te deben, también eso debajo: la fila va al lado de «debes», pero no esconde
    /// el otro.
    @ViewBuilder
    private var trailing: some View {
        switch group.side {
        case .iOwe, .owedToMe:
            VStack(alignment: .trailing, spacing: WidgetDS.Spacing.none) {
                if !group.iOwe.isEmpty {
                    amount(group.iOwe, systemImage: "arrow.up.right", label: "widget.groups.iOwe",
                           color: WidgetColors.groupOweText)
                }
                if !group.owedToMe.isEmpty {
                    amount(group.owedToMe, systemImage: "arrow.down.left", label: "widget.groups.owedToMe",
                           color: WidgetColors.groupOwedText)
                }
            }
        case .settled:
            Text("widget.groups.rowSettled", bundle: .main)
                .font(WidgetDS.Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func amount(
        _ amounts: [WidgetGroupAmount], systemImage: String, label: LocalizedStringResource, color: Color
    ) -> some View {
        HStack(spacing: WidgetDS.Spacing.xxs) {
            Image(systemName: systemImage)
                .font(WidgetDS.Typography.captionSmall)
                .accessibilityLabel(Text(label))
            Text(GroupsWidgetText.amounts(amounts, displayFormat: displayFormat))
                .font(WidgetDS.Typography.subheadlineEmphasized)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(color)
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension WidgetGroupBalance {
    /// El lado que enseña su fila: con una divisa a favor y otra en contra, «debes» (primero lo que debes).
    var side: WidgetInsightsLogic.GroupSide {
        WidgetInsightsLogic.groupSide(owes: !iOwe.isEmpty, isOwed: !owedToMe.isEmpty)
    }
}

enum GroupsWidgetText {
    /// «S/ 120.00 + $ 30.00»: cada divisa con sus decimales, como la lista de Grupos (`forceFullPrecision`).
    static func amounts(_ amounts: [WidgetGroupAmount], displayFormat: String) -> String {
        amounts
            .map { amount in
                WidgetAmountSplitter.split(
                    value: amount.amount,
                    symbol: CurrencySymbols.display(for: amount.currencyCode, format: displayFormat),
                    fractionDigits: 2
                ).accessibilityFormatted
            }
            .joined(separator: " + ")
    }
}

// MARK: - Widget Definition

struct GroupsWidget: Widget {
    let kind: String = "GroupsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GroupsWidgetProvider()) { entry in
            GroupsWidgetView(entry: entry)
                .invitesToOpenYalaWithoutData(isPlaceholder: entry.isPlaceholder, message: "widget.empty.openYalaGroups")
                .invitesToActivateFullWhenGroupsOnly()
                .containerBackground(WidgetColors.cardBackground, for: .widget)
        }
        .configurationDisplayName("widget.gallery.groups")
        .description("widget.gallery.groups.desc")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview("Medium", as: .systemMedium) {
    GroupsWidget()
} timeline: {
    GroupsWidgetEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
    GroupsWidget()
} timeline: {
    GroupsWidgetEntry.placeholder
}
