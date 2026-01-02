//
//  BalanceTrendCardView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI

struct BalanceTrendCardView: View {
    @Namespace private var namespace
    let currentBalance: Double
    let totalExpense: Double
    let currencyCode: String
    let trendPoints: [PanelViewModel.BarPoint]
    let yDomain: ClosedRange<Double>
    let balanceStatus: BalanceStatus
    let grouping: TrendGrouping
    let interval: DateInterval
    let period: DetailPeriod
    @Binding var trendType: TrendType
    @Binding var focusedDate: Date?
    var isLocked: Bool = false

    // Size Layout
    let size: WidgetSize

    /// Callback when user taps "Ver más detalle"
    let onViewDetail: ((TrendType) -> Void)?

    init(
        currentBalance: Double,
        totalExpense: Double,
        currencyCode: String,
        trendPoints: [PanelViewModel.BarPoint],
        yDomain: ClosedRange<Double>,
        balanceStatus: BalanceStatus,
        grouping: TrendGrouping,
        interval: DateInterval,
        trendType: Binding<TrendType>,
        focusedDate: Binding<Date?>,
        period: DetailPeriod,
        isLocked: Bool = false,
        size: WidgetSize = .large,
        onViewDetail: ((TrendType) -> Void)? = nil
    ) {
        self.currentBalance = currentBalance
        self.totalExpense = totalExpense
        self.currencyCode = currencyCode
        self.trendPoints = trendPoints
        self.yDomain = yDomain
        self.balanceStatus = balanceStatus
        self.grouping = grouping
        self.interval = interval
        self._trendType = trendType
        self._focusedDate = focusedDate
        self.period = period
        self.isLocked = isLocked
        self.size = size
        self.onViewDetail = onViewDetail
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: size == .medium ? DesignSystem.Spacing.large : DesignSystem.Spacing.xLarge
        ) {
            headerSection

            // For medium size, use geometry reader to ensure it fits or fixed height
            if size == .medium {
                chartSection
                    .padding(.top, 4)
            } else {
                chartSection
            }
        }
        .padding(.top, size == .medium ? DesignSystem.Spacing.medium : DesignSystem.Spacing.large)
        .padding(.horizontal, DesignSystem.Spacing.large)
        .padding(
            .bottom, size == .medium ? DesignSystem.Spacing.large : DesignSystem.Spacing.xxLarge
        )
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .top) {
            titleAndAmount
            Spacer()
            HStack(spacing: DesignSystem.Spacing.standard) {
                trendModeSelector

                // Chevron for Detail View
                if onViewDetail != nil {
                    Button {
                        onViewDetail?(trendType)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.headline)
                            .foregroundStyle(Color.gray.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var titleAndAmount: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Tendencia de saldo y gasto")
                .font(.headline)
                .foregroundStyle(Color.netoPrimaryText)
                .padding(.bottom, 2)

            Text(subtitleText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(amountText)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.netoPrimaryText)
        }
    }

    private var subtitleText: String {
        trendType == .balance ? "Saldo total" : "Gasto total"
    }

    private var amountText: String {
        let value = trendType == .balance ? currentBalance : totalExpense
        return NetoFormatter.currency(value: value, currencyCode: currencyCode)
    }

    // MARK: - Trend Mode Selector

    private var trendModeSelector: some View {
        HStack(spacing: 0) {
            ForEach(TrendType.allCases) { type in
                trendButton(for: type)
            }
        }
        .padding(4)
        .background(Color.netoSecondaryText.opacity(0.1))
        .clipShape(Capsule())
    }

    private func trendButton(for type: TrendType) -> some View {
        Button {
            withAnimation {
                trendType = type
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: type.iconName)
                    .font(.caption2.bold())
                Text(type.rawValue)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(trendType == type ? Color.white : Color.netoSecondaryText)
            .background(buttonBackground(for: type))
        }
        .disabled(isLocked)
        .opacity(isLocked ? 0.6 : 1.0)
    }

    @ViewBuilder
    private func buttonBackground(for type: TrendType) -> some View {
        if trendType == type {
            Capsule()
                .fill(fillColor(for: type))
                .matchedGeometryEffect(id: "TrendTab", in: namespace)
        } else {
            Capsule().fill(Color.clear)
        }
    }

    private func fillColor(for type: TrendType) -> Color {
        type == .balance ? Color.brandPrimary : Color.expenseGraph
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        TrendChartView(
            trendPoints: trendPoints,
            yDomain: yDomain,
            grouping: grouping,
            interval: interval,
            currencyCode: currencyCode,
            trendType: trendType,
            focusedDate: $focusedDate,
            period: period,
            chartHeight: size == .medium ? 100 : 220
        )
        .padding(.top, 10)
        .animation(nil, value: trendType)
    }
}
