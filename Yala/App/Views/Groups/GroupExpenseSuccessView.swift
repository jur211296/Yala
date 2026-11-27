//
//  GroupExpenseSuccessView.swift
//  Yala
//
//  Pantalla de éxito tras crear/editar un gasto de grupo, con el diseño minimalista del registro personal (encargo del
//  2026-11-24; el de `TransactionSuccessView`, elegido por Jürgen el 2026-11-20): «Editar» arriba, un check pequeño junto
//  al título, la descripción sobre el monto grande, debajo lo que te toca («Debes S/ 40.00 · Se lo debes a Ana») y una
//  tarjeta sin rótulos con grupo, quién pagó, fecha, categoría, cuenta y el reparto con cada participante. Debajo, qué
//  apuntó Yala en tus finanzas (solo si el puente lo escribió de verdad, card dx3m) con «Partir tu parte»; al pie,
//  «Agregar otro gasto» y «Aceptar» lado a lado. Sin confeti ni círculo grande.
//

import SwiftUI

// MARK: - Group Expense Success Data

/// Datos del gasto de grupo recién guardado para mostrar en la pantalla de éxito.
struct GroupExpenseSuccessData {
    let groupName: String
    let groupColorHex: String
    let date: Date
    let description: String
    let totalAmount: Double
    let currencyCode: String
    let paidByName: String
    let paidByIsMe: Bool
    let subcategoryName: String?
    let accountName: String?      // Caso A: cuenta personal real
    let accountColorHex: String?
    let splitType: SplitType
    let participants: [Participant]
    let debt: GroupExpenseDebt
    let isEditMode: Bool
    /// Auditoría UX 2.2 · L13-3: quién eres (para decir quién te debe sin contarte) y qué apuntó Yala en tus finanzas.
    var currentUserMemberID: String? = nil
    var personalOutcome: GroupExpensePersonalOutcome = .none
    /// Grupos B (card 6): el gasto guardado, y si se ofrece «Partir tu parte» en el bloque de qué apuntó Yala
    /// (`GroupSplitLinesEntryLogic.offersSplit`: puente activo, fuera de la sesión solo-grupos y con parte propia).
    var splitExpenseID: String? = nil
    var offersSplitLines: Bool = false
    /// Grupos B · card 00xj: pagaste tú con una categoría de ingreso (`GroupExpenseViewModel.isSale`). El título dice
    /// «Venta agregada» en vez de «Gasto agregado».
    var isSale: Bool = false

    /// Participante con su parte del gasto. `id` estable = memberID (los nombres pueden repetirse).
    struct Participant: Identifiable {
        let id: String
        let name: String
        let amount: Double
    }
}

// MARK: - Group Expense Success View

struct GroupExpenseSuccessView: View {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.setLocalizedDateFormatFromTemplate("dMMMy")
        return f
    }()

    let data: GroupExpenseSuccessData
    let onAccept: () -> Void
    let onCreateAnother: () -> Void
    let onEdit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppPreferences.self) private var appPreferences

    @State private var showHero = false
    @State private var showDetails = false
    @State private var showActions = false
    @State private var showsSplitLines = false

    private var tint: Color {
        switch GroupExpenseSuccessLogic.tint(isSale: data.isSale) {
        case .expense: TransactionType.expense.color
        case .income: TransactionType.income.color
        }
    }

    var body: some View {
        MinimalSuccessLayout(
            onEdit: onEdit,
            editIdentifier: "group_expense_success_edit",
            footerVisible: showActions
        ) {
            VStack(spacing: DS.Spacing.none) {
                hero
                    .padding(.bottom, DS.Spacing.xl)
                VStack(spacing: DS.Spacing.lg) {
                    detailsCard
                    moneyBlock
                }
                .padding(.horizontal, DS.Spacing.xl)
                .opacity(showDetails ? 1.0 : 0.0)
                .offset(y: showDetails ? 0 : 15)
            }
        } footer: {
            MinimalSuccessFooter(
                secondary: .init(title: L10n.Groups.Expense.Success.addAnother,
                                 identifier: "group_expense_success_add_another", action: onCreateAnother),
                primary: .init(title: L10n.Common.accept, identifier: "group_expense_success_accept", action: onAccept)
            )
        }
        // Sin identifier en el contenedor: en un container SwiftUI, .accessibilityIdentifier se
        // propaga a TODOS los elementos hijos y PISA sus identifiers propios.
        .onAppear(perform: runEntranceAnimation)
        .sheet(isPresented: $showsSplitLines) {
            if let splitExpenseID = data.splitExpenseID {
                GroupSplitLinesSheet(splitExpenseID: splitExpenseID)
            }
        }
    }

    // MARK: - Hero

    private var heroTitle: String {
        switch GroupExpenseSuccessLogic.title(isSale: data.isSale, isEditMode: data.isEditMode) {
        case .expenseCreated: ExitoGruposBandejaText.GroupTitle.expenseCreated
        case .expenseUpdated: ExitoGruposBandejaText.GroupTitle.expenseUpdated
        case .saleCreated: ExitoGruposBandejaText.GroupTitle.saleCreated
        case .saleUpdated: ExitoGruposBandejaText.GroupTitle.saleUpdated
        }
    }

    private var hero: some View {
        VStack(spacing: DS.Spacing.md) {
            MinimalSuccessTitle(title: heroTitle, tint: tint, bounces: reduceMotion ? false : showHero,
                                identifier: "group_expense_success_title")

            if !data.description.isEmpty {
                MinimalSuccessDescription(text: data.description, identifier: "group_expense_success_description")
            }

            AmountText(
                value: data.totalAmount,
                currencyCode: data.currencyCode,
                font: DS.Typography.heroAmount, secondaryFont: DS.Typography.heroAmountSecondary,
                tint: .color(tint),
                forceFullPrecision: true
            )
            .scaleEffect(showHero ? 1.0 : 0.9)
            .opacity(showHero ? 1.0 : 0.0)

            debtLine
                .opacity(showHero ? 1.0 : 0.0)
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    /// Tu parte, bajo el monto (L13-3): quién te debe, a quién debes o que no queda nada.
    private var debtLine: some View {
        let format = { (value: Double) in appPreferences.currency(value, currencyCode: data.currencyCode) }
        let title: String
        let detail: String?
        switch data.debt {
        case .theyOweMe(let amount):
            title = L10n.UXL13.successOwedTitle(format(amount))
            detail = debtorsDetail
        case .iOwe(let amount):
            title = L10n.UXL13.successIOweTitle(format(amount))
            detail = L10n.UXL13.successIOweTo(data.paidByName)
        case .settled:
            title = L10n.UXL13.successSettledTitle
            detail = nil
        }
        return VStack(spacing: DS.Spacing.xxs) {
            Text(title)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(debtColor)
            if let detail {
                Text(detail)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("group_expense_success_debt_line")
    }

    private var debtColor: Color {
        switch GroupExpenseSuccessLogic.debtTone(data.debt) {
        case .owedToMe: Color.groupOwedAmount
        case .iOwe: Color.groupOweAmount
        case .settled: Color(.secondaryLabel)
        }
    }

    /// «Ana y Beto, S/ 50.00 cada uno» si todos deben lo mismo; si no, cada uno con lo suyo.
    private var debtorsDetail: String? {
        let debtors = GroupExpenseSuccessLogic.debtors(
            participants: data.participants.map { (id: $0.id, name: $0.name, amount: $0.amount) },
            currentUserMemberID: data.currentUserMemberID
        )
        guard !debtors.isEmpty else { return nil }
        if debtors.count == 1 { return debtors[0].name }
        if GroupExpenseSuccessLogic.allEqual(debtors.map(\.amount)) {
            let formatter = ListFormatter()
            formatter.locale = AppLocale.current
            let names = formatter.string(from: debtors.map(\.name)) ?? debtors.map(\.name).joined(separator: ", ")
            return L10n.UXL13.successOwedEach(
                names: names,
                amount: appPreferences.currency(debtors[0].amount, currencyCode: data.currencyCode)
            )
        }
        return debtors
            .map { "\($0.name) \(appPreferences.currency($0.amount, currencyCode: data.currencyCode))" }
            .joined(separator: " · ")
    }

    // MARK: - Tarjeta

    private var fields: [GroupExpenseSuccessFieldOrder.Field] {
        GroupExpenseSuccessFieldOrder.fields(
            hasSubcategory: data.subcategoryName != nil,
            hasAccount: data.accountName != nil,
            outcome: data.personalOutcome
        )
    }

    private var detailsCard: some View {
        MinimalSuccessCard {
            ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                row(for: field)
            }
        }
    }

    @ViewBuilder
    private func row(for field: GroupExpenseSuccessFieldOrder.Field) -> some View {
        switch field {
        case .group:
            MinimalSuccessRow(icon: "person.3", label: L10n.Groups.Expense.Success.group, spoken: data.groupName,
                              identifier: "group_expense_success_group") {
                MinimalSuccessDotted(text: data.groupName, colorHex: data.groupColorHex)
            }
        case .paidBy:
            let paidBy = data.paidByIsMe ? ExitoGruposBandejaText.paidByMe : ExitoGruposBandejaText.paidBy(data.paidByName)
            MinimalSuccessRow(icon: "person.crop.circle", label: L10n.Groups.Expense.paidByTitle, spoken: paidBy,
                              identifier: "group_expense_success_paid_by") {
                Text(paidBy)
            }
        case .date:
            let date = Self.dateFormatter.string(from: data.date)
            MinimalSuccessRow(icon: "calendar", label: L10n.Transaction.date, spoken: date,
                              identifier: "group_expense_success_date") {
                Text(date)
            }
        case .subcategory:
            if let subcategory = data.subcategoryName {
                MinimalSuccessRow(icon: "tag", label: L10n.Transaction.category, spoken: subcategory,
                                  identifier: "group_expense_success_category") {
                    Text(subcategory)
                }
            }
        case .account:
            if let account = data.accountName {
                MinimalSuccessRow(icon: "creditcard", label: L10n.Transaction.account, spoken: account,
                                  identifier: "group_expense_success_account") {
                    MinimalSuccessDotted(text: account, colorHex: data.accountColorHex ?? AppConstants.defaultColorHex)
                }
            }
        case .split:
            // El reparto real («Todo de Pia»), no el tipo guardado: un «es todo de…» se guarda como `equal`.
            MinimalSuccessRow(icon: data.splitIconName, label: L10n.Groups.Expense.Success.splitLabel,
                              spoken: [data.splitLabel, participantsLine].joined(separator: ", "),
                              identifier: "group_expense_success_split_row") {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(data.splitLabel)
                    Text(participantsLine)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// «Jürgen S/ 40.00 · Ana S/ 40.00 · Luis S/ 40.00»: cómo se repartió, en una línea que parte si no cabe. El nombre
    /// propio va tal cual (como en la pantalla de antes): a veces ya es «Tú» y un sufijo lo repetiría.
    private var participantsLine: String {
        data.participants
            .map { "\($0.name) \(appPreferences.currency($0.amount, currencyCode: data.currencyCode))" }
            .joined(separator: " · ")
    }

    // MARK: - Qué apuntó Yala en tus finanzas

    @ViewBuilder
    private var moneyBlock: some View {
        let format = { (value: Double) in appPreferences.currency(value, currencyCode: data.currencyCode) }
        switch data.personalOutcome {
        case .chargedToAccount(let accountName):
            moneyRow(icon: "creditcard",
                     title: L10n.UXL13.successAccountTitle(amount: format(data.totalAmount), account: accountName),
                     detail: L10n.UXL13.successAccountDetail, offersSplit: data.offersSplitLines)
        case .waitingInInbox:
            moneyRow(icon: "tray.full", title: L10n.UXL13.successInboxTitle,
                     detail: L10n.UXL13.successInboxDetail(format(data.totalAmount)), offersSplit: false)
        case .shareAsGroupExpense(let amount):
            moneyRow(icon: "chart.pie", title: L10n.UXL13.successShareTitle(format(amount)),
                     detail: L10n.UXL13.successShareDetail, offersSplit: data.offersSplitLines)
        case .none:
            EmptyView()
        }
    }

    /// - Parameter offersSplit: Grupos B (card 6): «Partir tu parte» dentro del bloque, bajo el texto. Va fuera del
    ///   elemento combinado para que se pueda tocar por sí solo; el id del texto va en el texto por lo mismo.
    private func moneyRow(icon: String, title: String, detail: String, offersSplit: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(title)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("group_expense_success_money_line")

            if offersSplit {
                Button {
                    showsSplitLines = true
                } label: {
                    Label(L10n.Groups.SplitLines.splitYourShare, systemImage: "scissors")
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.thAccentText)
                        .padding(.leading, 20 + DS.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("group_expense_success_split")
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(.thCard)
        )
    }

    // MARK: - Entrada

    private func runEntranceAnimation() {
        if reduceMotion {
            showHero = true
            showDetails = true
            showActions = true
        } else {
            withAnimation(DS.Animation.appear) { showHero = true }
            withAnimation(DS.Animation.appear.delay(0.15)) { showDetails = true }
            withAnimation(DS.Animation.appear.delay(0.3)) { showActions = true }
        }
    }
}

#Preview {
    GroupExpenseSuccessView(
        data: GroupExpenseSuccessData(
            groupName: "Viaje a Cusco",
            groupColorHex: "#8B5CF6",
            date: .now,
            description: "Cena en el centro",
            totalAmount: 120,
            currencyCode: "PEN",
            paidByName: "Tú",
            paidByIsMe: true,
            subcategoryName: "Restaurantes",
            accountName: "Soles",
            accountColorHex: "FF6B6B",
            splitType: .equal,
            participants: [
                .init(id: "1", name: "Jürgen", amount: 40),
                .init(id: "2", name: "Ana", amount: 40),
                .init(id: "3", name: "Luis", amount: 40),
            ],
            debt: .theyOweMe(80),
            isEditMode: false,
            currentUserMemberID: "1"
        ),
        onAccept: {},
        onCreateAnother: {},
        onEdit: {}
    )
}
