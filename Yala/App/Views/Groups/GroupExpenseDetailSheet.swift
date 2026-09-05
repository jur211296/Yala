//
//  GroupExpenseDetailSheet.swift
//  Yala
//
//  Sheet de detalle read-only de un gasto compartido (Grupos). Detent fijo:
//  medium en iPhone (quick look estilo Wallet), large en iPad. La edición se
//  alcanza con el botón Editar, que cierra este sheet y deja que el padre
//  presente GroupExpenseFormView en su `onDismiss` (reemplazo de sheet nativo:
//  este baja, el editor sube en large). Réplica del flujo de TransactionDetailSheet
//  de Records, adaptado al modelo SplitExpense.
//
//  Diseño neutro: sobre el fondo transparent del detent medium los tintes finos
//  se pierden — montos, íconos y labels van en primary/secondary; el color solo
//  vive en fills sólidos (badge de categoría/división) y en el monto de perspectiva.
//

import SwiftData
import SwiftUI

struct GroupExpenseDetailSheet: View {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.locale = AppLocale.current
        return f
    }()

    private static let rowIconWidth: CGFloat = 20

    let expense: SplitExpense
    /// Mi share en este gasto (nil si no participo → "No participaste").
    let share: SplitShare?
    /// TX personal del bridge (si auto-match exitosa) — aporta subcategoría/categoría.
    let bridgeTransaction: TransactionItem?
    /// `[nombre normalizado de subcategoría: (icono, colorHex)]` de las subcategorías locales.
    /// Fallback self-contained del icono/categoría cuando no hay bridge (device fresco / no-participante):
    /// casa `SplitExpense.subcategoryName` del creador. SSOT vía `GroupExpenseIconResolver`.
    let subcategoryNameLookup: [String: (iconName: String, colorHex: String)]
    let memberNameLookup: [String: String]
    /// uuidString del current member (para detectar si yo soy el payer).
    let currentMemberID: String?

    /// Botón Editar. El padre marca pendingEdit y cierra este sheet; al cerrarse
    /// presenta GroupExpenseFormView (reemplazo de sheet nativo).
    let onEdit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences

    /// Detent fijo: medium (iPhone) / large (iPad). Mismo patrón que TransactionDetailSheet.
    private var detent: PresentationDetent {
        DS.Adaptive.usesLargeSheets ? .large : .medium
    }

    var body: some View {
        detailContent
            .presentationDetents([detent])
            .presentationDragIndicator(.hidden)
    }

    // MARK: - Detail content

    private var detailContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    compactHero
                    detailsCard
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.xl)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                    .accessibilityIdentifier("group_expense_detail_close")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Action.edit) {
                        onEdit()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primary)
                    .accessibilityIdentifier("group_expense_detail_edit")
                }
            }
            .yalaScreenBackground(DS.Adaptive.usesLargeSheets ? .subtle : .transparent)
        }
        .accessibilityIdentifier("group_expense_detail_sheet")
    }

    // MARK: - Classification

    private var isPayer: Bool {
        expense.paidByMemberID == currentMemberID
    }

    private var status: PersonalShareStatus {
        GroupExpenseAmountResolver.resolve(
            expense: expense,
            share: share,
            currentMemberID: currentMemberID
        )
    }

    private var payerName: String {
        // "(Tú)" — misma etiqueta que MemberPickerView/GroupMemberRow para el current
        // user (no `Split.youLabel`, que es el posesivo "Tu" del chip de división).
        isPayer ? L10n.Groups.Member.you : (memberNameLookup[expense.paidByMemberID] ?? "?")
    }

    private var splitTypeLabel: String {
        switch expense.splitType {
        case "percentage": return L10n.Split.typePercentage
        case "exact": return L10n.Split.typeExact
        case "shares": return L10n.Split.typeShares
        default: return L10n.Split.typeEqual
        }
    }

    private var splitTypeIcon: String {
        switch expense.splitType {
        case "percentage": return "percent"
        case "exact": return "number"
        case "shares": return "chart.pie.fill"
        default: return "equal.circle.fill"
        }
    }

    /// Subcategoría del bridge personal (si la auto-match fue exitosa y no es de sistema).
    private var bridgeSubcategory: Subcategory? {
        guard let sub = bridgeTransaction?.subcategory, !sub.isAnySystem else { return nil }
        return sub
    }

    /// Icono+color del bridge personal, o `nil`. Fallback de icono `?? splitTypeIcon` reproduce el
    /// hero previo byte a byte para el caso bridge (el hero neutro usa el ícono del tipo de división).
    private var bridgeIconTuple: (iconName: String, colorHex: String)? {
        guard let sub = bridgeSubcategory else { return nil }
        return (sub.iconName ?? splitTypeIcon, sub.safeCategory.colorHex)
    }

    /// Cadena bridge-first → nombre del creador → genérico (icono del tipo de división).
    private var resolvedIcon: ResolvedIcon {
        GroupExpenseIconResolver.resolve(
            bridgeIcon: bridgeIconTuple,
            subcategoryName: expense.subcategoryName,
            nameLookup: subcategoryNameLookup,
            fallbackIconName: splitTypeIcon
        )
    }

    /// Nombre de subcategoría a mostrar en la fila de categoría: el del bridge (LOCAL) si existe,
    /// sino el del creador que viaja en el gasto.
    private var categoryDisplayName: String {
        bridgeSubcategory?.name ?? expense.subcategoryName ?? ""
    }

    // MARK: - Hero compacto (badge + monto total en línea, descripción · fecha debajo)

    private var compactHero: some View {
        VStack(spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                heroBadge

                AmountText(
                    value: expense.amount,
                    currencyCode: expense.currencyCode,
                    font: DS.Typography.largeTitle,
                    secondaryFont: DS.Typography.body,
                    tint: .primary,
                    forceFullPrecision: true
                )
            }

            descriptionAndDateLine
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// "Descripción · fecha" en una línea; sin descripción queda solo la fecha.
    private var descriptionAndDateLine: some View {
        let dateText = Self.dateFormatter.string(from: expense.date)
        let desc = expense.expenseDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        let descPart = Text(desc).foregroundStyle(.primary)
        let separatorPart = Text(" · ").foregroundStyle(.secondary)
        let datePart = Text(dateText).foregroundStyle(.secondary)

        return Group {
            if desc.isEmpty {
                datePart
            } else {
                Text("\(descPart)\(separatorPart)\(datePart)")
            }
        }
        .font(DS.Typography.subheadline)
        .lineLimit(1)
        .truncationMode(.tail)
    }

    /// Fill sólido (legible sobre el fondo transparent): color de la categoría resuelta (bridge o
    /// nombre del creador), sino un fill neutro con el ícono del tipo de división.
    private var heroBadge: some View {
        let resolved = resolvedIcon
        let fillColor = resolved.colorHex.map { Color(hex: $0) } ?? Color(.secondaryLabel)
        let iconName = resolved.iconName

        return ZStack {
            Circle()
                .fill(fillColor)
                .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)

            Image(systemName: iconName)
                .font(DS.Typography.label)
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Details card (filas neutras, patrón TransactionDetailSheet)

    private var detailsCard: some View {
        VStack(spacing: DS.Spacing.none) {
            detailRow(
                icon: "person.fill",
                label: L10n.Groups.Expense.paidByTitle,
                value: payerName
            )

            perspectiveRow

            detailRow(
                icon: "divide.circle",
                label: L10n.Groups.Expense.splitType,
                value: splitTypeLabel
            )

            // Categoría: bridge (nombre + categoría padre) o, sin bridge, el nombre del creador
            // (una línea — no tenemos la categoría padre sin el bridge). Genérico → sin fila.
            if !resolvedIcon.isGeneric {
                categoryRow(name: categoryDisplayName, parentName: bridgeSubcategory?.safeCategory.name)
            }

            if let note = expense.note?.trimmingCharacters(in: .whitespacesAndNewlines),
               !note.isEmpty {
                detailRow(icon: "note.text", label: L10n.Groups.Expense.noteLabel, value: note)
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(.thCard)
        )
    }

    // MARK: - Rows

    /// Perspectiva personal: monto coloreado (prestaste/te prestaron) o "No participaste".
    @ViewBuilder
    private var perspectiveRow: some View {
        switch status {
        case .youAreOwed(let amount):
            amountRow(
                icon: "arrow.up.circle",
                label: L10n.Groups.Expense.youAreOwed,
                amount: amount,
                tint: DS.Semantic.successForeground
            )
        case .youOwe(let amount):
            amountRow(
                icon: "arrow.down.circle",
                label: L10n.Groups.Expense.youOwe,
                amount: amount,
                tint: Color.hotPink
            )
        case .notIncluded:
            detailRow(
                icon: "minus.circle",
                label: L10n.Split.yourPortion,
                value: L10n.Groups.Expense.notIncluded
            )
        case .identityUnresolved:
            // No se sabe todavía quién soy en este grupo ⇒ la fila de «tu parte» NO se pinta.
            // Callarse es correcto; afirmar «No participaste» sin saberlo es el bug de device del
            // 2026-08-28, donde los dos teléfonos contaban el mismo gasto de forma distinta.
            EmptyView()
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: Self.rowIconWidth)
                .accessibilityHidden(true)

            Text(label)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    private func amountRow(icon: String, label: String, amount: Double, tint: Color) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: Self.rowIconWidth)
                .accessibilityHidden(true)

            Text(label)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            AmountText(
                value: amount,
                currencyCode: expense.currencyCode,
                font: DS.Typography.label,
                secondaryFont: DS.Typography.caption,
                tint: .color(tint),
                forceFullPrecision: true
            )
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    private func categoryRow(name: String, parentName: String?) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "tag")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: Self.rowIconWidth)
                .accessibilityHidden(true)

            Text(L10n.Groups.Expense.category)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                Text(name)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                if let parentName {
                    Text(parentName)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }
}
