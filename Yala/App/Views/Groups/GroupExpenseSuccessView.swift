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

            debtIndicator
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
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .scaleEffect(showCheckmark ? 1.0 : 0.0)
                .opacity(showCheckmark ? 1.0 : 0.0)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var debtIndicator: some View {
        switch data.debt {
        case .theyOweMe(let amount):
            debtLabel(L10n.Groups.Summary.owedToMe, amount: amount, color: DS.Semantic.successForeground)
        case .iOwe(let amount):
            debtLabel(L10n.Groups.Summary.iOwe, amount: amount, color: .hotPink)
        case .settled:
            EmptyView()
        }
    }

    private func debtLabel(_ label: String, amount: Double, color: Color) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(label)
            Text(appPreferences.currency(amount, currencyCode: data.currencyCode))
                .fontWeight(.semibold)
        }
        .font(DS.Typography.subheadline)
        .foregroundStyle(color)
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

            if let account = data.accountName {
                detailRow(icon: "creditcard", label: L10n.Account.selectAccount,
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
