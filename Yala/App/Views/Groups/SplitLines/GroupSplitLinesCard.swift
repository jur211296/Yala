//
//  GroupSplitLinesCard.swift
//  Yala
//
//  Tarjeta «Tu parte» de Grupos B (`docs/disenos/grupos-tu-parte-en-lineas/README.md`, «Versión final acordada»; maqueta
//  `opcion-b.html`, escenarios 1, 3 y 7): tu parte de un gasto de grupo partida en líneas de Gasto o Recarga, «Añadir
//  línea» y el cuadre («Cuadra» / «Faltan S/ X»). Tocar una línea abre su hoja (`GroupSplitLineSheet`).
//
//  Solo el componente: lo montan la hoja de la Bandeja y la de «Partir tu parte» (tarjetas 5 y 6), que encienden su
//  «Guardar»/«Aprobar» con `GroupSplitLinesEditorLogic.canSave`. Las reglas viven en `GroupSplitLinesRecipe`; aquí solo
//  se pintan.
//

import SwiftData
import SwiftUI

struct GroupSplitLinesCard: View {

    // MARK: - Input

    @Binding var lines: [GroupSplitLinesRecipe.Line]
    /// Tu parte del gasto, en su divisa. Puede traer más decimales que la divisa (511/3): se redondea al compararla.
    let share: Decimal
    let currencyCode: String
    /// De dónde sale una recarga: «Grupos» si pagó otro, la cuenta con que pagaste si pagaste tú.
    let transferSourceName: String
    /// La cuenta de la que sale la recarga, si es tuya: no se ofrece como destino.
    var transferSourceAccount: Account? = nil

    // MARK: - Environment

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Query private var accounts: [Account]
    @Query private var subcategories: [Subcategory]

    @State private var editing: EditingLine?

    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 36 // A11Y-DT: @ScaledMetric

    /// Qué abre la hoja de una línea.
    private struct EditingLine: Identifiable {
        let id: UUID
        let line: GroupSplitLinesRecipe.Line?
        let suggestedAmount: Decimal?
    }

    // MARK: - Body

    var body: some View {
        let destinations = GroupSplitLinesCard.destinationInfo(accounts)
        let unavailable = GroupSplitLinesEditorLogic.linesWithUnavailableDestination(
            lines, destinations: destinations, currencyCode: currencyCode
        )
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            Text(L10n.Groups.SplitLines.title(format(share)))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.sm)
                .accessibilityAddTraits(.isHeader)

            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                lineRow(line, index: index, isUnavailable: unavailable.contains(line.id))
                SubsectionDivider()
            }

            footer
        }
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(.thCard))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("split_lines_card")
        .sheet(item: $editing) { item in
            GroupSplitLineSheet(
                initialLine: item.line,
                suggestedAmount: item.suggestedAmount,
                currencyCode: currencyCode,
                transferSourceName: transferSourceName,
                transferSourceAccount: transferSourceAccount,
                canDelete: item.line != nil && GroupSplitLinesEditorLogic.canRemove(from: lines),
                onSave: { saved in lines = GroupSplitLinesEditorLogic.upserting(saved, into: lines) },
                onDelete: { lines = GroupSplitLinesEditorLogic.removing(item.id, from: lines) }
            )
        }
    }

    // MARK: - Fila de una línea

    private func lineRow(_ line: GroupSplitLinesRecipe.Line, index: Int, isUnavailable: Bool) -> some View {
        let label = rowLabel(line, isUnavailable: isUnavailable)
        let amount = format(line.amount)
        return Button {
            editing = EditingLine(id: line.id, line: line, suggestedAmount: nil)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle().fill(label.color.opacity(0.15))
                    Image(systemName: label.icon)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(label.color)
                }
                .frame(width: iconSize, height: iconSize)
                .accessibilityHidden(true)

                rowTexts(label: label, amount: amount)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([label.title, label.subtitle, amount].joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("split_lines_row_\(index)")
    }

    /// Título y subtítulo a la izquierda, importe a la derecha. Con letra de accesibilidad el importe baja debajo.
    @ViewBuilder
    private func rowTexts(label: RowLabel, amount: String) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xxs))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.sm))
        layout {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(label.title)
                    .font(DS.Typography.body)
                    .foregroundStyle(label.titleIsMissing ? AnyShapeStyle(.thAccentText) : AnyShapeStyle(.primary))
                Text(label.subtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(label.subtitleIsWarning ? AnyShapeStyle(Color.groupOweAmount) : AnyShapeStyle(.secondary))
            }
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: DS.Spacing.sm) }
            Text(amount)
                .font(DS.Typography.body.monospacedDigit())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct RowLabel {
        let icon: String
        let color: Color
        let title: String
        let subtitle: String
        var titleIsMissing = false
        var subtitleIsWarning = false
    }

    private func rowLabel(_ line: GroupSplitLinesRecipe.Line, isUnavailable: Bool) -> RowLabel {
        switch line.kind {
        case .expense:
            guard let id = line.subcategoryID, let subcategory = subcategories.first(where: { $0.shortcutID == id }) else {
                return RowLabel(icon: "tag", color: theme.accent, title: L10n.Groups.SplitLines.chooseCategory,
                                subtitle: L10n.Transaction.TransactionType.expense, titleIsMissing: true)
            }
            let hex = subcategory.colorHex ?? subcategory.safeCategory.colorHex
            return RowLabel(icon: subcategory.iconName ?? subcategory.safeCategory.iconName ?? "tag.fill",
                            color: Color(hex: hex), title: subcategory.name,
                            subtitle: L10n.Transaction.TransactionType.expense)
        case .transfer:
            let account = line.destinationAccountID.flatMap { id in accounts.first { $0.shortcutID == id } }
            guard let account else {
                return RowLabel(icon: "arrow.left.arrow.right", color: theme.accent,
                                title: L10n.Groups.SplitLines.chooseAccount,
                                subtitle: line.destinationAccountID == nil
                                    ? L10n.Groups.SplitLines.transferSubtitle
                                    : L10n.Groups.SplitLines.destinationUnavailable,
                                titleIsMissing: true, subtitleIsWarning: line.destinationAccountID != nil)
            }
            return RowLabel(icon: "arrow.left.arrow.right", color: Color(hex: account.colorHex),
                            title: L10n.Groups.SplitLines.transferTo(account.name),
                            subtitle: isUnavailable
                                ? L10n.Groups.SplitLines.destinationUnavailable
                                : L10n.Groups.SplitLines.transferSubtitle,
                            subtitleIsWarning: isUnavailable)
        }
    }

    // MARK: - Pie: «Añadir línea» y cuadre

    private var footer: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.sm))
        return layout {
            Button {
                editing = EditingLine(
                    id: UUID(), line: nil,
                    suggestedAmount: GroupSplitLinesEditorLogic.amountForNewLine(
                        lines, share: share, currencyCode: currencyCode
                    )
                )
            } label: {
                Label(L10n.Groups.SplitLines.addLine, systemImage: "plus")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thAccentText)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("split_lines_add")

            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: DS.Spacing.sm) }

            balanceBadge
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    @ViewBuilder
    private var balanceBadge: some View {
        Group {
            switch GroupSplitLinesRecipe.balance(of: lines, share: share, currencyCode: currencyCode) {
            case .balanced:
                Label(L10n.Groups.SplitLines.balanced, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.groupOwedAmount)
            case .missing(let amount):
                Label(L10n.Groups.SplitLines.missing(format(amount)), systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(Color.groupOweAmount)
            case .over(let amount):
                Label(L10n.Groups.SplitLines.over(format(amount)), systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(Color.groupOweAmount)
            }
        }
        .font(DS.Typography.subheadline)
        .accessibilityIdentifier("split_lines_status")
    }

    // MARK: - Helpers

    private func format(_ amount: Decimal) -> String {
        appPreferences.currency(NSDecimalNumber(decimal: amount).doubleValue, currencyCode: currencyCode,
                                forceFullPrecision: true)
    }

    /// Lo que la lógica necesita de cada cuenta para decidir si sirve de destino, por `shortcutID`.
    static func destinationInfo(_ accounts: [Account]) -> [UUID: GroupSplitLinesEditorLogic.DestinationInfo] {
        var result: [UUID: GroupSplitLinesEditorLogic.DestinationInfo] = [:]
        for account in accounts {
            result[account.shortcutID] = .init(
                currencyCode: account.currencyCode,
                isSystemAccount: account.isSystemAccount,
                isArchived: account.isArchived
            )
        }
        return result
    }
}

// MARK: - Previews

#if DEBUG

/// Datos de las previews: el caso Pía (S/ 510 = recarga 500 a Sip + Comisiones 10) en un almacén en memoria.
@MainActor
enum GroupSplitLinesPreviewFixture {
    struct Seeded {
        let container: ModelContainer
        let sip: Account
        let bcp: Account
        let fees: Subcategory
        let groceries: Subcategory
    }

    static func make() -> Seeded {
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: Account.self, Category.self, Subcategory.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            fatalError("GroupSplitLinesPreviewFixture: \(error)")
        }
        let context = container.mainContext
        let sip = Account(name: "Sip", currencyCode: "PEN", colorHex: "#0EA5E9", iconName: "creditcard", type: "debit")
        let bcp = Account(name: "BCP", currencyCode: "PEN", colorHex: "#F97316", iconName: "creditcard", type: "debit")
        let usd = Account(name: "Wise USD", currencyCode: "USD", colorHex: "#22C55E", iconName: "creditcard", type: "debit")
        let groups = Account(name: "Grupos", currencyCode: "PEN", colorHex: "#6366F1", iconName: "person.3",
                             type: "checking", isSystemAccount: true)
        let services = Category(name: "Servicios", colorHex: "#8B5CF6", isIncome: false, iconName: "percent")
        let food = Category(name: "Comida", colorHex: "#10B981", isIncome: false, iconName: "cart")
        let fees = Subcategory(name: "Comisiones", iconName: "percent", category: services)
        let groceries = Subcategory(name: "Supermercado", iconName: "cart.fill", category: food)
        for model in [sip, bcp, usd, groups] { context.insert(model) }
        context.insert(services)
        context.insert(food)
        context.insert(fees)
        context.insert(groceries)
        return Seeded(container: container, sip: sip, bcp: bcp, fees: fees, groceries: groceries)
    }

    static func piaLines(_ seeded: Seeded) -> [GroupSplitLinesRecipe.Line] {
        [.transfer(amount: 500, destinationAccountID: seeded.sip.shortcutID),
         .expense(amount: 10, subcategoryID: seeded.fees.shortcutID)]
    }
}

private struct GroupSplitLinesCardPreview: View {
    let share: Decimal
    let seeded = GroupSplitLinesPreviewFixture.make()
    @State private var lines: [GroupSplitLinesRecipe.Line] = []

    var body: some View {
        ScrollView {
            GroupSplitLinesCard(lines: $lines, share: share, currencyCode: "PEN", transferSourceName: "Grupos")
                .padding(DS.Spacing.lg)
        }
        .yalaScreenBackground(.subtle)
        .modelContainer(seeded.container)
        .previewAppPreferences()
        .onAppear { if lines.isEmpty { lines = GroupSplitLinesPreviewFixture.piaLines(seeded) } }
    }
}

#Preview("Cuadra") {
    GroupSplitLinesCardPreview(share: 510)
}

#Preview("Faltan S/ 10") {
    GroupSplitLinesCardPreview(share: 520)
}

#Preview("Sobran S/ 10") {
    GroupSplitLinesCardPreview(share: 500)
}
#endif
