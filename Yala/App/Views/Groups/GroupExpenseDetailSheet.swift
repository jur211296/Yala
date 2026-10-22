//
//  GroupExpenseDetailSheet.swift
//  Yala
//
//  Detalle read-only de un gasto compartido (Grupos), propuesta B de
//  `group-expense-views-redesign` («recibo»): lo que se abre a buscar va primero.
//
//  1. Cabecera: categoría, descripción, total y fecha.
//  2. «Tu parte»: una frase con lo que te toca («Le debes a Ana» · S/ 40).
//  3. «Reparto»: la lista de quién pone cuánto; la barra por persona, solo si no es a partes iguales.
//  4. Detalles: categoría, nota y, si el gasto llegó a tu registro personal, dónde quedó.
//
//  La edición sigue siendo un paso aparte (botón Editar → el padre presenta
//  GroupExpenseFormView en el `onDismiss`): un gasto de grupo lo ven todos los miembros,
//  así que abrirlo no lo edita.
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
    /// Todas las partes del gasto: alimentan la barra y la lista del reparto.
    let allShares: [SplitShare]
    /// TX personal del bridge (si auto-match exitosa) — aporta subcategoría/categoría y cuenta.
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

    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 32 // A11Y-DT: @ScaledMetric

    var body: some View {
        detailContent
            .yalaSheetDetents([.large])
            .presentationDragIndicator(.visible)
    }

    // MARK: - Detail content

    private var detailContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    hero
                    yourPartCard
                    breakdownCard
                    detailsCard
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
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
            .yalaScreenBackground(.subtle)
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

    /// Nombre de una persona dentro del reparto: «Tú» para el usuario actual (sin paréntesis:
    /// aquí es el nombre, no una marca junto a otro nombre).
    private func displayName(for memberID: String) -> String {
        if memberID == currentMemberID { return L10n.Groups.Member.youName }
        return memberNameLookup[memberID] ?? "?"
    }

    private var payerName: String {
        displayName(for: expense.paidByMemberID)
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

    // MARK: - Reparto (datos)

    /// Una fila del reparto. El pagador aparece aunque no tenga parte (pagó por otros).
    private struct BreakdownEntry: Identifiable {
        let id: String
        let name: String
        let amount: Double
        let isPayer: Bool
    }

    /// Pagador primero; el resto por nombre (tú también), para que la lista no salte entre gastos.
    private var breakdownEntries: [BreakdownEntry] {
        var amountsByMember: [String: Double] = [:]
        for share in allShares where share.amount.isFinite {
            amountsByMember[share.memberID, default: 0] += share.amount
        }
        var entries = amountsByMember.map { memberID, amount in
            BreakdownEntry(
                id: memberID,
                name: displayName(for: memberID),
                amount: amount,
                isPayer: memberID == expense.paidByMemberID
            )
        }
        if amountsByMember[expense.paidByMemberID] == nil, !expense.paidByMemberID.isEmpty {
            entries.append(BreakdownEntry(
                id: expense.paidByMemberID,
                name: payerName,
                amount: 0,
                isPayer: true
            ))
        }
        return entries.sorted { lhs, rhs in
            if lhs.isPayer != rhs.isPayer { return lhs.isPayer }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private var memberColors: [String: Color] {
        let ids = Array(Set(Array(memberNameLookup.keys) + breakdownEntries.map(\.id)))
        return GroupMemberPalette.colors(for: ids, currentMemberID: currentMemberID, names: memberNameLookup)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: DS.Spacing.xs) {
            heroBadge
                .padding(.bottom, DS.Spacing.xxs)

            let desc = expense.expenseDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            if !desc.isEmpty {
                Text(desc)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            AmountText(
                value: expense.amount,
                currencyCode: expense.currencyCode,
                font: DS.Typography.largeTitle,
                secondaryFont: DS.Typography.body,
                tint: .primary,
                forceFullPrecision: true
            )

            Text(Self.dateFormatter.string(from: expense.date))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// Fill sólido: color de la categoría resuelta (bridge o nombre del creador), sino un
    /// fill neutro con el ícono del tipo de división.
    private var heroBadge: some View {
        let resolved = resolvedIcon
        let fillColor = resolved.colorHex.map { Color(hex: $0) } ?? Color(.secondaryLabel)
        return ZStack {
            Circle()
                .fill(fillColor)
                .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)

            Image(systemName: resolved.iconName)
                .font(DS.Typography.label)
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Tu parte

    /// Lo que te toca en una frase. Sin identidad resuelta no se pinta: afirmar algo sin
    /// saber quién eres es el bug de device del 2026-08-28 (`PersonalShareStatus`).
    @ViewBuilder
    private var yourPartCard: some View {
        switch status {
        case .youOwe(let amount):
            yourPartContent(
                sentence: L10n.Groups.Card.youOwe(payerName),
                amount: amount,
                tint: Color.hotPink
            )
        case .youAreOwed(let amount):
            yourPartContent(
                sentence: owedToYouSentence,
                amount: amount,
                tint: DS.Semantic.successForeground
            )
        case .notIncluded:
            yourPartContent(sentence: L10n.Groups.Expense.notIncluded, amount: nil, tint: .primary)
        case .identityUnresolved:
            EmptyView()
        }
    }

    /// «Ana te debe» si solo hay una persona más en el reparto; «Te deben» si son varias.
    private var owedToYouSentence: String {
        let debtors = breakdownEntries.filter { $0.id != currentMemberID && $0.amount > 0.004 }
        if debtors.count == 1, let only = debtors.first {
            return L10n.Groups.Card.theyOweYou(only.name)
        }
        return L10n.Groups.Summary.owedToMe
    }

    private func yourPartContent(sentence: String, amount: Double?, tint: Color) -> some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Split.yourPortion)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                Text(sentence)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DS.Spacing.sm)
            if let amount {
                AmountText(
                    value: amount,
                    currencyCode: expense.currencyCode,
                    font: DS.Typography.title3,
                    secondaryFont: DS.Typography.caption,
                    tint: .color(tint),
                    forceFullPrecision: true
                )
            }
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(.thCard)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("group_expense_detail_your_part")
    }

    // MARK: - Reparto

    private var breakdownCard: some View {
        let entries = breakdownEntries
        let colors = memberColors
        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text(L10n.Groups.Expense.breakdownTitle)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
                Spacer()
                Text(splitTypeLabel)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            // La barra solo cuando el reparto no es igual: ahí la proporción informa. Con partes
            // iguales repetía la lista y era ruido a primera vista (feedback del 2026-10-04).
            if expense.splitType != SplitType.equal.rawValue {
                GroupSplitBar(
                    segments: entries.map {
                        GroupSplitBarSegment(id: $0.id, amount: $0.amount, color: colors[$0.id] ?? .secondary)
                    },
                    currencyCode: expense.currencyCode
                )
            }

            VStack(spacing: DS.Spacing.sm) {
                ForEach(entries) { entry in
                    breakdownRow(entry, color: colors[entry.id] ?? .secondary)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(.thCard)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("group_expense_detail_breakdown")
    }

    private func breakdownRow(_ entry: BreakdownEntry, color: Color) -> some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: avatarSize, height: avatarSize)
                Text(String(entry.name.prefix(1)).uppercased())
                    .font(DS.Typography.label)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(entry.name)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if entry.isPayer {
                    Text(payerCaption)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: DS.Spacing.sm)

            AmountText(
                value: entry.amount,
                currencyCode: expense.currencyCode,
                font: DS.Typography.label,
                secondaryFont: DS.Typography.caption,
                tint: .primary,
                forceFullPrecision: true
            )
        }
        .accessibilityElement(children: .combine)
    }

    /// «Pagaste S/ 120.00» si fuiste tú; «Pagó S/ 120.00» bajo el nombre de otra persona.
    private var payerCaption: String {
        let total = appPreferences.currency(expense.amount, currencyCode: expense.currencyCode)
        return isPayer ? L10n.Groups.Expense.youPaid(total) : L10n.Groups.Expense.paidAmount(total)
    }

    // MARK: - Detalles

    /// Cuenta del movimiento personal enlazado, si existe y es una cuenta real.
    private var bridgeAccount: Account? {
        guard let account = bridgeTransaction?.account, !account.isSystemAccount else { return nil }
        return account
    }

    private var trimmedNote: String? {
        guard let note = expense.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else {
            return nil
        }
        return note
    }

    @ViewBuilder
    private var detailsCard: some View {
        let showsCategory = !resolvedIcon.isGeneric
        if showsCategory || trimmedNote != nil || bridgeAccount != nil {
            VStack(spacing: DS.Spacing.none) {
                // Categoría: bridge (nombre + categoría padre) o, sin bridge, el nombre del creador
                // (una línea — no tenemos la categoría padre sin el bridge). Genérico → sin fila.
                if showsCategory {
                    categoryRow(name: categoryDisplayName, parentName: bridgeSubcategory?.safeCategory.name)
                }

                if let note = trimmedNote {
                    detailRow(icon: "note.text", label: L10n.Groups.Expense.noteLabel, value: note)
                }

                if let account = bridgeAccount, let tx = bridgeTransaction {
                    financesRow(account: account, transaction: tx)
                }
            }
            .padding(.vertical, DS.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(.thCard)
            )
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

    /// Dónde quedó el gasto en tu registro personal: la cuenta y el monto que se apuntó.
    private func financesRow(account: Account, transaction: TransactionItem) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "creditcard")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: Self.rowIconWidth)
                .accessibilityHidden(true)

            Text(L10n.Groups.Expense.inYourFinances)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                AmountText(
                    value: abs(transaction.amount),
                    currencyCode: transaction.currencyCode,
                    font: DS.Typography.label,
                    secondaryFont: DS.Typography.caption,
                    tint: .primary,
                    forceFullPrecision: true
                )
                Text(account.name)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("group_expense_detail_finances")
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
