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
//  Rediseño del 2026-11-16 (ticket `analisis-por-cuenta`): bajo «Filtrar por esta cuenta», las gráficas de los widgets
//  del Panel con los datos de esta cuenta (`AccountAnalysisCharts`: la curva de Tendencias, el flujo de caja y la
//  distribución por categoría, con la comparación contra el período anterior), y abajo los gastos más grandes y los
//  últimos registros. Se fue la curva propia y la lista de barras de «En qué se fue»: no seguían el design system.
//
//  Rediseño del 2026-11-17 (pedido de Jürgen, variante A «Wallet»): arriba la tarjeta tal como la personalizó la persona,
//  grande y con entrada animada; debajo el monto grande con su rótulo y, en tarjetas de crédito, lo que debes repartido
//  con la fecha de pago y el próximo corte (`HojaCuentaTarjeta/`). Lo demás sigue igual, en el mismo orden.
//

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
    /// Lo que pintan las gráficas de los widgets con los datos de esta cuenta (rediseño del 2026-11-16).
    @State private var analysis: AccountAnalysis?
    /// El estado de cuenta de la tarjeta (card nmtk). `nil` = no es una tarjeta con día de corte.
    @State private var statement: CreditCardStatementSummary.Card?
    /// Los registros de «Tus gastos más grandes» y «Últimos registros», en el orden del cálculo: van en la tarjeta de
    /// «Últimos registros» del Panel (`RecentRecordsWidget`, decisión de Jürgen del 2026-11-16), que pinta registros.
    @State private var largestRecords: [TransactionItem] = []
    @State private var latestRecords: [TransactionItem] = []
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
                    statementBlock
                    linePicker
                    balanceEquation
                    filterButton
                    if let analysis {
                        AccountAnalysisCharts(
                            analysis: analysis,
                            currencyCode: currencyCode,
                            period: sessionState.selectedPeriod,
                            customRange: sessionState.customDateRange,
                            interval: viewModel.panelDateInterval,
                            isExpensesOnlyMode: isExpensesOnlyMode
                        )
                    }
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

    /// Arriba, la tarjeta tal como la personalizó la persona, grande; debajo, qué es el número y el número (pedido de
    /// Jürgen del 17-nov-2026, variante A «Wallet», `HojaCuentaTarjeta/`).
    private var hero: some View {
        VStack(spacing: DS.Spacing.lg) {
            HojaCuentaTarjetaCara(account: account, subtitulo: subtitle)
                .frame(maxWidth: .infinity)
                .padding(.top, DS.Spacing.sm)

            VStack(spacing: DS.Spacing.xxs) {
                Text(verbatim: amountLabel)
                    .font(DS.Typography.subheadlineEmphasized)
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
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("hoja_cuenta_monto")
        }
    }

    // MARK: - Estado de cuenta (card nmtk, D2-A)

    /// Bajo el monto: lo que debes repartido entre facturado y por facturar, la fecha de pago y el próximo corte, de
    /// todas las divisas de la tarjeta (`HojaCuentaTarjetaEstado`). Sin fechas, las pide. En «solo gastos» no va, como
    /// la cuenta del saldo: ese modo no lleva saldos.
    @ViewBuilder
    private var statementBlock: some View {
        switch HojaCuentaTarjetaLogica.bloque(
            esTarjetaDeCredito: AccountType(rawValue: account.type) == .creditCard,
            tieneEstadoDeCuenta: statement != nil,
            esCuentaDeSistema: account.isSystemAccount,
            soloGastos: isExpensesOnlyMode,
            puedeEditar: PanelAccountCardLogic.canEdit(isSystemAccount: account.isSystemAccount)
        ) {
        case .estadoDeCuenta:
            if let statement { HojaCuentaTarjetaEstado(card: statement) }
        case .pedirFechas:
            // Los días de corte y de pago son de la principal: el formulario se abre sobre ella.
            HojaCuentaTarjetaSinFechas {
                selectedLineID = nil
                isEditing = true
            }
        case .ninguno:
            EmptyView()
        }
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
        return VStack(alignment: .center, spacing: DS.Spacing.xxs) {
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
        // Llega a hoy si acaba hoy o después (los períodos en curso cierran a las 23:59:59).
        return interval.end >= Calendar.current.startOfDay(for: .now) ? L10n.AccountDetail.balanceToday : L10n.AccountDetail.balanceOn(dayLabel(interval.end))
    }

    private func dayLabel(_ date: Date) -> String {
        Self.rowDateFormatter.string(from: date)
    }

    @ViewBuilder
    private var filterButton: some View {
        if PanelAccountCardLogic.showsFilterAction(
            // Filtrar desde la ficha filtra la tarjeta (su principal), elija la línea que elija: la misma regla que el
            // carrusel. El filtro de sesión le añade sus líneas (entrega 3).
            membership: viewModel.accountMembership(account.persistentModelID)
        ) {
            YalaSecondaryButton(L10n.Keyboard.filterByAccount, icon: "line.3.horizontal.decrease.circle") {
                viewModel.selectedAccountID = account.persistentModelID
                dismiss()
            }
            .accessibilityIdentifier("account_detail_filter")
        }
    }

    // MARK: - Lo de abajo (al subir la hoja)

    /// «Tus gastos más grandes» y «Últimos registros» en la tarjeta de «Últimos registros» del Panel (Jürgen, 16-nov):
    /// el título de la sección fuera, como en el Panel, y dentro sus filas con el ícono de la subcategoría, la fecha y la
    /// necesidad. Las filas no se tocan, como antes.
    @ViewBuilder
    private func detailSections(_ summary: AccountDetailCalculator.Summary) -> some View {
        let largest = Self.readable(largestRecords)
        if !largest.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(L10n.AnalisisCuenta.largestTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(theme.primaryText)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("account_analysis_largest_title")
                RecentRecordsWidget(records: largest, currencyCode: currencyCode, showsTitle: false)
                    .accessibilityIdentifier("account_analysis_largest_card")
            }
        }

        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.AccountDetail.latest)
                .font(DS.Typography.headline)
                .foregroundStyle(theme.primaryText)
                .accessibilityAddTraits(.isHeader)
            // Vacío, el mismo estado de la tarjeta del Panel; antes, una línea suelta.
            RecentRecordsWidget(records: Self.readable(latestRecords), currencyCode: currencyCode, showsTitle: false)
                .accessibilityIdentifier("account_detail_latest_card")
        }
    }

    /// Lo que ya se borró no se lee (`swiftui-ds.md`: una fila con su modelo borrado aborta en el iPhone).
    private static func readable(_ records: [TransactionItem]) -> [TransactionItem] {
        records.filter { !$0.isDeleted && $0.modelContext != nil }
    }

    /// Los registros de unas entradas del cálculo, en su orden. La identidad es la misma con la que `recompute` las crea.
    private static func records(
        for entries: [AccountDetailCalculator.Entry], in byID: [String: TransactionItem]
    ) -> [TransactionItem] {
        entries.compactMap { byID[$0.id] }
    }

    private static let rowDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.setLocalizedDateFormatFromTemplate("dMMM")
        return f
    }()

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
        // Lo que espera su borrado con «Deshacer» no cuenta en la ficha (`RecordPendingDeletion`).
        let transactions = RecordPendingDeletion.shared.visible(shown.transactions ?? [])
        let entries = transactions.map { tx in
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
        analysis = AccountAnalysisBuilder.build(
            transactions: transactions,
            entries: entries,
            series: result.series,
            period: sessionState.selectedPeriod,
            customRange: sessionState.customDateRange,
            interval: interval,
            currencyCode: currencyCode,
            isExpensesOnlyMode: isExpensesOnlyMode,
            now: now,
            calendar: calendar,
            converter: currencyConverter
        )
        reconciliation = AccountDetailCalculator.reconciliation(entries: entries, interval: interval, calendar: calendar)
        statement = CreditCardStatementSummary.card(head: account, members: cardMembers, now: now, calendar: calendar)
        let byID = Dictionary(
            transactions.map { (String(describing: $0.persistentModelID), $0) }, uniquingKeysWith: { first, _ in first }
        )
        largestRecords = Self.records(for: analysis?.largestExpenses ?? [], in: byID)
        latestRecords = Self.records(for: result.latest, in: byID)
    }

    private static func title(for tx: TransactionItem) -> String {
        if let note = tx.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty { return note }
        if let sub = tx.subcategory?.name, !sub.isEmpty { return sub }
        return tx.category?.name ?? ""
    }
}
