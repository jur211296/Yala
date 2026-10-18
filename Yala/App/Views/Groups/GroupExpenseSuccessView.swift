//
//  GroupExpenseSuccessView.swift
//  Yala
//
//  Pantalla de éxito tras crear/editar un gasto de grupo. Espeja el patrón de
//  `TransactionSuccessView` (hero animado + checkmark + monto + resumen + acciones),
//  adaptada al split: grupo, quién pagó, división, participantes y la deuda que le queda
//  al usuario ("te deben" / "debes"). Con confetti de celebración (respeta reduceMotion).
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
        f.dateFormat = "d MMM yyyy"
        f.locale = AppLocale.current
        return f
    }()

    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 36 // A11Y-DT: @ScaledMetric
    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 32 // A11Y-DT: @ScaledMetric
    @ScaledMetric(relativeTo: .body) private var infoIconSize: CGFloat = 36 // A11Y-DT: @ScaledMetric

    let data: GroupExpenseSuccessData
    let onAccept: () -> Void
    let onCreateAnother: () -> Void
    let onEdit: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    @State private var showConfetti = false
    @State private var showHero = false
    @State private var showCheckmark = false
    @State private var showAmount = false
    @State private var showDetails = false
    @State private var showActions = false

    private var heroColor: Color { DS.Semantic.successForeground }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
            }

            // Subtle background glow
            RadialGradient(
                colors: [heroColor.opacity(0.06), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 200
            )
            .frame(height: 300)
            .blur(radius: 40)
            .offset(y: -60)

            VStack(spacing: DS.Spacing.none) {
                // Edit button at top right — native iOS style
                HStack {
                    Spacer()
                    Button(L10n.Action.edit, action: onEdit)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("group_expense_success_edit")
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.lg)

                ScrollView {
                    VStack(spacing: DS.Spacing.xxxl) {
                        heroArea

                        VStack(spacing: DS.Spacing.lg) {
                            detailsSection
                            participantsSection
                        }
                        .opacity(showDetails ? 1.0 : 0.0)
                        .offset(y: showDetails ? 0 : 15)
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.top, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.xl)
                }
                .scrollIndicators(.hidden)

                // Action buttons — native iOS style
                VStack(spacing: DS.Spacing.md) {
                    YalaPrimaryButton(L10n.Common.accept, action: onAccept)
                        .accessibilityIdentifier("group_expense_success_accept")

                    Button(action: onCreateAnother) {
                        Text(L10n.Groups.Expense.Success.addAnother)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("group_expense_success_add_another")
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xxxl)
                .opacity(showActions ? 1.0 : 0.0)
                .offset(y: showActions ? 0 : 10)
            }
        }
        // Sin identifier en el contenedor: en un container SwiftUI, .accessibilityIdentifier se
        // propaga a TODOS los elementos hijos y PISA sus identifiers propios (los botones
        // group_expense_success_accept/_edit/_add_another reportaban este id → XCUI no los hallaba).
        .onAppear(perform: runEntranceAnimation)
    }

    // MARK: - Hero

    private var heroArea: some View {
        VStack(spacing: DS.Spacing.lg) {
            Text(data.isEditMode
                ? L10n.Groups.Expense.Success.titleUpdated
                : L10n.Groups.Expense.Success.titleCreated)
                .font(DS.Typography.headline)
                .foregroundStyle(.secondary)
                .opacity(showHero ? 1.0 : 0.0)

            heroCircle

            AmountText(
                value: data.totalAmount,
                currencyCode: data.currencyCode,
                font: DS.Typography.heroAmount, secondaryFont: DS.Typography.heroAmountSecondary,
                tint: .color(heroColor),
                forceFullPrecision: true
            )
            .scaleEffect(showAmount ? 1.0 : 0.8)
            .opacity(showAmount ? 1.0 : 0.0)

            // L13-3 (decisión de Jürgen del 15-oct, variante 1): dos líneas que dicen qué pasó con tu dinero — quién te
            // debe (o a quién debes) y qué apuntamos en tus finanzas, y de qué cuenta salió.
            VStack(spacing: DS.Spacing.md) {
                debtLine
                moneyLine
            }
            .opacity(showAmount ? 1.0 : 0.0)
        }
    }

    private var heroCircle: some View {
        ZStack {
            // Radiant glow
            RadialGradient(
                colors: [heroColor.opacity(0.25), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 90
            )
            .frame(width: 180, height: 180)
            .blur(radius: 12)
            .opacity(showHero ? 1.0 : 0.0)

            // Main gradient circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [heroColor, heroColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .shadow(color: heroColor.opacity(0.4), radius: 20, y: 8)
                .scaleEffect(showHero ? 1.0 : 0.3)
                .opacity(showHero ? 1.0 : 0.0)

            // Glass overlay
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 100, height: 100)
                .mask(
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .opacity(showHero ? 1.0 : 0.0)

            // White checkmark
            Image(systemName: "checkmark")
                .font(.system(size: heroIconSize, weight: .semibold))
                .foregroundStyle(.white)
                .scaleEffect(showCheckmark ? 1.0 : 0.0)
                .opacity(showCheckmark ? 1.0 : 0.0)
                .accessibilityHidden(true)
        }
    }

    private var debtLine: some View {
        let format = { (value: Double) in appPreferences.currency(value, currencyCode: data.currencyCode) }
        switch data.debt {
        case .theyOweMe(let amount):
            return infoRow(icon: "person.2.fill", color: DS.Semantic.successForeground,
                           title: L10n.UXL13.successOwedTitle(format(amount)), detail: debtorsDetail)
                .accessibilityIdentifier("group_expense_success_debt_line")
        case .iOwe(let amount):
            return infoRow(icon: "person.2.fill", color: .hotPink,
                           title: L10n.UXL13.successIOweTitle(format(amount)),
                           detail: L10n.UXL13.successIOweTo(data.paidByName))
                .accessibilityIdentifier("group_expense_success_debt_line")
        case .settled:
            return infoRow(icon: "checkmark", color: .secondary, title: L10n.UXL13.successSettledTitle, detail: nil)
                .accessibilityIdentifier("group_expense_success_debt_line")
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

    @ViewBuilder
    private var moneyLine: some View {
        let format = { (value: Double) in appPreferences.currency(value, currencyCode: data.currencyCode) }
        switch data.personalOutcome {
        case .chargedToAccount(let accountName):
            infoRow(icon: "creditcard.fill", color: .electricIndigo,
                    title: L10n.UXL13.successAccountTitle(amount: format(data.totalAmount), account: accountName),
                    detail: L10n.UXL13.successAccountDetail)
                .accessibilityIdentifier("group_expense_success_money_line")
        case .waitingInInbox:
            infoRow(icon: "tray.full.fill", color: .electricIndigo,
                    title: L10n.UXL13.successInboxTitle,
                    detail: L10n.UXL13.successInboxDetail(format(data.totalAmount)))
                .accessibilityIdentifier("group_expense_success_money_line")
        case .shareAsGroupExpense(let amount):
            infoRow(icon: "chart.pie.fill", color: .electricIndigo,
                    title: L10n.UXL13.successShareTitle(format(amount)),
                    detail: L10n.UXL13.successShareDetail)
                .accessibilityIdentifier("group_expense_success_money_line")
        case .none:
            EmptyView()
        }
    }

    private func infoRow(icon: String, color: Color, title: String, detail: String?) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.white)
                .frame(width: infoIconSize, height: infoIconSize)
                .background(color, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(spacing: DS.Spacing.none) {
            detailRow(icon: "person.3.fill", label: L10n.Groups.Expense.Success.group,
                      value: data.groupName, dotColorHex: data.groupColorHex)

            paidByRow

            detailRow(icon: "calendar", label: L10n.Transaction.date, value: formattedDate)

            if let subcategory = data.subcategoryName {
                detailRow(icon: "tag", label: L10n.Transaction.category, value: subcategory)
            }

            // Con la línea «−S/ 150 en Cuenta» arriba, la fila de la cuenta repetiría lo mismo.
            if let account = data.accountName, !isChargedToAccount {
                detailRow(icon: "creditcard", label: L10n.Transaction.account,
                          value: account, dotColorHex: data.accountColorHex)
            }

            detailRow(icon: data.splitType.iconName, label: L10n.Groups.Expense.Success.splitLabel,
                      value: data.splitType.displayName)
        }
        .padding(.vertical, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(.thCard)
        )
    }

    private func detailRow(icon: String, label: String, value: String, dotColorHex: String? = nil) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(label)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                if let dot = dotColorHex {
                    Circle()
                        .fill(Color(hex: dot))
                        .frame(width: 8, height: 8)
                }
                Text(value)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    private var paidByRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "creditcard.fill")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)

            Text(L10n.Groups.Expense.paidByTitle)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                Text(data.paidByName)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if data.paidByIsMe {
                    Text(L10n.Groups.Member.you)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    // MARK: - Participants

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Groups.Expense.Success.participants)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.none) {
                ForEach(data.participants) { participant in
                    participantRow(participant)

                    if participant.id != data.participants.last?.id {
                        Divider()
                            .padding(.leading, DS.Spacing.xxxl)
                    }
                }
            }
            .solidCard(radius: DS.Radius.xl)
        }
    }

    private func participantRow(_ participant: GroupExpenseSuccessData.Participant) -> some View {
        HStack(spacing: DS.Spacing.md) {
            avatar(name: participant.name)

            Text(participant.name)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Text(appPreferences.currency(participant.amount, currencyCode: data.currencyCode))
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    private func avatar(name: String) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: data.groupColorHex).opacity(0.2))
                .frame(width: avatarSize, height: avatarSize)
            Text(String(name.prefix(1)).uppercased())
                .font(DS.Typography.label)
                .foregroundStyle(Color(hex: data.groupColorHex))
        }
        .accessibilityHidden(true)
    }

    // MARK: - Helpers

    private var isChargedToAccount: Bool {
        if case .chargedToAccount = data.personalOutcome { return true }
        return false
    }

    private var formattedDate: String {
        Self.dateFormatter.string(from: data.date)
    }

    private func runEntranceAnimation() {
        guard !reduceMotion else {
            showHero = true
            showCheckmark = true
            showAmount = true
            showDetails = true
            showActions = true
            return
        }

        showConfetti = true
        Task {
            // 0ms — hero circle + glow
            withAnimation(.spring(response: 0.5, dampingFraction: DS.Animation.springBouncy)) {
                showHero = true
            }

            // 150ms — checkmark
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(response: 0.4, dampingFraction: DS.Animation.springBouncy)) {
                showCheckmark = true
            }

            // 300ms — amount + debt
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showAmount = true
            }

            // 500ms — details + participants
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 0.35)) {
                showDetails = true
            }

            // 700ms — action buttons
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 0.3)) {
                showActions = true
            }
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
                .init(id: "1", name: "Tú", amount: 40),
                .init(id: "2", name: "Ana", amount: 40),
                .init(id: "3", name: "Luis", amount: 40),
            ],
            debt: .theyOweMe(80),
            isEditMode: false
        ),
        onAccept: {},
        onCreateAnother: {},
        onEdit: {}
    )
}
