//
//  AccountDetailSheet.swift
//  Yala
//
//  La vista de una cuenta: la hoja que abre el toque en su tarjeta del Panel (2026-10-03, `panel-accounts-redesign`,
//  diseño aprobado por Jürgen en el lienzo «Cuentas del Panel — propuestas»). A media altura enseña lo importante
//  —saldo, qué entró y qué salió en el período del Panel y la curva del saldo—; al subirla aparecen en qué se fue el
//  gasto, los últimos movimientos y filtrar el Panel por esta cuenta. «Editar» va en la barra y abre el formulario
//  de cuenta encima de esta hoja.
//
//  UX 2.2 · L3-11 (opción B): la hoja se titula con el nombre de la cuenta, enseña la cuenta de su saldo en el período
//  («saldo al empezar + entró − salió = saldo») en vez de dos cifras sueltas junto a un saldo de siempre, pone los
//  valores de inicio y fin sobre la curva y sube «Filtrar por esta cuenta» bajo esa cuenta.
//
//  No asume ser hoja de pantalla completa: el contenido va a ancho legible, por si algún día vive en la columna de
//  detalle de una lista en iPad. El tamaño lo decide la ventana (`yalaSheetDetents`).
//

import Charts
import SwiftData
import SwiftUI

struct AccountDetailSheet: View {
    let account: Account
    let viewModel: PanelViewModel
    let isExpensesOnlyMode: Bool
    /// Tras cerrar el formulario: el Panel recarga (la cuenta pudo cambiar de nombre, moneda o saldo).
    let onAccountChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(SessionState.self) private var sessionState
    @Environment(\.usesLargeSheets) private var usesLargeSheets

    @State private var isEditing = false
    @State private var selectedDetent: PresentationDetent = .medium
    @State private var summary: AccountDetailCalculator.Summary?
    @State private var reconciliation: AccountDetailCalculator.Reconciliation?
    @Environment(CurrencyConverter.self) private var currencyConverter
    /// Tarjeta con varias divisas: la línea que enseñan la cuenta del período, la curva y los movimientos. `nil` = la
    /// principal. Cada línea es una cuenta de una divisa: sus cálculos no cambian de premisa.
    @State private var selectedLineID: PersistentIdentifier?

    /// Las cuentas de la tarjeta, la principal primero. Una sola = cuenta de una divisa.
    private var cardMembers: [Account] {
        guard !isStale else { return [account] }
        // Sin las borradas: esta hoja sigue montada mientras el formulario elimina una línea, y leer un `@Model` borrado
        // tumba la app (`detailIsStale`).
        let live = viewModel.accounts.filter { !$0.isDeleted && $0.modelContext != nil }
        let cards = live.filter { !$0.isArchived }.accountCards(roles: live.lineRoles)
        return cards.first { $0.head.persistentModelID == account.persistentModelID }?.members ?? [account]
    }

    private var hasLines: Bool { cardMembers.count > 1 }

    /// La cuenta que se enseña abajo: la línea elegida si sigue en la tarjeta; si no, la principal.
    private var shown: Account {
        guard let selectedLineID else { return account }
        return cardMembers.first { $0.persistentModelID == selectedLineID } ?? account
    }

    private var isStale: Bool {
        PanelAccountCardLogic.detailIsStale(
            isDeleted: account.isDeleted,
            hasContext: account.modelContext != nil,
            isArchived: account.isArchived
        )
    }

    /// Con el formulario abierto encima, una cuenta ARCHIVADA no cierra esta hoja todavía: cerrarla se llevaría el
    /// formulario y el aviso que pueda estar enseñando. Se cierra al volver. Una cuenta BORRADA cierra siempre: leerla
    /// tumbaría la app.
    private var shouldClose: Bool {
        if account.isDeleted || account.modelContext == nil { return true }
        return isStale && !isEditing
    }

    var body: some View {
        Group {
            if shouldClose {
                Color.clear.onAppear { dismiss() }
            } else {
                content
            }
        }
        .yalaSheetDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }

    // MARK: - Contenido

    private var content: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    hero
                    linePicker
                    balanceEquation
                    filterButton
                    chart
                    if let summary {
                        detailSections(summary)
                    }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.xl)
                .frame(maxWidth: DS.Adaptive.readableWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                    .accessibilityIdentifier("account_detail_close")
                }
                ToolbarItem(placement: .principal) {
                    Text(account.name)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                }
                if PanelAccountCardLogic.canEdit(isSystemAccount: account.isSystemAccount) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(L10n.Action.edit) {
                            isEditing = true
                        }
                        .fontWeight(.semibold)
                        .accessibilityLabel(L10n.Accessibility.editAccount)
                        .accessibilityIdentifier("account_detail_edit")
                    }
                }
            }
            .yalaScreenBackground(selectedDetent == .large || usesLargeSheets ? .subtle : .transparent)
        }
        .accessibilityIdentifier("account_detail_sheet")
        .task(id: refreshKey) { recompute() }
        .sheet(isPresented: $isEditing, onDismiss: onAccountChanged) {
            AccountFormView(existingNames: otherAccountNames, accountToEdit: shown)
        }
    }

    // MARK: - Lo de arriba (media altura)

    private var accountColor: Color {
        account.isSystemAccount ? Color(.systemGray) : Color(hex: account.colorHex)
    }

    private var currencyCode: String { normalizeCurrencyCode(shown.currencyCode) }

    private var periodName: String { sessionState.selectedPeriod.displayName }

    private var cardValue: Double {
        isExpensesOnlyMode
            ? viewModel.accountPeriodExpenses[shown.persistentModelID] ?? 0
            : viewModel.accountBalances[shown.persistentModelID] ?? 0
    }

    private var amountKind: PanelAccountCardLogic.AmountKind {
        PanelAccountCardLogic.amountKind(
            isExpensesOnlyMode: isExpensesOnlyMode,
            isCreditCard: AccountType(rawValue: shown.type) == .creditCard,
            value: cardValue
        )
    }

    private var amountLabel: String {
        lineKindLabel(hasLines ? cardKind : amountKind)
    }

    private var subtitle: String {
        let typeName: String? = account.isSystemAccount
            ? L10n.Account.System.badge
            : AccountType(rawValue: account.type)?.localizedName
        if hasLines {
            return PanelAccountCardLogic.subtitle(
                typeName: typeName, currencyCodes: cardMembers.map { normalizeCurrencyCode($0.currencyCode) })
        }
        return PanelAccountCardLogic.subtitle(typeName: typeName, currencyCode: currencyCode)
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            Image(systemName: account.iconName)
                .font(DS.Typography.title3)
                .foregroundStyle(Color.contrastingText(for: accountColor))
                .frame(width: DS.Icon.badgeLarge + DS.Spacing.xs, height: DS.Icon.badgeLarge + DS.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(accountColor)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(verbatim: subtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(2)
                Text(verbatim: amountLabel)
                    .font(DS.Typography.caption)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(2)
                if hasLines {
                    cardLinesSummary
                } else {
                    AmountText(
                        value: PanelAccountCardLogic.displayedValue(cardValue, kind: amountKind),
                        currencyCode: currencyCode,
                        font: DS.Typography.largeTitle.bold(),
                        secondaryFont: DS.Typography.title3,
                        tint: .color(theme.primaryText)
                    )
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Tarjeta con varias divisas

    private func memberValue(_ member: Account) -> Double {
        isExpensesOnlyMode
            ? viewModel.accountPeriodExpenses[member.persistentModelID] ?? 0
            : viewModel.accountBalances[member.persistentModelID] ?? 0
    }

    /// El rótulo de cada línea; «tarjeta de crédito» lo decide la principal, como en la tarjeta del Panel.
    private func memberKind(_ member: Account) -> PanelAccountCardLogic.AmountKind? {
        PanelAccountCardLogic.lineKind(
            isExpensesOnlyMode: isExpensesOnlyMode,
            isCreditCard: AccountType(rawValue: account.type) == .creditCard,
            value: memberValue(member))
    }

    /// El rótulo de la cabecera de una tarjeta con líneas: el de todas si coinciden (`cardAmountKind`).
    private var cardKind: PanelAccountCardLogic.AmountKind {
        PanelAccountCardLogic.cardAmountKind(lineKinds: cardMembers.map(memberKind))
    }

    /// Una línea por divisa y el total en la preferida, como la tarjeta del Panel.
    private var cardLinesSummary: some View {
        let card = cardKind
        let target = appPreferences.defaultCurrencyCode.rawValue
        let amounts = cardMembers.map {
            AccountCardLogic.LineAmount(value: memberValue($0), currencyCode: normalizeCurrencyCode($0.currencyCode))
        }
        let total = AccountCardLogic.total(amounts, in: target) { value, code in
            let outcome = currencyConverter.convertCheckedWithLatestRate(Decimal(value), from: code, to: target)
            return (outcome.amount as NSDecimalNumber).doubleValue
        }
        return VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            ForEach(cardMembers, id: \.persistentModelID) { member in
                let kind = memberKind(member)
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                    AmountText(
                        value: PanelAccountCardLogic.displayedValue(memberValue(member), kind: kind ?? card),
                        currencyCode: normalizeCurrencyCode(member.currencyCode),
                        font: DS.Typography.title2.bold(),
                        secondaryFont: DS.Typography.subheadline,
                        tint: .color(theme.primaryText)
                    )
                    if let kind, PanelAccountCardLogic.showsLineLabel(lineKind: kind, cardKind: card) {
                        Text(lineKindLabel(kind))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text(L10n.PanelAccountCard.total)
                    .font(DS.Typography.caption)
                    .foregroundStyle(theme.secondaryText)
                AmountText(
                    value: PanelAccountCardLogic.displayedValue(total.value, kind: card),
                    currencyCode: target,
                    font: DS.Typography.subheadlineEmphasized,
                    secondaryFont: DS.Typography.caption,
                    tint: .color(theme.secondaryText),
                    isEstimate: total.isConverted
                )
            }
        }
    }

    private func lineKindLabel(_ kind: PanelAccountCardLogic.AmountKind) -> String {
        switch kind {
        case .balance: return L10n.PanelAccountCard.balance
        case .toPay: return L10n.PanelAccountCard.toPay
        case .spent: return L10n.PanelAccountCard.spentInPeriod(periodName)
        }
    }

    /// Qué línea enseña lo de abajo: la cuenta del período, la curva y los movimientos son de una sola divisa.
    @ViewBuilder
    private var linePicker: some View {
        if hasLines {
            // `nil` es la principal: así una línea que deja la tarjeta devuelve la selección a ella sola.
            Picker(L10n.AccountDetail.linePicker, selection: $selectedLineID) {
                ForEach(cardMembers, id: \.persistentModelID) { member in
                    let tag: PersistentIdentifier? = member.persistentModelID == account.persistentModelID
                        ? nil : member.persistentModelID
                    Text(verbatim: normalizeCurrencyCode(member.currencyCode)).tag(tag)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("account_detail_line_picker")
        }
    }

    /// La cuenta del saldo en el período (UX 2.2 · L3-11). En modo «solo gastos» no va: la cabecera ya dice lo gastado,
    /// y «Salió» cuenta además transferencias y ajustes, así que al lado de «Gastado» se leía como otro número para lo
    /// mismo.
    @ViewBuilder
    private var balanceEquation: some View {
        if let reconciliation, !isExpensesOnlyMode {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(L10n.AccountDetail.equationTitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(theme.secondaryText)
                equationRow(sign: nil, title: L10n.AccountDetail.balanceOn(dayLabel(openingDay)), value: reconciliation.opening, tint: .color(theme.primaryText))
                equationRow(sign: "+", title: L10n.AccountDetail.moneyIn, value: reconciliation.moneyIn, tint: .color(Color.incomeAmount))
                equationRow(sign: "−", title: L10n.AccountDetail.moneyOut, value: reconciliation.moneyOut, tint: .color(theme.primaryText))
                Divider()
                equationRow(sign: "=", title: closingLabel, value: reconciliation.closing, tint: .color(theme.primaryText), isTotal: true)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.card, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("account_detail_equation")
        }
    }

    private func equationRow(sign: String?, title: String, value: Double, tint: AmountText.Tint, isTotal: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            Text(verbatim: sign ?? " ")
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(theme.secondaryText)
                .frame(width: DS.Spacing.md, alignment: .center)
                .accessibilityHidden(sign == nil)
            Text(title)
                .font(isTotal ? DS.Typography.subheadlineEmphasized : DS.Typography.subheadline)
                .foregroundStyle(theme.primaryText)
                .lineLimit(2)
            Spacer(minLength: DS.Spacing.sm)
            AmountText(
                value: value,
                currencyCode: currencyCode,
                font: isTotal ? DS.Typography.headline : DS.Typography.subheadlineEmphasized,
                secondaryFont: DS.Typography.caption,
                tint: tint
            )
        }
    }

    /// El día en que empieza la cuenta: el primero del período, o el del primer movimiento si la cuenta es posterior
    /// (como la curva).
    private var openingDay: Date {
        summary?.series.first?.day ?? viewModel.panelDateInterval.start
    }

    /// «Saldo hoy» si el período llega a hoy; si ya terminó, «Saldo al 30 sep».
    private var closingLabel: String {
        let interval = viewModel.panelDateInterval
        return interval.end >= Date.now ? L10n.AccountDetail.balanceToday : L10n.AccountDetail.balanceOn(dayLabel(interval.end))
    }

    private func dayLabel(_ date: Date) -> String {
        Self.rowDateFormatter.string(from: date)
    }

    @ViewBuilder
    private var filterButton: some View {
        if PanelAccountCardLogic.showsFilterAction(
            // Filtrar desde la ficha filtra la tarjeta (su principal), elija la línea que elija: la misma regla que el
            // carrusel. Que el filtro incluya las líneas es la entrega 3.
            isSelected: viewModel.selectedAccountIDs.contains(account.persistentModelID),
            isExcludeMode: viewModel.isExcludeMode
        ) {
            YalaSecondaryButton(L10n.Keyboard.filterByAccount, icon: "line.3.horizontal.decrease.circle") {
                viewModel.selectedAccountID = account.persistentModelID
                dismiss()
            }
            .accessibilityIdentifier("account_detail_filter")
        }
    }

    @ViewBuilder
    private var chart: some View {
        if let summary, summary.series.count > 1 {
            Chart(summary.series, id: \.day) { point in
                AreaMark(x: .value("Día", point.day), y: .value("Saldo", point.balance))
                    .foregroundStyle(accountColor.opacity(0.14))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Día", point.day), y: .value("Saldo", point.balance))
                    .foregroundStyle(accountColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                // Valor de inicio y fin sobre la curva (UX 2.2 · L3-11): sin escala era una línea sin cifras. Texto ya
                // resuelto: dentro de una anotación no llega el entorno (`AmountText` tumbaría la app).
                if point.day == summary.series.first?.day || point.day == summary.series.last?.day {
                    PointMark(x: .value("Día", point.day), y: .value("Saldo", point.balance))
                        .foregroundStyle(accountColor)
                        .symbolSize(36)
                        .annotation(
                            position: .top,
                            alignment: point.day == summary.series.first?.day ? .leading : .trailing,
                            spacing: DS.Spacing.xxs
                        ) {
                            Text(appPreferences.currency(point.balance, currencyCode: currencyCode))
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(theme.secondaryText)
                                .lineLimit(1)
                                .fixedSize()
                        }
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartPlotStyle { plot in plot.padding(.top, DS.Spacing.lg) }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    // Con más de medio año en pantalla el día no ubica nada y dos «1 ene.» no se distinguen: mes y año.
                    if spansMoreThanHalfAYear(summary.series) {
                        AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                    } else {
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 120)
            .accessibilityElement()
            .accessibilityLabel(L10n.AccountDetail.chartLabel(account: shown.name, period: periodName))
        }
    }

    private func spansMoreThanHalfAYear(_ series: [AccountDetailCalculator.DayBalance]) -> Bool {
        guard let first = series.first?.day, let last = series.last?.day else { return false }
        return last.timeIntervalSince(first) > 183 * 24 * 3600
    }

    // MARK: - Lo de abajo (al subir la hoja)

    @ViewBuilder
    private func detailSections(_ summary: AccountDetailCalculator.Summary) -> some View {
        Divider()

        if !summary.topCategories.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(L10n.AccountDetail.topCategories)
                    .font(DS.Typography.headline)
                    .foregroundStyle(theme.primaryText)
                let top = summary.topCategories.first?.amount ?? 1
                ForEach(summary.topCategories, id: \.key) { item in
                    categoryRow(item, fraction: top > 0 ? item.amount / top : 0)
                }
            }
        }

        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.AccountDetail.latest)
                .font(DS.Typography.headline)
                .foregroundStyle(theme.primaryText)
            if summary.latest.isEmpty {
                Text(L10n.AccountDetail.empty)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(theme.secondaryText)
                    .padding(.vertical, DS.Spacing.sm)
            } else {
                ForEach(summary.latest, id: \.id) { entry in
                    latestRow(entry)
                }
            }
        }
    }

    private func categoryRow(_ item: AccountDetailCalculator.CategoryTotal, fraction: Double) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Text(item.name)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                Spacer(minLength: DS.Spacing.sm)
                AmountText(
                    value: item.amount,
                    currencyCode: currencyCode,
                    font: DS.Typography.subheadlineEmphasized,
                    secondaryFont: DS.Typography.caption,
                    tint: .color(theme.primaryText)
                )
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(theme.card)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color(hex: item.colorHex ?? AppConstants.defaultColorHex))
                            .frame(width: max(DS.Spacing.sm, proxy.size.width * fraction))
                    }
            }
            .frame(height: DS.Spacing.sm)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private func latestRow(_ entry: AccountDetailCalculator.Entry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(entry.title)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                Text(entryCaption(entry))
                    .font(DS.Typography.caption)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: DS.Spacing.sm)
            AmountText(
                value: entry.amount,
                currencyCode: currencyCode,
                font: DS.Typography.subheadlineEmphasized,
                secondaryFont: DS.Typography.caption,
                tint: .color(entry.amount > 0 ? Color.incomeAmount : theme.primaryText)
            )
        }
        .padding(.vertical, DS.Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    private static let rowDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.setLocalizedDateFormatFromTemplate("dMMM")
        return f
    }()

    private func entryCaption(_ entry: AccountDetailCalculator.Entry) -> String {
        let date = Self.rowDateFormatter.string(from: entry.date)
        guard let category = entry.categoryName, !category.isEmpty else { return date }
        return "\(date) · \(category)"
    }

    // MARK: - Datos

    /// Lo que obliga a recalcular: los datos (`dataVersion`), el período y el saldo de la propia cuenta, que cambia
    /// al guardar el formulario aunque el período no. El período va como elección y no como intervalo: «Todo el
    /// tiempo» se calcula desde `now` y su intervalo cambia en cada lectura, así que con él la tarea recalculaba en
    /// cada repintado.
    private struct RefreshKey: Equatable {
        let dataVersion: Int
        let period: DetailPeriod
        let customRange: DateInterval?
        let balance: Double
        let lineID: PersistentIdentifier?
    }

    private var refreshKey: RefreshKey {
        RefreshKey(
            dataVersion: sessionState.dataVersion,
            period: sessionState.selectedPeriod,
            customRange: sessionState.customDateRange,
            balance: viewModel.accountBalances[shown.persistentModelID] ?? 0,
            lineID: selectedLineID
        )
    }

    private var otherAccountNames: [String] {
        viewModel.accounts
            .filter { $0.persistentModelID != shown.persistentModelID }
            .map(\.name)
    }

    private func recompute() {
        guard !isStale else { return }
        let entries = (shown.transactions ?? []).map { tx in
            AccountDetailCalculator.Entry(
                id: String(describing: tx.persistentModelID),
                date: tx.date,
                amount: tx.amount,
                adjustmentType: tx.balanceAdjustmentType,
                categoryKey: tx.category.map { String(describing: $0.persistentModelID) },
                categoryName: tx.category?.name,
                categoryColorHex: tx.category?.colorHex,
                categoryIsIncome: tx.category?.isIncome,
                title: Self.title(for: tx)
            )
        }
        let interval = viewModel.panelDateInterval
        let calendar = Calendar.current
        let now = Date.now
        var result = AccountDetailCalculator.summary(entries: entries, interval: interval, now: now, calendar: calendar)
        if isExpensesOnlyMode {
            result = AccountDetailCalculator.Summary(
                moneyIn: result.moneyIn,
                moneyOut: result.moneyOut,
                series: AccountDetailCalculator.dailySpending(
                    entries: entries, interval: interval, now: now, calendar: calendar
                ),
                topCategories: result.topCategories,
                latest: result.latest
            )
        }
        summary = result
        reconciliation = AccountDetailCalculator.reconciliation(entries: entries, interval: interval, calendar: calendar)
    }

    private static func title(for tx: TransactionItem) -> String {
        if let note = tx.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty { return note }
        if let sub = tx.subcategory?.name, !sub.isEmpty { return sub }
        return tx.category?.name ?? ""
    }
}
