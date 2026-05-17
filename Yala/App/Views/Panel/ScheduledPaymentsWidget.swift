//
//  ScheduledPaymentsWidget.swift
//  Yala
//
//  Widget displaying upcoming scheduled payments in PanelView.
//  - small: KPI block + ring (% paid) + filter selector.
//  - medium: list of upcoming payments + filter selector in header.
//  Reads from PanelScheduledPaymentsData (pre-computed in PanelViewModel) —
//  zero iteration over @Observable models in body.
//

import SwiftUI

struct ScheduledPaymentsWidget: View {
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppPreferences.self) private var appPreferences

    let data: PanelScheduledPaymentsData
    let currencyCode: String

    /// PP2-06b: tamaño del card. `.small` muestra KPI + ring; `.medium` lista de próximos pagos.
    var size: WidgetSize = .medium

    /// Filter state (all/recurring/subscriptions)
    @Binding var filter: ScheduledPaymentsWidgetFilter

    /// Callback when user taps to show more
    var onShowMore: (() -> Void)?

    /// Slot pedagógico opcional inyectado en el header (Panel Polish #2).
    var headerInfoButton: AnyView? = nil

    @Namespace private var filterNamespace

    var body: some View {
        Group {
            if size == .small {
                smallCardContent
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    headerSection
                    listContent
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .panelCard(small: size == .small)
        .frame(height: size == .small ? WidgetSize.smallHeight : nil)
    }

    // MARK: - Small Layout (PP2-06b)

    private var smallCardContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            PanelSmallWidgetHeader(
                title: smallDynamicTitle,
                accessibilityLabel: L10n.Panel.seeMoreHintScheduled,
                action: onShowMore,
                headerInfoButton: headerInfoButton
            )

            if data.activeCount == 0 || data.monthlyTotal == 0 {
                smallEmptyState
            } else {
                HStack(alignment: .center, spacing: DS.Spacing.sm) {
                    smallKPIBlock
                    Spacer(minLength: 0)
                    smallRing
                        .accessibilityLabel(ringAccessibilityLabel)
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var smallKPIBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            AmountText(
                value: smallToPayAmount,
                currencyCode: currencyCode,
                // A11Y-DT: KPI widget — escala vía minimumScaleFactor(0.7).
                font: .system(size: 28, weight: .semibold),
                secondaryFont: .system(size: 14)
            )

            Text(L10n.Scheduled.Widget.smallToPay)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
        }
    }

    private var smallRing: some View {
        ZStack {
            ScoreRingView(
                progress: smallProgress,
                size: 56,
                lineWidth: 7,
                foreground: smallRingColor
            )
        }
        .frame(width: 56, height: 56)
    }

    /// % se omite: ya vive dentro del ring.
    private var smallInfoText: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(String(
                format: L10n.Scheduled.Widget.smallPaidAmount,
                appPreferences.currency(data.paidAmount, currencyCode: currencyCode)
            ))
            .font(DS.Typography.captionSmall)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Text(String(
                format: L10n.Scheduled.Widget.smallActivePending,
                data.activeCount,
                data.pendingCount
            ))
            .font(DS.Typography.captionSmall)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }

    // MARK: - Small derived values

    private var smallToPayAmount: Double {
        max(0, data.monthlyTotal - data.paidAmount)
    }

    private var smallProgress: Double {
        guard data.monthlyTotal > 0 else { return 0 }
        return max(0, min(1, data.paidAmount / data.monthlyTotal))
    }

    private var smallPercentPaid: Int {
        Int((smallProgress * 100).rounded())
    }

    private var ringAccessibilityLabel: String {
        "\(smallPercentPaid)%"
    }

    private var smallDynamicTitle: String {
        switch filter {
        case .all: return L10n.Scheduled.Widget.smallTitle
        case .recurring: return L10n.Scheduled.Tab.recurring
        case .subscriptions: return L10n.Scheduled.Tab.subscriptions
        }
    }

    /// Large mode title — mirror dynamic behavior of `smallDynamicTitle` but
    /// uses the full-form labels ("Pagos planificados" / "Pagos recurrentes")
    /// that read better in the wider layout.
    private var largeDynamicTitle: String {
        switch filter {
        case .all: return L10n.WidgetType.scheduledPayments
        case .recurring: return L10n.Scheduled.Widget.largeTitleRecurring
        case .subscriptions: return L10n.Scheduled.Tab.subscriptions
        }
    }

    private static let ringFromRGB: (r: CGFloat, g: CGFloat, b: CGFloat) = {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(Color.hotPink).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }()

    private static let ringToRGB: (r: CGFloat, g: CGFloat, b: CGFloat) = {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(Color.indigo).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }()

    /// Color del ring interpolado entre hotPink (0%) e indigo (100%).
    private var smallRingColor: Color {
        let t = smallProgress
        let from = Self.ringFromRGB
        let to = Self.ringToRGB
        return Color(
            red: from.r + (to.r - from.r) * t,
            green: from.g + (to.g - from.g) * t,
            blue: from.b + (to.b - from.b) * t
        )
    }

    private var smallEmptyState: some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: "calendar.badge.clock")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(L10n.Scheduled.Widget.emptyTitle)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    Text(largeDynamicTitle)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    WidgetHeaderInfoSlot(
                        injected: headerInfoButton,
                        legacyTitle: largeDynamicTitle,
                        legacyMessage: L10n.Widget.Hint.scheduledPayments
                    )
                }

                // Period label
                Text(data.periodLabel)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                // Filter selector
                filterSelector
            }
        }
    }

    private var filterSelector: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(ScheduledPaymentsWidgetFilter.allCases) { filterOption in
                filterButton(for: filterOption)
            }
        }
    }

    private func filterButton(for filterOption: ScheduledPaymentsWidgetFilter) -> some View {
        let isSelected = filter == filterOption

        return Button {
            dsWithAnimation(reduceMotion, .spring(response: 0.3, dampingFraction: 0.7)) {
                filter = filterOption
            }
        } label: {
            Image(systemName: filterOption.iconName)
                .font(DS.Typography.labelSmall)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : theme.secondaryText)
                .frame(width: 32, height: 32)
                .background {
                    if isSelected {
                        Circle()
                            .fill(theme.accent)
                            .matchedGeometryEffect(id: "filterSelector", in: filterNamespace)
                    } else {
                        Circle()
                            .fill(.thSecondaryText.opacity(0.08))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(filterOption == .all ? L10n.Accessibility.filterScheduledAll : filterOption == .recurring ? L10n.Accessibility.filterScheduledRecurring : L10n.Accessibility.filterScheduledSubscriptions)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - List Content

    private var listContent: some View {
        VStack(spacing: DS.Spacing.md) {
            if data.upcomingPayments.isEmpty {
                emptyListState
            } else {
                ForEach(data.upcomingPayments) { item in
                    paymentRow(item)
                }
            }
        }
    }

    private var emptyListState: some View {
        YalaEmptyState(
            icon: "calendar.badge.clock",
            title: L10n.Scheduled.Widget.emptyTitle,
            message: L10n.Scheduled.Widget.emptyMessage,
            style: .widget
        )
    }

    private func paymentRow(_ item: ScheduledPaymentListItem) -> some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(Color(hex: item.color))
                    .frame(width: 36, height: 36)

                Image(systemName: item.icon)
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }

            // Info
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(item.name)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .opacity(item.isPaid ? 0.6 : 1.0)

                Text(item.dueDateLabel)
                    .font(DS.Typography.caption)
                    .foregroundStyle(item.dueStatus == .past ? Color.hotPink : .secondary)
            }

            Spacer()

            // Amount + status badge
            HStack(spacing: DS.Spacing.xs) {
                AmountText(
                    value: item.isIncome ? item.amount : -item.amount,
                    currencyCode: item.currencyCode,
                    font: DS.Typography.headline, secondaryFont: DS.Typography.caption,
                    tint: .color(item.isIncome ? Color.priorityNeed : Color.hotPink),
                    forceSign: true,
                    isEstimate: item.isVariableAmount,
                    forceFullPrecision: true
                )
                .opacity(item.isPaid || item.isSkipped ? 0.6 : 1.0)

                if item.isSkipped {
                    Image(systemName: "arrow.uturn.forward.circle")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                } else if item.isPaid {
                    Image(systemName: "checkmark.circle.fill")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(theme.accent)
                        .accessibilityHidden(true)
                }
            }
        }
    }

}
