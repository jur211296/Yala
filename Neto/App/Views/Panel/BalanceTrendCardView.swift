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
    let transactions: [ChartTransaction]
    let balanceStatus: BalanceStatus
    let historicalThreshold: Double
    let grouping: TrendGrouping
    let interval: DateInterval
    @Binding var trendType: TrendType
    @Binding var focusedDate: Date?

    /// Callback when user taps "Ver más detalle"
    let onViewDetail: ((TrendType) -> Void)?

    init(
        currentBalance: Double,
        totalExpense: Double,
        currencyCode: String,
        transactions: [ChartTransaction],
        balanceStatus: BalanceStatus,
        historicalThreshold: Double,
        grouping: TrendGrouping,
        interval: DateInterval,
        trendType: Binding<TrendType>,
        focusedDate: Binding<Date?>,
        onViewDetail: ((TrendType) -> Void)? = nil
    ) {
        self.currentBalance = currentBalance
        self.totalExpense = totalExpense
        self.currencyCode = currencyCode
        self.transactions = transactions
        self.balanceStatus = balanceStatus
        self.historicalThreshold = historicalThreshold
        self.grouping = grouping
        self.interval = interval
        self._trendType = trendType
        self._focusedDate = focusedDate
        self.onViewDetail = onViewDetail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection
            chartSection

            // "Ver más detalle" link
            if onViewDetail != nil {
                HStack {
                    Spacer()
                    Button {
                        onViewDetail?(trendType)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Ver más detalle")
                                .font(.footnote.weight(.medium))
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(
                            trendType == .balance ? Color.brandPrimary : Color.expenseGraph)
                    }
                }
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .top) {
            titleAndAmount
            Spacer()
            trendModeSelector
        }
    }

    private var titleAndAmount: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titleText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(amountText)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
        }
    }

    private var titleText: String {
        trendType == .balance ? "Saldo total" : "Gasto total"
    }

    private var amountText: String {
        let value = trendType == .balance ? currentBalance : totalExpense
        return "\(currencyCode) \(formattedAmount(value))"
    }

    // MARK: - Trend Mode Selector

    private var trendModeSelector: some View {
        HStack(spacing: 0) {
            ForEach(TrendType.allCases) { type in
                trendButton(for: type)
            }
        }
        .padding(4)
        .background(Color.gray.opacity(0.1))
        .clipShape(Capsule())
    }

    private func trendButton(for type: TrendType) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                trendType = type
            }
        } label: {
            Text(type.rawValue)
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(trendType == type ? Color.white : Color.secondary)
                .background(buttonBackground(for: type))
        }
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
            transactions: transactions,
            historicalThreshold: historicalThreshold,
            grouping: grouping,
            interval: interval,
            currencyCode: currencyCode,
            trendType: trendType,
            focusedDate: $focusedDate
        )
        .padding(.top, 10)
    }

    // MARK: - Helpers

    private func formattedAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }
}
