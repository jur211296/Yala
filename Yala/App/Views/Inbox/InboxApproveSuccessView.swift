//
//  InboxApproveSuccessView.swift
//  Yala
//
//  Success screen after approving a draft from Inbox.
//  Shows transaction details with options: Edit, Accept, Approve Next.
//

import SwiftUI

/// Data for displaying approved transaction details
struct InboxApproveSuccessData {
    let date: Date
    let accountName: String
    let accountColorHex: String
    let note: String
    let amount: Double
    let currencyCode: String
    let subcategoryName: String
    let categoryName: String
    let categoryColorHex: String
    let isExpense: Bool
}

/// El check de las pantallas de éxito de la Bandeja (aprobar uno y aprobar varios). Tono suave, como los indicadores
/// del Panel: el verde de éxito al 15 % de fondo y el ✓ en verde. Sin halo, degradado ni sombra: la regla de Jürgen.
struct InboxApproveSuccessCheck: View {
    var isVisible: Bool = true
    var isCheckVisible: Bool = true

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 36 // A11Y-DT: @ScaledMetric

    var body: some View {
        ZStack {
            Circle()
                .fill(DS.Semantic.successBackground)
                .frame(width: 100, height: 100)
                .scaleEffect(isVisible ? 1.0 : 0.3)
                .opacity(isVisible ? 1.0 : 0.0)

            Image(systemName: "checkmark")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(DS.Semantic.successForeground)
                .scaleEffect(isCheckVisible ? 1.0 : 0.0)
                .opacity(isCheckVisible ? 1.0 : 0.0)
                .accessibilityHidden(true)
        }
    }
}

struct InboxApproveSuccessView: View {
    let data: InboxApproveSuccessData
    let hasNextDraft: Bool
    let onEdit: () -> Void
    let onAccept: () -> Void
    let onApproveNext: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @State private var showHero = false
    @State private var showCheckmark = false
    @State private var showAmount = false
    @State private var showDetails = false
    @State private var showActions = false

    private var typeColor: Color { data.isExpense ? Color.hotPink : Color.electricIndigo }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: DS.Spacing.none) {
                // Edit button at top right
                HStack {
                    Spacer()
                    Button(L10n.Action.edit, action: onEdit)
                        .buttonStyle(.bordered)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.lg)
                .opacity(showActions ? 1.0 : 0.0)

                // Mismo arreglo que `TransactionSuccessView`: el centro no tenía scroll y en un iPhone SE no
                // cabía ni a tamaño normal («Editar» y el título se salían por arriba y «Aprobar siguiente» por
                // abajo; medido el 2026-09-28). Solo el centro se desplaza, y solo si no cabe.
                GeometryReader { proxy in
                    ScrollView {
                        VStack(spacing: DS.Spacing.none) {
                            Spacer()

                            // Hero area
                            VStack(spacing: DS.Spacing.lg) {
                                // Title above circle
                                Text(L10n.Inbox.approveSuccess)
                                    .font(DS.Typography.headline)
                                    .foregroundStyle(.secondary)
                                    .opacity(showHero ? 1.0 : 0.0)

                                // Check verde SUAVE, el mismo al aprobar uno y varios (UX 2.2 · L4-13, variante 2): sin
                                // halo, degradado ni sombra. La aparición animada se queda.
                                InboxApproveSuccessCheck(isVisible: showHero, isCheckVisible: showCheckmark)

                                // Promoted amount
                                AmountText(
                                    value: data.amount,
                                    currencyCode: data.currencyCode,
                                    font: DS.Typography.heroAmount, secondaryFont: DS.Typography.heroAmountSecondary,
                                    tint: .color(typeColor),
                                    forceFullPrecision: true
                                )
                                .scaleEffect(showAmount ? 1.0 : 0.8)
                                .opacity(showAmount ? 1.0 : 0.0)
                            }
                            .padding(.bottom, DS.Spacing.xxxl)

                            // Transaction details
                            detailsSection
                                .padding(.horizontal, DS.Spacing.xl)
                                .opacity(showDetails ? 1.0 : 0.0)
                                .offset(y: showDetails ? 0 : 15)

                            Spacer()
                        }
                        .frame(minHeight: proxy.size.height)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollIndicators(.hidden)
                }

                // Action buttons
                actionButtons
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.xxxl)
                    .opacity(showActions ? 1.0 : 0.0)
                    .offset(y: showActions ? 0 : 10)
            }
        }
        .onAppear {
            // Momento de éxito: aquí se pide la oferta de prueba armada (UX 2.2 · L1-12, `TrialOfferMomentLogic`).
            TrialOfferMoments.noteRecordSaved()
            if reduceMotion {
                showHero = true
                showCheckmark = true
                showAmount = true
                showDetails = true
                showActions = true
            } else {
                Task {
                    do {
                        // 0ms — hero circle + glow
                        withAnimation(.spring(response: 0.5, dampingFraction: DS.Animation.springBouncy)) {
                            showHero = true
                        }

                        // 150ms — checkmark
                        try await Task.sleep(for: .milliseconds(150))
                        withAnimation(.spring(response: 0.4, dampingFraction: DS.Animation.springBouncy)) {
                            showCheckmark = true
                        }

                        // 300ms — amount
                        try await Task.sleep(for: .milliseconds(150))
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showAmount = true
                        }

                        // 500ms — details card
                        try await Task.sleep(for: .milliseconds(200))
                        withAnimation(.easeOut(duration: 0.35)) {
                            showDetails = true
                        }

                        // 700ms — action buttons
                        try await Task.sleep(for: .milliseconds(200))
                        withAnimation(.easeOut(duration: 0.3)) {
                            showActions = true
                        }
                    } catch {
                        // Task cancelled — stop animation sequence
                        return
                    }
                }
            }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(spacing: DS.Spacing.none) {
            // Date
            detailRow(
                icon: "calendar",
                label: L10n.Transaction.date,
                value: formattedDate
            )

            // Account
            accountRow

            // Category/Subcategory
            categoryRow

            // Note
            if !data.note.isEmpty {
                detailRow(
                    icon: "text.alignleft",
                    label: L10n.Transaction.note,
                    value: data.note
                )
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .panelCard()
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        formatter.locale = AppLocale.current
        return formatter
    }()

    private var formattedDate: String {
        Self.dateFormatter.string(from: data.date)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: DS.Icon.sizeLarge)
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

    private var accountRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "creditcard")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: DS.Icon.sizeLarge)
                .accessibilityHidden(true)

            Text(L10n.Transaction.account)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(Color(hex: data.accountColorHex))
                    .frame(width: DS.Chip.dotSize, height: DS.Chip.dotSize)
                Text(data.accountName)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    private var categoryRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "tag")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: DS.Icon.sizeLarge)
                .accessibilityHidden(true)

            Text(L10n.Transaction.category)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    Circle()
                        .fill(Color(hex: data.categoryColorHex))
                        .frame(width: DS.Chip.dotSize, height: DS.Chip.dotSize)
                    Text(data.subcategoryName)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)
                }
                Text(data.categoryName)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: DS.Spacing.md) {
            // Primary: Accept (go back to inbox)
            YalaPrimaryButton(L10n.Common.accept, action: onAccept)
                .accessibilityIdentifier("inbox_success_accept")

            // Secondary: Approve next (if available)
            if hasNextDraft {
                Button(action: onApproveNext) {
                    HStack {
                        Image(systemName: "arrow.right.circle")
                        Text(L10n.Inbox.approveNext)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                .controlSize(.large)
            }
        }
    }
}

#Preview {
    InboxApproveSuccessView(
        data: InboxApproveSuccessData(
            date: Date.now,
            accountName: "Efectivo",
            accountColorHex: "4CAF50",
            note: "Almuerzo con amigos",
            amount: -45.50,
            currencyCode: "PEN",
            subcategoryName: "Restaurantes",
            categoryName: "Alimentación",
            categoryColorHex: "FF9800",
            isExpense: true
        ),
        hasNextDraft: true,
        onEdit: {},
        onAccept: {},
        onApproveNext: {}
    )
}
