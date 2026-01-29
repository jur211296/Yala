//
//  CurrencySettingsView.swift
//  Yala
//
//  Settings view for preferred currency and exchange rates.
//

import SwiftData
import SwiftUI

struct CurrencySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(CurrencyConverter.self) private var currencyConverter
    @Environment(ExchangeRateService.self) private var exchangeRateService

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.pen
        .rawValue
    @AppStorage("secondaryCurrencies") private var secondaryCurrenciesRaw: String = ""

    private var preferredCurrency: CurrencyCode {
        CurrencyCode(rawValue: defaultCurrencyCode) ?? .pen
    }

    /// Parsed secondary currencies from storage
    private var secondaryCurrencies: Set<CurrencyCode> {
        Set(
            secondaryCurrenciesRaw
                .split(separator: ",")
                .compactMap { CurrencyCode(rawValue: String($0)) }
        )
    }

    /// All currencies to show in exchange rate section (all except the preferred one)
    private var displayedCurrencies: [CurrencyCode] {
        CurrencyCode.allCases.filter { $0 != preferredCurrency }
    }

    @State private var isUpdating: Bool = false
    @State private var updateProgress: Double = 0.0

    var body: some View {
        ZStack {
            PanelBackgroundView()

            // Main Content
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {

                    // Header
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.brandPrimary)
                            .padding(.bottom, DS.Spacing.sm)

                        Text(L10n.Settings.currencyAndExchange)
                            .font(Typography.title2)
                            .foregroundStyle(Color.yalaPrimaryText)

                        Text(L10n.Settings.currencyDescription)
                            .font(Typography.body)
                            .foregroundStyle(Color.yalaSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DS.Spacing.xxxl)

                    VStack(spacing: DS.Spacing.xxl) {
                        preferredCurrencySection
                        secondaryCurrenciesSection
                        exchangeRatesSection
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .blur(radius: isUpdating ? 3 : 0)
            .disabled(isUpdating)

            // Progress Overlay
            if isUpdating {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: DS.Spacing.lg) {
                    ProgressView(value: updateProgress, total: 1.0)
                        .progressViewStyle(.linear)
                        .frame(width: 200)

                    Text(L10n.Common.updatingRecords)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(L10n.Common.recalculatingConversions)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(DS.Spacing.xxl)
                .background(.ultraThinMaterial)
                .cornerRadius(DS.Radius.lg)
            }
        }
        .navigationTitle(L10n.Settings.currencyAndExchange)
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(isUpdating)
    }

    // MARK: - Preferred Currency Section

    private var preferredCurrencySection: some View {
        SectionBox(title: L10n.Settings.preferredCurrency) {
            VStack(spacing: 0) {
                ForEach(Array(CurrencyCode.allCases.enumerated()), id: \.element) {
                    index, currency in
                    if index > 0 {
                        SubsectionDivider()
                    }
                    preferredCurrencyRow(currency: currency)
                }
            }
        }
    }

    @ViewBuilder
    private func preferredCurrencyRow(currency: CurrencyCode) -> some View {
        let info = currencyInfo(for: currency)

        Button {
            updatePreferredCurrency(to: currency)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Text(info.flag)
                    .font(.title3)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(info.name.capitalized)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(info.code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if currency == preferredCurrency {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.electricIndigo)
                        .font(.body.weight(.semibold))
                }
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Secondary Currencies Section

    private var secondaryCurrenciesSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            SectionBox(title: L10n.Settings.secondaryCurrencies) {
                VStack(spacing: 0) {
                    ForEach(Array(displayedCurrencies.enumerated()), id: \.element) {
                        index, currency in
                        if index > 0 {
                            SubsectionDivider()
                        }
                        secondaryCurrencyRow(currency: currency)
                    }
                }
            }

            // Hint text
            Text(L10n.Settings.secondaryCurrenciesHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func secondaryCurrencyRow(currency: CurrencyCode) -> some View {
        let info = currencyInfo(for: currency)
        let isSelected = secondaryCurrencies.contains(currency)
        let canSelect = isSelected || secondaryCurrencies.count < 2

        Button {
            toggleSecondaryCurrency(currency)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Text(info.flag)
                    .font(.title3)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(info.name.capitalized)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(info.code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.electricIndigo : .secondary)
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(canSelect ? 1.0 : 0.5)
        .disabled(!canSelect)
    }

    private func toggleSecondaryCurrency(_ currency: CurrencyCode) {
        var current = secondaryCurrencies
        if current.contains(currency) {
            current.remove(currency)
        } else if current.count < 2 {
            current.insert(currency)
        }
        // Save back to storage
        secondaryCurrenciesRaw = current.map { $0.rawValue }.joined(separator: ",")
    }

    private func updatePreferredCurrency(to newCurrency: CurrencyCode) {
        guard newCurrency != preferredCurrency else { return }

        isUpdating = true
        updateProgress = 0.0

        Task {
            do {
                // Run the batch update
                try await CurrencyChangeService.shared.updateAllTransactions(
                    to: newCurrency.rawValue,
                    context: modelContext,
                    onProgress: { progress in
                        updateProgress = progress
                    }
                )

                // Only update the AppStorage setting AFTER successful migration
                defaultCurrencyCode = newCurrency.rawValue

            } catch {
                print("Error updating transactions: \(error)")
                // Optionally show an alert here?
            }

            isUpdating = false
        }
    }

    // MARK: - Exchange Rates Section

    private var exchangeRatesSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            SectionBox(title: L10n.Settings.exchangeRate) {
                VStack(spacing: 0) {
                    ForEach(Array(displayedCurrencies.enumerated()), id: \.element) {
                        index, currency in
                        if index > 0 {
                            SubsectionDivider()
                        }
                        exchangeRateRow(currency: currency)
                    }
                }
            }

            // Last updated disclaimer
            if let latestRate = exchangeRateService.getLatestRate(context: modelContext) {
                // Use API timestamp if available, otherwise fall back to dateKey
                let rateDate: Date? =
                    latestRate.timestamp
                    ?? {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        dateFormatter.timeZone = TimeZone(identifier: "UTC")
                        return dateFormatter.date(from: latestRate.dateKey)
                    }()

                if let date = rateDate {
                    Text("\(L10n.Common.lastUpdate) \(formatLastUpdated(date))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private func formatLastUpdated(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "d 'de' MMMM yyyy, HH:mm"
        return formatter.string(from: date)
    }

    @ViewBuilder
    private func exchangeRateRow(currency: CurrencyCode) -> some View {
        let info = currencyInfo(for: currency)
        let rate = getDisplayRate(from: currency, to: preferredCurrency)
        let preferredInfo = currencyInfo(for: preferredCurrency)

        HStack(spacing: DS.Spacing.md) {
            Text(info.flag)
                .font(.title3)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("1 \(info.code)")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(info.name.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let rate = rate {
                Text(String(format: "%.4f %@", rate, preferredInfo.code))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.primary)
            } else {
                Text("--")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private func getDisplayRate(from: CurrencyCode, to: CurrencyCode) -> Double? {
        currencyConverter.getDisplayRate(
            from: from.rawValue, to: to.rawValue, context: modelContext)
    }
}

#Preview {
    NavigationStack {
        CurrencySettingsView()
    }
    .modelContainer(for: [Account.self, ExchangeRate.self])
}
