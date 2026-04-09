//
//  ExchangeRateWidgetModels.swift
//  Yala
//
//  Models for the Exchange Rate widget.
//

import Foundation

// MARK: - Exchange Rate Chart Point

/// A single data point for the exchange rate line chart.
struct ExchangeRateChartPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    /// Rates from preferred currency to each comparison currency.
    /// Key = currency code (e.g., "USD"), Value = rate (e.g., 0.27 for 1 PEN = 0.27 USD)
    var rates: [String: Double]

    func rate(for currency: String) -> Double? {
        rates[currency]
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.date == rhs.date && lhs.rates == rhs.rates
    }
}

// MARK: - Exchange Rate Widget Data

/// Aggregated data for the Exchange Rate widget display.
struct ExchangeRateWidgetData: Equatable {
    /// The preferred currency (base currency for display).
    let preferredCurrency: String

    /// Current/latest exchange rates (for today or last available date).
    let currentRates: [String: Double]

    /// Date of the current rates (might be today or last available).
    let currentRatesDate: Date

    /// Whether the current rates are from today or a fallback.
    var isToday: Bool {
        Calendar.current.isDateInToday(currentRatesDate)
    }

    /// Chart data points for the selected period.
    let chartPoints: [ExchangeRateChartPoint]

    /// Error state if data couldn't be loaded.
    let hasError: Bool
    let errorMessage: String?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.preferredCurrency == rhs.preferredCurrency
            && lhs.currentRates == rhs.currentRates
            && lhs.currentRatesDate == rhs.currentRatesDate
            && lhs.chartPoints == rhs.chartPoints
            && lhs.hasError == rhs.hasError
            && lhs.errorMessage == rhs.errorMessage
    }

    // MARK: - Initializers

    init(
        preferredCurrency: String,
        currentRates: [String: Double],
        currentRatesDate: Date,
        chartPoints: [ExchangeRateChartPoint]
    ) {
        self.preferredCurrency = preferredCurrency
        self.currentRates = currentRates
        self.currentRatesDate = currentRatesDate
        self.chartPoints = chartPoints
        self.hasError = false
        self.errorMessage = nil
    }

    /// Error state initializer.
    init(preferredCurrency: String, errorMessage: String) {
        self.preferredCurrency = preferredCurrency
        self.currentRates = [:]
        self.currentRatesDate = Date.now
        self.chartPoints = []
        self.hasError = true
        self.errorMessage = errorMessage
    }

    /// Empty placeholder.
    static func empty(preferredCurrency: String) -> ExchangeRateWidgetData {
        ExchangeRateWidgetData(
            preferredCurrency: preferredCurrency,
            currentRates: [:],
            currentRatesDate: Date.now,
            chartPoints: []
        )
    }
}
